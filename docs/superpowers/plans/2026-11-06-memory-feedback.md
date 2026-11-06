# Memory Feedback (phase 4d) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure from real data whether 4c memory recall helps, through two
optional log fields, a bun reader that joins the log to transcripts into
local labels, a `/memory-feedback` skill, a session-start reminder, and a
fixed-threshold gate.

**Architecture:** The mod (`mods/memory/hooks/register.ts`) logs `cands`
and `ms` on prompt records. A bun reader in `lib/memory-feedback/` (four
focused modules: thresholds, labels, transcripts, metrics, plus the CLI)
imports the mod's own log validator, joins records to transcript
attachments, writes a text worksheet only to the scratchpad, and keeps IDs
and enums in `~/.claude/memory-feedback/` (0600). A shell lib prints the
reminder line in the banner. The skill drives labelling.

**Tech Stack:** TypeScript on bun (`bun test`, `node:fs`), Claude Code mod
kit (`claude-code/testing`), bash 3.2-safe shell, jq-free banner check.

**Spec:** `docs/superpowers/specs/2026-11-06-memory-feedback-design.md`
**Contract:** `.claude/tasks/contracts/2026-11-06-memory-feedback-4d-1825.md`

## Global Constraints

- No prompt or reply text in the plugin store, `labels.tsv`, `state.json`,
  `FEEDBACK.md` or any committed file; text only in `<dir>/worksheet.md` and
  `<dir>/items.json` where `<dir>` is the session scratchpad (LRN-124,
  LRN-261).
- `~/.claude/memory-feedback/` created 0700, every file in it 0600, writes
  through a temp file and a rename.
- Our code: at most 25 logic lines per function, 80 columns, 5 params, no
  global mutable state.
- No new dependency: bun built-ins and `node:*` only.
- Shell is bash 3.2-safe (no `mapfile`, `declare -A`, `local -n`).
- Every suite that runs the hook, the mod kit or bun runs contained:
  `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" <cmd> </dev/null`.
- Never run the real `claude` CLI except through
  `make test suite=lib/tests/mods.test.sh` (its existing
  `claude plugin validate|test`), contained as above.
- Mod edits are live in every session at once (LRN-212): the failing kit
  test lands before the code, the change stays additive.
- Retention stays `cleanupPeriodDays: 7` (BDR-057).
- Thresholds live only in `lib/memory-feedback/thresholds.ts` (BDR-100).
- Spec deviation, internal: the reader lives in `lib/memory-feedback/`
  instead of `mods/memory/feedback/` so `claude plugin validate --strict`
  and `claude plugin test` never see non-mod files; `state.json` holds
  `lastRun` and `toolExtended` only, the labelled set is derived from
  `labels.tsv` (one source); `labels.tsv` also carries machine rows `ask`
  (one per record) and `lost`, and the draft accepts `checked -` and
  `test -`.

## Review Focus

1. The store file is read while the engine rewrites it (torn JSON): the
   reader must fail loudly, write nothing, and say to retry. Test in Task 5.
2. A record whose transcript expired or was never written: counted `lost`,
   no crash, no label asked. Tests in Tasks 4 and 5.
3. A labeller draft that is incomplete, labels an entry twice, or invents an
   ID: refused whole, nothing written. Tests in Task 2 and Task 5.
4. `apply` run twice on the same worksheet: refused, `labels.tsv`
   unchanged. Test in Task 5.
5. The first run before any record carries `cands`: the worksheet says
   there is nothing to label, `apply` records the run only, the reminder
   goes quiet for 5 days. Tests in Tasks 5 and 6.

---

### Task 1: `cands` and `ms` in the injection log (4d.1)

Implements spec §1. BDR-137 (log in `$.store`, caps), LRN-212 (live
edit), BDR-125 (no runtime cited flag).

**Files:**
- Modify: `mods/memory/hooks/register.ts:973-1003` (types, validator),
  `:1700-1771` (`Picked`, `pickRecall`, `recallFor`)
- Test: `mods/memory/hooks/register.test.ts` (after `LO7`, ~line 2420)

**Interfaces:**
- Produces: `export type LogRecord` with `cands?: number`, `ms?: number`;
  `export const LOG_PREFIX = 'l:'`; `export function isLogRecord(v:
  unknown): v is LogRecord` (both were module-private).

- [ ] **Step 1: Write the failing kit tests**

Add after the `LO7` test in `register.test.ts`, and add `isLogRecord` to
the existing value import list from `./register` at the top of the file
(`Api` and `On` are already imported as types at lines 3; `Model` is the
file's own type at line 36):

```ts
/** [outcome, cands, ms] of every logged ask, oldest first. */
async function askMeta(w: World) {
  return (await loadLog(storeApi(w), ROOT))
    .map(r => [r.outcome, r.cands, r.ms])
}

/** The single ask of a fresh world answered by `model`. */
async function oneAsk($: Api, on: On, model?: Model) {
  const { w } = await bootRecall($, on)
  if (model !== undefined) w.model = model
  await start($)
  await say($, GO)
  return (await askMeta(w))[0] ?? []
}

test('LF1: an injected ask logs cands and ms', async ($, on) => {
  const [outcome, cands, ms] = await oneAsk($, on)
  expect(outcome).toBe('injected')
  expect(typeof cands === 'number' && cands >= 1).toBe(true)
  expect(ms).toBe(0) // the mock clock does not move during an answer
})

test('LF1b: a declined ask logs cands and ms', async ($, on) => {
  const [outcome, cands, ms] = await oneAsk($, on, { text: 'none' })
  expect(outcome).toBe('none')
  expect(typeof cands === 'number' && cands >= 1).toBe(true)
  expect(ms).toBe(0)
})

test('LF1c: an unanswered ask logs cands and ms', async ($, on) => {
  const [outcome, cands, ms] = await oneAsk($, on, 'unanswered')
  expect(outcome).toBe('timeout')
  expect(typeof cands === 'number' && cands >= 1).toBe(true)
  expect(ms).toBe(0)
})

test('LF2: no candidate and a pause log no ms', async ($, on) => {
  const { w } = await bootRecall($, on)
  w.proc = { stdout: rowsOut([['BLK-001', 'x'], ['LRN-002', 'y']])
    .replace(/open/g, 'superseded') }
  await start($)
  await say($, GO)
  expect(await askMeta(w)).toEqual([['none', 0, undefined]])
})

test('LF3: a paused ask logs cands without ms', async ($, on) => {
  const { w } = await bootRecall($, on)
  w.model = 'unanswered'
  await start($)
  for (let i = 0; i < 4; i++) await say($, DESIGN)
  const last = (await askMeta(w)).at(-1)
  expect(last?.[0]).toBe('paused')
  expect((last?.[1] as number) >= 1).toBe(true)
  expect(last?.[2]).toBeUndefined()
})

test('LF4: cands and ms are optional counts', async ($, on) => {
  const good = { ...REC(2), cands: 4, ms: 812 }
  const neg = { ...REC(3), cands: -1 }
  const frac = { ...REC(4), ms: 1.5 }
  const seed = { [`l:${ROOT}`]: [REC(1), good, neg, frac] }
  const w = await boot($, on, { seed })
  expect(await loadLog(storeApi(w), ROOT)).toEqual([REC(1), good])
  expect(isLogRecord(REC(1))).toBe(true)
})
```

- [ ] **Step 2: Run the suite, see the four new tests fail**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/mods.test.sh </dev/null`
Expected: FAIL on `memory: plugin test` naming LF1-LF4 (LF1, LF1b, LF1c, LF2, LF3, LF4) (cands undefined,
`isLogRecord` not exported). Every other test still passes.

- [ ] **Step 3: Implement**

In `register.ts`, replace the `LogRecord` type, `LOG_PREFIX` and
`isLogRecord` block (lines ~976-1003) with:

```ts
// `trigger` and `outcome` are absent on records written before 4c's
// review; `cands` and `ms` on records written before 4d.1.
export type LogRecord = {
  at: number
  session: string
  agent: string
  channel: 'prompt' | 'tool'
  ids: string[]
  trigger?: Trigger
  outcome?: Outcome
  cands?: number // prompt: BM25 candidates after the seen filter
  ms?: number // prompt: rerank wall time, when a rerank ran
}

// shortcut: one `l:<root>` key per project (about 28 KiB at 200 records),
// swept by `sweepLogs` against the engine's 4 MiB store cap, oldest key
// first; upgrade path: one global log key, or a smaller per-root cap.
export const LOG_PREFIX = 'l:'
const MAX_LOG = 200
const MAX_LOG_BYTES = 65536

/** Absent, or a non-negative integer. */
const isCount = (v: unknown) =>
  v === undefined || (Number.isInteger(v) && (v as number) >= 0)

/** A well-formed log record; the 4d reader imports it (LRN-261). */
export function isLogRecord(v: unknown): v is LogRecord {
  const r = v as Partial<LogRecord> | null
  return typeof r === 'object' && r !== null &&
    typeof r.at === 'number' && typeof r.session === 'string' &&
    typeof r.agent === 'string' &&
    (r.channel === 'prompt' || r.channel === 'tool') &&
    Array.isArray(r.ids) && r.ids.every(i => typeof i === 'string') &&
    (r.trigger === undefined || TRIGGERS.includes(r.trigger)) &&
    (r.outcome === undefined || OUTCOMES.includes(r.outcome)) &&
    isCount(r.cands) && isCount(r.ms)
}
```

Change `Picked` and `pickRecall` (lines ~1704-1740):

```ts
type Picked = { block: string; ids: string[]; outcome: Outcome; ms?: number }
```

```ts
/** Asks haiku among the candidates and claims its picks. */
async function pickRecall(
  $: Api,
  st: State,
  key: string,
  text: string,
  cands: Entry[],
): Promise<Picked> {
  const now = await $.clock.now()
  if (now < st.rerank.until) return nothing('paused')
  const answer = await askRerank($, st, text, cands, now)
  const ms = (await $.clock.now()) - now
  if (answer === undefined) return { ...nothing('timeout'), ms }
  const picked = picksOf(answer, cands)
  if (picked.length === 0) return { ...nothing('none'), ms }
  const taken = claimPicks(st, key, picked)
  const block = recallBlock(
    picked.filter(e => taken.includes(e.id)).map(recallLine), RECALL_CAP)
  if (block === '') return { ...nothing('refused'), ms }
  return { block, ids: taken, outcome: 'injected', ms }
}
```

In `recallFor`, replace the `record` literal:

```ts
  const record = {
    at: await $.clock.now(), session: ask.at.id, agent: 'main',
    ids: got.ids, trigger: ask.trigger, outcome: got.outcome,
    cands: cands.length, ...(got.ms === undefined ? {} : { ms: got.ms }),
  }
```

- [ ] **Step 4: Run the suite, see it pass**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/mods.test.sh </dev/null`
Expected: every check PASS, including `memory: plugin test passed`.

- [ ] **Step 5: Commit**

```bash
git add mods/memory/hooks/register.ts mods/memory/hooks/register.test.ts
git commit -m "feat(memory): log cands and rerank ms on prompt recall"
```

---

### Task 2: Labels, draft and state files

Implements spec §2 (labels.tsv, draft, state). LRN-124 (IDs and enums
only), LRN-027 (machine-readable state), LRN-168 (labels are claims, the
draft is checked).

**Files:**
- Create: `lib/memory-feedback/labels.ts`
- Test: `lib/memory-feedback/labels.test.ts`

**Interfaces:**
- Produces: `Channel`, `Label`, `Item`, `Row`, `Draft`, `State` types;
  `keyOf(r: { session: string; at: number; channel: string }): string`;
  `toLine(r: Row): string`; `fromLine(line: string): Row | undefined`;
  `writeSafe(file: string, text: string): void`;
  `readRows(file: string): Row[]`; `writeRows(file: string, rows: Row[]):
  void`; `readState(file: string): State`; `writeState(file: string, s:
  State): void`; `parseDraft(text: string, items: Item[]): Draft[] |
  string`; `rowsOf(it: Item, drafts: Draft[]): Row[]`.

- [ ] **Step 1: Write the failing tests**

`lib/memory-feedback/labels.test.ts`:

```ts
import { expect, test } from 'bun:test'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import {
  fromLine, parseDraft, readRows, readState, rowsOf, toLine, writeRows,
  writeState, type Item, type Row,
} from './labels.ts'

const item = (n: number, over: Partial<Item> = {}): Item => ({
  n, root: 'r', session: `s${n}`, at: 1000 + n, channel: 'prompt',
  trigger: 'fresh', outcome: 'injected', cands: 4, ms: 900,
  ids: ['BDR-001', 'LRN-002'], cited: ['BDR-001'], lost: false, ...over,
})
const ITEMS = [item(1), item(2, { ids: [], outcome: 'none' })]
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'mf-'))

test('L1: a row survives the TSV round trip', () => {
  const r: Row = { at: 5, root: 'r', session: 's', channel: 'tool',
    trigger: 'tool', outcome: 'injected', cands: undefined, ms: undefined,
    pick: 1, id: 'BLK-003', cited: true, label: 'relevant', cause: '' }
  expect(fromLine(toLine(r))).toEqual(r)
  expect(fromLine('at\troot')).toBeUndefined()
})

test('L2: a complete draft parses', () => {
  const d = parseDraft([
    '1\tBDR-001\trelevant', '1\tLRN-002\tirrelevant',
    '2\tBDR-009\tmissed\tno-overlap', '1\t-\tchecked', '# note',
  ].join('\n'), ITEMS)
  expect(Array.isArray(d) && d.length).toBe(4)
})

test('L3: every bad draft is refused with a reason', () => {
  const bad = [
    '1\tBDR-001\tmaybe',                       // unknown label
    '9\tBDR-001\trelevant',                    // unknown item
    '1\tBLK-777\trelevant\n1\tBDR-001\trelevant\n1\tLRN-002\trelevant',
    '1\tBDR-001\trelevant',                    // LRN-002 unlabelled
    '1\tBDR-001\trelevant\n1\tBDR-001\trelevant\n1\tLRN-002\trelevant',
    '1\tBDR-001\trelevant\n1\tLRN-002\trelevant\n2\tBDR-001\tmissed\tbad',
    '1\tBDR-001\trelevant\n1\tLRN-002\tmissed\tdeclined',
  ]
  for (const text of bad) expect(typeof parseDraft(text, ITEMS)).toBe('string')
})

test('L4: test - marks a whole item, no entry label needed', () => {
  expect(Array.isArray(parseDraft('1\t-\ttest', ITEMS))).toBe(true)
})

test('L5: a lost item takes no label', () => {
  const lost = [item(1, { lost: true })]
  expect(typeof parseDraft('1\tBDR-001\trelevant', lost)).toBe('string')
  expect(parseDraft('', lost)).toEqual([])
})

test('L6: rowsOf writes an ask row then the entry rows', () => {
  const d = parseDraft('1\tBDR-001\trelevant\n1\tLRN-002\tirrelevant',
    [item(1)])
  if (typeof d === 'string') throw new Error(d)
  const rows = rowsOf(item(1), d)
  expect(rows.map(r => [r.label, r.id, r.pick, r.cited])).toEqual([
    ['ask', '', undefined, false],
    ['relevant', 'BDR-001', 1, true],
    ['irrelevant', 'LRN-002', 2, false],
  ])
  expect(rowsOf(item(3, { lost: true }), [])[0]?.label).toBe('lost')
})

test('L7: files are 0600 in a 0700 dir, state defaults', () => {
  const dir = path.join(tmp(), 'mf')
  writeRows(path.join(dir, 'labels.tsv'), rowsOf(item(1), []))
  expect(fs.statSync(dir).mode & 0o777).toBe(0o700)
  expect(fs.statSync(path.join(dir, 'labels.tsv')).mode & 0o777)
    .toBe(0o600)
  expect(readRows(path.join(dir, 'labels.tsv'))).toHaveLength(1)
  expect(readState(path.join(dir, 'state.json')))
    .toEqual({ lastRun: 0, toolExtended: false })
  writeState(path.join(dir, 'state.json'), { lastRun: 9, toolExtended: true })
  expect(readState(path.join(dir, 'state.json')))
    .toEqual({ lastRun: 9, toolExtended: true })
})
```

- [ ] **Step 2: Run, see them fail**

Run: `cd lib/memory-feedback && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bun test labels.test.ts </dev/null`
Expected: FAIL, `Cannot find module './labels.ts'`.

- [ ] **Step 3: Write `labels.ts`**

```ts
// lib/memory-feedback/labels.ts: labels.tsv rows, the labeller's draft and
// state.json (phase 4d). IDs and enums only, never text (LRN-124).
import * as fs from 'node:fs'
import * as path from 'node:path'

export type Channel = 'prompt' | 'tool'
export type Label = 'relevant' | 'irrelevant' | 'test' | 'missed' |
  'checked' | 'ask' | 'lost'
const DRAFT_LABELS = ['relevant', 'irrelevant', 'test', 'missed', 'checked']
const ENTRY_LABELS = ['relevant', 'irrelevant', 'test']
const CAUSES = ['no-overlap', 'rank-over-30', 'declined', 'not-triggered']
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
  pick?: number; id: string; cited: boolean; label: Label; cause: string
}
export type Draft = { item: number; id: string; label: Label; cause: string }
export type State = { lastRun: number; toolExtended: boolean }

const COLS = ['at', 'root', 'session', 'channel', 'trigger', 'outcome',
  'cands', 'ms', 'pick', 'id', 'cited', 'label', 'cause']

/** One record's identity: session ids are unique across repos. */
export const keyOf = (r: { session: string; at: number; channel: string }) =>
  `${r.session}|${r.at}|${r.channel}`

const num = (v: number | undefined) => v === undefined ? '' : String(v)
const opt = (s: string | undefined) =>
  s === undefined || s === '' ? undefined : Number(s)

export function toLine(r: Row): string {
  return [r.at, r.root, r.session, r.channel, r.trigger, r.outcome,
    num(r.cands), num(r.ms), num(r.pick), r.id, r.cited ? '1' : '0',
    r.label, r.cause].join('\t')
}

/** A labels.tsv line as a row; the header or a short line: undefined. */
export function fromLine(line: string): Row | undefined {
  const f = line.split('\t')
  if (f.length !== COLS.length || f[0] === 'at') return undefined
  return {
    at: Number(f[0]), root: f[1] ?? '', session: f[2] ?? '',
    channel: f[3] as Channel, trigger: f[4] ?? '', outcome: f[5] ?? '',
    cands: opt(f[6]), ms: opt(f[7]), pick: opt(f[8]), id: f[9] ?? '',
    cited: f[10] === '1', label: f[11] as Label, cause: f[12] ?? '',
  }
}

/** Writes through a 0600 temp file and a rename; the dir is made 0700. */
export function writeSafe(file: string, text: string): void {
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 })
  const tmp = `${file}.${process.pid}.tmp`
  fs.writeFileSync(tmp, text, { mode: 0o600 })
  fs.renameSync(tmp, file)
}

export function readRows(file: string): Row[] {
  if (!fs.existsSync(file)) return []
  return fs.readFileSync(file, 'utf8').split('\n').map(fromLine)
    .filter((r): r is Row => r !== undefined)
}

export function writeRows(file: string, rows: Row[]): void {
  writeSafe(file, [COLS.join('\t'), ...rows.map(toLine)].join('\n') + '\n')
}

/** state.json; absent or unreadable gives a first-run state. */
export function readState(file: string): State {
  try {
    const s = JSON.parse(fs.readFileSync(file, 'utf8'))
    return { lastRun: Number(s.lastRun) || 0,
      toolExtended: s.toolExtended === true }
  } catch {
    return { lastRun: 0, toolExtended: false }
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
  if (!DRAFT_LABELS.includes(label)) return `bad label: ${label}`
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
  const got = drafts.filter(d => d.id !== '-' &&
    ENTRY_LABELS.includes(d.label)).map(d => `${d.item}:${d.id}`)
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
  const head: Row = { ...base(it), id: '', cited: false,
    label: it.lost ? 'lost' : 'ask', cause: '' }
  const mine = drafts.filter(d => d.item === it.n).map((d): Row => ({
    ...base(it), id: d.id === '-' ? '' : d.id,
    pick: it.ids.includes(d.id) ? it.ids.indexOf(d.id) + 1 : undefined,
    cited: it.cited.includes(d.id), label: d.label, cause: d.cause,
  }))
  return [head, ...mine]
}
```

- [ ] **Step 4: Run, see them pass**

Run: `cd lib/memory-feedback && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bun test labels.test.ts </dev/null`
Expected: 7 pass, 0 fail.

- [ ] **Step 5: Commit**

```bash
git add lib/memory-feedback/labels.ts lib/memory-feedback/labels.test.ts
git commit -m "feat(memory-feedback): labels, draft validation and state"
```

---

### Task 3: Thresholds and metrics (4d.3, pure)

Implements spec §4. BDR-100 (thresholds in one file), LRN-241 (test rows
excluded).

**Files:**
- Create: `lib/memory-feedback/thresholds.ts`
- Create: `lib/memory-feedback/metrics.ts`
- Test: `lib/memory-feedback/metrics.test.ts`

**Interfaces:**
- Consumes: `Row`, `Label`, `keyOf` from `./labels.ts` (Task 2).
- Produces:
  `export type Metrics`, `export function metricsOf(rows: Row[]): Metrics`,
  `export type Verdict = { prompt: Gate; tool: ToolGate; extendTool: boolean }`,
  `export function gateVerdict(m: Metrics, now: number, extended: boolean): Verdict`,
  `export function actionsOf(m: Metrics, v: Verdict): string[]`,
  `export function renderFeedback(m: Metrics, v: Verdict, now: number): string`,
  `export function p90(values: number[]): number | undefined`,
  `export function precision(rows: Row[]): number | undefined`.

- [ ] **Step 1: Write `thresholds.ts`**

```ts
// lib/memory-feedback/thresholds.ts: phase 4d gate numbers and threshold
// actions, fixed before the data (BDR-100: one file; the reader and a
// future /prune-memory step read it). Spec §4.
export const DAY_MS = 86400000
export const GATE_DAYS = 35 // the 5-week cap from the gate clock start
export const PROMPT_GATE_N = 20 // labelled injected prompt asks
export const TOOL_GATE_N = 10 // labelled tool injections

export const T = {
  promptKeep: 0.64, // relevant / labelled entries (4c baseline 14/22)
  triggerFloor: 0.5, // worst trigger kind under this gets tightened
  thirdPick: 0.4, // 3rd pick precision under this caps picks at 2
  lateShare: 0.25, // timeout + paused among asks with candidates
  msP90: 2500, // rerank p90 under this lowers RERANK_MS
  toolKeep: 0.5, // tool precision under this narrows the match
  missShare: 1 / 3, // sampled asks with a miss, at or over this
  noisyHits: 3, // injected this often and never relevant: noisy
  promoteHits: 3, // relevant this often...
  promoteSessions: 2, // ...in this many sessions: promotion candidate
} as const
```

- [ ] **Step 2: Write the failing tests**

`lib/memory-feedback/metrics.test.ts`:

```ts
import { expect, test } from 'bun:test'
import { DAY_MS, GATE_DAYS } from './thresholds.ts'
import {
  actionsOf, gateVerdict, metricsOf, p90, precision, renderFeedback,
  type Metrics,
} from './metrics.ts'
import type { Label, Row } from './labels.ts'

let clock = 1000
/** A labels.tsv row; each call gets its own `at` unless given. */
function row(over: Partial<Row> & { label: Label }): Row {
  clock += 1
  return { at: clock, root: 'r', session: 's1', channel: 'prompt',
    trigger: 'fresh', outcome: 'injected', cands: 3, ms: 900,
    id: 'BDR-001', cited: false, cause: '', ...over }
}
/** One injected ask with entries labelled `labels`, picks 1..n. */
function ask(labels: Label[], over: Partial<Row> = {}): Row[] {
  const at = (clock += 10)
  const head = row({ ...over, at, id: '', label: 'ask' })
  return [head, ...labels.map((label, i) => row({ ...over, at, label,
    id: `LRN-00${i + 1}`, pick: i + 1 }))]
}

test('M1: precision and p90', () => {
  const r = ask(['relevant', 'irrelevant', 'relevant', 'relevant'])
  expect(precision(r)).toBe(0.75)
  expect(precision([])).toBeUndefined()
  expect(p90([5, 1, 9, 3, 7, 2, 8, 4, 6, 10])).toBe(9)
  expect(p90([])).toBeUndefined()
})

test('M2: a test row excludes its whole item', () => {
  const rows = [...ask(['relevant']), ...ask(['irrelevant', 'test'])]
  const m = metricsOf(rows)
  expect(m.precision).toBe(1)
  expect(m.promptN).toBe(1)
})

test('M3: noisy at 3 hits, promotion at 3 in 2 sessions', () => {
  const noisy = [1, 2, 3].flatMap(() => ask(['irrelevant']))
  expect(metricsOf(noisy).noisy).toEqual(['LRN-001'])
  expect(metricsOf(noisy.slice(0, 4)).noisy).toEqual([])
  const one = [1, 2, 3].flatMap(() => ask(['relevant']))
  expect(metricsOf(one).promote).toEqual([])
  const two = [...one, ...ask(['relevant'], { session: 's2' })]
  expect(metricsOf(two).promote).toEqual(['LRN-001'])
})

test('M4: late share counts asks with candidates only', () => {
  const rows = [
    row({ id: '', label: 'ask', outcome: 'timeout' }),
    row({ id: '', label: 'ask', outcome: 'paused' }),
    row({ id: '', label: 'ask', outcome: 'none', cands: 0 }),
    ...ask(['relevant']),
  ]
  expect(metricsOf(rows).late).toBeCloseTo(2 / 3)
})

/** Metrics with `n` prompt asks and `t` tool injections, clock at 0. */
function m(n: number, t: number): Metrics {
  const p = Array.from({ length: n }, () => ask(['relevant'])).flat()
  const tl = Array.from({ length: t }, () =>
    ask(['relevant'], { channel: 'tool', trigger: 'tool', cands: undefined }))
  return { ...metricsOf([...p, ...tl]), start: 0 }
}
const CAP = GATE_DAYS * DAY_MS

test('M5: the prompt gate at 20 asks or at the cap', () => {
  expect(gateVerdict(m(19, 0), 1, false).prompt).toBe('open')
  expect(gateVerdict(m(20, 0), 1, false).prompt).toBe('reached')
  expect(gateVerdict(m(3, 0), CAP, false).prompt).toBe('reached')
  const none = { ...metricsOf([]), start: undefined }
  expect(gateVerdict(none, CAP * 9, false))
    .toEqual({ prompt: 'open', tool: 'open', extendTool: false })
})

test('M6: the tool gate extends once, then closes', () => {
  expect(gateVerdict(m(0, 10), 1, false).tool).toBe('reached')
  expect(gateVerdict(m(0, 9), CAP - 1, false).tool).toBe('open')
  expect(gateVerdict(m(0, 9), CAP, false))
    .toMatchObject({ tool: 'extended', extendTool: true })
  expect(gateVerdict(m(0, 9), 2 * CAP - 1, true))
    .toMatchObject({ tool: 'extended', extendTool: false })
  expect(gateVerdict(m(0, 9), 2 * CAP, true).tool).toBe('insufficient')
})

test('M7: actions only once a gate is reached', () => {
  const idle = Array.from({ length: 20 }, (_, i) =>
    ask([i % 3 === 0 ? 'relevant' : 'irrelevant'], { trigger: 'idle' }))
    .flat() // 7/20 relevant: under 64 % overall and under 50 % for idle
  const mm = { ...metricsOf(idle), start: 0 }
  expect(actionsOf(mm, gateVerdict(mm, 1, false)))
    .toContain('prompt precision under 64 %: tighten or drop the idle trigger')
  const open = { ...mm, promptN: 2 }
  expect(actionsOf(open, gateVerdict(open, 1, false))).toEqual([])
})

test('M8: rerank latency actions', () => {
  const slow = Array.from({ length: 20 }, () =>
    ask(['relevant'], { ms: 2400 })).flat()
  const mm = { ...metricsOf(slow), start: 0 }
  expect(actionsOf(mm, gateVerdict(mm, 1, false)))
    .toContain('rerank p90 under 2500 ms: lower RERANK_MS')
})

test('M9: FEEDBACK.md has no repo name and no prompt text', () => {
  const rows = ask(['relevant'], { root: 'secret-client-repo' })
  const text = renderFeedback(metricsOf(rows),
    gateVerdict(metricsOf(rows), 1, false), 0)
  expect(text).not.toContain('secret-client-repo')
  expect(text).toContain('Prompt gate: open (1/20)')
})
```

- [ ] **Step 3: Run, see them fail**

Run: `cd lib/memory-feedback && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bun test metrics.test.ts </dev/null`
Expected: FAIL, `Cannot find module './metrics.ts'`.

- [ ] **Step 4: Write `metrics.ts`**

```ts
// lib/memory-feedback/metrics.ts: phase 4d metrics, gate verdicts and the
// FEEDBACK.md text, computed from labels.tsv rows only (transcripts expire
// at 7 days, the rows stay). Spec §4.
import {
  DAY_MS, GATE_DAYS, PROMPT_GATE_N, T, TOOL_GATE_N,
} from './thresholds.ts'
import { keyOf, type Row } from './labels.ts'

export type Gate = 'open' | 'reached'
export type ToolGate = Gate | 'extended' | 'insufficient'
export type Verdict = { prompt: Gate; tool: ToolGate; extendTool: boolean }
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

/** Rows of items with no `test` row anywhere (LRN-241). */
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

/** timeout + paused share among asks that had candidates. */
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

/** IDs injected noisyHits times or more and never relevant. */
function noisy(entries: Row[]): string[] {
  return [...new Set(entries.map(r => r.id))].filter(id => {
    const mine = entries.filter(r => r.id === id)
    return mine.length >= T.noisyHits &&
      mine.every(r => r.label !== 'relevant')
  }).sort()
}

/** IDs relevant promoteHits times in promoteSessions sessions or more. */
function promote(entries: Row[]): string[] {
  const rel = entries.filter(r => r.label === 'relevant')
  return [...new Set(rel.map(r => r.id))].filter(id => {
    const mine = rel.filter(r => r.id === id)
    return mine.length >= T.promoteHits &&
      new Set(mine.map(r => r.session)).size >= T.promoteSessions
  }).sort()
}

/** Distinct labelled items of a channel. */
const itemsOf = (entries: Row[], ch: string) =>
  new Set(entries.filter(r => r.channel === ch).map(keyOf)).size

/** Every 4d signal; the clock starts at the first row carrying cands. */
export function metricsOf(all: Row[]): Metrics {
  const rows = liveRows(all)
  const entries = rows.filter(isEntry)
  const prompt = entries.filter(r => r.channel === 'prompt')
  const asks = rows.filter(r => r.channel === 'prompt' && r.label === 'ask')
  const starts = all.filter(r => r.cands !== undefined).map(r => r.at)
  const miss = misses(rows)
  return {
    start: starts.length === 0 ? undefined : Math.min(...starts),
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

function toolGate(n: number, now: number, cap: number, ext: boolean):
  { tool: ToolGate; extendTool: boolean } {
  if (n >= TOOL_GATE_N) return { tool: 'reached', extendTool: false }
  if (now < cap) return { tool: 'open', extendTool: false }
  if (!ext) return { tool: 'extended', extendTool: true }
  if (now < cap + GATE_DAYS * DAY_MS) {
    return { tool: 'extended', extendTool: false }
  }
  return { tool: 'insufficient', extendTool: false }
}

/** Each channel's gate; the prompt gate never waits for the tool gate. */
export function gateVerdict(m: Metrics, now: number, ext: boolean): Verdict {
  if (m.start === undefined) {
    return { prompt: 'open', tool: 'open', extendTool: false }
  }
  const cap = m.start + GATE_DAYS * DAY_MS
  const prompt: Gate =
    m.promptN >= PROMPT_GATE_N || now >= cap ? 'reached' : 'open'
  return { prompt, ...toolGate(m.toolN, now, cap, ext) }
}

/** The worst trigger under the floor; ties go idle, keyword, fresh. */
function worstTrigger(by: Record<string, Rate>): string | undefined {
  const order = ['idle', 'keyword', 'fresh']
  const low = order.filter(k => under(by[k], T.triggerFloor))
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
  out.push(...m.noisy.map(id => `noisy: /prune-memory rewrites ${id}`))
  out.push(...m.promote.map(id => `promotion candidate (BDR-100): ${id}`))
  return out
}

function toolLine(m: Metrics, v: Verdict): string {
  const n = `${m.toolN}/${TOOL_GATE_N}`
  return v.tool === 'insufficient'
    ? `Tool gate: insufficient sample n=${m.toolN}, closed`
    : `Tool gate: ${v.tool} (${n})`
}

/** FEEDBACK.md: counts and shares, IDs only in the last three lists. */
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
```

- [ ] **Step 5: Run, see them pass**

Run: `cd lib/memory-feedback && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bun test labels.test.ts metrics.test.ts </dev/null`
Expected: 16 pass, 0 fail.

- [ ] **Step 6: Commit**

```bash
git add lib/memory-feedback/thresholds.ts lib/memory-feedback/metrics.ts lib/memory-feedback/metrics.test.ts
git commit -m "feat(memory-feedback): thresholds, metrics and gate verdicts"
```

---

### Task 4: Transcript join

Implements spec §2 (join). EVAL-037 (one record per content block),
LRN-261 (the mod's types imported, not ported).

**Files:**
- Create: `lib/memory-feedback/transcripts.ts`
- Test: `lib/memory-feedback/transcripts.test.ts`

**Interfaces:**
- Consumes: `type LogRecord` from `../../mods/memory/hooks/register.ts`
  (Task 1).
- Produces: `type Rec`; `JOIN_MS`; `slugOf(root: string): string`;
  `sessionFiles(projects: string, root: string, session: string):
  string[]`; `records(file: string): Rec[]`; `composerText(r: Rec): string
  | undefined`; `type PromptJoin = { prompt: string; injected: string;
  reply: string }`; `joinPrompt(recs: Rec[], rec: LogRecord): PromptJoin |
  undefined`; `type ToolJoin = { command: string; known: string; next:
  boolean[] }`; `joinTool(recs: Rec[], rec: LogRecord): ToolJoin |
  undefined`.

- [ ] **Step 1: Write the failing tests**

`lib/memory-feedback/transcripts.test.ts`:

```ts
import { expect, test } from 'bun:test'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import type { LogRecord } from '../../mods/memory/hooks/register.ts'
import {
  composerText, joinPrompt, joinTool, records, sessionFiles, slugOf,
  type Rec,
} from './transcripts.ts'

const T0 = Date.parse('2026-11-10T10:00:00.000Z')
const iso = (ms: number) => new Date(T0 + ms).toISOString()
const user = (ms: number, text: string): Rec => ({ type: 'user',
  timestamp: iso(ms), origin: { kind: 'human' }, message: { content: text } })
const said = (ms: number, id: string, text: string): Rec => ({
  type: 'assistant', timestamp: iso(ms),
  message: { id, content: [{ type: 'text', text }] } })
const hook = (ms: number, name: string, lines: string[], use?: string) => ({
  type: 'attachment', timestamp: iso(ms), attachment: {
    type: 'hook_additional_context', hookName: name, content: lines,
    ...(use ? { toolUseID: use } : {}) } })
const rec = (over: Partial<LogRecord>): LogRecord => ({ at: T0, session: 's',
  agent: 'main', channel: 'prompt', ids: ['BDR-001'], trigger: 'fresh',
  outcome: 'injected', ...over })

test('X1: slug, files and a torn line', () => {
  expect(slugOf('/home/a.b/c_d')).toBe('-home-a-b-c-d')
  const p = fs.mkdtempSync(path.join(os.tmpdir(), 'mf-'))
  const dir = path.join(p, slugOf('/r'))
  fs.mkdirSync(path.join(dir, 's', 'subagents'), { recursive: true })
  fs.writeFileSync(path.join(dir, 's.jsonl'), '{"a":1}\n{"torn')
  fs.writeFileSync(path.join(dir, 's', 'subagents', 'x.jsonl'), '{"b":2}\n')
  const files = sessionFiles(p, '/r', 's')
  expect(files.map(f => path.basename(f))).toEqual(['s.jsonl', 'x.jsonl'])
  expect(records(files[0]!)).toEqual([{ a: 1 }])
  expect(sessionFiles(p, '/r', 'gone')).toEqual([])
})

test('X2: composer prompts only', () => {
  expect(composerText(user(0, 'fix the gate'))).toBe('fix the gate')
  expect(composerText(user(0, '/close'))).toBeUndefined()
  expect(composerText(user(0, '<system-reminder>x'))).toBeUndefined()
  expect(composerText({ ...user(0, 'x'), origin: { kind: 'sdk' } }))
    .toBeUndefined()
  expect(composerText({ ...user(0, 'x'), isSidechain: true }))
    .toBeUndefined()
})

test('X3: an injected ask joins prompt, block and deduped reply', () => {
  const recs = [
    user(-100, 'design the gate'),
    hook(800, 'prompt.submit', ['memory: note', 'memory recall:\nBDR-001 x']),
    said(2000, 'm1', 'see BDR-001'), said(2000, 'm1', 'see BDR-001'),
    said(2100, 'm1', 'done'),
    user(9000, 'next ask'), said(9500, 'm2', 'later'),
  ]
  expect(joinPrompt(recs, rec({}))).toEqual({ prompt: 'design the gate',
    injected: 'memory recall:\nBDR-001 x', reply: 'see BDR-001\ndone' })
})

const JOIN_LATE = 10001 // one ms past JOIN_MS

test('X4: a non-injected ask joins its prompt; no turn is lost', () => {
  const recs = [user(-3000, 'plan the reader')]
  expect(joinPrompt(recs, rec({ outcome: 'timeout', ids: [] })))
    .toEqual({ prompt: 'plan the reader', injected: '', reply: '' })
  expect(joinPrompt([], rec({ outcome: 'none', ids: [] }))).toBeUndefined()
  const late = [user(0, 'x'), hook(JOIN_LATE, 'prompt.submit',
    ['memory recall:\nBDR-001 x'])]
  expect(joinPrompt(late, rec({}))).toBeUndefined()
})

test('X5: a tool record joins command and the next results', () => {
  const recs: Rec[] = [
    { type: 'assistant', timestamp: iso(0), message: { id: 'a', content: [
      { type: 'tool_use', id: 'u1', name: 'Bash',
        input: { command: 'make test' } }] } },
    { type: 'user', timestamp: iso(5), message: { content: [
      { type: 'tool_result', tool_use_id: 'u1', is_error: true }] } },
    hook(10, 'tool.call', ['memory: known BLK-003 — x'], 'u1'),
    { type: 'assistant', timestamp: iso(20), message: { id: 'b', content: [
      { type: 'tool_use', id: 'u2', name: 'Bash', input: {} }] } },
    { type: 'user', timestamp: iso(25), message: { content: [
      { type: 'tool_result', tool_use_id: 'u2', is_error: false }] } },
  ]
  const r = rec({ channel: 'tool', ids: ['BLK-003'], trigger: 'tool' })
  expect(joinTool(recs, r)).toEqual({ command: 'make test',
    known: 'memory: known BLK-003 — x', next: [false] })
  expect(joinTool(recs, { ...r, ids: ['BLK-009'] })).toBeUndefined()
})
```

- [ ] **Step 2: Run, see them fail**

Run: `cd lib/memory-feedback && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bun test transcripts.test.ts </dev/null`
Expected: FAIL, `Cannot find module './transcripts.ts'`.

- [ ] **Step 3: Write `transcripts.ts`**

```ts
// lib/memory-feedback/transcripts.ts: reads Claude Code transcripts and
// joins one injection-log record to the turn it served (phase 4d).
import * as fs from 'node:fs'
import * as path from 'node:path'
import type { LogRecord } from '../../mods/memory/hooks/register.ts'

export type Rec = Record<string, any>
export const JOIN_MS = 10000 // attachment written at most this after `at`
const NEAR_MS = 60000 // composer prompt at most this far from the ask
const WRAPPERS = ['<command-', '<local-command', '<system-reminder']
const RECALL_HEAD = 'memory recall:'
const KNOWN_HEAD = 'memory: known '

/** The transcript folder name of a project root. */
export const slugOf = (root: string) => root.replace(/[^A-Za-z0-9]/g, '-')

/** The main transcript of a session, then its sub-agent ones. */
export function sessionFiles(
  projects: string, root: string, session: string,
): string[] {
  const dir = path.join(projects, slugOf(root))
  const sub = path.join(dir, session, 'subagents')
  const subs = fs.existsSync(sub)
    ? fs.readdirSync(sub).filter(f => f.endsWith('.jsonl')).sort()
      .map(f => path.join(sub, f))
    : []
  return [path.join(dir, `${session}.jsonl`), ...subs]
    .filter(f => fs.existsSync(f))
}

/** Parsed lines of a transcript; a torn or partial line is skipped. */
export function records(file: string): Rec[] {
  const out: Rec[] = []
  for (const raw of fs.readFileSync(file, 'utf8').split('\n')) {
    if (raw.trim() === '') continue
    try { out.push(JSON.parse(raw)) } catch { /* torn line */ }
  }
  return out
}

const tsOf = (r: Rec) => Date.parse(String(r.timestamp ?? ''))

function blocksOf(r: Rec): Rec[] {
  const c = r.message?.content
  return Array.isArray(c) ? c.filter(b => b && typeof b === 'object') : []
}

/** A typed composer prompt (recall-bench's rule); else undefined. */
export function composerText(r: Rec): string | undefined {
  if (r.type !== 'user' || r.isSidechain === true) return undefined
  if (r.isMeta === true || r.isCompactSummary === true) return undefined
  const c = r.message?.content
  if (typeof c !== 'string' || r.origin?.kind !== 'human') return undefined
  const t = c.trim()
  if (t.startsWith('/')) return undefined
  return WRAPPERS.some(w => t.startsWith(w)) ? undefined : t
}

/** The joined text of a `hook` context attachment; else undefined. */
function hookText(r: Rec, hook: string): string | undefined {
  const a = r.attachment
  if (r.type !== 'attachment' || a?.type !== 'hook_additional_context') {
    return undefined
  }
  if (a.hookName !== hook) return undefined
  return Array.isArray(a.content) ? a.content.map(String).join('\n')
    : String(a.content ?? '')
}

/** The earliest `hook` attachment holding `needle` in [at, at+JOIN_MS]. */
function attachmentAfter(
  recs: Rec[], at: number, hook: string, needle: string,
): Rec | undefined {
  let best: Rec | undefined
  for (const r of recs) {
    const t = tsOf(r)
    if (!(t >= at && t <= at + JOIN_MS)) continue
    if (!hookText(r, hook)?.includes(needle)) continue
    if (best === undefined || t < tsOf(best)) best = r
  }
  return best
}

type Prompt = { t: number; text: string }

/** The composer prompt nearest `ts`, within NEAR_MS. */
function promptNear(recs: Rec[], ts: number): Prompt | undefined {
  let best: Prompt | undefined
  for (const r of recs) {
    const text = composerText(r)
    const t = tsOf(r)
    if (text === undefined || Math.abs(t - ts) > NEAR_MS) continue
    if (best === undefined || Math.abs(t - ts) < Math.abs(best.t - ts)) {
      best = { t, text }
    }
  }
  return best
}

/** The first composer prompt after `ts`; Infinity when none. */
function nextPromptAt(recs: Rec[], ts: number): number {
  let end = Infinity
  for (const r of recs) {
    const t = tsOf(r)
    if (t > ts && t < end && composerText(r) !== undefined) end = t
  }
  return end
}

/** Main-thread assistant text after `ts` up to the next prompt. */
function replyAfter(recs: Rec[], ts: number): string {
  const end = nextPromptAt(recs, ts)
  const seen = new Set<string>()
  const parts: string[] = []
  for (const r of recs) {
    const t = tsOf(r)
    if (r.type !== 'assistant' || r.isSidechain === true) continue
    if (!(t > ts && t < end)) continue
    for (const b of blocksOf(r).filter(b => b.type === 'text')) {
      const key = `${r.message?.id}:${b.text}` // EVAL-037
      if (!seen.has(key)) parts.push(String(b.text))
      seen.add(key)
    }
  }
  return parts.join('\n')
}

export type PromptJoin = { prompt: string; injected: string; reply: string }

/** The turn a prompt-channel record served; undefined when lost. */
export function joinPrompt(
  recs: Rec[], rec: LogRecord,
): PromptJoin | undefined {
  if (rec.outcome !== 'injected') {
    const p = promptNear(recs, rec.at)
    return p && { prompt: p.text, injected: '', reply: '' }
  }
  const att = attachmentAfter(recs, rec.at, 'prompt.submit', RECALL_HEAD)
  if (att === undefined) return undefined
  const t = tsOf(att)
  const p = promptNear(recs, t)
  const text = hookText(att, 'prompt.submit') ?? ''
  return { prompt: p?.text ?? '',
    injected: text.slice(text.indexOf(RECALL_HEAD)),
    reply: replyAfter(recs, Math.max(t, p?.t ?? t)) }
}

/** The command of a Bash tool_use. */
function bashCommand(recs: Rec[], useId: string): string {
  for (const b of recs.flatMap(blocksOf)) {
    if (b.type === 'tool_use' && b.id === useId) {
      return String(b.input?.command ?? '')
    }
  }
  return ''
}

/** Whether each of the next 3 Bash results after `useId` failed. */
function nextResults(recs: Rec[], useId: string): boolean[] {
  const bash = new Set<string>()
  const out: boolean[] = []
  let after = false
  for (const b of recs.flatMap(blocksOf)) {
    if (b.type === 'tool_use' && b.name === 'Bash') bash.add(b.id)
    if (b.type !== 'tool_result' || !bash.has(b.tool_use_id)) continue
    if (after && out.length < 3) out.push(b.is_error === true)
    if (b.tool_use_id === useId) after = true
  }
  return out
}

export type ToolJoin = { command: string; known: string; next: boolean[] }

/** The failure a known line answered and the next 3 Bash results. */
export function joinTool(recs: Rec[], rec: LogRecord): ToolJoin | undefined {
  const needle = KNOWN_HEAD + (rec.ids[0] ?? '')
  const att = attachmentAfter(recs, rec.at, 'tool.call', needle)
  const useId = att?.attachment?.toolUseID
  if (att === undefined || typeof useId !== 'string') return undefined
  return { command: bashCommand(recs, useId),
    known: hookText(att, 'tool.call') ?? '',
    next: nextResults(recs, useId) }
}
```

- [ ] **Step 4: Run, see them pass**

Run: `cd lib/memory-feedback && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bun test </dev/null`
Expected: 21 pass, 0 fail (5 transcripts + 7 labels + 9 metrics).

- [ ] **Step 5: Commit**

```bash
git add lib/memory-feedback/transcripts.ts lib/memory-feedback/transcripts.test.ts
git commit -m "feat(memory-feedback): join log records to transcript turns"
```

---

### Task 5: Reader CLI and its suite

Implements spec §2 (commands, population, worksheet, apply). LRN-241
(population from the gate clock), LRN-133 (lost counted), LRN-261 (imports
`isLogRecord` and `LOG_PREFIX`).

**Files:**
- Create: `lib/memory-feedback/reader.ts`
- Test: `lib/memory-feedback/reader.test.ts`
- Create: `lib/tests/memory-feedback.test.sh` (the `make test` entry)

**Interfaces:**
- Consumes: Task 1 `LOG_PREFIX`, `isLogRecord`, `LogRecord`; Task 2
  `keyOf`, `parseDraft`, `readRows`, `readState`, `rowsOf`, `writeRows`,
  `writeSafe`, `writeState`, `Item`; Task 3 `gateVerdict`, `metricsOf`,
  `renderFeedback`; Task 4 `joinPrompt`, `joinTool`, `records`,
  `sessionFiles`, `Rec`.
- Produces: `type Paths = { store: string; projects: string; out: string
  }`; `storeFile(dir: string): string`; `readLogs(file: string): Logged[]`;
  `population(logs: Logged[], labelled: Set<string>): Logged[]`;
  `worksheet(dir: string, p: Paths): number`; `apply(dir: string, p: Paths,
  now: number): string`; CLI `bun reader.ts worksheet|apply <abs dir>`
  (rc 0 ok, 1 error on stderr, 2 usage).

- [ ] **Step 1: Write the failing tests**

`lib/memory-feedback/reader.test.ts`:

```ts
import { expect, test } from 'bun:test'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import { slugOf } from './transcripts.ts'
import {
  apply, population, readLogs, storeFile, worksheet, type Paths,
} from './reader.ts'

const T0 = Date.parse('2026-11-10T10:00:00.000Z')
const iso = (ms: number) => new Date(T0 + ms).toISOString()

/** A fixture home: store, one transcript, an empty out dir, a work dir. */
function fixture(store: unknown): { p: Paths; work: string } {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mf-'))
  const p = { store: path.join(home, 'store'),
    projects: path.join(home, 'projects'), out: path.join(home, 'mf') }
  fs.mkdirSync(p.store)
  fs.writeFileSync(path.join(p.store, 'memory_skills-dir-abc.json'),
    typeof store === 'string' ? store : JSON.stringify(store))
  const dir = path.join(p.projects, slugOf('/repo/x'))
  fs.mkdirSync(dir, { recursive: true })
  fs.writeFileSync(path.join(dir, 's1.jsonl'), [
    { type: 'user', timestamp: iso(-50), origin: { kind: 'human' },
      message: { content: 'design the reader gate' } },
    { type: 'attachment', timestamp: iso(400), attachment: {
      type: 'hook_additional_context', hookName: 'prompt.submit',
      content: ['memory recall:\nBDR-001 x'] } },
    { type: 'assistant', timestamp: iso(900),
      message: { id: 'm', content: [{ type: 'text', text: 'per BDR-001' }] } },
  ].map(r => JSON.stringify(r)).join('\n') + '\n')
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'mf-work-'))
  return { p, work }
}
const REC = (at: number, over = {}) => ({ at, session: 's1', agent: 'main',
  channel: 'prompt', ids: ['BDR-001'], trigger: 'fresh',
  outcome: 'injected', cands: 5, ms: 800, ...over })
const STORE = { 'l:/repo/x': [
  REC(T0 - 9e6, { cands: undefined }),  // before 4d.1: out of population
  REC(T0), REC(T0 + 60000, { session: 'gone' }),  // second one lost
], 'p:/repo/x': { sessions: [] } }

test('R1: no store file, or a torn one, fails loudly', () => {
  const { p } = fixture('{"l:/x": [tor')
  expect(() => readLogs(storeFile(p.store))).toThrow('unreadable')
  expect(() => storeFile(path.join(p.store, 'none'))).toThrow('no memory')
})

test('R2: population starts at the first cands record, skips labelled', () => {
  const { p } = fixture(STORE)
  const logs = readLogs(storeFile(p.store))
  expect(population(logs, new Set()).map(l => l.rec.at))
    .toEqual([T0, T0 + 60000])
  expect(population(logs, new Set([`s1|${T0}|prompt`]))).toHaveLength(1)
  expect(population(logs.slice(0, 1), new Set())).toEqual([])
})

test('R3: worksheet writes 0600 text files and a lost item', () => {
  const { p, work } = fixture(STORE)
  expect(worksheet(work, p)).toBe(2)
  const sheet = fs.readFileSync(path.join(work, 'worksheet.md'), 'utf8')
  expect(sheet).toContain('design the reader gate')
  expect(sheet).toContain('LOST')
  for (const f of ['worksheet.md', 'items.json']) {
    expect(fs.statSync(path.join(work, f)).mode & 0o777).toBe(0o600)
  }
  const items = JSON.parse(fs.readFileSync(
    path.join(work, 'items.json'), 'utf8'))
  expect(items.map((i: { cited: string[]; lost: boolean }) =>
    [i.cited, i.lost])).toEqual([[['BDR-001'], false], [[], true]])
})

test('R4: a bad draft refuses the whole apply, nothing written', () => {
  const { p, work } = fixture(STORE)
  worksheet(work, p)
  fs.writeFileSync(path.join(work, 'labels-draft.tsv'), '1\tBDR-001\tmaybe')
  expect(() => apply(work, p, T0)).toThrow('draft refused')
  expect(fs.existsSync(p.out)).toBe(false)
})

test('R5: apply writes labels, state, FEEDBACK; a second apply refuses',
  () => {
    const { p, work } = fixture(STORE)
    worksheet(work, p)
    fs.writeFileSync(path.join(work, 'labels-draft.tsv'),
      '1\tBDR-001\trelevant\n')
    const fb = apply(work, p, T0 + 1)
    expect(fb).toContain('Prompt gate: open (1/20)')
    expect(fb).toContain('Lost records: 1')
    expect(fb).not.toContain('design the reader gate')
    const labels = fs.readFileSync(path.join(p.out, 'labels.tsv'), 'utf8')
    expect(labels).not.toContain('design the reader gate')
    expect(labels).not.toContain('/repo/x')
    expect(JSON.parse(fs.readFileSync(path.join(p.out, 'state.json'),
      'utf8')).lastRun).toBe(T0 + 1)
    expect(() => apply(work, p, T0 + 2)).toThrow('already applied')
    expect(worksheet(work, p)).toBe(0)
  })

test('R6: a first run with nothing to label records the run only', () => {
  const { p, work } = fixture({ 'l:/repo/x': [REC(T0, { cands: undefined })] })
  expect(worksheet(work, p)).toBe(0)
  expect(fs.readFileSync(path.join(work, 'worksheet.md'), 'utf8'))
    .toContain('No unlabelled record')
  expect(apply(work, p, T0)).toContain('Gate clock start: not started')
  expect(fs.existsSync(path.join(p.out, 'state.json'))).toBe(true)
})
```

- [ ] **Step 2: Write the suite entry `lib/tests/memory-feedback.test.sh`**

```bash
#!/usr/bin/env bash
# lib/tests/memory-feedback.test.sh — the bun unit suite of
# lib/memory-feedback (phase 4d reader, labels, metrics, transcripts).
# Fails when bun is absent: it never passes vacuously.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
command -v bun >/dev/null 2>&1 || { echo "FAIL bun not on PATH"; exit 1; }
cd "$ROOT/lib/memory-feedback" || exit 1
bun test 2>&1
```

Then `chmod +x lib/tests/memory-feedback.test.sh`.

- [ ] **Step 3: Run, see the reader tests fail**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash lib/tests/memory-feedback.test.sh </dev/null`
Expected: FAIL, `Cannot find module './reader.ts'`; the 21 earlier tests
still pass.

- [ ] **Step 4: Write `reader.ts`**

```ts
#!/usr/bin/env bun
// lib/memory-feedback/reader.ts: phase 4d reader. `worksheet <dir>` joins
// the unlabelled injection-log records to their transcripts; `apply <dir>`
// validates the labeller's draft, appends labels.tsv and regenerates
// FEEDBACK.md. Text only ever lands in <dir>, the session scratchpad.
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import {
  LOG_PREFIX, isLogRecord, type LogRecord,
} from '../../mods/memory/hooks/register.ts'
import {
  keyOf, parseDraft, readRows, readState, rowsOf, writeRows, writeSafe,
  writeState, type Item,
} from './labels.ts'
import { gateVerdict, metricsOf, renderFeedback } from './metrics.ts'
import {
  joinPrompt, joinTool, records, sessionFiles, type Rec,
} from './transcripts.ts'

export type Paths = { store: string; projects: string; out: string }
export type Logged = { root: string; rec: LogRecord }
type Base = Omit<Item, 'cited' | 'lost'>
type Joined = { item: Item; text: string }

const PROMPT_MAX = 600
const REPLY_MAX = 800
const DRAFT_HELP = [
  'Write labels-draft.tsv next to this file, one TAB-separated line each:',
  '`<item> <id> <label> [<cause>]`. Labels: `relevant` or `irrelevant` per',
  'injected id; `test` per id, or `<item> - test` for a whole proof item;',
  '`<item> <id> missed <cause>` (no-overlap, rank-over-30, declined,',
  'not-triggered); `<item> - checked` for a sampled ask with no miss.',
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

/** Every valid log record of every root, oldest first. */
export function readLogs(file: string): Logged[] {
  let data: unknown
  try {
    data = JSON.parse(fs.readFileSync(file, 'utf8'))
  } catch {
    throw new Error(`store file unreadable (${file}): retry in a moment`)
  }
  if (typeof data !== 'object' || data === null) {
    throw new Error(`store file is not an object: ${file}`)
  }
  const out: Logged[] = []
  for (const [k, v] of Object.entries(data)) {
    if (!k.startsWith(LOG_PREFIX) || !Array.isArray(v)) continue
    const root = k.slice(LOG_PREFIX.length)
    for (const rec of v.filter(isLogRecord)) out.push({ root, rec })
  }
  return out.sort((a, b) => a.rec.at - b.rec.at)
}

/** Records from the gate clock start on, not labelled yet (LRN-241). */
export function population(logs: Logged[], done: Set<string>): Logged[] {
  const starts = logs.filter(l => l.rec.cands !== undefined)
    .map(l => l.rec.at)
  if (starts.length === 0) return []
  const start = Math.min(...starts)
  return logs.filter(l => l.rec.at >= start && !done.has(keyOf(l.rec)))
}

const cut = (s: string, n: number) =>
  s.length <= n ? s : `${s.slice(0, n)}…`
const citedIn = (ids: string[], text: string) =>
  ids.filter(id => new RegExp(`\\b${id}\\b`).test(text))

function header(b: Base, lost: boolean): string {
  const ids = b.ids.join(' ') || '-'
  return `## Item ${b.n}: ${b.channel}/${b.trigger}/${b.outcome}` +
    ` · cands ${b.cands ?? '-'} · ms ${b.ms ?? '-'} · ${b.root}` +
    ` · ids ${ids}${lost ? ' · LOST (no transcript turn)' : ''}`
}

const lostItem = (b: Base): Joined =>
  ({ item: { ...b, cited: [], lost: true }, text: header(b, true) })

function promptItem(b: Base, recs: Rec[], rec: LogRecord): Joined {
  const j = joinPrompt(recs, rec)
  if (j === undefined) return lostItem(b)
  const cited = citedIn(b.ids, j.reply)
  const text = [header(b, false), `Prompt: ${cut(j.prompt, PROMPT_MAX)}`,
    `Injected:\n${j.injected || '-'}`, `Reply: ${cut(j.reply, REPLY_MAX)}`,
    `Cited: ${cited.join(', ') || 'none'}`].join('\n\n')
  return { item: { ...b, cited, lost: false }, text }
}

function toolItem(b: Base, recs: Rec[], rec: LogRecord): Joined {
  const j = joinTool(recs, rec)
  if (j === undefined) return lostItem(b)
  const next = j.next.map(f => f ? 'failed' : 'ok').join(', ') || 'none'
  const text = [header(b, false), `Command: ${cut(j.command, PROMPT_MAX)}`,
    `Known: ${j.known}`, `Next Bash results: ${next}`].join('\n\n')
  return { item: { ...b, cited: [], lost: false }, text }
}

/** One worksheet item, joined across the session's transcript files. */
function joinOne(l: Logged, n: number, projects: string): Joined {
  const recs = sessionFiles(projects, l.root, l.rec.session)
    .flatMap(records)
  const r = l.rec
  const b: Base = { n, root: path.basename(l.root), session: r.session,
    at: r.at, channel: r.channel, trigger: r.trigger ?? '',
    outcome: r.outcome ?? '', cands: r.cands, ms: r.ms, ids: r.ids }
  return r.channel === 'prompt'
    ? promptItem(b, recs, r) : toolItem(b, recs, r)
}

const labelsOf = (p: Paths) => path.join(p.out, 'labels.tsv')
const stateOf = (p: Paths) => path.join(p.out, 'state.json')

/** Writes worksheet.md and items.json (0600) into `dir`; the count. */
export function worksheet(dir: string, p: Paths): number {
  const done = new Set(readRows(labelsOf(p)).map(keyOf))
  const pop = population(readLogs(storeFile(p.store)), done)
  const joined = pop.map((l, i) => joinOne(l, i + 1, p.projects))
  const head = pop.length === 0
    ? 'No unlabelled record since the gate clock start.'
    : `${pop.length} records to label.`
  writeSafe(path.join(dir, 'worksheet.md'), ['# Memory feedback worksheet',
    head, DRAFT_HELP, ...joined.map(j => j.text)].join('\n\n') + '\n')
  writeSafe(path.join(dir, 'items.json'),
    JSON.stringify(joined.map(j => j.item)))
  return pop.length
}

function readDraft(dir: string): string {
  const f = path.join(dir, 'labels-draft.tsv')
  return fs.existsSync(f) ? fs.readFileSync(f, 'utf8') : ''
}

/** Validates the draft, appends labels.tsv, saves state, FEEDBACK.md. */
export function apply(dir: string, p: Paths, now: number): string {
  const items: Item[] = JSON.parse(
    fs.readFileSync(path.join(dir, 'items.json'), 'utf8'))
  const drafts = parseDraft(readDraft(dir), items)
  if (typeof drafts === 'string') throw new Error(`draft refused: ${drafts}`)
  const old = readRows(labelsOf(p))
  const done = new Set(old.map(keyOf))
  if (items.some(i => done.has(keyOf(i)))) {
    throw new Error('items already applied: run worksheet again')
  }
  const rows = [...old, ...items.flatMap(i => rowsOf(i, drafts))]
  const st = readState(stateOf(p))
  const m = metricsOf(rows)
  const v = gateVerdict(m, now, st.toolExtended)
  const feedback = renderFeedback(m, v, now)
  writeRows(labelsOf(p), rows)
  writeState(stateOf(p),
    { lastRun: now, toolExtended: st.toolExtended || v.extendTool })
  writeSafe(path.join(p.out, 'FEEDBACK.md'), feedback)
  return feedback
}

function main(argv: string[]): number {
  const [cmd, dir] = argv
  const ok = (cmd === 'worksheet' || cmd === 'apply') &&
    dir !== undefined && path.isAbsolute(dir) && fs.existsSync(dir)
  if (!ok) {
    console.error('usage: reader.ts worksheet|apply <absolute existing dir>')
    return 2
  }
  try {
    if (cmd === 'worksheet') {
      console.log(`${worksheet(dir, defaultPaths())} records to label: ` +
        `${dir}/worksheet.md`)
    } else process.stdout.write(apply(dir, defaultPaths(), Date.now()))
    return 0
  } catch (e) {
    console.error(`memory-feedback: ${(e as Error).message}`)
    return 1
  }
}

if (import.meta.main) process.exit(main(process.argv.slice(2)))
```

- [ ] **Step 5: Run the whole suite, see it pass**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash lib/tests/memory-feedback.test.sh </dev/null`
Expected: 27 pass, 0 fail.

Then the usage path: `env PATH="$HOME/.bun/bin:$PATH" bun lib/memory-feedback/reader.ts; echo rc=$?`
Expected: the usage line on stderr, `rc=2`.

- [ ] **Step 6: Commit**

```bash
git add lib/memory-feedback/reader.ts lib/memory-feedback/reader.test.ts lib/tests/memory-feedback.test.sh
git commit -m "feat(memory-feedback): worksheet and apply reader"
```

---

### Task 6: Session-start reminder

Implements spec §3 (reminder). BDR-057 (the 7-day window is why it
exists).

**Files:**
- Create: `lib/memory-feedback-remind.sh`
- Test: `lib/tests/memory-feedback-remind.test.sh`
- Modify: `hooks/session-start.sh:447-455` (inside the `_ss_digest` block,
  before `_memory_digest`)
- Test: `lib/tests/session-digest.test.sh` (new case SD17 before SD15)

**Interfaces:**
- Produces: `bash lib/memory-feedback-remind.sh` prints one line or
  nothing, always rc 0; reads `$HOME/.claude/plugins/store/memory_skills-dir-*.json`
  and `$HOME/.claude/memory-feedback/state.json`.

- [ ] **Step 1: Write the failing suite**

`lib/tests/memory-feedback-remind.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/memory-feedback-remind.test.sh — the phase 4d banner line:
# shown when /memory-feedback never ran, or ran 5+ days ago and the store
# changed since; silent otherwise and on any error.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/memory-feedback-remind.sh"
WORK="$(mktemp -d)" || exit 1
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# home <name>: a fixture HOME with the store and feedback dirs
home() {
  mkdir -p "$WORK/$1/.claude/plugins/store" "$WORK/$1/.claude/memory-feedback"
  echo "$WORK/$1"
}
run() { HOME="$1" bash "$LIB" 2>&1; echo "rc=$?"; }

h=$(home none)
check MR1-no-store "$(run "$h")" "rc=0"

h=$(home never); : > "$h/.claude/plugins/store/memory_skills-dir-a.json"
check MR2-never "$(run "$h")" "memory feedback: never run → /memory-feedback
rc=0"

h=$(home due); S="$h/.claude/plugins/store/memory_skills-dir-a.json"
: > "$h/.claude/memory-feedback/state.json"; : > "$S"
touch -t 202601010000 "$h/.claude/memory-feedback/state.json"
check MR3-due "$(run "$h" | grep -cE \
  '^memory feedback: last run [0-9]+ d ago, transcripts expire at 7 → /memory-feedback$')" 1

h=$(home quiet); S="$h/.claude/plugins/store/memory_skills-dir-a.json"
: > "$h/.claude/memory-feedback/state.json"; : > "$S"
touch -t 202601010000 "$h/.claude/memory-feedback/state.json"
touch -t 202512010000 "$S"
check MR4-store-unchanged "$(run "$h")" "rc=0"

h=$(home fresh); S="$h/.claude/plugins/store/memory_skills-dir-a.json"
: > "$h/.claude/memory-feedback/state.json"; : > "$S"
touch -t 209901010000 "$S"
check MR5-ran-today "$(run "$h")" "rc=0"

printf 'memory-feedback-remind: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

`chmod +x lib/tests/memory-feedback-remind.test.sh`.

- [ ] **Step 2: Run it, see it fail**

Run: `bash lib/tests/memory-feedback-remind.test.sh`
Expected: FAIL on MR2 and MR3 (the lib is absent, `bash` prints an error).

- [ ] **Step 3: Write `lib/memory-feedback-remind.sh`**

```bash
#!/usr/bin/env bash
# lib/memory-feedback-remind.sh — the phase 4d reminder line of the
# session-start banner. Prints one line when /memory-feedback never ran, or
# ran REMIND_DAYS+ days ago and the memory store changed since (transcripts
# live 7 days, BDR-057). Prints nothing otherwise; always rc 0.
# bash 3.2 safe; no JSON parse at session start.
REMIND_DAYS=5

_mf_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

_mf_store() {  # the newest memory store file, or nothing
  local f store=""
  for f in "$HOME"/.claude/plugins/store/memory_skills-dir-*.json; do
    [ -f "$f" ] || continue
    if [ -z "$store" ] || [ "$f" -nt "$store" ]; then store=$f; fi
  done
  printf '%s' "$store"
}

memory_feedback_line() {
  local store state m age
  store=$(_mf_store); [ -n "$store" ] || return 0
  state="$HOME/.claude/memory-feedback/state.json"
  if [ ! -f "$state" ]; then
    echo "memory feedback: never run → /memory-feedback"; return 0
  fi
  [ "$store" -nt "$state" ] || return 0
  m=$(_mf_mtime "$state"); [ -n "$m" ] || return 0
  age=$(( ($(date +%s) - m) / 86400 ))
  [ "$age" -ge "$REMIND_DAYS" ] || return 0
  printf 'memory feedback: last run %s d ago, %s\n' "$age" \
    "transcripts expire at 7 → /memory-feedback"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then memory_feedback_line; fi
exit 0
```

`chmod +x lib/memory-feedback-remind.sh`.

- [ ] **Step 4: Run, see it pass, lint**

Run: `bash lib/tests/memory-feedback-remind.test.sh && shellcheck lib/memory-feedback-remind.sh lib/tests/memory-feedback-remind.test.sh`
Expected: `memory-feedback-remind: 5 passed, 0 failed`, shellcheck clean.

- [ ] **Step 5: Wire it into the banner, test-first**

In `lib/tests/session-digest.test.sh`, add before the `# SD15` block:

```bash
# SD17: the 4d reminder line prints before the digest, never inside it
h17="$WORK/h17"; mkdir -p "$h17/.claude/plugins/store"
: > "$h17/.claude/plugins/store/memory_skills-dir-a.json"
p=$(mkproj sd17); blk "$p" 1 open "Seventeen"
out17=$(cd "$p" && HOME="$h17" bash "$SS" <"$WORK/startup.json" 2>/dev/null)
check SD17-line "$(printf '%s\n' "$out17" | grep -c '^memory feedback: never run')" 1
check SD17-before-digest "$(printf '%s\n' "$out17" \
  | grep -n -e '^memory feedback' -e '^memory digest' | cut -d: -f2 \
  | tr '\n' ' ')" "memory feedback memory digest "
```

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash lib/tests/session-digest.test.sh </dev/null`
Expected: FAIL `SD17-line: got[0] want[1]`.

In `hooks/session-start.sh`, inside `if [ "$_ss_digest" = 1 ]; then`,
first lines of the block (before `_ss_root=...`), in the file's own
timeout convention (the registry-v1 block, lines ~319-322):

```bash
  # phase 4d: the weekly /memory-feedback reminder, bounded, never fatal
  _ss_mf="$(dirname "${BASH_SOURCE[0]}")/../lib/memory-feedback-remind.sh"
  _ss_tmo=(); command -v timeout >/dev/null 2>&1 && _ss_tmo=(timeout 2)
  [ -f "$_ss_mf" ] && { "${_ss_tmo[@]}" bash "$_ss_mf" 2>/dev/null || true; }
  unset _ss_mf _ss_tmo
```

- [ ] **Step 6: Run, see it pass, lint**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash lib/tests/session-digest.test.sh </dev/null && shellcheck hooks/session-start.sh lib/tests/session-digest.test.sh`
Expected: `session-digest: 56 passed, 0 failed` (54 + 2), shellcheck clean.

- [ ] **Step 7: Commit**

```bash
git add lib/memory-feedback-remind.sh lib/tests/memory-feedback-remind.test.sh hooks/session-start.sh lib/tests/session-digest.test.sh
git commit -m "feat(hooks): memory feedback reminder in the banner"
```

---

### Task 7: `/memory-feedback` skill and its router row

Implements spec §3 (skill steps). BDR-129 (registry writes through
memory.sh), LRN-168 (spot check), LRN-073 (fictional IDs in examples).

**Files:**
- Create: `skills/memory-feedback/SKILL.md`
- Modify: `mods/model-router/routing.json` (`"skills"` table, after
  `"reconcile": "apply",` ~line 130)

**Interfaces:**
- Consumes: Task 5 CLI `bun <repo>/lib/memory-feedback/reader.ts
  worksheet|apply <dir>`; `lib/memory.sh add eval|decision`.

- [ ] **Step 1: See the routing census fail on a new skill**

Create `skills/memory-feedback/SKILL.md` with the content of Step 2, then
run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash lib/tests/effort-routing.test.sh </dev/null | grep memory-feedback`
Expected: `FAIL skills/memory-feedback: no row in routing.json` (the file
is untracked until `git add`; run `git add skills/memory-feedback/SKILL.md`
first so `git ls-files` lists it).

- [ ] **Step 2: The skill file**

`skills/memory-feedback/SKILL.md`:

````markdown
---
name: memory-feedback
effort: high
description: Use when the session banner says "memory feedback" is due, or to measure whether memory recall injections help — labels each injected registry entry relevant or irrelevant from the transcript, samples misses, and reports precision and the phase 4d gates. Triggers: "memory feedback", "label recall", "recall precision", "is memory recall useful", "feedback mémoire". NOT registry curation (that is /prune-memory).
---

# /memory-feedback — label recall injections, read the gates

Phase 4d (BDR-125). The memory mod logs every recall ask; transcripts live
7 days, so this runs weekly. Claude labels, the user spot-checks. Text
stays in the scratchpad; `~/.claude/memory-feedback/` keeps IDs and enums
only, never in git.

## STEP 1 — WORKSHEET

```bash
MF="$(cd -P "$HOME/.claude/lib" && pwd)/memory-feedback/reader.ts"
bun "$MF" worksheet "<scratchpad dir, absolute>"
```

rc 1 → print the error and stop (a torn store file: retry once after a few
seconds). `0 records` → go to STEP 5 (records the run, nothing to label).

## STEP 2 — LABEL

Read `<dir>/worksheet.md`. For each item, each injected id gets one line in
`<dir>/labels-draft.tsv` (TAB separated):
- `relevant`: the entry bears on what the prompt asked or what the reply
  did; `irrelevant` otherwise. Judge the entry against the ask, not the
  reply's quality.
- `test`: the session was a proof, a bench or recall testing; `<item> - test`
  marks the whole item.
Lost items take no line.

## STEP 3 — SPOT CHECK

Pick 5 labelled entries at random (`shuf -n 5` over the draft's entry
lines). Show each to the user in one AskUserQuestion: the prompt gist in
your own words (never a secret), the entry title, your label; the user
confirms or flips. Apply the flips to the draft. A label is a claim
(LRN-168).

## STEP 4 — MISSES

On up to 5 prompt items whose outcome is injected or none, search the
registries (`bash ~/.claude/lib/memory.sh index` + entry bodies) for live
entries that bore on the ask and were not injected. Each one:
`<item> <id> missed <cause>` with cause `no-overlap` (no word in common
with the prompt), `rank-over-30`, `declined` (BM25 offered it, haiku did
not pick it), `not-triggered`. A searched item with no miss:
`<item> - checked`. Example line: `3	LRN-901	missed	no-overlap`.

## STEP 5 — APPLY

```bash
bun "$MF" apply "<scratchpad dir>"
```

rc 1 `draft refused: <reason>` → fix the draft, rerun. It prints
FEEDBACK.md: show the gate lines and the Actions list to the user.

## STEP 6 — GATE REACHED

Only when a gate line says `reached` or `insufficient`:
1. Propose the verdict as an EVAL entry (counts and shares from
   FEEDBACK.md, no prompt text) and each Action as a TODO line; the user
   approves each.
2. Write approved entries per `lib/capitalize-commit.md` § WRITE
   (`memory.sh add eval …`; a decided action also gets `add decision`), and
   commit through `lib/capitalize-commit.md` § DO.
Thresholds live in `lib/memory-feedback/thresholds.ts`; never tune them
here (BDR-100).

## RULES
- Never paste prompt or reply text into a registry, the TODO or a commit.
- Never commit `~/.claude/memory-feedback/`.
- Never run apply without the spot check of STEP 3.
````

- [ ] **Step 3: Add the router row**

In `mods/model-router/routing.json`, inside the top-level `"skills"`
object, after `"reconcile": "apply",` add:

```json
    "memory-feedback": "reflect",
```

`reflect` is best tier at effort high: labelling is judgment (LRN-168);
the frontmatter `effort: high` matches the row's floor.

- [ ] **Step 4: Run the census suites**

Run each, contained:
`systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash lib/tests/effort-routing.test.sh </dev/null | tail -2`
`systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash lib/tests/skill-routing-census.test.sh </dev/null | tail -2`
`systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash skills/prune-memory/tests/run-deterministic.sh </dev/null | tail -2`
Expected: all green; no `memory-feedback` collision line in the census; the
`LRN-901` example is fictional (no such entry in learnings.md), so the
RED-7 style lock stays green.

- [ ] **Step 5: Commit**

```bash
git add skills/memory-feedback/SKILL.md mods/model-router/routing.json
git commit -m "feat(memory-feedback): /memory-feedback skill and router row"
```

---

### Task 8: Full suite and live proof (controller)

Implements spec §6 (live proof). Run by the orchestrator, not a sub-agent:
it touches the live store and asks the user.

- [ ] **Step 1: Full test run, contained**

Run: `systemd-run --user --scope -q -p TasksMax=512 env PATH="$HOME/.bun/bin:$PATH" make test </dev/null 2>&1 | tail -30`
Expected: every suite green, including `memory-feedback`,
`memory-feedback-remind`, `mods`, `session-digest`, `effort-routing`.

- [ ] **Step 2: Live records carry the fields**

After Task 1 is on disk, type one recall-triggering prompt in a session,
then read field names only:
`jq -c '[to_entries[] | select(.key|startswith("l:")) | .value[-1] | keys] | last' ~/.claude/plugins/store/memory_skills-dir-*.json`
Expected: the key list contains `cands` (and `ms` if a rerank ran).

- [ ] **Step 3: One real `/memory-feedback` run**

Run the skill on the live log. Records of this build session are labelled
`test`. Expected: worksheet written to the scratchpad, apply prints
FEEDBACK.md with `Prompt gate: open`, `labels.tsv` and `state.json` exist
with mode 0600, `grep -c` of any prompt word in `labels.tsv` is 0, and the
banner of the next session shows no reminder.
