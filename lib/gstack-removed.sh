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
