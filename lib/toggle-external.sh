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
# A multi-skill pack (gstack, 21st, higgsfield) toggles all of its skills
# at once.
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
#   higgsfield        — Higgsfield media pack (needs the `higgsfield` CLI)
#   higgsfield-websites — single skill, landing-page aid (named ask only)
#   observability-and-instrumentation, deprecation-and-migration,
#   ci-cd-and-automation — the agent-skills trio, same single-symlink shape
#   as emil-design-eng (commit-pinned instead of main-branch tracking)
#   scroll-world-storytelling, build-threejs-scroll-worlds,
#   scroll-scrubbed-visual-sequence, scroll-scrubbed-word-reveal,
#   scroll-progress-timeline — the Mengto scroll skills, same shape
#
# For fine-grained activation (only design skills, only qa skills, only
# audit skills, etc.) instead of all-or-nothing gstack toggling, use:
#   bash lib/profile.sh list
#   bash lib/profile.sh set <design|dev|qa|audit|minimal>
#   bash lib/profile.sh reset       # back to the default profile (full)
# ============================================================
set -euo pipefail

REPO="${TOGGLE_EXTERNAL_REPO_OVERRIDE:-$(cd -P "$(dirname "$0")/.." && pwd)}"
SKILLS_DIR="$REPO/skills"
DISABLED_DIR="$REPO/skills-disabled"

# GSTACK_REMOVED + gstack_is_removed() — single source, honored by the
# `enable gstack` loop below. Resolved from $0 like REPO above, not from
# $REPO/lib — gstack-removed.sh sits next to this file wherever it runs.
# shellcheck source=lib/gstack-removed.sh disable=SC1091
source "$(dirname "$0")/gstack-removed.sh"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

# All non-plugin tools this script can toggle.
MANAGED_TOOLS=(gstack emil-design-eng darwin-skill 21st higgsfield
  higgsfield-websites
  observability-and-instrumentation deprecation-and-migration ci-cd-and-automation
  scroll-world-storytelling build-threejs-scroll-worlds
  scroll-scrubbed-visual-sequence scroll-scrubbed-word-reveal
  scroll-progress-timeline)

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

# Media skills of the "higgsfield" pack: an explicit allowlist. Upstream is
# unpinned, so a skill it adds or renames must never be linked by
# `enable higgsfield` without an edit here (default deny).
# higgsfield-websites is its own tool: landing-page aid, named ask only.
HIGGSFIELD_MEDIA_SKILLS=(higgsfield-generate higgsfield-soul-id
  higgsfield-product-photoshoot higgsfield-brandkit
  higgsfield-marketplace-cards higgsfield-video-explainer
  higgsfield-youtube-thumbnail)

# Prints the allowlisted media skills synced under skills-external/.
higgsfield_skills() {
  local name
  for name in "${HIGGSFIELD_MEDIA_SKILLS[@]}"; do
    [ -f "$REPO/skills-external/$name/SKILL.md" ] && echo "$name"
  done
  return 0
}

# Prints the synced higgsfield-* skills no tool owns: neither on the media
# allowlist nor higgsfield-websites. Upstream added or renamed something.
higgsfield_unlisted() {
  local d name
  for d in "$REPO"/skills-external/higgsfield-*/; do
    [ -f "${d}SKILL.md" ] || continue
    name="$(basename "$d")"
    case " ${HIGGSFIELD_MEDIA_SKILLS[*]} higgsfield-websites " in
      *" $name "*) ;;
      *) echo "$name" ;;
    esac
  done
}

# Prints the member skills of a multi-skill pack tool (21st, higgsfield).
pack_skills() {
  case "$1" in
    21st)       twentyfirst_skills ;;
    higgsfield) higgsfield_skills ;;
  esac
}

# bounded <cmd...> — run a CLI probe silently, 15 s at most when `timeout`
# exists: a closed-source binary must never hang a toggle, and what it
# prints (a token) must never reach the terminal. Twin of
# _higgsfield_probe in lib/higgsfield-skills.sh, kept here because this
# script takes no extra `source` (the fixture suites copy it alone).
bounded() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 15 "$@" </dev/null >/dev/null 2>&1
  else
    "$@" </dev/null >/dev/null 2>&1
  fi
}

# Post-enable notes for a pack. Its skills shell out to a CLI: without it
# (or without a session) they can only report failure. Warn, never block:
# the pack is still correctly wired and `make plugin` installs the CLI.
pack_hints() {
  local name
  case "$1" in
    21st)
      if ! command -v 21st >/dev/null 2>&1; then
        warn "the \`21st\` CLI is not on PATH — install it: npm i -g @21st-dev/cli"
      elif ! 21st whoami 2>/dev/null | grep -q '^Logged in as '; then
        warn "not signed in to 21st — component retrieval and 21st AI need: 21st login"
      fi
      ;;
    higgsfield)
      if ! command -v higgsfield >/dev/null 2>&1; then
        warn "the \`higgsfield\` CLI is not on PATH — run: make plugin"
      elif ! bounded higgsfield version; then
        warn "the \`higgsfield\` CLI does not answer (npm shim without its binary) — run: make plugin"
      elif ! bounded higgsfield auth token; then
        warn "not signed in to Higgsfield — generation needs: higgsfield auth login"
      fi
      while read -r name; do
        warn "$name is synced but on no allowlist, not linked — see HIGGSFIELD_MEDIA_SKILLS in lib/toggle-external.sh"
      done < <(higgsfield_unlisted)
      ;;
  esac
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
    emil-design-eng|observability-and-instrumentation|deprecation-and-migration|ci-cd-and-automation| \
    scroll-world-storytelling|build-threejs-scroll-worlds|scroll-scrubbed-visual-sequence| \
    scroll-scrubbed-word-reveal|scroll-progress-timeline|higgsfield-websites)
      [ -d "$REPO/skills-external/$tool" ] || { echo "missing"; return; }
      [ -e "$SKILLS_DIR/$tool" ] && echo "enabled" || echo "disabled"
      ;;
    darwin-skill)
      [ -d "$HOME/.agents/skills/$tool" ] || { echo "missing"; return; }
      [ -e "$SKILLS_DIR/$tool" ] && echo "enabled" || echo "disabled"
      ;;
    21st|higgsfield)
      local installed=0
      while read -r name; do
        installed=1
        [ -e "$SKILLS_DIR/$name" ] && { echo "enabled"; return; }
      done < <(pack_skills "$tool")
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
    emil-design-eng|darwin-skill|observability-and-instrumentation|deprecation-and-migration| \
    ci-cd-and-automation|scroll-world-storytelling|build-threejs-scroll-worlds| \
    scroll-scrubbed-visual-sequence|scroll-scrubbed-word-reveal|scroll-progress-timeline| \
    higgsfield-websites)
      if [ -e "$SKILLS_DIR/$tool" ]; then
        rm -rf "${DISABLED_DIR:?}/${tool:?}"
        mv "$SKILLS_DIR/$tool" "$DISABLED_DIR/$tool"
        ok "$tool disabled"
      else
        warn "$tool already disabled"
      fi
      ;;
    21st|higgsfield)
      # Parked under the plain skill name — same convention as the other
      # externals, so profile.sh's park/restore path stays interoperable.
      local parked=0
      while read -r name; do
        [ -e "$SKILLS_DIR/$name" ] || continue
        rm -rf "${DISABLED_DIR:?}/${name:?}"
        mv "$SKILLS_DIR/$name" "$DISABLED_DIR/$name"
        parked=$((parked + 1))
      done < <(pack_skills "$tool")
      if [ "$parked" -gt 0 ]; then
        ok "$tool disabled ($parked skills parked)"
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
      local moved=0 skipped=0
      if [ -d "$DISABLED_DIR" ]; then
        for entry in "$DISABLED_DIR"/gstack__*; do
          [ -e "$entry" ] || continue
          local name
          name="$(basename "$entry" | sed 's/^gstack__//')"
          if gstack_is_removed "$name"; then
            warn "skipped (removed by policy, lib/gstack-removed.sh): $name"
            skipped=$((skipped + 1))
            continue
          fi
          rm -rf "${SKILLS_DIR:?}/${name:?}"
          mv "$entry" "$SKILLS_DIR/$name"
          moved=$((moved + 1))
        done
      fi
      if [ "$moved" -eq 0 ] && [ "$skipped" -ge 1 ]; then
        warn "only policy-removed skills remain parked (lib/gstack-removed.sh)"
      elif [ "$moved" -eq 0 ]; then
        warn "gstack was not disabled — re-run gstack setup to (re)create symlinks"
      else
        ok "gstack enabled ($moved symlinks restored)"
      fi
      ;;
    emil-design-eng|darwin-skill|observability-and-instrumentation|deprecation-and-migration| \
    ci-cd-and-automation|scroll-world-storytelling|build-threejs-scroll-worlds| \
    scroll-scrubbed-visual-sequence|scroll-scrubbed-word-reveal|scroll-progress-timeline| \
    higgsfield-websites)
      local src
      case "$tool" in
        darwin-skill) src="$HOME/.agents/skills/$tool" ;;
        *) src="$REPO/skills-external/$tool" ;;
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
      if [ "$tool" = "higgsfield-websites" ]; then pack_hints higgsfield; fi
      ;;
    21st|higgsfield)
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
      done < <(pack_skills "$tool")
      if [ "$((restored + linked))" -eq 0 ]; then
        if [ "$(status_tool "$tool")" = "missing" ]; then
          err "$tool pack not installed in $REPO/skills-external — run: make plugin"
          return 1
        fi
        warn "$tool already enabled"
        return 0
      fi
      ok "$tool enabled ($((restored + linked)) skills: $restored restored, $linked linked)"
      pack_hints "$tool"
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
  sed -n '3,26p' "$0" | sed 's/^# \?//'
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
