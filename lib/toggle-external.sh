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
# A multi-skill pack (gstack, 21st) toggles all of its skills at once.
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
#   21st              — 21st.dev skill pack (needs the `21st` CLI + login)
#
# For fine-grained activation (only design skills, only qa skills, only
# audit skills, etc.) instead of all-or-nothing gstack toggling, use:
#   bash lib/profile.sh list
#   bash lib/profile.sh set <design|dev|qa|audit|minimal>
#   bash lib/profile.sh reset
# ============================================================
set -euo pipefail

REPO="${TOGGLE_EXTERNAL_REPO_OVERRIDE:-$(cd -P "$(dirname "$0")/.." && pwd)}"
SKILLS_DIR="$REPO/skills"
DISABLED_DIR="$REPO/skills-disabled"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

# All non-plugin tools this script can toggle.
MANAGED_TOOLS=(gstack emil-design-eng darwin-skill 21st)

# Prints the skill names that belong to the "21st" pack. Source of truth:
# skills-external/21st-* — the `21st skills install` run in install-plugins.sh
# owns that list, so adding a skill upstream needs no edit here.
twentyfirst_skills() {
  local d
  for d in "$REPO"/skills-external/21st-*/; do
    [ -f "${d}SKILL.md" ] || continue
    basename "$d"
  done
}

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
    darwin-skill)
      [ -d "$HOME/.agents/skills/$tool" ] || { echo "missing"; return; }
      [ -e "$SKILLS_DIR/$tool" ] && echo "enabled" || echo "disabled"
      ;;
    21st)
      local installed=0
      while read -r name; do
        installed=1
        [ -e "$SKILLS_DIR/$name" ] && { echo "enabled"; return; }
      done < <(twentyfirst_skills)
      [ "$installed" -eq 1 ] && echo "disabled" || echo "missing"
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
        # Clobber any stale destination. gstack ./setup now creates
        # skills/<name>/ as directories, so mv onto an existing dir
        # would nest it (gstack__<name>/<name>/) instead of renaming.
        # Content is symlinks to the submodule — `gstack ./setup` regenerates.
        rm -rf "$DISABLED_DIR/gstack__$name"
        mv "$SKILLS_DIR/$name" "$DISABLED_DIR/gstack__$name"
        moved=$((moved + 1))
      done < <(gstack_skills)
      ok "gstack disabled ($moved symlinks moved)"
      ;;
    emil-design-eng|darwin-skill)
      if [ -e "$SKILLS_DIR/$tool" ]; then
        rm -rf "${DISABLED_DIR:?}/${tool:?}"
        mv "$SKILLS_DIR/$tool" "$DISABLED_DIR/$tool"
        ok "$tool disabled"
      else
        warn "$tool already disabled"
      fi
      ;;
    21st)
      # Parked under the plain skill name — same convention as the other
      # externals, so profile.sh's park/restore path stays interoperable.
      local parked=0
      while read -r name; do
        [ -e "$SKILLS_DIR/$name" ] || continue
        rm -rf "${DISABLED_DIR:?}/${name:?}"
        mv "$SKILLS_DIR/$name" "$DISABLED_DIR/$name"
        parked=$((parked + 1))
      done < <(twentyfirst_skills)
      if [ "$parked" -gt 0 ]; then
        ok "21st disabled ($parked skills parked)"
      else
        warn "21st already disabled"
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
          rm -rf "${SKILLS_DIR:?}/${name:?}"
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
    emil-design-eng|darwin-skill)
      local src
      case "$tool" in
        emil-design-eng) src="$REPO/skills-external/$tool" ;;
        darwin-skill) src="$HOME/.agents/skills/$tool" ;;
      esac
      if [ -e "$DISABLED_DIR/$tool" ]; then
        rm -rf "${SKILLS_DIR:?}/${tool:?}"
        mv "$DISABLED_DIR/$tool" "$SKILLS_DIR/$tool"
        ok "$tool enabled"
      elif [ -e "$SKILLS_DIR/$tool" ]; then
        warn "$tool already enabled"
      elif [ -d "$src" ]; then
        ln -sf "$src" "$SKILLS_DIR/$tool"
        ok "$tool enabled (symlink created → $src)"
      else
        err "$tool not installed at $src — run: make plugin"
        return 1
      fi
      ;;
    21st)
      local restored=0 linked=0
      while read -r name; do
        if [ -e "$DISABLED_DIR/$name" ]; then
          rm -rf "${SKILLS_DIR:?}/${name:?}"
          mv "$DISABLED_DIR/$name" "$SKILLS_DIR/$name"
          restored=$((restored + 1))
        elif [ -e "$SKILLS_DIR/$name" ]; then
          : # already enabled
        else
          ln -sf "$REPO/skills-external/$name" "$SKILLS_DIR/$name"
          linked=$((linked + 1))
        fi
      done < <(twentyfirst_skills)
      if [ "$((restored + linked))" -eq 0 ]; then
        if [ "$(status_tool 21st)" = "missing" ]; then
          err "21st pack not installed in $REPO/skills-external — run: make plugin"
          return 1
        fi
        warn "21st already enabled"
        return 0
      fi
      ok "21st enabled ($((restored + linked)) skills: $restored restored, $linked linked)"
      # The skills shell out to the CLI; without it (or without a session)
      # they can only report failure. Warn, never block — the pack is still
      # correctly wired and `make plugin` installs the CLI.
      if ! command -v 21st >/dev/null 2>&1; then
        warn "the \`21st\` CLI is not on PATH — install it: npm i -g @21st-dev/cli"
      elif ! 21st whoami 2>/dev/null | grep -q '^Logged in as '; then
        warn "not signed in to 21st — component retrieval and 21st AI need: 21st login"
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
