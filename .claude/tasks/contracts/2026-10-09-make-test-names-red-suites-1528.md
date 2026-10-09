# CONTRACT — make-test-names-red-suites
- date: 2026-10-09 | flow: hotfix | branch: bugfix/make-test-names-red-suites
- status: active

## REQUEST (verbatim — IMMUTABLE)
Skill args: "Makefile `test` target: print `FAIL <suite>` for every red suite and a final summary line (`<n> suite(s) red: <names>` or `all suites green`) so a full `make test` names the failing suites itself; exit code unchanged (1 on any red). Today only `== <suite>` headers print and the aggregate rc forces a second per-suite run to find the red one."
User (fr): "c'est quand meme long 9 min pour faire un merge non ? … ou est le bottlneck ?" → measured: the pre-merge `make test` (454 s) was a full run PLUS a per-suite re-run to name the red suite; "oui vas y fait le maintenant".

## CLARIFICATIONS
Q: wording / A: given by the request: `FAIL <suite>` per red suite right after it runs, then one summary line `<n> suite(s) red: <names>` or `all suites green`. [user]
Q: exit code / A: unchanged: 1 when any suite is red, 0 otherwise. [user]

## ACCEPTANCE CRITERIA
1. Symptom gone: a run with one red suite prints `FAIL <that suite>` and `1 suite(s) red: <that suite>` and exits non-zero (GNU make reports a failed recipe as 2); a run with only green suites prints `all suites green` and exits 0. Checked on a two-suite fixture through `make test suite="<green> <red>"`-style invocations (the `suite` variable already accepts a list).
   CHECK: cd /Users/b.chanot/Documents/claude && W=$(mktemp -d) && printf '#!/usr/bin/env bash\nexit 0\n' > "$W/green.test.sh" && printf '#!/usr/bin/env bash\nexit 1\n' > "$W/red.test.sh" && out=$(make test suite="$W/green.test.sh $W/red.test.sh" 2>&1); rc=$?; [ $rc -ne 0 ] && echo "$out" | grep -q "^FAIL $W/red.test.sh" && echo "$out" | grep -q "1 suite(s) red: $W/red.test.sh" && out2=$(make test suite="$W/green.test.sh" 2>&1); rc2=$?; [ $rc2 -eq 0 ] && echo "$out2" | grep -q "all suites green" && echo SUMMARY-OK
   EXPECT: SUMMARY-OK
   EVIDENCE: MET exit=0 marker-found :: SUMMARY-OK
2. Build/tests green: the Makefile still runs the real suites (`make test suite=lib/tests/mods.test.sh` exits 0 and prints `all suites green`); `make -n test` parses.
   CHECK: cd /Users/b.chanot/Documents/claude && make -n test >/dev/null && out=$(make test suite=lib/tests/mods.test.sh 2>&1); rc=$?; [ $rc -eq 0 ] && echo "$out" | grep -q "all suites green" && echo REAL-SUITE-OK
   EXPECT: REAL-SUITE-OK
   EVIDENCE: MET exit=0 marker-found :: REAL-SUITE-OK

## FILE SCOPE
Makefile
