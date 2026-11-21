# CONTRACT — levers-followup
- date: 2026-11-20 | flow: feat | branch: feature/levers-followup
- status: active
- run-base: 23c580249e20d3b185bd9278726b024b5729132b

## REQUEST (verbatim — IMMUTABLE)
Suivi des six leviers (TODO "NEXT: follow-up /feat", décidé par l'utilisateur le 2026-11-20 en pass B et au GATE 2 du run done-triage-levers) : (a) lib/contract-interview.md STEP 4 fait faire le dry run + `- run-base:` à tout flow qui écrit un contrat ; (b) skills/ship-feature STEP 6 et skills/init-project STEP 10 : "Fix all CRITICAL" lié au levier 1 (rouvert seulement sur preuve reproductible) ; lib/capitalize-commit.md : `--end-of-options` + check `^[0-9a-f]{7,40}$` sur run_base ; agents/verifier.md STEP 4 : lignes `[gated]` en scope seulement sur un contrat non suivi. 5 fichiers.
(User, same turn: "d'accord fais les dans l'ordre alors sans t'arrêter".)

## CLARIFICATIONS
none — request complete (each item is a placement of a decision taken 2026-11-20 in the done-triage-levers run, contract .claude/tasks/contracts/2026-11-20-done-triage-levers-1413.md)

## ACCEPTANCE CRITERIA
1. (a) lib/contract-interview.md STEP 4: a paragraph after the print line says that before the first dev-step dispatch, after the flow's branch step, a contract with `CHECK:` lines gets its dry run (records `- run-base:`, the run's start SHA for the TODO count; `gates.sh run` on a `mktemp -d` copy from the project root, citing § BEFORE THE FIRST DISPATCH), in every flow that writes such a contract, challenged or not; a value written before the branch step is replaced by `git rev-parse HEAD` right after it; a flow's own positive control on the unfixed tree counts as the `gates.sh` half and `- run-base:` is still recorded. The template carries no run-base placeholder.
   CHECK: f=lib/contract-interview.md; s=$(awk '/^## STEP 4/{p=1;next} /^## MID-RUN/{p=0} p' $f); grep -q '^Before the first dev-step dispatch, after the flow.s branch step, a$' <<<"$s" && grep -q '^`- run-base:` (the run.s start SHA, for the TODO count of$' <<<"$s" && grep -q '^root, runs `bash ~/.claude/lib/gates.sh run` on a `mktemp -d` copy of the$' <<<"$s" && grep -q '^contract (`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH). Every$' <<<"$s" && grep -q '^replaced by `git rev-parse HEAD` right after it) and, from the project$' <<<"$s" && grep -q '^`gates.sh` half, and `- run-base:` is still recorded.$' <<<"$s" && [ "$(grep -c 'run-base: <' <<<"$s")" -eq 0 ] && echo CI_OK
   EXPECT: CI_OK
   EVIDENCE: MET exit=0 marker-found :: CI_OK
2. (b) skills/ship-feature/SKILL.md STEP 6 and skills/init-project/SKILL.md STEP 10: "Fix all CRITICAL before proceeding." becomes "Fix every CRITICAL or Important finding that carries reproducible evidence … before proceeding", with the one-attempt-else-MINOR clause, security to the user, citing `lib/verify-secure-loop.md` § DONE and `lib/verify-secure-loop.md` § MINOR triage (both path-prefixed); both RULES lines and the ship-feature loop-back table row say "CRITICAL or Important" with reproducible evidence; no "Fix all CRITICAL" left in either file; ship-feature STEP 4 and init-project STEP 8 carry, right after their `gitflow.sh start` block, a pointer to the contract dry run on that branch.
   CHECK: for f in skills/ship-feature/SKILL.md skills/init-project/SKILL.md; do grep -q '^verdict" (code review, BDR-150). Fix every CRITICAL or Important finding$' $f && grep -q '^command, else it is a MINOR; a security finding goes to the user$' $f && grep -q '^(`lib/verify-secure-loop.md` § DONE;$' $f && grep -q '^`lib/verify-secure-loop.md` § MINOR triage).$' $f && grep -q '^- Fix every CRITICAL or Important review issue that carries$' $f && [ "$(grep -c 'Fix all CRITICAL' $f)" -eq 0 ] && grep -A2 'lib/gitflow.sh" start feature' $f | grep -q '^Then, before the first dispatch, the contract dry run on this branch$' || exit 1; done; grep -q '^  reproducible evidence before proceeding (STEP 6).$' skills/ship-feature/SKILL.md && grep -q '^  reproducible evidence before proceeding (STEP 10).$' skills/init-project/SKILL.md && grep -q '^| STEP 6 — review returns CRITICAL or Important items with reproducible evidence | Loop back' skills/ship-feature/SKILL.md && echo REVIEW_OK
   EXPECT: REVIEW_OK
   EVIDENCE: MET exit=0 marker-found :: REVIEW_OK
3. lib/capitalize-commit.md: the snippet guards `run_base` with `[[ $run_base =~ ^[0-9a-f]{7,40}$ ]]` and passes it after `--end-of-options`; the prose says a non-SHA `run_base` gives `TODO n/a`. Run on a fixture (one open item closed, a closed one edited, two added): a full SHA and a 7-char SHA give `TODO +2 / -1` (also from a subdirectory after a commit); `HEAD`, `--output=x` and an unknown SHA give `TODO n/a`, and `--output=x` writes no file.
   CHECK: f=$PWD/lib/capitalize-commit.md; grep -q '^   `run_base` that is not a 7-40 hex SHA, or a failing `git diff` →$' $f && t=$(mktemp -d) && s=$t/s.sh && awk '/^       if \[\[ \$run_base =~/{p=1} p{print} p&&/todo="TODO n\/a"; fi$/{exit}' $f | sed 's/^       //' > $s && [ "$(wc -l < $s)" -eq 7 ] && grep -q -- '--end-of-options "$run_base"' $s && mkdir $t/r && cd $t/r && git init -q && mkdir -p .claude/tasks sub && printf -- '- [ ] a\n- [ ] b\n- [x] old\n' > .claude/tasks/TODO.md && git add . && git -c user.email=t@t -c user.name=t commit -qm base && b=$(git rev-parse HEAD) && b7=$(git rev-parse --short=7 HEAD) && printf -- '- [x] a DONE\n- [ ] b\n- [x] old edited\n- [ ] c\n- [ ] d\n' > .claude/tasks/TODO.md && r1=$(run_base=$b bash -c ". $s; echo \"\$todo\"") && r2=$(run_base=$b7 bash -c ". $s; echo \"\$todo\"") && r3=$(run_base=HEAD bash -c ". $s; echo \"\$todo\"") && r4=$(run_base=--output=x bash -c ". $s; echo \"\$todo\"") && r5=$(run_base=0123456789abcdef0123456789abcdef01234567 bash -c ". $s; echo \"\$todo\"") && git add . && git -c user.email=t@t -c user.name=t commit -qm run && r6=$(cd sub && run_base=$b bash -c ". $s; echo \"\$todo\"") && [ ! -e x ] && [ ! -e sub/x ] && echo "R1=$r1 R2=$r2 R3=$r3 R4=$r4 R5=$r5 R6=$r6"
   EXPECT: R1=TODO +2 / -1 R2=TODO +2 / -1 R3=TODO n/a R4=TODO n/a R5=TODO n/a R6=TODO +2 / -1
   EVIDENCE: MET exit=0 marker-found :: R1=TODO +2 / -1 R2=TODO +2 / -1 R3=TODO n/a R4=TODO n/a R5=TODO n/a R6=TODO +2 / -1
4. agents/verifier.md: STEP 4 keeps on a tracked contract only `EVIDENCE:` lines and the `- run-base:` line in scope; a `[gated]` entry added to a tracked contract goes on a new `GATED:` OUTPUT line, never in the out-of-scope count; the ORCHESTRATOR PROTOCOL routes `GATED:` entries to the orchestrator (check against the plan's decisions or ask the human, never a dev task or ECARTS gap, unconfirmable entry removed by the orchestrator and named in the final report).
   CHECK: f=agents/verifier.md; s=$(awk '/^## STEP 4/{p=1;next} /^## /{p=0} p' $f); grep -q '^untracked or added, else only its `EVIDENCE:` lines and `- run-base:` line.$' <<<"$s" && grep -q '^A `\[gated\]` entry added to a tracked contract goes on the `GATED:` line,$' <<<"$s" && grep -q '^never in the out-of-scope count: nothing in the diff proves who wrote it.$' <<<"$s" && grep -A1 '^SCOPE: in-scope <n> files; out-of-scope: <list | none>$' $f | grep -q '^GATED: <`\[gated\]` entries added to a tracked contract | none>$' && grep -q '^  - `GATED:` entries (any verdict) → the orchestrator checks each against$' $f && grep -q '^    never an ECARTS gap. An entry nobody can confirm is removed by the$' $f && echo VF_OK
   EXPECT: VF_OK
   EVIDENCE: NOT-MET exit=1 (nonzero) :: 
5. No em-dash in any line this run adds, except the pre-existing ship-feature table row it extends; exactly the four files of criteria 1-3 change (7 removed lines), agents/verifier.md untouched (criterion 4 abandoned).
   CHECK: F="lib/contract-interview.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md lib/capitalize-commit.md"; n=$(git diff -U0 23c580249e20d3b185bd9278726b024b5729132b -- $F | grep '^+[^+]' | grep -v '^+| STEP 6 — review returns CRITICAL or Important items' | grep -c '—'); [ "$n" -eq 0 ] && [ "$(git diff --name-only 23c580249e20d3b185bd9278726b024b5729132b -- $F | wc -l)" -eq 4 ] && [ "$(git diff --quiet 23c580249e20d3b185bd9278726b024b5729132b -- agents/verifier.md; echo $?)" -eq 0 ] && [ "$(git diff --numstat 23c580249e20d3b185bd9278726b024b5729132b -- $F | awk '{d+=$2} END{print d+0}')" -eq 7 ] && echo SCOPE5_OK
   EXPECT: SCOPE5_OK
   EVIDENCE: MET exit=0 marker-found :: SCOPE5_OK
6. Locking suites stay green (doctrine census incl. the new § DONE / § MINOR triage citations, challenge wiring, advisor locks, effort routing).
   CHECK: make test suite="lib/tests/doctrine-citers.test.sh lib/tests/plan-challenger.test.sh lib/tests/subagent-advisor.test.sh lib/tests/effort-routing.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
7. Loop and gate suites stay green.
   CHECK: make test suite="lib/tests/loops-light.test.sh lib/tests/loops-heavy.test.sh lib/tests/model-routing.test.sh lib/tests/contract-verifier.test.sh lib/tests/gates.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
8. Not loosened (judgement): apart from the changes criteria 1-4 name, nothing in the five files is removed or weakened; the review CRITICAL rule only adds the evidence condition and the security route already decided in lever 1/2.

ABANDON: 4 deferred 2026-11-20 by the orchestrator after the r3 confirmation challenge: a `[gated]`-on-tracked-contract rule only bites init-project (contract root-committed by gitflow init), and its routing must live at the GATE 1 act sites (lib/verify-secure-loop.md GATE 1, skills/init-project STEP 9), outside this run's files; every in-verifier version added mechanism (GATED line, re-verify on removal, structural-failure rule, diff reference point). Handoff: TODO line for the user's decision (fix at those act sites, or keep today's behaviour and record the limit).

## FILE SCOPE
- lib/contract-interview.md
- skills/ship-feature/SKILL.md
- skills/init-project/SKILL.md
- lib/capitalize-commit.md
- agents/verifier.md (criterion 4, abandoned: stays untouched)
- this contract and .claude/tasks/plans/2026-11-20-levers-followup-1725.md (run artifacts)
