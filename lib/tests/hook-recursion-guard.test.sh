#!/usr/bin/env bash
# lib/tests/hook-recursion-guard.test.sh
# Regression for BLK-043: session-start.sh must guard against re-entry
# and never call the claude CLI (a hook-launched claude re-enters the
# hook: fork bomb).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/session-start.sh"
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# Stub claude: logs every call, never starts a session; fails closed.
# shellcheck source=lib/tests/claude-stub.sh
. "$ROOT/lib/tests/claude-stub.sh" || exit 1
claude_stub_install "$WORK"

# Hook HOME: real ~/.claude entries.
mkdir -p "$WORK/hookhome/.claude" "$WORK/proj"
for e in "$HOME"/.claude/*; do
  ln -s "$e" "$WORK/hookhome/.claude/$(basename "$e")"
done

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
check T4-hook-no-claude-calls "$(claude_stub_calls)" 0

printf 'hook-recursion-guard: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
