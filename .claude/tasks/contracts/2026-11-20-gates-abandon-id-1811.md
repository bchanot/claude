# CONTRACT — gates-abandon-id
- date: 2026-11-20 | flow: hotfix | branch: bugfix/gates-abandon-id
- status: active
- run-base: 23c580249e20d3b185bd9278726b024b5729132b

## REQUEST (verbatim — IMMUTABLE)
lib/gates.sh:110 ABANDON regex `([0-9]+)?` reads `ABANDON: 1b …` / `1.1` as criterion 1: after a renumber criterion 1 is masked ABANDONED (rc 3) instead of an "unknown criterion" ERROR. Reproduced 2026-11-20: contract with criteria 1 (runnable) and 2 (manual) + `ABANDON: 1b moved after renumber` → `gates.sh status` prints "1 ABANDONED", VERDICT ABANDONED(1), rc 3. Fix: anchor the id so `1b`, `1.1` and an id-less line give ERROR, `ABANDON: 1 reason` stays ABANDONED; regression test in lib/tests/gates.test.sh; real ledgers (git grep '^ABANDON:' .claude/tasks/contracts) keep their verdict. TODO .claude/tasks/TODO.md:107.

## CLARIFICATIONS
none — request complete

## ACCEPTANCE CRITERIA
1. Symptom gone: `ABANDON: 1b …`, `ABANDON: 1.1 …` and an id-less `ABANDON: reason` each give `GATES — VERDICT: ERROR` with "malformed ABANDON" (rc 2), never a masked ABANDONED; `ABANDON: 1 reason` still gives ABANDONED (rc 3) and `ABANDON: 1` still "blank reason".
   CHECK: t=$(mktemp -d); for id in '1b moved' '1.1 moved' 'upstream offline'; do printf '## ACCEPTANCE CRITERIA\n1. ok\n   CHECK: true\n   EXPECT: x\n   EVIDENCE: pending\n2. manual\n\nABANDON: %s\n' "$id" > $t/c.md; o=$(bash lib/gates.sh status $t/c.md 2>&1); rc=$?; [ $rc -eq 2 ] && [[ "$o" == *"malformed ABANDON"* ]] && [[ "$o" != *"ABANDONED"* ]] || { echo "BAD $id rc=$rc"; exit 1; }; done; printf '## ACCEPTANCE CRITERIA\n1. ok\n   CHECK: echo M\n   EXPECT: M\n   EVIDENCE: pending\n2. manual\n\nABANDON: 2 upstream offline\n' > $t/v.md; o=$(bash lib/gates.sh run $t/v.md 2>&1); [ $? -eq 3 ] && [[ "$o" == *"VERDICT: ABANDONED(1)"* ]] && echo SYMPTOM_GONE
   EXPECT: SYMPTOM_GONE
   EVIDENCE: MET exit=0 marker-found :: SYMPTOM_GONE
2. Regression tests in lib/tests/gates.test.sh cover `1b`, `1.1` and the id-less line, and the suite is green.
   CHECK: grep -q 'ABANDON: 1b' lib/tests/gates.test.sh && grep -q 'ABANDON: 1.1' lib/tests/gates.test.sh && grep -q '^   ABANDON: 1b moved' lib/tests/gates.test.sh && make test suite=lib/tests/gates.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
3. Real ledgers keep their verdict: phase2-guards ABANDONED(2) (the levers-followup ledger lives on its own branch).
   CHECK: bash lib/gates.sh status .claude/tasks/contracts/2026-11-02-phase2-guards-1545.md 2>&1 | tail -1
   EXPECT: GATES — VERDICT: ABANDONED(2)
   EVIDENCE: MET exit=0 marker-found :: GATES — VERDICT: ABANDONED(2)
5. [gated 2026-11-20 orchestrator, challenge robustness MAJOR] An `ABANDON:` line indented under its criterion counts as an abandonment (ABANDONED, rc 3), and an indented malformed one gives the malformed ERROR; the game ledger with the indented handoff reads ABANDONED(1).
   CHECK: t=$(mktemp -d); printf '## ACCEPTANCE CRITERIA\n1. ok\n   CHECK: echo M\n   EXPECT: M\n   EVIDENCE: pending\n2. manual\n   ABANDON: 2 upstream offline\n' > $t/a.md; o=$(bash lib/gates.sh run $t/a.md 2>&1); [ $? -eq 3 ] && [[ "$o" == *"VERDICT: ABANDONED(1)"* ]] || exit 1; printf '## ACCEPTANCE CRITERIA\n1. ok\n   CHECK: true\n   EXPECT: x\n   EVIDENCE: pending\n   ABANDON: 1b x\n' > $t/b.md; o=$(bash lib/gates.sh status $t/b.md 2>&1); [ $? -eq 2 ] && [[ "$o" == *"malformed ABANDON"* ]] || exit 1; g=$t/game.md; git -C /home/bchanot/Documents/game show develop:.claude/tasks/contracts/2026-09-30-verify-qual-deparse-1925.md > $g && bash lib/gates.sh status $g 2>&1 | tail -1
   EXPECT: GATES — VERDICT: ABANDONED(1)
   EVIDENCE: MET exit=0 marker-found :: GATES — VERDICT: ABANDONED(1)
4. Contract and gates suites stay green.
   CHECK: make test suite="lib/tests/contract-verifier.test.sh lib/tests/loops-light.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green

## FILE SCOPE
- lib/gates.sh
- lib/tests/gates.test.sh
- this contract and .claude/tasks/plans/2026-11-20-gates-abandon-id-1811.md (run artifacts)
