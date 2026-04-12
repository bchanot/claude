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
  echo "⚠️  lib/detect-plugins.sh not found — config broken, run: bash link.sh"
  exit 0
fi
unset _lib

# ── Toggle plugin detection ──

TOGGLE_ACTIVE=()
TOGGLE_INACTIVE=()

for plugin in gstack uiux_pro_max frontend_design plugin_dev context7 ruflo graphifyy; do
  # Map function name to display name
  case "$plugin" in
    uiux_pro_max)    display="ui-ux-pro-max" ;;
    frontend_design) display="frontend-design" ;;
    plugin_dev)      display="plugin-dev" ;;
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

# GSD v2 — standalone CLI (not a Claude Code plugin — shown separately)
if detect_gsd 2>/dev/null; then
  GSD_STATUS="gsd v2 ✓"
else
  GSD_STATUS="gsd v2 ✗ (npm install -g gsd-pi)"
fi

# Version detection: follow CLAUDE.md symlink back to repo, then read version.txt
_claude_real="$(readlink "$HOME/.claude/CLAUDE.md" 2>/dev/null || true)"
if [ -n "$_claude_real" ]; then
  _repo_dir="$(cd "$(dirname "$_claude_real")" 2>/dev/null && pwd)"
  CONFIG_VERSION=$(cat "$_repo_dir/version.txt" 2>/dev/null || echo "?")
else
  CONFIG_VERSION="?"
fi
REPO_DIR="${_repo_dir:-}"
unset _claude_real _repo_dir

# Detect plan and set passive token budget
PLAN=$(detect_plan 2>/dev/null || echo "pro")
case "$PLAN" in
  max)  _budget=20000; PLAN_LABEL="Max" ;;
  pro)  _budget=11000; PLAN_LABEL="Pro" ;;
  free) _budget=5000;  PLAN_LABEL="Free" ;;
  *)    _budget=11000; PLAN_LABEL="Pro" ;;
esac

# Quick passive token cost estimate
# Only count plugins that are ACTIVE (detected as ON), not just installed
_passive_t=0
detect_superpowers 2>/dev/null && _passive_t=$((_passive_t + 800))

# Token costs for toggle plugins — map display name to cost
declare -A _plugin_costs=(
  [gstack]=2750
  [ui-ux-pro-max]=400
  [frontend-design]=200
  [plugin-dev]=100
  [context7]=200
  [ruflo]=1000
  [graphifyy]=300
)
for _p in "${TOGGLE_ACTIVE[@]}"; do
  _cost="${_plugin_costs[$_p]:-0}"
  _passive_t=$((_passive_t + _cost))
done
_budget_pct=$((_passive_t * 100 / _budget))
if [ "$_budget_pct" -gt 50 ]; then
  TOKEN_WARN="⚠️  ~${_passive_t}t passif (${_budget_pct}% budget $PLAN_LABEL)"
elif [ "$_budget_pct" -gt 25 ]; then
  TOKEN_WARN="~${_passive_t}t passif (${_budget_pct}% budget $PLAN_LABEL)"
else
  TOKEN_WARN=""
fi
unset _passive_t _budget_pct _budget

echo ""
echo "┌─ Claude Code config ──────────────────────────────────┐"
printf "│  ✅ ON  : %-40s│\n" "security-guidance rtk superpowers"
# Plugin display — all plugins shown, split across 2 lines if >4
_active_count=${#TOGGLE_ACTIVE[@]}
_inactive_count=${#TOGGLE_INACTIVE[@]}

if [ "$_active_count" -eq 0 ]; then
  printf "│  🟢 ON  : %-40s│\n" "none"
elif [ "$_active_count" -le 4 ]; then
  printf "│  🟢 ON  : %-40s│\n" "$ACTIVE_STR"
else
  # Split: first 4 on line 1, rest on continuation line
  _line1="${TOGGLE_ACTIVE[0]} ${TOGGLE_ACTIVE[1]} ${TOGGLE_ACTIVE[2]} ${TOGGLE_ACTIVE[3]}"
  _rest=("${TOGGLE_ACTIVE[@]:4}")
  _line2="${_rest[*]}"
  printf "│  🟢 ON  : %-40s│\n" "$_line1"
  printf "│             %-40s│\n" "$_line2"
  unset _line1 _line2 _rest
fi

if [ "$_inactive_count" -eq 0 ]; then
  printf "│  ⚫ OFF : %-40s│\n" "none"
elif [ "$_inactive_count" -le 4 ]; then
  printf "│  ⚫ OFF : %-40s│\n" "$INACTIVE_STR"
else
  _line1="${TOGGLE_INACTIVE[0]} ${TOGGLE_INACTIVE[1]} ${TOGGLE_INACTIVE[2]} ${TOGGLE_INACTIVE[3]}"
  _rest=("${TOGGLE_INACTIVE[@]:4}")
  _line2="${_rest[*]}"
  printf "│  ⚫ OFF : %-40s│\n" "$_line1"
  printf "│             %-40s│\n" "$_line2"
  unset _line1 _line2 _rest
fi
unset _active_count _inactive_count
printf "│  🖥️  CLI : %-40s│\n" "$GSD_STATUS"
[ -n "$TOKEN_WARN" ] && printf "│  💰 %-44s│\n" "${TOKEN_WARN:0:44}"
printf "│  📦 v%-45s│\n" "$CONFIG_VERSION"
# Version check: compare local vs remote (non-blocking)
_remote_ver=""
if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR/.git" ]; then
  _remote_ver=$(cd "$REPO_DIR" 2>/dev/null && git fetch origin --quiet 2>/dev/null && git show origin/master:version.txt 2>/dev/null || true)
fi
if [ -n "$_remote_ver" ] && [ "$_remote_ver" != "$CONFIG_VERSION" ]; then
  printf "│  🔄 update available: v%-27s│\n" "$_remote_ver"
fi
unset _remote_ver REPO_DIR

echo "│  💡 /plugin-check  before starting a new project  │"
echo "│  🩺 /health  to run full diagnostic               │"
echo "└───────────────────────────────────────────────────┘"
echo ""
unset TOKEN_WARN
