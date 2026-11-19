// lib/memory-feedback/advisor.ts: advisor usage read from Claude Code
// transcripts (Run C, LRN-295): served calls and input tokens per caller
// and model, deduped by message.id, for the FEEDBACK.md section.
import * as fs from 'node:fs'
import * as path from 'node:path'

export type Use = {
  caller: string; model: string; calls: number; input: number
}
export type Tally = { uses: Use[]; unparsed: number; files: number }
export type Source = { file: string; caller: string }
type Obj = Record<string, unknown>
type Acc = { seen: Set<string>; uses: Map<string, Use>; unparsed: number }

export const MAIN = 'main loop'
export const UNKNOWN_AGENT = 'sub-agent (unknown)'
export const RETENTION_DAYS = 7

const DAY_MS = 86400000
const META_MAX = 65536
const MARK = 'advisor_message'
const AGENT_RE = /^[A-Za-z0-9_.:-]{1,64}$/
const MODEL_RE = /^[A-Za-z0-9._:-]{1,80}$/
const UNAVAILABLE = 'Unavailable: transcripts unreadable.'

const day = (ms: number) => new Date(ms).toISOString().slice(0, 10)
const since = (from: number) => from === 0 ? 'all on disk' : day(from)
const heading = (from: number, to: number) =>
  `## Advisor usage (${since(from)} → ${day(to)})`
const obj = (v: unknown): Obj | undefined =>
  typeof v === 'object' && v !== null && !Array.isArray(v)
    ? v as Obj : undefined

function lstatOf(p: string): fs.Stats | undefined {
  try {
    return fs.lstatSync(p)
  } catch {
    return undefined
  }
}

/** Directory entries; [] when unreadable or gone, never throws. */
function listDir(dir: string): string[] {
  try {
    return fs.readdirSync(dir)
  } catch {
    return []
  }
}

const isRealDir = (p: string) => lstatOf(p)?.isDirectory() === true

/** Regular `<prefix>*.jsonl` files of `dir` newer than `from`. */
function jsonlIn(
  dir: string, prefix: string, from: number, callerOf: (f: string) => string,
): Source[] {
  return listDir(dir)
    .filter(n => n.startsWith(prefix) && n.endsWith('.jsonl'))
    .map(n => path.join(dir, n))
    .flatMap(file => {
      const st = lstatOf(file)
      return st?.isFile() && st.mtimeMs > from
        ? [{ file, caller: callerOf(file) }] : []
    })
}

/** Every transcript under `projects` modified after `from`, with its
 * caller: main threads and `<session>/subagents/agent-*.jsonl`. */
export function transcriptsOf(projects: string, from: number): Source[] {
  return listDir(projects).map(n => path.join(projects, n))
    .filter(isRealDir).flatMap(proj => {
      const subs = listDir(proj).map(n => path.join(proj, n))
        .filter(isRealDir).map(s => path.join(s, 'subagents'))
        .filter(isRealDir)
      return [...jsonlIn(proj, '', from, () => MAIN),
        ...subs.flatMap(s => jsonlIn(s, 'agent-', from, callerOf))]
    })
}

/** The agent type of a sub-agent transcript, from its sibling meta file;
 * UNKNOWN_AGENT for anything missing, odd or oversized. */
export function callerOf(jsonl: string): string {
  const meta = jsonl.replace(/\.jsonl$/, '') + '.meta.json'
  const st = lstatOf(meta)
  if (!st?.isFile() || st.size > META_MAX) return UNKNOWN_AGENT
  try {
    const type = obj(JSON.parse(fs.readFileSync(meta, 'utf8')))?.agentType
    return typeof type === 'string' && AGENT_RE.test(type)
      ? type : UNKNOWN_AGENT
  } catch {
    return UNKNOWN_AGENT
  }
}

/** The assistant messages of a file that mention advisor_message and
 * fall in (from, to]; [] for an unreadable file. */
function windowed(file: string, from: number, to: number): Obj[] {
  let text: string
  try {
    text = fs.readFileSync(file, 'utf8')
  } catch {
    return []
  }
  return text.split('\n').filter(l => l.includes(MARK)).flatMap(line => {
    try {
      const rec = obj(JSON.parse(line))
      const at = Date.parse(String(rec?.timestamp))
      const msg = obj(rec?.message)
      return rec?.type === 'assistant' && msg !== undefined &&
        at > from && at <= to ? [msg] : []
    } catch {
      return []
    }
  })
}

function bump(uses: Map<string, Use>, caller: string, it: Obj): void {
  const model = typeof it.model === 'string' && MODEL_RE.test(it.model)
    ? it.model : 'unknown'
  const key = `${caller}\t${model}`
  const use = uses.get(key) ?? { caller, model, calls: 0, input: 0 }
  use.calls += 1
  use.input += Number.isSafeInteger(it.input_tokens) &&
    (it.input_tokens as number) >= 0 ? it.input_tokens as number : 0
  uses.set(key, use)
}

/** Counts one message once: its served advisor iterations, or a drift. */
function tallyOne(msg: Obj, caller: string, acc: Acc): void {
  const id = msg.id
  if (typeof id !== 'string' || id === '' || acc.seen.has(id)) return
  acc.seen.add(id)
  const its = obj(msg.usage)?.iterations
  const calls = (Array.isArray(its) ? its : []).map(obj)
    .filter((i): i is Obj => i?.type === MARK)
  calls.forEach(it => bump(acc.uses, caller, it))
  if (calls.length === 0 &&
    JSON.stringify(msg.usage ?? null).includes(MARK)) acc.unparsed += 1
}

const byUse = (a: Use, b: Use) =>
  Number(b.caller === MAIN) - Number(a.caller === MAIN) ||
  b.calls - a.calls || a.caller.localeCompare(b.caller) ||
  a.model.localeCompare(b.model)

/** Served advisor calls and input tokens in (from, to], per caller and
 * model, over every transcript under `projects`. */
export function advisorUsage(
  projects: string, from: number, to: number,
): Tally {
  const sources = transcriptsOf(projects, from)
  const acc: Acc = { seen: new Set(), uses: new Map(), unparsed: 0 }
  for (const s of sources) {
    windowed(s.file, from, to).forEach(m => tallyOne(m, s.caller, acc))
  }
  return { uses: [...acc.uses.values()].sort(byUse),
    unparsed: acc.unparsed, files: sources.length }
}

/** 999 → `999`, 1500 → `1.5k`, 2500000 → `2.5M`. */
export function compact(n: number): string {
  if (n < 1000) return String(n)
  return n < 999950 ? `${(n / 1e3).toFixed(1)}k` : `${(n / 1e6).toFixed(1)}M`
}

function table(uses: Use[]): string {
  const sum = (f: (u: Use) => number) => uses.reduce((a, u) => a + f(u), 0)
  const rows = uses.map(u =>
    `| ${u.caller} | ${u.model} | ${u.calls} | ${compact(u.input)} |`)
  return ['| caller | model | calls | input tok |', '|---|---|---|---|',
    ...rows, `| total | | ${sum(u => u.calls)} | ` +
    `${compact(sum(u => u.input))} |`].join('\n')
}

function bodyOf(t: Tally, from: number): string {
  const drift = `${t.unparsed} transcript lines mention ${MARK}, none ` +
    'parsed: check the transcript shape.'
  if (t.uses.length > 0) {
    return t.unparsed > 0 ? `${table(t.uses)}\n\n${drift}` : table(t.uses)
  }
  if (t.files === 0) {
    return `No transcript modified since ${since(from)} under the ` +
      'projects dir: check the path.'
  }
  return t.unparsed > 0 ? drift : 'No advisor call in the window.'
}

/** The `## Advisor usage` markdown section, ending with a newline. */
export function renderAdvisor(t: Tally, from: number, to: number): string {
  const blocks = [heading(from, to)]
  if (from > 0 && to - from > RETENTION_DAYS * DAY_MS) {
    blocks.push(`Transcripts kept ${RETENTION_DAYS} d: calls before ` +
      `${day(to - RETENTION_DAYS * DAY_MS)} may be missing.`)
  }
  blocks.push(bodyOf(t, from))
  return blocks.join('\n\n') + '\n'
}

/** The section for FEEDBACK.md; a fixed Unavailable text on any failure
 * (an error message could carry a path). Never throws. */
export function advisorSection(
  projects: string, from: number, to: number,
): string {
  const f = Number.isFinite(from) && from >= 0 && from <= to ? from : 0
  try {
    return renderAdvisor(advisorUsage(projects, f, to), f, to)
  } catch {
    return `${heading(f, to)}\n\n${UNAVAILABLE}\n`
  }
}
