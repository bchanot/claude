#!/usr/bin/env bash
# ============================================================
# lib/higgsfield-skills.sh — Higgsfield skill pack sync + session probe
#
# Sourced by install-plugins.sh (Step 8.6), update-all.sh (7.3b) and
# doctor.sh. The pack is machine-owned: cloned from upstream and moved
# into skills-external/higgsfield-* (gitignored), then linked on demand by
# lib/toggle-external.sh. It is listed in neither link.sh nor any profile:
# either would re-enable a parked pack on every run (BDR-093).
# ============================================================

# Upstream skills repo, single source for both installers. An env value
# wins so the hermetic suite can point it at a local fixture repo.
HIGGSFIELD_SKILLS_URL="${HIGGSFIELD_SKILLS_URL:-\
https://github.com/higgsfield-ai/skills.git}"

# higgsfield_sync_skills <repo>
# Clone upstream into a throwaway stage and replace each
# <repo>/skills-external/higgsfield-* with the fresh copy; upstream's own
# machinery (setup, scripts/, plugin manifests, .git) is left in the stage.
# Prints the number of skills synced. Returns 1, existing copies untouched,
# when the clone fails or upstream holds no higgsfield-*/SKILL.md. A parked
# skill (skills-disabled/<name>, a symlink to the source path) stays parked.
higgsfield_sync_skills() {
  local repo="$1" stage dir name count=0
  stage="$(mktemp -d)" || return 1
  if git clone --quiet --depth 1 "$HIGGSFIELD_SKILLS_URL" "$stage/src" \
      >/dev/null 2>&1; then
    mkdir -p "$repo/skills-external"
    for dir in "$stage"/src/higgsfield-*/; do
      [ -f "${dir}SKILL.md" ] || continue
      name="$(basename "$dir")"
      rm -rf "${repo:?}/skills-external/${name:?}"
      mv "$dir" "$repo/skills-external/$name"
      count=$((count + 1))
    done
  fi
  rm -rf "${stage:?}"
  echo "$count"
  [ "$count" -gt 0 ]
}

# higgsfield_signed_in — 0 when the CLI holds a session. The CLI is closed
# source, so whether `auth token` stays local is unverified: bound it when
# `timeout` exists, feed it no stdin, and never let the token reach a
# terminal or a log.
higgsfield_signed_in() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 15 higgsfield auth token </dev/null >/dev/null 2>&1
  else
    higgsfield auth token </dev/null >/dev/null 2>&1
  fi
}
