#!/usr/bin/env bash
# lib/tests/deepseek-delegate.test.sh — lib/deepseek-delegate.sh against a
# stub wrapper reached through an absolute path in the test config.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
E="$ROOT/lib/deepseek-delegate.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" TMPDIR="$tmp/tmp"
mkdir -p "$HOME/.claude" "$TMPDIR" "$tmp/bin"
STUB="$tmp/bin/stub-wrapper"
TASK="$tmp/task.txt"; printf 'do the thing\nline two\n' > "$TASK"
: > "$tmp/empty.txt"

cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
o="$STUB_OUT"
printf '%s\n' "$@" > "$o/argv"
cat > "$o/stdin"
pwd -P > "$o/cwd"; ls -A > "$o/listing"; env > "$o/env"
echo "STUB-STDERR-NOISE" >&2
fin='{"type":"final","sessionId":"s","reason":{"kind":"completed"},'
fin="$fin"'"text":"caf\u00e9"}'
case "$STUB_MODE" in
  ok) echo '{"type":"start"}'; echo "$fin" ;;
  noise) echo garbage; echo 42; echo '[1]'; echo '{"type":"x"}'; echo "$fin"
    echo 'trailing junk' ;;
  emptytext) echo '{"type":"final","reason":{"kind":"completed"},"text":""}' ;;
  nofinal) echo '{"type":"start"}' ;;
  aborted) echo '{"type":"final","reason":{"kind":"aborted"},"text":"x"}' ;;
  nullreason) echo '{"type":"final","reason":null,"text":"x"}' ;;
  notext) echo '{"type":"final","reason":{"kind":"completed"}}' ;;
  errorevent) echo '{"type":"error","message":"boom"}'; echo "$fin" ;;
  exit1) echo "$fin"; exit 1 ;;
  exit124) echo "$fin"; exit 124 ;;
  linger) ( trap '' TERM; exec sleep 300 ) >/dev/null 2>&1 &
    echo $! > "$o/child"; echo "$fin" ;;
  sleep) sleep 300 & echo "$$ $!" > "$o/pids"; wait ;;
esac
exit 0
STUBEOF
chmod +x "$STUB"

setcfg() { printf '%s' "$1" > "$HOME/.claude/deepseek-delegate.json"; }
stdcfg() {
  setcfg "{\"command\":\"$STUB\",\"passEnv\":[\"STUB_MODE\",\"STUB_OUT\"]$1}"
}
n=0
runcase() { # runcase <mode> <engine args…> -> OUT ERR RC, stub dir in SO
  n=$((n+1)); SO="$tmp/o$n"; mkdir -p "$SO"
  OUT="$(STUB_MODE="$1" STUB_OUT="$SO" DD_CANARY=leak bash "$E" "${@:2}" \
    2>"$tmp/err")"; RC=$?
  ERR="$(cat "$tmp/err")"
}
nlines() { printf '%s' "$1" | grep -c ''; }
workdirs() { find "$TMPDIR" -maxdepth 1 -name 'deepseek-delegate.*' \
  | wc -l | tr -d ' '; }
alive() { kill -0 "$1" 2>/dev/null; }

# poll_alive <stub-out>: bounded 5 s, pid file there and both pids alive
poll_alive() {
  local i=0 a b
  while [ "$i" -lt 100 ]; do
    if [ -s "$1/pids" ]; then
      read -r a b < "$1/pids"
      if alive "$a" && alive "$b"; then return 0; fi
    fi
    sleep 0.05; i=$((i+1))
  done
  return 1
}
poll_gone() { # poll_gone <stub-out>: bounded 5 s, both pids gone
  local i=0 a b
  read -r a b < "$1/pids"
  while [ "$i" -lt 100 ]; do
    if ! alive "$a" && ! alive "$b"; then return 0; fi
    sleep 0.05; i=$((i+1))
  done
  return 1
}

# --- status on, then every off case (stub never run) ---
stdcfg ""
check S1-status-on "$(bash "$E" status; echo "rc$?")" "$(printf 'on\nrc0')"
mkdir -p "$tmp/bin_u"; cp "$STUB" "$tmp/bin_u/stub_wrapper"
setcfg "{\"command\":\"$tmp/bin_u/stub_wrapper\"}"
check S2-underscore-path "$(bash "$E" status; echo "rc$?")" \
  "$(printf 'on\nrc0')"
stdcfg ""
off_case() { # off_case <name> <config json>
  setcfg "$2"
  runcase ok run --kind explore "$TASK"
  check "$1-run-rc" "$RC" 3
  check "$1-run-silent" "$OUT" ""
  check "$1-run-oneline" "$(nlines "$ERR")" 1
  check "$1-stub-unrun" "$([ -e "$SO/argv" ] && echo ran || echo no)" no
  check "$1-status-rc" "$(bash "$E" status >/dev/null; echo $?)" 3
  check "$1-status-text" "$(bash "$E" status | cut -c1-4)" "off:"
}
off_case O1-absent '{"command":"/nonexistent/dd-stub"}'
off_case O2-disabled "{\"command\":\"$STUB\",\"enabled\":false}"
off_case O3-badjson '{"command":'
off_case O4-badcmd '{"command":"bad cmd;x"}'
off_case O5-rel1 '{"command":"./x"}'
off_case O6-rel2 '{"command":"bin/x"}'
off_case O7-tbool '{"timeoutSeconds":true}'
off_case O8-tfloat '{"timeoutSeconds":1.5}'
off_case O9-tstr '{"timeoutSeconds":"600"}'
off_case O10-enstr '{"enabled":"false"}'
off_case O11-passenv '{"passEnv":["OK","bad-name"]}'
off_case O12-notobj '[1]'
off_case O13-tzero '{"timeoutSeconds":0}'

# --- ok run: output, work dir, argv, stdin, cwd, environment ---
stdcfg ""
before="$(workdirs)"
runcase ok run --kind explore "$TASK"
check R1-rc "$RC" 0
check R1-text "$OUT" "$(printf 'caf\303\251')"
check R1-stderr-empty "$ERR" ""
check R1-workdir-removed "$(workdirs)" "$before"
want="--json --permission-mode read-only --approval-policy never -"
check R2-argv "$(tr '\n' ' ' < "$SO/argv" | sed 's/ $//')" "$want"
check R3-stdin "$(cmp -s "$TASK" "$SO/stdin" && echo same)" same
check R4-cwd-differs "$([ "$(cat "$SO/cwd")" != "$(pwd -P)" ] && echo yes)" yes
check R4-cwd-empty "$([ ! -s "$SO/listing" ] && echo empty)" empty
check R5-kind "$(grep -c '^DEEPSEEK_DELEGATE_KIND=explore$' "$SO/env")" 1
check R5-tel1 "$(grep -c '^DSH_TELEMETRY_DISABLED=1$' "$SO/env")" 1
check R5-tel2 "$(grep -c '^DSH_TELEMETRY_MODE=DISABLED$' "$SO/env")" 1
check R5-canary-absent "$(grep -c '^DD_CANARY=' "$SO/env")" 0
check R5-passenv "$(grep -c '^STUB_MODE=ok$' "$SO/env")" 1
runcase noise run --kind reflect "$TASK"
check R6-noise "$RC:$OUT" "0:$(printf 'caf\303\251')"
runcase emptytext run --kind verify "$TASK"
check R7-emptytext "$RC:$OUT" "0:"

# --- failure cases: exit 4, silent stdout, one line, named cause ---
fail_case() { # fail_case <mode> <cause> [rc]
  local b; b="$(workdirs)"
  runcase "$1" run --kind explore "$TASK"
  check "F-$1-rc" "$RC" "${3:-4}"
  check "F-$1-stdout" "$OUT" ""
  check "F-$1-oneline" "$(nlines "$ERR")" 1
  check "F-$1-cause" "$(printf '%s' "$ERR" | grep -c -F -- "$2")" 1
  check "F-$1-nocopy" "$(printf '%s' "$ERR" | grep -c STUB-STDERR)" 0
  check "F-$1-kept" "$(workdirs)" "$((b+1))"
}
fail_case nofinal "no final event"
fail_case aborted "final reason aborted"
fail_case nullreason "final reason null"
fail_case notext "final text missing"
fail_case errorevent "error event"
fail_case exit1 "wrapper exit 1"
fail_case exit124 "wrapper exit 124"

# --- worker cwd: own empty dir, outside the work dir, gone after ---
b="$(workdirs)"
runcase nofinal run --kind explore "$TASK"
wd="$(printf '%s' "$ERR" | sed -n 's/.*(log: \(.*\))$/\1/p')"
wcwd="$(cat "$SO/cwd")"
check C1-stub-ran "$([ -s "$SO/cwd" ] && [ -e "$SO/listing" ] && echo yes)" yes
check C1-workdir-kept "$([ -d "$wd" ] && echo yes)" yes
check C1-cwd-not-caller "$([ "$wcwd" != "$(pwd -P)" ] && echo yes)" yes
check C1-cwd-not-in-work "$(case "$wcwd/" in \
  "$(cd "$wd" && pwd -P)"/*) echo in ;; *) echo out ;; esac)" out
check C1-cwd-empty "$([ ! -s "$SO/listing" ] && echo empty)" empty
check C1-cwd-gone "$([ -e "$wcwd" ] && echo there || echo gone)" gone
check C1-only-work-left "$(workdirs)" "$((b+1))"
rm -rf "$wd"

# --- linger: a TERM-proof child of the worker is killed at the end ---
stdcfg ",\"timeoutSeconds\":30"
n=$((n+1)); SO="$tmp/o$n"; mkdir -p "$SO"
STUB_MODE=linger STUB_OUT="$SO" bash "$E" run --kind explore "$TASK" \
  >"$tmp/lout" 2>"$tmp/lerr" &
EPID=$!
i=0; child=""
while [ "$i" -lt 100 ]; do
  [ -s "$SO/child" ] && child="$(cat "$SO/child")" && alive "$child" && break
  child=""; sleep 0.05; i=$((i+1))
done
check L1-alive "$([ -n "$child" ] && echo yes)" yes
wait "$EPID"; check L1-rc "$?" 0
check L1-text "$(cat "$tmp/lout")" "$(printf 'caf\303\251')"
i=0; gone=""
while [ "$i" -lt 100 ]; do
  alive "$child" || { gone=yes; break; }
  sleep 0.05; i=$((i+1))
done
check L1-gone "$gone" yes

# --- kill cases: poll first so a vacuous pass is impossible ---
kill_run() { # kill_run <timeout> -> EPID, SO; engine in background
  stdcfg ",\"timeoutSeconds\":$1"
  n=$((n+1)); SO="$tmp/o$n"; mkdir -p "$SO"
  STUB_MODE=sleep STUB_OUT="$SO" bash "$E" run --kind explore "$TASK" \
    >"$tmp/kout" 2>"$tmp/kerr" &
  EPID=$!
}
kill_run 1
check K1-alive "$(poll_alive "$SO" && echo yes)" yes
wait "$EPID"; check K1-rc "$?" 124
check K1-stdout "$(cat "$tmp/kout")" ""
check K1-oneline "$(nlines "$(cat "$tmp/kerr")")" 1
check K1-gone "$(poll_gone "$SO" && echo yes)" yes

kill_run 30
check K2-alive "$(poll_alive "$SO" && echo yes)" yes
kill -TERM "$EPID"
wait "$EPID"; check K2-rc "$?" 4
check K2-cause "$(grep -c -F 'interrupted' "$tmp/kerr")" 1
check K2-stdout "$(cat "$tmp/kout")" ""
check K2-oneline "$(nlines "$(cat "$tmp/kerr")")" 1
check K2-gone "$(poll_gone "$SO" && echo yes)" yes

# --- usage errors (stub never run) ---
stdcfg ""
usage_case() { # usage_case <name> <engine args…>
  runcase ok "${@:2}"
  check "$1-rc" "$RC" 2
  check "$1-stub-unrun" "$([ -e "$SO/argv" ] && echo ran || echo no)" no
}
usage_case U1-missing-file run --kind explore "$tmp/nope.txt"
usage_case U2-empty-file run --kind explore "$tmp/empty.txt"
usage_case U3-no-kind run "$TASK"
usage_case U4-bad-kind run --kind write "$TASK"
usage_case U5-no-verb

# --- trap handler: no runner pid recorded -> no group signal ---
# The harness leads its own process group (perl setpgrp), so a group
# signal can never reach the suite; a sentinel in that group is the probe.
trapcmd="$(sed -n "/^  trap '\[ /,/TERM INT HUP\$/p" "$E" \
  | sed -e "s/ TERM INT HUP\$//" -e "s/^  trap //")"
check T1-trap-extracted "$(printf '%s' "$trapcmd" | grep -c 'kill -TERM')" 1
cat > "$tmp/harness.sh" <<'HEOF'
RUNNER_PID="$2"
sleep 30 & echo $! > "$1/sentinel"
eval "trap $3 TERM"
kill -TERM $$; sleep 1
kill -0 "$(cat "$1/sentinel")" 2>/dev/null && echo sentinel-alive
kill "$(cat "$1/sentinel")" 2>/dev/null
HEOF
group_run() { # group_run <runner pid value> <trap action> -> stdout
  mkdir -p "$tmp/g"; rm -f "$tmp/g/sentinel"
  perl -e 'use POSIX; setpgrp(0,0) or die; exec @ARGV' \
    bash "$tmp/harness.sh" "$tmp/g" "$1" "$2" 2>/dev/null
}
check T1-control-group-kill "$(group_run "" "'kill -TERM 0; :'")" ""
check T1-empty-pid "$(group_run "" "$trapcmd")" sentinel-alive
check T1-zero-pid "$(group_run 0 "$trapcmd")" sentinel-alive
check T1-negative-pid "$(group_run -1 "$trapcmd")" sentinel-alive
sleep 30 & spid=$!
group_run "$spid" "$trapcmd" >/dev/null
wait "$spid"; check T1-recorded-pid-term "$?" 143

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
