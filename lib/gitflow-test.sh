#!/usr/bin/env bash
# Throwaway-repo test suite for lib/gitflow.sh. Each test builds an isolated
# repo under $WORK, asserts, and cleans up. Run: bash lib/gitflow-test.sh
#
# shellcheck disable=SC2016
# (the chk helper EVALs its second arg; single-quoted assertion strings are
#  intentional — they must not expand at definition time.)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# Do NOT override GITFLOW_GITIGNORE_TEMPLATE: the lib self-resolves it from its
# own location (../templates), which is correct in both the repo and installed.
# shellcheck source=/dev/null
source "$HERE/gitflow.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
chk()  { if eval "$2"; then ok "$1"; else no "$1 [ $2 ]"; fi; }
newrepo() { local d="$WORK/$1"; rm -rf "$d"; mkdir -p "$d"; cd "$d" || return 1; git init -q; \
            git config user.email t@t; git config user.name t; \
            git config core.hooksPath /dev/null; }   # hooks off during setup
hookon() { git config --unset core.hooksPath 2>/dev/null || true; }  # use repo default .githooks

echo "T1 — pure predicates"
chk "type feature"        '[ "$(gitflow_branch_type feature/x)" = feature ]'
chk "type hotfix"         '[ "$(gitflow_branch_type hotfix/x)" = hotfix ]'
chk "type main"           '[ "$(gitflow_branch_type main)" = main ]'
chk "type other"          '[ "$(gitflow_branch_type wip/x)" = other ]'
chk "protected main"      'gitflow_protected_base main'
chk "protected develop"   'gitflow_protected_base develop'
chk "not protected feat"  '! gitflow_protected_base feature/x'
chk "base feature=develop" '[ "$(gitflow_base_for feature)" = develop ]'
chk "base hotfix=main"     '[ "$(gitflow_base_for hotfix)" = main ]'
chk "type chore"           '[ "$(gitflow_branch_type chore/x)" = chore ]'
chk "base chore=develop"   '[ "$(gitflow_base_for chore)" = develop ]'
chk "not protected chore"  '! gitflow_protected_base chore/x'

echo "T2 — init fresh (BLK-010 root commit)"
newrepo fresh; echo scaffold > README.md; hookon
gitflow_init "chore: scaffold" >/dev/null 2>&1
chk "main exists"        'git rev-parse --verify -q refs/heads/main >/dev/null'
chk "develop exists"     'git rev-parse --verify -q refs/heads/develop >/dev/null'
chk "root commit on main" '[ -n "$(git rev-parse -q --verify main)" ]'
chk "gitignore created"  '[ -f .gitignore ]'
chk "socle: !.claude/deploy/" 'grep -qxF "!.claude/deploy/" .gitignore'
chk "socle: re-ignore PENDING" 'grep -qxF ".claude/deploy/PENDING.json" .gitignore'
chk "hook installed"     '[ -x .githooks/pre-commit ] && [ "$(git config core.hooksPath)" = .githooks ]'
chk "tree CLEAN after init"  '[ -z "$(git status --porcelain)" ]'
chk "hook TRACKED in commit" 'git ls-files --error-unmatch .githooks/pre-commit >/dev/null 2>&1'
chk "socle IN root commit"   'git show HEAD:.gitignore | grep -qxF ".claude/deploy/PENDING.json"'

echo "T2b — init existing (master→main rename + adoption commit, hook inactive during it)"
newrepo existing
git symbolic-ref HEAD refs/heads/master          # force the repo onto 'master'
echo a > a.txt; printf 'node_modules/\n' > .gitignore; git add -A
git -c core.hooksPath=/dev/null commit -q -m "pre-existing on master"
hookon
gitflow_init >/dev/null 2>&1
chk "master→main renamed"   'git rev-parse --verify -q refs/heads/main >/dev/null && ! git rev-parse --verify -q refs/heads/master >/dev/null'
chk "develop created"        'git rev-parse --verify -q refs/heads/develop >/dev/null'
chk "adoption commit"        'git log main --oneline | grep -q "adopt gitflow"'
chk "existing tree CLEAN"    '[ -z "$(git status --porcelain)" ]'
chk "existing hook tracked"  'git ls-files --error-unmatch .githooks/pre-commit >/dev/null 2>&1'
chk "kept project rule"      'git show HEAD:.gitignore | grep -qxF "node_modules/"'

echo "T3 — hook blocks/permits after init"
cd "$WORK/fresh" || exit 1
git checkout -q main
echo x >> README.md; git add README.md
chk "block direct code on main" '! git commit -q -m onmain 2>/dev/null'
git restore --staged README.md 2>/dev/null; git checkout -q -- README.md
mkdir -p .claude/memory; echo m > .claude/memory/decisions.md; git add .claude/memory/decisions.md
chk "allow .claude/** on main"  'git commit -q -m "chore(memory)" 2>/dev/null'
gitflow_start feature demo >/dev/null 2>&1
echo f > feat.txt; git add feat.txt
chk "allow code on feature"     'git commit -q -m "feat work" 2>/dev/null'

echo "T4/T5 — start picks correct base"
newrepo starts; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start feature foo >/dev/null 2>&1
chk "feature off develop" '[ "$(git symbolic-ref --short HEAD)" = feature/foo ]'
chk "feature has develop ancestry" 'git merge-base --is-ancestor develop HEAD'
git checkout -q develop
gitflow_start hotfix bar >/dev/null 2>&1
chk "hotfix branch named"  '[ "$(git symbolic-ref --short HEAD)" = hotfix/bar ]'
chk "hotfix off main"      'git merge-base --is-ancestor main HEAD'

echo "T6 — finish feature → develop only"
newrepo finfeat; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start feature f1 >/dev/null 2>&1; echo w>w.txt; git add w.txt; git commit -q -m w
main_before="$(git rev-parse main)"
gitflow_finish >/dev/null 2>&1
chk "merged into develop" 'git log develop --oneline | grep -q "Merge feature/f1 into develop"'
chk "main untouched"      "[ \"\$(git rev-parse main)\" = \"$main_before\" ]"
chk "branch deleted"      '! git rev-parse --verify -q refs/heads/feature/f1 >/dev/null'

echo "T6b — finish chore → develop only (standalone memory/doc maintenance)"
newrepo finchore; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start chore c1 >/dev/null 2>&1
mkdir -p .claude/memory; echo m>.claude/memory/x.md; git add -A; git commit -q -m "chore(memory)"
main_before="$(git rev-parse main)"
gitflow_finish >/dev/null 2>&1
chk "chore merged into develop" 'git log develop --oneline | grep -q "Merge chore/c1 into develop"'
chk "chore main untouched"      "[ \"\$(git rev-parse main)\" = \"$main_before\" ]"
chk "chore branch deleted"      '! git rev-parse --verify -q refs/heads/chore/c1 >/dev/null'

echo "T7 — finish hotfix → main + develop fan-out"
newrepo finhot; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start hotfix h1 >/dev/null 2>&1; echo p>patch.txt; git add patch.txt; git commit -q -m patch
gitflow_finish >/dev/null 2>&1
chk "hotfix in main"     'git log main --oneline | grep -q "Merge hotfix/h1 into main"'
chk "hotfix in develop"  'git log develop --oneline | grep -q "Merge hotfix/h1 into develop"'
chk "hotfix branch gone" '! git rev-parse --verify -q refs/heads/hotfix/h1 >/dev/null'

echo "T8 — finish hotfix also lands in OPEN release"
newrepo finhotrel; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start release 1.0 >/dev/null 2>&1; echo r>rel.txt; git add rel.txt; git commit -q -m relwork
gitflow_start hotfix h2 >/dev/null 2>&1; echo p>p2.txt; git add p2.txt; git commit -q -m patch2
gitflow_finish >/dev/null 2>&1
chk "hotfix in open release" 'git log release/1.0 --oneline | grep -q "Merge hotfix/h2 into release/1.0"'

echo "T9 — reconcile is additive + idempotent + preserves project rules"
newrepo recon; echo a>a; git add a; git commit -q -m a
printf '%s\n' "node_modules/" "# my project rule" > .gitignore
gitflow_reconcile_gitignore 2>/dev/null
chk "kept project rule"   'grep -qxF "node_modules/" .gitignore'
chk "added socle"         'grep -qxF ".claude/*" .gitignore'
before="$(md5sum .gitignore)"
gitflow_reconcile_gitignore 2>/dev/null
chk "idempotent 2nd run"  "[ \"$before\" = \"\$(md5sum .gitignore)\" ]"

echo "T10 — COHERENCE: hook verdict == lib predicate (drift detector, #4)"
newrepo coh; echo a>a; hookon; gitflow_init >/dev/null 2>&1
for br in main develop feature/x bugfix/y release/z hotfix/w chore/m master mainline qa; do
  if gitflow_protected_base "$br"; then lib=protected; else lib=open; fi
  git checkout -q -B "$br" 2>/dev/null
  printf 'x\n' >> a; git add a
  if .githooks/pre-commit 2>/dev/null; then hook=allow; else hook=block; fi
  git restore --staged a 2>/dev/null || true
  if { [ "$lib" = protected ] && [ "$hook" = block ]; } || { [ "$lib" = open ] && [ "$hook" = allow ]; }; then
    ok "coherent($br): lib=$lib hook=$hook"
  else
    no "DRIFT($br): lib=$lib hook=$hook"
  fi
done

echo "T11 — CLI executable mode (the contract orchestrators call)"
newrepo cli; echo a>a
bash "$HERE/gitflow.sh" init >/dev/null 2>&1
chk "cli init → develop"      'git rev-parse --verify -q refs/heads/develop >/dev/null'
cli_out="$(bash "$HERE/gitflow.sh" start feature cli-foo 2>/dev/null)"
chk "cli start echoes branch"  "[ \"$cli_out\" = feature/cli-foo ]"
chk "cli start switched HEAD"  '[ "$(git symbolic-ref --short HEAD)" = feature/cli-foo ]'
if bash "$HERE/gitflow.sh" protected-base main;       then ok "cli protected-base main → rc0";    else no "cli protected-base main"; fi
if bash "$HERE/gitflow.sh" protected-base feature/x;  then no "cli protected-base feature (rc0?)"; else ok "cli protected-base feature → rc1"; fi
chk "cli base-for hotfix=main" '[ "$(bash "$HERE/gitflow.sh" base-for hotfix)" = main ]'

echo
echo "==== RESULT: $PASS passed, $FAIL failed ===="
[ "$FAIL" -eq 0 ]
