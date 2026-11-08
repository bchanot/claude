// lib/memory-feedback/labels.ts: labels.tsv rows (append-only), the
// labeller's draft and state.json (phase 4d). IDs, enums and repo tags
// only, never text (LRN-124).
import { createHash } from 'node:crypto'
import * as fs from 'node:fs'
import * as path from 'node:path'

export type Channel = 'prompt' | 'tool'
export type Label = 'relevant' | 'irrelevant' | 'test' | 'missed' |
  'checked' | 'ask' | 'lost'
const DRAFT_LABELS = ['relevant', 'irrelevant', 'test', 'missed', 'checked']
const ENTRY_LABELS = ['relevant', 'irrelevant']
const CAUSES = ['no-overlap', 'overlap']
const ID_RE = /^(BDR|LRN|BLK)-\d{3,}$/

/** One worksheet item: a log record and what the join found. */
export type Item = {
  n: number; root: string; session: string; at: number; channel: Channel
  trigger: string; outcome: string; cands?: number; ms?: number
  ids: string[]; cited: string[]; lost: boolean
}
export type Row = {
  at: number; root: string; session: string; channel: Channel
  trigger: string; outcome: string; cands?: number; ms?: number
  pick?: number; id: string; label: Label; cause: string
}
export type Draft = { item: number; id: string; label: Label; cause: string }
/** promptAt/toolAt: when each gate verdict was first reached. */
export type State = {
  lastRun: number; promptAt?: number; toolAt?: number; closed: boolean
}

const COLS = ['at', 'root', 'session', 'channel', 'trigger', 'outcome',
  'cands', 'ms', 'pick', 'id', 'label', 'cause']
const HEADER = COLS.join('\t') + '\n'

/** A repo tag: basename + 6 hex of the path (same names stay apart). */
export const tagOf = (root: string) => `${path.basename(root)}#` +
  createHash('sha1').update(root).digest('hex').slice(0, 6)

/** One record's identity: session ids are unique across repos. */
export const keyOf = (r: { session: string; at: number; channel: string }) =>
  `${r.session}|${r.at}|${r.channel}`

const num = (v: number | undefined) => v === undefined ? '' : String(v)
const opt = (s: string | undefined) =>
  s === undefined || s === '' ? undefined : Number(s)

export function toLine(r: Row): string {
  return [r.at, r.root, r.session, r.channel, r.trigger, r.outcome,
    num(r.cands), num(r.ms), num(r.pick), r.id, r.label, r.cause]
    .join('\t')
}

/** A labels.tsv line as a row; the header or a short line: undefined. */
export function fromLine(line: string): Row | undefined {
  const f = line.split('\t')
  if (f.length !== COLS.length || f[0] === 'at') return undefined
  return {
    at: Number(f[0]), root: f[1] ?? '', session: f[2] ?? '',
    channel: f[3] as Channel, trigger: f[4] ?? '', outcome: f[5] ?? '',
    cands: opt(f[6]), ms: opt(f[7]), pick: opt(f[8]), id: f[9] ?? '',
    label: f[10] as Label, cause: f[11] ?? '',
  }
}

const mkdir = (file: string) =>
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 })

/** Writes through a 0600 temp file and a rename; the dir is made 0700. */
export function writeSafe(file: string, text: string): void {
  mkdir(file)
  const tmp = `${file}.${process.pid}.tmp`
  fs.writeFileSync(tmp, text, { mode: 0o600 })
  fs.renameSync(tmp, file)
}

/** Every row; a damaged line fails loudly, it is never dropped. */
export function readRows(file: string): Row[] {
  if (!fs.existsSync(file)) return []
  const lines = fs.readFileSync(file, 'utf8').split('\n')
  return lines.flatMap((line, i) => {
    if (line === '' || line === HEADER.trimEnd()) return []
    const r = fromLine(line)
    if (r !== undefined) return [r]
    throw new Error(`labels.tsv line ${i + 1} unreadable: fix it by hand ` +
      'or restore labels.tsv.bak')
  })
}

/** Appends rows; the previous file is copied to labels.tsv.bak first. */
export function appendRows(file: string, rows: Row[]): void {
  mkdir(file)
  if (fs.existsSync(file)) fs.copyFileSync(file, `${file}.bak`)
  else fs.writeFileSync(file, HEADER, { mode: 0o600 })
  fs.appendFileSync(file, rows.map(r => toLine(r) + '\n').join(''))
}

/** state.json; absent: a first run; unparsable: a loud error. */
export function readState(file: string): State {
  if (!fs.existsSync(file)) return { lastRun: 0, closed: false }
  try {
    const s = JSON.parse(fs.readFileSync(file, 'utf8'))
    const at = (v: unknown) => typeof v === 'number' ? v : undefined
    return { lastRun: Number(s.lastRun) || 0, promptAt: at(s.promptAt),
      toolAt: at(s.toolAt), closed: s.closed === true }
  } catch {
    throw new Error(`state.json unreadable (${file}): fix or delete it`)
  }
}

export const writeState = (file: string, s: State) =>
  writeSafe(file, JSON.stringify(s) + '\n')

/** One draft line `item<TAB>id<TAB>label[<TAB>cause]`, or why not. */
function parseLine(line: string): Draft | string {
  const f = line.split('\t')
  if (f.length < 3 || f.length > 4) return `bad field count: ${line}`
  const item = Number(f[0])
  const label = f[2] ?? ''
  if (!Number.isInteger(item)) return `bad item: ${f[0]}`
  if (!DRAFT_LABELS.includes(label)) return `bad label: '${label}'`
  return { item, id: f[1] ?? '', label: label as Label, cause: f[3] ?? '' }
}

/** Why `d` does not fit item `it`; '' when it fits. */
function fitError(d: Draft, it: Item | undefined): string {
  if (it === undefined || it.lost) return `unknown or lost item ${d.item}`
  const plain = d.cause === ''
  if (d.id === '-') {
    return plain && (d.label === 'checked' || d.label === 'test')
      ? '' : `item ${d.item}: only checked or test take id -`
  }
  if (ENTRY_LABELS.includes(d.label)) {
    return plain && it.ids.includes(d.id)
      ? '' : `item ${d.item}: ${d.id} was not injected there`
  }
  const ok = d.label === 'missed' && it.channel === 'prompt' &&
    ID_RE.test(d.id) && !it.ids.includes(d.id) && CAUSES.includes(d.cause)
  return ok ? '' : `item ${d.item}: bad ${d.label} row ${d.id} ${d.cause}`
}

/** Every injected entry of every joined item labelled exactly once. */
function completeError(drafts: Draft[], items: Item[]): string {
  const whole = new Set(drafts.filter(d => d.id === '-' &&
    d.label === 'test').map(d => d.item))
  const got = drafts.filter(d => ENTRY_LABELS.includes(d.label))
    .map(d => `${d.item}:${d.id}`)
  if (new Set(got).size !== got.length) return 'an entry is labelled twice'
  for (const it of items) {
    if (it.lost || whole.has(it.n)) continue
    const miss = it.ids.find(id => !got.includes(`${it.n}:${id}`))
    if (miss !== undefined) return `item ${it.n}: ${miss} unlabelled`
  }
  return ''
}

/** The validated draft, or the first problem found. */
export function parseDraft(text: string, items: Item[]): Draft[] | string {
  const byN = new Map(items.map(i => [i.n, i]))
  const drafts: Draft[] = []
  for (const line of text.split('\n')) {
    if (line.trim() === '' || line.startsWith('#')) continue
    const d = parseLine(line)
    if (typeof d === 'string') return d
    const err = fitError(d, byN.get(d.item))
    if (err !== '') return err
    drafts.push(d)
  }
  const err = completeError(drafts, items)
  return err === '' ? drafts : err
}

const base = (it: Item) => ({
  at: it.at, root: it.root, session: it.session, channel: it.channel,
  trigger: it.trigger, outcome: it.outcome, cands: it.cands, ms: it.ms,
})

/** The labels.tsv rows of one item: its ask row, then its draft rows. */
export function rowsOf(it: Item, drafts: Draft[]): Row[] {
  const head: Row = { ...base(it), id: '',
    label: it.lost ? 'lost' : 'ask', cause: '' }
  const mine = drafts.filter(d => d.item === it.n).map((d): Row => ({
    ...base(it), id: d.id === '-' ? '' : d.id,
    pick: it.ids.includes(d.id) ? it.ids.indexOf(d.id) + 1 : undefined,
    label: d.label, cause: d.cause,
  }))
  return [head, ...mine]
}

/** A draft to fill in: one `<item> <id> ` line per injected id. */
export function skeleton(items: Item[]): string {
  const lines = items.filter(i => !i.lost)
    .flatMap(i => i.ids.map(id => `${i.n}\t${id}\t`))
  return ['# fill the 3rd column: relevant or irrelevant', ...lines]
    .join('\n') + '\n'
}
