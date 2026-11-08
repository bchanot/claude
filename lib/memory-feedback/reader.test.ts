import { afterAll, expect, test } from 'bun:test'
import { spawnSync } from 'node:child_process'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
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
const T0 = Date.parse('2026-11-10T10:00:00.000Z')
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
    { cited: ['BDR-999'] }, { at: -1 }, { lost: 'no' }]) {
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
