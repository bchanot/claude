# Memory Feedback (phase 4d) Implementation Plan — r2

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure from real data whether 4c memory recall helps, through two
optional log fields, a bun reader that joins the log to transcripts into
local labels, a `/memory-feedback` skill, a session-start reminder, and a
fixed-threshold gate.

**Architecture:** The mod (`mods/memory/hooks/register.ts`) logs `cands`
and `ms` on prompt records and exports its log validator. A bun reader in
`lib/memory-feedback/` (labels, metrics, transcripts, CLI) joins records to
transcript attachments, redacts and writes a text worksheet only to the
scratchpad, and keeps IDs and enums in `~/.claude/memory-feedback/` (0600,
append-only labels). A plain shell script prints the reminder line. The
skill drives labelling and records a gate verdict once, in this config repo.

**Tech Stack:** TypeScript on bun (`bun test`, `node:fs`, `node:crypto`,
`node:child_process`), Claude Code mod kit (`claude-code/testing`), bash
3.2-safe shell.

**Spec:** `docs/superpowers/specs/2026-11-06-memory-feedback-design.md`
**Contract:** `.claude/tasks/contracts/2026-11-06-memory-feedback-4d-1825.md`

## r2 changes (3-lens challenge, 2026-11-06)

correctness FATAL(7: 1 BLOCKER), robustness CONCERNS(6 MAJOR), simplicity
CONCERNS(1 MAJOR). Named changes:

- C1 BLOCKER: a real `tool.call` attachment carries `toolUseID` =
  `<tool_use id>-context`; `joinTool` strips the suffix; fixture X5 uses it.
- C2: tool walks read `assistant`/`user` records only and dedupe
  `tool_result` by id (api-request-blob replays); X5 carries a replay.
- C3: M6 helper `.flat()`. C4: `oneAsk` typed `$: Engine`.
- C5/R6: no `stat -c` (portability census): age via `find -mtime`; census
  run in Task 6.
- C6/R5/R14: the skill resolves bun (`command -v bun || ~/.bun/bin/bun`),
  runs it from the reader's dir, stops on any non-zero rc.
- C7: STEP 6 writes only into this config repo (`-C "$CFG"`); actions on
  another repo's entries are shown, never written.
- R1: prompt, reply, command and known line pass the mod's `redact`
  before the cut; a planted secret test.
- R2: noisy and promotion are keyed by repo tag + ID; the tag is
  `basename#sha1(root)[0:6]` (same-basename repos stay apart).
- R3: `labels.tsv` is append-only (`appendFileSync`), backed up to
  `labels.tsv.bak` first; an unreadable line fails loudly, never dropped.
- R4/C14: `state.json` records when each gate verdict was first reached;
  `apply` prints `NEW: …` only on that transition; STEP 6 acts only on NEW;
  the reminder stops once both gates are recorded (`"closed":true`).
- S1 (partial): the tool extension is a pure function of time (no
  `toolExtended` flag); `state.json` stays for the verdict record and as
  the run marker the reminder reads.
- R7: `ms` clamped to a non-negative integer. R8: transcripts cached per
  session; sub-agent files loaded only for sub-agent tool records.
- R9: records younger than 30 min are left for the next run.
- R10: a root at the log cap whose oldest record is newer than the last
  run is reported as a possible eviction. C10: torn transcript lines
  counted in the worksheet header.
- R11/S7: the reminder is a plain script. R12: silent with
  `"recall": false`. R13: the CLI refuses a dir inside a git work tree.
- R15: the skill is user-invoked. R16: a corrupt `state.json` fails
  loudly; state is written before the labels. R17: `sample` subcommand
  replaces `shuf`; test temp dirs removed.
- S2/C11: `test` only as `<item> - test`. S3: one `clockStart` rule.
  S4: `cited` stays in the worksheet only. S5/C12: miss causes are what
  the worksheet supports: `no-overlap` or `overlap`. S6: `worksheet`
  writes a skeleton draft. C13: the empty run skips the spot check.
  C15: lost rows count in the late share and the ms p90. C17: unreadable
  state case. C18: jq on the newest record. C19: suites through
  `make test suite=…`. C8/C9: RED expectations corrected.
- Deviations from the approved spec, surfaced at the gate: reader in
  `lib/memory-feedback/` (not `mods/memory/feedback/`: `claude plugin
  validate --strict` and `plugin test` must not see non-mod files); miss
  causes reduced to `no-overlap | overlap`; `labels.tsv` drops `cited`;
  noisy and promotion lines carry a repo tag.

## Global Constraints

- No prompt or reply text in the plugin store, `labels.tsv`, `state.json`,
  `FEEDBACK.md` or any committed file; text only in `<dir>/worksheet.md`
  and `<dir>/items.json`, `<dir>` being the session scratchpad, and only
  after the mod's `redact` (LRN-124, LRN-261, BDR-057).
- `~/.claude/memory-feedback/` created 0700, every file in it 0600.
  `labels.tsv` is append-only; `state.json` and `FEEDBACK.md` go through a
  temp file and a rename.
- Our code: at most 25 logic lines per function, 80 columns, 5 params, no
  global mutable state.
- No new dependency: bun built-ins and `node:*` only.
- Shell is bash 3.2-safe and portable (no `stat -c`, no `shuf`, no
  `mapfile`, no `declare -A`).
- Every suite runs through `make test suite=<path>`, contained:
  `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=<path> </dev/null`.
- Never run the real `claude` CLI except through
  `make test suite=lib/tests/mods.test.sh` (its existing
  `claude plugin validate|test`), contained as above.
- Mod edits are live in every session at once (LRN-212): the failing kit
  test lands before the code, the change stays additive.
- Retention stays `cleanupPeriodDays: 7` (BDR-057).
- Thresholds live only in `lib/memory-feedback/thresholds.ts` (BDR-100).
- Registry and TODO writes from the skill go to this config repo only,
  through `lib/memory.sh -C "$CFG"` (BDR-129).

## Review Focus

1. The store file read while the engine rewrites it (torn JSON): the
   reader fails loudly, writes nothing, says to retry. Test R1.
2. A record whose transcript expired, or a session still running: the
   first is `lost` and counted, the second is left for the next run. Tests
   X4, R2, R3.
3. A labeller draft that is incomplete, labels an entry twice, invents an
   ID or tags one entry `test`: refused whole, nothing written. Tests L3,
   R4.
4. `labels.tsv` damaged by a hand edit: the next run fails loudly and the
   `.bak` copy exists; nothing is silently dropped. Test L7.
5. A secret typed in a prompt or a failing command: masked in the
   worksheet. Test R3.

---

### Task 1: `cands` and `ms` in the injection log (4d.1)

Implements spec §1. BDR-137 (log in `$.store`, caps), LRN-212 (live
edit), BDR-125 (no runtime cited flag), LRN-261 (exports for the reader).

**Files:**
- Modify: `mods/memory/hooks/register.ts:973-1003` (types, validator,
  exports), `:1700-1771` (`Picked`, `pickRecall`, `recallFor`)
- Test: `mods/memory/hooks/register.test.ts` (after `LO7`, ~line 2420)

**Interfaces:**
- Produces: `export type LogRecord` with `cands?: number`, `ms?: number`;
  `export const LOG_PREFIX = 'l:'`; `export const MAX_LOG = 200`;
  `export function isLogRecord(v: unknown): v is LogRecord` (all three
  were module-private). `redact` is already exported.

- [ ] **Step 1: Write the failing kit tests**

Add `isLogRecord` to the existing value import list from `./register` at
the top of `register.test.ts`; `Engine` is already imported as a type
(line 2). Add after the `LO7` test:

```ts
/** [outcome, cands, ms] of every logged ask, oldest first. */
async function askMeta(w: World) {
  return (await loadLog(storeApi(w), ROOT))
    .map(r => [r.outcome, r.cands, r.ms])
}

/** The single ask of a fresh world answered by `model`. */
async function oneAsk($: Engine, on: On, model?: Model) {
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

test('LF2: no candidate logs cands 0 and no ms', async ($, on) => {
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

- [ ] **Step 2: Run the suite, see it fail**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/mods.test.sh </dev/null`
Expected: `FAIL memory: plugin test` (the whole file is red: `isLogRecord`
is not exported, so the module link fails before any test runs).

- [ ] **Step 3: Implement**

In `register.ts`, replace the `LogRecord` type, `LOG_PREFIX`, `MAX_LOG`
and `isLogRecord` block (lines ~976-1003) with:

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
export const MAX_LOG = 200
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
  // a clock step back must not make the record invalid (isCount)
  const ms = Math.max(0, Math.round((await $.clock.now()) - now))
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
Expected: every check PASS, including `memory: validate --strict passed`
and `memory: plugin test passed`.

- [ ] **Step 5: Commit**

```bash
git add mods/memory/hooks/register.ts mods/memory/hooks/register.test.ts
git commit -m "feat(memory): log cands and rerank ms on prompt recall"
```

---

### Task 2: Labels, draft and state files

Implements spec §2 (labels.tsv, draft, state). LRN-124 (IDs and enums
only), LRN-027 (machine-readable state), LRN-168 (the draft is checked).

**Files:**
- Create: `lib/memory-feedback/labels.ts`
- Test: `lib/memory-feedback/labels.test.ts`
- Create: `lib/tests/memory-feedback.test.sh` (the `make test` entry for
  every bun test of `lib/memory-feedback/`)

**Interfaces:**
- Produces: types `Channel`, `Label`, `Item`, `Row`, `Draft`, `State`;
  `tagOf(root: string): string`; `keyOf(r: { session: string; at: number;
  channel: string }): string`; `toLine(r: Row): string`; `fromLine(line:
  string): Row | undefined`; `writeSafe(file: string, text: string): void`;
  `readRows(file: string): Row[]` (throws on a damaged line);
  `appendRows(file: string, rows: Row[]): void`; `readState(file: string):
  State` (throws on a corrupt file); `writeState(file: string, s: State):
  void`; `parseDraft(text: string, items: Item[]): Draft[] | string`;
  `rowsOf(it: Item, drafts: Draft[]): Row[]`; `skeleton(items: Item[]):
  string`.

- [ ] **Step 1: Write the suite entry `lib/tests/memory-feedback.test.sh`**

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

Then `mkdir -p lib/memory-feedback && chmod +x lib/tests/memory-feedback.test.sh`.

- [ ] **Step 2: Write the failing tests**

`lib/memory-feedback/labels.test.ts`:

```ts
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
```

- [ ] **Step 3: Run, see them fail**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null`
Expected: FAIL, `Cannot find module './labels.ts'`.

- [ ] **Step 4: Write `labels.ts`**

```ts
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
```

- [ ] **Step 5: Run, see them pass**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null`
Expected: 10 pass, 0 fail; `all suites green`.

- [ ] **Step 6: Commit**

```bash
git add lib/memory-feedback/labels.ts lib/memory-feedback/labels.test.ts lib/tests/memory-feedback.test.sh
git commit -m "feat(memory-feedback): append-only labels, draft and state"
```

---

### Task 3: Thresholds and metrics (4d.3, pure)

Implements spec §4. BDR-100 (thresholds in one file), LRN-241 (`test`
items excluded).

**Files:**
- Create: `lib/memory-feedback/thresholds.ts`
- Create: `lib/memory-feedback/metrics.ts`
- Test: `lib/memory-feedback/metrics.test.ts`

**Interfaces:**
- Consumes: `Row`, `Label`, `keyOf` from `./labels.ts` (Task 2).
- Produces: `type Metrics`; `clockStart(rows: Row[], logAts: number[]):
  number | undefined`; `metricsOf(rows: Row[]): Metrics`;
  `type Verdict = { prompt: Gate; tool: ToolGate }`;
  `gateVerdict(m: Metrics, now: number): Verdict`;
  `actionsOf(m: Metrics, v: Verdict): string[]`;
  `renderFeedback(m: Metrics, v: Verdict, now: number): string`;
  `p90(values: number[]): number | undefined`;
  `precision(rows: Row[]): number | undefined`.

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
```

- [ ] **Step 3: Run, see them fail**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null`
Expected: FAIL, `Cannot find module './metrics.ts'`; labels tests pass.

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
```

- [ ] **Step 5: Run, see them pass**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null`
Expected: 19 pass, 0 fail (10 labels + 9 metrics).

- [ ] **Step 6: Commit**

```bash
git add lib/memory-feedback/thresholds.ts lib/memory-feedback/metrics.ts lib/memory-feedback/metrics.test.ts
git commit -m "feat(memory-feedback): thresholds, metrics and gate verdicts"
```

---

### Task 4: Transcript join

Implements spec §2 (join). EVAL-037 (one record per content block),
LRN-261 (the mod's type imported).

**Files:**
- Create: `lib/memory-feedback/transcripts.ts`
- Test: `lib/memory-feedback/transcripts.test.ts`

**Interfaces:**
- Consumes: `type LogRecord` from `../../mods/memory/hooks/register.ts`
  (Task 1).
- Produces: `type Rec`; `type Loaded = { recs: Rec[]; torn: number }`;
  `JOIN_MS`; `slugOf(root: string): string`; `sessionFiles(projects:
  string, root: string, session: string, withSub: boolean): string[]`;
  `records(file: string): Loaded`; `composerText(r: Rec): string |
  undefined`; `type PromptJoin = { prompt: string; injected: string;
  reply: string }`; `joinPrompt(recs: Rec[], rec: LogRecord): PromptJoin |
  undefined`; `type ToolJoin = { command: string; known: string; next:
  boolean[] }`; `joinTool(recs: Rec[], rec: LogRecord): ToolJoin |
  undefined`.

- [ ] **Step 1: Write the failing tests**

`lib/memory-feedback/transcripts.test.ts`:

```ts
import { afterAll, expect, test } from 'bun:test'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import type { LogRecord } from '../../mods/memory/hooks/register.ts'
import {
  composerText, joinPrompt, joinTool, records, sessionFiles, slugOf,
  type Rec,
} from './transcripts.ts'

const dirs: string[] = []
afterAll(() => dirs.forEach(d => fs.rmSync(d, { recursive: true })))
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
const JOIN_LATE = 10001 // one ms past JOIN_MS

test('X1: slug, files, sub-agent files on demand, torn lines counted', () => {
  expect(slugOf('/home/a.b/c_d')).toBe('-home-a-b-c-d')
  const p = fs.mkdtempSync(path.join(os.tmpdir(), 'mf-'))
  dirs.push(p)
  const dir = path.join(p, slugOf('/r'))
  fs.mkdirSync(path.join(dir, 's', 'subagents'), { recursive: true })
  fs.writeFileSync(path.join(dir, 's.jsonl'), '{"a":1}\n{"torn')
  fs.writeFileSync(path.join(dir, 's', 'subagents', 'x.jsonl'), '{"b":2}\n')
  const all = sessionFiles(p, '/r', 's', true)
  expect(all.map(f => path.basename(f))).toEqual(['s.jsonl', 'x.jsonl'])
  expect(sessionFiles(p, '/r', 's', false)).toHaveLength(1)
  expect(records(all[0]!)).toEqual({ recs: [{ a: 1 }], torn: 1 })
  expect(sessionFiles(p, '/r', 'gone', true)).toEqual([])
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

test('X4: a non-injected ask joins its prompt; a missing turn is lost',
  () => {
    const recs = [user(-3000, 'plan the reader')]
    expect(joinPrompt(recs, rec({ outcome: 'timeout', ids: [] })))
      .toEqual({ prompt: 'plan the reader', injected: '', reply: '' })
    expect(joinPrompt([], rec({ outcome: 'none', ids: [] })))
      .toBeUndefined()
    const late = [user(0, 'x'), hook(JOIN_LATE, 'prompt.submit',
      ['memory recall:\nBDR-001 x'])]
    expect(joinPrompt(late, rec({}))).toBeUndefined()
  })

test('X5: a tool record joins through the -context id, replays ignored',
  () => {
    const use = (ms: number, id: string, command?: string): Rec => ({
      type: 'assistant', timestamp: iso(ms), message: { id: `a${id}`,
        content: [{ type: 'tool_use', id, name: 'Bash',
          input: command ? { command } : {} }] } })
    const result = (ms: number, id: string, err: boolean, type = 'user') =>
      ({ type, timestamp: iso(ms), message: { content: [
        { type: 'tool_result', tool_use_id: id, is_error: err }] } })
    const recs: Rec[] = [
      use(0, 'u1', 'make test'), result(5, 'u1', true),
      hook(10, 'tool.call', ['memory: known BLK-003 — x'], 'u1-context'),
      result(15, 'u1', true, 'api-request-blob'), // a replay, not a call
      use(20, 'u2'), result(25, 'u2', false),
      result(30, 'u2', false), // a duplicate result of the same call
    ]
    const r = rec({ channel: 'tool', ids: ['BLK-003'], trigger: 'tool' })
    expect(joinTool(recs, r)).toEqual({ command: 'make test',
      known: 'memory: known BLK-003 — x', next: [false] })
    expect(joinTool(recs, { ...r, ids: ['BLK-009'] })).toBeUndefined()
  })
```

- [ ] **Step 2: Run, see them fail**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null`
Expected: FAIL, `Cannot find module './transcripts.ts'`.

- [ ] **Step 3: Write `transcripts.ts`**

```ts
// lib/memory-feedback/transcripts.ts: reads Claude Code transcripts and
// joins one injection-log record to the turn it served (phase 4d).
import * as fs from 'node:fs'
import * as path from 'node:path'
import type { LogRecord } from '../../mods/memory/hooks/register.ts'

export type Rec = Record<string, any>
export type Loaded = { recs: Rec[]; torn: number }
export const JOIN_MS = 10000 // attachment written at most this after `at`
const NEAR_MS = 60000 // composer prompt at most this far from the ask
const WRAPPERS = ['<command-', '<local-command', '<system-reminder']
const RECALL_HEAD = 'memory recall:'
const KNOWN_HEAD = 'memory: known '
const CONTEXT_SUFFIX = /-context$/ // tool.call attachments: <id>-context

/** The transcript folder name of a project root. */
export const slugOf = (root: string) => root.replace(/[^A-Za-z0-9]/g, '-')

/** The main transcript of a session, then its sub-agent ones if asked. */
export function sessionFiles(
  projects: string, root: string, session: string, withSub: boolean,
): string[] {
  const dir = path.join(projects, slugOf(root))
  const sub = path.join(dir, session, 'subagents')
  const subs = withSub && fs.existsSync(sub)
    ? fs.readdirSync(sub).filter(f => f.endsWith('.jsonl')).sort()
      .map(f => path.join(sub, f))
    : []
  return [path.join(dir, `${session}.jsonl`), ...subs]
    .filter(f => fs.existsSync(f))
}

/** Parsed lines of a transcript; torn or partial lines are counted. */
export function records(file: string): Loaded {
  const recs: Rec[] = []
  let torn = 0
  for (const raw of fs.readFileSync(file, 'utf8').split('\n')) {
    if (raw.trim() === '') continue
    try { recs.push(JSON.parse(raw)) } catch { torn += 1 }
  }
  return { recs, torn }
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

/** Blocks of real calls and results: blob replays are skipped. */
const callBlocks = (recs: Rec[]) => recs
  .filter(r => r.type === 'assistant' || r.type === 'user')
  .flatMap(blocksOf)

/** The command of a Bash tool_use. */
function bashCommand(blocks: Rec[], useId: string): string {
  const b = blocks.find(x => x.type === 'tool_use' && x.id === useId)
  return String(b?.input?.command ?? '')
}

/** Whether each of the next 3 Bash results after `useId` failed. */
function nextResults(blocks: Rec[], useId: string): boolean[] {
  const bash = new Set<string>()
  const done = new Set<string>()
  const out: boolean[] = []
  let after = false
  for (const b of blocks) {
    if (b.type === 'tool_use' && b.name === 'Bash') bash.add(b.id)
    if (b.type !== 'tool_result' || !bash.has(b.tool_use_id)) continue
    if (done.has(b.tool_use_id)) continue
    done.add(b.tool_use_id)
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
  const raw = att?.attachment?.toolUseID
  if (att === undefined || typeof raw !== 'string') return undefined
  const useId = raw.replace(CONTEXT_SUFFIX, '')
  const blocks = callBlocks(recs)
  return { command: bashCommand(blocks, useId),
    known: hookText(att, 'tool.call') ?? '',
    next: nextResults(blocks, useId) }
}
```

- [ ] **Step 4: Run, see them pass**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null`
Expected: 24 pass, 0 fail (10 labels + 9 metrics + 5 transcripts).

- [ ] **Step 5: Commit**

```bash
git add lib/memory-feedback/transcripts.ts lib/memory-feedback/transcripts.test.ts
git commit -m "feat(memory-feedback): join log records to transcript turns"
```

---

### Task 5: Reader CLI

Implements spec §2 (commands, population, worksheet, apply). LRN-241,
LRN-133 (lost and torn counted), LRN-261 (imports `isLogRecord`,
`LOG_PREFIX`, `MAX_LOG`, `redact`), BDR-057 (redact before writing).

**Files:**
- Create: `lib/memory-feedback/reader.ts`
- Test: `lib/memory-feedback/reader.test.ts`

**Interfaces:**
- Consumes: Task 1 `LOG_PREFIX`, `MAX_LOG`, `isLogRecord`, `redact`,
  `LogRecord`; Task 2 `appendRows`, `keyOf`, `parseDraft`, `readRows`,
  `readState`, `rowsOf`, `skeleton`, `tagOf`, `writeSafe`, `writeState`,
  `Item`, `State`; Task 3 `clockStart`, `gateVerdict`, `metricsOf`,
  `renderFeedback`, `Verdict`; Task 4 `joinPrompt`, `joinTool`, `records`,
  `sessionFiles`, `Loaded`.
- Produces: `type Paths`; `type Logged`; `storeFile(dir: string): string`;
  `readLogs(file: string): Logged[]`; `population(logs: Logged[], done:
  Set<string>, start: number | undefined, now: number): Logged[]`;
  `worksheet(dir: string, p: Paths, now: number): number`; `apply(dir:
  string, p: Paths, now: number): string`; `sample(dir: string, n: number):
  string[]`; `checkDir(dir: string | undefined): string`; CLI
  `bun reader.ts worksheet|apply|sample <abs dir>` (rc 0 ok, 1 error on
  stderr, 2 usage or refused dir).

- [ ] **Step 1: Write the failing tests**

`lib/memory-feedback/reader.test.ts`:

```ts
import { afterAll, expect, test } from 'bun:test'
import { spawnSync } from 'node:child_process'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import { slugOf } from './transcripts.ts'
import {
  apply, checkDir, population, readLogs, sample, storeFile, worksheet,
  type Paths,
} from './reader.ts'

const dirs: string[] = []
afterAll(() => dirs.forEach(d => fs.rmSync(d, { recursive: true })))
const mk = (pfx: string) => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), pfx))
  dirs.push(d)
  return d
}
const T0 = Date.parse('2026-11-10T10:00:00.000Z')
const NOW = T0 + 2 * 3600000 // every fixture record is 2 h old
const iso = (ms: number) => new Date(T0 + ms).toISOString()
// built at run time: no secret-shaped literal in the repo (BLK-041)
const PLANTED = ['API', 'TOKEN'].join('_') + '=' + 'hunter' + '2value'

/** A fixture home: store, one transcript, an out dir, a work dir. */
function fixture(store: unknown): { p: Paths; work: string } {
  const home = mk('mf-')
  const p = { store: path.join(home, 'store'),
    projects: path.join(home, 'projects'), out: path.join(home, 'mf') }
  fs.mkdirSync(p.store)
  fs.writeFileSync(path.join(p.store, 'memory_skills-dir-abc.json'),
    typeof store === 'string' ? store : JSON.stringify(store))
  const dir = path.join(p.projects, slugOf('/repo/x'))
  fs.mkdirSync(dir, { recursive: true })
  fs.writeFileSync(path.join(dir, 's1.jsonl'), [
    { type: 'user', timestamp: iso(-50), origin: { kind: 'human' },
      message: { content: `design the reader gate with ${PLANTED}` } },
    { type: 'attachment', timestamp: iso(400), attachment: {
      type: 'hook_additional_context', hookName: 'prompt.submit',
      content: ['memory recall:\nBDR-001 x'] } },
    { type: 'assistant', timestamp: iso(900),
      message: { id: 'm', content: [{ type: 'text', text: 'per BDR-001' }] } },
  ].map(r => JSON.stringify(r)).join('\n') + '\n')
  return { p, work: mk('mf-work-') }
}
const REC = (at: number, over = {}) => ({ at, session: 's1', agent: 'main',
  channel: 'prompt', ids: ['BDR-001'], trigger: 'fresh',
  outcome: 'injected', cands: 5, ms: 800, ...over })
const STORE = { 'l:/repo/x': [
  REC(T0 - 9e6, { cands: undefined }), // before 4d.1: out of population
  REC(T0), REC(T0 + 60000, { session: 'gone' }), // the second one lost
], 'p:/repo/x': { sessions: [] } }
const draft = (work: string, text: string) =>
  fs.writeFileSync(path.join(work, 'labels-draft.tsv'), text)

test('R1: no store file, or a torn one, fails loudly', () => {
  const { p } = fixture('{"l:/x": [tor')
  expect(() => readLogs(storeFile(p.store))).toThrow('unreadable')
  expect(() => storeFile(path.join(p.store, 'none'))).toThrow('no memory')
})

test('R2: population from the clock start, unlabelled, 30 min old', () => {
  const { p } = fixture(STORE)
  const logs = readLogs(storeFile(p.store))
  expect(population(logs, new Set(), T0, NOW).map(l => l.rec.at))
    .toEqual([T0, T0 + 60000])
  expect(population(logs, new Set([`s1|${T0}|prompt`]), T0, NOW))
    .toHaveLength(1)
  expect(population(logs, new Set(), T0, T0 + 600000)).toHaveLength(0)
  expect(population(logs, new Set(), undefined, NOW)).toEqual([])
})

test('R3: worksheet: 0600 files, redacted text, a lost item, a skeleton',
  () => {
    const { p, work } = fixture(STORE)
    expect(worksheet(work, p, NOW)).toBe(2)
    const sheet = fs.readFileSync(path.join(work, 'worksheet.md'), 'utf8')
    expect(sheet).toContain('design the reader gate')
    expect(sheet).not.toContain('hunter2value')
    expect(sheet).toContain('LOST')
    for (const f of ['worksheet.md', 'items.json', 'labels-draft.tsv']) {
      expect(fs.statSync(path.join(work, f)).mode & 0o777).toBe(0o600)
    }
    expect(fs.readFileSync(path.join(work, 'labels-draft.tsv'), 'utf8'))
      .toContain('1\tBDR-001\t')
    const items = JSON.parse(fs.readFileSync(
      path.join(work, 'items.json'), 'utf8'))
    expect(items.map((i: { cited: string[]; lost: boolean }) =>
      [i.cited, i.lost])).toEqual([[['BDR-001'], false], [[], true]])
  })

test('R4: a bad draft refuses the whole apply, nothing written', () => {
  const { p, work } = fixture(STORE)
  worksheet(work, p, NOW)
  draft(work, '1\tBDR-001\tmaybe')
  expect(() => apply(work, p, NOW)).toThrow('draft refused')
  expect(fs.existsSync(p.out)).toBe(false)
})

test('R5: apply writes labels, state, FEEDBACK; a second apply refuses',
  () => {
    const { p, work } = fixture(STORE)
    worksheet(work, p, NOW)
    draft(work, '1\tBDR-001\trelevant\n')
    const fb = apply(work, p, NOW)
    expect(fb).toContain('Prompt gate: open (1/20)')
    expect(fb).toContain('Lost records: 1')
    expect(fb).not.toContain('design the reader gate')
    const labels = fs.readFileSync(path.join(p.out, 'labels.tsv'), 'utf8')
    expect(labels).not.toContain('design')
    expect(labels).not.toContain('/repo/x')
    expect(labels).toMatch(/\tx#[0-9a-f]{6}\t/)
    expect(JSON.parse(fs.readFileSync(path.join(p.out, 'state.json'),
      'utf8')).lastRun).toBe(NOW)
    expect(() => apply(work, p, NOW + 1)).toThrow('already applied')
    expect(worksheet(work, p, NOW + 2)).toBe(0)
  })

test('R6: a first run with nothing to label records the run only', () => {
  const { p, work } = fixture({ 'l:/repo/x': [REC(T0, { cands: undefined })] })
  expect(worksheet(work, p, NOW)).toBe(0)
  expect(fs.readFileSync(path.join(work, 'worksheet.md'), 'utf8'))
    .toContain('No unlabelled record')
  expect(apply(work, p, NOW)).toContain('Gate clock start: not started')
  expect(fs.existsSync(path.join(p.out, 'state.json'))).toBe(true)
})

test('R7: a gate verdict is NEW once, then recorded', () => {
  const { p, work } = fixture(STORE)
  const late = T0 + 36 * 86400000 // past the 5-week cap
  worksheet(work, p, late)
  draft(work, '1\tBDR-001\trelevant\n')
  expect(apply(work, p, late)).toContain('NEW: prompt gate reached')
  worksheet(work, p, late + 1)
  draft(work, '')
  const again = apply(work, p, late + 1)
  expect(again).toContain('Prompt gate: reached')
  expect(again).not.toContain('NEW:')
})

test('R8: the CLI refuses a dir inside a git work tree', () => {
  const repo = mk('mf-repo-')
  spawnSync('git', ['-C', repo, 'init', '-q'])
  expect(checkDir(repo)).toContain('git work tree')
  expect(checkDir('relative/dir')).not.toBe('')
  expect(checkDir(mk('mf-ok-'))).toBe('')
})

test('R9: sample picks entry lines of the draft', () => {
  const { p, work } = fixture(STORE)
  worksheet(work, p, NOW)
  draft(work, '1\tBDR-001\trelevant\n1\t-\tchecked\n')
  expect(sample(work, 5)).toEqual(['1\tBDR-001\trelevant'])
})
```

- [ ] **Step 2: Run, see them fail**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null`
Expected: FAIL, `Cannot find module './reader.ts'`; the 24 earlier tests
still pass.

- [ ] **Step 3: Write `reader.ts`**

```ts
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
  tagOf, writeSafe, writeState, type Item, type State,
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

function header(b: Base, lost: boolean): string {
  const ids = b.ids.join(' ') || '-'
  return `## Item ${b.n}: ${b.channel}/${b.trigger}/${b.outcome}` +
    ` · cands ${b.cands ?? '-'} · ms ${b.ms ?? '-'} · ${b.root}` +
    ` · ids ${ids}${lost ? ' · LOST (no transcript turn)' : ''}`
}

const lostItem = (b: Base): Joined =>
  ({ item: { ...b, cited: [], lost: true }, text: header(b, true) })

function promptItem(b: Base, l: Loaded, rec: LogRecord): Joined {
  const j = joinPrompt(l.recs, rec)
  if (j === undefined) return lostItem(b)
  const cited = citedIn(b.ids, j.reply)
  const text = [header(b, false), `Prompt: ${clip(j.prompt, PROMPT_MAX)}`,
    `Injected:\n${redact(j.injected) || '-'}`,
    `Reply: ${clip(j.reply, REPLY_MAX)}`,
    `Cited: ${cited.join(', ') || 'none'}`].join('\n\n')
  return { item: { ...b, cited, lost: false }, text }
}

function toolItem(b: Base, l: Loaded, rec: LogRecord): Joined {
  const j = joinTool(l.recs, rec)
  if (j === undefined) return lostItem(b)
  const next = j.next.map(f => f ? 'failed' : 'ok').join(', ') || 'none'
  const text = [header(b, false), `Command: ${clip(j.command, PROMPT_MAX)}`,
    `Known: ${redact(j.known)}`, `Next Bash results: ${next}`]
    .join('\n\n')
  return { item: { ...b, cited: [], lost: false }, text }
}

/** A per-run transcript loader: each session read once (R8); sub-agent
 * files only for sub-agent tool records. */
function loaderFor(projects: string): Load {
  const cache = new Map<string, Loaded>()
  return (l: Logged) => {
    const sub = l.rec.channel === 'tool' && l.rec.agent !== 'main'
    const key = `${l.root}|${l.rec.session}|${sub}`
    const hit = cache.get(key)
    if (hit !== undefined) return hit
    const loaded = sessionFiles(projects, l.root, l.rec.session, sub)
      .map(records).reduce((a, b) => ({ recs: [...a.recs, ...b.recs],
        torn: a.torn + b.torn }), { recs: [], torn: 0 } as Loaded)
    cache.set(key, loaded)
    return loaded
  }
}

/** One worksheet item and its redacted text. */
function joinOne(l: Logged, n: number, load: Load): Joined {
  const r = l.rec
  const b: Base = { n, root: tagOf(l.root), session: r.session, at: r.at,
    channel: r.channel, trigger: r.trigger ?? '', outcome: r.outcome ?? '',
    cands: r.cands, ms: r.ms, ids: r.ids }
  const loaded = load(l)
  return r.channel === 'prompt'
    ? promptItem(b, loaded, r) : toolItem(b, loaded, r)
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

/** Writes worksheet.md, items.json, labels-draft.tsv (0600); the count. */
export function worksheet(dir: string, p: Paths, now: number): number {
  const rows = readRows(labelsOf(p))
  const logs = readLogs(storeFile(p.store))
  const logAts = logs.filter(l => l.rec.cands !== undefined)
    .map(l => l.rec.at)
  const pop = population(logs, new Set(rows.map(keyOf)),
    clockStart(rows, logAts), now)
  const load = loaderFor(p.projects)
  const joined = pop.map((l, i) => joinOne(l, i + 1, load))
  const torn = pop.reduce((t, l) => t + load(l).torn, 0)
  const head = sheetHead(pop.length, torn,
    evictions(logs, readState(stateOf(p)).lastRun))
  writeSafe(path.join(dir, 'worksheet.md'), ['# Memory feedback worksheet',
    head, DRAFT_HELP, ...joined.map(j => j.text)].join('\n\n') + '\n')
  const items = joined.map(j => j.item)
  writeSafe(path.join(dir, 'items.json'), JSON.stringify(items))
  writeSafe(path.join(dir, 'labels-draft.tsv'), skeleton(items))
  return pop.length
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

/** Validates the draft; writes state, then labels, then FEEDBACK.md. */
export function apply(dir: string, p: Paths, now: number): string {
  const items: Item[] = JSON.parse(
    fs.readFileSync(path.join(dir, 'items.json'), 'utf8'))
  const drafts = parseDraft(draftOf(dir), items)
  if (typeof drafts === 'string') throw new Error(`draft refused: ${drafts}`)
  const old = readRows(labelsOf(p))
  const done = new Set(old.map(keyOf))
  if (items.some(i => done.has(keyOf(i)))) {
    throw new Error('items already applied: run worksheet again')
  }
  const fresh = items.flatMap(i => rowsOf(i, drafts))
  const m = metricsOf([...old, ...fresh])
  const v = gateVerdict(m, now)
  const { state, news } = nextState(readState(stateOf(p)), v, now)
  const feedback = renderFeedback(m, v, now)
  writeState(stateOf(p), state)
  if (fresh.length > 0) appendRows(labelsOf(p), fresh)
  writeSafe(path.join(p.out, 'FEEDBACK.md'), feedback)
  return feedback + news.map(n => n + '\n').join('')
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
```

- [ ] **Step 4: Run, see it pass, then the CLI usage path**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null`
Expected: 33 pass, 0 fail.

Then: `(cd lib/memory-feedback && env PATH="$HOME/.bun/bin:$PATH" bun reader.ts apply "$PWD"; echo rc=$?)`
Expected: the usage line ending `: inside a git work tree` on stderr,
`rc=2`.

- [ ] **Step 5: Commit**

```bash
git add lib/memory-feedback/reader.ts lib/memory-feedback/reader.test.ts
git commit -m "feat(memory-feedback): worksheet, apply and sample reader"
```

---

### Task 6: Session-start reminder

Implements spec §3 (reminder). BDR-057 (the 7-day window is why it
exists).

**Files:**
- Create: `lib/memory-feedback-remind.sh`
- Test: `lib/tests/memory-feedback-remind.test.sh`
- Modify: `hooks/session-start.sh:447-455` (inside the `_ss_digest` block,
  before `_ss_root=`)
- Test: `lib/tests/session-digest.test.sh` (new case SD17 before SD15)

**Interfaces:**
- Produces: `bash lib/memory-feedback-remind.sh` prints one line or
  nothing, always rc 0; reads `$HOME/.claude/plugins/store/memory_skills-dir-*.json`,
  `$HOME/.claude/memory-feedback/state.json`, `$HOME/.claude/memory.json`.

- [ ] **Step 1: Write the failing suite**

`lib/tests/memory-feedback-remind.test.sh`:

```bash
#!/usr/bin/env bash
# lib/tests/memory-feedback-remind.test.sh — the phase 4d banner line:
# shown when /memory-feedback never ran, or ran 5+ days ago and the store
# changed since; silent once both gates are recorded, with recall off, or
# on any error.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/memory-feedback-remind.sh"
WORK="$(mktemp -d)" || exit 1
trap 'chmod -R u+rw "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# home <name>: a fixture HOME with a store file (unless "nostore")
home() {
  mkdir -p "$WORK/$1/.claude/plugins/store" "$WORK/$1/.claude/memory-feedback"
  [ "$1" = nostore ] || : > "$WORK/$1/.claude/plugins/store/memory_skills-dir-a.json"
  echo "$WORK/$1"
}
OPEN='{"lastRun":1,"closed":false}'
# old <home> <content>: a state.json last written on 2026-01-01
old() {
  printf '%s' "$2" > "$1/.claude/memory-feedback/state.json"
  touch -t 202601010000 "$1/.claude/memory-feedback/state.json"
}
run() { HOME="$1" bash "$LIB" 2>&1; echo "rc=$?"; }
DUE='memory feedback: last run 5+ d ago, transcripts expire at 7 → /memory-feedback'

check MR1-no-store "$(run "$(home nostore)")" "rc=0"
check MR2-never "$(run "$(home never)")" "memory feedback: never run → /memory-feedback
rc=0"
h=$(home due); old "$h" "$OPEN"
check MR3-due "$(run "$h")" "$DUE
rc=0"
h=$(home quiet); old "$h" "$OPEN"
touch -t 202512010000 "$h/.claude/plugins/store/memory_skills-dir-a.json"
check MR4-store-unchanged "$(run "$h")" "rc=0"
h=$(home fresh)
printf '%s' "$OPEN" > "$h/.claude/memory-feedback/state.json"
touch -t 209901010000 "$h/.claude/plugins/store/memory_skills-dir-a.json"
check MR5-ran-today "$(run "$h")" "rc=0"
h=$(home closed); old "$h" '{"lastRun":1,"closed":true}'
check MR6-closed "$(run "$h")" "rc=0"
h=$(home off); old "$h" "$OPEN"; printf '{"recall": false}' > "$h/.claude/memory.json"
check MR7-recall-off "$(run "$h")" "rc=0"
h=$(home locked); old "$h" "$OPEN"
chmod 000 "$h/.claude/memory-feedback/state.json"
check MR8-unreadable-rc "$(run "$h" | tail -1)" "rc=0"

printf 'memory-feedback-remind: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

`chmod +x lib/tests/memory-feedback-remind.test.sh`.

- [ ] **Step 2: Run it, see it fail**

Run: `systemd-run --user --scope -q -p TasksMax=256 make test suite=lib/tests/memory-feedback-remind.test.sh </dev/null`
Expected: FAIL on all 8 cases (the lib is absent: `bash` prints
`No such file or directory` and rc 127).

- [ ] **Step 3: Write `lib/memory-feedback-remind.sh`**

```bash
#!/usr/bin/env bash
# lib/memory-feedback-remind.sh — the phase 4d reminder line of the
# session-start banner (BDR-057: transcripts live 7 days). One line when
# /memory-feedback never ran, or ran REMIND_DAYS+ days ago and the memory
# store changed since. Silent once both gates are recorded ("closed":true),
# with "recall": false, or on any error; always rc 0. bash 3.2 safe,
# portable (find -mtime, no stat -c), no JSON parse.
REMIND_DAYS=5
state="$HOME/.claude/memory-feedback/state.json"

store=""
for f in "$HOME"/.claude/plugins/store/memory_skills-dir-*.json; do
  [ -f "$f" ] || continue
  if [ -z "$store" ] || [ "$f" -nt "$store" ]; then store=$f; fi
done
[ -n "$store" ] || exit 0
# recall off: no record can come (the 4b capture still writes the store)
grep -Eq '"recall"[[:space:]]*:[[:space:]]*false' \
  "$HOME/.claude/memory.json" 2>/dev/null && exit 0
if [ ! -f "$state" ]; then
  echo "memory feedback: never run → /memory-feedback"
  exit 0
fi
grep -q '"closed":true' "$state" 2>/dev/null && exit 0
[ "$store" -nt "$state" ] || exit 0
[ -n "$(find "$state" -mtime +$((REMIND_DAYS - 1)) 2>/dev/null)" ] || exit 0
echo "memory feedback: last run ${REMIND_DAYS}+ d ago," \
  "transcripts expire at 7 → /memory-feedback"
exit 0
```

`chmod +x lib/memory-feedback-remind.sh`.

- [ ] **Step 4: Run, see it pass, lint, portability census**

First `git add lib/memory-feedback-remind.sh lib/tests/memory-feedback-remind.test.sh`
(the census scans tracked files). Run:
`systemd-run --user --scope -q -p TasksMax=256 make test suite=lib/tests/memory-feedback-remind.test.sh </dev/null && systemd-run --user --scope -q -p TasksMax=256 make test suite=lib/tests/portability-census.test.sh </dev/null && shellcheck lib/memory-feedback-remind.sh lib/tests/memory-feedback-remind.test.sh`
Expected: `memory-feedback-remind: 8 passed, 0 failed`; portability census
green; shellcheck clean.

- [ ] **Step 5: Wire it into the banner, test-first**

In `lib/tests/session-digest.test.sh`, add before the `# SD15` block:

```bash
# SD17: the 4d reminder line prints before the digest, never inside it
h17="$WORK/h17"; mkdir -p "$h17/.claude/plugins/store"
: > "$h17/.claude/plugins/store/memory_skills-dir-a.json"
p=$(mkproj sd17); blk "$p" 1 open "Seventeen"
out17=$(cd "$p" && HOME="$h17" bash "$SS" <"$WORK/startup.json" 2>/dev/null)
check SD17-line "$(printf '%s\n' "$out17" \
  | grep -c '^memory feedback: never run')" 1
check SD17-before-digest "$(printf '%s\n' "$out17" \
  | grep -n -e '^memory feedback' -e '^memory digest' | cut -d: -f2 \
  | tr '\n' ' ')" "memory feedback memory digest "
```

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/session-digest.test.sh </dev/null`
Expected: FAIL `SD17-line: got[0] want[1]`.

In `hooks/session-start.sh`, inside `if [ "$_ss_digest" = 1 ]; then`,
first lines of the block (before `_ss_root=...`), in the file's timeout
convention (the registry-v1 block, lines ~319-322):

```bash
  # phase 4d: the weekly /memory-feedback reminder, bounded, never fatal
  _ss_mf="$(dirname "${BASH_SOURCE[0]}")/../lib/memory-feedback-remind.sh"
  _ss_tmo=(); command -v timeout >/dev/null 2>&1 && _ss_tmo=(timeout 2)
  [ -f "$_ss_mf" ] && { "${_ss_tmo[@]}" bash "$_ss_mf" 2>/dev/null || true; }
  unset _ss_mf _ss_tmo
```

- [ ] **Step 6: Run, see it pass, lint**

Run: `systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/session-digest.test.sh </dev/null && shellcheck hooks/session-start.sh lib/tests/session-digest.test.sh`
Expected: `session-digest: 56 passed, 0 failed` (54 + 2), shellcheck clean.

- [ ] **Step 7: Commit**

```bash
git add lib/memory-feedback-remind.sh lib/tests/memory-feedback-remind.test.sh hooks/session-start.sh lib/tests/session-digest.test.sh
git commit -m "feat(hooks): memory feedback reminder in the banner"
```

---

### Task 7: `/memory-feedback` skill and its router row

Implements spec §3 (skill steps). BDR-129 (registry writes through
memory.sh, `-C` to this repo), LRN-168 (spot check), LRN-073 (fictional
IDs in examples).

**Files:**
- Create: `skills/memory-feedback/SKILL.md`
- Modify: `mods/model-router/routing.json` (`"skills"` table, after
  `"reconcile": "apply",` ~line 130)

**Interfaces:**
- Consumes: Task 5 CLI `reader.ts worksheet|apply|sample <dir>`;
  `lib/memory.sh -C <root> add eval|decision`; `lib/capitalize-commit.md`.

- [ ] **Step 1: Write the skill file**

`skills/memory-feedback/SKILL.md`:

````markdown
---
name: memory-feedback
effort: high
description: Run only when the user asks for it ("memory feedback", "label recall", "recall precision", "is memory recall useful", "feedback mémoire", or after they mention the banner's memory feedback line). Labels each injected registry entry relevant or irrelevant from the transcript, samples misses, reports precision and the phase 4d gates. NOT registry curation (that is /prune-memory).
---

# /memory-feedback — label recall injections, read the gates

Phase 4d (BDR-125). The memory mod logs every recall ask; transcripts live
7 days, so this runs weekly. Claude labels, the user spot-checks. Redacted
text stays in the scratchpad; `~/.claude/memory-feedback/` keeps IDs, enums
and repo tags only, never in git.

## STEP 1 — WORKSHEET

```bash
BUN="$(command -v bun || echo "$HOME/.bun/bin/bun")"
MFD="$(cd -P "$HOME/.claude/lib" && pwd)/memory-feedback"
CFG="$(cd -P "$HOME/.claude/lib/.." && pwd)"   # this config repo
[ -x "$BUN" ] || echo "memory-feedback: bun not found"
(cd "$MFD" && "$BUN" reader.ts worksheet "<scratchpad dir, absolute>")
```

Any non-zero rc → print the message and stop (`store file unreadable`:
retry once after a few seconds; `bun not found`: tell the user). Running
from `$MFD` keeps the current repo's bun config out. `0 records` → go to
STEP 5 (no spot check: it records the run only).

## STEP 2 — LABEL

Read `<dir>/worksheet.md`. Fill the third column of the skeleton
`<dir>/labels-draft.tsv` for every line:
- `relevant`: the entry bears on what the prompt asked or what the reply
  did; `irrelevant` otherwise. Judge the entry against the ask, not the
  reply's quality.
- A proof, bench or recall-testing session: replace that item's lines by
  one `<item>	-	test` line.
Lost items have no line.

## STEP 3 — SPOT CHECK

```bash
(cd "$MFD" && "$BUN" reader.ts sample "<dir>")
```

Show the 5 picked entries to the user in one AskUserQuestion: the prompt
gist in your own words (never a secret), the entry title, your label; the
user confirms or flips each. Apply the flips to the draft (LRN-168).

## STEP 4 — MISSES

On up to 5 prompt items whose outcome is injected or none, search the
registries of that item's repo (`bash ~/.claude/lib/memory.sh -C <repo>
index` + entry bodies) for live entries that bore on the ask and were not
injected. Each one: `<item>	<id>	missed	<cause>`, cause `no-overlap` (no
content word shared with the prompt) or `overlap`. A searched item with no
miss: `<item>	-	checked`. Example line: `3	LRN-901	missed	no-overlap`.

## STEP 5 — APPLY

```bash
(cd "$MFD" && "$BUN" reader.ts apply "<dir>")
```

rc 1 `draft refused: <reason>` → fix the draft, rerun. It prints
FEEDBACK.md: show the gate lines and the Actions list to the user.

## STEP 6 — A GATE REACHED FOR THE FIRST TIME

Only when the output ends with a `NEW: …` line:
1. Propose the verdict as an EVAL entry (counts and shares from
   FEEDBACK.md, no prompt text, no other repo's name) and each Action as a
   TODO line of this config repo; the user approves each. Actions naming
   another repo's tag (noisy, promotion) are shown to the user to run
   /prune-memory there; they are never written here.
2. Write approved entries per `lib/capitalize-commit.md` § WRITE into this
   repo only: `bash "$CFG/lib/memory.sh" -C "$CFG" add eval …` (a decided
   action also gets `add decision`), TODO lines in
   `$CFG/.claude/tasks/TODO.md`, then commit per § DO run from `$CFG`.
Thresholds live in `lib/memory-feedback/thresholds.ts`; never tune them
here (BDR-100).

## RULES
- Never paste prompt or reply text into a registry, the TODO or a commit.
- Never commit `~/.claude/memory-feedback/` or the scratchpad files.
- Never run apply on labelled items without the spot check of STEP 3.
````

- [ ] **Step 2: See the routing census fail, then add the row**

Run: `git add skills/memory-feedback/SKILL.md && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/effort-routing.test.sh </dev/null | grep memory-feedback`
Expected: `FAIL skills/memory-feedback: no row in routing.json`.

In `mods/model-router/routing.json`, inside the top-level `"skills"`
object, after `"reconcile": "apply",` add:

```json
    "memory-feedback": "reflect",
```

`reflect` is best tier at effort high: labelling is judgment (LRN-168);
the frontmatter `effort: high` matches the row's floor.

- [ ] **Step 3: Run the census suites**

Each, contained (`systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=<path> </dev/null`):
`lib/tests/effort-routing.test.sh`, `lib/tests/skill-routing-census.test.sh`,
`lib/tests/model-routing.test.sh`, `skills/prune-memory/tests/run-deterministic.sh`.
Expected: all green; no `memory-feedback` collision line; `LRN-901` is
fictional (absent from learnings.md).

- [ ] **Step 4: Commit**

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
Expected: `all suites green`, including `memory-feedback`,
`memory-feedback-remind`, `mods`, `session-digest`, `effort-routing`,
`portability-census`.

- [ ] **Step 2: Live records carry the fields**

After Task 1 is on disk, type one recall-triggering prompt in a session,
then read field names of the newest record only:
`jq -c '[to_entries[] | select(.key|startswith("l:")) | .value[]] | sort_by(.at) | last | keys' ~/.claude/plugins/store/memory_skills-dir-*.json`
Expected: the key list contains `cands` (and `ms` if a rerank ran).

- [ ] **Step 3: One real `/memory-feedback` run, the skill text verbatim**

Run the skill as written (no PATH fix by hand). Records of this build
session are labelled `test`. Expected: worksheet in the scratchpad,
apply prints FEEDBACK.md with `Prompt gate: open`, `labels.tsv` and
`state.json` exist with mode 0600, `labels.tsv` holds no prompt word and
no full path, and the next session's banner shows no reminder line.
