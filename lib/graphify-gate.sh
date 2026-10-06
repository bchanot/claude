#!/usr/bin/env bash
# graphify-gate.sh — deterministic "propose graphify" signal (BDR-097).
#
# Rule (user, 2026-09-24): graphify only from 200 tracked code files. Below,
# grep + read is cheaper than a graph. The signal INFORMS, the user DECIDES:
# nothing here builds, installs or updates a graph.
#
# Sourced (functions) or executed: `graphify-gate.sh [dir]` prints one short
# line (banner-sized) and exits 0 when <dir>'s repo passes the threshold and has
# no graphify-out/graph.json; silent, rc 1 otherwise. GRAPHIFY_MIN_CODE_FILES
# overrides the threshold (tests).

GRAPHIFY_MIN_CODE_FILES="${GRAPHIFY_MIN_CODE_FILES:-200}"
# Extensions graphify extracts by AST (tree-sitter): the proxy for "code file".
GRAPHIFY_CODE_EXT='py|js|mjs|cjs|ts|tsx|jsx|vue|svelte|astro|php|go|rs|java|kt|c|h|cpp|hpp|cc|cs|rb|swift|scala|sh|bash|lua|sql'
# Vendored trees sometimes committed; never the project's own code.
GRAPHIFY_VENDOR_DIRS='vendor|node_modules|third_party|dist|build'

# graphify_code_file_count [dir] → tracked code files, vendored trees excluded.
# Tracked only (git ls-files): gitignored deps and build output never count.
graphify_code_file_count() {
  git -C "${1:-.}" ls-files 2>/dev/null \
    | grep -v -E "(^|/)($GRAPHIFY_VENDOR_DIRS)/" \
    | grep -E -c "\.($GRAPHIFY_CODE_EXT)$"
}

# graphify_gate [dir] → "graphify? N code files ≥ T, no graph" + rc 0 when the
# repo passes the threshold without a graph; silent rc 1 otherwise.
graphify_gate() {
  local root n
  root=$(git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ -f "$root/graphify-out/graph.json" ] && return 1     # graph exists — nothing to propose
  n=$(graphify_code_file_count "$root")
  [ "$n" -ge "$GRAPHIFY_MIN_CODE_FILES" ] || return 1
  printf 'graphify? %s code files ≥ %s, no graph\n' "$n" "$GRAPHIFY_MIN_CODE_FILES"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  set -uo pipefail
  graphify_gate "${1:-.}"
fi
