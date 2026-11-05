# Phase 4c Memory Recall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the right registry entries back to the model at three moments (a design or analysis prompt, a known error, the start of a context) without noise, inside the `mods/memory` mod and `hooks/session-start.sh`.

**Architecture:** One file grows: `mods/memory/hooks/register.ts` (single-file house style of model-router; the validator has no local-module story we rely on). A shared reader (memory.sh `index` through `$.process.run` for statuses, `$.fs.read` for the three registries) feeds the 4b error index, a BM25 + haiku intent recall at `prompt.submit`, and a known-error line on failing Bash results; a per-context ledger and a per-turn budget bound both channels; every injection is logged in the store. The digest is a bash block at the end of the session-start banner.

**Tech Stack:** TypeScript Claude Code mod (engine 2.1.316 types, `claude plugin test` kit), bash (session-start.sh, `lib/reconcile.sh`, `lib/memory.sh`), bun for the proof harness.

**Spec:** `docs/superpowers/specs/2026-11-04-memory-recall-design.md` (approved 2026-11-04). Contract: `.claude/tasks/contracts/2026-11-04-memory-recall-1859.md` (answers 0-11 `[gated]`). Spike: `.claude/tasks/plans/2026-11-04-memory-recall-spike/REPORT.md`.

## Global Constraints

- Every hook fails open: `.catch` → `next(e)` (or the 4b `memory_pending` failure answer), one log line per hook per session through `warnOnce`; a failing read, model call or process run attaches nothing and changes nothing.
- The mod never writes a registry and never calls a write verb of `lib/memory.sh`; the only process it runs is `bash <HOME>/.claude/lib/memory.sh -C <root> index`.
- Model id `claude-haiku-5-5` (full id, LRN-203); every `$.model.complete` and `$.process.run` is raced by an own timer (LRN-218): haiku 3000 ms, memory.sh 2500 ms.
- Regexes over prompt, tool or registry text are bounded (no nested unbounded quantifier, no `\s*` crossing a newline under `/m`) and timed on 64 KiB inputs under 50 ms each (LRN-219, LRN-259).
- Test oracles are literal strings; nothing an oracle compares is computed by the code under test (LRN-237). Secret-shaped fixtures are built at runtime by concatenation (BLK-041).
- `register.ts`: every line ≤ 80 columns; functions ≤ 25 logic lines and ≤ 5 locals where reasonable; no global mutable state (closure `State` only).
- Injection text: `<ID> <title ≤ 100> — <lesson>`; lesson = first sentence of the kind's field, ≤ 280 chars with `…`; block ≤ 1500 chars; at most 3 entries per recall.
- Keyword patterns copied verbatim from `mods/model-router/hooks/register.ts` default prompt rules at commit 9bbd1d5 (name the commit in a comment).
- Tests: `make test suite=lib/tests/mods.test.sh` while iterating; the full `make test` once before each commit that touches shell. Never touch `settings.json` (dirty on purpose) or `~/.claude/memory.json`.
- Commits: one per task, message given in the task, only the task's files.

## Review Focus

1. A BDR whose `Decision` field is 2 000 chars → the lesson is cut at 280 with `…`, and three such hits stay ≤ 1500 chars (Task 3, test RB3).
2. `$.process.run` rejects, hangs, or exits non-zero (no bash, a broken `HOME`) → recall and the error channel inject nothing, `memory_pending` still answers with `index: status reader unavailable` (Task 1, tests SR3-SR5).
3. A pasted 64 KiB log as the prompt → the query is cut to 2000 chars before tokenizing and BM25 over the real-size corpus stays fast (Task 3, test RB5).
4. Design words in every prompt of a long session → already injected IDs never come back in that context; with no candidate left, no haiku call is made (Task 4, tests IR7-IR8).
5. The same known error 20 times in a context → one injection (Task 5, test TE4).

---

### Task 0: Preflight (controller)

- [ ] `git branch --show-current` → `feature/memory-recall`; `make test suite=lib/tests/mods.test.sh` green at fb6cbf1; `grep -c "test(" mods/memory/hooks/register.test.ts` noted; `ls lib/tests/*.test.sh | head` and the Makefile `test` target read to learn how a new shell suite is picked up. Drift → re-plan.

### Task 1: Shared reader (statuses from memory.sh, entries with lessons)

**Files:** Modify `mods/memory/hooks/register.ts` (index block ~386-523, `loadIndex`, `formatPending` callers), `mods/memory/hooks/register.test.ts`.

**Interfaces:**
- Produces:
  - `export type Kind = 'BDR' | 'LRN' | 'BLK'`
  - `export type Entry = { id: string; kind: Kind; title: string; lesson: string; body: string }`
  - `export function entriesOf(text: string): Entry[]` — heading regex `/^## ((BDR|LRN|BLK)-\d+)\b[ \t]*[—-]?[ \t]*([^\n]{0,300})$/gm`; `title` = the heading text after the ID with a trailing `[tag]` and ` (date)` removed, cut at 100 with `…`; body from heading to next heading (heading included).
  - `export function lessonOf(kind: Kind, body: string): string` — label order BDR `Decision`; LRN `Apply`, `Future application`, `Pattern`; BLK `Solution`, `Real cause`; line shape `^[ \t]*-[ \t]*(\*\*)?<Label>(\*\*)?[ \t]*:[ \t]*(.{0,2000})$` (case-insensitive label, `/m`, bounded); first sentence = up to the first `. ` / `; ` followed by a capital or end, else the whole field; cut at 280 with `…`; `''` when no label.
  - `export function parseIndex(stdout: string): Map<string, string>` — rows `| ID | Date | Title | Status |` → ID → lowercased first word of Status (`''` when empty).
  - `export function isLive(status: Map<string, string>, id: string): boolean` — false when the word is `superseded` or `deprecated`, true otherwise (an ID absent from the map is live).
  - `async function statusMap($: Api, root: string): Promise<Map<string, string> | undefined>` — `$.env.get('HOME')`, then `$.process.run(['bash', `${home}/.claude/lib/memory.sh`, '-C', root, 'index'], { timeoutMs: 2000 })` raced by a 2500 ms timer; `undefined` on timeout, rejection, missing HOME or `exitCode !== 0`.
  - `type Registries = { entries: Entry[]; status: Map<string, string> | undefined; index: Map<string, string>; note: string }`
  - `async function loadRegistries($: Api, root: string): Promise<Registries>` replaces `loadIndex`: reads `decisions.md`, `learnings.md`, `blockers.md` with the 4b `tryRead`; `index` = `buildIndex(entries.filter(BLK|LRN), status)`; `note` = the 4b `index:` line (now naming three files) plus `; status reader unavailable` when `status` is undefined.
  - `export function buildIndex(entries: Entry[], status: Map<string, string> | undefined): Map<string, string>` — `status === undefined` → empty map (nothing is known without statuses); else the 4b span/gram rule over live entries.
- Removed: `isSuperseded`, `STATUS`, the `shortcut:` comment above it; the TODO.md line harvesting it is ticked in Task 7.
- Consumed by: `pendingAnswer`, `newFailureCount` (switch to `loadRegistries`).

- [ ] **Step 1: tests (literal oracles)**
  - `SR1` `parseIndex` on a literal 4-line stdout (`.claude/memory/decisions.md`, header, separator, `| BDR-031 | 2026-06-25 | t | superseded |`, `| LRN-001 | 2026-01-01 | t |  |`) → `BDR-031`→`superseded`, `LRN-001`→`''`.
  - `SR2` a test-side `on('process.run', …)` answering that stdout with exit 0 → `memory_pending` lists a failure matching a BLK span as `known BLK-…`, and an entry marked superseded in the stdout is not indexed (its matching failure reads `NEW`).
  - `SR3` `process.run` throws → the answer holds `status reader unavailable` and the failure reads `NEW`; `SR4` exit code 2 → same; `SR5` `process.run` never settles → the answer arrives (clock advanced 2500 ms) with `status reader unavailable`.
  - `LS1`-`LS4` `lessonOf`: BDR `- **Decision**: Use X. Then Y.` → `Use X.`; LRN with `Pattern` and `Apply` → the `Apply` text; BLK `- Solution: fix z` → `fix z`; a 2 000-char field → 280 chars ending `…`.
  - `EN1` `entriesOf` on `## BDR-007 — Title here [accepted] (2026-01-02)` → title `Title here`; a `## Notes` heading is not an entry.
  - Update IDX tests whose oracle assumed the lexical superseded reader or the 2-file `index:` line, each to a literal new expectation; list them in the report.
  - `TIMEentries` `entriesOf` + `lessonOf` on a 64 KiB registry of one entry with a 64 KiB field → < 50 ms.
- [ ] **Step 2:** run `make test suite=lib/tests/mods.test.sh` → new tests FAIL.
- [ ] **Step 3:** implement; remove `isSuperseded`/`STATUS`/`shortcut:`.
- [ ] **Step 4:** suite green; `awk 'length($0) > 80' mods/memory/hooks/register.ts | wc -l` → 0.
- [ ] **Step 5:** commit `feat(memory): status reader through memory.sh, entries with lessons`.

### Task 2: Errno phrases out of the error index

**Files:** `register.ts` (`grams`, `PLACEHOLDERS`), `register.test.ts`.

**Interfaces:**
- Produces: `export const ERRNO_PHRASES: readonly string[]` (the 18 phrases of spec Unit 3, lowercase); `export function deErrno(normLine: string): string` — each phrase (word-bounded, after `normalize`) → `<errno>`; `grams` calls `deErrno` first; `PLACEHOLDERS` gains `<errno>`.
- Consumed by: `buildIndex`, `matchOf` (unchanged signatures).

- [ ] **Step 1: tests**
  - `ER1` entry span `` `cat: x: No such file or directory (os error 2)` `` and failure line `ls: cannot access '/tmp/zz': No such file or directory` → NEW (the LRN-056 collision, reproduced on a fixture).
  - `ER2` entry span `` `fatal: unable to access remote host thing` `` and the same failure line text → `known` (content grams still match).
  - `ER3` `deErrno('cat: <path>: no such file or directory (os error #)')` → `'cat: <path>: <errno> (os error #)'`.
  - `ER4` `grams` of `'<errno> <path> # <hex>'` → `[]`.
  - `TIMEerrno` `deErrno` on 64 KiB of `no such file or ` repeats → < 50 ms.
- [ ] **Step 2:** FAIL. **Step 3:** implement. **Step 4:** green, width 0.
- [ ] **Step 5:** commit `fix(memory): errno phrases never make an error known`.

### Task 3: BM25 ranking, rerank prompt, answer parse, recall block (pure)

**Files:** `register.ts` (new block after the index block), `register.test.ts`.

**Interfaces:**
- Produces:
  - `export function tokensOf(text: string): string[]` — lowercase, `[\p{L}\p{N}]{2,40}` runs (bounded), minus `STOP_WORDS` (a const of ≤ 60 FR+EN function words: the, and, for, with, that, this, from, les, des, une, pour, dans, avec, est, pas, que, qui, sur, …).
  - `export function bm25Rank(entries: Entry[], query: string, k: number): Entry[]` — query = `cap(query, 2000)`; document = title + lesson + body; k1 1.2, b 0.75, idf `ln(1 + (N - df + 0.5) / (df + 0.5))`; entries with score > 0, highest first, ties by ID order, at most `k`.
  - `export function rerankPrompt(query: string, cands: Entry[]): string` — exactly:
    `Prompt: <redact(cap(query, 2000))>\nCandidates:\n<ID> | <title> | <lesson>` (one line per candidate)`\nAnswer with at most 3 candidate IDs that would help with this prompt, comma separated, or none.`
  - `export function parseIds(text: string, cands: Entry[], max: number): string[]` — `/(?:BDR|LRN|BLK)-\d{1,5}/g` matches, kept when a candidate ID, deduplicated, order kept, at most `max`.
  - `export function recallLine(e: Entry): string` — `${e.id} ${e.title} — ${e.lesson}` (no ` — ` when the lesson is empty).
  - `export function recallBlock(lines: string[], cap: number): string` — `memory recall:` + `\n` + lines; a line that would make the block exceed `cap` is dropped; `''` when no line fits.
- [ ] **Step 1: tests**
  - `RB1` three fixture entries; query `quoting heredoc shell` → the heredoc entry first (literal ID order oracle).
  - `RB2` `parseIds('BLK-041, BDR-999, LRN-258', cands, 3)` with cands BLK-041, LRN-258 → `['BLK-041', 'LRN-258']`; `parseIds('none', …)` → `[]`.
  - `RB3` three BDR entries with 2 000-char Decision fields → each line's lesson ends `…`, `recallBlock(…, 1500).length <= 1500`, literal first line.
  - `RB4` `rerankPrompt` on two candidates → the literal expected string.
  - `RB5` `bm25Rank` over 500 synthetic entries of 1 600 chars and a 64 KiB query → < 300 ms (and the query really cut: a token beyond char 2000 does not change the order).
  - `RB6` a query with a token built at runtime as a secret shape (`'sk_live_' + 'a'.repeat(24)`) → `rerankPrompt` holds `<redacted:stripe>`.
- [ ] **Step 2:** FAIL. **Step 3:** implement. **Step 4:** green, width 0.
- [ ] **Step 5:** commit `feat(memory): bm25 ranking and the rerank prompt`.

### Task 4: Intent recall at prompt.submit (trigger, haiku, ledger, budget, log, switch)

**Files:** `register.ts` (`State`, `newState`, `loadEnabled`, `registerSession`, `registerPrompt`, store `Project` type), `register.test.ts`.

**Interfaces:**
- `State` gains: `recall: boolean | null` (the `"recall"` key, read with `enabled`), `seen: Map<string, Set<string>>` (context key → injected IDs), `spent: Map<string, number>` (context key → chars injected this turn / this context), `fresh: Set<string>` (session ids whose next qualifying prompt is a context start), `lastPrompt: Map<string, number>` (session id → time of the last composer prompt).
- `loadEnabled` returns `{ enabled: boolean; recall: boolean }`; `"recall": false` → recall off; a non-boolean `recall` logs one line (`memory: ~/.claude/memory.json has no boolean "recall", recall stays on`) and counts as absent. `ensureEnabled` keeps its boolean contract; add `ensureRecall($, st): Promise<boolean>`.
- `export const DESIGN_RULE`, `export const ANALYSIS_RULE` — the two router patterns (commit 9bbd1d5), flags `iu`.
- `export function isTrigger(text: string, fresh: boolean, idleMs: number): boolean` — `!text.startsWith('/')`, ≥ 12 code points, and (`fresh` or `idleMs >= 1800000` or a rule matches).
- `export const IDLE_MS = 1800000`, `export const RECALL_CAP = 1500`, `export const HAIKU = 'claude-haiku-5-5'`, `export const RERANK_MS = 3000`.
- `function contextKey(session: string, agent: string | undefined): string` → `${session}:${agent ?? 'main'}`.
- `export function onContextStart(st: State, session: string): void` — deletes every `seen`/`spent` key starting `${session}:`, adds `session` to `fresh`. Called from `session.start` and from a new `classic.SessionStart` hook when `source` is `startup`, `clear` or `compact` (`resume` → nothing).
- `async function recallFor($: Api, st: State, at: Where, text: string): Promise<string>` — loads registries; `status === undefined` → `''`; candidates = `bm25Rank(entries filtered by isLive and not in seen[key], text, 30)`; none → `''` without a model call; `$.model.complete({ model: HAIKU, prompt: rerankPrompt(text, cands), effort: 'low', maxTokens: 64, timeoutMs: RERANK_MS })` raced by `RERANK_MS`; not answered / timeout / throw → `''`; ids → lines → `recallBlock(lines, RECALL_CAP - spent)`; records ids in `seen`, chars in `spent`, and a log record.
- Project store gains `log?: { at: number; session: string; agent: string; channel: 'prompt' | 'tool'; ids: string[] }[]`, kept ≤ 200 (oldest dropped) through the 4b write chain (`queueWrite` + `loadProject`/`saveProject`); `asProject` keeps a valid `log` array and drops malformed records.
- `registerPrompt`: on a composer, non-mid-turn prompt with a non-empty root: (1) the 4b note as today; (2) when `ensureRecall` and `isTrigger(text, fresh.has(session), now - lastPrompt)`: clear `fresh` for the session, reset the main key's `spent`, append the recall block when non-empty; (3) `lastPrompt.set(session, now)` on every composer prompt. Both contexts go in one `next({ ...e, context: [...(e.context ?? []), note?, block?] })`. `session.end` also clears `seen`, `spent`, `fresh`, `lastPrompt`, `recall`.
- [ ] **Step 1: tests** (a bottom `on('model.complete', …)` recording asks, `on('process.run', …)` answering a fixture index, `mock.clock`)
  - `IR1` first composer prompt of a session `on va concevoir la suite du mod` (no keyword) → one ask; context holds the literal block `memory recall:\nBLK-001 …`.
  - `IR2` a second ordinary prompt 1 min later without keyword → no ask, no block.
  - `IR3` 31 min later an ordinary prompt → an ask.
  - `IR4` `/feat add x` → no ask; a mid-turn prompt (`turnId` set) → no ask; origin `sdk` → no ask; 11-char prompt → no ask.
  - `IR5` the model answers `BDR-999, BLK-001` (BDR-999 not a candidate) → only BLK-001 injected; answers `none` → no block; never settles → no block after `RERANK_MS` (clock advanced) and the prompt passes; `isAnswered: false` → no block.
  - `IR6` `classic.SessionStart` `compact` (fired with `$.classic.SessionStart({ source: 'compact' })` in the test) → the next ordinary prompt asks again and BLK-001 may come back; `resume` → no reset.
  - `IR7` design keyword in three prompts in a row → BLK-001 injected once only (later asks never list it as a candidate).
  - `IR8` every candidate already seen → no ask at all.
  - `IR9` `"recall": false` in the switch file → no ask, the 4b note still attached after a milestone; `"recall": "no"` → recall on + one log line.
  - `IR10` process.run fails → no ask, prompt unchanged.
  - `IR11` after an injection, `loadProject` holds one `log` record `{channel: 'prompt', ids: ['BLK-001']}`; 205 injections → 200 records kept.
  - `IR12` a milestone pending and a trigger on the same prompt → context `[note, block]` in that order.
  - `TIMErules` both rules on 64 KiB of letters → < 50 ms.
- [ ] **Step 2:** FAIL. **Step 3:** implement. **Step 4:** green, width 0.
- [ ] **Step 5:** commit `feat(memory): intent recall at the prompt, once per context`.

### Task 5: Known-error line on failing Bash results

**Files:** `register.ts` (`captureFailure` returns the built failure, `registerBash`), `register.test.ts`.

**Interfaces:**
- `captureFailure` returns `Promise<Failure | undefined>` (the failure it built, stored or not).
- `async function knownLine($: Api, st: State, at: Where, f: Failure, agent: string | undefined): Promise<string>` — `ensureRecall` false → `''`; registries; `status === undefined` → `''`; `id = matchOf(index, f.key)`; none, or already in `seen[key]` → `''`; entry → `memory: known ${recallLine(entry)}`; when its length exceeds `RECALL_CAP - spent[key]` → `''`; records `seen`, `spent`, and a `tool` log record.
- `registerBash`: after capture, `line !== ''` → `return { ...out, context: [...(out.context ?? []), line] }`; else `return out` (unchanged object).
- [ ] **Step 1: tests**
  - `TE1` a failing command whose line matches a fixture BLK span → the answer keeps `isError`, `text`, `result` and gains `context: ['memory: known BLK-002 …']` (literal).
  - `TE2` an ENOENT line (the ER1 fixture) → no `context` key added (answer deep-equal to the tool's).
  - `TE3` a sub-agent (`agentId: 'a1'`) failure → injected; the same failure in the main loop → injected too (separate keys).
  - `TE4` the same failure 20 times in one context → one injection.
  - `TE5` `"recall": false` → no context, capture still stored.
  - `TE6` a matched entry superseded in the status stdout → no injection.
  - `TE7` budget: `spent` at 1450 for the main key and a 200-char line → no injection.
- [ ] **Step 2:** FAIL. **Step 3:** implement. **Step 4:** green, width 0.
- [ ] **Step 5:** commit `feat(memory): known-error line on failing commands`.

### Task 6: Earlier-session milestones in memory_pending

**Files:** `register.ts` (`formatPending`, `milestoneText`), `register.test.ts`.

**Interfaces:** `formatPending` lists the current session's milestones under `milestones:` (header renamed from `milestones (this session):`), then the earlier sessions' (newest session first), each earlier line ending ` (earlier session)`. Check `grep -rn "milestones (this session)" skills agents lib docs README.md USAGE.md` and update every citer in the same commit (BDR-100).
- [ ] **Step 1: tests** `PM1` current + one earlier milestone → literal lines in that order; `PM2` only an earlier milestone (the 4b live-proof case) → the answer is not `nothing captured` and holds `- commit fix: probe (HH:MM) (earlier session)` (HH:MM from the test clock through the same local-time helper the 4b tests use).
- [ ] **Step 2-4:** FAIL, implement, green.
- [ ] **Step 5:** commit `feat(memory): memory_pending lists earlier-session milestones`.

### Task 7: Session digest in session-start.sh

**Files:** Modify `hooks/session-start.sh` (end of file, before the final `echo ""`); Create `lib/tests/session-digest.test.sh` (or the name the Makefile's discovery requires, Task 0).

**Interfaces:** a function `_memory_digest <project-root>` printing the block of spec Unit 5:
```
memory digest:
- open: BLK-017 Bing Webmaster API unusable for a multi-client agency (W2…
- open: +1 more, +3 upstream
- todo: deferred (BDR-123): remap inline-writing best-tier skills …
- journal: 2026-11-04 — 4b memory capture merged into develop …
```
Source handling: `_ss_source=''`; `if [ ! -t 0 ]; then _ss_in=$(timeout 1 cat 2>/dev/null); _ss_source=$(printf '%s' "$_ss_in" | jq -r '.source // empty' 2>/dev/null); fi`; digest when `_ss_source` is empty, `startup`, `clear` or `compact`. Root = `git rev-parse --show-toplevel` else `pwd`; `.claude/memory/` absent → nothing. Open BLK through `lib/reconcile.sh` `reconcile_blk_open` (source the lib from `$_repo_dir/lib`), status word `open` listed (≤ 3, then `+N more`), `upstream` counted; TODO: first 3 `- [ ]` lines under `### Actionable` up to the next `#` heading, the `- [ ] ` prefix dropped; journal: last line starting `- `. Every line cut at 160 chars (`…`), block cut at 800. All digest commands `2>/dev/null`; the function's failure never changes the exit code (`|| true`).
- [ ] **Step 1: tests** (a `mktemp -d` fixture project per case, literal expected output):
  `SD1` source startup with 1 open + 2 upstream BLK, a TODO with 4 unchecked items, a journal → the literal block (3 todo lines, `+2 upstream`); `SD2` source `resume` → no `memory digest:`; `SD3` `</dev/null` → digest printed (empty source), exit 0; `SD4` no `.claude/memory` → no block; `SD5` TODO without `### Actionable` → no todo line; `SD6` a 400-char journal line → cut at 160 with `…`; `SD7` 10 open BLK with long titles → block ≤ 800 chars; `SD8` the existing callers (`lib/tests/memory.test.sh` T13c/d, `push-guard.test.sh`, `graphify-gate.test.sh`) still green.
- [ ] **Step 2-4:** FAIL, implement, `bash lib/tests/session-digest.test.sh` green, `shellcheck hooks/session-start.sh lib/tests/session-digest.test.sh` clean, full `make test` green.
- [ ] **Step 5:** commit `feat(hooks): memory digest at session start`.

### Task 8: Measured proof harness (controller + one sonnet dispatch)

**Files:** Create `.claude/tasks/plans/2026-11-04-memory-recall-spike/recall-bench.ts` (bun, imports `entriesOf`, `lessonOf`, `parseIndex`, `isLive`, `bm25Rank`, `rerankPrompt`, `parseIds`, `recallBlock`, `normalize`, `failureLine`, `redact`, `buildIndex`, `matchOf`, `deErrno` from `mods/memory/hooks/register.ts`), `RECALL.md` (counts and shares only).
- [ ] **Step 1 (sonnet):** the harness: mode `prompts` reads the last 14 days of `~/.claude/projects/-home-bchanot-Documents-claude/*.jsonl` (main-loop files only), keeps composer user prompts (string content, not a slash command, not a tool result) that meet `isTrigger` with `fresh` true for each session's first prompt and real idle gaps from timestamps, samples 20 with `--seed`, runs the real reader on this repo (`bash lib/memory.sh index` via `Bun.spawnSync`), BM25 top-30, then haiku through `claude -p --model claude-haiku-5-5 --output-format json` with `rerankPrompt` as the prompt, times each call, prints per prompt the prompt's first 120 chars (redacted) and the injected IDs + titles, and totals: asks, injections, mean IDs, timeout share at 3 s. Mode `errors` replays the Bash failures of the same 14 days (main + `*/subagents/*.jsonl`) through `failureLine` + the error index and prints per session the injections and each injected `(line, ID, title)` (redacted). Read-only; writes nothing but stdout.
- [ ] **Step 2 (controller):** run both modes; label each injected entry relevant / not relevant to its prompt or error; show the labels to the user at the merge gate; write `RECALL.md`: counts, the relevant share for each channel, the timeout share, the per-session injection rate, no prompt or error text.
- [ ] **Step 3:** gate input: relevant share < 64 % on either channel, or a timeout share > 25 %, → propose a change (tighter trigger, fewer candidates, `RERANK_MS` 5000) at the merge gate.
- [ ] **Step 4:** commit `chore(bench): phase 4c recall precision measured on 14 days of transcripts`.

### Task 9: Docs and TODO (sonnet)

**Files:** `README.md`, `USAGE.md` (French), `CHANGELOG.md` `[Unreleased]`, `ARCHITECTURE.md` (mods line), `.claude/tasks/TODO.md`.
- [ ] Content: recall triggers (first prompt of a context, after 30 min idle, design/analysis words; never slash commands), what is injected and its cap, the known-error line, the digest and its sources, `"recall": false`, the injection log (kept, not shown), residuals (3 s bound drops a share of recalls, the router's classifier label is not used, sub-agents get the error channel only, EVAL not recalled). TODO: 4c sub-bullet "built … merge pending", 4d line: "the injection log now exists (4c), 4d waits on its data", the 4b `shortcut:` harvest line ticked (the lexical superseded reader is gone, Task 1). `make test suite=lib/tests/doctrine-citers.test.sh` green.
- [ ] commit `docs: memory recall, known-error line and session digest`.

### Task 10: Live proof (controller + user)

- [ ] **Headless:** a `mktemp -d` repo on a feature branch, `.claude/memory/blockers.md` fixture with a BLK whose backticked span is `` `fatal: unable to access probe remote xyz` ``, `claude -p --model haiku` runs `git ls-remote https://127.0.0.1:9/probe.git` style command failing with that text (or a script echoing it to stderr with exit 1), then reports the context lines it saw: expect `memory: known BLK-001 …`.
- [ ] **Interactive (user):** in a fresh session in this repo, a design prompt → the transcript holds one `memory recall:` attachment on that prompt; `/compact` → the next session-start context holds `memory digest:`; record both in the contract § PROOF.
- [ ] `make test` all green; `shellcheck ./*.sh hooks/*.sh lib/*.sh` clean.

## R2 CHANGES (challenge r1: correctness CONCERNS(5), robustness CONCERNS(4), simplicity CONCERNS(1); no BLOCKER; these override the task text above)

Task split: Task 4 becomes **4a** (switch key, log store, ledger and its resets: IR6, IR9, IR11 + the tests below) and **4b** (trigger, BM25 candidates, rerank: IR1-IR5, IR7, IR8, IR10, IR12, TIMErules). Task 5 depends on 4a only.

Task 0 (rob 11): tell the user before Task 1 that the working-tree mod is live in their sessions and the executors' from the first save, and that adding `"recall": false` to `~/.claude/memory.json` themselves is the kill switch during the build.

Task 1 — reader:
- `boot` in register.test.ts gains one `process.run` bottom driven by a World field (default: a literal `memory.sh index` stdout matching the fixture registries, BLK-001 open, LRN-002 superseded), so IDX1, the order test and NT1b keep their meaning; IDX3 is re-anchored on that stdout; SR3-SR5 set the field to throw / exit 2 / hang (corr 3).
- `parseIndex` returns `Map<id, {status, title}>`; titles come from memory.sh (fence-aware, tag and date stripped), `entriesOf` only splits bodies (heading regex = 4b `HEADING` widened to `BDR|LRN|BLK`, no title capture); EN1's title oracle moves to SR1 (simp 2).
- Bounded captures carry no `$`: the label regex takes `.{0,2000}` as a prefix of the line, the heading `[^\n]{0,300}` likewise; tests at a 2 001-char Decision (lesson still cut at 280) and a 320-char heading (still an entry) (corr 4, rob 5).
- `loadRegistries($, root, names)`: the 4b callers (`pendingAnswer`, `newFailureCount`) pass `['blockers.md', 'learnings.md']` and keep their `index:` line unchanged; recall passes the three files (simp 3).
- Status unavailable: `memory_pending` still labels NEW/known from all entries (advisory), with `status reader unavailable` on the `index:` line; injections stay off (rob 7).
- A real-registry check in the test (skipped when the repo files are absent): the `entriesOf` IDs equal the `parseIndex` IDs on this repo (rob 6).
- `isLive`: an ID absent from the map while the map exists is NOT live (fail closed on AC3) (rob 6).
- `process.run` is skipped when no registry file was read (rob 3).

Task 2 — errno phrases: `input/output error` is listed as `<path> error` (normalize already turned `input/output` into `<path>`); ER case for it (corr 7, rob 14).

Task 3 — harness-facing exports: export `isTrigger`, `IDLE_MS`, `DESIGN_RULE`, `ANALYSIS_RULE` and a `failureKey(text, command)` wrapper of the `buildFailure` chain (tail → redact → lastLine → normalize) for the harness (simp 5, corr 12).

Task 4a — ledger:
- The main key's `spent` resets on EVERY composer non-mid-turn prompt (outside the trigger branch); test: recall on prompt 1, ordinary prompt 2, then a known error is injected (corr 1, rob 1).
- One context-start call site: the `classic.SessionStart` hook on `startup | clear | compact` (not `session.start`); `resume` changes nothing; a `classic.SessionStart` carrying `agent_id` resets only that agent's key; `session.end` clears by the ending session's id only; keys use `$.session.id()` (corr 9, simp 4).
- A missing `lastPrompt` means not idle (rob 10).
- Check-and-record of `seen`/`spent` run synchronously after the last await; test: two concurrent failing Bash calls → one injection (rob 9).
- The log: `saveProject` persists `log`; the sweep keeps a project key that still holds a log (it drops sessions first); test: an injection, then a failure capture, then a sweep → the log still holds the record (corr 11, rob 8).
- Switch: an absent `enabled` key with `"recall": false` logs nothing; only a present non-boolean logs (corr 6).

Task 4b — trigger and rerank:
- Registries load once per `prompt.submit` and are shared by the 4b note and recall (rob 3).
- A consecutive-failure pause for the rerank, modelled on the router's: 3 failed or timed-out reranks in a row → no rerank for 15 min (in the closure), reset on a success; test (rob 3).

Task 5 — sub-agent delivery of the known line is verified headless in Task 10 or listed as a residual (corr 10).

Task 7 — digest (corr 2, 8, 13; rob 2, 13; simp 1):
- Open BLK come from `bash "$_mem_lib" -C "$root" index blocker` (rows `| ID | date | title | status |`, status `open` listed, `upstream` counted), NOT `reconcile_blk_open`; reconcile.sh is not sourced.
- The digest runs in a subshell: `( _memory_digest "$root" ) 2>/dev/null || true`; the lib path is `$(dirname "${BASH_SOURCE[0]}")/../lib/memory.sh` (like the neighbours), never `$_repo_dir` (unset by then).
- stdin is read at the TOP of session-start.sh, behind `command -v timeout jq` (without them: no source, the digest prints only on an empty-stdin manual run, never guessed as startup).
- Cuts are char-safe (awk under a UTF-8 locale, or `cut -c` checked with a non-ASCII SD6 line containing `—`).
- SD9: a digest that hits an unset variable still exits 0 and leaves the banner intact.

Task 8 — harness (corr 5, 12, 15; rob 4; simp 5):
- Prompts from main-loop files whose `entrypoint == "cli"` only (no `sdk-*` sessions); the walk reuses `noise.py`'s `pairs_of`/`find_files` logic as reference (ported in TS, the source named).
- haiku runs from a `mktemp -d` cwd with `--setting-sources local`, no tools; latency from the JSON `duration_api_ms`, labelled an upper bound.
- Every share is reported with its n; fewer than 10 injections on a channel → "insufficient sample" at the gate, not a pass or a fail.

Task 9 — docs: also the plugin.json `description` and the register.ts header comment (no version bump) (simp 6, corr 14).

Task 10 — headless recipe copies LRN-260 (`GITFLOW_NO_PUSH=1`, `--allowedTools` naming the one probe command) (rob 12); a memory fixture body is written with Write + `--body-file`, never a heredoc quoting an extraction command (extract-guard, LRN-262).
