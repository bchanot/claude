#!/usr/bin/env bash
# ============================================================
# lib/gstack-removed.sh — the gstack skills this config never exposes
#
# Single source for the denylist. Sourced by lib/profile.sh
# (enable_all_gstack, enable_skill) and lib/toggle-external.sh
# (`enable gstack`), read by lib/tests/profile-census.test.sh. A name
# listed here is in no profile, `max` included, and every "bring gstack
# back" path skips it. Decided 2026-09-28 (skill-catalog prune, user go):
#
#   ship             base = origin/HEAD = main on Gitea, skips develop
#   land-and-deploy  `gh pr merge --squash --delete-branch` then deploys
#   setup-deploy     companion of land-and-deploy (Claude never deploys)
#   autoplan         reads ~/.claude/skills/gstack/plan-*/ paths that do
#                    not exist in this install
#   context-save     its pair context-restore is not linked; never used
#   learn            parallel JSONL store outside .claude/memory, unused
#   careful, guard   hooks exit 127 (missing bin path) — vacuous; the
#                    house permissions.deny is stricter (BDR-095)
#   design-shotgun   mockups need OPENAI_API_KEY, absent
#
# Also hosts the gstack helpers the two scripts share (gstack_skills and
# the park/unpark moves below). They live in this file because it is the
# only one the fixture suites copy next to profile.sh / toggle-external.sh:
# a new sourced file would be missing there. Each takes its directories as
# arguments (no reliance on the caller's globals).
#
# No `set -euo pipefail` here (sourced lib, mirrors lib/detect-plugins.sh).
# ============================================================

GSTACK_REMOVED=(ship land-and-deploy setup-deploy autoplan context-save
  learn careful guard design-shotgun)

# gstack_is_removed <name> — exit 0 when <name> is on the denylist.
gstack_is_removed() {
  local name="$1" entry
  for entry in "${GSTACK_REMOVED[@]}"; do
    [ "$entry" = "$name" ] && return 0
  done
  return 1
}

# gstack_skills <gstack_src> — prints the directory basenames under
# <gstack_src>/*/ that hold a SKILL.md; nothing when the dir is absent.
# Source of truth for "which skills belong to gstack".
gstack_skills() {
  local src="$1" d
  [ -d "$src" ] || return 0
  for d in "$src"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    basename "$d"
  done
}

# gstack_parked_names <disabled_dir> — prints <name> for every
# <disabled_dir>/gstack__<name> entry (a dangling symlink is skipped).
gstack_parked_names() {
  local entry
  [ -d "$1" ] || return 0
  for entry in "$1"/gstack__*; do
    [ -e "$entry" ] || continue
    basename "$entry" | sed 's/^gstack__//'
  done
}

# gstack_park <skills_dir> <disabled_dir> <name> — moves skills/<name> to
# skills-disabled/gstack__<name>. A stale destination is clobbered first:
# gstack ./setup creates skills/<name>/ as directories, so mv onto an
# existing dir would nest it (gstack__<name>/<name>/) instead of renaming.
# Content is symlinks to the submodule, `gstack ./setup` regenerates it.
# Call as a plain statement (never `|| …`, `if`, `!`): errexit must stay on.
gstack_park() {
  local skills_dir="$1" disabled_dir="$2" name="$3"
  rm -rf "$disabled_dir/gstack__$name"
  mv "$skills_dir/$name" "$disabled_dir/gstack__$name"
}

# gstack_unpark <skills_dir> <disabled_dir> <name> — moves
# skills-disabled/gstack__<name> back to skills/<name>, replacing whatever
# sits there. Same plain-statement rule as gstack_park.
gstack_unpark() {
  local skills_dir="$1" disabled_dir="$2" name="$3"
  rm -rf "${skills_dir:?}/${name:?}"
  mv "$disabled_dir/gstack__$name" "$skills_dir/$name"
}
