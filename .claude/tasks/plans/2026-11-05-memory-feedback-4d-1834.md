# Phase 4d memory feedback and promotion: plan (2026-11-05)

BDR-125 phase 4d, host `mods/memory` (BDR-137). Input: the 4c injection log,
store key `l:<root>` (`LogRecord` in `mods/memory/hooks/register.ts`).
Status: draft r1, not challenged, not gated. Starts after the 4c merge.

## What the log holds (read 2026-11-05, 18:30)

- Real use: 1 record. This repo, trigger `fresh`, outcome `injected`, IDs
  BDR-125, BDR-137, LRN-261: the prompt that asked for this plan.
- Plus 1 headless proof record (tool channel, fixture BLK-001, temp repo).
- Expected rate in this repo (RECALL.md, 14 days, after the content floor):
  about 15 triggered asks per 14 days, 3 tool-channel injections.

No decision can come from this. The TODO gate ("deferred until the log shows
misses or noise") is not met, and the log alone can never meet it, for the
three reasons below.

## Gaps between the log and the 4d questions

1. Usefulness is not recorded. The 4d design (queue challenge 2026-10-25)
   asked for "cited or not"; a record holds `at, session, agent, channel,
   ids, trigger, outcome`. Relevance needs the prompt and the reply, and
   both live in the transcript, not in the store.
2. Misses leave no trace. The log lists what came, never what should have
   come. Example: this plan's prompt did not bring BDR-100, the promotion
   rule the TODO 4d line cites, and nothing records that.
3. Transcripts live 7 days (`cleanupPeriodDays: 7`, job7 step D, secret
   hygiene). A single log-to-transcript join at the gate, about 3 weeks
   out, would find most turns gone. Older transcripts survive today; the
   setting does not promise it.

Minor: a prompt-channel `none` mixes "BM25 found no candidate" and "haiku
declined" (both paths in `recallFor`); rerank latency is not logged, only
the `timeout` outcome.

## 4d.1 Two log fields (mod, /feat after the 4c merge)

- Prompt records gain `cands` (BM25 candidates after the seen filter, 0-30)
  and `ms` (rerank wall time, absent when no rerank ran). Both optional in
  `isLogRecord`: records written before stay valid.
- Size: about 40 bytes more per record, 200 records stay under 40 KiB
  (cap 64 KiB).
- Nothing else enters the store: no prompt text, no reply text (LRN-124),
  no runtime cited flag (it would need a Stop hook reading the transcript
  every turn, for a signal the offline join gets at no runtime cost).
- Proof: kit tests for both fields, an old-shape record still loads, the
  `none` split visible on a fixture with zero candidates.

## 4d.2 Weekly reader (harness, no runtime change)

- `feedback.ts` (bun) beside this plan. It reuses `recall-bench.ts`'s
  transcript loader (`findFiles`, `records`, `composerText`, exported, not
  copied) and the mod's own functions (no port, LRN-261).
- Reads every `l:` key of the store file, all roots. The file path is
  engine-internal (`~/.claude/plugins/store/memory_skills-dir-*.json`):
  a renamed file fails loudly, acceptable for a measurement tool.
- Joins each record to its transcript by `session` and `at`:
  - prompt channel: the composer prompt it answered and the assistant turn
    that followed;
  - tool channel: the failing command and the next 3 Bash results of the
    same session (retry succeeded or not).
- Per injected entry: `cited` (the ID appears in the turn's assistant
  text, a lower bound) and a relevance label (controller labels, the user
  spot-checks: the 4c method).
- Misses: on up to 5 triggered asks per run, the controller searches the
  registries for relevant entries the recall did not bring, and names the
  cause (no lexical overlap, BM25 rank over 30, haiku declined). The
  FR-prompt vs EN-entry gap is the expected first cause.
- Persists `labels.tsv` (at, root name, channel, trigger, outcome, cands,
  ID, cited, label): IDs and enums only, committed. Labelled records are
  skipped on the next run; prompt and reply text stay in the scratchpad.
- Writes `FEEDBACK.md`: counts and shares only.
- Cadence: once a week, inside the 7-day window, about 10 minutes of label
  checks for the user.

## 4d.3 Gate and decisions fixed before the data

Gate: at least 20 labelled injected prompt asks and 10 tool injections (the
BDR-125 proof line), or 5 weeks after the 4c merge, whichever comes first.
At the date cap with a smaller n: report "insufficient sample" with the n,
extend once or close.

| Signal | Threshold | Action |
|---|---|---|
| prompt precision (relevant / injected entries) | at least 64 % | keep |
| same, below 64 % | worst trigger kind below 50 % | tighten or drop that trigger (idle first: the 4c noise sat there) |
| precision of the 3rd pick | below 40 % | cap at 2 entries |
| timeout + paused share (asks with `cands` > 0) | above 25 % | revisit `RERANK_MS` or skip the rerank on short lists |
| `ms` p90 | below 2500 | lower `RERANK_MS`: every triggered prompt waits that long |
| tool precision | below 50 % | require 2 matched grams, or exclude the entry |
| misses in the sample | 1 ask in 3 or more | diagnose by cause; no fix built ahead |
| entry injected 3 times or more, 0 relevant | any | noisy: /prune-memory rewrites it |
| entry relevant 3 times or more, in 2 sessions or more | any | promotion candidate (BDR-100) |

Each action is its own /feat or /hotfix with the measurement attached. 4d
builds no tuning before the gate.

## 4d.4 Promotion and /prune-memory (conditional)

Built only if the gate shows at least one noisy entry or one promotion
candidate; otherwise closed with the measurement, like phase 3.

- Promotion stays a proposal: the reader lists each candidate with its
  counts, the user picks, the mechanism (guard, test, skill step) becomes
  its own TODO run, and the entry links the mechanism's commit. Never
  automatic.
- /prune-memory STEP 1 gains "D. Recall feedback": reads `labels.tsv`
  through one lib script that holds the thresholds (doctrine "After code
  changes" step 4); noisy entries join section C, promotion candidates go
  to STEP 2 as TODO lines.
- Open at that point: where other repos keep their labels (the mod logs
  every root, the reader lives in this repo).

## Open choices (user)

1. Cadence vs retention: weekly reader runs (recommended); or raise
   `cleanupPeriodDays` for the window (reverses job7 step D, transcripts
   carry secrets); or one run at the gate on a single week.
2. 4d.1 fields `cands` and `ms`: add them (recommended) or measure with the
   current record.
3. Gate numbers and the 5-week cap.
4. Promotion threshold: relevant 3 times in 2 sessions.

## Prerequisite: 4c merge

- Recall half of the interactive proof seen in this session: a fresh design
  prompt brought 3 entries, all relevant to the ask by the controller's
  reading (labeller and beneficiary are the same model: unchecked).
- Still owed: the digest after a real `/compact`, the 4c gates, the user's
  "merge it".

## Out of scope

Runtime cited flag, prompt text in the store, the 4c deferrals (Read and
Bash command triggers, critical deny-once, Tier 1, cross-repo index,
`memory_search`), the `l:<root>` cross-root shortcut and the unbounded
`memory.sh check` residual (own TODO lines).
