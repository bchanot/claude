# PLAN r2.1 — router-keyword-cap (feat C, BLK-032)

Contract: `.claude/tasks/contracts/2026-10-23-router-keyword-cap-0019.md`
Branch: feature/router-keyword-cap (off develop 6168d90)

## r1 → r2 (challenge round 1: correctness FATAL(4), robustness FATAL(5), simplicity CONCERNS(1))

- BLOCKER (correctness 1, robustness 1): r1 capped the prompt slot in
  `wantedModel`; a capped `turnMain` then shadowed a held best-tier
  `runMain` (mainModelSlot order) → a keyword reply inside a /feat run
  dropped main from Fable to opus. CLOSED by changing the mechanism:
  prompt rules write EFFORT-ONLY routes (the `belowRun` pattern,
  register.ts:3060), so the model axis falls through to `runMain` by the
  existing per-axis rule (test `per axis: a model-less sticky never hides
  a turn route tier`). `wantedModel` / `wouldRunHead` are NOT edited.
- MAJOR (robustness 2, correctness 7): r1 failed open when `sessionModel`
  is '' (after /reload-plugins). CLOSED by the same change: an
  effort-only route never names a model, whatever the session model.
- BLOCKER (correctness 2) / MAJOR (robustness 3): r1's one-line swap of
  the probe tests hangs or goes red (the route tool's answer runs the
  probe). CLOSED: per-test rewrites spelled out below.
- MAJOR (all three): tests l.935 and l.1011 (HAIKU sessions) missed.
  CLOSED: named below with their new form.
- MAJOR (robustness 5, correctness 6): derived `orchestrate` on a main
  Agent dispatch still lifted main to Fable. User decision 2026-10-23:
  cap it too, same mechanism (effort-only).
- MINOR (test 5 setup, all three): hold fable with
  `switchTo($, FABLE, OPUS, 'auto')`, as the classifier stand-in test.
- MINOR (correctness 5, 8; robustness 6, 7): edge notes corrected below;
  robustness 7 (auto fallback rewrites sessionModel) is moot, nothing
  reads sessionModel any more for prompt routes.

## r2 → r2.1 (confirmation pass: correctness SOLID, 5 MINOR, all applied)

- l.5636 completions spelled out: `[FABLE, OPUS, FABLE]`.
- `effortRoute` returns `{}` (not undefined) for a phase with no effort,
  so a matched rule still claims the turn and the classifier stays off.
- Derived-dispatch edges added below.
- `mainModelSlot` stays a `function` declaration (oracle reads it).
- A6 types a PLAN keyword and expects `{ model: FABLE, effort: 'xhigh' }`;
  every new test name stays on ONE line even past 80 columns (oracles
  grep it; l.5690 is the precedent).

## Problem

`register.ts` DEFAULTS.prompt (l.295-309): `ultrathink` (floor, phase
escalate), plan keywords (default, phase plan), reflect keywords
(default, phase reflect); all three phases are `tier: best` → fable.
`defaultFromPrompt` (l.3924) writes `turnMain` and `routeFromPrompt`
(l.3937-3943) writes `turnFloor` with the phase's FULL route (tier +
effort), `source: 'prompt'`. `pushOrchestrate` (l.3251) writes the full
`orchestrate` route (`tier: best`), `source: 'derived'`, on every main
Agent dispatch not under a model/skill route. On the `opus` session
(BDR-123) each lifts main to Fable with no skill row involved.

## Approach

1. register.ts — one helper next to `phaseRoute` (l.352):
   ```ts
   /** A phase's effort alone: a route that never moves main's model. */
   function effortRoute(cfg: Config, phase: string): Route | undefined {
     const route = phaseRoute(cfg, phase)
     if (route === undefined) return undefined
     return route.effort === undefined ? {} : { effort: route.effort }
   }
   ```
2. Use it at the three writers, replacing `phaseRoute(...)` +
   `{ ...route }`:
   - `defaultFromPrompt` (l.3926-3928): `effortRoute(st.cfg, rule.phase)`;
   - `routeFromPrompt` floor (l.3940-3942): `effortRoute(st.cfg,
     floor.phase)`;
   - `pushOrchestrate` (l.3253-3257): `effortRoute(st.cfg,
     'orchestrate')`.
   Phase names, sources, labels, precedence: unchanged. The effort path
   (`mainEffort` l.1663) reads `route.effort` only, so efforts are
   unchanged; only the model axis changes.
3. Dead code: no floor route carries a model any more (`turnFloor` is
   written only by `floorFromPrompt`/`endMainTurn` from prompt rules;
   `PromptRule` has no `model` field). In `mainModelSlot` (l.1385-1397)
   drop `st.turnFloor` from the slot list and the classifier-vs-floor
   branch; the function becomes `[userMain, turnMain, runMain].find(...)`,
   kept as a `function` declaration.
   Update its doc comment (no "floor's own model").
4. Comments: DEFAULTS comment above `prompt:` (l.293-294): "Rules set the
   turn's effort only, never a model." `pushOrchestrate` doc: "the turn's
   effort becomes orchestrate's; the model stays where it is (a held run
   keeps its model)." Keep 80 columns.
5. lib/effort-shift.md "Limits", new bullet after the classifier one:
   ```
   - Keyword prompt rules (`plan|design|architecture…`,
     `why|review|audit…`), `ultrathink` and a background agent
     dispatch (derived `orchestrate`) set the turn's effort only, never
     a model above the session model: Fable on main comes only from a
     skill row, the `route` tool or a typed `/route`.
   ```
   (wording: "never a model above the session model" is the contract
   oracle string; effort-only routes name no model at all, which
   satisfies it.)

## Out of scope (unchanged on purpose)

- Route tool (`model`), skill rows (`skill`/`run`), sticky `/route`
  (`user`): the sanctioned Fable paths (BDR-123).
- Classifier: unchanged (its ceiling in `wantedModel`/`wouldRunHead`
  stays as is; it never runs under a held route).
- `userMovedEffort` (l.3501): classifier-only, unchanged.
- README.md / USAGE.md / CHANGELOG: STEP 6 doc-sync (README l.142 says
  "an `ultrathink` floor in the same turn keeps its own model": stale
  after this change, doc-sync must catch it).

## Edge cases (decided)

- Keyword reply inside a best-tier run: effort from the keyword, model
  from `runMain` (Fable). New test.
- `sessionModel` '' (after /reload-plugins): no lift, the route names no
  model. New test.
- Fable session (old setting): keyword turns start on fable and stay
  there (cur = session); efforts unchanged.
- Haiku session: a keyword or `ultrathink` never moves main off haiku;
  `planStep` strips effort on haiku (l.3572-3574), so they are no-ops.
  Accepted (never above the session model).
- Session model held down (e.g. opus outage on an opus session): a
  keyword turn follows `leaveDown(cur, undefined)` like any plain turn
  (→ sonnet), where it used to reach fable. Accepted: same as a plain
  prompt; the route tool or a skill row still reach fable.
- Fable held + keyword: the prompt route names no tier, `heldHead`
  (l.1565) is undefined → no stand-in notch. On a fable session whose
  fable is dead (`probe: a session model that never answers…`, l.5690)
  the keyword turn lands on opus at xhigh, no longer max.
- Mid-turn `ultrathink` after a classifier demotion in the same turn:
  the floor names no model, so the guess's model holds for the rest of
  that turn (sonnet, at max); the pending floor carries to the next turn,
  which starts on the session model. This AMENDS BDR-115 amendment
  2026-10-13 "ultrathink floor model beats guess" (recorded at
  CAPITALIZE).
- Derived orchestrate outside a run on the opus session: main stays on
  opus at orchestrate's effort (medium). Inside a held run: the run's
  model (Fable). After the pop nothing to restore on the model axis.
- Derived dispatch after a classifier demotion in the same turn: main
  orchestrates on the demoted model (`turnModel`, e.g. sonnet) for the
  rest of the turn, where develop lifted it to fable; spawned agents are
  still pinned to the session model by `sessionPin` (l.3184). Accepted.
- Derived dispatch with fable held: no stand-in notch (no tier named).
  Accepted.
- A phase with no effort (machine config): the rule writes an empty
  route `{}`, still claiming the turn (classifier stays off).
- `turnModel` (sticky per turn) is only set when the router moved main;
  effort-only routes never move it, so no sticky fable after a dispatch.

## Tests (mods/model-router/hooks/register.test.ts)

A. New block `// ---- keyword cap: prompt rules and dispatches set effort only`,
   each test asserting the step's `{ model, effort }`:
   1. `keyword cap: a plan keyword on an opus session stays on opus at xhigh`
      — `bootRig($, on, OPUS)`, typed `plan the billing migration`,
      `stepOn($, rig, OPUS)` → `{ model: OPUS, effort: 'xhigh' }`.
   2. `keyword cap: a reflect keyword on an opus session stays on opus at high`
      — typed `why does the cache miss` → `{ model: OPUS, effort: 'high' }`.
   3. `keyword cap: ultrathink on an opus session stays on opus at max`
      — `ultrathink($)` → `{ model: OPUS, effort: 'max' }`.
   4. `keyword cap: a route tool call after a keyword still lifts to fable`
      — typed plan keyword, `planRoute($)`, step → model FABLE.
   5. `keyword cap: a held fable gives no stand-in notch to a capped keyword`
      — `bootRig($, on, OPUS, 1000, world)` with `newWorld()`,
      `switchTo($, FABLE, OPUS, 'auto')` (marks fable down, no probe),
      typed plan keyword, step on OPUS → `{ model: OPUS, effort: 'xhigh' }`,
      `world.completions` contains no FABLE.
   6. `keyword cap: a keyword inside a held best-tier run keeps the run on fable`
      — opus session; hold a best-tier run slot the way the existing
      `run slot:` tests do (l.1159-1230: typed rowed best-tier skill +
      Skill call), `endTurn($)`, typed `plan the next step`, step on
      OPUS → `{ model: FABLE, effort: 'xhigh' }`.
   7. `keyword cap: an unknown session model never lets a keyword lift main`
      — `bootRig($, on, '')` (session.model answers ''), typed plan
      keyword, `stepOn($, rig, OPUS)` → model OPUS.
   8. `keyword cap: a dispatch outside a run keeps main on the session model`
      — opus session, a main background Agent dispatch the way the
      existing `derived:` tests do (l.914), step during the dispatch on
      OPUS → `{ model: OPUS, effort: 'medium' }`.

B. Existing tests to rewrite (expectation edits allowed ONLY here, each
   with a one-line comment saying why):
   - l.935 `default rule: planifie sets plan, a later route overrides`:
     boot on FABLE (`bootRig($, on)`), `stepOn($, rig, FABLE)`, expect
     `{ model: FABLE, effort: 'xhigh' }`; rest unchanged.
   - l.1011 `text: show names the model a floor upgrade moves to`:
     the behaviour is gone; replace with `text: show names no model move
     for an ultrathink floor` — `bootRig($, on, OPUS)`, ultrathink, the
     main line contains `floor max` and not `(upgrade)` nor FABLE.
   - l.5300 `classify: a mid-turn ultrathink floor still reaches fable max`:
     rename `classify: a mid-turn ultrathink floor raises effort only`,
     expect `{ model: SONNET, effort: 'max' }`.
   - l.5564 `probe: a fable that never answers lands the plan step on opus`:
     `await pastProbe(rig, planRoute($))` in place of the typed keyword,
     then `await runStep($, { ...highStep(), model: OPUS })`; `seen`
     and the `down:` line unchanged; `completions` → `[FABLE, OPUS]`
     (fable probed by the route call, opus by the step).
   - l.5597 `probe: a lapsed hold probes again and holds longer`:
     `await pastProbe(rig, planRoute($))` per loop turn in place of the
     typed keyword; expectations unchanged if they hold (derive: route
     probes FABLE, first step probes OPUS, second turn probes FABLE).
   - l.5636 `probe: a failure during the flight keeps the target unverified`:
     start `const call = planRoute($)` (in flight on the gated probe),
     `await rig.clock.settle()`, `switchTo($, FABLE, OPUS, 'auto')`,
     `open()`, `await call`, then the step; after the 15 min advance a
     second `planRoute($)` + step. Invariant asserted: FABLE appears
     twice in `completions` (still unverified after the in-flight
     failure): `completions` → `[FABLE, OPUS, FABLE]` (route probe
     fails in flight, re-decision lands on opus unprobed, the step
     probes opus, the second route probes fable); `seen[0]` stays
     `{ model: OPUS, effort: 'max' }`.
   - l.5690 `probe: a session model that never answers leaves for opus on the first step`:
     effort `max` → `xhigh` (a keyword names no tier: no stand-in notch).
   - Any OTHER test the suite turns red: if its subject is a model lift
     by a keyword, `ultrathink` or a derived dispatch, rewrite it to the
     effort-only result with a comment; for any other subject → STOP,
     report BLOCKED with the test names and failures.

Suite: `make test suite=lib/tests/mods.test.sh`.

## Disposition (memory)

- honors BDR-123: Fable on main only through rows, route tool, `/route`;
  closes its keyword-lift known gap and the derived-orchestrate leak.
- honors BDR-115 rule 5 "per axis" and the `belowRun` precedent
  (effort-only route under a run); AMENDS BDR-115 amendment 2026-10-13
  clause "ultrathink floor model beats guess" (edge above).
- honors LRN-218 / BLK-031: probe lands on the decided model, untouched.
- LRN-224: agent rows untouched.
- BLK-032 → resolved at CAPITALIZE; TODO W1-C accepted-by-design (1)
  derived-orchestrate part and (2) keyword part closed.
