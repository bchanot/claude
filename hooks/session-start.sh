#!/usr/bin/env bash
# ============================================================
# Claude Code — Session start plugin status
# Runs once per session. Zero API calls. Filesystem only.
# ============================================================

TOGGLE_ACTIVE=()
TOGGLE_INACTIVE=()

# --- GStack ---
if [ -d "$HOME/.claude/skills/gstack" ]; then
  TOGGLE_ACTIVE+=("gstack")
else
  TOGGLE_INACTIVE+=("gstack")
fi

# --- GSD ---
if ls "$HOME/.claude/skills/" 2>/dev/null | grep -qi "gsd"; then
  TOGGLE_ACTIVE+=("gsd")
else
  TOGGLE_INACTIVE+=("gsd")
fi

# --- UI/UX Pro Max ---
if ls "$HOME/.claude/plugins/cache/" 2>/dev/null | grep -qi "ui-ux-pro-max"; then
  TOGGLE_ACTIVE+=("ui-ux-pro-max")
else
  TOGGLE_INACTIVE+=("ui-ux-pro-max")
fi

# --- frontend-design ---
if ls "$HOME/.claude/plugins/cache/" 2>/dev/null | grep -qi "frontend-design"; then
  TOGGLE_ACTIVE+=("frontend-design")
else
  TOGGLE_INACTIVE+=("frontend-design")
fi

# --- Context7 MCP ---
if claude mcp list 2>/dev/null | grep -q "context7"; then
  TOGGLE_ACTIVE+=("context7")
else
  TOGGLE_INACTIVE+=("context7")
fi

# --- Format output ---
ACTIVE_STR="${TOGGLE_ACTIVE[*]:-none}"
INACTIVE_STR="${TOGGLE_INACTIVE[*]:-none}"

echo ""
echo "┌─ Toggle plugins ──────────────────────────────────┐"
printf "│  🟢 ON  : %-40s│\n" "$ACTIVE_STR"
printf "│  ⚫ OFF : %-40s│\n" "$INACTIVE_STR"
echo "│  💡 /plugin-check  before starting a new project  │"
echo "└───────────────────────────────────────────────────┘"
echo ""
