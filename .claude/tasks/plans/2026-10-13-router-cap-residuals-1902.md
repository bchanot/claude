# PLAN — router-cap-residuals (feat, r3: r2 + confirmation CONCERNS(3) closed below)
Contract: .claude/tasks/contracts/2026-10-13-router-cap-residuals-1902.md

## Files
1. mods/model-router/hooks/register.ts
2. mods/model-router/hooks/register.test.ts

## Approach
- (1) Demoted-turn spawn pin, NARROW (`spawnTarget` ~l.2890, `spawnModelCause`,
  `handoffOf` ~l.3160) [BLOCKER: the hook cannot see an agent's frontmatter `model:`;
  `e.model === undefined && route === undefined` is NOT "inherits"]. New const
  `INHERITING_AGENTS: ReadonlySet<string> = new Set(['general-purpose'])` next to
  `PROJECT_SOURCES` (~l.155), comment: "built-in types with no frontmatter model: an
  undefined `model` makes them inherit the spawning loop's model". `spawnTarget`
  rewrites to `st.sessionModel` (verbatim, keeps `[1m]`) ONLY when ALL hold:
  `e.model === undefined && route === undefined`, `!e.fork && e.workflow === undefined`
  (frozen: engine ignores a hook model), `e.parentAgentId === undefined` (main's child:
  `parentModel` IS main's model), `INHERITING_AGENTS.has(e.subagentType)`, `st.offers.get(e.subagentType) === 'built-in'`
  [r3 #1: a repo or user `general-purpose.md` shadowing the built-in may carry a
  frontmatter model; no offer record = deny], `st.turnModel !== undefined` and `ranksAbove(st, canonical(sessionModel),
  canonical(turnModel))` (main sits BELOW the session model: demotion or breaker
  fallback, never an upgrade), session model ranked and not in `st.down`. Else
  `undefined` (today's path). `handoffOf`: the "has a hand-off" condition adds
  `sp.wanted !== undefined`; `spawnModelCause` returns `'session'` when `route ===
  undefined && e.model === undefined && sp.wanted !== undefined`. `shortcut:` comment at
  the allowlist: "the frontmatter model of other types is invisible to the hook; widen
  the set when the engine exposes it on agent.offer".
- (2) Prompt estimate (State, `prompt.submit` ~l.3560, `skill.prompt` ~l.3462,
  `readingFor` ~l.1387, `mainPlan` ~l.3240, `endMainTurn` ~l.3282):
  `State.promptEstimate: { tokens: number; usage: number | undefined; unknown: boolean }
  | null`. `addEstimate(st, text, usage)`: estimate = `Math.ceil(Array.from(text).length
  / 3)`; a pending entry SUMS the tokens and KEEPS the first baseline (`usage`); a fresh
  one takes `usage` = `await readTokens($)` at that moment. `prompt.submit` (any
  origin, mid-turn too): `addEstimate` with `e.text`; if the input carries a
  `document` attachment (check the kit type for the attachments field; if absent in the
  input type, skip this clause and say so in the report) set `unknown = true`.
  `skill.prompt`: `addEstimate` with `e.text` ONLY when the prompt is main's TYPED skill
  (the `typedPath` verdict, exposed from `armTypedSkill` for rowed and unrowed names
  alike; a preload inside an in-flight spawn — `spawning > 0` — adds nothing) [r3 #2],
  called BEFORE `confirmSkill` so the dialog and toast see the body.
  `prompt.submit` also counts the code points of `e.context ?? []` entries (hooks above
  attached them; hooks-below context arrives after `next`, residual) [r3 #6].
  `withEstimate(st, raw): number | undefined` PURE (no mutation): `raw` when
  `raw === undefined || st.promptEstimate === null`; `undefined` (blocked) when
  `est.unknown`; `raw + est.tokens` when `est.usage === undefined || raw − est.usage <
  est.tokens / 2`; else `raw`. Used by BOTH `readingFor` (texts: snapshot,
  mainQuestion, toastChange) and `mainPlan` → step and texts agree.
  `mainPlan`: `const raw = await readTokens($)`; `read = { tokens: withEstimate(st,
  raw), now }` for `decideFor`; `noteServed(st, plan, { tokens: raw, now })` records the
  RAW size (an over-estimate in the record would trip the compaction path); then
  `st.promptEstimate = null` (consumed by the first main step of the turn the prompt
  belongs to). Mid-turn submits (`e.turnId !== undefined`) go to
  `st.pendingEstimate` instead, promoted by `endMainTurn` into `promptEstimate` with the
  baseline reset to `undefined` (the codebase convention for mid-turn input:
  `pendingPrompt`/`pendingSlash`) [r3 #4: whether the engine injects a mid-turn prompt
  into the running turn is unverified; next-turn is the conservative reading]. An
  unconsumed `promptEstimate` at turn end is likewise carried (baseline reset), never
  dropped.
- (3) TTL (`CACHE_TTL_MS` ~l.224, `coldRead` ~l.1188, `SwitchIn` ~l.3325,
  `onModelSwitch`, `resetSession`): `State.cacheTtlMs` initialised to `CACHE_TTL_MS`,
  listed in `resetSession`'s `kept`, untouched by `reloadCommand`. `SwitchIn` gains
  `cache_ttl?: unknown` and `agent_id?: unknown`. `const CACHE_TTLS: Readonly<Record<
  string, number>> = { '5m': 300000, '1h': 3600000 }` (the engine's closed enum);
  `ttlOf(v: unknown)` = `typeof v === 'string' && hasKey(CACHE_TTLS, v) ? CACHE_TTLS[v]
  : undefined`. `onModelSwitch`: when `e.agent_id !== undefined` (a sub-agent's switch)
  do NOT write `sessionModel` nor the TTL (breaker handling unchanged); else `const ttl
  = ttlOf(e.cache_ttl); if (ttl !== undefined) st.cacheTtlMs = ttl` before the
  `st.off` return. `coldRead` compares against `st.cacheTtlMs`. Const comment: "1 h
  default; replaced by the engine's `cache_ttl` at the first model-switch event".
- (4) `switchWord(st)` → `on (downgrade, cap ${st.cfg.downgradeMaxTokens} tokens cold,
  ttl ${Math.round(st.cacheTtlMs / 60000)} min)`; `off (downgrade)` unchanged.

## Edge cases
- Session model unknown (''), unranked or down → no pin, engine decides.
- Upgraded main (haiku session lifted to fable by a plan route) → no pin: the agent
  inherits fable as today.
- Fork / workflow / nested / project-source / non-allowlisted type → untouched.
- Estimate: `readTokens` failing at submit → baseline undefined → added (conservative);
  `tokens` unknown at the step → stays unknown → blocked. Two queued pastes → summed.
  `document` attachment → unknown → every switch blocked that turn.
- Mid-turn submit: consumed by the first main step after it; none follows → carried to
  the next turn, baseline reset.
- A prompt dropped by a later hook leaves a stale estimate for the next step (accepted:
  conservative; residual).
- TTL takes effect only after the first PostModelSwitch event of the process; before it
  the 60 min default holds (residual, named in TODO: no API exposes the account TTL).
- Sub-agent PostModelSwitch events never move `sessionModel` or the TTL.

## Tests (register.test.ts) — contract letters
- Helpers: `typed($, text)` (l.878) / `queued` for prompts, `clearSession` (l.4507) for
  /clear, `usageVar`, `switchTo(from, to, source, cache_ttl = '5m')` (add the optional
  4th param typed `'5m' | '1h'`); `home: { classify: false }` for the estimate tests
  (bootRig has no classify bottom hook).
- Migration: `text: show names the switch and its cap` (~l.5188) expects `switch: on
  (downgrade, cap 120000 tokens cold, ttl 60 min)`. `toast: a downgrade held by the cap
  says so` (~l.5202): `typeFeat` submits `/feat add a thing` (17 code points → estimate
  6) on usage 300000, so the toast now reads `cold read 300006 tokens over 120000`
  (plus the skill body's estimate if `typeFeat` also runs skill.prompt with a body: the
  executor derives the exact figure and states it in the report) [r3 #3].
- `switchTo(from, to, source, cache_ttl = '5m', agent_id?)`; (i) registers a bottom
  `on('session.end', …)` before boot (bootRig has none); (f) uses `queued($,
  'composer', …)` for the mid-turn case and a FRESH rig for the carried case [r3 #7].
- (a) `spawn: general-purpose during a demoted turn starts on the session model`
  (fable rig, route mechanical, step → haiku, spawn general-purpose with `parentModel:
  HAIKU` → bottom gets `model: FABLE`).
- (a) fires `offerOf($, 'general-purpose', 'built-in')` before the spawn [r3 #1].
- (b7) `general-purpose` offered from `projectSettings` (shadowed) → untouched [r3 #1].
- (b) same spawn, no route in force → untouched. (b2) `feater` (rowed) during a demoted
  turn → SONNET (row wins). (b3) `general-purpose` with `fork: true` → untouched. (b4)
  nested: `parentAgentId: 'a1'` → untouched. (b5) a non-allowlisted unrowed type
  (`code-explorer`) → untouched. (b6) haiku session upgraded to fable by a plan route,
  spawn general-purpose → untouched (inherits fable).
- (c) = (b2).
- (d) `cap: a pasted prompt counts before the first step`: `home: { classify: false,
  downgradeMaxTokens: 110000 }`, usageVar 100000, `typed` 60000-code-point text
  (estimate 20000), route implement → refused, log `cold read 120000 tokens over
  110000`.
- (e) `set(110000)` before the step (growth 10000 = half) → nothing added → 110000 ≤
  110000 → SONNET; sibling `set(109999)` (growth 9999 < half) → added → 129999 →
  refused.
- (f) consumed: after (d)'s first step, a second step same turn sees raw (route implement
  at raw 100000 → SONNET); carried: `typed` mid-turn (with `turnId`) then `endTurn`, next
  turn's first step adds it (refused at the 110000 cap with raw 100000).
- (g) `switchTo(FABLE, FABLE, 'command', '5m')`, record 6 min old → cold (refused above
  cap); `switchTo(..., '1h')`, record 59 min old → warm (allowed).
- (h) sub-agent switch event (`agent_id: 'a1'`, `'5m'`) → TTL and `sessionModel`
  unchanged (`/route show` ttl still 60 min).
- (i) `clearSession` keeps a 5 min TTL.
- (j) show: `ttl 60 min` default; `ttl 5 min` after a `'5m'` event.
- (k) `cap: a document attachment blocks the FIRST step's switch` (`attachments: [{
  type: 'document' }]` exists on PromptSubmitInput, d.ts ~7198) — first step blocked,
  second step raw [r3 #7].
- (l) `cap: a typed skill's body counts` (`SkillPromptInput.text`), and (l2) `a preload
  during an in-flight spawn adds nothing` [r3 #2].
- Run: `make test suite=lib/tests/mods.test.sh`.

## Disposition (STEP 0.6)
- honors BDR-116 amendment 2026-10-13 / LRN-216: the record stays RAW and on every main
  step; the cap alone reads the adjusted size; the TTL is one state value `coldRead`
  reads.
- honors BDR-115 (spawn hook sets a model once; explicit `model` wins; an agent moves UP
  from its frontmatter, never below): the pin covers only types with no frontmatter
  model, and only lifts them back to the session model.
- honors LRN-206 (kit: one bottom hook per event): `usageVar`/`switchTo` reuse.

## CHALLENGE SUMMARY (r1 → r2)
- BLOCKER (correctness #1 = robustness #1): frontmatter invisible → allowlist
  `INHERITING_AGENTS` + fork/workflow/nested/project-source guards + tests (b3-b5).
- MAJOR: upgrade sets `turnModel` (c#2, r#3) → `ranksAbove(session, turnModel)` + (b6);
  texts vs step (s#1, c#5, r#10) → pure `withEstimate` in `readingFor`; test (e) values
  (s#5, c#3) → boundary 110000/109999; TTL enum (s#3, c#4, r#8) → two-value lookup, (h)
  rewritten as the sub-agent case; mid-turn estimate dropped at turn end (r#4) → carried
  with baseline reset; served inflation (r#5, c#6) → RAW record; overwrite (r#6) → sum;
  attachments/skill body (r#7, c#9) → unknown flag + skill.prompt estimate; sub-agent
  switch events (r#9) → ignored for sessionModel/TTL; rig names (s#4, c#8) → `typed`,
  `clearSession`, show test migration; `switchWord(st)` (s#6).
- Residuals kept (TODO): TTL known only after the first switch event; a dropped prompt
  leaves a conservative stale estimate; hooks-below `context` not counted; sub-agent auto
  fallback marks main's model down (pre-existing, `onAutoSwitch` targets `lastPlan`);
  LIVE CHECK: does `parentModel` follow the turn.step rewrite or the session model? read
  general-purpose's step-0 `message.model` in a transcript during a demoted turn (if it
  is already the session model, the pin is a no-op) [r3 #5].
- Confirmation pass r2: CONCERNS(3), closed by the [r3 #n] changes above.
- Deferred BLOCKERs: none.
