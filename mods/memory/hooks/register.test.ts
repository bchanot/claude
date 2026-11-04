import { test, expect, mock } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'
import { cap, tail, redact, normalize } from './register'

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

// Secret-shaped inputs are built at runtime; expectations are literals.
const A = 'A'.repeat(40)
const now = () =>
  typeof performance === 'undefined' ? Date.now() : performance.now()
const PEM = '-----'

const REDACT_CASES: [string, string, string][] = [
  ['1 env assignment', 'run X_' + 'TOKEN=abc123 make',
    'run X_TOKEN=<redacted> make'],
  ['1 case-insensitive', 'pass' + 'word=hunter2 x', 'password=<redacted> x'],
  ['2 stripe', 'k ' + 'sk_' + 'live_' + 'a1B2c3D4e5F6 z',
    'k <redacted:stripe> z'],
  ['3 aws', 'deploy KEY ' + 'AK' + 'IA' + 'Q'.repeat(16) + ' done',
    'deploy KEY <redacted:aws> done'],
  ['4 github', 't ' + 'gh' + 'p_' + A.slice(0, 36) + ' z',
    't <redacted:github> z'],
  ['5 slack', 't ' + 'xo' + 'xb-' + '1234567890-abcdef' + ' z',
    't <redacted:slack> z'],
  ['6 sendgrid',
    't ' + 'S' + 'G.' + 'a'.repeat(20) + '.' + 'b'.repeat(20) + ' z',
    't <redacted:sendgrid> z'],
  ['7 supabase', 't ' + 'sb_' + 'secret_' + 'abcdefghij12' + ' z',
    't <redacted:supabase> z'],
  ['8 private key',
    'a ' + PEM + 'BEGIN RSA PRIVATE KEY' + PEM + '\nMIIB\n' +
      PEM + 'END RSA PRIVATE KEY' + PEM + ' b',
    'a <redacted:private-key> b'],
  ['8 unterminated key',
    'a ' + PEM + 'BEGIN PRIVATE KEY' + PEM + '\nMIIB\nmore',
    'a <redacted:private-key>'],
  ['9 bearer', 'H: Bearer ' + 'abc.DEF-123_456' + ' z',
    'H: Bearer <redacted> z'],
  ['10 url credentials', 'git clone ' + 'https://' + 'user:pw' + '@host/x',
    'git clone https://<redacted>@host/x'],
]

for (const [name, input, expected] of REDACT_CASES) {
  test(`redact pattern ${name}`, () => {
    expect(redact(input)).toBe(expected)
  })
}

test('redact keeps a 40-hex SHA', () => {
  const sha = 'a'.repeat(20) + '1'.repeat(20)
  expect(redact('commit ' + sha)).toBe('commit ' + sha)
})

test('redact caps a 70 KiB input at 65536 code units', () => {
  expect(redact('x'.repeat(70 * 1024)).length).toBeLessThanOrEqual(65536)
})

test('cap keeps the first n, tail keeps the last n', () => {
  expect(cap('abcdef', 3)).toBe('abc')
  expect(tail('abcdef', 3)).toBe('def')
  expect(tail('abc', 0)).toBe('')
  expect(tail('abc', 10)).toBe('abc')
})

test('normalize collapses paths, hashes, numbers and spaces', () => {
  expect(normalize('Error: /home/u/x/y.ts:42 failed'))
    .toBe('error: <path>:# failed')
  expect(normalize('commit 9a24a62e failed')).toBe('commit <hex> failed')
  expect(normalize('  a \t b  7 ')).toBe('a b #')
})

test('TIME1: redact and normalize stay fast on a 64 KiB run of letters', () => {
  const text = 'a'.repeat(65536)
  for (const fn of [redact, normalize]) {
    const t0 = now()
    fn(text)
    expect(now() - t0).toBeLessThan(500)
  }
})
