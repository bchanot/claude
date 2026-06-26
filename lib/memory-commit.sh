#!/usr/bin/env bash
# memory-commit.sh — surgically commit ONLY .claude/memory + .claude/tasks.
#
# Used by the dev-flow capitalize step (and, later, the v2 Stop hook) to couple
# the memory commit to the flow. Safety lives in the PATHSPEC, never in a human
# diff review — automation removes that review, so the scope must be airtight:
# code that happens to be dirty or staged is NEVER embarked.
#
# Usage (CLI):
#   memory-commit.sh pending             # exit 0 if memory/tasks have changes, 1 if clean
#   memory-commit.sh commit "<message>"  # surgical commit; exit 0 ok/no-op, 3 unsafe state
#
# Sourceable: `memory_pending` and `commit_memory` for the v2 hook.

set -uo pipefail

MC_PATHS=(".claude/memory" ".claude/tasks")

_in_git_repo() { git rev-parse --git-dir >/dev/null 2>&1; }

# True (0) when the repo is in a state where we must NOT auto-commit:
# detached HEAD, or a merge/rebase/cherry-pick in progress.
_unsafe_state() {
  local gitdir
  gitdir="$(git rev-parse --git-dir 2>/dev/null)" || return 0
  if [ -e "$gitdir/MERGE_HEAD" ] || [ -e "$gitdir/rebase-merge" ] ||
    [ -e "$gitdir/rebase-apply" ] || [ -e "$gitdir/CHERRY_PICK_HEAD" ]; then
    return 0
  fi
  git symbolic-ref -q HEAD >/dev/null 2>&1 || return 0 # detached HEAD
  return 1
}

# Scoped paths that have actual pending changes. A bare/empty path (e.g. an
# empty .claude/tasks dir) is excluded: `git commit -- <pathspec>` aborts the
# WHOLE commit on a pathspec that matches no known file, even though `git add`
# tolerates it. So scope = only paths git would accept.
_changed_paths() {
  local p
  for p in "${MC_PATHS[@]}"; do
    [ -e "$p" ] || continue
    [ -n "$(git status --porcelain -- "$p" 2>/dev/null)" ] && printf '%s\n' "$p"
  done
}

# 0 if something is pending under the scoped paths, 1 if clean / absent.
memory_pending() {
  _in_git_repo || return 1
  local changed
  mapfile -t changed < <(_changed_paths)
  [ "${#changed[@]}" -gt 0 ]
}

# Surgical commit of the scoped paths only. Returns 0 (ok or no-op), 3 (unsafe).
commit_memory() {
  local msg="${1:?commit message required}"
  _in_git_repo || {
    echo "memory-commit: not a git repo — skip"
    return 3
  }
  if _unsafe_state; then
    echo "memory-commit: detached HEAD or merge/rebase in progress — skip (no commit)"
    return 3
  fi
  local changed
  mapfile -t changed < <(_changed_paths)
  if [ "${#changed[@]}" -eq 0 ]; then
    echo "memory-commit: nothing pending — no-op"
    return 0
  fi
  # Re-stage working-tree content of the scoped paths over any stale index entry,
  # then commit ONLY those paths. The pathspec on `git commit` makes it a partial
  # commit: other staged files (dangling code) are not recorded.
  git add -- "${changed[@]}"
  if git diff --cached --quiet -- "${changed[@]}"; then
    echo "memory-commit: only ignored/no-op changes — no-op"
    return 0
  fi
  git commit -m "$msg" -- "${changed[@]}"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    pending) memory_pending ;;
    commit)
      shift
      commit_memory "${1:-}"
      ;;
    *)
      echo "usage: memory-commit.sh {pending | commit <message>}" >&2
      return 2
      ;;
  esac
}

# Run main only when executed, not when sourced.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
