#!/usr/bin/env bash
# ============================================================
# lib/higgsfield-skills.sh — Higgsfield skill pack sync + CLI probes
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

# _higgsfield_adopt <clone> <dest>
# Move every real higgsfield-*/ directory of the clone that holds a SKILL.md
# over its copy in <dest>; prints how many landed. A symlinked entry is
# skipped: only upstream's own directories are adopted. A skill counts only
# once its move succeeded.
_higgsfield_adopt() {
  local clone="$1" dest="$2" dir name count=0
  for dir in "$clone"/higgsfield-*/; do
    dir="${dir%/}"
    { [ -f "$dir/SKILL.md" ] && [ ! -L "$dir" ]; } || continue
    name="$(basename "$dir")"
    rm -rf "${dest:?}/${name:?}" && mv "$dir" "$dest/$name" \
      && count=$((count + 1))
  done
  echo "$count"
}

# higgsfield_sync_skills <repo>
# Clone upstream into a stage and replace each
# <repo>/skills-external/higgsfield-* with the fresh copy; upstream's own
# machinery (setup, scripts/, plugin manifests, .git) stays in the stage.
# The stage sits next to the destination, on the same filesystem, so each
# replacement is a rename. Prints the number of skills synced. Returns 1,
# existing copies untouched, when the clone fails or upstream holds no
# higgsfield-*/SKILL.md. A parked skill (skills-disabled/<name>, a symlink
# to the source path) stays parked. Known limit: a skill that upstream
# removes or renames keeps its last local copy.
higgsfield_sync_skills() {
  local dest="$1/skills-external" stage count=0
  mkdir -p "$dest" || return 1
  stage="$(mktemp -d "$dest/.higgsfield-stage.XXXXXX")" || return 1
  # No credential prompt: a private or deleted upstream must fail, not hang.
  if GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 \
      "$HIGGSFIELD_SKILLS_URL" "$stage/src" >/dev/null 2>&1; then
    count="$(_higgsfield_adopt "$stage/src" "$dest")"
  fi
  rm -rf "${stage:?}"
  echo "$count"
  [ "$count" -gt 0 ]
}

# _higgsfield_probe <args...>
# Run `higgsfield <args>` silently, 15 s at most when `timeout` exists. The
# CLI is closed source: a probe must never hang an installer, and what it
# prints (a token, for `auth token`) must never reach a terminal or a log.
_higgsfield_probe() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 15 higgsfield "$@" </dev/null >/dev/null 2>&1
  else
    higgsfield "$@" </dev/null >/dev/null 2>&1
  fi
}

# higgsfield_cli_ok — 0 when the binary answers. `command -v` alone only
# proves the npm shim: the binary is vendored by a postinstall script that
# npm may hold back, on a first install or on any later update.
higgsfield_cli_ok() { _higgsfield_probe version; }

# higgsfield_signed_in — 0 when the CLI holds a session.
higgsfield_signed_in() { _higgsfield_probe auth token; }
