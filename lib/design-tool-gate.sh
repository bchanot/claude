#!/usr/bin/env bash
# ============================================================
# lib/design-tool-gate.sh — deterministic design-toolchain state check.
#
# Answers one question for lib/design-gate.md § DECISION: "is the design
# toolchain active enough to proceed?" Source of truth = `profile.sh
# current --plain` (packs + managed plugins of THIS project and
# conversation). Required: pack-design, pack-gstack-design and the
# ui-ux-pro-max plugin, plus the `21st` CLI signed in (gate-only state:
# in / out / unknown, from `21st whoami`).
#
# Exit: 0 ready · 10 incomplete (a pack or plugin off, or no 21st CLI) ·
#       11 ready-but-unverified (21st could not answer) · 12 sign-in
#       required · 2 error (profile.sh failed or gave no pack lines).
# Remedy on 10: source=flag → relaunch `cc <name> web` (a --settings
# conversation is frozen); else `profile.sh set web` (or `enable design`)
# then /reload-plugins. The CLI is a global npm install either way.
# Usage: design-tool-gate.sh        (no argument; env DESIGN_GATE_PROFILE_SH)
# ============================================================
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SH="${DESIGN_GATE_PROFILE_SH:-$REPO/lib/profile.sh}"
NEEDED=(pack-design pack-gstack-design
  "plugin:ui-ux-pro-max@ui-ux-pro-max-skill")

# ---- 21st CLI on PATH + sign-in state (kept from the previous version) ----
# Same sanitized-PATH problem for `21st` (an npm global bin): a PATH repair
# for the 21st CLI only (claude is no longer called here). The npm global
# bin dir is often missing from a hook's PATH. Probe for the binary directly
# and prepend the dir that has it, otherwise a perfectly installed CLI reads
# as "missing" and trips the gate.
ensure_21st_on_path() {
  command -v 21st >/dev/null 2>&1 && return
  local cand
  for cand in \
    "$HOME/.local/bin/21st" \
    /opt/homebrew/bin/21st \
    /usr/local/bin/21st; do
    [ -x "$cand" ] && { PATH="$(dirname "$cand"):$PATH"; return; }
  done
  local m newest matches=()
  for m in "$HOME"/.nvm/versions/node/*/bin/21st; do
    [ -x "$m" ] && matches+=("$m")
  done
  if [ "${#matches[@]}" -gt 0 ]; then
    newest="$(printf '%s\n' "${matches[@]}" | sort -V | tail -1)"
    PATH="$(dirname "$newest"):$PATH"
  fi
}
ensure_21st_on_path

# 21st's sign-in state, three-valued. `whoami` is a local token read (no
# network), rc 0 either way — so rc alone can't tell signed-in from signed-
# out; the FIRST LINE of stdout does. A token env, when already exported by
# the user's shell profile, wins without a CLI call (never requested here:
# tool calls don't share a shell, and a secret doesn't belong in a comment
# or the transcript). A perl `alarm` of 15 s bounds a hung CLI (GNU
# `timeout` is absent from the macOS system PATH); stdin is closed so a
# CLI that reads stdin can't eat the gate's own `read` loop; stderr never
# enters the match (stdout only). Echoes: in | out | unknown:<diagnostic>.
twentyfirst_auth_state() {
  if [ -n "${TWENTYFIRST_TOKEN:-}" ] || [ -n "${API_KEY_21ST:-}" ]; then
    echo in
    return
  fi
  local line rc
  if line="$(perl -e 'alarm shift; exec @ARGV' 15 21st whoami \
             2>/dev/null </dev/null)"; then
    rc=0
  else
    rc=$?
  fi
  line="${line%%$'\n'*}"  # first line, without head(1) in a pipeline
  if [ "$rc" -eq 0 ]; then
    case "$line" in
      "Logged in as "*) echo in;  return ;;
      "Not logged in"*) echo out; return ;;
    esac
  fi
  [ -n "$line" ] || line="no output"
  echo "unknown:whoami: rc=$rc ${line:0:60}"
}

# ---- packs and plugin from profile.sh ---------------------------------------
plain="$(bash "$PROFILE_SH" -C "$PWD" current --plain 2>/dev/null)" \
  || { echo "design-gate: profile.sh current --plain failed" >&2; exit 2; }
grep -q '^pack-design=' <<<"$plain" || {
  echo "design-gate: profile.sh current --plain gave no pack-design line" >&2
  exit 2; }
plain_get() { sed -n "s/^$1=//p" <<<"$plain" | head -1; }
missing=()
for k in "${NEEDED[@]}"; do
  [ "$(plain_get "$k")" = on ] || missing+=("$k")
done
source="$(plain_get source)"; profile="$(plain_get profile)"

# ---- 21st: CLI present, then signed in ---------------------------------------
cli_hint=""; auth=in
if ! command -v 21st >/dev/null 2>&1; then
  cli_hint="    21st needs the CLI: npm i -g @21st-dev/cli   then   21st login"
else
  auth="$(twentyfirst_auth_state)"
fi

# ---- verdict -----------------------------------------------------------------
if [ "${#missing[@]}" -gt 0 ] || [ -n "$cli_hint" ]; then
  echo "design toolchain: INCOMPLETE"
  [ "${#missing[@]}" -gt 0 ] && echo "  off: ${missing[*]}"
  [ -n "$cli_hint" ] && echo "$cli_hint"
  if [ "$source" = flag ]; then
    echo "  → relaunch this conversation with a design profile:" \
         " cc <name> web"
  else
    echo "  → run:  bash ~/.claude/lib/profile.sh set web" \
         "  (or: enable design)"
    echo "    then /reload-plugins"
  fi
  exit 10
fi
case "$auth" in
  out)
    echo "design toolchain: SIGN-IN REQUIRED —" \
         "21st CLI installed, not signed in"
    echo "  ask the user to run in this session:  ! 21st login  (browser flow)"
    echo "  then re-run this gate before any 21st step —" \
         "never skip 21st silently"
    exit 12 ;;
  unknown:*)
    echo "design toolchain: READY BUT UNVERIFIED — 21st could not answer:" \
      "${auth#unknown:}"
    echo "  a CLI runtime/PATH problem (node under nvm?), not a sign-in problem"
    exit 11 ;;
esac
echo "design toolchain: READY —" \
  "packs design + gstack-design + ui-ux-pro-max on ($profile)"
exit 0
