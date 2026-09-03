#!/usr/bin/env bash
# Notification + Stop hook — signal the user through the terminal when
# Claude needs input (permission, question, idle wait) or has finished
# responding. Each case gets its own readable label so the toast says
# which one fired.
#
# Runs on the remote (Linux); the only channel that crosses SSH into the
# VS Code client is the terminal stream. Hooks have no controlling TTY,
# so the sequence goes through the supported `terminalSequence` JSON
# output field and Claude Code writes it to the terminal:
#   - BEL x2 (double beep) -> sound, needs VS Code setting
#     accessibility.signals.terminalBell { "sound": "on" } AND a non-zero
#     volume for Code in the Windows volume mixer (BLK-020).
#   - OSC 777 notify -> Windows toast via the client-side extension
#     "Terminal Notification" (wenbopan.vscode-terminal-osc-notifier).
#     A terminal can be deaf to OSC while the bell still rings; test it
#     before attaching a session to it (LRN-148).
# Both are invisible no-ops in terminals that ignore them.
set -u

payload=$(cat 2>/dev/null)
read_field() {
  printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null \
    | tr -d '\000-\037' | cut -c1-160
}

event=$(read_field '.notification_type')
[ -n "$event" ] || event=$(read_field '.hook_event_name')

case "$event" in
  Stop) label="Finished responding" ;;
  permission_prompt) label="Needs your permission" ;;
  agent_needs_input) label="Asks you a question" ;;
  idle_prompt) label="Waiting for you" ;;
  elicitation_dialog|elicitation_url_dialog) label="Needs your input" ;;
  *) label="Needs your attention" ;;
esac

detail=$(read_field '.message')
[ -z "$detail" ] || label="${label}: ${detail}"

bell=$(printf '\a')
esc=$(printf '\033')
seq="${bell}${bell}${esc}]777;notify;Claude Code;${label}${esc}\\"
jq -cn --arg seq "$seq" '{suppressOutput: true, terminalSequence: $seq}'
exit 0
