#!/usr/bin/env bash
# lib/tests/model-check.test.sh — flip-tests for lib/model-check.sh (LRN-096)
set -u
S="$(cd "$(dirname "$0")/../.." && pwd)/lib/model-check.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

fx()  { printf '{"model": "%s"}' "$1" > "$T/s.json"; }
run() { MODEL_CHECK_SETTINGS="$T/s.json" bash "$S" >"$T/out" 2>&1; echo "$?"; }

fx 'claude-fable-5[1m]';        check T1-fable-exit "$(run)" 0
check T1-fable-class "$(cut -d: -f1 <"$T/out")" big
fx 'claude-opus-4-8';           check T2-opus       "$(run)" 0
fx 'claude-sonnet-5';           check T3-sonnet     "$(run)" 2
fx 'claude-haiku-4-5-20251001'; check T4-haiku      "$(run)" 2
fx 'opusplan';                  check T5-opusplan   "$(run)" 3
fx 'gpt-9-mega';                check T6-foreign    "$(run)" 3
printf '{"no_model": true}' > "$T/s.json"; check T7-no-key    "$(run)" 3
printf '{broken'            > "$T/s.json"; check T8-malformed "$(run)" 3
check T9-missing-file "$(MODEL_CHECK_SETTINGS="$T/absent.json" bash "$S" >/dev/null 2>&1; echo $?)" 3

printf 'model-check: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
