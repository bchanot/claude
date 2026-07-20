#!/usr/bin/env bash
# lib/tests/source-scope.test.sh
set -u
S="$(cd "$(dirname "$0")/../.." && pwd)/lib/source-scope.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# does `list` (run inside dir $1) contain the name $2?
listed() { ( cd "$1" && bash "$S" list 2>/dev/null | grep -qxF "$2" ) \
  && echo yes || echo no; }

TMP="$(mktemp -d)"

# --- always-excluded build output + caches ---
mkdir -p "$TMP/plain"
for d in node_modules .git dist build .next .nuxt .output _site .astro \
         .svelte-kit .cache out coverage .vercel .netlify .turbo; do
  check "A-$d-listed" "$(listed "$TMP/plain" "$d")" yes
done

# --- public/ is SOURCE by default: Astro/Vite/Next keep favicon.ico,
#     apple-touch-icon.png and robots.txt there, and the audit checks them ---
check B1-public-kept-by-default "$(listed "$TMP/plain" public)" no

# --- public/ is OUTPUT for Gatsby and Hugo only ---
mkdir -p "$TMP/gatsby";  : > "$TMP/gatsby/gatsby-config.js"
check B2-gatsby-js   "$(listed "$TMP/gatsby" public)" yes
mkdir -p "$TMP/gatsby2"; : > "$TMP/gatsby2/gatsby-config.ts"
check B3-gatsby-ts   "$(listed "$TMP/gatsby2" public)" yes
mkdir -p "$TMP/hugo";    : > "$TMP/hugo/hugo.toml"
check B4-hugo-toml   "$(listed "$TMP/hugo" public)" yes
mkdir -p "$TMP/hugo2";   : > "$TMP/hugo2/hugo.yaml"
check B5-hugo-yaml   "$(listed "$TMP/hugo2" public)" yes
# legacy config.toml alone is ambiguous (many tools use it) — needs archetypes/
mkdir -p "$TMP/amb";     : > "$TMP/amb/config.toml"
check B6-config-toml-alone-is-ambiguous "$(listed "$TMP/amb" public)" no
mkdir -p "$TMP/hugo3/archetypes"; : > "$TMP/hugo3/config.toml"
check B7-config-toml-plus-archetypes    "$(listed "$TMP/hugo3" public)" yes

# --- grep mode: flags, and no glob character (safe unquoted) ---
G="$(cd "$TMP/plain" && bash "$S" grep)"
case "$G" in *--exclude-dir=dist*) check C1-grep-has-dist ok ok ;;
  *) check C1-grep-has-dist "missing" ok ;; esac
case "$G" in *"*"*) check C2-grep-has-no-glob "has-glob" ok ;;
  *) check C2-grep-has-no-glob ok ok ;; esac

# --- findargs: one token per line, 3 tokens per dir ---
N="$(cd "$TMP/plain" && bash "$S" findargs | wc -l)"
D="$(cd "$TMP/plain" && bash "$S" list | wc -l)"
check D1-findargs-3-tokens-per-dir "$N" "$((D * 3))"
check D2-findargs-first-token "$(cd "$TMP/plain" && bash "$S" findargs | head -1)" '!'

# --- FUNCTIONAL: the array form actually excludes build output ---
# A flat unquoted string does NOT work here: the shell globs */dist/* against
# the CWD and passes the matches to find as search paths. Measured on a real
# repo, that turned 90 hits into 135 and kept every dist/ file.
W="$TMP/work"; mkdir -p "$W/src" "$W/dist" "$W/public" "$W/node_modules"
: > "$W/src/a.png"; : > "$W/dist/a.png"; : > "$W/public/favicon.ico"
: > "$W/node_modules/dep.png"
cd "$W" || exit 1
mapfile -t FEXCL < <(bash "$S" findargs)
check E1-excludes-dist  "$(find . "${FEXCL[@]}" -name 'a.png' | grep -c '/dist/')"  0
check E2-keeps-src      "$(find . "${FEXCL[@]}" -name 'a.png' | grep -c '/src/')"   1
check E3-excludes-nodem "$(find . "${FEXCL[@]}" -name '*.png' | grep -c 'node_modules')" 0
# public/ survives: the audit's own resource checks live there
check E4-keeps-public   "$(find . "${FEXCL[@]}" -name 'favicon.ico' | wc -l)" 1
cd / || exit 1

# --- usage ---
bash "$S" >/dev/null 2>&1;        check X1-no-args  "$?" 2
bash "$S" bogus >/dev/null 2>&1;  check X2-bad-verb "$?" 2
# `find` was renamed to `findargs` when the flat-string form proved unsafe
bash "$S" find >/dev/null 2>&1;   check X3-old-find-verb-gone "$?" 2

rm -rf "$TMP"
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
