import { test, expect, mock } from 'claude-code/testing'
import type { Engine, MockClock } from 'claude-code/testing'
import type { On, TurnStepInput } from 'claude-code'

const FABLE = 'claude-fable-5-1'
const OPUS = 'claude-opus-5-5'
const SONNET = 'claude-sonnet-5-5'
const HAIKU = 'claude-haiku-4-5-20251001'

/**
 * Fires session.start so the mod loads its config and registers /route.
 * The bottom hooks the router reads are in place before the first `$` call:
 * the session model, the classic failure and switch events, a mock clock,
 * a small context (`tokens`; null = usage unanswered, size unknown).
 */
async function boot(
  $: Engine,
  on: On,
  model: string = FABLE,
  tokens: number | null = 1000,
): Promise<MockClock> {
  const clock = mock.clock(on)
  on('session.model', () => ({ value: model }))
  on('classic.StopFailure', () => ({}))
  on('classic.PostModelSwitch', () => ({}))
  on('skill.prompt', ($, e) => ({ text: e.text }))
  on('agent.offer', () => ({ isOffered: true }))
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

// `enabled: false` in ~/.claude/model-router.json cannot be reached here (the
// kit has no fs); the shared off path is covered through `/route off`.
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
// session-only off is reachable here (the kit has no fs).
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

// The kit has no fs: the reload read fails, so the previous cfg must stay.
test('reload with an unreadable override keeps the previous config', async (
  $, on) => {
  await boot($, on)
  await route($, 'switch on')
  const out = await route($, 'reload')
  expect(out).toContain('switch: on')
  expect(await route($, 'show')).toContain('switch: on')
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
  const clock = await boot($, on, model, tokens)
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
  source: 'command' | 'auto',
) => $.classic.PostModelSwitch({
  from_model: from,
  to_model: to,
  requested_model: null,
  source,
  context_tokens: 0,
  prompt_cache_warm: false,
  cache_ttl: '5m',
  estimated_cache_write_usd: 0,
  pricing: 'catalog',
})

const planRoute = ($: Engine) =>
  $.tool.call({ tool: ROUTE_TOOL, phase: 'plan' })

/** A bottom `session.usage` answering a context of `tokens`. */
function usageOf(on: On, tokens: number): void {
  on('session.usage', () => ({
    value: {
      startedAt: 0,
      context: { window: 1000000, tokens },
      rateLimits: [],
    },
  }))
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
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  expect(await stepOn($, rig, FABLE)).toEqual({ model: FABLE, effort: 'low' })
})

test('downgrade: the switch on moves main to the cheap tier', async (
  $, on) => {
  const rig = await bootRig($, on)
  await route($, 'switch on')
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  const sent = await stepOn($, rig, FABLE)
  expect(sent.model).toBe(HAIKU)
  expect(sent.effort).toBeUndefined()
})

test('fallback: a rate limit on fable moves plan to opus xhigh', async (
  $, on) => {
  const rig = await bootRig($, on)
  await planRoute($)
  expect((await stepOn($, rig, FABLE)).model).toBe(FABLE)
  await failWith($, 'rate_limit')
  expect(await stepOn($, rig, FABLE)).toEqual({ model: OPUS, effort: 'xhigh' })
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
  const rig = await bootRig($, on, HAIKU)
  await typed($, 'planifie la migration')
  expect(await stepOn($, rig, HAIKU)).toEqual({ model: FABLE, effort: 'xhigh' })
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

test('text: show names the model a floor upgrade moves to', async (
  $, on) => {
  await bootRig($, on, HAIKU)
  await $.prompt.submit({
    text: 'ultrathink please',
    wait: false,
    origin: { kind: 'composer' },
  })
  const line = mainLine(await route($, 'show'))
  expect(line).toContain(`${FABLE} (upgrade)`)
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
async function bootRun($: Engine, on: On, model: string = FABLE) {
  on('tool.call', { tool: 'Skill' }, () => ({
    result: { success: true, commandName: 'bottom' },
  }))
  return bootRig($, on, model)
}

const spawnOf = (agent: string, extra: object = {}) =>
  ({ ...spawnInput(), subagentType: agent, ...extra })

const offerOf = ($: Engine, agent: string, source: string) =>
  $.agent.offer({
    agent,
    description: 'd',
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

test('run slot: a model-loaded helper skill keeps it', async ($, on) => {
  await bootRun($, on)
  await loadSkill($, 'feat')
  await loadSkill($, 'using-git-worktrees')
  expect(mainLine(await route($, 'show'))).toContain('skill mechanical')
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
  on('env.get', () => ({ value: '/home/t' }))
  on('fs.exists', () => ({ value: true }))
  on('fs.stat', () => ({
    value: { kind: 'file' as const, size: 40, mtimeMs: 0, isLink: false },
  }))
  on('fs.read', () => ({ value: '{"agents":{"verifier":null}}' }))
  const rig = await bootRun($, on)
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
