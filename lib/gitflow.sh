#!/usr/bin/env bash
# gitflow.sh — mechanical core of the gitflow model.
#
# Two ways in:
#   - SOURCED by tests / skills that want the functions.
#   - EXECUTED as a CLI dispatcher: `gitflow.sh <op> [args]` (how skills call it,
#     one Bash invocation per operation).
#
# The judgment layer (WHEN to finish — the human gate) lives in skills/gitflow/
# SKILL.md, never here. This file only does the deterministic mechanics, so it
# can be tested on throwaway repos. Mirrors the surgical-commit helper style:
# `set -uo pipefail` on execute, argv arrays, fail loud, no global state.

_GITFLOW_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── branch model ─────────────────────────────────────────────────────────────
GITFLOW_MAIN="main"
GITFLOW_DEVELOP="develop"
# template resolved relative to the lib; overridable for tests.
GITFLOW_GITIGNORE_TEMPLATE="${GITFLOW_GITIGNORE_TEMPLATE:-$_GITFLOW_LIB_DIR/../templates/gitignore/standard.gitignore}"
# Transient planning artifacts (superpowers spec/plan). A feature/bugfix run
# COMMITS them (SDD worktree + reviewers read them from disk); finish PURGES
# them before the merge reaches develop's tip (BDR-065). Fixed path list;
# read GITFLOW_PURGE_TRANSIENT=0 at finish time to opt out (read in the helper,
# never cached here, so an inline `VAR=0 gitflow_finish` override works).
GITFLOW_TRANSIENT_PATHS=("docs/superpowers/specs" "docs/superpowers/plans")
# Hook set. Every writer, emitter, reconciler and drift check reads this list
# (doctor.sh and the tests through `gitflow.sh hooks`), so a hook added here
# reaches every repo with no second edit.
GITFLOW_HOOKS=(pre-commit post-commit post-merge reference-transaction)

# ── predicates / pure helpers ────────────────────────────────────────────────

# echo the gitflow type of a branch: feature|bugfix|release|hotfix|chore|main|develop|other
gitflow_branch_type() {
  local br="${1:-$(git symbolic-ref --short -q HEAD 2>/dev/null)}"
  case "$br" in
    "$GITFLOW_MAIN")    echo main ;;
    "$GITFLOW_DEVELOP") echo develop ;;
    feature/*)          echo feature ;;
    bugfix/*)           echo bugfix ;;
    release/*)          echo release ;;
    hotfix/*)           echo hotfix ;;
    chore/*)            echo chore ;;
    *)                  echo other ;;
  esac
}

# THE shared predicate — rc 0 iff (given or current) branch is a protected base.
# Consumed by: start/finish (here), the assistance skills (aiguillage), and the
# pre-commit hook (mirrored, coherence-tested — see gitflow-test.sh T10).
gitflow_protected_base() {
  local br="${1:-$(git symbolic-ref --short -q HEAD 2>/dev/null)}"
  [ "$br" = "$GITFLOW_MAIN" ] || [ "$br" = "$GITFLOW_DEVELOP" ]
}

# echo the base a given type must fork from.
gitflow_base_for() {
  case "$1" in
    feature|bugfix|release|chore) echo "$GITFLOW_DEVELOP" ;;
    hotfix)                 echo "$GITFLOW_MAIN" ;;
    *) echo "gitflow: unknown type '$1'" >&2; return 2 ;;
  esac
}

# rc 0 iff at least one release/* branch exists (hotfix fan-out condition).
gitflow_release_open() {
  [ -n "$(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*')" ]
}

# ── start ────────────────────────────────────────────────────────────────────

# gitflow_start <type> <name> → checkout -b <type>/<name> from the correct base.
# _gitflow_push_branch <br> → push + set upstream on origin (BDR-095: a remote
# only backs up what it holds, so a branch is pushed the moment it exists).
# Best effort BY CONTRACT: no origin, offline, or refused → loud warning, rc 0.
# A failed push must never block the work, only make the gap visible.
# GITFLOW_NO_PUSH=1 opts out (throwaway test repos).
_gitflow_push_branch() {
  local br="$1"
  [ "${GITFLOW_NO_PUSH:-0}" = 1 ] && return 0
  git remote get-url origin >/dev/null 2>&1 || return 0
  if _gitflow_timeout git push -q -u --follow-tags origin "$br" >/dev/null 2>&1; then
    return 0
  fi
  echo "gitflow: push of '$br' FAILED — it exists only on this disk. Push by hand: git push -u origin $br" >&2
  return 0
}

# Wrap a network call in a timeout when coreutils' timeout exists (macOS lacks it).
_gitflow_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${GITFLOW_PUSH_TIMEOUT:-30}" "$@"
  else
    "$@"
  fi
}

gitflow_start() {
  local type="${1:-}" name="${2:-}" base
  base="$(gitflow_base_for "$type")" || return 2
  [ -n "$name" ] || { echo "gitflow_start: missing <name>" >&2; return 2; }
  git rev-parse --verify -q "$base" >/dev/null \
    || { echo "gitflow_start: base '$base' missing — run 'gitflow init' first" >&2; return 3; }
  git checkout -q "$base" || return 1
  git pull --ff-only -q 2>/dev/null || true   # best-effort sync; offline / no-upstream ok
  git checkout -q -b "$type/$name" || return 1
  _gitflow_push_branch "$type/$name"
  echo "$type/$name"
}

# ── finish (directed merge + hotfix fan-out) ─────────────────────────────────

_gitflow_merge_into() {            # _gitflow_merge_into <target> <source>
  local target="$1" source="$2"
  git checkout -q "$target" || return 1
  git pull --ff-only -q 2>/dev/null || true
  git merge --no-ff -q -m "Merge $source into $target" "$source" \
    || { echo "gitflow: conflict merging $source → $target — resolve, commit, re-run finish" >&2; return 4; }
  _gitflow_push_branch "$target"   # git merge fires post-merge, not post-commit; push here too
}

_gitflow_merge_into_open_releases() {   # <source>
  local source="$1" rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    _gitflow_merge_into "$rel" "$source" || return 4
  done < <(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*')
}

# rc 0 iff <branch> is fully contained in develop or in main — the ONLY state in
# which the lib deletes a branch. Fails closed: neither base in the repo →
# nothing to verify against → rc 1. Explicit on purpose: `git branch -d` checks
# "merged into the upstream" once one is set, and since BDR-095 every branch
# has an auto-pushed upstream that is trivially in sync — its safety valve is
# dead (proven by gitflow-test.sh T22a).
gitflow_merged_into_base() {
  local br="$1" base
  for base in "$GITFLOW_DEVELOP" "$GITFLOW_MAIN"; do
    git rev-parse --verify -q "refs/heads/$base" >/dev/null || continue
    if git merge-base --is-ancestor "$br" "$base" 2>/dev/null; then return 0; fi
  done
  return 1
}

# _gitflow_delete_remote <br> → remove origin/<br> once the LOCAL copy is gone.
# Same contract as the pushes (BDR-095): best effort, warn never fail; skipped
# under GITFLOW_NO_PUSH=1, gitflow.autopush=false or no origin. The REMOTE tip
# is re-checked against develop/main before the delete: a commit pushed from
# elsewhere that never reached a base (or that this clone has never fetched)
# keeps the remote branch alive, loudly. Never a base, by construction and by
# the explicit guard below.
_gitflow_delete_remote() {
  local br="$1" out rc tip
  [ "${GITFLOW_NO_PUSH:-0}" = 1 ] && return 0
  [ "$(git config --bool --default true gitflow.autopush)" = false ] && return 0
  git remote get-url origin >/dev/null 2>&1 || return 0
  gitflow_protected_base "$br" && return 0
  out="$(_gitflow_timeout git ls-remote --exit-code --heads origin "refs/heads/$br" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 2 ] && return 0                         # no remote copy — nothing to remove
  if [ "$rc" -ne 0 ]; then
    echo "gitflow: origin unreachable — remote copy of '$br' NOT removed. By hand: git push origin --delete $br" >&2
    return 0
  fi
  tip="${out%%[[:space:]]*}"
  if ! gitflow_merged_into_base "$tip"; then
    echo "gitflow: origin/$br holds commits not merged into $GITFLOW_DEVELOP or $GITFLOW_MAIN — remote copy KEPT" >&2
    return 0
  fi
  if _gitflow_timeout git push -q origin --delete "$br" >/dev/null 2>&1; then
    echo "gitflow: removed origin/$br (tip merged)" >&2
  else
    echo "gitflow: remote delete of '$br' FAILED — remote copy NOT removed. By hand: git push origin --delete $br" >&2
  fi
  return 0
}

# gitflow_delete <branch> → the one sanctioned way to delete a branch, local
# copy then origin copy. finish calls it after its merges; the CLI exposes it
# for a branch merged elsewhere (a Gitea PR, a hand merge). Refuses, branch
# KEPT: rc 2 no such branch · rc 6 protected base (main/develop are never
# deleted) · rc 5 not merged into develop or main.
gitflow_delete() {
  local br="${1:-}"
  if [ -z "$br" ] || ! git rev-parse --verify -q "refs/heads/$br" >/dev/null; then
    echo "gitflow_delete: no local branch '${br:-<missing>}'" >&2; return 2
  fi
  if gitflow_protected_base "$br"; then
    echo "gitflow: REFUSED — '$br' is a protected base, never deleted" >&2; return 6
  fi
  if ! gitflow_merged_into_base "$br"; then
    echo "gitflow: REFUSED — '$br' is not merged into $GITFLOW_DEVELOP or $GITFLOW_MAIN — branch kept" >&2
    return 5
  fi
  git checkout -q "$GITFLOW_DEVELOP" 2>/dev/null || git checkout -q "$GITFLOW_MAIN" 2>/dev/null
  git branch -q -d "$br" || { echo "gitflow: git refused to delete '$br' — branch kept" >&2; return 5; }
  _gitflow_delete_remote "$br"
}

# _gitflow_purge_transient → remove the committed transient planning artifacts
# (BDR-065) from the CURRENT branch just before the directed merge. Result: the
# removal rides the feature/bugfix branch, whose earlier commits stay reachable
# from develop through the --no-ff merge (`git show <sha>:…` = the archive),
# while develop's TIP lands clean. Automates the manual post-merge chore that
# BDR-065 left as doctrine (and that slipped once — commit 655e364).
#
# BEST-EFFORT BY CONTRACT: this NEVER aborts a finish. Nothing tracked → no-op;
# uncommitted changes under those paths, or a failed commit → warn + degrade to
# the old manual-cleanup behaviour, index/tree restored, merge still proceeds.
# The scoped commit (`-- <paths>`) records only the deletions, so a dirty index
# is never swept in. Opt out with GITFLOW_PURGE_TRANSIENT=0.
_gitflow_purge_transient() {
  [ "${GITFLOW_PURGE_TRANSIENT:-1}" = 1 ] || return 0
  local p; local -a tracked=()
  for p in "${GITFLOW_TRANSIENT_PATHS[@]}"; do
    [ -n "$(git ls-files -- "$p")" ] && tracked+=("$p")
  done
  [ "${#tracked[@]}" -gt 0 ] || return 0             # nothing tracked → no-op
  # only purge paths with no pending changes → git rm is all-or-nothing safe and
  # never discards uncommitted work under docs/superpowers.
  if ! git diff --quiet HEAD -- "${tracked[@]}" 2>/dev/null; then
    echo "gitflow: transient artifacts have uncommitted changes — purge skipped, finishing without it (clean up by hand)" >&2
    return 0
  fi
  if git rm -r -q -- "${tracked[@]}" >/dev/null 2>&1 \
     && git commit -q -m "chore: purge transient planning artifacts (BDR-065)" -- "${tracked[@]}"; then
    echo "gitflow: purged transient planning artifacts before merge (${tracked[*]})" >&2
  else
    echo "gitflow: transient-artifact purge failed — finishing without it (clean up by hand)" >&2
    git reset -q HEAD -- "${tracked[@]}" 2>/dev/null || true   # unstage any partial rm
    git checkout -q -- "${tracked[@]}" 2>/dev/null || true     # restore working tree
  fi
  return 0
}

# gitflow_finish [<type> <name>] → directed merge of the CURRENT branch per its
# type, then gitflow_delete (refuses main/develop and anything unmerged). WHEN
# to call this is the human gate (SKILL.md).
#
# The merge source is ALWAYS the checked-out branch (HEAD) — that is the contract.
# The optional <type> <name> is a SAFETY ASSERTION, not a target selector: if you
# name a branch it MUST equal the current one, else finish refuses loudly instead
# of silently merging whatever you happen to be standing on. (Guards the audit UX
# trap: `finish bugfix audit-bugs` run from feature/audit-tokens merged the wrong
# branch — args were silently ignored. See BLK-015 / LRN-089.) No args = unchanged.
gitflow_finish() {
  local br type req_type="${1:-}" req_name="${2:-}"
  br="$(git symbolic-ref --short -q HEAD)" || { echo "gitflow_finish: detached HEAD" >&2; return 3; }
  if [ -n "$req_type" ] || [ -n "$req_name" ]; then
    [ "$req_type/$req_name" = "$br" ] || {
      echo "gitflow_finish: operates on the current branch '$br', but you asked '$req_type/$req_name' — checkout '$req_type/$req_name' first (or run finish with no args)." >&2
      return 2
    }
  fi
  type="$(gitflow_branch_type "$br")"
  case "$type" in
    feature|bugfix)
      _gitflow_purge_transient   # BDR-065 auto-cleanup, on HEAD, pre-merge; never blocks
      _gitflow_merge_into "$GITFLOW_DEVELOP" "$br" && gitflow_delete "$br" ;;
    chore)
      _gitflow_merge_into "$GITFLOW_DEVELOP" "$br" && gitflow_delete "$br" ;;
    release)
      _gitflow_merge_into "$GITFLOW_MAIN" "$br" \
        && _gitflow_merge_into "$GITFLOW_DEVELOP" "$br" \
        && gitflow_delete "$br" ;;
    hotfix)
      _gitflow_merge_into "$GITFLOW_MAIN" "$br" \
        && _gitflow_merge_into "$GITFLOW_DEVELOP" "$br" \
        && { gitflow_release_open && _gitflow_merge_into_open_releases "$br" || true; } \
        && gitflow_delete "$br" ;;
    *) echo "gitflow_finish: '$br' is not a finishable gitflow branch" >&2; return 2 ;;
  esac
}

# ── init (resolves BLK-010) + reconcile + hook install ───────────────────────

_gitflow_init_fresh() {            # unborn HEAD → deterministic root commit on main
  local msg="${1:-chore: initial commit}"
  git symbolic-ref HEAD "refs/heads/$GITFLOW_MAIN"   # name the unborn branch 'main'
  git add -A
  git commit -q -m "$msg" \
    || { echo "gitflow_init: nothing staged for the root commit (scaffold first)" >&2; return 1; }
  git branch "$GITFLOW_DEVELOP"
}

_gitflow_init_existing() {         # has commits → ensure main (rename master) + develop
  if ! git rev-parse --verify -q "refs/heads/$GITFLOW_MAIN" >/dev/null; then
    if git rev-parse --verify -q refs/heads/master >/dev/null; then
      git branch -m master "$GITFLOW_MAIN"
    else
      echo "gitflow_init: no '$GITFLOW_MAIN' and no 'master' — refusing to guess the prod branch" >&2
      return 2
    fi
  fi
  git checkout -q "$GITFLOW_MAIN" || return 1
  # The socle (.gitignore + versioned hooks) reaches main through a MERGE: the
  # pre-commit hook is global on the machine (BDR-095), so a direct commit on
  # main is refused even during init, while a merge commit is hook-exempt.
  # Any failure aborts BEFORE develop/hook activation so a partial run can't
  # activate the hook and self-block every re-run.
  git add -- .gitignore .githooks 2>/dev/null || true
  if ! git diff --cached --quiet -- .gitignore .githooks 2>/dev/null; then
    _gitflow_adopt_socle || return 1
  fi
  git rev-parse --verify -q "refs/heads/$GITFLOW_DEVELOP" >/dev/null \
    || git branch "$GITFLOW_DEVELOP" "$GITFLOW_MAIN"
}

# Commit the staged socle on chore/gitflow-adopt (a working branch, so the
# pre-commit allows it), merge it --no-ff into main (a merge commit runs no
# pre-commit), delete the branch. The branch forks off main because develop
# does not exist yet at init time.
_gitflow_adopt_socle() {
  local br="chore/gitflow-adopt"
  if git rev-parse --verify -q "refs/heads/$br" >/dev/null; then
    echo "gitflow_init: '$br' already exists (earlier run) — merge or delete it, then re-run" >&2
    return 1
  fi
  git checkout -q -b "$br" || return 1
  git commit -q -m "chore: adopt gitflow socle + versioned hooks" \
    || { echo "gitflow_init: socle commit failed — aborting before hook activation (recoverable)" >&2; return 1; }
  git checkout -q "$GITFLOW_MAIN" || return 1
  git merge --no-ff -q -m "Merge $br into $GITFLOW_MAIN" "$br" \
    || { echo "gitflow_init: socle merge into $GITFLOW_MAIN failed — aborting before hook activation" >&2; return 1; }
  git branch -q -d "$br"
}

# gitflow_init [msg] → idempotent. Order matters (full BLK-010 closure):
# reconcile .gitignore + write the versioned hook FIRST, so the fresh root
# commit / existing adoption commit EMBED them; activate the hook LAST so the
# bootstrap commits are never self-blocked by the hook they install.
gitflow_init() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "gitflow_init: not a git repo" >&2; return 1; }
  # identity precheck — without it the root/socle commit fails mid-run (see fatal
  # guard in _gitflow_init_existing). Fail loud up front instead of half-applying.
  { [ -n "$(git config user.name)" ] && [ -n "$(git config user.email)" ]; } \
    || { echo "gitflow_init: git identity unset (user.name/user.email) — set it first" >&2; return 1; }
  gitflow_reconcile_gitignore || return $?   # socle into .gitignore BEFORE any commit
  _gitflow_write_hook || return $?           # write .githooks/pre-commit (inactive)
  if ! git rev-parse --verify -q HEAD >/dev/null 2>&1; then
    _gitflow_init_fresh "$@" || return $?     # root commit embeds scaffold + socle + hook
  else
    _gitflow_init_existing || return $?       # adoption commit (hook still inactive)
  fi
  gitflow_activate_hook || return $?          # activate LAST
}

# Additive reconcile: ensure every non-comment template line is present; append
# only what's missing under a managed marker. NEVER rewrites project-own rules.
gitflow_reconcile_gitignore() {
  local tmpl="$GITFLOW_GITIGNORE_TEMPLATE" gi=".gitignore" line
  local -a missing=()
  [ -f "$tmpl" ] || { echo "gitflow: gitignore template missing: $tmpl" >&2; return 1; }
  [ -e "$gi" ] || : > "$gi"
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    grep -qxF -- "$line" "$gi" || missing+=("$line")
  done < "$tmpl"
  [ "${#missing[@]}" -gt 0 ] || return 0          # idempotent no-op
  {
    echo ""
    echo "# ── gitflow standard socle (added by gitflow_init; additive, safe to edit) ──"
    printf '%s\n' "${missing[@]}"
  } >> "$gi"
  echo "gitflow: appended ${#missing[@]} socle line(s) to $gi" >&2
}

# Emit the self-contained pre-commit hook. The protected-base test is INLINED
# (mirror of gitflow_protected_base) because the hook runs in arbitrary project
# repos with no access to this lib. Coherence guaranteed by gitflow-test.sh T10.
_gitflow_emit_pre_commit() {
cat <<HOOK
#!/bin/sh
# gitflow pre-commit — generated by gitflow_init. Do not hand-edit.
# Mirrors gitflow_protected_base (lib/gitflow.sh). Drift caught by T10.
gd=\$(git rev-parse --git-dir)
br=\$(git symbolic-ref --short -q HEAD 2>/dev/null)

git rev-parse --verify -q HEAD >/dev/null 2>&1 || exit 0   # root commit — allow
[ -f "\$gd/MERGE_HEAD" ] && exit 0                          # merge in progress — allow

# Secret backstop (job7) — any branch, not just protected ones. Non-blocking
# if gitleaks isn't installed; auto-discovers ./.gitleaks.toml (repo root).
if command -v gitleaks >/dev/null 2>&1; then
  if ! gitleaks git --staged --no-banner >/dev/null 2>&1; then
    echo "gitflow pre-commit: BLOCKED — gitleaks found a secret in staged changes." >&2
    echo "  Details: gitleaks git --staged --no-banner" >&2
    echo "  Genuine false-positive? add an allowlist rule to .gitleaks.toml — never bypass with --no-verify." >&2
    exit 1
  fi
else
  echo "gitflow pre-commit: gitleaks not installed — secret scan skipped (https://github.com/gitleaks/gitleaks)." >&2
fi

# Per-repo opt-out of the branch model (a clone of a foreign project):
#   git config gitflow.protect false
[ "\$(git config --bool --default true gitflow.protect)" = false ] && exit 0

case "\$br" in
  $GITFLOW_MAIN|$GITFLOW_DEVELOP) ;;                        # protected — keep checking
  *) exit 0 ;;                                              # working branch — allow
esac

# whitelist: all-staged-under-.claude/ (memory/doc/deploy helpers) or
# .githooks/ (the hooks themselves, refreshed by the lib) — allow
if [ -z "\$(git diff --cached --name-only | grep -vE '^\.(claude|githooks)/' | head -1)" ]; then
  exit 0
fi

echo "gitflow pre-commit: BLOCKED — direct commit on '\$br'." >&2
echo "  Branch from the right base (feature/bugfix->develop, hotfix->main), or merge." >&2
echo "  (.claude/** and .githooks/** commits are exempt; foreign clone? git config gitflow.protect false)" >&2
exit 1
HOOK
}

# Emit the self-contained push hook, $1 = post-commit | post-merge: push every
# commit as it lands (BDR-095). `git commit` fires post-commit, `git merge` and
# `git pull` fire post-merge, so both carry the same body. Same contract as
# _gitflow_push_branch, inlined because the hook runs in arbitrary project
# repos with no access to this lib.
_gitflow_emit_push_hook() {
printf '#!/bin/sh\n# gitflow %s — generated by gitflow_init. Do not hand-edit.\n' "$1"
cat <<'HOOK'
# Pushes every commit as it lands (BDR-095): a remote only backs up what it
# holds. Never fails the commit: no origin / offline / refused → warning only.
# Opt out for one command with GITFLOW_NO_PUSH=1 (throwaway repos, tests).
[ "${GITFLOW_NO_PUSH:-0}" = 1 ] && exit 0
# Per-repo opt-out (no push rights on a foreign clone): git config gitflow.autopush false
[ "$(git config --bool --default true gitflow.autopush)" = false ] && exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0
br=$(git symbolic-ref --short -q HEAD 2>/dev/null) || exit 0   # detached HEAD — nothing to track
if command -v timeout >/dev/null 2>&1; then t="timeout ${GITFLOW_PUSH_TIMEOUT:-30}"; else t=""; fi
if $t git push -q -u --follow-tags origin "$br" >/dev/null 2>&1; then exit 0; fi
echo "gitflow post-commit: push of '$br' FAILED — this commit exists only on this disk." >&2
echo "  Push by hand: git push -u origin $br   (rejected as non-fast-forward? never force-push; ask first)" >&2
exit 0
HOOK
}

# Emit the reference-transaction hook: vetoes the deletion of a protected base
# at the ref layer, whatever issued it — branch -d/-D, update-ref -d, a rename
# (which deletes the old name), a script, a sub-agent. Names inlined like the
# pre-commit's (the hook runs with no access to this lib; drift caught by T19).
# Only the `prepared` call can veto; the other two exit at once.
_gitflow_emit_reference_transaction() {
cat <<HOOK
#!/bin/sh
# gitflow reference-transaction — generated by gitflow_init. Do not hand-edit.
# Refuses deleting (or renaming) $GITFLOW_MAIN / $GITFLOW_DEVELOP, whatever the
# command. Mirrors gitflow_protected_base (lib/gitflow.sh).
[ "\$1" = prepared ] || exit 0
while read -r _old new ref; do
  case "\$ref" in refs/heads/$GITFLOW_MAIN|refs/heads/$GITFLOW_DEVELOP) ;; *) continue ;; esac
  case "\$new" in *[!0]*) continue ;; esac     # new value not all-zeros → an update, not a deletion
  # Per-repo opt-out (a foreign clone): git config gitflow.protect false
  [ "\$(git config --bool --default true gitflow.protect)" = false ] && exit 0
  echo "gitflow reference-transaction: BLOCKED — deleting '\$ref', a protected base." >&2
  echo "  $GITFLOW_MAIN and $GITFLOW_DEVELOP are never deleted or renamed. A merged working branch: gitflow.sh delete <branch>" >&2
  exit 1
done
exit 0
HOOK
}

_gitflow_emit_hook() {             # <name> — one of GITFLOW_HOOKS
  case "$1" in
    pre-commit) _gitflow_emit_pre_commit ;;
    post-commit|post-merge) _gitflow_emit_push_hook "$1" ;;
    reference-transaction) _gitflow_emit_reference_transaction ;;
    *) return 2 ;;
  esac
}

# write the versioned hook files into $1 (default .githooks) — does NOT
# activate (see gitflow_activate_hook / gitflow_global_hooks).
_gitflow_write_hook() {
  local hd="${1:-.githooks}" name
  mkdir -p "$hd"
  for name in "${GITFLOW_HOOKS[@]}"; do
    _gitflow_emit_hook "$name" > "$hd/$name" || return 1
    chmod +x "$hd/$name" || return 1
  done
}

# point git at the versioned hook dir. Run LAST in init so the bootstrap commits
# (socle / adoption / root) are never blocked by the hook they install.
gitflow_activate_hook() {
  git config core.hooksPath .githooks
}

# convenience: write + activate in one call (re-install / CLI 'install-hook').
gitflow_install_hook() {
  _gitflow_write_hook && gitflow_activate_hook
}

# gitflow_reconcile_hooks → refresh a repo's .githooks/ when it lags the lib
# (LRN-114: a generator edit never reaches installed hooks by itself; the
# session-start hook calls this once per session). Only for repos that opted
# into the per-repo layout (.githooks/pre-commit present, or local
# core.hooksPath = .githooks); others are covered by the global hooks dir.
# Prints "gitflow hooks refreshed: <names>" when it wrote something, nothing
# when current. Never fails the caller.
gitflow_reconcile_hooks() {
  local root hd name stale=""
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
  hd="$root/.githooks"
  [ -f "$hd/pre-commit" ] \
    || [ "$(git config --local core.hooksPath 2>/dev/null)" = ".githooks" ] \
    || return 0
  for name in "${GITFLOW_HOOKS[@]}"; do
    diff -q <(_gitflow_emit_hook "$name") "$hd/$name" >/dev/null 2>&1 || stale="$stale $name"
  done
  [ -n "$stale" ] || return 0
  (cd "$root" && gitflow_install_hook) || return 0
  echo "gitflow hooks refreshed:$stale"
}

# gitflow_global_hooks <dir> [config-value] → write the three hooks into <dir>
# and point git's GLOBAL core.hooksPath at it (value defaults to <dir>; link.sh
# passes '~/.claude/githooks' so the setting is machine-agnostic). Every repo
# on the machine is then protected and auto-pushed, whether or not it ever ran
# gitflow init; a repo's own local core.hooksPath still wins, by git's rules.
gitflow_global_hooks() {
  local dir="${1:-}" value="${2:-${1:-}}"
  [ -n "$dir" ] || { echo "gitflow_global_hooks: missing <dir>" >&2; return 2; }
  _gitflow_write_hook "$dir" || return 1
  [ "$(git config --global core.hooksPath 2>/dev/null)" = "$value" ] && return 0
  git config --global core.hooksPath "$value"
}

# ── CLI dispatch (only when executed, not sourced) ───────────────────────────
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  set -uo pipefail
  cmd="${1:-}"; shift 2>/dev/null || true
  case "$cmd" in
    type)           gitflow_branch_type "$@" ;;
    protected-base) gitflow_protected_base "$@" ;;
    base-for)       gitflow_base_for "$@" ;;
    release-open)   gitflow_release_open ;;
    start)          gitflow_start "$@" ;;
    finish)         gitflow_finish "$@" ;;
    delete)         gitflow_delete "$@" ;;
    merged)         [ -n "${1:-}" ] || { echo "usage: gitflow.sh merged <branch>" >&2; exit 2; }
                    gitflow_merged_into_base "$1" ;;
    hooks)          printf '%s\n' "${GITFLOW_HOOKS[@]}" ;;
    init)           gitflow_init "$@" ;;
    reconcile)      gitflow_reconcile_gitignore "$@" ;;
    purge-transient) _gitflow_purge_transient ;;
    install-hook)   gitflow_install_hook "$@" ;;
    reconcile-hooks) gitflow_reconcile_hooks ;;
    global-hooks)   gitflow_global_hooks "$@" ;;
    emit-hook)      _gitflow_emit_hook "${1:-pre-commit}" \
                      || { echo "gitflow.sh emit-hook {$(IFS='|'; echo "${GITFLOW_HOOKS[*]}")}" >&2; exit 2; } ;;
    *) echo "usage: gitflow.sh {type|protected-base|base-for|release-open|start|finish|delete <br>|merged <br>|init|reconcile|purge-transient|install-hook|reconcile-hooks|global-hooks <dir> [value]|hooks|emit-hook <name>}" >&2; exit 2 ;;
  esac
fi
