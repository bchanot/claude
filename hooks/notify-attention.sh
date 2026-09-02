#!/usr/bin/env bash
# Notification + Stop hook — signal the user through the terminal when
# Claude needs input (permission prompt, question, idle wait) or has
# finished responding.
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
#     The extension only instruments terminals created AFTER it is
#     active: install it first, then start or re-attach the session.
# Both are invisible no-ops in terminals that ignore them.
set -u

payload=$(cat 2>/dev/null)
read_field() {
  printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null \
    | tr -d '\000-\037' | cut -c1-200
}

msg=$(read_field '.message // .notification_type')
if [ -z "$msg" ]; then
  case "$(read_field '.hook_event_name')" in
    Stop) msg="Claude has finished responding" ;;
    *) msg="Claude Code needs your input" ;;
  esac
fi

bell=$(printf '\a')
esc=$(printf '\033')
seq="${bell}${bell}${esc}]777;notify;Claude Code;${msg}${esc}\\"
jq -cn --arg seq "$seq" '{suppressOutput: true, terminalSequence: $seq}'
exit 0
