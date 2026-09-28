# CONTRACT — floor-guard-xit-boundary
- date: 2026-09-28 | flow: hotfix (bugfix/* off develop) | branch: bugfix/floor-guard-xit-boundary
- status: active

## REQUEST (verbatim — IMMUTABLE)
> fais le hotfix du floor-guard
> BLK-023: lib/floor-guard.sh SKIP pattern `xit(` (meant for Jasmine's xit) matches any `exit(` / `SystemExit(` / `process.exit(` in python or JS test helpers → false FLOOR SKIP finding (ECARTS on a conform diff, 2026-09-28). Fix: make the Jasmine match word-bounded so `sys.exit(` no longer trips it; keep `xit(` detection for a real Jasmine `xit(` at line start or after a non-identifier char. Add the two regression cases to lib/tests/floor-guard.test.sh (a python `sys.exit(1)` line must NOT flag; a JS `  xit('skipped', ...)` line MUST flag).

## CLARIFICATIONS
- Pass A: silent autofill (hotfix). Pass B: nothing visible or public is open (an internal matcher; message text unchanged).
- [challenge 2026-09-28: simplicity SOLID, correctness SOLID, robustness CONCERNS(2), all closed by named plan changes, r2] fixture echo lines in lib/tests/floor-guard.test.sh carry `# floor-guard: allow flip-test fixture` outside the echoed string (a test-path diff scan would flag the fixture itself; WAIVED on a test file is informational and authorized here); the vacuous live clause left criterion 2; `def fit(` / `function xit(` / `xit.each(` behave as before and are recorded as a `shortcut:` comment (upgrade path named there), out of hotfix scope.
- Root cause (LOCATE): `skip_kind` (lib/floor-guard.sh:188-189) is a plain substring test over SKIP_SUBSTRINGS; the bare-identifier entries `'xit('`, `'fit('`, `'xdescribe('`, `'fdescribe('` therefore match inside longer identifiers (`exit(`, `SystemExit(`, `process.exit(`, `model.fit(`, `profit(`). The dotted/decorator entries (`.skip(`, `.only(`, `it.todo(`, `@pytest.mark.skip`, `@unittest.skip`, `t.Skip(`) are unaffected.
- Fix (closed): the four bare identifiers move out of SKIP_SUBSTRINGS into one compiled regex with an identifier-boundary lookbehind, `(?<![A-Za-z0-9_.])(?:xit|fit|xdescribe|fdescribe)\(`, and `skip_kind` returns SKIP when either the remaining substrings or that regex match. Excluding `.` in the lookbehind also stops `model.fit(` (a method call) from flagging; a Jasmine focused/skipped block is always a bare call.

## ACCEPTANCE CRITERIA
1. Symptom gone: test-file lines `process.exit(1);`, `model.fit(x);`, `profit(1)` produce no FLOOR SKIP (SKIP_EXIT_CLEAN is RED on the old matcher, GREEN after — the regression oracle); Jasmine `  xit(`, `fit(`, `fdescribe(` lines still do. [challenge: fixtures extended]
   CHECK: out=$(make test suite=lib/tests/floor-guard.test.sh 2>&1); echo "$out" | grep -qE 'FAIL=[1-9]' && { echo "$out" | tail -12; exit 1; }; for k in SKIP SKIP_EXIT_CLEAN SKIP_XIT_FLAGS SKIP_FIT_FLAGS SKIP_FDESCRIBE_FLAGS; do echo "$out" | grep -q "PASS $k" || { echo "missing PASS $k"; exit 1; }; done; echo FLOOR_SUITE_GREEN
   EXPECT: FLOOR_SUITE_GREEN
   EVIDENCE: MET exit=0 marker-found :: FLOOR_SUITE_GREEN
2. Build/tests green: shellcheck on the test, bash syntax of the guard, the regex compiles, and the guard's own diff is clean (its new lines are not on a test path). [challenge: the former census clause was vacuous — the file no longer holds an `exit(` — and is dropped; SKIP_EXIT_CLEAN in criterion 1 is the regression proof]
   CHECK: shellcheck lib/tests/floor-guard.test.sh && bash -n lib/floor-guard.sh && python3 -c "import re;re.compile(r'(?<![A-Za-z0-9_.])(?:xit|fit|xdescribe|fdescribe)\(')" && bash lib/floor-guard.sh develop -- lib/floor-guard.sh 2>&1 | grep -q 'FLOOR GUARD: clean' && echo BUILD_OK
   EXPECT: BUILD_OK
   EVIDENCE: MET exit=0 marker-found :: BUILD_OK

## FILE SCOPE
- lib/floor-guard.sh (SKIP_SUBSTRINGS + skip_kind), lib/tests/floor-guard.test.sh (two cases)
