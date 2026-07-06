#!/usr/bin/env bash
# Deterministic tests for lib/memory-commit.sh.
#
# Proves the surgical-scope safety contract on REAL git behavior (not assumed):
#   - dangling code (untracked OR pre-staged) is NEVER embarked in a memory commit
#   - stale-staged memory (version A) yields the WORKING-TREE version (B) that
#     capitalize just wrote — `git add --` re-stage neutralizes the stale index
#   - clean tree → no-op ; broken git state → skip ; TODO.md is in scope
#
# No -e: run every test and report, even after a failure.
set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$HERE/../memory-commit.sh"
PASS=0
FAIL=0

ok() { printf '    \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
ko() { printf '    \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Fresh throwaway repo with a baseline commit (.claude/memory tracked, src/ tracked).
new_repo() {
  local d
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t
  git -C "$d" config user.name tester
  mkdir -p "$d/.claude/memory" "$d/.claude/tasks" "$d/src"
  printf 'baseline\n' >"$d/.claude/memory/decisions.md"
  printf 'src baseline\n' >"$d/src/app.txt"
  git -C "$d" add -A
  git -C "$d" commit -qm baseline
  printf '%s' "$d"
}

# Files recorded in HEAD (no diff noise).
head_files() { git -C "$1" diff-tree --no-commit-id --name-only -r HEAD; }

echo "T1 — untracked dangling code is NOT embarked"
R="$(new_repo)"
printf 'NEW DECISION\n' >>"$R/.claude/memory/decisions.md"
printf 'junk\n' >"$R/src/dangling.txt"
(cd "$R" && "$HELPER" commit "chore(memory): T1") >/dev/null 2>&1
committed="$(head_files "$R")"
status="$(git -C "$R" status --porcelain)"
printf '    committed: [%s]\n' "$committed"
printf '    status   : [%s]\n' "$status"
if [ "$committed" = ".claude/memory/decisions.md" ]; then ok "only memory committed"; else ko "expected only memory, got [$committed]"; fi
if printf '%s\n' "$status" | grep -q '^?? src/dangling.txt$'; then ok "dangling code still untracked"; else ko "dangling code not left untracked"; fi
rm -rf "$R"

echo "T2 — PRE-STAGED dangling code is NOT embarked, stays staged"
R="$(new_repo)"
printf 'NEW DECISION\n' >>"$R/.claude/memory/decisions.md"
printf 'junk\n' >"$R/src/dangling.txt"
git -C "$R" add src/dangling.txt
(cd "$R" && "$HELPER" commit "chore(memory): T2") >/dev/null 2>&1
committed="$(head_files "$R")"
status="$(git -C "$R" status --porcelain)"
printf '    committed: [%s]\n' "$committed"
printf '    status   : [%s]\n' "$status"
if [ "$committed" = ".claude/memory/decisions.md" ]; then ok "only memory committed"; else ko "expected only memory, got [$committed]"; fi
if printf '%s\n' "$status" | grep -q '^A  src/dangling.txt$'; then ok "pre-staged code remained staged, not embarked"; else ko "pre-staged code state wrong"; fi
rm -rf "$R"

echo "T2-bis — stale-staged memory (A) vs working tree (B): commit must take B"
R="$(new_repo)"
printf 'STALE STAGED VERSION A\n' >>"$R/.claude/memory/decisions.md"
git -C "$R" add .claude/memory/decisions.md            # index = A
printf 'baseline\nFRESH WORKING B\n' >"$R/.claude/memory/decisions.md"  # working = B (no 'A' line)
(cd "$R" && "$HELPER" commit "chore(memory): T2bis") >/dev/null 2>&1
blob="$(git -C "$R" show HEAD:.claude/memory/decisions.md)"
printf '    committed blob:\n'
printf '%s\n' "$blob" | sed 's/^/      | /'
if printf '%s' "$blob" | grep -q 'FRESH WORKING B' && ! printf '%s' "$blob" | grep -q 'STALE STAGED VERSION A'; then
  ok "working-tree (B) committed, stale staged (A) discarded"
else
  ko "stale staged version (A) leaked into the commit"
fi
rm -rf "$R"

echo "T3 — clean tree → no-op, exit 0, HEAD unchanged"
R="$(new_repo)"
before="$(git -C "$R" rev-parse HEAD)"
(cd "$R" && "$HELPER" commit "chore(memory): T3")
rc=$?
after="$(git -C "$R" rev-parse HEAD)"
printf '    exit=%s HEAD %s\n' "$rc" "$([ "$before" = "$after" ] && echo unchanged || echo CHANGED)"
if [ "$rc" -eq 0 ] && [ "$before" = "$after" ]; then ok "no-op, exit 0, HEAD unchanged"; else ko "expected no-op exit 0, got exit $rc"; fi
rm -rf "$R"

echo "T4 — broken git state (mid-merge) → skip, exit 3, no commit"
R="$(new_repo)"
printf 'CHANGE\n' >>"$R/.claude/memory/decisions.md"
: >"$R/.git/MERGE_HEAD"
before="$(git -C "$R" rev-parse HEAD)"
(cd "$R" && "$HELPER" commit "chore(memory): T4")
rc=$?
after="$(git -C "$R" rev-parse HEAD)"
printf '    exit=%s HEAD %s\n' "$rc" "$([ "$before" = "$after" ] && echo unchanged || echo CHANGED)"
if [ "$rc" -eq 3 ] && [ "$before" = "$after" ]; then ok "unsafe state skipped, exit 3, no commit"; else ko "expected skip exit 3, got exit $rc"; fi
rm -rf "$R"

echo "T5 — .claude/tasks/TODO.md is in scope"
R="$(new_repo)"
printf -- '- [ ] task\n' >"$R/.claude/tasks/TODO.md"
(cd "$R" && "$HELPER" commit "chore(memory): T5") >/dev/null 2>&1
committed="$(head_files "$R")"
printf '    committed: [%s]\n' "$committed"
if printf '%s\n' "$committed" | grep -q '^.claude/tasks/TODO.md$'; then ok "TODO.md embarked"; else ko "TODO.md not embarked"; fi
rm -rf "$R"

echo "T6 — stdout contract: commit→hash, no-op→empty, unsafe→empty"
R="$(new_repo)"
printf 'CHG\n' >>"$R/.claude/memory/decisions.md"
out="$( (cd "$R" && "$HELPER" commit "chore(memory): T6") 2>/dev/null )"
expected="$(git -C "$R" rev-parse --short HEAD)"
printf '    commit  stdout=[%s] HEAD=[%s]\n' "$out" "$expected"
if [ -n "$out" ] && [ "$out" = "$expected" ]; then ok "commit emits the memory-commit hash on stdout"; else ko "hash mismatch [$out] != [$expected]"; fi
out="$( (cd "$R" && "$HELPER" commit "chore(memory): T6-noop") 2>/dev/null )"
printf '    no-op   stdout=[%s]\n' "$out"
if [ -z "$out" ]; then ok "no-op emits nothing on stdout"; else ko "no-op leaked stdout [$out]"; fi
printf 'CHG2\n' >>"$R/.claude/memory/decisions.md"
: >"$R/.git/MERGE_HEAD"
out="$( (cd "$R" && "$HELPER" commit "chore(memory): T6-unsafe") 2>/dev/null )"
rc=$?
printf '    unsafe  stdout=[%s] exit=%s\n' "$out" "$rc"
if [ -z "$out" ] && [ "$rc" -eq 3 ]; then ok "unsafe emits nothing on stdout, exit 3"; else ko "unsafe leaked stdout [$out] or rc $rc"; fi
rm -rf "$R"

echo "T7 — double run: at most one commit (real run, not by construction)"
R="$(new_repo)"
printf 'ONCE\n' >>"$R/.claude/memory/decisions.md"
base="$(git -C "$R" rev-list --count HEAD)"
h1="$( (cd "$R" && "$HELPER" commit "chore(memory): T7-run1") 2>/dev/null )"
after1="$(git -C "$R" rev-list --count HEAD)"
h2="$( (cd "$R" && "$HELPER" commit "chore(memory): T7-run2") 2>/dev/null )"
after2="$(git -C "$R" rev-list --count HEAD)"
printf '    counts base=%s after1=%s after2=%s ; h1=[%s] h2=[%s]\n' "$base" "$after1" "$after2" "$h1" "$h2"
if [ "$after1" -eq "$((base + 1))" ] && [ -n "$h1" ]; then ok "run1 created exactly one commit (hash emitted)"; else ko "run1 commit count wrong"; fi
if [ "$after2" -eq "$after1" ] && [ -z "$h2" ]; then ok "run2 is a no-op (no 2nd commit, empty stdout)"; else ko "run2 was not a no-op"; fi
rm -rf "$R"

echo "T8 — pre-commit hook REJECTS commit → fail LOUD (exit 5), no stale hash, HEAD unmoved"
R="$(new_repo)"
printf '#!/bin/sh\nexit 1\n' >"$R/.git/hooks/pre-commit"; chmod +x "$R/.git/hooks/pre-commit"
BEFORE="$(git -C "$R" rev-parse --short HEAD)"
printf 'REJECTED CHANGE\n' >>"$R/.claude/memory/decisions.md"
OUT="$( (cd "$R" && "$HELPER" commit "chore(memory): T8 rejected") 2>/dev/null )"
RC=$?
AFTER="$(git -C "$R" rev-parse --short HEAD)"
printf '    rc=%s out=[%s] before=[%s] after=[%s]\n' "$RC" "$OUT" "$BEFORE" "$AFTER"
if [ "$RC" -eq 5 ]; then ok "rejected commit → exit 5 (fail-loud)"; else ko "expected 5, got $RC (rc0+stale-hash = masked failure)"; fi
if [ -z "$OUT" ]; then ok "stdout empty on rejection (no stale hash)"; else ko "stdout leaked a hash on rejection: [$OUT]"; fi
if [ "$BEFORE" = "$AFTER" ]; then ok "HEAD unmoved"; else ko "HEAD moved despite rejection"; fi
rm -rf "$R"

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
