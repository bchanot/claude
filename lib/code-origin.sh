#!/usr/bin/env bash
# code-origin.sh [path] — is this repo our code or foreign code?
# Prints one line: "ours <reason>" or "foreign <reason>". Always rc 0.
#
# Order: `git config claude.origin` (ours|foreign, set by hand per clone, never
# committed to a third-party repo), then the root commit's author against
# user.email and every global `claude.identity`. Undecidable → foreign.
set -u

repo="${1:-.}"

_git() { git -C "$repo" "$@"; }

_override() {
  local value
  value="$(_git config --get claude.origin 2>/dev/null)" || return 1
  case "$value" in
    ours|foreign) echo "$value override claude.origin" ;;
    *) echo "foreign claude.origin '$value' invalid (want ours|foreign)" ;;
  esac
}

_oldest_root() {
  _git rev-list --max-parents=0 --reverse HEAD 2>/dev/null | sed -n 1p
}

_our_emails() {
  _git config --get user.email 2>/dev/null
  git config --global --get-all claude.identity 2>/dev/null
}

_is_ours() {
  local email="$1" mine
  while IFS= read -r mine; do
    [ -n "$mine" ] || continue
    [ "$(echo "$mine" | tr '[:upper:]' '[:lower:]')" = \
      "$(echo "$email" | tr '[:upper:]' '[:lower:]')" ] && return 0
  done < <(_our_emails)
  return 1
}

_root_verdict() {
  local root email author year
  _git rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "foreign not a git repository"; return; }
  [ "$(_git rev-parse --is-shallow-repository 2>/dev/null)" = true ] \
    && { echo "foreign shallow clone, root unknown"; return; }
  root="$(_oldest_root)"
  [ -n "$root" ] || { echo "foreign no commit, root unknown"; return; }
  email="$(_git log -1 --format=%ae "$root")"
  author="${email%%@*}"
  year="$(_git log -1 --format=%ad --date=format:%Y "$root")"
  if _is_ours "$email"; then
    echo "ours root $author $year"
  else
    echo "foreign root $author $year"
  fi
}

_override || _root_verdict
