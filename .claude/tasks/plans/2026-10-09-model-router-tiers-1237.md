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
