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
# checks MIRROR profile.sh:skill_status() — change one, sync the other,
# except the 21st auth state: gate-only, no skill_status counterpart.
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
#                    This is where the `21st` CLI lands: required, never
#                    silent (npm i -g @21st-dev/cli, then 21st login).
#                    21st's sign-in state is three-valued: in (active),
#                    out (exit 12, ask to sign in), unknown (exit 11).
# Both classes trip the gate. Tools NOT on the GATE-BLOCK allowlist are
# ignored entirely (browser/plan/shotgun tooling, graphify).
#
# disabledMcpServers is NEVER read — unreliable for bi-modal servers
# (context7 can appear there yet be active via another channel).
#
# Exit: 0 = ready · 11 = ready-but-unverified (proceed, say so) ·
#       10 = incomplete (trips) · 12 = sign-in required (21st) · 2 = error.
# Usage: design-tool-gate.sh [profile]        (default profile: design)
# ============================================================
set -euo pipefail

REPO="${DESIGN_GATE_REPO_OVERRIDE:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROFILE_SH="${DESIGN_GATE_PROFILE_SH:-$REPO/lib/profile.sh}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
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
  command -v "$CLAUDE_BIN" >/dev/null 2>&1 && return
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

# Same sanitized-PATH problem for `21st` (an npm global bin), with a twist:
# the repair above only fires when claude ITSELF is unresolvable, and claude
# often lives in ~/.local/bin while the npm global bin dir is missing from a
# hook's PATH. Probe for the binary directly and prepend the dir that has it,
# otherwise a perfectly installed CLI reads as "missing" and trips the gate.
ensure_21st_on_path() {
  command -v 21st >/dev/null 2>&1 && return
  local cand
  for cand in \
    "$HOME/.local/bin/21st" \
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
# or the transcript). `timeout 15` bounds a hung CLI; stdin is closed so a
# CLI that reads stdin can't eat the gate's own `read` loop; stderr never
# enters the match (stdout only). Echoes: in | out | unknown:<diagnostic>.
twentyfirst_auth_state() {
  if [ -n "${TWENTYFIRST_TOKEN:-}" ] || [ -n "${API_KEY_21ST:-}" ]; then
    echo in
    return
  fi
  local line rc
  if line="$(timeout 15 21st whoami 2>/dev/null </dev/null | head -1)"; then
    rc=0
  else
    rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    case "$line" in
      "Logged in as "*) echo in;  return ;;
      "Not logged in"*) echo out; return ;;
    esac
  fi
  [ -n "$line" ] || line="no output"
  echo "unknown:whoami: rc=$rc ${line:0:60}"
}

# Gate scope: the "# GATE-BLOCK:" allowlist (one or more lines, concatenated).
# Empty => fall back to "every gate-relevant entry is in scope" (coarse).
core_set="$(grep '^# GATE-BLOCK:' "$PROFILE_FILE" 2>/dev/null \
            | sed 's/^# GATE-BLOCK:[[:space:]]*//' | tr '\n' ' ' || true)"

# Membership in the allowlist. Empty allowlist = everything in scope.
in_scope() {
  [ -z "$core_set" ] && return 0
  case " $core_set " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# State of one tool, by type. Mirrors profile.sh:skill_status() — keep in
# sync, except the 21st auth state (gate-only, no skill_status counterpart).
# Echoes: active | inactive | unknown (can't verify, claude absent) |
#         signedout | unknown:<diagnostic>  (last two: 21st CLI only)
tool_active() {
  local name="$1" type="$2"
  case "$type" in
    gstack|external|personal)
      if [ -e "$SKILLS_DIR/$name" ]; then echo active; else echo inactive; fi
      ;;
    plugin)
      if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then echo unknown; return; fi
      if "$CLAUDE_BIN" plugin list 2>/dev/null \
           | awk -v p="^[[:space:]]*❯ ${name}@" '$0 ~ p {f=1; next} f && /Status:/ {print; exit}' \
           | grep -q "✔ enabled"
      then echo active; else echo inactive; fi
      ;;
    mcp)
      if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then echo unknown; return; fi
      if "$CLAUDE_BIN" mcp list 2>/dev/null | grep -q "^${name}"; then echo active; else echo inactive; fi
      ;;
    cli)
      command -v "$name" >/dev/null 2>&1 || { echo inactive; return; }
      [ "$name" = "21st" ] || { echo active; return; }
      local auth
      auth="$(twentyfirst_auth_state)"
      case "$auth" in
        in)        echo active ;;
        out)       echo signedout ;;
        unknown:*) echo "$auth" ;;
      esac
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
signedout=()   # 21st CLI installed, not signed in
unverified_cli=()  # 21st CLI: whoami answered something unexpected
while IFS=$'\t' read -r type name; do
  [ -n "$type" ] || continue
  in_scope "$name" || continue        # ignore non-core tooling (browser, plan-*, graphify)
  state="$(tool_active "$name" "$type")"
  case "$state" in
    active)     ;;
    signedout)  signedout+=("$name") ;;
    unknown)    unverified+=("$name") ;;
    unknown:*)  unverified_cli+=("$name (${state#unknown:})") ;;
    *)
      case "$type" in
        gstack|external|personal|plugin) blocking+=("$name") ;;
        *)                               manual+=("$name") ;;
      esac
      ;;
  esac
done <<< "$plain"

# print_unverified — the "also unverified" lines shared by the 10, 11 and 12
# blocks: a claude-unreachable tool keeps its existing remedy; a 21st CLI
# that answered whoami with something unexpected gets its own — the two are
# never merged, so no block blames 21st for a claude problem or vice versa.
print_unverified() {
  if [ "${#unverified[@]}" -gt 0 ]; then
    echo "  also unverified (claude CLI unreachable): ${unverified[*]}"
  fi
  local entry name diag
  for entry in "${unverified_cli[@]}"; do
    name="${entry%% (*}"
    diag="${entry#*\(}"; diag="${diag%\)}"
    echo "  $name could not answer: $diag —" \
         "a CLI runtime/PATH problem (node under nvm?)," \
         "not a sign-in problem; fix it, then re-run"
  done
}

# Verdict — four outcomes, checked in order:
#   blocking/manual non-empty -> INCOMPLETE (exit 10): the gate trips.
#   else signedout non-empty  -> SIGN-IN REQUIRED (exit 12): ask the user to
#     run `21st login`, end the turn, wait, re-run — never a silent skip.
#   else unverified/unverified_cli non-empty -> READY BUT UNVERIFIED (exit
#     11): fail-VISIBLE. claude unreachable and/or 21st couldn't answer
#     whoami — never pass either as a silent READY.
#   nothing pending           -> READY (exit 0).
if [ "${#blocking[@]}" -gt 0 ] || [ "${#manual[@]}" -gt 0 ]; then
  echo "design toolchain: INCOMPLETE"
  if [ "${#blocking[@]}" -gt 0 ]; then
    echo "  activate with /profile $PROFILE:  ${blocking[*]}"
  fi
  if [ "${#manual[@]}" -gt 0 ]; then
    echo "  required + manual step (external install / sign-in):  ${manual[*]}"
    case " ${manual[*]} " in
      *" 21st "*) echo "    21st needs the CLI: npm i -g @21st-dev/cli   then   21st login" ;;
    esac
  fi
  print_unverified
  echo "  → run:  /profile $PROFILE"
  exit 10
fi

if [ "${#signedout[@]}" -gt 0 ]; then
  echo "design toolchain: SIGN-IN REQUIRED — 21st CLI installed, not signed in"
  echo "  ask the user to run in this session:" \
       " ! 21st login" \
       "  (browser flow, saves a local token)"
  echo "  then re-run this gate before any 21st step — never skip 21st silently"
  print_unverified
  exit 12
fi

if [ "${#unverified[@]}" -gt 0 ] || [ "${#unverified_cli[@]}" -gt 0 ]; then
  echo "design toolchain: READY BUT UNVERIFIED —" \
       "$(( ${#unverified[@]} + ${#unverified_cli[@]} )) tool(s) not checked"
  print_unverified
  if [ "${#unverified[@]}" -gt 0 ]; then
    echo "  the gate could NOT confirm the design plugin (ui-ux-pro-max) is"
    echo "  active. Proceed only after checking manually:"
    echo "      claude plugin list"
  fi
  exit 11
fi

echo "design toolchain: READY — profile '$PROFILE' design tools active"
exit 0
