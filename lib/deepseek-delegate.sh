#!/usr/bin/env bash
# lib/deepseek-delegate.sh — engine of the deepseek-delegate skill.
# Runs one read-only task through a machine-local wrapper command: fixed
# flags, empty working directory, filtered environment, external time
# bound, completion check on the NDJSON stream.
# Usage: deepseek-delegate.sh status
#        deepseek-delegate.sh run --kind <explore|reflect|verify> <task-file>
# Exit: 0 ok · 2 usage · 3 off · 4 run failed or incomplete · 124 timeout.
# Config (optional): $HOME/.claude/deepseek-delegate.json, keys enabled,
# command, timeoutSeconds, passEnv. Bash 3.2-safe, GNU and BSD userland.
set -u

# pid of the perl runner; read by the signal trap, the only global state
RUNNER_PID=""

die_usage() {
  echo "usage: deepseek-delegate.sh status |" \
    "run --kind <explore|reflect|verify> <task-file>" >&2
  return 2
}

# py_config <path>: validated config as key=value lines on stdout
py_config() {
  python3 -I - "$1" <<'PY'
import json, os, re, sys
def bad(why):
    print("status=off: config invalid (%s)" % why)
    sys.exit(0)
path, cfg = sys.argv[1], {}
if os.path.exists(path):
    try:
        with open(path, "rb") as f:
            cfg = json.loads(f.read().decode("utf-8"))
    except Exception:
        bad("unparsable")
    if not isinstance(cfg, dict):
        bad("not an object")
enabled = cfg.get("enabled", True)
cmd = cfg.get("command", "dsh-deepseek")
limit = cfg.get("timeoutSeconds", 600)
names = cfg.get("passEnv", [])
if not isinstance(enabled, bool): bad("enabled")
if not (isinstance(cmd, str) and (re.fullmatch(r"[A-Za-z0-9_.-]+", cmd)
        or re.fullmatch(r"/[A-Za-z0-9_./-]+", cmd))): bad("command")
if not (type(limit) is int and 1 <= limit <= 3600): bad("timeoutSeconds")
if not (isinstance(names, list) and all(isinstance(n, str)
        and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", n) for n in names)):
    bad("passEnv")
if not enabled:
    print("status=off: disabled in config")
    sys.exit(0)
print("status=ok\ncommand=%s\ntimeout=%d\npassenv=%s"
      % (cmd, limit, " ".join(names)))
PY
}

# cfg_get <record> <key>: first value of key in a key=value record
cfg_get() {
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -n 1
}

# load_config: record with status=ok|off: <reason>, the config keys and
# commandpath (absolute, resolved once). Off reasons keep a fixed order.
load_config() {
  local rec cmd abs
  command -v python3 >/dev/null 2>&1 \
    || { echo "status=off: python3 missing"; return 0; }
  command -v perl >/dev/null 2>&1 \
    || { echo "status=off: perl missing"; return 0; }
  rec="$(py_config "$HOME/.claude/deepseek-delegate.json" 2>/dev/null)"
  case "$(cfg_get "$rec" status)" in
    ok) ;;
    off:*) printf '%s\n' "$rec"; return 0 ;;
    *) echo "status=off: config invalid (python failed)"; return 0 ;;
  esac
  cmd="$(cfg_get "$rec" command)"
  abs="$(command -v -- "$cmd" 2>/dev/null)"
  case "$abs" in
    /*) [ -f "$abs" ] && [ -x "$abs" ] || abs="" ;;
    *) abs="" ;;
  esac
  [ -n "$abs" ] || { echo "status=off: command not found ($cmd)"; return 0; }
  printf '%s\ncommandpath=%s\n' "$rec" "$abs"
}

cmd_status() {
  local rec state
  rec="$(load_config)"
  state="$(cfg_get "$rec" status)"
  if [ "$state" = ok ]; then echo on; return 0; fi
  echo "off: ${state#off: }"
  return 3
}

# write_runner <file>: perl runner. It stays in the engine's process
# group; the worker gets its own group, led by the wrapper's pid.
write_runner() {
  cat > "$1" <<'PL'
my ($marker, $limit, @cmd) = @ARGV;
my $pid;
sub stop { kill 'KILL', -$pid if $pid; }
$SIG{ALRM} = sub { open(my $m, '>', $marker); close($m); stop(); exit 124; };
$SIG{$_} = sub { stop(); exit 143; } for qw(TERM INT HUP);
$pid = fork();
exit 125 unless defined $pid;
if (!$pid) {
  $SIG{$_} = 'DEFAULT' for qw(TERM INT HUP ALRM);
  setpgrp(0, 0);
  alarm($limit + 30);
  exec { $cmd[0] } @cmd;
  exit 127;
}
setpgrp($pid, $pid);
alarm($limit);
waitpid($pid, 0);
my $st = $?;
alarm(0);
kill 'TERM', -$pid;
select(undef, undef, undef, 1);
kill 'KILL', -$pid;
exit(($st & 127) ? 128 + ($st & 127) : $st >> 8);
PL
}

# worker_env <record> <kind>: NAME=value entries, NUL-terminated
worker_env() {
  local n names="PATH HOME USER LOGNAME SHELL LANG LC_ALL TERM TMPDIR"
  names="$names $(cfg_get "$1" passenv)"
  for n in $names; do
    [ -n "${!n+x}" ] && printf '%s=%s\0' "$n" "${!n}"
  done
  printf '%s\0' "DEEPSEEK_DELEGATE_KIND=$2" DSH_TELEMETRY_DISABLED=1 \
    DSH_TELEMETRY_MODE=DISABLED
  return 0
}

# start_runner <record> <kind> <task> <work> <cwd>: runner in the
# background, working directory <cwd> (its own empty dir, outside <work>),
# pid in RUNNER_PID
start_runner() {
  local entry
  local envargs=()
  while IFS= read -r -d '' entry; do envargs+=("$entry"); done \
    < <(worker_env "$1" "$2")
  ( cd "$5" && exec env -i "${envargs[@]}" "$(command -v perl)" \
      "$4/runner.pl" "$4/timed-out" "$(cfg_get "$1" timeout)" \
      "$(cfg_get "$1" commandpath)" \
      --json --permission-mode read-only --approval-policy never - \
  ) < "$3" > "$4/stream" 2> "$4/log" &
  RUNNER_PID=$!
}

# wait_runner: a trap-interrupted wait returns early, so wait again
# until the runner is gone; returns the runner's status
wait_runner() {
  local rc
  wait "$RUNNER_PID"; rc=$?
  while kill -0 "$RUNNER_PID" 2>/dev/null; do wait "$RUNNER_PID"; rc=$?; done
  return "$rc"
}

# run_worker <record> <kind> <task> <work> <cwd>: runner status
run_worker() {
  local rc
  write_runner "$4/runner.pl"
  # no runner pid recorded yet: do nothing (kill 0 hits the whole group)
  trap '[ "${RUNNER_PID:-0}" -gt 0 ] &&
    kill -TERM "$RUNNER_PID" 2>/dev/null' TERM INT HUP
  start_runner "$1" "$2" "$3" "$4" "$5"
  wait_runner; rc=$?
  trap - TERM INT HUP
  return "$rc"
}

# judge_stream <work>: cause on stdout, rc 0 only when the stream is a
# completed run; the answer lands in <work>/answer
judge_stream() {
  python3 -I - "$1/stream" "$1/answer" 2>>"$1/log" <<'PY'
import json, re, sys
err, fin = False, None
with open(sys.argv[1], "rb") as f:
    data = f.read()
for raw in data.split(b"\n"):
    try:
        ev = json.loads(raw.decode("utf-8"))
    except Exception:
        continue
    if not isinstance(ev, dict):
        continue
    if ev.get("type") == "error":
        err = True
    elif ev.get("type") == "final":
        fin = ev
def cause():
    if err: return "error event"
    if fin is None: return "no final event"
    reason = fin.get("reason")
    kind = reason.get("kind") if isinstance(reason, dict) else None
    if kind != "completed":
        safe = ""
        if isinstance(kind, str):
            safe = re.sub(r"[^A-Za-z0-9_.-]", "", kind)[:40]
        return "final reason %s" % (safe or "null")
    if not isinstance(fin.get("text"), str): return "final text missing"
    return ""
why = cause()
if why:
    print(why)
    sys.exit(1)
with open(sys.argv[2], "wb") as out:
    out.write(fin["text"].encode("utf-8"))
PY
}

# verdict <work> <runner-rc>: cause on stdout, rc 0 ok · 4 · 124
verdict() {
  local cause
  [ -e "$1/timed-out" ] && { echo "timed out"; return 124; }
  [ "$2" -eq 143 ] && { echo "interrupted"; return 4; }
  [ "$2" -ne 0 ] && { echo "wrapper exit $2"; return 4; }
  cause="$(judge_stream "$1")" && return 0
  echo "${cause:-judge failed}"
  return 4
}

# remove_work <dir>: only a directory this engine created under TMPDIR
remove_work() {
  case "$1" in
    *..*) return 0 ;;
    "${TMPDIR:-/tmp}"/deepseek-delegate.*) rm -rf -- "$1" ;;
  esac
  return 0
}

# run_checked <record> <kind> <task>: one run, work dir lifecycle, output
run_checked() {
  local work cwd cause rc
  if ! work="$(mktemp -d "${TMPDIR:-/tmp}/deepseek-delegate.XXXXXX")" \
    || ! cwd="$(mktemp -d "${TMPDIR:-/tmp}/deepseek-delegate.XXXXXX")"; then
    remove_work "${work:-}"
    echo "deepseek-delegate: work dir failed" >&2; return 4
  fi
  run_worker "$1" "$2" "$3" "$work" "$cwd"; rc=$?
  remove_work "$cwd"
  cause="$(verdict "$work" "$rc")"; rc=$?
  if [ "$rc" -eq 0 ]; then
    cat "$work/answer"; remove_work "$work"; return 0
  fi
  echo "deepseek-delegate: $cause (log: $work)" >&2
  return "$rc"
}

cmd_run() {
  local rec task
  [ "$#" -eq 3 ] && [ "$1" = "--kind" ] || { die_usage; return 2; }
  case "$2" in explore|reflect|verify) ;; *) die_usage; return 2 ;; esac
  [ -f "$3" ] && [ -s "$3" ] || { die_usage; return 2; }
  case "$3" in /*) task="$3" ;; *) task="$PWD/$3" ;; esac
  rec="$(load_config)"
  if [ "$(cfg_get "$rec" status)" != ok ]; then
    echo "deepseek-delegate: $(cfg_get "$rec" status)" >&2
    return 3
  fi
  run_checked "$rec" "$2" "$task"
}

case "${1:-}" in
  status) [ "$#" -eq 1 ] || { die_usage; exit 2; }; cmd_status; exit $? ;;
  run) shift; cmd_run "$@"; exit $? ;;
  *) die_usage; exit 2 ;;
esac
