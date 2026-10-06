#!/usr/bin/env bash
# lib/tests/graphify-gate.test.sh — "propose graphify" threshold signal (BDR-097).
set -u
LIB="$(cd "$(dirname "$0")/../.." && pwd)/lib/graphify-gate.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# gate(dir) -> the signal line, or "silent"
gate() { bash "$LIB" "$1" 2>/dev/null || echo silent; }
has() { case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac; }
# mkrepo <name> <n php files at root> [<n php files under vendor/>]
mkrepo() {
  local d="$WORK/$1" i
  git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
  git -C "$d" config core.hooksPath /dev/null
  for i in $(seq 1 "$2"); do echo "<?php // $i" > "$d/f$i.php"; done
  if [ "${3:-0}" -gt 0 ]; then
    mkdir -p "$d/vendor/lib"
    for i in $(seq 1 "$3"); do echo "<?php // v$i" > "$d/vendor/lib/v$i.php"; done
  fi
  git -C "$d" add -A; git -C "$d" commit -q -m init
  echo "$d"
}

mkdir -p "$WORK/plain"
check T1-not-a-repo "$(gate "$WORK/plain")" silent

d=$(mkrepo below 199)
check T2-199-files-silent "$(gate "$d")" silent

d=$(mkrepo at 200)
check T3-200-files-fires "$(has "$(gate "$d")" "200 code files")" yes
check T3b-line-is-banner-sized "$([ "$(gate "$d" | wc -m)" -le 45 ] && echo yes || echo no)" yes
mkdir -p "$d/graphify-out"; echo '{}' > "$d/graphify-out/graph.json"
check T4-graph-exists-silent "$(gate "$d")" silent

d=$(mkrepo vendored 190 60)
check T5-vendored-not-counted "$(gate "$d")" silent
for i in $(seq 191 200); do echo "<?php // $i" > "$d/f$i.php"; done
git -C "$d" add -A; git -C "$d" commit -q -m more
check T5b-own-files-reach-200 "$(has "$(gate "$d")" "200 code files")" yes

d=$(mkrepo untracked 199)
for i in $(seq 200 210); do echo "<?php // $i" > "$d/f$i.php"; done   # left untracked
check T6-untracked-not-counted "$(gate "$d")" silent

d=$(mkrepo tiny 10)
check T7-threshold-override "$(has "$(GRAPHIFY_MIN_CODE_FILES=5 bash "$LIB" "$d" 2>/dev/null)" "≥ 5")" yes

d=$(mkrepo subdir 200); mkdir -p "$d/app/sub"
check T8-from-subdirectory "$(has "$(gate "$d/app/sub")" "200 code files")" yes

d=$(mkrepo docs 10)
for i in $(seq 1 300); do echo "# $i" > "$d/doc$i.md"; done
git -C "$d" add -A; git -C "$d" commit -q -m docs
check T9-non-code-not-counted "$(gate "$d")" silent

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
