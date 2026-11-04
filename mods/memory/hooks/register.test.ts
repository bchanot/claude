import { test, expect, mock } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

const HOME = '/home/t'
const SWITCH = `${HOME}/.claude/memory.json`
const ROOT = '/work/app'
const BASH_ANSWER = { result: { stdout: 'ok', stderr: '' } }

type World = {
  switchText: string | undefined // ~/.claude/memory.json (undefined: absent)
  rootFails: boolean // session.root rejects
  logs: string[] // every $.ui.log line
  sets: string[] // every store key written
  tools: string[] // every tool name registered
}

/** The bottom hooks the mod reads, over a fake world. */
async function boot(
  $: Engine,
  on: On,
  switchText?: string,
  rootFails = false,
): Promise<World> {
  const w: World = { switchText, rootFails, logs: [], sets: [], tools: [] }
  mock.clock(on)
  // not mock.store: the test must see every key written
  const kv = new Map<string, unknown>()
  on('store.get', (_a, e) => ({ value: kv.get(e.key) }))
  on('store.keys', () => ({ value: [...kv.keys()] }))
  on('store.delete', (_a, e) => ({ value: void kv.delete(e.key) }))
  on('store.set', (_a, e) => {
    w.sets.push(e.key)
    kv.set(e.key, e.value)
    return { value: undefined }
  })
  on('tool.register', (_a, e) => {
    w.tools.push(e.name)
    return { value: undefined } as never
  })
  on('env.get', () => ({ value: HOME }))
  on('fs.stat', (_a, e) => {
    if (e.path !== SWITCH || w.switchText === undefined) {
      throw new Error('ENOENT')
    }
    return { value: {
      kind: 'file' as const, size: w.switchText.length, mtimeMs: 0,
      isLink: false,
    } }
  })
  on('fs.read', (_a, e) => {
    if (e.path !== SWITCH || w.switchText === undefined) {
      throw new Error('ENOENT')
    }
    return { value: w.switchText }
  })
  on('session.root', () => {
    if (w.rootFails) throw new Error('no root')
    return { value: ROOT }
  })
  on('session.id', () => ({ value: 's1' }))
  on('session.start', (_a, e) => ({ cwd: e.cwd }))
  on('ui.log', (_a, e) => {
    w.logs.push(String((e as { text?: unknown }).text))
    return { value: undefined } as never
  })
  on('tool.call', { tool: 'Bash' }, () => BASH_ANSWER as never)
  await $.session.start({ cwd: '/tmp', surface: null, isInteractive: false })
  return w
}

const bash = ($: Engine, command: string) =>
  $.tool.call({ tool: 'Bash', command })

test('TOFF: enabled false passes a Bash answer through, store empty',
  async ($, on) => {
    const w = await boot($, on, '{"enabled": false}')
    const out = await bash($, 'make test')
    expect(out).toEqual(BASH_ANSWER)
    expect(w.sets).toEqual([])
  })

test('an absent switch file keeps the mod on', async ($, on) => {
  const w = await boot($, on)
  expect(await bash($, 'ls')).toEqual(BASH_ANSWER)
  expect(w.tools).toEqual(['memory_pending'])
})

test('a malformed switch file keeps the mod on', async ($, on) => {
  const w = await boot($, on, '{nope')
  expect(await bash($, 'ls')).toEqual(BASH_ANSWER)
  expect(w.logs).toEqual([])
  expect(w.tools).toEqual(['memory_pending'])
})

test('the tool is not registered when the switch is off', async ($, on) => {
  const w = await boot($, on, '{"enabled": false}')
  expect(w.tools).toEqual([])
})

test('FAILOPEN: a rejecting session.root still returns the answer',
  async ($, on) => {
    const w = await boot($, on, undefined, true)
    expect(await bash($, 'ls')).toEqual(BASH_ANSWER)
    expect(await bash($, 'ls')).toEqual(BASH_ANSWER)
    const warns = w.logs.filter(l => l.startsWith('memory: Bash hook'))
    expect(warns).toHaveLength(1)
  })
