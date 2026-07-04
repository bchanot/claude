#!/usr/bin/env bash
# ============================================================
# Structure locks — heavy-flow wiring (verify-loops lot 5)
# ship-feature + init-project get contract + enrich-at-gate +
# verify-secure-loop; onboard is the explicit NO-LOOP audit case.
# ============================================================
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SHF="$REPO/skills/ship-feature/SKILL.md"
INI="$REPO/skills/init-project/SKILL.md"
ONB="$REPO/skills/onboard/SKILL.md"
PASS=0; FAIL=0

tf() { # tf <label> <file> <fixed-string>   (single-line patterns only, LRN-093)
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    echo "  PASS $1"; PASS=$((PASS+1))
  else
    echo "  FAIL $1 — missing: $3"; FAIL=$((FAIL+1))
  fi
}

echo "-- ship-feature (enrich-at-gate) --"
tf "shf contract step"        "$SHF" "STEP 0e — CONTRACT"
tf "shf contract-interview"   "$SHF" "lib/contract-interview.md"
tf "shf enrich at gate"       "$SHF" "ENRICH the STEP 0e contract"
tf "shf gated marker"         "$SHF" "[gated <date>]"
tf "shf verify+secure step"   "$SHF" "STEP 5 — VERIFY + SECURE"
tf "shf uses shared include"  "$SHF" "lib/verify-secure-loop.md"
tf "shf judges enriched"      "$SHF" "ENRICHED contract"
tf "shf orthogonal to review" "$SHF" "DISTINCT axis from STEP 6 code review"

echo "-- init-project (contract from BRIEF + adds security) --"
tf "ini contract from brief"  "$INI" "contract-interview.md"
tf "ini criteria from V1"     "$INI" "V1 FEATURES (each testable)"
tf "ini enrich at gate1"      "$INI" "ENRICH the STEP 1 contract"
tf "ini verify+secure step"   "$INI" "STEP 9 — VERIFY + SECURE"
tf "ini uses shared include"  "$INI" "lib/verify-secure-loop.md"
tf "ini adds security gate"   "$INI" "adds the security gate init-project previously lacked"

echo "-- onboard (explicit NO-LOOP audit) --"
tf "onb no-loop stated"       "$ONB" "n'a PAS de boucle verify"
tf "onb audit not gate"       "$ONB" "MODE: audit"
tf "onb scope contract"       "$ONB" "contract de SCOPE"
tf "onb no symmetry loop"     "$ONB" "Ne PAS ajouter la boucle des flux dev"

echo ""
echo "loops-heavy structure locks: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
