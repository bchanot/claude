#!/usr/bin/env bash
# lib/tests/code-origin.test.sh — code-origin.sh verdicts: override, root
# author, extra identities, undecidable cases. Hermetic: global git config is
# pointed at a temp file and nothing is pushed.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
L="$ROOT/lib/code-origin.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GITFLOW_NO_PUSH=1 GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
git config --global user.name me
git config --global user.email me@mine.test

# mkrepo <name> <author-email> <date> → repo with one root commit
mkrepo() {
  git init -q "$tmp/$1"
  GIT_AUTHOR_EMAIL="$2" GIT_AUTHOR_DATE="$3" GIT_COMMITTER_DATE="$3" \
    git -C "$tmp/$1" commit -q --allow-empty -m root
}
verdict() { bash "$L" "$tmp/$1"; }

# --- root author ---
mkrepo mine me@mine.test "2024-05-01T10:00:00"
check T1-own-root "$(verdict mine)" "ours root me 2024"
mkrepo other n.turpault@corp.test "2009-02-25T10:00:00"
check T2-foreign-root "$(verdict other)" "foreign root n.turpault 2009"
mkrepo upper ME@Mine.Test "2024-05-01T10:00:00"
check T3-email-case "$(verdict upper | cut -d' ' -f1)" ours

# --- extra identity ---
mkrepo second old@work.test "2020-01-01T10:00:00"
check T4-before-identity "$(verdict second | cut -d' ' -f1)" foreign
git config --global --add claude.identity old@work.test
check T5-after-identity "$(verdict second | cut -d' ' -f1)" ours

# --- override ---
git -C "$tmp/other" config claude.origin ours
check T6-override-ours "$(verdict other)" "ours override claude.origin"
git -C "$tmp/mine" config claude.origin foreign
check T7-override-foreign "$(verdict mine)" "foreign override claude.origin"
git -C "$tmp/mine" config claude.origin bogus
check T8-override-invalid "$(verdict mine)" \
  "foreign claude.origin 'bogus' invalid (want ours|foreign)"

# --- undecidable → foreign, said out loud ---
mkdir "$tmp/plain"
check T9-no-git "$(verdict plain)" "foreign not a git repository"
git init -q "$tmp/empty"
check T10-no-commit "$(verdict empty)" "foreign no commit, root unknown"
git clone -q --depth 1 "file://$tmp/second" "$tmp/shallow" 2>/dev/null
check T11-shallow "$(verdict shallow)" "foreign shallow clone, root unknown"

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
