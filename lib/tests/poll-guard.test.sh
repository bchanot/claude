#!/usr/bin/env bash
# lib/tests/poll-guard.test.sh
# hooks/poll-guard.sh: denies an unbounded until/while sleep loop (R2) and
# pgrep/pkill -f in a Monitor command or a loop (R1), silent on everything
# else. Also locks the settings.json wiring (last).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
H="$ROOT/hooks/poll-guard.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

OUT=""; RC=0
run() { # run <tool|-> <bg:true|false|absent> <cmd>
  local bg='{}'
  [ "$2" = absent ] || bg="{\"run_in_background\":$2}"
  OUT=$(printf '%s' "$3" | jq -Rs --arg t "$1" --argjson bg "$bg" \
    '{tool_input:({command:.} + $bg)} + (if $t == "-" then {}
      else {tool_name:$t} end)' | bash "$H" 2>/dev/null); RC=$?
}
decision() { printf '%s' "$OUT" \
  | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null; }
reason() { printf '%s' "$OUT" \
  | jq -r '.hookSpecificOutput.permissionDecisionReason' 2>/dev/null; }
# every Bash case runs foreground AND background
deny() { local m; for m in false true; do run Bash "$m" "$1"
  check "deny[$m][$1]" "$RC $(decision)" "0 deny"; done; }
allow() { local m; for m in false true; do run Bash "$m" "$1"
  check "allow[$m][$1]" "$RC [$OUT]" "0 []"; done; }
mdeny() { run Monitor absent "$1"
  check "mdeny[$1]" "$RC $(decision)" "0 deny"; }
mallow() { run Monitor absent "$1"
  check "mallow[$1]" "$RC [$OUT]" "0 []"; }
# line readers: one command per heredoc line, so no quoted string holds a $
denyl() { local l; while IFS= read -r l; do deny "$l"; done; }
allowl() { local l; while IFS= read -r l; do allow "$l"; done; }
has_r1() { reason | grep -c 'pgrep -f matches every shell'; }
has_r2() { reason | grep -c 'poll loop with no time bound'; }

# ── R2 deny: observed shapes reduced, then the variants ──
deny 'until [ -s f ] && ! grep -q x f; do sleep 5; done'
denyl <<'EOF'
S=/x; until grep -q y $S/f; do sleep 10; done; tail f
EOF
deny 'cd /p; until grep -qE "a|b" f; do sleep 5; done'
deny "until grep -q '^done' f; do sleep 5; done"
deny 'until timeout 3 nc -z h 5432; do sleep 1; done'
deny "timeout 0 bash -c 'until x; do sleep 1; done'"
deny "bash -c 'while true; do sleep 1; done'"
deny "timeout -k 5 0 bash -c 'until x; do sleep 1; done'"
deny "timeout -s 9 0 bash -c 'until x; do sleep 1; done'"
deny "timeout --kill-after 5 0 bash -c 'until x; do sleep 1; done'"
deny "gtimeout --signal KILL 0 bash -c 'until x; do sleep 1; done'"
deny $'while :; do\n  st=$(curl x)\n  sleep 12\ndone'
run Bash false 'until x; do sleep 1; done'
check r2-reason "$(has_r2)$(has_r1)" 10
check r2-reason-seconds "$(reason | grep -c 'SECONDS -ge 1800')" 1

# ── R2 allow: bounded loops and prose ──
allowl <<'EOF'
until grep -q R l || [ $SECONDS -ge 600 ]; do sleep 1; done
while [ "$SECONDS" -lt 600 ]; do sleep 1; done
until x || [ ${SECONDS} -ge 600 ]; do sleep 1; done
EOF
allow 'while (( SECONDS < 60 )); do sleep 1; done'
allow "timeout 600 bash -c 'until x; do sleep 5; done'"
allow "timeout -k 5 600 bash -c 'until x; do sleep 5; done'"
allow "gtimeout --foreground 10m sh -c 'until x; do sleep 5; done'"
allow "timeout -s KILL 600 bash -c 'until x; do sleep 1; done'"
allow "timeout --kill-after=5 600 bash -c 'until x; do sleep 1; done'"
allow "timeout --kill-after=5 -s KILL 30 bash -c 'until x; do sleep 1; done'"
allow 'npm run dev'
allow 'cargo test'
allow 'sleep 2'
allow 'for i in 1 2 3; do sleep 1; done'
allow 'git commit -m "fix(hooks): poll-guard (pgrep -f; until … sleep)"'
allow "grep -rnE 'pgrep -f|pkill -f' ."

# ── R1 deny ──
mdeny 'until ! pgrep -f "x y"; do sleep 1; done'
mdeny 'pkill -9 -f x'
mdeny 'pgrep -A -f x'
mdeny 'pgrep --ignore-ancestors -f x'
mdeny 'pgrep -xf "a b"'
mdeny 'pgrep --full x'
IFS= read -r R1CASE <<'EOF'
until ! pgrep -fa x || [ $SECONDS -ge 60 ]; do sleep 1; done
EOF
deny "$R1CASE"
run Bash false "$R1CASE"
check r1-alone "$(has_r1)$(has_r2)" 10
check r1-reason-marker "$(reason | grep -c "grep -q '^rc='")" 1
check r1-reason-no-pgrep-x "$(reason | grep -c 'pgrep -x')" 0
mdeny 'pgrep -x a; pkill -f b'

# ── R1 allow ──
mallow 'pgrep -x cargo'
mallow 'pgrep -x a & tail -f log'
mallow 'tail -f log'

# ── both rules: one deny, both texts ──
run Bash false 'until ! pgrep -f run-all.sh; do sleep 3; done'
check both-one-object "$(printf '%s' "$OUT" | jq -s length)" 1
check both-r1-then-r2 "$(has_r1) $(has_r2) $(reason \
  | grep -c '^poll-guard: pgrep -f .*poll-guard: poll loop')" "1 1 1"

# tool name absent is Bash
run - absent 'until x; do sleep 1; done'
check noname-loop "$RC $(decision)" "0 deny"
run - absent 'npm test'
check noname-plain "$RC [$OUT]" "0 []"
# Monitor gets no R2
mallow 'until x; do sleep 1; done'

# ── accepted false positives (documented in the hook header) ──
deny 'memory.sh add x --body "until ! pgrep -f x; do sleep 5; done"'
allow 'memory.sh add x --body-file /tmp/b'
deny $'while :; do\n  r=$(higgsfield generate get "$id")\n  sleep 10\ndone'

# ── plumbing ──
BASH_BIN=$(command -v bash)
mkdir -p "$WORK/shim"
ln -s "$(command -v grep)" "$WORK/shim/grep"
err=$(printf '%s' '{"tool_input":{"command":"until x; do sleep 1; done"}}' \
  | PATH="$WORK/shim" "$BASH_BIN" "$H" 2>&1 >"$WORK/o"); rc=$?
check nojq "$rc [$(cat "$WORK/o")] [$err]" \
  "0 [] [poll-guard: jq missing, guard inactive]"
run Bash false 'until x; do sleep 1; done'
check deny-json-shape "$(printf '%s' "$OUT" | jq -r \
  '.hookSpecificOutput | .hookEventName + " " + .permissionDecision')" \
  "PreToolUse deny"
out=$(printf 'not json' | bash "$H" 2>/dev/null); check badjson "$? [$out]" "0 []"
out=$(printf '{}' | bash "$H" 2>/dev/null); check nocmd "$? [$out]" "0 []"
check syntax "$(bash -n "$H" 2>&1; echo $?)" 0

# ── wiring (last): settings.json carries the entry ──
S="$ROOT/settings.json"
check wiring-entry "$(jq -e '[.hooks.PreToolUse[]
  | select(.matcher=="Bash|Monitor")
  | .hooks[] | select(.command=="bash ~/.claude/hooks/poll-guard.sh"
      and .timeout==10)] | length==1' "$S" 2>&1)" true

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
