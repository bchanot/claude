#!/usr/bin/env bash
# Deterministic tests for lib/doc-shape.sh — the MINOR-shape oracle.
#
# The oracle re-checks that a patch the LLM classified MINOR actually HAS minor
# shape, on REAL git diffs (not assumed). Each case proves a verdict:
#   S1  factual one-liner (1 add / 1 del, no heading)      → 0 within envelope
#   S2  adds a `## Section` heading                         → 1 exceeds (structural)
#   S3  +30 plain lines, no heading                         → 1 exceeds (size)
#   S3b +20 plain lines (== threshold)                      → 0 within (boundary)
#   S3c +10 lines with DOC_SHAPE_MAX_ADDED=5 (env override) → 1 exceeds (tunable)
#   S4  dead-reference removal (-2 / +0)                    → 0 within (small)
#   S5  new / untracked doc file                            → 1 exceeds (a creation)
#   S6  a code path (not a doc)                             → 1 exceeds (anomaly)
#   S7  clean tracked doc (no diff)                         → 0 within (vacuous)
#   S8  MIXED multi-path, ONE file exceeds                  → 1 exceeds, offender named
#   S9  usage (check with no paths)                         → 2
#   S10 not a git repo                                      → 3
#
# No -e: run every test and report, even after a failure.
set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$HERE/../doc-shape.sh"
ERRFILE="$(mktemp)"
PASS=0
FAIL=0

ok() { printf '    \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
ko() { printf '    \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Fresh throwaway repo: a few tracked docs + one code file, committed.
new_repo() {
  local d
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t
  git -C "$d" config user.name tester
  mkdir -p "$d/docs" "$d/src"
  printf 'run: foo\nold line A\nold line B\n' >"$d/README.md"
  printf 'usage baseline\n' >"$d/USAGE.md"
  printf 'guide baseline\n' >"$d/docs/guide.md"
  printf 'print("hi")\n' >"$d/src/app.py"
  git -C "$d" add -A
  git -C "$d" commit -qm baseline
  printf '%s' "$d"
}

# Append N numbered plain lines (no heading) to a file.
append_lines() {
  local f="$1" n="$2" i
  for ((i = 1; i <= n; i++)); do printf 'extra line %s\n' "$i" >>"$f"; done
}

# Remove exactly N lines from the END of a committed file (pure removal, 0
# added lines, no heading) — for the REMOVED-envelope tests (S11-S13).
truncate_last_n() {
  local f="$1" n="$2" total keep
  total=$(wc -l <"$f")
  keep=$((total - n))
  head -n "$keep" "$f" >"$f.tmp" && mv "$f.tmp" "$f"
}

# run [ENV=val] <repo> <args...> → sets RC (exit), OUT (stdout), ERR (stderr).
# stdout MUST stay empty: the exit code carries the verdict, reasons go to stderr.
run() {
  local r="$1"; shift
  OUT="$( (cd "$r" && "$HELPER" "$@") 2>"$ERRFILE" )"; RC=$?
  ERR="$(cat "$ERRFILE")"
}

echo "S1 — factual one-liner (1 add / 1 del, no heading) → within (0)"
R="$(new_repo)"
printf 'run: bar\nold line A\nold line B\n' >"$R/README.md"   # change one line
run "$R" check "README.md"
printf '    rc=%s  out=[%s]\n' "$RC" "$OUT"
if [ "$RC" -eq 0 ]; then ok "factual tweak → within (0)"; else ko "expected 0, got $RC"; fi
if [ -z "$OUT" ]; then ok "stdout empty"; else ko "stdout leaked: [$OUT]"; fi
rm -rf "$R"

echo "S2 — adds a heading → exceeds (1, structural)"
R="$(new_repo)"
printf '\n## New Feature\n\nDescribes the new feature.\n' >>"$R/README.md"
run "$R" check "README.md"
printf '    rc=%s  err=%s\n' "$RC" "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 1 ]; then ok "heading → exceeds (1)"; else ko "expected 1, got $RC"; fi
if printf '%s' "$ERR" | grep -qi 'heading'; then ok "stderr names the heading reason"; else ko "reason not named"; fi
rm -rf "$R"

echo "S3 — +30 plain lines, no heading → exceeds (1, size)"
R="$(new_repo)"
append_lines "$R/README.md" 30
run "$R" check "README.md"
printf '    rc=%s  err=%s\n' "$RC" "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 1 ]; then ok "30 added → exceeds (1)"; else ko "expected 1, got $RC"; fi
if printf '%s' "$ERR" | grep -qi 'added'; then ok "stderr names the size reason"; else ko "reason not named"; fi
rm -rf "$R"

echo "S3b — +20 plain lines (== threshold) → within (0, boundary)"
R="$(new_repo)"
append_lines "$R/README.md" 20
run "$R" check "README.md"
printf '    rc=%s\n' "$RC"
if [ "$RC" -eq 0 ]; then ok "20 added (== MAX) → within (0)"; else ko "expected 0, got $RC"; fi
rm -rf "$R"

echo "S3c — +10 lines with DOC_SHAPE_MAX_ADDED=5 → exceeds (1, env-tunable)"
R="$(new_repo)"
append_lines "$R/README.md" 10
OUT="$( (cd "$R" && DOC_SHAPE_MAX_ADDED=5 "$HELPER" check "README.md") 2>"$ERRFILE" )"; RC=$?
printf '    rc=%s\n' "$RC"
if [ "$RC" -eq 1 ]; then ok "override MAX_ADDED=5, 10 added → exceeds (1)"; else ko "expected 1, got $RC"; fi
rm -rf "$R"

echo "S4 — dead-reference removal (-2 / +0) → within (0)"
R="$(new_repo)"
printf 'run: foo\n' >"$R/README.md"   # drop the two 'old line' references
run "$R" check "README.md"
printf '    rc=%s\n' "$RC"
if [ "$RC" -eq 0 ]; then ok "small removal → within (0)"; else ko "expected 0, got $RC"; fi
rm -rf "$R"

echo "S5 — new / untracked doc file → exceeds (1, a creation)"
R="$(new_repo)"
printf 'brand new doc\n' >"$R/NEW.md"   # untracked
run "$R" check "NEW.md"
printf '    rc=%s  err=%s\n' "$RC" "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 1 ]; then ok "untracked doc → exceeds (1)"; else ko "expected 1, got $RC"; fi
if printf '%s' "$ERR" | grep -Eqi 'untracked|new'; then ok "stderr flags the creation"; else ko "reason not named"; fi
rm -rf "$R"

echo "S6 — a code path (not a doc) → exceeds (1, anomaly)"
R="$(new_repo)"
printf 'print("hi")\nprint("bye")\n' >"$R/src/app.py"
run "$R" check "src/app.py"
printf '    rc=%s  err=%s\n' "$RC" "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 1 ]; then ok "non-doc path → exceeds (1)"; else ko "expected 1, got $RC"; fi
if printf '%s' "$ERR" | grep -qi 'doc'; then ok "stderr flags the non-doc"; else ko "reason not named"; fi
rm -rf "$R"

echo "S7 — clean tracked doc (no diff) → within (0, vacuous)"
R="$(new_repo)"
run "$R" check "docs/guide.md"   # unmodified
printf '    rc=%s\n' "$RC"
if [ "$RC" -eq 0 ]; then ok "clean path → within (0)"; else ko "expected 0, got $RC"; fi
rm -rf "$R"

echo "S8 — MIXED multi-path, ONE exceeds → exceeds (1), offender named"
R="$(new_repo)"
printf 'extra\n' >>"$R/README.md"        # small, within
append_lines "$R/USAGE.md" 30            # big, exceeds
run "$R" check "README.md" "USAGE.md"
printf '    rc=%s  err=%s\n' "$RC" "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 1 ]; then ok "any path exceeds → whole set exceeds (1)"; else ko "expected 1, got $RC"; fi
if printf '%s' "$ERR" | grep -q 'USAGE.md'; then ok "stderr names the offender (USAGE.md)"; else ko "offender not named"; fi
if printf '%s' "$ERR" | grep -q 'README.md'; then ko "README.md wrongly flagged"; else ok "within-envelope file NOT flagged"; fi
rm -rf "$R"

echo "S9 — usage (check with no paths) → 2"
R="$(new_repo)"
run "$R" check
printf '    rc=%s\n' "$RC"
if [ "$RC" -eq 2 ]; then ok "no paths → usage (2)"; else ko "expected 2, got $RC"; fi
rm -rf "$R"

echo "S10 — not a git repo → 3"
D="$(mktemp -d)"   # plain dir, no git init
run "$D" check "README.md"
printf '    rc=%s\n' "$RC"
if [ "$RC" -eq 3 ]; then ok "not-a-repo → 3"; else ko "expected 3, got $RC"; fi
rm -rf "$D"

echo "S11 — remove exactly 20 lines (== threshold, pure removal) → within (0, boundary)"
R="$(new_repo)"
: >"$R/README.md"; append_lines "$R/README.md" 40
git -C "$R" add README.md; git -C "$R" commit -qm "baseline 40 lines"
truncate_last_n "$R/README.md" 20
run "$R" check "README.md"
printf '    rc=%s\n' "$RC"
if [ "$RC" -eq 0 ]; then ok "removed 20 (== MAX) → within (0)"; else ko "expected 0, got $RC"; fi
rm -rf "$R"

echo "S12 — remove 30 lines (pure removal) → exceeds (1, size)"
R="$(new_repo)"
: >"$R/README.md"; append_lines "$R/README.md" 40
git -C "$R" add README.md; git -C "$R" commit -qm "baseline 40 lines"
truncate_last_n "$R/README.md" 30
run "$R" check "README.md"
printf '    rc=%s  err=%s\n' "$RC" "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 1 ]; then ok "removed 30 → exceeds (1)"; else ko "expected 1, got $RC"; fi
if printf '%s' "$ERR" | grep -q 'README.md'; then ok "stderr names the offending path"; else ko "offender not named"; fi
rm -rf "$R"

echo "S13 — DOC_SHAPE_MAX_REMOVED=5 + 6-line removal → exceeds (1, env-tunable)"
R="$(new_repo)"
: >"$R/README.md"; append_lines "$R/README.md" 40
git -C "$R" add README.md; git -C "$R" commit -qm "baseline 40 lines"
truncate_last_n "$R/README.md" 6
OUT="$( (cd "$R" && DOC_SHAPE_MAX_REMOVED=5 "$HELPER" check "README.md") 2>"$ERRFILE" )"; RC=$?
printf '    rc=%s\n' "$RC"
if [ "$RC" -eq 1 ]; then ok "override MAX_REMOVED=5, 6 removed → exceeds (1)"; else ko "expected 1, got $RC"; fi
rm -rf "$R"

rm -f "$ERRFILE"
echo ""
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
