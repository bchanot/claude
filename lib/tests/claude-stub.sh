#!/usr/bin/env bash
# lib/tests/claude-stub.sh — sourced by the hook-running suites (BLK-043).
# A hook run that reaches the real claude CLI starts a session that re-runs
# the hook: fork bomb. claude_stub_install puts a logging stub first on PATH
# and exits the calling suite unless the stub is really the one resolved.
# bash 3.2 safe.

# stub_first_or_die <cmd> <expected-path>: exit 1 unless <cmd> resolves there
stub_first_or_die() {
  if [ "$(command -v "$1")" != "$2" ]; then
    echo "$1 stub not first on PATH" >&2
    exit 1
  fi
}

# claude_stub_install <work-dir>: stub in <work-dir>/stub, log in
# <work-dir>/claude.log (path read by the stub from CLAUDE_STUB_LOG), PATH,
# CLAUDE_STUB_LOG and GIT_CEILING_DIRECTORIES exported
claude_stub_install() {
  local dir
  if [ -z "${1:-}" ] || [ ! -d "$1" ]; then
    echo "claude_stub_install: work dir missing" >&2
    exit 1
  fi
  dir=$(cd -P "$1" && pwd) || exit 1
  CLAUDE_LOG="$dir/claude.log"
  : >"$CLAUDE_LOG" || exit 1
  mkdir -p "$dir/stub" || exit 1
  export CLAUDE_STUB_LOG="$CLAUDE_LOG"
  cat >"$dir/stub/claude" <<'EOF' || exit 1
#!/bin/sh
echo "$*" >>"$CLAUDE_STUB_LOG"
EOF
  chmod +x "$dir/stub/claude" || exit 1
  export PATH="$dir/stub:$PATH"
  stub_first_or_die claude "$dir/stub/claude"
  (cd / && claude probe)
  if [ "$(claude_stub_calls)" != 1 ]; then
    echo "claude stub positive control failed" >&2
    exit 1
  fi
  : >"$CLAUDE_LOG" || exit 1
  export GIT_CEILING_DIRECTORIES="$dir"
}

# claude_stub_calls: number of claude calls logged since the install
claude_stub_calls() { wc -l <"$CLAUDE_LOG" | tr -d ' '; }
