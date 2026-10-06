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

# ── manual-push mode (gitflow.autopush=false) ──
git checkout -q -- a
git config gitflow.autopush false
check T10-manual-clean-start "$(fire SessionStart "$PWD")" silent
check T10-manual-clean-stop "$(fire Stop "$PWD")" silent
echo m>m; git add m; git commit -q -m m
git branch side HEAD; git checkout -q side; echo s>s; git add s; git commit -q -m s
git checkout -q -
check T11-manual-stop-silent "$(fire Stop "$PWD")" silent
out=$(fire SessionStart "$PWD")
check T11-manual-info "$(has "$out" "manual push mode")" yes
check T11-manual-count "$(has "$out" "2 commit(s)")" yes
check T11-manual-lists-branch "$(has "$out" "side")" yes
check T11-manual-no-warning "$(has "$out" "unpushed work")" no
git checkout -q -b fresh
check T12-fresh-branch-repo-wide "$(has "$(fire SessionStart "$PWD")" "2 commit(s)")" yes
git checkout -q -
git push -q origin HEAD side 2>/dev/null; echo d>>a
out=$(fire SessionStart "$PWD")
check T13-dirty-info "$(has "$out" "manual push mode")" yes
check T13-dirty-uncommitted "$(has "$out" "uncommitted")" yes
check T13-dirty-no-commit-clause "$(has "$out" "commit(s) not on origin")" no
check T13-dirty-stop-silent "$(fire Stop "$PWD")" silent
git checkout -q -- a
git config gitflow.autopush flase
echo i>i; git add i; git commit -q -m i
out=$(fire SessionStart "$PWD")
check T14-invalid-named "$(has "$out" "not a boolean")" yes
check T14-invalid-treated-auto "$(has "$out" "unpushed work")" yes
check T14-invalid-stop-auto "$(has "$(fire Stop "$PWD")" "1 commit(s)")" yes
git config --unset gitflow.autopush
check T15-unset-auto-intact "$(has "$(fire Stop "$PWD")" "1 commit(s)")" yes
git config gitflow.autopush false; git remote remove origin
out=$(fire SessionStart "$PWD")
check T16-no-origin-manual "$(has "$out" "manual push mode")" yes
check T16-no-origin-clause "$(has "$out" "no 'origin' remote")" yes
check T16-no-origin-stop-silent "$(fire Stop "$PWD")" silent

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
