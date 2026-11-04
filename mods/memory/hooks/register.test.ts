import { test, expect, mock } from 'claude-code/testing'
import type { Engine, MockClock } from 'claude-code/testing'
import type { On } from 'claude-code'
import {
  cap, tail, redact, normalize, failureLine, sessionOf, addFailure,
  entriesOf, isSuperseded, grams, buildIndex, matchOf,
  segments, suiteKeyOf, commitLabel, finishLabel,
} from './register'

const HOME = '/home/t'
const SWITCH = `${HOME}/.claude/memory.json`
const ROOT = '/work/app'
const BASH_ANSWER = { result: { stdout: 'ok', stderr: '' } }

type World = {
  switchText: string | undefined // ~/.claude/memory.json (undefined: absent)
  rootFails: boolean // session.root rejects
  id: string // what session.id answers now
  root: string // what session.root answers now
  answer: unknown // what the Bash bottom answers now
  byCommand: Map<string, unknown> // answers that depend on the command
  clock: MockClock
  kv: Map<string, unknown> // the store
  sets: string[] // every store key written
  logs: string[] // every $.ui.log line
  tools: string[] // every tool name registered
  files: Map<string, string | null> // other files (null: a directory)
  unreadable: Set<string> // paths whose fs.read throws
  statFails: Set<string> // paths whose fs.stat throws though they exist
  existsFails: Set<string> // paths whose fs.exists throws
  gets: number // store.get calls
  getsFail: boolean // store.get throws
}

type Opts = {
  switchText?: string
  rootFails?: boolean
  seed?: Record<string, unknown> // the store at the start
  storeFails?: boolean // store.set rejects (a hand-made store)
  files?: Record<string, string | null> // registries under the root
  unreadable?: string[] // paths whose fs.read throws
  statFails?: string[] // paths whose fs.stat throws though they exist
  existsFails?: string[] // paths whose fs.exists throws
}

/**
 * The plugin's store over a Map the test can read and count. mock.store
 * is not used: it offers no read-back, and the kit refuses a second
 * store.set hook to observe or fail it.
 */
function handStore(on: On, w: World, fails: boolean): void {
  on('store.get', (_a, e) => {
    w.gets++
    if (w.getsFail) throw new Error('boom')
    return { value: w.kv.get(e.key) }
  })
  on('store.keys', () => ({ value: [...w.kv.keys()] }))
  on('store.delete', (_a, e) => ({ value: void w.kv.delete(e.key) }))
  on('store.set', (_a, e) => {
    if (fails) throw new Error('disk full')
    w.sets.push(e.key)
    w.kv.set(e.key, JSON.parse(JSON.stringify(e.value)))
    return { value: undefined }
  })
}

/** The bottom hooks the mod reads, over a fake world. */
async function boot($: Engine, on: On, o: Opts = {}): Promise<World> {
  const clock = mock.clock(on, { now: 1000 })
  const w: World = {
    switchText: o.switchText, rootFails: o.rootFails ?? false,
    id: 's1', root: ROOT,
    answer: BASH_ANSWER, byCommand: new Map(), clock,
    kv: new Map(Object.entries(o.seed ?? {})),
    sets: [], logs: [], tools: [],
    files: new Map(Object.entries(o.files ?? {})),
    unreadable: new Set(o.unreadable ?? []),
    statFails: new Set(o.statFails ?? []),
    existsFails: new Set(o.existsFails ?? []),
    gets: 0, getsFail: false,
  }
  handStore(on, w, o.storeFails ?? false)
  on('tool.register', (_a, e) => {
    w.tools.push(e.name)
    return { value: undefined } as never
  })
  on('env.get', () => ({ value: HOME }))
  on('fs.exists', (_a, e) => {
    if (w.existsFails.has(e.path)) throw new Error('EIO')
    return { value: w.files.has(e.path) || e.path === SWITCH }
  })
  on('fs.stat', (_a, e) => {
    if (w.statFails.has(e.path)) throw new Error('EIO')
    if (w.files.has(e.path)) {
      const text = w.files.get(e.path)
      return { value: {
        kind: text === null ? 'dir' as const : 'file' as const,
        size: text?.length ?? 0, mtimeMs: 0, isLink: false,
      } }
    }
    if (e.path !== SWITCH || w.switchText === undefined) {
      throw new Error('ENOENT')
    }
    return { value: {
      kind: 'file' as const, size: w.switchText.length, mtimeMs: 0,
      isLink: false,
    } }
  })
  on('fs.read', (_a, e) => {
    if (w.unreadable.has(e.path)) throw new Error('EIO')
    if (w.files.has(e.path)) return { value: w.files.get(e.path) ?? '' }
    if (e.path !== SWITCH || w.switchText === undefined) {
      throw new Error('ENOENT')
    }
    return { value: w.switchText }
  })
  on('session.root', () => {
    if (w.rootFails) throw new Error('no root')
    return { value: w.root }
  })
  on('session.id', () => ({ value: w.id }))
  on('session.start', (_a, e) => ({ cwd: e.cwd }))
  on('ui.log', (_a, e) => {
    w.logs.push(String((e as { text?: unknown }).text))
    return { value: undefined } as never
  })
  on('tool.call', { tool: 'Bash' }, (_a, e) =>
    (w.byCommand.get(e.command) ?? w.answer) as never)
  on('session.end', (_a, e) => ({ sessionId: e.sessionId }))
  await $.session.start({ cwd: '/tmp', surface: null, isInteractive: false })
  return w
}

const bash = ($: Engine, command: string) =>
  $.tool.call({ tool: 'Bash', command })

/** Answers the next Bash call with a failed command's text. */
function failWith(w: World, text: string): void {
  w.answer = { result: { stdout: '', stderr: '' }, text, isError: true }
}

const failing = async ($: Engine, w: World, text: string, cmd = 'make') => {
  failWith(w, text)
  return bash($, cmd)
}

type Project = { sessions: { id: string; at: number; failures: Fail[] }[] }
type Fail = {
  key: string; line: string; excerpt: string; command: string
  agent: boolean; at: number; count: number
}

const projectOf = (w: World, root = ROOT) =>
  w.kv.get(`p:${root}`) as Project | undefined

const failuresOf = (w: World) =>
  projectOf(w)?.sessions[0]?.failures ?? []

test('TOFF: enabled false passes a failing answer, stores nothing',
  async ($, on) => {
    const w = await boot($, on, { switchText: '{"enabled": false}' })
    const out = await failing($, w, 'Exit code 1\nfatal: bad thing')
    expect(out).toEqual(w.answer)
    expect(w.sets).toEqual([])
  })

test('an absent switch file keeps the mod on', async ($, on) => {
  const w = await boot($, on)
  expect(await bash($, 'ls')).toEqual(BASH_ANSWER)
  expect(w.tools).toEqual(['memory_pending'])
})

test('a malformed switch file keeps the mod on', async ($, on) => {
  const w = await boot($, on, { switchText: '{nope' })
  expect(await bash($, 'ls')).toEqual(BASH_ANSWER)
  expect(w.logs).toEqual([])
  expect(w.tools).toEqual(['memory_pending'])
})

test('the tool is not registered when the switch is off', async ($, on) => {
  const w = await boot($, on, { switchText: '{"enabled": false}' })
  expect(w.tools).toEqual([])
})

test('FAILOPEN: a rejecting session.root still returns the answer',
  async ($, on) => {
    const w = await boot($, on, { rootFails: true })
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

test('redact drops everything past 65536 code units', () => {
  const out = redact('x'.repeat(65536) + 'END_MARK')
  expect(out.length).toBe(65536)
  expect(out.includes('END_MARK')).toBe(false)
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

test('TIME1: redact and normalize stay fast on 64 KiB of letters', () => {
  const text = 'a'.repeat(65536)
  for (const fn of [redact, normalize]) {
    const t0 = now()
    fn(text)
    expect(now() - t0).toBeLessThan(500)
  }
})

test('TIME1: redact stays fast on adversarial 64 KiB inputs', () => {
  const inputs = [
    'TOKEN'.repeat(13107),
    'secret'.repeat(10922),
    'Bearer '.repeat(9362),
    'a://b:'.repeat(10922),
  ]
  for (const text of inputs) {
    const t0 = now()
    redact(text)
    expect(now() - t0).toBeLessThan(500)
  }
})

const EXIT1 = 'Exit code 1\n'

test('failureLine: the last line after the first, trailers stripped', () => {
  expect(failureLine(EXIT1 + 'a\nfatal: bad thing')).toBe('fatal: bad thing')
  expect(failureLine('Exit code 2\nfatal here [+3 hidden: rtk recall ab12]'))
    .toBe('fatal here')
  expect(failureLine('Exit code 2\nreal error\n[full output: rtk recall ab12]'))
    .toBe('real error')
  expect(failureLine('Exit code 1')).toBeUndefined()
  expect(failureLine('boom\nfatal: x')).toBeUndefined()
  expect(failureLine(EXIT1 + '/tmp/a/b 12 deadbeef1')).toBeUndefined()
  expect(failureLine(EXIT1 + 'FATAL: disk full')).toBe('FATAL: disk full')
})

test('CAP1: a failed command stores one failure with its line', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'fatal: bad thing', 'git push')
  const f = failuresOf(w)
  expect(f).toHaveLength(1)
  expect(f[0]?.line).toBe('fatal: bad thing')
  expect(f[0]?.key).toBe('fatal: bad thing')
  expect(f[0]?.command).toBe('git push')
  expect(f[0]?.agent).toBe(false)
  expect(f[0]?.at).toBe(w.clock.now())
})

test('CAP2: Exit code alone stores nothing', async ($, on) => {
  const w = await boot($, on)
  await failing($, w, 'Exit code 1')
  expect(w.sets).toEqual([])
})

test('CAP3: excluded texts and a letterless line store nothing', async (
  $, on,
) => {
  const w = await boot($, on)
  const texts = [
    'Permission to use Bash has been denied',
    "Claude requested it and you haven't granted it yet",
    'model-router: refused',
    'x <tool_use_error>nope</tool_use_error>',
    'Exit code 1\n0',
  ]
  for (const text of texts) await failing($, w, text)
  expect(w.sets).toEqual([])
})

test('CAP11: a last line that is not error-shaped stores nothing', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'rc=0')
  await failing($, w, EXIT1 + 'error x\nrc=0')
  await failing($, w, EXIT1 + '== before')
  expect(w.sets).toEqual([])
})

test('CAP11: error-shaped last lines are stored, line literal', async (
  $, on,
) => {
  const w = await boot($, on)
  const lines = [
    "ls: cannot access '/x/y': No such file or directory",
    "/bin/bash: eval: line 157: unexpected EOF while looking for matching ``'",
    'https://www.shellcheck.net/wiki/SC2016 -- ' +
      "Expressions don't expand in singl...",
    'doctor.sh: 4 added lines > 80',
    'FATAL: disk full',
    "can't open",
    'assertion failed: assert x',
    'permission denied',
  ]
  for (const line of lines) await failing($, w, 'Exit code 2\n' + line)
  expect(failuresOf(w).map(f => f.line)).toEqual(lines)
})

test('CAP4: the same line twice is one entry with count 2', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'fatal: bad thing 1')
  await w.clock.advance(5)
  await failing($, w, EXIT1 + 'fatal: bad thing 2')
  const f = failuresOf(w)
  expect(f).toHaveLength(1)
  expect(f[0]?.count).toBe(2)
  expect(f[0]?.at).toBe(1005)
})

const letters = (i: number) =>
  String.fromCharCode(97 + (i % 26)) + String.fromCharCode(97 + (i / 26 | 0))

test('CAP5: 51 distinct lines keep 50, the oldest dropped', async (
  $, on,
) => {
  const w = await boot($, on)
  for (let i = 0; i < 51; i++) {
    await failing($, w, EXIT1 + `error ${letters(i)}`)
  }
  const f = failuresOf(w)
  expect(f).toHaveLength(50)
  expect(f[0]?.line).toBe(`error ${letters(1)}`)
  expect(f[49]?.line).toBe(`error ${letters(50)}`)
})

test('CAP6: a 4th session drops the oldest of the project', async (
  $, on,
) => {
  const w = await boot($, on)
  for (const id of ['s1', 's2', 's3', 's4']) {
    w.id = id
    await w.clock.advance(10)
    await failing($, w, EXIT1 + `error ${id}`)
  }
  const ids = projectOf(w)?.sessions.map(s => s.id)
  expect(ids).toEqual(['s4', 's3', 's2'])
})

test('CAP7: a sub-agent call stores agent true', async ($, on) => {
  const w = await boot($, on)
  failWith(w, EXIT1 + 'fatal: bad thing')
  await $.tool.call({ tool: 'Bash', command: 'make', agentId: 'a1' })
  expect((failuresOf(w))[0]?.agent).toBe(true)
})

test('CAP8: a runtime-built token in the command is stored redacted',
  async ($, on) => {
    const w = await boot($, on)
    await failing($, w, EXIT1 + 'fatal: bad thing',
      'X_' + 'TOKEN=abc123 make test')
    expect((failuresOf(w))[0]?.command)
      .toBe('X_TOKEN=<redacted> make test')
  })

test('CAP9: the model gets the bottom answer, byte for byte', async (
  $, on,
) => {
  const w = await boot($, on)
  const out = await failing($, w, EXIT1 + 'fatal: bad thing')
  expect(JSON.stringify(out)).toBe(JSON.stringify(w.answer))
})

test('CAP10: an over-cap store evicts the oldest other session', async (
  $, on,
) => {
  const big = (id: string, at: number) => ({
    id, at, milestones: [], red: [],
    failures: [{ key: 'k', line: 'l', excerpt: 'x'.repeat(600000),
      command: 'c', agent: false, at, count: 1 }],
  })
  const seed = { 'p:/other': { sessions: [big('o2', 20), big('o1', 10)] } }
  const w = await boot($, on, { seed })
  await failing($, w, EXIT1 + 'fatal: bad thing')
  const other = projectOf(w, '/other')
  expect(other?.sessions.map(s => s.id)).toEqual(['o2'])
  expect(failuresOf(w)).toHaveLength(1)
})

test('a sweep with nothing droppable keeps the current session', async (
  $, on,
) => {
  const seed = { 'p:/work/app': { sessions: [{
    id: 's1', at: 1, milestones: [], red: [],
    failures: [{ key: 'k', line: 'l', excerpt: 'x'.repeat(1100000),
      command: 'c', agent: false, at: 1, count: 1 }],
  }] } }
  const w = await boot($, on, { seed })
  await failing($, w, EXIT1 + 'fatal: bad thing')
  expect(projectOf(w)?.sessions.map(s => s.id)).toEqual(['s1'])
})

test('a token cut at the excerpt window edge comes out redacted', async (
  $, on,
) => {
  const w = await boot($, on)
  const token = 'gh' + 'p_' + 'Q'.repeat(36)
  await failing($, w, EXIT1 + 'fatal: ' + token + 'z'.repeat(580))
  const f = (failuresOf(w))[0]
  expect(f?.excerpt).toContain('<redacted:github>')
  expect(f?.excerpt).not.toContain('QQQQ')
  expect(f?.line).not.toContain('QQQQ')
})

test('a PEM body as the last line leaves no body in line or key', async (
  $, on,
) => {
  const w = await boot($, on)
  const pem = PEM + 'BEGIN PRIVATE KEY' + PEM + '\n' + 'MIIBVgIBADAN'.repeat(5)
  await failing($, w, EXIT1 + 'error: ' + pem)
  const f = (failuresOf(w))[0]
  expect(f?.line).toBe('error: <redacted:private-key>')
  expect(f?.key).toBe('error: <redacted:private-key>')
  expect(JSON.stringify(f)).not.toContain('MIIB')
})

test('ENTRY1: an entry over 2048 drops its excerpt first', async ($, on) => {
  const w = await boot($, on)
  const text = EXIT1 + '"'.repeat(700) + '\n' + 'error' + 'a"'.repeat(150)
  await failing($, w, text, '"'.repeat(400))
  const f = (failuresOf(w))[0]
  expect(JSON.stringify(f).length).toBeLessThanOrEqual(2048)
  expect(f?.excerpt).toBe('')
  expect(f?.line.length).toBe(300)
})

test('ID1: a changed session id with no session.start is a new record',
  async ($, on) => {
    const w = await boot($, on)
    await failing($, w, EXIT1 + 'error one')
    w.id = 's2'
    await w.clock.advance(10)
    await failing($, w, EXIT1 + 'error two')
    const ids = projectOf(w)?.sessions.map(s => s.id)
    expect(ids).toEqual(['s2', 's1'])
  })

test('ID2: session.end clear then a new id gives two sessions', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'error one')
  await $.session.end({
    reason: 'clear', sessionId: 's1', resume: { id: 's1' },
  })
  w.id = 's2'
  await w.clock.advance(10)
  await failing($, w, EXIT1 + 'error two')
  expect(projectOf(w)?.sessions).toHaveLength(2)
})

test('RACE1: two concurrent failing calls store two entries', async (
  $, on,
) => {
  const w = await boot($, on)
  const answer = (text: string) =>
    ({ result: { stdout: '', stderr: '' }, text, isError: true })
  w.byCommand.set('a', answer(EXIT1 + 'error one'))
  w.byCommand.set('b', answer(EXIT1 + 'error two'))
  const calls = [bash($, 'a'), bash($, 'b')]
  await Promise.all(calls)
  expect(failuresOf(w)).toHaveLength(2)
})

test('TFAIL: a store that throws still returns the bottom answer',
  async ($, on) => {
    const w = await boot($, on, { storeFails: true })
    const out = await failing($, w, EXIT1 + 'fatal: bad thing')
    expect(JSON.stringify(out)).toBe(JSON.stringify(w.answer))
    const again = await failing($, w, EXIT1 + 'fatal: bad thing')
    expect(JSON.stringify(again)).toBe(JSON.stringify(w.answer))
    expect(w.logs.filter(l => l.startsWith('memory: Bash capture')))
      .toHaveLength(1)
  })

test('sessionOf stamps the found session, never trims it', () => {
  const mk = (id: string, at: number) =>
    ({ id, at, failures: [], milestones: [], red: [] })
  const p = { sessions: [mk('a', 1), mk('b', 2), mk('c', 3), mk('d', 4)] }
  const s = sessionOf(p, 'a', 9)
  expect(s.at).toBe(9)
  expect(p.sessions.map(x => x.id)).toEqual(['a', 'd', 'c'])
})

test('addFailure: same key counts, a new key appends', () => {
  const s = sessionOf({ sessions: [] }, 's', 1)
  const f = (key: string) =>
    ({
      key, line: key, excerpt: '', command: '', agent: false, at: 1, count: 1,
    })
  addFailure(s, f('x'))
  addFailure(s, f('x'))
  addFailure(s, f('y'))
  expect(s.failures.map(x => [x.key, x.count])).toEqual([['x', 2], ['y', 1]])
})

// ---- the registry index and memory_pending ----------------------------

const REG = `${ROOT}/.claude/memory`
const BLK = `${REG}/blockers.md`
const LRN = `${REG}/learnings.md`
const BLOCKERS = '## BLK-001 \u2014 x\n- **Status**: open\n' +
  'seen: `fatal: unable to access remote`\n'
const LEARNINGS = '## LRN-002 \u2014 y\n- **Status**: superseded\n' +
  'old: `error: pathspec did not match anything`\n'
const REGS = { [BLK]: BLOCKERS, [LRN]: LEARNINGS }
const PENDING = 'mcp__memory__memory_pending'

const pending = async ($: Engine): Promise<string> =>
  String(((await $.tool.call({ tool: PENDING })) as { result: unknown })
    .result)

test('IDX1: a captured line the registry holds reads known BLK-001', async (
  $, on,
) => {
  const w = await boot($, on, { files: REGS })
  await failing($, w, EXIT1 + 'fatal: unable to access remote host', 'git pull')
  expect(await pending($)).toBe([
    'memory_pending (project app, 1 session(s))',
    'index: read blockers.md, learnings.md',
    'failures:',
    '- known BLK-001 \u00d71 fatal: unable to access remote host' +
      ' \u2014 command: git pull',
    '  excerpt: Exit code 1\u23cefatal: unable to access remote host',
  ].join('\n'))
})

test('IDX2: an unrelated line reads NEW', async ($, on) => {
  const w = await boot($, on, { files: REGS })
  await failing($, w, EXIT1 + 'completely different error happened')
  expect(await pending($)).toContain('- NEW \u00d71 completely different')
})

test('IDX3: a line matching only a superseded LRN reads NEW', async (
  $, on,
) => {
  const w = await boot($, on, { files: REGS })
  await failing($, w, EXIT1 + 'error: pathspec did not match anything')
  expect(await pending($)).toContain('- NEW \u00d71 error: pathspec')
})

test('IDX4: no registry files, every failure NEW, both named', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'fatal: unable to access remote host')
  const text = await pending($)
  expect(text).toContain(
    'index: skipped blockers.md (missing), learnings.md (missing)')
  expect(text).toContain('- NEW \u00d71')
})

test('IDX5: an empty store answers nothing captured', async ($, on) => {
  await boot($, on)
  expect(await pending($)).toBe('memory_pending: nothing captured')
})

test('IDX6: the tool is not registered when disabled, and says off', async (
  $, on,
) => {
  const w = await boot($, on, { switchText: '{"enabled": false}' })
  expect(w.tools).toEqual([])
  expect(await pending($))
    .toBe('memory capture is off (~/.claude/memory.json)')
})

test('IDX7: the answer holds no unredacted runtime-built token', async (
  $, on,
) => {
  const w = await boot($, on)
  const token = 'gh' + 'p_' + 'Q'.repeat(36)
  await failing($, w, EXIT1 + 'fatal: bad ' + token, 'git push ' + token)
  const text = await pending($)
  expect(text).toContain('<redacted:github>')
  expect(text).not.toContain('QQQQ')
})

test('IDX8: the error span is indexed, not the prose between', async () => {
  const body = '## BLK-009 \u2014 z\n`git rm` and later words ' +
    '`fatal: unable to access remote host`\n'
  const index = buildIndex([body])
  expect(matchOf(index, normalize('fatal: unable to access remote host')))
    .toBe('BLK-009')
  expect(matchOf(index, normalize('and later words fatal unable')))
    .toBeUndefined()
})

test('a key of fewer than 4 words has no gram, so it is NEW', () => {
  expect(grams('a b c')).toEqual([])
  expect(grams('a b c d e')).toEqual(['a b c d', 'b c d e'])
  const index = buildIndex(['## BLK-001 x\n`aaa bbb ccc ddd`\n'])
  expect(matchOf(index, 'aaa bbb ccc')).toBeUndefined()
})

test('entriesOf slices between headings, heading line included', () => {
  const text = '## BLK-001 a\nx\n## other\ny\n## LRN-2 [b]\nz\n'
  expect(entriesOf(text)).toEqual([
    { id: 'BLK-001', body: '## BLK-001 a\nx\n## other\ny\n' },
    { id: 'LRN-2', body: '## LRN-2 [b]\nz\n' },
  ])
})

test('isSuperseded: the last status wins, else the heading tag', () => {
  expect(isSuperseded('## LRN-1 a\n- **Status**: open\n- **Statut**: ' +
    'superseded\n')).toBe(true)
  expect(isSuperseded('## LRN-1 a\n- **Status**: superseded\n' +
    '- **Status**: open\n')).toBe(false)
  expect(isSuperseded('## LRN-1 [superseded] a\nbody\n')).toBe(true)
  expect(isSuperseded('## LRN-1 [open] a\n')).toBe(false)
})

test('a directory and an over-size file are skipped on the index line', async (
  $, on,
) => {
  const big = 'x'.repeat(4194305)
  const w = await boot($, on, { files: { [BLK]: null, [LRN]: big } })
  await failing($, w, EXIT1 + 'fatal: bad thing')
  expect(await pending($)).toContain(
    'index: skipped blockers.md (not a file), learnings.md (over 4 MiB)')
})

test('an empty root answers no project root', async ($, on) => {
  const w = await boot($, on)
  w.root = ''
  expect(await pending($)).toBe('memory_pending: no project root')
})

/** HH:MM of the local clock, from the Date API (not the code under test). */
const localHhmm = (at: number) => {
  const d = new Date(at)
  const two = (n: number) => String(n).padStart(2, '0')
  return `${two(d.getHours())}:${two(d.getMinutes())}`
}

test('milestones, sub-agent, earlier session and order', async ($, on) => {
  const mk = (id: string, at: number, failures: unknown[], ms: unknown[]) =>
    ({ id, at, failures, milestones: ms, red: [] })
  const f = (line: string, agent = false) => ({
    key: line, line, excerpt: 'a\nb', command: 'c', agent, at: 1, count: 2,
  })
  const seed = { [`p:${ROOT}`]: { sessions: [
    mk('s1', 900, [f('known one fatal: unable to access remote host'),
      f('brand new line here ok', true)],
    [{ kind: 'commit', label: 'fix: x', at: 3600000 * 14 + 120000 }]),
    mk('s0', 100, [f('old trouble in town today')], []),
  ] } }
  const w = await boot($, on, { seed, files: REGS })
  expect(w.kv.size).toBe(1)
  expect(await pending($)).toBe([
    'memory_pending (project app, 2 session(s))',
    'index: read blockers.md, learnings.md',
    'milestones (this session):',
    '- commit fix: x (' + localHhmm(3600000 * 14 + 120000) + ')',
    'failures:',
    '- NEW \u00d72 (sub-agent) brand new line here ok \u2014 command: c',
    '  excerpt: a\u23ceb',
    '- known BLK-001 \u00d72 known one fatal: unable to access remote host' +
      ' \u2014 command: c',
    '  excerpt: a\u23ceb',
    '- NEW \u00d72 (earlier session) old trouble in town today' +
      ' \u2014 command: c',
    '  excerpt: a\u23ceb',
  ].join('\n'))
})

test('the excerpt shows its last 300 characters', async ($, on) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'x'.repeat(400) + '\nfatal: tail marker')
  const text = await pending($)
  const shown = text.split('excerpt: ')[1] ?? ''
  expect(shown.length).toBe(300)
  expect(shown.endsWith('fatal: tail marker')).toBe(true)
})

test('the failure list is capped at 20000 chars with a count', async (
  $, on,
) => {
  const f = (i: number) => ({
    key: `k${i}`, line: `line ${i} ${'y'.repeat(300)}`,
    excerpt: 'e'.repeat(300), command: 'c', agent: false, at: 1, count: 1,
  })
  const failures = Array.from({ length: 50 }, (_, i) => f(i))
  const seed = { [`p:${ROOT}`]: { sessions: [
    { id: 's1', at: 1, milestones: [], red: [], failures },
  ] } }
  await boot($, on, { seed })
  const text = await pending($)
  expect(text).toMatch(/\n\u2026 \d+ more failure\(s\) omitted$/)
  expect(text.length).toBeLessThan(20300)
})

test('ID1/ID2: after an id change the earlier session is marked', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'error one here today')
  w.id = 's2'
  await w.clock.advance(10)
  await failing($, w, EXIT1 + 'error two here today')
  const text = await pending($)
  expect(text).toContain('session(s))')
  expect(text).toContain('- NEW \u00d71 error two here today')
  expect(text).toContain('(earlier session) error one here today')
  expect(text.indexOf('error two')).toBeLessThan(text.indexOf('error one'))
})

const endSession = ($: Engine) =>
  $.session.end({ reason: 'clear', sessionId: 's1', resume: { id: 's1' } })

test('session.end re-reads the switch and registers the tool again', async (
  $, on,
) => {
  const w = await boot($, on, { switchText: '{"enabled": false}' })
  expect(w.tools).toEqual([])
  w.switchText = undefined
  await endSession($)
  await bash($, 'ls')
  expect(w.tools).toEqual(['memory_pending'])
  w.switchText = '{"enabled": false}'
  await endSession($)
  expect(await pending($))
    .toBe('memory capture is off (~/.claude/memory.json)')
})

test('the tool failing answers a stable text, not a throw', async (
  $, on,
) => {
  const w = await boot($, on, { rootFails: true })
  expect(await pending($)).toBe(
    'memory_pending failed (throw); nothing returned')
  expect(w.logs.some(l => l.startsWith('memory: memory_pending hook')))
    .toBe(true)
})

test('the tool never writes the store', async ($, on) => {
  const w = await boot($, on, { files: REGS })
  await pending($)
  expect(w.sets).toEqual([])
})

test('TIME1: an index over 80000 newlines builds in under 500 ms', () => {
  const body = '## BLK-001 x\n' + '\n'.repeat(80000) + '- **Status**: open\n' +
    '\r\n'.repeat(40000) + '`fatal: unable to access remote`\n'
  const t0 = now()
  const index = buildIndex([body])
  expect(now() - t0).toBeLessThan(500)
  expect(index.size).toBe(2)
})

test('a registry whose read throws is named unreadable', async ($, on) => {
  const w = await boot($, on, { files: REGS, unreadable: [BLK] })
  await failing($, w, EXIT1 + 'fatal: unable to access remote host')
  const text = await pending($)
  expect(text).toContain(
    'index: read learnings.md; skipped blockers.md (unreadable)')
  expect(text).toContain('- NEW \u00d71')
})

test('a lone CR in the excerpt shows as the newline mark', async ($, on) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'a\rb\r\nc\nfatal: end')
  expect(await pending($)).toContain(
    'excerpt: Exit code 1\u23cea\u23ceb\u23cec\u23cefatal: end')
})

test('malformed stored elements are skipped, valid ones listed', async (
  $, on,
) => {
  const ok = { key: 'good line here ok', line: 'good line here ok',
    excerpt: '', command: 'c', agent: false, at: 1, count: 1 }
  const seed = { [`p:${ROOT}`]: { sessions: [{
    id: 's1', at: 1, red: [],
    failures: [{ ...ok, key: 42 }, null, ok],
    milestones: [{ kind: 'commit', label: 'x', at: 'bad' }, null,
      { kind: 'commit', label: 'fine', at: 60000 }],
  }] } }
  await boot($, on, { seed })
  const text = await pending($)
  expect(text).toContain('- commit fine (' + localHhmm(60000) + ')')
  expect(text).toContain('- NEW \u00d71 good line here ok')
  expect(text).not.toContain('bad')
})

test('a registry of exactly 4 MiB is read, one byte more skipped', async (
  $, on,
) => {
  const w = await boot($, on, { files: {
    [BLK]: 'x'.repeat(4194304), [LRN]: 'x'.repeat(4194305),
  } })
  await failing($, w, EXIT1 + 'fatal: bad thing')
  expect(await pending($)).toContain(
    'index: read blockers.md; skipped learnings.md (over 4 MiB)')
})

test('a span of 12 chars is indexed, one of 11 is not', () => {
  const at12 = buildIndex(['## BLK-001 x\n`aa bb cc ddd`\n'])
  const at11 = buildIndex(['## BLK-001 x\n`aa bb cc dd`\n'])
  expect(at12.size).toBe(1)
  expect(at11.size).toBe(0)
})

test('a rejected stat on an existing registry is unreadable', async (
  $, on,
) => {
  const w = await boot($, on, { files: REGS, statFails: [BLK] })
  await failing($, w, EXIT1 + 'error: pathspec did not match anything')
  expect(await pending($)).toContain(
    'index: read learnings.md; skipped blockers.md (unreadable)')
})

test('a throwing exists probe names the registry, keeps the other', async (
  $, on,
) => {
  const files = { [BLK]: BLOCKERS, [LRN]: LEARNINGS.replace(
    'superseded', 'open') }
  const w = await boot($, on, { files, statFails: [BLK], existsFails: [BLK] })
  await failing($, w, EXIT1 + 'error: pathspec did not match anything')
  const text = await pending($)
  expect(text).toContain(
    'index: read learnings.md; skipped blockers.md (unreadable)')
  expect(text).toContain('- known LRN-002 \u00d71')
})

// Task 5: milestones and the one-line note.
type Stored = {
  milestones: { kind: string; label: string; at: number }[]
  red: string[]
}
const stored = (w: World): Stored =>
  (projectOf(w)?.sessions[0] ?? { milestones: [], red: [] }) as
    unknown as Stored
const kinds = (w: World) => stored(w).milestones.map(m => m.kind)
const labels = (w: World) => stored(w).milestones.map(m => m.label)

const OK = { result: { stdout: 'ok', stderr: '' } }
const RED = { result: { stdout: '', stderr: '' }, isError: true,
  text: 'Exit code 2\nmake: *** [test] Error 1' }
const FINISH_CMD = 'bash "$HOME/.claude/lib/gitflow.sh" finish'

/** Bash calls whose answer is `answer`, one command at a time. */
async function run(
  $: Engine, w: World, command: string, answer: unknown = OK,
): Promise<void> {
  w.answer = answer
  await bash($, command)
}

test('segments splits on && || ; and newline', () => {
  expect(segments('a && b||c;d\ne')).toEqual(['a', 'b', 'c', 'd', 'e'])
})

test('suiteKeyOf: a make test segment, never a mention', () => {
  expect(suiteKeyOf('cd x &&  make   test suite=a'))
    .toBe('cd x && make test suite=a')
  expect(suiteKeyOf('grep "make test" notes.md')).toBeUndefined()
  expect(suiteKeyOf('make build')).toBeUndefined()
  expect(suiteKeyOf('X_TOKEN=abc make test'))
    .toBe('X_TOKEN=<redacted> make test')
})

test('commitLabel: feat and fix only, any segment, -am and env', () => {
  expect(commitLabel('git add a && git commit -m "fix(x): y"'))
    .toBe('fix(x): y')
  expect(commitLabel("git -C /r commit -qm 'feat!: big one'"))
    .toBe('feat: big one')
  expect(commitLabel('A=1 git commit -am "feat: z"')).toBe('feat: z')
  expect(commitLabel('git commit -m "chore: z"')).toBeUndefined()
  expect(commitLabel('echo git commit -m "fix: z"')).toBeUndefined()
  expect(commitLabel('git commit -m "fix: ' + 'w'.repeat(200) + '"'))
    .toBe('fix: ' + 'w'.repeat(75))
})

test('finishLabel: type and name, bare finish, chore excluded', () => {
  expect(finishLabel(FINISH_CMD)).toBe('finish')
  expect(finishLabel('bash ~/.claude/lib/gitflow.sh finish feature x'))
    .toBe('feature x')
  expect(finishLabel('bash ~/.claude/lib/gitflow.sh finish chore x'))
    .toBeUndefined()
  expect(finishLabel('echo gitflow.sh finish')).toBeUndefined()
})

test('MS1: a fix commit success stores one commit milestone', async (
  $, on,
) => {
  const w = await boot($, on)
  await run($, w, 'git add a && git commit -m "fix(x): y"')
  expect(kinds(w)).toEqual(['commit'])
  expect(labels(w)).toEqual(['fix(x): y'])
  expect(stored(w).milestones[0]?.at).toBe(w.clock.now())
})

test('MS2: a chore commit stores nothing', async ($, on) => {
  const w = await boot($, on)
  await run($, w, 'git commit -m "chore: z"')
  expect(w.kv.size).toBe(0)
})

test('MS3 MS4: finish stores a milestone, finish chore none', async (
  $, on,
) => {
  const w = await boot($, on)
  await run($, w, 'bash ~/.claude/lib/gitflow.sh finish chore x')
  expect(w.kv.size).toBe(0)
  await run($, w, FINISH_CMD)
  expect(kinds(w)).toEqual(['finish'])
  expect(labels(w)).toEqual(['finish'])
})

test('MS5: red then green gives one green; green alone none', async (
  $, on,
) => {
  const w = await boot($, on)
  await run($, w, 'make test suite=a')
  expect(w.kv.size).toBe(0)
  await run($, w, 'make test suite=a', RED)
  expect(stored(w).red).toEqual(['make test suite=a'])
  await run($, w, 'make test suite=a')
  expect(kinds(w)).toEqual(['green'])
  expect(labels(w)).toEqual(['make test suite=a'])
  expect(stored(w).red).toEqual([])
  await run($, w, 'make test suite=a')
  expect(kinds(w)).toEqual(['green'])
})

test('MS5b: a red of another suite does not turn green', async ($, on) => {
  const w = await boot($, on)
  await run($, w, 'make test suite=a', RED)
  await run($, w, 'make test suite=b')
  expect(kinds(w)).toEqual([])
})

test('MS6: a sub-agent commit and red store no milestone', async (
  $, on,
) => {
  const w = await boot($, on)
  w.answer = OK
  await $.tool.call({ tool: 'Bash', command: 'git commit -m "fix: a"',
    agentId: 'a1' })
  w.answer = RED
  await $.tool.call({ tool: 'Bash', command: 'make test', agentId: 'a1' })
  expect(stored(w).red).toEqual([])
  expect(kinds(w)).toEqual([])
})

test('a backgrounded, timed out or interrupted run is no success', async (
  $, on,
) => {
  const w = await boot($, on)
  await run($, w, 'make test', RED)
  for (const result of [{ backgroundTaskId: 'b1' }, { timedOutAfterMs: 9 },
    { interrupted: true }]) {
    await run($, w, 'make test', { result: { stdout: '', ...result } })
  }
  w.answer = OK
  await $.tool.call({ tool: 'Bash', command: 'make test',
    run_in_background: true })
  expect(kinds(w)).toEqual([])
  await run($, w, 'make test')
  expect(kinds(w)).toEqual(['green'])
})

test('a deny answer on a commit stores no milestone', async ($, on) => {
  const w = await boot($, on)
  await run($, w, 'git commit -m "fix: a"', { deny: 'blocked' })
  expect(kinds(w)).toEqual([])
})

test('a red key is stored redacted', async ($, on) => {
  const w = await boot($, on)
  await run($, w, 'X_TOKEN=abc make test', RED)
  expect(stored(w).red).toEqual(['X_TOKEN=<redacted> make test'])
})

test('a commit label is stored redacted', async ($, on) => {
  const w = await boot($, on)
  await run($, w, `git commit -m "fix: ${'sk_live_' + 'a'.repeat(12)}"`)
  expect(labels(w)).toEqual(['fix: <redacted:stripe>'])
})

test('a red answer without Exit code is no red', async ($, on) => {
  const w = await boot($, on)
  await run($, w, 'make test', { ...RED, text: 'denied by a guard' })
  expect(w.kv.size).toBe(0)
})

test('milestones keep 20, red keeps 10 of 300 chars', async ($, on) => {
  const w = await boot($, on)
  for (let i = 0; i < 22; i++) {
    await run($, w, `git commit -m "fix: n${i}"`)
  }
  expect(labels(w)).toHaveLength(20)
  expect(labels(w)[0]).toBe('fix: n2')
  for (let i = 0; i < 12; i++) {
    await run($, w, `make test suite=${i}`, RED)
  }
  expect(stored(w).red).toHaveLength(10)
  await run($, w, `make test ${'x'.repeat(400)}`, RED)
  expect(stored(w).red.at(-1)).toHaveLength(300)
})

test('a stored commit milestone shows in the memory_pending answer', async (
  $, on,
) => {
  const w = await boot($, on)
  await run($, w, 'git commit -m "fix(x): y"')
  expect(await pending($)).toBe([
    'memory_pending (project app, 1 session(s))',
    'index: skipped blockers.md (missing), learnings.md (missing)',
    'milestones (this session):',
    '- commit fix(x): y (' + localHhmm(1000) + ')',
  ].join('\n'))
})

/** Boots with a bottom prompt hook that records the context it gets. */
async function bootNotes(
  $: Engine, on: On, o: Opts = {},
): Promise<{ w: World; seen: (readonly string[] | undefined)[] }> {
  const seen: (readonly string[] | undefined)[] = []
  on('prompt.submit', (_a, e) => {
    seen.push(e.context)
    return { text: e.text }
  })
  return { w: await boot($, on, o), seen }
}

const composer = ($: Engine, turnId?: string) => $.prompt.submit({
  text: 'next', wait: turnId !== undefined, origin: { kind: 'composer' },
  ...(turnId === undefined ? {} : { turnId }),
})

test('NT1 NT2: one note after a milestone, none after', async ($, on) => {
  const { w, seen } = await bootNotes($, on)
  await failing($, w, EXIT1 + 'fatal: bad thing', 'git push')
  await run($, w, 'git commit -m "fix(x): y"')
  await composer($)
  expect(seen).toEqual([[
    'memory: commit fix(x): y \u2014 1 new failure mode(s) this session;' +
      ' /capitalize when ready.',
  ]])
  await composer($)
  expect(seen[1]).toBeUndefined()
})

test('NT1b: a known failure is not counted as new', async ($, on) => {
  const { w, seen } = await bootNotes($, on, { files: REGS })
  await failing($, w, EXIT1 + 'fatal: unable to access remote host', 'git')
  await run($, w, 'git commit -m "fix: y"')
  await composer($)
  expect(seen[0]?.[0]).toContain('\u2014 0 new failure mode(s)')
})

test('NT3: a mid-turn prompt gets no note and keeps the milestone', async (
  $, on,
) => {
  const { w, seen } = await bootNotes($, on)
  await run($, w, 'git commit -m "fix: y"')
  await composer($, 'u1')
  expect(seen[0]).toBeUndefined()
  await composer($)
  expect(seen[1]).toHaveLength(1)
})

test('NT4: no milestone, no context added', async ($, on) => {
  const { seen } = await bootNotes($, on)
  await composer($)
  expect(seen).toEqual([undefined])
})

test('a prompt that is not from the composer gets no note', async (
  $, on,
) => {
  const { w, seen } = await bootNotes($, on)
  await run($, w, 'git commit -m "fix: y"')
  await $.prompt.submit({ text: 'x', wait: false, origin: { kind: 'sdk' } })
  expect(seen[0]).toBeUndefined()
  await composer($)
  expect(seen[1]).toHaveLength(1)
})

test('an existing context is kept and the note appended', async ($, on) => {
  const { w, seen } = await bootNotes($, on)
  await run($, w, 'git commit -m "fix: y"')
  await $.prompt.submit({ text: 'x', wait: false, context: ['keep'],
    origin: { kind: 'composer' } })
  expect(seen[0]?.[0]).toBe('keep')
  expect(seen[0]).toHaveLength(2)
})

test('session.end drops the unnoted milestones', async ($, on) => {
  const { w, seen } = await bootNotes($, on)
  await run($, w, 'git commit -m "fix: y"')
  await endSession($)
  await composer($)
  expect(seen[0]).toBeUndefined()
})

test('MTOFF: switched off, no milestone and no note', async ($, on) => {
  const { w, seen } = await bootNotes($, on,
    { switchText: '{"enabled": false}' })
  await run($, w, 'git commit -m "fix: y"')
  await composer($)
  expect(w.kv.size).toBe(0)
  expect(seen[0]).toBeUndefined()
})

const HEREDOC = (subject: string) =>
  `git commit -m "$(cat <<'EOF'\n${subject}\n\nbody\nEOF\n)"`

test('MS7: a heredoc commit message counts, a chore one does not', async (
  $, on,
) => {
  const w = await boot($, on)
  await run($, w, HEREDOC('chore: nope'))
  expect(w.kv.size).toBe(0)
  await run($, w, HEREDOC('fix(memory): heredoc subject'))
  expect(labels(w)).toEqual(['fix(memory): heredoc subject'])
  expect(commitLabel('git commit -m "$(cat <<EOF\nfeat!: a\nEOF\n)"'))
    .toBe('feat: a')
  expect(commitLabel('git commit -m "$(cat <<"EOF"\nfix: b\nEOF\n)"'))
    .toBe('fix: b')
})

test('a later git log -m does not make a chore commit a fix', () => {
  expect(commitLabel('git commit -m "chore: a" && git log -m "fix: b"'))
    .toBeUndefined()
})

test('finish is read per segment', () => {
  expect(finishLabel('echo bash x/gitflow.sh finish')).toBeUndefined()
  expect(finishLabel(
    'bash ~/.claude/lib/gitflow.sh finish feature x && echo finish chore'))
    .toBe('feature x')
  expect(finishLabel('FOO=1 bash g/gitflow.sh finish')).toBe('finish')
})

test('rtk and subshell prefixes still read as a commit', () => {
  expect(commitLabel('rtk git commit -m "fix: r"')).toBe('fix: r')
  expect(commitLabel('(git commit -m "fix: s")')).toBe('fix: s')
})

test('a secret straddling the 80 cut does not escape the label', () => {
  const secret = 'sk_live_' + 'a'.repeat(30)
  const out = commitLabel(`git commit -m "fix: ${'w'.repeat(60)} ${secret}"`)
  expect(out).toBe('fix: ' + 'w'.repeat(60) + ' <redacted:stri')
})

test('a finish label is stored redacted', async ($, on) => {
  const w = await boot($, on)
  await run($, w, 'bash ~/.claude/lib/gitflow.sh finish feature TOKEN=abc')
  expect(labels(w)).toEqual(['feature TOKEN=<redacted>'])
})

test('the first of two -m is the subject', () => {
  expect(commitLabel("git commit -m 'fix: a' -m 'body'")).toBe('fix: a')
})

test('an env-prefixed suite keeps its prefix in the green label', async (
  $, on,
) => {
  const w = await boot($, on)
  await run($, w, 'X=1 make test suite=a', RED)
  await run($, w, 'X=1 make test suite=a')
  expect(kinds(w)).toEqual(['green'])
  expect(labels(w)).toEqual(['X=1 make test suite=a'])
})

test('pending keeps the 20 latest milestones', async ($, on) => {
  const { w, seen } = await bootNotes($, on)
  for (let i = 0; i < 22; i++) await run($, w, `git commit -m "fix: n${i}"`)
  await composer($)
  expect(seen[0]?.[0]).toContain('memory: commit fix: n2 ')
})

test('I2: names with digits are redacted', () => {
  expect(redact('OAUTH2_CLIENT_' + 'SECRET=abc'))
    .toBe('OAUTH2_CLIENT_SECRET=<redacted>')
  expect(redact('S3_' + 'SECRET=abc')).toBe('S3_SECRET=<redacted>')
  expect(redact('TOKEN' + '_V2=abc')).toBe('TOKEN_V2=<redacted>')
})

const JWT = 'eyJ' + 'a'.repeat(20) + '.eyJ' + 'b'.repeat(20) + '.' +
  'c'.repeat(20)

test('I2: a JWT is redacted alone and inside an env value', () => {
  expect(redact('t ' + JWT + ' z')).toBe('t <redacted:jwt> z')
  expect(redact('SUPABASE_SERVICE_ROLE_KEY=' + JWT))
    .toBe('SUPABASE_SERVICE_ROLE_KEY=<redacted:jwt>')
  expect(redact('MY_' + 'TOKEN=' + JWT)).toBe('MY_TOKEN=<redacted>')
})

test('TIME1: redact stays fast on 64 KiB of eyJ repeats', () => {
  const t0 = now()
  redact('eyJ'.repeat(21845))
  expect(now() - t0).toBeLessThan(500)
})

test('I2: a long credential leaves no tail in clear', () => {
  const long = 'p'.repeat(300)
  expect(redact('x --pass' + 'word ' + long + ' z'))
    .toBe('x --password <redacted> z')
  expect(redact('curl -u bob:' + long)).toBe('curl -u <redacted>')
  expect(redact('Authorization: Ba' + 'sic ' + long))
    .toBe('Authorization: Basic <redacted>')
})

test('I2: credentials on the command line are redacted', () => {
  expect(redact('curl -u ' + 'bob:hunter2 https://x'))
    .toBe('curl -u <redacted> https://x')
  expect(redact('curl --user ' + 'bob:hunter2 https://x'))
    .toBe('curl --user <redacted> https://x')
  expect(redact('mysql --pass' + 'word hunter2 db'))
    .toBe('mysql --password <redacted> db')
  expect(redact('mysql --pass' + 'word=hunter2 db'))
    .toBe('mysql --password <redacted> db')
  expect(redact('Authorization: Ba' + 'sic dXNlcjpwdw== z'))
    .toBe('Authorization: Basic <redacted> z')
  expect(redact('Authorization: Bea' + 'rer abcdefgh12345 z'))
    .toBe('Authorization: Bearer <redacted> z')
  expect(redact('Authorization: to' + 'ken abc123 z'))
    .toBe('Authorization: token <redacted> z')
})

test('IDX9: a placeholder-only gram is not indexed nor matched', () => {
  const span = '`connect 10.0.0.1:5432 refused 12 34`'
  const index = buildIndex(['## LRN-074 x\n' + span + '\n'])
  const key = normalize('Error at 2026-11-04 12:00:00.123 timeout')
  expect(matchOf(index, key)).toBeUndefined()
  expect(grams('# # # # x')).toEqual(['# # # x'])
  expect(grams('a # <path> <hex> b'))
    .toEqual(['a # <path> <hex>', '# <path> <hex> b'])
})

test('M1: a letterless last line is dropped, one with letters kept', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, 'Exit code 1\n> 2')
  expect(w.sets).toEqual([])
  await failing($, w, 'Exit code 1\n> 2 lines differ')
  expect(failuresOf(w).map(f => f.line)).toEqual(['> 2 lines differ'])
})

test('M2: a plain successful ls touches the store not at all', async (
  $, on,
) => {
  const w = await boot($, on)
  await bash($, 'ls')
  expect(w.gets).toBe(0)
  expect(w.sets).toEqual([])
})

test('M3: a 70000-char failing text is captured', async ($, on) => {
  const w = await boot($, on)
  await failing($, w, 'Exit code 1\n' + 'x\n'.repeat(35000) + 'fatal: end')
  expect(failuresOf(w).map(f => f.line)).toEqual(['fatal: end'])
})

test('M4: a heredoc command shows on one answer line', async ($, on) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'fatal: no', HEREDOC('feat: z'))
  const out = await pending($)
  expect(out).toContain('command: git commit -m "$(cat <<\'EOF\'\u23cefeat: z')
  expect(out.split('\n').filter(l => l.startsWith('- NEW'))).toHaveLength(1)
  expect(out.split('\n')).toHaveLength(5)
})

test('M5: the milestone time is the local one', async ($, on) => {
  const w = await boot($, on)
  await run($, w, 'git commit -m "fix: y"')
  expect(await pending($)).toContain(`(${localHhmm(1000)})`)
})

test('NT5: a bare finish reads once in the note', async ($, on) => {
  const { w, seen } = await bootNotes($, on)
  await run($, w, FINISH_CMD)
  await composer($)
  expect(seen).toEqual([[
    'memory: finish \u2014 0 new failure mode(s) this session;' +
      ' /capitalize when ready.',
  ]])
})

test('M12: a throwing note step passes the prompt unchanged', async (
  $, on,
) => {
  const { w, seen } = await bootNotes($, on)
  await run($, w, 'git commit -m "fix: y"')
  w.getsFail = true
  await composer($)
  expect(seen).toEqual([undefined])
  expect(w.logs.filter(l => l.includes('prompt.submit'))).toHaveLength(1)
})

test('session.end lets a hook error log again', async ($, on) => {
  const w = await boot($, on, { rootFails: true })
  await bash($, 'ls')
  await bash($, 'ls')
  const warns = () => w.logs.filter(l => l.startsWith('memory: Bash hook'))
  expect(warns()).toHaveLength(1)
  await endSession($)
  await bash($, 'ls')
  expect(warns()).toHaveLength(2)
})
