#!/usr/bin/env bash
# poll-guard.sh — PreToolUse (Bash|Monitor): refuse the two shapes that leave
# a sub-agent "waiting on 1 shell" for days (diagnosis 2026-11-27):
#   R1  pgrep/pkill -f in a Monitor command or a poll loop: the Bash tool
#       runs `bash -c '<text>'`, so the shell's own argv (and any sibling
#       loop's) holds the pattern; pgrep -f always matches and the condition
#       never changes. -A does not help (siblings still match).
#   R2  a Bash until/while + sleep loop with no time bound: a foreground call
#       moves to the background at the tool timeout and is never killed.
# LOOP = the text holds the words until|while, sleep and done, and a `do`
# keyword right after `;` or a newline (quotes included: bash -c '...' counts).
# BOUNDED = a SECONDS comparison, or the command starts with timeout /
# gtimeout and a duration >= 1. Monitor gets no R2 (it has timeout_ms).
#
# Deny form: JSON on stdout, exit 0 (shape of hooks/extract-guard.sh).
# Silent on every allowed command. jq or grep missing, or grep failing (rc
# above 1): one stderr warning, allow. Plain text matching, no tokenizer.
#
# MISSES: a loop in a script file; a loop built by variable; `tail -f f |
# grep -q x`; $SECONDS inside a double-quoted inner script (expanded early);
# a standalone pkill -f outside any loop (Bash).
# ACCEPTED FALSE POSITIVES: prose holding a full loop with pgrep -f passed as
# an argument (--body "...; do ...; done": use a body file); unbounded
# `while :` polls taught by skills-external/higgsfield-*: add the SECONDS
# bound.
set -u

for t in jq grep; do
  command -v "$t" >/dev/null 2>&1 || {
    echo "poll-guard: $t missing, guard inactive" >&2
    exit 0
  }
done

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // "Bash"' 2>/dev/null) \
  || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' \
  2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

# has <text> <ERE>: 0 match, 1 no match; grep failure (rc > 1) allows
has() {
  printf '%s\n' "$1" | grep -qE -- "$2"
  local rc=$?
  [ "$rc" -le 1 ] || {
    echo "poll-guard: grep failed, guard inactive" >&2
    exit 0
  }
  return "$rc"
}

W='(^|[^[:alnum:]_-])'
E='([^[:alnum:]_-]|$)'
FLAG='(-[[:alnum:]]*f[[:alnum:]]*|--full)'
CMP='(-ge|-gt|-le|-lt|>=|<=|>|<)'
# options taking a separate argument consume it; flags and --opt=value / -kN
# forms consume nothing (a bare -k or -s must never fall in the flag branch)
OPT='([[:space:]]+(-k|-s|--kill-after|--signal)[[:space:]]+[^[:space:]]+'
OPT="$OPT|[[:space:]]+(--foreground|--preserve-status|--verbose|-v)"
OPT="$OPT|[[:space:]]+--[[:alnum:]-]+=[^[:space:]]+"
OPT="$OPT|[[:space:]]+-[ks][^[:space:]]+)*"
DUR='[[:space:]]+[0-9]*[1-9][0-9]*(\.[0-9]*)?[smhd]?([[:space:]]|$)'

is_loop() {
  has "$cmd" "${W}(until|while)$E" && has "$cmd" "${W}sleep$E" \
    && has "$cmd" "(^|;)[[:space:]]*do$E" && has "$cmd" "${W}done$E"
}

is_bounded() {
  has "$cmd" "${W}SECONDS[}\"]*[[:space:]]*$CMP" && return 0
  has "${cmd%%$'\n'*}" "^[[:space:]]*g?timeout$OPT$DUR"
}

has_self_match() {
  has "$cmd" \
    "${W}(pgrep|pkill)[[:space:]]([^;&|]*[[:space:]])?$FLAG([[:space:]]|\$)"
}

IFS= read -r -d '' R1 <<'TXT' || true
poll-guard: pgrep -f matches every shell whose command line holds the
pattern: this one and any sibling loop, so the condition never changes.
Wait on the job's own end instead: its completion notification, or an exit
marker it writes (`cmd >out 2>&1; echo "rc=$?" >>out`, then `until grep -q
'^rc=' out || [ $SECONDS -ge 1800 ]; do sleep 5; done`).
TXT
IFS= read -r -d '' R2 <<'TXT' || true
poll-guard: poll loop with no time bound: if its condition never comes
true, the shell outlives the tool timeout and the agent stays 'waiting on 1
shell' for days. Bound it inside the loop: `until <cond> || [ $SECONDS -ge
1800 ]; do sleep 5; done` (in a quoted inner script, single-quote it so
$SECONDS is not expanded early), or wait for the completion notification of
the command you are waiting on.
TXT
R1=${R1//$'\n'/ }; R2=${R2//$'\n'/ }

reason=""
if [ "$tool" = "Monitor" ]; then
  has_self_match && reason="$R1"
elif is_loop; then
  has_self_match && reason="$R1"
  is_bounded || reason="${reason:+$reason }$R2"
fi
[ -n "$reason" ] || exit 0

jq -cn --arg r "$reason" '{hookSpecificOutput:{
  hookEventName:"PreToolUse",permissionDecision:"deny",
  permissionDecisionReason:$r}}'
exit 0
