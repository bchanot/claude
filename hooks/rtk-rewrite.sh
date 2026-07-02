#!/usr/bin/env bash
# rtk-hook-version: 3
# RTK Claude Code hook — rewrites commands to use rtk for token savings.
# Requires: rtk >= 0.23.0, jq
#
# This is a thin delegating hook: all rewrite logic lives in `rtk rewrite`,
# which is the single source of truth (src/discover/registry.rs).
# To add or change rewrite rules, edit the Rust registry — not this file.
#
# INTEGRITY PIN: the rtk binary verifies this file against
# hooks/.rtk-hook.sha256 at execution time and refuses to run on mismatch.
# ANY edit here must re-pin:  (cd hooks && sha256sum rtk-rewrite.sh > .rtk-hook.sha256)
#
# Exit code protocol for `rtk rewrite`:
#   0 + stdout  Rewrite found, no deny/ask rule matched → auto-allow
#   1           No RTK equivalent → pass through unchanged
#   2           Deny rule matched → pass through (Claude Code native deny handles it)
#   3 + stdout  Ask rule matched → rewrite but let Claude Code prompt the user

if ! command -v jq &>/dev/null; then
  echo "[rtk] WARNING: jq is not installed. Hook cannot rewrite commands. Install jq: https://jqlang.github.io/jq/download/" >&2
  exit 0
fi

# PATH heal: hook/tool-shell PATH may lack the cargo bin dir (hand-managed
# ~/.bashrc can lose the cargo line — LRN-036 class). Resolve the ABSOLUTE
# binary path: the rewritten command executes in the tool shell, whose PATH
# the hook cannot fix — a bare `rtk …` rewrite would exit 127 there.
RTK_BIN="$(command -v rtk 2>/dev/null || true)"
RTK_ON_PATH=1
if [ -z "$RTK_BIN" ]; then
  RTK_ON_PATH=0
  for _d in "$HOME/.cargo/bin" "$HOME/.local/bin"; do
    if [ -x "$_d/rtk" ]; then RTK_BIN="$_d/rtk"; break; fi
  done
fi

if [ -z "$RTK_BIN" ]; then
  echo "[rtk] WARNING: rtk is not installed or not in PATH. Hook cannot rewrite commands. Install: https://github.com/rtk-ai/rtk#installation" >&2
  exit 0
fi

# Version guard: rtk rewrite was added in 0.23.0.
# Older binaries: warn once and exit cleanly (no silent failure).
RTK_VERSION=$("$RTK_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -n "$RTK_VERSION" ]; then
  MAJOR=$(echo "$RTK_VERSION" | cut -d. -f1)
  MINOR=$(echo "$RTK_VERSION" | cut -d. -f2)
  # Require >= 0.23.0
  if [ "$MAJOR" -eq 0 ] && [ "$MINOR" -lt 23 ]; then
    echo "[rtk] WARNING: rtk $RTK_VERSION is too old (need >= 0.23.0). Upgrade: cargo install rtk" >&2
    exit 0
  fi
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Delegate all rewrite + permission logic to the Rust binary.
REWRITTEN=$("$RTK_BIN" rewrite "$CMD" 2>/dev/null)
EXIT_CODE=$?

case $EXIT_CODE in
  0)
    # Rewrite found, no permission rules matched — safe to auto-allow.
    # If the output is identical, the command was already using RTK.
    [ "$CMD" = "$REWRITTEN" ] && exit 0
    ;;
  1)
    # No RTK equivalent — pass through unchanged.
    exit 0
    ;;
  2)
    # Deny rule matched — let Claude Code's native deny rule handle it.
    exit 0
    ;;
  3)
    # Ask rule matched — rewrite the command but do NOT auto-allow so that
    # Claude Code prompts the user for confirmation.
    ;;
  *)
    exit 0
    ;;
esac

# When rtk is NOT on PATH, a bare `rtk …` rewrite exits 127 in the tool
# shell (whose PATH the hook cannot fix). Substitute the absolute path at
# the string head — the only position safe to rewrite. Compound commands
# (`a && b`) can carry further bare rtk segments we canNOT substitute
# safely (quoted text, e.g. commit messages, may contain the same
# pattern): if any remain at a command position, pass through unrewritten
# — lose the compression, never emit a command that 127s.
if [ "$RTK_ON_PATH" -eq 0 ]; then
  case "$REWRITTEN" in
    rtk\ *) REWRITTEN="$RTK_BIN ${REWRITTEN#rtk }" ;;
  esac
  if printf '%s' "$REWRITTEN" | grep -Eq '(^|[;&|][[:space:]]*)rtk[[:space:]]'; then
    exit 0
  fi
fi

ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')

if [ "$EXIT_CODE" -eq 3 ]; then
  # Ask: rewrite the command, omit permissionDecision so Claude Code prompts.
  jq -n \
    --argjson updated "$UPDATED_INPUT" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "updatedInput": $updated
      }
    }'
else
  # Allow: rewrite the command and auto-allow.
  jq -n \
    --argjson updated "$UPDATED_INPUT" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "RTK auto-rewrite",
        "updatedInput": $updated
      }
    }'
fi
