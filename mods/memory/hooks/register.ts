// memory: captures what fails in a session and offers it to the memory
// registries. This file is the frame: the off switch, the fail-open hooks
// and the per-session state. Every hook reads the session id and root at
// the point of use, never from a cache. A hook that fails passes the event
// through unchanged: the mod may never break a tool call or a prompt.
import type { EngineInterface, On, Register } from 'claude-code'

type Api = EngineInterface

type State = {
  enabled: boolean | null // null: not read yet this session
  warned: Set<string>
  pending: string[] // milestones not yet shown in a note
  writes: Promise<void> // the one chain every store write runs on
}

const SWITCH_FILE = '.claude/memory.json'
const MAX_SWITCH_BYTES = 65536
const TOOL = 'memory_pending'
const SERVED_TOOL = 'mcp__memory__memory_pending'

const MAX_REGEX_INPUT = 65536
const PEM = '-----'
const PEM_KIND = '(?:[A-Z]+ )?PRIVATE KEY'

// Redaction patterns, applied in order. Repeats are bounded where the
// input is free text, so no pattern can run away on a 64 KiB input.
const REDACTIONS: [RegExp, string][] = [
  [new RegExp(
    '\\b([A-Za-z_]{0,60}(?:TOKEN|API_KEY|SECRET|PASSWORD|PASSWD)' +
      '[A-Za-z_]{0,60})=\\S+',
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
  [/([a-z][a-z0-9+.-]{0,30}:\/\/)[^\s/@:]+:[^\s/@]+@/gi, '$1<redacted>@'],
]

const HEX_RUN = /\b[0-9a-f]{7,}\b/g
const PATH = /(?:\.{0,2}\/)?[\w.-]{1,200}(?:\/[\w.-]{1,200}){1,30}/g

/** The first `n` code units of `text` (input guard for regex work). */
export function cap(text: string, n: number): string {
  return text.slice(0, n)
}

/** The last `n` code units of `text` (the end of an output holds the error). */
export function tail(text: string, n: number): string {
  return n <= 0 ? '' : text.slice(-n)
}

/** Masks secret-shaped text; reads at most the first 64 KiB. */
export function redact(text: string): string {
  let out = cap(text, MAX_REGEX_INPUT)
  for (const [pattern, mask] of REDACTIONS) out = out.replace(pattern, mask)
  return out
}

/** A comparison key: volatile parts (hashes, paths, numbers) collapsed. */
export function normalize(line: string): string {
  return line
    .toLowerCase()
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
 * text is another kind, has no such line, or the redacted line is not
 * error-shaped (`ERRORISH`); no earlier line is tried.
 */
export function failureLine(text: string): string | undefined {
  if (!EXIT_CODE.test(text)) return undefined
  const lines = text.split('\n')
    .map(l => l.slice(-LINE_WINDOW).replace(RTK_TRAILER, '').trim())
    .filter(l => l !== '')
  if (lines.length < 2) return undefined
  const line = (lines[lines.length - 1] ?? '').slice(0, MAX_LINE)
  return ERRORISH.test(line) ? line : undefined
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
  const red = redact(tail(text, MAX_REGEX_INPUT))
  const line = failureLine(red)
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
const REGISTRIES = ['blockers.md', 'learnings.md']
const MAX_REGISTRY = 4194304
const MIN_SPAN = 12
const GRAM_WORDS = 4
const HEADING = /^## ((?:BLK|LRN)-\d+)\b.*$/gm
const SPAN = /`([^`\n]+)`/g
// [ \t] not \s: a multiline regex must not cross newlines (quadratic).
const STATUS =
  /^[ \t]*-[ \t]*\*\*Stat(?:us|ut)[^*\n]*\*\*[ \t]*:?[ \t]*([A-Za-z-]+)/gim

type Entry = { id: string; body: string }

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

/** The BLK/LRN entries; a body runs from its heading to the next one. */
export function entriesOf(text: string): Entry[] {
  const heads = [...text.matchAll(HEADING)]
  return heads.map((m, i) => ({
    id: m[1] ?? '',
    body: text.slice(m.index ?? 0, heads[i + 1]?.index ?? text.length),
  }))
}

// shortcut: a lexical reader, not memory.sh's shared parser (that lives in
// shell); upgrade = call the parser once the engine exposes a CLI run in
// hooks.
/** The last labelled status reads superseded; else the heading `[tag]`. */
export function isSuperseded(body: string): boolean {
  const last = [...body.matchAll(STATUS)].pop()
  if (last !== undefined) return (last[1] ?? '').toLowerCase() === 'superseded'
  return /\[superseded\]/i.test(body.split('\n', 1)[0] ?? '')
}

/** Every window of 4 words; a key of fewer words has none (always NEW). */
export function grams(normLine: string): string[] {
  const words = normLine.split(/[^a-z0-9<>#]+/).filter(Boolean)
  if (words.length < GRAM_WORDS) return []
  return words
    .slice(0, words.length - GRAM_WORDS + 1)
    .map((_, i) => words.slice(i, i + GRAM_WORDS).join(' '))
}

function spansOf(body: string): string[] {
  return [...body.matchAll(SPAN)]
    .map(m => m[1] ?? '')
    .filter(span => span.length >= MIN_SPAN)
}

function indexEntry(index: Map<string, string>, entry: Entry): void {
  if (isSuperseded(entry.body)) return
  for (const span of spansOf(entry.body)) {
    for (const gram of grams(normalize(span))) {
      if (!index.has(gram)) index.set(gram, entry.id)
    }
  }
}

/** gram -> first ID, over the backticked spans of live entries. */
export function buildIndex(texts: string[]): Map<string, string> {
  const index = new Map<string, string>()
  for (const text of texts) {
    for (const entry of entriesOf(text)) indexEntry(index, entry)
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

type Registries = { index: Map<string, string>; note: string }

async function loadIndex($: Api, root: string): Promise<Registries> {
  const texts: string[] = []
  const read: string[] = []
  const skipped: string[] = []
  for (const name of REGISTRIES) {
    const path = `${root}/.claude/memory/${name}`
    const r = await tryRead($, path)
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
  return {
    index: buildIndex(texts),
    note: `index: ${parts.filter(Boolean).join('; ')}`,
  }
}

// The answer of memory_pending: data for the model, never executed.
const ANSWER_CAP = 20000
const EXCERPT_SHOWN = 300
const OFF_TEXT = 'memory capture is off (~/.claude/memory.json)'
const NOTHING_TEXT = 'memory_pending: nothing captured'

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
  const head = `- ${tag} ×${f.count}${marks} ${f.line} — command: ${f.command}`
  if (f.excerpt === '') return head
  const shown = tail(f.excerpt, EXCERPT_SHOWN).replace(/\r\n?|\n/g, '⏎')
  return `${head}\n  excerpt: ${shown}`
}

function milestoneText(m: Milestone): string {
  const hhmm = new Date(m.at).toISOString().slice(11, 16)
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

function newState(): State {
  return {
    enabled: null,
    warned: new Set(),
    pending: [],
    writes: Promise.resolve(),
  }
}

/** Logs a hook's fail-open once per session; never throws itself. */
function warnOnce(st: State, $: Api, hook: string, kind: string): void {
  if (st.warned.has(hook)) return
  st.warned.add(hook)
  try {
    $.ui.log(`memory: ${hook} hook failed (${kind}); passed through`)
  } catch {
    // a failing log must not break the fail-open itself
  }
}

/** True unless the user's switch file says `enabled: false`. */
async function loadEnabled($: Api): Promise<boolean> {
  try {
    const home = await $.env.get('HOME')
    if (!home) return true
    const path = `${home}/${SWITCH_FILE}`
    const info = await $.fs.stat(path)
    if (info.kind !== 'file' || info.size > MAX_SWITCH_BYTES) return true
    const data: unknown = JSON.parse(await $.fs.read(path))
    if (typeof data !== 'object' || data === null) return true
    return (data as { enabled?: unknown }).enabled !== false
  } catch {
    return true
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
  st.enabled = await loadEnabled($)
  if (st.enabled) await registerTool($)
  return st.enabled
}

/** The tool's answer; reads the store and the registries, writes nothing. */
async function pendingAnswer($: Api, st: State): Promise<string> {
  if (!(await ensureEnabled($, st))) return OFF_TEXT
  const root = await $.session.root()
  if (root === '') return 'memory_pending: no project root'
  const id = await $.session.id()
  await st.writes
  const project = await loadProject($, root)
  return formatPending(root, project, id, await loadIndex($, root))
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
    st.pending = []
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
    st.pending = [...st.pending, ...added.map(m => `${m.kind} ${m.label}`)]
      .slice(-MAX_PENDING)
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
async function newFailureCount($: Api, st: State, at: Where): Promise<number> {
  await st.writes
  const p = await loadProject($, at.root)
  const { index } = await loadIndex($, at.root)
  const cur = p.sessions.find(s => s.id === at.id)
  return (cur?.failures ?? []).filter(isFailure)
    .filter(f => matchOf(index, f.key) === undefined).length
}

/** The note for the oldest unnoted milestone; clears what it covers. */
async function noteFor($: Api, st: State, at: Where): Promise<string> {
  const first = st.pending[0] ?? ''
  st.pending = []
  const n = await newFailureCount($, st, at)
  return `memory: ${first} \u2014 ${n} new failure mode(s) this session;` +
    ' /capitalize when ready.'
}

function registerPrompt(on: On, st: State): void {
  on('prompt.submit', async ($, e, next) => {
    if (!(await ensureEnabled($, st))) return next(e)
    const mine = e.origin.kind === 'composer' && e.turnId === undefined
    if (!mine || st.pending.length === 0) return next(e)
    const at = { root: await $.session.root(), id: await $.session.id() }
    if (at.root === '') return next(e)
    const note = await noteFor($, st, at)
    return next({ ...e, context: [...(e.context ?? []), note] })
  }).catch(($, e, next) => {
    warnOnce(st, $, 'prompt.submit', next.error.kind)
    return next(e)
  })
}

export const register: Register = on => {
  const st = newState()
  registerSession(on, st)
  registerBash(on, st)
  registerPending(on, st)
  registerPrompt(on, st)
}
