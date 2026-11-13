import { expect, test } from 'bun:test'
import { DAY_MS, GATE1_FIX_AT, GATE_DAYS } from './thresholds.ts'
import {
  actionsOf, clockStart, gateVerdict, metricsOf, p90, precision,
  renderFeedback, type Metrics,
} from './metrics.ts'
import type { Label, Row } from './labels.ts'

let clock = GATE1_FIX_AT + 1000 // every default row is post-fix
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

const shift = (rs: Row[], at: number) => rs.map(r => ({ ...r, at }))
const PRE = Date.parse('2026-11-12T15:00:00Z')

test('M11: the fix instant splits prompt precision, not noisy', () => {
  const old = shift(ask(['irrelevant', 'irrelevant', 'irrelevant']), PRE)
  const mm = metricsOf([...old, ...ask(['relevant'])])
  expect(mm.precision).toBe(1)
  expect(mm.n.prompt).toBe(1)
  expect(mm.preFix).toBe(3)
  expect(mm.promptN).toBe(2) // the gate count reads every row
  const thrice = [1, 2, 3].flatMap(() => shift(ask(['irrelevant']), PRE))
  expect(metricsOf(thrice).noisy).toEqual(['r#000000 LRN-001'])
  const edge = [...shift(ask(['irrelevant']), GATE1_FIX_AT - 1),
    ...shift(ask(['relevant']), GATE1_FIX_AT)]
  expect(metricsOf(edge).precision).toBe(1)
  expect(metricsOf(edge).n.prompt).toBe(1)
})

test('M12: the miss share reads post-fix asks only', () => {
  const miss = (at: number) => [row({ at, id: '', label: 'ask' }),
    row({ at, id: 'BDR-009', label: 'missed', cause: 'overlap' })]
  const mm = metricsOf([...miss(GATE1_FIX_AT - 1), ...miss(GATE1_FIX_AT)])
  expect(mm.sampled).toBe(1)
  expect(mm.missShare).toBe(1)
})

/** Metrics whose every gate is reached, with `over` on top. */
const reached = (over: Partial<Metrics>): Metrics => ({
  ...metricsOf([]), start: 0, promptN: 20, toolN: 10, postAsks: 20, ...over,
})
const acts = (over: Partial<Metrics>) => {
  const mm = reached(over)
  return actionsOf(mm, gateVerdict(mm, 1))
}
const sized = (i: number, k: number, f: number) => ({
  idle: { rate: i, n: 5 }, keyword: { rate: k, n: 5 },
  fresh: { rate: f, n: 5 },
})

test('M13: each comparator at its threshold and one step past', () => {
  const has = (over: Partial<Metrics>, part: string) =>
    acts(over).some(a => a.includes(part))
  expect(has({ late: 0.25 }, 'timeout + paused')).toBe(false)
  expect(has({ late: 0.26 }, 'timeout + paused')).toBe(true)
  expect(has({ msP90: 2500 }, 'rerank p90')).toBe(false)
  expect(has({ msP90: 2499 }, 'rerank p90')).toBe(true)
  expect(has({ tool: 0.5 }, 'tool precision')).toBe(false)
  expect(has({ tool: 0.49 }, 'tool precision')).toBe(true)
  expect(has({ missShare: 1 / 3 }, 'misses in 1 ask')).toBe(true)
  expect(has({ missShare: 0.33 }, 'misses in 1 ask')).toBe(false)
  const by = sized(0.4, 0.9, 0.9)
  expect(has({ precision: 0.64, byTrigger: by }, 'prompt precision'))
    .toBe(false)
  expect(has({ precision: 0.63, byTrigger: by }, 'prompt precision'))
    .toBe(true)
  const low = (r: number) => sized(r, 0.9, 0.9)
  expect(has({ precision: 0.5, byTrigger: low(0.5) }, 'prompt precision'))
    .toBe(false)
  expect(has({ precision: 0.5, byTrigger: low(0.49) }, 'prompt precision'))
    .toBe(true)
})

test('M14: the worst trigger ties go idle, keyword, fresh', () => {
  const pick = (by: ReturnType<typeof sized>) => acts({ precision: 0.3,
    byTrigger: by }).find(a => a.startsWith('prompt precision'))
  expect(pick(sized(0.25, 0.25, 0.25))).toContain('the idle trigger')
  expect(pick(sized(0.9, 0.25, 0.25))).toContain('the keyword trigger')
  expect(pick(sized(0.25, 0.2, 0.9))).toContain('the keyword trigger')
  expect(pick(sized(0.9, 0.9, 0.1))).toContain('the fresh trigger')
})

test('M15: promotion needs 3 hits in 2 sessions, noisy 3 never hit', () => {
  const rel = (s: string) => ask(['relevant'], { session: s })
  expect(metricsOf([...rel('a'), ...rel('a'), ...rel('b')]).promote)
    .toEqual(['r#000000 LRN-001'])
  expect(metricsOf([...rel('a'), ...rel('b')]).promote).toEqual([])
  const irr = () => ask(['irrelevant'])
  expect(metricsOf([...irr(), ...irr(), ...irr()]).noisy).toHaveLength(1)
  expect(metricsOf([...irr(), ...irr()]).noisy).toEqual([])
})

test('M16: the post-fix floor gates the prompt actions, 19 vs 20', () => {
  const idle = (n: number) => Array.from({ length: n }, () =>
    ask(['irrelevant'], { trigger: 'idle' })).flat()
  const run = (n: number) => {
    const mm = { ...metricsOf(idle(n)), start: 0, promptN: 20 }
    return actionsOf(mm, gateVerdict(mm, 1))
  }
  expect(run(19).some(a => a.startsWith('prompt precision'))).toBe(false)
  expect(run(20).some(a => a.startsWith('prompt precision'))).toBe(true)
  const text = renderFeedback(metricsOf(idle(19)), gateVerdict(
    metricsOf(idle(19)), 1), 0)
  expect(text).toContain('Post-fix prompt asks: 19/20 (since ' +
    '2026-11-12T19:53:59.000Z), pre-fix entries excluded: 0')
})

test('M17: below the floor the miss action waits, late and p90 fire', () => {
  const asks = Array.from({ length: 19 }, () =>
    ask(['irrelevant'], { trigger: 'idle', ms: 2000 })).flat()
  const miss = row({ id: 'BDR-009', label: 'missed', cause: 'overlap',
    at: asks[0]!.at })
  const late = Array.from({ length: 8 }, () =>
    row({ id: '', label: 'ask', outcome: 'timeout' }))
  const mm = { ...metricsOf([...asks, miss, ...late]), start: 0, promptN: 20 }
  expect(mm.missShare).toBeGreaterThanOrEqual(1 / 3)
  const out = actionsOf(mm, gateVerdict(mm, 1))
  expect(out.some(a => a.startsWith('misses in 1 ask'))).toBe(false)
  expect(out.some(a => a.startsWith('timeout + paused'))).toBe(true)
  expect(out.some(a => a.startsWith('rerank p90'))).toBe(true)
})

test('M18: an ask with 2 entries counts once toward the floor', () => {
  const two = Array.from({ length: 19 }, () =>
    ask(['relevant', 'relevant'])).flat()
  expect(metricsOf(two).postAsks).toBe(19)
  expect(metricsOf([...two, ...ask(['relevant'])]).postAsks).toBe(20)
})

test('M19: a pre-fix row still counts toward promote', () => {
  const old = (s: string) => shift(ask(['relevant'], { session: s }), PRE)
  expect(metricsOf([...old('a'), ...old('a'), ...old('b')]).promote)
    .toEqual(['r#000000 LRN-001'])
})
