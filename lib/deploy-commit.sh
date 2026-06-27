#!/usr/bin/env bash
# deploy-commit.sh — surgical commit for the .claude/deploy/ runbook family.
# Allowlist scope = .claude/deploy/ ONLY (inverse of doc-commit's .claude exclusion).
set -u

_in_git_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

_unsafe_state() {                       # 0 = unsafe
  local g; g=$(git rev-parse --git-dir 2>/dev/null) || return 0
  git symbolic-ref -q HEAD >/dev/null 2>&1 || return 0     # detached HEAD
  [ -e "$g/MERGE_HEAD" ] || [ -d "$g/rebase-merge" ] || \
    [ -d "$g/rebase-apply" ] || [ -e "$g/CHERRY_PICK_HEAD" ] && return 0
  return 1
}

_out_of_scope() {                       # 0 = forbidden, 1 = in scope
  case "$1" in
    *..*) return 0 ;;                   # traversal — forbidden FIRST
    .claude/deploy/*) return 1 ;;       # allowed
    *) return 0 ;;                      # everything else forbidden
  esac
}

_scope_violations() { local p; for p in "$@"; do _out_of_scope "$p" && printf '%s\n' "$p"; done; }

_changed_only() {                       # echo passed files that actually have changes
  local p; for p in "$@"; do
    [ -n "$(git status --porcelain -- "$p" 2>/dev/null)" ] && printf '%s\n' "$p"; done
}

cmd="${1:-}"; shift || true
_in_git_repo || { echo "deploy-commit: not a git repo" >&2; exit 2; }

case "$cmd" in
  pending)
    [ "$#" -gt 0 ] || { echo "deploy-commit: pending needs file args" >&2; exit 2; }
    [ -n "$(_changed_only "$@")" ] && exit 0 || exit 1 ;;
  commit)
    msg="${1:-}"; shift || true
    [ -n "$msg" ] && [ "$#" -gt 0 ] || { echo "deploy-commit: commit needs <msg> <file>..." >&2; exit 2; }
    mapfile -t violations < <(_scope_violations "$@")
    if [ "${#violations[@]}" -gt 0 ]; then
      { echo "deploy-commit: REFUSED — path(s) outside .claude/deploy/ allowlist:";
        printf '  - %s\n' "${violations[@]}";
        echo "deploy-commit: NOTHING committed. Caller must pass only .claude/deploy/ files."; } >&2
      exit 4
    fi
    _unsafe_state && { echo "deploy-commit: unsafe git state (detached/merge/rebase) — not committing" >&2; exit 3; }
    mapfile -t changed < <(_changed_only "$@")
    [ "${#changed[@]}" -gt 0 ] || exit 1
    git add -- "${changed[@]}"
    git commit -q -m "$msg" -- "${changed[@]}" || { echo "deploy-commit: git commit failed" >&2; exit 1; }
    git rev-parse --short HEAD ;;
  *) echo "usage: deploy-commit.sh pending <file>... | commit \"<msg>\" <file>..." >&2; exit 2 ;;
esac
