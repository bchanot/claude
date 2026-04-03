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

detect_skill_creator() {
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && ls "$cache_dir" 2>/dev/null | grep -qi "skill-creator"
}

detect_pr_review_toolkit() {
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && ls "$cache_dir" 2>/dev/null | grep -qi "pr-review-toolkit"
}

# --- Toggle plugins ---

detect_gstack() {
  [ -d "$HOME/.claude/skills/gstack" ]
}

detect_gsd() {
  ls "$HOME/.claude/skills/" 2>/dev/null | grep -qi "gsd"
}

detect_frontend_design() {
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && ls "$cache_dir" 2>/dev/null | grep -qi "frontend-design"
}

detect_uiux_pro_max() {
  local cache_dir="$HOME/.claude/plugins/cache"
  [ -d "$cache_dir" ] && ls "$cache_dir" 2>/dev/null | grep -qi "ui-ux-pro-max"
}

detect_context7() {
  claude mcp list 2>/dev/null | grep -q "context7"
}
