import { afterAll, expect, test } from 'bun:test'
import { spawnSync } from 'node:child_process'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import { GATE1_FIX_AT } from './thresholds.ts'
import { tagOf } from './labels.ts'
import { slugOf } from './transcripts.ts'
import {
  apply, checkDir, population, readLogs, safePath, sample, storeFile,
  worksheet,
  type Paths,
} from './reader.ts'

const dirs: string[] = []
afterAll(() => dirs.forEach(d => fs.rmSync(d, { recursive: true })))
const mk = (pfx: string) => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), pfx))
  dirs.push(d)
  return d
}
const T0 = GATE1_FIX_AT + 20 * 3600000 // post-fix: the floor counts it
const NOW = T0 + 2 * 3600000 // every fixture record is 2 h old
const iso = (ms: number) => new Date(T0 + ms).toISOString()
// built at run time: no secret-shaped literal in the repo (BLK-041)
const PLANTED = ['API', 'TOKEN'].join('_') + '=' + 'hunter' + '2value'

/** A fixture home: store, one transcript, an out dir, a work dir. */
function fixture(store: unknown): { p: Paths; work: string } {
  const home = mk('mf-')
  const p = { store: path.join(home, 'store'),
    projects: path.join(home, 'projects'), out: path.join(home, 'mf') }
  fs.mkdirSync(p.store)
  fs.writeFileSync(path.join(p.store, 'memory_skills-dir-abc.json'),
    typeof store === 'string' ? store : JSON.stringify(store))
  const dir = path.join(p.projects, slugOf('/repo/x'))
  fs.mkdirSync(dir, { recursive: true })
  fs.writeFileSync(path.join(dir, 's1.jsonl'), [
    { type: 'user', timestamp: iso(-50), origin: { kind: 'human' },
      message: { content: `design the reader gate with ${PLANTED}` } },
    { type: 'attachment', timestamp: iso(400), attachment: {
      type: 'hook_additional_context', hookName: 'prompt.submit',
      content: ['memory recall:\nBDR-001 x'] } },
    { type: 'assistant', timestamp: iso(900),
      message: { id: 'm', content: [{ type: 'text', text: 'per BDR-001' }] } },
  ].map(r => JSON.stringify(r)).join('\n') + '\n')
  return { p, work: mk('mf-work-') }
}
const REC = (at: number, over = {}) => ({ at, session: 's1', agent: 'main',
  channel: 'prompt', ids: ['BDR-001'], trigger: 'fresh',
  outcome: 'injected', cands: 5, ms: 800, ...over })
const STORE = { 'l:/repo/x': [
  REC(T0 - 9e6, { cands: undefined }), // before 4d.1: out of population
  REC(T0), REC(T0 + 60000, { session: 'gone' }), // the second one lost
], 'p:/repo/x': { sessions: [] } }
const draft = (work: string, text: string) =>
  fs.writeFileSync(path.join(work, 'labels-draft.tsv'), text)

test('R1: no store file, or a torn one, fails loudly', () => {
  const { p } = fixture('{"l:/x": [tor')
  expect(() => readLogs(storeFile(p.store))).toThrow('unreadable')
  expect(() => storeFile(path.join(p.store, 'none'))).toThrow('no memory')
})

test('R2: population from the clock start, unlabelled, 30 min old', () => {
  const { p } = fixture(STORE)
  const logs = readLogs(storeFile(p.store))
  expect(population(logs, new Set(), T0, NOW).map(l => l.rec.at))
    .toEqual([T0, T0 + 60000])
  expect(population(logs, new Set([`s1|${T0}|prompt`]), T0, NOW))
    .toHaveLength(1)
  expect(population(logs, new Set(), T0, T0 + 600000)).toHaveLength(0)
  expect(population(logs, new Set(), undefined, NOW)).toEqual([])
})

test('R3: worksheet: 0600 files, redacted text, a lost item, a skeleton',
  () => {
    const { p, work } = fixture(STORE)
    expect(worksheet(work, p, NOW)).toBe(2)
    const sheet = fs.readFileSync(path.join(work, 'worksheet.md'), 'utf8')
    expect(sheet).toContain('design the reader gate')
    expect(sheet).toContain('(/repo/x)')
    expect(sheet).not.toContain('hunter2value')
    expect(sheet).toContain('LOST')
    for (const f of ['worksheet.md', 'items.json', 'labels-draft.tsv']) {
      expect(fs.statSync(path.join(work, f)).mode & 0o777).toBe(0o600)
    }
    expect(fs.readFileSync(path.join(work, 'labels-draft.tsv'), 'utf8'))
      .toContain('1\tBDR-001\t')
    const items = JSON.parse(fs.readFileSync(
      path.join(work, 'items.json'), 'utf8'))
    expect(items.map((i: { cited: string[]; lost: boolean }) =>
      [i.cited, i.lost])).toEqual([[['BDR-001'], false], [[], true]])
  })

test('R4: a bad draft refuses the whole apply, nothing written', () => {
  const { p, work } = fixture(STORE)
  worksheet(work, p, NOW)
  draft(work, '1\tBDR-001\tmaybe')
  expect(() => apply(work, p, NOW)).toThrow('draft refused')
  expect(fs.existsSync(p.out)).toBe(false)
})

test('R5: apply writes labels, state, FEEDBACK; a second apply refuses',
  () => {
    const { p, work } = fixture(STORE)
    worksheet(work, p, NOW)
    draft(work, '1\tBDR-001\trelevant\n')
    const fb = apply(work, p, NOW)
    expect(fb).toContain('Prompt gate: open (1/20)')
    expect(fb).toContain('Lost records: 1')
    expect(fb).not.toContain('design the reader gate')
    const labels = fs.readFileSync(path.join(p.out, 'labels.tsv'), 'utf8')
    expect(labels).not.toContain('design')
    expect(labels).not.toContain('/repo/x')
    expect(labels).toMatch(/\tx#[0-9a-f]{6}\t/)
    expect(JSON.parse(fs.readFileSync(path.join(p.out, 'state.json'),
      'utf8')).lastRun).toBe(NOW)
    expect(() => apply(work, p, NOW + 1)).toThrow('already applied')
    expect(worksheet(work, p, NOW + 2)).toBe(0)
  })

test('R6: a first run with nothing to label records the run only', () => {
  const { p, work } = fixture({ 'l:/repo/x': [REC(T0, { cands: undefined })] })
  expect(worksheet(work, p, NOW)).toBe(0)
  expect(fs.readFileSync(path.join(work, 'worksheet.md'), 'utf8'))
    .toContain('No unlabelled record')
  expect(apply(work, p, NOW)).toContain('Gate clock start: not started')
  expect(fs.existsSync(path.join(p.out, 'state.json'))).toBe(true)
})

test('R7: a gate verdict is NEW once, then recorded', () => {
  const { p, work } = fixture(STORE)
  const late = T0 + 36 * 86400000 // past the 5-week cap
  worksheet(work, p, late)
  draft(work, '1\tBDR-001\trelevant\n')
  expect(apply(work, p, late)).toContain('NEW: prompt gate reached')
  worksheet(work, p, late + 1)
  draft(work, '')
  const again = apply(work, p, late + 1)
  expect(again).toContain('Prompt gate: reached')
  expect(again).not.toContain('NEW:')
})

test('R8: the CLI refuses a dir inside a git work tree', () => {
  const repo = mk('mf-repo-')
  spawnSync('git', ['-C', repo, 'init', '-q'])
  expect(checkDir(repo)).toContain('git work tree')
  expect(checkDir('relative/dir')).not.toBe('')
  const ok = mk('mf-ok-')
  fs.chmodSync(ok, 0o700)
  expect(checkDir(ok)).toBe('')
  const open = mk('mf-open-')
  fs.chmodSync(open, 0o775)
  expect(checkDir(open)).toContain('writable')
})

test('R10: a tampered items.json is refused, nothing written', () => {
  for (const bad of [{ root: '/repo/x' }, { root: 'a\tb#abcdef' },
    { session: '../s' }, { channel: 'x' }, { ids: ['../x'] },
    { cited: ['BDR-999'] }, { at: -1 }, { at: 1e21 }, { lost: 'no' }]) {
    const { p, work } = fixture(STORE)
    worksheet(work, p, NOW)
    const f = path.join(work, 'items.json')
    const items = JSON.parse(fs.readFileSync(f, 'utf8'))
    fs.writeFileSync(f, JSON.stringify([{ ...items[0], ...bad }, items[1]]))
    draft(work, '1\tBDR-001\trelevant\n')
    expect(() => apply(work, p, NOW)).toThrow('items.json invalid')
    expect(fs.existsSync(p.out)).toBe(false)
  }
})

test('R9: sample picks entry lines of the draft', () => {
  const { p, work } = fixture(STORE)
  worksheet(work, p, NOW)
  draft(work, '1\tBDR-001\trelevant\n1\t-\tchecked\n')
  expect(sample(work, 5)).toEqual(['1\tBDR-001\trelevant'])
})

test('safePath keeps plain paths and withholds shell-active ones', () => {
  const w = 'path withheld: unsafe characters'
  expect(safePath('/home/u/repo.x')).toBe('/home/u/repo.x')
  for (const bad of ['/tmp/$(id)', '/tmp/`id`', "/tmp/a'b", '/a/../b'])
    expect(safePath(bad)).toBe(w)
})

/** The 3 transcript records of the prompt asked at `T0 + ms`. */
const turn = (ms: number, tag: string) => [
  { type: 'user', timestamp: iso(ms - 50), origin: { kind: 'human' },
    message: { content: `prompt-${tag}` } },
  { type: 'attachment', timestamp: iso(ms + 400), attachment: {
    type: 'hook_additional_context', hookName: 'prompt.submit',
    content: ['memory recall:\nBDR-001 x'] } },
  { type: 'assistant', timestamp: iso(ms + 900),
    message: { id: `m${ms}`, content: [{ type: 'text', text: 'ok' }] } },
]
const jsonl = (recs: object[], torn = 0) => recs.map(r => JSON.stringify(r))
  .concat(Array(torn).fill('{"torn')).join('\n') + '\n'
const put = (p: Paths, session: string, text: string) => fs.writeFileSync(
  path.join(p.projects, slugOf('/repo/x'), `${session}.jsonl`), text)
const sheetOf = (work: string) =>
  fs.readFileSync(path.join(work, 'worksheet.md'), 'utf8')

const promptAt = (sheet: string, t: string) =>
  sheet.indexOf(`Prompt: prompt-${t}`)
const itemsOf = (work: string): { n: number }[] => JSON.parse(
  fs.readFileSync(path.join(work, 'items.json'), 'utf8'))

test('R11: A,B,A sessions: each file read once, order kept', () => {
  const { p, work } = fixture({ 'l:/repo/x': [
    REC(T0, { session: 'sA' }), REC(T0 + 60000, { session: 'sB' }),
    REC(T0 + 120000, { session: 'sA' })] })
  put(p, 'sA', jsonl([...turn(0, 'A1'), ...turn(120000, 'A2')], 1))
  put(p, 'sB', jsonl(turn(60000, 'B1')))
  expect(worksheet(work, p, NOW)).toBe(3)
  const sheet = sheetOf(work)
  expect(sheet).toContain('Skipped 1 torn transcript lines.')
  const heads = sheet.split('\n').filter(l => l.startsWith('## Item'))
  expect(heads.map(h => h.slice(0, 9))).toEqual(['## Item 1',
    '## Item 2', '## Item 3'])
  expect(heads.map(h => /s:(s.)/.exec(h)?.[1])).toEqual(['sA', 'sB', 'sA'])
  expect(promptAt(sheet, 'A1')).toBeLessThan(promptAt(sheet, 'B1'))
  expect(promptAt(sheet, 'B1')).toBeLessThan(promptAt(sheet, 'A2'))
  expect(itemsOf(work).map(i => i.n)).toEqual([1, 2, 3])
})

test('R12: torn lines are summed across files', () => {
  const { p, work } = fixture({ 'l:/repo/x': [
    REC(T0, { session: 'sA' }), REC(T0 + 60000, { session: 'sB' })] })
  put(p, 'sA', jsonl(turn(0, 'A'), 1))
  put(p, 'sB', jsonl(turn(60000, 'B'), 2))
  worksheet(work, p, NOW)
  expect(sheetOf(work)).toContain('Skipped 3 torn transcript lines.')
})

test('R13: a root at the log cap, newer than the last run, is noted', () => {
  const full = Array.from({ length: 200 }, (_, i) =>
    REC(T0 + i * 1000, { ids: [], outcome: 'none' }))
  const { p, work } = fixture({ 'l:/repo/x': full })
  fs.mkdirSync(p.out)
  fs.writeFileSync(path.join(p.out, 'state.json'),
    JSON.stringify({ lastRun: T0 - 1, closed: false }))
  worksheet(work, p, NOW)
  expect(sheetOf(work)).toContain(
    `Possible eviction before labelling: ${tagOf('/repo/x')}`)
})

const use = (ms: number, id: string, command: string) => ({
  type: 'assistant', timestamp: iso(ms), message: { id: `a${id}`,
    content: [{ type: 'tool_use', id, name: 'Bash',
      input: { command } }] } })
const result = (ms: number, id: string, err: boolean) => ({
  type: 'user', timestamp: iso(ms), message: { content: [
    { type: 'tool_result', tool_use_id: id, is_error: err }] } })
const toolRec = (at: number, session: string) => REC(at, { session,
  channel: 'tool', ids: ['BLK-003'], trigger: undefined,
  outcome: undefined, cands: 1, ms: undefined })

test('R14: a tool item shows command, known line, next results', () => {
  const { p, work } = fixture({ 'l:/repo/x': [
    toolRec(T0, 'sA'), toolRec(T0 + 60000, 'sB')] })
  put(p, 'sA', jsonl([use(-100, 'u1', 'make test'), result(-50, 'u1', true),
    { type: 'attachment', timestamp: iso(400), attachment: {
      type: 'hook_additional_context', hookName: 'tool.call',
      toolUseID: 'u1-context', content: ['memory: known BLK-003 x'] } },
    use(500, 'u2', 'ls'), result(600, 'u2', false)]))
  expect(worksheet(work, p, NOW)).toBe(2)
  expect(sheetOf(work)).toContain('Command: make test')
  expect(sheetOf(work)).toContain('Known: memory: known BLK-003 x')
  expect(sheetOf(work)).toContain('Next Bash results: ok')
  expect(sheetOf(work)).toContain('LOST') // sB has no transcript
})

test('R15: the post-fix floor is NEW once, state keeps postFixAt', () => {
  const recs = Array.from({ length: 20 }, (_, i) =>
    REC(T0 + i * 1000, { session: `s${i}`, ids: ['BDR-001'] }))
  const { p, work } = fixture({ 'l:/repo/x': recs })
  recs.forEach((r, i) => put(p, r.session, jsonl(turn(i * 1000, 'f'))))
  worksheet(work, p, NOW)
  draft(work, Array.from({ length: 20 }, (_, i) =>
    `${i + 1}\tBDR-001\trelevant`).join('\n'))
  const first = apply(work, p, NOW)
  expect(first).toContain('NEW: post-fix prompt sample reached (20/20 asks)')
  expect(first).toContain('Post-fix prompt asks: 20/20 (since ' +
    '2026-11-12T19:53:59.000Z)')
  const st = JSON.parse(fs.readFileSync(path.join(p.out, 'state.json'),
    'utf8'))
  expect(st.postFixAt).toBe(NOW)
  worksheet(work, p, NOW + 1)
  draft(work, '')
  expect(apply(work, p, NOW + 1)).not.toContain('post-fix prompt sample')
})

/** Applies `n` relevant asks over an old state file: both gate-1 gates
 * recorded, no postFixAt. Returns the state written. */
function closedAfter(n: number, closed = false): { closed: boolean } {
  const recs = Array.from({ length: n }, (_, i) =>
    REC(T0 + i * 1000, { session: `s${i}`, ids: ['BDR-001'] }))
  const { p, work } = fixture({ 'l:/repo/x': recs })
  fs.mkdirSync(p.out)
  fs.writeFileSync(path.join(p.out, 'state.json'), JSON.stringify(
    { lastRun: T0 - 1, promptAt: T0 - 2, toolAt: T0 - 2, closed }))
  recs.forEach((r, i) => put(p, r.session, jsonl(turn(i * 1000, 'f'))))
  worksheet(work, p, NOW)
  draft(work, recs.map((_, i) => `${i + 1}\tBDR-001\trelevant`).join('\n'))
  apply(work, p, NOW)
  return JSON.parse(fs.readFileSync(path.join(p.out, 'state.json'), 'utf8'))
}

test('R16: closed waits for the post-fix floor, old state included', () => {
  expect(closedAfter(19).closed).toBe(false)
  expect(closedAfter(20).closed).toBe(true)
})

test('R17: a legacy closed:true without postFixAt is rewritten open', () => {
  expect(closedAfter(1, true).closed).toBe(false)
})
