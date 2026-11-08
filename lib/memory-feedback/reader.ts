#!/usr/bin/env bun
// lib/memory-feedback/reader.ts: phase 4d reader. `worksheet <dir>` joins
// the unlabelled injection-log records to their transcripts; `apply <dir>`
// validates the labeller's draft, appends labels.tsv and regenerates
// FEEDBACK.md; `sample <dir>` picks entries for the spot check. Redacted
// text only ever lands in <dir>, the session scratchpad.
import { spawnSync } from 'node:child_process'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import {
  LOG_PREFIX, MAX_LOG, isLogRecord, redact, type LogRecord,
} from '../../mods/memory/hooks/register.ts'
import {
  appendRows, keyOf, parseDraft, readRows, readState, rowsOf, skeleton,
  tagOf, writeSafe, writeState, type Draft, type Item, type Row,
  type State,
} from './labels.ts'
import {
  clockStart, gateVerdict, metricsOf, renderFeedback, type Verdict,
} from './metrics.ts'
import {
  joinPrompt, joinTool, records, sessionFiles, type Loaded,
} from './transcripts.ts'

export type Paths = { store: string; projects: string; out: string }
export type Logged = { root: string; rec: LogRecord }
type Base = Omit<Item, 'cited' | 'lost'>
type Joined = { item: Item; text: string }
type Load = (l: Logged) => Loaded
type Loader = { load: Load; torn: () => number }

const AGE_FLOOR_MS = 1800000 // a younger record may still be mid-turn
const PROMPT_MAX = 600
const REPLY_MAX = 800
const DRAFT_HELP = [
  'Fill the 3rd column of labels-draft.tsv: `relevant` or `irrelevant`.',
  'A whole proof item: `<item> - test`. A miss: `<item> <id> missed',
  '<cause>` with cause `no-overlap` or `overlap`; a searched ask with no',
  'miss: `<item> - checked`. Lines are TAB separated.',
].join('\n')

export function defaultPaths(): Paths {
  const c = path.join(os.homedir(), '.claude')
  return { store: path.join(c, 'plugins', 'store'),
    projects: path.join(c, 'projects'),
    out: path.join(c, 'memory-feedback') }
}

/** The newest memory store file; throws when there is none. */
export function storeFile(dir: string): string {
  const files = fs.existsSync(dir) ? fs.readdirSync(dir)
    .filter(f => f.startsWith('memory_skills-dir-') && f.endsWith('.json'))
    .map(f => path.join(dir, f)) : []
  if (files.length === 0) throw new Error(`no memory store file in ${dir}`)
  const mtime = (f: string) => fs.statSync(f).mtimeMs
  return files.sort((a, b) => mtime(b) - mtime(a))[0] as string
}

function readStore(file: string): object {
  let data: unknown
  try {
    data = JSON.parse(fs.readFileSync(file, 'utf8'))
  } catch {
    throw new Error(`store file unreadable (${file}): retry in a moment`)
  }
  if (typeof data !== 'object' || data === null) {
    throw new Error(`store file is not an object: ${file}`)
  }
  return data
}

/** Every valid log record of every root, oldest first. */
export function readLogs(file: string): Logged[] {
  return Object.entries(readStore(file))
    .filter(([k, v]) => k.startsWith(LOG_PREFIX) && Array.isArray(v))
    .flatMap(([k, v]) => (v as unknown[]).filter(isLogRecord)
      .map(rec => ({ root: k.slice(LOG_PREFIX.length), rec })))
    .sort((a, b) => a.rec.at - b.rec.at)
}

/** Unlabelled records from the clock start, AGE_FLOOR_MS old or more. */
export function population(
  logs: Logged[], done: Set<string>, start: number | undefined,
  now: number,
): Logged[] {
  if (start === undefined) return []
  return logs.filter(l => l.rec.at >= start &&
    l.rec.at <= now - AGE_FLOOR_MS && !done.has(keyOf(l.rec)))
}

/** Roots at the log cap whose oldest record is newer than the last run. */
function evictions(logs: Logged[], lastRun: number): string[] {
  if (lastRun === 0) return []
  const roots = [...new Set(logs.map(l => l.root))]
  return roots.filter(root => {
    const mine = logs.filter(l => l.root === root)
    return mine.length >= MAX_LOG && (mine[0]?.rec.at ?? 0) > lastRun
  }).map(tagOf)
}

const clip = (s: string, n: number) => {
  const r = redact(s) // redact first: a secret straddling the cut escapes
  return r.length <= n ? r : `${r.slice(0, n)}…`
}
const citedIn = (ids: string[], text: string) =>
  ids.filter(id => new RegExp(`\\b${id}\\b`).test(text))

/** An item header; the absolute repo path is for STEP 4 (scratchpad
 * only: labels.tsv keeps the tag). */
function header(b: Base, repo: string, lost: boolean): string {
  const ids = b.ids.join(' ') || '-'
  return `## Item ${b.n}: ${b.channel}/${b.trigger}/${b.outcome}` +
    ` · cands ${b.cands ?? '-'} · ms ${b.ms ?? '-'}` +
    ` · s:${b.session.slice(0, 8)}` +
    ` · ${new Date(b.at).toISOString().slice(11, 16)} UTC` +
    ` · ${b.root} (${repo})` +
    ` · ids ${ids}${lost ? ' · LOST (no transcript turn)' : ''}`
}

const lostItem = (b: Base, repo: string): Joined =>
  ({ item: { ...b, cited: [], lost: true }, text: header(b, repo, true) })

function promptItem(
  b: Base, repo: string, l: Loaded, rec: LogRecord,
): Joined {
  const j = joinPrompt(l.recs, rec)
  if (j === undefined) return lostItem(b, repo)
  const cited = citedIn(b.ids, j.reply)
  const text = [header(b, repo, false),
    `Prompt: ${clip(j.prompt, PROMPT_MAX)}`,
    `Injected:\n${redact(j.injected) || '-'}`,
    `Reply: ${clip(j.reply, REPLY_MAX)}`,
    `Cited: ${cited.join(', ') || 'none'}`].join('\n\n')
  return { item: { ...b, cited, lost: false }, text }
}

function toolItem(
  b: Base, repo: string, l: Loaded, rec: LogRecord,
): Joined {
  const j = joinTool(l.recs, rec)
  if (j === undefined) return lostItem(b, repo)
  const next = j.next.map(f => f ? 'failed' : 'ok').join(', ') || 'none'
  const text = [header(b, repo, false),
    `Command: ${clip(j.command, PROMPT_MAX)}`,
    `Known: ${redact(j.known)}`, `Next Bash results: ${next}`]
    .join('\n\n')
  return { item: { ...b, cited: [], lost: false }, text }
}

/** A per-run transcript loader: each file read once (R8); a record
 * reads its main thread or its own sub-agent file only; torn lines
 * summed once per file. */
function loaderFor(projects: string): Loader {
  const files = new Map<string, Loaded>()
  const read = (f: string) => {
    const got = files.get(f) ?? records(f)
    files.set(f, got)
    return got
  }
  const load = (l: Logged): Loaded => {
    const r = l.rec
    const fs_ = sessionFiles(projects, l.root, r.session, r.agent)
    return { torn: 0, recs: fs_.flatMap(f => read(f).recs) }
  }
  const torn = () => [...files.values()].reduce((t, x) => t + x.torn, 0)
  return { load, torn }
}

/** One worksheet item and its redacted text. */
function joinOne(l: Logged, n: number, load: Load): Joined {
  const r = l.rec
  const b: Base = { n, root: tagOf(l.root), session: r.session, at: r.at,
    channel: r.channel, trigger: r.trigger ?? '', outcome: r.outcome ?? '',
    cands: r.cands, ms: r.ms, ids: r.ids }
  const loaded = load(l)
  return r.channel === 'prompt'
    ? promptItem(b, l.root, loaded, r) : toolItem(b, l.root, loaded, r)
}

const labelsOf = (p: Paths) => path.join(p.out, 'labels.tsv')
const stateOf = (p: Paths) => path.join(p.out, 'state.json')

/** The worksheet's first lines: counts, torn lines, possible evictions. */
function sheetHead(n: number, torn: number, evicted: string[]): string {
  const lines = [n === 0
    ? 'No unlabelled record since the gate clock start.'
    : `${n} records to label.`]
  if (torn > 0) lines.push(`Skipped ${torn} torn transcript lines.`)
  if (evicted.length > 0) {
    lines.push(`Possible eviction before labelling: ${evicted.join(', ')}`)
  }
  return lines.join('\n')
}

const logAtsOf = (logs: Logged[]) =>
  logs.filter(l => l.rec.cands !== undefined).map(l => l.rec.at)

/** Joins the unlabelled population to its transcripts. */
function collect(p: Paths, now: number) {
  const rows = readRows(labelsOf(p))
  const logs = readLogs(storeFile(p.store))
  const pop = population(logs, new Set(rows.map(keyOf)),
    clockStart(rows, logAtsOf(logs)), now)
  const loader = loaderFor(p.projects)
  const joined = pop.map((l, i) => joinOne(l, i + 1, loader.load))
  return { joined, head: sheetHead(pop.length, loader.torn(),
    evictions(logs, readState(stateOf(p)).lastRun)) }
}

function writeSheet(dir: string, joined: Joined[], head: string): void {
  writeSafe(path.join(dir, 'worksheet.md'), ['# Memory feedback worksheet',
    head, DRAFT_HELP, ...joined.map(j => j.text)].join('\n\n') + '\n')
  const items = joined.map(j => j.item)
  writeSafe(path.join(dir, 'items.json'), JSON.stringify(items))
  writeSafe(path.join(dir, 'labels-draft.tsv'), skeleton(items))
}

/** Writes worksheet.md, items.json, labels-draft.tsv (0600); the count. */
export function worksheet(dir: string, p: Paths, now: number): number {
  const { joined, head } = collect(p, now)
  writeSheet(dir, joined, head)
  return joined.length
}

const draftOf = (dir: string) => {
  const f = path.join(dir, 'labels-draft.tsv')
  return fs.existsSync(f) ? fs.readFileSync(f, 'utf8') : ''
}

/** The state after this run, and a NEW line per gate first reached. */
function nextState(st: State, v: Verdict, now: number) {
  const news: string[] = []
  let { promptAt, toolAt } = st
  if (promptAt === undefined && v.prompt === 'reached') {
    promptAt = now
    news.push('NEW: prompt gate reached')
  }
  const toolDone = v.tool === 'reached' || v.tool === 'insufficient'
  if (toolAt === undefined && toolDone) {
    toolAt = now
    news.push(`NEW: tool gate ${v.tool}`)
  }
  const closed = promptAt !== undefined && toolAt !== undefined
  return { state: { lastRun: now, promptAt, toolAt, closed }, news }
}

const assertFresh = (items: Item[], old: Row[]) => {
  const done = new Set(old.map(keyOf))
  if (items.some(i => done.has(keyOf(i)))) {
    throw new Error('items already applied: run worksheet again')
  }
}

/** The new rows, and the metrics and verdict once they are added. */
function projected(
  items: Item[], drafts: Draft[], old: Row[], now: number,
) {
  const fresh = items.flatMap(i => rowsOf(i, drafts))
  const m = metricsOf([...old, ...fresh])
  return { fresh, m, v: gateVerdict(m, now) }
}

/** Appends labels, then writes state, then FEEDBACK.md. */
function commit(
  p: Paths, items: Item[], drafts: Draft[], now: number,
): string {
  const old = readRows(labelsOf(p))
  assertFresh(items, old)
  const { fresh, m, v } = projected(items, drafts, old, now)
  const next = nextState(readState(stateOf(p)), v, now)
  const feedback = renderFeedback(m, v, now)
  if (fresh.length > 0) appendRows(labelsOf(p), fresh)
  writeState(stateOf(p), next.state)
  writeSafe(path.join(p.out, 'FEEDBACK.md'), feedback)
  return feedback + next.news.map(n => n + '\n').join('')
}

/** Validates the draft; appends labels, writes state, then FEEDBACK.md
 * (a failed state write leaves the NEW line to print on the next run). */
export function apply(dir: string, p: Paths, now: number): string {
  const items: Item[] = JSON.parse(
    fs.readFileSync(path.join(dir, 'items.json'), 'utf8'))
  const drafts = parseDraft(draftOf(dir), items)
  if (typeof drafts === 'string') throw new Error(`draft refused: ${drafts}`)
  return commit(p, items, drafts, now)
}

/** Up to `n` entry lines of the draft, picked at random. */
export function sample(dir: string, n: number): string[] {
  const lines = draftOf(dir).split('\n')
    .filter(l => /\t(relevant|irrelevant)$/.test(l))
  for (let i = lines.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[lines[i], lines[j]] = [lines[j] as string, lines[i] as string]
  }
  return lines.slice(0, n)
}

/** '' for a usable dir; else why not (text must never reach a repo). */
export function checkDir(dir: string | undefined): string {
  if (dir === undefined || !path.isAbsolute(dir)) return 'not absolute'
  if (!fs.existsSync(dir)) return 'does not exist'
  const git = spawnSync('git', ['-C', dir, 'rev-parse',
    '--is-inside-work-tree'], { encoding: 'utf8' })
  if (git.error !== undefined || typeof git.stdout !== 'string') {
    return 'git unavailable'
  }
  return git.stdout.trim() === 'true' ? 'inside a git work tree' : ''
}

function run(cmd: string, dir: string): void {
  const p = defaultPaths()
  if (cmd === 'worksheet') {
    const n = worksheet(dir, p, Date.now())
    console.log(`${n} records to label: ${dir}/worksheet.md`)
  } else if (cmd === 'apply') {
    process.stdout.write(apply(dir, p, Date.now()))
  } else console.log(sample(dir, 5).join('\n'))
}

function main(argv: string[]): number {
  const [cmd, dir] = argv
  const why = checkDir(dir)
  if (!['worksheet', 'apply', 'sample'].includes(cmd ?? '') || why !== '') {
    console.error('usage: reader.ts worksheet|apply|sample <dir> ' +
      `(absolute, outside any git work tree)${why ? `: ${why}` : ''}`)
    return 2
  }
  try {
    run(cmd as string, dir as string)
    return 0
  } catch (e) {
    console.error(`memory-feedback: ${(e as Error).message}`)
    return 1
  }
}

if (import.meta.main) process.exit(main(process.argv.slice(2)))
