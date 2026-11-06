#!/usr/bin/env bash
# lib/tests/claude-stub.test.sh
# Regression for BLK-043 residuals: claude_stub_install must fail closed
# (never leave the real claude CLI first on PATH) and survive a relative dir.
# shellcheck disable=SC1090,SC2329  # HELPER override; chmod shadow is called by the helper
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="${CLAUDE_STUB_LIB:-$ROOT/lib/tests/claude-stub.sh}"
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# (a) fail-closed: chmod is a no-op so the stub stays 0644, command -v
# skips it and finds the fake claude (writes a sentinel) further on PATH.
mkdir -p "$WORK/a/work" "$WORK/a/fake"
printf '#!/bin/sh\ntouch "%s"\n' "$WORK/a/sentinel" >"$WORK/a/fake/claude"
chmod +x "$WORK/a/fake/claude"
err=$( ( chmod() { :; }; PATH="$WORK/a/fake:$PATH"
  . "$HELPER"; claude_stub_install "$WORK/a/work" ) 2>&1 >/dev/null )
rc=$?
check Ta-rc "$rc" 1
case "$err" in *"claude stub not first on PATH"*) m=yes ;; *) m=no ;; esac
check Ta-message "$m" yes
check Ta-sentinel-absent "$([ -e "$WORK/a/sentinel" ] && echo yes || echo no)" no

# (b) relative dir: the stub still resolves after a cd elsewhere.
mkdir -p "$WORK/b/rel"
got=$( cd "$WORK/b" && . "$HELPER" && claude_stub_install rel \
  && cd / && command -v claude )
check Tb-relative-resolves "$got" "$WORK/b/rel/stub/claude"

# (c) happy path
mkdir -p "$WORK/c"
out=$( . "$HELPER"; claude_stub_install "$WORK/c" && claude_stub_calls )
check Tc-happy "$out" 0

printf 'claude-stub: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
