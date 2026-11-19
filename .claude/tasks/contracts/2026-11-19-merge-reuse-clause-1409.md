# CONTRACT — merge-reuse-clause (run 1 of 2)
- date: 2026-11-19 | flow: feat | branch: feature/advisor-merge-reuse
- status: active

## REQUEST (verbatim — IMMUTABLE)
Merge et corrige le bug et fais les todo

Scope of this run (main loop): TODO:14 — the end-of-run advisor lines in skills/a11y, skills/guardrails, skills/ship-feature, skills/init-project restate lib/effort-shift.md § Advisor item 3's merge-reuse clause, plus a regression lock in lib/tests/loops-light.test.sh. Run 2 (same branch) does feat + bugfix.

## CLARIFICATIONS
Q: challenge MINORs (lock 1 anchored on "the gates.", lock 3 "commits excepted)." with si re-wrap, $EFF source lock → 91) / A: main loop, internal (no visible wording change) [2026-11-19]
Q: which sites get the clause / A: all 6 (the 4 named + feat + bugfix); /feat 5-file cap → two /feat runs on one branch, this run = the 4 named sites [gated 2026-11-19]

## ACCEPTANCE CRITERIA
1. loops-light carries 13 new locks (3 per site + the lib source) and is green: 91 pass, 0 fail.
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/loops-light.test.sh 2>&1 | tail -1 | grep -qF '91 pass, 0 fail' && echo LOCKS-91
   EXPECT: LOCKS-91
   EVIDENCE: MET exit=0 marker-found :: LOCKS-91
2. Each of the four sites carries the full clause right after its "a fix it drives goes back through the gates." (joined text).
   CHECK: cd /home/bchanot/Documents/claude && n=0; for f in a11y guardrails ship-feature init-project; do tr '\n' ' ' < skills/$f/SKILL.md | tr -s ' ' | grep -qF 'goes back through the gates. A later merge proposal reuses this answer and names any code commit made after it (doc and memory commits excepted).' && n=$((n+1)); done; [ "$n" -eq 4 ] && echo SITES-4
   EXPECT: SITES-4
   EVIDENCE: MET exit=0 marker-found :: SITES-4
3. lib/effort-shift.md item 3 is unchanged (the clause stays single-sourced there).
   CHECK: cd /home/bchanot/Documents/claude && git diff --quiet develop -- lib/effort-shift.md && echo EFF-UNCHANGED
   EXPECT: EFF-UNCHANGED
   EVIDENCE: MET exit=0 marker-found :: EFF-UNCHANGED
4. Full make test green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
5. The new site locks are red on develop's skills (12 FAIL; the lib lock passes on develop simulated on a scratch clone before dispatch); no wording changed outside the plan's blocks; new prose lines ≤ 80 columns (manual).

## FILE SCOPE
skills/a11y/SKILL.md, skills/guardrails/SKILL.md, skills/ship-feature/SKILL.md, skills/init-project/SKILL.md, lib/tests/loops-light.test.sh
