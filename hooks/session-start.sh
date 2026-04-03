#!/usr/bin/env bash
# ============================================================
# Claude Code — Session start plugin status
# Runs once per session. Zero API calls. Filesystem only.
# ============================================================

# ── Quick health check (filesystem only, no subprocesses) ──
BROKEN=()
for f in CLAUDE.md settings.json agents skills; do
  [ ! -e "$HOME/.claude/$f" ] && BROKEN+=("$f")
done

if [ ${#BROKEN[@]} -gt 0 ]; then
  # Try to find the repo path from an existing symlink
  _repo_hint=""
  for _probe in CLAUDE.md settings.json; do
    if [ -L "$HOME/.claude/$_probe" ]; then
      _repo_hint="$(cd "$(dirname "$(readlink "$HOME/.claude/$_probe")")" 2>/dev/null && pwd)"
      break
    fi
  done
  _fix_cmd="${_repo_hint:+cd $_repo_hint && }bash link.sh"

  echo ""
  echo "┌─ ⚠️  CONFIG ISSUES ────────────────────────────────┐"
  for b in "${BROKEN[@]}"; do
    printf "│  MISSING: ~/.claude/%-30s│\n" "$b"
  done
  printf "│  → %-47s│\n" "$_fix_cmd"
  echo "│  → /health for full diagnostic                     │"
  echo "└───────────────────────────────────────────────────┘"
  unset _repo_hint _fix_cmd
fi

# ── Load shared detection library ──
_lib="$(dirname "${BASH_SOURCE[0]}")/../lib/detect-plugins.sh"
if [ -f "$_lib" ]; then
  # shellcheck source=../lib/detect-plugins.sh
  source "$_lib"
else
  # Fallback: inline detection if lib is missing
  detect_gstack()          { [ -d "$HOME/.claude/skills/gstack" ]; }
  detect_gsd()             { ls "$HOME/.claude/skills/" 2>/dev/null | grep -qi "gsd"; }
  detect_uiux_pro_max()    { ls "$HOME/.claude/plugins/cache/" 2>/dev/null | grep -qi "ui-ux-pro-max"; }
  detect_frontend_design() { ls "$HOME/.claude/plugins/cache/" 2>/dev/null | grep -qi "frontend-design"; }
  detect_context7()        { claude mcp list 2>/dev/null | grep -q "context7"; }
fi
unset _lib

# ── Toggle plugin detection ──

TOGGLE_ACTIVE=()
TOGGLE_INACTIVE=()

for plugin in gstack gsd uiux_pro_max frontend_design context7; do
  # Map function name to display name
  case "$plugin" in
    uiux_pro_max)    display="ui-ux-pro-max" ;;
    frontend_design) display="frontend-design" ;;
    *)               display="$plugin" ;;
  esac

  if "detect_$plugin" 2>/dev/null; then
    TOGGLE_ACTIVE+=("$display")
  else
    TOGGLE_INACTIVE+=("$display")
  fi
done

# --- Format output ---
ACTIVE_STR="${TOGGLE_ACTIVE[*]:-none}"
INACTIVE_STR="${TOGGLE_INACTIVE[*]:-none}"

# Version detection: follow CLAUDE.md symlink back to repo, then read version.txt
_claude_real="$(readlink "$HOME/.claude/CLAUDE.md" 2>/dev/null || true)"
if [ -n "$_claude_real" ]; then
  _repo_dir="$(cd "$(dirname "$_claude_real")" 2>/dev/null && pwd)"
  CONFIG_VERSION=$(cat "$_repo_dir/version.txt" 2>/dev/null || echo "?")
else
  CONFIG_VERSION="?"
fi
unset _claude_real _repo_dir

echo ""
echo "┌─ Toggle plugins ──────────────────────────────────┐"
printf "│  🟢 ON  : %-40s│\n" "$ACTIVE_STR"
printf "│  ⚫ OFF : %-40s│\n" "$INACTIVE_STR"
echo "│  💡 /plugin-check  before starting a new project  │"
echo "│  🩺 /health  to run full diagnostic               │"
echo "└───────────────────────────────────────────────────┘"
echo ""
