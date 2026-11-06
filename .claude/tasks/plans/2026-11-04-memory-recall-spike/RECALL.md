# Phase 4c recall measured on 14 days of transcripts (2026-11-05)

Harness: `recall-bench.ts` (bun) imports the mod's own functions (`isTrigger`, `bm25Rank`, `rerankPrompt`, `parseIds`, `assembleEntries`, `failureKey`, `buildIndex`, `matchOf`…); statuses from `lib/memory.sh index`; haiku `claude-haiku-5-5` through `claude -p` from a `mktemp -d` cwd with `--setting-sources local`, no tools. Counts and shares only; no prompt or error text here (LRN-124).

## Prompt channel

Population: main-loop transcripts with `entrypoint == "cli"`, user entries with `origin.kind == "human"` (typed prompts), not meta, not compaction summaries: 65 prompts, 11 older entries skipped (no `origin` field), 24 meet the trigger, 20 sampled (seed 42). A first run sampled `<task-notification>` and summary entries (origin `task-notification` / `isCompactSummary`, never seen by the mod's `composer` gate): discarded as a measurement.

| measure | value |
|---|---|
| asks | n = 20 |
| injections (prompts with ≥ 1 entry) | 15 / 20 |
| entries injected | n = 38 (2.5 per injection) |
| relevant entries (controller labels) | 19 / 38 = 50 % |
| relevant on prompts with ≥ 5 content words (estimate) | 16 / 28 = 57 % |
| bar (BDR-125 amendment 2, haiku rerank baseline) | 14 / 22 = 64 % |
| haiku `duration_api_ms` > 3000 (upper bound) | 4 / 20 = 20 % (first run: 7 / 20) |

The noise sits on content-free prompts triggered by idle time (short approvals): 0 relevant of 10 injected. Prompts with a topic recall the right entries. Caveat: the harness reads today's registries, so entries written after a prompt can be recalled for it (temporal leakage): the true shares are somewhat lower.

## Error channel

36 Bash failures keyed over 14 days (main + sub-agents), 3 known-line injections (2 sessions): one exact lesson, two plausible. n = 3: insufficient sample.

## Decision (2026-11-05)

User: "Plancher de contenu" — no intent recall on a prompt with fewer than 5 content words (stop words excluded); recall ships on and switchable (`"recall": false`); the injection log (4c) feeds the 4d measurement on real use. The 3 s rerank bound stays (timeout share 20 % < 25 %).

## After the content floor (debdead) and the bound decision

Same harness, same seed: 15 prompts meet the trigger (was 24), all sampled; 14 injections; n = 41 entries; relevant 25 / 41 = 61 % counting entries written after the prompt (temporal leakage, 6 entries), 19 / 35 = 54 % excluding them. Still under the 64 % bar; the misses are vague follow-ups, the hits are topical prompts. haiku `duration_api_ms` > 3000 over the three runs: 16 / 55 = 29 % (> 25 % bar); > 4500: 1 / 55; > 5000: 1 / 55. User decision: `RERANK_MS` = 5000.

## After the final-review fixes (2397c36: 2-letter stop words, log trigger/outcome, log keys in the sweep)

Same harness, same seed: still 15 prompts meet the trigger (the 2-letter stop words did not change this sample), 14 injections, n = 40 entries; relevant 30 / 40 = 75 % counting entries written after the prompt (8 such entries), 22 / 32 = 69 % excluding them; haiku > 3000 ms 1 / 15, > 5000 ms 1 / 15. Reading: the rerank is not deterministic (different picks run to run) and the labels are one labeller's on a small sample; across the four measured runs the relevant share ranged about 54-75 %. The injection log (now with `trigger` and `outcome`) is the real-use measure for 4d.
