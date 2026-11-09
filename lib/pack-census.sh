#!/usr/bin/env bash
# shellcheck disable=SC2088  # the literal "~/.claude/skills" is a grep pattern
# ============================================================
# lib/pack-census.sh — census of the pack layout and its readers
#
# Packs are skills-dir plugins `skills/pack-<n>/` (manifest
# `.claude-plugin/plugin.json`, entries `skills/<s>` = tracked relative
# symlinks into skills-external/ or real dirs). Checks:
#   1. manifest parses, name = folder; every entry resolves (dangling =
#      WARN; RED with --installed on a pack ON by manifest); no skill both
#      flat and in a pack; no retired gstack name (lib/gstack-removed.list).
#   2. fragments lib/profiles/*.json: same key set as full.json; model-router
#      + security-guidance true, example-skills + brightdata false
#      everywhere; full.json packs = manifest defaults.
#   3. no reader of the old layout left (scope and terms in check_citers).
# Shared by make test (lib/tests/pack-census.test.sh) and doctor.sh.
# Prints RED/WARN lines, then `PACKS OK <p> packs <s> skills` when no RED.
# Exit: 0 clean or WARN only · 1 any RED.
# Usage: pack-census.sh [--repo <dir>] [--installed]
# ============================================================
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --installed) INSTALLED=1; shift ;;
    *) echo "pack-census: unknown option $1" >&2; exit 2 ;;
  esac
done
SKILLS="$REPO/skills"
PROFILES="$REPO/lib/profiles"
REMOVED="$REPO/lib/gstack-removed.list"
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAG_JQ="$HERE/pack-census-fragments.jq"
red=0; packs=0; skills=0
declare -A seen
red() { echo "RED $*"; red=1; }

pack_on() {
  jq -e '.defaultEnabled != false' "$1/.claude-plugin/plugin.json" >/dev/null
}

check_manifest() { # $1 pack dir
  local n m name; n="$(basename "$1")"; m="$1/.claude-plugin/plugin.json"
  [ -f "$m" ] || { red "$n: no .claude-plugin/plugin.json"; return; }
  jq -e . "$m" >/dev/null 2>&1 || { red "$n: manifest is not JSON"; return; }
  name="$(jq -r '.name // ""' "$m")"
  [ "$name" = "$n" ] || red "$n: manifest name is $name"
}

dup_remedy() { # $1 skill listed flat and in a pack
  if [ -L "$SKILLS/$1" ]; then echo "rm skills/$1 (a flat link)"
  else echo "mv skills/$1 skills-external/$1 (a real dir)"; fi
}

check_entry() { # $1 pack dir, $2 entry path
  local n s; n="$(basename "$1")"; s="$(basename "$2")"
  if [ ! -e "$2/SKILL.md" ]; then
    if [ "$INSTALLED" = 1 ] && pack_on "$1"; then
      red "$n: $s target missing (pack ON)"
    else echo "WARN $n: $s target missing (installer not run)"; fi
  fi
  [ -f "$REMOVED" ] && grep -qx -- "$s" "$REMOVED" \
    && red "$n: $s is a retired gstack skill"
  if [ -n "${seen[$s]:-}" ]; then
    red "$s listed twice: ${seen[$s]} and $n; run: $(dup_remedy "$s")"
  else seen[$s]="$n"; fi
  skills=$((skills+1))
}

check_fragments() {
  local files=("$PROFILES"/*.json) full="$PROFILES/full.json" out
  [ -f "$full" ] || { red "lib/profiles/full.json missing"; return; }
  out="$(jq -rn --argjson m "$(manifests_json)" \
    -f "$FRAG_JQ" "${files[@]}")" \
    || { red "lib/profiles: a fragment is not JSON"; return; }
  [ -z "$out" ] || echo "$out"
  ! grep -q '^RED' <<<"$out" || red=1
}

manifests_json() { # [{id, on}] for every pack manifest
  jq -cn '[inputs | {id: (.name + "@skills-dir"),
                     on: (.defaultEnabled != false)}]' \
    "$SKILLS"/pack-*/.claude-plugin/plugin.json 2>/dev/null || echo '[]'
}

# A bare `skills/<pack skill>/` is stale; the layout is
# `skills/pack-<n>/skills/<s>/`, and a path with any prefix passes.
# The old-layout terms are written with a bracketed last letter so this
# file never matches itself; the test's fixture strings live in
# lib/tests/fixtures/ (excluded) for the same reason.
check_citers() { # $@ pack skill names → one grep over the contract scope
  local args=(-e 'skills-disable[d]/' -e 'toggle-externa[l]'
    -e '\.active-profil[e]' -e 'lib/profiles/[a-z-]*\.profil[e]') n hit
  for n in "$@"; do
    args+=(-e "~/.claude/skills/$n\b" -e "\$HOME/.claude/skills/$n\b"
      -e "\(^\|[^A-Za-z0-9_./}~-]\)skills/$n/")
  done
  hit="$( { grep -rno --include='*.sh' --include='*.md' --include='*.py' \
      --include='*.json' --include='Makefile' "${args[@]}" "$REPO"/hooks \
      "$REPO"/lib "$REPO"/agents "$REPO"/skills "$REPO"/rules \
      "$REPO"/templates "$REPO"/mods "$REPO"/*.sh "$REPO"/CLAUDE.global.md \
      "$REPO"/README.md "$REPO"/USAGE.md "$REPO"/ARCHITECTURE.md \
      "$REPO"/Makefile "$REPO"/plugins.lock.json 2>/dev/null
      grep -nHo "${args[@]}" "$REPO"/.gitignore 2>/dev/null; } \
    | grep -v -e '/lib/tests/fixtures/' -e '/skills-external/' \
    | sed -E 's#:[0-9]*:#\t#; s#\t[^\t](skills/[^/\t]+/)$#\t\1#' \
    | sort -u || true)"
  [ -n "$hit" ] || return 0
  while IFS=$'\t' read -r f m; do
    red "${f#"$REPO"/} cites $m"
  done <<<"$hit"
}

main() {
  local d s p e names=()
  [ -f "$REMOVED" ] || red "lib/gstack-removed.list missing"
  for d in "$SKILLS"/*/; do
    d="${d%/}"; s="$(basename "$d")"
    case "$s" in pack-*) continue ;; esac
    [ -e "$d/SKILL.md" ] && seen[$s]="skills/$s"
  done
  for p in "$SKILLS"/pack-*/; do
    p="${p%/}"; packs=$((packs+1)); check_manifest "$p"
    for e in "$p"/skills/*; do
      [ -e "$e" ] || [ -L "$e" ] || continue
      check_entry "$p" "$e"; names+=("$(basename "$e")")
    done
  done
  check_fragments
  [ "${#names[@]}" -gt 0 ] && check_citers "${names[@]}"
  [ "$red" -eq 0 ] && echo "PACKS OK $packs packs $skills skills"
  exit "$red"
}
main
