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
#   0 + stdout  Rewrite found, no rtk deny/ask rule matched → rewrite. NO
#               permissionDecision is emitted (auto-allow dropped 2026-07-02:
#               it made rtk's registry a parallel permission authority that
#               bypassed settings.json deny/ask). The REWRITTEN command goes
#               through native evaluation; explicit `rtk <tool>` allow rules
#               in settings.json keep read-only forms frictionless.
#   1           No RTK equivalent → command continues unchanged into the
#               redaction check below (still may be rewritten there)
#   2           Deny rule matched → pass through (Claude Code native deny handles it)
#   3 + stdout  Ask rule matched → rewrite but let Claude Code prompt the user
#
# Independent of the above: any command whose FINAL form is a single-pipeline
# `printenv`/`env` dump gets a redaction pipe appended (job7 — see below).
# This is a security post-process, not a token-savings rewrite, so it lives
# here rather than in the Rust registry.

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
    # Rewrite found. If identical to the input, RTK had nothing to add —
    # keep going so the redaction check below still runs on it.
    [ "$CMD" = "$REWRITTEN" ] && REWRITTEN="$CMD"
    ;;
  1)
    # No RTK equivalent — keep the original command so the redaction
    # check below still runs on it.
    REWRITTEN="$CMD"
    ;;
  2)
    # Deny rule matched (rtk's own registry — not necessarily backed by a
    # matching settings.json deny rule, so the original command can still
    # reach native evaluation and run: e.g. bare `env`/`printenv` hits this
    # exit code with no settings.json rule behind it). Keep the original
    # command so the redaction check below still runs on it.
    REWRITTEN="$CMD"
    ;;
  3)
    # Ask rule matched — rewrite the command but do NOT auto-allow so that
    # Claude Code prompts the user for confirmation.
    ;;
  *)
    exit 0
    ;;
esac

# Security: redact raw environment dumps before they can reach stdout/the
# transcript (job7 — a bare `printenv`/`env` dump was the GITEA leak vector).
# `env VAR=x cmd` (env launching a subprocess with a var set) is legitimate
# and left intact. Scope: single-pipeline commands only — a command
# containing `;`, `&`, or `||` bails untouched, same "lose the feature
# rather than emit something wrong" rule as the RTK_ON_PATH substitution
# below: appending the redaction pipe at the end would silently attach to
# the WRONG segment of a compound command.
if ! printf '%s' "$REWRITTEN" | grep -Eq '[;&]' \
   && ! printf '%s' "$REWRITTEN" | grep -qF '||'; then
  if printf '%s' "$REWRITTEN" | grep -Eq '^[[:space:]]*(printenv|env)([[:space:]]|$)' \
     && ! printf '%s' "$REWRITTEN" | grep -Eq '^[[:space:]]*env([[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)+[[:space:]]+[^|[:space:]]'; then
    REWRITTEN="${REWRITTEN} | sed -E 's/^([A-Za-z_]*(TOKEN|API_KEY|SECRET|PASSWORD|PASSWD)[A-Za-z_]*)=.*/\1=REDACTED/'"
  fi
fi

[ "$CMD" = "$REWRITTEN" ] && exit 0

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

# Rewrite WITHOUT a permissionDecision (exit 0 and exit 3 alike): the
# rewritten command goes through Claude Code's native allow/deny/ask
# evaluation. Permission control lives in settings.json, not in rtk.
jq -n \
  --argjson updated "$UPDATED_INPUT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "updatedInput": $updated
    }
  }'
