# CONTRACT — deferred-citers
- date: 2026-11-21 | flow: feat | branch: bugfix/doctor-model-default
- status: active
- run-base: 828f3284dcca3f3949c88b9613e29123be1401da

## REQUEST (verbatim — IMMUTABLE)
Patch des citers de la règle [deferred] (ca65852), décision utilisateur 2026-11-21 "Patch now" : skills/feat/SKILL.md:135-136, skills/bugfix/SKILL.md:140-141, skills/hotfix/SKILL.md:102-109 repointés vers lib/challenge-plan.md § OUTPUT (un point [deferred] arrête le run une fois à la fin de l'étape de challenge : garder / couper / rouvrir ; /hotfix pose la question lui-même ; l'escalade hotfix → /bugfix reste pour un BLOCKER non différé qui montre le fix faux).

## CLARIFICATIONS
none — request complete. Challenge: skipped (placed decision: deferred-stop rule ca65852, challenged in its run and answered by the user 2026-11-21).

## ACCEPTANCE CRITERIA
1. feat and bugfix challenge steps stop once on any `[deferred]` point (keep / cut / reopen) citing `lib/challenge-plan.md` § OUTPUT; the old "surfacing any deferred BLOCKER in the STEP 1 pass B batch" and "folding any deferred BLOCKER into the STEP 3 approval gate" are gone.
   CHECK: for f in skills/feat/SKILL.md skills/bugfix/SKILL.md; do grep -q '^`\[deferred\]` point (keep / cut / reopen, `lib/challenge-plan.md` § OUTPUT).$' $f || exit 1; done; [ "$(grep -c 'pass B batch\|STEP 3 approval gate' skills/feat/SKILL.md skills/bugfix/SKILL.md | awk -F: '{s+=$2} END{print s}')" -eq 0 ] && echo FB_OK
   EXPECT: FB_OK
   EVIDENCE: MET exit=0 marker-found :: FB_OK
2. hotfix STEP 1.8: a `[deferred]` point is asked by /hotfix itself (keep / cut / reopen, § OUTPUT); the BLOCKER-shows-the-fix-wrong escalation to /bugfix stays.
   CHECK: f=skills/hotfix/SKILL.md; grep -q '^A `\[deferred\]` point: /hotfix asks keep / cut / reopen itself$' $f && grep -q '^(`lib/challenge-plan.md` § OUTPUT). A BLOCKER that shows the fix is wrong' $f && grep -q 'escalate to `/bugfix`' $f && echo HF_OK
   EXPECT: HF_OK
   EVIDENCE: MET exit=0 marker-found :: HF_OK
3. Only the three skill files change (5 removed lines) and the locking suites stay green (census resolves the three new § OUTPUT citations).
   CHECK: [ "$(git diff --name-only 828f3284dcca3f3949c88b9613e29123be1401da -- skills | wc -l)" -eq 3 ] && [ "$(git diff --numstat 828f3284dcca3f3949c88b9613e29123be1401da -- skills | awk '{d+=$2} END{print d+0}')" -eq 5 ] && make test suite="lib/tests/doctrine-citers.test.sh lib/tests/plan-challenger.test.sh lib/tests/loops-light.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green

## FILE SCOPE
- skills/feat/SKILL.md
- skills/bugfix/SKILL.md
- skills/hotfix/SKILL.md
- this contract and .claude/tasks/plans/2026-11-21-deferred-citers-2108.md (run artifacts)
