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

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
