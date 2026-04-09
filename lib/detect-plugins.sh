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
  command -v rtk &>/dev/null
}

detect_superpowers() {
  # Fast check: filesystem (plugin cache)
  local cache_dir="$HOME/.claude/plugins/cache"
  if [ -d "$cache_dir" ]; then
    ls "$cache_dir" 2>/dev/null | grep -qi "superpowers" && return 0
  fi
  # Slow fallback: CLI (only if fast check fails)
  claude plugin list 2>/dev/null | grep -qi "superpowers" && return 0
  return 1
}

detect_security_guidance() {
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && ls "$cache_dir" 2>/dev/null | grep -qi "security-guidance"
}


# --- Toggle plugins ---

detect_gstack() {
  [ -d "$HOME/.claude/skills/gstack" ]
}

detect_gsd() {
  # GSD v2 (gsd-pi) is a standalone CLI, not a Claude Code plugin.
  # Detection: check for 'gsd' binary in PATH.
  command -v gsd &>/dev/null
}

detect_frontend_design() {
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && ls "$cache_dir" 2>/dev/null | grep -qi "frontend-design"
}

detect_plugin_dev() {
  # plugin-dev replaces the old "skill-creator" reference
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && ls "$cache_dir" 2>/dev/null | grep -qi "plugin-dev"
}

detect_uiux_pro_max() {
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && ls "$cache_dir" 2>/dev/null | grep -qi "ui-ux-pro-max"
}

detect_context7() {
  # Context7 CLI (ctx7) — installed globally via npm
  command -v ctx7 &>/dev/null
}

detect_ruflo() {
  # 1. Fast: check npm global binary
  command -v ruflo &>/dev/null && return 0
  # 2. Fast: check MCP config files (ruflo or ruvnet/claude-flow variants)
  for _cfg in "$HOME/.claude.json" "$HOME/.mcp.json"; do
    [ -f "$_cfg" ] && grep -qi "ruflo\|ruvnet\|claude-flow" "$_cfg" 2>/dev/null && return 0
  done
  # 3. Slow fallback: claude mcp list (only if fast checks fail, spawns subprocess)
  command -v claude &>/dev/null && claude mcp list 2>/dev/null | grep -qi "ruflo" && return 0
  return 1
}
