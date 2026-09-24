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

echo "T12 — finish arg-guard (named branch must equal current, else refuse)"
newrepo finargs; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start feature standon >/dev/null 2>&1; echo w>w.txt; git add w.txt; git commit -q -m w
# mismatch: standing on feature/standon but asking to finish bugfix/other → refuse
# shellcheck disable=SC2034  # mism_out/mism_rc are used in the deferred chk eval strings
mism_out="$(gitflow_finish bugfix other 2>&1)"; mism_rc=$?
chk "arg-mismatch → nonzero rc"       "[ $mism_rc -ne 0 ]"
chk "arg-mismatch → HEAD untouched"   '[ "$(git symbolic-ref --short HEAD)" = feature/standon ]'
chk "arg-mismatch → branch kept"      'git rev-parse --verify -q refs/heads/feature/standon >/dev/null'
chk "arg-mismatch → develop NOT merged" '! git log develop --oneline | grep -q "Merge feature/standon into develop"'
chk "arg-mismatch → message names both" 'printf "%s" "$mism_out" | grep -q "current branch" && printf "%s" "$mism_out" | grep -q "bugfix/other"'
# match: naming the current branch explicitly finishes exactly like the no-arg path
gitflow_finish feature standon >/dev/null 2>&1
chk "arg-match → merged into develop" 'git log develop --oneline | grep -q "Merge feature/standon into develop"'
chk "arg-match → branch deleted"      '! git rev-parse --verify -q refs/heads/feature/standon >/dev/null'

echo "T13 — finish release fan-out (main+develop+delete), 2 open releases + bugfix→develop-only"
newrepo finrel; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start release 9.9.9 >/dev/null 2>&1; echo v>VERSION; git add VERSION; git commit -q -m "bump 9.9.9"
finish_rc=0; gitflow_finish >/dev/null 2>&1 || finish_rc=$?
chk "T13a finish rc 0"                 "[ $finish_rc -eq 0 ]"
chk "T13a main has release commit"     'git log main --oneline | grep -q "bump 9.9.9"'
chk "T13a develop has release commit"  'git log develop --oneline | grep -q "bump 9.9.9"'
chk "T13a release branch deleted"      '! git rev-parse --verify -q refs/heads/release/9.9.9 >/dev/null'

newrepo finrel2; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start release 1.0 >/dev/null 2>&1; echo r1>r1; git add r1; git commit -q -m rel1
gitflow_start release 2.0 >/dev/null 2>&1; echo r2>r2; git add r2; git commit -q -m rel2
gitflow_start hotfix hboth >/dev/null 2>&1; echo p>p; git add p; git commit -q -m hotfixboth
gitflow_finish >/dev/null 2>&1
chk "T13b hotfix in release/1.0" 'git log release/1.0 --oneline | grep -q "Merge hotfix/hboth into release/1.0"'
chk "T13b hotfix in release/2.0" 'git log release/2.0 --oneline | grep -q "Merge hotfix/hboth into release/2.0"'

newrepo finbugfix; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start bugfix bx >/dev/null 2>&1; echo w>w.txt; git add w.txt; git commit -q -m bugfixwork
main_before="$(git rev-parse main)"
gitflow_finish >/dev/null 2>&1
chk "T13c develop has bugfix commit" 'git log develop --oneline | grep -q "Merge bugfix/bx into develop"'
chk "T13c main untouched"            "[ \"\$(git rev-parse main)\" = \"$main_before\" ]"
chk "T13c bugfix branch deleted"     '! git rev-parse --verify -q refs/heads/bugfix/bx >/dev/null'

echo "T14 — hook exemption matrix (mixed-block / MERGE_HEAD / root-commit), direct invocation"
newrepo hookmix; echo a>a; hookon; gitflow_init >/dev/null 2>&1
git checkout -q main
echo "console.log(1)" > src.js
mkdir -p .claude/tasks; echo t > .claude/tasks/t.md
git add src.js .claude/tasks/t.md
chk "T14a mixed code+.claude BLOCKED on main" '! git commit -q -m mixed 2>/dev/null'

newrepo mergehead; echo a>a; hookon; gitflow_init >/dev/null 2>&1
git checkout -q main
echo "console.log(1)" > src.js; git add src.js
touch "$(git rev-parse --git-dir)/MERGE_HEAD"
chk "T14b MERGE_HEAD exemption allows commit on main" 'git commit -q -m "resolve conflict" 2>/dev/null'

newrepo root14c
git symbolic-ref HEAD refs/heads/main   # name the unborn branch 'main' (protected)
gitflow_install_hook   # write + activate BEFORE any commit (unlike newrepo/hookon)
echo x > x.txt; git add x.txt
chk "T14c root commit succeeds hook-active-before-first-commit" 'git commit -q -m root 2>/dev/null'

echo "T15 — init identity precheck: no identity → rc1, zero mutation"
d="$WORK/noident"; rm -rf "$d"; mkdir -p "$d"; cd "$d" || exit 1
git init -q
echo a > a.txt
init_rc=0
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null gitflow_init >/dev/null 2>&1 || init_rc=$?
chk "T15 rc 1 (identity unset)"    "[ $init_rc -eq 1 ]"
chk "T15 no develop branch"        '! git rev-parse --verify -q refs/heads/develop >/dev/null'
chk "T15 unborn HEAD (no commit)"  '! git rev-parse --verify -q HEAD >/dev/null 2>&1'
chk "T15 hooksPath unset"          '[ -z "$(git config core.hooksPath 2>/dev/null)" ]'
chk "T15 nothing staged"           '[ -z "$(git diff --cached --name-only)" ]'
chk "T15 no .gitignore written"    '[ ! -e .gitignore ]'
chk "T15 no .githooks written"     '[ ! -d .githooks ]'

echo "T16 — gitleaks pre-commit backstop (job7), independent of branch protection"
newrepo gl; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start feature glwork >/dev/null 2>&1

# T16a — a real secret pattern staged on a working branch (not main/develop,
# proving this backstop is NOT gated by the branch-protection check above it)
printf 'aws_access_key_id = AKIA%s\n' "GDR5XRBXYARW2I5N" > secret.txt
git add secret.txt
# shellcheck disable=SC2034  # gl_out is used in the deferred chk eval strings
gl_out="$(git commit -q -m "add secret" 2>&1)"; gl_rc=$?
chk "T16a fake secret on feature branch → blocked" "[ $gl_rc -ne 0 ]"
chk "T16a message mentions gitleaks"               'printf "%s" "$gl_out" | grep -qi gitleaks'
chk "T16a nothing committed"          '! git log --oneline 2>/dev/null | grep -q "add secret"'
git restore --staged secret.txt 2>/dev/null || true; rm -f secret.txt

# T16b — a clean commit is unaffected
echo clean > clean.txt; git add clean.txt
chk "T16b clean commit still succeeds" 'git commit -q -m "clean work" 2>/dev/null'

# T16c — gitleaks missing from PATH → warn, never block (defense in depth
# must not become a new single point of failure)
echo clean2 > clean2.txt; git add clean2.txt
# shellcheck disable=SC2034  # noleaks_out is used in the deferred chk eval strings
noleaks_out="$(PATH=/usr/bin:/bin git commit -q -m "clean work 2" 2>&1)"; noleaks_rc=$?
chk "T16c missing-gitleaks → still commits (rc0)" "[ $noleaks_rc -eq 0 ]"
chk "T16c missing-gitleaks → warns"    'printf "%s" "$noleaks_out" | grep -qi "not installed"'

echo "T17 — finish auto-purges transient superpowers artifacts (BDR-065)"
# T17a — feature carrying docs/superpowers spec+plan: purged before merge,
# develop TIP clean, artifacts still recoverable from history (archive property)
newrepo purgefeat; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start feature pf >/dev/null 2>&1
mkdir -p docs/superpowers/specs docs/superpowers/plans
echo spec > docs/superpowers/specs/s.md
echo plan > docs/superpowers/plans/p.md
echo code > feat.txt
git add -A; git commit -q -m "feat + transient spec/plan"
gitflow_finish >/dev/null 2>&1
# the add-commit stays reachable from develop via the --no-ff merge's 2nd parent;
# --full-history defeats the path simplification that hides it, and `git show
# <sha>:path` proves BDR-065's "git history = the archive" recovery.
# shellcheck disable=SC2034  # pf_add_sha is used in the deferred chk eval string
pf_add_sha="$(git log develop --full-history --format=%H -- docs/superpowers/specs/s.md | tail -1)"
chk "T17a merged into develop"           'git log develop --oneline | grep -q "Merge feature/pf into develop"'
chk "T17a develop TIP has no transient"  '[ -z "$(git ls-tree -r develop --name-only -- docs/superpowers)" ]'
chk "T17a purge commit on record"        'git log develop --oneline | grep -q "purge transient planning artifacts"'
chk "T17a artifact recoverable from history" '[ "$(git show "$pf_add_sha":docs/superpowers/specs/s.md 2>/dev/null)" = spec ]'
chk "T17a non-transient code survives"   'git ls-tree -r develop --name-only | grep -qx feat.txt'
chk "T17a feature branch deleted"        '! git rev-parse --verify -q refs/heads/feature/pf >/dev/null'

# T17b — no artifacts → purge is a silent no-op, no spurious commit
newrepo purgenone; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start feature pn >/dev/null 2>&1; echo w>w.txt; git add w.txt; git commit -q -m w
gitflow_finish >/dev/null 2>&1
chk "T17b merged into develop"     'git log develop --oneline | grep -q "Merge feature/pn into develop"'
chk "T17b no purge commit created" '! git log develop --oneline | grep -q "purge transient"'

# T17c — opt-out (GITFLOW_PURGE_TRANSIENT=0) keeps the artifacts on develop
newrepo purgeoff; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start feature po >/dev/null 2>&1
mkdir -p docs/superpowers/specs; echo spec > docs/superpowers/specs/s.md
git add -A; git commit -q -m "feat + spec"
GITFLOW_PURGE_TRANSIENT=0 gitflow_finish >/dev/null 2>&1
chk "T17c opt-out keeps transient on develop TIP" '[ -n "$(git ls-tree -r develop --name-only -- docs/superpowers)" ]'

# T17d — chore is OUT of purge scope (only feature/bugfix originate artifacts)
newrepo purgechore; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start chore pc >/dev/null 2>&1
mkdir -p docs/superpowers/specs; echo spec > docs/superpowers/specs/s.md
git add -A; git commit -q -m "chore + spec"
gitflow_finish >/dev/null 2>&1
chk "T17d chore leaves transient (not in scope)" '[ -n "$(git ls-tree -r develop --name-only -- docs/superpowers)" ]'

echo "T18 — auto-push: branch pushed at start, every commit pushed (BDR-095)"
newrepo pushsrc; echo a>a; hookon; gitflow_init >/dev/null 2>&1
bare="$WORK/pushsrc.git"; git init -q --bare "$bare"; git remote add origin "$bare"
git push -q origin main develop 2>/dev/null
gitflow_start feature ap >/dev/null 2>&1
chk "T18a start pushed the branch"        'git ls-remote --heads origin feature/ap | grep -q feature/ap'
echo w>w; git add w; git commit -q -m w 2>/dev/null
chk "T18b commit pushed by post-commit"   '[ "$(git rev-parse HEAD)" = "$(git -C "$bare" rev-parse feature/ap)" ]'
echo w2>>w; git add w; GITFLOW_NO_PUSH=1 git commit -q -m w2 2>/dev/null
chk "T18c GITFLOW_NO_PUSH=1 → not pushed" '[ "$(git rev-parse HEAD)" != "$(git -C "$bare" rev-parse feature/ap)" ]'
git config gitflow.autopush false
echo w2b>>w; git add w; git commit -q -m w2b 2>/dev/null
chk "T18h gitflow.autopush=false → not pushed" '[ "$(git rev-parse HEAD)" != "$(git -C "$bare" rev-parse feature/ap)" ]'
git config --unset gitflow.autopush
git remote set-url origin /nonexistent/x.git
echo w3>>w; git add w
# shellcheck disable=SC2034  # ap_out/ap_rc are read by the deferred chk evals
ap_out="$(git commit -q -m w3 2>&1)"; ap_rc=$?
chk "T18d unreachable origin → commit still succeeds" "[ $ap_rc -eq 0 ]"
chk "T18e unreachable origin → loud warning"         'printf "%s" "$ap_out" | grep -q "FAILED"'
git remote set-url origin "$bare"
gitflow_finish >/dev/null 2>&1
chk "T18f finish pushed develop (merge commit)"      '[ "$(git rev-parse develop)" = "$(git -C "$bare" rev-parse develop)" ]'
newrepo noremote; echo a>a; hookon; gitflow_init >/dev/null 2>&1
gitflow_start feature nr >/dev/null 2>&1; echo w>w; git add w
# shellcheck disable=SC2034
nr_out="$(git commit -q -m w 2>&1)"; nr_rc=$?
chk "T18g no origin → silent, commit ok"            "[ $nr_rc -eq 0 ] && ! printf '%s' \"\$nr_out\" | grep -q FAILED"

echo "T19 — installed hooks == emitted hooks in the config repo (LRN-114 drift gate)"
if [ -d "$HERE/../.githooks" ]; then
  chk "T19a pre-commit installed == emitted"  'diff -q <(_gitflow_emit_pre_commit) "$HERE/../.githooks/pre-commit" >/dev/null'
  chk "T19b post-commit installed == emitted" 'diff -q <(_gitflow_emit_push_hook post-commit) "$HERE/../.githooks/post-commit" >/dev/null'
  chk "T19c post-merge installed == emitted"  'diff -q <(_gitflow_emit_push_hook post-merge) "$HERE/../.githooks/post-merge" >/dev/null'
  chk "T19e reference-transaction installed == emitted" 'diff -q <(_gitflow_emit_reference_transaction) "$HERE/../.githooks/reference-transaction" >/dev/null'
else
  ok "T19 skipped (no .githooks next to the lib)"
fi
if [ -d "$HERE/../githooks" ]; then
  for h in "${GITFLOW_HOOKS[@]}"; do
    chk "T19d global githooks/$h == emitted" "diff -q <(_gitflow_emit_hook $h) \"$HERE/../githooks/$h\" >/dev/null"
  done
else
  ok "T19d skipped (no githooks/ next to the lib — run make link)"
fi

echo "T20 — reconcile-hooks: a stale .githooks/ is refreshed, a current one is left alone"
newrepo rec; echo a>a; hookon; gitflow_init >/dev/null 2>&1
rm -f .githooks/post-commit; echo "# stale" >> .githooks/pre-commit
# shellcheck disable=SC2034
rec_out="$(gitflow_reconcile_hooks 2>/dev/null)"
chk "T20a names the refreshed hooks"      'printf "%s" "$rec_out" | grep -q "pre-commit" && printf "%s" "$rec_out" | grep -q "post-commit"'
chk "T20b pre-commit rewritten == emitted" 'diff -q <(_gitflow_emit_pre_commit) .githooks/pre-commit >/dev/null'
chk "T20c post-commit restored"            '[ -x .githooks/post-commit ]'
chk "T20d second run is silent"            '[ -z "$(gitflow_reconcile_hooks 2>/dev/null)" ]'
mkdir -p sub; cd sub || exit 1; echo "# stale" >> ../.githooks/post-merge
chk "T20e works from a subdirectory"       'gitflow_reconcile_hooks 2>/dev/null | grep -q post-merge'
cd .. || exit 1
newrepo plain; echo a>a; git add a; git commit -q -m a
chk "T20f non-gitflow repo → silent, no .githooks created" '[ -z "$(gitflow_reconcile_hooks 2>/dev/null)" ] && [ ! -d .githooks ]'

echo "T21 — pre-commit whitelist + per-repo protect opt-out"
newrepo wl; echo a>a; hookon; gitflow_init >/dev/null 2>&1
git checkout -q develop
echo "# tweak" >> .githooks/post-merge; git add .githooks/post-merge
chk "T21a .githooks/-only commit on develop → allowed" '.githooks/pre-commit 2>/dev/null'
echo code>code.txt; git add code.txt
chk "T21b .githooks/ + code on develop → blocked"    '! .githooks/pre-commit 2>/dev/null'
git config gitflow.protect false
chk "T21c gitflow.protect=false → allowed"           '.githooks/pre-commit 2>/dev/null'
git config --unset gitflow.protect
git restore --staged code.txt .githooks/post-merge 2>/dev/null || true

echo "T22 — delete guard: never main/develop, never unmerged (premise: -d is dead once the upstream is in sync)"
newrepo delguard; echo a>a; hookon; gitflow_init >/dev/null 2>&1
bare="$WORK/delguard.git"; git init -q --bare "$bare"; git remote add origin "$bare"
git push -q origin main develop 2>/dev/null
gitflow_start feature weak >/dev/null 2>&1; echo w>w; git add w; git commit -q -m w 2>/dev/null
git checkout -q develop
chk "T22a PREMISE: git branch -d deletes an UNMERGED branch whose upstream is in sync" \
    'git branch -q -d feature/weak 2>/dev/null && ! git rev-parse --verify -q refs/heads/feature/weak >/dev/null'
gitflow_start feature keep >/dev/null 2>&1; echo k>k; git add k; git commit -q -m k 2>/dev/null
chk "T22b merged_into_base: unmerged → false"        '! gitflow_merged_into_base feature/keep'
# shellcheck disable=SC2034  # *_rc are read by the deferred chk evals
del_rc=0; gitflow_delete feature/keep >/dev/null 2>&1 || del_rc=$?
chk "T22c gitflow_delete refuses an unmerged branch (rc 5)" "[ $del_rc -eq 5 ]"
chk "T22d … and the branch is kept"                  'git rev-parse --verify -q refs/heads/feature/keep >/dev/null'
dev_rc=0; gitflow_delete develop >/dev/null 2>&1 || dev_rc=$?
chk "T22e refuses develop (rc 6), develop kept"      "[ $dev_rc -eq 6 ] && git rev-parse --verify -q refs/heads/develop >/dev/null"
main_rc=0; gitflow_delete main >/dev/null 2>&1 || main_rc=$?
chk "T22f refuses main (rc 6), main kept"            "[ $main_rc -eq 6 ] && git rev-parse --verify -q refs/heads/main >/dev/null"
nope_rc=0; gitflow_delete feature/nope >/dev/null 2>&1 || nope_rc=$?
chk "T22g unknown branch → rc 2"                     "[ $nope_rc -eq 2 ]"
git checkout -q develop; git merge -q --no-ff -m "merge keep" feature/keep 2>/dev/null
chk "T22h merged_into_base: merged into develop → true" 'gitflow_merged_into_base feature/keep'
chk "T22i gitflow_delete deletes a merged branch"    'gitflow_delete feature/keep >/dev/null 2>&1 && ! git rev-parse --verify -q refs/heads/feature/keep >/dev/null'
git checkout -q main; git checkout -q -b hotfix/h; echo h>h; git add h; git commit -q -m h 2>/dev/null
git checkout -q main; git merge -q --no-ff -m "merge h" hotfix/h 2>/dev/null
chk "T22j merged into main only → deletable"         'gitflow_delete hotfix/h >/dev/null 2>&1 && ! git rev-parse --verify -q refs/heads/hotfix/h >/dev/null'
chk "T22k CLI: merged verb"                          'bash "$HERE/gitflow.sh" merged develop'
newrepo nobase; git symbolic-ref HEAD refs/heads/trunk; echo a>a; git add a; git commit -q -m a
git checkout -q -b topic; echo t>t; git add t; git commit -q -m t; git checkout -q trunk
chk "T22l no main/develop in the repo → refuses (fail closed), branch kept" \
    '! gitflow_delete topic >/dev/null 2>&1 && git rev-parse --verify -q refs/heads/topic >/dev/null'

echo "T23 — reference-transaction hook: main/develop can never be deleted or renamed, whatever the command"
newrepo rt; echo a>a; hookon; gitflow_init >/dev/null 2>&1
chk "T23a hook installed + executable"               '[ -x .githooks/reference-transaction ]'
gitflow_start feature rt >/dev/null 2>&1   # stand on a working branch: git itself would allow deleting develop
chk "T23b force-delete develop → blocked, develop kept"    '! git branch -D develop >/dev/null 2>&1 && git rev-parse --verify -q refs/heads/develop >/dev/null'
chk "T23c force-delete main → blocked, main kept"          '! git branch -D main >/dev/null 2>&1 && git rev-parse --verify -q refs/heads/main >/dev/null'
chk "T23d update-ref -d refs/heads/develop → blocked"      '! git update-ref -d refs/heads/develop >/dev/null 2>&1 && git rev-parse --verify -q refs/heads/develop >/dev/null'
chk "T23e rename develop → blocked, nothing renamed" \
    '! git branch -m develop dev2 >/dev/null 2>&1 && git rev-parse --verify -q refs/heads/develop >/dev/null && ! git rev-parse --verify -q refs/heads/dev2 >/dev/null'
echo r>r; git add r; git commit -q -m r 2>/dev/null
chk "T23f ordinary commit unaffected"                '[ "$(git log -1 --format=%s)" = r ]'
git checkout -q develop; git checkout -q feature/rt
chk "T23g checkout unaffected"                       '[ "$(git symbolic-ref --short HEAD)" = feature/rt ]'
gitflow_finish >/dev/null 2>&1
chk "T23h finish: the merged feature still deletes through the hook" '! git rev-parse --verify -q refs/heads/feature/rt >/dev/null'
git checkout -q -b feature/tmp; git checkout -q develop
chk "T23i a non-protected branch passes the hook"    'git branch -d feature/tmp >/dev/null 2>&1'
git config gitflow.protect false; git checkout -q main
chk "T23j gitflow.protect=false → develop deletable (foreign-clone opt-out)" \
    'git branch -D develop >/dev/null 2>&1 && ! git rev-parse --verify -q refs/heads/develop >/dev/null'
git config --unset gitflow.protect
chk "T23k CLI: hooks verb lists the four hooks" \
    '[ "$(bash "$HERE/gitflow.sh" hooks | tr "\n" " ")" = "pre-commit post-commit post-merge reference-transaction " ]'

echo "T24 — remote copy removed after a verified merge (best effort; never a base, never an unmerged tip)"
newrepo rdel; echo a>a; hookon; gitflow_init >/dev/null 2>&1
bare="$WORK/rdel.git"; git init -q --bare "$bare"; git remote add origin "$bare"
git push -q origin main develop 2>/dev/null
gitflow_start feature rd >/dev/null 2>&1; echo w>w; git add w; git commit -q -m w 2>/dev/null
chk "T24a precondition: origin/feature/rd exists"    'git ls-remote --exit-code --heads origin feature/rd >/dev/null 2>&1'
# shellcheck disable=SC2034  # *_out/*_rc are read by the deferred chk evals
fin_out="$(gitflow_finish 2>&1)"
chk "T24b finish removed origin/feature/rd, said so" '! git ls-remote --exit-code --heads origin feature/rd >/dev/null 2>&1 && printf "%s" "$fin_out" | grep -q "removed origin/feature/rd"'
chk "T24c develop + main still on origin"           'git ls-remote --exit-code --heads origin develop >/dev/null 2>&1 && git ls-remote --exit-code --heads origin main >/dev/null 2>&1'
# a commit pushed from elsewhere onto origin/feature/ahead, never merged → remote copy KEPT
gitflow_start feature ahead >/dev/null 2>&1; echo x>x; git add x; git commit -q -m x 2>/dev/null
git checkout -q develop; git merge -q --no-ff -m "merge ahead" feature/ahead 2>/dev/null
other="$WORK/rdel-other"; git clone -q "$bare" "$other" 2>/dev/null
( cd "$other" && git config core.hooksPath /dev/null && git config user.email o@o && git config user.name o \
  && git checkout -q feature/ahead && echo z>z && git add z && git commit -q -m elsewhere && git push -q origin feature/ahead 2>/dev/null )
# shellcheck disable=SC2034
ah_out="$(gitflow_delete feature/ahead 2>&1)"; ah_rc=$?
chk "T24d local merged branch deleted, rc 0"        "[ $ah_rc -eq 0 ] && ! git rev-parse --verify -q refs/heads/feature/ahead >/dev/null"
chk "T24e remote tip holds an unmerged commit → origin copy KEPT, loud" \
    'git ls-remote --exit-code --heads origin feature/ahead >/dev/null 2>&1 && printf "%s" "$ah_out" | grep -q KEPT'
# never pushed → nothing to remove, silent
GITFLOW_NO_PUSH=1 gitflow_start feature local >/dev/null 2>&1; echo l>l; git add l; GITFLOW_NO_PUSH=1 git commit -q -m l 2>/dev/null
git checkout -q develop; GITFLOW_NO_PUSH=1 git merge -q --no-ff -m "merge local" feature/local 2>/dev/null
# shellcheck disable=SC2034
nl_out="$(gitflow_delete feature/local 2>&1)"; nl_rc=$?
chk "T24f no remote copy → rc 0, silent"             "[ $nl_rc -eq 0 ] && [ -z \"\$nl_out\" ]"
# origin unreachable → local gone, loud, rc 0, remote copy untouched
gitflow_start feature off >/dev/null 2>&1; echo o>o; git add o; git commit -q -m o 2>/dev/null
git checkout -q develop; git merge -q --no-ff -m "merge off" feature/off 2>/dev/null
git remote set-url origin /nonexistent/x.git
# shellcheck disable=SC2034
off_out="$(gitflow_delete feature/off 2>&1)"; off_rc=$?
git remote set-url origin "$bare"
chk "T24g origin unreachable → local deleted, rc 0, loud 'NOT removed'" \
    "[ $off_rc -eq 0 ] && ! git rev-parse --verify -q refs/heads/feature/off >/dev/null && printf '%s' \"\$off_out\" | grep -q 'NOT removed'"
chk "T24h … remote copy still there"                'git ls-remote --exit-code --heads origin feature/off >/dev/null 2>&1'
# gitflow.autopush=false (no push rights) → remote copy untouched
gitflow_start feature np >/dev/null 2>&1; echo n>n; git add n; git commit -q -m n 2>/dev/null
git checkout -q develop; git merge -q --no-ff -m "merge np" feature/np 2>/dev/null
git config gitflow.autopush false
gitflow_delete feature/np >/dev/null 2>&1
git config --unset gitflow.autopush
chk "T24i gitflow.autopush=false → remote copy untouched" 'git ls-remote --exit-code --heads origin feature/np >/dev/null 2>&1'

echo
echo "==== RESULT: $PASS passed, $FAIL failed ===="
[ "$FAIL" -eq 0 ]
