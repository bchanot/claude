#!/usr/bin/env bash
# memory-commit.sh — surgically commit ONLY .claude/memory + .claude/tasks.
#
# Used by the dev-flow capitalize step to couple the memory commit to the
# flow. Safety lives in the PATHSPEC, never in a human diff review —
# automation removes that review, so the scope must be airtight: code that
# happens to be dirty or staged is NEVER embarked.
#
# Usage (CLI):
#   memory-commit.sh commit "<message>"  # surgical commit; exit 0 ok/no-op, 3 unsafe state
#
# Output contract for `commit`: diagnostics go to stderr; on a real commit the
# short hash of the MEMORY commit is the ONLY thing on stdout (empty on no-op or
# unsafe), so callers can capture it: `mem_hash=$(memory-commit.sh commit "msg")`.
#
# Sourceable: `commit_memory`.

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

# Surgical commit of the scoped paths only. Returns 0 (ok or no-op), 3 (unsafe).
# On a real commit, prints the memory-commit short hash to stdout (stderr = diag).
commit_memory() {
  local msg="${1:?commit message required}"
  _in_git_repo || {
    echo "memory-commit: not a git repo — skip" >&2
    return 3
  }
  if _unsafe_state; then
    echo "memory-commit: detached HEAD or merge/rebase in progress — skip (no commit)" >&2
    return 3
  fi
  local changed
  mapfile -t changed < <(_changed_paths)
  if [ "${#changed[@]}" -eq 0 ]; then
    echo "memory-commit: nothing pending — no-op" >&2
    return 0
  fi
  # Re-stage working-tree content of the scoped paths over any stale index entry,
  # then commit ONLY those paths. The pathspec on `git commit` makes it a partial
  # commit: other staged files (dangling code) are not recorded.
  git add -- "${changed[@]}"
  if git diff --cached --quiet -- "${changed[@]}"; then
    echo "memory-commit: only ignored/no-op changes — no-op" >&2
    return 0
  fi
  # Contract: diagnostics go to stderr; on success ONLY the memory-commit short
  # hash goes to stdout, so a caller can do `mem_hash=$(... commit "msg")`.
  # FAIL-LOUD on the commit itself. With `set -uo pipefail` (no -e), a rejected
  # commit (pre-commit hook on a protected branch, signing failure, …) would NOT
  # abort: the line below would falsely claim "committed" and rev-parse would
  # emit the PREVIOUS HEAD's hash with exit 0 — a silent masked failure. Reject
  # → loud, NO hash on stdout, exit 5 (mirrors doc-commit.sh's rc 5).
  if ! git commit -q -m "$msg" -- "${changed[@]}"; then
    {
      echo "memory-commit: COMMIT REJECTED — git commit exited non-zero" \
        "(pre-commit hook? protected branch? signing?)."
      echo "memory-commit: NOTHING committed, working tree left as-is," \
        "NO hash emitted — investigate before retry."
    } >&2
    return 5
  fi
  git rev-parse --short HEAD
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    commit)
      shift
      commit_memory "${1:-}"
      ;;
    *)
      echo "usage: memory-commit.sh commit <message>" >&2
      return 2
      ;;
  esac
}

# Run main only when executed, not when sourced.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
