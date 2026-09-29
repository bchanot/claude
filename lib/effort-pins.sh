#!/usr/bin/env bash
# lib/effort-pins.sh — re-apply the entry effort level on vendored skills
# (BDR-107 second axis, extended to every vendored external by BDR-108).
# Upstream copies carry no `effort:` and every vendoring step rewrites
# SKILL.md, so the level lives in lib/effort-pins.txt and this helper puts
# it back after the last vendoring step of install-plugins.sh and
# update-all.sh. Idempotent: same level → untouched, other level →
# replaced inside the frontmatter only, skill not vendored → skipped,
# malformed map line → rejected loudly, never applied. Placement inside the
# frontmatter has no effect on the harness, which reads the key anywhere.
#
# Usage: source it, then `apply_effort_pins [repo-root]`
#        or standalone: bash lib/effort-pins.sh [repo-root]
# Exit 1 when at least one map line was rejected.

EFFORT_PINS_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EFFORT_PIN_LEVEL_RE='^(low|medium|high|xhigh|max)$'
EFFORT_PIN_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'

# Callers (install-plugins.sh, update-all.sh) define these; standalone
# runs get plain fallbacks.
declare -F ok   >/dev/null || ok()   { printf '  ok   %s\n' "$*"; }
declare -F info >/dev/null || info() { printf '  info %s\n' "$*"; }
declare -F err  >/dev/null || err()  { printf '  ERR  %s\n' "$*" >&2; }

# _effort_pin_current <skill-file> → prints the frontmatter effort, if any
_effort_pin_current() {
  awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' "$1" \
    | sed -n 's/^effort: //p' | head -1
}

# _effort_pin_write <skill-file> <name> <level> — replace the frontmatter
# `effort:` line, or insert one after `name: <name>` (before the closing
# `---` when the frontmatter has no name line). Body lines never change.
_effort_pin_write() {
  local file="$1" name="$2" level="$3"
  awk -v n="$name" -v lvl="$level" '
    NR==1 && /^---$/ { fm=1; print; next }
    fm && /^---$/ {
      if (!done) { print "effort: " lvl; done=1 }
      fm=0; print; next
    }
    fm && /^effort: / { if (!done) { print "effort: " lvl; done=1 }; next }
    fm && $0 == "name: " n { print; if (!done) { print "effort: " lvl; done=1 }; next }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# apply_effort_pins [repo-root] — walk the map, pin every vendored skill
apply_effort_pins() {
  local repo="${1:-$EFFORT_PINS_REPO}" map name level rest file
  local applied=0 kept=0 rejected=0
  map="$repo/lib/effort-pins.txt"
  [ -f "$map" ] || { err "effort-pins: map missing: $map"; return 1; }
  while read -r name level rest; do
    case "$name" in ''|'#'*) continue ;; esac
    if [ -n "$rest" ] || ! [[ "$name" =~ $EFFORT_PIN_NAME_RE ]] \
       || ! [[ "$level" =~ $EFFORT_PIN_LEVEL_RE ]]; then
      err "effort-pins: rejected map line '$name $level $rest'"
      rejected=$((rejected + 1)); continue
    fi
    file="$repo/skills-external/$name/SKILL.md"
    [ -f "$file" ] || continue
    if [ "$(_effort_pin_current "$file")" = "$level" ]; then
      kept=$((kept + 1)); continue
    fi
    _effort_pin_write "$file" "$name" "$level" && applied=$((applied + 1))
  done < "$map"
  ok "effort-pins: $applied applied, $kept already at level"
  [ "$rejected" -eq 0 ]
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  apply_effort_pins "$@"
fi
