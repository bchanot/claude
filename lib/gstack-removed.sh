#!/usr/bin/env bash
# ============================================================
# lib/gstack-removed.sh — the gstack skills this config never exposes
#
# The denylist itself lives in gstack-removed.list (one name per line),
# read here into GSTACK_REMOVED and by lib/pack-census.sh. A name listed is
# in no pack and no profile, `max` included. Pruned 2026-09-28 (BDR-105),
# helpers housed here per BDR-117, retired with the symlink toggling.
# Why each name went:
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
# No `set -euo pipefail` here (sourced lib).
# ============================================================

mapfile -t GSTACK_REMOVED < "$(dirname "${BASH_SOURCE[0]}")/gstack-removed.list"
