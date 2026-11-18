# CONTRACT — gates-label-timeout
- date: 2026-11-17 | flow: hotfix | branch: bugfix/gates-label-timeout
- status: active

## REQUEST (verbatim — IMMUTABLE)
corrige les deux bugs mis dans le todos puis passe a C

Bug description (TODO:88-89): (1) gates.sh: warn or reject a criterion row labelled `^[0-9]+[a-z]\.` (LRN-284: `1b.` absorbed into criterion 1, its CHECK/EXPECT overwritten, false MET). (2) gates.sh default `GATES_TIMEOUT=120` < full `make test` (~135 s on 2026-11-16): a "Full make test green" criterion goes NOT-MET on timeout alone (A6 run, re-run with GATES_TIMEOUT=400). Raise the default or have contract-interview write the timeout for full-suite criteria.

## CLARIFICATIONS
Q: the two bugs? / A: inferred, not asked: TODO:88-89, the two gates.sh items (TODO:90 design-tool-gate is deferred to its next touch by its own text); the user's answers to the two questions below approve both fixes
Deviation 2026-11-17 (advisor, reported to the user): the same false MET reproduces with an indented `   2. sub`, `- sub` or `**2.** sub` label, so `_set_attr` also rejects a second CHECK/EXPECT/EVIDENCE on one criterion (no past contract has one; every past verdict unchanged)
Q: bad label handling? / A: reject: an unindented ACCEPTANCE CRITERIA line starting with a digit that is not `N. text` (`1b.`, `1.1`, `2)`) is a parse error naming the line, its attributes belong to no criterion, verdict ERROR [gated 2026-11-17]
Q: timeout fix? / A: default 600 s, the GATES_TIMEOUT env override kept [gated 2026-11-17]

## ACCEPTANCE CRITERIA
1. A `1b.` label after a failing criterion makes `gates.sh run` return ERROR rc 2 naming line 6 (before the fix this fixture is a false MET).
   CHECK: cd /home/bchanot/Documents/claude && f=$(mktemp) && printf '## ACCEPTANCE CRITERIA\n1. real\n   CHECK: exit 1\n   EXPECT: x\n   EVIDENCE: pending\n1b. sub\n   CHECK: echo y\n   EXPECT: y\n   EVIDENCE: pending\n' > "$f"; out=$(bash lib/gates.sh run "$f" 2>&1); rc=$?; rm -f "$f"; [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'malformed criterion label at line 6' && printf '%s' "$out" | grep -q 'VERDICT: ERROR' && echo LABEL-REJECTED
   EXPECT: LABEL-REJECTED
   EVIDENCE: MET exit=0 marker-found :: LABEL-REJECTED
2. With GATES_TIMEOUT unset, gates.sh reports a 600 s timeout; with GATES_TIMEOUT=7 it reports 7 s.
   CHECK: cd /home/bchanot/Documents/claude && f=$(mktemp) && printf '## ACCEPTANCE CRITERIA\n1. manual\n' > "$f"; a=$(env -u GATES_TIMEOUT bash lib/gates.sh status "$f" 2>&1); b=$(GATES_TIMEOUT=7 bash lib/gates.sh status "$f" 2>&1); rm -f "$f"; printf '%s' "$a" | grep -q 'timeout 600s' && printf '%s' "$b" | grep -q 'timeout 7s' && echo DEFAULT-600
   EXPECT: DEFAULT-600
   EVIDENCE: MET exit=0 marker-found :: DEFAULT-600
3. lib/tests/gates.test.sh carries the regression cases and is green; shellcheck clean on both files.
   CHECK: cd /home/bchanot/Documents/claude && grep -q '1b\. sub' lib/tests/gates.test.sh && grep -q '1\.1 dotted' lib/tests/gates.test.sh && grep -q 'timeout 600s' lib/tests/gates.test.sh && shellcheck -S warning lib/gates.sh lib/tests/gates.test.sh && bash lib/tests/gates.test.sh 2>&1 | tail -1 | grep -q ', 0 fail' && echo SUITE-GREEN
   EXPECT: SUITE-GREEN
   EVIDENCE: MET exit=0 marker-found :: SUITE-GREEN
4. An indented `   2. sub` label with a passing oracle after a failing criterion 1 makes `gates.sh run` return ERROR naming the second CHECK (before the fix: false MET).
   CHECK: cd /home/bchanot/Documents/claude && f=$(mktemp) && printf '## ACCEPTANCE CRITERIA\n1. real\n   CHECK: exit 1\n   EXPECT: x\n   EVIDENCE: pending\n   2. sub\n   CHECK: echo y\n   EXPECT: y\n   EVIDENCE: pending\n' > "$f"; out=$(bash lib/gates.sh run "$f" 2>&1); rc=$?; rm -f "$f"; [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'second CHECK: at line 7' && printf '%s' "$out" | grep -q 'VERDICT: ERROR' && echo STRAY-REJECTED
   EXPECT: STRAY-REJECTED
   EVIDENCE: MET exit=0 marker-found :: STRAY-REJECTED
5. Full make test green, run by gates.sh with no GATES_TIMEOUT set (proves the new default covers the suite).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green

## FILE SCOPE
lib/gates.sh
lib/tests/gates.test.sh
(bookkeeping: .claude/tasks/TODO.md, .claude/memory via memory.sh, this contract, the challenge plan .claude/tasks/plans/2026-11-17-gates-label-timeout-2342.md)
