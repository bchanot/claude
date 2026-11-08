import { expect, test } from 'bun:test'
import { DAY_MS, GATE_DAYS } from './thresholds.ts'
import {
  actionsOf, clockStart, gateVerdict, metricsOf, p90, precision,
  renderFeedback, type Metrics,
} from './metrics.ts'
import type { Label, Row } from './labels.ts'

let clock = 1000
/** A labels.tsv row; each call gets its own `at` unless given. */
function row(over: Partial<Row> & { label: Label }): Row {
  clock += 1
  return { at: clock, root: 'r#000000', session: 's1', channel: 'prompt',
    trigger: 'fresh', outcome: 'injected', cands: 3, ms: 900,
    id: 'BDR-001', cause: '', ...over }
}
/** One injected ask with entries labelled `labels`, picks 1..n. */
function ask(labels: Label[], over: Partial<Row> = {}): Row[] {
  const at = (clock += 10)
  const head = row({ ...over, at, id: '', label: 'ask' })
  return [head, ...labels.map((label, i) => row({ ...over, at, label,
    id: `LRN-00${i + 1}`, pick: i + 1 }))]
}

test('M1: precision, p90 and the clock start rule', () => {
  const r = ask(['relevant', 'irrelevant', 'relevant', 'relevant'])
  expect(precision(r)).toBe(0.75)
  expect(precision([])).toBeUndefined()
  expect(p90([5, 1, 9, 3, 7, 2, 8, 4, 6, 10])).toBe(9)
  expect(p90([])).toBeUndefined()
  expect(clockStart(r, [1])).toBe(r[0]?.at)
  expect(clockStart([], [7, 3])).toBe(3)
  expect(clockStart([], [])).toBeUndefined()
})

test('M2: a `- test` row excludes its whole item', () => {
  const t = ask(['irrelevant'])
  const rows = [...ask(['relevant']), ...t,
    row({ at: t[0]!.at, id: '', label: 'test' })]
  const m = metricsOf(rows)
  expect(m.precision).toBe(1)
  expect(m.promptN).toBe(1)
})

test('M3: noisy and promotion keyed by repo and ID', () => {
  const noisy = [1, 2, 3].flatMap(() => ask(['irrelevant']))
  expect(metricsOf(noisy).noisy).toEqual(['r#000000 LRN-001'])
  expect(metricsOf(noisy.slice(0, 4)).noisy).toEqual([])
  const split = [...noisy.slice(0, 4), ...ask(['irrelevant'],
    { root: 'other#111111' })]
  expect(metricsOf(split).noisy).toEqual([])
  const one = [1, 2, 3].flatMap(() => ask(['relevant']))
  expect(metricsOf(one).promote).toEqual([])
  const two = [...one, ...ask(['relevant'], { session: 's2' })]
  expect(metricsOf(two).promote).toEqual(['r#000000 LRN-001'])
})

test('M4: late share counts asks with candidates, lost ones too', () => {
  const rows = [
    row({ id: '', label: 'ask', outcome: 'timeout' }),
    row({ id: '', label: 'lost', outcome: 'paused' }),
    row({ id: '', label: 'ask', outcome: 'none', cands: 0 }),
    ...ask(['relevant']),
  ]
  expect(metricsOf(rows).late).toBeCloseTo(2 / 3)
  expect(metricsOf(rows).lost).toBe(1)
})

/** Metrics with `n` prompt asks and `t` tool injections, clock at 0. */
function m(n: number, t: number): Metrics {
  const p = Array.from({ length: n }, () => ask(['relevant'])).flat()
  const tl = Array.from({ length: t }, () => ask(['relevant'],
    { channel: 'tool', trigger: 'tool', cands: undefined })).flat()
  return { ...metricsOf([...p, ...tl]), start: 0 }
}
const CAP = GATE_DAYS * DAY_MS

test('M5: the prompt gate at 20 asks or at the cap', () => {
  expect(gateVerdict(m(19, 0), 1).prompt).toBe('open')
  expect(gateVerdict(m(20, 0), 1).prompt).toBe('reached')
  expect(gateVerdict(m(3, 0), CAP).prompt).toBe('reached')
  const none = { ...metricsOf([]), start: undefined }
  expect(gateVerdict(none, CAP * 9))
    .toEqual({ prompt: 'open', tool: 'open' })
})

test('M6: the tool gate extends once by time, then closes', () => {
  expect(gateVerdict(m(0, 10), 1).tool).toBe('reached')
  expect(gateVerdict(m(0, 9), CAP - 1).tool).toBe('open')
  expect(gateVerdict(m(0, 9), CAP).tool).toBe('extended')
  expect(gateVerdict(m(0, 9), 2 * CAP - 1).tool).toBe('extended')
  expect(gateVerdict(m(0, 9), 2 * CAP).tool).toBe('insufficient')
})

test('M7: actions only once a gate is reached', () => {
  const idle = Array.from({ length: 20 }, (_, i) =>
    ask([i % 3 === 0 ? 'relevant' : 'irrelevant'], { trigger: 'idle' }))
    .flat() // 7/20 relevant: under 64 % overall and under 50 % for idle
  const mm = { ...metricsOf(idle), start: 0 }
  expect(actionsOf(mm, gateVerdict(mm, 1)))
    .toContain('prompt precision under 64 %: tighten or drop the idle trigger')
  const open = { ...mm, promptN: 2 }
  expect(actionsOf(open, gateVerdict(open, 1))).toEqual([])
})

test('M8: rerank latency action', () => {
  const slow = Array.from({ length: 20 }, () =>
    ask(['relevant'], { ms: 2400 })).flat()
  const mm = { ...metricsOf(slow), start: 0 }
  expect(actionsOf(mm, gateVerdict(mm, 1)))
    .toContain('rerank p90 under 2500 ms: lower RERANK_MS')
})

test('M9: FEEDBACK.md counts, no repo tag without a noisy entry', () => {
  const rows = ask(['relevant'], { root: 'client#abcdef' })
  const mm = metricsOf(rows)
  const text = renderFeedback(mm, gateVerdict(mm, 1), 0)
  expect(text).not.toContain('client#abcdef')
  expect(text).toContain('Prompt gate: open (1/20)')
})

test('M10: FEEDBACK.md shows n per channel and trigger', () => {
  const rows = [...ask(['relevant', 'irrelevant']),
    ...ask(['irrelevant'], { trigger: 'idle' })]
  const mm = metricsOf(rows)
  const text = renderFeedback(mm, gateVerdict(mm, 1), 0)
  expect(text).toContain('| precision, idle | 0 % (n=1) |')
  expect(text).toContain('| precision, fresh | 50 % (n=2) |')
  expect(text).toContain('| prompt precision | 33 % (n=3) |')
  expect(text).toContain('| tool precision | n/a (n=0) |')
})
