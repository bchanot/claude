// lib/memory-feedback/metrics.ts: phase 4d metrics, gate verdicts and the
// FEEDBACK.md text, computed from labels.tsv rows only (transcripts expire
// at 7 days, the rows stay). Spec §4.
import {
  DAY_MS, GATE_DAYS, PROMPT_GATE_N, T, TOOL_GATE_N,
} from './thresholds.ts'
import { keyOf, type Row } from './labels.ts'

export type Gate = 'open' | 'reached'
export type ToolGate = Gate | 'extended' | 'insufficient'
export type Verdict = { prompt: Gate; tool: ToolGate }
type Rate = number | undefined
export type Metrics = {
  start?: number; promptN: number; toolN: number; lost: number
  precision: Rate; byTrigger: Record<string, Rate>; thirdPick: Rate
  late: Rate; msP90: Rate; tool: Rate; missShare: Rate; sampled: number
  noisy: string[]; promote: string[]
}

const share = (k: number, n: number): Rate => n === 0 ? undefined : k / n
const isEntry = (r: Row) =>
  r.label === 'relevant' || r.label === 'irrelevant'
const under = (v: Rate, t: number) => v !== undefined && v < t
const pct = (v: Rate) => v === undefined ? 'n/a' : `${Math.round(v * 100)} %`
const day = (ms: number) => new Date(ms).toISOString().slice(0, 10)
const entryKey = (r: Row) => `${r.root} ${r.id}`

/** The gate clock start: the first labelled row with cands, else the
 * first log record with cands (one rule for reader and metrics). */
export function clockStart(rows: Row[], logAts: number[]): Rate {
  const labelled = rows.filter(r => r.cands !== undefined).map(r => r.at)
  const ats = labelled.length > 0 ? labelled : logAts
  return ats.length === 0 ? undefined : Math.min(...ats)
}

/** Rows of items with no `test` row (LRN-241). */
function liveRows(rows: Row[]): Row[] {
  const test = new Set(rows.filter(r => r.label === 'test').map(keyOf))
  return rows.filter(r => !test.has(keyOf(r)))
}

/** relevant / (relevant + irrelevant); undefined with no entry. */
export function precision(rows: Row[]): Rate {
  const e = rows.filter(isEntry)
  return share(e.filter(r => r.label === 'relevant').length, e.length)
}

/** The 90th percentile, nearest rank; undefined with no value. */
export function p90(values: number[]): Rate {
  if (values.length === 0) return undefined
  const s = [...values].sort((a, b) => a - b)
  return s[Math.ceil(0.9 * s.length) - 1]
}

function byTrigger(entries: Row[]): Record<string, Rate> {
  const out: Record<string, Rate> = {}
  for (const k of ['fresh', 'idle', 'keyword']) {
    out[k] = precision(entries.filter(r => r.trigger === k))
  }
  return out
}

/** timeout + paused among asks (lost ones too) that had candidates. */
function lateShare(asks: Row[]): Rate {
  const had = asks.filter(r => (r.cands ?? 0) > 0)
  const late = had.filter(r =>
    r.outcome === 'timeout' || r.outcome === 'paused')
  return share(late.length, had.length)
}

/** Share of sampled asks (a missed or checked row) with a miss. */
function misses(rows: Row[]): { rate: Rate; sampled: number } {
  const sampled = new Set(rows
    .filter(r => r.label === 'missed' || r.label === 'checked').map(keyOf))
  const missed = new Set(rows.filter(r => r.label === 'missed').map(keyOf))
  return { rate: share(missed.size, sampled.size), sampled: sampled.size }
}

/** `<repo tag> <ID>` injected noisyHits times or more, never relevant. */
function noisy(entries: Row[]): string[] {
  return [...new Set(entries.map(entryKey))].filter(k => {
    const mine = entries.filter(r => entryKey(r) === k)
    return mine.length >= T.noisyHits &&
      mine.every(r => r.label !== 'relevant')
  }).sort()
}

/** `<repo tag> <ID>` relevant promoteHits times in promoteSessions. */
function promote(entries: Row[]): string[] {
  const rel = entries.filter(r => r.label === 'relevant')
  return [...new Set(rel.map(entryKey))].filter(k => {
    const mine = rel.filter(r => entryKey(r) === k)
    return mine.length >= T.promoteHits &&
      new Set(mine.map(r => r.session)).size >= T.promoteSessions
  }).sort()
}

/** Distinct labelled items of a channel. */
const itemsOf = (entries: Row[], ch: string) =>
  new Set(entries.filter(r => r.channel === ch).map(keyOf)).size

/** Every 4d signal, from labels.tsv rows. */
export function metricsOf(all: Row[]): Metrics {
  const rows = liveRows(all)
  const entries = rows.filter(isEntry)
  const prompt = entries.filter(r => r.channel === 'prompt')
  const asks = rows.filter(r => r.channel === 'prompt' &&
    (r.label === 'ask' || r.label === 'lost'))
  const miss = misses(rows)
  return {
    start: clockStart(all, []),
    promptN: itemsOf(entries, 'prompt'), toolN: itemsOf(entries, 'tool'),
    lost: rows.filter(r => r.label === 'lost').length,
    precision: precision(prompt), byTrigger: byTrigger(prompt),
    thirdPick: precision(prompt.filter(r => r.pick === 3)),
    late: lateShare(asks), msP90: p90(asks.flatMap(r => r.ms ?? [])),
    tool: precision(entries.filter(r => r.channel === 'tool')),
    missShare: miss.rate, sampled: miss.sampled,
    noisy: noisy(entries), promote: promote(entries),
  }
}

/** The tool gate by count, else by time: one extension, then closed. */
function toolGate(n: number, now: number, cap: number): ToolGate {
  if (n >= TOOL_GATE_N) return 'reached'
  if (now < cap) return 'open'
  return now < cap + GATE_DAYS * DAY_MS ? 'extended' : 'insufficient'
}

/** Each channel's gate; the prompt gate never waits for the tool gate. */
export function gateVerdict(m: Metrics, now: number): Verdict {
  if (m.start === undefined) return { prompt: 'open', tool: 'open' }
  const cap = m.start + GATE_DAYS * DAY_MS
  const prompt: Gate =
    m.promptN >= PROMPT_GATE_N || now >= cap ? 'reached' : 'open'
  return { prompt, tool: toolGate(m.toolN, now, cap) }
}

/** The worst trigger under the floor; ties go idle, keyword, fresh. */
function worstTrigger(by: Record<string, Rate>): string | undefined {
  const low = ['idle', 'keyword', 'fresh']
    .filter(k => under(by[k], T.triggerFloor))
  low.sort((a, b) => (by[a] ?? 0) - (by[b] ?? 0))
  return low[0]
}

function promptActions(m: Metrics): string[] {
  const out: string[] = []
  const worst = worstTrigger(m.byTrigger)
  if (under(m.precision, T.promptKeep) && worst !== undefined) {
    out.push(`prompt precision under ${pct(T.promptKeep)}: ` +
      `tighten or drop the ${worst} trigger`)
  }
  if (under(m.thirdPick, T.thirdPick)) {
    out.push(`3rd pick under ${pct(T.thirdPick)}: cap recall at 2 entries`)
  }
  if ((m.late ?? 0) > T.lateShare) {
    out.push(`timeout + paused over ${pct(T.lateShare)}: ` +
      'revisit RERANK_MS or skip the rerank on short lists')
  }
  if (under(m.msP90, T.msP90)) {
    out.push(`rerank p90 under ${T.msP90} ms: lower RERANK_MS`)
  }
  if ((m.missShare ?? 0) >= T.missShare) {
    out.push('misses in 1 ask in 3 or more: diagnose by cause')
  }
  return out
}

/** The threshold actions, once at least one gate is reached. */
export function actionsOf(m: Metrics, v: Verdict): string[] {
  if (v.prompt !== 'reached' && v.tool !== 'reached') return []
  const out = v.prompt === 'reached' ? promptActions(m) : []
  if (v.tool === 'reached' && under(m.tool, T.toolKeep)) {
    out.push(`tool precision under ${pct(T.toolKeep)}: ` +
      'require 2 matched 4-grams, or exclude the entry')
  }
  out.push(...m.noisy.map(k => `noisy: /prune-memory rewrites ${k}`))
  out.push(...m.promote.map(k => `promotion candidate (BDR-100): ${k}`))
  return out
}

function toolLine(m: Metrics, v: Verdict): string {
  return v.tool === 'insufficient'
    ? `Tool gate: insufficient sample n=${m.toolN}, closed`
    : `Tool gate: ${v.tool} (${m.toolN}/${TOOL_GATE_N})`
}

/** FEEDBACK.md: counts and shares; repo tags only in the last lists. */
export function renderFeedback(m: Metrics, v: Verdict, now: number) {
  const acts = actionsOf(m, v)
  return [
    `# Memory feedback (${day(now)})`, '',
    `Gate clock start: ${m.start === undefined ? 'not started' : day(m.start)}`,
    `Prompt gate: ${v.prompt} (${m.promptN}/${PROMPT_GATE_N})`,
    toolLine(m, v), `Lost records: ${m.lost}`, '',
    '| Signal | Value |', '|---|---|',
    `| prompt precision | ${pct(m.precision)} |`,
    ...Object.entries(m.byTrigger).map(([k, x]) =>
      `| precision, ${k} | ${pct(x)} |`),
    `| 3rd pick precision | ${pct(m.thirdPick)} |`,
    `| timeout + paused | ${pct(m.late)} |`,
    `| rerank ms p90 | ${m.msP90 ?? 'n/a'} |`,
    `| tool precision | ${pct(m.tool)} |`,
    `| asks with a miss | ${pct(m.missShare)} of ${m.sampled} |`, '',
    `Noisy: ${m.noisy.join(', ') || 'none'}`,
    `Promotion candidates: ${m.promote.join(', ') || 'none'}`, '',
    'Actions:', ...(acts.length ? acts.map(a => `- ${a}`) : ['- none']),
  ].join('\n') + '\n'
}
