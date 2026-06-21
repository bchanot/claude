#!/usr/bin/env bash
# ============================================================
# lib/design-tool-gate.sh — Deterministic design-toolchain state check.
#
# Answers ONE question for the design gate (design-gate.md §DECISION):
#   "Is the design toolchain active enough to proceed?"
#
# Source of truth = the profile system. The gate never activates a single
# tool atomically; it checks whether a profile's DESIGN-CORE tools (default
# profile: `design`) are active and, if not, points at `/profile <name>`.
#
# Two inputs from the profile, both claude-free:
#   - structure:  profile.sh show <profile> --plain   ->  "<type>\t<name>"
#   - gate scope: the "# GATE-BLOCK:" line(s) in <profile>.profile — the
#                 allowlist of tools the gate trips on. A comment, so
#                 read_profile strips it and --plain never shows it. Absent
#                 -> fall back to every skill/plugin/mcp entry (coarse).
#
# State (active or not) is checked per channel, by type. These per-type
# checks MIRROR profile.sh:skill_status() — change one, sync the other.
#
#   type                       channel                          class
#   gstack|external|personal   skill symlink in skills/         blocking
#   plugin                     `claude plugin list` -> enabled  blocking
#   mcp | cli                  `claude mcp list` / command -v   required-manual
#
# Class:
#   blocking         required + `/profile design` activates it directly.
#   required-manual  required but the profile can't flip it silently (API
#                    key / external install) — the gate STILL trips, names
#                    it, and the remedy is `/profile design` + a manual step.
#                    This is where magic lands: required, never silent.
# Both classes trip the gate. Tools NOT on the GATE-BLOCK allowlist are
# ignored entirely (browser/plan/shotgun tooling, graphify).
#
# disabledMcpServers is NEVER read — unreliable for bi-modal servers
# (magic/context7 can appear there yet be active via another channel).
#
# Exit: 0 = ready · 11 = ready-but-unverified (proceed, say so) · 10 = incomplete (trips) · 2 = error.
# Usage: design-tool-gate.sh [profile]        (default profile: design)
# ============================================================
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SH="$REPO/lib/profile.sh"
PROFILES_DIR="$REPO/lib/profiles"
SKILLS_DIR="$REPO/skills"
PROFILE="${1:-design}"
PROFILE_FILE="$PROFILES_DIR/$PROFILE.profile"

[ -x "$PROFILE_SH" ]  || { echo "design-gate: profile.sh not executable at $PROFILE_SH" >&2; exit 2; }
[ -f "$PROFILE_FILE" ] || { echo "design-gate: profile '$PROFILE' not found" >&2; exit 2; }

# Ensure the claude CLI + its node runtime are reachable even when a skill/hook
# shells this script out with a sanitized PATH. The interactive alias
# claude->dtach_claude never reaches a non-interactive subshell; the real binary
# AND its node bin dir are what matter (claude's shebang needs node, same dir).
# If `command -v claude` already resolves, do nothing; else probe known install
# dirs and prepend. nvm keeps old node versions after an upgrade, so pick the
# newest that actually ships claude (sort -V), not the first glob match.
ensure_claude_on_path() {
  command -v claude >/dev/null 2>&1 && return
  local cand
  for cand in \
    "$HOME/.claude/local/claude" \
    "$HOME/.local/bin/claude" \
    /usr/local/bin/claude; do
    [ -x "$cand" ] && { PATH="$(dirname "$cand"):$PATH"; return; }
  done
  local m newest matches=()
  for m in "$HOME"/.nvm/versions/node/*/bin/claude; do
    [ -x "$m" ] && matches+=("$m")
  done
  if [ "${#matches[@]}" -gt 0 ]; then
    newest="$(printf '%s\n' "${matches[@]}" | sort -V | tail -1)"
    PATH="$(dirname "$newest"):$PATH"
  fi
}
ensure_claude_on_path

# Gate scope: the "# GATE-BLOCK:" allowlist (one or more lines, concatenated).
# Empty => fall back to "every gate-relevant entry is in scope" (coarse).
core_set="$(grep '^# GATE-BLOCK:' "$PROFILE_FILE" 2>/dev/null \
            | sed 's/^# GATE-BLOCK:[[:space:]]*//' | tr '\n' ' ' || true)"

# Membership in the allowlist. Empty allowlist = everything in scope.
in_scope() {
  [ -z "$core_set" ] && return 0
  case " $core_set " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# State of one tool, by type. Mirrors profile.sh:skill_status() — keep in sync.
# Echoes: active | inactive | unknown  (unknown = can't verify, claude absent)
tool_active() {
  local name="$1" type="$2"
  case "$type" in
    gstack|external|personal)
      if [ -e "$SKILLS_DIR/$name" ]; then echo active; else echo inactive; fi
      ;;
    plugin)
      if ! command -v claude >/dev/null 2>&1; then echo unknown; return; fi
      if claude plugin list 2>/dev/null \
           | awk -v p="^[[:space:]]*❯ ${name}@" '$0 ~ p {f=1; next} f && /Status:/ {print; exit}' \
           | grep -q "✔ enabled"
      then echo active; else echo inactive; fi
      ;;
    mcp)
      if ! command -v claude >/dev/null 2>&1; then echo unknown; return; fi
      if claude mcp list 2>/dev/null | grep -q "^${name}"; then echo active; else echo inactive; fi
      ;;
    cli)
      if command -v "$name" >/dev/null 2>&1; then echo active; else echo inactive; fi
      ;;
    *) echo inactive ;;
  esac
}

# Structure via the parse contract (claude-free). Fail loud on a bad profile —
# an empty read must NOT silently report "ready".
plain="$("$PROFILE_SH" show "$PROFILE" --plain 2>/dev/null)" \
  || { echo "design-gate: 'profile.sh show $PROFILE --plain' failed" >&2; exit 2; }
[ -n "$plain" ] || { echo "design-gate: profile '$PROFILE' is empty or unreadable" >&2; exit 2; }

blocking=()    # inactive, /profile design activates it (skill/plugin)
manual=()      # inactive, required but needs a manual step (mcp key / cli install)
unverified=()  # can't check (claude CLI absent)
while IFS=$'\t' read -r type name; do
  [ -n "$type" ] || continue
  in_scope "$name" || continue        # ignore non-core tooling (browser, plan-*, graphify)
  case "$(tool_active "$name" "$type")" in
    active)  ;;
    unknown) unverified+=("$name") ;;
    *)
      case "$type" in
        gstack|external|personal|plugin) blocking+=("$name") ;;
        *)                               manual+=("$name") ;;
      esac
      ;;
  esac
done <<< "$plain"

# Verdict — three outcomes:
#   blocking/manual non-empty -> INCOMPLETE (exit 10): the gate trips.
#   only unverified non-empty -> READY BUT UNVERIFIED (exit 11): fail-VISIBLE.
#     claude was unreachable, so the plugin/MCP (magic, ui-ux-pro-max) could
#     not be checked. Never pass this as a silent READY — proceed, but say so.
#   nothing pending           -> READY (exit 0).
if [ "${#blocking[@]}" -gt 0 ] || [ "${#manual[@]}" -gt 0 ]; then
  echo "design toolchain: INCOMPLETE"
  if [ "${#blocking[@]}" -gt 0 ]; then
    echo "  activate with /profile $PROFILE:  ${blocking[*]}"
  fi
  if [ "${#manual[@]}" -gt 0 ]; then
    echo "  required + manual step (API key / external install):  ${manual[*]}"
    case " ${manual[*]} " in
      *" magic "*) echo "    magic needs MAGIC_API_KEY in ~/.claude/.env (/profile $PROFILE runs toggle-external.sh)" ;;
    esac
  fi
  if [ "${#unverified[@]}" -gt 0 ]; then
    echo "  also unverified (claude CLI unreachable): ${unverified[*]}"
  fi
  echo "  → run:  /profile $PROFILE"
  exit 10
fi

if [ "${#unverified[@]}" -gt 0 ]; then
  echo "design toolchain: READY BUT UNVERIFIED — ${#unverified[@]} tool(s) not checked"
  echo "  unverified (claude CLI unreachable): ${unverified[*]}"
  echo "  the gate could NOT confirm the design plugin/MCP (e.g. magic,"
  echo "  ui-ux-pro-max) are active. Proceed only after checking manually:"
  echo "      claude mcp list     claude plugin list"
  exit 11
fi

echo "design toolchain: READY — profile '$PROFILE' design tools active"
exit 0
