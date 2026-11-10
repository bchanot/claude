#!/usr/bin/env bash
# ============================================================
# lib/detect-plugins.sh — Single source of truth for plugin detection
# Sourced by: session-start.sh, doctor.sh, agents/status-reporter.md
#
# detect_* return 0 (detected) or 1 (not detected), silently — callers
# handle messaging. list_on_plugins prints to stdout.
# ============================================================

# --- Always-on plugins ---

detect_rtk() {
  command -v rtk &>/dev/null && return 0
  # PATH heal: hook/session PATH may lack the cargo bin dir (LRN-036 class)
  [ -x "$HOME/.cargo/bin/rtk" ] || [ -x "$HOME/.local/bin/rtk" ]
}

detect_superpowers() {
  # superpowers = 7 vendored skills since 2026-09-28; the plugin is gone.
  # One file test on the linked vendored skill: proves vendored AND
  # linked in one shot — no plugin cache glob, no `plugin list` CLI call.
  [ -f "$HOME/.claude/skills/brainstorming/SKILL.md" ]
}


# --- Effective plugin state ---

list_on_plugins() {
  # Enabled plugin ids for this project and conversation, one per line:
  # the effective profile for the ids lib/profiles manages (BDR-134),
  # user-scope true for the others (LRN-005). Always returns 0.
  # shortcut: unmanaged ids read user scope only (not project/local) and
  # a skills-dir mod set in no scope (memory) is not seen, nor a mod's
  # ~/.claude/<name>.json off switch; upgrade = jq merge of the scopes +
  # plugin manifests.
  local plain="${PROFILE_PLAIN:-}" user
  [ -n "$plain" ] || plain="$(bash "$HOME/.claude/lib/profile.sh" -C "$PWD" \
    current --plain 2>/dev/null)" || plain=""
  user="$(grep -oE '"[A-Za-z0-9_-]+@[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*true' \
    "$HOME/.claude/settings.json" 2>/dev/null)" || user=""
  awk -F= 'FNR == NR { if (sub(/^plugin:/, "", $1)) { m[$1] = 1
      if ($2 == "on") print $1 }; next }
    { sub(/^"/, ""); sub(/".*$/, "") }
    $0 != "" && !($0 in m) && $0 !~ /^pack-.*@skills-dir$/' \
    <(printf '%s\n' "$plain") <(printf '%s\n' "$user")
  return 0
}


# --- Toggle plugins ---

detect_gstack() {
  # gstack = the three packs; "on" = pack-gstack-dev on for this project and
  # conversation. PROFILE_PLAIN (session-start) avoids a second profile.sh run.
  local plain="${PROFILE_PLAIN:-}"
  [ -n "$plain" ] || plain="$(bash "$HOME/.claude/lib/profile.sh" -C "$PWD" \
    current --plain 2>/dev/null)" || return 1
  grep -q '^pack-gstack-dev=on' <<<"$plain"
}

detect_gsd() {
  # GSD v2 (gsd-pi) is a standalone CLI, not a Claude Code plugin.
  # Detection: check for 'gsd' binary in PATH.
  command -v gsd &>/dev/null
}

detect_plugin_dev() {
  # plugin-dev replaces the old "skill-creator" reference
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && compgen -G "$cache_dir"/*plugin-dev* &>/dev/null
}

detect_uiux_pro_max() {
  # installed (cache) AND enabled for this project (here-string: no pipe)
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && compgen -G "$cache_dir"/*ui-ux-pro-max* &>/dev/null \
    && grep -q '^ui-ux-pro-max@' <<<"$(list_on_plugins)"
}

detect_context7() {
  # Context7 CLI (ctx7) — installed globally via npm
  command -v ctx7 &>/dev/null
}

detect_graphifyy() {
  # Graphifyy — codebase knowledge graph, installed via pipx
  command -v graphify &>/dev/null
}
