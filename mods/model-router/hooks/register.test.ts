import { test, expect, mock } from 'claude-code/testing'
import type { Engine, MockClock, Plugin } from 'claude-code/testing'
import type { On, TurnStepInput } from 'claude-code'

const FABLE = 'claude-fable-5-1'
const OPUS = 'claude-opus-5-5'
const SONNET = 'claude-sonnet-5-5'
const HAIKU = 'claude-haiku-5-5'

type Rec = Record<string, unknown>
type Asked = { text: string; options: string[]; header: string }

const HOME = '/home/t'
const HOME_FILE = `${HOME}/.claude/model-router.json`
const ROOT = '/work/app'
const REAL_ROOT = '/real/work/app'
const REMOTE = 'https://github.com/acme/app.git'
const KEY = 'github.com/acme/app'
const REJECT = '<rejected>' // an answer the dialog never gets: headless
// A Change answered to the end: model, effort (no scope yet). /feat is on
// reflect (best, high); implement is the first work/medium phase, apply
// the work/low one, judge the only big one (opus has one effort: skipped).
const TO_IMPLEMENT = ['Change', 'sonnet (work)', 'medium']
const TO_APPLY = ['Change', 'sonnet (work)', 'low']
const TO_JUDGE = ['Change', 'opus (big)']
const SCOPE_ASK = 3 // index of the scope question after a Change chain

// What the engine answers a completion with: an object, not the documented
// string (observed live); the router accepts any resolved shape.
const PROBE_OK = { isAnswered: true, text: 'ok' } as unknown as string

/** What the bottom `fs`, `env`, `session.repo` and dialog hooks serve. */
type World = {
  files: Map<string, string> // 'routing' (routing.json) or a full path
  reads: string[] // every path fs.read got
  written: string[] // every path fs.write got
  asked: Asked[] // the dialogs, in order
  answers: string[] // queued dialog answers (REJECT = headless)
  gate: Promise<void> | undefined // holds a dialog open until it settles
  writeGate: Promise<void> | undefined // holds an fs.write open
  failWrite: boolean // fs.write rejects
  clockFailsAfterAsk: boolean // clock.now rejects once a dialog opened
  sleepFails: boolean // clock.sleep rejects (the picker's delay)
  sessionId: string // what session.id answers
  onAsk: (() => void) | undefined // called when a dialog opens
  onWrite: (() => void) | undefined // called when an fs.write starts
  repo: { root: string; remote: string | null } | null | 'fail'
  env: string | undefined // HOME as env.get answers it (undefined = unset)
  kinds: Map<string, 'file' | 'dir' | 'other'> // per-path stat kind override
  dirs: Map<string, {
    kind: 'dir' | 'file' | 'other'
    isLink: boolean
    exists?: false // a dangling link: stat answers, exists does not
  }>
  // paths fs.exists/fs.stat answer for, with or without file text
  brokenStat: Set<string> // paths that exist but whose stat rejects
  surfaces: readonly string[] // what session.surfaces answers ([] = headless)
  complete: (model: string) => unknown // what a completion resolves to
  completions: string[] // every model a completion was asked of
}

type Fixture = {
  ask?: boolean // routing.json `ask` (default false: no dialog)
  edit?: (file: Rec) => void // tweaks the inline routing.json
  routing?: 'absent' | 'broken'
  home?: Rec | 'broken' // ~/.claude/model-router.json
  answers?: string[]
  repo?: World['repo']
  noHome?: boolean // HOME unset: env.get answers undefined
  surfaces?: readonly string[] // default ['terminal']
  clockFailsAfterAsk?: boolean // see World; the rig gets no MockClock
  sleepFails?: boolean // see World; the rig gets no MockClock
}

/**
 * The phases as shipped and the rows the tests use; the real table is
 * locked by the census.
 */
const baseRouting = (): Rec => ({
  phases: {
    plan: { tier: 'best', effort: 'xhigh' },
    reflect: { tier: 'best', effort: 'high' },
    orchestrate: { tier: 'best', effort: 'medium' },
    escalate: { tier: 'best', effort: 'max' },
    judge: { tier: 'big', effort: 'xhigh' },
    audit: { tier: 'best', effort: 'xhigh' },
    implement: { tier: 'work', effort: 'medium' },
    write: { tier: 'work', effort: 'high' },
    verify: { tier: 'work', effort: 'xhigh' },
    explore: { tier: 'work', effort: 'medium' },
    apply: { tier: 'work', effort: 'low' },
    mechanical: { tier: 'cheap', effort: 'low' },
  },
  skills: {
    feat: 'reflect',
    status: 'mechanical',
    gitflow: 'implement',
    'using-git-worktrees': 'mechanical',
  },
  agents: {
    Explore: 'explore',
    'plan-challenger': 'judge',
    feater: 'implement',
    verifier: 'verify',
  },
  projects: {},
  confirmed: {},
  changed: {},
  ask: false,
})

function newWorld(fx: Fixture = {}): World {
  const file = baseRouting()
  file.ask = fx.ask ?? false
  fx.edit?.(file)
  const files = new Map<string, string>()
  if (fx.routing === 'broken') files.set('routing', '{nope')
  else if (fx.routing !== 'absent') {
    files.set('routing', JSON.stringify(file, null, 2))
  }
  if (fx.home !== undefined) {
    files.set(HOME_FILE,
      fx.home === 'broken' ? '{nope' : JSON.stringify(fx.home))
  }
  return {
    files,
    reads: [],
    written: [],
    asked: [],
    answers: [...(fx.answers ?? [])],
    gate: undefined,
    writeGate: undefined,
    failWrite: false,
    clockFailsAfterAsk: fx.clockFailsAfterAsk ?? false,
    sleepFails: fx.sleepFails ?? false,
    sessionId: 's1',
    onAsk: undefined,
    onWrite: undefined,
    repo: fx.repo === undefined ? { root: ROOT, remote: REMOTE } : fx.repo,
    env: fx.noHome ? undefined : HOME,
    kinds: new Map(),
    dirs: new Map(),
    brokenStat: new Set(),
    surfaces: fx.surfaces ?? ['terminal'],
    complete: () => PROBE_OK,
    completions: [],
  }
}

const LOCAL_FILE = `${ROOT}/.claude/settings.local.json`

const slot = (path: string): string => {
  if (path.endsWith('/routing.json')) return 'routing'
  if (path === LOCAL_FILE) return 'local'
  // the engine resolves a relative path against its cwd: `undefined/...`
  // (a HOME read as unset and not guarded) comes back absolute
  const rel = /\/(undefined\/\.claude\/.*)$/.exec(path)
  return rel?.[1] ?? path
}

/** routing.json as the world holds it now. */
const routingOf = (w: World): Rec =>
  JSON.parse(w.files.get('routing') ?? '{}') as Rec

/**
 * A path-aware fs, HOME, project root and repo: the kit has none (an fs call
 * no hook answers is refused, never sent to the disk: see "writes: kit").
 */
function installWorld(on: On, w: World): void {
  on('env.get', () => ({ value: w.env }))
  on('fs.exists', (_a, e) => ({
    value: w.dirs.get(e.path)?.exists === false ? false :
      w.files.has(slot(e.path)) || e.path === ROOT || w.dirs.has(e.path),
  }))
  on('fs.stat', (_a, e) => {
    const text = w.files.get(slot(e.path))
    const known = w.dirs.get(e.path)
    if (w.brokenStat.has(e.path)) throw new Error('EIO')
    if (text === undefined && e.path !== ROOT && known === undefined) {
      throw new Error('ENOENT')
    }
    return {
      value: {
        kind: known?.kind ?? w.kinds.get(e.path) ??
          (text === undefined ? 'dir' as const : 'file' as const),
        size: text?.length ?? 0,
        mtimeMs: 0,
        isLink: known?.isLink ?? false,
        ...(e.resolve ? { realPath: REAL_ROOT } : {}),
      },
    }
  })
  on('fs.read', (_a, e) => {
    w.reads.push(e.path)
    const text = w.files.get(slot(e.path))
    if (text === undefined) throw new Error('ENOENT')
    return { value: text }
  })
  installWrite(on, w)
  on('session.root', () => ({ value: ROOT }))
  on('session.surfaces', () => ({ value: w.surfaces as never }))
  on('session.repo', () => {
    if (w.repo === 'fail') throw new Error('no repo')
    return { value: w.repo === null ? null : {
      ...w.repo, internal: false, name: null,
    } }
  })
  on('classic.CwdChanged', () => ({}))
  installDialog(on, w)
}

/** The paths the world's fs.write accepts: see installWrite. */
const worldServes = (w: World, path: string): boolean =>
  path === LOCAL_FILE || (slot(path) === 'routing' && w.reads.includes(path))

/**
 * The world's fs.write. Loud: a write anywhere but the routing.json the mod
 * read fails the test (never a project tree, never the machine override).
 * One carve-out: the project's .claude/settings.local.json, which the
 * /model scope dialog writes, read or not (a missing file is created).
 */
function installWrite(on: On, w: World): void {
  on('fs.write', async (_a, e) => {
    expect(worldServes(w, e.path),
      `the world never served ${e.path}`).toBe(true)
    w.written.push(e.path)
    w.onWrite?.()
    await w.writeGate
    if (w.failWrite) throw new Error('EACCES')
    w.files.set(slot(e.path), e.text)
    return { value: undefined }
  })
}

/** The AskUserQuestion tool beneath `$.ui.ask`: records, then answers. */
function installDialog(on: On, w: World): void {
  on('tool.call', { tool: 'AskUserQuestion' }, async (_a, e) => {
    const q = (e as unknown as { questions: Rec[] }).questions[0] ?? {}
    const options = (q.options as { label: string }[] | undefined) ?? []
    w.asked.push({
      text: String(q.question),
      options: options.map(o => o.label),
      header: String(q.header),
    })
    w.onAsk?.()
    await w.gate
    const answer = w.answers.shift() ?? REJECT
    if (answer === REJECT) return { deny: 'no one to ask' }
    return { result: {
      questions: e.questions, answers: { [String(q.question)]: answer },
    } } as never
  })
}

/** A clock that rejects once a dialog opened (no MockClock: never advanced). */
function failingClock(on: On, w: World): MockClock {
  on('clock.now', () => {
    if (w.asked.length > 0) throw new Error('boom')
    return { value: 0 }
  })
  on('clock.sleep', () => ({ value: undefined }))
  return undefined as unknown as MockClock
}

/** A clock whose sleep rejects (LRN-229: a whole-clock replacement). */
function sleepFailsClock(on: On): MockClock {
  on('clock.now', () => ({ value: 0 }))
  on('clock.sleep', () => {
    throw new Error('boom')
  })
  return undefined as unknown as MockClock
}

/** The clock the world asks for: a mock one unless a fixture breaks it. */
function clockOf(on: On, w: World): MockClock {
  if (w.clockFailsAfterAsk) return failingClock(on, w)
  return w.sleepFails ? sleepFailsClock(on) : mock.clock(on)
}

/**
 * Fires session.start so the mod loads its config and registers /route.
 * The bottom hooks the router reads are in place before the first `$` call:
 * the session model, the classic failure and switch events, a mock clock,
 * a small context (`tokens`; null = usage unanswered, size unknown), and
 * the `world` (fs, repo, dialog) serving an inline routing.json.
 */
async function boot(
  $: Engine,
  on: On,
  model: string = FABLE,
  tokens: number | null = 1000,
  world: World = newWorld(),
): Promise<MockClock> {
  const clock = clockOf(on, world)
  on('session.model', () => ({ value: model }))
  on('classic.StopFailure', () => ({}))
  on('classic.PostModelSwitch', () => ({}))
  on('classic.PreModelSwitch', () => ({}))
  on('session.id', () => ({ value: world.sessionId }))
  on('skill.prompt', ($, e) => ({ text: e.text }))
  on('agent.offer', () => ({ isOffered: true }))
  // the probe of the model main runs on: every model answers unless a test says not
  on('model.complete', async (_$, e) => {
    world.completions.push(e.model)
    return { value: (await world.complete(e.model)) as string }
  })
  installWorld(on, world)
  if (tokens !== null) usageOf(on, tokens)
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  await $.session.start({ cwd: '/tmp', surface: null, isInteractive: false })
  return clock
}

/** Runs `/route <args>` as the user would type it. */
async function route($: Engine, args: string): Promise<string> {
  const out = await $.command.run({
    command: 'route',
    args,
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 80 },
  })
  return out.text ?? ''
}

/** The `main:` line of `show`: the phases listing holds every id and level. */
function mainLine(text: string): string {
  return text.split('\n').find(l => l.startsWith('main:')) ?? ''
}

const spawnInput = (model?: string) => ({
  tool_use_id: 't1',
  prompt: 'x',
  description: 'd',
  subagentType: 'Explore',
  provider: { plugin: 'engine', tier: 'core' as const },
  parentModel: 'claude-fable-5-1',
  background: false,
  fork: false,
  ...(model === undefined ? {} : { model }),
})

test('route tool with phase orchestrate sets medium on main', async (
  $, on) => {
  await boot($, on)
  const out = await $.tool.call({
    tool: 'mcp__model-router__route',
    phase: 'orchestrate',
  })
  expect(out).toHaveProperty('result')
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('model orchestrate')
  expect(line).toContain('effort medium')
})

test('/route clear drops the route', async ($, on) => {
  await boot($, on)
  await $.tool.call({ tool: 'mcp__model-router__route', phase: 'plan' })
  expect(mainLine(await route($, 'show'))).toContain('model plan')
  await route($, 'clear')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('/route bogus names the phases', async ($, on) => {
  await boot($, on)
  const text = await route($, 'bogus')
  expect(text).toContain('unknown')
  for (const phase of ['plan', 'judge', 'explore', 'mechanical']) {
    expect(text).toContain(phase)
  }
})

test('ultrathink in a prompt sets a max floor on main', async ($, on) => {
  on('prompt.submit', ($, e) => ({ text: e.text }))
  await boot($, on)
  await $.prompt.submit({
    text: 'ultrathink please',
    wait: false,
    origin: { kind: 'composer' },
  })
  expect(mainLine(await route($, 'show'))).toContain('floor max')
})

test('/route model: alias resolved, id passed, typo refused', async (
  $, on) => {
  await boot($, on)
  await route($, 'switch off')
  const alias = await route($, 'model=sonnet')
  expect(mainLine(alias)).toContain('asked claude-sonnet-5-5, keeps ')
  const id = await route($, 'model=claude-x-9')
  expect(mainLine(id)).toContain('claude-x-9')
  expect(await route($, 'model=sonet')).toContain('unknown')
})

test('Explore spawn gets the sonnet id; an explicit model wins', async (
  $, on) => {
  const seen: (string | undefined)[] = []
  on('agent.spawn', ($, e) => {
    seen.push(e.model)
    return { model: e.model ?? e.parentModel, agentId: 'a1' }
  })
  await boot($, on)
  await $.agent.spawn(spawnInput())
  await $.agent.spawn(spawnInput('opus'))
  expect(seen).toEqual(['claude-sonnet-5-5', 'opus'])
})

test('a sticky /route wins over a model-declared route', async ($, on) => {
  await boot($, on)
  await route($, 'judge')
  const out = await $.tool.call({
    tool: 'mcp__model-router__route',
    phase: 'mechanical',
  })
  expect(JSON.stringify(out)).toContain('sticky')
  expect(mainLine(await route($, 'show'))).toContain('user judge')
})

test('/route off makes the route tool a no-op', async ($, on) => {
  await boot($, on)
  await route($, 'off')
  const out = await $.tool.call({
    tool: 'mcp__model-router__route',
    phase: 'plan',
  })
  expect(JSON.stringify(out)).toContain('off')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

type Seen = { model: string; effort: unknown }

/** A bottom turn.step hook that records what reaches the model. */
function recordSteps(on: On, seen: Seen[]): void {
  on('turn.step', async function* ($, e) {
    seen.push({ model: e.model, effort: e.effort })
    return {
      turnId: e.turnId,
      index: e.index,
      answer: '',
      toolUses: [],
      stopReason: 'end_turn' as const,
      usage: null,
    }
  })
}

const stepInput = (agentId?: string) => ({
  turnId: 'u1',
  index: 0,
  model: 'claude-fable-5-1',
  effort: 'low' as const,
  messageCount: 1,
  ...(agentId === undefined ? {} : { agentId }),
})

/** Streams one turn.step to its end; the hooks run as the chunks flow. */
async function runStep(
  $: Engine,
  input: TurnStepInput,
): Promise<void> {
  const stream = $.turn.step(input)
  for await (const _chunk of stream) {
    // chunks are not under test
  }
  await stream.result
}

test('the main step carries the routed effort, model untouched', async (
  $, on) => {
  const seen: Seen[] = []
  recordSteps(on, seen)
  await boot($, on)
  await $.tool.call({ tool: 'mcp__model-router__route', phase: 'plan' })
  await runStep($, stepInput())
  expect(seen).toEqual([{ model: 'claude-fable-5-1', effort: 'xhigh' }])
})

test('a tabled agent steps at its table effort', async ($, on) => {
  const seen: Seen[] = []
  recordSteps(on, seen)
  on('agent.spawn', ($, e) => ({
    model: e.model ?? e.parentModel,
    agentId: 'a1',
  }))
  await boot($, on)
  await $.agent.spawn(spawnInput())
  await runStep($, stepInput('a1'))
  expect(seen).toEqual([{ model: 'claude-fable-5-1', effort: 'medium' }])
})

test('/route from a non-composer origin is refused, state kept', async (
  $, on) => {
  await boot($, on)
  await route($, 'judge')
  const out = await $.command.run({
    command: 'route',
    args: 'mechanical',
    origin: { kind: 'plugin', name: 'x' },
    presentation: { isFullscreen: false, columns: 80 },
  })
  expect(out.text).toContain('user-only')
  expect(mainLine(await route($, 'show'))).toContain('user judge')
})

test('an in-agent route sets effort only, the model stays', async ($, on) => {
  const seen: Seen[] = []
  recordSteps(on, seen)
  await boot($, on)
  await $.tool.call({
    tool: 'mcp__model-router__route',
    phase: 'judge',
    agentId: 'a1',
  })
  await runStep($, { ...stepInput('a1'), model: 'claude-sonnet-5-5' })
  expect(seen).toEqual([{ model: 'claude-sonnet-5-5', effort: 'xhigh' }])
})

test('a rule only scans the first 4096 chars of a prompt', async ($, on) => {
  on('prompt.submit', ($, e) => ({ text: e.text }))
  await boot($, on)
  await $.prompt.submit({
    text: 'x'.repeat(5000) + ' ultrathink',
    wait: false,
    origin: { kind: 'composer' },
  })
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

// ---- user effort floor -------------------------------------------------

const ROUTE_TOOL = 'mcp__model-router__route'

/** A main (or agent) step as the engine would make it: engine effort high. */
const highStep = (agentId?: string): TurnStepInput => ({
  ...stepInput(agentId),
  effort: 'high' as const,
})

/** Types `ultrathink` in the composer, idle or over a running turn. */
async function ultrathink($: Engine, turnId?: string): Promise<void> {
  await $.prompt.submit({
    text: 'ultrathink please',
    wait: turnId !== undefined,
    origin: { kind: 'composer' },
    ...(turnId === undefined ? {} : { turnId }),
  })
}

/** Ends a main turn: the floor's life is bounded by this event. */
async function endTurn($: Engine): Promise<void> {
  await $.turn.complete({
    turnId: 'u1',
    answer: '',
    durationMs: 1,
    isAborted: false,
    reason: 'answer',
  })
}

/** One main step; returns the effort that reached the bottom hook. */
async function stepEffort($: Engine, seen: Seen[]): Promise<unknown> {
  await runStep($, highStep())
  return seen[seen.length - 1]?.effort
}

/** Boots with a bottom step recorder and prompt/turn hooks in place. */
async function bootFloor($: Engine, on: On): Promise<Seen[]> {
  const seen: Seen[] = []
  recordSteps(on, seen)
  on('prompt.submit', ($, e) => ({ text: e.text }))
  on('turn.complete', () => ({ text: '' }))
  on('tool.call', { tool: 'Skill' }, () => ({
    result: { success: true, commandName: 'other' },
  }))
  on('agent.spawn', ($, e) => ({
    model: e.model ?? e.parentModel,
    agentId: 'a1',
  }))
  await boot($, on)
  return seen
}

test('floor: ultrathink survives a model route', async ($, on) => {
  const seen = await bootFloor($, on)
  await ultrathink($)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(await stepEffort($, seen)).toBe('max')
})

test('floor: survives a skill load; an unrowed skill keeps the route', async (
  $, on) => {
  const seen = await bootFloor($, on)
  await ultrathink($)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  await $.tool.call({ tool: 'Skill', skill: 'other' })
  expect(await stepEffort($, seen)).toBe('max')
  expect(mainLine(await route($, 'show'))).toContain('model orchestrate')
})

test('floor: lifts a lower sticky, then ends with the turn', async (
  $, on) => {
  const seen = await bootFloor($, on)
  await route($, 'effort=low')
  await ultrathink($)
  expect(await stepEffort($, seen)).toBe('max')
  await endTurn($)
  expect(await stepEffort($, seen)).toBe('low')
})

test('floor: main only, an agent step is unaffected', async ($, on) => {
  const seen = await bootFloor($, on)
  await $.agent.spawn(spawnInput())
  await ultrathink($)
  await runStep($, highStep('a1'))
  expect(seen[0]?.effort).toBe('medium')
})

test('floor: /route clear removes it', async ($, on) => {
  const seen = await bootFloor($, on)
  await ultrathink($)
  expect(mainLine(await route($, 'show'))).toContain('floor max')
  await route($, 'clear')
  expect(await stepEffort($, seen)).toBe('high')
  expect(mainLine(await route($, 'show'))).not.toContain('floor')
})

test('floor: a mid-turn prompt applies now and is kept for the next', async (
  $, on) => {
  const seen = await bootFloor($, on)
  await ultrathink($, 'u1')
  expect(await stepEffort($, seen)).toBe('max')
  await endTurn($)
  expect(await stepEffort($, seen)).toBe('max')
  await endTurn($)
  expect(await stepEffort($, seen)).toBe('high')
})

test('floor: the route answer names the floor over a sticky', async (
  $, on) => {
  await bootFloor($, on)
  await route($, 'effort=low')
  await ultrathink($)
  const out = await $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })
  const text = JSON.stringify(out)
  expect(text).toContain('user floor max (prompt rule escalate)')
  expect(text).toContain('/route clear')
})

// `enabled: false` in ~/.claude/model-router.json has its own layers test;
// this one covers the shared off path through `/route off`.
test('floor: /route off keeps the floor from routing', async ($, on) => {
  const seen = await bootFloor($, on)
  await ultrathink($)
  await route($, 'off')
  expect(await stepEffort($, seen)).toBe('high')
  expect(mainLine(await route($, 'show'))).not.toContain('floor')
})

test('per axis: a model-only sticky keeps the turn route effort', async (
  $, on) => {
  const seen = await bootFloor($, on)
  await route($, 'model=sonnet')
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(await stepEffort($, seen)).toBe('medium')
})

// The config-driven `offConfig` is re-applied in the same rebuild; only the
// session-only off is reached here (the config-driven one has its own test).
test('session.end rebuild drops a session-only /route off', async (
  $, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  await boot($, on)
  await route($, 'off')
  await $.session.end({
    reason: 'clear',
    sessionId: 's1',
    resume: { id: 's1' },
  })
  expect(await route($, 'show')).toContain('router: on')
})

// The override breaks after the first load: the previous cfg must stay.
test('reload with an unreadable override keeps the previous config', async (
  $, on) => {
  const world = newWorld({ home: {} })
  await boot($, on, FABLE, 1000, world)
  await route($, 'switch off')
  world.files.set(HOME_FILE, '{nope')
  const out = await route($, 'reload')
  expect(out).toContain('switch: off')
  expect(await route($, 'show')).toContain('switch: off')
})

// ---- tiers, breaker, derived phases -------------------------------------

type Rig = { seen: Seen[]; clock: MockClock; specs: (string | undefined)[] }

type Failure = 'rate_limit' | 'overloaded' | 'invalid_request'

/** Bottom hooks for a routed run, then the boot; `specs` records spawns. */
async function bootRig(
  $: Engine,
  on: On,
  model: string = FABLE,
  tokens: number | null = 1000,
  world: World = newWorld(),
): Promise<Rig> {
  const seen: Seen[] = []
  const specs: (string | undefined)[] = []
  recordSteps(on, seen)
  on('prompt.submit', ($, e) => ({ text: e.text }))
  on('turn.complete', () => ({ text: '' }))
  on('agent.spawn', ($, e) => {
    specs.push(e.model)
    return { model: e.model ?? e.parentModel, agentId: 'a1' }
  })
  on('tool.call', { tool: 'Agent' }, () => ({
    result: {
      status: 'async_launched' as const,
      agentId: 'a1',
      description: 'd',
      prompt: 'p',
      outputFile: '/tmp/o',
    },
  }))
  const clock = await boot($, on, model, tokens, world)
  return { seen, clock, specs }
}

/** One main step on `model`; returns what reached the bottom hook. */
async function stepOn($: Engine, rig: Rig, model: string): Promise<Seen> {
  await runStep($, { ...highStep(), model })
  return rig.seen[rig.seen.length - 1] ?? { model: '', effort: undefined }
}

const failWith = ($: Engine, error: Failure, agentId?: string) =>
  $.classic.StopFailure({
    error,
    ...(agentId === undefined ? {} : { agent_id: agentId }),
  })

const switchTo = (
  $: Engine,
  from: string,
  to: string,
  source: 'command' | 'auto' | 'picker',
  cache_ttl: '5m' | '1h' = '5m',
  agent_id?: string,
) => $.classic.PostModelSwitch({
  from_model: from,
  to_model: to,
  requested_model: null,
  source,
  context_tokens: 0,
  prompt_cache_warm: false,
  cache_ttl,
  ...(agent_id === undefined ? {} : { agent_id }),
  estimated_cache_write_usd: 0,
  pricing: 'catalog',
})

const planRoute = ($: Engine) =>
  $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })

/** One bottom `session.usage` over a count `set` changes (never a second). */
function usageVar(on: On, initial: number): { set: (n: number) => void } {
  let tokens = initial
  on('session.usage', () => ({
    value: {
      startedAt: 0,
      context: { window: 1000000, tokens },
      rateLimits: [],
    },
  }))
  return { set: n => { tokens = n } }
}

/** A bottom `session.usage` answering a context of `tokens`. */
function usageOf(on: On, tokens: number): void {
  usageVar(on, tokens)
}

/** bootRig with a context size the test changes through `usage.set`. */
async function bootRigVar(
  $: Engine,
  on: On,
  model: string = FABLE,
  tokens = 1000,
  world: World = newWorld(),
) {
  const usage = usageVar(on, tokens)
  return { rig: await bootRig($, on, model, null, world), usage }
}

test('tier: a plan route upgrades a haiku session to fable xhigh', async (
  $, on) => {
  const rig = await bootRig($, on, HAIKU)
  await planRoute($)
  expect(await stepOn($, rig, HAIKU)).toEqual({
    model: FABLE,
    effort: 'xhigh',
  })
})

test('tier: show prints the resolved id of each phase and a down line', async (
  $, on) => {
  await bootRig($, on)
  const text = await route($, 'show')
  expect(text).toContain('plan=best→claude-fable-5-1/xhigh')
  expect(text).toContain('judge=big→claude-opus-5-5/xhigh')
  expect(text).toContain('down: none')
})

test('tier: an upgrade is skipped above the context cap', async ($, on) => {
  const rig = await bootRig($, on, SONNET, 300000)
  await planRoute($)
  expect(await stepOn($, rig, SONNET)).toEqual({
    model: SONNET,
    effort: 'xhigh',
  })
})

test('cap: unknown usage blocks the upgrade', async ($, on) => {
  const rig = await bootRig($, on, HAIKU, null)
  await planRoute($)
  expect((await stepOn($, rig, HAIKU)).model).toBe(HAIKU)
})

test('cap: a down model leaves for a better wanted only under the cap', async (
  $, on) => {
  const rig = await bootRig($, on, OPUS, 300000)
  await planRoute($)
  await stepOn($, rig, OPUS)
  await failWith($, 'rate_limit')
  expect((await stepOn($, rig, OPUS)).model).toBe(SONNET)
})

test('breaker: model_not_found on a non-table id marks nothing', async (
  $, on) => {
  const rig = await bootRig($, on)
  await planRoute($)
  await stepOn($, rig, 'claude-zz-9')
  await $.classic.StopFailure({ error: 'model_not_found' })
  expect(await route($, 'show')).toContain('down: none')
})

test('downgrade: mechanical on fable keeps the model, switch off', async (
  $, on) => {
  const rig = await bootRig($, on)
  await route($, 'switch off')
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  expect(await stepOn($, rig, FABLE)).toEqual({ model: FABLE, effort: 'low' })
})

test('cap: a downgrade under the cold-read cap moves main', async (
  $, on) => {
  const rig = await bootRig($, on)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  const sent = await stepOn($, rig, FABLE)
  expect(sent.model).toBe(HAIKU)
  expect(sent.effort).toBe('low')
})

const HAIKU_4 = 'claude-haiku-4-5-20251001'
const HAIKU_4_HOME = { home: { models: { haiku: HAIKU_4 } } }

test('haiku 5: /route show prints the effort, not "takes none"', async (
  $, on) => {
  await bootRig($, on)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('effort low')
  expect(line).not.toContain('takes none')
})

test('haiku 4: a routed step keeps no effort, show says so', async (
  $, on) => {
  const rig = await bootRig($, on, FABLE, 1000, newWorld(HAIKU_4_HOME))
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  const sent = await stepOn($, rig, FABLE)
  expect(sent.model).toBe(HAIKU_4)
  expect(sent.effort).toBeUndefined()
  expect(mainLine(await route($, 'show'))).toContain('haiku 4 takes none')
})

test('haiku 5: an unrouted step passes the engine effort', async (
  $, on) => {
  const rig = await bootRig($, on, HAIKU)
  expect(await stepOn($, rig, HAIKU)).toEqual({
    model: HAIKU,
    effort: 'high',
  })
})

test('haiku 5: a plan keyword on a haiku session is xhigh', async (
  $, on) => {
  const rig = await bootRig($, on, HAIKU)
  await $.prompt.submit({
    text: 'plan the migration',
    wait: false,
    origin: { kind: 'composer' },
  })
  expect(await stepOn($, rig, HAIKU)).toEqual({
    model: HAIKU,
    effort: 'xhigh',
  })
})

test('fallback: a rate limit on fable moves plan to opus max', async (
  $, on) => {
  const rig = await bootRig($, on)
  await planRoute($)
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  await failWith($, 'rate_limit')
  // opus stands in for fable: plan's xhigh goes one notch up
  expect(await stepOn($, rig, FABLE)).toEqual({ model: OPUS, effort: 'max' })
  expect(await route($, 'show')).toContain('claude-fable-5-1 for 15 min')
  await route($, 'reload')
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
})

test('breaker: an invalid_request or a turn error never marks down', async (
  $, on) => {
  const rig = await bootRig($, on)
  await planRoute($)
  await stepOn($, rig, FABLE)
  await failWith($, 'invalid_request')
  await $.turn.complete({
    turnId: 'u1',
    answer: '',
    durationMs: 1,
    isAborted: false,
    reason: 'error',
  })
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  expect(await route($, 'show')).toContain('down: none')
})

test('breaker: the hold lapses with the clock, a second one doubles', async (
  $, on) => {
  const rig = await bootRig($, on)
  await planRoute($)
  await stepOn($, rig, FABLE)
  await failWith($, 'overloaded')
  await rig.clock.advance(15 * 60000)
  expect(await route($, 'show')).toContain('down: none')
  await endTurn($)
  await planRoute($)
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  await failWith($, 'overloaded')
  expect(await route($, 'show')).toContain('claude-fable-5-1 for 30 min')
})

test('breaker: a /model command clears the mark of its target', async (
  $, on) => {
  const rig = await bootRig($, on)
  await planRoute($)
  await stepOn($, rig, FABLE)
  await failWith($, 'rate_limit')
  expect(await route($, 'show')).toContain('claude-fable-5-1 for')
  await switchTo($, OPUS, FABLE, 'command')
  expect(await route($, 'show')).toContain('down: none')
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
})

test('breaker: model_not_found holds until the reload', async ($, on) => {
  const rig = await bootRig($, on)
  await planRoute($)
  await stepOn($, rig, FABLE)
  await $.classic.StopFailure({ error: 'model_not_found' })
  await rig.clock.advance(24 * 3600000)
  expect(await route($, 'show')).toContain('until reload (model_not_found)')
})

test('engine fallback: an auto switch marks the model it left, once', async (
  $, on) => {
  const rig = await bootRig($, on)
  await switchTo($, FABLE, OPUS, 'auto')
  const first = await route($, 'show')
  expect(first).toContain('claude-fable-5-1 for 15 min (engine fallback)')
  await planRoute($)
  expect((await stepOn($, rig, OPUS)).model).toBe(OPUS)
  await rig.clock.advance(60000)
  await switchTo($, FABLE, OPUS, 'auto')
  expect(await route($, 'show')).toContain('claude-fable-5-1 for 14 min')
})

test('unknown: a session model absent from the table is never switched', async (
  $, on) => {
  const rig = await bootRig($, on)
  await planRoute($)
  expect((await stepOn($, rig, 'claude-zz-9')).model).toBe('claude-zz-9')
})

test('unknown: the haiku alias id is in the table, a route moves it', async (
  $, on) => {
  const logs = recordLogs(on)
  const rig = await bootRig($, on, HAIKU)
  await planRoute($)
  expect((await stepOn($, rig, HAIKU)).model).toBe(FABLE)
  expect(logsWith(logs, 'unknown to the models table')).toBe(0)
})

test('spawn: Explore goes to opus while sonnet is down', async ($, on) => {
  const rig = await bootRig($, on)
  await $.agent.spawn(spawnInput())
  await failWith($, 'overloaded', 'a1')
  await $.agent.spawn(spawnInput())
  expect(rig.specs).toEqual([SONNET, OPUS])
})

/** Types a plain prompt, idle, in the composer. */
const typed = ($: Engine, text: string) => $.prompt.submit({
  text,
  wait: false,
  origin: { kind: 'composer' },
})

const dispatch = ($: Engine) =>
  $.tool.call({ tool: 'Agent', description: 'd', prompt: 'p' })

const agentEnds = ($: Engine) => $.turn.complete({
  turnId: 'a1',
  agentId: 'a1',
  answer: '',
  durationMs: 1,
  isAborted: false,
  reason: 'answer',
})

test('derived: a dispatch pushes orchestrate, the end pops the prompt', async (
  $, on) => {
  await bootRig($, on)
  await typed($, 'planifie la migration')
  expect(mainLine(await route($, 'show'))).toContain('prompt plan')
  await dispatch($)
  expect(mainLine(await route($, 'show'))).toContain('derived orchestrate')
  await agentEnds($)
  expect(mainLine(await route($, 'show'))).toContain('prompt plan')
})

test('derived: a route declared after the dispatch survives the pop', async (
  $, on) => {
  await bootRig($, on)
  await typed($, 'planifie la migration')
  await dispatch($)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect' })
  await agentEnds($)
  expect(mainLine(await route($, 'show'))).toContain('model reflect')
})

test('default rule: planifie sets plan, a later route overrides', async (
  $, on) => {
  // a keyword sets effort only: the fable session keeps its model
  const rig = await bootRig($, on)
  await typed($, 'planifie la migration')
  expect(await stepOn($, rig, FABLE)).toEqual({ model: FABLE, effort: 'xhigh' })
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'implement' })
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('model implement')
  expect(line).not.toContain('prompt')
})

test('default rule: a typed slash command gets no default rule', async (
  $, on) => {
  await bootRig($, on)
  await typed($, '/analyze pourquoi ça plante')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('per axis: a model-less sticky never hides a turn route tier', async (
  $, on) => {
  const rig = await bootRig($, on, HAIKU)
  await route($, 'effort=low')
  await planRoute($)
  expect(await stepOn($, rig, HAIKU)).toEqual({ model: FABLE, effort: 'low' })
})

// ---- texts follow the decision, from the turn's model ------------------

test('text: effort-only route on a down model says fallback', async (
  $, on) => {
  const rig = await bootRig($, on)
  await stepOn($, rig, FABLE)
  await failWith($, 'rate_limit')
  const out = await $.tool.call({ tool: ROUTE_TOOL, effort: 'low' })
  expect(JSON.stringify(out)).toContain(`model ${OPUS} (fallback)`)
})

test('text: /route effort= on a down model names the fallback', async (
  $, on) => {
  const rig = await bootRig($, on)
  await stepOn($, rig, FABLE)
  await failWith($, 'rate_limit')
  await route($, 'effort=low')
  expect(mainLine(await route($, 'show'))).toContain(`${OPUS} (fallback)`)
})

test('text: show names the session model after the turn ended', async (
  $, on) => {
  const rig = await bootRig($, on, HAIKU)
  await planRoute($)
  expect((await stepOn($, rig, HAIKU)).model).toBe(FABLE)
  await endTurn($)
  await route($, 'mechanical')
  const line = mainLine(await route($, 'show'))
  expect(line).toContain(`model ${HAIKU}`)
  expect(line).not.toContain(FABLE)
})

test('text: show reflects a /model command to opus', async ($, on) => {
  const rig = await bootRig($, on)
  await route($, 'switch off')
  await stepOn($, rig, FABLE)
  await switchTo($, FABLE, OPUS, 'command')
  await route($, 'mechanical')
  const line = mainLine(await route($, 'show'))
  expect(line).toContain(OPUS)
  expect(line).not.toContain(FABLE)
})

test('text: an unknown session model prints "session model"', async (
  $, on) => {
  await bootRig($, on, 'mystery-model')
  await route($, 'plan')
  expect(mainLine(await route($, 'show'))).toContain('keeps session model')
})

test('text: show names no model move for an ultrathink floor', async (
  $, on) => {
  // a floor names no model any more, so show has no upgrade to report
  await bootRig($, on, OPUS)
  await ultrathink($)
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('floor max')
  expect(line).not.toContain('(upgrade)')
  expect(line).not.toContain(FABLE)
})

// ---- wave 2: skill rows, run slot, agent rows ---------------------------

const skillPrompt = ($: Engine, skill: string) =>
  $.skill.prompt({ skill, text: 'x' })

const loadSkill = ($: Engine, skill: string, agentId?: string) =>
  $.tool.call({
    tool: 'Skill',
    skill,
    ...(agentId === undefined ? {} : { agentId }),
  })

/** bootRig plus a bottom Skill tool, so a model-loaded skill goes through. */
async function bootRun(
  $: Engine,
  on: On,
  model: string = FABLE,
  world: World = newWorld(),
  tokens: number | null = 1000,
) {
  on('tool.call', { tool: 'Skill' }, () => ({
    result: { success: true, commandName: 'bottom' },
  }))
  return bootRig($, on, model, tokens, world)
}

const spawnOf = (agent: string, extra: object = {}) =>
  ({ ...spawnInput(), subagentType: agent, ...extra })

const offerOf = (
  $: Engine,
  agent: string,
  source: string,
  description = 'd',
) =>
  $.agent.offer({
    agent,
    description,
    source,
    provider: { plugin: 'engine', tier: 'core' },
  })

/**
 * A ui.log recorder. The kit refuses a bottom hook for a void event, so the
 * hook sits on top and swallows the missing implementation below it.
 */
function recordLogs(on: On): string[] {
  const lines: string[] = []
  on('ui.log', async ($, e, next) => {
    lines.push(e.text)
    try {
      await next(e)
    } catch {
      // nothing implements ui.log below the recorder in the kit
    }
  })
  return lines
}

test('typed /feat routes main to its row, best tier', async ($, on) => {
  await bootRun($, on)
  await typed($, '/feat add a thing')
  await skillPrompt($, 'feat')
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('skill reflect')
  expect(line).toContain('effort high')
  expect(line).toContain('[tier best]')
})

test('typed slash: a foreign origin arms nothing, fallback refused', async (
  $, on) => {
  await bootRun($, on)
  await $.prompt.submit({
    text: '/feat x',
    wait: false,
    origin: { kind: 'channel', server: 'slack' },
  })
  await skillPrompt($, 'feat')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('typed slash: a preload in a live sub-agent leaves main alone', async (
  $, on) => {
  await bootRun($, on)
  await typed($, 'hello')
  await $.agent.spawn(spawnOf('feater'))
  await skillPrompt($, 'feat')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('typed slash: no live loop and an allowed origin still routes', async (
  $, on) => {
  await bootRun($, on)
  await typed($, 'hello')
  await skillPrompt($, 'feat')
  expect(mainLine(await route($, 'show'))).toContain('skill reflect')
})

test('typed slash: an sdk origin arms the marker', async ($, on) => {
  await bootRun($, on)
  await $.prompt.submit({
    text: '/status',
    wait: false,
    origin: { kind: 'sdk' },
  })
  await $.agent.spawn(spawnOf('feater'))
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('skill mechanical')
})

test('typed slash: a mid-turn /status waits for the turn end', async (
  $, on) => {
  await bootRun($, on)
  await $.prompt.submit({
    text: '/status',
    wait: true,
    origin: { kind: 'composer' },
    turnId: 'u1',
  })
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
  await endTurn($)
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('skill mechanical')
})

test('skill without a row keeps the route; a rowed one replaces it', async (
  $, on) => {
  await bootRun($, on)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })
  await loadSkill($, 'find-docs')
  expect(mainLine(await route($, 'show'))).toContain('model plan')
  await loadSkill($, 'gitflow')
  expect(mainLine(await route($, 'show'))).toContain('skill implement')
})

test('run slot: survives route calls and the turn end', async ($, on) => {
  await bootRun($, on)
  await loadSkill($, 'feat')
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  await endTurn($)
  expect(mainLine(await route($, 'show'))).toContain('run reflect')
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })
  await endTurn($)
  expect(mainLine(await route($, 'show'))).toContain('run reflect')
})

test('run slot: a model-loaded helper skill moves effort only', async (
  $, on) => {
  const rig = await bootRun($, on)
  await loadSkill($, 'feat')
  await loadSkill($, 'using-git-worktrees')
  expect(mainLine(await route($, 'show'))).toContain('skill mechanical')
  expect(await stepOn($, rig, FABLE)).toEqual({ model: FABLE, effort: 'low' })
  await endTurn($)
  expect(mainLine(await route($, 'show'))).toContain('run reflect')
})

test('run slot: a typed non-best skill drops it', async ($, on) => {
  await bootRun($, on)
  await loadSkill($, 'feat')
  await endTurn($)
  await typed($, '/status')
  await skillPrompt($, 'status')
  await endTurn($)
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('run slot: /route clear and /route off drop it', async ($, on) => {
  await bootRun($, on)
  await loadSkill($, 'feat')
  expect(await route($, 'clear')).toContain('run slot dropped')
  await endTurn($)
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
  await loadSkill($, 'feat')
  await route($, 'off')
  await route($, 'on')
  await endTurn($)
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('run slot: a user /model switch drops it, an auto one does not', async (
  $, on) => {
  await bootRun($, on)
  await loadSkill($, 'feat')
  await endTurn($)
  await switchTo($, FABLE, OPUS, 'auto')
  expect(mainLine(await route($, 'show'))).toContain('run reflect')
  await switchTo($, FABLE, OPUS, 'command')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('run slot: a Skill call inside a sub-agent never touches it', async (
  $, on) => {
  await bootRun($, on)
  await loadSkill($, 'feat', 'a1')
  await endTurn($)
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('run slot: route(clear) clears the turn and names the run', async (
  $, on) => {
  await bootRun($, on)
  await loadSkill($, 'feat')
  const out = await $.tool.call({ tool: ROUTE_TOOL, clear: true })
  expect(JSON.stringify(out)).toContain('run reflect still holds')
})

test('route answer names the id even with a floor in force', async (
  $, on) => {
  await bootRun($, on)
  await ultrathink($)
  const out = await $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })
  const text = JSON.stringify(out)
  expect(text).toContain(`model ${FABLE}`)
  expect(text).toContain('user floor max')
})

test('agent row: feater spawns on sonnet and steps at medium', async (
  $, on) => {
  const rig = await bootRun($, on)
  const out = await $.agent.spawn(spawnOf('feater'))
  expect(rig.specs).toEqual([SONNET])
  expect(out.model).toBe(SONNET)
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(rig.seen[rig.seen.length - 1]).toEqual({
    model: SONNET,
    effort: 'medium',
  })
})

/** Spawn feater, load a skill inside it, return the effort of its step. */
async function effortAfterSkill($: Engine, on: On, skill: string) {
  const rig = await bootRun($, on)
  await $.agent.spawn(spawnOf('feater'))
  await loadSkill($, skill, 'a1')
  await runStep($, { ...highStep('a1'), model: SONNET })
  return rig.seen[rig.seen.length - 1].effort
}

test('agent skill: an unrowed one leaves the loop effort', async ($, on) => {
  expect(await effortAfterSkill($, on, 'find-docs')).toBe('medium')
})

test('agent skill: a rowed one writes the loop effort', async ($, on) => {
  expect(await effortAfterSkill($, on, 'status')).toBe('low')
})

test('agent row: judge moves up to fable when opus is down', async (
  $, on) => {
  const rig = await bootRun($, on)
  await switchTo($, OPUS, SONNET, 'auto')
  await $.agent.spawn(spawnOf('plan-challenger'))
  expect(rig.specs).toEqual([FABLE])
})

test('agent row: opus and fable down, no write and one log line', async (
  $, on) => {
  const logs = recordLogs(on)
  const rig = await bootRun($, on)
  await switchTo($, OPUS, SONNET, 'auto')
  await switchTo($, FABLE, SONNET, 'auto')
  await $.agent.spawn(spawnOf('plan-challenger'))
  await $.agent.spawn(spawnOf('plan-challenger'))
  expect(rig.specs).toEqual([undefined, undefined])
  const down = logs.filter(l => l.includes('frontmatter model kept'))
  expect(down).toEqual([
    'model-router: plan-challenger tier big down, frontmatter model kept',
  ])
})

const auditWorld = () => newWorld({
  edit: f => { (f.agents as Rec)['security-auditor'] = 'audit' },
})

test('audit row: fable down, no write, frontmatter runs', async (
  $, on) => {
  const logs = recordLogs(on)
  const rig = await bootRun($, on, FABLE, auditWorld())
  await switchTo($, FABLE, SONNET, 'auto')
  await $.agent.spawn(spawnOf('security-auditor'))
  expect(rig.specs).toEqual([undefined])
  const down = logs.filter(l => l.includes('frontmatter model kept'))
  expect(down).toEqual([
    'model-router: security-auditor tier best down, frontmatter model kept',
  ])
})

test('audit row: first spawn dies on fable, the retry lands on the floor',
  async ($, on) => {
    const rig = await bootRun($, on, FABLE, auditWorld())
    await $.agent.spawn(spawnOf('security-auditor'))
    await failWith($, 'rate_limit', 'a1')
    await $.agent.spawn(spawnOf('security-auditor'))
    expect(rig.specs).toEqual([FABLE, undefined])
  })

test('agent row: explicit model, explicit effort and fork win', async (
  $, on) => {
  const rig = await bootRun($, on)
  await $.agent.spawn(spawnOf('feater', { model: 'opus' }))
  await $.agent.spawn(spawnOf('feater', { fork: true }))
  expect(rig.specs).toEqual(['opus', undefined])
  await $.tool.call({
    tool: 'Agent',
    description: 'd',
    prompt: 'p',
    effort: 'low',
    tool_use_id: 't1',
  })
  await $.agent.spawn(spawnOf('feater'))
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(rig.seen[rig.seen.length - 1]?.effort).toBe('high')
})

test('agent row: a project definition keeps its own model', async ($, on) => {
  const rig = await bootRun($, on)
  await offerOf($, 'verifier', 'projectSettings')
  await offerOf($, 'feater', 'userSettings')
  await $.agent.spawn(spawnOf('verifier'))
  await $.agent.spawn(spawnOf('feater'))
  expect(rig.specs).toEqual([undefined, SONNET])
})

test('agent row: an override null drops the row', async ($, on) => {
  const world = newWorld({ home: { agents: { verifier: null } } })
  const rig = await bootRun($, on, FABLE, world)
  await $.agent.spawn(spawnOf('verifier'))
  await $.agent.spawn(spawnOf('feater'))
  expect(rig.specs).toEqual([undefined, SONNET])
})

test('show lists the write and apply phases', async ($, on) => {
  await bootRun($, on)
  const text = await route($, 'show')
  expect(text).toContain('apply=work→claude-sonnet-5-5/low')
  expect(text).toContain('write=work→claude-sonnet-5-5/high')
})

// ---- wave 2: typed-slash origins, spawning counter, spawn exclusions ----

/** A promise the test settles by hand, to hold a hook in flight. */
function deferred() {
  let release: () => void = () => {}
  const gate = new Promise<void>(r => { release = r })
  return { gate, release }
}

test('typed slash: an in-flight spawn refuses the fallback', async (
  $, on) => {
  const hold = deferred()
  const entered = deferred()
  on('prompt.submit', ($, e) => ({ text: e.text }))
  on('agent.spawn', async ($, e) => {
    entered.release()
    await hold.gate
    return { model: e.model ?? e.parentModel, agentId: 'a1' }
  })
  await boot($, on)
  await typed($, 'hello')
  const spawned = $.agent.spawn(spawnOf('feater'))
  await entered.gate
  await skillPrompt($, 'feat')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
  hold.release()
  await spawned
})

test('typed slash: a bridge origin arms the marker', async ($, on) => {
  await bootRun($, on)
  await $.prompt.submit({
    text: '/feat x',
    wait: false,
    origin: { kind: 'bridge' },
  })
  await $.agent.spawn(spawnOf('feater'))
  await skillPrompt($, 'feat')
  expect(mainLine(await route($, 'show'))).toContain('skill reflect')
})

test('typed slash: a promoted mid-turn marker routes past a live loop', async (
  $, on) => {
  await bootRun($, on)
  await $.agent.spawn(spawnOf('feater'))
  await $.prompt.submit({
    text: '/status',
    wait: true,
    origin: { kind: 'composer' },
    turnId: 'u1',
  })
  await endTurn($)
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('skill mechanical')
})

test('agent row: any provider plugin applies, a local definition not', async (
  $, on) => {
  const rig = await bootRun($, on)
  const provider = { plugin: 'some-plugin', tier: 'core' as const }
  await $.agent.spawn(spawnOf('feater', { provider }))
  await offerOf($, 'verifier', 'localSettings')
  await $.agent.spawn(spawnOf('verifier', { provider }))
  expect(rig.specs).toEqual([SONNET, undefined])
})

test('agent row: a workflow spawn is untouched, model and effort', async (
  $, on) => {
  const rig = await bootRun($, on)
  await $.agent.spawn(spawnOf('feater', { workflow: {} }))
  expect(rig.specs).toEqual([undefined])
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(rig.seen[rig.seen.length - 1]?.effort).toBe('high')
})

test('typed slash: the marker binds to its skill name only', async (
  $, on) => {
  await bootRun($, on)
  await typed($, '/status')
  await $.agent.spawn(spawnOf('feater'))
  await skillPrompt($, 'feat')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('typed slash: the marker is one-shot', async ($, on) => {
  await bootRun($, on)
  await typed($, '/status')
  await $.agent.spawn(spawnOf('feater'))
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('skill mechanical')
  await route($, 'clear')
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('skill.prompt nested in a Skill call leaves the run slot', async (
  $, on) => {
  on('tool.call', { tool: 'Skill' }, async (_api, e) => {
    await skillPrompt($, 'status')
    return { result: { success: true, commandName: String(e.skill) } }
  })
  await bootRig($, on, FABLE)
  await typed($, '/status')
  await loadSkill($, 'feat')
  await endTurn($)
  expect(mainLine(await route($, 'show'))).toContain('run reflect')
})

/** Submits a prompt from `kind` over a running turn (mid-turn). */
const queued = ($: Engine, kind: string, text: string) =>
  $.prompt.submit({
    text,
    wait: true,
    origin: { kind },
    turnId: 'u1',
  })

test('idle fallback: a mid-turn foreign prompt never arms it', async (
  $, on) => {
  await bootRun($, on)
  await queued($, 'channel', 'hello')
  await endTurn($)
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('idle fallback: a mid-turn composer prompt promotes the allowance', async (
  $, on) => {
  await bootRun($, on)
  await $.prompt.submit({
    text: 'hello',
    wait: false,
    origin: { kind: 'channel' },
  })
  await queued($, 'composer', 'hello')
  await endTurn($)
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('skill mechanical')
})

test('spawning: a finished spawn no longer counts as a live loop', async (
  $, on) => {
  await bootRun($, on)
  await $.agent.spawn(spawnOf('feater'))
  await agentEnds($)
  await typed($, 'hello')
  await skillPrompt($, 'status')
  expect(mainLine(await route($, 'show'))).toContain('skill mechanical')
})

// ---- wave 3-A: routing.json layers ---------------------------------------

/** A ui.toast recorder, same shape as recordLogs. */
function recordToasts(on: On): string[] {
  const lines: string[] = []
  on('ui.toast', async ($, e, next) => {
    lines.push(e.text)
    try {
      await next(e)
    } catch {
      // nothing implements ui.toast below the recorder in the kit
    }
  })
  return lines
}

const projectRows = (agents: Rec, key: string = KEY) => (file: Rec) => {
  file.projects = { [key]: { agents } }
}

/** The model a `feater` spawn reaches the bottom hook with. */
async function featerModel($: Engine, rig: Rig): Promise<string | undefined> {
  await $.agent.spawn(spawnOf('feater'))
  return rig.specs[rig.specs.length - 1]
}

test('layers: routing.json rows route a spawn', async ($, on) => {
  const rig = await bootRun($, on)
  expect(await featerModel($, rig)).toBe(SONNET)
})

test('layers: a projects[key] row beats the routing.json row', async (
  $, on) => {
  const w = newWorld({ edit: projectRows({ feater: 'judge' }) })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(OPUS)
})

test('layers: another repo key leaves the routing.json row', async (
  $, on) => {
  const w = newWorld({ edit: projectRows({ feater: 'judge' }, 'other/repo') })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(SONNET)
})

test('layers: the machine override beats the project row', async (
  $, on) => {
  const w = newWorld({
    edit: projectRows({ feater: 'judge' }),
    home: { agents: { feater: 'mechanical' } },
  })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(HAIKU)
})

test('layers: a .claude/model-router.json in the project is never read', async (
  $, on) => {
  const w = newWorld()
  const tree = `${ROOT}/.claude/model-router.json`
  w.files.set(tree, '{"agents":{"feater":"judge"}}')
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(SONNET)
  expect(w.reads).not.toContain(tree)
})

test('layers: the machine override\'s ask:false is honored', async (
  $, on) => {
  const w = newWorld({ ask: true, home: { ask: false } })
  await bootRun($, on, FABLE, w)
  await typed($, '/feat x')
  await skillPrompt($, 'feat')
  expect(w.asked).toEqual([])
})

test('layers: a row on a phase the table lacks is ignored, logged', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld({
    edit: f => { (f.agents as Rec).feater = 'ghost' },
  })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBeUndefined()
  expect(logs.join('\n')).toContain('config agents.feater ignored')
})

test('layers: an invalid routing.json phase falls back by name', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld({
    edit: f => { f.phases = { reflect: { tier: 'nope' } } },
  })
  await bootRun($, on, FABLE, w)
  const text = await route($, 'show')
  expect(text).toContain('reflect=best→claude-fable-5-1/high')
  expect(logs.join('\n')).toContain('config phases.reflect ignored')
})

test('layers: a valid routing.json phase replaces the default', async (
  $, on) => {
  const w = newWorld({
    edit: f => { f.phases = { reflect: { tier: 'work', effort: 'low' } } },
  })
  await bootRun($, on, FABLE, w)
  const text = await route($, 'show')
  expect(text).toContain('reflect=work→claude-sonnet-5-5/low')
})

test('layers: a routing.json phase gone missing falls back, logged', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld({ edit: f => { delete (f.phases as Rec).reflect } })
  await bootRun($, on, FABLE, w)
  expect(await route($, 'show')).toContain('reflect=best→claude-fable-5-1/high')
  expect(logs.filter(l => l.includes('lacks phases'))).toEqual([
    'model-router: routing.json lacks phases reflect; code defaults kept',
  ])
})

test('layers: a row may name a phase only the override defines', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld({
    edit: f => {
      ;(f.skills as Rec).feat = 'custom'
      projectRows({ feater: 'custom' })(f)
    },
    home: { phases: { custom: { tier: 'cheap', effort: 'low' } } },
  })
  const rig = await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(await mainNow($)).toContain('skill custom')
  expect(await featerModel($, rig)).toBe(HAIKU)
  expect(logs.join('\n')).not.toContain('ignored')
})

test('layers: show names routing.json as the config', async ($, on) => {
  await bootRun($, on)
  expect(await route($, 'show')).toContain('config: routing.json')
})

test('layers: a broken override at first load turns the router off', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld({ home: 'broken' })
  await bootRun($, on, FABLE, w)
  expect(logs.join('\n')).toContain('model-router.json unreadable')
  expect(logs.join('\n')).toContain('router off (fail closed)')
  expect(await route($, 'show')).toContain('router: off (config)')
})

test('layers: an override that is not a regular file fails closed', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld({ home: { verbose: true } })
  w.kinds.set(HOME_FILE, 'other')
  await bootRun($, on, FABLE, w)
  expect(logs.join('\n')).toContain('model-router.json is not a regular file')
  expect(await route($, 'show')).toContain('router: off (config)')
})

test('layers: prototype and malformed keys are dropped, named safely', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld()
  w.files.set(HOME_FILE, '{"models":{"__proto__":"claude-x-1",' +
    '"constructor":"claude-x-1","bad key\\n":"claude-x-1","mini":"claude-x-1"}}')
  await bootRun($, on, FABLE, w)
  expect(logs).toContain('model-router: config models.constructor ignored')
  expect(logs.filter(l => l === 'model-router: config models.<key> ignored'))
    .toHaveLength(2) // __proto__ and the key with a newline, both masked
  expect(logs).toContain('model-router: config fallback lacks mini; appended')
  const shown = await route($, 'nope')
  expect(shown).toContain('mini')
  expect(shown).not.toContain('constructor')
})

test('layers: a nested-quantifier prompt rule is dropped', async ($, on) => {
  const logs = recordLogs(on)
  const home = { prompt: [{ pattern: '(a+)+$', phase: 'plan' }] }
  await bootRun($, on, FABLE, newWorld({ home }))
  expect(logs).toContain('model-router: config prompt rule ignored')
})

test('layers: a later broken override keeps the whole previous config', async (
  $, on) => {
  const w = newWorld({ home: { agents: { feater: 'mechanical' } } })
  const rig = await bootRun($, on, FABLE, w)
  w.files.set(HOME_FILE, '{nope')
  expect(await route($, 'reload')).toContain('previous config kept')
  expect(await featerModel($, rig)).toBe(HAIKU)
})

test('layers: a routing.json gone missing keeps the previous config', async (
  $, on) => {
  const w = newWorld()
  const rig = await bootRun($, on, FABLE, w)
  w.files.delete('routing')
  await route($, 'reload')
  expect(await featerModel($, rig)).toBe(SONNET)
})

test('layers: routing.json unreadable at start means defaults, no rows', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld({ routing: 'broken', ask: true })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBeUndefined()
  expect(await route($, 'show')).toContain('plan=best→claude-fable-5-1/xhigh')
  const said = logs.filter(l => l.includes('routing.json unreadable'))
  expect(said).toHaveLength(1)
})

test('layers: routing.json missing at start logs once, no rows', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld({ routing: 'absent' })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBeUndefined()
  expect(logs.filter(l => l.includes('routing.json missing'))).toHaveLength(1)
})

test('layers: session toggles survive a rebuild', async ($, on) => {
  await bootRun($, on)
  await route($, 'switch off')
  await route($, 'verbose on')
  const out = await route($, 'reload')
  expect(out).toContain('switch: off')
  expect(out).toContain('verbose: on')
})

test('layers: /clear keeps the config, the next prompt re-reads it', async (
  $, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  const w = newWorld()
  const rig = await bootRun($, on, FABLE, w)
  await clearOf($)
  const before = w.reads.length
  expect(await featerModel($, rig)).toBe(SONNET)
  expect(w.reads.length).toBe(before)
  const file = routingOf(w)
  projectRows({ feater: 'judge' })(file)
  w.files.set('routing', JSON.stringify(file))
  await typed($, 'hello')
  expect(await featerModel($, rig)).toBe(OPUS)
})

test('layers: /clear swaps nothing when the re-read fails', async ($, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  const w = newWorld()
  const rig = await bootRun($, on, FABLE, w)
  await clearOf($)
  w.files.delete('routing')
  await typed($, 'hello')
  expect(await featerModel($, rig)).toBe(SONNET)
})

test('layers: a state that never saw session.start loads on first use', async (
  $, on) => {
  const w = newWorld()
  installWorld(on, w)
  on('agent.offer', () => ({ isOffered: true }))
  const specs: (string | undefined)[] = []
  on('agent.spawn', ($, e) => {
    specs.push(e.model)
    return { model: e.model ?? e.parentModel, agentId: 'a1' }
  })
  await $.agent.spawn(spawnOf('feater'))
  expect(specs).toEqual([SONNET])
})

test('layers: a cwd change re-reads the layers for the new repo', async (
  $, on) => {
  const w = newWorld({
    edit: projectRows({ feater: 'judge' }, 'github.com/o/two'),
  })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(SONNET)
  w.repo = { root: '/work/two', remote: 'git@GitHub.com:o/two.git' }
  await $.classic.CwdChanged({ old_cwd: ROOT, new_cwd: '/work/two' })
  expect(await featerModel($, rig)).toBe(OPUS)
})

test('layers: no remote gives no project key, no local: string', async (
  $, on) => {
  const w = asks([...TO_IMPLEMENT, 'This project only'],
    { repo: { root: ROOT, remote: null } })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked[SCOPE_ASK]?.options).toEqual(['Everywhere', 'Later'])
  expect(w.written).toEqual([])
  expect(w.files.get('routing')).not.toContain('local:')
  expect(w.files.get('routing')).not.toContain(REAL_ROOT)
})

test('layers: a failing repo read skips only the project layer', async (
  $, on) => {
  const w = newWorld({ edit: projectRows({ feater: 'judge' }), repo: 'fail' })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(SONNET)
})

test('layers: a remote with credentials keys without them', async ($, on) => {
  const w = newWorld({
    edit: projectRows({ feater: 'judge' }),
    repo: { root: ROOT, remote: 'https://me:tok@GitHub.com/acme/app/' },
  })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(OPUS)
})

/** The project keys "This project only" stores for a remote. */
async function keyedBy($: Engine, on: On, remote: string) {
  const w = asks([...TO_IMPLEMENT, 'This project only'],
    { repo: { root: ROOT, remote } })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  return { w, keys: Object.keys(routingOf(w).projects as Rec) }
}

for (const bad of [
  'https://user:p@ss@Host.com/a/b.git',
  'https://user:pa/ss@host/a/b.git',
]) {
  test(`layers: credentials never become a key: ${bad}`, async ($, on) => {
    const { w, keys } = await keyedBy($, on, bad)
    expect(keys).toEqual([])
    expect(w.asked[SCOPE_ASK]?.options).toEqual(['Everywhere', 'Later'])
    expect(w.files.get('routing')).not.toContain('ss@')
  })
}

/** Remotes each rejected by exactly one guard of normalizeRemote. */
for (const [guard, bad] of [
  ['path @', 'https://user:12/ss@host/a/b.git'],
  ['empty host', 'file:///srv/git/app.git'],
  ['host [@:]', 'https://[::1]/a/b'],
  ['non-URL', 'https:host/a/b'],
  ['non-URL', 'weird remote'],
] as const) {
  test(`layers: ${guard} guard rejects ${bad}`, async ($, on) => {
    const { w, keys } = await keyedBy($, on, bad)
    expect(keys).toEqual([])
    expect(w.asked[SCOPE_ASK]?.options).toEqual(['Everywhere', 'Later'])
    expect(w.files.get('routing')).not.toContain('/srv/')
    expect(w.files.get('routing')).not.toContain('ss@')
  })
}

for (const [remote, key] of [
  ['https://tok@host/a/b', 'host/a/b'],
  ['git@github.com:acme/app.git', KEY],
  [REMOTE, KEY],
] as const) {
  test(`layers: ${remote} keys as ${key}`, async ($, on) => {
    expect((await keyedBy($, on, remote)).keys).toEqual([key])
  })
}

// ---- wave 3-A: first-use dialog -------------------------------------------

/** A world with dialogs on and the answers queued. */
const asks = (answers: string[], fx: Fixture = {}) =>
  newWorld({ ask: true, answers, ...fx })

/** The user types /feat; the engine then loads the skill's prompt. */
async function typeFeat($: Engine): Promise<void> {
  await typed($, '/feat add a thing')
  await skillPrompt($, 'feat')
}

const mainNow = async ($: Engine) => mainLine(await route($, 'show'))
const confirmedOf = (w: World): Rec => routingOf(w).confirmed as Rec

test('T1: a typed skill asks once, with the real id and effort', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked).toHaveLength(1)
  const first = w.asked[0] as Asked
  expect(first.text).toContain('/feat')
  expect(first.text).toContain('claude-fable-5-1 at high')
  expect(first.options).toEqual(['Later', 'Keep', 'Change'])
  expect(first.header).toBe('model-router')
})

test('T1: the question follows the model main will really run on', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, SONNET, w)
  await typeFeat($)
  expect(w.asked[0]?.text).toContain('claude-fable-5-1 at high')
})

test('T1: Keep writes the row and its phase, then the skill never asks', async (
  $, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(confirmedOf(w)).toEqual({
    skills: { feat: 'reflect' },
    phases: { reflect: 'reflect' },
  })
  await typeFeat($)
  expect(w.asked).toHaveLength(1)
})

test('T1: Keep leaves the route as it was', async ($, on) => {
  await bootRun($, on, FABLE, asks(['Keep']))
  await typeFeat($)
  expect(await mainNow($)).toContain('skill reflect')
})

test('T1: a Change then Everywhere rewrites the row, routes at once', async (
  $, on) => {
  const w = asks([...TO_IMPLEMENT, 'Everywhere'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  const file = routingOf(w)
  expect((file.skills as Rec).feat).toBe('implement')
  expect((file.changed as Rec).skills).toEqual({
    feat: { from: 'reflect', to: 'implement' },
  })
  expect(confirmedOf(w).skills).toEqual({ feat: 'implement' })
  expect(await mainNow($)).toContain('skill implement')
})

test('T1: the scope question names the two scopes', async ($, on) => {
  const w = asks([...TO_IMPLEMENT, 'Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked[SCOPE_ASK]?.options).toEqual(['Everywhere', 'This project only'])
})

test('T1: This project only writes the exception, not the row', async (
  $, on) => {
  const w = asks([...TO_IMPLEMENT, 'This project only'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  const file = routingOf(w)
  expect((file.skills as Rec).feat).toBe('reflect')
  expect(file.projects).toEqual({ [KEY]: { skills: { feat: 'implement' } } })
  expect(file.changed).toEqual({})
  expect(confirmedOf(w).skills).toEqual({ feat: 'reflect' })
  expect(await mainNow($)).toContain('skill implement')
})

test('T1: after a project exception no other project asks', async ($, on) => {
  const w = asks([...TO_IMPLEMENT, 'This project only'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  w.repo = { root: '/work/two', remote: 'https://github.com/acme/two.git' }
  await $.classic.CwdChanged({ old_cwd: ROOT, new_cwd: '/work/two' })
  await typeFeat($)
  expect(w.asked).toHaveLength(SCOPE_ASK + 1)
  expect(await mainNow($)).toContain('skill reflect')
})

/** /clear: a new conversation, the config kept and re-read at the prompt. */
function clearOf($: Engine) {
  return $.session.end({
    reason: 'clear',
    sessionId: 's1',
    resume: { id: 's1' },
  })
}

test('T1: a second change keeps the first shipped phase in changed', async (
  $, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  const w = asks([...TO_IMPLEMENT, 'Everywhere', ...TO_APPLY, 'Everywhere'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  const file = routingOf(w)
  ;(file.confirmed as Rec).skills = {}
  w.files.set('routing', JSON.stringify(file))
  await clearOf($)
  await typeFeat($)
  expect(((routingOf(w).changed as Rec).skills as Rec).feat).toEqual({
    from: 'reflect',
    to: 'apply',
  })
})

test('T1: Later applies the default, writes nothing, asks no more', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  await typeFeat($)
  expect(w.written).toEqual([])
  expect(w.asked).toHaveLength(1)
  expect(await mainNow($)).toContain('skill reflect')
})

test('T1: a dismissed dialog is a Later', async ($, on) => {
  const w = asks([REJECT])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  await typeFeat($)
  expect(w.written).toEqual([])
  expect(w.asked).toHaveLength(1)
  expect(await mainNow($)).toContain('skill reflect')
})

test('T1: an answer that is no label is a Later and says so', async (
  $, on) => {
  const toasts = recordToasts(on)
  const w = asks(['banana'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.written).toEqual([])
  expect(toasts).toContain('answer not recognised, default kept')
  expect(await mainNow($)).toContain('skill reflect')
})

test('T1: a scope answer that is not a label is a Later', async ($, on) => {
  const w = asks([...TO_IMPLEMENT, 'whenever'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.written).toEqual([])
  expect(await mainNow($)).toContain('skill reflect')
})

test('T1: without a repo key only Everywhere is offered', async ($, on) => {
  const w = asks([...TO_IMPLEMENT, 'This project only'], { repo: 'fail' })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked[SCOPE_ASK]?.options).toEqual(['Everywhere', 'Later'])
  expect(w.written).toEqual([])
})

test('T1: the model\'s own Skill call never asks', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await loadSkill($, 'feat')
  expect(w.asked).toEqual([])
})

test('T1: a skill without a row never asks', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await typed($, '/other')
  await skillPrompt($, 'other')
  expect(w.asked).toEqual([])
})

test('T1: a project row counts as decided', async ($, on) => {
  const w = asks(['Keep'], {
    edit: f => { f.projects = { [KEY]: { skills: { feat: 'plan' } } } },
  })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked).toEqual([])
  expect(await mainNow($)).toContain('skill plan')
})

test('T1: a machine override row counts as decided', async ($, on) => {
  const w = asks(['Keep'], { home: { skills: { feat: 'plan' } } })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked).toEqual([])
})

test('T1: another session\'s decision is seen before the dialog', async (
  $, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  const file = routingOf(w)
  file.confirmed = { skills: { feat: 'reflect' } }
  w.files.set('routing', JSON.stringify(file))
  await typeFeat($)
  expect(w.asked).toEqual([])
})

test('T1: `ask` turned off elsewhere is seen before the dialog', async (
  $, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  const file = routingOf(w)
  file.ask = false
  w.files.set('routing', JSON.stringify(file))
  await typeFeat($)
  expect(w.asked).toEqual([])
})

test('T1: a row edited by hand after a Keep asks again', async ($, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  const w = asks(['Keep', 'Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  const file = routingOf(w)
  ;(file.skills as Rec).feat = 'plan'
  w.files.set('routing', JSON.stringify(file))
  await clearOf($)
  await typeFeat($)
  expect(w.asked).toHaveLength(2)
})

test('T1: ask false asks nothing', async ($, on) => {
  const w = newWorld({ answers: ['Keep'] })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked).toEqual([])
})

test('T1: the router off asks nothing', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await route($, 'off')
  await typeFeat($)
  expect(w.asked).toEqual([])
})

test('T1: routing.json unreadable at the dialog asks nothing', async (
  $, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  w.files.delete('routing')
  await typeFeat($)
  expect(w.asked).toEqual([])
  expect(await mainNow($)).toContain('skill reflect')
})

test('T3: routing.json unreadable at the dialog asks nothing', async (
  $, on) => {
  const w = asks(['Keep'], { routing: 'broken' })
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(w.asked).toEqual([])
})

test('T1: a failed write applies the default, key stays asked', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = asks(['Keep', 'Later'])
  await bootRun($, on, FABLE, w)
  w.failWrite = true
  await typeFeat($)
  expect(await mainNow($)).toContain('skill reflect')
  expect(logs.join('\n')).toContain('first-use dialog failed')
  w.failWrite = false
  await typeFeat($)
  expect(w.asked).toHaveLength(1)
})

test('T1: after a failed write the next session asks again', async (
  $, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  const w = asks(['Keep', 'Later'])
  await bootRun($, on, FABLE, w)
  w.failWrite = true
  await typeFeat($)
  w.failWrite = false
  await clearOf($)
  await typeFeat($)
  expect(w.asked).toHaveLength(2)
})

const failures = (logs: string[]): string[] =>
  logs.filter(l => l.includes('first-use dialog failed'))

test('T1: two rows failing to write log the failure once', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = asks(['Keep', 'Keep'])
  await bootRun($, on, FABLE, w)
  w.failWrite = true
  await typeFeat($)
  await typed($, '/status')
  await skillPrompt($, 'status')
  expect(w.asked).toHaveLength(2)
  expect(failures(logs)).toHaveLength(1)
})

test('T1: a rebuild failing after the write keeps the key asked', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = asks([...TO_IMPLEMENT, 'Everywhere'])
  await bootRun($, on, FABLE, w)
  w.onWrite = () => { w.files.set(HOME_FILE, '{nope') }
  await typeFeat($)
  expect((routingOf(w).skills as Rec).feat).toBe('implement')
  expect(await mainNow($)).toContain('skill reflect')
  const pending = (await route($, 'pending')).split('\n')
  expect(pending[1]).toBe('asked this session: skills:feat')
  expect(failures(logs)).toHaveLength(1)
  expect(failures(logs)[0]).toContain('first-use dialog failed (Error)')
})

test('T1: a Keep toasts that routing.json changed', async ($, on) => {
  const toasts = recordToasts(on)
  await bootRun($, on, FABLE, asks(['Keep']))
  await typeFeat($)
  expect(toasts.join('\n')).toContain('routing.json updated: commit it')
})

test('writes: only routing.json, 2-space, keys in the documented order', async (
  $, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.written).toHaveLength(1)
  expect(w.written[0]).toMatch(/\/mods\/model-router\/routing\.json$/)
  expect(w.files.get('routing')).toMatch(/^\{\n {2}"phases"/)
  expect(Object.keys(routingOf(w))).toEqual([
    'phases', 'skills', 'agents', 'projects', 'confirmed', 'changed', 'ask',
  ])
})

test('writes: a missing routing.json is never created', async ($, on) => {
  const w = newWorld({ routing: 'absent' })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'ask off')
  expect(out).toContain('missing or unreadable')
  expect(w.written).toEqual([])
})

test('writes: two writers on one file both land', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  const held = deferred()
  const seen = deferred()
  w.writeGate = held.gate
  w.onWrite = seen.release
  const first = typeFeat($)
  await seen.gate
  w.onWrite = undefined
  const second = route($, 'ask off')
  await new Promise(r => setTimeout(r, 20)) // let a second writer start
  held.release()
  await first
  await second
  expect(routingOf(w).ask).toBe(false)
  expect(confirmedOf(w).skills).toEqual({ feat: 'reflect' })
})

test('writes: the route tool never writes', async ($, on) => {
  const w = newWorld()
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })
  await $.tool.call({ tool: ROUTE_TOOL, effort: 'low' })
  expect(w.written).toEqual([])
})

/** A Change chain, then `scope`: the world after the typed /feat. */
async function changeFeat($: Engine, on: On, scope: string) {
  const w = asks([...TO_IMPLEMENT, scope])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  return w
}

test('writes: an Everywhere change is one write', async ($, on) => {
  const w = await changeFeat($, on, 'Everywhere')
  expect(w.written).toHaveLength(1)
  const file = routingOf(w)
  expect((file.skills as Rec).feat).toBe('implement')
  expect((file.changed as Rec).skills).toEqual({
    feat: { from: 'reflect', to: 'implement' },
  })
  expect(confirmedOf(w).skills).toEqual({ feat: 'implement' })
})

test('writes: a This project only change is one write', async ($, on) => {
  const w = await changeFeat($, on, 'This project only')
  expect(w.written).toHaveLength(1)
  const file = routingOf(w)
  expect(file.projects).toEqual({ [KEY]: { skills: { feat: 'implement' } } })
  expect(confirmedOf(w).skills).toEqual({ feat: 'reflect' })
})

/** Rebuilds the fixture in reverse key order: `ask` first, `phases` last. */
function reverseKeys(file: Rec): void {
  const copy = { ...file }
  for (const key of Object.keys(copy)) delete file[key]
  for (const key of Object.keys(copy).reverse()) file[key] = copy[key]
}

test('writes: an out-of-order routing.json is written back in order', async (
  $, on) => {
  const w = asks(['Keep'], { edit: reverseKeys })
  expect(Object.keys(routingOf(w))).toEqual([
    'ask', 'changed', 'confirmed', 'projects', 'agents', 'skills', 'phases',
  ])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.written).toHaveLength(1)
  expect(Object.keys(routingOf(w))).toEqual([
    'phases', 'skills', 'agents', 'projects', 'confirmed', 'changed', 'ask',
  ])
})

test('writes: an output over the cap is refused: a Later', async ($, on) => {
  const toasts = recordToasts(on)
  const pad = (f: Rec) => {
    f.pad = 'x'.repeat(65536 - JSON.stringify(f, null, 2).length - 60)
  }
  const w = asks(['Keep'], { edit: pad })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(toasts.join('\n')).toContain(
    'routing.json would exceed 65536 bytes: nothing saved')
  expect(w.written).toEqual([])
})

const NOTHING_SAVED = 'routing.json is missing or unreadable: nothing saved'

test('writes: routing.json gone at the save: a Later, kept asked', async (
  $, on) => {
  const toasts = recordToasts(on)
  const w = asks(['Keep', 'Keep'])
  await bootRun($, on, FABLE, w)
  const saved = w.files.get('routing') ?? ''
  w.onAsk = () => { w.files.delete('routing') }
  await typeFeat($)
  expect(toasts).toContain(NOTHING_SAVED)
  expect(w.written).toEqual([])
  expect(w.files.has('routing')).toBe(false)
  expect(await mainNow($)).toContain('skill reflect')
  w.onAsk = undefined
  w.files.set('routing', saved)
  await typeFeat($)
  expect(w.asked).toHaveLength(1)
  const pending = (await route($, 'pending')).split('\n')
  expect(pending[1]).toBe('asked this session: skills:feat')
})

// The kit has no disk: an fs.write no hook answers, or whose mock throws
// (the engine skips a failing hook), is refused by the kit's bottom. The
// probe aims at /home/t, where nothing can be created: a real write would
// fail there with a disk error, not this one.
const REFUSED = 'no implementation for fs.write'

/** An inline plugin: `/probe <path>` says what `$.fs.write` did. */
const PROBE: Plugin = {
  name: 'fs-probe',
  register: on => {
    on('command.run', { command: 'probe' }, async ($, e) => {
      try {
        await $.fs.write(e.args, 'x')
        return { text: 'written' }
      } catch (err) {
        return { text: String(err) }
      }
    })
  },
}

const probe = async ($: Engine): Promise<string> => (await $.command.run({
  command: 'probe',
  args: `${HOME}/never-written.json`,
  origin: { kind: 'composer' },
  presentation: { isFullscreen: false, columns: 80 },
})).text ?? ''

test('writes: kit: an fs.write no hook answers is refused', {
  plugins: [PROBE],
}, async $ => {
  expect(await probe($)).toContain(REFUSED)
})

test('writes: kit: a throwing fs.write mock lands on the same refusal', {
  plugins: [PROBE],
}, async ($, on) => {
  on('fs.write', () => {
    throw new Error('EACCES')
  })
  expect(await probe($)).toContain(REFUSED)
})

// ---- wave 3-A: T2 agent spawns, T3 route tool ----------------------------

test('T2: a rowed spawn asks with the model and effort it will get', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('feater'))
  const q = w.asked[0] as Asked
  expect(q.text).toContain('First dispatch of feater')
  expect(q.text).toContain('claude-sonnet-5-5 at medium')
  expect(q.options).toEqual(['Later', 'Keep', 'Change'])
})

test('T2: the question carries an explicit effort param', async ($, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({
    tool: 'Agent',
    description: 'd',
    prompt: 'p',
    effort: 'low',
    tool_use_id: 't1',
  })
  await $.agent.spawn(spawnOf('feater'))
  expect(w.asked[0]?.text).toContain('claude-sonnet-5-5 at low')
})

test('T2: Keep writes the agent row and the spawn goes on', async ($, on) => {
  const w = asks(['Keep'])
  const rig = await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('feater'))
  expect(confirmedOf(w)).toEqual({
    agents: { feater: 'implement' },
    phases: { implement: 'implement' },
  })
  expect(rig.specs).toEqual([SONNET])
  await $.agent.spawn(spawnOf('feater'))
  expect(w.asked).toHaveLength(1)
})

test('T2: a change routes this very spawn with the new row', async (
  $, on) => {
  const w = asks([...TO_JUDGE, 'Everywhere'])
  const rig = await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('feater'))
  expect(rig.specs).toEqual([OPUS])
})

test('T2: an explicit model param never asks', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('feater', { model: 'opus' }))
  expect(w.asked).toEqual([])
})

test('T2: a spawn inside an agent never asks', async ($, on) => {
  const w = asks(['Keep'])
  const rig = await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('feater', { parentAgentId: 'a9' }))
  expect(w.asked).toEqual([])
  expect(rig.specs).toEqual([SONNET])
})

test('T2: a project-defined agent never asks', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await offerOf($, 'verifier', 'projectSettings')
  await $.agent.spawn(spawnOf('verifier'))
  expect(w.asked).toEqual([])
})

test('T2: an agent without a row never asks', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('stranger'))
  expect(w.asked).toEqual([])
})

test('T2: a parallel spawn of the same agent is routed unasked', async (
  $, on) => {
  const w = asks(['Keep'])
  const rig = await bootRun($, on, FABLE, w)
  const held = deferred()
  const open = deferred()
  w.gate = held.gate
  w.onAsk = open.release
  const owner = $.agent.spawn(spawnOf('feater'))
  await open.gate
  await $.agent.spawn(spawnOf('feater'))
  expect(rig.specs).toEqual([SONNET])
  held.release()
  await owner
  expect(w.asked).toHaveLength(1)
  expect(rig.specs).toEqual([SONNET, SONNET])
})

test('T2: a parallel spawn of another agent is routed unasked', async (
  $, on) => {
  const w = asks(['Keep'])
  const rig = await bootRun($, on, FABLE, w)
  const held = deferred()
  const open = deferred()
  w.gate = held.gate
  w.onAsk = open.release
  const owner = $.agent.spawn(spawnOf('feater'))
  await open.gate
  await $.agent.spawn(spawnOf('plan-challenger'))
  expect(rig.specs).toEqual([OPUS])
  held.release()
  await owner
  expect(w.asked).toHaveLength(1)
})

test('T2: the unasked agent is asked at its next use', async ($, on) => {
  const w = asks(['Keep', 'Keep'])
  const rig = await bootRun($, on, FABLE, w)
  const held = deferred()
  const open = deferred()
  w.gate = held.gate
  w.onAsk = open.release
  const owner = $.agent.spawn(spawnOf('feater'))
  await open.gate
  await $.agent.spawn(spawnOf('plan-challenger'))
  held.release()
  await owner
  w.gate = undefined
  await $.agent.spawn(spawnOf('plan-challenger'))
  expect(w.asked).toHaveLength(2)
  expect(rig.specs).toEqual([OPUS, SONNET, OPUS])
})

test('T3: a phase declared through the route tool asks Keep or Later', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  const q = w.asked[0] as Asked
  expect(q.text).toContain('First use of orchestrate on the main loop')
  expect(q.text).toContain('claude-fable-5-1 at medium')
  expect(q.options).toEqual(['Later', 'Keep'])
})

test('T3: Keep endorses the phase in routing.json', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(confirmedOf(w)).toEqual({ phases: { orchestrate: 'orchestrate' } })
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(w.asked).toHaveLength(1)
})

test('T3: no change is offered, a phase name answer is a Later', async (
  $, on) => {
  const w = asks(['plan'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(w.written).toEqual([])
  expect(await mainNow($)).toContain('model orchestrate')
})

test('T3: a phase endorsed by a skill Keep is not asked again', async (
  $, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect' })
  expect(w.asked).toHaveLength(1)
})

test('T3: an effort-only call never asks', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, effort: 'low' })
  expect(w.asked).toEqual([])
})

test('T3: a route call inside an agent never asks', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'judge', agentId: 'a1' })
  expect(w.asked).toEqual([])
})

test('a step never opens a dialog', async ($, on) => {
  const w = asks(['Keep'])
  const rig = await bootRig($, on, FABLE, 1000, w)
  await runStep($, highStep())
  expect(w.asked).toEqual([])
  expect(rig.seen).toHaveLength(1)
})

// ---- wave 3-A: /route pending, ask, reload -------------------------------

test('/route pending lists what is not confirmed, asked first', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  const lines = (await route($, 'pending')).split('\n')
  expect(lines[0]).toBe('pending confirmation: 20')
  expect(lines[1]).toBe('asked this session: skills:feat')
  expect(lines[2]).toContain('agents:feater')
  expect(lines[2]).toContain('phases:plan')
  expect(lines[2]).not.toContain('skills:feat')
})

test('/route pending drops a confirmed row', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  const text = await route($, 'pending')
  expect(text).toContain('pending confirmation: 18')
  expect(text).not.toContain('phases:reflect')
})

test('/route ask off writes the flag and silences the dialog', async (
  $, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  expect(await route($, 'ask off')).toContain('ask off')
  expect(routingOf(w).ask).toBe(false)
  await typeFeat($)
  expect(w.asked).toEqual([])
})

test('/route ask on turns the dialog back on', async ($, on) => {
  const w = newWorld({ answers: ['Later'] })
  await bootRun($, on, FABLE, w)
  await route($, 'ask on')
  expect(routingOf(w).ask).toBe(true)
  await typeFeat($)
  expect(w.asked).toHaveLength(1)
})

test('/route ask names a machine override that wins', async ($, on) => {
  const w = newWorld({ home: { ask: false } })
  await bootRun($, on, FABLE, w)
  expect(await route($, 'ask on')).toContain('sets ask off and wins')
})

test('/route ask wants on or off', async ($, on) => {
  const w = newWorld()
  await bootRun($, on, FABLE, w)
  expect(await route($, 'ask maybe')).toContain('usage: /route ask on|off')
  expect(w.written).toEqual([])
})

test('/route ask refuses a user-less origin like the rest of /route', async (
  $, on) => {
  const w = newWorld()
  await bootRun($, on, FABLE, w)
  const out = await $.command.run({
    command: 'route',
    args: 'ask off',
    origin: { kind: 'plugin', name: 'x' },
    presentation: { isFullscreen: false, columns: 80 },
  })
  expect(out.text).toContain('user-only')
  expect(w.written).toEqual([])
})

test('/route reload re-reads routing.json and the override', async (
  $, on) => {
  const w = newWorld()
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(SONNET)
  const file = routingOf(w)
  ;(file.agents as Rec).feater = 'judge'
  w.files.set('routing', JSON.stringify(file))
  w.files.set(HOME_FILE, '{"agents":{"verifier":"mechanical"}}')
  await route($, 'reload')
  expect(await featerModel($, rig)).toBe(OPUS)
  await $.agent.spawn(spawnOf('verifier'))
  expect(rig.specs[rig.specs.length - 1]).toBe(HAIKU)
})

test('layers: enabled:false in the override survives /clear', async (
  $, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  const w = newWorld({ home: { enabled: false } })
  const rig = await bootRun($, on, FABLE, w)
  expect(await route($, 'show')).toContain('router: off (config)')
  await clearOf($)
  expect(await route($, 'show')).toContain('router: off (config)')
  expect(await featerModel($, rig)).toBeUndefined()
})

// ---- wave 3-B: a dialog with context, model then effort on a change ------

const skillPath = (name: string) => `${HOME}/.claude/skills/${name}/SKILL.md`
const skillMd = (front: string, body = '# body') =>
  `---\nname: feat\n${front}\nallowed-tools: Read\n---\n${body}\n`
const ROUTED = 'Routed to reflect: claude-fable-5-1 at high. OK?'

/** A typed /feat with `md` served as its SKILL.md; the world after. */
async function featWith(
  $: Engine,
  on: On,
  md: string | undefined,
  fx: Fixture = {},
) {
  const w = asks(['Later'], fx)
  if (md !== undefined) w.files.set(skillPath('feat'), md)
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  return w
}

/** Edits one phase of the inline routing.json. */
const setPhase = (phase: string, extra: Rec) => (file: Rec) => {
  const phases = file.phases as Record<string, Rec>
  phases[phase] = { ...phases[phase], ...extra }
}

for (const [form, front, desc] of [
  ['plain', 'description: Builds a thing. Then more words.', 'Builds a thing'],
  ['literal block', 'description: |\n  Line one\n  runs on. Second.',
    'Line one runs on'],
  ['folded block', 'description: >-\n  Folded one\n  two. Next.',
    'Folded one two'],
  ['single-quoted', "description: 'It''s here. More.'", "It's here"],
  ['double-quoted', 'description: "Say \\"hi\\" now. More."', 'Say "hi" now'],
] as const) {
  test(`text: a ${form} SKILL.md description leads the skill question`, async (
    $, on) => {
    const w = await featWith($, on, skillMd(front))
    expect(w.asked[0]?.text).toBe(`First route for /feat — ${desc}. ${ROUTED}`)
  })
}

test('text: a skill without a SKILL.md is named alone', async ($, on) => {
  const w = await featWith($, on, undefined)
  expect(w.asked[0]?.text).toBe(`First route for /feat. ${ROUTED}`)
})

test('text: a name outside the allowlist reads no file', async ($, on) => {
  const w = asks(['Later'], {
    edit: f => { (f.skills as Rec)['../x'] = 'reflect' },
  })
  const md = skillMd('description: Escaped. Bad.')
  w.files.set(`${HOME}/.claude/skills/../x/SKILL.md`, md)
  w.files.set(`${HOME}/.claude/x/SKILL.md`, md) // the folded spelling
  await bootRun($, on, FABLE, w)
  await typed($, 'hello')
  await skillPrompt($, '../x')
  expect(w.asked[0]?.text).toBe(`First route for /../x. ${ROUTED}`)
  expect(w.reads.filter(p => p.includes('SKILL.md'))).toEqual([])
})

test('text: a SKILL.md that is not a regular file is not read', async (
  $, on) => {
  const w = asks(['Later'])
  w.files.set(skillPath('feat'), skillMd('description: Hidden. No.'))
  w.kinds.set(skillPath('feat'), 'dir')
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked[0]?.text).toBe(`First route for /feat. ${ROUTED}`)
  expect(w.reads).not.toContain(skillPath('feat'))
})

test('text: a SKILL.md over the size cap is named alone', async ($, on) => {
  const big = skillMd('description: Too big. No.', 'x'.repeat(70000))
  const w = await featWith($, on, big)
  expect(w.asked[0]?.text).toBe(`First route for /feat. ${ROUTED}`)
})

test('text: HOME unset names the skill alone, reads nothing', async (
  $, on) => {
  const w = asks(['Later'], { noHome: true })
  w.files.set(skillPath('feat'), skillMd('description: Hidden. No.'))
  // served where an unguarded `${undefined}/.claude/...` would land
  for (const root of ['undefined', '']) {
    w.files.set(`${root}/.claude/skills/feat/SKILL.md`,
      skillMd('description: Unguarded. No.'))
  }
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked[0]?.text).toBe(`First route for /feat. ${ROUTED}`)
  expect(w.reads.filter(p => p.includes('SKILL.md'))).toEqual([])
})

test('text: an empty HOME never reads from the root', async ($, on) => {
  const w = asks(['Later'])
  w.env = ''
  w.files.set('/.claude/skills/feat/SKILL.md',
    skillMd('description: Hidden. No.'))
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked[0]?.text).toBe(`First route for /feat. ${ROUTED}`)
  expect(w.reads.filter(p => p.includes('SKILL.md'))).toEqual([])
})

test('text: a long description with control chars is cut and cleaned', async (
  $, on) => {
  const raw = 'word \u0007‮ '.repeat(100)
  const w = await featWith($, on, skillMd(`description: ${raw}`))
  const text = w.asked[0]?.text ?? ''
  const desc = text.slice(text.indexOf(' — ') + 3, text.indexOf('. Routed'))
  expect([...desc]).toHaveLength(140)
  expect(desc.endsWith('…')).toBe(true)
  expect(text).not.toMatch(/[\p{Cc}\p{Cf}]/u)
})

test('text: an agent question carries the offered description', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await offerOf($, 'feater', 'userSettings', 'Writes the code.\nMore text.')
  await $.agent.spawn(spawnOf('feater'))
  expect(w.asked[0]?.text).toBe('First dispatch of feater — Writes the code. ' +
    'Routed to implement: claude-sonnet-5-5 at medium. OK?')
})

test('text: an agent description is cleaned like a skill one', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await offerOf($, 'feater', 'userSettings', 'a‮b\u0007c'.repeat(100))
  await $.agent.spawn(spawnOf('feater'))
  const text = w.asked[0]?.text ?? ''
  expect(text).not.toMatch(/[\p{Cc}\p{Cf}]/u)
  expect(text.indexOf('. Routed') - text.indexOf(' — ') - 3).toBe(140)
})

test('text: the phase about shows in the skill question', async ($, on) => {
  const w = await featWith($, on, undefined,
    { edit: setPhase('reflect', { about: 'deep thinking' }) })
  expect(w.asked[0]?.text).toBe('First route for /feat. Routed to reflect ' +
    '(deep thinking): claude-fable-5-1 at high. OK?')
})

test('text: the about is cleaned before it enters a question', async (
  $, on) => {
  const w = await featWith($, on, undefined,
    { edit: setPhase('reflect', { about: 'a‮b\nc' }) })
  expect(w.asked[0]?.text).toContain('Routed to reflect (ab c):')
})

test('text: an astral description is cut by code point, not unit', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await offerOf($, 'feater', 'userSettings', '\u{1F600}'.repeat(200))
  await $.agent.spawn(spawnOf('feater'))
  const text = w.asked[0]?.text ?? ''
  const desc = text.slice(text.indexOf(' — ') + 3, text.indexOf('. Routed'))
  expect([...desc]).toHaveLength(140)
  expect(desc.endsWith('…')).toBe(true)
  expect(desc.isWellFormed()).toBe(true)
})

test('text: an agent question carries the phase about', async ($, on) => {
  const w = asks(['Later'], {
    edit: setPhase('implement', { about: 'writing code' }),
  })
  await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('feater'))
  expect(w.asked[0]?.text).toContain('Routed to implement (writing code):')
})

test('change: the effort question lists four labels at most', async (
  $, on) => {
  const w = asks(['Change', 'sonnet (work)', 'Later'], {
    edit: f => {
      (f.phases as Rec).deep = { tier: 'work', effort: 'max' }
    },
  })
  await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('feater'))
  const q = w.asked.find(a => a.text.startsWith('Which effort'))
  expect(q?.options).toEqual(['low', 'medium', 'high', 'xhigh'])
})

for (const [what, about] of [
  ['an overlong', 'x'.repeat(121)],
  ['a non-string', 5],
] as const) {
  test(`about: ${what} value is dropped and logged`, async ($, on) => {
    const logs = recordLogs(on)
    const w = await featWith($, on, undefined,
      { edit: setPhase('reflect', { about }) })
    expect(w.asked[0]?.text).toBe(`First route for /feat. ${ROUTED}`)
    expect(logs.join('\n')).toContain('phases.reflect.about ignored')
  })
}

test('text: a phase question names its about and its consumers', async (
  $, on) => {
  const w = asks(['Later'], {
    edit: setPhase('orchestrate', { about: 'dispatch work' }),
  })
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(w.asked[0]?.text).toBe('First use of orchestrate on the main loop — ' +
    'dispatch work; used by 0 rows, the derived route of dispatches: ' +
    'claude-fable-5-1 at medium. OK?')
})

test('text: a phase question counts rows and prompt rules', async ($, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect' })
  expect(w.asked[0]?.text).toBe('First use of reflect on the main loop — ' +
    'used by 1 row, 1 prompt rule: claude-fable-5-1 at high. OK?')
})

test('text: a phase question names its floor rule', async ($, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'escalate' })
  expect(w.asked[0]?.text).toBe('First use of escalate on the main loop — ' +
    'used by 0 rows, 1 floor rule: claude-fable-5-1 at max. OK?')
})

test('T3: a Change answer changes nothing and is said', async ($, on) => {
  const toasts = recordToasts(on)
  const w = asks(['Change'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(w.asked).toHaveLength(1)
  expect(w.written).toEqual([])
  expect(toasts).toContain('answer not recognised, default kept')
})

test('change: the model question offers the four tiered aliases', async (
  $, on) => {
  const w = asks(['Change', 'Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked[1]?.text).toBe('Which model for feat?')
  expect(w.asked[1]?.options).toEqual([
    'fable (best)', 'opus (big)', 'sonnet (work)', 'haiku (cheap)',
  ])
})

for (const [label, alias, efforts] of [
  ['fable (best)', 'fable', ['medium', 'high', 'xhigh', 'max']],
  ['sonnet (work)', 'sonnet', ['low', 'medium', 'high', 'xhigh']],
] as const) {
  test(`change: ${alias} offers the efforts of its phases, ascending`, async (
    $, on) => {
    const w = asks(['Change', label, 'Later'])
    await bootRun($, on, FABLE, w)
    await typeFeat($)
    expect(w.asked[2]?.text).toBe(`Which effort on ${alias}?`)
    expect(w.asked[2]?.options).toEqual(efforts)
  })
}

for (const [label, phase] of [
  ['opus (big)', 'judge'],
  ['haiku (cheap)', 'mechanical'],
] as const) {
  test(`change: ${label} has one effort, the question is skipped`, async (
    $, on) => {
    const w = asks(['Change', label, 'Later'])
    await bootRun($, on, FABLE, w)
    await typeFeat($)
    expect(w.asked).toHaveLength(3)
    expect(w.asked[2]?.text).toContain(`Use ${phase} for feat`)
    expect(w.asked[2]?.options).toEqual(['Everywhere', 'This project only'])
  })
}

/** The shipped mechanical phase moved off haiku: no shipped phase uses it. */
const lowMechanical = (f: Rec): void => {
  (f.phases as Rec).mechanical = { tier: 'work', effort: 'low' }
}

test('change: an alias no shipped phase uses is a Later and says so', async (
  $, on) => {
  const toasts = recordToasts(on)
  const w = asks(['Change', 'haiku (cheap)'], {
    edit: lowMechanical,
  })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(toasts).toContain(
    'no shipped phase uses haiku: add one to routing.json')
  expect(w.asked).toHaveLength(2)
  expect(w.written).toEqual([])
})

test('change: a dismissed model question is a silent Later', async (
  $, on) => {
  const toasts = recordToasts(on)
  const w = asks(['Change', REJECT])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(toasts).toEqual([])
  expect(w.written).toEqual([])
})

for (const [step, answers] of [
  ['the first', ['whatever']],
  ['the model', ['Change', 'mistral']],
  ['the effort', ['Change', 'sonnet (work)', 'ludicrous']],
] as const) {
  test(`change: another answer at ${step} question is a Later, said`, async (
    $, on) => {
    const toasts = recordToasts(on)
    const w = asks([...answers])
    await bootRun($, on, FABLE, w)
    await typeFeat($)
    expect(toasts).toContain('answer not recognised, default kept')
    expect(w.asked).toHaveLength(answers.length)
    expect(w.written).toEqual([])
    expect(toasts.join('\n')).not.toContain('mistral')
  })
}

test('change: a Keep on a main row says nothing about a new route', async (
  $, on) => {
  const toasts = recordToasts(on)
  await bootRun($, on, FABLE, asks(['Keep']))
  await typeFeat($)
  expect(toasts.join('\n')).not.toContain('now runs')
})

test('change: a downgrade names the real route and the switch', async (
  $, on) => {
  const toasts = recordToasts(on)
  const w = asks([...TO_IMPLEMENT, 'Everywhere'])
  await bootRun($, on, FABLE, w)
  await route($, 'switch off')
  await typeFeat($)
  expect((routingOf(w).skills as Rec).feat).toBe('implement')
  expect(toasts).toContain('/feat now runs claude-fable-5-1 at medium, ' +
    'main moves up only: /route switch on allows a downgrade')
})

test('change: with the switch on the toast carries no hint', async (
  $, on) => {
  const toasts = recordToasts(on)
  await bootRun($, on, FABLE, asks([...TO_IMPLEMENT, 'Everywhere']))
  await route($, 'switch on')
  await typeFeat($)
  expect(toasts).toContain('/feat now runs claude-sonnet-5-5 at medium')
})

test('change: an upgrade toast carries no hint', async ($, on) => {
  const toasts = recordToasts(on)
  const w = asks(['Change', 'fable (best)', 'xhigh', 'Everywhere'])
  await bootRun($, on, SONNET, w)
  await typeFeat($)
  expect(toasts).toContain('/feat now runs claude-fable-5-1 at xhigh')
})

test('change: an upgrade the config holds back carries no hint', async (
  $, on) => {
  const toasts = recordToasts(on)
  const w = asks(['Change', 'fable (best)', 'xhigh', 'Everywhere'],
    { home: { mainUpgrade: false } })
  await bootRun($, on, SONNET, w)
  await typeFeat($)
  expect(toasts).toContain('/feat now runs claude-sonnet-5-5 at xhigh')
})

test('change: a project scope stores the derived phase, keeps the row', async (
  $, on) => {
  const w = asks([...TO_APPLY, 'This project only'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  const file = routingOf(w)
  expect((file.skills as Rec).feat).toBe('reflect')
  expect(file.projects).toEqual({ [KEY]: { skills: { feat: 'apply' } } })
})

test('change: a security auditor moves to opus at xhigh, at once', async (
  $, on) => {
  const w = asks([...TO_JUDGE, 'Everywhere'], {
    edit: f => { (f.agents as Rec)['security-auditor'] = 'verify' },
  })
  const rig = await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('security-auditor'))
  expect(w.asked[0]?.text).toContain('claude-sonnet-5-5 at xhigh')
  expect(rig.specs).toEqual([OPUS])
  expect((routingOf(w).agents as Rec)['security-auditor']).toBe('judge')
  await runStep($, { ...highStep('a1'), model: OPUS })
  expect(rig.seen[rig.seen.length - 1]?.effort).toBe('xhigh')
})

test('change: an agent picks sonnet then high, the write phase', async (
  $, on) => {
  const w = asks(['Change', 'sonnet (work)', 'high', 'Everywhere'])
  const rig = await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('feater'))
  expect((routingOf(w).agents as Rec).feater).toBe('write')
  expect(rig.specs).toEqual([SONNET])
})

test('change: the current phase wins a tie, and counts as a Keep', async (
  $, on) => {
  const w = asks(['Change', 'sonnet (work)', 'medium'])
  await bootRun($, on, FABLE, w)
  await $.agent.spawn(spawnOf('Explore'))
  expect(w.asked).toHaveLength(3)
  expect(routingOf(w).changed).toEqual({})
  expect(confirmedOf(w).agents).toEqual({ Explore: 'explore' })
})

// ---- wave 3-C: /route forget -----------------------------------------------

const TWO = 'github.com/acme/two'
const FORGET_NOTE = 'other live sessions see it after /route reload'
const MODEL_LOCK = 'lib/tests/model-routing.test.sh'

/** A feater moved to judge, as a Change Everywhere would have left it. */
const movedFeater = (file: Rec): void => {
  (file.agents as Rec).feater = 'judge'
  file.changed = { agents: { feater: { from: 'implement', to: 'judge' } } }
  file.confirmed = { agents: { feater: 'judge' } }
}

/** Edits the inline routing.json with `extra` keys laid over it. */
const decisions = (extra: Rec) => (file: Rec): void => {
  Object.assign(file, extra)
}

/** A world with decisions in the file, for the forget tests. */
const forgetWorld = (extra: Rec, answers: string[] = []) =>
  newWorld({ edit: decisions(extra), answers })

test('forget: a confirmed skill is removed and asked again', async ($, on) => {
  const w = asks(['Keep', 'Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(await route($, 'forget feat')).toContain('forgot feat: 1 confirmed')
  expect(confirmedOf(w).skills).toBeUndefined()
  await typeFeat($)
  expect(w.asked).toHaveLength(2)
})

test('forget: /route pending lists a forgotten key again', async ($, on) => {
  const w = asks(['Keep'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  await route($, 'forget feat')
  const lines = (await route($, 'pending')).split('\n')
  expect(lines[1]).toBe('asked this session: none')
  expect(lines[2]).toContain('skills:feat')
})

test('forget: the answer closes on the other sessions\' reload', async (
  $, on) => {
  const w = forgetWorld({ confirmed: { skills: { feat: 'reflect' } } })
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget feat')).toMatch(new RegExp(`${FORGET_NOTE}$`))
})

test('forget: a changed agent goes back to its shipped phase', async (
  $, on) => {
  const w = newWorld({ edit: movedFeater })
  const rig = await bootRun($, on, FABLE, w)
  expect(await featerModel($, rig)).toBe(OPUS)
  await route($, 'forget feater')
  const file = routingOf(w)
  expect((file.agents as Rec).feater).toBe('implement')
  expect(file.changed).toEqual({})
  expect(file.confirmed).toEqual({})
  expect(await featerModel($, rig)).toBe(SONNET)
})

test('forget: a restored row names the frontmatter to realign', async (
  $, on) => {
  await bootRun($, on, FABLE, newWorld({ edit: movedFeater }))
  expect(await route($, 'forget feater')).toContain(
    ' (agents.feater → implement: sonnet at medium; if agents/feater.md ' +
    'was aligned to judge, set model: sonnet, effort: medium and its lock in ' +
    `${MODEL_LOCK}, then \`make test\`)`)
})

test('forget: a built-in agent restored names no file', async ($, on) => {
  const w = forgetWorld({
    agents: { Explore: 'write' },
    changed: { agents: { Explore: { from: 'explore', to: 'write' } } },
  })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget Explore')
  expect(out).toContain('(agents.Explore → explore: sonnet at medium)')
})

test('forget: the built-in Plan agent restored names no file', async (
  $, on) => {
  const w = forgetWorld({
    agents: { Plan: 'write' },
    changed: { agents: { Plan: { from: 'judge', to: 'write' } } },
  })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget Plan')
  expect(out).toContain('(agents.Plan → judge:')
  expect(out).not.toContain('agents/Plan.md')
})

test('forget all: a refused restore is kept, the rest removed', async (
  $, on) => {
  const w = forgetWorld({
    agents: { Explore: 'judge' },
    changed: { agents: { Explore: { from: 'explore', to: 'write' } } },
    confirmed: { skills: { feat: 'reflect' } },
  }, ['Forget'])
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget all')
  expect(out).toContain('1 restore(s) kept: agents.Explore: the row differs')
  expect(confirmedOf(w).skills).toBeUndefined()
  expect(routingOf(w).changed).toEqual(
    { agents: { Explore: { from: 'explore', to: 'write' } } })
})

test('forget: a phase is removed and the route tool asks again', async (
  $, on) => {
  const w = asks(['Keep', 'Later'])
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(await route($, 'forget orchestrate')).toContain('1 confirmed')
  expect(confirmedOf(w).phases).toBeUndefined()
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect(w.asked).toHaveLength(2)
})

const twoRepos = {
  projects: {
    [KEY]: { skills: { feat: 'plan' } },
    [TWO]: { skills: { feat: 'apply' }, agents: { feater: 'judge' } },
  },
}

test('forget: a name loses its exception in every repo', async ($, on) => {
  const w = forgetWorld(twoRepos)
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget feat')
  expect(out).toContain('2 project exception(s) removed')
  expect(routingOf(w).projects).toEqual({
    [TWO]: { agents: { feater: 'judge' } },
  })
})

test('forget: an undecided row has nothing to forget, no write', async (
  $, on) => {
  const w = newWorld()
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget status')).toBe('nothing to forget for status')
  expect(w.written).toEqual([])
})

test('forget: an unknown name has nothing to forget, no write', async (
  $, on) => {
  const w = newWorld()
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget zzz')).toContain('nothing to forget for zzz')
  expect(w.written).toEqual([])
})

test('forget: a key only asked this session is reset, no write', async (
  $, on) => {
  const w = asks(['Later', 'Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  const out = await route($, 'forget feat')
  expect(out).toContain('asked again at the next use, nothing was saved')
  expect(w.written).toEqual([])
  await typeFeat($)
  expect(w.asked).toHaveLength(2)
})

test('forget: an asked key the override decides is said so', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  w.files.set(HOME_FILE, '{"skills":{"feat":"plan"}}')
  await route($, 'reload')
  const out = await route($, 'forget feat')
  expect(out).toContain('still decided by ~/.claude/model-router.json')
})

for (const args of ['forget', 'forget a b']) {
  test(`forget: "${args}" is a usage line, no write`, async ($, on) => {
    const w = newWorld()
    await bootRun($, on, FABLE, w)
    expect(await route($, args)).toBe(
      'usage: /route forget <name|all|projects>')
    expect(w.written).toEqual([])
  })
}

test('forget: a row named all is reserved, said', async ($, on) => {
  const w = newWorld({ edit: f => { (f.skills as Rec).all = 'plan' } })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget all')
  expect(out).toContain('named all is reserved here: edit routing.json by hand')
})

/** `/route forget <args>` typed while a first-use dialog is held open. */
async function forgetDuringDialog($: Engine, w: World, args: string) {
  const held = deferred()
  const seen = deferred()
  w.gate = held.gate
  w.onAsk = seen.release
  const typing = typeFeat($)
  await seen.gate
  const out = await route($, args)
  held.release()
  await typing
  return out
}

test('forget: refused while a dialog is open, nothing written', async (
  $, on) => {
  const w = asks(['Later'])
  await bootRun($, on, FABLE, w)
  const out = await forgetDuringDialog($, w, 'forget feat')
  expect(out).toBe('answer the open dialog first')
  expect(w.written).toEqual([])
})

const confirmedFeat = { confirmed: { skills: { feat: 'reflect' } } }

test('forget all asks first: Cancel, then Forget', async ($, on) => {
  const w = forgetWorld({ ...confirmedFeat, ...twoRepos }, ['Cancel'])
  await bootRun($, on, FABLE, w)
  await route($, 'forget all')
  expect(w.asked[0]?.options).toEqual(['Cancel', 'Forget'])
  expect(w.asked[0]?.header).toBe('model-router')
})

test('forget all: the question counts what it removes', async ($, on) => {
  const w = forgetWorld({ ...confirmedFeat, ...twoRepos }, ['Cancel'])
  await bootRun($, on, FABLE, w)
  await route($, 'forget all')
  expect(w.asked[0]?.text).toBe('Forget 4 decisions: 0 row(s) restored, ' +
    '3 project exception(s) in 2 repos?')
})

test('forget all: Cancel writes nothing', async ($, on) => {
  const w = forgetWorld(confirmedFeat, ['Cancel'])
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget all')).toContain('cancelled, nothing written')
  expect(w.written).toEqual([])
})

for (const [what, answer] of [
  ['a dismissed dialog', REJECT],
  ['another answer', 'whenever'],
] as const) {
  test(`forget all: ${what} is a cancel`, async ($, on) => {
    const w = forgetWorld(confirmedFeat, [answer])
    await bootRun($, on, FABLE, w)
    expect(await route($, 'forget all')).toContain('cancelled')
    expect(w.written).toEqual([])
  })
}

test('forget all: nothing to forget skips the question', async ($, on) => {
  const w = newWorld({ answers: ['Forget'] })
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget all')).toBe('nothing to forget')
  expect(w.asked).toEqual([])
})

test('forget all: empties confirmed, changed and projects', async ($, on) => {
  const w = forgetWorld({
    agents: { feater: 'judge' },
    confirmed: { skills: { feat: 'reflect' }, agents: { feater: 'judge' } },
    changed: movedChange(),
    projects: twoRepos.projects,
  }, ['Forget'])
  await bootRun($, on, FABLE, w)
  await route($, 'forget all')
  const file = routingOf(w)
  expect([file.confirmed, file.changed, file.projects]).toEqual([{}, {}, {}])
})

/** The `changed` table of a feater moved to judge. */
function movedChange(): Rec {
  return { agents: { feater: { from: 'implement', to: 'judge' } } }
}

test('forget all: the rows come back, the counts are said', async ($, on) => {
  const w = forgetWorld({
    agents: { feater: 'judge' },
    confirmed: { skills: { feat: 'reflect' }, agents: { feater: 'judge' } },
    changed: movedChange(),
    projects: { [KEY]: { skills: { feat: 'plan' } } },
  }, ['Forget'])
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget all')
  expect(out).toContain('forgot all: 2 confirmed, 1 row(s) restored, ' +
    '1 project exception(s) removed')
  expect((routingOf(w).agents as Rec).feater).toBe('implement')
})

test('forget all: the asked set is cleared', async ($, on) => {
  const w = asks(['Keep', 'Forget', 'Later'])
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  await route($, 'forget all')
  await typeFeat($)
  expect(w.asked).toHaveLength(3)
})

test('forget all: the plan is recomputed on the file the write reads', async (
  $, on) => {
  const w = forgetWorld(confirmedFeat, ['Forget'])
  await bootRun($, on, FABLE, w)
  w.onAsk = () => {
    const file = routingOf(w)
    file.confirmed = {
      skills: { feat: 'reflect' },
      agents: { verifier: 'verify' },
    }
    w.files.set('routing', JSON.stringify(file))
  }
  const out = await route($, 'forget all')
  expect(out).toContain('2 confirmed')
  expect(routingOf(w).confirmed).toEqual({})
})

test('forget all: the file vanishing during the question saves nothing', async (
  $, on) => {
  const w = forgetWorld(confirmedFeat, ['Forget'])
  await bootRun($, on, FABLE, w)
  w.onAsk = () => { w.files.delete('routing') }
  expect(await route($, 'forget all')).toBe('forget refused: nothing saved')
  expect(w.written).toEqual([])
})

test('forget all: holds the dialog slot while it asks', async ($, on) => {
  const w = asks(['Forget'], { edit: decisions(confirmedFeat) })
  await bootRun($, on, FABLE, w)
  const held = deferred()
  const seen = deferred()
  w.gate = held.gate
  w.onAsk = seen.release
  const forgetting = route($, 'forget all')
  await seen.gate
  w.onAsk = undefined
  await typed($, '/status')
  await skillPrompt($, 'status')
  expect(w.asked).toHaveLength(1)
  held.release()
  await forgetting
})

test('forget all: a second forget is refused while the first asks', async (
  $, on) => {
  const w = forgetWorld(confirmedFeat, ['Cancel'])
  await bootRun($, on, FABLE, w)
  const held = deferred()
  const seen = deferred()
  w.gate = held.gate
  w.onAsk = seen.release
  const first = route($, 'forget all')
  await seen.gate
  expect(await route($, 'forget feat')).toBe('answer the open dialog first')
  held.release()
  await first
})

test('forget projects: only the project exceptions go', async ($, on) => {
  const w = forgetWorld({ ...confirmedFeat, ...twoRepos }, ['Forget'])
  await bootRun($, on, FABLE, w)
  await route($, 'forget projects')
  expect(routingOf(w).projects).toEqual({})
  expect(routingOf(w).confirmed).toEqual(confirmedFeat.confirmed)
})

test('forget projects: nothing to forget skips the question', async (
  $, on) => {
  const w = forgetWorld(confirmedFeat, ['Forget'])
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget projects')).toBe('nothing to forget')
  expect(w.asked).toEqual([])
})

/** A moved feater whose recorded change no longer matches the file. */
const brokenRestore = (changed: Rec, row = 'judge') => (file: Rec) => {
  (file.agents as Rec).feater = row
  file.changed = { agents: { feater: changed } }
}

for (const [why, changed, row, text] of [
  ['the row differs', { from: 'implement', to: 'judge' }, 'write',
    'differs from the recorded change'],
  ['from is no phase', { from: 'nosuch', to: 'judge' }, 'judge',
    'nosuch is not a known phase'],
  ['from is not a string', { from: 5, to: 'judge' }, 'judge',
    'no phase recorded'],
] as const) {
  test(`forget: a restore is refused when ${why}, entry kept`, async (
    $, on) => {
    const w = newWorld({ edit: brokenRestore(changed, row) })
    await bootRun($, on, FABLE, w)
    expect(await route($, 'forget feater')).toContain(text)
    expect(w.written).toEqual([])
    expect(routingOf(w).changed).toEqual({ agents: { feater: changed } })
  })
}

test('forget: a refused restore reports it next to what was removed', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    brokenRestore({ from: 'implement', to: 'judge' }, 'write')(f)
    f.confirmed = { agents: { feater: 'write' } }
  } })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget feater')
  expect(out).toContain('1 confirmed, 0 row(s) restored')
  expect(out).toContain('1 restore(s) kept: agents.feater:')
})

test('forget: the override still setting the row is said', async ($, on) => {
  const w = newWorld({
    edit: movedFeater,
    home: { agents: { feater: 'judge' } },
  })
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget feater')).toContain(
    '; ~/.claude/model-router.json still sets feater and wins here')
})

test('forget: a restored skill the run still holds says /route clear', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    (f.skills as Rec).feat = 'plan'
    f.changed = { skills: { feat: { from: 'reflect', to: 'plan' } } }
    f.confirmed = { skills: { feat: 'plan' } }
  } })
  await bootRun($, on, FABLE, w)
  await typed($, '/feat add a thing')
  await skillPrompt($, 'feat')
  expect(await route($, 'forget feat')).toContain(
    '; current run may keep plan: /route clear to apply')
})

/** A feat moved to plan, as a Change Everywhere would have left it. */
const movedFeat = (file: Rec): void => {
  (file.skills as Rec).feat = 'plan'
  file.changed = { skills: { feat: { from: 'reflect', to: 'plan' } } }
  file.confirmed = { skills: { feat: 'plan' } }
}

const KEEPS = 'current run may keep'

for (const answer of ['Cancel', REJECT]) {
  test(`forget projects asks first: ${answer} saves nothing`, async (
    $, on) => {
    const w = forgetWorld(twoRepos, [answer])
    await bootRun($, on, FABLE, w)
    expect(await route($, 'forget projects')).toContain('cancelled')
    expect(w.asked[0]?.options).toEqual(['Cancel', 'Forget'])
    expect(w.written).toEqual([])
  })
}

test('forget: a restored agent or other-phase skill keeps no run', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    movedFeat(f)
    f.changed = { ...(f.changed as Rec), agents: {
      feater: { from: 'implement', to: 'plan' } } }
    ;(f.agents as Rec).feater = 'plan'
    ;(f.skills as Rec).status = 'apply'
    ;(f.changed as Rec).skills = { ...((f.changed as Rec).skills as Rec),
      status: { from: 'mechanical', to: 'apply' } }
  } })
  await bootRun($, on, FABLE, w)
  await typed($, '/feat add a thing')
  await skillPrompt($, 'feat')
  expect(await route($, 'forget feater')).not.toContain(KEEPS)
  expect(await route($, 'forget status')).not.toContain(KEEPS)
})

test('forget: a phase the model routed is not a run to keep', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    (f.skills as Rec).status = 'plan'
    f.changed = { skills: { status: { from: 'mechanical', to: 'plan' } } }
    f.confirmed = { skills: { status: 'plan' } }
  } })
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })
  expect(await route($, 'forget status')).not.toContain(KEEPS)
})

test('forget: no machine pin on the name, no "wins here"', async ($, on) => {
  const w = newWorld({
    edit: decisions(confirmedFeat),
    home: { skills: { hotfix: 'plan' } },
  })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget feat')
  expect(out).toContain('forgot feat: 1 confirmed')
  expect(out).not.toContain('wins here')
})

test('forget: a restored skill row names its SKILL.md to realign', async (
  $, on) => {
  await bootRun($, on, FABLE, newWorld({ edit: movedFeat }))
  expect(await route($, 'forget feat')).toContain(
    'if skills/feat/SKILL.md was aligned to plan, set model: ')
})

test('forget: a missing routing.json saves nothing', async ($, on) => {
  const w = newWorld({ routing: 'absent' })
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget feat')).toContain('nothing saved')
  expect(w.written).toEqual([])
})

test('forget: a rebuild failing after the write is said', async ($, on) => {
  const w = forgetWorld(confirmedFeat)
  await bootRun($, on, FABLE, w)
  w.onWrite = () => { w.files.set(HOME_FILE, '{nope') }
  expect(await route($, 'forget feat')).toBe(
    'saved, config not rebuilt: /route reload')
  expect(routingOf(w).confirmed).toEqual({})
})

test('forget: a failing write is not applied', async ($, on) => {
  const w = forgetWorld(confirmedFeat)
  await bootRun($, on, FABLE, w)
  w.failWrite = true
  expect(await route($, 'forget feat')).toContain('forget not applied')
  expect(routingOf(w).confirmed).toEqual(confirmedFeat.confirmed)
})

test('forget: the route tool cannot forget', async ($, on) => {
  const w = forgetWorld(confirmedFeat)
  await bootRun($, on, FABLE, w)
  await $.tool.call({ tool: ROUTE_TOOL, clear: true })
  expect(w.written).toEqual([])
  expect(routingOf(w).confirmed).toEqual(confirmedFeat.confirmed)
})

test('forget: a forget input to the route tool is refused', async (
  $, on) => {
  const w = forgetWorld(confirmedFeat)
  await bootRun($, on, FABLE, w)
  for (const input of [{ forget: 'feat' }, { phase: 'forget' }]) {
    const out = await $.tool.call({ tool: ROUTE_TOOL, ...input })
    expect(JSON.stringify(out)).toContain('"deny"')
  }
  expect(w.written).toEqual([])
  expect(routingOf(w).confirmed).toEqual(confirmedFeat.confirmed)
})

test('forget projects: the asked set is kept, no re-ask', async ($, on) => {
  const w = newWorld({
    ask: true,
    edit: decisions({ projects: { [TWO]: twoRepos.projects[TWO] } }),
    answers: ['Later', 'Forget'],
  })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  await route($, 'forget projects')
  await typeFeat($)
  expect(w.asked).toHaveLength(2)
  expect(w.asked[1]?.options).toEqual(['Cancel', 'Forget'])
})

test('forget: a non-composer origin is refused, nothing written', async (
  $, on) => {
  const w = forgetWorld(confirmedFeat)
  await bootRun($, on, FABLE, w)
  const out = await $.command.run({
    command: 'route',
    args: 'forget feat',
    origin: { kind: 'plugin', name: 'x' },
    presentation: { isFullscreen: false, columns: 80 },
  })
  expect(out.text).toContain('user-only')
  expect(w.written).toEqual([])
})

// ---- wave 4-A: transition logs --------------------------------------------

type LoggedOpts = {
  model?: string
  answeredBy?: (planned: string) => string // the model a step answers on
  world?: World
  verbose?: boolean // default true
  stepMark?: string // the bottom step pushes this into `logs`
}

const usageFor = (model: string) => ({
  model,
  input_tokens: 0,
  output_tokens: 0,
  cache_read_input_tokens: 0,
  cache_creation_input_tokens: 0,
})

type Logged = { logs: string[]; seen: Seen[] }

/** A run with every bottom hook a logged scenario needs, verbose on. */
async function bootLogged(
  $: Engine,
  on: On,
  o: LoggedOpts = {},
): Promise<Logged> {
  const logs = recordLogs(on)
  const seen: Seen[] = []
  let spawned = 0
  on('turn.step', async function* ($, e) {
    seen.push({ model: e.model, effort: e.effort })
    if (o.stepMark !== undefined) logs.push(o.stepMark)
    return {
      turnId: e.turnId,
      index: e.index,
      answer: '',
      toolUses: [],
      stopReason: 'end_turn' as const,
      usage: o.answeredBy ? usageFor(o.answeredBy(e.model)) : null,
    }
  })
  on('prompt.submit', ($, e) => ({ text: e.text }))
  on('turn.complete', () => ({ text: '' }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  on('tool.call', { tool: 'Skill' }, () => ({
    result: { success: true, commandName: 'bottom' },
  }))
  on('tool.call', { tool: 'Agent' }, () => ({
    result: {
      status: 'async_launched' as const,
      agentId: 'a1',
      description: 'd',
      prompt: 'p',
      outputFile: '/tmp/o',
    },
  }))
  on('agent.spawn', ($, e) => ({
    model: e.model ?? e.parentModel,
    agentId: `a${++spawned}`,
  }))
  await boot($, on, o.model ?? FABLE, 1000, o.world ?? newWorld())
  if (o.verbose !== false) await route($, 'verbose on')
  logs.splice(0)
  return { logs, seen }
}

const mainWord = (from: string, to: string, why: string): string =>
  `main: ${from} → ${to} (${why})`

test('logs: a main that never changes logs nothing', async ($, on) => {
  const { logs } = await bootLogged($, on)
  for (let i = 0; i < 3; i++) await runStep($, highStep())
  expect(logs).toEqual([])
})

test('logs: a route-tool plan logs one line, not one per step', async (
  $, on) => {
  const { logs } = await bootLogged($, on)
  await planRoute($)
  await runStep($, highStep())
  await runStep($, highStep())
  expect(logs).toEqual([
    mainWord('fable/high', 'fable/xhigh', 'plan: route tool'),
  ])
})

test('logs: a typed skill names itself as the cause', async ($, on) => {
  const { logs } = await bootLogged($, on)
  await typeFeat($)
  await runStep($, stepInput())
  expect(logs).toEqual([
    mainWord('fable/low', 'fable/high', 'reflect: skill /feat'),
  ])
})

test('logs: an upgrade rides on the same line', async ($, on) => {
  const { logs } = await bootLogged($, on, { model: SONNET })
  await typeFeat($)
  await runStep($, { ...highStep(), model: SONNET })
  expect(logs).toEqual([
    mainWord('sonnet/high', 'fable/high', 'reflect: skill /feat, upgrade'),
  ])
})

test('logs: a downgrade is a switch', async ($, on) => {
  const { logs } = await bootLogged($, on)
  await route($, 'mechanical')
  await runStep($, highStep())
  expect(logs).toEqual([
    mainWord('fable/high', 'haiku/low',
      'mechanical: sticky /route, switch'),
  ])
})

test('logs: a model down names the alias it left', async ($, on) => {
  const { logs } = await bootLogged($, on)
  await runStep($, highStep())
  await failWith($, 'rate_limit')
  logs.splice(0)
  await runStep($, highStep())
  expect(logs).toEqual([
    mainWord('fable/high', 'opus/high', 'session, fallback: fable down'),
  ])
})

test('logs: derived orchestrate logs once per turn', async ($, on) => {
  const { logs } = await bootLogged($, on)
  await runStep($, highStep())
  await dispatch($)
  await runStep($, highStep())
  await agentEnds($)
  await runStep($, highStep())
  await dispatch($)
  await runStep($, highStep())
  const waves = logs.filter(l => l.includes('orchestrate: dispatch'))
  expect(waves).toEqual([
    mainWord('fable/high', 'fable/medium', 'orchestrate: dispatch'),
  ])
})

test('logs: an ultrathink floor names the prompt floor', async ($, on) => {
  const { logs } = await bootLogged($, on)
  await ultrathink($)
  await runStep($, highStep())
  expect(logs).toEqual([
    mainWord('fable/high', 'fable/max', 'escalate: prompt floor'),
  ])
})

test('logs: a sticky /route names itself', async ($, on) => {
  const { logs } = await bootLogged($, on)
  await route($, 'xhigh')
  await runStep($, highStep())
  expect(logs).toEqual([
    mainWord('fable/high', 'fable/xhigh', 'custom: sticky /route'),
  ])
})

test('logs: a default prompt rule says prompt rule', async ($, on) => {
  const { logs } = await bootLogged($, on)
  await typed($, 'explain why it fails')
  await runStep($, stepInput())
  expect(logs).toEqual([
    mainWord('fable/low', 'fable/high', 'reflect: prompt rule'),
  ])
})

test('logs: after /clear the first step compares to the engine', async (
  $, on) => {
  const { logs } = await bootLogged($, on)
  await route($, 'xhigh')
  await runStep($, highStep())
  logs.splice(0)
  await clearOf($)
  await runStep($, highStep())
  expect(logs).toEqual([])
})

test('logs: /route on after off compares to the engine', async ($, on) => {
  const { logs } = await bootLogged($, on)
  await route($, 'xhigh')
  await runStep($, highStep())
  await endTurn($)
  await route($, 'off')
  await route($, 'on')
  await runStep($, highStep())
  expect(logs.filter(l => l.includes('sticky'))).toHaveLength(2)
})

test('logs: a failing log never unroutes the step', async ($, on) => {
  const { logs, seen } = await bootLogged($, on)
  await route($, 'xhigh')
  const poison = { toString: 1 } // String(poison) throws
  await runStep($, { ...highStep(), effort: poison as never })
  expect(seen[seen.length - 1]?.effort).toBe('xhigh')
  expect(logs.join('\n')).toContain('turn.step log failed')
})

test('logs: verbose off logs no transition', async ($, on) => {
  const { logs } = await bootLogged($, on, { verbose: false })
  await planRoute($)
  await runStep($, highStep())
  await typeFeat($)
  await $.agent.spawn(spawnOf('feater'))
  expect(logs).toEqual([])
})

test('logs: the transition line precedes the step below it', async (
  $, on) => {
  const { logs } = await bootLogged($, on, { stepMark: 'STEP' })
  await planRoute($)
  await runStep($, highStep())
  expect(logs).toEqual([
    mainWord('fable/high', 'fable/xhigh', 'plan: route tool'),
    'STEP',
  ])
})

test('logs: switch warnings keep their exact texts', async ($, on) => {
  const logs = recordLogs(on)
  const home = { verbose: 'ON', enabled: 'no' }
  await bootRun($, on, FABLE, newWorld({ home }))
  expect(logs).toContain('config "verbose" is not a boolean; ignored')
  expect(logs).toContain(
    'model-router: config "enabled" is not a boolean; router off (fail closed)')
  expect(await route($, 'show')).toContain('router: off (config)')
})

for (const bad of ['ON', 1, null]) {
  test(`logs: verbose ${JSON.stringify(bad)} falls back to off`, async (
    $, on) => {
    const logs = recordLogs(on)
    await bootRun($, on, FABLE, newWorld({ home: { verbose: bad } }))
    expect(logs.filter(l => l.includes('"verbose" is not a boolean')))
      .toHaveLength(1)
    expect(await route($, 'show')).toContain('verbose: off')
  })
}

test('logs: verbose true in the override turns the lines on', async (
  $, on) => {
  await bootRun($, on, FABLE, newWorld({ home: { verbose: true } }))
  expect(await route($, 'show')).toContain('verbose: on')
})

/** What each of the old firehose lines would have been triggered by. */
const LEGACY: [string, string, ($: Engine) => Promise<unknown>][] = [
  ['step', 'step ', $ => runStep($, highStep())],
  ['answered by', 'answered by', $ => runStep($, highStep())],
  ['skill path', 'skill ', $ => typeFeat($)],
  ['route json', 'route main', $ => planRoute($)],
  ['spawn', 'spawn ', $ => $.agent.spawn(spawnOf('feater'))],
]

for (const [name, text, act] of LEGACY) {
  test(`logs: the old ${name} line is gone at true`, async ($, on) => {
    const { logs } = await bootLogged($, on)
    await act($)
    await runStep($, highStep())
    expect(logs.filter(l => l.includes(text))).toEqual([])
  })
}

// ---- wave 4-A: agent lines ----------------------------------------------

const handoffs = (logs: string[]): string[] =>
  logs.filter(l => l.includes(' → agent '))

/** A main step first, so the hand-off starts from fable/high. */
async function afterMainStep($: Engine, on: On, o: LoggedOpts = {}) {
  const run = await bootLogged($, on, o)
  await runStep($, highStep())
  return run
}

test('logs: a rowed spawn is one hand-off line, then silence', async (
  $, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater'))
  const line = 'main fable/high → agent feater sonnet/medium ' +
    '(row implement, row)'
  expect(logs).toEqual([line])
  await runStep($, { ...highStep('a1'), model: SONNET })
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(logs).toEqual([line])
})

test('logs: an explicit model is its own cause', async ($, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater', { model: 'opus' }))
  expect(logs).toEqual([
    'main fable/high → agent feater opus/medium ' +
      '(explicit, row)',
  ])
})

test('logs: an explicit effort is one line, then silence', async ($, on) => {
  const { logs } = await afterMainStep($, on)
  await $.tool.call({
    tool: 'Agent', description: 'd', prompt: 'p', effort: 'low',
    tool_use_id: 't1',
  })
  await $.agent.spawn(spawnOf('feater'))
  const line = 'main fable/high → agent feater sonnet/low ' +
    '(row implement, explicit)'
  expect(logs).toEqual([line])
  await runStep($, { ...stepInput('a1'), model: SONNET })
  expect(logs).toEqual([line])
})

test('logs: a haiku spawn shows its effort, then silence', async (
  $, on) => {
  const world = newWorld({
    edit: f => { (f.agents as Rec).feater = 'mechanical' },
  })
  const { logs } = await afterMainStep($, on, { world })
  await $.agent.spawn(spawnOf('feater'))
  const line = 'main fable/high → agent feater haiku/low ' +
    '(row mechanical, row)'
  expect(logs).toEqual([line])
  await runStep($, { ...highStep('a1'), model: HAIKU })
  expect(logs).toEqual([line])
})

test('logs: three parallel challengers are one hand-off line', async (
  $, on) => {
  const { logs } = await afterMainStep($, on)
  await Promise.all([1, 2, 3].map(() =>
    $.agent.spawn(spawnOf('plan-challenger'))))
  expect(handoffs(logs)).toHaveLength(1)
})

test('logs: two agent types to one model are two hand-offs', async (
  $, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater'))
  await $.agent.spawn(spawnOf('Explore'))
  expect(handoffs(logs)).toHaveLength(2)
})

test('logs: a haiku 4 spawn shows no effort, then silence', async (
  $, on) => {
  const world = newWorld({
    ...HAIKU_4_HOME,
    edit: f => { (f.agents as Rec).feater = 'mechanical' },
  })
  const { logs } = await afterMainStep($, on, { world })
  await $.agent.spawn(spawnOf('feater'))
  const line = 'main fable/high → agent feater haiku/- ' +
    '(row mechanical, row)'
  expect(logs).toEqual([line])
  await runStep($, { ...highStep('a1'), model: HAIKU_4 })
  expect(logs).toEqual([line])
})

test('logs: an unrowed haiku spawn is silent at its first step', async (
  $, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('unrowed', { model: 'haiku' }))
  const line = 'main fable/high → agent unrowed haiku/- (explicit, engine)'
  expect(logs).toEqual([line])
  await runStep($, { ...highStep('a1'), model: HAIKU })
  expect(logs).toEqual([line])
})

test('logs: one agent type to two models is two hand-offs', async (
  $, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater'))
  await $.agent.spawn(spawnOf('feater', { model: 'opus' }))
  expect(handoffs(logs)).toHaveLength(2)
})

test('logs: a tier moved up in-tier names the alias that was down', async (
  $, on) => {
  const { logs } = await bootLogged($, on)
  await switchTo($, OPUS, SONNET, 'auto')
  await $.agent.spawn(spawnOf('plan-challenger'))
  expect(handoffs(logs)).toEqual([
    'main fable/- → agent plan-challenger fable/xhigh ' +
      '(fallback: opus down, row)',
  ])
})

test('logs: a tier down keeps the frontmatter, said as such', async (
  $, on) => {
  const { logs } = await bootLogged($, on)
  await switchTo($, OPUS, SONNET, 'auto')
  await switchTo($, FABLE, SONNET, 'auto')
  await $.agent.spawn(spawnOf('plan-challenger'))
  expect(handoffs(logs)[0]).toContain('(frontmatter, row)')
})

test('logs: an in-agent route tool move is one line', async ($, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater'))
  logs.splice(0)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'judge', agentId: 'a1' })
  await runStep($, { ...highStep('a1'), model: SONNET })
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(logs).toEqual([
    'agent feater: sonnet/medium → sonnet/xhigh (route tool)',
  ])
})

test('logs: an agent moving twice logs both moves', async ($, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater'))
  logs.splice(0)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'judge', agentId: 'a1' })
  await runStep($, { ...highStep('a1'), model: SONNET })
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'implement', agentId: 'a1' })
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(logs).toHaveLength(2)
  expect(logs[1]).toContain('sonnet/xhigh → sonnet/medium (route tool)')
})

test('logs: an in-agent skill move names the skill', async ($, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater'))
  logs.splice(0)
  await loadSkill($, 'status', 'a1')
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(logs).toEqual([
    'agent feater: sonnet/medium → sonnet/low (skill status)',
  ])
})

const answers = (logs: string[]): string[] =>
  logs.filter(l => l.includes('answered by'))

/** One agent step on the planned model, the engine answering on `by`. */
async function agentAnswer($: Engine, on: On, by: string, planned = SONNET) {
  const run = await afterMainStep($, on, { answeredBy: () => by })
  await $.agent.spawn(spawnOf('feater'))
  await runStep($, { ...highStep('a1'), model: planned })
  await runStep($, { ...highStep('a1'), model: planned })
  return run
}

test('logs: an agent answered by another model is said once', async (
  $, on) => {
  const { logs } = await agentAnswer($, on, OPUS)
  expect(answers(logs)).toEqual([
    'agent feater answered by opus instead of sonnet',
  ])
})

test('logs: a [1m] suffix alone is not an answer anomaly', async ($, on) => {
  const { logs } = await agentAnswer($, on, SONNET, `${SONNET}[1m]`)
  expect(answers(logs)).toEqual([])
})

test('logs: a [1m] usage against a bare plan is no anomaly', async (
  $, on) => {
  const { logs } = await agentAnswer($, on, `${SONNET}[1m]`)
  expect(answers(logs)).toEqual([])
})

test('logs: a second agent answering off-plan logs its own line', async (
  $, on) => {
  const { logs } = await afterMainStep($, on, { answeredBy: () => OPUS })
  await $.agent.spawn(spawnOf('feater'))
  await $.agent.spawn(spawnOf('Explore'))
  for (const id of ['a1', 'a2']) {
    await runStep($, { ...highStep(id), model: SONNET })
    await runStep($, { ...highStep(id), model: SONNET })
  }
  expect(answers(logs)).toHaveLength(2)
})

test('logs: one agent answering two off-plan models logs twice', async (
  $, on) => {
  let n = 0
  const { logs } = await afterMainStep($, on, {
    answeredBy: () => (++n % 2 ? OPUS : FABLE) })
  await $.agent.spawn(spawnOf('feater'))
  for (let i = 0; i < 4; i++) {
    await runStep($, { ...highStep('a1'), model: SONNET })
  }
  expect(answers(logs)).toHaveLength(2)
})

test('logs: an unanswered usage says nothing', async ($, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater'))
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(answers(logs)).toEqual([])
})

test('logs: main answered by another model says nothing here', async (
  $, on) => {
  const { logs } = await bootLogged($, on, { answeredBy: () => OPUS })
  await runStep($, highStep())
  expect(answers(logs)).toEqual([])
  expect(logs).toEqual([]) // no bookkeeping warning either
})

test('logs: verbose off says no answer anomaly either', async ($, on) => {
  const { logs } = await bootLogged($, on, {
    answeredBy: () => OPUS, verbose: false })
  await $.agent.spawn(spawnOf('feater'))
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(answers(logs)).toEqual([])
})

// ---- wave 4-A: log guards ------------------------------------------------

const CTRL = '\u0007' // a control char inside a name
const LONG = `${'a'.repeat(30)}${CTRL}${'b'.repeat(30)}`
const CUT = `${'a'.repeat(30)}${'b'.repeat(9)}…` // 40 clean code points
const hasCtrl = (text: string): boolean => /[\p{Cc}\p{Cf}]/u.test(text)

/** A phase named LONG (with a bidi mark), as a routing.json may hold it. */
const hostilePhase = `${'a'.repeat(30)}\u202e${'b'.repeat(30)}`
const withPhase = (f: Rec): void => {
  (f.phases as Rec)[hostilePhase] = { tier: 'best', effort: 'xhigh' }
}

test('logs: two dispatches in one turn are one hand-off, main moved between',
  async ($, on) => {
    const { logs } = await afterMainStep($, on)
    await $.agent.spawn(spawnOf('feater'))
    await route($, 'xhigh')
    await runStep($, highStep())
    await $.agent.spawn(spawnOf('feater'))
    expect(handoffs(logs)).toHaveLength(1)
  })

test('logs: an agent type is cleaned in the hand-off line', async (
  $, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf(LONG, { model: 'opus' }))
  expect(handoffs(logs)).toHaveLength(1)
  expect(handoffs(logs)[0]).toContain(`agent ${CUT} `)
  expect(hasCtrl(logs.join('\n'))).toBe(false)
})

test('logs: a model id is cleaned in the hand-off line', async ($, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('feater', { model: `m${LONG}` }))
  expect(handoffs(logs)).toHaveLength(1)
  expect(handoffs(logs)[0]).toContain(
    `feater m${'a'.repeat(30)}${'b'.repeat(8)}…/`)
  expect(hasCtrl(logs.join('\n'))).toBe(false)
})

test('logs: an agent type is cleaned in a later move line', async (
  $, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf(LONG, { model: 'opus' }))
  logs.splice(0)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'judge', agentId: 'a1' })
  await runStep($, { ...highStep('a1'), model: OPUS })
  expect(logs).toHaveLength(1)
  expect(logs[0]).toContain(`agent ${CUT}: `)
  expect(hasCtrl(logs[0] ?? '')).toBe(false)
})

test('logs: an unchanged sticky /route logs once across turns', async (
  $, on) => {
  const { logs } = await bootLogged($, on)
  await route($, 'xhigh')
  for (let i = 0; i < 3; i++) {
    await runStep($, highStep())
    await endTurn($)
  }
  expect(logs.filter(l => l.includes('sticky /route'))).toHaveLength(1)
})

test('logs: an engine-picked effort is named in the hand-off', async (
  $, on) => {
  const { logs } = await afterMainStep($, on)
  await $.agent.spawn(spawnOf('stranger', { model: 'opus' }))
  expect(handoffs(logs)).toHaveLength(1)
  expect(handoffs(logs)[0]).toContain('(explicit, engine)')
})

// ---- wave 4-A: residuals of waves 3-A, 3-B, 3-C ---------------------------

test('residual a: a failing forget write answers without the cause', async (
  $, on) => {
  const w = forgetWorld(confirmedFeat)
  await bootRun($, on, FABLE, w)
  w.failWrite = true
  const out = await route($, 'forget feat')
  expect(out).toBe('forget not applied, see the log')
})

test('residual a: a failing forget write logs the cause', async ($, on) => {
  const logs = recordLogs(on)
  const w = forgetWorld(confirmedFeat)
  await bootRun($, on, FABLE, w)
  w.failWrite = true
  await route($, 'forget feat')
  expect(logs.some(l => l.startsWith('forget failed: ')))
    .toBe(true)
})

test('residual a: a failing ask write answers without the cause', async (
  $, on) => {
  const logs = recordLogs(on)
  const w = newWorld()
  await bootRun($, on, FABLE, w)
  w.failWrite = true
  expect(await route($, 'ask off')).toBe('ask not applied, see the log')
  expect(logs.some(l => l.startsWith('ask failed: ')))
    .toBe(true)
})

test('residual a: an ask saved but not rebuilt says so', async ($, on) => {
  const w = newWorld()
  await bootRun($, on, FABLE, w)
  w.onWrite = () => { w.files.set(HOME_FILE, '{nope') }
  expect(await route($, 'ask off')).toBe(
    'ask saved, config not rebuilt: /route reload')
  expect(routingOf(w).ask).toBe(false)
})

const ODD = 'x‮y' // a bidi override inside a name

const bidi = '‮'

test('residual b: a restored row name is cleaned in the answer', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    (f.skills as Rec)[ODD] = 'plan'
    f.changed = { skills: { [ODD]: { from: 'reflect', to: 'plan' } } }
  } })
  await bootRun($, on, FABLE, w)
  const out = await route($, `forget ${ODD}`)
  expect(out).toContain('(skills.xy → reflect:')
})

test('residual b: a restored row\'s old phase is cleaned too', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    (f.skills as Rec).feat = `pl${bidi}an`
    f.changed = { skills: { feat: { from: 'reflect', to: `pl${bidi}an` } } }
  } })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget feat')
  expect(out).toContain('was aligned to plan,')
  expect(out).not.toContain(bidi)
})

test('residual b: a refused restore\'s phase is cleaned', async ($, on) => {
  const w = newWorld({ edit: brokenRestore(
    { from: `no${bidi}such`, to: 'judge' }) })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget feater')
  expect(out).toContain('nosuch is not a known phase')
  expect(out).not.toContain(bidi)
})

test('residual b: a refused restore\'s row name is cleaned', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    f.changed = { skills: { [ODD]: { from: 5, to: 'plan' } } }
  } })
  await bootRun($, on, FABLE, w)
  const out = await route($, `forget ${ODD}`)
  expect(out).toContain('skills.xy: no phase recorded')
})

test('residual b: a long row name is cut in the answer only', async (
  $, on) => {
  const name = 'a'.repeat(45)
  const w = newWorld({ edit: f => {
    (f.skills as Rec)[name] = 'plan'
    f.changed = { skills: { [name]: { from: 'reflect', to: 'plan' } } }
  } })
  await bootRun($, on, FABLE, w)
  const out = await route($, `forget ${name}`)
  expect(out).toContain(`(skills.${'a'.repeat(39)}… → reflect:`)
  expect((routingOf(w).skills as Rec)[name]).toBe('reflect')
})

test('residual c: a name outside the skill charset names no file', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    (f.agents as Rec)['../x'] = 'judge'
    f.changed = { agents: { '../x': { from: 'implement', to: 'judge' } } }
  } })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget ../x')
  expect(out).toContain('1 row(s) restored')
  expect(out).not.toContain('was aligned to')
})

/** A file whose `kind` table holds `__proto__` as an OWN key. */
const protoRow = (kind: string, entry: unknown) => (f: Rec): void => {
  const rows = (f[kind] ?? {}) as Rec
  Object.defineProperty(rows, '__proto__', {
    value: entry, enumerable: true, configurable: true, writable: true,
  })
  f[kind] = rows
}

test('residual d: a __proto__ restore is refused, plan and apply agree', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    protoRow('skills', 'plan')(f)
    const changed: Rec = {}
    protoRow('changed', changed)(f)
    const skills: Rec = {}
    Object.defineProperty(skills, '__proto__', {
      value: { from: 'reflect', to: 'plan' },
      enumerable: true, configurable: true, writable: true,
    })
    f.changed = { skills }
  } })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget __proto__')
  expect(out).toContain('skills.__proto__: reserved name')
  expect(w.written).toEqual([])
})

test('residual e: a changed.phases entry is never restored', async ($, on) => {
  const w = newWorld({ edit: f => {
    (f.phases as Rec).plan = 'reflect'
    f.changed = { phases: { plan: { from: 'reflect', to: 'reflect' } } }
  } })
  await bootRun($, on, FABLE, w)
  expect(await route($, 'forget plan')).toBe('nothing to forget for plan')
  expect(w.written).toEqual([])
})

/** The efforts the Change chain offers for fable, from the second question. */
async function fableEfforts($: Engine, on: On, fx: Fixture) {
  const w = asks(['Change', 'fable (best)', 'Later'], fx)
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  return w.asked[2]?.options
}

const FABLE_EFFORTS = ['medium', 'high', 'xhigh', 'max']

test('residual f: a null phase in the file is ignored, no crash', async (
  $, on) => {
  const edit = (f: Rec): void => { (f.phases as Rec).plan = null }
  expect(await fableEfforts($, on, { edit })).toEqual(FABLE_EFFORTS)
})

test('residual f: a file without phases offers the code defaults', async (
  $, on) => {
  const edit = (f: Rec): void => { delete f.phases }
  expect(await fableEfforts($, on, { edit })).toEqual(FABLE_EFFORTS)
})

const CUSTOM_CHEAP = { phases: { custom: { tier: 'cheap', effort: 'high' } } }

test('residual f: an override-only phase is not offered', async ($, on) => {
  const w = asks(['Change', 'haiku (cheap)', 'Later'], { home: CUSTOM_CHEAP })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(w.asked[2]?.text).toContain('Use mechanical for feat')
})

test('residual f: an override-only phase is never written', async ($, on) => {
  const w = asks(['Change', 'haiku (cheap)', 'high', 'Everywhere'],
    { home: CUSTOM_CHEAP })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect((routingOf(w).skills as Rec).feat).toBe('reflect')
  expect(w.written).toEqual([])
})

test('residual f: the target is a shipped phase the override redefines', async (
  $, on) => {
  const w = asks(['Change', 'haiku (cheap)', 'Everywhere'], {
    home: { phases: { mechanical: { tier: 'work', effort: 'medium' } } },
  })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect((routingOf(w).skills as Rec).feat).toBe('mechanical')
})

test('residual f: an alias only an override phase uses toasts, Later', async (
  $, on) => {
  const toasts = recordToasts(on)
  const w = asks(['Change', 'haiku (cheap)'], {
    edit: lowMechanical,
    home: { phases: { custom: { tier: 'cheap', effort: 'low' } } },
  })
  await bootRun($, on, FABLE, w)
  await typeFeat($)
  expect(toasts).toContain(
    'no shipped phase uses haiku: add one to routing.json')
  expect(w.written).toEqual([])
})

test('residual b: a hostile restored phase is cleaned in the clause', async (
  $, on) => {
  const w = newWorld({ edit: f => {
    withPhase(f)
    ;(f.skills as Rec).feat = 'plan'
    f.changed = { skills: { feat: { from: hostilePhase, to: 'plan' } } }
  } })
  await bootRun($, on, FABLE, w)
  const out = await route($, 'forget feat')
  expect(out).toContain(`skills.feat → ${CUT}:`)
  expect(hasCtrl(out)).toBe(false)
})

// ---- wave 4-A: hostile skill name ----------------------------------------

const HOSTILE_SKILL = `${'a'.repeat(30)}‮${CTRL}${'b'.repeat(30)}`
const skillWorld = (): World => newWorld({ edit: f => {
  (f.skills as Rec)[HOSTILE_SKILL] = 'plan'
} })

/** The name a line shows after `marker`, up to the closing char. */
const nameAfter = (line: string, marker: string, end: string): string =>
  line.slice(line.indexOf(marker) + marker.length).split(end)[0]

test('logs: a hostile skill name is cleaned in the main line', async (
  $, on) => {
  const { logs } = await bootLogged($, on, { world: skillWorld() })
  await runStep($, highStep())
  logs.splice(0)
  await loadSkill($, HOSTILE_SKILL)
  await runStep($, { ...highStep(), effort: 'low' as const })
  const line = logs.find(l => l.includes('skill /')) ?? ''
  const name = nameAfter(line, 'skill /', ')')
  expect(name).not.toBe('')
  expect(hasCtrl(line)).toBe(false)
  expect([...name].length).toBeLessThanOrEqual(40)
})

test('logs: a hostile skill name is cleaned in the agent cause', async (
  $, on) => {
  const { logs } = await afterMainStep($, on, { world: skillWorld() })
  await $.agent.spawn(spawnOf('feater'))
  logs.splice(0)
  await loadSkill($, HOSTILE_SKILL, 'a1')
  await runStep($, { ...highStep('a1'), model: SONNET })
  const line = logs.find(l => l.includes('(skill ')) ?? ''
  const name = nameAfter(line, '(skill ', ')')
  expect(name).not.toBe('')
  expect(hasCtrl(line)).toBe(false)
  expect([...name].length).toBeLessThanOrEqual(40)
})

test('logs: an ended agent forgets its answer marks (reused id)', async (
  $, on) => {
  const { logs } = await agentAnswer($, on, OPUS)
  await agentEnds($)
  await $.agent.spawn(spawnOf('feater'))
  await runStep($, { ...highStep('a1'), model: SONNET })
  expect(answers(logs)).toHaveLength(2)
})

// ---- wave 4-B: prompt classifier -----------------------------------------

type Ask = { text: string; labels: readonly string[]; options: unknown }
type Reply = (n: number) => Promise<string | undefined> | string | undefined
type Cls = {
  asks: Ask[]
  seen: Seen[]
  clock: MockClock
  logs: string[]
  toasts: string[]
  status: string[]
  world: World
}
type ClsOpts = {
  reply?: Reply
  model?: string
  world?: World
  verbose?: boolean
  tokens?: number // context size the usage hook answers (default 1000)
}

const PLAIN = 'refactor the billing module please'
const PAUSE_MS = 15 * 60000 // cooldownMinutes default, in ms

/** A ui.status recorder, same shape as recordLogs. */
function recordStatus(on: On): string[] {
  const lines: string[] = []
  on('ui.status', async ($, e, next) => {
    lines.push(e.text ?? '')
    try {
      await next(e)
    } catch {
      // nothing implements ui.status below the recorder in the kit
    }
  })
  return lines
}

/** A bottom `model.classify` answering `reply`; records every ask. */
async function bootCls($: Engine, on: On, o: ClsOpts = {}): Promise<Cls> {
  const logs = recordLogs(on)
  const toasts = recordToasts(on)
  const status = recordStatus(on)
  const seen: Seen[] = []
  const asks: Ask[] = []
  recordSteps(on, seen)
  on('prompt.submit', ($, e) => ({ text: e.text }))
  on('turn.complete', () => ({ text: '' }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  on('tool.call', { tool: 'Skill' }, () => ({
    result: { success: true, commandName: 'bottom' },
  }))
  on('agent.spawn', ($, e) => ({
    model: e.model ?? e.parentModel,
    agentId: 'a1',
  }))
  on('model.classify', async (_$, e) => {
    asks.push({ text: e.text, labels: e.labels, options: e.options })
    return { value: await (o.reply ?? (() => 'coding'))(asks.length) }
  })
  const world = o.world ?? newWorld()
  const clock = await boot($, on, o.model ?? FABLE, o.tokens ?? 1000, world)
  if (o.verbose) await route($, 'verbose on')
  logs.splice(0)
  return { asks, seen, clock, logs, toasts, status, world }
}

const clearSession = ($: Engine) => $.session.end({
  reason: 'clear',
  sessionId: 's1',
  resume: { id: 's1' },
})

/** The effort a main step reaches the bottom with (engine asks high). */
async function clsEffort($: Engine, c: Cls): Promise<unknown> {
  await runStep($, highStep())
  return c.seen[c.seen.length - 1]?.effort
}

const never = (): Promise<never> => new Promise(() => undefined)
const boom = (): never => {
  throw new Error('overloaded')
}

/** `n` typed prompts that each fail, a turn end between them. */
async function failTimes($: Engine, n: number): Promise<void> {
  for (let i = 0; i < n; i++) {
    await typed($, PLAIN)
    await endTurn($)
  }
}

const LABELS_EFFORT: [string, string][] = [
  ['design', 'xhigh'],
  ['analysis', 'high'],
  ['coding', 'medium'],
  ['bookkeeping', 'low'],
]

test('classify: one call with the five labels and no model option', async (
  $, on) => {
  const c = await bootCls($, on)
  await typed($, PLAIN)
  expect(c.asks).toEqual([{
    text: PLAIN,
    labels: ['design', 'analysis', 'coding', 'bookkeeping', 'chat'],
    options: undefined,
  }])
})

for (const [label, effort] of LABELS_EFFORT) {
  test(`classify: ${label} becomes the turn effort ${effort}`, async (
    $, on) => {
    const c = await bootCls($, on, { reply: () => label })
    await runStep($, highStep())
    await typed($, PLAIN)
    expect(await clsEffort($, c)).toBe(effort)
  })
}

test('classify: coding lowers the engine effort to medium', async ($, on) => {
  const c = await bootCls($, on)
  await typed($, PLAIN)
  expect(await clsEffort($, c)).toBe('medium')
})

test('classify: a chat answer routes nothing', async ($, on) => {
  const c = await bootCls($, on, { reply: () => 'chat' })
  await typed($, PLAIN)
  expect(await clsEffort($, c)).toBe('high')
})

test('classify: no label at all routes nothing', async ($, on) => {
  const c = await bootCls($, on, { reply: () => undefined })
  await typed($, PLAIN)
  expect(await clsEffort($, c)).toBe('high')
})

test('classify: a label naming an object key routes nothing', async (
  $, on) => {
  const c = await bootCls($, on, { reply: () => 'constructor' })
  await typed($, PLAIN)
  expect(await clsEffort($, c)).toBe('high')
})

test('classify: an unknown label neither warns nor counts', async ($, on) => {
  const c = await bootCls($, on, { reply: () => 'nonsense' })
  await failTimes($, 4)
  expect(c.asks).toHaveLength(4)
  expect(c.toasts).toEqual([])
  expect(c.logs).toEqual([])
})

test('classify: a design guess never moves a sonnet session up', async (
  $, on) => {
  const c = await bootCls($, on, { model: SONNET, reply: () => 'design' })
  await typed($, PLAIN)
  await runStep($, { ...highStep(), model: SONNET })
  expect(c.seen[c.seen.length - 1]).toEqual({ model: SONNET, effort: 'xhigh' })
})

test('classify: the route carries the tier', async ($, on) => {
  const c = await bootCls($, on, { reply: () => 'design' })
  await typed($, PLAIN)
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('classifier plan')
  expect(line).toContain('[tier best]')
  expect(c.asks).toHaveLength(1)
})

test('classify: the route is gone at turn.complete', async ($, on) => {
  const c = await bootCls($, on, { reply: () => 'design' })
  await typed($, PLAIN)
  await endTurn($)
  expect(await clsEffort($, c)).toBe('high')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('classify: a route tool call in the turn replaces it', async ($, on) => {
  const c = await bootCls($, on, { reply: () => 'bookkeeping' })
  await typed($, PLAIN)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })
  expect(await clsEffort($, c)).toBe('xhigh')
})

test('classify: a typed skill in the turn replaces it', async ($, on) => {
  const c = await bootCls($, on, { reply: () => 'design' })
  await typed($, PLAIN)
  await typed($, '/feat add a thing')
  await skillPrompt($, 'feat')
  expect(await clsEffort($, c)).toBe('high')
})

test('classify: a user /effort change beats the guessed effort', async (
  $, on) => {
  const c = await bootCls($, on, { reply: () => 'design' })
  await runStep($, highStep())
  await endTurn($)
  await typed($, PLAIN)
  await runStep($, { ...highStep(), effort: 'low' as const })
  expect(c.seen[c.seen.length - 1]?.effort).toBe('low')
})

test('classify: the baseline survives /clear', async ($, on) => {
  const c = await bootCls($, on, { reply: () => 'design' })
  await runStep($, highStep())
  await endTurn($)
  await clearSession($)
  await typed($, PLAIN)
  await runStep($, { ...highStep(), effort: 'low' as const })
  expect(c.seen[c.seen.length - 1]?.effort).toBe('low')
})

test('classify: a baseline-effort step takes the guessed effort', async (
  $, on) => {
  const c = await bootCls($, on, { reply: () => 'design' })
  await runStep($, highStep())
  await typed($, PLAIN)
  await runStep($, highStep())
  expect(c.seen[c.seen.length - 1]?.effort).toBe('xhigh')
})

// ---- the guards: one clause each ---

/** The prompt is typed, then the asks are counted. */
async function asksFor($: Engine, c: Cls, text: string): Promise<number> {
  await typed($, text)
  return c.asks.length
}

test('classify guard: text under 12 characters is not sent', async (
  $, on) => {
  const c = await bootCls($, on)
  expect(await asksFor($, c, 'hello world')).toBe(0)
})

test('classify guard: 12 characters are sent', async ($, on) => {
  const c = await bootCls($, on)
  expect(await asksFor($, c, 'hello worlds')).toBe(1)
})

test('classify guard: padded short text is not sent', async ($, on) => {
  const c = await bootCls($, on)
  expect(await asksFor($, c, '        short        ')).toBe(0)
})

test('classify guard: a padded slash prompt is not sent', async ($, on) => {
  const c = await bootCls($, on)
  expect(await asksFor($, c, '  /feat add a long thing')).toBe(0)
})

test('classify guard: the sample is sent trimmed', async ($, on) => {
  const c = await bootCls($, on)
  await typed($, `   ${PLAIN}   `)
  expect(c.asks.map(a => a.text)).toEqual([PLAIN])
})

test('classify guard: a slash prompt is not sent', async ($, on) => {
  const c = await bootCls($, on)
  expect(await asksFor($, c, '/unknown with a long argument')).toBe(0)
})

test('classify guard: a non-composer origin is not sent', async ($, on) => {
  const c = await bootCls($, on)
  await $.prompt.submit({ text: PLAIN, wait: false, origin: { kind: 'sdk' } })
  expect(c.asks).toHaveLength(0)
})

test('classify guard: a mid-turn prompt is not sent', async ($, on) => {
  const c = await bootCls($, on)
  await queued($, 'composer', PLAIN)
  expect(c.asks).toHaveLength(0)
})

test('classify guard: a keyword rule match is not sent', async ($, on) => {
  const c = await bootCls($, on)
  expect(await asksFor($, c, 'please review the billing module')).toBe(0)
})

test('classify guard: ultrathink is not sent', async ($, on) => {
  const c = await bootCls($, on)
  expect(await asksFor($, c, 'ultrathink about the billing module')).toBe(0)
})

test('classify guard: a sticky /route is not overridden', async ($, on) => {
  const c = await bootCls($, on)
  await route($, 'mechanical')
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify guard: a held run slot is not sent', async ($, on) => {
  const c = await bootCls($, on)
  await typed($, '/feat add a thing')
  await skillPrompt($, 'feat')
  await endTurn($)
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify guard: a carried floor is not sent', async ($, on) => {
  const c = await bootCls($, on)
  await queued($, 'composer', 'ultrathink about the billing module')
  await endTurn($)
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify guard: a sub-agent never reaches the classifier', async (
  $, on) => {
  const c = await bootCls($, on)
  await $.agent.spawn(spawnInput())
  await runStep($, highStep('a1'))
  expect(c.asks).toHaveLength(0)
})

test('classify guard: a config classify=false is not sent', async ($, on) => {
  const c = await bootCls($, on, {
    world: newWorld({ home: { classify: false } }),
  })
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify guard: /route classify off is not sent', async ($, on) => {
  const c = await bootCls($, on)
  await route($, 'classify off')
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify guard: the mod off is not sent', async ($, on) => {
  const c = await bootCls($, on)
  await route($, 'off')
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify guard: a haiku id marked down is not sent', async ($, on) => {
  const c = await bootCls($, on)
  await switchTo($, HAIKU, SONNET, 'auto')
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify guard: a main loop on haiku is not sent', async ($, on) => {
  const c = await bootCls($, on, { model: HAIKU })
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify guard: a phase without effort routes nothing', async (
  $, on) => {
  const world = newWorld({ edit: f => {
    (f.phases as Rec).plan = { tier: 'best' }
  } })
  const c = await bootCls($, on, { reply: () => 'design', world })
  await typed($, PLAIN)
  expect(await clsEffort($, c)).toBe('high')
})

test('classify guard: a non-best skill turn leaves the next open', async (
  $, on) => {
  const c = await bootCls($, on)
  await typed($, '/status now')
  await skillPrompt($, 'status')
  await endTurn($)
  expect(await asksFor($, c, PLAIN)).toBe(1)
})

test('classify guard: /route clear reopens it after a best-tier run', async (
  $, on) => {
  const c = await bootCls($, on)
  await typed($, '/feat add a thing')
  await skillPrompt($, 'feat')
  await endTurn($)
  await route($, 'clear')
  expect(await asksFor($, c, PLAIN)).toBe(1)
})

test('classify guard: a route landing during the call wins', async (
  $, on) => {
  let release: () => void = () => undefined
  const gate = new Promise<void>(resolve => { release = resolve })
  const c = await bootCls($, on, {
    reply: async () => { await gate; return 'design' },
  })
  await route($, 'switch off')
  const pending = typed($, PLAIN)
  await c.clock.settle()
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  release()
  await pending
  expect(mainLine(await route($, 'show'))).toContain('model mechanical')
  expect(await clsEffort($, c)).toBe('low')
})

// ---- bounded and fail-safe ---

test('classify bound: a call never answering gives no route at 3 s', async (
  $, on) => {
  const c = await bootCls($, on, { reply: never })
  const pending = typed($, PLAIN)
  await c.clock.settle()
  await c.clock.advance(3000)
  await pending
  expect(await clsEffort($, c)).toBe('high')
})

test('classify bound: the prompt proceeds after a timeout', async ($, on) => {
  const c = await bootCls($, on, { reply: never })
  const pending = typed($, PLAIN)
  await c.clock.settle()
  await c.clock.advance(3000)
  expect((await pending).text).toBe(PLAIN)
})

test('classify bound: three timeouts pause the classifier', async ($, on) => {
  const c = await bootCls($, on, { reply: never })
  for (let i = 0; i < 3; i++) {
    const pending = typed($, PLAIN)
    await c.clock.settle()
    await c.clock.advance(3000)
    await pending
  }
  expect(c.toasts).toEqual(['classifier paused 15 min (3 failures)'])
})

test('classify bound: a rejection is not an error for the prompt', async (
  $, on) => {
  const c = await bootCls($, on, { reply: boom })
  await typed($, PLAIN)
  expect(c.logs.filter(l => l.includes('failed'))).toEqual([])
})

test('classify fail: three rejections pause with one toast', async ($, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 3)
  expect(c.toasts).toEqual(['classifier paused 15 min (3 failures)'])
})

test('classify fail: two rejections do not pause', async ($, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 2)
  expect(c.toasts).toEqual([])
})

test('classify fail: the status line shows the pause marker', async (
  $, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 3)
  expect(c.status[c.status.length - 1]).toContain('classifier: paused')
})

test('classify fail: no call during the cooldown', async ($, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 3)
  expect(await asksFor($, c, PLAIN)).toBe(3)
})

test('classify fail: a settled answer resets the counter', async ($, on) => {
  const c = await bootCls($, on, {
    reply: n => (n === 3 ? 'chat' : boom()),
  })
  await failTimes($, 5)
  expect(c.toasts).toEqual([])
  expect(c.asks).toHaveLength(5)
})

test('classify pause: still paused one ms before the cooldown ends', async (
  $, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 3)
  await c.clock.advance(PAUSE_MS - 1)
  expect(await asksFor($, c, PLAIN)).toBe(3)
})

test('classify pause: resumes when the cooldown ends', async ($, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 3)
  await c.clock.advance(PAUSE_MS)
  expect(await asksFor($, c, PLAIN)).toBe(4)
})

test('classify pause: the marker clears when it ends', async ($, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 3)
  await c.clock.advance(PAUSE_MS)
  await typed($, '/status')
  expect(c.status[c.status.length - 1]).not.toContain('paused')
})

test('classify pause: /clear keeps it', async ($, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 3)
  await clearSession($)
  expect(await asksFor($, c, PLAIN)).toBe(3)
})

test('classify pause: /route reload clears it', async ($, on) => {
  const c = await bootCls($, on, { reply: boom })
  await failTimes($, 3)
  await route($, 'reload')
  expect(await asksFor($, c, PLAIN)).toBe(4)
})

// ---- sample ---

test('classify sample: 2000 code points are sent whole', async ($, on) => {
  const c = await bootCls($, on)
  const text = 'é'.repeat(2000)
  await typed($, text)
  expect(c.asks[0]?.text).toBe(text)
})

test('classify sample: a longer text is cut to head and tail', async (
  $, on) => {
  const c = await bootCls($, on)
  await typed($, 'H'.repeat(600) + 'M'.repeat(1000) + 'T'.repeat(1500))
  expect(c.asks[0]?.text).toBe('H'.repeat(500) + 'T'.repeat(1500))
})

test('classify sample: a cut never leaves a lone surrogate', async (
  $, on) => {
  const c = await bootCls($, on)
  await typed($, '😀'.repeat(2400))
  const sent = c.asks[0]?.text ?? ''
  expect(sent.isWellFormed()).toBe(true)
  expect(Array.from(sent)).toHaveLength(2000)
})

// ---- no dialog, config, visibility ---

test('classify: no dialog and no file write on a classified prompt', async (
  $, on) => {
  const c = await bootCls($, on, { world: newWorld({ ask: true }) })
  await typed($, PLAIN)
  expect(c.asks).toHaveLength(1)
  expect(c.world.asked).toEqual([])
  expect(c.world.written).toEqual([])
})

test('classify config: an invalid value keeps the default on', async (
  $, on) => {
  const c = await bootCls($, on, {
    world: newWorld({ home: { classify: 'yes' } }),
  })
  expect(await asksFor($, c, PLAIN)).toBe(1)
})

test('classify config: an invalid value is logged once', async ($, on) => {
  const c = await bootCls($, on, {
    world: newWorld({ home: { classify: 'yes' } }),
  })
  await route($, 'reload')
  const said = c.logs.filter(l => l.includes('"classify" is not a boolean'))
  expect(said).toHaveLength(1)
})

test('classify config: /route show prints classify: on', async ($, on) => {
  await bootCls($, on)
  expect(await route($, 'show')).toContain('classify: on')
})

test('classify config: /route classify off prints classify: off', async (
  $, on) => {
  await bootCls($, on)
  expect(await route($, 'classify off')).toContain('classify: off')
})

test('classify config: a bad toggle argument prints the usage', async (
  $, on) => {
  await bootCls($, on)
  expect(await route($, 'classify maybe')).toBe('usage: /route classify on|off')
})

test('classify config: the toggle survives a rebuild', async ($, on) => {
  const c = await bootCls($, on)
  await route($, 'classify off')
  expect(await route($, 'reload')).toContain('classify: off')
  expect(await asksFor($, c, PLAIN)).toBe(0)
})

test('classify config: /route is refused from a plugin origin', async (
  $, on) => {
  await bootCls($, on)
  const out = await $.command.run({
    command: 'route',
    args: 'classify off',
    origin: { kind: 'plugin', name: 'x' },
    presentation: { isFullscreen: false, columns: 80 },
  })
  expect(out.text).toContain('user-only')
})

test('classify visibility: the status line reads classifier <phase>', async (
  $, on) => {
  const c = await bootCls($, on, { reply: () => 'analysis' })
  await typed($, PLAIN)
  expect(c.status[c.status.length - 1]).toContain('route: classifier reflect')
})

test('classify visibility: verbose says (reflect: classifier)', async (
  $, on) => {
  const c = await bootCls($, on, { reply: () => 'analysis', verbose: true })
  await runStep($, { ...highStep(), effort: 'low' as const })
  await typed($, PLAIN)
  await runStep($, { ...highStep(), effort: 'low' as const })
  expect(c.logs).toContain(
    mainWord('fable/low', 'fable/high', 'reflect: classifier'))
})

test('classify: a repeated undefined label never pauses', async ($, on) => {
  const c = await bootCls($, on, { reply: () => undefined })
  await failTimes($, 3)
  expect(c.asks).toHaveLength(3)
  expect(c.toasts).toEqual([])
  expect(c.status.some(l => l.includes('paused'))).toBe(false)
})

test('classify: /route advertises classify on|off in its hint', async (
  $, on) => {
  const hints: unknown[] = []
  on('command.register', (_$, e) => {
    hints.push(e.argumentHint)
    return { value: { command: e.name } }
  })
  await bootCls($, on)
  expect(hints.join('\n')).toContain('classify on|off')
})

// ---- downgrade cap: the cold read -------------------------------------------

const logsWith = (logs: string[], text: string): number =>
  logs.filter(l => l.includes(text)).length

const SKIP = 'downgrade skipped'

test('cap: a downgrade above the cold-read cap keeps main', async ($, on) => {
  const logs = recordLogs(on)
  const rig = await bootRig($, on, FABLE, 300000)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  expect(await stepOn($, rig, FABLE)).toEqual({ model: FABLE, effort: 'low' })
  await stepOn($, rig, FABLE)
  expect(logsWith(logs, `${SKIP}: cold read 300000 tokens over 120000`))
    .toBe(1)
})

test('cap: unknown usage blocks the downgrade', async ($, on) => {
  const logs = recordLogs(on)
  const rig = await bootRig($, on, FABLE, null)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  expect(logsWith(logs, `${SKIP}: context size unknown`)).toBe(1)
})

test('cap: a user downgradeMaxTokens overrides the default', async (
  $, on) => {
  const world = newWorld({ home: { downgradeMaxTokens: 500 } })
  const rig = await bootRig($, on, FABLE, 1000, world)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
})

/** Routes `phase` and steps once on FABLE; the model that was sent. */
async function routedStep($: Engine, rig: Rig, phase: string) {
  await $.tool.call({ tool: ROUTE_TOOL, phase })
  return (await stepOn($, rig, FABLE)).model
}

test('cap: a warm model is cheap to return to, a cold one is capped', async (
  $, on) => {
  const logs = recordLogs(on)
  const { rig, usage } = await bootRigVar($, on, FABLE, 100000)
  expect(await routedStep($, rig, 'implement')).toBe(SONNET)
  await endTurn($)
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  await endTurn($)
  usage.set(210000)
  expect(await routedStep($, rig, 'implement')).toBe(SONNET)
  await endTurn($)
  // control: opus never served, the same context is a cold read of 210000
  expect(await routedStep($, rig, 'judge')).toBe(FABLE)
  expect(logsWith(logs, `${SKIP}: cold read 210000 tokens over 120000`))
    .toBe(1)
})

test('cap: the served record expires after the TTL', async ($, on) => {
  const { rig, usage } = await bootRigVar($, on, FABLE, 100000)
  await routedStep($, rig, 'implement')
  await endTurn($)
  await stepOn($, rig, FABLE)
  await endTurn($)
  usage.set(210000)
  await rig.clock.advance(61 * 60000)
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
})

test('cap: /route reload forgets the served record', async ($, on) => {
  const { rig, usage } = await bootRigVar($, on, FABLE, 100000)
  await routedStep($, rig, 'implement')
  await endTurn($)
  await stepOn($, rig, FABLE)
  await endTurn($)
  usage.set(210000)
  await route($, 'reload')
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
})

test('cap: the skip line is said once until a downgrade succeeds', async (
  $, on) => {
  const logs = recordLogs(on)
  const { rig, usage } = await bootRigVar($, on, FABLE, 300000)
  for (let turn = 0; turn < 2; turn++) {
    await routedStep($, rig, 'mechanical')
    await endTurn($)
  }
  expect(logsWith(logs, SKIP)).toBe(1)
  usage.set(1000)
  expect(await routedStep($, rig, 'mechanical')).toBe(HAIKU)
  await endTurn($)
  usage.set(300000)
  expect(await routedStep($, rig, 'mechanical')).toBe(FABLE)
  expect(logsWith(logs, SKIP)).toBe(2)
})

test('cap: a smaller context than the record is cold', async ($, on) => {
  const world = newWorld({ home: { downgradeMaxTokens: 40000 } })
  const { rig, usage } = await bootRigVar($, on, SONNET, 100000, world)
  await stepOn($, rig, SONNET)
  await endTurn($)
  await switchTo($, SONNET, FABLE, 'command')
  usage.set(50000)
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
})

test('window: haiku outgrown returns main to the session model', async (
  $, on) => {
  const logs = recordLogs(on)
  const world = newWorld({ home: { windows: { [HAIKU]: 200000 } } })
  const { rig, usage } = await bootRigVar($, on, FABLE, 1000, world)
  expect(await routedStep($, rig, 'mechanical')).toBe(HAIKU)
  usage.set(250000)
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  await stepOn($, rig, FABLE)
  expect(logsWith(logs, 'context outgrew')).toBe(1)
})

test('config: a quoted "false" mainModelSwitch reads as off with a warning',
  async ($, on) => {
    const logs = recordLogs(on)
    const world = newWorld({ home: { mainModelSwitch: 'false' } })
    await boot($, on, FABLE, 1000, world)
    expect(await route($, 'show')).toContain('switch: off (downgrade)')
    expect(logsWith(logs, 'mainModelSwitch" is not a boolean')).toBe(1)
  })

test('text: show names the switch and its cap', async ($, on) => {
  await boot($, on)
  expect(await route($, 'show')).toContain(
    'switch: on (downgrade, cap 120000 tokens cold, ttl 60 min)')
})

test('status: the switch shows only when off', async ($, on) => {
  const c = await bootCls($, on)
  await route($, 'classify off')
  expect(c.status[c.status.length - 1]).not.toContain('switch')
  await route($, 'switch off')
  expect(c.status[c.status.length - 1]).toContain(' · switch off')
})

test('toast: a downgrade held by the cap says so', async ($, on) => {
  const toasts = recordToasts(on)
  const w = asks([...TO_IMPLEMENT, 'Everywhere'])
  await bootRun($, on, FABLE, w, 300000)
  await typeFeat($)
  expect(toasts).toContain('/feat now runs claude-fable-5-1 at medium, ' +
    `held: ${SKIP}: cold read 300007 tokens over 120000`)
})

// ---- downgrade cap: the classifier's model axis ---------------------------

const lastSeen = (c: Cls): Seen | undefined => c.seen[c.seen.length - 1]

test('classify: coding moves main to sonnet medium under the cap', async (
  $, on) => {
  const c = await bootCls($, on)
  await typed($, PLAIN)
  await runStep($, highStep())
  expect(lastSeen(c)).toEqual({ model: SONNET, effort: 'medium' })
})

test('classify: coding above the cap keeps fable at medium', async (
  $, on) => {
  const c = await bootCls($, on, { tokens: 300000 })
  await typed($, PLAIN)
  await runStep($, highStep())
  expect(lastSeen(c)).toEqual({ model: FABLE, effort: 'medium' })
})

test('classify: a user /effort drops the model guess too', async ($, on) => {
  const c = await bootCls($, on)
  await runStep($, highStep())
  await endTurn($)
  await typed($, PLAIN)
  await runStep($, { ...highStep(), effort: 'low' as const })
  expect(lastSeen(c)).toEqual({ model: FABLE, effort: 'low' })
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('classify: a user /effort drops the guess for one turn only', async (
  $, on) => {
  const c = await bootCls($, on)
  await runStep($, highStep())
  await endTurn($)
  const low = { ...highStep(), effort: 'low' as const }
  await typed($, PLAIN)
  await runStep($, low)
  expect(lastSeen(c)).toEqual({ model: FABLE, effort: 'low' })
  await endTurn($)
  await typed($, PLAIN)
  await runStep($, low)
  expect(lastSeen(c)).toEqual({ model: SONNET, effort: 'medium' })
})

test('classify: a mid-turn ultrathink floor raises effort only', async (
  $, on) => {
  const c = await bootCls($, on)
  await typed($, PLAIN)
  await runStep($, highStep())
  expect(lastSeen(c)?.model).toBe(SONNET)
  await queued($, 'composer', 'ultrathink please')
  await runStep($, highStep())
  // the floor names no model: the guess's sonnet holds, at the floor's max
  expect(lastSeen(c)).toEqual({ model: SONNET, effort: 'max' })
})

test('classify: a guessed sonnet rate-limited falls to opus, not haiku', async (
  $, on) => {
  const c = await bootCls($, on)
  await typed($, PLAIN)
  await runStep($, highStep())
  expect(lastSeen(c)?.model).toBe(SONNET)
  await failWith($, 'rate_limit')
  await runStep($, highStep())
  expect(lastSeen(c)?.model).toBe(OPUS)
})

// ---- cap residuals: session pin, prompt estimate, engine TTL ---------------

const GP = 'general-purpose'

/** A demoted main (fable session, mechanical route on haiku) + spawn rig. */
async function demotedRig($: Engine, on: On, source = 'built-in') {
  const { rig } = await bootRigVar($, on, FABLE, 1000)
  await offerOf($, GP, source)
  expect(await routedStep($, rig, 'mechanical')).toBe(HAIKU)
  return rig
}

test('spawn: general-purpose during a demoted turn starts on the session model',
  async ($, on) => {
    const logs = recordLogs(on)
    const rig = await demotedRig($, on)
    await route($, 'verbose on')
    await $.agent.spawn(spawnOf(GP, { parentModel: HAIKU }))
    expect(rig.specs).toEqual([FABLE])
    expect(logsWith(logs, `agent ${GP}`)).toBe(1)
    expect(logsWith(logs, '(session, engine)')).toBe(1)
  })

test('spawn: no route in force leaves general-purpose untouched', async (
  $, on) => {
  const { rig } = await bootRigVar($, on, FABLE, 1000)
  await offerOf($, GP, 'built-in')
  await $.agent.spawn(spawnOf(GP, { parentModel: FABLE }))
  expect(rig.specs).toEqual([undefined])
})

test('spawn: a rowed agent keeps its row during a demoted turn', async (
  $, on) => {
  const rig = await demotedRig($, on)
  await $.agent.spawn(spawnOf('feater', { parentModel: HAIKU }))
  expect(rig.specs).toEqual([SONNET])
})

test('spawn: a fork during a demoted turn is untouched', async ($, on) => {
  const rig = await demotedRig($, on)
  await $.agent.spawn(spawnOf(GP, { parentModel: HAIKU, fork: true }))
  expect(rig.specs).toEqual([undefined])
})

test('spawn: a nested spawn during a demoted turn is untouched', async (
  $, on) => {
  const rig = await demotedRig($, on)
  await $.agent.spawn(spawnOf(GP, { parentModel: HAIKU, parentAgentId: 'a1' }))
  expect(rig.specs).toEqual([undefined])
})

test('spawn: a type outside the allowlist is untouched', async ($, on) => {
  const rig = await demotedRig($, on)
  await offerOf($, 'code-explorer', 'built-in')
  await $.agent.spawn(spawnOf('code-explorer', { parentModel: HAIKU }))
  expect(rig.specs).toEqual([undefined])
})

test('spawn: an upgraded main never pins general-purpose', async ($, on) => {
  const { rig } = await bootRigVar($, on, HAIKU, 1000)
  await offerOf($, GP, 'built-in')
  await planRoute($)
  expect((await stepOn($, rig, HAIKU)).model).toBe(FABLE)
  await $.agent.spawn(spawnOf(GP, { parentModel: FABLE }))
  expect(rig.specs).toEqual([undefined])
})

test('spawn: a shadowed general-purpose is never pinned', async ($, on) => {
  const rig = await demotedRig($, on, 'projectSettings')
  await $.agent.spawn(spawnOf(GP, { parentModel: HAIKU }))
  expect(rig.specs).toEqual([undefined])
})

const longText = (points: number) => 'x'.repeat(points)

/** Cap 110000, classifier off, a context of `tokens`; estimates need both. */
function estimateRig($: Engine, on: On, tokens: number) {
  const home = { classify: false, downgradeMaxTokens: 110000 }
  return bootRigVar($, on, FABLE, tokens, newWorld({ home }))
}

test('cap: a pasted prompt counts before the first step', async ($, on) => {
  const logs = recordLogs(on)
  const { rig } = await estimateRig($, on, 100000)
  await typed($, longText(60000))
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
  expect(logsWith(logs, `${SKIP}: cold read 120000 tokens over 110000`))
    .toBe(1)
})

test('cap: the estimate is skipped once usage counted the prompt', async (
  $, on) => {
  const first = await estimateRig($, on, 100000)
  await typed($, longText(60000))
  first.usage.set(110000)
  expect(await routedStep($, first.rig, 'implement')).toBe(SONNET)
})

test('cap: usage growth under half the estimate still adds it', async (
  $, on) => {
  const logs = recordLogs(on)
  const { rig, usage } = await estimateRig($, on, 100000)
  await typed($, longText(60000))
  usage.set(109999)
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
  expect(logsWith(logs, 'cold read 129999 tokens over 110000')).toBe(1)
})

test('cap: the first main step consumes the estimate', async ($, on) => {
  const { rig } = await estimateRig($, on, 100000)
  await typed($, longText(60000))
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
  expect((await stepOn($, rig, FABLE)).model).toBe(SONNET)
})

test('cap: a mid-turn prompt is counted at the next turn first step', async (
  $, on) => {
  const { rig } = await estimateRig($, on, 100000)
  await queued($, 'composer', longText(60000))
  await endTurn($)
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
})

test('cap: an estimate no step consumed is carried over the turn end', async (
  $, on) => {
  const { rig } = await estimateRig($, on, 100000)
  await typed($, longText(60000))
  await endTurn($)
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
})

test('cap: a document attachment blocks the first step switch', async (
  $, on) => {
  const logs = recordLogs(on)
  const { rig } = await estimateRig($, on, 1000)
  await $.prompt.submit({
    text: 'see the file',
    wait: false,
    origin: { kind: 'composer' },
    attachments: [{ type: 'document' }],
  })
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
  expect(logsWith(logs, `${SKIP}: context size unknown`)).toBe(1)
  expect((await stepOn($, rig, FABLE)).model).toBe(SONNET)
})

test('cap: a typed skill body counts', async ($, on) => {
  const { rig } = await estimateRig($, on, 100000)
  await typed($, '/analyze')
  await $.skill.prompt({ skill: 'analyze', text: longText(60000) })
  expect(await routedStep($, rig, 'implement')).toBe(FABLE)
})

test('cap: a preload during a live spawn adds nothing', async ($, on) => {
  const { rig } = await estimateRig($, on, 100000)
  await typed($, 'hello')
  await $.agent.spawn(spawnOf('feater'))
  await $.skill.prompt({ skill: 'analyze', text: longText(60000) })
  expect(await routedStep($, rig, 'implement')).toBe(SONNET)
})

/** A sonnet record of 100000 tokens, then `age` min later a 210000 context. */
async function ttlCase($: Engine, on: On, ttl: '5m' | '1h', age: number) {
  const { rig, usage } = await bootRigVar($, on, FABLE, 100000)
  await switchTo($, FABLE, FABLE, 'command', ttl)
  await routedStep($, rig, 'implement')
  await endTurn($)
  await stepOn($, rig, FABLE)
  await endTurn($)
  usage.set(210000)
  await rig.clock.advance(age * 60000)
  return routedStep($, rig, 'implement')
}

test('ttl: the engine 5m makes a 6 min old record cold', async ($, on) => {
  expect(await ttlCase($, on, '5m', 6)).toBe(FABLE)
})

test('ttl: the engine 1h keeps a 59 min old record warm', async ($, on) => {
  expect(await ttlCase($, on, '1h', 59)).toBe(SONNET)
})

test('ttl: a sub-agent switch event moves neither TTL nor session', async (
  $, on) => {
  const rig = await bootRig($, on)
  await route($, 'switch off')
  await stepOn($, rig, FABLE)
  await switchTo($, FABLE, OPUS, 'command', '5m', 'a1')
  const text = await route($, 'show')
  await route($, 'mechanical')
  const line = mainLine(await route($, 'show'))
  expect(line).toContain(FABLE)
  expect(line).not.toContain(OPUS)
  expect(text).not.toContain('ttl 5 min')
})

test('ttl: /clear keeps the engine TTL', async ($, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  await bootRig($, on)
  await switchTo($, FABLE, FABLE, 'command', '5m')
  await clearSession($)
  expect(await route($, 'show')).toContain('ttl 5 min')
})

test('ttl: show says 60 min by default and 5 min after a 5m event', async (
  $, on) => {
  await boot($, on)
  expect(await route($, 'show')).toContain('ttl 60 min)')
  await switchTo($, FABLE, FABLE, 'command', '5m')
  expect(await route($, 'show')).toContain('ttl 5 min)')
})

// ---- probe: the model main runs on answers before main is sent -----------

const PROBE_MS = 8000
const FABLE_PLAN = 'plan the billing migration'

/** A world whose completions resolve as `complete(model)` says. */
function probeWorld(
  complete: (model: string) => unknown,
  fx: Fixture = {},
): World {
  return { ...newWorld(fx), complete }
}

const hangsOn = (id: string) => (model: string): unknown =>
  model === id ? never() : PROBE_OK
const rejectsOn = (id: string) => (model: string): unknown =>
  model === id ? Promise.reject(new Error('credits')) : PROBE_OK

/** Lets a probe that never answers hit its bound while `work` waits on it. */
async function pastProbe<T>(rig: Rig, work: Promise<T>): Promise<T> {
  await rig.clock.settle()
  await rig.clock.advance(PROBE_MS)
  return work
}

/** The `down:` line of `show`. */
const downLine = (text: string): string =>
  text.split('\n').find(l => l.startsWith('down:')) ?? ''

test('probe: a fable that never answers lands the plan step on opus', async (
  $, on) => {
  const world = probeWorld(hangsOn(FABLE))
  const rig = await bootRig($, on, OPUS, 1000, world)
  // a keyword no longer lifts: the route tool carries the plan tier
  await pastProbe(rig, planRoute($))
  await runStep($, { ...highStep(), model: OPUS })
  expect(rig.seen).toEqual([{ model: OPUS, effort: 'max' }])
  // fable probed by the route call, opus by the step
  expect(world.completions).toEqual([FABLE, OPUS])
  expect(downLine(await route($, 'show'))).toContain(
    `${FABLE} for 15 min (probe)`)
})

test('probe: the route tool answers an opus id, never fable', async (
  $, on) => {
  const rig = await bootRig($, on, OPUS, 1000, probeWorld(hangsOn(FABLE)))
  const out = await pastProbe(rig, $.tool.call({
    tool: ROUTE_TOOL,
    phase: 'reflect',
  }))
  const text = JSON.stringify(out)
  expect(text).toContain(OPUS)
  expect(text).not.toContain(FABLE)
})

test('probe: an answered probe is cached across turns', async ($, on) => {
  const world = newWorld()
  const rig = await bootRig($, on, OPUS, 1000, world)
  await planRoute($)
  expect((await stepOn($, rig, OPUS)).model).toBe(FABLE)
  await endTurn($)
  await planRoute($)
  expect((await stepOn($, rig, OPUS)).model).toBe(FABLE)
  expect(world.completions).toEqual([FABLE])
})

test('probe: a lapsed hold probes again and holds longer', async ($, on) => {
  const world = probeWorld(hangsOn(FABLE))
  const rig = await bootRig($, on, OPUS, 1000, world)
  for (const wait of [15, 30]) {
    // the route tool lifts, a keyword no longer does
    await pastProbe(rig, planRoute($))
    await runStep($, { ...highStep(), model: OPUS })
    expect(downLine(await route($, 'show'))).toContain(`for ${wait} min`)
    await endTurn($)
    await rig.clock.advance(wait * 60000)
  }
  // the fallback opus is verified by its own probe the first time only
  expect(world.completions).toEqual([FABLE, OPUS, FABLE])
  expect(rig.seen.map(s => s.model)).toEqual([OPUS, OPUS])
})

test('probe: a rejection marks the target down like a timeout', async (
  $, on) => {
  const world = probeWorld(rejectsOn(FABLE))
  const rig = await bootRig($, on, OPUS, 1000, world)
  await planRoute($)
  expect((await stepOn($, rig, OPUS)).model).toBe(OPUS)
  expect(world.completions).toEqual([FABLE, OPUS])
  expect(downLine(await route($, 'show'))).toContain('(probe)')
})

for (const [shape, answer] of [
  ['a string', 'ok'], ['an object', PROBE_OK], ['nothing', undefined],
] as const) {
  test(`probe: ${shape} as the answer lets the move go`, async ($, on) => {
    const world = probeWorld(() => answer)
    const rig = await bootRig($, on, OPUS, 1000, world)
    await planRoute($)
    expect((await stepOn($, rig, OPUS)).model).toBe(FABLE)
    expect(world.completions).toEqual([FABLE])
  })
}

test('probe: a failure during the flight keeps the target unverified', async (
  $, on) => {
  let open: () => void = () => undefined
  const gate = new Promise<void>(resolve => { open = resolve })
  const world = probeWorld(async () => { await gate; return PROBE_OK })
  const rig = await bootRig($, on, OPUS, 1000, world)
  // the route tool's probe is the one in flight (a keyword no longer lifts)
  const call = planRoute($)
  await rig.clock.settle()
  await switchTo($, FABLE, OPUS, 'auto')
  open()
  await call
  await runStep($, { ...highStep(), model: OPUS })
  expect(rig.seen).toEqual([{ model: OPUS, effort: 'max' }])
  await endTurn($)
  await rig.clock.advance(15 * 60000)
  await planRoute($)
  await runStep($, { ...highStep(), model: OPUS })
  // route probe fails in flight, the step probes opus, the second route fable
  expect(world.completions).toEqual([FABLE, OPUS, FABLE])
})

test('probe: an explicit route onto a held model probes once in all', async (
  $, on) => {
  const world = probeWorld(hangsOn(FABLE))
  const rig = await bootRig($, on, OPUS, 1000, world)
  await pastProbe(rig, route($, 'fable'))
  await runStep($, { ...highStep(), model: OPUS })
  await runStep($, { ...highStep(), model: OPUS })
  await route($, 'show')
  // fable is asked once; the second step leaves the held fable for opus,
  // a move like any other, so opus is tried the same way
  expect(world.completions).toEqual([FABLE, OPUS])
  expect(rig.seen.map(s => s.model)).toEqual([FABLE, OPUS])
})

test('probe: no probe when the classifier guess is above the session', async (
  $, on) => {
  const world = probeWorld(hangsOn(FABLE))
  const c = await bootCls($, on, {
    model: SONNET, reply: () => 'design', world,
  })
  await typed($, PLAIN)
  await runStep($, { ...highStep(), model: SONNET })
  expect(world.completions).toEqual([SONNET])
  expect(c.seen[c.seen.length - 1]?.model).toBe(SONNET)
})

test('probe: no probe when the upgrade switch refuses the move', async (
  $, on) => {
  const world = probeWorld(hangsOn(FABLE), { home: { mainUpgrade: false } })
  const rig = await bootRig($, on, OPUS, 1000, world)
  await planRoute($)
  expect((await stepOn($, rig, OPUS)).model).toBe(OPUS)
  expect(world.completions).toEqual([OPUS])
})

test('probe: a session model that never answers leaves for opus on the first step', async (
  $, on) => {
  const world = probeWorld(hangsOn(FABLE))
  const rig = await bootRig($, on, FABLE, 1000, world)
  await typed($, FABLE_PLAN)
  await pastProbe(rig, runStep($, { ...highStep(), model: FABLE }))
  // a keyword names no tier: no stand-in notch, xhigh instead of max
  expect(rig.seen).toEqual([{ model: OPUS, effort: 'xhigh' }])
  expect(world.completions).toEqual([FABLE])
  expect(downLine(await route($, 'show'))).toContain(
    `${FABLE} for 15 min (probe)`)
})

test('probe: a healthy session model is probed once and kept', async (
  $, on) => {
  const world = newWorld()
  const rig = await bootRig($, on, FABLE, 1000, world)
  await planRoute($)
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  await endTurn($)
  await planRoute($)
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  expect(world.completions).toEqual([FABLE])
})

test('probe: a lapsed hold on the session model probes it again', async (
  $, on) => {
  const world = probeWorld(hangsOn(FABLE))
  const rig = await bootRig($, on, FABLE, 1000, world)
  for (const wait of [15, 30]) {
    await typed($, FABLE_PLAN)
    await pastProbe(rig, runStep($, { ...highStep(), model: FABLE }))
    expect(downLine(await route($, 'show'))).toContain(`for ${wait} min`)
    await endTurn($)
    await rig.clock.advance(wait * 60000)
  }
  // opus, the fallback, answers its own probe once
  expect(world.completions).toEqual([FABLE, OPUS, FABLE])
  expect(rig.seen.map(s => s.model)).toEqual([OPUS, OPUS])
})

test('probe: false in the override makes no completion at all', async (
  $, on) => {
  const world = probeWorld(hangsOn(FABLE), { home: { probe: false } })
  const rig = await bootRig($, on, OPUS, 1000, world)
  await planRoute($)
  expect((await stepOn($, rig, OPUS)).model).toBe(FABLE)
  expect(world.completions).toEqual([])
  expect(await route($, 'show')).toContain('probe: off')
})

test('probe: a non-boolean setting is ignored, logged, probe stays on', async (
  $, on) => {
  const logs = recordLogs(on)
  const world = newWorld({ home: { probe: 'no' } })
  const rig = await bootRig($, on, OPUS, 1000, world)
  await planRoute($)
  await stepOn($, rig, OPUS)
  expect(world.completions).toEqual([FABLE])
  expect(logs.some(l => l.includes('"probe" is not a boolean'))).toBe(true)
  expect(await route($, 'show')).toContain('probe: on')
})

test('probe: /clear keeps the verified models', async ($, on) => {
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  const world = newWorld()
  const rig = await bootRig($, on, OPUS, 1000, world)
  await planRoute($)
  await stepOn($, rig, OPUS)
  await clearSession($)
  await planRoute($)
  await stepOn($, rig, OPUS)
  expect(world.completions).toEqual([FABLE])
})

// ---- stand-in: a lower model runs the tier one notch up ------------------

/** Main on fable fails: the hold stands, the next move is a stand-in. */
async function fableHeld($: Engine, rig: Rig): Promise<void> {
  await stepOn($, rig, FABLE)
  await failWith($, 'rate_limit')
}

test('stand-in: reflect on opus runs xhigh, and the answer says so', async (
  $, on) => {
  const rig = await bootRig($, on)
  await fableHeld($, rig)
  const out = await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect' })
  expect(JSON.stringify(out)).toContain(
    'effort xhigh (opus stands in for fable)')
  expect(await stepOn($, rig, FABLE)).toEqual({ model: OPUS, effort: 'xhigh' })
})

test('stand-in: orchestrate goes medium to high, escalate stays max', async (
  $, on) => {
  const rig = await bootRig($, on)
  await fableHeld($, rig)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  expect((await stepOn($, rig, FABLE)).effort).toBe('high')
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'escalate' })
  expect((await stepOn($, rig, FABLE)).effort).toBe('max')
})

test('stand-in: an explicit effort is never bumped', async ($, on) => {
  const rig = await bootRig($, on)
  await fableHeld($, rig)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect', effort: 'high' })
  expect(await stepOn($, rig, FABLE)).toEqual({ model: OPUS, effort: 'high' })
})

test('stand-in: fable available, no bump', async ($, on) => {
  const rig = await bootRig($, on, OPUS)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect' })
  expect(await stepOn($, rig, OPUS)).toEqual({ model: FABLE, effort: 'high' })
})

test('stand-in: a classifier guess above the session is no stand-in', async (
  $, on) => {
  const c = await bootCls($, on, { model: OPUS, reply: () => 'analysis' })
  await switchTo($, FABLE, OPUS, 'auto')
  await typed($, PLAIN)
  await runStep($, { ...highStep(), model: OPUS })
  expect(c.seen[c.seen.length - 1]).toEqual({ model: OPUS, effort: 'high' })
})

test('stand-in: with the upgrade switch off, no bump', async ($, on) => {
  const world = newWorld({ home: { mainUpgrade: false } })
  const rig = await bootRig($, on, OPUS, 1000, world)
  await switchTo($, FABLE, OPUS, 'auto')
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect' })
  expect(await stepOn($, rig, OPUS)).toEqual({ model: OPUS, effort: 'high' })
})

test('stand-in: a sticky effort from another slot is not bumped', async (
  $, on) => {
  const rig = await bootRig($, on)
  await fableHeld($, rig)
  await route($, 'effort=low')
  await planRoute($)
  expect(await stepOn($, rig, FABLE)).toEqual({ model: OPUS, effort: 'low' })
})

test('stand-in: an ultrathink floor ends at max, not past it', async (
  $, on) => {
  const rig = await bootRig($, on)
  await fableHeld($, rig)
  await ultrathink($)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect' })
  expect(await stepOn($, rig, FABLE)).toEqual({ model: OPUS, effort: 'max' })
})

test('stand-in: the verbose line names it as a cause', async ($, on) => {
  const logs = recordLogs(on)
  const rig = await bootRig($, on)
  await route($, 'verbose on')
  await fableHeld($, rig)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'reflect' })
  await stepOn($, rig, FABLE)
  expect(logs.some(l => l.startsWith('main:') && l.includes('stand-in')))
    .toBe(true)
})

// ---- keyword cap: prompt rules and dispatches set effort only ------------

test('keyword cap: a plan keyword on an opus session stays on opus at xhigh', async (
  $, on) => {
  const rig = await bootRig($, on, OPUS)
  await typed($, 'plan the billing migration')
  expect(await stepOn($, rig, OPUS)).toEqual({ model: OPUS, effort: 'xhigh' })
})

test('keyword cap: a reflect keyword on an opus session stays on opus at high', async (
  $, on) => {
  const rig = await bootRig($, on, OPUS)
  await typed($, 'why does the cache miss')
  expect(await stepOn($, rig, OPUS)).toEqual({ model: OPUS, effort: 'high' })
})

test('keyword cap: ultrathink on an opus session stays on opus at max', async (
  $, on) => {
  const rig = await bootRig($, on, OPUS)
  await ultrathink($)
  expect(await stepOn($, rig, OPUS)).toEqual({ model: OPUS, effort: 'max' })
})

test('keyword cap: a route tool call after a keyword still lifts to fable', async (
  $, on) => {
  const rig = await bootRig($, on, OPUS)
  await typed($, 'plan the billing migration')
  await planRoute($)
  expect((await stepOn($, rig, OPUS)).model).toBe(FABLE)
})

test('keyword cap: a held fable gives no stand-in notch to a capped keyword', async (
  $, on) => {
  const world = newWorld()
  const rig = await bootRig($, on, OPUS, 1000, world)
  await switchTo($, FABLE, OPUS, 'auto')
  await typed($, 'plan the billing migration')
  expect(await stepOn($, rig, OPUS)).toEqual({ model: OPUS, effort: 'xhigh' })
  expect(world.completions).not.toContain(FABLE)
})

test('keyword cap: a keyword inside a held best-tier run keeps the run on fable', async (
  $, on) => {
  const rig = await bootRun($, on, OPUS)
  await loadSkill($, 'feat')
  await endTurn($)
  await typed($, 'plan the next step')
  expect(await stepOn($, rig, OPUS)).toEqual({ model: FABLE, effort: 'xhigh' })
})

test('keyword cap: an unknown session model never lets a keyword lift main', async (
  $, on) => {
  const rig = await bootRig($, on, '')
  await typed($, 'plan the billing migration')
  expect((await stepOn($, rig, OPUS)).model).toBe(OPUS)
})

test('keyword cap: a dispatch outside a run keeps main on the session model', async (
  $, on) => {
  const rig = await bootRig($, on, OPUS)
  await dispatch($)
  expect(await stepOn($, rig, OPUS)).toEqual({ model: OPUS, effort: 'medium' })
})

// ---- /model <name>: the scope dialog -------------------------------------

const SCOPES = ['This project', 'This conversation', 'Everywhere']
const FABLE_1M = `${FABLE}[1m]`
const NO_SCOPE = 'model: no scope chosen, nothing changed'

type ModelRig = {
  w: World
  ran: string[] // the args the native /model got
  toasts: string[]
  rig: Rig
}

/** Boots with a bottom native /model that records its args. */
async function bootModel(
  $: Engine,
  on: On,
  answers: string[],
  session: string = OPUS,
  fx: Fixture = {},
): Promise<ModelRig> {
  const ran: string[] = []
  on('command.run', { command: 'model' }, (_a, e) => {
    ran.push(e.args)
    return { text: 'native' }
  })
  const toasts = recordToasts(on)
  const w = newWorld({ answers, ...fx })
  const rig = await bootRig($, on, session, 1000, w)
  return { w, ran, toasts, rig }
}

/** Runs `/model <args>` as typed (or from another origin). */
async function modelCmd(
  $: Engine,
  args: string,
  kind: 'composer' | 'sdk' = 'composer',
): Promise<string> {
  const out = await $.command.run({
    command: 'model',
    args,
    origin: { kind },
    presentation: { isFullscreen: false, columns: 80 },
  })
  return out.text ?? ''
}

const localOf = (w: World): Rec =>
  JSON.parse(w.files.get('local') ?? '{}') as Rec

test('model command: asks the three scopes, the full id, native not run', async (
  $, on) => {
  const m = await bootModel($, on, ['Later', 'Later'])
  await modelCmd($, 'fable')
  await modelCmd($, 'claude-fable-5-1[1m]')
  expect(m.w.asked.map(q => q.options)).toEqual([SCOPES, SCOPES])
  expect(m.w.asked.map(q => q.header)).toEqual(['model-router', 'model-router'])
  const [plain, long] = m.w.asked as [Asked, Asked]
  expect(plain.text.endsWith(`Switch main to ${FABLE} where?`)).toBe(true)
  expect(long.text.endsWith(`Switch main to ${FABLE_1M} where?`)).toBe(true)
  expect(m.ran).toEqual([])
})

test('model command: This project writes the full id and keeps the keys', async (
  $, on) => {
  const m = await bootModel($, on, ['This project'])
  m.w.files.set('local', JSON.stringify({ permissions: { allow: ['Bash'] } }))
  m.w.dirs.set(`${ROOT}/.claude`, { kind: 'dir', isLink: false })
  const out = await modelCmd($, 'fable')
  expect(localOf(m.w)).toEqual({
    permissions: { allow: ['Bash'] }, model: FABLE,
  })
  expect(m.w.files.get('local')).toBe(
    JSON.stringify(localOf(m.w), null, 2) + '\n')
  expect(out).toContain(`${FABLE} written to .claude/settings.local.json`)
  expect(out).toContain('remove its "model" key to undo')
  expect(out).not.toContain('file created')
  expect(m.toasts).toEqual([])
  expect(m.ran).toEqual([])
  expect((await stepOn($, m.rig, OPUS)).model).toBe(FABLE)
})

test('model command: This project keeps [1m] verbatim in the file', async (
  $, on) => {
  const m = await bootModel($, on, ['This project', 'This project'])
  await modelCmd($, 'fable[1m]')
  expect(localOf(m.w).model).toBe(FABLE_1M)
  await modelCmd($, 'claude-fable-5-1[1m]')
  expect(localOf(m.w).model).toBe(FABLE_1M)
  expect((await stepOn($, m.rig, OPUS)).model).toBe(FABLE)
})

test('model command: the [1m] note shows only for a token or session [1m]', async (
  $, on) => {
  const m = await bootModel($, on, ['This project', 'This project'])
  expect(await modelCmd($, 'fable')).not.toContain('[1m] follows')
  expect(await modelCmd($, 'fable[1m]')).toContain(
    "[1m] follows the session's variant")
  expect(m.ran).toEqual([])
})

test('model command: a [1m] session adds the note to a plain token', async (
  $, on) => {
  await bootModel($, on, ['This project'], `${OPUS}[1m]`)
  expect(await modelCmd($, 'fable')).toContain('[1m] follows')
})

test('model command: This project creates the file when absent', async (
  $, on) => {
  const m = await bootModel($, on, ['This project'])
  const out = await modelCmd($, 'opus')
  expect(localOf(m.w)).toEqual({ model: OPUS })
  expect(out).toContain('file created: keep it gitignored')
  expect(m.toasts).toEqual([])
})

const BAD_TEXT: [string, string, string][] = [
  ['null', 'null', 'not an object'],
  ['an array', '[]', 'not an object'],
  ['a string', '"x"', 'not an object'],
  ['broken JSON', '{nope', 'not JSON'],
  ['over the size cap', JSON.stringify({ pad: 'x'.repeat(70000) }),
    'too large'],
]

for (const [name, text, cause] of BAD_TEXT) {
  test(`model command: This project refuses a file: ${name}`, async (
    $, on) => {
    const m = await bootModel($, on, ['This project'])
    m.w.files.set('local', text)
    expect(await modelCmd($, 'fable')).toContain(`not written (${cause})`)
    expect(m.w.files.get('local')).toBe(text)
    expect(m.w.written).toEqual([])
    expect(m.toasts).toEqual([`settings.local.json not written: ${cause}`])
    expect(mainLine(await route($, 'show'))).toContain('user custom')
  })
}

const refusals: [string, (w: World) => void, string][] = [
  ['.claude link', w => w.dirs.set(`${ROOT}/.claude`,
    { kind: 'dir', isLink: true }), '.claude is a link'],
  ['.claude file', w => w.dirs.set(`${ROOT}/.claude`,
    { kind: 'file', isLink: false }), '.claude is not a directory'],
  ['settings link', w => {
    w.files.set('local', '{}')
    w.dirs.set(LOCAL_FILE, { kind: 'file', isLink: true })
  }, 'settings.local.json is a link'],
  ['.claude dangling link', w => w.dirs.set(`${ROOT}/.claude`,
    { kind: 'other', isLink: true, exists: false }), '.claude is a link'],
  ['settings dangling link', w => w.dirs.set(LOCAL_FILE,
    { kind: 'other', isLink: true, exists: false }),
  'settings.local.json is a link'],
  ['settings dir', w => {
    w.files.set('local', '{}')
    w.dirs.set(LOCAL_FILE, { kind: 'dir', isLink: false })
  }, 'not a regular file'],
  ['stat error', w => {
    w.files.set('local', '{}')
    w.brokenStat.add(LOCAL_FILE)
  }, 'fs error HooksError'],
]

for (const [name, setup, cause] of refusals) {
  test(`model command: This project refuses: ${name}`, async ($, on) => {
    const m = await bootModel($, on, ['This project'])
    setup(m.w)
    const before = m.w.files.get('local')
    const out = await modelCmd($, 'fable')
    expect(out).toContain(`not written (${cause})`)
    expect(m.w.files.get('local')).toBe(before)
    expect(m.w.written).toEqual([])
    expect(m.toasts).toEqual([`settings.local.json not written: ${cause}`])
    expect(mainLine(await route($, 'show'))).toContain('user custom')
    expect(m.ran).toEqual([])
  })
}

test('model command: a failing write reports an fs error, route set', async (
  $, on) => {
  const m = await bootModel($, on, ['This project'])
  m.w.failWrite = true
  const out = await modelCmd($, 'fable')
  expect(out).toContain('not written (fs error')
  expect(m.toasts).toHaveLength(1)
  expect(out).not.toContain('EACCES')
  expect(mainLine(await route($, 'show'))).toContain('user custom')
})

test('model command: This conversation sets the route, writes nothing', async (
  $, on) => {
  const m = await bootModel($, on, ['This conversation'])
  await route($, 'effort=max')
  const out = await modelCmd($, 'fable')
  expect(out).toContain(`sticky route ${FABLE} for this conversation`)
  expect(m.w.written).toEqual([])
  expect(m.w.files.has('local')).toBe(false)
  expect(m.ran).toEqual([])
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('user custom')
  expect(line).toContain('effort max')
  expect((await stepOn($, m.rig, OPUS)).model).toBe(FABLE)
})

test('model command: the local scopes drop the run slot', async ($, on) => {
  on('command.run', { command: 'model' }, () => ({ text: 'native' }))
  await bootRun($, on, OPUS, newWorld({ answers: ['This conversation'] }))
  await loadSkill($, 'feat')
  await endTurn($)
  expect(await modelCmd($, 'sonnet')).toContain('sticky route')
  expect(await route($, 'clear')).not.toContain('run slot dropped')
})

test('model command: Everywhere runs native, args unchanged', async (
  $, on) => {
  const m = await bootModel($, on, ['Everywhere'])
  expect(await modelCmd($, 'opus')).toBe('native')
  expect(m.ran).toEqual(['opus'])
  expect(m.w.written).toEqual([])
})

test('model command: Everywhere drops an earlier sticky model', async (
  $, on) => {
  const m = await bootModel($, on, ['This conversation', 'Everywhere'])
  await modelCmd($, 'fable')
  expect(mainLine(await route($, 'show'))).toContain('user custom')
  await modelCmd($, 'opus')
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
  expect(m.ran).toEqual(['opus'])
})

test('model command: Everywhere drops a sticky tier too, keeps effort', async (
  $, on) => {
  const m = await bootModel($, on, ['Everywhere'])
  await route($, 'plan')
  await modelCmd($, 'opus')
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('effort xhigh')
  expect(line).not.toContain(FABLE)
  expect(m.ran).toEqual(['opus'])
})

test('model command: no dialog for a call native owns', async ($, on) => {
  const m = await bootModel($, on, [])
  const args = ['', 'fable opus', 'default', 'opusplan', 'claude-opus-5-6',
    'haiku[1m]', 'whatever']
  for (const a of args) expect(await modelCmd($, a)).toBe('native')
  expect(m.ran).toEqual(args)
  expect(m.w.asked).toEqual([])
})

test('model command: no dialog from another origin', async ($, on) => {
  const m = await bootModel($, on, [])
  expect(await modelCmd($, 'fable', 'sdk')).toBe('native')
  expect(m.w.asked).toEqual([])
})

test('model command: no dialog when the router is off', async ($, on) => {
  const m = await bootModel($, on, [])
  await route($, 'off')
  expect(await modelCmd($, 'fable')).toBe('native')
  expect(m.w.asked).toEqual([])
})

test('model command: no dialog without a surface', async ($, on) => {
  const m = await bootModel($, on, [], OPUS, { surfaces: [] })
  expect(await modelCmd($, 'fable')).toBe('native')
  expect(m.w.asked).toEqual([])
})

test('model command: a second /model while one is open goes native', async (
  $, on) => {
  const m = await bootModel($, on, ['This conversation'])
  const held = deferred()
  const open = deferred()
  m.w.gate = held.gate
  m.w.onAsk = open.release
  const first = modelCmd($, 'fable')
  await open.gate
  expect(await modelCmd($, 'opus')).toBe('native')
  held.release()
  expect(await first).toContain('sticky route')
  expect(m.w.asked).toHaveLength(1)
})

test('model command: the question notes a project pin only when set', async (
  $, on) => {
  const m = await bootModel($, on, ['Later', 'Later'])
  await modelCmd($, 'fable')
  m.w.files.set('local', JSON.stringify({ model: OPUS }))
  await modelCmd($, 'fable')
  const [bare, pinned] = m.w.asked as [Asked, Asked]
  expect(bare.text).not.toContain('pins')
  const lines = pinned.text.split('\n')
  const note = lines[lines.length - 2] ?? ''
  expect(note).toContain(
    `this project pins ${OPUS} in .claude/settings.local.json`)
  expect(note).toContain('the project pin wins')
  expect(lines[lines.length - 1]).toBe(`Switch main to ${FABLE} where?`)
})

test('model command: Esc or free text cancels, nothing changes', async (
  $, on) => {
  const m = await bootModel($, on, [])
  expect(await modelCmd($, 'fable')).toBe(NO_SCOPE)
  m.w.answers.push('maybe')
  expect(await modelCmd($, 'fable')).toBe(NO_SCOPE)
  expect(m.ran).toEqual([])
  expect(m.w.written).toEqual([])
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('model command: Everywhere: native runs once, its throw is reported, not re-run', async (
  $, on) => {
  const ran: string[] = []
  on('command.run', { command: 'model' }, (_a, e) => {
    ran.push(e.args)
    throw new Error('boom')
  })
  await bootRig($, on, OPUS, 1000, newWorld({ answers: ['Everywhere'] }))
  const out = await modelCmd($, 'opus')
  expect(out).toContain('model failed (')
  expect(out).toContain('/route show')
  expect(out).not.toContain('boom')
  expect(ran).toEqual(['opus'])
})

for (const scope of ['This conversation', 'This project']) {
  test(`model command: ${scope}: a throw after the answer never reaches native`, async (
    $, on) => {
    // the dialog is answered, then the status text reads the clock
    const m = await bootModel($, on, [scope], OPUS, {
      clockFailsAfterAsk: true,
    })
    const out = await modelCmd($, 'fable')
    expect(out).toContain('model failed (')
    expect(out).toContain('/route show')
    expect(out).not.toContain('boom')
    expect(m.ran).toEqual([])
  })
}

test('writes: kit: only the project settings.local.json is carved out', {
  plugins: [PROBE],
}, async ($, on) => {
  const m = await bootModel($, on, [])
  const out = await $.command.run({
    command: 'probe',
    args: LOCAL_FILE,
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 80 },
  })
  expect(out.text).toBe('written')
  for (const path of [`${ROOT}/.claude/settings.json`,
    `${LOCAL_FILE}.bak`, `${ROOT}/other/settings.local.json`, HOME_FILE]) {
    expect(worldServes(m.w, path), path).toBe(false)
  }
  expect(worldServes(m.w, LOCAL_FILE)).toBe(true)
})

// ---- /model picker: deny now, ask after ----------------------------------

const BUSY = 'answer the open dialog first'
const DENY = 'model-router asks where this switch applies'

type SwitchSource = 'picker' | 'command' | 'sdk'

/** The PreModelSwitch input of a switch to `requested` from `source`. */
const preSwitch = (requested: string | null, source: SwitchSource) => ({
  from_model: OPUS,
  to_model: requested ?? OPUS,
  requested_model: requested,
  source,
  context_tokens: 0,
  prompt_cache_warm: false,
  cache_ttl: '5m' as const,
  estimated_cache_write_usd: 0,
  pricing: 'catalog' as const,
})

const pick = (
  $: Engine,
  requested: string | null,
  source: SwitchSource = 'picker',
) => $.classic.PreModelSwitch(preSwitch(requested, source))

/** Lets the timers and the hooks of the deferred dialog run. */
async function settle(done: () => boolean = () => false): Promise<void> {
  for (let i = 0; i < 100 && !done(); i++) {
    await new Promise(r => setTimeout(r, 0))
  }
  for (let i = 0; i < 5; i++) await new Promise(r => setTimeout(r, 0))
}

type PickerRig = ModelRig & { logs: string[] }

async function bootPicker(
  $: Engine,
  on: On,
  answers: string[],
  fx: Fixture = {},
): Promise<PickerRig> {
  const logs = recordLogs(on)
  const m = await bootModel($, on, answers, OPUS, fx)
  return { ...m, logs }
}

/** The picker's switch, then the deferred question answered. */
async function pickAndAnswer(
  $: Engine,
  p: PickerRig,
  requested: string,
): Promise<unknown> {
  const out = await pick($, requested)
  await p.rig.clock.advance(300)
  await settle(() => p.w.asked.length > 0 && p.logs.length > 0)
  return out
}

test('picker: a known model is denied at once, the question comes after', async (
  $, on) => {
  const p = await bootPicker($, on, ['This conversation'])
  const held = deferred()
  p.w.gate = held.gate
  const out = await pick($, 'fable')
  expect(JSON.stringify(out)).toContain(DENY)
  expect(JSON.stringify(out)).toContain('deny')
  expect(p.w.asked).toEqual([])
  await p.rig.clock.advance(300)
  await settle(() => p.w.asked.length > 0)
  const [q] = p.w.asked as [Asked]
  expect(q.options).toEqual(SCOPES)
  expect(q.header).toBe('model-router')
  expect(q.text.endsWith(`Switch main to ${FABLE} where?`)).toBe(true)
  held.release()
  await settle()
  expect(p.ran).toEqual([])
})

const PASSTHROUGH: [string, string | null, SwitchSource][] = [
  ['source command', 'fable', 'command'],
  ['source sdk', 'fable', 'sdk'],
  ['Default (null)', null, 'picker'],
  ['opusplan', 'opusplan', 'picker'],
  ['an unknown id', 'claude-opus-5-6', 'picker'],
]

for (const [name, requested, source] of PASSTHROUGH) {
  test(`picker: ${name} passes through, no question`, async ($, on) => {
    const p = await bootPicker($, on, ['This project'])
    const out = await pick($, requested, source)
    await p.rig.clock.advance(300)
    await settle()
    expect(JSON.stringify(out)).not.toContain('deny')
    expect(p.w.asked).toEqual([])
    expect(p.toasts).toEqual([])
  })
}

test('picker: router off passes through', async ($, on) => {
  const p = await bootPicker($, on, [])
  await route($, 'off')
  expect(JSON.stringify(await pick($, 'fable'))).not.toContain('deny')
  await settle()
  expect(p.w.asked).toEqual([])
})

test('picker: no surface passes through', async ($, on) => {
  const p = await bootPicker($, on, [], { surfaces: [] })
  expect(JSON.stringify(await pick($, 'fable'))).not.toContain('deny')
  await settle()
  expect(p.w.asked).toEqual([])
})

test('picker: an open dialog denies with a toast, never native', async (
  $, on) => {
  const p = await bootPicker($, on, ['This conversation'])
  const held = deferred()
  const open = deferred()
  p.w.gate = held.gate
  p.w.onAsk = open.release
  const first = modelCmd($, 'fable')
  await open.gate
  const out = await pick($, 'sonnet')
  expect(JSON.stringify(out)).toContain('deny')
  expect(p.toasts).toEqual([BUSY])
  held.release()
  await first
  expect(p.w.asked).toHaveLength(1)
  expect(p.ran).toEqual([])
})

test('picker: This project writes the full id, native never runs', async (
  $, on) => {
  const p = await bootPicker($, on, ['This project'])
  await pickAndAnswer($, p, 'fable')
  expect(localOf(p.w)).toEqual({ model: FABLE })
  expect(p.logs.join('\n')).toContain(`${FABLE} written to`)
  expect(p.ran).toEqual([])
  expect((await stepOn($, p.rig, OPUS)).model).toBe(FABLE)
})

test('picker: This conversation routes only, writes nothing', async (
  $, on) => {
  const p = await bootPicker($, on, ['This conversation'])
  await pickAndAnswer($, p, 'fable')
  expect(p.w.written).toEqual([])
  expect(p.logs.join('\n')).toContain('for this conversation')
  expect(p.ran).toEqual([])
  expect((await stepOn($, p.rig, OPUS)).model).toBe(FABLE)
})

test('picker: Everywhere drops a hand pick, runs native once', async (
  $, on) => {
  const p = await bootPicker($, on, ['This conversation', 'Everywhere'])
  await modelCmd($, 'fable')
  await pickAndAnswer($, p, 'sonnet')
  expect(p.ran).toEqual(['sonnet'])
  expect(p.w.asked).toHaveLength(2)
  expect(p.w.written).toEqual([])
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
  expect(p.logs.filter(l => l.includes('native'))).toEqual([])
})

test('picker: dismissed logs the no-scope text and frees the slot', async (
  $, on) => {
  const p = await bootPicker($, on, [])
  await pickAndAnswer($, p, 'fable')
  expect(p.logs).toContain(NO_SCOPE)
  expect(p.ran).toEqual([])
  expect(p.w.written).toEqual([])
  await pickAndAnswer($, p, 'fable')
  expect(p.w.asked).toHaveLength(2)
})

test('picker: a throwing sleep is logged under its key, slot freed', async (
  $, on) => {
  const logs = recordLogs(on)
  const m = await bootModel($, on, ['This project'], OPUS,
    { sleepFails: true })
  expect(JSON.stringify(await pick($, 'fable'))).toContain('deny')
  await settle(() => logs.some(l => l.includes('PreModelSwitch picker')))
  expect(logs.join('\n')).toContain('PreModelSwitch picker failed')
  expect(m.w.asked).toEqual([])
  expect(m.w.written).toEqual([])
  const again = await pick($, 'fable')
  expect(JSON.stringify(again)).toContain('deny')
  expect(m.toasts).toEqual([])
})

test('picker: a throw after the answer is logged, native never runs', async (
  $, on) => {
  const logs = recordLogs(on)
  const m = await bootModel($, on, ['This conversation'], OPUS,
    { clockFailsAfterAsk: true })
  await pick($, 'fable')
  await settle(() => logs.some(l => l.includes('model failed (')))
  expect(logs.join('\n')).toContain('model failed (')
  expect(m.ran).toEqual([])
  await pick($, 'fable')
  await settle()
  expect(m.w.asked).toHaveLength(2)
})

test('picker: a changed conversation applies nothing', async ($, on) => {
  const p = await bootPicker($, on, ['This project'])
  const held = deferred()
  const open = deferred()
  p.w.gate = held.gate
  p.w.onAsk = open.release
  await pick($, 'fable')
  await p.rig.clock.advance(300)
  await open.gate
  p.w.sessionId = 's2'
  held.release()
  await settle(() => p.logs.length > 0)
  expect(p.logs.join('\n')).toContain('conversation changed')
  expect(p.w.written).toEqual([])
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})

test('picker: a native switch passes without a second dialog', async (
  $, on) => {
  const p = await bootPicker($, on, ['Everywhere'])
  await pickAndAnswer($, p, 'opus')
  expect(JSON.stringify(await pick($, 'opus', 'command'))).not.toContain('deny')
  expect(p.w.asked).toHaveLength(1)
})

test('picker: a pick clears the mark of its target', async ($, on) => {
  const p = await bootPicker($, on, ['This conversation'])
  await route($, 'model=fable')
  await stepOn($, p.rig, FABLE)
  await failWith($, 'overloaded')
  expect(await route($, 'show')).toContain('claude-fable-5-1 for')
  await pickAndAnswer($, p, 'fable')
  expect(await route($, 'show')).toContain('down: none')
})

test('picker: a PostModelSwitch of a denied pick keeps the hand pick', async (
  $, on) => {
  const p = await bootPicker($, on, ['This conversation', 'This conversation'])
  await modelCmd($, 'fable')
  const held = deferred()
  p.w.gate = held.gate
  await pick($, 'sonnet')
  await switchTo($, OPUS, SONNET, 'picker')
  held.release()
  await settle()
  expect(mainLine(await route($, 'show'))).toContain('user custom')
})

// ---- hand pick: a model chosen by hand always switches --------------------

type HandRig = {
  w: World
  rig: Rig
  usage: { set: (n: number) => void }
  logs: string[]
}

async function bootHand(
  $: Engine,
  on: On,
  answers: string[],
  session: string = OPUS,
  tokens = 1000,
  fx: Fixture = {},
): Promise<HandRig> {
  on('command.run', { command: 'model' }, () => ({ text: 'native' }))
  const logs = recordLogs(on)
  const w = newWorld({ answers, ...fx })
  const { rig, usage } = await bootRigVar($, on, session, tokens, w)
  return { w, rig, usage, logs }
}

test('hand pick: a held-down target waits across the turn boundary', async (
  $, on) => {
  const h = await bootHand($, on, ['This conversation'])
  await modelCmd($, 'fable')
  expect((await stepOn($, h.rig, OPUS)).model).toBe(FABLE)
  await failWith($, 'overloaded')
  await endTurn($)
  expect((await stepOn($, h.rig, OPUS)).model).toBe(OPUS)
  await stepOn($, h.rig, OPUS)
  expect(h.logs.filter(l => l.includes('hand pick waits'))).toHaveLength(1)
  await endTurn($)
  await h.rig.clock.advance(15 * 60000)
  expect((await stepOn($, h.rig, OPUS)).model).toBe(FABLE)
})

test('hand pick: the current model down leaves it for the hand pick', async (
  $, on) => {
  const h = await bootHand($, on, ['This conversation'], OPUS, 300000,
    { home: { mainUpgrade: false } })
  await stepOn($, h.rig, OPUS)
  await failWith($, 'overloaded')
  await endTurn($)
  await modelCmd($, 'fable')
  expect((await stepOn($, h.rig, OPUS)).model).toBe(FABLE)
})

test('hand pick: an unranked session model does not trap it', async (
  $, on) => {
  const h = await bootHand($, on, ['This conversation'], 'claude-zz-9')
  await modelCmd($, 'opus')
  expect((await stepOn($, h.rig, 'claude-zz-9')).model).toBe(OPUS)
})

test('hand pick: over the upgrade cap and with the switch off still moves', async (
  $, on) => {
  const h = await bootHand($, on, ['This conversation'], OPUS, 300000,
    { home: { mainUpgrade: false } })
  await modelCmd($, 'fable')
  expect((await stepOn($, h.rig, OPUS)).model).toBe(FABLE)
  await endTurn($)
  expect((await stepOn($, h.rig, OPUS)).model).toBe(FABLE)
})

test('hand pick: over the downgrade cap with switch off still moves', async (
  $, on) => {
  const h = await bootHand($, on, ['This conversation'], FABLE, 300000)
  await route($, 'switch off')
  await modelCmd($, 'sonnet')
  expect((await stepOn($, h.rig, FABLE)).model).toBe(SONNET)
})

test('hand pick: a typed /route model= keeps the caps', async ($, on) => {
  const h = await bootHand($, on, [], OPUS, 300000)
  await route($, 'model=fable')
  expect((await stepOn($, h.rig, OPUS)).model).toBe(OPUS)
})

test('hand pick: the current model pinned and down falls to the next', async (
  $, on) => {
  const h = await bootHand($, on, ['This conversation'])
  await modelCmd($, 'opus')
  expect((await stepOn($, h.rig, OPUS)).model).toBe(OPUS)
  await failWith($, 'overloaded')
  const same = (await stepOn($, h.rig, OPUS)).model
  expect(same).not.toBe(OPUS)
  await endTurn($)
  expect((await stepOn($, h.rig, OPUS)).model).toBe(same)
})

test('hand pick: a target that fails mid-turn is left', async ($, on) => {
  const h = await bootHand($, on, ['This conversation'])
  await modelCmd($, 'fable')
  expect((await stepOn($, h.rig, OPUS)).model).toBe(FABLE)
  await failWith($, 'overloaded')
  expect((await stepOn($, h.rig, OPUS)).model).not.toBe(FABLE)
})

test('hand pick: outgrowing a known window still returns home', async (
  $, on) => {
  const h = await bootHand($, on, ['This conversation'], FABLE, 1000,
    { home: { windows: { [HAIKU]: 200000 } } })
  await modelCmd($, 'haiku')
  expect((await stepOn($, h.rig, FABLE)).model).toBe(HAIKU)
  h.usage.set(250000)
  expect((await stepOn($, h.rig, FABLE)).model).toBe(FABLE)
})

test('hand pick: a native user switch drops it', async ($, on) => {
  const h = await bootHand($, on, ['This conversation'])
  await modelCmd($, 'fable')
  await switchTo($, OPUS, SONNET, 'picker')
  expect((await stepOn($, h.rig, SONNET)).model).toBe(SONNET)
  expect(mainLine(await route($, 'show'))).toContain('session defaults')
})
