# PLAN — advisor note per former-Fable skill run (r4)

CONTRACT: .claude/tasks/contracts/2026-11-23-advisor-skill-note-1840.md

## Rule (the same words in the note and in point 4)
1. A main-loop run of a skill whose row phase (merged config `st.cfg`) is
   `plan` or `reflect` makes one advisor call on its settled plan,
   diagnosis or fix, before it executes or reports (at load when the run
   starts from a settled plan).
2. A call made this run at point 1, 2 or 3 of § Advisor counts as this one.
3. Only two kinds of skip waive it: `lib/challenge-plan.md` § SKIP (placed
   decision) and point 3's named skips. Any other skip of a challenge step
   (hotfix's cosmetic guard, harden or web-validate MODE=audit, seo or geo
   conservative mode, code-clean's clean stop) does not waive it: the call
   is made where that step would have run.
4. A skill loaded inside a plan/reflect skill's run makes no call of its
   own (the outer run owns it); under a skill of another row or no row, it
   calls.

## Note text (exact, one source line, then "\n\n", prepended)
"Advisor (`~/.claude/lib/effort-shift.md` § Advisor, **Per run**): when the
`advisor` tool is listed, this skill run makes one main-loop advisor call on
its settled plan, diagnosis or fix, before it executes or reports. A call
this run already made at an advisor point counts. Only
`~/.claude/lib/challenge-plan.md` § SKIP and the end-of-run skips waive it;
any other skipped challenge step still gets the call where it would have
run. Loaded inside another plan/reflect skill's run: no call of its own."

## Files
- [ ] mods/model-router/hooks/register.ts
  - Consts near REFERENCE_SKILLS: `ADVISOR_NOTE` (text above + "\n\n"),
    `ADVISOR_PHASES = new Set(['plan', 'reflect'])`.
  - State field `advisorSkill: string | null`, init null in the state
    factory (~line 1028), comment "main-loop Skill load awaiting its note".
  - Helper `advisorDue(st, skill): boolean` = `skillRow(st, skill)?.phase`
    in ADVISOR_PHASES (row-phase test only; `st.off` is handled by the
    existing early returns).
  - registerSkills tool.call (~4627): decide due-ness with the SAME name
    `onSkillLoad` routes by. Immediately before `const out = await next(e)`
    (after tierAsk), if `e.agentId === undefined && advisorDue(st, skill)`
    set `st.advisorSkill = skill`. In `finally`: `if (e.agentId ===
    undefined) st.advisorSkill = null`. No name normalization (no
    skillKey): AC6 live check decides whether names ever differ.
  - registerSkills skill.prompt (~4650):
    - In-call branch (`st.skillCalls > 0`, mod on): `const out = await
      next(e)`; if `st.advisorSkill === e.skill` → set `st.advisorSkill =
      null` and return `{ text: ADVISOR_NOTE + out.text }`; else `out`.
    - Typed branch: evaluate `typed && advisorDue(st, e.skill)` AFTER
      `confirmSkill` returns (a first-use move counts), then wrap the
      `next(e)` result the same way.
  - Accepted gaps (state them in a code comment at the marker): a same-name
    sub-agent load while a main Skill call is in flight takes the note (and
    the main load loses it); a typed slash whose prompt lands while any
    Skill call is in flight loses its note; two concurrent main Skill calls
    keep only the last marker. skill.prompt carries no agentId.
- [ ] mods/model-router/hooks/register.test.ts — `describe('advisor note')`
  with tests titled `test('advisor note: …'`. Local rig: a world built with
  `newWorld({ edit: f => Object.assign(f.skills, { 'writing-plans': 'plan',
  'pack-design:frontend-design': 'reflect', capitalize: 'apply' }) })`
  (adapt to the fixture API), and a bottom Skill tool modeled on the test
  at ~line 1613 that calls `$.skill.prompt({ skill: e.skill, text: 'BODY' })`
  and returns its text in the result so the test can read it. Assert with a
  literal prefix duplicated in the test: `'Advisor (`~/.claude/lib/effort-
  shift.md` § Advisor, **Per run**)'` (no export from register.ts).
  Cases (11): main `feat` → note; main `writing-plans` → note; main
  `pack-design:frontend-design` → note; agentId set → no note; preload
  (skill.prompt, no Skill call, not typed, a sub-agent spawned so the typed
  fallback is off) → no note; `capitalize` (apply) → no note; `status`
  (mechanical) → no note; unrowed skill → no note; `/route off` → no note;
  typed `/feat` → note; sub-agent Skill call ending during a main call does
  not clear the main marker (note still on the main load).
- [ ] lib/effort-shift.md § Advisor — after item 3 (ends "…a new run."):
  "4. **Per run.** A main-loop run of a skill whose model-router row is
     `plan` or `reflect` (the rows that put main on Fable before BDR-150)
     makes one call on its settled plan, diagnosis or fix, before it
     executes or reports (at load when it starts from a settled plan). A
     call this run made at point 1, 2 or 3 counts as this one. Only
     `lib/challenge-plan.md` § SKIP and point 3's skips waive it; any other
     skipped challenge step (hotfix's cosmetic guard, an audit-only or
     conservative mode, a clean stop) gets the call where that step would
     have run. A skill loaded inside a plan/reflect skill's run makes none;
     under another row or none, it calls. The model-router mod prepends
     this rule to the skill body on a main-loop load, never on a
     sub-agent's."

## Edge cases
- Mod off → no note (existing early returns). Hook failure → passthrough.
- Nested loads under a plan/reflect run still carry the note; its last
  sentence says no call.
- routing.json dirty before the run: never edited or staged by this run.

## Disposition
- honors BDR-150 (a call point, not a route); LRN-303 (body carrier over
  Skill-result `context`, an attachment channel LRN-303 found ignored;
  price = the marker and its accepted gaps).
- honors user picks 2026-11-23: one call per run; the advisor-section skips
  kept (§ SKIP, point 3); sub-agent scope unchanged; cosmetic /hotfix gains
  its call. Challenge-step guards that never were advisor skips now get the
  call (that is what "one per run" buys).
- CLAUDE.global.md untouched. README/USAGE/CHANGELOG via STEP 6.
- [deferred] behavioural tally (calls per run counted in transcripts):
  needs real runs after reload; proposed = the one-week re-measure already
  promised to the user, run with the same transcript count.
