#!/usr/bin/env bash
# doc-commit.sh — surgically commit ONLY the PUBLIC-DOC files doc-sync patched.
#
# Twin of memory-commit.sh, INVERSE scope: memory-commit TARGETS .claude/; this
# one commits public docs and must NEVER touch .claude/ or CLAUDE.md (BDR-022).
# Safety lives in the (dynamic) PATHSPEC + a fail-closed scope guard, never in a
# human diff review — automation removes that review, so the scope must be airtight.
#
# The scope guard is fail-CLOSED and LOUD: a forbidden path (.claude/** or
# CLAUDE.md) in the list is an UPSTREAM bug — doc-syncer must never patch those
# (BDR-022). Seeing one, ABORT THE WHOLE COMMIT and signal; do NOT silently filter
# it and commit the rest. A half-commit with no alert would MASK the violation.
# Caller passes EXACTLY the files doc-sync patched this run.
#
# Usage (CLI):
#   doc-commit.sh pending <file>...            # exit 0 if any passed file has changes, 1 if clean
#   doc-commit.sh commit "<message>" <file>... # surgical commit
#
# Exit codes (commit): 0 ok/no-op · 2 usage · 3 unsafe git state · 4 scope violation ·
#   5 commit rejected (git commit exited non-zero — hook / protected branch / signing).
# Output contract: diagnostics → stderr; on a real commit the short hash of the doc
# commit is the ONLY thing on stdout (empty on no-op/abort), so callers can capture
# it: doc_hash=$(doc-commit.sh commit "msg" README.md USAGE.md).
#
# Sourceable: docs_pending and commit_docs for the v2 hook.

set -uo pipefail

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

# True (0) when a path is OUT OF SCOPE for a doc commit: anything under .claude/
# (any depth) or a CLAUDE.md (root or nested). These are doc-syncer's read-only
# context, never sync targets (BDR-022) — their presence is an upstream anomaly.
_forbidden_path() {
  case "$1" in
    .claude | .claude/* | */.claude/* | CLAUDE.md | */CLAUDE.md) return 0 ;;
    *) return 1 ;;
  esac
}

# Print every forbidden path in the argument list, one per line (empty = none).
_scope_violations() {
  local p
  for p in "$@"; do
    _forbidden_path "$p" && printf '%s\n' "$p"
  done
}

# Of the passed paths, those that EXIST and have real pending changes. A clean or
# absent path is dropped (not fatal): `git commit -- <no-match>` aborts the WHOLE
# commit, while `git add` tolerates it — so scope = only paths git would accept.
_changed_paths() {
  local p
  for p in "$@"; do
    [ -e "$p" ] || continue
    [ -n "$(git status --porcelain -- "$p" 2>/dev/null)" ] && printf '%s\n' "$p"
  done
}

# 0 if any passed path has pending changes, 1 if all clean / absent.
docs_pending() {
  _in_git_repo || return 1
  local changed
  mapfile -t changed < <(_changed_paths "$@")
  [ "${#changed[@]}" -gt 0 ]
}

# Surgical commit of the passed doc paths only. Returns 0 (ok/no-op), 3 (unsafe),
# 4 (scope violation), 5 (commit rejected by git). On a real commit, prints the
# doc-commit short hash to stdout.
commit_docs() {
  local msg="${1:?commit message required}"
  shift
  _in_git_repo || {
    echo "doc-commit: not a git repo — skip" >&2
    return 3
  }
  if _unsafe_state; then
    echo "doc-commit: detached HEAD or merge/rebase in progress — skip (no commit)" >&2
    return 3
  fi
  # FAIL-CLOSED scope guard. A forbidden path is an upstream BDR-022 violation
  # (doc-syncer must never patch .claude/ or CLAUDE.md). Abort the WHOLE commit and
  # name the offenders — never filter-and-commit-the-rest (that masks the bug).
  local violations
  mapfile -t violations < <(_scope_violations "$@")
  if [ "${#violations[@]}" -gt 0 ]; then
    {
      echo "doc-commit: REFUSED — out-of-scope path(s) in the doc list (upstream BDR-022 violation):"
      printf '  - %s\n' "${violations[@]}"
      echo "doc-commit: NOTHING committed. doc-syncer must never patch .claude/ or CLAUDE.md —" \
        "investigate why these surfaced before retrying."
    } >&2
    return 4
  fi
  local changed
  mapfile -t changed < <(_changed_paths "$@")
  if [ "${#changed[@]}" -eq 0 ]; then
    echo "doc-commit: nothing pending — no-op" >&2
    return 0
  fi
  # Re-stage working-tree content over any stale index entry, then commit ONLY
  # those paths. The pathspec on `git commit` makes it partial: other staged files
  # (dangling code) are not recorded.
  git add -- "${changed[@]}"
  if git diff --cached --quiet -- "${changed[@]}"; then
    echo "doc-commit: only ignored/no-op changes — no-op" >&2
    return 0
  fi
  # FAIL-LOUD on the commit itself. With `set -uo pipefail` (no -e), a rejected
  # commit (pre-commit hook on a protected branch, signing failure, …) would NOT
  # abort: the printf below would falsely claim "committed" and rev-parse would
  # emit the PREVIOUS HEAD's hash with exit 0 — a silent masked failure. The
  # script is fail-closed+loud on scope (exit 4); it must be the same on its own
  # commit. Reject → loud, NO hash on stdout, exit 5 (distinct from rc 3 "could
  # not start": rc 5 = "tried, git refused").
  if ! git commit -q -m "$msg" -- "${changed[@]}"; then
    {
      echo "doc-commit: COMMIT REJECTED — git commit exited non-zero" \
        "(pre-commit hook? protected branch? signing?)."
      echo "doc-commit: NOTHING committed, working tree left as-is," \
        "NO hash emitted — investigate before retry."
    } >&2
    return 5
  fi
  printf 'doc-commit: committed %d file(s): %s\n' "${#changed[@]}" "${changed[*]}" >&2
  git rev-parse --short HEAD
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    pending)
      shift
      docs_pending "$@"
      ;;
    commit)
      shift
      commit_docs "$@"
      ;;
    *)
      echo "usage: doc-commit.sh {pending <file>... | commit <message> <file>...}" >&2
      return 2
      ;;
  esac
}

# Run main only when executed, not when sourced.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
