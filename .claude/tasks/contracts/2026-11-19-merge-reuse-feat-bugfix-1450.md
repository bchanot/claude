# CONTRACT — merge-reuse-feat-bugfix (run 2 of 2)
- date: 2026-11-19 | flow: feat | branch: feature/advisor-merge-reuse
- status: active

## REQUEST (verbatim — IMMUTABLE)
Merge et corrige le bug et fais les todo

Scope of this run (main loop): TODO:14 run 2 — the feat and bugfix end-of-run lines restate lib/effort-shift.md § Advisor item 3's merge-reuse clause with the skip ("reuses the last run's answer, or its skip"), plus loops-light locks. Run 1 = af846d6 (a11y, guardrails, ship-feature, init-project).

## CLARIFICATIONS
Q: which sites get the clause / A: all 6; feat/bugfix get "reuses the last run's answer, or its skip" (scope question option text) [gated 2026-11-19]

## ACCEPTANCE CRITERIA
1. loops-light carries 6 new locks (3 per site) and is green: 97 pass, 0 fail.
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/loops-light.test.sh 2>&1 | tail -1 | grep -qF '97 pass, 0 fail' && echo LOCKS-97
   EXPECT: LOCKS-97
   EVIDENCE: MET exit=0 marker-found :: LOCKS-97
2. feat and bugfix carry the full clause right after their "a fix it drives goes back through the gates." (joined text).
   CHECK: cd /home/bchanot/Documents/claude && n=0; for f in feat bugfix; do tr '\n' ' ' < skills/$f/SKILL.md | tr -s ' ' | grep -qF 'goes back through the gates. A later merge proposal reuses the last run'"'"'s answer, or its skip, and names any code commit made after it (doc and memory commits excepted).' && n=$((n+1)); done; [ "$n" -eq 2 ] && echo SITES-2
   EXPECT: SITES-2
   EVIDENCE: MET exit=0 marker-found :: SITES-2
3. The 9814720 skip locks and lib/effort-shift.md stay intact: lib unchanged vs develop, and the skip sentence's locked fragments still present in both skills.
   CHECK: cd /home/bchanot/Documents/claude && git diff --quiet develop -- lib/effort-shift.md && for f in skills/feat/SKILL.md skills/bugfix/SKILL.md; do grep -qF 'a verdict no longer in view runs the call.' "$f" && grep -qF "auditor's \`TOOL:\` line, beside a PASS." "$f" || exit 1; done && echo SKIP-INTACT
   EXPECT: SKIP-INTACT
   EVIDENCE: MET exit=0 marker-found :: SKIP-INTACT
4. Full make test green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
5. The 6 new locks are red before the edit (simulated on a scratch clone before dispatch); no wording changed outside the plan's blocks; new prose lines ≤ 80 columns (manual).

## FILE SCOPE
skills/feat/SKILL.md, skills/bugfix/SKILL.md, lib/tests/loops-light.test.sh
