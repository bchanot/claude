#!/usr/bin/env bash
# shellcheck disable=SC2016  # jq programs quote $vars on purpose
# ============================================================
# lib/profile.sh — profiles as settings fragments for packs + connectors
#
# A profile `lib/profiles/<name>.json` is a literal Claude Code settings
# fragment: `enabledPlugins` (every pack `pack-<n>@skills-dir` and managed
# plugin, explicit true/false), `deniedMcpServers` (claude.ai connector
# names, optional) and `model` (optional). Per project, `set` merges it
# into `.claude/settings.local.json`; per conversation, `cc <name>
# <profile>` (lib/cc.sh) passes the file as `claude --settings`. Nothing
# here writes the user scope, moves a symlink or calls `claude`.
#
# Usage:
#   profile.sh [-C <dir>] list
#   profile.sh [-C <dir>] show <name>
#   profile.sh [-C <dir>] current [--plain]
#   profile.sh [-C <dir>] set <name>
#   profile.sh [-C <dir>] unset
#   profile.sh [-C <dir>] enable|disable <pack | plugin id>
#   profile.sh [-C <dir>] diff <name>
#
# <dir> (default: cwd) is the session dir. The project root, where the
# local file lives, follows Claude Code: inside a git repo it is the parent
# of the git common dir (a worktree resolves to the main checkout), unless
# that is $HOME or above; otherwise the nearest ancestor holding .claude/,
# CLAUDE.md or .git, below $HOME. The shared .claude/settings.json is read
# from <dir> itself.
# `current` = lib/profile-state.jq, ONE jq pass over: $CLAUDE_PROFILE_SETTINGS
# (the --settings file lib/cc.sh exports), <root>/.claude/settings.local.json,
# <root>/.claude/settings.json, ~/.claude/settings.json; a pack absent from
# all takes its manifest `defaultEnabled` (absent key = on); a managed plugin
# absent from all is off; `enabledPlugins` and `model` per key, highest wins;
# `deniedMcpServers` = the UNION of every file; `disableClaudeAiConnectors`
# any-source-true; then ~/.claude.json `projects[<root>].disabledMcpServers`.
# `--plain` = one `key=value` per line: the single truth for gates, hooks
# and the statusline (supersedes `show --plain`, BDR-024).
#
# Exit: 0 ok · 2 usage, unknown profile or pack, not a project root (no
#       CLAUDE.md and no .git), unreadable or invalid local JSON; nothing
#       is written on any refusal.
# ============================================================
set -euo pipefail

REPO="${PROFILE_REPO_OVERRIDE:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." \
  && pwd)}"
PROFILES_DIR="$REPO/lib/profiles"
SKILLS_DIR="$REPO/skills"
STATE_JQ="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/profile-state.jq"
USER_SETTINGS="${PROFILE_USER_SETTINGS:-$HOME/.claude/settings.json}"
CLAUDE_JSON="${PROFILE_CLAUDE_JSON:-$HOME/.claude.json}"
LOCAL_REL=".claude/settings.local.json"
PROJECT="$PWD"      # the project root: local settings, ~/.claude.json key
SESSION_DIR="$PWD"  # the -C dir: shared project settings

die() { echo "profile: $*" >&2; exit 2; }
usage() {
  sed -n '/^# Usage:/,/^#$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,2\}//' >&2
  exit 2
}

# ---- project root ----------------------------------------------------------
NAME_RE='^[a-z0-9][a-z0-9-]*$'
PACK_RE='^[A-Za-z0-9][A-Za-z0-9@._:-]*$'
require_name() { # $1 value, $2 regex, $3 label: refuse before any path use
  [[ "$1" =~ $2 ]] || die "invalid $3 '$1'"
}
home_or_above() { # $1 dir
  [ "$1" = / ] && return 0
  case "$HOME/" in "$1"/*) return 0 ;; esac
  return 1
}
git_root() { # $1 dir → parent of the git common dir, unless $HOME or above
  local common root
  common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir \
    2>/dev/null)" || return 1
  [ "$(basename "$common")" = .git ] || return 1
  root="$(dirname "$common")"
  home_or_above "$root" && return 1
  echo "$root"
}
find_root() { # $1 dir → the project root (see header)
  local d="$1"
  git_root "$d" && return 0
  while [ "$d" != / ] && [ "$d" != "$HOME" ]; do
    if [ -d "$d/.claude" ] || [ -f "$d/CLAUDE.md" ] || [ -e "$d/.git" ]; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  echo "$1"
}
require_project_root() {
  [ -f "$PROJECT/CLAUDE.md" ] || [ -e "$PROJECT/.git" ] \
    || die "not a project root (no CLAUDE.md and no .git): $PROJECT"
}

# ---- inputs ----------------------------------------------------------------
profile_file() { echo "$PROFILES_DIR/$1.json"; }
profile_names() {
  local f
  for f in "$PROFILES_DIR"/*.json; do [ -f "$f" ] && basename "$f" .json; done
  return 0
}
profile_desc() { # the `- **name**: text` line of lib/profiles/README.md
  sed -n "s/^- \*\*$1\*\*: //p" "$PROFILES_DIR/README.md" 2>/dev/null | head -1
}
managed_ids() {
  jq -r '.enabledPlugins | keys[]' "$PROFILES_DIR"/*.json | sort -u
}
managed_connectors() {
  jq -r '(.deniedMcpServers // [])[] | .serverName' "$PROFILES_DIR"/*.json \
    | sort -u
}
as_json_list() { jq -Rn '[inputs]'; }   # stdin lines → JSON string array
json_or_empty() { # $1 file → its JSON, {} when absent; rc 2 when invalid
  [ -f "$1" ] || { echo '{}'; return 0; }
  jq -c . "$1" 2>/dev/null || return 2
}
read_local() {
  json_or_empty "$PROJECT/$LOCAL_REL" \
    || die "$LOCAL_REL is not valid JSON, nothing written"
}
pack_default() { # $1 id → true | false | missing (manifest defaultEnabled)
  local m="$SKILLS_DIR/${1%@skills-dir}/.claude-plugin/plugin.json"
  [ -f "$m" ] || { echo missing; return 0; }
  jq -r 'if .defaultEnabled == false then "false" else "true" end' "$m"
}
manifests_json() { # [{id, on}] for every pack manifest, [] when none
  jq -cn '[inputs | {id: (.name + "@skills-dir"),
                     on: (.defaultEnabled != false)}]' \
    "$SKILLS_DIR"/pack-*/.claude-plugin/plugin.json 2>/dev/null || echo '[]'
}
have_flag() {
  [ -n "${CLAUDE_PROFILE_SETTINGS:-}" ] && [ -f "$CLAUDE_PROFILE_SETTINGS" ]
}
raw_or_null() { # $1 file → the path, or /dev/null when absent or unset
  if [ -n "$1" ] && [ -f "$1" ]; then echo "$1"; else echo /dev/null; fi
}

# ---- effective state: two jq calls -----------------------------------------
state() { # $1 mode: plain | human | json
  local hasflag=0; have_flag && hasflag=1
  jq -rn --arg mode "$1" --arg proj "$PROJECT" --arg hasflag "$hasflag" \
    --arg flagname "${CLAUDE_PROFILE:--}" \
    --rawfile u "$(raw_or_null "$USER_SETTINGS")" \
    --rawfile p "$(raw_or_null "$SESSION_DIR/.claude/settings.json")" \
    --rawfile l "$(raw_or_null "$PROJECT/$LOCAL_REL")" \
    --rawfile f "$(raw_or_null "${CLAUDE_PROFILE_SETTINGS:-}")" \
    --rawfile cj "$(raw_or_null "$CLAUDE_JSON")" \
    --argjson m "$(manifests_json)" -f "$STATE_JQ" "$PROFILES_DIR"/*.json
}

# ---- commands ---------------------------------------------------------------
unknown_profile() {
  echo "profile: unknown profile '$1'. Known:" >&2; cmd_list >&2; exit 2
}
cmd_list() {
  local n d
  for n in $(profile_names); do
    d="$(profile_desc "$n")"
    printf '%-10s %s\n' "$n" "${d:-(no line in lib/profiles/README.md)}"
  done
}
cmd_show() {
  local f id v tag
  require_name "$1" "$NAME_RE" "profile name"
  f="$(profile_file "$1")"; [ -f "$f" ] || unknown_profile "$1"
  echo "profile $1: $(profile_desc "$1")"
  for id in $(jq -r '.enabledPlugins | keys[]' "$f"); do
    v="$(jq -r --arg k "$id" '.enabledPlugins[$k]
          | if . then "on" else "off" end' "$f")"
    tag=""
    case "$id" in pack-*@skills-dir)
      [ "$(pack_default "$id")" = missing ] \
        && tag="  missing (no skills/${id%@skills-dir}/)" ;;
    esac
    printf '  %-42s %s%s\n' "$id" "$v" "$tag"
  done
  echo "  connectors denied: $(jq -r '(.deniedMcpServers // [])
    | if length == 0 then "none" else map(.serverName) | join(", ") end' "$f")"
  echo "  model: $(jq -r '.model // "-"' "$f")"
}
cmd_current() {
  if [ "${1:-}" = "--plain" ]; then state plain; else state human; fi
}
write_local() { # $1 JSON → atomic replace of the local settings
  local tmp
  mkdir -p "$PROJECT/.claude"
  tmp="$(mktemp "$PROJECT/.claude/.settings.local.XXXXXX")"
  jq . <<<"$1" > "$tmp" && mv -f "$tmp" "$PROJECT/$LOCAL_REL"
}
after_write_hint() {
  echo "next: /reload-plugins loads the packs in this session;" \
    "connectors and model apply to the next session"
  if have_flag; then
    echo "note: this conversation runs --settings ${CLAUDE_PROFILE:-?}:" \
      "the flag fragment fixes every managed key, so this write applies to" \
      "other sessions only; relaunch: cc <name> <profile>"
  fi
}
cmd_set() {
  local f cur new
  require_name "$1" "$NAME_RE" "profile name"
  f="$(profile_file "$1")"; [ -f "$f" ] || unknown_profile "$1"
  require_project_root; cur="$(read_local)"
  new="$(jq --slurpfile p "$f" \
    --argjson names "$(managed_connectors | as_json_list)" '
    . as $cur | $p[0] as $p
    | .enabledPlugins = (($cur.enabledPlugins // {}) + $p.enabledPlugins)
    | .deniedMcpServers = ([($cur.deniedMcpServers // [])[]
        | select(.serverName as $s | ($names | index($s)) == null)]
        + ($p.deniedMcpServers // []))
    | if (.deniedMcpServers | length) == 0 then del(.deniedMcpServers)
      else . end
    | if $p.model then .model = $p.model else . end' <<<"$cur")"
  write_local "$new"
  echo "profile $1 → $LOCAL_REL"; after_write_hint
}
cmd_unset() {
  local cur name pm new
  require_project_root; cur="$(read_local)"
  name="$(CLAUDE_PROFILE_SETTINGS='' state json | jq -r .name)"
  pm="-"
  [ "$name" != custom ] \
    && pm="$(jq -r '.model // "-"' "$(profile_file "$name")")"
  new="$(jq --argjson ids "$(managed_ids | as_json_list)" \
    --argjson names "$(managed_connectors | as_json_list)" --arg pm "$pm" '
    .enabledPlugins = ((.enabledPlugins // {})
        | with_entries(select(.key as $k | ($ids | index($k)) == null)))
    | if (.enabledPlugins | length) == 0 then del(.enabledPlugins) else . end
    | .deniedMcpServers = [(.deniedMcpServers // [])[]
        | select(.serverName as $s | ($names | index($s)) == null)]
    | if (.deniedMcpServers | length) == 0 then del(.deniedMcpServers)
      else . end
    | if $pm != "-" and .model == $pm then del(.model) else . end' <<<"$cur")"
  if [ "$(jq -c . <<<"$new")" = "$cur" ]; then
    echo "nothing to unset in $LOCAL_REL (was: $name)"; return 0
  fi
  write_local "$new"
  echo "profile keys removed from $LOCAL_REL (was: $name)"; after_write_hint
}
resolve_id() { # design | pack-design | pack-design@skills-dir | <plugin id>
  case "$1" in
    *@*) echo "$1" ;;
    pack-*) echo "$1@skills-dir" ;;
    *) echo "pack-$1@skills-dir" ;;
  esac
}
cmd_toggle() { # $1 true|false, $2 pack or plugin spelling
  local id cur new
  require_name "$2" "$PACK_RE" "pack or plugin name"
  id="$(resolve_id "$2")"
  managed_ids | grep -qxF -- "$id" \
    || die "unknown pack or plugin '$2' (known: $(managed_ids | tr '\n' ' '))"
  require_project_root; cur="$(read_local)"
  new="$(jq --arg id "$id" --argjson v "$1" \
    '.enabledPlugins = ((.enabledPlugins // {}) + {($id): $v})' <<<"$cur")"
  write_local "$new"
  echo "$id=$1 → $LOCAL_REL"; after_write_hint
}
cmd_diff() {
  local f out
  require_name "$1" "$NAME_RE" "profile name"
  f="$(profile_file "$1")"; [ -f "$f" ] || unknown_profile "$1"
  out="$(jq -r --argjson e "$(state json)" '
    def onoff: if . then "on" else "off" end;
    (.enabledPlugins | to_entries[] | select($e.plugins[.key] != .value)
     | .key + ": " + ($e.plugins[.key] | onoff) + " → " + (.value | onoff)),
    (([(.deniedMcpServers // [])[] | .serverName] | sort) as $want
     | ($e.managed_denied | sort) as $have
     | if $want == $have then empty
       else "connectors denied: " + ($have | join(", ")) + " → "
            + ($want | join(", ")) end),
    (if .model != null and .model != $e.model
     then "model: " + $e.model + " → " + (.model // "-")
     else empty end)' "$f")"
  if [ -n "$out" ]; then echo "$out"; else echo "no difference from $1"; fi
}

# ---- main --------------------------------------------------------------------
command -v jq >/dev/null 2>&1 || die "jq is required"
while [ $# -gt 0 ]; do
  case "$1" in
    -C) [ -n "${2:-}" ] || usage
        PROJECT="$(cd "$2" 2>/dev/null && pwd)" || die "no such dir: $2"
        shift 2 ;;
    *) break ;;
  esac
done
SESSION_DIR="$PROJECT"
PROJECT="$(find_root "$PROJECT")"
case "${1:-}" in
  list)    cmd_list ;;
  show)    [ -n "${2:-}" ] || usage; cmd_show "$2" ;;
  current) cmd_current "${2:-}" ;;
  set)     [ -n "${2:-}" ] || usage; cmd_set "$2" ;;
  unset)   cmd_unset ;;
  enable)  [ -n "${2:-}" ] || usage; cmd_toggle true "$2" ;;
  disable) [ -n "${2:-}" ] || usage; cmd_toggle false "$2" ;;
  diff)    [ -n "${2:-}" ] || usage; cmd_diff "$2" ;;
  *) usage ;;
esac
