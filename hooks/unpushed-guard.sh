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
#
# Manual-push mode (git config gitflow.autopush false, human-set): unpushed
# work is expected, so Stop stays silent; SessionStart gives one info line
# counting every local branch, with the branches to push by hand.
set -u

payload=$(cat 2>/dev/null)
field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }
event=$(field '.hook_event_name')
cwd=$(field '.cwd'); [ -n "$cwd" ] || cwd=$PWD
cd "$cwd" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
br=$(git symbolic-ref --short -q HEAD 2>/dev/null) || exit 0

raw=$(git config gitflow.autopush 2>/dev/null)
manual=0; invalid=0
[ "$(git config --bool --default true gitflow.autopush 2>/dev/null)" = false ] && manual=1
[ -n "$raw" ] && ! git config --bool gitflow.autopush >/dev/null 2>&1 && invalid=1
[ "$manual" = 1 ] && [ "$event" != SessionStart ] && exit 0   # BDR-087: info at start only

# Local branches holding commits no remote has, one per line.
ahead_branches() {
  local b
  while IFS= read -r b; do
    [ "$(git rev-list --count "$b" --not --remotes 2>/dev/null)" -gt 0 ] && echo "$b"
  done < <(git for-each-ref --format='%(refname:short)' refs/heads)
}

# Manual mode: commits on every local branch that no remote holds.
manual_clause() {
  local n list first
  n=$(git rev-list --count --branches --not --remotes 2>/dev/null || echo 0)
  [ "$n" -gt 0 ] || return 0
  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "no 'origin' remote, $n commit(s) on this disk only"
    return
  fi
  list=$(ahead_branches); first=$(printf '%s\n' "$list" | head -n 1)
  echo "$n commit(s) not on origin ($(printf '%s' "$list" | paste -sd, - | sed 's/,/, /g')), push by hand: git push -u origin $first"
}

# Commits that no remote holds, as one clause; empty when everything is pushed.
unpushed_clause() {
  local up n
  [ "$manual" = 1 ] && { manual_clause; return; }
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
if [ "$invalid" = 1 ] && [ "$event" = "SessionStart" ]; then
  msg="${msg:+$msg; }gitflow.autopush='$raw' is not a boolean, treated as auto (pushes run)"
fi
[ -n "$msg" ] || exit 0

if [ "$manual" = 1 ]; then msg="ℹ manual push mode: $msg"; else msg="⚠ unpushed work: $msg"; fi
if [ "$event" = "SessionStart" ]; then
  jq -cn --arg m "$msg" \
    '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $m}}'
else
  jq -cn --arg m "$msg" '{systemMessage: $m}'
fi
