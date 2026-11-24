# CONTRACT — advisor note per former-Fable skill run
- run-base: 4b8ed29736d0975544c0348f00204eb7bae7f92f

## REQUEST (verbatim)
User 2026-11-23: "il faut appeler l'adviser partout ou initialement on avait
le routage ver fable aussi." Answers (same day): scope = "Un appel par run";
skips = "Les garder"; sub-agents = "Rien ne change".

## CLARIFICATIONS
- [gated] One main-loop advisor call per run of a skill whose routing.json
  row phase is `plan` or `reflect` (the rows that lifted main to Fable before
  BDR-150; rows unchanged since 24b0f35^). A call the skill already places
  counts. Existing skips stay. Sub-agent advisor scope unchanged.
- [gated] Plan r4 § Rule 1-4: one call on the settled plan/diagnosis/fix;
  a point 1-3 call counts; only challenge-plan § SKIP and point 3 skips
  waive it (other challenge guards get the call: cosmetic /hotfix gains
  one, as told to the user); nested under a plan/reflect run: no call.
  Row phase read from the merged config.
- [internal] Carrier: the model-router mod prepends one note line to the
  skill body (skill.prompt) for main-loop loads only (main Skill tool call or
  user-typed slash), never sub-agent loads or preloads.

- [gated 2026-11-24] Deferred point "behavioural tally (calls per run
  counted in transcripts)": keep. Not a criterion of this run; done at the
  one-week re-measure with the same transcript count. User: "tu peux lancer".

## ACCEPTANCE CRITERIA
1. A main-loop load of a plan/reflect row (Skill tool call without agentId,
   or a user-typed slash) gets ADVISOR_NOTE prepended to the skill text;
   prefixed rows (`pack-design:frontend-design`) too. Mod suite green.
   CHECK: cd /home/bchanot/Documents/claude && timeout 300 claude plugin test mods/model-router 2>&1 | grep -cE '^ *0 fail$'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
2. No note for: a sub-agent Skill load (agentId set), a preload (no Skill
   call, not typed), a row of another phase (capitalize), an unrowed skill,
   the mod off. Each case has a test whose name starts "advisor note".
   CHECK: n=$(grep -c "test('advisor note:" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts); [ "$n" -ge 11 ] && echo enough || echo "only $n"
   EXPECT: enough
   EVIDENCE: MET exit=0 marker-found :: enough
3. lib/effort-shift.md § Advisor gains point 4 `**Per run.**`.
   CHECK: grep -c '^4\. \*\*Per run\.\*\*' /home/bchanot/Documents/claude/lib/effort-shift.md
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
4. `make test` green except the baseline memory-feedback suite (bun not on PATH).
   CHECK: cd /home/bchanot/Documents/claude && make test 2>&1 | grep 'suite(s) red'
   EXPECT: 1 suite(s) red: lib/tests/memory-feedback.test.sh
   EVIDENCE: MET exit=0 marker-found :: 1 suite(s) red: lib/tests/memory-feedback.test.sh
5. CLAUDE.global.md and routing.json untouched by this run (routing.json's
   working-tree `"close": "apply"` predates the run: live mod dialog).
   CHECK: cd /home/bchanot/Documents/claude && git diff --quiet 4b8ed29..HEAD -- CLAUDE.global.md mods/model-router/routing.json && git diff --quiet -- CLAUDE.global.md && echo untouched
   EXPECT: untouched
   EVIDENCE: MET exit=0 marker-found :: untouched
6. Live precondition before any merge proposal (not a test): after the user
   runs /reload-plugins, with a background sub-agent live (typed fallback
   off), a main-loop Skill load of one reflect row and one pack row shows
   the note; until then reported "not verified live".

## FILE SCOPE
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
- lib/effort-shift.md
