#!/usr/bin/env bash
# scan.sh — read-only report of rebuildable disk residue under a root.
# Usage: bash scan.sh [root]   (default: $HOME)
# Output: one TSV row per candidate:
#   category <TAB> size <TAB> age_days <TAB> path <TAB> note
# Deletes nothing: /disk-clean shows the rows, asks, then acts.
# DISK_CLEAN_DOCKER overrides the docker binary (tests stub it).
set -u

ROOT="${1:-$HOME}"
DOCKER="${DISK_CLEAN_DOCKER:-docker}"
TMP_MIN_AGE_DAYS=2   # a live session's tmp dir is younger than this

size_of() { du -sh "$1" 2>/dev/null | cut -f1; }

age_days() {
  local mtime
  mtime=$(stat -c %Y "$1" 2>/dev/null) || { echo "?"; return; }
  echo $(( ($(date +%s) - mtime) / 86400 ))
}

row() { printf '%s\t%s\t%s\t%s\t%s\n' "$@"; }

# busy_note <project dir> -> "busy" when a cargo/rustc runs inside it
busy_note() {
  local pid cwd
  for pid in $(pgrep -x 'cargo|rustc' 2>/dev/null); do
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
    case "$cwd/" in "$1"/*) echo "busy (pid $pid)"; return ;; esac
  done
  echo "-"
}

# Cargo projects: a Cargo.toml whose dir holds target/debug.
scan_cargo() {
  local manifest dir
  find "$ROOT" -maxdepth 5 \( -name target -o -name node_modules \
      -o -name '.rustup' -o -name '.cargo' -o -name '.git' \) -prune \
      -o -name Cargo.toml -print 2>/dev/null |
  while read -r manifest; do
    dir=$(dirname "$manifest")
    [ -d "$dir/target/debug" ] || continue
    row cargo "$(size_of "$dir/target/debug")" \
      "$(age_days "$dir/target/debug")" "$dir" "$(busy_note "$dir")"
  done
}

# node_modules of projects outside hidden dirs; age = package.json mtime.
scan_node_modules() {
  local nm
  find "$ROOT" -maxdepth 5 -path '*/.*' -prune \
      -o -type d -name node_modules -print -prune 2>/dev/null |
  while read -r nm; do
    row node_modules "$(size_of "$nm")" \
      "$(age_days "$(dirname "$nm")/package.json")" "$nm" "-"
  done
}

# Playwright: every browser dir but the highest revision of its kind.
scan_playwright() {
  local base="$ROOT/.cache/ms-playwright" kind dir newest
  [ -d "$base" ] || return 0
  for kind in $(find "$base" -mindepth 1 -maxdepth 1 -printf '%f\n' |
      sed -n 's/-[0-9]*$//p' | sort -u); do
    newest=$(printf '%s\n' "$base/$kind"-[0-9]* | sort -V | tail -1)
    for dir in "$base/$kind"-[0-9]*; do
      [ "$dir" = "$newest" ] && continue
      row playwright "$(size_of "$dir")" "$(age_days "$dir")" "$dir" \
        "superseded by $(basename "$newest")"
    done
  done
}

# Orphan tmp dirs of past Claude sessions.
scan_claude_tmp() {
  local base="$ROOT/.cache/claude-tmp" count
  [ -d "$base" ] || return 0
  count=$(find "$base" -maxdepth 1 -name 'tmp.*' \
    -mtime +"$TMP_MIN_AGE_DAYS" | wc -l)
  [ "$count" -gt 0 ] || return 0
  row claude_tmp "$(size_of "$base")" "-" "$base" \
    "$count tmp.* dirs older than ${TMP_MIN_AGE_DAYS}d"
}

# Docker: the reclaimable column of `docker system df`.
scan_docker() {
  command -v "$DOCKER" >/dev/null 2>&1 || return 0
  "$DOCKER" system df --format '{{.Type}}\t{{.Reclaimable}}' \
      2>/dev/null |
  while IFS=$'\t' read -r type reclaimable; do
    row docker "$reclaimable" "-" "$type" "reclaimable"
  done
}

[ -d "$ROOT" ] || { echo "scan.sh: no such dir: $ROOT" >&2; exit 2; }
df -h "$ROOT" | tail -1 | awk '{print "#disk\t" $5 " used, " $4 " free"}'
scan_cargo
scan_node_modules
scan_playwright
scan_claude_tmp
scan_docker
