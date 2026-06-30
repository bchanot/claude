#!/usr/bin/env bash
# reconcile.sh — deterministic engine for /reconcile.
#
# Confronts DECLARATIVE sources (TODO checkboxes, registry statuses) against REAL
# state (git, fs, registry BODY). It is the engine behind the /reconcile skill;
# the skill orchestrates + gates, this file holds the mechanical truth-probes.
#
# FOUNDING PRINCIPLE — recursive coherence (LRN-055): a reconciler must NEVER trust
# a declarative source as an oracle. So this engine NEVER reads the `## Index` table
# nor believes a `[x]`/`[ ]` checkbox; it enumerates registry entries from the BODY
# `## ID —` headings and decides "done/stale" from git/fs only. It practices what it
# preaches — the recursive-coherence test (run-reconcile.sh T1) reds if this is broken.
#
# HONEST LIMITS (graven, do not over-read):
#   - Deferral detection is LEXICAL (reconcile_deferrals): it catches deferrals MARKED
#     by a keyword, misses ones phrased without one ("à reprendre quand X"). Deterministic
#     on the detectable; the skill SURFACES the ambiguous for human review, never asserts.
#   - Contradiction detection surfaces CANDIDATES (token overlap), never asserts a verdict.
#
# Layers:
#   reconcile_enumerate_ids        — body-only ID enumeration (recursive-coherence core)
#   reconcile_oracle_*             — live git/fs truth probes
#   reconcile_blk_current_status   — registry status, LAST block wins (compound/UPDATE/FINAL)
#   reconcile_blk_open             — blockers whose CURRENT status is not resolved
#   reconcile_verdict              — pure kernel: declared checkbox × real fact → verdict
#   reconcile_deferrals            — lexical deferral sweep (honest limit)
#   reconcile_contradiction_candidates — accepted-BDR ⇄ open-chantier token overlap (surface)
set -uo pipefail

RECONCILE_GREP="${RECONCILE_GREP:-/usr/bin/grep}"   # LRN-074: pin grep, never assume GNU flags
# markers that LEXICALLY signal a deferral/follow-up (honest limit: marked-only)
RECONCILE_DEFER_RE='[Dd]efer|[Ff]ollow-?up|[Oo]ut.of.scope|OUT-OF-SCOPE|[Rr]econsider|[Rr]evisit|2e passage|won.t.do|optional\)|one-line ticket'

# --- recursive coherence: enumerate IDs from the BODY, never the ## Index ---
# $1 registry file, $2 prefix (BDR|LRN|BLK|EVAL). Emits one id per line, unique.
reconcile_enumerate_ids() {
  "$RECONCILE_GREP" -oE "^## ${2}-[0-9]+" "$1" | "$RECONCILE_GREP" -oE "${2}-[0-9]+" | sort -u
}

# --- live truth probes (query the REAL repo/fs; this is the "verify, don't believe" core) ---
reconcile_oracle_tree_clean() {            # rc 0 = working tree clean
  [ -z "$(git -C "${1:-.}" status --porcelain 2>/dev/null)" ]
}
reconcile_oracle_merge_done() {            # $1 repo, $2 branch fragment → rc 0 if a merge commit exists
  [ -n "$(git -C "${1:-.}" log --oneline --grep "Merge .*$2" -1 2>/dev/null)" ]
}
reconcile_oracle_pushed() {                # $1 repo, $2 branch → rc 0 if nothing unpushed vs origin
  [ -z "$(git -C "${1:-.}" rev-list "origin/$2..$2" 2>/dev/null)" ]
}
reconcile_oracle_sha_exists() {            # $1 repo, $2 sha → rc 0 if the commit object exists
  git -C "${1:-.}" cat-file -e "${2}^{commit}" 2>/dev/null
}
reconcile_oracle_msg_committed() {         # $1 repo, $2 grep → rc 0 if a commit message matches
  [ -n "$(git -C "${1:-.}" log --oneline --grep "$2" -1 2>/dev/null)" ]
}
reconcile_oracle_path_present() { [ -e "${1:?}" ]; }   # $1 path → rc 0 if it still exists on disk

# --- registry status: LAST status-bearing line wins (the BLK-008 trap A fell into) ---
# $1 blockers file, $2 id. Echoes the current status line (compound/UPDATE/FINAL aware).
reconcile_blk_current_status() {
  # drop ALL `## BLK-` header lines first: the range is inclusive of the NEXT entry's
  # header, and a sibling header may carry a status word (e.g. BLK-005 "...upstream rename")
  # → cross-entry bleed. The entry's own header carries no status, so dropping it is safe.
  sed -n "/^## ${2} /,/^## BLK-/p" "$1" \
    | "$RECONCILE_GREP" -v '^## BLK-' \
    | "$RECONCILE_GREP" -iE 'status|RESOLVED|REVERTED|upstream|resolved|[^a-z]open' \
    | tail -1
}
# blockers whose CURRENT status is not resolved → emits "id<TAB>status"
reconcile_blk_open() {
  local id st
  for id in $(reconcile_enumerate_ids "$1" BLK); do
    st=$(reconcile_blk_current_status "$1" "$id")
    case "$st" in
      *RESOLVED*|*resolved*) : ;;
      *) printf '%s\t%s\n' "$id" "$st" ;;
    esac
  done
}

# --- pure reconciliation kernel: declared checkbox × real fact → verdict (no git, fully testable) ---
# $1 checkbox char (x| |~), $2 real_done (true|false).
reconcile_verdict() {
  case "$1:$2" in
    " :true") echo "STALE:open-but-done" ;;
    "x:false") echo "STALE:done-but-open" ;;
    "~:true") echo "STALE:partial-but-done" ;;
    *) echo "CONSISTENT" ;;
  esac
}

# --- lexical deferral sweep (HONEST LIMIT: marked-only) → "src<TAB>line<TAB>text" ---
reconcile_deferrals() {
  [ -f "$1" ] && "$RECONCILE_GREP" -nE "$RECONCILE_DEFER_RE" "$1" 2>/dev/null | sed 's/^/TODO\t/'
  [ -f "$2" ] && "$RECONCILE_GREP" -nE "$RECONCILE_DEFER_RE" "$2" 2>/dev/null | sed 's/^/BDR\t/'
  return 0
}

# --- contradiction CANDIDATES (surface, never assert): CLI-flag token shared by a BDR + the TODO ---
# $1 decisions file, $2 todo file. CLI-flag-like tokens are distinctive enough to flag for review.
reconcile_contradiction_candidates() {
  local tok
  for tok in $("$RECONCILE_GREP" -oE '\-\-[a-z][a-z-]+' "$1" 2>/dev/null | sort -u); do
    "$RECONCILE_GREP" -qF -- "$tok" "$2" 2>/dev/null \
      && printf 'CANDIDATE\t%s\tflag "%s" in a BDR title and an open TODO chantier — review for contradiction\n' "$tok" "$tok"
  done
  return 0
}
