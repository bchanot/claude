// memory: captures what fails in a session and offers it to the memory
// registries. This file is the frame: the off switch, the fail-open hooks
// and the per-session state. Every hook reads the session id and root at
// the point of use, never from a cache. A hook that fails passes the event
// through unchanged: the mod may never break a tool call or a prompt.
import type { EngineInterface, On, Register } from 'claude-code'

type Api = EngineInterface

type State = {
  enabled: boolean | null // null: not read yet this session
  recall: boolean | null // the "recall" key, read with `enabled`
  warned: Set<string>
  pending: string[] // milestones not yet shown in a note
  writes: Promise<void> // the one chain every store write runs on
  seen: Map<string, Set<string>> // context key -> injected IDs
  spent: Map<string, number> // context key -> chars injected
  fresh: Set<string> // sessions whose next qualifying prompt starts a context
  lastPrompt: Map<string, number> // session id -> time of its last prompt
  rerank: { fails: number; until: number } // failures in a row, pause end
}

export const IDLE_MS = 1800000
export const RECALL_CAP = 1500
export const HAIKU = 'claude-haiku-5-5'
export const RERANK_MS = 3000

const SWITCH_FILE = '.claude/memory.json'
const MAX_SWITCH_BYTES = 65536
const CONTEXT_STARTS = new Set(['startup', 'clear', 'compact'])
const TOOL = 'memory_pending'
const SERVED_TOOL = 'mcp__memory__memory_pending'
const SWITCH_UNREADABLE =
  'memory: ~/.claude/memory.json unreadable, capture stays on'
const SWITCH_INVALID =
  'memory: ~/.claude/memory.json has no boolean "enabled", capture stays on'

const SWITCH_RECALL_INVALID =
  'memory: ~/.claude/memory.json has no boolean "recall", recall stays on'

const MAX_REGEX_INPUT = 65536
const PEM = '-----'
const PEM_KIND = '(?:[A-Z]+ )?PRIVATE KEY'
// a value: a quoted string up to its closing quote, else up to a space
const VALUE = '("[^"\\n]{0,400}"|\'[^\'\\n]{0,400}\'|\\S+)'
const SECRET_KEY = '(?:password|token|secret|api[_-]?key)'
// the JSON key may hold `-`; the bare pair key may not (a `-` run would
// make every word start rescan 60 characters)
const keyWord = (cls: string) => `${cls}{0,60}${SECRET_KEY}${cls}{0,60}`
const JSON_KEY = keyWord('[A-Za-z0-9_-]')
const PAIR_KEY = keyWord('[A-Za-z0-9_]')

// Redaction patterns, applied in order: the JWT shape first (so a secret
// named variable still ends as `NAME=<redacted>` through pattern 1, and any
// other name keeps `NAME=<redacted:jwt>`), then the name rule, the vendor
// shapes, PEM, Bearer, URL credentials, and last the command-line shapes
// (-u user:pass, --password, Authorization), then the 6-bis shapes: vendor
// prefixes, --token flags, API-key headers, JSON and `key: value` pairs, a
// hex URL user. Repeats are bounded where the input is free text, so no
// pattern can run away on a 64 KiB input.
const REDACTIONS: [RegExp, string][] = [
  [new RegExp(
    '(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{8,}\\.eyJ[A-Za-z0-9_-]{8,}' +
      '\\.[A-Za-z0-9_-]{8,}',
    'g',
  ), '<redacted:jwt>'],
  // before pattern 1: a cookie jar `k=v; token=x` is one value
  [new RegExp(`(?<=^|\\s)--cookie(?:=|[ \\t]{1,5})${VALUE}`, 'g'),
    '--cookie <redacted>'],
  [new RegExp(
    '\\b([A-Za-z0-9_]{0,60}(?:TOKEN|API_KEY|SECRET|PASSWORD|PASSWD)' +
      '[A-Za-z0-9_]{0,60})=' + VALUE,
    'gi',
  ), '$1=<redacted>'],
  [/sk_live_[0-9A-Za-z]{10,}/g, '<redacted:stripe>'],
  [/AKIA[0-9A-Z]{16}/g, '<redacted:aws>'],
  [/gh[pousr]_[A-Za-z0-9]{30,}/g, '<redacted:github>'],
  [/xox[abprs]-[A-Za-z0-9-]{10,}/g, '<redacted:slack>'],
  [/SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}/g, '<redacted:sendgrid>'],
  [/sb_secret_[A-Za-z0-9_-]{10,}/g, '<redacted:supabase>'],
  [new RegExp(
    `${PEM}BEGIN ${PEM_KIND}${PEM}[\\s\\S]*?` +
      `(?:${PEM}END ${PEM_KIND}${PEM}|$)`,
    'g',
  ), '<redacted:private-key>'],
  [/\bBearer\s+[A-Za-z0-9._~+/=-]{8,}/g, 'Bearer <redacted>'],
  [/(?<![a-z0-9+.-])([a-z][a-z0-9+.-]{0,200}:\/\/)[^\s/@:]+:[^\s/@]+@/gi,
    '$1<redacted>@'],
  [/(?<=^|\s)(-u|--user)[ \t]{1,5}\S{1,200}:\S*/g, '$1 <redacted>'],
  [/--password(?:=|[ \t]{1,5})\S*/g, '--password <redacted>'],
  [/Authorization:[ \t]{0,5}(Basic|Bearer|token)[ \t]{1,5}\S*/gi,
    'Authorization: $1 <redacted>'],
  [/sk-ant-[A-Za-z0-9_-]{10,}/g, '<redacted:anthropic>'],
  [/sk-proj-[A-Za-z0-9_-]{10,}/g, '<redacted:openai>'],
  [/github_pat_[A-Za-z0-9_]{10,}/g, '<redacted:github>'],
  [/glpat-[A-Za-z0-9_-]{10,}/g, '<redacted:gitlab>'],
  [/AIza[A-Za-z0-9_-]{20,}/g, '<redacted:google>'],
  [/npm_[A-Za-z0-9]{10,}/g, '<redacted:npm>'],
  [/--(token|api-key|secret)(?:=|[ \t]{1,5})\S*/g, '--$1 <redacted>'],
  [new RegExp(
    '(?<![A-Za-z0-9-])([A-Za-z0-9-]{0,30}api[_-]?key|PRIVATE-TOKEN|' +
      '(?:Set-)?Cookie):[ \\t]{0,5}[^\\n]*',
    'gi',
  ), '$1: <redacted>'],
  [new RegExp(
    `"(${JSON_KEY})"[ \\t]{0,5}:[ \\t]{0,5}"[^"\\n]{0,400}"`,
    'gi',
  ), '"$1": "<redacted>"'],
  // a value already `<redacted…>` (pattern 1) is not marked twice
  [new RegExp(
    `\\b(${PAIR_KEY})` +
      `[ \\t]{0,5}[:=][ \\t]{0,5}(?!<redacted)${VALUE}`,
    'gi',
  ), '$1: <redacted>'],
  [/(?<![a-z0-9+.-])([a-z][a-z0-9+.-]{0,200}:\/\/)[0-9a-f]{40}@/gi,
    '$1<redacted>@'],
]

const QUOTED = /'[^'\n]*'|"[^"\n]*"/g
const SEPARATOR = /[;&|\n]+/g
// before `curl`: ( $( NAME=value  NAME=$(  sudo  rtk
const CURL_SEGMENT = new RegExp(
  '^[ \\t(]{0,5}(?:\\$\\()?(?:[A-Za-z_]\\w{0,60}=' +
    '(?:\\S{0,200}[ \\t]{1,5}|\\$\\()|(?:sudo|rtk)[ \\t]{1,5}){0,10}' +
    'curl\\b',
)
const COOKIE_FLAG = new RegExp(`(?<=^|\\s)-b[ \\t]{1,5}${VALUE}`, 'g')

const HEX_RUN = /\b[0-9a-f]{7,}\b/g
const IO_ERROR = /input\/output error/g
const PATH = /(?:\.{0,2}\/)?[\w.-]{1,200}(?:\/[\w.-]{1,200}){1,30}/g

/** The first `n` code units of `text` (input guard for regex work). */
export function cap(text: string, n: number): string {
  return text.slice(0, n)
}

/** The last `n` code units of `text` (the end of an output holds the error). */
export function tail(text: string, n: number): string {
  return n <= 0 ? '' : text.slice(-n)
}

/**
 * `curl -b <jar>` redacted per command segment: `-b` means a cookie jar
 * only after `curl`. Segments are cut on separators outside quotes (the
 * blanked copy has the same length, so its cuts apply to the text).
 */
function redactCurlCookie(text: string): string {
  if (!text.includes('-b')) return text
  const blank = text.replace(QUOTED, q => ' '.repeat(q.length))
  const parts: string[] = []
  let from = 0
  for (const m of [...blank.matchAll(SEPARATOR), null]) {
    const end = m?.index ?? text.length
    const seg = text.slice(from, end)
    const hit = seg.includes('-b') && CURL_SEGMENT.test(seg)
    parts.push(hit ? seg.replace(COOKIE_FLAG, '-b <redacted>') : seg)
    parts.push(m?.[0] ?? '')
    from = end + (m?.[0].length ?? 0)
  }
  return parts.join('')
}

/** Masks secret-shaped text; reads at most the first 64 KiB. */
export function redact(text: string): string {
  let out = redactCurlCookie(cap(text, MAX_REGEX_INPUT))
  for (const [pattern, mask] of REDACTIONS) out = out.replace(pattern, mask)
  return out
}

/** A comparison key: volatile parts (hashes, paths, numbers) collapsed. */
export function normalize(line: string): string {
  return line
    .toLowerCase()
    .replace(IO_ERROR, '<errno>') // before PATH reads its slash
    .replace(HEX_RUN, '<hex>')
    .replace(PATH, '<path>')
    .replace(/\d+/g, '#')
    .replace(/\s+/g, ' ')
    .trim()
}

// The store: one key per project root, at most MAX_SESSIONS sessions each.
type Failure = {
  key: string // normalize(line): what makes two failures the same
  line: string
  excerpt: string
  command: string
  agent: boolean
  at: number
  count: number
}
type Milestone = {
  kind: 'commit' | 'finish' | 'green'
  label: string
  at: number
}
type Session = {
  id: string
  at: number // last activity
  failures: Failure[]
  milestones: Milestone[]
  red: string[]
}
type Project = { sessions: Session[] }

const STORE_PREFIX = 'p:'
const MAX_ROOT = 400
const MAX_SESSIONS = 3
const MAX_FAILURES = 50
const MAX_MILESTONES = 20
const MAX_RED = 10
const MAX_RED_LEN = 300
const MAX_LINE = 300
const MAX_SPAN = 300 // a registry span is capped before normalize
const MAX_COMMAND = 300
const EXCERPT_LEN = 600
const MAX_ENTRY = 2048
const STORE_CAP = 1048576
const LINE_WINDOW = 1000 // bounds the trailer regex on one long line

const EXIT_CODE = /^Exit code \d+/
export const ERRORISH = new RegExp(
  'error|fatal|cannot|can\'t|no such|not found|denied|failed|failure|' +
  'unexpected|invalid|exception|traceback|panic|usage:|SC\\d{4}|' +
  '> \\d+|assert',
  'i',
)
const RTK_TRAILER =
  /\s*\[(?:\+\d+ hidden|full output): rtk recall [0-9a-f]+\]$/

/**
 * The line that tells what failed, from an already redacted answer: the
 * last line after the first of an `Exit code N` text. `undefined` when the
 * text is another kind, has no such line, or the redacted line holds no
 * letter or is not error-shaped (`ERRORISH`); no earlier line is tried.
 */
export function failureLine(text: string): string | undefined {
  return EXIT_CODE.test(text) ? lastLine(text) : undefined
}

/** The error-shaped last line of a redacted text with a letter in it. */
function lastLine(text: string): string | undefined {
  const lines = text.split('\n')
    .map(l => l.slice(-LINE_WINDOW).replace(RTK_TRAILER, '').trim())
    .filter(l => l !== '')
  if (lines.length < 2) return undefined
  const line = (lines[lines.length - 1] ?? '').slice(0, MAX_LINE)
  return hasLetter(line) && ERRORISH.test(line) ? line : undefined
}

/** A letter outside the `<path>`, `<hex>` and `#` placeholders. */
function hasLetter(line: string): boolean {
  return /\p{L}/u.test(normalize(line).replace(/<path>|<hex>/g, ''))
}

function isSession(v: unknown): v is Session {
  const s = v as Partial<Session> | null
  return typeof s === 'object' && s !== null && typeof s.id === 'string' &&
    typeof s.at === 'number' && Array.isArray(s.failures) &&
    Array.isArray(s.milestones) && Array.isArray(s.red)
}

/** A stored value read as a project; malformed parts are dropped. */
function asProject(value: unknown): Project {
  const sessions = (value as Partial<Project> | null)?.sessions
  if (!Array.isArray(sessions)) return { sessions: [] }
  return { sessions: sessions.filter(isSession) }
}

const storeKey = (root: string) => STORE_PREFIX + root.slice(0, MAX_ROOT)

export async function loadProject($: Api, root: string): Promise<Project> {
  return asProject(await $.store.get(storeKey(root)))
}

/**
 * Finds the session or creates it, stamps its activity and keeps the
 * MAX_SESSIONS latest of the project; the one returned is never trimmed.
 */
export function sessionOf(p: Project, id: string, now: number): Session {
  const found = p.sessions.find(s => s.id === id)
  const s = found ?? { id, at: now, failures: [], milestones: [], red: [] }
  s.at = now
  const others = p.sessions.filter(o => o !== s).sort((a, b) => b.at - a.at)
  p.sessions = [s, ...others].slice(0, MAX_SESSIONS)
  return s
}

export function addFailure(s: Session, f: Failure): void {
  const same = s.failures.find(x => x.key === f.key)
  if (same === undefined) {
    s.failures = [...s.failures, f].slice(-MAX_FAILURES)
    return
  }
  same.count++
  same.at = f.at
}

/** An entry over MAX_ENTRY loses its excerpt first, then its line. */
function fitEntry(f: Failure): Failure {
  const out = { ...f }
  for (const field of ['excerpt', 'line', 'command', 'key'] as const) {
    const over = JSON.stringify(out).length - MAX_ENTRY
    if (over <= 0) break
    out[field] = field === 'excerpt'
      ? '' : out[field].slice(0, Math.max(0, out[field].length - over))
  }
  return out
}

/**
 * The failure entry of a tool answer, or `undefined` when the answer is
 * not a capturable failure. Everything stored comes from the redacted text.
 */
function buildFailure(
  text: string,
  command: string,
  agent: boolean,
  at: number,
): Failure | undefined {
  if (!EXIT_CODE.test(text)) return undefined
  const red = redact(tail(text, MAX_REGEX_INPUT))
  const line = lastLine(red)
  if (line === undefined) return undefined
  return fitEntry({
    key: normalize(line),
    line,
    excerpt: tail(red, EXCERPT_LEN),
    command: redact(cap(command, MAX_REGEX_INPUT)).slice(0, MAX_COMMAND),
    agent,
    at,
    count: 1,
  })
}

function bounded(s: Session): Session {
  return {
    ...s,
    milestones: s.milestones.slice(-MAX_MILESTONES),
    red: s.red.slice(-MAX_RED).map(r => r.slice(0, MAX_RED_LEN)),
  }
}

export async function saveProject(
  $: Api,
  root: string,
  p: Project,
): Promise<void> {
  await $.store.set(storeKey(root), { sessions: p.sessions.map(bounded) })
}

type Held = { key: string; size: number; project: Project; changed: boolean }

async function readHeld($: Api): Promise<Held[]> {
  const keys = (await $.store.keys()).filter(k => k.startsWith(STORE_PREFIX))
  const held: Held[] = []
  for (const key of keys) {
    const raw = await $.store.get(key)
    const size = JSON.stringify(raw ?? null).length
    held.push({ key, size, project: asProject(raw), changed: false })
  }
  return held
}

/** The oldest session that is not the current one, with its project. */
function oldestOther(held: Held[], cur: string, id: string) {
  let best: { h: Held; s: Session } | undefined
  for (const h of held) {
    for (const s of h.project.sessions) {
      if (h.key === cur && s.id === id) continue
      if (best === undefined || s.at < best.s.at) best = { h, s }
    }
  }
  return best
}

/**
 * Drops the oldest non-current sessions, across projects, until the
 * `p:*` keys fit STORE_CAP or none is droppable. Runs when a session
 * record is created, not on every write.
 */
async function sweepStore($: Api, curKey: string, id: string): Promise<void> {
  const held = await readHeld($)
  let total = held.reduce((n, h) => n + h.size, 0)
  while (total > STORE_CAP) {
    const victim = oldestOther(held, curKey, id)
    if (victim === undefined) break
    const { h, s } = victim
    h.project.sessions = h.project.sessions.filter(x => x !== s)
    h.changed = true
    const size = JSON.stringify(h.project).length
    total += size - h.size
    h.size = size
  }
  for (const h of held.filter(x => x.changed)) {
    if (h.project.sessions.length === 0) await $.store.delete(h.key)
    else await $.store.set(h.key, h.project)
  }
}

// The registry error index: which captured failures a registry knows.
const MAX_REGISTRY = 4194304
const MIN_SPAN = 12
const GRAM_WORDS = 4
// the ID only: a bounded capture carries no `$`, so a long heading stays one
const HEADING = /^## ((?:BDR|LRN|BLK)-\d+)\b/gm
const SPAN = /`([^`\n]+)`/g
const STATUS_WAIT_MS = 2500 // our own race over the process's 2000 ms
const STATUS_TIMEOUT_MS = 2000
const MAX_INDEX_ROW = 1000
const DEAD = new Set(['superseded', 'deprecated'])
const INDEX_ROW = new RegExp(
  '^\\|[ \\t]{0,5}((?:BDR|LRN|BLK)-\\d+)[ \\t]{0,5}\\|[^|]{0,40}\\|' +
    '(.{0,900})\\|([^|]{0,100})\\|[ \\t]{0,5}$',
)
const MAX_TITLE = 100
const MAX_LESSON = 280
const MAX_FIELD = 2000
const LESSON_LABELS: Record<Kind, string[]> = {
  BDR: ['Decision'],
  LRN: ['Apply', 'Future application', 'Pattern'],
  BLK: ['Solution', 'Real cause'],
}

export type Kind = 'BDR' | 'LRN' | 'BLK'
export type Entry = {
  id: string
  kind: Kind
  title: string
  lesson: string
  body: string
}
type Part = { id: string; body: string }
type Listed = { status: string; title: string }
export type StatusMap = Map<string, Listed>

type Read = { text: string } | { why: string }

/** True only when exists says no; a throwing probe cannot tell. */
async function isGone($: Api, path: string): Promise<boolean> {
  try {
    return !(await $.fs.exists(path))
  } catch {
    return false
  }
}

/** One stat, one read: the text, or why the registry is skipped. */
// a rejected stat means missing only when exists says so
async function tryRead($: Api, path: string): Promise<Read> {
  try {
    const info = await $.fs.stat(path)
    if (info.kind !== 'file') return { why: 'not a file' }
    if (info.size > MAX_REGISTRY) return { why: 'over 4 MiB' }
  } catch {
    return { why: (await isGone($, path)) ? 'missing' : 'unreadable' }
  }
  try {
    return { text: await $.fs.read(path) }
  } catch {
    return { why: 'unreadable' }
  }
}

/** The entries' ID and body; a body runs from its heading to the next. */
export function entriesOf(text: string): Part[] {
  const heads = [...text.matchAll(HEADING)]
  return heads.map((m, i) => ({
    id: m[1] ?? '',
    body: text.slice(m.index ?? 0, heads[i + 1]?.index ?? text.length),
  }))
}

/**
 * ID -> status word and title, from the rows `memory.sh index` prints
 * (`| ID | Date | Title | Status |`); the status is its lowercased first
 * word, `''` when empty.
 */
export function parseIndex(stdout: string): StatusMap {
  const rows: StatusMap = new Map()
  for (const line of stdout.split('\n')) {
    const m = INDEX_ROW.exec(line.slice(0, MAX_INDEX_ROW))
    if (m === null) continue
    const word = (m[3] ?? '').trim().match(/^[A-Za-z]+/)?.[0] ?? ''
    const title = (m[2] ?? '').trim()
    rows.set(m[1] ?? '', { status: word.toLowerCase(), title })
  }
  return rows
}

/** False when the ID is superseded or deprecated, or the map lacks it. */
export function isLive(status: StatusMap, id: string): boolean {
  const row = status.get(id)
  return row !== undefined && !DEAD.has(row.status)
}

/** `text` cut to `n` characters, the last one `…` when it was cut. */
function clip(text: string, n: number): string {
  return text.length > n ? `${text.slice(0, n - 1)}…` : text
}

/** The first sentence: up to `. ` or `; ` before a capital, or the end. */
function firstSentence(field: string): string {
  return /^(.*?[.;])(?:[ \t]+(?=[A-Z])|$)/.exec(field)?.[1] ?? field
}

/**
 * The one-line lesson of an entry: the first sentence of its first labelled
 * field, in the order of its kind; `''` when none is there.
 */
export function lessonOf(kind: Kind, body: string): string {
  for (const label of LESSON_LABELS[kind]) {
    const line = new RegExp(
      `^[ \\t]*-[ \\t]*(?:\\*\\*)?${label}(?:\\*\\*)?[ \\t]*:[ \\t]*` +
        `(.{0,${MAX_FIELD}})`,
      'im',
    ).exec(body)
    const field = (line?.[1] ?? '').trim()
    if (line !== null) return clip(firstSentence(field), MAX_LESSON)
  }
  return ''
}

/** The entries of registry texts, titled by `memory.sh index`'s rows. */
export function assembleEntries(texts: string[], index: StatusMap): Entry[] {
  return texts.flatMap(entriesOf).map(({ id, body }) => {
    const kind = id.slice(0, 3) as Kind
    const title = clip(index.get(id)?.title ?? '', MAX_TITLE)
    return { id, kind, title, lesson: lessonOf(kind, body), body }
  })
}

export const ERRNO_PHRASES: readonly string[] = [
  'no such file or directory', 'permission denied', 'command not found',
  'is a directory', 'not a directory', 'file exists',
  'directory not empty', 'operation not permitted',
  'no space left on device', 'connection refused', 'connection timed out',
  'broken pipe', 'resource temporarily unavailable', 'invalid argument',
  'too many open files', 'read-only file system',
  'device or resource busy', 'input/output error',
]

// Word-bounded literals; `input/output error` is already `<errno>` here.
const ERRNO = new RegExp(
  `(?<![a-z0-9])(?:${ERRNO_PHRASES.join('|')})(?![a-z0-9])`, 'g')

/** Each errno phrase of a normalized line, as `<errno>`. */
export function deErrno(normLine: string): string {
  return normLine.replace(ERRNO, '<errno>')
}

const PLACEHOLDERS = new Set(['#', '<path>', '<hex>', '<errno>'])

/**
 * Every window of 4 words, except one made only of placeholders (it
 * carries no content); a key of fewer words has none (always NEW).
 */
export function grams(normLine: string): string[] {
  const words = deErrno(normLine).split(/[^a-z0-9<>#]+/).filter(Boolean)
  if (words.length < GRAM_WORDS) return []
  return words
    .slice(0, words.length - GRAM_WORDS + 1)
    .map((_, i) => words.slice(i, i + GRAM_WORDS))
    .filter(win => !win.every(w => PLACEHOLDERS.has(w)))
    .map(win => win.join(' '))
}

function spansOf(body: string): string[] {
  return [...body.matchAll(SPAN)]
    .map(m => (m[1] ?? '').slice(0, MAX_SPAN))
    .filter(span => span.length >= MIN_SPAN)
}

function indexEntry(index: Map<string, string>, entry: Entry): void {
  for (const span of spansOf(entry.body)) {
    for (const gram of grams(normalize(span))) {
      if (!index.has(gram)) index.set(gram, entry.id)
    }
  }
}

/**
 * gram -> first ID, over the backticked spans of live entries. Without
 * statuses (`undefined`) every entry is indexed: advisory, never injected.
 */
export function buildIndex(
  entries: Entry[],
  status: StatusMap | undefined,
): Map<string, string> {
  const index = new Map<string, string>()
  for (const entry of entries) {
    if (status === undefined || isLive(status, entry.id)) {
      indexEntry(index, entry)
    }
  }
  return index
}

/** The registry ID of the first gram of `key` the index holds. */
export function matchOf(
  index: Map<string, string>,
  key: string,
): string | undefined {
  for (const gram of grams(key)) {
    const id = index.get(gram)
    if (id !== undefined) return id
  }
  return undefined
}

/** The stdout of `argv` on exit 0; `undefined` on any other end or 2.5 s. */
async function runWithin($: Api, argv: string[]): Promise<string | undefined> {
  const stop = new AbortController()
  const timer = $.clock.sleep(STATUS_WAIT_MS, { signal: stop.signal })
    .then(() => undefined, () => undefined)
  const run = $.process.run(argv, { timeoutMs: STATUS_TIMEOUT_MS })
    .then(r => (r.exitCode === 0 ? r.stdout : undefined), () => undefined)
  try {
    return await Promise.race([run, timer])
  } finally {
    stop.abort()
  }
}

/** The statuses `memory.sh index` prints; `undefined` when unavailable. */
async function statusMap($: Api, root: string): Promise<StatusMap | undefined> {
  try {
    const home = await $.env.get('HOME')
    if (!home) return undefined
    const out = await runWithin(
      $, ['bash', `${home}/.claude/lib/memory.sh`, '-C', root, 'index'])
    const rows = out === undefined ? undefined : parseIndex(out)
    return rows?.size ? rows : undefined
  } catch {
    return undefined
  }
}

const STOP_WORDS = new Set(
  ('the and for with that this from are was were not but you your have has ' +
    'had will can all any its into than then them they their there what ' +
    'when which who how why les des une pour dans avec est pas que qui sur ' +
    'par aux ces ses son mais ont sont plus comme').split(' '),
)
const TOKEN = /[\p{L}\p{N}]{2,40}/gu
const MAX_QUERY = 2000
const MAX_DOC = 65536
const BM25_K1 = 1.2
const BM25_B = 0.75
const MAX_PICKS = 3

/** Lowercase word runs (2-40 letters or digits) minus function words. */
export function tokensOf(text: string): string[] {
  const words = cap(text, MAX_DOC).toLowerCase().match(TOKEN) ?? []
  return words.filter(w => !STOP_WORDS.has(w))
}

type Doc = { entry: Entry; tf: Map<string, number>; len: number }

function docOf(entry: Entry): Doc {
  const tokens = tokensOf(`${entry.title} ${entry.lesson} ${entry.body}`)
  const tf = new Map<string, number>()
  for (const t of tokens) tf.set(t, (tf.get(t) ?? 0) + 1)
  return { entry, tf, len: tokens.length }
}

function scoreOf(
  doc: Doc, terms: string[], df: Map<string, number>, n: number, avg: number,
): number {
  let score = 0
  for (const term of terms) {
    const f = doc.tf.get(term) ?? 0
    if (f === 0) continue
    const d = df.get(term) ?? 0
    const idf = Math.log(1 + (n - d + 0.5) / (d + 0.5))
    const norm = 1 - BM25_B + (BM25_B * doc.len) / avg
    score += (idf * f * (BM25_K1 + 1)) / (f + BM25_K1 * norm)
  }
  return score
}

/** The `k` best entries for a query (BM25), highest first, score > 0. */
export function bm25Rank(entries: Entry[], query: string, k: number): Entry[] {
  const terms = [...new Set(tokensOf(cap(query, MAX_QUERY)))]
  const docs = entries.map(docOf)
  const df = new Map<string, number>()
  for (const d of docs) for (const t of d.tf.keys()) {
    df.set(t, (df.get(t) ?? 0) + 1)
  }
  const avg = docs.reduce((sum, d) => sum + d.len, 0) / (docs.length || 1)
  return docs
    .map(d => ({ e: d.entry, s: scoreOf(d, terms, df, docs.length, avg || 1) }))
    .filter(x => x.s > 0)
    .sort((a, b) => b.s - a.s ||
      a.e.id.localeCompare(b.e.id, 'en', { numeric: true }))
    .slice(0, k)
    .map(x => x.e)
}

/** The haiku prompt: the redacted user prompt and one line per candidate. */
export function rerankPrompt(query: string, cands: Entry[]): string {
  const lines = cands.map(c => `${c.id} | ${c.title} | ${c.lesson}`)
  // redact first: a secret straddling the cut would escape its pattern
  const asked = cap(redact(cap(query, MAX_REGEX_INPUT)), MAX_QUERY)
  return (
    `Prompt: ${asked}\nCandidates:\n` +
    `${lines.join('\n')}\nAnswer with at most ${MAX_PICKS} candidate IDs ` +
    'that would help with this prompt, comma separated, or none.'
  )
}

const ID_IN_ANSWER = /(?:BDR|LRN|BLK)-\d{1,5}/g

/** The candidate IDs named in a model answer, deduplicated, in order. */
export function parseIds(text: string, cands: Entry[], max: number): string[] {
  const known = new Set(cands.map(c => c.id))
  const found = cap(text, MAX_REGEX_INPUT).match(ID_IN_ANSWER) ?? []
  return [...new Set(found)].filter(id => known.has(id)).slice(0, max)
}

/** One recall line; the lesson keeps its own terminator. */
export function recallLine(e: Entry): string {
  const head = `${e.id} ${e.title}`
  return e.lesson === '' ? head : `${head} — ${e.lesson}`
}

const RECALL_HEADER = 'memory recall:'

/** The injected block; a line that would pass `max` characters is dropped. */
export function recallBlock(lines: string[], max: number): string {
  const header = RECALL_HEADER
  let block = header
  for (const line of lines) {
    if (block.length + 1 + line.length <= max) block += `\n${line}`
  }
  return block === header ? '' : block
}

/** The dedup key of a failure text, as `buildFailure` stores it. */
export function failureKey(text: string, command: string): string | undefined {
  void command // the key comes from the output only; kept for the harness
  if (!EXIT_CODE.test(text)) return undefined
  const line = lastLine(redact(tail(text, MAX_REGEX_INPUT)))
  return line === undefined ? undefined : normalize(line)
}

type Registries = {
  entries: Entry[]
  status: StatusMap | undefined
  index: Map<string, string>
  note: string
}

type Loaded = { texts: string[]; note: string }

/** The texts of the named registries and the first part of the note. */
async function readRegistries(
  $: Api,
  root: string,
  names: string[],
): Promise<Loaded> {
  const texts: string[] = []
  const read: string[] = []
  const skipped: string[] = []
  for (const name of names) {
    const r = await tryRead($, `${root}/.claude/memory/${name}`)
    if ('why' in r) {
      skipped.push(`${name} (${r.why})`)
      continue
    }
    texts.push(r.text)
    read.push(name)
  }
  const parts = [
    read.length > 0 ? `read ${read.join(', ')}` : '',
    skipped.length > 0 ? `skipped ${skipped.join(', ')}` : '',
  ]
  return { texts, note: `index: ${parts.filter(Boolean).join('; ')}` }
}

const FAILURE_FILES = ['blockers.md', 'learnings.md']
const FAILURE_KINDS = new Set<Kind>(['BLK', 'LRN'])

/**
 * The entries of the named registries with their statuses, and the error
 * index over the BLK and LRN ones. No registry read: no process run.
 */
async function loadRegistries(
  $: Api,
  root: string,
  names: string[],
): Promise<Registries> {
  const { texts, note } = await readRegistries($, root, names)
  const status = texts.length > 0 ? await statusMap($, root) : undefined
  const entries = assembleEntries(texts, status ?? new Map())
  const failing = entries.filter(e => FAILURE_KINDS.has(e.kind))
  const lost = texts.length > 0 && status === undefined
  return {
    entries,
    status,
    index: buildIndex(failing, status),
    note: lost ? `${note}; status reader unavailable` : note,
  }
}

// The answer of memory_pending: data for the model, never executed.
const ANSWER_CAP = 20000
const EXCERPT_SHOWN = 300
const OFF_TEXT = 'memory capture is off (~/.claude/memory.json)'
const NOTHING_TEXT = 'memory_pending: nothing captured'

const NEWLINES = /\r\n?|\n/g

const isText = (...v: unknown[]) => v.every(x => typeof x === 'string')

/** The store is data: a malformed element is skipped, never thrown on. */
function isFailure(v: unknown): v is Failure {
  const f = v as Partial<Failure> | null
  return typeof f === 'object' && f !== null &&
    isText(f.key, f.line, f.excerpt, f.command) &&
    Number.isFinite(f.count)
}

function isMilestone(v: unknown): v is Milestone {
  const m = v as Partial<Milestone> | null
  return typeof m === 'object' && m !== null && isText(m.kind, m.label) &&
    Number.isFinite(m.at) && Math.abs(m.at as number) < 8.64e15
}

type Row = { f: Failure; id: string | undefined; earlier: boolean }

/** Current-session NEW, current-session known, then earlier sessions. */
function rowsOf(p: Project, curId: string, index: Map<string, string>) {
  const rows: Row[] = p.sessions.flatMap(s =>
    s.failures.filter(isFailure).map(f => ({
      f, id: matchOf(index, f.key), earlier: s.id !== curId,
    })))
  const rank = (r: Row) => (r.earlier ? 2 : r.id === undefined ? 0 : 1)
  return rows.sort((a, b) => rank(a) - rank(b))
}

function failureText({ f, id, earlier }: Row): string {
  const tag = id === undefined ? 'NEW' : `known ${id}`
  const marks = (f.agent ? ' (sub-agent)' : '') +
    (earlier ? ' (earlier session)' : '')
  const cmd = f.command.replace(NEWLINES, '⏎')
  const line = f.line.replace(NEWLINES, '⏎')
  const head = `- ${tag} ×${f.count}${marks} ${line} — command: ${cmd}`
  if (f.excerpt === '') return head
  const shown = tail(f.excerpt, EXCERPT_SHOWN).replace(NEWLINES, '⏎')
  return `${head}\n  excerpt: ${shown}`
}

function milestoneText(m: Milestone): string {
  const d = new Date(m.at)
  const two = (n: number) => String(n).padStart(2, '0')
  const hhmm = `${two(d.getHours())}:${two(d.getMinutes())}`
  return `- ${m.kind} ${m.label} (${hhmm})`
}

/** The failure list within ANSWER_CAP; the rest is counted, not shown. */
function capFailures(items: string[]): string[] {
  const kept: string[] = []
  let used = 0
  for (const item of items) {
    if (used + item.length + 1 > ANSWER_CAP) break
    kept.push(item)
    used += item.length + 1
  }
  const omitted = items.length - kept.length
  return omitted > 0 ? [...kept, `… ${omitted} more failure(s) omitted`] : kept
}

export function formatPending(
  root: string,
  p: Project,
  curId: string,
  rx: Registries,
): string {
  const rows = rowsOf(p, curId, rx.index)
  const cur = p.sessions.find(s => s.id === curId)
  const ms = (cur?.milestones ?? []).filter(isMilestone)
  if (rows.length === 0 && ms.length === 0) return NOTHING_TEXT
  const name = root.split('/').filter(Boolean).pop() ?? root
  const out = [`memory_pending (project ${name}, ${p.sessions.length} ` +
    'session(s))', rx.note]
  if (ms.length > 0) {
    out.push('milestones (this session):', ...ms.map(milestoneText))
  }
  if (rows.length > 0) {
    out.push('failures:', ...capFailures(rows.map(failureText)))
  }
  return out.join('\n')
}

/** Runs `job` after every earlier write; a failed link breaks nothing. */
function queueWrite(st: State, job: () => Promise<void>): Promise<void> {
  const run = st.writes.then(job)
  st.writes = run.catch(() => undefined)
  return run
}

export type LogRecord = {
  at: number
  session: string
  agent: string
  channel: 'prompt' | 'tool'
  ids: string[]
}

// shortcut: one `l:<root>` key per project, so no cap across roots; upgrade
// path: one global log key, or a sweep of the `l:` keys by age.
const LOG_PREFIX = 'l:'
const MAX_LOG = 200
const MAX_LOG_BYTES = 65536

function isLogRecord(v: unknown): v is LogRecord {
  const r = v as Partial<LogRecord> | null
  return typeof r === 'object' && r !== null &&
    typeof r.at === 'number' && typeof r.session === 'string' &&
    typeof r.agent === 'string' &&
    (r.channel === 'prompt' || r.channel === 'tool') &&
    Array.isArray(r.ids) && r.ids.every(i => typeof i === 'string')
}

const logKey = (root: string) => LOG_PREFIX + root.slice(0, MAX_ROOT)

/** The injection log of a project; malformed records are dropped. */
export async function loadLog($: Api, root: string): Promise<LogRecord[]> {
  const raw = await $.store.get(logKey(root))
  return Array.isArray(raw) ? raw.filter(isLogRecord) : []
}

/** The newest records that fit MAX_LOG and MAX_LOG_BYTES serialized. */
function fitLog(log: LogRecord[]): LogRecord[] {
  let kept = log.slice(-MAX_LOG)
  while (kept.length > 0 && JSON.stringify(kept).length > MAX_LOG_BYTES) {
    kept = kept.slice(1)
  }
  return kept
}

/** Appends an injection record on the write chain; the oldest fall off. */
export function appendLog(
  $: Api,
  st: State,
  root: string,
  record: LogRecord,
): Promise<void> {
  return queueWrite(st, async () => {
    const log = await loadLog($, root)
    await $.store.set(logKey(root), fitLog([...log, record]))
  })
}

type Where = { root: string; id: string }

/** Load, change the current session, save; sweeps when it is created. */
async function mutateSession(
  $: Api,
  at: Where,
  now: number,
  change: (s: Session) => void,
): Promise<void> {
  const p = await loadProject($, at.root)
  const created = !p.sessions.some(s => s.id === at.id)
  change(sessionOf(p, at.id, now))
  await saveProject($, at.root, p)
  if (created) await sweepStore($, storeKey(at.root), at.id)
}

const recordFailure = ($: Api, at: Where, f: Failure) =>
  mutateSession($, at, f.at, s => addFailure(s, f))

// Milestones: a commit, a gitflow finish, a suite gone from red to green.
// Regexes read at most 64 KiB of one command and use bounded repeats.
const MAX_LABEL = 80
const MAX_PENDING = 20
const ENV_PREFIX = '(?:[A-Za-z_]\\w{0,60}=\\S{0,200}[ \\t]{1,5}){0,10}'
const SUITE_SEGMENT = new RegExp(
  `^${ENV_PREFIX}make\\b[^;&|]{0,1000}\\btest\\b`,
)
const COMMIT_SEGMENT = new RegExp(
  `^[(\\s]{0,5}(?:rtk[ \\t]{1,5})?${ENV_PREFIX}` +
    'git(?:[ \\t]{1,5}-C[ \\t]{1,5}\\S{1,200})?[ \\t]{1,5}commit\\b',
)
const CONVENTIONAL = '(feat|fix)(\\([^)\\n]{0,80}\\))?!?:[ \\t]{0,5}'
const COMMIT_MESSAGE = new RegExp(
  `-[a-z]{0,5}m[ \\t]{1,5}(["']?)${CONVENTIONAL}([^"'\\n]{0,300})`,
)
// -m "$(cat <<'EOF' newline subject: the subject is the first body line
const COMMIT_HEREDOC = new RegExp(
  '-[a-z]{0,5}m[ \\t]{1,5}"\\$\\(cat[ \\t]{1,5}<<-?["\']?' +
    '[A-Za-z_]{1,20}["\']?[ \\t]{0,5}\\n[ \\t]{0,20}' +
    `${CONVENTIONAL}([^\\n]{0,300})`,
)
const FINISH = new RegExp(
  `^${ENV_PREFIX}(?:bash|sh)[ \\t]{1,5}\\S{0,200}gitflow\\.sh"?` +
    '[ \\t]{1,5}finish\\b(?:[ \\t]{1,5}([a-z]{1,20})[ \\t]{1,5}' +
    '([\\w.=/-]{1,60}))?',
)
const FINISH_CHORE = /\bfinish[ \t]{1,5}chore\b/

/** The `;` `&&` `||` newline separated parts of a command. */
export function segments(command: string): string[] {
  return cap(command, MAX_REGEX_INPUT).split(/&&|\|\||;|\n/)
    .map(s => s.trim())
}

const label = (text: string) => redact(text).slice(0, MAX_LABEL)

/** The redacted, whitespace-normalized command when it runs a suite. */
export function suiteKeyOf(command: string): string | undefined {
  if (!segments(command).some(s => SUITE_SEGMENT.test(s))) return undefined
  return redact(cap(command, MAX_REGEX_INPUT)).replace(/\s+/g, ' ').trim()
    .slice(0, MAX_RED_LEN)
}

function conventional(type?: string, scope?: string, subject?: string) {
  return label(`${type}${scope ?? ''}: ${(subject ?? '').trim()}`)
}

/** `<type><scope>: <subject>` of a feat/fix commit, else `undefined`. */
export function commitLabel(command: string): string | undefined {
  const text = cap(command, MAX_REGEX_INPUT)
  const seg = segments(command).find(s => COMMIT_SEGMENT.test(s))
  if (seg === undefined) return undefined
  const rest = text.slice(Math.max(0, text.indexOf(seg)))
  const h = COMMIT_HEREDOC.exec(rest)
  if (h !== null) return conventional(h[1], h[2], h[3])
  const m = COMMIT_MESSAGE.exec(seg)
  return m === null ? undefined : conventional(m[2], m[3], m[4])
}

/** `<type> <name>` after a gitflow finish, `finish` alone, or undefined. */
export function finishLabel(command: string): string | undefined {
  for (const seg of segments(command)) {
    const m = FINISH.exec(seg)
    if (m === null || FINISH_CHORE.test(seg)) continue
    return m[1] === undefined ? 'finish' : label(`${m[1]} ${m[2]}`)
  }
  return undefined
}

export function newState(): State {
  return {
    enabled: null,
    recall: null,
    warned: new Set(),
    pending: [],
    writes: Promise.resolve(),
    seen: new Map(),
    spent: new Map(),
    fresh: new Set(),
    lastPrompt: new Map(),
    rerank: { fails: 0, until: 0 },
  }
}

/** Logs a hook's fail-open once per session; never throws itself. */
function warnOnce(st: State, $: Api, hook: string, kind: string): void {
  logOnce(st, $, hook, `memory: ${hook} hook failed (${kind}); passed through`)
}

/** Logs `text` once per session under `key`; never throws itself. */
function logOnce(st: State, $: Api, key: string, text: string): void {
  if (st.warned.has(key)) return
  st.warned.add(key)
  try {
    $.ui.log(text)
  } catch {
    // a failing log must not break the fail-open itself
  }
}

type Switch = { enabled: boolean; recall: boolean }

/**
 * The switch file's two keys. An absent key is on; a present non-boolean
 * logs one line and counts as absent. `enabled: false` cuts recall too.
 */
export function switchOf($: Api, st: State, data: unknown): Switch {
  const keys = (data ?? {}) as { enabled?: unknown; recall?: unknown }
  if (keys.enabled !== undefined && typeof keys.enabled !== 'boolean') {
    logOnce(st, $, 'switch', SWITCH_INVALID)
  }
  if (keys.recall !== undefined && typeof keys.recall !== 'boolean') {
    logOnce(st, $, 'switch-recall', SWITCH_RECALL_INVALID)
  }
  const enabled = keys.enabled !== false
  return { enabled, recall: enabled && keys.recall !== false }
}

/**
 * The user's switch file. A file that exists but cannot be read or parsed
 * keeps everything on and logs one line.
 */
async function loadEnabled($: Api, st: State): Promise<Switch> {
  const on = { enabled: true, recall: true }
  let path = ''
  try {
    const home = await $.env.get('HOME')
    if (!home) return on
    path = `${home}/${SWITCH_FILE}`
    const info = await $.fs.stat(path)
    if (info.kind !== 'file' || info.size > MAX_SWITCH_BYTES) return on
    return switchOf($, st, JSON.parse(await $.fs.read(path)))
  } catch {
    if (path !== '' && !(await isGone($, path))) {
      logOnce(st, $, 'switch', SWITCH_UNREADABLE)
    }
    return on
  }
}

/** The tool the model calls to list the failures and milestones captured. */
async function registerTool($: Api): Promise<void> {
  try {
    await $.tool.register({
      name: TOOL,
      description:
        'Failures and milestones this mod captured in the current ' +
        'project\'s recent sessions, each failure NEW or known <registry ' +
        'ID>. Call it first in /capitalize and every CAPITALIZE step; it ' +
        'never writes anything.',
      inputSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    })
  } catch {
    $.ui.log('memory: tool not registered')
  }
}

/**
 * Reads the switch on the first event of a session and caches it; each
 * read of `enabled: true` registers the tool again (a name registered
 * twice is replaced).
 */
async function ensureEnabled($: Api, st: State): Promise<boolean> {
  if (st.enabled !== null) return st.enabled
  const sw = await loadEnabled($, st)
  st.enabled = sw.enabled
  st.recall = sw.recall
  if (st.enabled) await registerTool($)
  return st.enabled
}

/** True when the mod is on and the "recall" key does not turn it off. */
async function ensureRecall($: Api, st: State): Promise<boolean> {
  return (await ensureEnabled($, st)) && st.recall === true
}

const contextKey = (session: string, agent: string | undefined) =>
  `${session}:${agent ?? 'main'}`

/** Forgets what a session's contexts injected. */
function forgetContexts(st: State, session: string): void {
  for (const map of [st.seen, st.spent]) {
    for (const key of [...map.keys()]) {
      if (key.startsWith(`${session}:`)) map.delete(key)
    }
  }
}

/** A new context: nothing injected yet, the next prompt may recall. */
export function onContextStart(st: State, session: string): void {
  forgetContexts(st, session)
  st.fresh.add(session)
}

/**
 * Takes the IDs not yet seen in the context whose line costs (`chars`,
 * parallel to `ids`) still fit RECALL_CAP, and records them. Synchronous:
 * called after the last await, so two racing callers never both claim.
 */
export function claim(
  st: State,
  key: string,
  ids: string[],
  chars: number[],
): string[] {
  const seen = st.seen.get(key) ?? new Set<string>()
  let spent = st.spent.get(key) ?? 0
  const taken: string[] = []
  ids.forEach((id, i) => {
    const cost = chars[i]
    // a missing cost refuses the id: unknown is not free
    if (cost === undefined || seen.has(id) || spent + cost > RECALL_CAP) return
    seen.add(id)
    spent += cost
    taken.push(id)
  })
  st.seen.set(key, seen)
  st.spent.set(key, spent)
  return taken
}

/** The tool's answer; reads the store and the registries, writes nothing. */
async function pendingAnswer($: Api, st: State): Promise<string> {
  if (!(await ensureEnabled($, st))) return OFF_TEXT
  const root = await $.session.root()
  if (root === '') return 'memory_pending: no project root'
  const id = await $.session.id()
  await st.writes
  const project = await loadProject($, root)
  const rx = await loadRegistries($, root, FAILURE_FILES)
  return formatPending(root, project, id, rx)
}

function registerPending(on: On, st: State): void {
  on('tool.call', { tool: SERVED_TOOL }, async $ => ({
    result: await pendingAnswer($, st),
  })).catch(($, _e, next) => {
    warnOnce(st, $, 'memory_pending', next.error.kind)
    return {
      result: `memory_pending failed (${next.error.kind}); nothing returned`,
    }
  })
}

/** The ending session's recall state; other sessions keep theirs. */
export function endContext(st: State, session: string): void {
  forgetContexts(st, session)
  st.fresh.delete(session)
  st.lastPrompt.delete(session)
}

/**
 * A context starts on startup, clear and compact (not resume or fork).
 * An agent's start resets that agent's key only.
 */
export function resetContext(
  st: State,
  source: string,
  session: string,
  agent: string | undefined,
): void {
  if (!CONTEXT_STARTS.has(source)) return
  if (agent === undefined) return onContextStart(st, session)
  const key = contextKey(session, agent)
  st.seen.delete(key)
  st.spent.delete(key)
}

function registerContext(on: On, st: State): void {
  on('classic.SessionStart', async ($, e, next) => {
    const session = e.session_id ?? await $.session.id()
    resetContext(st, e.source, session, e.agent_id)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'SessionStart', next.error.kind)
    return next(e)
  })
}

function registerSession(on: On, st: State): void {
  on('session.start', async ($, e, next) => {
    await ensureEnabled($, st)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'session.start', next.error.kind)
    return next(e)
  })
  on('session.end', async ($, e, next) => {
    st.enabled = null
    st.recall = null
    st.pending = []
    st.warned.clear()
    endContext(st, e.sessionId)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'session.end', next.error.kind)
    return next(e)
  })
}

/** Stores the failure a Bash answer carries; never throws, never re-runs. */
async function captureFailure(
  $: Api,
  st: State,
  at: Where,
  e: { command?: unknown; agentId?: unknown },
  out: { isError?: boolean; text?: string },
): Promise<void> {
  try {
    if (out.isError !== true) return
    const agent = e.agentId !== undefined
    const f = buildFailure(
      String(out.text ?? ''), String(e.command ?? ''), agent,
      await $.clock.now(),
    )
    if (f !== undefined) await queueWrite(st, () => recordFailure($, at, f))
  } catch {
    warnOnce(st, $, 'Bash capture', 'store')
  }
}

type BashEvent = {
  command?: unknown
  agentId?: unknown
  run_in_background?: unknown
}
type BashOut = {
  isError?: boolean
  deny?: unknown
  text?: string
  result?: {
    backgroundTaskId?: unknown
    timedOutAfterMs?: unknown
    interrupted?: unknown
  }
}

/** A finished foreground command that was neither denied nor failed. */
function isSuccess(e: BashEvent, out: BashOut): boolean {
  const r = out.result
  return out.isError !== true && out.deny === undefined &&
    r?.backgroundTaskId === undefined && r?.timedOutAfterMs === undefined &&
    r?.interrupted !== true && e.run_in_background !== true
}

/** The suite a failed command ran, remembered as red until it passes. */
function recordRed($: Api, st: State, at: Where, key: string, now: number) {
  return queueWrite(st, () => mutateSession($, at, now, s => {
    if (!s.red.includes(key)) s.red = [...s.red, key]
  }))
}

/** `commit fix: x`; a bare `finish` is not said twice. */
const noteLabel = (m: Milestone) =>
  m.label === m.kind ? m.kind : `${m.kind} ${m.label}`

/** Commit and finish milestones of a success; green when the suite was red. */
function recordSuccess(
  $: Api,
  st: State,
  at: Where,
  command: string,
  now: number,
): Promise<void> {
  const found = [
    ['commit', commitLabel(command)],
    ['finish', finishLabel(command)],
  ].filter((m): m is [Milestone['kind'], string] => m[1] !== undefined)
  const key = suiteKeyOf(command)
  if (found.length === 0 && key === undefined) return Promise.resolve()
  return queueWrite(st, async () => {
    const cur = (await loadProject($, at.root)).sessions
      .find(s => s.id === at.id)
    const green = key !== undefined && cur?.red.includes(key) === true
    if (found.length === 0 && !green) return
    const added = found.map(([kind, text]) => ({ kind, label: text, at: now }))
    if (green) added.push({ kind: 'green', label: label(key), at: now })
    await mutateSession($, at, now, s => {
      s.milestones = [...s.milestones, ...added]
      if (green) s.red = s.red.filter(r => r !== key)
    })
    st.pending = [...st.pending, ...added.map(noteLabel)].slice(-MAX_PENDING)
  })
}

/** Milestones of a main-loop Bash answer; never throws. */
async function captureMilestones(
  $: Api,
  st: State,
  at: Where,
  e: BashEvent,
  out: BashOut,
): Promise<void> {
  try {
    if (e.agentId !== undefined) return
    const command = String(e.command ?? '')
    const now = await $.clock.now()
    const key = suiteKeyOf(command)
    if (out.isError === true) {
      if (key !== undefined && EXIT_CODE.test(String(out.text ?? ''))) {
        await recordRed($, st, at, key, now)
      }
    } else if (isSuccess(e, out)) {
      await recordSuccess($, st, at, command, now)
    }
  } catch {
    warnOnce(st, $, 'Bash milestones', 'store')
  }
}

function registerBash(on: On, st: State): void {
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (!(await ensureEnabled($, st))) return next(e)
    // read before next: a failure here must not run the tool twice
    const at = { root: await $.session.root(), id: await $.session.id() }
    if (at.root === '') return next(e)
    const out = await next(e)
    await captureFailure($, st, at, e, out)
    await captureMilestones($, st, at, e, out as BashOut)
    return out
  }).catch(($, e, next) => {
    warnOnce(st, $, 'Bash', next.error.kind)
    return next(e)
  })
}

/** Failures of the current session no registry entry knows. */
async function newFailureCount(
  $: Api,
  st: State,
  at: Where,
  index: Map<string, string>,
): Promise<number> {
  await st.writes
  const p = await loadProject($, at.root)
  const cur = p.sessions.find(s => s.id === at.id)
  return (cur?.failures ?? []).filter(isFailure)
    .filter(f => matchOf(index, f.key) === undefined).length
}

/** The note for the oldest unnoted milestone; clears what it covers. */
async function noteFor(
  $: Api,
  st: State,
  at: Where,
  rx: Registries,
): Promise<string> {
  const first = st.pending[0] ?? ''
  st.pending = []
  const n = await newFailureCount($, st, at, rx.index)
  return `memory: ${first} \u2014 ${n} new failure mode(s) this session;` +
    ' /capitalize when ready.'
}

// The default prompt rules of the model router (mods/model-router, commit
// 9bbd1d5): a prompt that designs or analyses asks for recall.
const WORD_BEFORE = '(?<![\\p{L}\\p{N}-])'
const WORD_AFTER = '(?![\\p{L}\\p{N}-])'
const wordRule = (words: string) =>
  new RegExp(`${WORD_BEFORE}(${words})${WORD_AFTER}`, 'iu')

export const DESIGN_RULE = wordRule(
  'plan|planifie|planning|brainstorm|architecture|con[c\\u00e7]ois|design',
)
export const ANALYSIS_RULE = wordRule(
  'pourquoi|why|explique|explain|analyse|analyze|comprendre|understand|' +
    'review|audit',
)

const MIN_PROMPT = 12 // code points
const MAX_CANDS = 30
const RERANK_FAILS = 3 // failed reranks in a row that pause it
const RERANK_PAUSE_MS = 900000

/** True when a prompt may ask for recall: fresh context, idle, or a rule. */
export function isTrigger(
  text: string,
  fresh: boolean,
  idleMs: number,
): boolean {
  if (text.startsWith('/') || Array.from(text).length < MIN_PROMPT) {
    return false
  }
  const asked = cap(text, MAX_REGEX_INPUT)
  return fresh || idleMs >= IDLE_MS ||
    DESIGN_RULE.test(asked) || ANALYSIS_RULE.test(asked)
}

/** Counts a rerank: the third failure in a row pauses it for 15 min. */
function countRerank(st: State, ok: boolean, now: number): void {
  if (ok) {
    st.rerank.fails = 0
    return
  }
  st.rerank.fails += 1
  if (st.rerank.fails < RERANK_FAILS) return
  st.rerank = { fails: 0, until: now + RERANK_PAUSE_MS }
}

/** The haiku answer, or undefined: failed, unanswered, late or paused. */
async function askRerank(
  $: Api,
  st: State,
  text: string,
  cands: Entry[],
): Promise<string | undefined> {
  const now = await $.clock.now()
  if (now < st.rerank.until) return undefined
  const ask = {
    model: HAIKU,
    prompt: rerankPrompt(text, cands),
    effort: 'low' as const,
    maxTokens: 64,
    timeoutMs: RERANK_MS,
  }
  const call = $.model.complete(ask).catch((): undefined => undefined)
  const late = $.clock.sleep(RERANK_MS).then((): undefined => undefined)
  const out = await Promise.race([call, late])
  const answer = out?.isAnswered === true ? out.text : undefined
  countRerank(st, answer !== undefined, now)
  return answer
}

/** Live entries of the context not injected yet, best BM25 first. */
function candidatesFor(
  st: State,
  key: string,
  rx: Registries,
  text: string,
): Entry[] {
  const { status } = rx
  if (status === undefined) return []
  const seen = st.seen.get(key)
  const open = rx.entries.filter(e => isLive(status, e.id) && !seen?.has(e.id))
  return bm25Rank(open, text, MAX_CANDS)
}

/**
 * The recall block for a prompt: BM25 candidates, haiku picks, the ledger
 * claim, the log. '' when nothing is to be injected.
 */
async function recallFor(
  $: Api,
  st: State,
  at: Where,
  text: string,
  rx: Registries,
): Promise<string> {
  const key = contextKey(at.id, undefined)
  const cands = candidatesFor(st, key, rx, text)
  if (cands.length === 0) return ''
  const answer = await askRerank($, st, text, cands)
  const byId = new Map(cands.map(c => [c.id, c]))
  const picked = parseIds(answer ?? '', cands, MAX_PICKS)
    .flatMap(id => byId.get(id) ?? [])
  const when = await $.clock.now()
  // the header is charged to the first line of the block
  const costs = picked.map((e, i) =>
    recallLine(e).length + 1 + (i === 0 ? RECALL_HEADER.length : 0))
  const taken = claim(st, key, picked.map(e => e.id), costs)
  const block = recallBlock(
    picked.filter(e => taken.includes(e.id)).map(recallLine), RECALL_CAP)
  if (block === '') return ''
  const record = { at: when, session: at.id, agent: 'main', ids: taken }
  await appendLog($, st, at.root, { ...record, channel: 'prompt' })
    .catch(() => undefined)
  return block
}

const ALL_FILES = ['decisions.md', ...FAILURE_FILES]

/** The contexts a prompt adds: the 4b note, then the recall block. */
async function additions(
  $: Api,
  st: State,
  at: Where,
  text: string,
  wantRecall: boolean,
): Promise<string[]> {
  const rx = await loadRegistries($, at.root, ALL_FILES)
  const note = st.pending.length > 0 ? await noteFor($, st, at, rx) : ''
  const block = wantRecall
    ? await recallFor($, st, at, text, rx).catch(() => '')
    : ''
  return [note, block].filter(part => part !== '')
}

type PromptIn = {
  text: string
  turnId?: string | undefined
  origin: { kind: string }
}

/**
 * The contexts to append to a composer prompt; [] for any other prompt. A
 * new prompt starts a new turn: the main key's `spent` budget resets.
 */
export async function promptContext(
  $: Api,
  st: State,
  e: PromptIn,
): Promise<string[]> {
  if (!(await ensureEnabled($, st))) return []
  if (e.origin.kind !== 'composer' || e.turnId !== undefined) return []
  const at = { root: await $.session.root(), id: await $.session.id() }
  if (at.root === '') return []
  const now = await $.clock.now()
  const last = st.lastPrompt.get(at.id)
  const idle = last === undefined ? 0 : now - last // unknown: not idle
  st.lastPrompt.set(at.id, now)
  st.spent.delete(contextKey(at.id, undefined))
  const wantRecall = (await ensureRecall($, st)) &&
    isTrigger(e.text, st.fresh.has(at.id), idle)
  if (wantRecall) st.fresh.delete(at.id)
  if (!wantRecall && st.pending.length === 0) return []
  return additions($, st, at, e.text, wantRecall)
}

function registerPrompt(on: On, st: State): void {
  on('prompt.submit', async ($, e, next) => {
    const added = await promptContext($, st, e)
    if (added.length === 0) return next(e)
    return next({ ...e, context: [...(e.context ?? []), ...added] })
  }).catch(($, e, next) => {
    warnOnce(st, $, 'prompt.submit', next.error.kind)
    return next(e)
  })
}

export const register: Register = on => {
  const st = newState()
  registerSession(on, st)
  registerContext(on, st)
  registerBash(on, st)
  registerPending(on, st)
  registerPrompt(on, st)
}
