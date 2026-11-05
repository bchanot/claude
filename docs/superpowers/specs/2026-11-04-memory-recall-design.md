# Phase 4c memory recall — design (2026-11-04)

BDR-125 phase 4c, host `mods/memory` (BDR-137). Contract
`.claude/tasks/contracts/2026-11-04-memory-recall-1859.md` (brainstorm answers
0-11 `[gated 2026-11-04]`). Engine facts:
`.claude/tasks/plans/2026-11-04-memory-recall-spike/REPORT.md` (CLI 2.1.318).
Branch `feature/memory-recall`.

## Goal
The registries hold the lessons; nothing brings them back when they matter.
4c brings back the right entries at three moments, without noise: when a
design or analysis prompt starts work, when a known error comes back, and at
the start of every context. Writing is untouched (4b capture, memory.sh).
Success: precision of the injected entries at or above the 14/22 baseline
(64 %), the error channel's noise measured before shipping, a digest seen
after a real compaction.

## Unit 1 — shared reader (register.ts)
- Status and titles: `lib/memory.sh -C <root> index` through `$.process.run(['bash',
  <HOME>/.claude/lib/memory.sh, '-C', root, 'index'], {timeoutMs: 2000})`,
  raced by an own 2.5 s timer; rows `| ID | Date | Title | Status |`. memory.sh
  is the single reader (BDR-129): `parseIndex` returns `Map<id, {status,
  title}>`, the title already fence-aware with tag and date stripped, and an ID
  is closed for recall when its status word is `superseded` or `deprecated`.
  An ID absent from a map that exists is not live (fail closed). The script
  path is `$HOME/.claude/lib/memory.sh`. The run is skipped when no registry
  file was read.
- Status unavailable (failed, timed out or malformed read): `memory_pending`
  still labels each failure `NEW` or `known <ID>` from ALL entries (advisory,
  superseded ones included) and its `index:` line ends `status reader
  unavailable`; recall and the error channel inject nothing.
- Entries: `decisions.md`, `learnings.md`, `blockers.md` read with `$.fs.read`
  (stat first, 4 MiB cap per file). `entriesOf` only splits bodies (heading
  regex = the 4b one widened to `BDR|LRN|BLK`, no title capture); the pure
  `assembleEntries(texts, index)` joins kind, the memory.sh title cut at 100
  with `…`, the lesson and the body into `{id, kind, title, lesson, body}`.
  4b callers load `blockers.md` and `learnings.md` only.
- Lesson line: BDR the `Decision` field; LRN `Apply`, else `Future
  application`, else `Pattern`; BLK `Solution`, else `Real cause` (label match
  case-insensitive, bold or plain); its first sentence, cut at 280 chars with
  `…`; none → empty lesson (title only). Label and heading regexes carry
  bounded prefixes (`.{0,2000}`, `[^\n]{0,300}`), no `$`.
- The 4b lexical `isSuperseded` and its `shortcut:` comment are gone: the error
  index takes its live set from the same status map.

## Unit 2 — intent recall (`prompt.submit`)
- Trigger: origin `composer`, `turnId` absent, not a slash command (text not
  starting `/`), ≥ 12 code points, and at least 5 content words (tokens minus
  the stop-word list; measurement gate 2026-11-05, `MIN_CONTENT_WORDS`), and
  one of: the first such prompt of the context (set at `session.start` and
  consumed by the first qualifying prompt; a new context starts through the
  classic `SessionStart` hook on source `startup`, `clear` or `compact`, keyed
  by the event's `session_id` when present, else `$.session.id()`); the first
  after ≥ 30 min without a composer prompt in this session; a match of the
  design or analysis keyword patterns, copied from model-router's default
  prompt rules (`mods/model-router/hooks/register.ts`, commit 9bbd1d5):
  `plan|planifie|planning|brainstorm|architecture|con[cç]ois|design` and
  `pourquoi|why|explique|explain|analyse|analyze|comprendre|understand|review|audit`,
  same word boundaries.
- Rank: BM25 (k1 1.2, b 0.75) over title + lesson + body of the live
  BDR/LRN/BLK entries, tokens = lowercase letter/digit runs of ≥ 2 chars minus
  a short FR+EN stop-word list; the query is the prompt's first 2000 chars,
  redacted (4b `redact`). Entries already injected in this context are
  removed before ranking. Top 30 with a score > 0.
- Rerank: `$.model.complete({model: 'claude-haiku-5-5', effort: 'low',
  maxTokens: 64, timeoutMs: 5000, prompt})`, raced by an own 5 s timer
  (`RERANK_MS`; measurement gate 2026-11-05: 29 % of calls ran over 3 s)
  (LRN-218). The prompt: the redacted query, the candidates one per line as
  `ID | title | lesson`, and the instruction to answer at most 3 IDs, comma
  separated, or `none`. The answer is parsed for `(BDR|LRN|BLK)-\d+`, kept
  only when the ID is a candidate, at most 3, order kept.
- Inject: one context block `memory recall:` then one line per entry
  `<ID> <title ≤ 100> — <lesson>`; the block ≤ 1500 chars (an entry that
  would overflow is dropped). No candidate, a `none`, a timeout, a refusal or
  any error → nothing attached, the prompt passes unchanged.
- The 4b milestone note on the same prompt is attached first; recall follows.

## Unit 3 — tool-error recall (Bash `tool.call`)
- After the 4b capture (same failure rule, same redacted line): the failure's
  key is matched against the error index (live BLK/LRN, Unit 1); a match whose
  ID was not injected in this context attaches `memory: known <ID> <title ≤
  100> — <lesson>` to the tool answer's `context` (the answer keeps its shape,
  LRN-205; spike: the model sees it).
- Common phrases: before gramming, both the entry spans and the failure key
  replace each errno phrase by the placeholder `<errno>`; a gram made only of
  placeholders is skipped (LRN-258, `<errno>` joins `#`, `<path>`, `<hex>`).
  Phrases: no such file or directory, permission denied, command not found,
  is a directory, not a directory, file exists, directory not empty,
  operation not permitted, no space left on device, connection refused,
  connection timed out, broken pipe, resource temporarily unavailable,
  invalid argument, too many open files, read-only file system, device or
  resource busy, input/output error.
- Main loop and sub-agents (the context key carries the agent id).

## Unit 4 — ledger, budget, log
- Once per context: `st.seen: Map<contextKey, Set<ID>>`, key = session id +
  (`agentId` or `main`); cleared at `session.end`, and the session's keys on
  `classic.SessionStart` source `clear` or `compact`.
- Budget: the main loop has 1500 chars per turn, shared by both channels,
  reset by each composer prompt; a sub-agent (error channel only) has 1500
  chars for its whole context.
- Log: each injection appends `{at, session, agent, channel: 'prompt' |
  'tool', ids}` to its own store key `l:<root>` (≤ 200 records, ≤ 64 KiB,
  oldest dropped), outside the session sweep and the project value; never
  displayed; 4d reads it. No cross-root cap (TODO `shortcut:`).

## Unit 5 — session digest (`hooks/session-start.sh`)
- Reads the hook JSON from stdin only when stdin is not a terminal, with
  `timeout 1`; `source` taken with jq. Prints the digest for `startup`,
  `clear`, `compact`, and for an empty source (a manual run); never for
  `resume`. Without `timeout` or `jq` the source is unknowable: the digest
  prints only when stdin is a terminal, never from a hook.
- Only in a project whose git toplevel (else cwd) has `.claude/memory/`:
  `memory digest:` then up to four kinds of lines:
  open BLK from `memory.sh -C <root> index blocker` (run under `timeout 2`,
  rows with status word `open`: `- open: BLK-n title`, ≤ 160 chars each, at
  most 3, then `+N more`), the upstream ones counted (`+N upstream`); the first
  3 unchecked `- [ ]` items under `### Actionable` in `.claude/tasks/TODO.md`
  (≤ 160 chars each); the last `- ` line of `.claude/memory/journal.md`
  (≤ 160 chars). Cuts use bash `${v:0:159}…` and stay valid UTF-8.
- Block ≤ 800 chars. Header, BLK lines, the count line and the journal line
  always stay; TODO lines are added in order while they fit, so under the cap
  they drop first, whole lines, never a mid-line cut. Any missing file or
  section → that line is omitted; nothing to show → no block. Fail silent: a
  `memory.sh` that fails, hangs, prints malformed rows or a `blockers.md` that
  is a directory never changes the banner or the exit code.
- No SubagentStart twin.

## Unit 6 — `memory_pending`
Milestones of the earlier stored sessions follow the current session's,
marked `(earlier session)`, same 3-session window; the answer order stays
header, `index:`, milestones, failures.

## Unit 7 — off switch
`~/.claude/memory.json`: `"enabled": false` cuts everything (4b);
`"recall": false` cuts Units 2 and 3 injections only (capture, the note, the
tool and the log of past injections stay). Read like `enabled` (lazily per
session, a non-boolean logs one line and counts as absent).

## Docs
README / USAGE (fr) memory sections gain recall, the error channel, the
digest, `"recall": false`, the residuals; CHANGELOG `[Unreleased]`; TODO (4c
ticked at merge, 4d stays deferred with the log now in place).

## Proof
- Kit tests: reader (status map, lesson per kind, failure → fail open),
  trigger (first prompt, idle, keyword, slash and mid-turn excluded), BM25
  order on fixtures, rerank parse (foreign IDs dropped, `none`, timeout, never
  settles), budget and once-per-context (reset on compact/clear and
  session.end), error channel (known match attaches, ENOENT does not, sub-agent
  key), earlier milestones, `recall: false`, log cap; regex costs timed on
  64 KiB (LRN-259).
- Shell suite: the digest on fixture projects (sources, missing files, caps,
  `</dev/null`), existing session-start callers unchanged.
- Measured before shipping (LRN-261, EVAL-056): a bun harness under
  `.claude/tasks/plans/2026-11-04-memory-recall-spike/` imports the mod's own
  functions (no port) and calls haiku through `claude -p --model haiku`:
  (a) 20 real composer prompts from 14 days of this repo's transcripts that
  meet the trigger: injected IDs per prompt, timeout share at the bound; the
  controller labels each injected entry relevant or not, the user checks the
  labels; bar: relevant share ≥ 64 % (14/22). (b) the 14-day Bash failure
  replay: injections per session and the noise share on the injected ones,
  ENOENT lines included. Counts and shares only in the committed notes.
- Live: headless `-p` for the error channel (a failing command matching a
  fixture BLK attaches the line); interactive by the user for recall (a design
  prompt in a fresh session), and the digest after a real `/compact`.

## Measurement gates (2026-11-05)
`.claude/tasks/plans/2026-11-04-memory-recall-spike/RECALL.md`: on 14 days of
transcripts the rerank precision is 54 to 61 % against the 64 % bar. Decided:
recall ships on and switchable (`"recall": false`), with a content floor (5
content words, Unit 2) and `RERANK_MS` 5000 (Unit 2); the injection log feeds
4d. Error channel: n = 3, insufficient sample.

## Out of scope
Read path triggers, Bash command triggers, critical deny-once, Tier 1,
cross-repo index, `memory_search` tool, reading the router's classifier
label, a SubagentStart twin, injection citation tracking (4d), EVAL in the
recall corpus.
