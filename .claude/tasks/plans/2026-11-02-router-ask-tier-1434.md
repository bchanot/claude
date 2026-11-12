# /feat router-ask-tier — PLAN r3 (2026-11-02)

r3 after the confirmation pass on r2 (correctness CONCERNS(6), no BLOCKER).
Named changes: inheritance of a choice only between slots of the SAME tier
and only for helper (non-typed) writes, so a typed run is a new span and a
work route never inherits 'big'; `tierAsk` writes on the real `st` and
reads a probe view (the `/route` path); "Opus instead" is offered only when
opus itself is up, sonnet is the mid-span fallback only; a stored per-type
spawn answer is applied BEFORE any ask guard and the spawn dialog holds
`asking`; `isStandIn` is false on a 'big' span; the pure `cur !== head`
guard runs first; question texts drop the "Routed to" prefix; `tierWord`
names a 'big' span; `flagCommand` takes one descriptor; the "first use"
comment block and the `asking` field comment are the ones edited; three
key-order assertions; the held-head lift (fable held at the route event,
hold lapses later) is a residual put to the gate (pass B F).

r2 after 3 lenses on r1 (correctness FATAL(6), robustness FATAL(6),
simplicity CONCERNS(4)). Unanimous BLOCKER: r1 wrote the answer on
`turnMain` after `armTypedSkill` had already derived `runMain`, so "Opus
instead" lasted one turn and a run re-asked. r2 changes: the choice is a
TIER NAME stamped on every slot the event armed (turn + run), resolution
goes through `resolveName` (no stand-in rewrite), the ask reads the real
decision (`snapshot` / `decideMain`) instead of rebuilding it, a 4th call
site covers model-loaded best-tier skills, spawns remember one answer per
agent type per session, the "instead" option is offered only when its
model is up and never falls back onto the head, headless is guarded by
`$.session.surfaces()`, `/route <phase>` assigns after the answer.
Pass-B choices are listed at the end; defaults taken are marked (default).

FEAT: model-router asks before a route lifts the main loop, or sends a rowed
spawn, onto Fable — rule 7, 4 files (register.ts, register.test.ts,
routing.json, USAGE.md), README/CHANGELOG through doc-sync.
Contract: `.claude/tasks/contracts/2026-11-02-router-ask-tier-1434.md`.

## Facts (verified in `mods/model-router/hooks/register.ts` at develop 3cc4e0d)
- Tiers (DEFAULT_CONFIG ~283): `best` = [fable, opus, sonnet], `big` =
  [opus, fable, sonnet]. "Resolved model sits in that tier" = resolves to the
  HEAD of the `askTier` tier (`tiers.best[0]` → `models.fable`).
- Main-loop route writers: `routeMainBySkill` (~3485; typed via
  `armTypedSkill` 3537 in skill.prompt 4254, BEFORE `confirmSkill` 4259;
  model-loaded via `onSkillLoad` 3502 in tool.call Skill 4242), `applyRoute`
  (route tool, ~3395), `setUserRoute` (`/route`, 2019; `/route` is
  `immediate: true`, 3370: it runs mid-turn). `mainModelSlot` (1466) =
  userMain ?? turnMain ?? runMain; `wantedModel` (1547) resolves its tier;
  `decideMain` (1445) is the ONE decision "used by the step and every text";
  `snapshot` (1922) = `decideFor` on `turnModel ?? sessionModel`.
- `endMainTurn` (4042) nulls turnMain; `userMovedEffort` (3976) nulls it
  mid-turn; `resetSession` (1043) keeps `asking` but NOT `asked`.
- Dialogs render in skill.prompt (T1), tool.call (`confirmPhase`,
  route tool; the Skill tool.call hook is the same hook kind), agent.spawn
  (T2) and command.run (`/model`, LRN-243); never in turn.step (LRN-231).
  `askOr` (2532) → LATER on a rejected ask; the `/model` paths guard first on
  `$.session.surfaces()` empty (2409, 2472); `askStep` (2684) maps Later /
  unrecognised / headless. `pickerDialog` checks `$.session.id()` before
  applying a late answer (`stillHere`, ~2452).
- `confirmSkill` (2984) returns early when `confirmFirst` is false, and
  re-runs `routeMainBySkill` (2990) when it is true. `routeSpawn` (2996)
  returns the route from a ternary on `confirmFirst`.
- `resolveName` (1135): a tier skips down aliases then walks the chain; an
  alias/id is explicit and never skipped. `availableIn` (1115).
  `spawnTarget` (3630) → `inTier` picks the first alias not down at or above
  the tier's head; an explicit `e.model` wins; `routeSpawn` already returns
  early for frozen / unrowed / inside spawns.
- `askCommand` (3041) + `writeRouting` (2865) is the `/route ask` writer;
  ROUTING_ORDER (189) is 74 columns: appending `'askTier'` needs a wrap.
- `buildMemory` (790) takes no cfg; callers `assemble` (939) and
  `refreshMemory` (2527). `assemble` logs "routing.json missing; … no asks"
  and uses `emptyMemory()`.
- Prompt rules and the classifier write effort-only routes (BLK-032): they
  never resolve a model, so never ask; the classifier writes only when no
  route is in force (`classifierIdle`), so it never reaches a call site.

## Design
### D1 config, memory, state
- routing.json: `"askTier": "best"` after `"ask": true`. `ROUTING_ORDER`
  gains `'askTier'`: the line is rewrapped as `'phases', 'skills', 'agents',
  'projects', 'confirmed', 'changed',` / `'ask', 'askTier',` (≤ 80 cols).
- `Memory.askTier: unknown` (raw file value, absent = undefined) and
  `Memory.askTierLocal: unknown` (override). `buildMemory` copies both raw,
  no new parameter. `emptyMemory()` → `askTier: false` (no file = no ask,
  matching the "no asks" load log).
- `tierHead(st): string | undefined` — the one reader: value =
  `st.mem.askTierLocal ?? st.mem.askTier`; `undefined` → `'best'` silently;
  `false` → undefined (off); `'best'` → `st.cfg.models[st.cfg.tiers.best[0]]`;
  any other value → `best`. The validation log line `model-router: askTier
  must be "best" or false; read as best` is emitted by `buildMemory`
  through its `log` parameter (live at `assemble`, silent at
  `refreshMemory`), the same way `aboutOf` logs an overlong `about`: once
  per config load, never on the hot path. (Default E: other tier names are
  out of scope — the labels are the user's exact words.)
- `headId(st)` = `st.cfg.models[st.cfg.tiers.best[0]]` (the head whatever
  the key says; used by `insteadName` so a span keeps avoiding fable after
  `/route ask-tier off`).
- `State` gains `tierPaused: boolean` (Stop; `newState` false; NOT in
  `resetSession`'s kept list → /clear re-arms) and `tierSpawn: Map<string,
  Choice>` (agent type → answer; not kept either).
- `Routed.tierChoice?: Choice` where `type Choice = 'best' | 'big'` — the
  TIER the span resolves through: `'best'` = Fable accepted (or Later /
  Stop / headless), `'big'` = Opus instead. Constants `TIER_HEAD = 'Fable'`,
  `TIER_INSTEAD = 'Opus instead (big tier)'`, `TIER_STOP = 'Stop asking this
  session'`, `INSTEAD_TIER = 'big'` next to LATER/KEEP/CHANGE (192).

### D2 resolution of a chosen span
- `wantedModel` (1547): `const name = slot.tierChoice === 'big' &&
  slot.route.tier === BEST ? (insteadName(st) ?? routeName(slot.route)) :
  routeName(slot.route)`. `insteadName(st)` = `availableIn(st,
  tiers.big.filter(a => models[a] !== headId(st)))` → the first non-head
  alias of `big` that is up (opus, else sonnet); `undefined` only when
  nothing but the head is up → the normal tier resolution (the span runs,
  on whatever the breaker leaves; silent: the status line and `show` name
  the model). Otherwise never the head: the model the user declined is not
  the fallback of their refusal.
- Offer rule (one rule everywhere, D3/D5/AC2/AC8/test 11): the `Opus
  instead` option is offered only when `models[tiers.big[0]]` (opus) is not
  down — the label must stay true at answer time; sonnet is only the
  mid-span fallback when opus goes down later.
- Effort: the phase's own (default D). `isStandIn` (1670) gains one guard:
  `mainModelSlot(st)?.tierChoice === 'big'` → false (a chosen opus is not a
  stand-in: no notch, no "stands in for" text). `standInEffort`,
  `standInWord`, `heldHead` otherwise unchanged.
- Inheritance (`applyRoute` 3395 and `routeMainBySkill` 3485 for a
  model-loaded skill, `typed === false` only): the new turnMain copies
  `tierChoice` from the slot it replaces (`st.turnMain`) or else from
  `st.runMain`, ONLY when `prev.route.tier === new.route.tier`. A typed
  rowed skill (`typed === true`) never inherits: it opens a new span, so a
  typed `/bugfix` after an answered `/feat` run asks again, and a work or
  cheap route (`route phase=implement`, `gitflow`) never carries 'big'.
  `routeMainBySkill` copies the turn's `tierChoice` into the run slot it
  derives (the spread does it once the field is on `turn`).
- `tierWord` (1866): a slot with `tierChoice === 'big'` prints `[tier big
  (instead of best)]` so `/route show` names the span's choice.

### D3 when to ask (main loop) — `tierAsk($, st, slot, origin, view = st)`
`st` is the real state (every write: `asking`, `tierPaused`, `logged`);
`view` is the state the decision is read from (`st` everywhere except the
`/route` path, D4.4, where it is the probe copy). Pure cheap guards first,
in this order, all required: `!st.off`; `head = tierHead(st)` defined;
`!st.tierPaused`; `canonical(st.turnModel ?? st.sessionModel) !== head`
(main already on fable: a helper Skill inside a fable run costs nothing);
`st.asking === null`; `slot.tierChoice === undefined`; `slot.route.tier ===
BEST` (an explicit `model` route never asks: `/route model=fable`, `/model`
hand picks; another tier never resolves to the head unless opus is held,
and then the breaker already decided); `slot === mainModelSlot(view)` (a
sticky slot that outranks it decides, not this one). Then the two awaits:
`(await $.session.surfaces()).length > 0` (headless asks nothing, like
`/model`), and `v = await snapshot($, view)`; ask only when
`canonical(v.call.model) === head` (so `mainUpgrade: false`, the cold-read
cap, a window miss or a held head → no question, nothing to decide; the
slot stays unstamped, see pass B F).
- The dialog holds `st.asking = 'tier:main'` (finally null) and records
  `sid = await $.session.id()` first; an answer arriving after `$.session.
  id()` changed (a /clear) is dropped.
- Text (main): `${origin} routes main to ${phaseWord(st, slot.phase)}:
  ${idWord(st, v.call.model)} at ${effortWord(view, v)}. Run it on fable?`
  where `phaseWord` = `phase` + ` (${about})` when `aboutLine` is set (the
  body of `routedTo` without its "Routed to" prefix; `routedTo` calls it);
  origin ∈ `Skill /feat` (typed or model-loaded), `Route tool`, `/route`.
  Options: `[TIER_HEAD, TIER_INSTEAD, TIER_STOP]`, or `[TIER_HEAD,
  TIER_STOP]` when opus is down (offer rule, D2). Answers via `askStep`
  (Later / unrecognised / rejected → undefined): `TIER_HEAD` or undefined →
  stamp `'best'`; `TIER_INSTEAD` → stamp `'big'`; `TIER_STOP` →
  `st.tierPaused = true`, stamp `'best'`. (Default A: a dismissed dialog
  stamps the span.)
- Stamp = write `tierChoice` on `slot` AND on `st.runMain` when
  `st.runMain !== null && st.runMain.route.tier === slot.route.tier`
  (the run derived from this event, or the run this route serves). After
  a `'big'` stamp, `refresh($, st)` so the status line follows.
- Fail-open: everything inside try/catch; a throw logs once (`failOnce`
  text pattern: `model-router: tier dialog failed (…); route kept`) and the
  route applies as today.

### D4 call sites
1. `confirmSkill` (typed rowed skill): restructured as `const changed =
   await confirmFirst(...); if (changed) { re-route as today; toast }; await
   tierAsk($, st, st.turnMain, `Skill /${skill}`)` — the tier ask runs on
   both branches, after the re-route, so the stamp survives.
2. tool.call Skill on main (`registerSkills`, `e.agentId === undefined`):
   after `onSkillLoad`, when `skillRow` exists → `await tierAsk($, st,
   st.turnMain, `Skill /${skill}`)` (default, pass B B: a model-loaded
   best-tier skill — brainstorming, writing-plans, requesting-code-review,
   subagent-driven-development, writing-skills — is a skill-row lift, BDR-123).
   Inside a run already on fable, the cheap guards end it at once (cur ===
   head), so helper skills cost nothing.
3. `handleRouteTool` main path: after `confirmPhase`, `await tierAsk($, st,
   st.turnMain, 'Route tool')`.
4. `setUserRoute`: `parsed` is computed; `probe: State = { ...st, userMain:
   parsed }` (the `wouldRunHead` pattern, read-only) is the `view` of
   `tierAsk($, st, parsed, '/route', probe)`: guards and `snapshot` read
   the probe, `asking` / `tierPaused` land on the real `st`, the answer
   stamps `parsed`; THEN `st.userMain = parsed` (never assigned before the
   answer: `/route` runs mid-turn and a step meanwhile would upgrade).
   `show` follows.

### D5 sub-agents — in `routeSpawn`, after its early returns and after the
first-use block (both branches of the ternary; `phase` re-read from
`st.cfg.agents[type]` after `confirmFirst`, a Change may have moved it)
Order:
1. Stored answer first, before any ask guard: `const kept =
   st.tierSpawn.get(e.subagentType)`; `kept === 'big'` and the route is
   best-tier → return `{ ...route, tier: undefined, model: insteadName(st)
   ?? <route unchanged> }` (opus, else sonnet, never the head; re-resolved
   at every spawn); `kept === 'best'` → return the route as is. A stored
   answer applies whatever `tierPaused`, `asking` or the key say (like a
   stamped main slot).
2. Ask guards: `tierHead` defined, `!st.tierPaused`, `st.asking === null`,
   `e.parentAgentId === undefined`, `e.model === undefined`, `route.tier ===
   BEST`, `spawnTarget($, st, e, route)` is the head id, then surfaces
   non-empty. (Default C: one answer per agent type per session: the audit
   gates spawn verifier and security-auditor at every loop iteration, a
   per-spawn dialog with no timeout would stall unattended orchestration.)
3. The dialog holds `st.asking = 'tier:agent:<type>'` (finally null),
   records `sid` like D3. Text: `Agent ${type} runs ${phaseWord(st, phase)}
   on ${head id} at ${explicitEffort.get(tool_use_id) ?? route.effort ??
   'its own effort'}. Run it on fable?`; same options (instead dropped when
   opus is down). Answer → `st.tierSpawn.set(type, choice)`, then step 1's
   rule gives this spawn its route; Stop → `tierPaused` + `'best'` stored.

### D6 command and show
- `handleCommand`: `case 'ask-tier': return flagCommand($, st, rest[0],
  ASK_TIER_FLAG)` and `case 'ask': return flagCommand($, st, rest[0],
  ASK_FLAG)` — `askCommand` generalized into `flagCommand($, st, arg, flag:
  Flag)` with `type Flag = { word: string; key: string; value: (on: boolean)
  => unknown; local: (m: Memory) => unknown }` (4 params): usage `usage:
  /route ${word} on|off`, answer `${word} ${arg}`, override note `;
  ~/.claude/model-router.json sets ${key} ${on|off} and wins here` when
  `local(st.mem)` is defined. The `/route ask` strings locked by the
  existing tests are unchanged.
- `registerCommand` argumentHint gains `ask-tier on|off`.
- `show`: router line gains ` · ask-tier: ${word}` with word `best` | `off`
  | `best (paused this session)` (invalid value prints `best` too).
- Comments: the "first use" block (~2485) gains one sentence ("a route that
  would lift main, or a rowed spawn, onto the head of `askTier` asks first:
  Fable, Opus instead, or stop for the session; nothing written"), and the
  `asking` field comment (line 122) reads "key of the one dialog in flight
  (first-use or tier ask)". AC10 names the 2485 block.

### D7 tests (register.test.ts)
Fixture: `baseRouting()` gains `askTier: false` (the fixture's `ask`
convention: no dialog by default); `Fixture.askTier?: 'best' | false`;
`asksTier(answers, fx?) = newWorld({ answers, askTier: 'best', ...fx })`
(first-use `ask` stays false unless a test sets it). The THREE key-order
assertions (test.ts ~2337, ~2408 reversed pre-write list, ~2414) gain
`'askTier'` at its place. A `verifier → audit` row and an `about` line on
`reflect`/`audit` go through per-test `edit:`. Tests, names `TIER:`:
1. typed /feat on OPUS, `edit` adds `phases.reflect.about = 'analysis'` →
   one ask; text contains `Skill /feat routes main to reflect (analysis):
   claude-fable-5-1 at high. Run it on fable?`; options equal exactly
   `['Fable', 'Opus instead (big tier)', 'Stop asking this session']`.
2. `Fable` → next main step FABLE/high.
3. `Opus instead` → main step OPUS/high (phase's own effort, no notch);
   then `$.tool.call route phase=orchestrate` in the same turn → no second
   ask, step OPUS/medium; then `turn.complete` + a new turn's step → still
   OPUS (run slot stamped); `/route show` main line contains `[tier big
   (instead of best)]`.
3b. after `Opus instead`, `$.tool.call route phase=implement` → step SONNET
   (a work route never inherits 'big'); a typed `/bugfix` (fixture row
   `bugfix: 'reflect'`) after the answered `/feat` → a second ask (new span).
3c. fable marked down after an `Opus instead` answer → step stays OPUS at
   high (no stand-in notch, no "stands in for" in `show`).
4. `Stop asking` → step FABLE; a second typed rowed best skill → no ask;
   `/route show` contains `ask-tier: best (paused this session)`.
5. session already on FABLE → `w.asked` empty, step FABLE.
6. headless (`surfaces: []`) → `w.asked` empty, step FABLE (no REJECT
   consumed); dismissed (`REJECT` answer with a surface) → step FABLE, a
   later route-tool call of the span asks nothing.
7. route tool `phase: 'plan'` from main on OPUS → asks with `Route tool`;
   with `agentId` → nothing.
8. `/route plan` → asks; the slot is set only after the answer (a step
   recorded while the dialog is held — `gate` — stays OPUS); `Stop asking
   this session` answered there → `tierPaused` real (a later typed /feat
   asks nothing); `/route model=fable` → nothing, route set.
9. sticky `/route model=opus` then typed /feat → no ask (slot is not the
   effective one), step OPUS.
10. `mainUpgrade: false` (home override) → typed /feat asks nothing, step
    OPUS.
11. SONNET session, opus marked down (a `rate_limit` StopFailure charged
    to OPUS through an earlier spawn), then typed /feat → the ask offers
    `['Fable', 'Stop asking this session']` (instead dropped).
12. model-loaded skill: `$.tool.call Skill brainstorming` on main (row
    `brainstorming: 'plan'` in the fixture edit) from OPUS → asks with
    `Skill /brainstorming`; `Opus instead` → step OPUS/xhigh.
13. spawn: fixture `edit: f => { f.agents.verifier = 'audit';
    f.phases.audit.about = 'gates' }`, OPUS session, `spawnOf('verifier')`
    → asks with `Agent verifier runs audit (gates) on claude-fable-5-1 at
    xhigh`; `Opus instead` → `rig.specs` = [OPUS]; a second
    `spawnOf('verifier')` → no ask, [OPUS] again; the same with a first-use
    dialog held open (`gate`) on another type → still [OPUS], no second
    dialog; `Fable` → [FABLE]; explicit `model` → no ask; nested
    (`parentAgentId`) → no ask; `spawnOf('feater')` (work) → no ask.
14. first-use on (`ask: true`) + askTier: typed /feat with answers
    `['Keep', 'Opus instead (big tier)']` → two asks in order (`First route
    for /feat`, then the tier question) and the step is OPUS.
15. a dialog in flight (`gate` held on a first-use spawn ask) → a typed
    rowed skill routes fable unasked.
16. `/route ask-tier off` → `routingOf(w).askTier === false`, typed /feat
    asks nothing; `ask-tier on` → `'best'`; `ask-tier maybe` → `usage: /route
    ask-tier on|off`, `w.written` empty; home `{ askTier: false }` → `/route
    ask-tier on` answer contains `wins here` and no ask fires.
17. `edit: f => { f.askTier = 'work' }` → one ui.log line, the ask fires
    (read as best); the line is not repeated on `/route reload`.
18. `routing: 'absent'`, OPUS session, `$.tool.call route phase=plan` on
    main → no ask (emptyMemory false), route set.
19. `/route ask` tests unchanged and green (flagCommand refactor).

### D8 docs
USAGE.md: `/route` row (173) gains `ask-tier on|off`; the model-router
paragraph (199) gains: before a route lifts the main loop, or sends a rowed
agent, onto Fable, the mod asks once per span (origin, phase and its
`about`, model and effort): `Fable`, `Opus à la place` (le tier big, effort
de la phase inchangé), `ne plus demander cette session` ; un skill chargé
par le modèle compte comme une ligne de skill ; une réponse par type
d'agent et par session ; jamais en `-p` ni dans un sous-agent ; la clé
`askTier` (`best` ou `false`) de `routing.json`, `/route ask-tier on|off`,
l'override machine gagne. README.md 144-146 + CHANGELOG `[Unreleased]` →
doc-sync STEP 6.

## Plan (checklist, dispatch-ready)
- [ ] mods/model-router/routing.json — `"askTier": "best"` after `"ask": true`.
- [ ] register.ts — constants (TIER_*, INSTEAD_TIER, Choice), ROUTING_ORDER
      rewrap, `Memory.askTier/askTierLocal` raw + `emptyMemory` false,
      `State.tierPaused` + `tierSpawn` (not kept by resetSession),
      `Routed.tierChoice`, `tierHead`, `insteadName`.
- [ ] register.ts — `wantedModel` branch (D2), inheritance in `applyRoute`
      and `routeMainBySkill`.
- [ ] register.ts — `tierAsk` + `tierQuestion` + stamp (D3); call sites D4
      1-4 (`confirmSkill` restructured, Skill tool.call on main,
      `handleRouteTool`, `setUserRoute` assign-after-answer).
- [ ] register.ts — `routeSpawn` tier ask with `tierSpawn` memory (D5).
- [ ] register.ts — `flagCommand` (ask + ask-tier), `handleCommand` case,
      argumentHint, `show` segment, header sentence (D6).
- [ ] register.test.ts — fixture + key-order assertions + TIER tests 1-19.
- [ ] USAGE.md — row + paragraph (D8).
- [ ] Executor runs `make test suite=lib/tests/mods.test.sh` and `make test`;
      reports the first-use tests untouched and green.
- Style: new functions ≤ 25 logic lines, ≤ 5 params, 80 cols (the file keeps
  3 pre-existing long lines; add none).

## Edge cases
- Opus held during a `'big'` span → `insteadName` → sonnet (never fable),
  silently; opus back → opus again at the next step (resolution is per
  step, like a tier). Opus AND sonnet held → the tier's normal resolution
  (the span runs rather than stalls).
- RESIDUAL for the gate (pass B F): the ask fires at route events only
  (a step cannot ask, LRN-231). When fable is HELD at the event (billing,
  BLK-030/031) or the cold read is over the cap, no question fires and the
  slot stays unstamped; when the hold lapses (`prune`) or a compaction
  brings the context under `upgradeMaxTokens`, the next step upgrades main
  to fable unasked. Alternative: treat an unstamped best slot as
  `insteadName` until a route event asks (changes today's routing in the
  held-head case: main would stay on opus after the hold lapses instead of
  returning to fable).
- `[1m]`: comparisons on `canonical()`; `moveTo` carries the variant.
- `sessionModel === ''` cannot happen after session.start (4149 reads it);
  if it does, `canonical('') !== head` → the decision decides (snapshot).
- Stop then `/route ask-tier on` → still paused this session (`show` says
  so); `/clear` re-arms.
- A `/route forget` or first-use write never touches `askTier`
  (serializeRouting keeps unknown keys; the key is in ROUTING_ORDER).
- Write failure of `ask-tier` → `failedWrite` text, like `ask`.
- Residual accepted (robustness 13): `/model <x>` typed while any dialog
  holds `asking` falls to native (pre-existing path, BDR-126); not widened
  by this feature beyond the dialog's open time.

## Pass B (open choices, asked at the gate; defaults taken in r3)
A. Dismissed dialog (Esc / free text) → the span runs on Fable and is not
   asked again (default) — or re-asked at the next route event of the span.
B. Model-loaded best-tier skill on main (brainstorming, writing-plans…) asks
   too (default, BDR-123 "skill row") — or typed skills only.
C. Sub-agents: one answer per agent type per session (default) — or one
   question per spawn.
F. Held-head residual (Edge cases): accept it (default: today's breaker
   behaviour, documented) — or keep an unasked best slot off fable until a
   route event asks.
Settled as defaults, not asked (internal or fixed by the request's words):
D. "Opus instead" runs the phase's own effort, shown in the question.
E. `askTier` accepts `best` or `false` only.

## Disposition (STEP 0.6 RELATED MEMORY)
IN FORCE: BDR-116 (routing.json single source; `/route ask` writer; one
dialog at a time; never in `-p` or a sub-agent) — D1/D3/D6; BDR-123 /
BLK-032 (Fable on main only via skill row, route tool, `/route`, hand pick;
prompt rules effort-only) — D4 covers typed AND model-loaded skill rows, the
route tool and `/route <phase>`; BDR-126/127/132 (hand picks always switch)
— explicit-model routes never ask; LRN-242 (2-4 options) — 3 or 2; LRN-231
(no dialog in a step hook) — asks at route-setting events only; LRN-243
(interactive behaviour proven before building) — every hook kind used
already renders `$.ui.ask` in the shipped code.
ALREADY SEEN: LRN-229 (kit: forcing a throw after an answer), BLK-030/031
(Fable without credits is the breaker's job, not this ask).
NON-BINDING: BDR-107, BDR-115, LRN-211, LRN-226.
SELECTION: scanned 4 registries, surfaced 14 = in-force 8 + seen 3 +
non-binding 4 (BLK-032 counted in two groups).
