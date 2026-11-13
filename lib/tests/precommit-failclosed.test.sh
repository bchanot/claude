#!/usr/bin/env bash
# lib/tests/precommit-failclosed.test.sh — githooks/pre-commit blocks a
# commit on develop when `git diff --cached` itself fails (fail closed).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/githooks/pre-commit"
WORK="$(mktemp -d)" || exit 1; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

R="$WORK/repo"; git init -q "$R" && cd "$R" || exit 1
git config user.email t@t; git config user.name t
git checkout -q -b develop 2>/dev/null
git commit -q --allow-empty -m init   # a root commit is always allowed
mkdir -p .claude/memory && echo a > .claude/memory/x.md && git add .
GIT_CEILING_DIRECTORIES="$WORK" bash "$HOOK" >/dev/null 2>&1
check PC1-allowlisted-passes "$?" 0

echo b > code.sh && git add code.sh
out=$(bash "$HOOK" 2>&1); rc=$?
check PC2-code-blocked "$rc/$(printf '%s' "$out" | grep -c BLOCKED)" 1/1

REAL=$(command -v git)
mkdir "$WORK/shim"
export REAL_GIT="$REAL"
cat > "$WORK/shim/git" <<'S'
#!/bin/sh
case "$*" in *"diff --cached"*) exit 128 ;; esac
exec "$REAL_GIT" "$@"
S
chmod +x "$WORK/shim/git"
git reset -q code.sh; rm code.sh   # only the allowlisted path is staged
out=$(PATH="$WORK/shim:$PATH" bash "$HOOK" 2>&1); rc=$?
check PC3-git-error-blocks "$rc/$(printf '%s' "$out" \
  | grep -c 'cannot list staged paths: BLOCKED')" 1/1

# PC4: the filter stage (grep rc >= 2) blocks too
mkdir "$WORK/shim2"
cat > "$WORK/shim2/grep" <<'S'
#!/bin/sh
exit 2
S
chmod +x "$WORK/shim2/grep"
out=$(PATH="$WORK/shim2:$PATH" bash "$HOOK" 2>&1); rc=$?
check PC4-grep-error-blocks "$rc/$(printf '%s' "$out" \
  | grep -c 'cannot filter staged paths')" 1/1

printf 'precommit-failclosed: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
