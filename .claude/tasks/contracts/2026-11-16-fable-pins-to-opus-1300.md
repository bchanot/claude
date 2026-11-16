# CONTRACT — fable-pins-to-opus (BDR-150 follow-up, amends BDR-077 W1)
- date: 2026-11-16 | flow: feat | branch: feature/fable-pins-to-opus (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Fable dispatch pins → opus (user 2026-11-16, BDR-150: Fable is the advisor, never auto-routed; this amends BDR-077 W1 "skill-runner children pinned fable"). Explicit `model: "fable"` sub-agent pins become `model: "opus"` (effort stays "high"): agents/client-handover-writer.md (7 sites: :270, :273, :432, :463, :476, :565, :685), skills/client-handover/SKILL.md:34, lib/model-gate.md:27 (dispatch tiers paragraph: skill-runners get opus). The census tests follow: lib/tests/model-routing.test.sh:88-95 (BDR-077 W1 block asserts 'model: "fable"' in client-handover-writer.md and model-gate.md) and lib/tests/effort-routing.test.sh:231-232 (client-handover-writer skill-runner lines carry effort="high"). model-gate's table keeps accepting a fable id (a hand-picked Fable session may still run a skill).

## CLARIFICATIONS
- [internal 2026-11-16] plan .claude/tasks/plans/2026-11-16-fable-pins-to-opus-1300.md, section r2 wins (same-line pins, exact count 7, repo-wide fable census, gate row for `fixed at spawn`).
- [deferred 2026-11-16] lib/effort-shift.md:30-32 and the prose citers (plan-challenger, challenge-plan, tour, README) go to the doctrine run next (feat 5-file cap); TODO line written at close.

## ACCEPTANCE CRITERIA
1. No `model: "fable"` pin left in the dispatch sites.
   CHECK: cd /home/bchanot/Documents/claude && { grep -c 'model: "fable"' agents/client-handover-writer.md skills/client-handover/SKILL.md lib/model-gate.md || true; } | awk -F: '{s+=$2} END {print s}'
   EXPECT: 0
   EVIDENCE: MET exit=0 marker-found :: 0
2. The seven skill-runner pins in client-handover-writer.md are opus with effort high.
   CHECK: cd /home/bchanot/Documents/claude && grep 'model: "opus"' agents/client-handover-writer.md | grep -c 'effort="high"'
   EXPECT: 7
   EVIDENCE: MET exit=0 marker-found :: 7
3. model-routing and effort-routing suites green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/model-routing.test.sh </dev/null 2>&1 | tail -1 && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/effort-routing.test.sh </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green all suites green
4. Full make test green (GATES_TIMEOUT=400); the census assertions bite (a reintroduced `model: "fable"` pin or an opus skill-runner line without effort="high" turns a suite red; shown on a scratch copy) (manual).

## FILE SCOPE
agents/client-handover-writer.md (7 pin lines + the BDR-077 paragraph ~:268-271), skills/client-handover/SKILL.md (~:34), lib/model-gate.md (Dispatch tiers paragraph ~:23-29), lib/tests/model-routing.test.sh (~:88-95), lib/tests/effort-routing.test.sh (~:224-225).
