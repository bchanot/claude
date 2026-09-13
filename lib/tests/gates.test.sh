#!/usr/bin/env bash
# ============================================================
# lib/gates.sh — behavioural tests + structure locks for the
# deterministic floor (GATE 0, lib/verify-secure-loop.md).
#
# Fail-closed is the entire point of this runner, so every
# "looks green but must not pass" case is asserted explicitly:
# nonzero exit carrying the marker, marker absent, timeout,
# unindented attribute silently demoting a gate to manual.
# Non-execution is proved with a sentinel file, and the
# sentinel's own positive control is asserted first — an
# absence check that was never able to fire proves nothing.
# ============================================================
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GATES="$REPO/lib/gates.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0; N=0
LAST=""

ok()   { echo "  PASS $1"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL $1 — $2"; FAIL=$((FAIL + 1)); }

# gate <label> <mode> <expected-verdict> <expected-rc>  <<< fixture-on-stdin
gate() {
  local label="$1" mode="$2" want="$3" wantrc="$4" out rc
  N=$((N + 1)); LAST="$WORK/c$N.md"
  cat > "$LAST"
  out="$(GATES_TIMEOUT="${GATES_TIMEOUT:-120}" \
    bash "$GATES" "$mode" "$LAST" 2>&1)"
  rc=$?
  if [[ "$out" == *"$want"* ]] && [ "$rc" -eq "$wantrc" ]; then
    ok "$label"
  else
    bad "$label" "want '$want' rc=$wantrc, got rc=$rc"
    printf '%s\n' "$out" | sed 's/^/        /'
  fi
}

has() {
  if grep -qF -- "$2" "$LAST"; then ok "$1"; else bad "$1" "missing: $2"; fi
}
exists() {
  if [ -e "$1" ]; then ok "$2"; else bad "$2" "sentinel absent: $1"; fi
}
absent() {
  if [ -e "$1" ]; then bad "$2" "sentinel created: $1"; else ok "$2"; fi
}

echo "── fail-closed execution ──"

gate "exit 0 + marker = MET" run "GATES — VERDICT: MET" 0 <<'EOF'
## ACCEPTANCE CRITERIA
1. green
   CHECK: echo "MARKER-OK"
   EXPECT: MARKER-OK
   EVIDENCE: pending
EOF
has "evidence written back" "EVIDENCE: MET exit=0 marker-found"

# The case a naive checker gets wrong: the marker IS in the output, but the
# process failed. Substring matching alone would certify a broken build.
gate "nonzero exit + marker = UNMET" run "GATES — VERDICT: UNMET(1)" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. lies
   CHECK: echo "MARKER-OK"; exit 7
   EXPECT: MARKER-OK
   EVIDENCE: pending
EOF
has "nonzero recorded honestly" "NOT-MET exit=7 (nonzero)"

gate "exit 0 + no marker = UNMET" run "GATES — VERDICT: UNMET(1)" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. silent success is not success
   CHECK: echo "something else"
   EXPECT: MARKER-OK
   EVIDENCE: pending
EOF
has "marker-absent recorded" "NOT-MET exit=0 marker-absent"

GATES_TIMEOUT=1 gate "timeout = UNMET" run "GATES — VERDICT: UNMET(1)" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. hangs
   CHECK: sleep 5
   EXPECT: never
   EVIDENCE: pending
EOF
has "timeout recorded" "NOT-MET timeout=1s"

gate "manual-only contract passes through" run "RUNNABLE: 0 of 2" 0 <<'EOF'
## ACCEPTANCE CRITERIA
1. a human reads the copy
2. the design matches the brief
EOF

echo "── non-execution (sentinel), positive control first ──"

# Positive control: prove the sentinel mechanism can fire at all.
gate "sentinel fires when a CHECK runs" run "GATES — VERDICT: MET" 0 <<EOF
## ACCEPTANCE CRITERIA
1. control
   CHECK: touch "$WORK/fired"; echo "M"
   EXPECT: M
   EVIDENCE: pending
EOF
exists "$WORK/fired" "positive control: sentinel created"

gate "status never executes" status "GATES — VERDICT: PENDING(1)" 2 <<EOF
## ACCEPTANCE CRITERIA
1. must not run
   CHECK: touch "$WORK/status-ran"; echo "M"
   EXPECT: M
   EVIDENCE: pending
EOF
absent "$WORK/status-ran" "status did not execute"
has "status did not write evidence" "EVIDENCE: pending"

gate "fenced example is not a gate" run "RUNNABLE: 1 of 1" 0 <<EOF
## ACCEPTANCE CRITERIA
1. real
   CHECK: echo "R"
   EXPECT: R
   EVIDENCE: pending

\`\`\`markdown
2. documentation example, invisible to the parser
   CHECK: touch "$WORK/fenced-ran"; echo "nope"
   EXPECT: nope
   EVIDENCE: pending
\`\`\`
EOF
absent "$WORK/fenced-ran" "fenced CHECK never executed"

gate "malformed ledger executes nothing" run "GATES — VERDICT: ERROR" 2 <<EOF
## ACCEPTANCE CRITERIA
1. would run if the ledger parsed
   CHECK: touch "$WORK/malformed-ran"; echo "M"
   EXPECT: M
   EVIDENCE: pending
2. partial oracle poisons the whole ledger
   CHECK: echo "x"
   EVIDENCE: pending
EOF
absent "$WORK/malformed-ran" "malformed ledger did not execute"
has "malformed ledger not written" "EVIDENCE: pending"

echo "── parse strictness ──"

gate "CHECK without EXPECT" run "CHECK without EXPECT" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. partial
   CHECK: echo x
   EVIDENCE: pending
EOF

gate "EXPECT without CHECK" run "EXPECT without CHECK" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. partial
   EXPECT: x
   EVIDENCE: pending
EOF

# An unindented CHECK must be diagnosed, never absorbed: silently ignoring it
# demotes a runnable criterion to a manual one — the one parse bug that turns
# this runner into a rubber stamp.
gate "unindented attribute is diagnosed" run "unindented CHECK:" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. sneaky
CHECK: echo x
EXPECT: x
   EVIDENCE: pending
EOF

gate "runnable without EVIDENCE line" run "has no EVIDENCE: line" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. no ledger slot
   CHECK: echo x
   EXPECT: x
EOF

gate "duplicate criterion id" run "duplicate criterion id: 1" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. first
   EVIDENCE: pending
1. second
   EVIDENCE: pending
EOF

# After a rejected duplicate the following attributes must be orphaned, not
# aliased onto the previous criterion — that would hand one gate another's
# oracle and let a stale EVIDENCE line satisfy it.
gate "duplicate orphans what follows" run "belongs to no criterion" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. real
   CHECK: echo x
   EXPECT: x
   EVIDENCE: pending
1. duplicate
   CHECK: echo y
   EXPECT: y
   EVIDENCE: pending
EOF

gate "no numbered criteria" run "no numbered criteria" 2 <<'EOF'
## ACCEPTANCE CRITERIA
nothing numbered here
EOF

echo "── abandonment ──"

gate "valid abandonment = rc 3" run "GATES — VERDICT: ABANDONED(1)" 3 <<'EOF'
## ACCEPTANCE CRITERIA
1. green
   CHECK: echo "M"
   EXPECT: M
   EVIDENCE: pending
2. impossible
   EVIDENCE: pending

ABANDON: 2 upstream API offline; handoff recorded in BLK-099
EOF

gate "blank abandonment reason" run "blank reason" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. green
   EVIDENCE: pending

ABANDON: 1
EOF

gate "abandonment naming nothing" run "unknown criterion" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. green
   EVIDENCE: pending

ABANDON: 9 names a criterion that does not exist
EOF

echo "── usage ──"

# usage <label> <expected-substring> <argv...>
usage() {
  local label="$1" want="$2" out rc; shift 2
  out="$(bash "$GATES" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq 2 ] && [[ "$out" == *"$want"* ]]; then
    ok "$label"
  else
    bad "$label" "rc=$rc out=$out"
  fi
}

usage "no args = ERROR rc 2"         "usage:"
usage "missing contract = ERROR rc 2" "contract unreadable" run "$WORK/nope.md"
usage "unknown mode refused"          "usage:" frobnicate "$WORK/c1.md"

# ── structure locks on the doctrine this runner is wired into ───────────────

CI="$REPO/lib/contract-interview.md"
VS="$REPO/lib/verify-secure-loop.md"
AGT="$REPO/agents/verifier.md"
FE="$REPO/agents/feater.md"
BF="$REPO/agents/bugfixer.md"

lock() { # lock <label> <file> <fixed-string>
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    ok "$1"
  else
    bad "$1" "missing: $3"
  fi
}

echo "── contract-interview.md oracle doctrine ──"
lock "oracle section"          "$CI" "### ORACLES"
lock "runner named"            "$CI" "lib/gates.sh run <contract>"
lock "fail-closed spelled out" "$CI" "exit 0 **AND** the marker"
lock "both or neither"         "$CI" "Both attributes or neither"
lock "rule observe artifact"   "$CI" "Observe the named artifact"
lock "rule success-only"       "$CI" "Success-only marker"
lock "rule positive control"   "$CI" "Positive control before any absence check"
lock "rule recompute numbers"  "$CI" "Recompute supplied numbers"
lock "shell trust boundary"    "$CI" "url-guard.sh"
lock "template carries oracle" "$CI" "EXPECT: <success-only marker>"
lock "abandonment lifecycle"   "$CI" "**ABANDONMENT**"
lock "abandonment not deleted" "$CI" "NEVER deleted"

echo "── verify-secure-loop.md GATE 0 ──"
lock "gate 0 exists"           "$VS" "## GATE 0 — DETERMINISTIC FLOOR"
lock "gate 0 no dispatch"      "$VS" "**No verifier is dispatched**"
lock "gate 0 loop bound"       "$VS" "Max 3 floor iterations"
lock "gate 0 budget separate"  "$VS" "not eat the conformity budget"
lock "malformed = main loop"   "$VS" "never dispatch a dev for it"
lock "order invariant"         "$VS" "GATE 0 → GATE 1 → GATE 2"

echo "── verifier.md oracle + abandonment ──"
lock "verdict grammar"         "$AGT" \
  "VERIFY — VERDICT: CONFORME | ECARTS(n) | ABANDONED(n) | ERROR(<reason>)"
lock "red oracle wins"         "$AGT" "NEVER overrides a red or unrun oracle"
lock "vacuous oracle caught"   "$AGT" "vacuous oracle"
lock "oracle != english"       "$AGT" "proves the ORACLE, not the"
lock "never edits contract"    "$AGT" "reported, never rewritten"
lock "abandoned is not met"    "$AGT" "\`ABANDONED\` ≠ \`MET\`"
lock "abandoned routes human"  "$AGT" "direct human gate, never a dev loop"

echo "── executor four passes ──"
lock "feater passes"           "$FE" "## FOUR PASSES"
lock "feater no placeholder"   "$FE" "no deferred remainder you plan"
lock "feater never widens"     "$FE" "they never widen it"
lock "bugfixer passes"         "$BF" "## FOUR PASSES"
lock "bugfixer stays minimal"  "$BF" "keep the fix minimal"
lock "bugfixer neg control"    "$BF" "**Negative control.**"
lock "bugfixer test must fail" "$BF" "A test that passes both ways"

echo ""
echo "gates: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
