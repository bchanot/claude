#!/usr/bin/env bash
# lib/tests/rtk-rewrite.test.sh
# job7 — printenv/env dump redaction pass in hooks/rtk-rewrite.sh.
set -u
H="$(cd "$(dirname "$0")/../.." && pwd)/hooks/rtk-rewrite.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

# raw(cmd) -> the hook's stdout for a simulated PreToolUse Bash command.
raw() {
  local input
  input=$(jq -n --arg cmd "$1" '{tool_input:{command:$cmd}}')
  printf '%s' "$input" | bash "$H"
}

# fire(cmd) -> "redacted" if the hook appended the sed redaction pipe,
# "intact" if the command comes back unchanged/untouched.
fire() {
  if raw "$1" | grep -q 'sed -E'; then echo redacted; else echo intact; fi
}

# --- Env/printenv dumps must be redacted ---
check T1-bare-printenv   "$(fire 'printenv')"        redacted
check T2-bare-env        "$(fire 'env')"              redacted
check T3-env-pipe-grep   "$(fire 'env | grep FOO')"   redacted

# --- `env VAR=x cmd` launches a subprocess — legitimate, left intact ---
check T4-env-legit       "$(fire 'env FOO=bar cmd')"  intact
check T5-env-legit-2vars "$(fire 'env A=1 B=2 cmd')"  intact

# --- Compound commands bail untouched (never attach the pipe to the wrong
#     segment) ---
check T6-bail-and        "$(fire 'env && true')"      intact
check T7-bail-semi       "$(fire 'env; true')"        intact
check T8-bail-or         "$(fire 'env || true')"       intact

# --- Regression: unrelated rtk-eligible commands still rewrite, untouched
#     by the redaction pass ---
check T9-unrelated-still-rewrites \
  "$(raw 'cat /etc/hostname' | grep -c 'rtk ')" "1"
check T10-unrelated-not-redacted \
  "$(raw 'cat /etc/hostname' | grep -c 'sed -E')" "0"

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
