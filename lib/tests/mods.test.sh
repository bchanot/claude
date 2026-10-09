#!/usr/bin/env bash
# lib/tests/mods.test.sh — every mods/<name>/ plugin: the manifest name
# equals the folder, skills/<name> is the relative loading symlink
# ../mods/<name>, and (when the CLI offers `claude plugin test`) the mod
# passes `claude plugin validate` without warning and `claude plugin test`.
# MODS_ROOT overrides the repo root (fixture controls). Fails when no mod
# is found, so it can never pass vacuously.
set -u
ROOT="${MODS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CLI_TIMEOUT=120
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
ko() { fail=$((fail+1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else ko "$1: got[$2] want[$3]"; fi; }

# bounded CMD...: stdout+stderr on stdout, rc 124 on timeout.
bounded() {
  local t
  t=$(command -v timeout || command -v gtimeout || true)
  if [ -n "$t" ]; then "$t" "$CLI_TIMEOUT" "$@" 2>&1; return; fi
  local out rc=0 pid i=0
  out=$(mktemp) || return 1
  "$@" >"$out" 2>&1 & pid=$!
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt "$CLI_TIMEOUT" ]; do
    sleep 1; i=$((i+1))
  done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; rc=124
  else wait "$pid" || rc=$?; fi
  cat "$out"; rm -f "$out"; return "$rc"
}

manifest_name() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' \
    "$1" 2>/dev/null
}

# cli_unavailable: prints the reason and returns 0 when the capability is missing.
cli_unavailable() {
  command -v claude >/dev/null 2>&1 || { echo "claude not found"; return 0; }
  local rc=0
  bounded claude plugin test --help >/dev/null || rc=$?
  [ "$rc" -eq 124 ] && { echo "probe timed out after ${CLI_TIMEOUT}s"; return 0; }
  [ "$rc" -ne 0 ] && { echo "no 'claude plugin test' command"; return 0; }
  return 1
}

check_cli() {
  local name="$1" dir="$2" out rc=0
  out=$(bounded claude plugin validate "$dir") || rc=$?
  if [ "$rc" -eq 124 ]; then ko "$name: validate timed out after ${CLI_TIMEOUT}s"
  elif ! printf '%s' "$out" | grep -q 'Validation passed'; then
    ko "$name: validate did not pass: $(printf '%s' "$out" | head -3 | tr '\n' ' ')"
  elif printf '%s' "$out" | grep -qi 'warning'; then
    ko "$name: validate printed a warning"
  else ok "$name: validate passed, no warning"; fi
  rc=0
  out=$(bounded claude plugin test "$dir") || rc=$?
  if [ "$rc" -eq 124 ]; then ko "$name: plugin test timed out after ${CLI_TIMEOUT}s"
  elif [ "$rc" -ne 0 ]; then
    ko "$name: plugin test rc=$rc: $(printf '%s' "$out" | tail -3 | tr '\n' ' ')"
  else ok "$name: plugin test passed"; fi
}

manifests=()
for m in "$ROOT"/mods/*/.claude-plugin/plugin.json; do
  [ -f "$m" ] && manifests+=("$m")
done
if [ "${#manifests[@]}" -eq 0 ]; then ko "no mod found under $ROOT/mods"; fi

use_cli=1
if reason=$(cli_unavailable); then
  use_cli=0
  echo "SKIP: claude plugin test unavailable ($reason) — validate/test not run"
fi

for m in ${manifests[@]+"${manifests[@]}"}; do
  dir="$(dirname "$(dirname "$m")")"; name="$(basename "$dir")"
  check "$name: manifest name matches folder" "$(manifest_name "$m")" "$name"
  link="$ROOT/skills/$name"
  if [ -L "$link" ]; then
    check "$name: loading link target" "$(readlink "$link")" "../mods/$name"
  else ko "$name: skills/$name is not a symlink"; fi
  [ "$use_cli" -eq 1 ] && check_cli "$name" "$dir"
done

echo "mods: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
