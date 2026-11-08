import { afterAll, expect, test } from 'bun:test'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import {
  appendRows, fromLine, parseDraft, readRows, readState, rowsOf, skeleton,
  tagOf, toLine, writeState, type Item, type Row,
} from './labels.ts'

const dirs: string[] = []
const tmp = () => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'mf-'))
  dirs.push(d)
  return d
}
afterAll(() => dirs.forEach(d => fs.rmSync(d, { recursive: true })))

const item = (n: number, over: Partial<Item> = {}): Item => ({
  n, root: 'r#000000', session: `s${n}`, at: 1000 + n, channel: 'prompt',
  trigger: 'fresh', outcome: 'injected', cands: 4, ms: 900,
  ids: ['BDR-001', 'LRN-002'], cited: ['BDR-001'], lost: false, ...over,
})
const ITEMS = [item(1), item(2, { ids: [], outcome: 'none' })]
const OK = '1\tBDR-001\trelevant\n1\tLRN-002\tirrelevant'

test('L1: a row survives the TSV round trip', () => {
  const r: Row = { at: 5, root: 'r#000000', session: 's',
    channel: 'tool', trigger: 'tool', outcome: 'injected',
    cands: undefined, ms: undefined, pick: 1, id: 'BLK-003',
    label: 'relevant', cause: '' }
  expect(fromLine(toLine(r))).toEqual(r)
  expect(fromLine('at\troot')).toBeUndefined()
})

test('L2: a complete draft parses', () => {
  const d = parseDraft([OK, '2\tBDR-009\tmissed\tno-overlap',
    '1\t-\tchecked', '# note'].join('\n'), ITEMS)
  expect(Array.isArray(d) && d.length).toBe(4)
})

test('L3: every bad draft is refused with a reason', () => {
  const bad = [
    '1\tBDR-001\tmaybe\n1\tLRN-002\trelevant',      // unknown label
    `${OK}\n9\tBDR-001\trelevant`,                   // unknown item
    `${OK}\n1\tBLK-777\trelevant`,                   // not injected there
    '1\tBDR-001\trelevant',                          // LRN-002 unlabelled
    `${OK}\n1\tBDR-001\trelevant`,                   // labelled twice
    `${OK}\n2\tBDR-001\tmissed\tbad`,                // unknown cause
    `${OK}\n1\tLRN-002\tmissed\toverlap`,            // missed but injected
    '1\tBDR-001\ttest\n1\tLRN-002\trelevant',        // per-id test
    '1\tBDR-001\t\n1\tLRN-002\trelevant',            // blank skeleton label
  ]
  for (const text of bad) {
    expect(typeof parseDraft(text, ITEMS)).toBe('string')
  }
})

test('L4: `- test` marks a whole item, no entry label needed', () => {
  expect(Array.isArray(parseDraft('1\t-\ttest', ITEMS))).toBe(true)
})

test('L5: a lost item takes no label', () => {
  const lost = [item(1, { lost: true })]
  expect(typeof parseDraft('1\tBDR-001\trelevant', lost)).toBe('string')
  expect(parseDraft('', lost)).toEqual([])
})

test('L6: rowsOf writes an ask row then the entry rows', () => {
  const d = parseDraft(OK, [item(1)])
  if (typeof d === 'string') throw new Error(d)
  expect(rowsOf(item(1), d).map(r => [r.label, r.id, r.pick])).toEqual([
    ['ask', '', undefined], ['relevant', 'BDR-001', 1],
    ['irrelevant', 'LRN-002', 2],
  ])
  expect(rowsOf(item(3, { lost: true }), [])[0]?.label).toBe('lost')
})

test('L7: append-only labels, a backup, a loud damaged line', () => {
  const dir = path.join(tmp(), 'mf')
  const file = path.join(dir, 'labels.tsv')
  appendRows(file, rowsOf(item(1), []))
  appendRows(file, rowsOf(item(2), []))
  expect(fs.statSync(dir).mode & 0o777).toBe(0o700)
  expect(fs.statSync(file).mode & 0o777).toBe(0o600)
  expect(readRows(file)).toHaveLength(2)
  expect(readRows(`${file}.bak`)).toHaveLength(1)
  fs.appendFileSync(file, 'broken line\n')
  expect(() => readRows(file)).toThrow('labels.tsv.bak')
})

test('L8: state defaults, round trip, a corrupt file throws', () => {
  const f = path.join(tmp(), 'state.json')
  expect(readState(f)).toEqual({ lastRun: 0, closed: false })
  writeState(f, { lastRun: 9, promptAt: 9, closed: false })
  expect(readState(f)).toEqual({ lastRun: 9, promptAt: 9, closed: false })
  fs.writeFileSync(f, '{oops')
  expect(() => readState(f)).toThrow('state.json')
})

test('L9: repo tags keep same-named repos apart', () => {
  expect(tagOf('/a/x')).toMatch(/^x#[0-9a-f]{6}$/)
  expect(tagOf('/a/x')).toBe(tagOf('/a/x'))
  expect(tagOf('/a/x')).not.toBe(tagOf('/b/x'))
})

test('L10: the skeleton draft lists each injected id once', () => {
  const lines = skeleton([item(1), item(2, { ids: [] }),
    item(3, { lost: true })]).split('\n').filter(l => !l.startsWith('#'))
  expect(lines.filter(l => l !== '')).toEqual(['1\tBDR-001\t', '1\tLRN-002\t'])
})
