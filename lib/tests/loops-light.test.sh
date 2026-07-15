#!/usr/bin/env bash
# ============================================================
# Structure locks — light-flow wiring (verify-loops lot 4)
# feat/bugfix get contract + fresh verifier + security gate
# (bounded 3x); hotfix gets contract + security gate whose
# FAILURE REVERTS (never loops). Locks the load-bearing clauses.
# ============================================================
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
INC="$REPO/lib/verify-secure-loop.md"
FSK="$REPO/skills/feat/SKILL.md"
BUG="$REPO/agents/bugfixer.md"
HOT="$REPO/agents/hotfixer.md"
HSK="$REPO/skills/hotfix/SKILL.md"
PASS=0; FAIL=0

tf() { # tf <label> <file> <fixed-string>
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    echo "  PASS $1"; PASS=$((PASS+1))
  else
    echo "  FAIL $1 — missing: $3"; FAIL=$((FAIL+1))
  fi
}
tr_() { # tr_ <label> <file> <ERE>
  if grep -qE -- "$3" "$2" 2>/dev/null; then
    echo "  PASS $1"; PASS=$((PASS+1))
  else
    echo "  FAIL $1 — no match: $3"; FAIL=$((FAIL+1))
  fi
}

echo "── verify-secure-loop.md (shared include) ──"
if [ -f "$INC" ]; then echo "  PASS include exists"; PASS=$((PASS+1)); else echo "  FAIL include missing"; FAIL=$((FAIL+1)); fi
tf "gate1 fresh verifier"        "$INC" "GATE 1 — REQUEST CONFORMITY (fresh verifier)"
tf "gate2 fresh auditor"         "$INC" "GATE 2 — SECURITY (fresh security-auditor)"
tf "blind — no dev summary"      "$INC" "Never pass the dev's summary"
tf "conforme first pass no loop" "$INC" "First-pass conforme = no loop"
tf "conformity max 3"            "$INC" "Max 3 conformity iterations"
tf "security max 3"              "$INC" "Max 3 security iterations"
tf "reverify request first"     "$INC" "re-verify the REQUEST first"
tf "order invariant"            "$INC" "always re-checked BEFORE security"
tf "mute never a pass (verify)" "$INC" "NEVER a PASS"
tf "nominal cheap stated"       "$INC" "one verifier dispatch + one security dispatch"

echo "── feat/SKILL.md (feat orchestrator wiring) ──"
tf "feat contract step"         "$FSK" "STEP 0.7 — CONTRACT"
tf "feat contract-interview"    "$FSK" "lib/contract-interview.md"
tf "feat verify+secure step"    "$FSK" "STEP 4 — VERIFY + SECURE"
tf "feat uses shared include"   "$FSK" "lib/verify-secure-loop.md"
tf "feat nominal 1+1 dispatch"  "$FSK" "verifier + one security dispatch"
tf "feat dispatches feater"     "$FSK" 'subagent_type="feater"'

echo "── bugfixer.md (bugfix wiring) ──"
tf "bug contract step"          "$BUG" "STEP 3.5 — CONTRACT"
tf "bug diagnosis feeds it"     "$BUG" "feeds it: REQUEST verbatim"
tf "bug fresh gates"            "$BUG" "Fresh gates (verify + secure)"
tf "bug uses shared include"    "$BUG" "lib/verify-secure-loop.md"

echo "── hotfixer.md (hotfix wiring — revert, not loop) ──"
tr_ "hotfix has Agent tool"     "$HOT" "^tools:.*Agent"
tf "hotfix silent contract"     "$HOT" "STEP 1.7 — CONTRACT (silent autofill)"
tf "hotfix zero questions"      "$HOT" "questions ever"
tf "hotfix security gate"       "$HOT" "Security gate (fresh auditor)"
tf "hotfix block reverts"       "$HOT" "failure REVERTS, never loops"
tf "hotfix no verifier"         "$HOT" "No verifier is dispatched at hotfix weight"
tf "hotfix skill has Agent"     "$HSK" "  - Agent"

echo ""
echo "loops-light structure locks: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
