#!/usr/bin/env bash
# doc-shape.sh — deterministic check that a doc patch has MINOR *shape*.
#
# Companion to doc-commit.sh. doc-syncer AUTO MODE classifies drift as NONE /
# MINOR / SIGNIFICANT by LLM judgment, with no deterministic backstop — so a
# SIGNIFICANT change mislabeled MINOR would auto-commit silently (RISK-1). This
# oracle re-checks the SHAPE of each MINOR patch BEFORE the auto-commit: if a
# patch's shape belies "minor" (adds a section heading, is large, or is a new
# file), it EXCEEDS the MINOR envelope and doc-syncer escalates it to the
# existing SIGNIFICANT gate instead of committing it silently.
#
# SCOPE OF THE GUARANTEE (honest, do not over-read it): this catches STRUCTURAL
# and size significance, NOT semantic significance. A 3-line edit that changes
# meaning but adds no heading and stays small still reads as MINOR-shape. The
# oracle is a deterministic FLOOR under the LLM's judgment (LRN-046) — a
# reduction of RISK-1's gross cases, not an elimination. The LLM still owns the
# semantic call above this floor.
#
# Verdict is AGGREGATE: ANY passed path that exceeds → overall exit 1, every
# offender named on stderr. The LLM classified the SET atomically MINOR; if one
# file's shape disagrees, the whole set is suspect → the whole set escalates.
#
# Envelope (per path, working tree vs HEAD), all deterministic:
#   - adds a Markdown ATX heading (^+#{1,6} <text>) → exceeds (new section)
#   - added   lines > DOC_SHAPE_MAX_ADDED   (def 20) → exceeds (too big for a tweak)
#   - removed lines > DOC_SHAPE_MAX_REMOVED (def 20) → exceeds
#   - new / untracked file                           → exceeds (a creation, not a drift-patch)
#   - not a recognized public-doc file               → exceeds (escalate the anomaly)
# A clean tracked path (no diff) is vacuously within the envelope.
# Known gap: Setext headings (=== / --- underlines) are not detected; ATX is the
# norm in this codebase's docs.
#
# Usage:  doc-shape.sh check <path>...
# Exit:   0 within MINOR envelope · 1 exceeds (reasons→stderr) · 2 usage · 3 not-a-git-repo
# Output: reasons → stderr; stdout stays empty (the exit code carries the verdict).
#
# Sourceable: doc_shape_ok for the doc-syncer flow.

set -uo pipefail

DOC_SHAPE_MAX_ADDED="${DOC_SHAPE_MAX_ADDED:-20}"
DOC_SHAPE_MAX_REMOVED="${DOC_SHAPE_MAX_REMOVED:-20}"

_in_git_repo() { git rev-parse --git-dir >/dev/null 2>&1; }

# True (0) when the path is a recognized public-doc file (doc-syncer's universe,
# BDR-016): the markdown family, anything under docs/, or a bare standard name.
_is_doc() {
  case "$(basename -- "$1")" in
    *.md | *.mdx | *.markdown | *.rst) return 0 ;;
    README | INSTALL | CONFIGURE | USAGE | DEPLOY | CONTRIBUTING | \
      CHANGELOG | SECURITY | ARCHITECTURE | LICENSE | AUTHORS | NOTICE) return 0 ;;
  esac
  case "$1" in
    docs/* | */docs/*) return 0 ;;
  esac
  return 1
}

# Echo the reason a single path EXCEEDS the MINOR envelope, or nothing if it is
# within. Pure read — never mutates the tree.
_path_exceeds_reason() {
  local p="$1"
  _is_doc "$p" || { printf 'not a recognized public-doc file: %s\n' "$p"; return; }
  [ -e "$p" ] || { printf 'path not found: %s\n' "$p"; return; }
  if ! git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    printf 'new/untracked doc (a creation, not a MINOR drift-patch): %s\n' "$p"
    return
  fi
  if git diff HEAD -- "$p" | grep -Eq '^\+#{1,6}[ \t]'; then
    printf 'adds a section heading (structural change, not a factual tweak): %s\n' "$p"
    return
  fi
  local stat added=0 removed=0
  stat="$(git diff HEAD --numstat -- "$p")"
  [ -n "$stat" ] && read -r added removed _ <<<"$stat"
  case "$added$removed" in *[!0-9]*) printf 'binary or unreadable diff: %s\n' "$p"; return ;; esac
  if [ "$added" -gt "$DOC_SHAPE_MAX_ADDED" ]; then
    printf 'added %s lines > %s envelope: %s\n' "$added" "$DOC_SHAPE_MAX_ADDED" "$p"
    return
  fi
  if [ "$removed" -gt "$DOC_SHAPE_MAX_REMOVED" ]; then
    printf 'removed %s lines > %s envelope: %s\n' "$removed" "$DOC_SHAPE_MAX_REMOVED" "$p"
    return
  fi
}

# 0 if EVERY passed path is within the MINOR envelope, 1 if ANY exceeds (each
# offender's reason printed to stderr). Empty list → 0 (vacuously minor).
doc_shape_ok() {
  _in_git_repo || {
    echo "doc-shape: not a git repo — cannot judge shape" >&2
    return 3
  }
  local p reason any=0
  for p in "$@"; do
    reason="$(_path_exceeds_reason "$p")"
    if [ -n "$reason" ]; then
      echo "doc-shape: EXCEEDS MINOR envelope — $reason" >&2
      any=1
    fi
  done
  return "$any"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    check)
      shift
      [ "$#" -ge 1 ] || {
        echo "usage: doc-shape.sh check <path>..." >&2
        return 2
      }
      doc_shape_ok "$@"
      ;;
    *)
      echo "usage: doc-shape.sh check <path>..." >&2
      return 2
      ;;
  esac
}

# Run main only when executed, not when sourced.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
