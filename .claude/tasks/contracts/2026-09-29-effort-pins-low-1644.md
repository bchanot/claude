# CONTRACT — effort-pins-low
- date: 2026-09-29 | flow: bugfix by hand (bugfix/* off develop) | branch: bugfix/effort-pins-low
- status: active

## REQUEST (verbatim — IMMUTABLE)
> fais les cinq low restants
> [the five LOW parked in TODO after the 2026-09-29 security re-gate of BDR-108: no signal trap on the mktemp sibling; T13 never reaches the post-write re-read branch; T14 fails under root; `WORK="$(mktemp -d)"` unguarded in the suite; install-plugins.sh `err()` uses `echo -e` on the rejected map line]

## CLARIFICATIONS
- Pass A silent autofill (bugfix). Pass B: nothing visible or public opens; messages may change wording.
- LOW 1 (signal): `_effort_pin_write` installs an INT/TERM trap that removes `$tmp` and exits 130 for the duration of the cp/awk/mv chain, then restores the previous INT/TERM traps on every return path. NEVER an EXIT trap: install-plugins.sh runs a guarded-config EXIT trap the helper must not replace.
- LOW 2 (T13): the post-write re-read branch is unreachable through the file system once `_effort_pin_closed` has passed (the awk always inserts at the closing `---`); it stays as a post-condition of the awk, its message drops the misleading "(CRLF …)" hint, and a unit test reaches it by stubbing `_effort_pin_write` to a no-op inside a subshell that sourced the lib. T13 keeps proving a CRLF file is rejected (renamed to what it proves).
- LOW 3 (root): T14 prints a visible SKIP and counts nothing when `id -u` is 0 (chmod bits are ignored as root).
- LOW 4: `WORK="$(mktemp -d)" || exit 1` in the suite.
- LOW 5: the helper prints the rejected map line through `printf '%q'` so a caller's `echo -e` err() cannot interpret backslash escapes from map content; install-plugins.sh `err()` itself is untouched (other messages rely on `-e`).

## ACCEPTANCE CRITERIA
1. Signal safety: a SIGINT delivered during the awk write leaves no `SKILL.md.*` sibling and the process exits 130; on a normal return the previous INT/TERM trap state is restored and no EXIT trap was set. Case `T15-sigint-removes-temp` + `T15b-traps-restored`.
   CHECK: out=$(make test suite=lib/tests/effort-pins.test.sh 2>&1); echo "$out" | grep -q 'effort-pins: [0-9]* pass, 0 fail' || { echo "$out" | grep FAIL; exit 1; }; for k in T15-sigint-removes-temp T15b-traps-restored; do echo "$out" | grep -q "PASS $k" || { echo "missing PASS $k"; exit 1; }; done; ! grep -qE 'trap [^#]*EXIT' lib/effort-pins.sh && echo SIGNAL_OK
   EXPECT: SIGNAL_OK
   EVIDENCE: MET exit=0 marker-found :: SIGNAL_OK
2. Re-read branch reached: a test stubs `_effort_pin_write` to a no-op and asserts `_effort_pin_apply_one` returns 1 with an err line naming the file; the message no longer mentions CRLF; T13 is renamed `T13-crlf-file-rejected`.
   CHECK: out=$(make test suite=lib/tests/effort-pins.test.sh 2>&1); for k in T13-crlf-file-rejected T13b-reread-mismatch-fails; do echo "$out" | grep -q "PASS $k" || { echo "missing PASS $k"; exit 1; }; done; ! grep -q 'CRLF or malformed' lib/effort-pins.sh && echo REREAD_OK
   EXPECT: REREAD_OK
   EVIDENCE: MET exit=0 marker-found :: REREAD_OK
3. Suite hardening: `WORK` guarded, T14 skips visibly under root (the skip path is exercised by faking `id -u` through a function override in a subshell run of the T14 block, or by an explicit `EFFORT_PINS_TEST_FAKE_ROOT=1` hook read by the suite).
   CHECK: grep -q 'WORK="$(mktemp -d)" || exit 1' lib/tests/effort-pins.test.sh && out=$(EFFORT_PINS_TEST_FAKE_ROOT=1 make test suite=lib/tests/effort-pins.test.sh 2>&1) && echo "$out" | grep -q 'SKIP T14' && echo "$out" | grep -q 'effort-pins: [0-9]* pass, 0 fail' && echo SUITE_OK
   EXPECT: SUITE_OK
   EVIDENCE: MET exit=0 marker-found :: SUITE_OK
4. Escape-safe rejection message: a map line `bad\tname high` (literal backslash-t) is rejected and the err text carries the shell-quoted form (`bad\\tname`), so an `echo -e` caller prints it verbatim. Case `T16-rejected-line-quoted`.
   CHECK: out=$(make test suite=lib/tests/effort-pins.test.sh 2>&1); echo "$out" | grep -q 'PASS T16-rejected-line-quoted' && grep -q "printf '%q'" lib/effort-pins.sh && echo QUOTE_OK
   EXPECT: QUOTE_OK
   EVIDENCE: MET exit=0 marker-found :: QUOTE_OK
5. Everything else green: shellcheck on the helper and suite, effort-routing census, live tree idempotent (0 applied, 0 failed), doctrine-citers.
   CHECK: shellcheck lib/effort-pins.sh lib/tests/effort-pins.test.sh && make test suite=lib/tests/effort-routing.test.sh 2>&1 | grep -q 'census: [0-9]* pass, 0 fail' && bash lib/effort-pins.sh 2>&1 | grep -q ' 0 applied, [0-9]* already at level, 0 failed' && make test suite=lib/tests/no-vacuous-locks.test.sh >/dev/null 2>&1 && echo STABLE_OK
   EXPECT: STABLE_OK
   EVIDENCE: MET exit=0 marker-found :: STABLE_OK

## FILE SCOPE
- lib/effort-pins.sh, lib/tests/effort-pins.test.sh
- .claude/tasks/TODO.md (parked LOW line ticked), CHANGELOG.md (Fixed line), this contract
