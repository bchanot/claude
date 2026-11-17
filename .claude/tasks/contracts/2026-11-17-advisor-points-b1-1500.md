# CONTRACT — advisor-points-b1 (BDR-150 amendment, run B1)
- date: 2026-11-17 | flow: feat | branch: feature/advisor-points-b1 (off develop)
- status: active
- plan: .claude/tasks/plans/2026-11-17-advisor-points-b1-1500.md (r4)

## REQUEST (verbatim — IMMUTABLE)
User 2026-11-17: "oui a, b et c dans la run B", answering: (a) move the main loop's "before the plan" point into lib/challenge-plan.md, shared by 9 skills: the main loop consults the advisor on the written plan before dispatching the challengers; (b) add the analyzer to the agents allowed one call; (c) add a concrete trigger to the global line: "before recommending a change to the doctrine, the architecture or a public interface". Run B (from run A) also places inline call lines in lib/verify-secure-loop.md (second failure, caps).

## CLARIFICATIONS
- [internal 2026-11-17] run B split (/feat max 5 files): B1 = CLAUDE.global.md, lib/effort-shift.md, lib/challenge-plan.md, lib/verify-secure-loop.md, agents/analyzer.md (this contract); B2 = stuck trigger lines in skills/feat, skills/bugfix, skills/ship-feature, skills/init-project gate bullets, merge lines in skills/ship-feature STEP 9 and skills/release-candidate STEP 4, agents/security-auditor.md direction fix.
- [internal 2026-11-17] plan r2: stuck unit "since GATE 0 first ran", block C once, user wording "before recommending", analyzer moved in.
- [internal 2026-11-17] re-challenge (correctness FATAL(2), robustness CONCERNS(1), simplicity CONCERNS(1)) → plan r4, no third round: criterion 3 awk anchored on `^**Advisor first`; block F `Advisor:` row added to whatever summary template the caller prints, states `called, no change` / `not called (…)`; block C dedup "no main-loop advisor call since the skill run started", re-persist PLAN on disk, route clause dropped; block H (nominal-path cost line); block I (named points cover the § Workflow triggers inside a skill run); B2 inline sentence narrowed to the analyzer; E parenthetical dropped. Residuals → BUGS-FOUND at capitalize: verifier/security-auditor advisor rules not dispatch-scoped (inline load path unused today), agents/plan-challenger.md ORCHESTRATOR PROTOCOL mirror lacks the advisor step and row.
- [internal 2026-11-17] challenge round 1 (correctness FATAL(5), robustness CONCERNS(4), simplicity SOLID) → plan r3: plan call once per skill run, reads PLAN first, route sent with it, no attribution in PLAN, CHALLENGE SUMMARY lists advisor-driven changes (block F); stuck unit counts main-loop calls only; STOP clause moved before "## Order invariant" (block G); effort-shift item 2 "says whether it predates"; analyzer rule scoped to dispatch, anchored after TASKS/PROCESS, fix advice allowed where the brief asks; `analyzer` backticked; B2 gains skills/init-project. Rejected: one-line D triggers (S1, the brief ban stays at the site), on-disk stuck marker (R10, over-built).

## RELATED MEMORY
- BDR-150 (accepted, amended 6ef3069): amended again here.
- LRN-294, LRN-295, BUGS-FOUND advisor residual: prose-only scope, cost per main-loop call.
- BDR-066 / LRN-083: decisions and advice stay in the main loop.

## ACCEPTANCE CRITERIA
1. CLAUDE.global.md carries block A (trigger c, dispatched analyzer, one-line citation).
   CHECK: cd /home/bchanot/Documents/claude && echo "$({ grep -c 'before recommending a change' CLAUDE.global.md || true; })/$({ grep -c 'verifier, security-auditor and `analyzer` at most once, before their' CLAUDE.global.md || true; })/$({ grep -cF '`~/.claude/lib/effort-shift.md` § Advisor;' CLAUDE.global.md || true; })/$(wc -l < CLAUDE.global.md)"
   EXPECT: 1/1/1/316
   EVIDENCE: MET exit=0 marker-found :: 1/1/1/316
2. lib/effort-shift.md § Advisor: plan point on the written plan, "whether it predates", dispatched analyzer, inline loads, old wording gone.
   CHECK: cd /home/bchanot/Documents/claude && sec() { sed -n '/^## Advisor/,/^## Never/p' lib/effort-shift.md; }; echo "$(sec | grep -c 'on the written plan, before the')/$(sec | grep -c 'says whether it predates')/$(sec | grep -c 'and `analyzer` call it at most once per dispatch')/$(sec | grep -c 'loaded inline by the main loop follows the')/$(sec | grep -c 'no second call for the same recommendation')/$(sec | grep -c "ahead of writing a skill's plan")/$(sec | grep -c STEP)"
   EXPECT: 1/1/1/1/1/0/0
   EVIDENCE: MET exit=0 marker-found :: 1/1/1/1/1/0/0
3. lib/challenge-plan.md: main-loop advisor call before the first dispatch, challengers blind, summary lists advisor-driven changes.
   CHECK: cd /home/bchanot/Documents/claude && echo "$({ grep -c 'Advisor first (main loop)' lib/challenge-plan.md || true; })/$({ grep -c 'The advice never enters a challenger brief' lib/challenge-plan.md || true; })/$({ grep -c 'whatever summary template the caller prints' lib/challenge-plan.md || true; })/$({ grep -c 'revises the `PLAN` file on disk before the dispatch' lib/challenge-plan.md || true; })/$(awk '/^\*\*Advisor first/{a=NR} /^Dispatch THREE fresh/{d=NR} END{print (a>0 && a<d)}' lib/challenge-plan.md)"
   EXPECT: 1/1/1/1/1
   EVIDENCE: MET exit=0 marker-found :: 1/1/1/1/1
4. lib/verify-secure-loop.md: five main-loop stuck lines, the STOP clause before the order invariant.
   CHECK: cd /home/bchanot/Documents/claude && echo "$({ grep -c 'with no main-loop advisor call since GATE 0' lib/verify-secure-loop.md || true; })/$({ grep -cF '`lib/effort-shift.md` § Advisor' lib/verify-secure-loop.md || true; })/$({ grep -c 'never$' lib/verify-secure-loop.md || true; })/$(awk '/the STOP carries its answer/{s=NR} /^## Order invariant/{o=NR} END{print (s>0 && s<o)}' lib/verify-secure-loop.md)/$({ grep -c 'NEVER a PASS' lib/verify-secure-loop.md || true; })"
   EXPECT: 5/5/3/1/2
   EVIDENCE: MET exit=0 marker-found :: 5/5/3/1/2
5. agents/analyzer.md carries its dispatch-scoped one-call rule.
   CHECK: cd /home/bchanot/Documents/claude && echo "$({ grep -c 'Advisor, when dispatched as a sub-agent' agents/analyzer.md || true; })/$({ grep -c 'erroring → proceed' agents/analyzer.md || true; })/$({ grep -c 'never on the advice' agents/analyzer.md || true; })"
   EXPECT: 1/1/1
   EVIDENCE: MET exit=0 marker-found :: 1/1/1
6. Citation census green (fast oracle).
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/doctrine-citers.test.sh </dev/null 2>&1 | tail -1
   EXPECT: FAIL=0
   EVIDENCE: MET exit=0 marker-found :: PASS=23 FAIL=0
7. Full make test green (run with GATES_TIMEOUT=400).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
8. Touched lines ≤ 80 columns; blocks applied verbatim from the plan; no other wording changed in the five files (manual).

## FILE SCOPE
CLAUDE.global.md (§ Workflow bullet ~:81-88), lib/effort-shift.md (§ Advisor items), lib/challenge-plan.md (§ DISPATCH head), lib/verify-secure-loop.md (GATE 0/1/2 bullets ~:38, :78, :91, :110, :115), agents/analyzer.md (§ RULES).
