#!/usr/bin/env bash
# lib/tests/config-protection.test.sh
set -u
H="$(cd "$(dirname "$0")/../.." && pwd)/hooks/config-protection.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
# Run hook for a file_path with NO sentinel present (CWD = a clean temp dir).
run() { local c r; c="$(mktemp -d)"; ( cd "$c" && printf \
  '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" | bash "$H" ) \
  >/dev/null 2>&1; r=$?; rm -rf "$c"; return "$r"; }

# --- Guarded quality-gate files -> blocked (exit 2) ---
run "/home/u/Documents/claude/lib/gitflow.sh";              check T1-gitflow           "$?" 2
run "/home/u/.claude/settings.json";                        check T2-live-settings     "$?" 2
run "/home/u/Documents/claude/.claude/settings.local.json"; check T3-local-settings    "$?" 2
run "/home/u/Documents/claude/settings.json";               check T4-root-settings     "$?" 2
run "/home/u/Documents/claude/.githooks/pre-commit";        check T5-githook           "$?" 2
run "/home/u/Documents/claude/doctor.sh";                   check T6-doctor            "$?" 2
run "/home/u/Documents/claude/.shellcheckrc";               check T7-shellcheckrc      "$?" 2
# self-guard: the hook itself, other hooks, and the test suite are guarded
run "/home/u/Documents/claude/hooks/config-protection.sh";  check T8-self-guard        "$?" 2
run "/home/u/.claude/hooks/session-start.sh";               check T9-deployed-hook     "$?" 2
run "/home/u/Documents/claude/lib/tests/config-protection.test.sh"; check T10-tests-guarded "$?" 2

# --- Non-guarded -> allowed (exit 0) ---
run "/home/u/Documents/claude/lib/gitflow-migrate.sh";      check T11-near-miss        "$?" 0
run "/home/u/project/src/app.js";                           check T12-code             "$?" 0
run "/home/u/project/settings.json";                        check T13-foreign-settings "$?" 0

# --- Fail-open on malformed input (no file_path) -> allowed ---
c="$(mktemp -d)"; ( cd "$c" && printf '{}' | bash "$H" ) >/dev/null 2>&1
check T14-fail-open "$?" 0; rm -rf "$c"

# --- Sentinel one-shot: non-empty reason -> allow + log + consume; 2nd edit blocked ---
tmp="$(mktemp -d)"; mkdir -p "$tmp/.claude"
printf 'fixing eslint false-positive' > "$tmp/.claude/.config-edit-ok"
( cd "$tmp" && printf '{"tool_name":"Edit","tool_input":{"file_path":"/x/doctor.sh"}}' \
  | HOME="$tmp" bash "$H" ) >/dev/null 2>&1
check T15-sentinel-allow "$?" 0
check T15-consumed "$([ -e "$tmp/.claude/.config-edit-ok" ] && echo present || echo gone)" gone
check T15-logged "$(grep -c 'BYPASS.*doctor.sh.*fixing eslint' \
  "$tmp/.claude/logs/config-protection.log" 2>/dev/null)" 1
( cd "$tmp" && printf '{"tool_name":"Edit","tool_input":{"file_path":"/x/doctor.sh"}}' \
  | HOME="$tmp" bash "$H" ) >/dev/null 2>&1
check T16-second-blocked "$?" 2
rm -rf "$tmp"

# --- Sentinel with EMPTY reason -> refused + consumed ---
tmp="$(mktemp -d)"; mkdir -p "$tmp/.claude"; : > "$tmp/.claude/.config-edit-ok"
( cd "$tmp" && printf '{"tool_name":"Edit","tool_input":{"file_path":"/x/doctor.sh"}}' \
  | HOME="$tmp" bash "$H" ) >/dev/null 2>&1
check T17-empty-refused "$?" 2
check T17-consumed "$([ -e "$tmp/.claude/.config-edit-ok" ] && echo present || echo gone)" gone
rm -rf "$tmp"

# --- T18/T19: payload shapes beyond Edit (locks against future Edit-only narrowing) ---
c="$(mktemp -d)"; ( cd "$c" && printf \
  '{"tool_name":"Write","tool_input":{"file_path":"/x/doctor.sh","content":"x"}}' | bash "$H" ) \
  >/dev/null 2>&1; check T18-write-payload "$?" 2; rm -rf "$c"

c="$(mktemp -d)"; ( cd "$c" && printf \
  '{"tool_name":"MultiEdit","tool_input":{"file_path":"/x/doctor.sh","edits":[{"old_string":"a","new_string":"b"}]}}' | bash "$H" ) \
  >/dev/null 2>&1; check T19-multiedit-payload "$?" 2; rm -rf "$c"

# --- T20: sentinel with ONLY whitespace bytes (not literally empty) -> refused + consumed ---
tmp="$(mktemp -d)"; mkdir -p "$tmp/.claude"; printf ' \n\t' > "$tmp/.claude/.config-edit-ok"
( cd "$tmp" && printf '{"tool_name":"Edit","tool_input":{"file_path":"/x/doctor.sh"}}' \
  | HOME="$tmp" bash "$H" ) >/dev/null 2>&1
check T20-whitespace-only-refused "$?" 2
check T20-whitespace-only-consumed "$([ -e "$tmp/.claude/.config-edit-ok" ] && echo present || echo gone)" gone
rm -rf "$tmp"

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
