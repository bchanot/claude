import { test, expect, mock } from 'claude-code/testing'
import type { Engine, MockClock } from 'claude-code/testing'
import type { On, EngineInterface as Api } from 'claude-code'
import type { Entry, Kind } from './register'
import {
  cap, tail, redact, normalize, failureLine, sessionOf, addFailure,
  entriesOf, parseIndex, isLive, lessonOf, assembleEntries, grams,
  buildIndex, matchOf, deErrno, tokensOf, bm25Rank, rerankPrompt,
  parseIds, recallLine, recallBlock, failureKey,
  segments, suiteKeyOf, commitLabel, finishLabel,
  newState, switchOf, claim, onContextStart, resetContext, endContext,
  appendLog, loadLog, isLogRecord, RECALL_CAP, isTrigger,
  MIN_CONTENT_WORDS, promptContext,
  DESIGN_RULE, ANALYSIS_RULE, HAIKU, RERANK_MS, IDLE_MS,
} from './register'
import type { LogRecord } from './register'

const HOME = '/home/t'
const SWITCH = `${HOME}/.claude/memory.json`
const ROOT = '/work/app'
const BASH_ANSWER = { result: { stdout: 'ok', stderr: '' } }

/** What `memory.sh index` prints for the fixture registries below. */
const INDEX_OUT = [
  '.claude/memory/blockers.md', '',
  '| ID | Date | Title | Status |', '|---|---|---|---|',
  '| BLK-001 | 2026-01-01 | x | open |', '',
  '.claude/memory/learnings.md', '',
  '| ID | Date | Title | Status |', '|---|---|---|---|',
  '| LRN-002 | 2026-01-01 | y | superseded |', '',
].join('\n')

/** How the process bottom answers: a stdout, or a way to fail. */
type Proc = { stdout: string } | 'throw' | 'exit2' | 'hang'

/** How the model bottom answers: a text, a non-answer, or a failure. */
type Model = { text: string } | 'unanswered' | 'throw' | 'hang'

/** What the model bottom was asked. */
type Ask = {
  model: string; prompt: string; effort: unknown
  maxTokens: unknown; timeoutMs: unknown
}

type World = {
  home: string | undefined // what env.get answers for HOME
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
  proc: Proc // what `memory.sh index` does now
  runs: string[][] // every process.run argv
  gets: number // store.get calls
  getsFail: boolean // store.get throws
  model: Model // what `model.complete` does now
  asks: Ask[] // every model.complete call
  storeCap: number // store.set rejects when the store would pass this size
  rejected: number // store.set calls rejected (full store or rejectSets)
  rejectSets: number // the next store.set calls to reject whatever the size
  gitProtect: string | undefined // `git config gitflow.protect` (absent: exit 1)
  gitRuns: string[][] // every git process.run argv
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
  storeCap?: number // total serialized bytes the store accepts
  rejectSets?: number // reject this many store.set calls, then accept
  gitProtect?: string // what `git config --get gitflow.protect` prints
}

/** The bytes the store holds, counting `key` as empty (it is rewritten). */
function storedSize(w: World, key: string): number {
  let n = 0
  for (const [k, v] of w.kv) if (k !== key) n += JSON.stringify(v).length
  return n
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
    const over = storedSize(w, e.key) + JSON.stringify(e.value).length >
      w.storeCap
    if (over || w.rejectSets > 0) {
      w.rejectSets = Math.max(0, w.rejectSets - 1)
      w.rejected++
      throw new Error('store full')
    }
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
    proc: { stdout: INDEX_OUT }, runs: [], home: HOME,
    gets: 0, getsFail: false, model: { text: 'none' }, asks: [],
    storeCap: o.storeCap ?? Infinity, rejected: 0,
    rejectSets: o.rejectSets ?? 0,
    gitProtect: o.gitProtect, gitRuns: [],
  }
  handStore(on, w, o.storeFails ?? false)
  on('tool.register', (_a, e) => {
    w.tools.push(e.name)
    return { value: undefined } as never
  })
  on('env.get', () => ({ value: w.home }))
  on('fs.exists', (_a, e) => {
    if (w.existsFails.has(e.path)) throw new Error('EIO')
    return { value: w.files.has(e.path) ||
      (e.path === SWITCH && w.switchText !== undefined) }
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
  on('process.run', async (_a, e) => {
    if (e.argv[0] === 'git') {
      w.gitRuns.push([...e.argv])
      const out = w.gitProtect
      return { value: { exitCode: out === undefined ? 1 : 0,
        stdout: out === undefined ? '' : `${out}\n`, stderr: '',
        isStdoutTruncated: false, isStderrTruncated: false } }
    }
    w.runs.push([...e.argv])
    if (w.proc === 'throw') throw new Error('spawn failed')
    if (w.proc === 'hang') await new Promise(() => undefined)
    const done = w.proc === 'exit2'
      ? { exitCode: 2, stdout: '' } : { exitCode: 0, stdout: w.proc.stdout }
    return { value: { ...done, stderr: '', isStdoutTruncated: false,
      isStderrTruncated: false } }
  })
  on('model.complete', async (_a, e) => {
    const x = e as unknown as Ask
    w.asks.push({ model: x.model, prompt: x.prompt, effort: x.effort,
      maxTokens: x.maxTokens, timeoutMs: x.timeoutMs })
    if (w.model === 'throw') throw new Error('api down')
    if (w.model === 'hang') await new Promise(() => undefined)
    const usage = { input_tokens: 0, output_tokens: 0 }
    const done = w.model === 'unanswered'
      ? { isAnswered: false, reason: 'api-error', status: 500,
        error: 'server_error', usage }
      : { isAnswered: true, text: w.model.text, usage }
    return { value: done } as never
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
  on('classic.SessionStart', () => ({}))
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
  expect(await bash($, 'ls')).toEqual(BASH_ANSWER)
  expect(w.logs).toEqual([
    'memory: ~/.claude/memory.json unreadable, capture stays on',
  ])
  expect(w.tools).toEqual(['memory_pending'])
})

test('an absent switch file logs nothing', async ($, on) => {
  const w = await boot($, on)
  await bash($, 'ls')
  expect(w.logs).toEqual([])
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

/** The error index of one registry text, every entry live (no statuses). */
const idxOf = (text: string) =>
  buildIndex(assembleEntries([text], new Map()), undefined)

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
  const index = idxOf(body)
  expect(matchOf(index, normalize('fatal: unable to access remote host')))
    .toBe('BLK-009')
  expect(matchOf(index, normalize('and later words fatal unable')))
    .toBeUndefined()
})

test('a key of fewer than 4 words has no gram, so it is NEW', () => {
  expect(grams('a b c')).toEqual([])
  expect(grams('a b c d e')).toEqual(['a b c d', 'b c d e'])
  const index = idxOf('## BLK-001 x\n`aaa bbb ccc ddd`\n')
  expect(matchOf(index, 'aaa bbb ccc')).toBeUndefined()
})

test('entriesOf slices between headings, heading line included', () => {
  const text = '## BLK-001 a\nx\n## other\ny\n## LRN-2 [b]\nz\n'
  expect(entriesOf(text)).toEqual([
    { id: 'BLK-001', body: '## BLK-001 a\nx\n## other\ny\n' },
    { id: 'LRN-2', body: '## LRN-2 [b]\nz\n' },
  ])
})

test('isLive: superseded and deprecated are dead, an absent ID too', () => {
  const m = parseIndex(INDEX_OUT)
  expect(isLive(m, 'BLK-001')).toBe(true)
  expect(isLive(m, 'LRN-002')).toBe(false)
  expect(isLive(m, 'BLK-999')).toBe(false)
  expect(isLive(parseIndex('| BDR-001 | d | t | deprecated |\n'), 'BDR-001'))
    .toBe(false)
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
    'milestones:',
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

test('PM1: current milestone first, then the earlier one', async (
  $, on,
) => {
  const mk = (id: string, at: number, ms: unknown[]) =>
    ({ id, at, failures: [], milestones: ms, red: [] })
  const seed = { [`p:${ROOT}`]: { sessions: [
    mk('s0', 100, [{ kind: 'commit', label: 'fix: old', at: 7200000 }]),
    mk('s1', 900, [{ kind: 'commit', label: 'fix: new', at: 3600000 }]),
  ] } }
  await boot($, on, { seed })
  expect(await pending($)).toBe([
    'memory_pending (project app, 2 session(s))',
    'index: skipped blockers.md (missing), learnings.md (missing)',
    'milestones:',
    '- commit fix: new (' + localHhmm(3600000) + ')',
    '- commit fix: old (' + localHhmm(7200000) + ') (earlier session)',
  ].join('\n'))
})

test('PM2: only an earlier milestone is not nothing captured', async (
  $, on,
) => {
  const seed = { [`p:${ROOT}`]: { sessions: [
    { id: 's0', at: 100, failures: [], red: [],
      milestones: [{ kind: 'commit', label: 'fix: probe', at: 3600000 }] },
  ] } }
  await boot($, on, { seed })
  const text = await pending($)
  expect(text).not.toBe('memory_pending: nothing captured')
  expect(text).toContain(
    '- commit fix: probe (' + localHhmm(3600000) + ') (earlier session)')
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
  const index = idxOf(body)
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
  const at12 = idxOf('## BLK-001 x\n`aa bb cc ddd`\n')
  const at11 = idxOf('## BLK-001 x\n`aa bb cc dd`\n')
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
  w.proc = { stdout: INDEX_OUT.replace('superseded', 'open') }
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
    'milestones:',
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
  const index = idxOf('## LRN-074 x\n' + span + '\n')
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

// ---- 6-bis: vendor prefixes, flags, headers, JSON, pairs, URL user ------

const SIX_BIS: [string, string, string][] = [
  ['anthropic', 't ' + 'sk-' + 'ant-' + 'api03-AbC_dEf-123 z',
    't <redacted:anthropic> z'],
  ['openai', 't ' + 'sk-' + 'proj-' + 'AbCdEf_123-xyz z',
    't <redacted:openai> z'],
  ['github pat', 't ' + 'github_' + 'pat_' + '11ABCDEFG_0123456789 z',
    't <redacted:github> z'],
  ['gitlab', 't ' + 'gl' + 'pat-' + 'abcDEF-12345_xyz z',
    't <redacted:gitlab> z'],
  ['google', 't ' + 'AI' + 'za' + 'SyA-1234567890_abcdefGHIJ z',
    't <redacted:google> z'],
  ['npm', 't ' + 'npm' + '_' + 'abcdEFGH0123 z', 't <redacted:npm> z'],
  ['flag token', 'cli --tok' + 'en abc123 run', 'cli --token <redacted> run'],
  ['flag api-key=', 'cli --api' + '-key=abc123 run',
    'cli --api-key <redacted> run'],
  ['flag secret', 'cli --sec' + 'ret abc123', 'cli --secret <redacted>'],
  ['header x-api-key', 'curl -H "x-api' + '-key: abc 123" u',
    'curl -H "x-api-key: <redacted>'],
  ['header private-token', 'PRIVATE-' + 'TOKEN: abc',
    'PRIVATE-TOKEN: <redacted>'],
  ['header cookie', 'Coo' + 'kie: a=1; b=2\nnext', 'Cookie: <redacted>\nnext'],
  ['json', '{"pass' + 'word": "a b", "x": 1}',
    '{"password": "<redacted>", "x": 1}'],
  ['json upper key', '{"TOK' + 'EN":"abc"}', '{"TOKEN": "<redacted>"}'],
  ['pair colon', 'tok' + 'en: abc123 end', 'token: <redacted> end'],
  ['pair spaced', 'aws_sec' + 'ret_access_key = abc123 end',
    'aws_secret_access_key: <redacted> end'],
  ['pair quoted', 'PASS' + 'WORD="a b" end', 'PASSWORD=<redacted> end'],
  ['pair single quoted', "sec" + "ret: 'a b' end", 'secret: <redacted> end'],
  ['pair after pattern 1 not doubled', 'X_TOK' + 'EN=abc end',
    'X_TOKEN=<redacted> end'],
  ['hex url user', 'git clone https://' + 'a'.repeat(20) + '1'.repeat(20) +
    '@host/x', 'git clone https://<redacted>@host/x'],
]

for (const [name, input, expected] of SIX_BIS) {
  test(`redact 6-bis ${name}`, () => {
    expect(redact(input)).toBe(expected)
  })
}

test('redact 6-bis keeps a bare 40-hex SHA and a short hex URL user', () => {
  const sha = 'a'.repeat(20) + '1'.repeat(20)
  expect(redact('at ' + sha + '@host')).toBe('at ' + sha + '@host')
  expect(redact('https://abc123@host')).toBe('https://abc123@host')
})

test('redact 6-bis residual: user:p@ss@host keeps its tail', () => {
  expect(redact('git clone https://user:p@ss@host/x'))
    .toBe('git clone https://<redacted>@ss@host/x')
})

test('TIME1: each 6-bis rule stays fast on 64 KiB adversarial input', () => {
  const inputs = [
    'sk-ant-'.repeat(9362), 'github_pat_'.repeat(5958), 'npm_'.repeat(16384),
    '--token '.repeat(8192), 'Cookie:'.repeat(9362), '"token":'.repeat(8192),
    'token: '.repeat(9362), 'a_token ='.repeat(7282), 'x://'.repeat(16384),
    'a'.repeat(30) + ' token:'.repeat(9362),
    '"password": "'.repeat(5041), "token='".repeat(9362),
    ('a'.repeat(60) + 'token' + 'b'.repeat(60) + ' ').repeat(361),
  ]
  for (const text of inputs) {
    redact(text.slice(0, 1024)) // warm-up: regex compilation is not the cost
    const t0 = now()
    redact(text)
    expect(now() - t0).toBeLessThan(30) // measured 1-3 ms; slack for load
  }
})

test('the registry index caps a 1 MiB span before normalize', () => {
  const body = '## BLK-001 x\n`' + 'fatal word '.repeat(95326) + '`\n'
  const t0 = now()
  const index = idxOf(body)
  expect(now() - t0).toBeLessThan(50)
  expect(index.size).toBeGreaterThan(0)
})

test('an inner CR in a stored line shows as the newline mark', async (
  $, on,
) => {
  const seed = { [`p:${ROOT}`]: { sessions: [{
    id: 's1', at: 5, milestones: [], red: [],
    failures: [{ key: 'k', line: 'fatal a\rb', excerpt: '', command: 'c',
      agent: false, at: 1, count: 1 }],
  }] } }
  await boot($, on, { seed })
  expect(await pending($)).toContain('- NEW \u00d71 fatal a\u23ceb \u2014')
})

// ---- re-scan: header tail, cookie flags, JSON key affixes ---------------

test('a 420-char Cookie header leaves nothing after the mark', () => {
  const out = redact("curl -H 'cookie: k=" + 'v'.repeat(420) +
    "; sid=SESSION123'")
  expect(out).toBe("curl -H 'cookie: <redacted>")
  expect(out.includes('sid=')).toBe(false)
})

test('curl cookie flags are redacted to the closing quote', () => {
  expect(redact("curl -b 'sessionid=abc123def; csrftoken=x' https://h"))
    .toBe('curl -b <redacted> https://h')
  expect(redact('curl --cookie=a=1 https://h'))
    .toBe('curl --cookie <redacted> https://h')
})

test('JSON keys carry affixes: access_token, client_secret, apiKey', () => {
  expect(redact('{"access_' + 'token": "x"}'))
    .toBe('{"access_token": "<redacted>"}')
  expect(redact('{"client_' + 'secret":"x","refresh-' + 'token": "y"}'))
    .toBe('{"client_secret": "<redacted>","refresh-token": "<redacted>"}')
  expect(redact('{"api' + 'Key": "x"}')).toBe('{"apiKey": "<redacted>"}')
})

test('TIME1: redact on 64 KiB of plain letters stays under 50 ms', () => {
  const t0 = now()
  redact('lorem ipsum dolor sit amet '.repeat(2521))
  expect(now() - t0).toBeLessThan(50)
})

test('a switch file without a boolean enabled logs one line', async (
  $, on,
) => {
  const w = await boot($, on, { switchText: '{"enabled": "false"}' })
  await bash($, 'ls')
  await bash($, 'ls')
  expect(w.logs).toEqual([
    'memory: ~/.claude/memory.json has no boolean "enabled", ' +
      'capture stays on',
  ])
  expect(w.tools).toEqual(['memory_pending'])
})

// ---- round 3: hyphenated api-key, URL scheme bound, cookie scope --------

test('hyphenated api-key forms are redacted', () => {
  expect(redact('{"x-api' + '-key": "v"}')).toBe('{"x-api-key": "<redacted>"}')
  expect(redact('api' + '-key: v')).toBe('api-key: <redacted>')
  expect(redact('X-API-' + 'KEY: v w')).toBe('X-API-KEY: <redacted>')
})

test('a credential URL glued to 40 scheme characters is redacted', () => {
  expect(redact('a'.repeat(40) + 'https://user:pw' + '@host'))
    .toBe('a'.repeat(40) + 'https://<redacted>@host')
})

test('-b is a cookie jar only in a curl segment', () => {
  expect(redact('git checkout -b feature/x'))
    .toBe('git checkout -b feature/x')
  expect(redact("curl -b 'sid=1' h")).toBe('curl -b <redacted> h')
  expect(redact('X=1 curl -b a=b h && git checkout -b y'))
    .toBe('X=1 curl -b <redacted> h && git checkout -b y')
  expect(redact("curl -b 'a=1; b=2' h")).toBe('curl -b <redacted> h')
})

test('TIME1: round 3 shapes stay fast on 64 KiB', () => {
  const inputs = ['curl -b '.repeat(8192), "';".repeat(32768),
    'x-api-'.repeat(10922), 'a'.repeat(65536), 'ab://'.repeat(13107)]
  for (const text of inputs) {
    const t0 = now()
    redact(text)
    expect(now() - t0).toBeLessThan(50)
  }
})

// ---- round 4: Set-Cookie, curl segment prefixes --------------------------

test('a Set-Cookie response header is redacted', () => {
  expect(redact('< Set-Coo' + 'kie: session=abc123def; Path=/'))
    .toBe('< Set-Cookie: <redacted>')
})

test('-b is redacted behind sudo, rtk, env and $( prefixes', () => {
  expect(redact('sudo curl -b "sid=abc" h')).toBe('sudo curl -b <redacted> h')
  expect(redact('x=$(curl -b "sid=abc" h)'))
    .toBe('x=$(curl -b <redacted> h)')
  expect(redact('X=1 rtk curl -b a=b h')).toBe('X=1 rtk curl -b <redacted> h')
  expect(redact('echo -b a')).toBe('echo -b a')
})

test('TIME1: curl prefix shapes stay fast on 64 KiB', () => {
  for (const unit of ['x=$(curl -b a;', 'sudo '.repeat(3) + 'x=1 ', 'X=1 ']) {
    const text = unit.repeat(Math.ceil(65536 / unit.length))
    redact(text.slice(0, 1024))
    const t0 = now()
    redact(text)
    expect(now() - t0).toBeLessThan(30)
  }
})

// ---- Task 1 (phase 4c): statuses from memory.sh, entries with lessons ----

const SR_LINE = 'fatal: unable to access remote host'

test('SR1: parseIndex reads ID, lowercased status word and title', () => {
  const out = [
    '.claude/memory/decisions.md', '',
    '| ID | Date | Title | Status |', '|---|---|---|---|',
    '| BDR-031 | 2026-06-25 | t | superseded |',
    '| LRN-001 | 2026-01-01 | a | b | Open (2026) |',
    '| LRN-003 | 2026-01-01 | t |  |',
  ].join('\n')
  expect([...parseIndex(out)]).toEqual([
    ['BDR-031', { status: 'superseded', title: 't' }],
    ['LRN-001', { status: 'open', title: 'a | b' }],
    ['LRN-003', { status: '', title: 't' }],
  ])
})

test('SR2: a superseded entry is not indexed, a live one is known', async (
  $, on,
) => {
  const w = await boot($, on, { files: REGS })
  w.proc = { stdout: INDEX_OUT.replace('| open |', '| superseded |') }
  await failing($, w, EXIT1 + SR_LINE)
  expect(await pending($)).toContain('- NEW ×1 ' + SR_LINE)
  w.proc = { stdout: INDEX_OUT.replace('| superseded |', '| open |') }
  await failing($, w, EXIT1 + 'error: pathspec did not match anything')
  expect(await pending($)).toContain('- known LRN-002 ×1 error: path')
})

test('SR2b: the process is run once, with the memory.sh argv', async (
  $, on,
) => {
  const w = await boot($, on, { files: REGS })
  await pending($)
  expect(w.runs).toEqual([
    ['bash', '/home/t/.claude/lib/memory.sh', '-C', '/work/app', 'index'],
  ])
})

for (const [name, proc] of [
  ['SR3: process.run throws', 'throw'],
  ['SR4: exit code 2', 'exit2'],
  ['SR6: an empty stdout', { stdout: '' }],
] as const) {
  test(`${name}: advisory known, status reader unavailable`, async (
    $, on,
  ) => {
    const w = await boot($, on, { files: REGS })
    w.proc = proc
    await failing($, w, EXIT1 + SR_LINE)
    const text = await pending($)
    expect(text.split('\n').find(l => l.startsWith('index:')))
      .toBe('index: read blockers.md, learnings.md; status reader unavailable')
    expect(text).toContain('- known BLK-001 ×1 ' + SR_LINE)
  })
}

test('SR5: process.run never settles, the answer comes at 2500 ms', async (
  $, on,
) => {
  const w = await boot($, on, { files: REGS })
  await failing($, w, EXIT1 + SR_LINE)
  w.proc = 'hang'
  const answer = pending($)
  await w.clock.advance(2500)
  const text = await answer
  expect(text.split('\n').find(l => l.startsWith('index:')))
    .toBe('index: read blockers.md, learnings.md; status reader unavailable')
  expect(text).toContain('- known BLK-001 ×1 ' + SR_LINE)
})

test('SR7: no registry read, no process run, no unavailable note', async (
  $, on,
) => {
  const w = await boot($, on)
  await failing($, w, EXIT1 + SR_LINE)
  const text = await pending($)
  expect(w.runs).toEqual([])
  expect(text).not.toContain('status reader')
})

test('SR8: HOME unset, status unavailable, fails open', async ($, on) => {
  const w = await boot($, on, { files: REGS })
  await failing($, w, EXIT1 + SR_LINE)
  w.runs = [] // the capture's known-line step ran the reader once
  w.home = undefined
  const text = await pending($)
  expect(w.runs).toEqual([])
  expect(text.split('\n').find(l => l.startsWith('index:')))
    .toBe('index: read blockers.md, learnings.md; status reader unavailable')
  expect(text).toContain('- known BLK-001 ×1 ' + SR_LINE)
})

test('SR9: the status word is its leading letters only', () => {
  const row = '| BDR-031 | 2026-06-25 | t | superseded-by BDR-040 |'
  expect(parseIndex(row).get('BDR-031')?.status).toBe('superseded')
})

test('TIMEindex: parseIndex on 64 KiB stays under 50 ms', () => {
  const rows = [
    '| LRN-001 | 2026-01-01 | ' + 'a | '.repeat(16000) + ' | open |',
    '| BLK-001 | ' + '|'.repeat(65000),
    ('| LRN-002 | 2026-01-01 | t | open |\n').repeat(2000),
  ]
  for (const text of rows) {
    const t0 = now()
    parseIndex(text.slice(0, 65536))
    expect(now() - t0).toBeLessThan(50)
  }
})

test('LS1: a BDR Decision reads its first sentence', () => {
  expect(lessonOf('BDR', '## BDR-1 t\n- **Decision**: Use X. Then Y.\n'))
    .toBe('Use X.')
})

test('LS2: an LRN takes Apply before Pattern', () => {
  const body = '## LRN-1 t\n- **Pattern**: p one\n- **Apply**: do it now\n'
  expect(lessonOf('LRN', body)).toBe('do it now')
  expect(lessonOf('LRN', '## LRN-1 t\n- **Pattern**: p one\n'))
    .toBe('p one')
})

test('LS3: a BLK plain label, Solution before Real cause', () => {
  expect(lessonOf('BLK', '## BLK-1 t\n- Real cause: c\n- Solution: fix z\n'))
    .toBe('fix z')
  expect(lessonOf('BLK', '## BLK-1 t\n- **Real cause**: only c\n'))
    .toBe('only c')
  expect(lessonOf('BLK', '## BLK-1 t\n- **Friction**: f\n')).toBe('')
})

test('LS4: a 2000-char field is cut at 280 ending with an ellipsis', () => {
  const text = lessonOf('BDR', '## BDR-1 t\n- **Decision**: ' +
    'a'.repeat(2000) + '\n')
  expect(text).toHaveLength(280)
  expect(text.endsWith('a…')).toBe(true)
})

test('LS5: a 2001-char Decision still yields a lesson cut at 280', () => {
  const text = lessonOf('BDR', '## BDR-1 t\n- **Decision**: ' +
    'b'.repeat(2001) + '\nnext line\n')
  expect(text).toHaveLength(280)
  expect(text.endsWith('…')).toBe(true)
})

test('LS6: `; ` ends the sentence before a capital only', () => {
  expect(lessonOf('BDR', '- Decision: a; Then b')).toBe('a;')
  expect(lessonOf('BDR', '- Decision: a; then b. c')).toBe('a; then b. c')
})

test('EN1: a heading of 320 chars is still an entry; ## Notes is not', () => {
  const text = '## BDR-007 — ' + 'T'.repeat(320) + '\nbody\n## Notes\nx\n'
  const parts = entriesOf(text)
  expect(parts.map(p => p.id)).toEqual(['BDR-007'])
  expect(parts[0]?.body).toBe(text) // the 4b rule: up to the next entry
})

test('assembleEntries joins kind, memory.sh title, lesson and body', () => {
  const body = '## LRN-009 — t [open] (2026-01-02)\n- **Apply**: do z. Ok\n'
  const long = 'W'.repeat(150)
  const index = parseIndex(
    `| LRN-009 | 2026-01-02 | ${long} | open |\n`)
  const [e] = assembleEntries([body], index)
  expect(e).toEqual({
    id: 'LRN-009', kind: 'LRN', title: 'W'.repeat(99) + '…',
    lesson: 'do z.', body,
  })
  expect(assembleEntries([body], new Map())[0]?.title).toBe('')
})

test('TIMEentries: entriesOf, lessonOf on 64 KiB fields, under 50 ms', () => {
  const bodies = [
    '## BLK-001 x\n- Solution: ' + 'a'.repeat(65536 - 26),
    '## BLK-001 x\n- Solution: ' + 'a. '.repeat(21000),
    '## BLK-001 x\n' + ' '.repeat(65536) + '- Solution: y',
    '## BLK-001 x\n' + '- '.repeat(32768),
  ]
  for (const text of bodies) {
    const t0 = now()
    for (const part of entriesOf(text)) lessonOf('BLK', part.body)
    expect(now() - t0).toBeLessThan(50)
  }
})

// ---- Task 2 (phase 4c): errno phrases out of the error index ----

const ER_ENTRY = '## LRN-009 e\n- **Status**: open\n'

test('ER1: an ENOENT line never makes another ENOENT known', async (
  $, on,
) => {
  const text = ER_ENTRY +
    'seen: `cat: x: No such file or directory (os error 2)`\n'
  const w = await boot($, on, { files: { [LRN]: text } })
  w.proc = { stdout: '| LRN-009 | 2026-01-01 | e | open |' }
  await failing($, w,
    EXIT1 + "ls: cannot access '/tmp/zz': No such file or directory")
  expect(await pending($)).toContain('- NEW ×1 ls: cannot access')
})

test('ER2: content grams still match around an errno-free line', async (
  $, on,
) => {
  const text = ER_ENTRY + 'seen: `fatal: unable to access remote host thing`\n'
  const w = await boot($, on, { files: { [LRN]: text } })
  w.proc = { stdout: '| LRN-009 | 2026-01-01 | e | open |' }
  await failing($, w, EXIT1 + 'fatal: unable to access remote host thing')
  expect(await pending($)).toContain('- known LRN-009 ×1 fatal:')
})

test('ER3: deErrno replaces a phrase on a normalized line', () => {
  expect(deErrno('cat: <path>: no such file or directory (os error #)'))
    .toBe('cat: <path>: <errno> (os error #)')
  expect(deErrno('xpermission denied here')).toBe('xpermission denied here')
})

test('ER4: a gram of placeholders only is skipped', () => {
  expect(grams('<errno> <path> # <hex>')).toEqual([])
})

test('ER5: input/output error becomes <errno> despite the path rule', () => {
  expect(normalize('cp: Input/output error (os error 5)'))
    .toBe('cp: <errno> (os error #)')
  expect(normalize('read /dev/sda1: input/output error'))
    .toBe('read <path>: <errno>')
})

test('TIMEerrno: deErrno on 64 KiB of a phrase prefix, under 50 ms', () => {
  const t0 = now()
  deErrno('no such file or '.repeat(4096))
  expect(now() - t0).toBeLessThan(50)
})

const mk = (id: string, title: string, lesson: string, body = ''): Entry =>
  ({ id, kind: id.slice(0, 3) as Kind, title, lesson, body })

const RB_ENTRIES = [
  mk('LRN-001', 'css grid gaps', 'Use gap.', 'layout of cards'),
  mk('BLK-002', 'heredoc quoting breaks', 'Quote the delimiter.',
    'shell heredoc quoting eats the dollar sign in shell scripts'),
  mk('BDR-003', 'store keys', 'Prefix them.', 'kv store naming'),
]

test('RB1: bm25Rank puts the heredoc entry first, drops score 0', () => {
  const ids = bm25Rank(RB_ENTRIES, 'quoting heredoc shell', 5).map(e => e.id)
  expect(ids).toEqual(['BLK-002'])
  expect(bm25Rank(RB_ENTRIES, 'the and for', 5)).toEqual([])
  expect(tokensOf('The Heredoc, a b ÉTÉ 42')).toEqual(['heredoc', 'été', '42'])
})

test('RB1b: ties go by numeric ID order, k bounds the result', () => {
  const twin = [mk('LRN-10', 'zed', ''), mk('LRN-9', 'zed', '')]
  expect(bm25Rank(twin, 'zed', 5).map(e => e.id)).toEqual(['LRN-9', 'LRN-10'])
  expect(bm25Rank(twin, 'zed', 1).map(e => e.id)).toEqual(['LRN-9'])
})

test('RB2: parseIds keeps candidate IDs once, in order, up to max', () => {
  const cands = [mk('BLK-041', 't', ''), mk('LRN-258', 't', '')]
  expect(parseIds('BLK-041, BDR-999, LRN-258', cands, 3))
    .toEqual(['BLK-041', 'LRN-258'])
  expect(parseIds('LRN-258 BLK-041 LRN-258', cands, 1)).toEqual(['LRN-258'])
  expect(parseIds('none', cands, 3)).toEqual([])
})

test('RB3: long Decisions give ellipsis lessons and a block under cap', () => {
  const field = 'Use alpha ' + 'x'.repeat(1990)
  const es = ['BDR-001', 'BDR-002', 'BDR-003'].map(id =>
    assembleEntries([`## ${id} — t\n- **Decision**: ${field}\n`],
      new Map([[id, { status: 'accepted', title: 'T' + id }]]))[0]!)
  for (const e of es) expect(recallLine(e).endsWith('…')).toBe(true)
  const block = recallBlock(es.map(recallLine), 1500)
  expect(block.length).toBeLessThanOrEqual(1500)
  expect(block.split('\n')[0]).toBe('memory recall:')
  expect(block.split('\n')[1]).toBe(
    'BDR-001 TBDR-001 — Use alpha ' + 'x'.repeat(280 - 11) + '…')
})

test('RB3b: recallLine and recallBlock edges', () => {
  expect(recallLine(mk('LRN-1', 'T', 'a;'))).toBe('LRN-1 T — a;')
  expect(recallLine(mk('LRN-1', 'T', 'Use X.'))).toBe('LRN-1 T — Use X.')
  expect(recallLine(mk('LRN-1', 'T', ''))).toBe('LRN-1 T')
  expect(recallBlock(['a'.repeat(50)], 20)).toBe('')
  expect(recallBlock(['a'.repeat(50), 'bb'], 20)).toBe('memory recall:\nbb')
  expect(recallBlock([], 100)).toBe('')
})

test('RB4: rerankPrompt is the literal prompt', () => {
  const cands = [mk('LRN-1', 'T one', 'Do a.'), mk('BLK-2', 'T two', '')]
  expect(rerankPrompt('fix the heredoc', cands)).toBe(
    'Prompt: fix the heredoc\nCandidates:\nLRN-1 | T one | Do a.\n' +
    'BLK-2 | T two | \nAnswer with at most 3 candidate IDs that would ' +
    'help with this prompt, comma separated, or none.')
})

test('RB5: 500 entries and a 64 KiB query rank under 300 ms', () => {
  const es = Array.from({ length: 500 }, (_, i) =>
    mk(`LRN-${i + 1}`, `t${i}`, 'l', `w${i} word `.repeat(160)))
  const head = 'w7 '.padEnd(2000, 'z ')
  const t0 = now()
  const a = bm25Rank(es, head + 'w9 '.repeat(20000), 5).map(e => e.id)
  expect(now() - t0).toBeLessThan(300)
  const b = bm25Rank(es, head + 'w300 '.repeat(20000), 5).map(e => e.id)
  expect(a).toEqual(b)
  expect(a[0]).toBe('LRN-8')
})

test('RB6: a secret-shaped token is redacted in the rerank prompt', () => {
  const secret = 'sk_live_' + 'a'.repeat(24)
  const p = rerankPrompt(`use ${secret} now`, [])
  expect(p).toContain('<redacted:stripe>')
  expect(p).not.toContain(secret)
})

test('RB7: failureKey is the normalized last line of the redacted tail', () => {
  expect(failureKey('Exit code 1\nrm: /tmp/x/y: Permission denied', 'rm x'))
    .toBe('rm: <path>: permission denied')
  expect(failureKey('', 'ls')).toBeUndefined()
  expect(failureKey('make: *** [all] Error 2', 'make')).toBeUndefined()
})

test('RB6b: a secret straddling char 2000 of the query is redacted', () => {
  const secret = 'sk_live_' + 'a'.repeat(24)
  const q = 'x'.repeat(1979) + ' ' + secret + ' tail'
  const p = rerankPrompt(q, [])
  expect(q.indexOf(secret)).toBeLessThan(2000)
  expect(q.indexOf(secret) + secret.length).toBeGreaterThan(2000)
  expect(p).toContain('<redacted:stripe>')
  expect(p).not.toContain('sk_live_')
  expect(p).not.toContain('aaaa')
})

test('TIMErank: tokensOf and parseIds on 64 KiB, under 50 ms', () => {
  const t0 = now()
  tokensOf('ab '.repeat(21000))
  tokensOf('x'.repeat(65536))
  parseIds('BDR-1 '.repeat(10000) + 'LRN-'.repeat(15000), [], 3)
  expect(now() - t0).toBeLessThan(50)
})

// ---- recall: switch key, injection log, per-context ledger -------------

test('SW1: no enabled key with "recall": false logs nothing', async (
  $, on,
) => {
  const w = await boot($, on, { switchText: '{"recall": false}' })
  await bash($, 'ls')
  expect(w.logs).toEqual([])
  expect(w.tools).toEqual(['memory_pending'])
})

test('SW2: a non-boolean "recall" logs one line, recall stays on', async (
  $, on,
) => {
  const w = await boot($, on, { switchText: '{"recall": "no"}' })
  await bash($, 'ls')
  await bash($, 'ls')
  expect(w.logs).toEqual([
    'memory: ~/.claude/memory.json has no boolean "recall", ' +
      'recall stays on',
  ])
  expect(w.tools).toEqual(['memory_pending'])
})

test('SW3: switchOf reads the two keys', () => {
  const $ = { ui: { log: () => undefined } } as never
  const of = (data: unknown) => switchOf($, newState(), data)
  expect(of({})).toEqual({ enabled: true, recall: true })
  expect(of({ recall: false })).toEqual({ enabled: true, recall: false })
  expect(of({ recall: 'no' })).toEqual({ enabled: true, recall: true })
  expect(of({ enabled: false })).toEqual({ enabled: false, recall: false })
  expect(of({ enabled: false, recall: true }))
    .toEqual({ enabled: false, recall: false })
  expect(of(null)).toEqual({ enabled: true, recall: true })
})

test('SW4: enabled false turns everything off, silently', async ($, on) => {
  const w = await boot($, on, { switchText: '{"enabled": false}' })
  await failing($, w, 'Exit code 1\nfatal: bad thing')
  expect(w.logs).toEqual([])
  expect(w.tools).toEqual([])
  expect(w.sets).toEqual([])
})

/** A state that holds injections for two sessions and an agent. */
function ledger() {
  const st = newState()
  for (const key of ['s1:main', 's1:a1', 's2:main']) {
    st.seen.set(key, new Set(['BLK-001']))
    st.spent.set(key, 100)
  }
  return st
}

test('CS1: startup, clear and compact reset the session, mark it fresh',
  () => {
    for (const source of ['startup', 'clear', 'compact']) {
      const st = ledger()
      resetContext(st, source, 's1', undefined)
      expect([...st.seen.keys()]).toEqual(['s2:main'])
      expect([...st.spent.keys()]).toEqual(['s2:main'])
      expect([...st.fresh]).toEqual(['s1'])
    }
  })

test('CS2: resume and fork change nothing', () => {
  const st = ledger()
  resetContext(st, 'resume', 's1', undefined)
  resetContext(st, 'fork', 's1', undefined)
  expect([...st.seen.keys()]).toEqual(['s1:main', 's1:a1', 's2:main'])
  expect([...st.spent.values()]).toEqual([100, 100, 100])
  expect(st.fresh.size).toBe(0)
})

test('CS3: an agent start resets only that agent key', () => {
  const st = ledger()
  resetContext(st, 'startup', 's1', 'a1')
  expect([...st.seen.keys()]).toEqual(['s1:main', 's2:main'])
  expect([...st.spent.keys()]).toEqual(['s1:main', 's2:main'])
  expect(st.fresh.size).toBe(0)
})

test('CS4: the classic SessionStart event passes through the hook',
  async ($, on) => {
    const w = await boot($, on)
    const out = await $.classic.SessionStart({
      hook_event_name: 'SessionStart', transcript_path: '/t', cwd: ROOT,
      session_id: 's1', source: 'compact',
    } as never)
    expect(out).toEqual({})
    expect(w.logs).toEqual([])
  })

test('CS5: endContext clears only the ending session', () => {
  const st = ledger()
  for (const id of ['s1', 's2']) {
    st.fresh.add(id)
    st.lastPrompt.set(id, 5)
  }
  endContext(st, 's1')
  expect([...st.seen.keys()]).toEqual(['s2:main'])
  expect([...st.spent.keys()]).toEqual(['s2:main'])
  expect([...st.fresh]).toEqual(['s2'])
  expect([...st.lastPrompt.keys()]).toEqual(['s2'])
})

test('onContextStart is the one reset: forgets then marks fresh', () => {
  const st = ledger()
  onContextStart(st, 's2')
  expect([...st.seen.keys()]).toEqual(['s1:main', 's1:a1'])
  expect([...st.fresh]).toEqual(['s2'])
})

test('CL1: claim returns the unseen IDs that fit and records them', () => {
  const st = newState()
  const got = claim(st, 'k', ['A-1', 'B-2', 'C-3'], [400, 400, 400])
  expect(got).toEqual(['A-1', 'B-2', 'C-3'])
  expect(st.spent.get('k')).toBe(1200)
  expect([...(st.seen.get('k') ?? [])]).toEqual(['A-1', 'B-2', 'C-3'])
})

test('CL2: claim excludes the seen and stops at the budget', () => {
  const st = newState()
  expect(claim(st, 'k', ['A-1'], [900])).toEqual(['A-1'])
  // A-1 is seen; B-2 (700) would pass 1500, C-3 (600) fits exactly
  expect(claim(st, 'k', ['A-1', 'B-2', 'C-3'], [900, 700, 600]))
    .toEqual(['C-3'])
  expect(st.spent.get('k')).toBe(RECALL_CAP)
  expect(st.seen.get('k')?.has('B-2')).toBe(false)
  expect(claim(st, 'k', ['B-2'], [1])).toEqual([])
})

test('CL3: claim keys are independent', () => {
  const st = newState()
  claim(st, 's1:main', ['A-1'], [1500])
  expect(claim(st, 's1:a1', ['A-1'], [1500])).toEqual(['A-1'])
})

/** The plugin's $.store over the world's Map, for the pure log calls. */
const storeApi = (w: World) => ({ store: {
  get: async (k: string) => w.kv.get(k),
  set: async (k: string, v: unknown) => {
    w.sets.push(k)
    w.kv.set(k, JSON.parse(JSON.stringify(v)))
  },
  keys: async () => [...w.kv.keys()],
  delete: async (k: string) => void w.kv.delete(k),
} }) as never

const REC = (at: number, ids = ['BLK-001']): LogRecord =>
  ({ at, session: 's1', agent: 'main', channel: 'prompt', ids })

test('LG1: a log in l:<root> survives a capture and a sweep', async (
  $, on,
) => {
  const big = (id: string, at: number) => ({
    id, at, milestones: [], red: [],
    failures: [{ key: 'k', line: 'l', excerpt: 'x'.repeat(600000),
      command: 'c', agent: false, at, count: 1 }],
  })
  const seed = {
    'l:/work/app': [REC(7)],
    'p:/other': { sessions: [big('o2', 20), big('o1', 10)] },
  }
  const w = await boot($, on, { seed })
  await failing($, w, EXIT1 + 'fatal: bad thing')
  expect(projectOf(w, '/other')?.sessions.map(s => s.id)).toEqual(['o2'])
  expect(w.kv.get('l:/work/app')).toEqual([REC(7)])
  expect(projectOf(w)?.sessions).toHaveLength(1)
})

test('LG2: 205 appends keep the newest 200', async ($, on) => {
  const w = await boot($, on)
  const st = newState()
  const api = storeApi(w)
  for (let at = 0; at < 205; at++) await appendLog(api, st, ROOT, REC(at))
  const log = w.kv.get(`l:${ROOT}`) as LogRecord[]
  expect(log).toHaveLength(200)
  expect(log[0]?.at).toBe(5)
  expect(log[199]?.at).toBe(204)
  expect(w.sets.every(k => k === `l:${ROOT}`)).toBe(true)
})

test('LG3: over 64 KiB serialized, the oldest records are dropped',
  async ($, on) => {
    const w = await boot($, on)
    const st = newState()
    const ids = ['X'.repeat(10000)]
    for (let at = 0; at < 10; at++) {
      await appendLog(storeApi(w), st, ROOT, REC(at, ids))
    }
    const log = w.kv.get(`l:${ROOT}`) as LogRecord[]
    expect(log.map(r => r.at)).toEqual([4, 5, 6, 7, 8, 9])
    expect(JSON.stringify(log).length).toBeLessThanOrEqual(65536)
  })

test('LG5: a record without trigger and outcome stays valid', async (
  $, on,
) => {
  const bad = { ...REC(3), trigger: 'x' }
  const odd = { ...REC(4), outcome: 'x' }
  const ok = { ...REC(5), trigger: 'idle', outcome: 'none' }
  const seed = { [`l:${ROOT}`]: [REC(1), bad, odd, ok] }
  const w = await boot($, on, { seed })
  expect(await loadLog(storeApi(w), ROOT)).toEqual([REC(1), ok])
})

/** A raw log of `n` records of about `kb` KiB, the newest at `at`. */
const bigLog = (at: number, kb: number) =>
  [REC(at, ['X'.repeat(kb * 1024)])]

test('LG6: over the engine cap, the oldest l: key goes first', async (
  $, on,
) => {
  const seed: Record<string, unknown> = {}
  for (let i = 1; i <= 68; i++) seed[`l:/r${i}`] = bigLog(i * 10, 60)
  const w = await boot($, on, { seed })
  await failing($, w, EXIT1 + 'fatal: bad thing')
  expect(w.kv.has('l:/r1')).toBe(false)
  expect(w.kv.has('l:/r68')).toBe(true)
  expect(failuresOf(w)).toHaveLength(1)
  const bytes = [...w.kv.values()].reduce(
    (n: number, v) => n + JSON.stringify(v).length, 0)
  expect(bytes).toBeLessThanOrEqual(4194304)
})

test('LG7: the current root log is never evicted while others exist',
  async ($, on) => {
    const seed: Record<string, unknown> = { [`l:${ROOT}`]: bigLog(1, 60) }
    for (let i = 1; i <= 68; i++) seed[`l:/r${i}`] = bigLog(i * 10, 60)
    const w = await boot($, on, { seed })
    await failing($, w, EXIT1 + 'fatal: bad thing')
    expect(w.kv.has(`l:${ROOT}`)).toBe(true)
    expect(w.kv.has('l:/r1')).toBe(false)
  })

test('LG8: a new log key sweeps too, before its own write', async (
  $, on,
) => {
  const w = await boot($, on)
  for (let i = 1; i <= 68; i++) w.kv.set(`l:/r${i}`, bigLog(i * 10, 60))
  await appendLog(storeApi(w), newState(), ROOT, REC(900))
  expect(w.kv.has('l:/r1')).toBe(false)
  expect(w.kv.get(`l:${ROOT}`)).toEqual([REC(900)])
})

test('LG4: loadLog drops malformed records; project key untouched',
  async ($, on) => {
    const bad = { at: 'x', session: 's1', agent: 'main', ids: [] }
    const w = await boot($, on, { seed: {
      [`l:${ROOT}`]: [REC(1), bad, null, { ...REC(2), channel: 'x' }],
    } })
    expect(await loadLog(storeApi(w), ROOT)).toEqual([REC(1)])
    expect(w.kv.has(`p:${ROOT}`)).toBe(false)
  })

// ---- intent recall at the prompt ---------------------------------------

const DECISIONS = `${REG}/decisions.md`
const entryText = (id: string, title: string, label: string, lesson: string) =>
  `## ${id} \u2014 ${title}\n- **Status**: open\n- **${label}**: ${lesson}\n`
const rowsOut = (rows: [string, string][]) => [
  '.claude/memory/x.md', '', '| ID | Date | Title | Status |',
  '|---|---|---|---|',
  ...rows.map(([id, title]) => `| ${id} | 2026-01-01 | ${title} | open |`), '',
].join('\n')

const BLK1_LINE = 'BLK-001 mod design \u2014 Keep the suite small and ' +
  'concevoir the mod first.'
const BLK1 = entryText('BLK-001', 'mod design', 'Solution',
  'Keep the suite small and concevoir the mod first.')
const LRN2 = entryText('LRN-002', 'design notes', 'Pattern',
  'Write design notes before coding.')
const REC_FILES = { [BLK]: BLK1, [LRN]: LRN2 }
const REC_INDEX = rowsOut([['BLK-001', 'mod design'],
  ['LRN-002', 'design notes']])

const GO = 'on va concevoir la suite du mod memory recall'
const DESIGN = 'design the mod suite and tests please'
const NOTES = 'write notes about the mod now'

/** Boots the notes world with recall fixtures; the model picks BLK-001. */
async function bootRecall($: Engine, on: On, o: Opts = {}) {
  const r = await bootNotes($, on, { files: REC_FILES, ...o })
  r.w.proc = { stdout: REC_INDEX }
  r.w.model = { text: 'BLK-001' }
  return r
}

const start = ($: Engine, source = 'startup') => $.classic.SessionStart({
  hook_event_name: 'SessionStart', transcript_path: '/t', cwd: ROOT,
  session_id: 's1', source,
} as never)

const say = ($: Engine, text: string, turnId?: string) => $.prompt.submit({
  text, wait: turnId !== undefined, origin: { kind: 'composer' },
  ...(turnId === undefined ? {} : { turnId }),
})

const BLOCK1 = `memory recall:\n${BLK1_LINE}`

/** The `trigger` and `outcome` of every logged ask, oldest first. */
async function askLog(w: World) {
  return (await loadLog(storeApi(w), ROOT))
    .map(r => [r.trigger, r.outcome, r.ids])
}

test('LO1: a fresh ask that injects logs fresh and injected', async (
  $, on,
) => {
  const { w } = await bootRecall($, on)
  await start($)
  await say($, GO)
  expect(await askLog(w)).toEqual([['fresh', 'injected', ['BLK-001']]])
})

test('LO2: idle and keyword triggers are told apart', async ($, on) => {
  const { w } = await bootRecall($, on)
  await start($)
  await say($, GO)
  await w.clock.advance(1860000)
  await say($, NOTES)
  await say($, DESIGN)
  expect((await askLog(w)).map(r => r[0]))
    .toEqual(['fresh', 'idle', 'keyword'])
})

test('LO3: an answer of none logs an empty ask', async ($, on) => {
  const { w, seen } = await bootRecall($, on)
  w.model = { text: 'none' }
  await start($)
  await say($, GO)
  expect(seen).toEqual([undefined])
  expect(await askLog(w)).toEqual([['fresh', 'none', []]])
})

test('LO4: no candidate left logs none without asking', async ($, on) => {
  const { w } = await bootRecall($, on)
  w.proc = { stdout: rowsOut([['BLK-001', 'x'], ['LRN-002', 'y']])
    .replace(/open/g, 'superseded') }
  await start($)
  await say($, GO)
  expect(w.asks).toEqual([])
  expect(await askLog(w)).toEqual([['fresh', 'none', []]])
})

test('LO5: an unanswered call and a throw log timeout', async ($, on) => {
  const { w } = await bootRecall($, on)
  await start($)
  for (const m of ['unanswered', 'throw'] as Model[]) {
    w.model = m
    await say($, DESIGN)
  }
  expect(await askLog(w)).toEqual([
    ['fresh', 'timeout', []], ['keyword', 'timeout', []],
  ])
})

test('LO6: an ask during the pause logs paused', async ($, on) => {
  const { w } = await bootRecall($, on)
  w.model = 'unanswered'
  await start($)
  for (let i = 0; i < 4; i++) await say($, DESIGN)
  expect((await askLog(w)).map(r => r[1]))
    .toEqual(['timeout', 'timeout', 'timeout', 'paused'])
  expect(w.asks).toHaveLength(3)
})

test('LO7: a pick the ledger refuses logs refused', async ($, on) => {
  const { w } = await bootRecall($, on)
  await start($)
  await Promise.all([say($, GO), say($, DESIGN)])
  expect((await askLog(w)).map(r => r[1]).sort())
    .toEqual(['injected', 'refused'])
})

/** [outcome, cands, ms] of every logged ask, oldest first. */
async function askMeta(w: World) {
  return (await loadLog(storeApi(w), ROOT))
    .map(r => [r.outcome, r.cands, r.ms])
}

/** The single ask of a fresh world answered by `model`. */
async function oneAsk($: Engine, on: On, model?: Model) {
  const { w } = await bootRecall($, on)
  if (model !== undefined) w.model = model
  await start($)
  await say($, GO)
  return (await askMeta(w))[0] ?? []
}

test('LF1: an injected ask logs cands and ms', async ($, on) => {
  const [outcome, cands, ms] = await oneAsk($, on)
  expect(outcome).toBe('injected')
  expect(typeof cands === 'number' && cands >= 1).toBe(true)
  expect(ms).toBe(0) // the mock clock does not move during an answer
})

test('LF1b: a declined ask logs cands and ms', async ($, on) => {
  const [outcome, cands, ms] = await oneAsk($, on, { text: 'none' })
  expect(outcome).toBe('none')
  expect(typeof cands === 'number' && cands >= 1).toBe(true)
  expect(ms).toBe(0)
})

test('LF1c: an unanswered ask logs cands and ms', async ($, on) => {
  const [outcome, cands, ms] = await oneAsk($, on, 'unanswered')
  expect(outcome).toBe('timeout')
  expect(typeof cands === 'number' && cands >= 1).toBe(true)
  expect(ms).toBe(0)
})

test('LF2: no candidate logs cands 0 and no ms', async ($, on) => {
  const { w } = await bootRecall($, on)
  w.proc = { stdout: rowsOut([['BLK-001', 'x'], ['LRN-002', 'y']])
    .replace(/open/g, 'superseded') }
  await start($)
  await say($, GO)
  expect(await askMeta(w)).toEqual([['none', 0, undefined]])
})

test('LF3: a paused ask logs cands without ms', async ($, on) => {
  const { w } = await bootRecall($, on)
  w.model = 'unanswered'
  await start($)
  for (let i = 0; i < 4; i++) await say($, DESIGN)
  const last = (await askMeta(w)).at(-1)
  expect(last?.[0]).toBe('paused')
  expect((last?.[1] as number) >= 1).toBe(true)
  expect(last?.[2]).toBeUndefined()
})

test('LF4: cands and ms are optional counts', async ($, on) => {
  const good = { ...REC(2), cands: 4, ms: 812 }
  const neg = { ...REC(3), cands: -1 }
  const frac = { ...REC(4), ms: 1.5 }
  const seed = { [`l:${ROOT}`]: [REC(1), good, neg, frac] }
  const w = await boot($, on, { seed })
  expect(await loadLog(storeApi(w), ROOT)).toEqual([REC(1), good])
  expect(isLogRecord(REC(1))).toBe(true)
})

test('IR1: the first prompt of a context asks and injects the block',
  async ($, on) => {
    const { w, seen } = await bootRecall($, on)
    await start($)
    await say($, GO)
    expect(w.asks).toHaveLength(1)
    expect(w.asks[0]).toMatchObject({ model: 'claude-haiku-5-5',
      effort: 'low', maxTokens: 64, timeoutMs: 5000 })
    expect(w.asks[0]?.prompt).toContain('BLK-001 | mod design | ')
    expect(seen).toEqual([[BLOCK1]])
  })

test('IR2 IR3: an ordinary prompt 1 min later is silent, 31 min asks',
  async ($, on) => {
    const { w, seen } = await bootRecall($, on)
    await start($)
    await say($, GO)
    await w.clock.advance(60000)
    await say($, NOTES)
    expect(w.asks).toHaveLength(1)
    expect(seen[1]).toBeUndefined()
    await w.clock.advance(1860000)
    await say($, NOTES)
    expect(w.asks).toHaveLength(2)
  })

test('IR4: slash, mid-turn, sdk and short prompts never ask', async (
  $, on,
) => {
  const { w, seen } = await bootRecall($, on)
  await start($)
  await say($, '/feat add design notes')
  await say($, DESIGN, 'u1')
  await $.prompt.submit({ text: DESIGN, wait: false, origin: { kind: 'sdk' } })
  await say($, 'design note')
  expect(w.asks).toEqual([])
  expect(seen.every(c => c === undefined)).toBe(true)
  await say($, DESIGN)
  expect(w.asks).toHaveLength(1)
})

test('IR5: an ID that is not a candidate is never injected', async (
  $, on,
) => {
  const { w, seen } = await bootRecall($, on)
  w.model = { text: 'BDR-999, BLK-001' }
  await start($)
  await say($, GO)
  expect(seen).toEqual([[BLOCK1]])
})

test('IR5b: none, an unanswered call and a throw add nothing', async (
  $, on,
) => {
  const { w, seen } = await bootRecall($, on)
  await start($)
  for (const m of [{ text: 'none' }, 'unanswered', 'throw'] as Model[]) {
    w.model = m
    await say($, DESIGN)
  }
  expect(w.asks).toHaveLength(3)
  expect(seen.every(c => c === undefined)).toBe(true)
})

test('IR5c: a call that never settles passes after RERANK_MS', async (
  $, on,
) => {
  const { w, seen } = await bootRecall($, on)
  w.model = 'hang'
  await start($)
  const p = say($, DESIGN)
  await w.clock.advance(RERANK_MS)
  await p
  expect(w.asks).toHaveLength(1)
  expect(seen).toEqual([undefined])
})

test('IR6: compact starts a new context, resume does not', async ($, on) => {
  const { w, seen } = await bootRecall($, on)
  await start($)
  await say($, GO)
  await start($, 'compact')
  await say($, GO)
  expect(w.asks).toHaveLength(2)
  expect(seen).toEqual([[BLOCK1], [BLOCK1]])
  await start($, 'resume')
  await say($, NOTES)
  expect(w.asks).toHaveLength(2)
})

test('IR7: BLK-001 is injected once, later asks never list it', async (
  $, on,
) => {
  const { w, seen } = await bootRecall($, on)
  await start($)
  for (let i = 0; i < 3; i++) await say($, DESIGN)
  expect(w.asks).toHaveLength(3)
  expect(w.asks[1]?.prompt).not.toContain('BLK-001')
  expect(w.asks[2]?.prompt).not.toContain('BLK-001')
  expect(seen).toEqual([[BLOCK1], undefined, undefined])
})

test('IR8: every candidate already seen means no ask at all', async (
  $, on,
) => {
  const { w } = await bootRecall($, on, { files: { [BLK]: BLK1 } })
  await start($)
  await say($, DESIGN)
  await say($, DESIGN)
  expect(w.asks).toHaveLength(1)
})

test('IR9: "recall": false asks nothing, the note still attaches', async (
  $, on,
) => {
  const { w, seen } = await bootRecall($, on,
    { switchText: '{"enabled": true, "recall": false}' })
  await start($)
  await run($, w, 'git commit -m "fix: y"')
  await say($, DESIGN)
  expect(w.asks).toEqual([])
  expect(seen[0]).toHaveLength(1)
  expect(seen[0]?.[0]).toContain('memory: commit fix: y')
})

test('IR9b: a non-boolean "recall" logs one line, recall stays on', async (
  $, on,
) => {
  const { w, seen } = await bootRecall($, on,
    { switchText: '{"recall": "no"}' })
  await start($)
  await say($, GO)
  expect(seen).toEqual([[BLOCK1]])
  expect(w.logs).toEqual([
    'memory: ~/.claude/memory.json has no boolean "recall", recall stays on',
  ])
})

for (const proc of ['throw', 'exit2'] as const) {
  test(`IR10: status reader ${proc}: no ask, prompt unchanged`, async (
    $, on,
  ) => {
    const { w, seen } = await bootRecall($, on)
    w.proc = proc
    await start($)
    await say($, GO)
    expect(w.asks).toEqual([])
    expect(seen).toEqual([undefined])
  })
}

test('IR11: an injection leaves one log record; 205 keep 200', async (
  $, on,
) => {
  const { w } = await bootRecall($, on)
  await start($)
  await say($, GO)
  expect(await loadLog(storeApi(w), ROOT)).toMatchObject([
    { at: 1000, session: 's1', agent: 'main', channel: 'prompt',
      ids: ['BLK-001'], trigger: 'fresh', outcome: 'injected' },
  ])
  for (let i = 0; i < 204; i++) {
    await start($, 'clear')
    await say($, GO)
  }
  expect(await loadLog(storeApi(w), ROOT)).toHaveLength(200)
})

test('IR12: a pending milestone and a trigger give [note, block]', async (
  $, on,
) => {
  const { w, seen } = await bootRecall($, on)
  await start($)
  await run($, w, 'git commit -m "fix: y"')
  await say($, GO)
  expect(seen).toHaveLength(1)
  expect(seen[0]?.[0]).toContain('memory: commit fix: y')
  expect(seen[0]?.[1]).toBe(BLOCK1)
})

test('registries load once per prompt for the note and the recall', async (
  $, on,
) => {
  const { w } = await bootRecall($, on)
  await start($)
  await run($, w, 'git commit -m "fix: y"')
  const before = w.runs.length
  await say($, GO)
  expect(w.runs.length - before).toBe(1)
})

test('RP1: 3 failed reranks in a row pause it 15 min, a success resets',
  async ($, on) => {
    const { w } = await bootRecall($, on)
    w.model = 'unanswered'
    await start($)
    for (let i = 0; i < 4; i++) await say($, DESIGN)
    expect(w.asks).toHaveLength(3)
    await w.clock.advance(900000)
    await say($, DESIGN)
    expect(w.asks).toHaveLength(4)
  })

test('RP2: a success between failures keeps the pause away', async (
  $, on,
) => {
  const { w } = await bootRecall($, on)
  await start($)
  for (const m of ['unanswered', 'unanswered', { text: 'none' },
    'unanswered', 'unanswered', 'unanswered'] as Model[]) {
    w.model = m
    await say($, DESIGN)
  }
  expect(w.asks).toHaveLength(6)
  await say($, DESIGN)
  expect(w.asks).toHaveLength(6)
})

test('RP3: timeouts and throws count like failures', async ($, on) => {
  const { w } = await bootRecall($, on)
  await start($)
  w.model = 'throw'
  await say($, DESIGN)
  await say($, DESIGN)
  w.model = 'hang'
  const p = say($, DESIGN)
  await w.clock.advance(RERANK_MS)
  await p
  await say($, DESIGN)
  expect(w.asks).toHaveLength(3)
})

test('TIMErules: both rules on 64 KiB of letters, under 50 ms', () => {
  const text = 'a'.repeat(65536)
  const t0 = now()
  expect(DESIGN_RULE.test(text)).toBe(false)
  expect(ANALYSIS_RULE.test(text)).toBe(false)
  expect(isTrigger(text, false, 0)).toBe(false)
  expect(now() - t0).toBeLessThan(50)
})

test('isTrigger: rules, fresh, idle, slash and length', () => {
  const SUITE = 'on va concevoir la suite du mod memory'
  const long = 'please review this module and the new tests'
  expect(isTrigger(long, false, 0)).toBe(true)
  expect(isTrigger(SUITE, false, 0)).toBe(false)
  expect(isTrigger(SUITE, true, 0)).toBe(true)
  expect(isTrigger(SUITE, false, IDLE_MS)).toBe(true)
  expect(isTrigger('/feat design the thing', true, IDLE_MS)).toBe(false)
  expect(isTrigger('design note', true, 0)).toBe(false)
  expect(isTrigger('un-design-ed thing here', false, 0)).toBe(false)
  expect(HAIKU).toBe('claude-haiku-5-5')
})

test('isTrigger: fewer than five content words never triggers', () => {
  expect(MIN_CONTENT_WORDS).toBe(5)
  // 2-letter function words (finding I1) are no content
  for (const vague of ['ok tu peux continuer la suite stp',
    'ok je valide, on passe à la suite', 'is it ok to do it now']) {
    expect(isTrigger(vague, true, 0)).toBe(false)
    expect(isTrigger(vague, false, IDLE_MS)).toBe(false)
  }
  const topical = 'why does the recall rerank pick stale memory entries'
  expect(isTrigger(topical, false, 0)).toBe(true)
  expect(isTrigger('oui ça me convient', true, 0)).toBe(false)
  expect(isTrigger('non pas de changement go', false, IDLE_MS)).toBe(false)
  expect(isTrigger('i approve all for all', false, IDLE_MS)).toBe(false)
  expect(isTrigger('design the mod suite please', false, 0)).toBe(false)
  expect(isTrigger('la spec me convient, écris le plan maintenant stp',
    true, 0)).toBe(true)
})

/**
 * The few calls promptContext makes, over the world: the test's own `$` has
 * no session.root, and a hook's `$` is refused outside its module.
 */
const fakeApi = (w: World): Api => ({
  session: { root: async () => w.root, id: async () => w.id },
  clock: { now: async () => w.clock.now(),
    sleep: () => new Promise<void>(() => undefined) },
  env: { get: async () => w.home },
  fs: {
    stat: async (p: string) => {
      const text = w.files.get(p)
      if (text === undefined) throw new Error('ENOENT')
      return { kind: 'file', size: text?.length ?? 0 }
    },
    read: async (p: string) => w.files.get(p) ?? '',
    exists: async (p: string) => w.files.has(p),
  },
  process: { run: async () => ({ exitCode: 0,
    stdout: (w.proc as { stdout: string }).stdout }) },
  model: { complete: async (a: Ask) => {
    w.asks.push(a)
    return { isAnswered: true, text: (w.model as { text: string }).text }
  } },
  store: storeApi(w).store,
  ui: { log: () => undefined },
}) as unknown as Api

/** A state past the switch read, so promptContext skips the tool setup. */
const switchedOn = () => Object.assign(newState(), {
  enabled: true, recall: true })

/** A recall entry whose line is 381 characters: 90 title, 280 lesson. */
const longEntry = (n: number) => {
  const field = 'alpha '.repeat(50).slice(0, 279) + '.'
  return entryText(`BLK-00${n}`, 't'.repeat(89) + n, 'Solution', field)
}

test('SP1: an ordinary prompt resets the main key spent budget', async (
  $, on,
) => {
  const ids = ['BLK-001', 'BLK-002', 'BLK-003']
  const w = await boot($, on, { files: {
    [BLK]: [1, 2, 3].map(longEntry).join('\n') } })
  const api = () => fakeApi(w)
  w.proc = { stdout: rowsOut(ids.map(id =>
    [id, 't'.repeat(89) + id.slice(-1)])) }
  w.model = { text: ids.join(', ') }
  const st = switchedOn()
  const e = (text: string) => ({ text, origin: { kind: 'composer' } })
  onContextStart(st, 's1')
  const [block] = await promptContext(api(), st,
    e('design alpha now, whole team'))
  expect(block?.length).toBe(1160) // 14 header + 3 x (381 line + 1)
  expect(st.spent.get('s1:main')).toBe(1160)
  expect(await promptContext(api(), st, e('nothing special at all')))
    .toEqual([])
  expect(st.spent.has('s1:main')).toBe(false)
  // a 400-char line fits after the reset; 1160 + 400 > 1500 would not
  expect(claim(st, 's1:main', ['KNOWN-1'], [400])).toEqual(['KNOWN-1'])
})

test('SP2: a prompt without a known last prompt is not idle', async (
  $, on,
) => {
  const w = await boot($, on, { files: REC_FILES })
  w.proc = { stdout: REC_INDEX }
  const api = () => fakeApi(w)
  const st = switchedOn()
  const e = { text: NOTES, origin: { kind: 'composer' } }
  expect(await promptContext(api(), st, e)).toEqual([])
  expect(w.asks).toEqual([])
  expect(st.lastPrompt.get('s1')).toBe(1000)
})

test('CL4: a missing cost refuses the id, it is not free', () => {
  const st = newState()
  expect(claim(st, 'k', ['A-1', 'B-2'], [10])).toEqual(['A-1'])
  expect(st.seen.get('k')?.has('B-2')).toBe(false)
})

test('LG5: two appends fired together keep both records', async (
  $, on,
) => {
  const w = await boot($, on)
  const st = newState()
  const api = storeApi(w)
  await Promise.all([
    appendLog(api, st, ROOT, REC(1)),
    appendLog(api, st, ROOT, REC(2)),
  ])
  expect((w.kv.get(`l:${ROOT}`) as LogRecord[]).map(r => r.at))
    .toEqual([1, 2])
})

// ---- known-error line on failing commands ------------------------------

const KN_SPAN = 'fatal: unable to access remote host'
const KN_ENTRY = entryText('BLK-002', 'remote access', 'Solution',
  'Check the VPN first.') + `seen: \`${KN_SPAN}\`\n`
const KN_LINE = 'memory: known BLK-002 remote access — ' +
  'Check the VPN first.'

/** A world whose BLK-002 is open and matches KN_SPAN. */
async function bootKnown($: Engine, on: On, o: Opts = {}) {
  const w = await boot($, on, { files: { [BLK]: KN_ENTRY }, ...o })
  w.proc = { stdout: rowsOut([['BLK-002', 'remote access']]) }
  return w
}

const asAgent = ($: Engine, command = 'make') =>
  $.tool.call({ tool: 'Bash', command, agentId: 'a1' } as never)

test('TE1: a known failure gains the context line, keeps its shape',
  async ($, on) => {
    const w = await bootKnown($, on)
    const out = await failing($, w, EXIT1 + KN_SPAN)
    expect(out).toEqual({ ...(w.answer as object), context: [KN_LINE] })
  })

test('TE2: an ENOENT line adds no context key', async ($, on) => {
  const text = ER_ENTRY +
    'seen: `cat: x: No such file or directory (os error 2)`\n'
  const w = await boot($, on, { files: { [LRN]: text } })
  w.proc = { stdout: '| LRN-009 | 2026-01-01 | e | open |' }
  const out = await failing($, w,
    EXIT1 + "ls: cannot access '/tmp/zz': No such file or directory")
  expect(out).toEqual(w.answer)
  expect('context' in (out as object)).toBe(false)
})

test('TE3: a sub-agent and the main loop each get the line', async (
  $, on,
) => {
  const w = await bootKnown($, on)
  failWith(w, EXIT1 + KN_SPAN)
  const sub = await asAgent($)
  expect((sub as { context?: string[] }).context).toEqual([KN_LINE])
  const main = await bash($, 'make')
  expect((main as { context?: string[] }).context).toEqual([KN_LINE])
  const again = await asAgent($)
  expect('context' in (again as object)).toBe(false)
})

test('TE4: the same failure 20 times in one context injects once',
  async ($, on) => {
    const w = await bootKnown($, on)
    failWith(w, EXIT1 + KN_SPAN)
    let injected = 0
    for (let i = 0; i < 20; i++) {
      const out = await bash($, 'make') as { context?: string[] }
      if (out.context !== undefined) injected++
    }
    expect(injected).toBe(1)
  })

test('TE7: the status reader runs only for a candidate', async (
  $, on,
) => {
  const w = await bootKnown($, on)
  const known = w.runs.length
  await failing($, w, EXIT1 + 'fatal: nothing alike zebra quartz')
  expect(w.runs.length).toBe(known)
  await failing($, w, EXIT1 + KN_SPAN)
  expect(w.runs.length - known).toBe(1)
})

test('TE7b: a live successor sharing the span of a dead entry wins', async (
  $, on,
) => {
  const older = entryText('BLK-001', 'old remote access', 'Solution',
    'Old fix.') + `seen: \`${KN_SPAN}\`\n`
  const w = await bootKnown($, on, { files: { [BLK]: older + KN_ENTRY } })
  w.proc = { stdout: [
    '| BLK-001 | 2026-01-01 | old remote access | superseded |',
    '| BLK-002 | 2026-02-01 | remote access | open |'].join('\n') }
  const out = await failing($, w, EXIT1 + KN_SPAN)
  expect(out).toEqual({ ...(w.answer as object), context: [KN_LINE] })
})

test('TE4b: two concurrent failing calls inject one line', async (
  $, on,
) => {
  const w = await bootKnown($, on)
  failWith(w, EXIT1 + KN_SPAN)
  const outs = await Promise.all([bash($, 'make'), bash($, 'make')]) as
    { context?: string[] }[]
  expect(outs.filter(o => o.context !== undefined)).toHaveLength(1)
  expect(await loadLog(storeApi(w), ROOT)).toHaveLength(1)
})

test('TE5: "recall": false adds no line, the capture is stored',
  async ($, on) => {
    const w = await bootKnown($, on, {
      switchText: '{"enabled": true, "recall": false}' })
    const out = await failing($, w, EXIT1 + KN_SPAN)
    expect(out).toEqual(w.answer)
    expect(failuresOf(w)).toHaveLength(1)
  })

test('TE6: a superseded entry injects nothing', async ($, on) => {
  const w = await bootKnown($, on)
  w.proc = { stdout: [
    '| BLK-002 | 2026-01-01 | remote access | superseded |'].join('\n') }
  const out = await failing($, w, EXIT1 + KN_SPAN)
  expect(out).toEqual(w.answer)
})

test('TE6b: an unavailable status reader injects nothing', async (
  $, on,
) => {
  const w = await bootKnown($, on)
  w.proc = 'exit2'
  const out = await failing($, w, EXIT1 + KN_SPAN)
  expect(out).toEqual(w.answer)
})

test('TE7c: at 1448 chars spent, a 200-char line is refused', async (
  $, on,
) => {
  // four lines of 362 chars (57 title + 280 lesson) = 1448 spent
  const names = ['alpha', 'bravo', 'charlie', 'delta', 'echo']
  const spanOf = (n: string) => `fatal: ${n} cluster is down`
  const body = (i: number, title: number, lesson: number) => entryText(
    `BLK-01${i}`, 't'.repeat(title - 1) + i, 'Solution',
    'l'.repeat(lesson - 1) + '.') + `seen: \`${spanOf(names[i] ?? '')}\`\n`
  const texts = [0, 1, 2, 3].map(i => body(i, 57, 280))
  texts.push(body(4, 50, 125)) // 14 + 8 + 50 + 3 + 125 = 200
  const rows = texts.map((_t, i): [string, string] =>
    [`BLK-01${i}`, 't'.repeat(i === 4 ? 49 : 56) + i])
  const w = await boot($, on, { files: { [BLK]: texts.join('\n') } })
  w.proc = { stdout: rowsOut(rows) }
  for (let i = 0; i < 4; i++) {
    const out = await failing($, w, EXIT1 + spanOf(names[i] ?? '')) as
      { context?: string[] }
    expect(out.context?.[0]?.length).toBe(362)
  }
  const last = await failing($, w, EXIT1 + spanOf('echo'))
  expect(last).toEqual(w.answer)
})

test('TE8: a failing known-line step returns the answer unchanged',
  async ($, on) => {
    const w = await bootKnown($, on)
    w.proc = 'throw'
    const out = await failing($, w, EXIT1 + KN_SPAN)
    expect(out).toEqual(w.answer)
    expect(failuresOf(w)).toHaveLength(1)
  })

test('TE9: a recall of ~1160 chars, an ordinary prompt, then a ~395 known ' +
  'line is injected', async ($, on) => {
  const span = 'fatal: alpha cluster is down'
  const known = entryText('BLK-004', 't'.repeat(89) + '4', 'Solution',
    'alpha '.repeat(50).slice(0, 279) + '.') + `seen: \`${span}\`\n`
  const { w, seen } = await bootNotes($, on, { files: { [BLK]:
    [...[1, 2, 3].map(longEntry), known].join('\n') } })
  w.proc = { stdout: rowsOut([1, 2, 3, 4].map((n): [string, string] =>
    [`BLK-00${n}`, 't'.repeat(89) + n])) }
  w.model = { text: 'BLK-001, BLK-002, BLK-003' }
  await start($)
  await say($, 'design alpha now, whole team')
  expect(seen[0]?.[0]?.length).toBe(1160) // 14 + 3 x (381 + 1)
  await say($, 'nothing special at all')
  const out = await failing($, w, EXIT1 + span) as { context?: string[] }
  // 1160 + 395 > 1500: only the per-prompt reset lets it through
  expect(out.context?.[0]?.length).toBe(395)
})

test('RB8: a first pick the budget refuses leaves spent equal to the block',
  async ($, on) => {
    const w = await boot($, on, { files: { [BLK]: [
      longEntry(1),
      entryText('BLK-002', 'beta', 'Solution', 'alpha b.'),
    ].join('\n') } })
    w.proc = { stdout: rowsOut([
      ['BLK-001', 't'.repeat(89) + '1'], ['BLK-002', 'beta']]) }
    w.model = { text: 'BLK-001, BLK-002' }
    const st = switchedOn()
    // another caller spends 1150 while the rerank is in flight
    const api = Object.assign(fakeApi(w), { model: { complete: async () => {
      claim(st, 's1:main', ['X'], [1150])
      return { isAnswered: true, text: 'BLK-001, BLK-002' }
    } } }) as unknown as Api
    onContextStart(st, 's1')
    const [block] = await promptContext(api,
      st, { text: 'design alpha now, whole team',
        origin: { kind: 'composer' } })
    expect(block).toBe('memory recall:\nBLK-002 beta — alpha b.')
    expect(st.spent.get('s1:main')).toBe(1150 + (block?.length ?? 0))
    expect(st.seen.get('s1:main')?.has('BLK-001')).toBe(false)
  })

test('PC1: a throwing note still lets the recall attach', async ($, on) => {
  const { w, seen } = await bootRecall($, on)
  await start($)
  await run($, w, 'git commit -m "fix: y"')
  w.getsFail = true
  await say($, GO)
  expect(seen[0]).toEqual([BLOCK1])
})

test('PC2: a throwing recall still lets the note attach', async ($, on) => {
  const w = await boot($, on, { files: REC_FILES })
  w.proc = { stdout: REC_INDEX }
  const st = switchedOn()
  st.pending = ['commit fix: y']
  const api = Object.assign(fakeApi(w), { model: { complete: async () => ({
    get isAnswered(): boolean { throw new Error('boom') },
  }) } }) as unknown as Api
  const added = await promptContext(api, st, { text: GO,
    origin: { kind: 'composer' } })
  expect(added).toHaveLength(1)
  expect(added[0]).toContain('memory: commit fix: y')
  expect(w.logs.filter(l => l.includes('prompt.submit'))).toEqual([])
})

// ---- store sweep before the save, one retry on a rejected set ----------

const ENGINE_BYTES = 4194304
const fill = (n: number) => 'x'.repeat(n - 2) // n serialized bytes

test('SW1: a full store and a new session: swept first, the save lands',
  async ($, on) => {
    const w = await boot($, on, {
      storeCap: ENGINE_BYTES,
      seed: { 'l:/a': fill(1400000), 'l:/b': fill(1400000),
        'l:/c': fill(1394240) },
    })
    await failing($, w, EXIT1 + 'fatal: bad thing')
    expect(failuresOf(w)).toHaveLength(1)
    expect(w.kv.has('l:/a')).toBe(false)
    expect(w.rejected).toBe(0)
  })

test('SW2: a rejected set sweeps and retries once, the retry lands',
  async ($, on) => {
    const w = await boot($, on, { rejectSets: 1 })
    await failing($, w, EXIT1 + 'fatal: bad thing')
    expect(w.rejected).toBe(1)
    expect(failuresOf(w)).toHaveLength(1)
  })

test('SW3: a set rejected twice is not retried a third time', async (
  $, on,
) => {
  const w = await boot($, on, { rejectSets: 5 })
  const out = await failing($, w, EXIT1 + 'fatal: bad thing')
  expect(out).toEqual(w.answer)
  expect(w.rejected).toBe(2)
})

test('SW4: a rejected log set retries once and lands', async ($, on) => {
  const { w } = await bootRecall($, on, { rejectSets: 1 })
  await start($)
  await say($, GO)
  expect(w.rejected).toBe(1)
  expect(await askLog(w)).toEqual([['fresh', 'injected', ['BLK-001']]])
})

// ---- a foreign repository gets no recall and no known line -------------

test('FR1: gitflow.protect false: no known line, capture still works',
  async ($, on) => {
    const w = await bootKnown($, on, { gitProtect: 'false' })
    const out = await failing($, w, EXIT1 + KN_SPAN)
    expect(out).toEqual(w.answer)
    expect(failuresOf(w)).toHaveLength(1)
    expect(w.gitRuns[0]).toEqual(
      ['git', '-C', ROOT, 'config', '--get', 'gitflow.protect'])
  })

test('FR2: gitflow.protect false: no recall, memory_pending answers',
  async ($, on) => {
    const { w, seen } = await bootRecall($, on, { gitProtect: 'false' })
    await start($)
    await run($, w, 'git commit -m "fix: y"')
    await say($, GO)
    expect(seen[0]?.some(c => c.startsWith('memory recall:')) ?? false)
      .toBe(false)
    expect(w.asks).toHaveLength(0)
    expect(await pending($)).toContain('fix: y')
  })

const protectCases: [string, Opts][] = [
  ['true', { gitProtect: 'true' }], ['absent', {}],
]
for (const [name, opts] of protectCases) {
  test(`FR3: gitflow.protect ${name}: known line unchanged`, async ($, on) => {
    const w = await bootKnown($, on, opts)
    const out = await failing($, w, EXIT1 + KN_SPAN)
    expect(out).toEqual({ ...(w.answer as object), context: [KN_LINE] })
  })

  test(`FR3: gitflow.protect ${name}: recall unchanged`, async ($, on) => {
    const { seen } = await bootRecall($, on, opts)
    await start($)
    await say($, GO)
    expect(seen[0]?.[0]).toBe(BLOCK1)
  })
}

test('FR4: the protect read happens once per root and session', async (
  $, on,
) => {
  const w = await bootKnown($, on, { gitProtect: 'true' })
  await failing($, w, EXIT1 + KN_SPAN)
  await failing($, w, EXIT1 + 'fatal: other zebra quartz', 'make b')
  expect(w.gitRuns).toHaveLength(1)
})
