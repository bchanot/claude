#!/usr/bin/env bash
# lib/tests/a11y-scan.test.sh — floor of the /a11y scanner catalogue.
# The clean fixture must scan with zero FAIL and zero WARN. Each mutant breaks
# one rule on a copy of it and must raise that rule at the expected severity
# (positive control). The A11Y-CLEAR / A11Y-NO-NEW markers, the gates.sh
# contract wiring and the rejection of guardrails rules are checked too; the
# shared engine itself is proven in guardrails-scan.test.sh.
# shellcheck disable=SC2016
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCAN="$ROOT/skills/a11y/scripts/scan.py"
GOOD="$ROOT/lib/tests/fixtures/a11y-good"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0; LAST_OUT=""; LAST_RC=0

check() { # check <label> <got> <want>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  PASS $1"
  else FAIL=$((FAIL+1)); echo "  FAIL $1 (got '$2', want '$3')"; fi
}

scan() { python3 -B "$SCAN" "$@"; }

# edit <file> <sed-expr>: in-place edit without sed -i (BSD/GNU portable).
edit() { sed "$2" "$1" > "$1.new" && mv "$1.new" "$1"; }

has() { # has <SEVERITY> <RULE>: the last scan raised it
  printf '%s\n' "$LAST_OUT" | grep -Eq "^ +$1 +$2 " && echo yes || echo no
}

mutant() { # mutant <label> <SEVERITY> <RULE> <snippet run inside a copy>
  local label="$1" sev="$2" rule="$3" snippet="$4" dir
  dir="$WORK/$label"
  cp -R "$GOOD" "$dir" || { check "$label copy" failed ok; return; }
  if ! ( cd "$dir" && eval "$snippet" ) >/dev/null 2>&1; then
    check "$label setup" failed ok; return
  fi
  LAST_OUT=$(scan "$dir"); LAST_RC=$?
  check "$label raises $sev $rule" "$(has "$sev" "$rule")" yes
}

benign() { # benign <label> <snippet>: a legitimate pattern raises nothing
  local label="$1" snippet="$2" dir="$WORK/$1" out
  cp -R "$GOOD" "$dir" || { check "$label copy" failed ok; return; }
  if ! ( cd "$dir" && eval "$snippet" ) >/dev/null 2>&1; then
    check "$label setup" failed ok; return
  fi
  out=$(scan "$dir")
  check "$label raises no FAIL or WARN" \
    "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1
}

TSX=src/components/ContactForm.tsx

echo "== clean fixture"
out=$(scan "$GOOD"); rc=$?
check "clean exit code" "$rc" 0
check "clean has no FAIL or WARN" \
  "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1
check "report is titled a11y" \
  "$(printf '%s\n' "$out" | grep -c '^a11y scan: ')" 1

echo "== rules"
mutant img-alt FAIL A11Y-IMG-ALT "edit $TSX 's/ alt=\"Company logo\"//'"
mutant field-label FAIL A11Y-FIELD-LABEL "edit $TSX '/<label htmlFor=\"email\">/d'"
mutant click-keyboard FAIL A11Y-CLICK-NO-KEYBOARD "edit $TSX 's/ onKeyDown={go}//'"
mutant tabindex-positive WARN A11Y-TABINDEX-POSITIVE \
  "edit $TSX 's/tabIndex={0}/tabIndex={2}/'"
mutant focus-css-warn WARN A11Y-FOCUS-OUTLINE \
  "printf 'a:focus { outline: none; }\n' > src/styles.css"
mutant focus-css-fail FAIL A11Y-FOCUS-OUTLINE \
  "printf 'a:focus { outline: none; }\n' > src/styles.css; edit $TSX 's/outline-none focus-visible:ring-2 focus-visible:ring-blue-500/x/'"
mutant focus-tailwind FAIL A11Y-FOCUS-OUTLINE \
  "edit $TSX 's/outline-none focus-visible:ring-2 focus-visible:ring-blue-500/outline-none/'"

echo "== benign patterns stay silent"
benign comment-with-img-tag \
  "printf '%s\n' '// the <img> below is decorative' >> $TSX"
benign dialog-overlay-click \
  "printf '%s\n' '<div role=\"dialog\" aria-label=\"x\" onClick={go}>y</div>' >> $TSX"

echo "== check modes (contract oracle and re-pass baseline)"
IMG="A11Y-IMG-ALT:$TSX"
cp -R "$GOOD" "$WORK/cm"; edit "$WORK/cm/$TSX" 's/ alt="Company logo"//'
out=$(scan "$WORK/cm" --assert-absent "$IMG"); rc=$?
check "positive control: the oracle fails while the hit is there" "$rc" 1
check "a failing oracle never prints the marker" \
  "$(printf '%s\n' "$out" | grep -c A11Y-CLEAR)" 0
out=$(scan "$GOOD" --assert-absent "$IMG"); rc=$?
check "the oracle passes once the hit is gone" "$rc" 0
check "a passing oracle prints the marker" \
  "$(printf '%s\n' "$out" | grep -c '^A11Y-CLEAR 1$')" 1
scan "$GOOD" --assert-absent "HOST-NO-RATE-LIMIT:$TSX" >/dev/null 2>&1
check "a guardrails rule is unknown here (exit 2)" "$?" 2
scan "$WORK/cm" --json > "$WORK/cm-before.json"
out=$(scan "$GOOD" --baseline "$WORK/cm-before.json"); rc=$?
check "baseline lists the fixed hit" \
  "$(printf '%s\n' "$out" | grep -c '^  FIXED A11Y-IMG-ALT ')" 1
check "baseline with no new hit exits 0 with the marker" \
  "$rc:$(printf '%s\n' "$out" | grep -c '^A11Y-NO-NEW$')" "0:1"
scan "$GOOD" --json > "$WORK/clean-before.json"
out=$(scan "$WORK/cm" --baseline "$WORK/clean-before.json"); rc=$?
check "baseline with a new hit exits 1 without the marker" \
  "$rc:$(printf '%s\n' "$out" | grep -c A11Y-NO-NEW)" "1:0"

# contract <dir> <file>: a fix contract whose oracle is the scanner itself
contract() {
  cat > "$2" <<EOC
# CONTRACT — a11y-oracle-test
## ACCEPTANCE CRITERIA
1. every image in the contact form has an alt
   CHECK: python3 -B '$SCAN' '$1' --assert-absent '$IMG'
   EXPECT: A11Y-CLEAR
   EVIDENCE: pending
## FILE SCOPE
$TSX
EOC
}
contract "$WORK/cm" "$WORK/c-unfixed.md"
bash "$ROOT/lib/gates.sh" run "$WORK/c-unfixed.md" >/dev/null 2>&1
check "gates.sh: the oracle is UNMET before the fix" "$?" 2
contract "$GOOD" "$WORK/c-fixed.md"
bash "$ROOT/lib/gates.sh" run "$WORK/c-fixed.md" >/dev/null 2>&1
check "gates.sh: the oracle is MET after the fix" "$?" 0

echo "== cli"
scan --domain api "$GOOD" >/dev/null 2>&1; check "a guardrails domain exits 2" "$?" 2

echo "---"
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
