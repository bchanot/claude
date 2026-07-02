#!/usr/bin/env bash
# ============================================================
# lib/detect-plugins.sh — Single source of truth for plugin detection
# Sourced by: session-start.sh, doctor.sh, install-plugins.sh
#
# Each function returns 0 (detected) or 1 (not detected).
# No output — callers handle messaging.
# ============================================================

# --- Always-on plugins ---

detect_rtk() {
  command -v rtk &>/dev/null && return 0
  # PATH heal: hook/session PATH may lack the cargo bin dir (LRN-036 class)
  [ -x "$HOME/.cargo/bin/rtk" ] || [ -x "$HOME/.local/bin/rtk" ]
}

detect_superpowers() {
  # Fast check: filesystem (plugin cache)
  local cache_dir="$HOME/.claude/plugins/cache"
  if [ -d "$cache_dir" ]; then
    compgen -G "$cache_dir"/*superpowers* &>/dev/null && return 0
  fi
  # Slow fallback: CLI (only if fast check fails)
  claude plugin list 2>/dev/null | grep -qi "superpowers" && return 0
  return 1
}

detect_security_guidance() {
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && compgen -G "$cache_dir"/*security-guidance* &>/dev/null
}


# --- Toggle plugins ---

detect_gstack() {
  # gstack is exposed via per-skill symlinks (browse, canary, qa, …);
  # the legacy top-level symlink was removed to avoid duplicate entries.
  # Detect by checking any of its individual skills.
  [ -L "$HOME/.claude/skills/browse" ] || [ -L "$HOME/.claude/skills/qa" ]
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
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && compgen -G "$cache_dir"/*ui-ux-pro-max* &>/dev/null
}

detect_context7() {
  # Context7 CLI (ctx7) — installed globally via npm
  command -v ctx7 &>/dev/null
}

detect_graphifyy() {
  # Graphifyy — codebase knowledge graph, installed via pipx
  command -v graphify &>/dev/null
}

# True if a plugin is registered as enabled in settings.json's
# enabledPlugins map. Filesystem only (no subprocess to claude CLI).
# Argument is the full "name@marketplace" key.
plugin_enabled() {
  local key="$1"
  [ -f "$HOME/.claude/settings.json" ] || return 1
  grep -qE "\"${key}\"[[:space:]]*:[[:space:]]*true" "$HOME/.claude/settings.json"
}


# --- Plan detection ---

detect_plan() {
  # Detect Claude plan: max, pro, or free.
  # Checks ~/.claude.json for model access hints.
  # Returns plan name on stdout, always exits 0.
  local claude_json="$HOME/.claude.json"
  if [ -f "$claude_json" ]; then
    # Max plan: has opus model access or max flag
    if grep -q '"planType".*"max"' "$claude_json" 2>/dev/null; then
      echo "max"; return 0
    fi
    # Check cached features for max indicators
    if grep -q '"tengu_cobalt_compass": true' "$claude_json" 2>/dev/null \
       && grep -q '"tengu_harbor": true' "$claude_json" 2>/dev/null; then
      echo "max"; return 0
    fi
  fi
  # Fallback: check if claude CLI reports plan
  local plan
  plan=$(claude config get planType 2>/dev/null || true)
  case "$plan" in
    max|Max|MAX) echo "max" ;;
    pro|Pro|PRO) echo "pro" ;;
    free|Free|FREE) echo "free" ;;
    *) echo "pro" ;;  # default assumption
  esac
}
