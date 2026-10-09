import { test, expect } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On, TurnStepInput } from 'claude-code'

/** Fires session.start so the mod loads its config and registers /route. */
async function boot($: Engine, on: On): Promise<void> {
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  await $.session.start({ cwd: '/tmp', surface: null, isInteractive: false })
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

test('Skill(effort-low) is answered without next, route shows low', async (
  $, on) => {
  let reached = false
  on('tool.call', { tool: 'Skill' }, () => {
    reached = true
    return { result: { success: true, commandName: 'bottom' } }
  })
  await boot($, on)
  const out = await $.tool.call({ tool: 'Skill', skill: 'effort-low' })
  expect(out).toMatchObject({
    result: { success: true, commandName: 'effort-low' },
  })
  expect(reached).toBe(false)
  const line = mainLine(await route($, 'show'))
  expect(line).toContain('skill effort-low')
  expect(line).toContain('effort low')
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
  expect(mainLine(alias)).toContain('claude-sonnet-5-5')
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

test('floor: typed /effort-medium clamps low, lets max pass', async (
  $, on) => {
  const seen = await bootFloor($, on)
  await $.skill.prompt({ skill: 'effort-medium', text: 'x' })
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'mechanical' })
  expect(await stepEffort($, seen)).toBe('medium')
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'escalate' })
  expect(await stepEffort($, seen)).toBe('max')
})

test('floor: typed /effort-low lowers an unrouted turn', async ($, on) => {
  const seen = await bootFloor($, on)
  const out = await $.skill.prompt({ skill: 'effort-low', text: 'x' })
  expect(out.text).toContain('minimum')
  expect(await stepEffort($, seen)).toBe('low')
})

test('floor: survives a skill load', async ($, on) => {
  const seen = await bootFloor($, on)
  await ultrathink($)
  await $.tool.call({ tool: ROUTE_TOOL, phase: 'orchestrate' })
  await $.tool.call({ tool: 'Skill', skill: 'other' })
  expect(await stepEffort($, seen)).toBe('max')
  expect(mainLine(await route($, 'show'))).not.toContain('orchestrate')
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

test('typed marker: a preload in a live agent is ignored', async ($, on) => {
  const seen = await bootFloor($, on)
  await $.agent.spawn(spawnInput())
  const out = await $.skill.prompt({ skill: 'effort-max', text: 'x' })
  expect(out.text?.startsWith('model-router: effort-max preload')).toBe(true)
  expect(mainLine(await route($, 'show'))).not.toContain('floor')
  expect(await stepEffort($, seen)).not.toBe('max')
})

test('typed marker: /effort-max seen at submit writes the floor', async (
  $, on) => {
  await bootFloor($, on)
  await $.agent.spawn(spawnInput())
  await $.prompt.submit({
    text: '/effort-max go',
    wait: false,
    origin: { kind: 'composer' },
  })
  await $.skill.prompt({ skill: 'effort-max', text: 'x' })
  expect(mainLine(await route($, 'show'))).toContain('floor max')
})

test('typed slash with no agent and no marker writes the floor', async (
  $, on) => {
  await bootFloor($, on)
  await $.skill.prompt({ skill: 'effort-max', text: 'x' })
  expect(mainLine(await route($, 'show'))).toContain('floor max')
})
