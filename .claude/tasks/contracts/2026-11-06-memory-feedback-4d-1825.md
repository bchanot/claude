# CONTRACT — memory-feedback-4d
- date: 2026-11-06 | flow: ship-feature | branch: feature/memory-feedback (to start off develop c10d859)
- status: active (enriched at STEP 3, 2026-11-07)
- plan: docs/superpowers/plans/2026-11-06-memory-feedback.md (r3); spec docs/superpowers/specs/2026-11-06-memory-feedback-design.md

## REQUEST (verbatim — IMMUTABLE)
yes start it

(context, the request as received: "Phase 4d memory feedback and promotion (BDR-125 queue). Plan r1 draft, not challenged: .claude/tasks/plans/2026-11-05-memory-feedback-4d-1834.md (4 open choices). TODO line '4d feedback and promotion': order 4d.1 log fields `cands` + `ms` → 4d.2 weekly reader (log × transcripts, labels.tsv) → 4d.3 gate (≥20 prompt + ≥10 tool injections, or 5 weeks) with thresholds fixed now → 4d.4 /prune-memory + BDR-100 promotion, conditional.")

## CLARIFICATIONS
Q: cadence / A: session-start reminder in every repo; retention stays 7 days. [gated 2026-11-06]
Q: population / A: records carrying cands (4d.1 on), every repo, `test` items excluded. [gated 2026-11-06]
Q: labels / A: local ~/.claude/memory-feedback (0700/0600), never in git; FEEDBACK.md local, a gate verdict recorded as an EVAL in this repo. [gated 2026-11-06]
Q: fields, gates, thresholds, skill, label values / A: cands + ms; two independent gates (prompt 20, tool 10, 35-day cap, tool extended once); r1 thresholds; /memory-feedback; relevant/irrelevant/test (+missed, checked). [gated 2026-11-06]
Q: spec deviations / A: reader in lib/memory-feedback/; miss causes no-overlap|overlap; labels.tsv without cited; noisy/promotion lines carry a repo tag. [gated 2026-11-07]

## ACCEPTANCE CRITERIA
1. The feedback loop can say, from data, whether recall injections are useful (precision per channel and trigger), what they miss, and which entries are noisy or promotion candidates; no tuning is built before the gate.
   (judged by the verifier against the enriched criteria below)
2. No prompt or reply text, and no secret, enters the plugin store or any committed file (LRN-124, LRN-261).
   (judged by the verifier from the diff)
3. The memory mod stays fail-open; records written before any schema change still load.
   (judged by the verifier; kit tests named at STEP 3)

4. [gated 2026-11-07] 4d.1: prompt records carry `cands` (every ask) and `ms` (when a rerank ran), old records still load, IR11 passes; mod kit and strict validation green.
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'export function isLogRecord' mods/memory/hooks/register.ts && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/mods.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/g4.out 2>&1 && echo C4_MOD
   EXPECT: C4_MOD
   EVIDENCE: PENDING
5. [gated 2026-11-07] Reader, labels, metrics, transcripts: the bun suite is green (labels append-only and loud on damage, draft validation, redaction of the worksheet, -context tool join, lost/torn counting, gates, NEW-once verdict, git-tree refusal).
   CHECK: cd /home/bchanot/Documents/claude && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/g5.out 2>&1 && grep -q ' 0 fail' /home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/g5.out && echo C5_READER
   EXPECT: C5_READER
   EVIDENCE: PENDING
6. [gated 2026-11-07] Reminder: never-run, due, quiet, closed, recall-off, unreadable cases; printed before the digest; portable (census green).
   CHECK: cd /home/bchanot/Documents/claude && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/memory-feedback-remind.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/g6a.out 2>&1 && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/session-digest.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/g6b.out 2>&1 && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/portability-census.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/g6c.out 2>&1 && echo C6_REMIND
   EXPECT: C6_REMIND
   EVIDENCE: PENDING
7. [gated 2026-11-07] Skill /memory-feedback routed (reflect, effort high), no routing collision, no dangling doctrine citer.
   CHECK: cd /home/bchanot/Documents/claude && test -f skills/memory-feedback/SKILL.md && for t in effort-routing skill-routing-census model-routing doctrine-citers; do systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/$t.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/g7-$t.out 2>&1 || exit 1; done && echo C7_SKILL
   EXPECT: C7_SKILL
   EVIDENCE: PENDING
8. [gated 2026-11-07] No text, no secret and no full repo path reaches labels.tsv, state.json, FEEDBACK.md or a committed file; the skill writes registries only into this repo (-C).
   (judged by the verifier from the diff and the reader tests R3/R5/M9)
9. [gated 2026-11-07] Full suite green, and the live proof of Task 8 done (a real record with cands; one real /memory-feedback run).
   (judged by the verifier from the controller's Task 8 evidence in the EXECUTION LOG)

## FILE SCOPE
- mods/memory/hooks/register.ts, mods/memory/hooks/register.test.ts
- lib/memory-feedback/{thresholds,labels,metrics,transcripts,reader}.ts + their *.test.ts
- lib/tests/memory-feedback.test.sh, lib/memory-feedback-remind.sh, lib/tests/memory-feedback-remind.test.sh
- hooks/session-start.sh, lib/tests/session-digest.test.sh
- skills/memory-feedback/SKILL.md, mods/model-router/routing.json
- docs/superpowers/{specs,plans}/2026-11-06-memory-feedback* (transient, purged at finish)
- public docs as patched by doc sync (STEP 8)
