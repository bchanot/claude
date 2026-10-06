#!/usr/bin/env bash
# hooks/unpushed-guard.sh — SessionStart + Stop: surface work that exists on
# this disk only (BDR-095). The 21/09 wipe cost four days of commits that had
# never left the machine; the post-commit hook now pushes every commit, so a
# branch ahead of its upstream is a real signal (push refused, offline, hook
# not installed), not noise.
#
# Non-blocking by contract: a systemMessage for the user, never a decision.
# SessionStart also reports uncommitted changes (a dead session leaves some
# behind); Stop reports unpushed commits only, since a dirty tree mid-work is
# the normal state at a turn end.
set -u

payload=$(cat 2>/dev/null)
field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }
event=$(field '.hook_event_name')
cwd=$(field '.cwd'); [ -n "$cwd" ] || cwd=$PWD
cd "$cwd" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
br=$(git symbolic-ref --short -q HEAD 2>/dev/null) || exit 0

# Commits that no remote holds, as one clause; empty when everything is pushed.
unpushed_clause() {
  local up n
  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "no 'origin' remote, every commit lives on this disk only"
    return
  fi
  if up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
    n=$(git rev-list --count "$up..HEAD" 2>/dev/null || echo 0)
    [ "$n" -gt 0 ] && echo "$n commit(s) on '$br' not on $up, push: git push"
  else
    # commits no remote-tracking ref holds: the ones only this disk has
    n=$(git rev-list --count HEAD --not --remotes 2>/dev/null || echo 0)
    echo "'$br' has no upstream ($n commit(s) on this disk only), push: git push -u origin $br"
  fi
}

msg=$(unpushed_clause)
if [ "$event" = "SessionStart" ]; then
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$dirty" -gt 0 ] && msg="${msg:+$msg; }$dirty uncommitted change(s) in $cwd"
fi
[ -n "$msg" ] || exit 0

msg="⚠ unpushed work: $msg"
if [ "$event" = "SessionStart" ]; then
  jq -cn --arg m "$msg" \
    '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $m}}'
else
  jq -cn --arg m "$msg" '{systemMessage: $m}'
fi
