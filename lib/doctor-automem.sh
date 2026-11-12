#!/usr/bin/env bash
# ============================================================
# lib/doctor-automem.sh — doctor.sh's auto-memory leftover check
#
# settings.json sets "autoMemoryEnabled": false (BDR-125 phase 1): Claude
# Code no longer reads ~/.claude/projects/<slug>/memory/, so a file left
# there is knowledge nobody loads. `automem_leftover_dirs <projects_dir>`
# prints how many <slug>/memory dirs hold at least one file and ALWAYS
# exits 0 (doctor.sh runs under `set -euo pipefail`; an absent dir is 0).
#
# No `set -euo pipefail` here: a sourced lib must not change the caller's
# shell options.
# ============================================================

# automem_leftover_dirs <projects_dir> — see file header.
automem_leftover_dirs() {
  local d n=0
  for d in "$1"/*/memory; do
    [ -d "$d" ] || continue
    if [ -n "$(find "$d" -type f -print -quit 2>/dev/null)" ]; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}
