# Fix plan — gates.sh stray oracle + default timeout (hotfix)

Contract: .claude/tasks/contracts/2026-11-17-gates-label-timeout-2342.md
Branch: bugfix/gates-label-timeout. Files: lib/gates.sh, lib/tests/gates.test.sh.

## Root causes
1. `_absorb` (lib/gates.sh:86-98) opens a criterion only on
   `^([0-9]+)\.[[:space:]]+(.*)$`. Any other label (`1b. sub`, `1.1 dotted`,
   `2) paren`, an indented `   2. sub`, `- sub`, `**2.** sub`) matches no
   branch and is dropped as prose, but `_CUR` still points at the previous
   criterion, so `_set_attr` lets the CHECK/EXPECT/EVIDENCE under it
   overwrite that criterion's oracle. Criterion 1 with `CHECK: exit 1`
   followed by a stray passing oracle yields VERDICT: MET (LRN-284; all six
   shapes reproduced on a scratch copy).
2. `TIMEOUT="${GATES_TIMEOUT:-120}"` (lib/gates.sh:32) is per CHECK; the full
   `make test` takes ~135 s, so a "full suite green" criterion goes NOT-MET
   on timeout unless the caller exports GATES_TIMEOUT (contracts used
   400/600/1200).

## Edit — lib/gates.sh (exact)
A. Line 32: `TIMEOUT="${GATES_TIMEOUT:-600}"`, with three comment lines
   right above it:
   ```bash
   # TIMEOUT is per CHECK and a run lasts their sum: the caller's own limit (a
   # foreground tool call stops at 600 s) must cover it, else run it in the
   # background. A killed run writes nothing back; the floor stays PENDING.
   ```

B. `_set_attr`: a comment line above the function, then a guard between the
   `_CUR -lt 0` block and the assigning `case`:
   ```bash
   # A second attribute on one criterion is an error, never an overwrite: it
   # is what an oracle under a label the parser missed looks like (LRN-284).
   _set_attr() { # _set_attr <CHECK|EXPECT|EVIDENCE> <value> <lineno>
     if [ "$_CUR" -lt 0 ]; then
       _err "$1 at line $3 belongs to no criterion"
       return 0
     fi
     local seen=""
     case "$1" in
       CHECK)    seen="${_CHECK[_CUR]}" ;;
       EXPECT)   seen="${_EXPECT[_CUR]}" ;;
       EVIDENCE) [ "${_EVLINE[_CUR]}" = 0 ] || seen=yes ;;
     esac
     if [ -n "$seen" ]; then
       _err "second $1: at line $3 in criterion ${_ID[_CUR]}"
       return 0
     fi
     case "$1" in
   ```
C. `_absorb`: new branch right after the criterion branch, before ABANDON:
   ```bash
     elif [[ "$1" =~ ^[0-9] ]]; then
       _err "malformed criterion label at line $2 (want \`N. text\`)"
       _CUR=-1
   ```
   It covers the case B cannot: a digit label after a MANUAL criterion
   (no attribute yet) would otherwise lend it the stray oracle. The comment
   above `_absorb` gains: "A digit-led line that is not `N. text` (`1b.`,
   `1.1`, `2)`) is rejected and orphans what follows, like a duplicate id."

D. `main`: when no criterion parsed, the die message carries the first
   parse error, so an all-malformed block (`1) a`, `2) b`) still names its
   line:
   `main`'s locals become `local mode="$1" file="$2" first`, and the
   two-line `[ "${#_ID[@]}" -gt 0 ] || _die "no numbered criteria …"`
   becomes:
   ```bash
     if [ "${#_ID[@]}" -eq 0 ]; then
       first="${_ERRORS[0]:+; ${_ERRORS[0]}}"
       _die "no numbered criteria under ## ACCEPTANCE CRITERIA$first"
     fi
   ```

Any `_ERRORS` entry already makes the verdict ERROR rc 2 and executes
nothing (existing "malformed ledger executes nothing" case).

Scans done on all 90+ .claude/tasks/contracts/*.md: no unindented digit-led
non-criterion line and no criterion with a repeated attribute; `gates.sh
status` verdicts identical before/after on every contract (scratch copy).

## Edit — lib/tests/gates.test.sh (exact)
1. Section "fail-closed execution", right after
   `has "timeout recorded" "NOT-MET timeout=1s"`:
   ```bash
   # The default must outlast the full suite (~135 s on 2026-11-16): at 120 s
   # a "full make test green" criterion went NOT-MET on the timeout alone.
   LAST="$WORK/default-timeout.md"
   printf '## ACCEPTANCE CRITERIA\n1. manual\n' > "$LAST"
   out="$(env -u GATES_TIMEOUT bash "$GATES" status "$LAST" 2>&1)"
   if [[ "$out" == *"timeout 600s"* ]]; then
     ok "default timeout 600s"
   else
     bad "default timeout 600s" "status did not print timeout 600s"
   fi
   ```
2. Section "parse strictness", right after the "duplicate orphans what
   follows" case (its closing `EOF`):
   ```bash
   # An oracle under a label the parser does not read as `N. text` must never
   # overwrite the previous criterion's: criterion 1 fails, the stray oracle
   # passes, a false MET (LRN-284). A digit-led label is rejected by name;
   # any other shape trips the second-attribute guard when the previous
   # criterion already has that attribute (after a manual one it does not).
   gate "1b. label rejected" run "malformed criterion label at line 6" 2 <<'EOF'
   ## ACCEPTANCE CRITERIA
   1. real
      CHECK: exit 1
      EXPECT: x
      EVIDENCE: pending
   1b. sub
      CHECK: echo y
      EXPECT: y
      EVIDENCE: pending
   EOF

   gate "1.1 label rejected" run "malformed criterion label at line 3" 2 <<'EOF'
   ## ACCEPTANCE CRITERIA
   1. first
   1.1 dotted
      EVIDENCE: pending
   EOF

   gate "no valid label" run "malformed criterion label at line 2" 2 <<'EOF'
   ## ACCEPTANCE CRITERIA
   2) paren
   EOF

   gate "indented label: second CHECK" run "second CHECK: at line 7" 2 <<'EOF'
   ## ACCEPTANCE CRITERIA
   1. real
      CHECK: exit 1
      EXPECT: x
      EVIDENCE: pending
      2. sub
      CHECK: echo y
      EXPECT: y
      EVIDENCE: pending
   EOF

   gate "bullet label: second EVIDENCE" run "second EVIDENCE: at line 9" 2 <<'EOF'
   ## ACCEPTANCE CRITERIA
   1. real
      CHECK: exit 1
      EXPECT: x
      EVIDENCE: pending
   - sub
      CHECK: echo y
      EXPECT: y
      EVIDENCE: pending
   EOF
   ```
   (Plan text is indented 3 for the list; in the file every heredoc body
   line starts at column 0 exactly as in the existing cases, the oracle
   attributes indented 3 spaces.)

## Residual (accepted)
- Any label branch C misses (indented `   2.`, `- `, `**2.**`) after a MANUAL
  criterion still lends it the stray oracle: that row turns MANUAL into
  MET/NOT-MET on an unrelated oracle. No failing oracle is overwritten.
- `ABANDON: 1b …` parses as id 1 (gates.sh:90 regex): pre-existing, same
  class, logged to TODO, not fixed here.
- lib/verify-secure-loop.md:46-47 lists ERROR causes as examples; it already
  omits "no numbered criteria" and "ABANDON names unknown criterion", so the
  two new causes do not make it newly stale. Logged to TODO (complete the
  list), not a third file here.
- ~/.claude/lib is a symlink to this repo's lib: an in-flight contract in
  another repo with a repeated attribute or a digit-led prose line now goes
  ERROR (fail-closed, names the line).

## Out of scope
lib/design-tool-gate.sh:70 (TODO:90, deferred by its own text). The test
helper's own `${GATES_TIMEOUT:-120}` stays (fast fixtures only).
