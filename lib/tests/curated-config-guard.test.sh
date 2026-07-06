#!/usr/bin/env bash
# lib/tests/curated-config-guard.test.sh — SPEC-03 (J4-03).
#
# Drives install-plugins.sh's restore_curated_configs() in a sandbox. The SUT
# is extracted from the REAL script AT TEST RUNTIME (awk range, verified
# single-occurrence + column-0 closing brace) so drift in install-plugins.sh
# propagates into this test instead of testing a stale copy. GUARDED_CONFIGS,
# CFG_SNAPSHOT, REPO and an info() stub are defined here — the array literal
# at install-plugins.sh:41 is outside the extracted range.
set -u
INSTALL_SH="$(cd "$(dirname "$0")/../.." && pwd)/install-plugins.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

SUT="$(mktemp)"
awk '/^restore_curated_configs\(\) \{/,/^\}/' "$INSTALL_SH" > "$SUT"

REPO="$(mktemp -d)"
CFG_SNAPSHOT="$(mktemp -d)"
EXPECT="$(mktemp -d)"          # our own reference copy — independent of CFG_SNAPSHOT (SUT rm -rf's it)
GUARDED_CONFIGS=("CLAUDE.md" ".claude/settings.json" "settings.json")
info() { :; }                 # stub — extracted body calls info(), irrelevant to the assertions

mkdir -p "$REPO/.claude"
printf 'CLAUDE original\n' > "$REPO/CLAUDE.md"
printf '{"a":1}\n'         > "$REPO/.claude/settings.json"
printf '{"b":2}\n'         > "$REPO/settings.json"

for f in "${GUARDED_CONFIGS[@]}"; do
  mkdir -p "$CFG_SNAPSHOT/$(dirname "$f")" "$EXPECT/$(dirname "$f")"
  cp "$REPO/$f" "$CFG_SNAPSHOT/$f"
  cp "$REPO/$f" "$EXPECT/$f"
done

# simulate installer drift: mutate ONE guarded file, leave the other two alone
printf 'CLAUDE CLOBBERED BY INSTALLER\n' > "$REPO/CLAUDE.md"

# shellcheck source=/dev/null
source "$SUT"
restore_curated_configs

cmp -s "$REPO/CLAUDE.md" "$EXPECT/CLAUDE.md"
check T1-mutated-file-restored "$?" 0
cmp -s "$REPO/.claude/settings.json" "$EXPECT/.claude/settings.json"
check T2-untouched-local-settings-unchanged "$?" 0
cmp -s "$REPO/settings.json" "$EXPECT/settings.json"
check T3-untouched-settings-unchanged "$?" 0
[ ! -d "$CFG_SNAPSHOT" ]
check T4-snapshot-dir-removed "$?" 0

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
