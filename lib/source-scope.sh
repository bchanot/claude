#!/usr/bin/env bash
# Emit the directory exclusions that separate SOURCE from BUILD OUTPUT.
#
#   EXCL="$(bash ~/.claude/lib/source-scope.sh grep)"
#   grep -rl "gtag" $EXCL --include="*.html" .          # note: $EXCL unquoted
#
#   mapfile -t FEXCL < <(bash ~/.claude/lib/source-scope.sh findargs)
#   find . "${FEXCL[@]}" -iname '*.jpg' -printf '%s %p\n'   # quoted array!
#
# findargs emits ONE TOKEN PER LINE and MUST be consumed through a quoted
# array. A flat string does not work: `find . $FEXCL ...` lets the shell glob
# `*/dist/*` against the CWD before find ever sees it, and the matches are then
# passed as search PATHS. Measured on zenquality: that turned 90 hits into 135
# and kept every dist/ file. The array form passes each token literally.
#
# WHY: grep and find disagree about what is in the repo, and seo-analyzer uses
# both.
#
#   grep  → Claude Code installs a shell function routing grep to ugrep with
#           `--ignore-files`, i.e. .gitignore-aware. A gitignored dist/ is
#           invisible to it when recursing from `.`. Verified 2026-07-17.
#   find  → knows nothing about .gitignore. It sees everything.
#
# So on zenquality (Astro, dist/ gitignored, built locally) the spec's image
# audit at seo-analyzer.md:497 returns 92 images of which 45 live in dist/ —
# every asset listed twice, source and generated copy, identical bytes. Two
# real consequences:
#   1. "top 20 by size" is half generated duplicates: ~10 real images audited
#      while 20 are claimed.
#   2. Batch C (`cwebp -q 80 <img> -o <img>.webp`) can target dist/og-image.png.
#      The .webp lands in dist/ and the `npm run build` that /seo runs to VERIFY
#      the fix erases it. The fix lands, verification passes, nothing survives.
#
# The grep side is already safe by accident — do NOT "fix" it to match find.
# `grep` mode below is defence in depth for the cases the shim misses: a repo
# that COMMITS its build output (no .gitignore entry to honour), or a directory
# that is not a git repo at all.
#
# `public/` is deliberately NOT in the always-list: it is SOURCE for
# Astro/Vite/Next and holds the very files this audit checks — favicon.ico,
# apple-touch-icon.png, robots.txt, OG images. It is build OUTPUT only for
# Hugo and Gatsby, detected below. Blanket-excluding it would blind the audit
# to its own resource checks.
#
# Exclusions are by NAME, not path, so a monorepo's frontend/dist is caught
# exactly like a root ./dist.
set -uo pipefail

_die() { echo "source-scope: $1" >&2; exit 2; }

# Build output + tool caches. Never source.
ALWAYS=(node_modules .git dist build .next .nuxt .output _site .astro
        .svelte-kit .cache out coverage .vercel .netlify .turbo)

# public/ is output for exactly these two generators.
_public_is_output() {
  find . -maxdepth 3 \( -name "gatsby-config.js" -o -name "gatsby-config.ts" \
    -o -name "gatsby-config.mjs" -o -name "hugo.toml" -o -name "hugo.yaml" \
    -o -name "hugo.json" \) 2>/dev/null | read -r _ && return 0
  # Hugo's legacy config.toml is ambiguous on its own — pair it with archetypes/
  [ -d ./archetypes ] && [ -f ./config.toml ] && return 0
  return 1
}

_list() {
  printf '%s\n' "${ALWAYS[@]}"
  _public_is_output && printf 'public\n'
  return 0
}

case "${1:-}" in
  list) _list ;;
  # Safe unquoted: --exclude-dir=NAME carries no glob character.
  grep) _list | while read -r d; do printf -- '--exclude-dir=%s ' "$d"; done; echo ;;
  # One token per line — consume with mapfile + a QUOTED array, never a flat
  # string (see header: the shell would glob */dist/* against the CWD).
  findargs) _list | while read -r d; do printf '!\n-path\n*/%s/*\n' "$d"; done ;;
  *) _die "usage: source-scope.sh {list|grep|findargs}" ;;
esac
