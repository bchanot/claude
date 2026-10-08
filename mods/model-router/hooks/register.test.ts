import { test, expect } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

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

test('ultrathink in a prompt sets escalate on main', async ($, on) => {
  on('prompt.submit', ($, e) => ({ text: e.text }))
  await boot($, on)
  await $.prompt.submit({
    text: 'ultrathink please',
    wait: false,
    origin: { kind: 'composer' },
  })
  expect(mainLine(await route($, 'show'))).toContain('prompt escalate')
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
  input: ReturnType<typeof stepInput>,
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
