#!/usr/bin/env bash
# ============================================================
# Deterministic backstop for LRN-093 (vacuous grep locks).
# grep NEVER interprets a literal \n as a newline: in a -F
# fixed string it splits the pattern into a per-line OR (matches
# anything); in -E it is a literal "n". Either way a structure
# lock carrying \n proves nothing. The LRN advisory alone did not
# hold (2 recurrences same chantier) -> this mechanical guard.
#
# Rule: no backslash-n inside a quoted pattern on a grep / tf /
# tr_ / tn line, anywhere under lib/tests/*.test.sh. Flip-tested
# below against a synthetic offender so the guard proves it bites.
# ============================================================
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SELF="no-vacuous-locks.test.sh"
FAIL=0

# One scanner, reused for the real tree and the flip-test fixture.
# Matches a grep -*F/-*E call OR a tf/tr_/tn helper (at line start or after
# whitespace) whose quoted pattern contains a literal backslash-n.
scan() { # scan <dir containing *.test.sh>
  grep -rnE '(grep +-[A-Za-z]*[EFqe]|(^|[[:space:]])(tf|tr_|tn)[[:space:]]).*"[^"]*\\n' \
    "$1"/*.test.sh 2>/dev/null | grep -v "$SELF"
}

echo "-- LRN-093 backstop: scan lib/tests/*.test.sh --"
HITS="$(scan "$REPO/lib/tests")"
if [ -n "$HITS" ]; then
  FAIL=1
  printf '%s\n' "$HITS" | while IFS= read -r line; do
    printf '  FAIL vacuous backslash-n lock: %s\n' "$line"
  done
else
  printf '  PASS no vacuous backslash-n locks in lib/tests/*.test.sh\n'
fi

# Flip-test: the guard MUST catch a known offender (LRN-093 discipline —
# prove a lock CAN fail before trusting its green).
echo "-- flip-test: guard bites a synthetic offender --"
TMP="$(mktemp -d)"
# shellcheck disable=SC2016  # the single quotes are deliberate: literal backslash-n
printf '%s\n' 'tf "bad" "$F" "no\nforced loop"' > "$TMP/z.test.sh"
if [ -n "$(scan "$TMP")" ]; then
  printf '  PASS guard catches the synthetic offender\n'
else
  printf '  FAIL guard blind to a known offender (regex too weak)\n'
  FAIL=1
fi
rm -rf "$TMP"

echo ""
if [ "$FAIL" -eq 0 ]; then echo "no-vacuous-locks: clean"; else echo "no-vacuous-locks: vacuous locks present"; fi
[ "$FAIL" -eq 0 ]
