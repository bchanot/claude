# CONTRACT — memory-feedback-4d
- date: 2026-11-06 | flow: ship-feature | branch: feature/memory-feedback (to start off develop c10d859)
- status: active (seed, STEP 0e; enriched at STEP 3)
- plan: .claude/tasks/plans/2026-11-05-memory-feedback-4d-1834.md (r1 draft, superseded by the STEP 2 plan)

## REQUEST (verbatim — IMMUTABLE)
yes start it

(context, the request as received: "Phase 4d memory feedback and promotion (BDR-125 queue). Plan r1 draft, not challenged: .claude/tasks/plans/2026-11-05-memory-feedback-4d-1834.md (4 open choices). TODO line '4d feedback and promotion': order 4d.1 log fields `cands` + `ms` → 4d.2 weekly reader (log × transcripts, labels.tsv) → 4d.3 gate (≥20 prompt + ≥10 tool injections, or 5 weeks) with thresholds fixed now → 4d.4 /prune-memory + BDR-100 promotion, conditional.")

## CLARIFICATIONS

## ACCEPTANCE CRITERIA
1. The feedback loop can say, from data, whether recall injections are useful (precision per channel and trigger), what they miss, and which entries are noisy or promotion candidates; no tuning is built before the gate.
   (judged by the verifier against the enriched criteria below)
2. No prompt or reply text, and no secret, enters the plugin store or any committed file (LRN-124, LRN-261).
   (judged by the verifier from the diff)
3. The memory mod stays fail-open; records written before any schema change still load.
   (judged by the verifier; kit tests named at STEP 3)

## FILE SCOPE
- mods/memory/hooks/register.ts, mods/memory/hooks/register.test.ts
- .claude/tasks/plans/2026-11-04-memory-recall-spike/recall-bench.ts (export only, if reused)
- a new reader + labels under .claude/tasks/plans/ (names fixed at STEP 2)
- skills/prune-memory/SKILL.md, skills/prune-memory/tests/run-deterministic.sh, one threshold lib script (4d.4, conditional)
