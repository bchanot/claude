#!/usr/bin/env bash
# ============================================================
# lib/gstack-links.sh — shared gstack helper-tree linker
#
# gstack skills hardcode `~/.claude/skills/gstack/<path>` for shared
# assets (bin/, browse/dist/, design/dist/, lib/diagram-render/dist/,
# ETHOS.md, scripts/jargon-list.json, freeze/bin/, */sections/*.md,
# review/checklist.md + specialists/, …) that per-skill SKILL.md
# symlinks never expose (BDR-030 links gstack skills individually).
# `link_gstack_helpers()` walks the submodule ONCE and mirrors every one
# of those assets under <dst>, so make-pdf, diagram, the freeze hook,
# cso/plan-*-review sections etc. actually resolve — before this, only
# bin/ and browse/dist/ were hand-linked and everything else returned
# *_NOT_AVAILABLE or exited 127 (LRN-096 class).
#
# A skill dir (one holding its own SKILL.md, e.g. review/, careful/) is
# mirrored child-by-child with SKILL.md excluded — <dst> must never
# expose a SKILL.md at ANY depth, or skill discovery lists gstack/<name>
# as a duplicate entry alongside the individually-linked skill. A
# non-skill dir that HOLDS a nested SKILL.md somewhere below it
# (browser-skills/, openclaw/ — vendored/generated content, not a gstack
# asset) is skipped whole: mirroring it would expose that nested
# SKILL.md through <dst> too. `.git*` and `node_modules` are skipped by
# name (vcs metadata / vendored deps, never worth walking).
#
# Sourced by link.sh, install-plugins.sh (Step 2) and update-all.sh — the
# same block used to be hand-duplicated in all three (three divergent
# copies, one of them `ln -sf` without `-n` — nests src/bin/bin on a
# re-run — criterion 18 forbids the duplication now).
#
# No `set -e` (mirrors lib/vendor-skills.sh): a sourced lib must not
# change the caller's shell options.
# ============================================================

# Fallback color helpers when sourced standalone (hermetic test suite) —
# every diagnostic call below is explicitly redirected to stderr (>&2) so
# `n=$(link_gstack_helpers …)` captures ONLY the final link count,
# whichever ok/warn/info implementation (caller's or this fallback) runs.
if ! declare -F ok >/dev/null 2>&1; then
  GREEN='\033[0;32m'; NC='\033[0m'
  ok() { echo -e "${GREEN}✓${NC} $1"; }
fi
if ! declare -F warn >/dev/null 2>&1; then
  YELLOW='\033[1;33m'; NC='\033[0m'
  warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
fi
if ! declare -F info >/dev/null 2>&1; then
  BLUE='\033[0;34m'; NC='\033[0m'
  info() { echo -e "${BLUE}→${NC} $1"; }
fi

# _gstack_links_guard_dst <src> <dst> — removes a stale <dst> symlink
# (gstack ./setup plants `skills/gstack -> skills-external/gstack` when
# the dir is absent), refuses ever writing INTO <src> (dst resolving
# inside src), then ensures <dst> exists as a real dir. rc 1 on the
# write-into-src guard; nothing is created in that case.
_gstack_links_guard_dst() {
  local src="$1" dst="$2" real_src real_dst
  if [ -L "$dst" ]; then
    info "removing stale gstack symlink: $dst" >&2
    rm -f "$dst"
  fi
  real_src="$(realpath "$src")"
  real_dst="$(realpath -m "$dst")"
  case "$real_dst" in
    "$real_src"/*|"$real_src")
      warn "refusing to write into the gstack submodule: $dst" >&2
      return 1
      ;;
  esac
  mkdir -p "$dst"
}

# _gstack_links_skip_entry <name> — true iff a top-level entry is never
# mirrored by name alone (vcs metadata, vendored deps, the top-level
# SKILL.md itself).
_gstack_links_skip_entry() {
  case "$1" in
    .git*|node_modules|SKILL.md) return 0 ;;
    *) return 1 ;;
  esac
}

# _gstack_links_skill_dir <src_entry> <dst_dir> — mirrors a gstack skill
# dir (one that holds its own SKILL.md) child-by-child, SKILL.md
# excluded. Echoes the count of links freshly created (idempotent on a
# re-run: an already-correct symlink is not recounted).
_gstack_links_skill_dir() {
  local entry="$1" dst_dir="$2" child base n=0
  mkdir -p "$dst_dir"
  for child in "$entry"/*; do
    [ -e "$child" ] || continue
    base="$(basename "$child")"
    [ "$base" = "SKILL.md" ] && continue
    if [ ! -L "$dst_dir/$base" ] \
      || [ "$(readlink "$dst_dir/$base")" != "$child" ]; then
      n=$((n + 1))
    fi
    ln -sfn "$child" "$dst_dir/$base"
  done
  echo "$n"
}

# _gstack_links_top_entry <src_entry> <dst_entry> — links ONE top-level
# src entry into dst: mirror child-by-child if it is a skill dir, skip
# whole if it is a non-skill dir hiding a nested SKILL.md, else a single
# whole-entry symlink (file or clean non-skill dir). Echoes the count of
# links freshly created.
_gstack_links_top_entry() {
  local src_entry="$1" dst_entry="$2" n=0
  if [ -d "$src_entry" ] && [ -f "$src_entry/SKILL.md" ]; then
    n=$(_gstack_links_skill_dir "$src_entry" "$dst_entry")
  elif [ -d "$src_entry" ] \
    && [ -n "$(find -L "$src_entry" -name SKILL.md -print -quit)" ]; then
    info "skipped $(basename "$src_entry") (nested SKILL.md, not a \
gstack asset)" >&2
  else
    if [ ! -L "$dst_entry" ] \
      || [ "$(readlink "$dst_entry")" != "$src_entry" ]; then
      n=1
    fi
    ln -sfn "$src_entry" "$dst_entry"
  fi
  echo "$n"
}

# link_gstack_helpers <src> <dst> — mirrors every gstack shared asset
# under <src> (the skills-external/gstack submodule) into <dst>
# (normally ~/.claude/skills/gstack), idempotent (ln -sfn), never
# exposing a SKILL.md at any depth under <dst>. Echoes the total link
# count freshly created THIS run on stdout (add it to the caller's
# CHANGED counter); prints one ok/warn summary on stderr. rc 1 (echoing
# 0) iff <dst> resolves inside <src> — nothing is created in that case.
link_gstack_helpers() {
  local src="$1" dst="$2" entry base total=0 n
  _gstack_links_guard_dst "$src" "$dst" || { echo 0; return 1; }
  for entry in "$src"/*; do
    [ -e "$entry" ] || continue
    base="$(basename "$entry")"
    _gstack_links_skip_entry "$base" && continue
    n=$(_gstack_links_top_entry "$entry" "$dst/$base")
    total=$((total + n))
  done
  if [ "$total" -gt 0 ]; then
    ok "gstack helper tree: $total link(s) created under $dst" >&2
  else
    ok "gstack helper tree up to date ($dst)" >&2
  fi
  echo "$total"
}
