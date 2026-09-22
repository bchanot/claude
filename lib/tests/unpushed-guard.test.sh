#!/usr/bin/env bash
# lib/tests/unpushed-guard.test.sh — SessionStart/Stop unpushed-work signal (BDR-095).
set -u
H="$(cd "$(dirname "$0")/../.." && pwd)/hooks/unpushed-guard.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# fire(event, dir) -> the hook's systemMessage, or "silent"
fire() {
  local out
  out=$(jq -n --arg e "$1" --arg d "$2" '{hook_event_name:$e, cwd:$d}' | bash "$H" 2>/dev/null)
  [ -n "$out" ] && printf '%s' "$out" | jq -r '.systemMessage' || echo silent
}
has() { case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac; }

mkdir -p "$WORK/plain"
check T1-not-a-repo "$(fire Stop "$WORK/plain")" silent

git init -q "$WORK/repo"; cd "$WORK/repo" || exit 1
git config user.email t@t; git config user.name t; git config core.hooksPath /dev/null
echo a>a; git add a; git commit -q -m a
check T2-no-origin-mentioned "$(has "$(fire Stop "$PWD")" "no 'origin'")" yes

git init -q --bare "$WORK/origin.git"; git remote add origin "$WORK/origin.git"
check T3-no-upstream "$(has "$(fire Stop "$PWD")" "no upstream")" yes
git push -q -u origin master 2>/dev/null || git push -q -u origin main 2>/dev/null
check T4-in-sync-silent "$(fire Stop "$PWD")" silent

echo b>>a; git add a; git commit -q -m b
check T5-ahead-stop "$(has "$(fire Stop "$PWD")" "1 commit(s)")" yes
check T6-ahead-start "$(has "$(fire SessionStart "$PWD")" "1 commit(s)")" yes
git push -q origin HEAD 2>/dev/null

echo c>>a
check T7-dirty-stop-silent "$(fire Stop "$PWD")" silent
check T8-dirty-start-reported "$(has "$(fire SessionStart "$PWD")" "uncommitted")" yes
out=$(jq -n --arg d "$PWD" '{hook_event_name:"SessionStart", cwd:$d}' | bash "$H" 2>/dev/null)
check T9-start-adds-context "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')" SessionStart

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
