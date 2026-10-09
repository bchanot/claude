# PLAN — model-router wave 1-C: absolute tiers, availability fallback, derived phases (dispatch-ready)
Contract: .claude/tasks/contracts/2026-10-09-model-router-tiers-1237.md
Code: mods/model-router/hooks/register.ts (read in full) and register.test.ts.
API truth: mods/model-router/.claude-plugin/types/claude-code/index.d.ts
(TurnStepInput, TurnCompleteInput + TurnCompleteReason, SessionRateLimit,
`classic.PostModelSwitch` → PostModelSwitchHookInput, `$.session.model`,
`$.model.classify`, 'claude-code/testing'), .../claude-code-tools/index.d.ts.

## Why (user, 2026-10-09)
1. "Session model" phases assumed Fable. On a haiku session, `plan` at xhigh on
   haiku is wrong. Phases must name ABSOLUTE tiers.
2. When Fable has no credit left, routing must fall back (plan → opus xhigh).
3. The user never types `/route`: phases are derived (prompt wording,
   dispatch spans, skills) or declared by the model.
4. Reflection and planning always get the best available model.

## Engine facts (read in the declarations today)
- `SessionRateLimit.kind` ∈ five_hour | seven_day | spend_limit: account
  windows, NOT per model → availability cannot be read from quotas.
- A dead request: `turn.step` result `usage: null`, `stopReason: null`;
  `turn.complete` `reason: 'error'` (retries exhausted) or `'refusal'`
  (refused, no fallback model); `'aborted'` = the user interrupted.
- `classic.PostModelSwitch` fires on every main-model change with
  `from_model`, `to_model`, `source` ∈ command|picker|sdk|auto|resume,
  `context_tokens`, `prompt_cache_warm`.
- `turn.step` `e.model` = the id the engine resolved (session's or a
  fallback's); `$.session.model()` = the main loop's model as `/model` shows.
- `$.model.classify(text, labels, { model? })` → label | undefined, rejects
  on failure; default = the engine's small fast model.

## Config (additions; everything else unchanged)
```ts
type Route = { model?: string; effort?: Level }   // model: TIER name, alias or full id
type PromptRule = { pattern: string; phase: string; mode?: 'floor' | 'default' }
type Config = {
  …existing…
  tiers: Record<string, string[]>     // tier → ordered alias preference
  fallback: string[]                  // alias order, best first; = rank
  cooldownMinutes: number             // breaker hold
  mainUpgrade: boolean                // main loop may switch UP to a phase's tier
  classifier: boolean                 // ask the small model when no rule matched
}
```
DEFAULT_CONFIG changes:
- `tiers`: best `['fable','opus','sonnet']`, big `['opus','fable','sonnet']`,
  work `['sonnet','opus']`, cheap `['haiku','sonnet']`.
- `fallback`: `['fable','opus','sonnet','haiku']`. `cooldownMinutes: 15`.
  `mainUpgrade: true`. `classifier: false`.
- phases: plan `{ model: 'best', effort: 'xhigh' }`, reflect `{ best, high }`,
  orchestrate `{ best, medium }`, escalate `{ best, max }`, judge `{ big, xhigh }`,
  implement `{ work, medium }`, write `{ work, medium }`, verify `{ work, xhigh }`,
  explore `{ work, medium }`, mechanical `{ cheap, low }`. (Keep the `model`
  field name: a tier name is a model NAME the resolver understands; no new
  `tier` field. AC3 greps `tier: '…'`?? NO: AC3 is written against
  `model: 'best'`-style entries? → see AC3 note below.)
- prompt: `[{ pattern: '\\bultrathink\\b', phase: 'escalate', mode: 'floor' },
  { pattern: '\\b(plan|planifie|planning|brainstorm|architecture|con[cç]ois|design)\\b', phase: 'plan', mode: 'default' },
  { pattern: '\\b(pourquoi|why|explique|explain|analyse|analyze|comprendre|understand|review|audit)\\b', phase: 'reflect', mode: 'default' }]`.
  `mode` absent → 'default'.
AC3 note for the executor: the contract's CHECK counts `tier: '(best|big|work|cheap)'`
in DEFAULT_CONFIG and refuses `model: '` entries there. So the PHASE type gets
an explicit `tier?: string` field: `type Route = { tier?: string; model?: string;
effort?: Level }`; a route resolves `tier` first, then `model`. Default phases
use `tier:`. `/route model=<x>` keeps writing `model` (alias or id). The route
tool keeps `phase`/`effort`/`clear` only.
Validation: `tiers` values = non-empty arrays of `models` keys (bad entries
dropped, logged); `fallback` = array of `models` keys, deduplicated, non-empty
(else default); phase `tier` must be a `tiers` key; `cooldownMinutes` positive
integer; `mode` ∈ floor|default.

## Resolution (ONE resolver, used by spawn, main plan and texts)
```ts
function availableIn(st, aliases: string[]): string | undefined
  // first alias whose full id is not down (st.down.get(id) > now → down)
function resolveModel(st, name: string): string
  // tier name → availableIn(tiers[name]) ?? first alias → id
  // alias → id (explicit: never skipped when down); full id → itself
function resolveRoute(st, route: Route): string | undefined
  // route.tier ? resolveModel(st, route.tier) : route.model ? resolveModel(st, route.model) : undefined
function rank(st, id: string): number
  // index in cfg.fallback of the alias whose id prefixes `id` (strip "[1m]"); unknown → fallback.length
```
`now` comes from `$.clock.now()` (read once per hook call that needs it).

## Breaker (`st.down: Map<string, number>` full id → until ms; `st.lastMainModel: string`)
- `turn.complete`: main (`e.agentId` undefined) with `reason` ∈ error|refusal →
  `markDown(st, st.lastMainModel)`; agent with that reason → `markDown(loop.model)`
  (Loop gains `model: string`, the model the engine reported at spawn,
  `started.model`). `aborted`/`answer` → nothing.
- `classic.PostModelSwitch` with `e.source === 'auto'` → `markDown(e.from_model)`.
- `markDown` logs ALWAYS (not only verbose): `model-router: <id> unavailable
  until <HH:MM>; routing falls back`. `/route reload` and `session.end` clear
  the map. `show()` gets a `down: <id> until <HH:MM>, …` or `down: none` line.

## Main-loop model decision (`mainModel` rewritten)
```
wanted = resolveRoute(st, (userMain ?? turnMain ?? turnFloor)?.route)   // per-axis as today
cur = e.model
if cur is down and wanted is undefined → wanted = nextAvailable(st, cur)  // fallback chain after cur's alias
if wanted undefined or sameRank(wanted, cur) → cur
if rank(wanted) < rank(cur)  (better) → cfg.mainUpgrade ? wanted : cur
if rank(wanted) > rank(cur)  (cheaper) → cfg.mainModelSwitch && windowOk ? wanted : cur
if cur is down and wanted defined → wanted (always: nothing to lose)
```
`st.lastMainModel = plan.model` at every main step. `sameRank` compares
aliases (so `claude-fable-5-1` vs `claude-fable-5-1[1m]` never flips).
The log/status show `→ fallback` when the breaker chose the model.

## Spawn (`spawnRoute` / `registerSpawn`)
`wanted = resolveRoute(st, route)`; explicit `e.model` still wins. Store
`loop.model = started.model`. (Explicit alias given by the caller while down:
left alone, explicit means explicit; note in the tool description.)

## Derived phases (no user action)
D1. Dispatch push/pop: in the Agent `tool.call` hook, when `e.agentId` is
    undefined (main) and `st.turnMain?.source !== 'model'` written AFTER the
    dispatch… simpler rule: on a main Agent call, if `st.resumeMain` is
    unset, `st.resumeMain = st.turnMain ?? NONE` and `st.turnMain = { phase:
    'orchestrate', route: phases.orchestrate, source: 'derived' }`. When an
    agent's `turn.complete` leaves `st.loops` empty AND `st.turnMain?.source
    === 'derived'` → `st.turnMain = st.resumeMain` (NONE → null), clear
    `resumeMain`. A `route` call or skill load in between replaces turnMain
    (source model/skill) so the pop is skipped and `resumeMain` cleared at
    the next main `turn.complete` (endMainTurn clears both). Source type gains
    `'derived'`.
D2. Prompt default rules (`mode: 'default'`): write `turnMain = { phase,
    route, source: 'prompt' }` (NOT the floor) — overridable by routes and
    skills; floor rules unchanged. Mid-turn prompt with a default rule → only
    `pendingPrompt`-like handling for FLOOR rules stays; a default rule typed
    mid-turn is ignored (the running turn has its own routes).
D3. Classifier: when `cfg.classifier` and no rule matched and the prompt is
    composer-origin and idle (no `turnId`): `label = await
    $.model.classify(e.text.slice(0, MAX_PROMPT_SCAN), [...phaseNames,
    'other'])` in try/catch; a phase label → default route (source 'prompt');
    anything else → nothing. Document the cost in the config comment.

## Texts
`routedText`/`mainNote`/`show`: print the RESOLVED id and `(fallback)` when
the breaker skipped a better alias; `(tier best → claude-fable-5-1)`.
Spinner/status unchanged shape.

## Tests (register.test.ts; names must contain the contract's words)
Reuse the boot helper; full typed inputs; bottom hooks (`agent.spawn`,
`turn.complete`, `classic.PostModelSwitch` — read its input type for the
required fields; `prompt.submit`). Engine effort `high` in steps.
- `tier: a plan route upgrades a haiku session to fable at xhigh` — route tool
  `plan`, step with `model: 'claude-haiku-4-5-20251001'` → bottom sees
  `claude-fable-5-1` and `xhigh`.
- `downgrade: mechanical on fable keeps the model while the switch is off`.
- `fallback: an error turn on fable moves the next main step to opus` — step on
  fable (sets lastMainModel), `$.turn.complete({ reason: 'error', agentId
  undefined, … })`, step on fable → bottom sees `claude-opus-5-5`, effort
  unchanged; then `/route reload` → step on fable stays fable.
- `breaker: PostModelSwitch auto marks the old model down` — `$.classic.PostModelSwitch({ from_model: 'claude-fable-5-1', to_model: 'claude-opus-5-5', source: 'auto', … })` → `/route show` lists `claude-fable-5-1` under `down:`.
- `spawn: Explore goes to opus while sonnet is down` — mark sonnet down
  through an agent error turn (spawn Explore via bottom hook returning a1,
  `$.turn.complete({ agentId: 'a1', reason: 'error' })`), spawn again → bottom
  `e.model === 'claude-opus-5-5'`.
- `derived: a dispatch pushes orchestrate and pops the previous plan route`
  — route tool `plan`, `$.tool.call({ tool: 'Agent', … })` with a bottom hook,
  `/route show` main line shows `derived orchestrate`; `$.turn.complete({
  agentId: 'a1', reason: 'answer' })` (loop registered via spawn) → main line
  shows `model plan` again.
- `default rule: "planifie la migration" routes the turn to plan, a route call overrides`.
- Keep every B1 `floor` test and all earlier tests green (≥ 40 tests total).

## Constraints
- ≤ 25 logic lines per function (extract helpers: `availableIn`, `rank`,
  `markDown`, `nextAvailable`, `decideMain`, `pushOrchestrate`, `popOrchestrate`,
  `applyDefaultRule`, `classifyPrompt`), 80 chars/line, no `any`, state in
  the closure, fail-open `.catch` with `warnOnce` on every new hook
  (`classic.PostModelSwitch`), the route tool schema unchanged.
- Do not touch: the hardening (caps, `safely`, attestation), the Skill
  bridge, the floor slot semantics.
- Verify: validate, the contract's tsc CHECK, `claude plugin test .`, AC3/AC4
  greps, `gates.sh run` on the contract.

## Disposition
- honors BDR-115 and its amendment (one resolver, calling-loop writes,
  truthful texts, per-machine config); supersedes "a phase without model
  keeps the loop's model" (every default phase now names a tier).
- honors BDR-076 (dispatched judgment on opus first: `big` = opus, fable,
  sonnet) and BDR-066 (execution on sonnet: `work`).
- LRN-203: hooks still write full ids (the resolver's output).
- LRN-204: downgrade on main stays gated; upgrade accepted (quality over one
  cold-cache step).
- Deferred: repo agents' frontmatter pins cannot fall back (the mod does not
  see them in wave 1) → wave 2 moves them into the table with tiers.

## r2 — challenge round (3 lenses, all FATAL: 4 BLOCKER, 20 MAJOR): BINDING, overrides every section above where they conflict
R1. ONE phase field for the fallback-aware choice: `Route = { tier?: string;
    model?: string; effort?: Level }`. Default phases use `tier:` only (plan,
    reflect, orchestrate, escalate → best; judge → big; implement, write,
    verify, explore → work; mechanical → cheap). `acceptPhase` refuses a route
    carrying both `tier` and `model`, and refuses a `tiers` key that collides
    with a `models` alias. The earlier "model: 'best'" drafts and the "no new
    tier field" sentence are VOID. `/route model=<alias|id>` keeps writing
    `model`; the route tool schema is unchanged.
R2. Ids: `canonical(st, id)` = strip a trailing `[1m]`, then alias → table id,
    then two-way prefix match against the table ids (`id.startsWith(tableId)
    || tableId.startsWith(id)`), else the id itself. `aliasOf(st, id)` and
    `modelRank(st, id)` (= index of the alias in `fallback`, `undefined` when
    unknown) work on canonical ids. The existing effort `rank` keeps its name.
    Breaker keys, `agentModels` values and comparisons are canonical. When the
    current main model carries `[1m]`, a resolved replacement carries `[1m]`
    too (the long-context tier is a property of the session, not of the
    alias); log the first time it happens (unverified live: see Verify).
R3. Model axis per slot: `routeModelName(route) = route.tier ?? route.model`;
    the main model axis is the FIRST defined `routeModelName` across
    userMain, turnMain, turnFloor (per-axis, like B1's effort). `resolveName`
    turns that name into an available id: a `tiers` key → first alias of the
    list not down → `models` id; a tier whose every alias is down →
    `nextAvailable(st, cur)` (global chain) → may be `undefined` (keep cur);
    an alias or full id → canonical id, never skipped (explicit means explicit).
R4. Main decision `decideMain(st, cur, wanted, ctx)` → `{ model, why }`, used
    by `mainPlan` AND by every text (texts pass `cur = canonical(await
    $.session.model())`); order is BINDING:
    1. `st.off` → cur.
    2. `rankCur = modelRank(cur)`; UNKNOWN cur (not in the table) → cur, log
       once per session (`model-router: <id> unknown to the models table; no
       model switch`), the breaker still applies at step 3 if it is down.
    3. cur DOWN → `wanted` if defined and not down, else `nextAvailable(cur)`;
       apply `windowOk`; if nothing fits → cur (why `fallback`).
    4. `wanted` undefined or `aliasOf(wanted) === aliasOf(cur)` → cur.
    5. `modelRank(wanted) < rankCur` (better) → `cfg.mainUpgrade &&
       ctx.tokens <= cfg.upgradeMaxTokens` ? wanted (why `upgrade`) : cur
       (why `upgrade skipped: context <n> tokens over <max>` or `switch off`).
    6. cheaper → `cfg.mainModelSwitch && windowOk` ? wanted (why `downgrade`)
       : cur (why `switch off`).
    New config scalar `upgradeMaxTokens` (default 200000): an upgrade pays a
    cold read of the whole context on the new model (LRN-204); above the
    threshold it is skipped and logged once per turn. `ctx.tokens` comes from
    `$.session.usage()` read once per main step (fail → treat as 0).
R5. Engine fallback respected: at every main step `sess = canonical(await
    $.session.model())`; when `canonical(e.model) !== sess`, the engine is on
    a fallback → `markDown(sess, 'engine fallback')` and `cur = e.model` (the
    router never upgrades back to the model the engine just left).
R6. Breaker inputs (replace the r1 list): (a) `classic.StopFailure` with
    `error` ∈ rate_limit | overloaded | billing_error | model_not_found →
    `markDown(target)` where target = `st.agentModels.get(e.agent_id)` when
    `e.agent_id` is set, else `st.lastPlan?.model`; other errors (context
    limit = invalid_request, server_error, auth, max_output_tokens…) → nothing;
    (b) R5's engine-fallback detection; (c) `classic.PostModelSwitch`: source
    `command | picker | sdk` → `st.down.delete(canonical(to_model))` and reset
    its strikes (the user's explicit `/model` wins); source `auto` → LOG only
    (`requested_model`, from, to), never a mark (unverified semantics).
    `turn.complete` `reason` is NOT a breaker input any more (context-limit
    and network errors are not availability); refusal → nothing.
    Backoff per canonical id: strikes 1, 2, 3… → 15, 30, 60, 120, 300 min
    (cap); `model_not_found` → until `/route reload`. `markDown` logs ALWAYS:
    `model-router: <id> unavailable (<reason>) until <HH:MM>; routing falls
    back`. Inert while `st.off`.
    Lifecycle: `/route reload` clears `down` and strikes BEFORE loading the
    config (whatever the read result); `session.end` (/clear) KEEPS `down`,
    strikes and `agentModels` (availability is account-wide); expired
    entries are pruned at the start of any hook that reads them, with `now`
    read ONLY when `st.down.size > 0` (`$.clock.now()`), passed explicitly to
    the helpers (no clock read in sync text functions: they receive the
    pruned map).
R7. Agent models: `st.agentModels: Map<agentId, canonicalId>` set at spawn
    from `started.model` (canonicalized; an alias answered by a hook above is
    mapped through the table); deleted with the loop. No `Loop.model`,
    `spawnModel` or `loop.model` identifier anywhere (W1-A AC8 grep).
    `spawnRoute` resolves `route.tier ?? route.model` through `resolveName`
    (skips down aliases); explicit `e.model` still wins even when down.
    Deferred (noted): agents without a table row and no explicit model follow
    `parentModel`; forks always inherit; neither falls back in wave 1.
R8. Derived orchestrate (D1) made exact: state `pushed: { prev: Routed | null;
    spawnIds: Set<string> } | null`. In the main Agent `tool.call` hook:
    before `next`, if `st.turnMain?.source` is not 'model' or 'skill' and
    `st.pushed` is null → `st.pushed = { prev: st.turnMain, spawnIds: new Set() }`
    and `st.turnMain = { phase: 'orchestrate', route: phases.orchestrate,
    source: 'derived' }`; after `next` resolves: the spawned `agentId` (from
    `st.spawnByCall: Map<tool_use_id, agentId>` filled at `agent.spawn`) is
    added to `pushed.spawnIds`; if NO agent was registered for this
    `tool_use_id` (foreground run already finished, or denied) → nothing to
    wait for from this call. Pop rule: when `pushed.spawnIds` is empty after
    the Agent call returned, or when the LAST id of `pushed.spawnIds` ends
    (`turn.complete` with that agentId, deleted from the set), and
    `st.turnMain?.source === 'derived'` → `st.turnMain = pushed.prev`,
    `st.pushed = null`. A route/skill write in between (source model/skill)
    replaces turnMain; the pop then only clears `pushed`. `endMainTurn`
    clears `pushed` and `spawnByCall`. In `turn.complete` for an agent, delete
    the loop and the maps FIRST, inside `safely`, before any other work.
R9. Prompt default rules (D2) made safe: rules scanned in two passes (floor
    rules, then default rules), each pass first match; absent `mode` →
    'floor' (B1 override files keep their meaning). Default rules are SKIPPED
    when the trimmed text starts with `/` (slash commands and skills route
    themselves), when the same prompt carries a floor match or sets
    `typedSlash` (the user's explicit level wins), or when typed mid-turn.
    Patterns compile with flags `iu` and the defaults use Unicode-aware
    guards instead of `\b`: `(?<![\p{L}\p{N}-])(plan|planifie|planning|
    brainstorm|architecture|con[cç]ois|design)(?![\p{L}\p{N}-])` and the
    reflect list likewise; the validator requires the pattern to compile
    with `iu`. A default-rule route is written to `turnMain` (source
    'prompt'); it never lowers (no cheap/work default rule shipped).
R10. Classifier (D3) DEFERRED to wave 2: no `classifier` key, no code.
R11. Texts: `routedText`, `effortBridge`/`mainNote`, `slashEffort`, `show`,
    `statusLine`, the route tool description and `mainOnHaiku` derive their
    MODEL words from `decideMain` with `cur = canonical(await
    $.session.model())` (hooks are async; `show` becomes async — the
    command hook awaits it); they print the decided id and `why`
    (`upgrade`, `fallback`, `switch off`, `unchanged`). The tool description
    says: "the main loop moves UP to a phase's tier by itself, DOWN only with
    the switch on; a sub-agent's model is fixed at spawn". `show` prints:
    `upgrade: on|off`, `switch (downgrade): on|off`, `down: <id> until <HH:MM>
    (<reason>) …| none`, each phase as `name=<tier or model>→<resolved id>/<effort>`.
    Existing test 3f (`/route model=sonnet` shows `claude-sonnet-5-5`) is
    adapted: on the kit's session model the line reads `asked claude-sonnet-5-5,
    keeps <cur> (switch off)`; the alias→id resolution is asserted on the
    `asked` part.
R12. `st.lastPlan: Plan | null` replaces `lastMain` and `lastMainModel`; the
    spinner text is derived at render; `endMainTurn` resets it.
R13. Config validation additions: `tiers` values non-empty arrays of alias
    keys (bad entries dropped, logged), `fallback` deduplicated non-empty
    alias list (else default, logged), `cooldownMinutes` and
    `upgradeMaxTokens` positive integers, `mode` ∈ floor|default, a log at
    load when `tiers.best[0] !== fallback[0]` (rank comes from `fallback`
    alone). `mainModelSwitch` documented as DOWNGRADE-only in the Config
    comment.
R14. Tests (≥ 43 total, names carry the contract words): keep all 30; add:
    `tier` (plan on a haiku session → fable xhigh, with mock.clock installed
    where the breaker is touched), `downgrade` (mechanical on fable keeps
    fable, switch off), `fallback` (plan route + `$.classic.StopFailure({
    error: 'rate_limit', … })` on main after a fable step → next step
    `claude-opus-5-5` at xhigh; `/route reload` → fable again), `breaker`
    ×3 (an aborted/`invalid_request` failure never marks down; backoff expiry
    via `mock.clock` advance restores fable; `/model` command
    `PostModelSwitch source: 'command'` clears a down model), `engine fallback`
    (`$.session.model` mocked/answered as fable while the step arrives on
    opus → no upgrade back, fable marked down), `unknown` (cur
    `claude-zz-9` never switches), `spawn` (Explore → opus while sonnet is
    down through an agent StopFailure with `agent_id`), `derived` ×2 (push on
    dispatch, pop when the spawned agent ends → plan back; a route call after
    the dispatch is NOT overwritten by the pop), `default rule` ×3 (planifie
    → plan then a route call overrides; `/analyze …` typed → no rule;
    `/effort-low pourquoi …` → no default rule, floor low), `per axis`
    (`/route effort=low` sticky + turn `plan` tier → model axis = best).
    Read `mock.clock` and how `$.session.model` is answered in the kit
    (a bottom `on('session.model', …)` hook) before writing them.
R15. Disposition, superseded clauses named: floor contract AC4 "`turnMain`
    only ever holds 'model' or 'skill' sources" → now also 'derived' and
    'prompt'; W1-A AC6 "main-loop model changes happen only when
    `mainModelSwitch` is true" → true for DOWNGRADES only; upgrades follow
    `mainUpgrade` + `upgradeMaxTokens`, and the breaker/engine-fallback path
    moves off a dead model unconditionally; BDR-115 (6) window guard → applied
    to every switch (up, down, fallback) through `windowOk`. The tiers
    contract AC5 reads "every B1/1-A criterion still holds EXCEPT the three
    clauses above".
R16. Live verification after reload (orchestrator, not the executor): the
    `[1m]` carry-over on a fallback id, `PostModelSwitch` `source: 'auto'`
    semantics, `StopFailure` reaching the mod with `agent_id`.

## r3 — confirmation pass (FATAL(8): 1 BLOCKER, 6 MAJOR): BINDING over r2 where they conflict
S1. R5 (engine-fallback detection at every step) is REMOVED: no comparison of
    `e.model` with `$.session.model()` at steps, no mark from it. The
    engine's own fallback is learned ONLY through `classic.PostModelSwitch`
    `source: 'auto'`, which now MARKS `canonical(from_model)` down with one
    strike (15 min) when `from_model` is a table id, logging
    `requested_model`, `to_model`. (R6(c) "auto → log only" is void.) A mark
    is idempotent per episode: `markDown` on an id already down adds NO
    strike and logs nothing; strikes count episodes (a mark after expiry).
S2. `st.sessionModel` (raw string) is read once at `session.start` through
    `$.session.model()` inside try/catch ('' on failure) and refreshed in the
    `PostModelSwitch` hook from `e.to_model` (any source). No other
    `$.session.model()` call anywhere; texts use `st.sessionModel`.
S3. Within a turn the main model is STICKY once moved: `cur` for the decision
    is `st.lastPlan?.model ?? e.model` (the model actually sent last; lastPlan
    is reset at `endMainTurn` so each turn starts from the engine's model).
    After an upgrade (plan → fable), a later cheaper phase in the same turn
    (implement → work) goes through the CHEAPER branch against cur = fable:
    gated by `mainModelSwitch` + windowOk, so no return trip and no second
    cold read. After a fallback (fable down → opus), later steps stay on opus
    for the turn. "Keep cur" returns the exact string last sent (`e.model`
    verbatim on the first step), so `[1m]` is preserved; a resolved
    replacement carries `[1m]` only when the raw session string carries it
    AND the target alias is not haiku.
S4. decideMain spelled out (order binding): off → cur · unknown cur (no table
    alias) → cur, logged once · cur down → first available of [wanted (if
    a table id and not down), nextAvailable(cur)] that passes windowOk, else
    cur · wanted undefined → cur · wanted unknown to the table (explicit full
    id such as `claude-x-9`) → treated as CHEAPER (gated by `mainModelSwitch`,
    windowOk) · same alias → cur · better → `mainUpgrade && tokens ≤
    upgradeMaxTokens && windowOk` ? wanted : cur · cheaper → `mainModelSwitch
    && windowOk` ? wanted : cur. `ctx.tokens` from `$.session.usage()` read
    once per main step (catch → 0); texts read it the same way (async), so a
    text and the step agree. `nextAvailable(cur)` walks `fallback` from the
    alias after cur's (unknown cur → from the top) skipping down ids; at
    spawn, `nextAvailable` walks from the tier's last alias.
    `model_not_found` marks show `until reload` in texts.
S5. Derived orchestrate (R8 rewritten): D1 affects BACKGROUND dispatches only.
    In the main Agent `tool.call` hook: push as in R8 (source not model/skill,
    `pushed` null) BEFORE `next`; after `next`: read the RESULT — `status ===
    'async_launched'` → add `result.agentId` to `pushed.spawnIds`; any other
    status or a deny → nothing to wait for from this call. Pop rule unchanged
    (spawnIds empty after the call, or the last id's `turn.complete`); no
    `spawnByCall` map. Documented: a foreground dispatch pushes and pops
    inside one call, so no main step runs at orchestrate for it (fine: main
    is blocked meanwhile).
S6. Breaker targets keep their value until replaced: `st.lastPlan` is NOT
    reset at `endMainTurn` (only the spinner text is cleared via a separate
    `st.spinner` string); `agentModels` entries are deleted at `session.end`
    only, never at an agent's `turn.complete` (the StopFailure/turn.complete
    order is unverified; R16 gains it).
S7. R9 patterns: compile with `iu`; on a SyntaxError retry with `i` (B1
    override files keep working); a pattern failing both is dropped, logged.
S8. R11: the route tool description is STATIC text (registered once): "the
    main loop moves up to a phase's tier by itself (below the context cap),
    down only with the switch on; a sub-agent's model is fixed at spawn".
    `show`, `routedText`, `mainNote`, `statusLine` call `decideMain` with
    `cur = st.lastPlan?.model ?? st.sessionModel` and the same tokens read.
S9. Tests, kit recipe (replaces R14 details): `boot(model = 'claude-fable-5-1')`
    registers, before the first `$` call, bottom hooks `on('session.model',
    () => ({ value: model }))` (answer shape per the Op results in the
    declarations), `on('classic.StopFailure', ($, e) => <passthrough result>)`,
    `on('classic.PostModelSwitch', …)`, and installs `mock.clock(on)`; every
    breaker test advances the mock clock. `derived` recipe: prompt
    "planifie …" (source 'prompt'), then `$.tool.call({ tool: 'Agent', … })`
    whose bottom hook returns `{ result: { status: 'async_launched',
    agentId: 'a1', … } }` (read the Agent RESULT type for the required
    fields) → `/route show` main line says `derived orchestrate`; then
    `$.turn.complete({ agentId: 'a1', … })` → main line says `prompt plan`.
    Second derived test: same, but a route tool call `reflect` after the
    dispatch → the pop does not overwrite `model reflect`. `engine fallback`
    test: `$.classic.PostModelSwitch({ from_model: 'claude-fable-5-1',
    to_model: 'claude-opus-5-5', source: 'auto', … })` → fable listed under
    `down:`; a plan route step does not go back to fable; a second auto
    switch inside the hold adds no strike (show prints the same until).
    Strikes test: expire (advance clock) → mark again → until doubles.
S10. AC3 fix: the `fallback:` and `tiers:` greps run inside the
    DEFAULT_CONFIG awk range.
S11. R16 gains: the order of `classic.StopFailure` vs `turn.complete`; whether
    the engine's fallback on a hook-rewritten request raises `PostModelSwitch`.

## r4 — second confirmation (FATAL(4): 1 BLOCKER, 3 MAJOR): BINDING over r3 where they conflict; the last revision, executor dispatched on it
T1. Two fields, no contradiction: `st.turnModel: string | undefined` is the
    STICKY cur, set ONLY when `decideMain` moved the model (upgrade,
    downgrade or fallback), reset in `endMainTurn` and at `session.end`;
    `st.lastPlan` (the plan actually sent last, breaker target) is KEPT across
    turns and never used as cur. `cur = st.turnModel ?? e.model`. "Keep cur"
    returns `st.turnModel` when set, else `e.model` VERBATIM: an unrouted step
    never re-sends a model the router did not choose this turn, so an
    engine fallback that lands in `e.model` is respected by construction.
    S3's "lastPlan is reset at endMainTurn" is void (S6 stands).
T2. Auto switch marking (S1 refined): on `PostModelSwitch` `source: 'auto'`,
    let `sent = canonical(st.lastPlan?.model)` and `to = canonical(to_model)`.
    If `to === sent` → nothing (the engine landed where the router already
    was, or the router's own rewrite surfaced as a switch). Else the mark
    target is `sent` when it is a table id (the model actually sent), else
    `canonical(from_model)` when THAT is a table id, else nothing. Always
    log `from_model`, `to_model`, `requested_model`. R16 gains: which
    `from_model` the event carries after a router upgrade, and whether a
    router rewrite itself raises an `auto` switch.
T3. `st.sessionModel` is PRESERVED through the `session.end` rebuild (listed
    with `down`, strikes, `agentModels`). `canonical()` never prefix-matches
    an empty string or a string that does not start with `claude-`: both
    map to UNKNOWN (returned unchanged, no table id). The `[1m]` carry reads
    the raw string of the step (`e.model`, or `st.turnModel`), never
    `sessionModel`. `sessionModel` is used by texts only; when it is '' or
    unknown, texts print the engine word `session model` instead of an id.
T4. Tokens: `ctx.tokens: number | undefined` (undefined on a failed or absent
    read). The upgrade cap treats undefined as 0 (upgrade allowed: the targets
    are fable/opus, no window entry); `windowOk` treats undefined as NOT
    fitting (fail closed, as today).
T5. Marks: strikes are per EPISODE (a mark on an id already down adds no
    strike and no log), but a `model_not_found` arriving during a timed hold
    LENGTHENS it to "until reload" (logged once). Auto marks use the same
    episode backoff (15 → 30 → 60 → 120 → 300 min).
T6. S5 race: on an `async_launched` result with `st.pushed === null`, push
    again first (if `turnMain?.source` still allows it), then add the id.
T7. Tests assert hold DURATIONS (minutes until, computed from the mock clock)
    or the presence of the id under `down:`, never a literal `HH:MM`.
    `show` prints `down: <id> for <n> min (<reason>)` (and `until reload`),
    computed from the pruned map and the clock value passed in.
T8. R16 final list (live, orchestrator): StopFailure vs turn.complete order;
    PostModelSwitch on a rewritten-request fallback and its `from_model`;
    whether a router rewrite raises `auto`; `[1m]` carry validity on opus;
    `$.session.model()` string form.
