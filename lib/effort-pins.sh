#!/usr/bin/env bash
# lib/effort-pins.sh — re-apply the entry effort level on vendored skills
# (BDR-107 second axis, extended to every vendored external by BDR-108).
# Upstream copies carry no `effort:` and every vendoring step rewrites
# SKILL.md, so the level lives in lib/effort-pins.txt and this helper puts
# it back after the last vendoring step of install-plugins.sh and
# update-all.sh. Idempotent: same level → untouched, other level →
# replaced inside the frontmatter only, skill not vendored → skipped,
# malformed map line → rejected loudly, never applied. Hardenings: a map
# whose last line lacks a newline is still read; a SKILL.md whose frontmatter
# never closes is skipped untouched; the level is re-read after every write
# and a mismatch counts as failed; the write goes through a mktemp sibling
# removed on any failure and on INT/TERM (previous traps restored, never an
# EXIT trap: the installer owns one); the rejected map line is printed
# shell-quoted so a caller's `echo -e` cannot interpret it. Placement inside
# the frontmatter has no effect on the harness, which reads the key anywhere.
#
# Usage: source it, then `apply_effort_pins [repo-root]`
#        or standalone: bash lib/effort-pins.sh [repo-root]
# Exit 1 when at least one map line was rejected or a skill failed.

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

# _effort_pin_closed <skill-file> → rc 0 when the frontmatter has a closing ---
_effort_pin_closed() {
  awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{f=1;exit} END{exit !f}' "$1"
}

# _effort_pin_traps_restore <saved> — drop the INT/TERM handlers set for the
# write and re-install the caller's saved ones. No exit-time handler here.
_effort_pin_traps_restore() {
  trap - INT TERM
  [ -z "$1" ] || eval "$1"
}

# _effort_pin_write <skill-file> <name> <level> — replace the frontmatter
# `effort:` line, or insert one after `name: <name>` (before the closing
# `---` when the frontmatter has no name line). Body lines never change.
# Writes a mktemp sibling then renames; any failure leaves no temp behind.
_effort_pin_write() {
  local file="$1" name="$2" level="$3" tmp prev rc
  tmp="$(mktemp "$file.XXXXXX")" || return 1
  prev="$(trap -p INT TERM)"
  trap 'rm -f "$tmp"; exit 130' INT TERM
  cp -p "$file" "$tmp" && awk -v n="$name" -v lvl="$level" '
    NR==1 && /^---$/ { fm=1; print; next }
    fm && /^---$/ {
      if (!done) { print "effort: " lvl; done=1 }
      fm=0; print; next
    }
    fm && /^effort: / { if (!done) { print "effort: " lvl; done=1 }; next }
    fm && $0 == "name: " n { print; if (!done) { print "effort: " lvl; done=1 }; next }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"; rc=$?
  [ "$rc" -eq 0 ] || rm -f "$tmp"
  _effort_pin_traps_restore "$prev"
  return "$rc"
}

# _effort_pin_apply_one <file> <name> <level> → rc 0 applied, 2 already at
# level, 1 failed (err line printed, file untouched or write rolled back)
_effort_pin_apply_one() {
  local file="$1" name="$2" level="$3"
  if ! _effort_pin_closed "$file"; then
    err "effort-pins: $file: frontmatter never closed — skipped"; return 1
  fi
  [ "$(_effort_pin_current "$file")" = "$level" ] && return 2
  if ! _effort_pin_write "$file" "$name" "$level"; then
    err "effort-pins: $file: write failed"; return 1
  fi
  if [ "$(_effort_pin_current "$file")" != "$level" ]; then
    err "effort-pins: $file: level not applied after write"
    return 1
  fi
  return 0
}

# apply_effort_pins [repo-root] — walk the map, pin every vendored skill
apply_effort_pins() {
  local repo="${1:-$EFFORT_PINS_REPO}" map name level rest file rc
  local applied=0 kept=0 rejected=0 failed=0
  map="$repo/lib/effort-pins.txt"
  [ -f "$map" ] || { err "effort-pins: map missing: $map"; return 1; }
  while read -r name level rest || [ -n "$name" ]; do
    case "$name" in ''|'#'*) continue ;; esac
    if [ -n "$rest" ] || ! [[ "$name" =~ $EFFORT_PIN_NAME_RE ]] \
       || ! [[ "$level" =~ $EFFORT_PIN_LEVEL_RE ]]; then
      err "effort-pins: rejected map line $(printf '%q' "$name $level $rest")"
      rejected=$((rejected + 1)); continue
    fi
    file="$repo/skills-external/$name/SKILL.md"
    [ -f "$file" ] || continue
    _effort_pin_apply_one "$file" "$name" "$level"; rc=$?
    case "$rc" in
      0) applied=$((applied + 1)) ;;
      2) kept=$((kept + 1)) ;;
      *) failed=$((failed + 1)) ;;
    esac
  done < "$map"
  ok "effort-pins: $applied applied, $kept already at level, $failed failed"
  [ "$rejected" -eq 0 ] && [ "$failed" -eq 0 ]
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  apply_effort_pins "$@"
fi
