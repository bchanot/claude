#!/usr/bin/env bash
# Notification hook — signal the user through the terminal when Claude
# needs input (permission prompt, question, idle wait).
#
# Runs on the remote (Linux); the only channel that crosses SSH into the
# VS Code client is the terminal stream. Hooks have no controlling TTY,
# so the sequence goes through the supported `terminalSequence` JSON
# output field and Claude Code writes it to the terminal:
#   - BEL x2 (double beep) -> sound, needs VS Code setting
#     accessibility.signals.terminalBell { "sound": "on" }
#   - OSC 777 notify -> Windows toast via the client-side extension
#     "Terminal Notification" (wenbopan.vscode-terminal-osc-notifier)
# Both are invisible no-ops in terminals that ignore them.
set -u

msg=$(jq -r '.message // .notification_type // empty' 2>/dev/null \
  | tr -d '\000-\037' | cut -c1-200)
[ -n "$msg" ] || msg="Claude Code needs your input"

bell=$(printf '\a')
esc=$(printf '\033')
seq="${bell}${bell}${esc}]777;notify;Claude Code;${msg}${esc}\\"
jq -cn --arg seq "$seq" '{suppressOutput: true, terminalSequence: $seq}'
exit 0
