#!/usr/bin/env bash
# ============================================================
# Structure locks — contract/verifier pair (verify-loops lot 2)
# Deterministic greps on load-bearing doctrine clauses: an edit
# that silently drops one (blind verifier, PROOF mandatory,
# immutable REQUEST, micro-gate scope enrichment…) reds here.
# ============================================================
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO/lib/contract-interview.md"
AGT="$REPO/agents/verifier.md"
PASS=0; FAIL=0

# Fixed-string lock (UTF-8 punctuation safe)
tf() { # tf <label> <file> <fixed-string>
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    echo "  PASS $1"; PASS=$((PASS+1))
  else
    echo "  FAIL $1 — missing: $3"; FAIL=$((FAIL+1))
  fi
}

# Regex lock
tr_() { # tr_ <label> <file> <ERE>
  if grep -qE -- "$3" "$2" 2>/dev/null; then
    echo "  PASS $1"; PASS=$((PASS+1))
  else
    echo "  FAIL $1 — no match: $3"; FAIL=$((FAIL+1))
  fi
}

# Negative lock — pattern must NOT match
tn() { # tn <label> <file> <ERE>
  if grep -qE -- "$3" "$2" 2>/dev/null; then
    echo "  FAIL $1 — forbidden match: $3"; FAIL=$((FAIL+1))
  else
    echo "  PASS $1"; PASS=$((PASS+1))
  fi
}

echo "── contract-interview.md locks ──"
if [ -f "$LIB" ]; then
  echo "  PASS lib exists"; PASS=$((PASS+1))
else
  echo "  FAIL lib missing: $LIB"; FAIL=$((FAIL+1))
fi
tf  "verbatim request immutable"      "$LIB" "REQUEST (verbatim — IMMUTABLE)"
tf  "contracts dir committed path"    "$LIB" ".claude/tasks/contracts/"
tf  "unique per-run slug"             "$LIB" "<YYYY-MM-DD>-<slug>-<HHMM>"
tf  "silent when complete"            "$LIB" "ZERO questions"
tf  "question budget"                 "$LIB" "max 3 questions"
tf  "aborted status"                  "$LIB" "status: aborted"
tf  "never left dirty"                "$LIB" "NEVER left dirty"
tf  "scope enrichment micro-gate"     "$LIB" "micro-gate"
tf  "gated marker"                    "$LIB" "[gated <YYYY-MM-DD>]"
tf  "main-loop only"                  "$LIB" "ORCHESTRATOR MAIN LOOP"
tf  "re-scope supersedes"             "$LIB" "supersedes:"
tf  "hand-off = path not content"     "$LIB" "contract PATH, not a restatement"

echo "── verifier.md locks ──"
if [ -f "$AGT" ]; then
  echo "  PASS agent exists"; PASS=$((PASS+1))
else
  echo "  FAIL agent missing: $AGT"; FAIL=$((FAIL+1))
fi
tr_ "frontmatter name"                "$AGT" "^name: verifier$"
tr_ "tools read-only set"             "$AGT" "^tools: Read, Grep, Glob, Bash$"
tn  "no write-capable tools"          "$AGT" "^tools:.*(Edit|Write|NotebookEdit)"
tf  "verdict grammar"                 "$AGT" "VERIFY — VERDICT: CONFORME | ECARTS(n) | ERROR(<reason>)"
tf  "blind — no iteration history"    "$AGT" "NEVER receive iteration history"
tf  "blind — complete every time"     "$AGT" "every verification is complete and blind"
tf  "unverifiable is not met"         "$AGT" "\`UNVERIFIABLE\` ≠ \`MET\`"
tf  "proof mandatory"                 "$AGT" "\`PROOF\` is MANDATORY"
tf  "contract read from disk"         "$AGT" "READ it from disk"
tf  "checked count equality"          "$AGT" "checked count in"
tf  "report-only"                     "$AGT" "Report-only. Never edit"
tf  "bash observation only"           "$AGT" "OBSERVATION ONLY"
tf  "loop bound"                      "$AGT" "Max 3 iterations"
tf  "structural retry then escalate"  "$AGT" "2nd structural failure"
tf  "mute never a pass"               "$AGT" "A mute verifier is NEVER a PASS"
tf  "conforme first pass no loop"     "$AGT" "proceed straight to the security gate"
tf  "reverify order request first"    "$AGT" "re-verify the request FIRST"

echo ""
echo "contract-verifier structure locks: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
