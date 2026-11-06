#!/usr/bin/env bash
# lib/tests/detect-plan.test.sh
# Regression for BLK-043: detect_plan must never call the claude CLI
# (a hook-launched claude re-enters session-start.sh: fork bomb).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${DETECT_PLUGINS_LIB:-$ROOT/lib/detect-plugins.sh}"
HOOK="$ROOT/hooks/session-start.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
calls() { wc -l <"$CLAUDE_LOG" | tr -d ' '; }

# Stub claude: logs every call, never starts a session.
CLAUDE_LOG="$WORK/claude.log"; : >"$CLAUDE_LOG"
mkdir -p "$WORK/stub"
printf '#!/bin/sh\necho "$*" >>"%s"\n' "$CLAUDE_LOG" >"$WORK/stub/claude"
chmod +x "$WORK/stub/claude"
export PATH="$WORK/stub:$PATH"

# Positive control: the stub is reached through PATH.
claude probe
check T0-stub-reached "$(calls)" 1
: >"$CLAUDE_LOG"

# detect_plan, no .claude.json: pro, no claude call.
mkdir -p "$WORK/empty"
out=$(HOME="$WORK/empty" bash -c "source '$LIB'; detect_plan")
check T1-no-json-plan "$out" pro
check T1-no-json-calls "$(calls)" 0

# detect_plan, max markers: max, no claude call.
mkdir -p "$WORK/maxhome"
printf '{"tengu_cobalt_compass": true, "tengu_harbor": true}\n' \
  >"$WORK/maxhome/.claude.json"
: >"$CLAUDE_LOG"
out=$(HOME="$WORK/maxhome" bash -c "source '$LIB'; detect_plan")
check T2-max-plan "$out" max
check T2-max-calls "$(calls)" 0

# Hook HOME: real ~/.claude entries + max fixture (no fallback needed).
mkdir -p "$WORK/hookhome/.claude" "$WORK/proj"
for e in "$HOME"/.claude/*; do
  ln -s "$e" "$WORK/hookhome/.claude/$(basename "$e")"
done
cp "$WORK/maxhome/.claude.json" "$WORK/hookhome/.claude.json"

# Guard: hook exits 0 silently when already running.
out=$(cd "$WORK/proj" && HOME="$WORK/hookhome" SESSION_START_RUNNING=1 \
  SESSION_START_OFFLINE=1 bash "$HOOK" </dev/null 2>&1); rc=$?
check T3-guard-rc "$rc" 0
check T3-guard-silent "$out" ""

# Export: a child of the hook sees SESSION_START_RUNNING=1.
: >"$CLAUDE_LOG"
real_git=$(command -v git)
GIT_LOG="$WORK/git.log"; : >"$GIT_LOG"
{
  printf '#!/bin/sh\nGIT_LOG="%s"\nREAL_GIT="%s"\n' "$GIT_LOG" "$real_git"
  cat <<'EOF'
echo "${SESSION_START_RUNNING:-unset}" >>"$GIT_LOG"
exec "$REAL_GIT" "$@"
EOF
} >"$WORK/stub/git"
chmod +x "$WORK/stub/git"
( cd "$WORK/proj" && env -u SESSION_START_RUNNING HOME="$WORK/hookhome" \
  SESSION_START_OFFLINE=1 bash "$HOOK" </dev/null >/dev/null 2>&1 )
check T4-child-sees-guard "$(head -1 "$GIT_LOG")" 1
check T4-hook-no-claude-calls "$(calls)" 0

printf 'detect-plan: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
