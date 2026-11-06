# Memory feedback (phase 4d): design

Date: 2026-11-06. Queue: BDR-125 phase 4d. Host: `mods/memory` (BDR-137).
Supersedes the open choices of `.claude/tasks/plans/2026-11-05-memory-feedback-4d-1834.md` (r1).
Contract: `.claude/tasks/contracts/2026-11-06-memory-feedback-4d-1825.md`.

## Goal

Say from real data whether 4c recall helps: precision per channel and per
trigger, what it misses, which entries are noisy, which deserve promotion to
a mechanism (BDR-100). Thresholds and gates are fixed now, before the data.
Nothing is tuned before a gate is reached; each threshold action is its own
/feat or /hotfix carrying its measurement.

In scope: 4d.1 log fields, 4d.2 reader + `/memory-feedback` skill +
session-start reminder, 4d.3 thresholds + gate verdict. Out of scope: 4d.4
(/prune-memory step D, promotion mechanics), built only if a gate shows a
noisy entry or a promotion candidate (own TODO line).

## User decisions (2026-11-06)

| Choice | Decision |
|---|---|
| Cadence vs 7-day transcript retention | session-start reminder, user runs `/memory-feedback`; retention stays 7 days (BDR-057) |
| Gate population | records carrying `cands` (4d.1 on), every repo; `test` label excluded from shares |
| Labels location | local `~/.claude/memory-feedback/` (0600), never in git |
| Log fields | `cands` + `ms` |
| Gate shape | two independent gates, prompt and tool |
| Thresholds | r1 table unchanged |
| Approach | TS reader in `mods/memory/feedback/` + skill `/memory-feedback` |
| Label values | `relevant`, `irrelevant`, `test` (+ `missed` rows) |
| FEEDBACK.md | local, regenerated each run; recorded in the repo as an EVAL entry (and a BDR when an action is decided) at each gate |

## 1. Log fields (4d.1, `mods/memory/hooks/register.ts`)

- `LogRecord` gains `cands?: number` (BM25 candidates after the seen
  filter, 0-30) on every prompt-channel record, and `ms?: number` (rerank
  wall time, integer ms) on every record where a rerank call ran, timeout
  included. Absent when no rerank ran (no candidate, paused).
- `isLogRecord` accepts both as optional non-negative integers; a record
  without them stays valid (LG5 precedent). No other field, no text.
- Size: about 20 bytes per field; 200 records stay under the 64 KiB cap.
- `none` with `cands` = 0 (nothing to offer) is now distinct from `none`
  with `cands` > 0 (haiku declined).

## 2. Reader (`mods/memory/feedback/reader.ts`, bun)

Imports the mod's own functions (`isLogRecord`, key helpers) rather than
porting them (LRN-261). Transcript loading lives in
`mods/memory/feedback/transcripts.ts`.

### Inputs

- The store file `~/.claude/plugins/store/memory_skills-dir-*.json`, every
  `l:<root>` key, all roots. Engine-internal path: a missing or unparsable
  file fails loudly.
- Transcripts `~/.claude/projects/<slug(root)>/<session>.jsonl`, slug = the
  root with every non-alphanumeric character replaced by `-`.
- `~/.claude/memory-feedback/state.json`: last run, labelled record keys
  (`root|session|at|channel`), tool-gate extension flag (LRN-027).

### Population

Records with a `cands` field (prompt channel) or written after the first
such record (tool channel), not yet labelled. The gate clock starts at the
first record carrying `cands`.

### Join

- Prompt, `injected`: the `attachment` record with `hook_additional_context`
  and `hookName` `prompt.submit` nearest after `at`, within 10 s, same
  session. Prompt = the composer user record it follows; reply = the
  assistant text blocks after it up to the next composer prompt, deduped by
  `message.id` (EVAL-037).
- Prompt, `none` / `timeout` / `refused` / `paused`: the last composer
  prompt of the session before `at`.
- Tool: the `tool.call` attachment carrying `toolUseID`; the failing Bash
  command and the next 3 Bash results of the session (retry succeeded or not).
- No transcript, no attachment: the record is `lost`, counted in
  FEEDBACK.md, never dropped silently (LRN-133).
- `cited`: the entry ID appears in the reply text (lower bound).

### Commands

- `worksheet <dir>`: writes `<dir>/worksheet.md` and `<dir>/items.json`
  (mode 0600). `<dir>` is the session scratchpad. These are the only files
  that hold prompt or reply text (prompt cut at 600 chars, reply at 800).
- `apply <dir>`: reads `<dir>/labels-draft.tsv`, refuses an unknown label,
  an unknown item, or an ID not in that item (non-zero rc, nothing
  written); appends to `labels.tsv`, updates `state.json`, regenerates
  `FEEDBACK.md`. Writes go through a temp file and rename.

### labels.tsv (`~/.claude/memory-feedback/`, 0600)

One row per injected entry, plus `missed` rows: `at, root name, session,
channel, trigger, outcome, cands, ms, pick (1-3), id, cited, label, cause`.
`label` in `relevant | irrelevant | test | missed`; `cause` only on
`missed`: `no-overlap | rank-over-30 | declined | not-triggered`. IDs and
enums only, no text.

### FEEDBACK.md (`~/.claude/memory-feedback/`)

Counts and shares only, no repo names, no IDs except in the noisy and
promotion lists: n per channel and trigger, lost count, every metric of
section 4, each gate's verdict.

## 3. Skill `/memory-feedback` and reminder

Skill steps (main loop; the labeller is Claude, the user spot-checks):

1. `worksheet` into the scratchpad.
2. Label each injected entry `relevant` or `irrelevant`; proof, bench and
   recall-testing sessions get `test`.
3. Spot check: 5 labelled items at random shown to the user, who confirms
   or flips each (LRN-168: a label is a claim).
4. Misses: on up to 5 triggered asks, search the registries
   (`memory.sh index` + bodies) for relevant entries not injected; add
   `missed` rows with a cause.
5. `apply`; print each gate's verdict. A reached gate turns its threshold
   actions into TODO proposals, approved one by one; the verdict is written
   as an EVAL entry (and a BDR when an action is decided) through
   `memory.sh`.

Reminder (`hooks/session-start.sh`, every repo): one banner line
`memory feedback: last run <n> d ago, transcripts expire at 7 → /memory-feedback`
when `state.json` is 5 days old or more (or absent while a store file
exists) and the store file is newer than `state.json`. Two `stat` calls, no
JSON parse, silent on any error.

New skill: a `routing.json` row and the citers census entry.

## 4. Thresholds and gates (`mods/memory/feedback/thresholds.ts`)

One exported table, read by the reader and by a future /prune-memory step D
(BDR-100: thresholds in one file).

| Signal | Threshold | Action |
|---|---|---|
| prompt precision (relevant / labelled injected entries) | ≥ 64 % (4c baseline 14/22) | keep |
| same, below 64 % | worst trigger kind < 50 % | tighten or drop that trigger (idle first) |
| precision of the 3rd pick | < 40 % | cap at 2 entries |
| timeout + paused share (asks with `cands` > 0) | > 25 % | revisit `RERANK_MS` or skip the rerank on short lists |
| `ms` p90 | < 2500 | lower `RERANK_MS` |
| tool precision | < 50 % | require 2 matched 4-grams, or exclude the entry |
| missed in the sampled asks | ≥ 1 ask in 3 | diagnose by cause; no fix built ahead |
| entry injected ≥ 3 times, 0 relevant | any | noisy: /prune-memory rewrites it |
| entry relevant ≥ 3 times in ≥ 2 sessions | any | promotion candidate (BDR-100) |

Gates (`gateVerdict`, pure):

- Prompt: reached at 20 labelled injected asks (non-`test`) or 35 days
  after the clock start.
- Tool: reached at 10 labelled tool injections or 35 days. Below 10 at the
  cap: `insufficient sample n=<n>`, extended once by 35 days (flag in
  `state.json`), then closed with no tuning.
- Each gate decides alone; the prompt gate never waits for the tool gate.

## 5. Errors

- Reader: fail loud (message + non-zero rc) on a missing or malformed store
  file, a malformed transcript line is skipped and counted, an invalid
  draft refuses the whole apply.
- Reminder: bounded, silent on any error, never breaks the banner.
- Mod: unchanged fail-open contract; log writes keep `.catch`.

## 6. Tests

- `register.test.ts` (4d.1): `cands` written on every prompt outcome, `ms`
  written when a rerank ran (timeout included) and absent otherwise, an
  old-shape record loads, `none` split by `cands`. Run through
  `make test suite=lib/tests/mods.test.sh`.
- `mods/memory/feedback/reader.test.ts` (bun), synthetic store and
  transcripts, no real text: each join case (injected, none, tool, lost),
  `message.id` dedupe, `cited`, apply refusals (nothing written), file
  modes, `gateVerdict` at each threshold boundary, the tool extension.
- Reminder: session-start suite cases with forced mtimes (shown, hidden,
  absent state, unreadable state).
- Live proof: one real `/memory-feedback` run on today's log (pre-4d.1
  records serve as practice, labelled `test` where they are proofs).

## Constraints honoured

BDR-125 (no Stop hook, no runtime cited flag), BDR-137 (store caps,
interactive-only prompt proof), BDR-100 (one threshold file, mechanism not
lesson), BDR-129 (registry writes through memory.sh), BDR-057 (retention
stays 7 days), LRN-124/LRN-261 (no text in store or git, import not port),
LRN-027 (state file), LRN-241 (`test` label), LRN-212 (mod edits are live:
kit tests before the edit lands), LRN-073 (fictional IDs in skill
examples), EVAL-037 (message.id dedupe).
