# PLAN r3 — model-router wave 4-A: transition logs + residuals (2026-10-11)

r1 → r2 after simplicity CONCERNS(4), robustness CONCERNS(5), correctness
FATAL(5) (BLOCKER: an agent's model move happens at spawn, invisible at
turn.step); r2 → r3 after the confirmation (correctness CONCERNS(5)).
Precedence r3 > r2 > r1. Contract
`.claude/tasks/contracts/2026-10-11-model-router-w4a-logs-residuals-*.md`.
Base: develop f1cea54. Corrected facts: `Plan` = {model, effort} and
`mainPlan` discards the `Call` (its `why`); `agentPlan` returns `e.model`
verbatim (the spawn hook rewrote it already); `TurnStepInput` carries only
`agentId`; `Loop` = {effort, explicitEffort}; `Routed` = {phase, route,
source} (no skill name, no rule word); `mainRoute` excludes `turnFloor`;
`mainEffort().by` ∈ sticky|turn|floor|engine; no `effortSource`; `st.lastPlan`
holds main's previous plan (nulled on /clear); `st.logged` / `turnLogged`
are the dedupe sets; `AgentSpawnInput.parentModel` exists; `askOr` swallows
a rejected ask into LATER; `forget not applied (${String(err)})` lives in
`forgetWrite` (and its twin in `askCommand`); `buildMemory` has no
models/tiers to validate phases; the user's override sets `verbose: true`.

## D1 Logs: `verbose` stays boolean; true = transitions only
- The four firehose `vlog` sites are DELETED (step line, "answered by",
  spawn line, route-tool JSON, skill-path line). No `trace` level. `vlog`
  stays the single gate; `/route verbose on|off`, argumentHint and show
  texts unchanged.
- Main transition: `planStep` returns `{ plan, why }` where `why` =
  per-axis cause words computed at decision time (no `$` call, no
  re-decision): effort cause from `mainEffort().by` + its slot (`sticky
  /route`, `route tool` (turn, source model), `skill <label>` (run/turn,
  source skill|run), `prompt floor` (floor), `dispatch` (derived
  orchestrate), `session`); model cause = the `Call.why` when it moved
  (`upgrade`, `fallback: <alias> down`, `switch`) else none. `Routed`
  gains an optional `label`: the skill name at `routeMainBySkill` /
  `confirmSkill` (`/feat`), the rule's phase at `floorFromPrompt`.
  Rendered: "model-router: main: <alias>/<effort> → <alias>/<effort>
  (<phase>: <cause>[, <model cause>])", e.g. "(plan: skill /ship-feature)",
  "(orchestrate: dispatch)", "(escalate: prompt floor)", "(reflect:
  prompt rule)" (turn/source prompt; `defaultFromPrompt` sets the label),
  "(custom: sticky /route)", "(reflect: skill /feat, upgrade)"; no route
  in force → "(session[, <model cause>])". Model cause from `Call.why`:
  upgrade → `upgrade`, fallback → `fallback: <alias> down`, downgrade →
  `switch`. Comparison: `prev = st.lastPlan ?? {e.model, e.effort}`,
  CAPTURED BEFORE `noteMain` overwrites `lastPlan` (after /clear or
  `/route on|off`, which null `lastPlan`, the first step compares to the
  engine input: stated omission); emitted INSIDE `safely(st, $,
  'turn.step log', …)` BEFORE `next` (a log failure never unroutes a
  step; own warn key); deduped per turn per (loop, from→to) through
  `turnLogged` (derived orchestrate waves log once per turn).
- Agent HAND-OFF line (r3, a dispatch is a model change): emitted in
  `afterSpawn` for every rowed or explicit spawn, deduped per turn per
  (type, to) through `turnLogged` (three parallel challengers = one
  line): "model-router: main <alias>/<effort> → agent <type>
  <alias>/<effort> (<model cause>, <effort cause>)" where from = main's
  `st.lastPlan` (or the engine's session model when none), to = the
  EFFECTIVE sent plan (`started.model` canonical; effort = explicit ??
  row effort, stripped on haiku), model cause = `row <phase>` | `explicit`
  | `fallback: <alias> down` (in-tier move) | `frontmatter` (tier down,
  nothing written), effort cause = `row` | `explicit` | `engine` (no row).
  `Loop` gains optional `{ type, last: {model, effort}, cause }`: set in
  `trackLoop` from the effective plan; `writeLoop` updates `effort` and
  `cause` only (`route tool` | `skill <name>` | `explicit`); each agent
  step compares `plan` to `loop.last ?? {e.model, e.effort}`, logs
  "model-router: agent <type>: <from> → <to> (<cause>)" on a difference,
  then sets `loop.last = plan` (haiku: effort undefined on both sides);
  no Loop or no `type` → label `agent <id8>`; `endAgent` drops the entry;
  caps as `MAX_AGENT_MODELS`.
- Aliases: `aliasOf(cfg, canonical(cfg, id))` with a `[1m]` marker kept,
  the id itself when no alias matches; effort `-` when undefined; every
  name in a line passes `clean(…, 40)`.
- Answered-by anomaly (agents only; main's engine switch is already
  logged by `onAutoSwitch`): after `next`, inside `safely`, when
  `result.usage` is non-null and `canonical(usage.model) !==
  canonical(plan.model)`, log once per (agentId, model) via `st.logged`
  key `answered:<id>:<model>`: "model-router: agent <type> answered by
  <alias> instead of <alias>".
- Unconditional lines stay as today and count as warnings: `logCall`
  (upgrade skipped / no fit), `tierDownLog`, `onAutoSwitch`, `warnOnce`,
  config drops, toasts. The spinner suffix unchanged.
- Config: `verbose` invalid (`"ON"`, 1, null) → default `false` + one
  log per load (mergeConfig falls back to the seed, stated).

## D2 Residuals
- (a) `forgetWrite` catch AND `askCommand` catch (the latter gains the
  `RebuildFailed` branch "ask saved, config not rebuilt: /route reload"):
  `$.ui.log("model-router: <cmd> failed: " + String(err))`, answers
  "forget not applied, see the log" / "ask not applied, see the log".
- (b) `kept` becomes `{kind, name, reason}[]`; `clean(x, 40)` applied to
  the file-sourced fragments (name, from, to) at RENDER time only
  (`forgetAnswer`, `restoreClause`, `idleAnswer`, kept rendering); the
  fixed reason texts untouched; `ForgetPlan`/`Restore` fields untouched
  (a 45-char row name is restored byte-exact in the file; test).
- (c) `floorFile`: `SKILL_NAME.test(name)` else undefined.
- (d) `restoreOf`: `name === '__proto__'` → refused ("reserved name").
- (e) the `changed` scan iterates ROWS only.
- (f) `mem.filePhases` = exactly the seeded layer: `mergeConfig({
  phases: file.phases }, noop).phases` (code defaults + file phases
  validated against the DEFAULT models and tiers, override excluded),
  computed in `assemble` AND `refreshMemory`; `effortsOf` and
  `targetPhase` use it, so a machine-only phase is never offered nor
  written; the existing empty-efforts toast reads "no shipped phase uses
  <alias>: add one to routing.json". Tests: a null file phase (ignored,
  no crash), a file without `phases` (code defaults offered), an
  override-only `custom` (not offered, not written).
- (g) `confirmFirst`: `answered` flag set after `decide()` returns; the
  catch deletes the key from `asked` only when unset. Tests: a throw
  BETWEEN `asked.add` and the answer (a throwing `ui.toast` on an
  unrecognised answer) → key unasked (fails if the delete is removed);
  `world.failWrite` (post-answer) → key stays asked, one log; the three
  existing tests asserting the old post-answer deletion are inverted
  (authorized); the `failOnce` dedupe test rewritten with two different
  rows failing.

## Steps
- [ ] S1 delete the four vlog sites; `planStep` → `{plan, why}`;
      `Routed.label` (skill name, prompt rule phase); `Loop {type?, last?,
      cause?}`; `lastPlan = null` on `/route on|off`.
- [ ] S2 `transitionLine` (main, in safely before next, turnLogged dedupe)
      + agent line in `afterSpawn` + agent step comparison + answered-by
      anomaly; `aliasOf` canonical; names cleaned.
- [ ] S3 residuals (a)-(g).
- [ ] S4 docs: README (three `verbose` sites: the `/route` bullet, the key
      list "default false", the commands table → "transitions only"),
      USAGE `/route` row, CHANGELOG Unreleased (Changed: logs; Fixed: the
      residuals). argumentHint unchanged.
- [ ] S5 kit tests (recordLogs recorder; a `usage`-bearing bottom step hook
      where needed), one per clause: main unchanged over 3 steps → 0
      lines; route tool plan → exactly one line with "(plan: route tool)";
      typed `/feat` → "(reflect: skill /feat)"; derived orchestrate → one
      line per turn even with two dispatch waves; ultrathink → "(escalate:
      prompt floor)"; sticky `/route xhigh` → "(custom: sticky /route)";
      sonnet session + typed `/feat` → ", upgrade"; feater spawn → one
      agent line "agent feater: fable/high → sonnet/medium (row: feater
      implement)" and 0 lines on its next steps; explicit model/effort
      spawn words; in-agent route tool effort move → one agent line
      "(route tool)"; answered-by anomaly once (usage hook), none when
      usage null, none on a `[1m]` plan; a throwing `ui.log` leaves the
      step routed; `verbose: false` → nothing; invalid override values
      → default + one log; /clear → first step compared to engine input;
      the legacy four lines never appear at `true` (typed skill, route
      tool, spawn, step); "explain why" prompt → "(reflect: prompt
      rule)"; explicit-effort spawn and haiku spawn → one hand-off line
      then 0 lines on their next steps; three parallel challengers → one
      hand-off line; tier-down spawn → "frontmatter" cause; (a)-(g) each
      with a mutation-sensitive test.
- Disposition: honors BDR-115/116 (no new writer; logs carry ids and
  cleaned names only), LRN-210, LRN-212 (live mod: the terminal changes
  as soon as the feater saves).

## Challenge ledger (r1 → r2)
- simp 1, corr 11/12 (`trace` surface) → removed; boolean kept.
- simp 2, corr 2, rob 3/6 (new Map, missing type/cause) → `st.lastPlan`
  + `Loop {type, last, cause}`, dropped in endAgent, capped.
- simp 3/4, corr 1 BLOCKER/3/4/5, rob 3 (why not derivable; spawn move
  invisible) → `planStep` returns why from the decision; `Routed.label`;
  agent line in `afterSpawn` with `parentModel`.
- simp 5, corr 6, rob 2 (answered-by) → agents only, canonical ids, null
  usage skipped, `st.logged` dedupe.
- rob 1 (log failure unroutes) → safely before next, own warn key.
- rob 7 (flapping) → per-turn dedupe via turnLogged.
- rob 8 (names) → clean(40) on labels and causes.
- rob 9, corr 12 (invalid verbose) → default + one log, stated.
- rob 10 (/clear) → stated omission; reset at /route on.
- rob 11 (legacy lines untested) → S5 cases.
- simp 6, corr 9, rob 5 ((f) unvalidated / dead toast) → validated seed
  layer in assemble + refreshMemory; toast folded.
- simp 7, corr 8 ((g) premise) → `answered` flag; tests inverted.
- rob 4 ((b) clean on plan fields) → render-time only.
- corr 10, rob 12 ((a) site + twin) → forgetWrite + askCommand.

## Confirmation ledger (r2 → r3)
- conf 1 (agent from-effort unsourced, non-changes) → hand-off line from
  main's lastPlan, per-axis causes, per-turn dedupe per (type, to).
- conf 2 (loop.last bookkeeping) → last = effective sent plan, writeLoop
  updates cause/effort only, each step sets last after comparing; tests.
- conf 3 (prompt rules unlabelled) → `prompt rule` cause + label.
- conf 4 ((b) kept strings) → kept as records, fragments cleaned at render.
- conf 5 ((g) pre-answer test) → throw between asked.add and the answer.
- conf 6 (prev before noteMain) → stated.
- conf 7 (why words, no-route render, alias fallback) → mapping spelled out.
- conf 8 ((f) formula) → `mergeConfig({phases}, noop).phases`.
- conf 9 ((a) askCommand) → RebuildFailed branch added.
- conf 10 (/route on reset) → S1.
- conf 11 (loop without type) → optional fields, id8 label.
- conf 12 (failOnce test) → two rows.
