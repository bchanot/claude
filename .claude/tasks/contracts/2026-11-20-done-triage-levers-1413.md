# CONTRACT — done-triage-levers
- date: 2026-11-20 | flow: feat | branch: feature/done-triage-levers
- status: active
- run-base: 68a4d8b

## REQUEST (verbatim — IMMUTABLE)
Implémente les six leviers décrits dans .claude/tasks/plans/2026-11-20-done-and-triage-levers.md (TODO "NEXT, fresh session"). Suis le plan tel quel : 5 fichiers, challenge maintenu car c'est un nouveau mécanisme.

## CLARIFICATIONS
none — request complete (the handoff plan names the six levers, their substance and their five carriers; placement and exact prose are settled in the run plan .claude/tasks/plans/2026-11-20-done-triage-levers-1413.md, challenged r1 by three lenses)
Q: CLAUDE.global.md lever-4 line wording / A: keep "A TODO loop notes its start SHA in TODO.md, runs that list + user adds; new items: report, run if one breaks its work." [gated 2026-11-20]
Q: strings `MINOR dropped: <finding>` and `Challenge: skipped (placed decision: …)` / A: both OK [gated 2026-11-20]
Q: extend scope to (a) lib/contract-interview.md STEP 4 and (b) skills/ship-feature STEP 6 + skills/init-project STEP 10? / A: both (a) and (b). Three more files exceed /feat's five-file cap: this run stays on its five files, (a)+(b) run as a follow-up /feat right after this one (3 files) [gated 2026-11-20]
Q: GATE 2 REPORTED (1) LOW `$run_base` reaches `git diff` without `--end-of-options`/SHA check (lib/capitalize-commit.md:75), (2) verifier STEP 4 accepts `[gated]` lines on a tracked contract / A: fix both in the follow-up /feat (now 5 files: contract-interview, ship-feature, init-project, capitalize-commit, verifier) [gated 2026-11-20]

## ACCEPTANCE CRITERIA
1. Lever 1, done = oracles green: lib/verify-secure-loop.md has `## DONE: oracles green, reopened only on evidence`: done at GATE 0 MET + GATE 1 CONFORME + GATE 2 PASS; a review reopens only with reproducible evidence (a command failing on HEAD, or real output shown wrong); a plausible scenario gets one attempt at a failing command, else it is a MINOR; a behavioural claim is done at locks green + one live probe + one dated measurement.
   CHECK: f=lib/verify-secure-loop.md; grep -q '^## DONE: oracles green, reopened only on evidence$' $f && grep -q 'only with reproducible evidence: a command that fails on HEAD, or real$' $f && grep -q '^output shown wrong. A plausible scenario alone does not reopen the run:$' $f && grep -q '^the main loop tries once to turn it into a failing command, and if it$' $f && grep -q '^the rule") is done at its locks green, one live probe and one dated$' $f && echo LEVER1_OK
   EXPECT: LEVER1_OK
   EVIDENCE: MET exit=0 marker-found :: LEVER1_OK
2. Lever 2, MINOR triage: lib/verify-secure-loop.md has `## MINOR triage: fold before dispatch, or drop`: a MINOR on the run's plan or diff is folded before dispatch or dropped; no post-gate fix round; a drop is one `MINOR dropped:` line in the report and the run's plan file, nothing in TODO.md / BUGS-FOUND.md / a registry; backlog only on reproducible evidence or user ask; a security finding is never droppable and goes to the user; doc-syncer's `[MINOR]` patch class, guardrails, gates and user questions are untouched.
   CHECK: f=lib/verify-secure-loop.md; grep -q '^## MINOR triage: fold before dispatch, or drop$' $f && grep -q '^fix round after the gates for a MINOR: it costs a full gate cycle. A drop$' $f && grep -q 'is one line, `MINOR dropped: <finding>`, in the run report and appended to$' $f && grep -q 'the run.s plan file; nothing goes to TODO.md, BUGS-FOUND.md or any$' $f && grep -q 'what the user asks for. Never a droppable MINOR: a security finding (a$' $f && grep -q '^Untouched by this triage: doc-syncer.s `\[MINOR\]` patch class, the safety$' $f && echo LEVER2_OK
   EXPECT: LEVER2_OK
   EVIDENCE: MET exit=0 marker-found :: LEVER2_OK
3. Lever 3, placed decision: lib/challenge-plan.md has `## SKIP: a placed decision` before `## DISPATCH`: skip = no challengers and no plan advisor call; three required conditions (text dictated by the decision; the decision is the user's own words or was challenged in the run that wrote it; the caller runs verify-secure-loop.md after its dispatch); the open-choice test, never code versus text, in doubt challenge; the skip is the include's own path (user decision 2026-11-20) and discharges the plan point of effort-shift § Advisor; the caller prints `Challenge: skipped (placed decision: …)`.
   CHECK: f=lib/challenge-plan.md; s=$(grep -n '^## SKIP: a placed decision$' $f | cut -d: -f1); d=$(grep -n '^## DISPATCH' $f | cut -d: -f1); [ -n "$s" ] && [ "$s" -lt "$d" ] && grep -q '^no challengers and no plan advisor call. Three conditions, all required:$' $f && grep -q '^decision.s text is the user.s own words, or was challenged in the run that$' $f && grep -q '^user did not dictate), never code versus text; in doubt, challenge. The$' $f && grep -q '^skip is this include.s own path (user decision 2026-11-20): a skill.s$' $f && grep -q '^discharges the plan point (`lib/effort-shift.md` § Advisor). The caller prints$' $f && grep -q '^`Challenge: skipped (placed decision: <the user.s decision, date>)` in$' $f && echo LEVER3_OK
   EXPECT: LEVER3_OK
   EVIDENCE: MET exit=0 marker-found :: LEVER3_OK
4. Lever 2 at the challenge synthesis: lib/challenge-plan.md's SYNTHESIZE MINOR bullet says each MINOR is folded now or dropped, gives the drop format inline, routes a security finding to the user, and cites `lib/verify-secure-loop.md` § MINOR triage.
   CHECK: f=lib/challenge-plan.md; grep -q '^  Each MINOR is folded into the plan now or dropped: a drop is one$' $f && grep -q '^  `MINOR dropped: <finding>` line in the report and the plan file, nothing$' $f && grep -q '^  (`lib/verify-secure-loop.md` § MINOR triage).$' $f && echo SYNTH_OK
   EXPECT: SYNTH_OK
   EVIDENCE: MET exit=0 marker-found :: SYNTH_OK
5. Lever 4, frozen loop list: CLAUDE.global.md's Planning & TODO section says a TODO loop notes its start SHA in TODO.md, runs that list plus user adds, reports new items and runs one only if it breaks its work; the file stays at or under 320 lines and the new lines at or under 80 chars.
   CHECK: f=CLAUDE.global.md; [ "$(wc -l < $f)" -le 320 ] && awk '/^## Planning & TODO/{p=1;next} /^## /{p=0} p' $f > /tmp/.cg5.$$ && grep -q '^  then carries one line per run. A TODO loop notes its start SHA in TODO.md,$' /tmp/.cg5.$$ && grep -q '^  runs that list + user adds; new items: report, run if one breaks its work.$' /tmp/.cg5.$$ && [ "$(git diff -U0 68a4d8b -- $f | grep '^+[^+]' | awk 'length($0)>81' | wc -l)" -eq 0 ] && rm -f /tmp/.cg5.$$ && echo LEVER4_OK
   EXPECT: LEVER4_OK
   EVIDENCE: MET exit=0 marker-found :: LEVER4_OK
6. Lever 5 main-loop side: lib/verify-secure-loop.md's header says its first section runs before the dev dispatch; `## BEFORE THE FIRST DISPATCH: contract dry run (main loop)` sits before `## GATE 0`, applies when the flow wrote a contract with `CHECK:` lines, records `- run-base: <git rev-parse HEAD>` (a SHA), runs `gates.sh run` on a `mktemp -d` copy from the project root (no ERROR, NOT-MET only for undone work and for that reason, already-MET valid only for keep-green rows), states the scratch-copy simulation for prose oracles inline, and fixes bad oracles before any floor loop. lib/challenge-plan.md restates the two actions outside the SKIP condition, before the executor dispatch.
   CHECK: f=lib/verify-secure-loop.md; b=$(grep -n '^## BEFORE THE FIRST DISPATCH: contract dry run (main loop)$' $f | cut -d: -f1); g=$(grep -n '^## GATE 0' $f | cut -d: -f1); [ -n "$b" ] && [ "$b" -lt "$g" ] && grep -q '^section runs before the dev step is dispatched). Turns a$' $f && grep -q '^When the flow wrote a contract with `CHECK:` lines, the main loop does two$' $f && grep -q '^   `- run-base: <git rev-parse HEAD>` (a SHA, never a branch name;$' $f && grep -q '^2. Copies the contract to a `mktemp -d` path and, from the project root,$' $f && grep -q '^   to a scratch copy of the repo and run the CHECKs there (LRN-296).$' $f && grep -q '^A bad oracle is fixed in the contract here, before any floor loop.$' $f && grep -q '^Challenged or skipped: when the flow wrote a contract with `CHECK:` lines,$' lib/challenge-plan.md && grep -q '^before the executor dispatch the main loop records `- run-base:` in the$' lib/challenge-plan.md && grep -q '^(`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH).$' lib/challenge-plan.md && echo DRYRUN_OK
   EXPECT: DRYRUN_OK
   EVIDENCE: MET exit=0 marker-found :: DRYRUN_OK
7. Lever 5 verifier side: agents/verifier.md STEP 4 counts run artifacts in scope by default (name-status plus untracked): a plan file the diff ADDS under `.claude/tasks/plans/` or `docs/superpowers/plans/`; on an existing plan, appended `MINOR dropped:` lines only; the CONTRACT handed to the verifier, whole when untracked or added, else only its `EVIDENCE:`, `- run-base:` and `[gated]` lines; any other plan or contract change stays out of scope. lib/verify-secure-loop.md's out-of-scope bullet points to it.
   CHECK: f=agents/verifier.md; awk '/^## STEP 4/{p=1;next} /^## /{p=0} p' $f > /tmp/.vf7.$$; grep -q '^`FILE SCOPE` says: a plan file the diff ADDS under `.claude/tasks/plans/`$' /tmp/.vf7.$$ && grep -q '^`MINOR dropped:` lines only; the CONTRACT you were handed, whole when$' /tmp/.vf7.$$ && grep -q '^untracked or added, else only its `EVIDENCE:` lines, `- run-base:` line and$' /tmp/.vf7.$$ && grep -q '^`\[gated\]` entries. Any other change to a plan or a contract stays out of$' /tmp/.vf7.$$ && grep -q '^  default (`agents/verifier.md`, STEP 4).$' lib/verify-secure-loop.md && rm -f /tmp/.vf7.$$ && echo SCOPE_OK
   EXPECT: SCOPE_OK
   EVIDENCE: MET exit=0 marker-found :: SCOPE_OK
8. Lever 6, `TODO +n / -m`: lib/capitalize-commit.md computes `<todo>` in DO step 1, before step 2's commit; `run_base` is a SHA from the contract's `- run-base:` line else `git rev-parse HEAD` at that point (with a `shortcut:` note); a failing diff gives `TODO n/a`; step 3 and both rc 0 templates carry `· <todo>`. The 6-line snippet, on a fixture where a run closes one open item, edits a closed one and adds two, yields `TODO +2 / -1` with the start SHA (uncommitted, then committed, run from a subdirectory), the same with `HEAD` on the uncommitted change, and `TODO n/a` on an unknown SHA.
   CHECK: f=$PWD/lib/capitalize-commit.md; a=$(grep -n '^   Then, still before step 2, count the run.s TODO movement as `<todo>`:$' $f | cut -d: -f1); c=$(grep -n '^2. Commit surgically' $f | cut -d: -f1); [ -n "$a" ] && [ "$a" -lt "$c" ] && grep -q '^3. Report by (rc, mem_hash). Every report line ends with `· <todo>` (step 1):$' $f && grep -q '`✅ mémoire committée <mem_hash> · <todo>`' $f && grep -q '`CAPITALIZE: rien à committer · <todo>`' $f && grep -q 'never the gitflow base branch: the contract.s `- run-base:` line' $f && grep -q '`git rev-parse HEAD` now (shortcut: without a contract only the pending' $f && t=$(mktemp -d) && s=$t/s.sh && awk '/^       if d=\$\(git diff --no-color/{p=1} p{print} p&&/todo="TODO n\/a"; fi$/{exit}' $f | sed 's/^       //' > $s && [ "$(wc -l < $s)" -eq 6 ] && mkdir $t/r && cd $t/r && git init -q && mkdir -p .claude/tasks sub && printf -- '- [ ] a\n- [ ] b\n- [x] old\n' > .claude/tasks/TODO.md && git add . && git -c user.email=t@t -c user.name=t commit -qm base && b=$(git rev-parse HEAD) && printf -- '- [x] a DONE\n- [ ] b\n- [x] old edited\n- [ ] c\n- [ ] d\n' > .claude/tasks/TODO.md && r1=$(run_base=$b bash -c ". $s; echo \"\$todo\"") && r2=$(run_base=HEAD bash -c ". $s; echo \"\$todo\"") && r3=$(run_base=0123456789abcdef0123456789abcdef01234567 bash -c ". $s; echo \"\$todo\"") && git add . && git -c user.email=t@t -c user.name=t commit -qm run && r4=$(cd sub && run_base=$b bash -c ". $s; echo \"\$todo\"") && echo "R1=$r1 R2=$r2 R3=$r3 R4=$r4"
   EXPECT: R1=TODO +2 / -1 R2=TODO +2 / -1 R3=TODO n/a R4=TODO +2 / -1
   EVIDENCE: MET exit=0 marker-found :: R1=TODO +2 / -1 R2=TODO +2 / -1 R3=TODO n/a R4=TODO +2 / -1
9. No em-dash in any line this run adds to the five files, and all five files are changed.
   CHECK: n=$(git diff -U0 68a4d8b -- lib/verify-secure-loop.md lib/challenge-plan.md CLAUDE.global.md lib/capitalize-commit.md agents/verifier.md | grep '^+[^+]' | grep -c '—'); [ "$n" -eq 0 ] && [ "$(git diff --name-only 68a4d8b -- lib/verify-secure-loop.md lib/challenge-plan.md CLAUDE.global.md lib/capitalize-commit.md agents/verifier.md | wc -l)" -eq 5 ] && echo NODASH_OK
   EXPECT: NODASH_OK
   EVIDENCE: MET exit=0 marker-found :: NODASH_OK
10. Locking suites stay green (doctrine census incl. the new § citations, escalate-route count, challenge wiring, advisor row lock).
   CHECK: make test suite="lib/tests/doctrine-citers.test.sh lib/tests/effort-routing.test.sh lib/tests/plan-challenger.test.sh lib/tests/subagent-advisor.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
11. Loop and gate suites stay green.
   CHECK: make test suite="lib/tests/loops-light.test.sh lib/tests/loops-heavy.test.sh lib/tests/gates.test.sh lib/tests/contract-verifier.test.sh lib/tests/model-routing.test.sh lib/tests/curated-config-guard.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
12. Not loosened: apart from the changes criteria 1-8 name (criterion 13's file is outside this count), no existing line of the five files is removed or weakened. Exactly 8 lines are removed against 68a4d8b, each an anchor the plan extends or re-wraps (verify-secure-loop.md header line 3 and "otherwise the dev removes the file.", CLAUDE.global.md "then carries one line per run.", verifier.md's two STEP 4 lines "Compare against the contract's `FILE SCOPE`. Report every out-of-scope" / "file. Disposition is NOT your call: …", capitalize-commit.md "3. Report by (rc, mem_hash):" and its two rc 0 templates); GATE 0 and the security gate read as before.
   CHECK: n=$(git diff --numstat 68a4d8b -- lib/verify-secure-loop.md lib/challenge-plan.md CLAUDE.global.md lib/capitalize-commit.md agents/verifier.md | awk '{d+=$2} END{print d+0}'); [ "$n" -eq 8 ] && echo REMOVED_8
   EXPECT: REMOVED_8
   EVIDENCE: MET exit=0 marker-found :: REMOVED_8
13. [gated 2026-11-20] Citer: lib/effort-shift.md § Advisor point 1 says the plan advisor call is skipped with the challenge for a placed decision, citing `lib/challenge-plan.md` § SKIP; the census still resolves every citation.
   CHECK: f=lib/effort-shift.md; grep -q '^   challengers see it (`lib/challenge-plan.md`), at most once per skill run;$' $f && grep -q '^   skipped with the challenge for a placed decision (`lib/challenge-plan.md` § SKIP).$' $f && make test suite=lib/tests/doctrine-citers.test.sh 2>&1 | tail -1 | grep -q 'all suites green' && echo CITER_OK
   EXPECT: CITER_OK
   EVIDENCE: MET exit=0 marker-found :: CITER_OK

## FILE SCOPE
- lib/verify-secure-loop.md
- lib/challenge-plan.md
- CLAUDE.global.md
- lib/capitalize-commit.md
- agents/verifier.md
- lib/effort-shift.md [gated 2026-11-20] (citer of lever 3)
- this contract and .claude/tasks/plans/2026-11-20-done-triage-levers-1413.md (run artifacts)
