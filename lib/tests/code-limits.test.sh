#!/usr/bin/env bash
# lib/tests/code-limits.test.sh — hooks/code-limits.sh (BDR-125 phase 2):
# lines a file gained over 80 columns, in OUR code, once per file per
# session, additionalContext only, silent on every other path.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
H="$ROOT/hooks/code-limits.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK/tmp"; mkdir -p "$TMPDIR"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
long() { printf 'x%.0s' $(seq 1 "$1"); }
has() { printf '%s' "$1" | grep -c -- "$2"; }

mkrepo() { # mkrepo <dir> <origin>
  git init -q "$1" && git -C "$1" config claude.origin "$2"
  git -C "$1" config user.email t@t && git -C "$1" config user.name t
  printf 'a\n' > "$1/a.sh" && git -C "$1" add a.sh
  git -C "$1" commit -q -m init
}
fire() { # fire <file> [session] [payload extra json] -> additionalContext
  jq -n --arg f "$1" --arg s "${2:-s1}" --argjson x "${3:-{\}}" \
    '{session_id:$s, tool_name:"Edit", tool_input:({file_path:$f} + $x)}' \
    | bash "$H" | jq -r '.hookSpecificOutput.additionalContext // empty'
}

mkrepo "$WORK/ours" ours
printf 'a\n%s\n' "$(long 90)" > "$WORK/ours/a.sh"
out="$(fire "$WORK/ours/a.sh")"
check T1-reports-long "$(has "$out" 'L2 (90)')" 1
check T2-once-per-session "$(fire "$WORK/ours/a.sh")" ""
check T3-new-session "$(has "$(fire "$WORK/ours/a.sh" s2)" 'L2 (90)')" 1

mkrepo "$WORK/foreign" foreign
printf 'a\n%s\n' "$(long 90)" > "$WORK/foreign/a.sh"
check T4-foreign-silent "$(fire "$WORK/foreign/a.sh")" ""

printf 'a\n%s\n' "$(long 80)" > "$WORK/ours/a.sh"
check T5-80-is-fine "$(fire "$WORK/ours/a.sh" s3)" ""

{ printf 'a\n'; for i in 1 2 3 4 5 6 7; do long $((85 + i)); echo; done; } \
  > "$WORK/ours/a.sh"
out="$(fire "$WORK/ours/a.sh" s4)"
check T6-count-all "$(has "$out" 'has 7 added line')" 1
check T7-cap-5 "$(printf '%s' "$out" | grep -o 'L[0-9]* (' | wc -l \
  | tr -d ' ')" 5

big="$(long 95)"
printf '%s\n' "$big" > "$WORK/ours/new.ts"
x="$(jq -n --arg c "$big" '{content:$c}')"
check T8-untracked-write "$(has "$(fire "$WORK/ours/new.ts" s5 "$x")" \
  'L1 (95)')" 1
printf 'short\n%s\n' "$big" > "$WORK/ours/old.ts"
x="$(jq -n '{new_string:"short"}')"
check T9-untracked-edit-payload-only "$(fire "$WORK/ours/old.ts" s6 "$x")" ""

printf '%s\n' "$big" > "$WORK/ours/doc.md"
check T10-md-silent "$(fire "$WORK/ours/doc.md" s7)" ""
check T11-bad-session-silent "$(fire "$WORK/ours/new.ts" '../x' \
  "$(jq -n --arg c "$big" '{content:$c}')")" ""

out=$(jq -n --arg f "$WORK/ours/new.ts" \
  '{session_id:"s8", tool_input:{file_path:$f}}' \
  | PATH=/nonexistent "$BASH" "$H"); rc=$?
check T12-no-jq-rc0 "$rc" 0
check T13-no-jq-silent "$out" ""

mkdir -p "$WORK/fresh" && git -C "$WORK/fresh" init -q
printf '%s\n' "$big" > "$WORK/fresh/a.sh"
fire "$WORK/fresh/a.sh" s9 >/dev/null
check T14-no-commit-not-cached \
  "$(find "$TMPDIR/claude-code-limits-s9" -name 'origin-*' | wc -l \
  | tr -d ' ')" 0

printf 'PASS=%d FAIL=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
