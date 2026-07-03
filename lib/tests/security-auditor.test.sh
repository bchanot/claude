#!/usr/bin/env bash
# ============================================================
# Structure locks — security-auditor agent + grafts (lot 3)
# Deterministic greps on load-bearing doctrine: an edit that
# drops one (pinned rulesets, DEGRADED-still-checks, PROOF,
# block-HIGH-only, anti-gaming, the two SKILL grafts) reds here.
# ============================================================
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
AGT="$REPO/agents/security-auditor.md"
ONB="$REPO/skills/onboard/SKILL.md"
ADL="$REPO/skills/audit-delta/SKILL.md"
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
tn() { # tn <label> <file> <ERE>  (must NOT match)
  if grep -qE -- "$3" "$2" 2>/dev/null; then
    echo "  FAIL $1 — forbidden match: $3"; FAIL=$((FAIL+1))
  else
    echo "  PASS $1"; PASS=$((PASS+1))
  fi
}

echo "── security-auditor.md locks ──"
if [ -f "$AGT" ]; then
  echo "  PASS agent exists"; PASS=$((PASS+1))
else
  echo "  FAIL agent missing: $AGT"; FAIL=$((FAIL+1))
fi
tr_ "frontmatter name"            "$AGT" "^name: security-auditor$"
tr_ "tools incl Write (audit)"    "$AGT" "^tools: Read, Grep, Glob, Bash, Write$"
tf  "verdict grammar"             "$AGT" "SECURITY — VERDICT: PASS | BLOCK(n) | ERROR(<reason>)"
tf  "ruleset security-audit"      "$AGT" "p/security-audit"
tf  "ruleset secrets"             "$AGT" "p/secrets"
tf  "ruleset owasp required"      "$AGT" "p/owasp-top-ten"
tf  "no config auto stated"       "$AGT" "never \`--config auto\`"
tf  "no auto login"               "$AGT" "never \`semgrep login\`"
tf  "secrets to CRITICAL"         "$AGT" "p/secrets | CRITICAL"
tf  "block ERROR threshold only"  "$AGT" "blocking threshold is ERROR"
tf  "medium low reported"         "$AGT" "MEDIUM/LOW are REPORTED, never"
tf  "degraded still checks"       "$AGT" "STILL RUN STEP 3"
tf  "degraded vacuous pass named" "$AGT" "vacuous pass"
tf  "anti-gaming suppression"     "$AGT" "NEW suppression comment"
tf  "anti-gaming micro-gate"      "$AGT" "[gated <date>]"
tf  "proof mandatory"             "$AGT" "\`PROOF\` is MANDATORY"
tf  "mute never a pass"           "$AGT" "NEVER a PASS"
tf  "write rule-locked audit"     "$AGT" "writable path is \`REPORT\`"
tf  "gate mode write forbidden"   "$AGT" "\`Write\` is FORBIDDEN in this mode"
tf  "blind no history"            "$AGT" "NEVER receive iteration history"
tf  "reverify request first"      "$AGT" "re-verify the REQUEST first"
tf  "max 3 security iters"        "$AGT" "Max 3 security iterations"

echo "── onboard graft locks ──"
tf  "onboard dispatches auditor"  "$ONB" "subagent_type=\"security-auditor\""
tf  "onboard report path"         "$ONB" ".onboard-audit/semgrep.md"
tf  "onboard verify incl semgrep" "$ONB" "code-clean,cso,semgrep,doc"

echo "── audit-delta graft locks ──"
tf  "audit-delta dispatches"      "$ADL" "subagent_type=\"security-auditor\""
tf  "audit-delta semgrep first"   "$ADL" "FIRST run the semgrep SAST pass"

echo ""
echo "security-auditor structure locks: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
