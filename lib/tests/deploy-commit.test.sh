#!/usr/bin/env bash
# lib/tests/deploy-commit.test.sh
set -u
H="$(cd "$(dirname "$0")/.." && pwd)/deploy-commit.sh"
pass=0; fail=0
mkrepo() { local d; d=$(mktemp -d); git -C "$d" init -q; git -C "$d" config user.email t@t;
  git -C "$d" config user.name t; mkdir -p "$d/.claude/deploy"; printf 'x\n' >"$d/seed";
  git -C "$d" add seed; git -C "$d" commit -q -m seed; printf '%s' "$d"; }
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

d=$(mkrepo); printf 'run\n' >"$d/.claude/deploy/PROCEDURE.md"
out=$( cd "$d" && bash "$H" commit "docs(deploy): t" .claude/deploy/PROCEDURE.md ); rc=$?
check T1-rc "$rc" 0
check T1-committed-only "$(git -C "$d" show --name-only --format= HEAD)" ".claude/deploy/PROCEDURE.md"
check T1-hash-nonempty "$([ -n "$out" ] && echo y || echo n)" y

d=$(mkrepo); printf 'b\n' >"$d/src.txt"
( cd "$d" && bash "$H" commit "x" src.txt ) >/dev/null 2>&1; check T2-out-of-scope-rc "$?" 4

d=$(mkrepo)
( cd "$d" && bash "$H" commit "x" ".claude/deploy/../memory/secret" ) >/dev/null 2>&1
check T3-traversal-rc "$?" 4

d=$(mkrepo); printf 'p\n' >"$d/.claude/deploy/PROCEDURE.md"; printf 's\n' >"$d/src.txt"
( cd "$d" && bash "$H" commit "x" .claude/deploy/PROCEDURE.md src.txt ) >/dev/null 2>&1
check T4-mixed-refuses-all "$?" 4
check T4-nothing-committed "$(git -C "$d" rev-list --count HEAD)" 1

d=$(mkrepo); git -C "$d" checkout -q --detach
printf 'p\n' >"$d/.claude/deploy/PROCEDURE.md"
( cd "$d" && bash "$H" commit "x" .claude/deploy/PROCEDURE.md ) >/dev/null 2>&1
check T5-unsafe-rc "$?" 3

d=$(mkrepo)
( cd "$d" && bash "$H" pending .claude/deploy/PROCEDURE.md ); check T6-pending-clean-rc "$?" 1

d=$(mkrepo); printf 'p\n' >"$d/.claude/deploy/PROCEDURE.md"
printf 'i\n' >"$d/.claude/deploy/INCIDENTS.md"; printf '{}\n' >"$d/.claude/deploy/STATE.json"
( cd "$d" && bash "$H" commit "docs(deploy): learn" .claude/deploy/PROCEDURE.md \
   .claude/deploy/INCIDENTS.md .claude/deploy/STATE.json ) >/dev/null 2>&1
check T7-atomic-rc "$?" 0
check T7-three-files "$(git -C "$d" show --name-only --format= HEAD | grep -c deploy)" 3

d=$(mkrepo); printf 'b\n' >"$d/src.txt"
( cd "$d" && bash "$H" pending src.txt ) >/dev/null 2>&1; check T8-pending-out-of-scope-rc "$?" 4

d=$(mkrepo); printf '.claude/\n' >"$d/.gitignore"
printf 'run\n' >"$d/.claude/deploy/PROCEDURE.md"
( cd "$d" && bash "$H" commit "docs(deploy): t" .claude/deploy/PROCEDURE.md ) >/dev/null 2>&1
check T9-ignored-rc "$?" 5

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
