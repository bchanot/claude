import { test, expect, mock } from 'claude-code/testing'
import type { Engine, MockClock } from 'claude-code/testing'
import type { On } from 'claude-code'
import {
  cap, tail, redact, normalize, failureLine, sessionOf, addFailure,
  entriesOf, isSuperseded, grams, buildIndex, matchOf, readRegistry,
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
}

type Opts = {
  switchText?: string
  rootFails?: boolean
  seed?: Record<string, unknown> // the store at the start
  storeFails?: boolean // store.set rejects (a hand-made store)
  files?: Record<string, string | null> // registries under the root
}

/**
 * The plugin's store over a Map the test can read and count. mock.store
 * is not used: it offers no read-back, and the kit refuses a second
 * store.set hook to observe or fail it.
 */
function handStore(on: On, w: World, fails: boolean): void {
  on('store.get', (_a, e) => ({ value: w.kv.get(e.key) }))
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
  }
  handStore(on, w, o.storeFails ?? false)
  on('tool.register', (_a, e) => {
    w.tools.push(e.name)
    return { value: undefined } as never
  })
  on('env.get', () => ({ value: HOME }))
  on('fs.stat', (_a, e) => {
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
  expect(failureLine('Exit code 2\nboom here [+3 hidden: rtk recall ab12]'))
    .toBe('boom here')
  expect(failureLine('Exit code 2\nreal\n[full output: rtk recall ab12]'))
    .toBe('real')
  expect(failureLine('Exit code 1')).toBeUndefined()
  expect(failureLine('boom\nfatal: x')).toBeUndefined()
  expect(failureLine(EXIT1 + '/tmp/a/b 12 deadbeef1')).toBeUndefined()
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
    await failing($, w, EXIT1 + `boom ${letters(i)}`)
  }
  const f = failuresOf(w)
  expect(f).toHaveLength(50)
  expect(f[0]?.line).toBe(`boom ${letters(1)}`)
  expect(f[49]?.line).toBe(`boom ${letters(50)}`)
})

test('CAP6: a 4th session drops the oldest of the project', async (
  $, on,
) => {
  const w = await boot($, on)
  for (const id of ['s1', 's2', 's3', 's4']) {
    w.id = id
    await w.clock.advance(10)
    await failing($, w, EXIT1 + `boom ${id}`)
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
  await failing($, w, EXIT1 + pem)
  const f = (failuresOf(w))[0]
  expect(f?.line).toBe('<redacted:private-key>')
  expect(f?.key).toBe('<redacted:private-key>')
  expect(JSON.stringify(f)).not.toContain('MIIB')
})

test('ENTRY1: an entry over 2048 drops its excerpt first', async ($, on) => {
  const w = await boot($, on)
  const text = EXIT1 + '"'.repeat(700) + '\n' + 'a"'.repeat(150)
  await failing($, w, text, '"'.repeat(400))
  const f = (failuresOf(w))[0]
  expect(JSON.stringify(f).length).toBeLessThanOrEqual(2048)
  expect(f?.excerpt).toBe('')
  expect(f?.line.length).toBe(300)
})

test('ID1: a changed session id with no session.start is a new record',
  async ($, on) => {
    const w = await boot($, on)
    await failing($, w, EXIT1 + 'boom one')
    w.id = 's2'
    await w.clock.advance(10)
    await failing($, w, EXIT1 + 'boom two')
    const ids = projectOf(w)?.sessions.map(s => s.id)
    expect(ids).toEqual(['s2', 's1'])
  })

test('ID2: session.end clear then a new id gives two sessions', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + 'boom one')
  await $.session.end({
    reason: 'clear', sessionId: 's1', resume: { id: 's1' },
  })
  w.id = 's2'
  await w.clock.advance(10)
  await failing($, w, EXIT1 + 'boom two')
  expect(projectOf(w)?.sessions).toHaveLength(2)
})

test('RACE1: two concurrent failing calls store two entries', async (
  $, on,
) => {
  const w = await boot($, on)
  const answer = (text: string) =>
    ({ result: { stdout: '', stderr: '' }, text, isError: true })
  w.byCommand.set('a', answer(EXIT1 + 'boom one'))
  w.byCommand.set('b', answer(EXIT1 + 'boom two'))
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
  await failing($, w, EXIT1 + 'completely different problem happened')
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

test('readRegistry: a directory and an over-size file read as empty', async (
  $, on,
) => {
  const big = 'x'.repeat(4194305)
  const w = await boot($, on, { files: { [BLK]: null, [LRN]: big } })
  expect(await readRegistry($ as never, BLK)).toBe('')
  expect(await readRegistry($ as never, LRN)).toBe('')
  await failing($, w, EXIT1 + 'fatal: bad thing')
  expect(await pending($)).toContain(
    'index: skipped blockers.md (not a file), learnings.md (over 4 MiB)')
})

test('an empty root answers no project root', async ($, on) => {
  const w = await boot($, on)
  w.root = ''
  expect(await pending($)).toBe('memory_pending: no project root')
})

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
    '- commit fix: x (14:02)',
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
  await failing($, w, EXIT1 + 'boom one here today')
  w.id = 's2'
  await w.clock.advance(10)
  await failing($, w, EXIT1 + 'boom two here today')
  const text = await pending($)
  expect(text).toContain('session(s))')
  expect(text).toContain('- NEW \u00d71 boom two here today')
  expect(text).toContain('(earlier session) boom one here today')
  expect(text.indexOf('boom two')).toBeLessThan(text.indexOf('boom one'))
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
