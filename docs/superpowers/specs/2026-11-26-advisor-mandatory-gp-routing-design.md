# Design — mandatory advisor and routing of untyped sub-agents

Date: 2026-11-26. Contract:
`.claude/tasks/contracts/2026-11-26-advisor-mandatory-gp-routing-1934.md`
(the user's decisions are recorded there and are closed).

## Goal

Three outcomes, all prose doctrine, no new mechanism:

1. Fable enters every plan reflection through the advisor (BDR-150 intact).
2. The advisor is called for sure wherever it is already allowed, and each
   call leaves a trace of what it changed.
3. Untyped sub-agents stop running execution or writing on opus.

Measured basis (usage report of 2026-11-26, 14 days of transcripts): allowed
sub-agents called in 354 of 388 runs outside one session that never had the
tool; 3 plan revisions (25.2 M weighted tokens) were handed to an opus
general-purpose agent right after a challenge round; 26 SDD workers and 10
plan drafters ran on opus through an explicit `model` param.

## Approach

Reword the rules where they are read today. Rejected: discarding a report
that lacks the advisor line (each retry is a full challenger or verifier
run, and nothing can force a server-tool call); a central rule alone
(opus sub-agents ignored it as an attachment, LRN-303).

## Rules and where each one lives

### R1 — two main-loop advisor calls per challenge phase

`lib/challenge-plan.md`, `lib/effort-shift.md` § Advisor point 1.

- Call on the plan: unchanged, before the first dispatch, with no
  main-loop advisor call since the skill run started.
- Call on the first synthesis (new): after the first pass is synthesized
  and the PLAN re-persisted, when any lens returned a BLOCKER or a MAJOR,
  the main loop calls the advisor on the revised plan and its synthesis
  decisions (accepted, dropped, deferred), before any confirmation
  challenger. All lenses SOLID: no second call.
- No call after the confirmation pass.
- An answer that lands a real flaw revises the PLAN as plain text. The
  advice never enters a challenger brief.
- The placed-decision SKIP still waives the phase's calls. Absent or
  erroring: go on as written. A skill run inside a sub-agent makes neither
  call (row `not called (sub-agent)`).
- The `Advisor:` row of the CHALLENGE SUMMARY keeps its values and now
  covers both calls, naming which one (plan, synthesis) drove each change.
  The 12 callers' row templates do not change.

### R2 — the synthesis is never delegated

`lib/challenge-plan.md` § SYNTHESIZE + RE-THINK, protocol mirror in
`agents/plan-challenger.md`.

Which finding is accepted, dropped or deferred, and the named change that
closes it, are the dispatching loop's own decisions and are never handed to
another agent. Applying changes already decided to a long plan file may be
dispatched as drafting: general-purpose, `model: "sonnet"`, a brief that
lists each decided change.

### R3 — exactly one call for the five allowed sub-agent callers

plan-challenger, verifier, security-auditor, a dispatched analyzer, the
opus code review.

- Agent definitions (`agents/{plan-challenger,verifier,security-auditor,
  analyzer}.md`): "Advisor, when dispatched as a sub-agent: exactly one
  call when the `advisor` tool is listed, at the point each definition already names (its own steps),
  whatever the harness prompt schedules; tool not listed or call erroring
  → proceed, no retry." The existing limits on what advice may do stay.
- Review briefs (ship-feature STEP 6, init-project STEP 10): the sentence
  added to the brief asks for exactly one call and for the effect line.
- `lib/effort-shift.md` § Advisor (sub-agent paragraph), `CLAUDE.global.md`
  (Workflow advisor bullet, SDD standalone line), `hooks/subagent-advisor.sh`
  ("When allowed: exactly one call").
- Executors and every other sub-agent: still never.
- No imperative in capitals: "exactly one call when the tool is listed"
  must not read against "absent or erroring → proceed" (BDR-081).

### R4 — the effect line

One grammar, defined once in `lib/effort-shift.md` § Advisor:
`changed: <what>` | `no change` | `not called (<reason>)`.

- Sub-agents end their report with
  `ADVISOR: changed: <what> | no change | not called (absent | error)`,
  added as the last line of each OUTPUT block. verifier: what = the
  NOT-MET rows it prompted; security-auditor: findings added or raised
  (its PROOF suffix stays); plan-challenger: findings added or sharpened;
  analyzer: what it was sent back to read; code review: stated in the
  brief.
- A report without the line is not a structural failure: the line is for
  the transcript tally, never a gate.
- Main loop: the `ADVISOR` field of feat and bugfix and the `Advisor:`
  lines of a11y, guardrails, ship-feature, init-project, audit-delta, tour
  and release-candidate carry the same grammar, plus the existing
  `skipped (<reason>)` values.

### R5 — hotfix calls on every run

`skills/hotfix/SKILL.md`. A logic fix calls through STEP 1.8 (R1). A
cosmetic fix, whose challenge is skipped, makes one call on the located
fix at that step (already point 4 of § Advisor, now written in the skill).
HOTFIX APPLIED gains an `ADVISOR` field.

### R6 — untyped dispatches carry a model chosen by nature

`lib/model-gate.md` (dispatch tiers), `CLAUDE.global.md` (one rule line,
net-zero line count: the file is at the 320-line guard).

- general-purpose and the other built-ins: `model` always explicit.
- opus: skill-runners and judgment (review, verification, diagnosis).
- sonnet: execution (fixes, HTML mockups), writing, plan drafting or
  prototyping from a closed-decision brief, collection.
- haiku: probes.
- Never fable.
- One named exception: the tour multi-project runner, no model (BDR-084).
- `skills/ship-feature/SKILL.md` STEP 2: a delegated draft or prototype
  of plan tasks is a general-purpose sonnet dispatch with a
  closed-decision brief; design choices stay in the main loop.
- No router change: an explicit `model` param keeps winning.

### R7 — SDD final whole-branch review on sonnet under an orchestrator

`skills/ship-feature/SKILL.md` STEP 4, `skills/init-project/SKILL.md`
(twin), `lib/effort-shift.md` (SDD sentence).

One sentence after the existing sonnet pin: the pin includes SDD's final
whole-branch review, its re-reviews and its fix rounds at any round,
whatever the SDD skill's Model Selection says about the most capable
model; the opus craft review is the orchestrator's own code-review step.
Standalone SDD keeps its opus final review. The vendored SDD text is not
edited (BDR-106).

### R8 — coherence and bookkeeping

- Router note (`mods/model-router/hooks/register.ts` ADVISOR_NOTE and the
  test's NOTE constant): keeps the per-run floor, adds that a challenge
  step makes its own calls per `challenge-plan.md`.
- `lib/challenge-plan.md` header cost line: two main-loop calls per
  challenged plan.
- `lib/effort-shift.md` § Advisor: note that a session opened before the
  `advisorModel` setting made no call in the one case observed
  (2026-11-26, its `advisorModel` read the caller's own model): type
  `/advisor` in it or relaunch it. Worded as an observation.
- `.claude/tasks/TODO.md`: the behavioural check's tripwires rewritten
  for the new rule (exactly one served call per allowed dispatch where
  the tool is listed, counted as `advisor_message` iterations, LRN-301;
  the effect line present; two main-loop calls on a challenged plan with
  a BLOCKER or MAJOR; sonnet callers still 0).

## Unchanged

The three skips (placed decision; feat and bugfix with gates clean on the
first pass; audit-delta and tour with no fix), the stuck rule of
`lib/verify-secure-loop.md`, vendored skills, `routing.json`,
`settings.json`, the tour runner, the verdict grammar lines.

## Tests

- Locks updated before the text (red, then green):
  `lib/tests/subagent-advisor.test.sh` (hook text, agent allowance,
  review brief, CLAUDE.global, effort-shift, challenge-plan rows),
  `model-routing.test.sh`, `loops-light.test.sh`,
  `mods/model-router/hooks/register.test.ts` (NOTE).
- One new single-line lock per new sentence (R1 second call, R2, R4
  grammar, R5 field, R6 rule and exception, R7 sentence, R8 session
  note). Locks are exact single-line strings (LRN-166): every locked
  sentence sits on one line in its file.
- Absence lock with a positive control: no "at most once" or "one call
  allowed" for the five callers, checked on text with newlines joined
  (two carriers split the phrase over two lines today).
- `make test` green, shellcheck clean on the hook and its suite,
  `CLAUDE.global.md` at 320 lines or fewer.

## Tasks (each one commits a rule with all its citers, BDR-100)

1. R3 + R4 for sub-agents: agents, hook, review briefs, effort-shift
   sub-agent paragraph and grammar, CLAUDE.global advisor bullet and SDD
   line, tests.
2. R1 + R2 + R5 + main-loop half of R4 + router note: challenge-plan,
   effort-shift point 1, plan-challenger mirror, hotfix, feat, bugfix, the
   seven `Advisor:` end lines, register.ts and its test, tests.
3. R6 + R7: model-gate, CLAUDE.global rule line, ship-feature and
   init-project, effort-shift SDD sentence, tests.
4. R8 leftovers: session note, TODO tripwires.

Tasks 1 and 3 both edit `CLAUDE.global.md` and `lib/effort-shift.md`:
they run in sequence.

## Risks

- "Exactly one" is checked only after the fact, by a transcript tally.
- Deployment is live through symlinks: once the branch is checked out,
  this run's own challengers and gates run under the new text.
- A typo hotfix pays one main-loop advisor call.
- A reworded sentence can redden an exact-string lock elsewhere: each
  task greps the old phrase across `lib/tests`, skills, agents, lib and
  docs before committing.
- Public docs (README, USAGE, ARCHITECTURE, CHANGELOG) keep the old
  wording until the doc-sync step.
