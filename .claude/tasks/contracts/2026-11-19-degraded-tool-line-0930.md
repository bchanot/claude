# CONTRACT — degraded-tool-line
- date: 2026-11-19 | flow: bugfix | branch: bugfix/degraded-tool-line
- status: active

## REQUEST (verbatim — IMMUTABLE)
Merge et corrige le bug et fais les todo

Scope of this run (main loop, from the previous turn's report): "le bug" = BUGS-FOUND.md:134 (security-auditor prints `VERDICT: PASS` on a DEGRADED scan, DEGRADED only on its `TOOL:` line; lib/verify-secure-loop.md, agents/security-auditor.md and skills/hotfix/SKILL.md teach DEGRADED as a VERDICT-line value); TODO:13 (loops-light lock on the feat/bugfix skip sentence) folds in as the regression test. TODO:14 and Run C are separate runs.

## CLARIFICATIONS
Q: fix plan (.claude/tasks/plans/2026-11-19-degraded-tool-line-0930.md, STEP 3 gate with challenge summary) / A: yes [gated 2026-11-19]

## ACCEPTANCE CRITERIA
1. loops-light carries the new locks and is green: 78 pass, 0 fail.
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/loops-light.test.sh 2>&1 | tail -1 | grep -qF '78 pass, 0 fail' && echo LOCKS-78
   EXPECT: LOCKS-78
   EVIDENCE: MET exit=0 marker-found :: LOCKS-78
2. No reader lists DEGRADED as a VERDICT value: the backticked token `DEGRADED` is gone from the three readers.
   CHECK: cd /home/bchanot/Documents/claude && ! grep -qF '`DEGRADED`' lib/verify-secure-loop.md agents/security-auditor.md skills/hotfix/SKILL.md && echo OLD-VALUE-GONE
   EXPECT: OLD-VALUE-GONE
   EVIDENCE: MET exit=0 marker-found :: OLD-VALUE-GONE
3. Each of the three readers' PASS branch reads the TOOL line first and makes a PASS without it a structural failure (joined text).
   CHECK: cd /home/bchanot/Documents/claude && n=0; for f in lib/verify-secure-loop.md agents/security-auditor.md skills/hotfix/SKILL.md; do tr '\n' ' ' < "$f" | tr -s ' ' | grep -qF '`PASS` → read the `TOOL:` line first: DEGRADED (semgrep absent) shows there, never on the VERDICT line; a PASS with no `TOOL:` line is a structural failure (below).' && n=$((n+1)); done; [ "$n" -eq 3 ] && echo READERS-3
   EXPECT: READERS-3
   EVIDENCE: MET exit=0 marker-found :: READERS-3
4. The auditor's and hotfix's structural-failure lists name a PASS with no TOOL line (joined text).
   CHECK: cd /home/bchanot/Documents/claude && tr '\n' ' ' < agents/security-auditor.md | tr -s ' ' | grep -qF 'PASS without PROOF or without `TOOL:` line) → retry ONCE fresh' && tr '\n' ' ' < skills/hotfix/SKILL.md | tr -s ' ' | grep -qF 'Structural failure (mute / unparsable / no VERDICT line / PASS with no `TOOL:` line) → treat as a failed gate' && echo STRUCT-2
   EXPECT: STRUCT-2
   EVIDENCE: MET exit=0 marker-found :: STRUCT-2
5. lib/effort-shift.md § Advisor item 3 names the line DEGRADED prints on, and hotfix's DEGRADED PASS sets its SECURITY field.
   CHECK: cd /home/bchanot/Documents/claude && tr '\n' ' ' < lib/effort-shift.md | tr -s ' ' | grep -qF '`skipped (gates clean on first pass)`; DEGRADED shows on the auditor'"'"'s `TOOL:` line. A skipped call discharges' && tr '\n' ' ' < skills/hotfix/SKILL.md | tr -s ' ' | grep -qF 'a DEGRADED PASS sets the summary'"'"'s SECURITY field to `DEGRADED (checklist only)`' && echo EFF-HOT-OK
   EXPECT: EFF-HOT-OK
   EVIDENCE: MET exit=0 marker-found :: EFF-HOT-OK
6. Full make test green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
7. The new locks are red on develop's readers (16 FAIL simulated on a scratch clone before dispatch); no wording changed outside the plan's blocks; new prose lines ≤ 80 columns (manual).

## FILE SCOPE
lib/verify-secure-loop.md, agents/security-auditor.md, skills/hotfix/SKILL.md, lib/effort-shift.md, lib/tests/loops-light.test.sh
