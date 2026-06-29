#!/usr/bin/env bash
# Deterministic tests for lib/doc-commit.sh.
#
# Proves the contract on REAL git behavior (not assumed). Load-bearing deltas vs
# memory-commit, each tested by what it must REFUSE, not only what it accepts:
#   T1  inverse-exclusion scope guard (BDR-022) — fail-CLOSED and LOUD:
#       T1a forbidden path ALONE (.claude/ and CLAUDE.md) → exit 4, nothing committed
#       T1b legit docs only                              → commits cleanly
#       T1c MIXED legit + forbidden                      → exit 4, NOTHING committed (the trap)
#   T2  dynamic pathspec — a clean passed path is filtered, commit does NOT abort
#   T3  dangling code (untracked OR pre-staged) never embarked
#   T4  stale-staged doc (version A) → commit carries working-tree version B
#   T5  idempotent — empty list / clean tree → no-op exit 0
#   T6  unsafe git state (detached HEAD) → exit 3, no commit
#   T7  path WITH A SPACE passed as one arg → committed (argv is space-safe, no separator)
#   T8  pre-commit hook REJECTS the commit → fail LOUD (exit 5), no stale hash on stdout,
#       HEAD unmoved — the script must NOT report "committed" when git commit failed
#
# No -e: run every test and report, even after a failure.
set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$HERE/../doc-commit.sh"
ERRFILE="$(mktemp)"
PASS=0
FAIL=0

ok() { printf '    \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
ko() { printf '    \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Fresh throwaway repo: public docs + forbidden context + code, all tracked.
new_repo() {
  local d
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t
  git -C "$d" config user.name tester
  mkdir -p "$d/.claude/memory" "$d/src"
  printf 'readme baseline\n' >"$d/README.md"
  printf 'usage baseline\n' >"$d/USAGE.md"
  printf 'deploy baseline\n' >"$d/DEPLOY.md"
  printf 'claude-md baseline\n' >"$d/CLAUDE.md"
  printf 'decisions baseline\n' >"$d/.claude/memory/decisions.md"
  printf 'src baseline\n' >"$d/src/app.txt"
  git -C "$d" add -A
  git -C "$d" commit -qm baseline
  printf '%s' "$d"
}

# Files recorded in HEAD, sorted (stable compare).
head_files() { git -C "$1" diff-tree --no-commit-id --name-only -r HEAD | sort | tr '\n' ' '; }

# run <repo> <args...> → sets RC (exit), OUT (stdout = hash), ERR (stderr = diag).
run() {
  local r="$1"; shift
  OUT="$( (cd "$r" && "$HELPER" "$@") 2>"$ERRFILE" )"; RC=$?
  ERR="$(cat "$ERRFILE")"
}

echo "T1a — forbidden path ALONE → REFUSE loud (exit 4), nothing committed"
R="$(new_repo)"
BEFORE="$(git -C "$R" rev-parse HEAD)"
printf 'dirtied\n' >>"$R/.claude/memory/decisions.md"
run "$R" commit "docs: T1a-claude" ".claude/memory/decisions.md"
printf '    rc=%s  out=[%s]\n' "$RC" "$OUT"
printf '    err: %s\n' "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 4 ]; then ok ".claude/ alone → exit 4"; else ko "expected 4, got $RC"; fi
if [ "$(git -C "$R" rev-parse HEAD)" = "$BEFORE" ]; then ok "no commit created"; else ko "a commit was created"; fi
if [ -z "$OUT" ]; then ok "stdout empty (no hash)"; else ko "stdout leaked: [$OUT]"; fi
if printf '%s' "$ERR" | grep -qi 'REFUSED'; then ok "stderr is loud (REFUSED)"; else ko "stderr not loud"; fi
printf 'dirtied\n' >>"$R/CLAUDE.md"
run "$R" commit "docs: T1a-claudemd" "CLAUDE.md"
printf '    [CLAUDE.md] rc=%s  out=[%s]\n' "$RC" "$OUT"
if [ "$RC" -eq 4 ]; then ok "CLAUDE.md alone → exit 4"; else ko "expected 4, got $RC"; fi
rm -rf "$R"

echo "T1b — legit docs only → commits cleanly"
R="$(new_repo)"
printf 'feature added\n' >>"$R/README.md"
printf 'cmd changed\n' >>"$R/USAGE.md"
run "$R" commit "docs: T1b update README + USAGE" "README.md" "USAGE.md"
COMMITTED="$(head_files "$R")"
printf '    rc=%s  out(hash)=[%s]\n' "$RC" "$OUT"
printf '    committed: [%s]\n' "$COMMITTED"
if [ "$RC" -eq 0 ]; then ok "exit 0"; else ko "expected 0, got $RC"; fi
if [ "$COMMITTED" = "README.md USAGE.md " ]; then ok "committed exactly README + USAGE"; else ko "got [$COMMITTED]"; fi
if [ -n "$OUT" ]; then ok "hash on stdout"; else ko "no hash printed"; fi
if [ -z "$(git -C "$R" status --porcelain -- .claude CLAUDE.md)" ]; then ok ".claude/CLAUDE.md untouched"; else ko "forbidden paths touched"; fi
rm -rf "$R"

echo "T1c — MIXED legit + forbidden → exit 4, NOTHING committed (the trap)"
R="$(new_repo)"
BEFORE="$(git -C "$R" rev-parse HEAD)"
printf 'feature added\n' >>"$R/README.md"
printf 'dirtied\n' >>"$R/.claude/memory/decisions.md"
run "$R" commit "docs: T1c mixed" "README.md" ".claude/memory/decisions.md"
printf '    rc=%s  out=[%s]\n' "$RC" "$OUT"
printf '    err: %s\n' "$(printf '%s' "$ERR" | grep -i decisions | head -1)"
if [ "$RC" -eq 4 ]; then ok "mixed → exit 4"; else ko "expected 4, got $RC"; fi
if [ "$(git -C "$R" rev-parse HEAD)" = "$BEFORE" ]; then ok "NOTHING committed (README not half-committed)"; else ko "a commit slipped through"; fi
if printf '%s' "$ERR" | grep -q '.claude/memory/decisions.md'; then ok "stderr names the offender"; else ko "offender not named"; fi
if git -C "$R" status --porcelain | grep -q ' M README.md'; then ok "README left dirty (not embarked)"; else ko "README state wrong"; fi
rm -rf "$R"

echo "T2 — dynamic pathspec: clean passed path filtered, no abort"
R="$(new_repo)"
printf 'feature added\n' >>"$R/README.md"
printf 'cmd changed\n' >>"$R/USAGE.md"
# DEPLOY.md passed but NOT modified → must be filtered, must not abort the commit.
run "$R" commit "docs: T2" "README.md" "USAGE.md" "DEPLOY.md"
COMMITTED="$(head_files "$R")"
printf '    rc=%s  committed=[%s]\n' "$RC" "$COMMITTED"
if [ "$RC" -eq 0 ]; then ok "exit 0 (clean DEPLOY.md did not abort)"; else ko "expected 0, got $RC"; fi
if [ "$COMMITTED" = "README.md USAGE.md " ]; then ok "committed README + USAGE only (DEPLOY filtered)"; else ko "got [$COMMITTED]"; fi
rm -rf "$R"

echo "T3 — dangling code (untracked + pre-staged) NOT embarked"
R="$(new_repo)"
printf 'feature added\n' >>"$R/README.md"
printf 'untracked junk\n' >"$R/src/dangling.txt"
printf 'staged junk\n' >"$R/src/staged.txt"; git -C "$R" add src/staged.txt
run "$R" commit "docs: T3" "README.md"
COMMITTED="$(head_files "$R")"
STATUS="$(git -C "$R" status --porcelain)"
printf '    committed=[%s]\n' "$COMMITTED"
if [ "$COMMITTED" = "README.md " ]; then ok "only README committed"; else ko "got [$COMMITTED]"; fi
if printf '%s\n' "$STATUS" | grep -q '^?? src/dangling.txt$'; then ok "untracked code left untracked"; else ko "untracked code embarked"; fi
if printf '%s\n' "$STATUS" | grep -q '^A  src/staged.txt$'; then ok "pre-staged code stays staged"; else ko "pre-staged code embarked"; fi
rm -rf "$R"

echo "T4 — stale-staged doc (A) → commit carries working-tree (B)"
R="$(new_repo)"
printf 'VERSION A\n' >>"$R/README.md"; git -C "$R" add README.md   # stage A
printf 'VERSION B\n' >>"$R/README.md"                              # working tree = A+B
run "$R" commit "docs: T4" "README.md"
HEADCONTENT="$(git -C "$R" show HEAD:README.md)"
printf '    HEAD README tail: %s\n' "$(printf '%s' "$HEADCONTENT" | tail -1)"
if printf '%s\n' "$HEADCONTENT" | grep -q 'VERSION B'; then ok "commit contains working-tree B (re-stage neutralized stale index)"; else ko "stale index A leaked"; fi
rm -rf "$R"

echo "T5 — idempotent: empty list / clean tree → no-op exit 0"
R="$(new_repo)"
BEFORE="$(git -C "$R" rev-parse HEAD)"
run "$R" commit "docs: T5 empty"           # no files at all
printf '    [no files]  rc=%s  err=%s\n' "$RC" "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 0 ]; then ok "empty list → exit 0"; else ko "expected 0, got $RC"; fi
run "$R" commit "docs: T5 clean" "README.md"   # passed but clean
printf '    [clean README]  rc=%s\n' "$RC"
if [ "$RC" -eq 0 ]; then ok "clean path → exit 0"; else ko "expected 0, got $RC"; fi
if [ "$(git -C "$R" rev-parse HEAD)" = "$BEFORE" ]; then ok "no commit created"; else ko "a commit was created"; fi
rm -rf "$R"

echo "T6 — unsafe state (detached HEAD) → exit 3, no commit"
R="$(new_repo)"
git -C "$R" checkout --detach -q
BEFORE="$(git -C "$R" rev-parse HEAD)"
printf 'feature added\n' >>"$R/README.md"
run "$R" commit "docs: T6" "README.md"
printf '    rc=%s  err=%s\n' "$RC" "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 3 ]; then ok "detached HEAD → exit 3"; else ko "expected 3, got $RC"; fi
if [ "$(git -C "$R" rev-parse HEAD)" = "$BEFORE" ]; then ok "no commit created"; else ko "a commit was created"; fi
rm -rf "$R"

echo "T7 — path WITH A SPACE passed as one arg → committed (argv is space-safe)"
R="$(new_repo)"
mkdir -p "$R/docs"
printf 'guide baseline\n' >"$R/docs/My Guide.md"
git -C "$R" add -A; git -C "$R" commit -qm "add spaced doc"
printf 'feature added\n' >>"$R/docs/My Guide.md"
run "$R" commit "docs: T7 spaced" "docs/My Guide.md"
printf '    rc=%s  out(hash)=[%s]\n' "$RC" "$OUT"
if [ "$RC" -eq 0 ]; then ok "exit 0"; else ko "expected 0, got $RC"; fi
if [ -n "$OUT" ]; then ok "hash printed (commit made)"; else ko "no hash"; fi
if git -C "$R" cat-file -e "HEAD:docs/My Guide.md" 2>/dev/null; then ok "spaced path present in HEAD"; else ko "spaced path not committed"; fi
if [ -z "$(git -C "$R" status --porcelain -- "docs/My Guide.md")" ]; then ok "spaced doc clean (embarked as ONE file, not split)"; else ko "spaced doc still dirty"; fi
rm -rf "$R"

echo "T8 — pre-commit hook REJECTS commit → exit 5 LOUD, no stale hash, HEAD unmoved"
R="$(new_repo)"
printf '#!/bin/sh\nexit 1\n' >"$R/.git/hooks/pre-commit"; chmod +x "$R/.git/hooks/pre-commit"
BEFORE="$(git -C "$R" rev-parse HEAD)"
printf 'feature added\n' >>"$R/README.md"
run "$R" commit "docs: T8 rejected" "README.md"
printf '    rc=%s  out=[%s]\n' "$RC" "$OUT"
printf '    err: %s\n' "$(printf '%s' "$ERR" | head -1)"
if [ "$RC" -eq 5 ]; then ok "rejected commit → exit 5"; else ko "expected 5, got $RC (commit failure swallowed = masking)"; fi
if [ -z "$OUT" ]; then ok "stdout empty (no stale hash)"; else ko "stale hash leaked on failure: [$OUT]"; fi
if printf '%s' "$ERR" | grep -qi 'REJECTED'; then ok "stderr is loud (REJECTED)"; else ko "stderr not loud (no REJECTED — likely a false 'committed')"; fi
if [ "$(git -C "$R" rev-parse HEAD)" = "$BEFORE" ]; then ok "HEAD unmoved (nothing committed)"; else ko "HEAD moved despite hook reject"; fi
rm -rf "$R"

rm -f "$ERRFILE"
echo ""
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
