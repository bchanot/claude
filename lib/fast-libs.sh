#!/usr/bin/env bash
# fast-libs.sh — single source of truth for "fast-moving library" detection.
#
# Fast-moving = API churns faster than model training data (React, Next.js,
# Prisma…) → consult ctx7 (find-docs) before coding against it. Stable techs
# (C, C++98, POSIX sh, SQL…) never match: no ctx7 needed (BDR-078).
#
# Consumers: hooks/ctx7-reminder.sh, /ship-feature STEP 0c, /init-project
# STEP 5c, /onboard STEP 3.5, feater/bugfixer executor briefs.
#
# Verbs:
#   fast-libs.sh detect [dir]        detected libs, one/line; exit 1 if none
#   fast-libs.sh cache-status [dir]  fresh|stale|missing; exit 0 only if fresh

set -euo pipefail

# Exact npm dependency keys (unscoped). Anchored full-key match — "react"
# must not drag react-icons along.
NPM_EXACT='next|react|react-dom|react-native|expo|prisma|supabase'
NPM_EXACT+='|drizzle-orm|astro|svelte|vue|nuxt|tailwindcss|vite|next-auth'
NPM_EXACT+='|motion|framer-motion|ai|openai|langchain|remix|fastify'
# Scoped npm orgs (@org/…).
NPM_SCOPED='prisma|supabase|astrojs|sveltejs|tanstack|clerk|anthropic-ai'
NPM_SCOPED+='|langchain|remix-run|nestjs|tailwindcss'
# Python distributions (requirements.txt / pyproject.toml).
PY_LIBS='fastapi|pydantic|sqlalchemy|langchain'

CACHE_MAX_AGE_DAYS=7

npm_fast_libs() { # $1=dir — matching dependency keys, one per line
  [ -f "$1/package.json" ] || return 0
  jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' \
    "$1/package.json" 2>/dev/null \
    | grep -E "^(${NPM_EXACT})\$|^@(${NPM_SCOPED})/" || true
}

py_fast_libs() { # $1=dir — matching distributions, one per line
  grep -hoiE "\b(${PY_LIBS})\b" \
    "$1/requirements.txt" "$1/pyproject.toml" 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' | LC_ALL=C sort -u || true
}

detect() { # $1=dir — union, sorted unique; exit 1 when empty
  local libs
  # LC_ALL=C: deterministic order whatever the caller's locale.
  libs="$(printf '%s\n%s\n' "$(npm_fast_libs "$1")" "$(py_fast_libs "$1")" \
    | sed '/^$/d' | LC_ALL=C sort -u)"
  [ -n "$libs" ] || return 1
  printf '%s\n' "$libs"
}

cache_status() { # $1=dir — fresh|stale|missing; exit 0 only when fresh
  [ -d "$1/.ctx7-cache" ] || { echo missing; return 1; }
  if [ -n "$(find "$1/.ctx7-cache" -name '*.md' \
      -mtime "-${CACHE_MAX_AGE_DAYS}" -print -quit 2>/dev/null)" ]; then
    echo fresh; return 0
  fi
  echo stale; return 1
}

case "${1:-}" in
  detect)       detect "${2:-.}" ;;
  cache-status) cache_status "${2:-.}" ;;
  *) echo "usage: fast-libs.sh detect|cache-status [dir]" >&2; exit 2 ;;
esac
