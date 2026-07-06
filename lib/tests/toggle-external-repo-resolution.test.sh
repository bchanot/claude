#!/usr/bin/env bash
# lib/tests/toggle-external-repo-resolution.test.sh
#
# Regression test for J4-20 (BLK-006 class): toggle-external.sh:34 resolved
# REPO with a LOGICAL `cd` (no -P). Direct invocation via a symlinked path —
# exactly the real ~/.claude/lib -> <repo>/lib layout — resolves REPO to the
# SYMLINK's logical parent instead of the physical repo root, so every path
# derived from it (SKILLS_DIR, DISABLED_DIR) points at the wrong tree.
set -u
HELPER_SRC="$(cd "$(dirname "$0")/../.." && pwd)/lib/toggle-external.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

SANDBOX="$(mktemp -d)"
mkdir -p "$SANDBOX/repo/lib" "$SANDBOX/repo/skills-external/emil-design-eng" \
  "$SANDBOX/repo/skills" "$SANDBOX/home/.claude"
cp "$HELPER_SRC" "$SANDBOX/repo/lib/toggle-external.sh"
# mark emil-design-eng ENABLED in the real (physical) repo tree
ln -s "$SANDBOX/repo/skills-external/emil-design-eng" "$SANDBOX/repo/skills/emil-design-eng"
# replicate the real ~/.claude/lib -> <repo>/lib symlink
ln -s "$SANDBOX/repo/lib" "$SANDBOX/home/.claude/lib"

out="$(bash "$SANDBOX/home/.claude/lib/toggle-external.sh" status emil-design-eng)"
check T1-repo-resolves-through-symlink "$out" enabled

rm -rf "$SANDBOX"
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
