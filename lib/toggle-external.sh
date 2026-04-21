#!/usr/bin/env bash
# ============================================================
# lib/toggle-external.sh — enable/disable non-plugin tools
#
# Marketplace plugins are toggled by `claude plugin enable|disable`.
# Tools distributed outside the marketplace (gstack submodule, emil
# curl install, npx-installed skills) have no such lever — they live
# as symlinks inside skills/. This script moves those symlinks
# to/from skills-disabled/ so Claude Code stops/starts scanning them.
#
# Usage:
#   toggle-external.sh list
#   toggle-external.sh status <tool>
#   toggle-external.sh enable <tool>
#   toggle-external.sh disable <tool>
#
# Managed tools:
#   gstack            — per-skill symlinks populated by gstack's own setup
#   emil-design-eng   — single symlink → skills-external/emil-design-eng
#   darwin-skill      — single symlink → ~/.agents/skills/darwin-skill
#   find-skills       — single symlink → ~/.agents/skills/find-skills
# ============================================================
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
DISABLED_DIR="$REPO/skills-disabled"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

# All non-plugin tools this script can toggle.
MANAGED_TOOLS=(gstack emil-design-eng darwin-skill find-skills)

# Prints the names (directory basenames) that belong to "gstack".
# Source of truth: skills-external/gstack/*/SKILL.md. The repo's
# skills/<name> symlinks are generated from these by gstack ./setup.
gstack_skills() {
  local gstack_src="$REPO/skills-external/gstack"
  [ -d "$gstack_src" ] || return 0
  for d in "$gstack_src"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    basename "$d"
  done
}

# Prints "enabled" / "disabled" / "missing" for a tool.
status_tool() {
  local tool="$1"
  case "$tool" in
    gstack)
      [ -d "$REPO/skills-external/gstack" ] || { echo "missing"; return; }
      while read -r name; do
        [ -e "$SKILLS_DIR/$name" ] && { echo "enabled"; return; }
      done < <(gstack_skills)
      echo "disabled"
      ;;
    emil-design-eng)
      [ -d "$REPO/skills-external/emil-design-eng" ] || { echo "missing"; return; }
      [ -e "$SKILLS_DIR/emil-design-eng" ] && echo "enabled" || echo "disabled"
      ;;
    darwin-skill|find-skills)
      [ -d "$HOME/.agents/skills/$tool" ] || { echo "missing"; return; }
      [ -e "$SKILLS_DIR/$tool" ] && echo "enabled" || echo "disabled"
      ;;
    *)
      echo "unknown"; return 1 ;;
  esac
}

disable_tool() {
  local tool="$1"
  mkdir -p "$DISABLED_DIR"
  case "$tool" in
    gstack)
      local moved=0
      while read -r name; do
        [ -e "$SKILLS_DIR/$name" ] || continue
        mv "$SKILLS_DIR/$name" "$DISABLED_DIR/gstack__$name"
        moved=$((moved + 1))
      done < <(gstack_skills)
      ok "gstack disabled ($moved symlinks moved)"
      ;;
    emil-design-eng|darwin-skill|find-skills)
      if [ -e "$SKILLS_DIR/$tool" ]; then
        mv "$SKILLS_DIR/$tool" "$DISABLED_DIR/$tool"
        ok "$tool disabled"
      else
        warn "$tool already disabled"
      fi
      ;;
    *) err "Unknown tool: $tool"; return 1 ;;
  esac
}

enable_tool() {
  local tool="$1"
  case "$tool" in
    gstack)
      local moved=0
      if [ -d "$DISABLED_DIR" ]; then
        for entry in "$DISABLED_DIR"/gstack__*; do
          [ -e "$entry" ] || continue
          local name
          name="$(basename "$entry" | sed 's/^gstack__//')"
          mv "$entry" "$SKILLS_DIR/$name"
          moved=$((moved + 1))
        done
      fi
      if [ "$moved" -eq 0 ]; then
        warn "gstack was not disabled — re-run gstack setup to (re)create symlinks"
      else
        ok "gstack enabled ($moved symlinks restored)"
      fi
      ;;
    emil-design-eng|darwin-skill|find-skills)
      if [ -e "$DISABLED_DIR/$tool" ]; then
        mv "$DISABLED_DIR/$tool" "$SKILLS_DIR/$tool"
        ok "$tool enabled"
      elif [ -e "$SKILLS_DIR/$tool" ]; then
        warn "$tool already enabled"
      else
        err "$tool not installed — run: make plugin"
        return 1
      fi
      ;;
    *) err "Unknown tool: $tool"; return 1 ;;
  esac
}

list_all() {
  printf "%-20s %s\n" "TOOL" "STATUS"
  printf "%-20s %s\n" "----" "------"
  for t in "${MANAGED_TOOLS[@]}"; do
    printf "%-20s %s\n" "$t" "$(status_tool "$t")"
  done
}

usage() {
  sed -n '3,23p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    list)    list_all ;;
    status)  [ $# -ge 2 ] || usage 1; status_tool "$2" ;;
    enable)  [ $# -ge 2 ] || usage 1; enable_tool "$2" ;;
    disable) [ $# -ge 2 ] || usage 1; disable_tool "$2" ;;
    ""|-h|--help|help) usage 0 ;;
    *) err "Unknown command: $cmd"; usage 1 ;;
  esac
}

main "$@"
