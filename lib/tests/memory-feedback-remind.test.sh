#!/usr/bin/env bash
# lib/tests/memory-feedback-remind.test.sh — the phase 4d banner line:
# shown when /memory-feedback never ran, or ran 5+ days ago and the store
# changed since; silent once all three gate marks are recorded, with recall
# off, or on any error.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/memory-feedback-remind.sh"
WORK="$(mktemp -d)" || exit 1
trap 'chmod -R u+rw "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# home <name>: a fixture HOME with a store file (unless "nostore")
home() {
  mkdir -p "$WORK/$1/.claude/plugins/store" \
    "$WORK/$1/.claude/memory-feedback"
  [ "$1" = nostore ] ||
    : > "$WORK/$1/.claude/plugins/store/memory_skills-dir-a.json"
  echo "$WORK/$1"
}
OPEN='{"lastRun":1,"closed":false}'
# old <home> <content>: a state.json last written on 2026-01-01
old() {
  printf '%s' "$2" > "$1/.claude/memory-feedback/state.json"
  touch -t 202601010000 "$1/.claude/memory-feedback/state.json"
}
run() { HOME="$1" bash "$LIB" 2>&1; echo "rc=$?"; }
DUE='memory feedback: last run 5+ d ago, '
DUE+='transcripts expire at 7 → /memory-feedback'

check MR1-no-store "$(run "$(home nostore)")" "rc=0"
NEVER='memory feedback: never run → /memory-feedback'
check MR2-never "$(run "$(home never)")" "$NEVER
rc=0"
h=$(home due); old "$h" "$OPEN"
check MR3-due "$(run "$h")" "$DUE
rc=0"
h=$(home quiet); old "$h" "$OPEN"
touch -t 202512010000 \
  "$h/.claude/plugins/store/memory_skills-dir-a.json"
check MR4-store-unchanged "$(run "$h")" "rc=0"
h=$(home fresh)
printf '%s' "$OPEN" > "$h/.claude/memory-feedback/state.json"
touch -t 209901010000 \
  "$h/.claude/plugins/store/memory_skills-dir-a.json"
check MR5-ran-today "$(run "$h")" "rc=0"
h=$(home closed); old "$h" '{"lastRun":1,"closed":true}'
check MR6-closed "$(run "$h")" "rc=0"
h=$(home off); old "$h" "$OPEN"
printf '{"recall": false}' > "$h/.claude/memory.json"
check MR7-recall-off "$(run "$h")" "rc=0"
h=$(home locked); old "$h" "$OPEN"
chmod 000 "$h/.claude/memory-feedback/state.json"
check MR8-unreadable "$(run "$h")" "rc=0"

printf 'memory-feedback-remind: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
