# Bugfix plan: DEGRADED read off the wrong line (BUGS-FOUND:134 + TODO:13)

## DIAGNOSIS
BUG: three gate readers teach DEGRADED as a value of the `SECURITY — VERDICT:` line.
ROOT CAUSE: agents/security-auditor.md OUTPUT (:133-134) prints
`SECURITY — VERDICT: PASS | BLOCK(n) | ERROR(<reason>)`; DEGRADED appears only on the
`TOOL:` line (`ABSENT (DEGRADED — checklist only; install: make plugin)`). The parse
lists in lib/verify-secure-loop.md:111-128, agents/security-auditor.md:184-192 and
skills/hotfix/SKILL.md:182-183 end their parse at a terminal `PASS` bullet and list
`DEGRADED` as a sibling value of the VERDICT line. A reader parsing the VERDICT line
never sees it: a DEGRADED scan reads as a clean PASS (the hotfix SECURITY summary field,
the feat/bugfix end-of-run skip, the "surface the checklist + recommend make plugin"
step never fires). A PASS with no `TOOL:` line is not named a structural failure, so it
also reads as non-DEGRADED.
EVIDENCE: OUTPUT template vs the three parse lists; B3 STEP 6 opus review.
PRIOR: LRN-300 (a rule keyed on a gate verdict names the line its qualifier prints on) —
applied to the three readers and to lib/effort-shift.md item 3, the canonical skip rule.
The auditor's output format stays unchanged (no parser contract change).
BLAST RADIUS: the three readers + lib/effort-shift.md:124 ("security PASS (not
DEGRADED)" names no line). agents/security-auditor.md STEP 1 (:44-48) already puts
DEGRADED on the `TOOL:` line: untouched. feat/bugfix already name the TOOL line
(51f343f): untouched, now locked. README:84 / USAGE / CHANGELOG cite no parse list:
untouched (doc-sync re-checks). audit-delta:271, tour:156, onboard:549 say "semgrep
ABSENT → DEGRADED" (audit mode, non-blocking): untouched. a11y/guardrails/ship-feature/
init-project inherit lib/verify-secure-loop.md (their "PASS → STEP n" lines point at it).
Rejected alternative: change the auditor to print `VERDICT: DEGRADED` — breaks every
`PASS | BLOCK(n)` parser and the PROOF rule; the logged fix direction is the reader side.
A DEGRADED BLOCK needs no own sentence: the BLOCK bullet handles every BLOCK.

## FIX PLAN (exact text; each `old` occurs exactly once in its file)

1. lib/verify-secure-loop.md — the PASS bullet reads the TOOL line; the old
DEGRADED bullet is deleted.

### Block vsl-pass-old
```
- `PASS` → done, proceed to commit.
```
### Block vsl-pass-new
```
- `PASS` → read the `TOOL:` line first: DEGRADED (semgrep absent) shows
  there, never on the VERDICT line; a PASS with no `TOOL:` line is a
  structural failure (below). Then done, proceed to commit; a DEGRADED
  PASS also surfaces the checklist result + recommends `make plugin`
  (the tool's absence never blocks).
```
### Block vsl-degraded-old
```
- `DEGRADED` (semgrep absent) → does NOT block on the tool's absence; surface
  the checklist result + recommend `make plugin`. A DEGRADED run that still
  BLOCKs (grep-caught secret/injection) blocks like any other.
```
(replaced by nothing: the three lines are removed)

2. agents/security-auditor.md — same shape.

### Block aud-pass-old
```
  - `PASS` → proceed (to commit / next step).
```
### Block aud-pass-new
```
  - `PASS` → read the `TOOL:` line first: DEGRADED (semgrep absent)
    shows there, never on the VERDICT line; a PASS with no `TOOL:` line
    is a structural failure (below). Then proceed (to commit / next
    step); a DEGRADED PASS also surfaces the checklist result +
    recommends `make plugin` (the tool's absence never blocks).
```
### Block aud-degraded-old
```
  - `DEGRADED` (semgrep absent) → does NOT block; surface the checklist
    result + recommend `make plugin`. A DEGRADED BLOCK (grep-caught
    hardcoded secret etc.) blocks like any other.
```
(removed)

### Block aud-struct-old
```
    unparsable, crash, PASS without PROOF) → retry ONCE fresh; 2nd
    structural failure → human escalation. A mute auditor is never a PASS.
```
### Block aud-struct-new
```
    unparsable, crash, PASS without PROOF or without `TOOL:` line) →
    retry ONCE fresh; 2nd structural failure → human escalation. A mute
    auditor is never a PASS.
```

3. skills/hotfix/SKILL.md

### Block hot-pass-old
```
   - `PASS` (or `DEGRADED` with no BLOCK) → proceed to commit.
```
### Block hot-pass-new
```
   - `PASS` → read the `TOOL:` line first: DEGRADED (semgrep absent)
     shows there, never on the VERDICT line; a PASS with no `TOOL:` line
     is a structural failure (below). Then proceed to commit; a DEGRADED
     PASS sets the summary's SECURITY field to `DEGRADED (checklist only)`.
```
### Block hot-struct-old
```
   - Structural failure (mute / unparsable / no VERDICT line) → treat as a
     failed gate: retry ONCE fresh; a 2nd structural failure → revert +
     escalate. A mute auditor is never a PASS.
```
### Block hot-struct-new
```
   - Structural failure (mute / unparsable / no VERDICT line / PASS with
     no `TOOL:` line) → treat as a failed gate: retry ONCE fresh; a 2nd
     structural failure → revert + escalate. A mute auditor is never a
     PASS.
```

4. lib/effort-shift.md § Advisor item 3 — name the line (LRN-300).

### Block eff-old
```
   `skipped (gates clean on first pass)`. A skipped call discharges
```
### Block eff-new
```
   `skipped (gates clean on first pass)`; DEGRADED shows on the
   auditor's `TOOL:` line. A skipped call discharges
```

5. lib/tests/loops-light.test.sh — regression locks. Single-line fragments with the
file's own `tf`/`tn` (LRN-093: a clause spanning lines → lock a distinctive single-line
fragment), double quotes with escaped backticks (the file's idiom). The section lives
here, not in security-auditor.test.sh, so one section locks this bug across its five
files (that file's `tn` is ERE: the parenthesised strings would match vacuously there).

### Block t-vars-old
```
HSKL="$REPO/skills/hotfix/SKILL.md"
```
### Block t-vars-new
```
HSKL="$REPO/skills/hotfix/SKILL.md"
AUD="$REPO/agents/security-auditor.md"
EFF="$REPO/lib/effort-shift.md"
```
### Block t-locks-old
```
echo ""
echo "loops-light structure locks: $PASS pass, $FAIL fail"
```
### Block t-locks-new
```
echo "── DEGRADED on the TOOL line, feat/bugfix skip (BUGS-FOUND:134) ──"
for f in "$FSK" "$BSK"; do
  n=$(basename "$(dirname "$f")")
  tf "$n skip not DEGRADED"   "$f" "security PASS (not DEGRADED),"
  tf "$n skip first attempt"  "$f" "each on its first attempt;"
  tf "$n skip out of view"    "$f" "a verdict no longer in view runs the call."
  tf "$n skip names TOOL"     "$f" "auditor's \`TOOL:\` line, beside a PASS."
done
tf "effort-shift names TOOL"  "$EFF" "auditor's \`TOOL:\` line. A skipped call"
for f in "$INC" "$AUD" "$HSKL"; do
  n=$(basename "$(dirname "$f")")/$(basename "$f")
  tf "$n PASS reads TOOL"     "$f" "\`PASS\` → read the \`TOOL:\` line first"
  tf "$n DEGRADED off VERDICT" "$f" "never on the VERDICT line;"
  tf "$n no TOOL structural"  "$f" "a PASS with no \`TOOL:\` line"
  tf "$n structural (below)"  "$f" "structural failure (below)"
  tn "$n DEGRADED no verdict" "$f" "\`DEGRADED\`"
  tn "$n DEGRADED no branch"  "$f" "DEGRADED (semgrep absent) →"
done

echo ""
echo "loops-light structure locks: $PASS pass, $FAIL fail"
```
The two `tn` catch the old shapes coming back: the backticked `DEGRADED` value and a
`DEGRADED (semgrep absent) →` branch (none of the three files keeps that token after the fix; hotfix's
`DEGRADED (checklist only)` does not match). The paired `tf` on the same file fails on
an unreadable file, which `tn` alone would pass.
Simulated on a scratch clone (locks first, fix second): develop = 16 FAIL (effort-shift
lock + 3 files × 4 reader `tf` + 3 backticked `tn`), the 8 feat/bugfix locks PASS, the
3 `DEGRADED (semgrep absent) →` `tn` PASS (they guard the un-backticked variant, absent
on both sides); fix applied = 78/78 PASS.
Deferred (confirmation pass, logged to BUGS-FOUND at bookkeeping): a DEGRADED BLOCK's
cap STOP does not name the missing semgrep / `make plugin`; DEGRADED is read by word
presence, a garbled `TOOL:` line reads as a full scan (allowlist `semgrep <ver>` would
close it). Both were already true before this fix (the old bullet keyed on the wrong
line).

6. Bookkeeping (main loop, not executor): BUGS-FOUND:134 FIXED, TODO:13 done.

RISK: low — prose only, no output format change. New prose lines ≤ 80 cols; the lock
lines follow the test file's existing width (it already has lines past 80).
