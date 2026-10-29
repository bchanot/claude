#!/usr/bin/env bash
# lib/tests/doctor-automem.test.sh — lib/doctor-automem.sh's
# automem_leftover_dirs(): absent dir, empty memory dirs, a file, a nested
# file, an empty subdir only, rc 0 under errexit (doctor.sh runs under
# `set -euo pipefail`) — BDR-125 phase 1.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/lib/doctor-automem.sh"
# shellcheck source=../doctor-automem.sh disable=SC1091
source "$LIB"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

check T1-absent-dir "$(automem_leftover_dirs "$W/nope")" 0
mkdir -p "$W/p/-home-a/memory" "$W/p/-home-b/memory"
check T2-empty-dirs "$(automem_leftover_dirs "$W/p")" 0
echo x > "$W/p/-home-a/memory/MEMORY.md"
check T3-one-file "$(automem_leftover_dirs "$W/p")" 1
mkdir -p "$W/p/-home-b/memory/sub"; echo y > "$W/p/-home-b/memory/sub/note.md"
check T4-nested-file-counts "$(automem_leftover_dirs "$W/p")" 2
mkdir -p "$W/p/-home-c/memory/empty-sub"
check T5-empty-subdir-silent "$(automem_leftover_dirs "$W/p")" 2
check T6-rc0-under-errexit "$(bash -c 'set -euo pipefail; source "$1"; automem_leftover_dirs "$2" >/dev/null; echo "rc$?"' _ "$LIB" "$W/nope")" rc0
# doctor.sh calls it on "$HOME/.claude/projects": the same call under a temp HOME
mkdir -p "$W/h/.claude/projects/-home-x/memory"; echo z > "$W/h/.claude/projects/-home-x/memory/a.md"
check T7-via-temp-home "$(HOME="$W/h" bash -c 'source "$1"; automem_leftover_dirs "$HOME/.claude/projects"' _ "$LIB")" 1

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
