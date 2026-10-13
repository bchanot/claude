# PLAN — router-downgrade-cap (feat, r3: r2 + confirmation pass FATAL(7) → 1 BLOCKER + 6 MAJOR closed by the named changes below)
Contract: .claude/tasks/contracts/2026-10-13-router-downgrade-cap-0013.md

## Files
1. mods/model-router/hooks/register.ts
2. mods/model-router/hooks/register.test.ts
3. lib/effort-shift.md

## Core change of r2 — the cap bounds the COLD READ, not the context size
LRN-204: a switch INTO a model costs the tokens that model's prompt cache does not
hold; within the 1 h TTL its cache holds the prefix up to its last main step. So the
cost of moving main to model M at a context of T tokens is
`coldRead(M) = T − servedTokens(M)` when M served main within the TTL, else `T`.
r1 compared T itself to the cap, which (correctness #1) refused the cheap re-down to a
warm Sonnet and forced a cold read on Fable instead. r2 compares `coldRead`.

## Approach
- Config (`register.ts` Config type ~l.30-37, DEFAULT_CONFIG ~l.217-275, mergeRouting
  ~l.512-537): `downgradeMaxTokens: number` next to `upgradeMaxTokens` in `Config`,
  `Routing` and `mergeRouting` (`pickPositive(user.downgradeMaxTokens,
  base.downgradeMaxTokens, 'downgradeMaxTokens', log)`); default `120000`, comment
  "max cold read a downgrade may cost (LRN-204)". `upgradeMaxTokens` comment becomes
  "max cold read an upgrade may cost". `mainModelSwitch: true`, merged FAIL-CLOSED like `pickEnabled` (~l.505-510): a
  non-boolean override logs `model-router: config "mainModelSwitch" is not a boolean;
  switch off` and reads as `false` [r3 #5: `pickSwitch` falls back to the seeded
  default, which is now `true`].
- Served record (State ~l.80-100, `mainPlan` ~l.3052) [r3, BLOCKER #1 / #6 / #12]:
  `served: Map<string, { at: number; tokens: number }>` keyed by the canonical id main
  was sent (`plan.model`). `mainPlan` reads `tokens` (`readTokens`) and `now`
  (`$.clock.now()`) on EVERY main step, routed or not, and records
  `served.set(canonical(plan.model), { at: now, tokens })` after the decision, whatever
  the routing — an unrouted step on the session model is exactly the one that keeps
  that model warm. Texts (`snapshot`, `toastChange`) keep the lazy read. `served` is
  NOT in `resetSession`'s kept list (`/clear` starts cold) and is cleared by `/route
  reload` next to the breaker marks (~l.1099-1108). Const `CACHE_TTL_MS = 60 * 60000`
  next to `CLASSIFY_*`, comment: "the account's prompt-cache TTL (1 h here; an
  engine-reported `cache_ttl` would supersede it — TODO)". `decideFor($, st, cur,
  tokens?, now?)` takes the values when the caller has them and reads them itself
  otherwise; it returns `{ call, wanted }` as today. `capSaid` is set/cleared in
  `mainPlan` from the returned call (a text run never mutates it).
  Compaction / history rewrite [#6]: in `coldRead`, when `tokens < entry.tokens` the
  entry is stale → drop it and return `tokens` (cold).
- One cap helper replaces `capBlock` (~l.1143-1147): `coldBlock(st, id, tokens, max,
  now)` → `undefined` when `tokens !== undefined && coldRead ≤ max`; else the reason
  `'context size unknown'` or `` `cold read ${cold} tokens over ${max}` ``.
  `coldRead(st, id, tokens, now)` = `tokens − entry.tokens` when `served.get(canonical
  id)` exists and `now − entry.at ≤ CACHE_TTL_MS` (floored at 0), else `tokens`.
  `decideFor` receives `tokens`/`now` from `mainPlan` (texts read them lazily, as today).
- `upgradeCall` (~l.1177-1192): `coldBlock(…, st.cfg.upgradeMaxTokens)` in place of
  `capBlock`; same `keep(cur, why, 'model-router: upgrade skipped: …')`, `logKey
  'upgrade-skipped'`. `leaveDown` (~l.1160-1175) uses the same helper for `upOk`.
  NO return bypass (simplicity #1, correctness #1/#5, robustness #4-#6): a return to a
  warm model has a small cold read and passes by itself; turn end restores `e.model`.
- `downgradeCall` (~l.1196-1205): `switch off` refusal first (text unchanged), then
  `coldBlock(…, st.cfg.downgradeMaxTokens)` → `skipped(cur, 'downgrade', block)` with
  `logKey 'downgrade-skipped'`, then `fits`, then `moveTo`. One shared `skipped(cur,
  kind, block)` builds both skip calls (upgrade too).
- Log spam (robustness #8): `downgrade-skipped` is said once per session until a
  downgrade next succeeds: `st.capSaid: boolean`, set in `mainPlan` when the returned
  call is a downgrade skip (log suppressed while set), cleared in `mainPlan` when the
  returned call is `why === 'downgrade'`; the per-turn `turnLogged` dedupe stays for
  the upgrade.
- `[1m]` carry (robustness #6): `moveTo` keeps `[1m]` from `cur`; after a haiku hop
  `cur` has none. Change `moveTo(cur, target, why, session)` to carry `[1m]` when
  EITHER `cur` or `st.sessionModel` has it (and the target is not haiku); all callers
  pass `st.sessionModel`.
- Window re-check (robustness #2) [r3 #10]: in `decideMain`, after the `unknownCall`
  check: when `st.turnModel !== undefined`, `tokens !== undefined`, `!fits(st, id,
  tokens)`, and the session model is a known ranked id, not down and not haiku → `moveTo
  (cur, canonical(st.sessionModel), 'window', st.sessionModel)` with a once-log
  `model-router: context outgrew <id>: back to <session model>`; any guard failing →
  fall through to the normal decision. Only `windows` entries (haiku) can trigger it.
- Classifier model axis, DOWNGRADES ONLY under the switch (correctness #2, simplicity
  #3, robustness #3) [r3 #3 / #4 / #9]: `routeFromLabel` (~l.3531-3541) writes `route:
  { ...phaseRoute(st.cfg, phase) }` (tier + effort). `mainModel` becomes
  `mainModelSlot(st): Routed | null` = the FIRST slot (userMain, turnMain, runMain,
  turnFloor) whose route carries a model name; `decideFor` resolves the name from it.
  Two rules on that slot when `slot.source === 'classifier'`: (i) a floor with a model
  name wins over it (`turnFloor` route name used instead: `ultrathink` mid-turn still
  reaches fable/max); (ii) the resolved `wanted` is dropped (`undefined`) when it
  `ranksAbove` the SESSION model (`canonical(st.sessionModel)`), never compared to
  `cur` — so a guess never moves main above the user's baseline, while a breaker
  fallback from a guessed sonnet to opus (below fable) still works and never falls to
  haiku. Texts and step agree (both go through `decideFor`). Existing test l.4568
  (sonnet session, design guess → sonnet) holds; rename it `…never moves UP`.
- Classifier vs a user `/effort` (simplicity #2, correctness #6/#7, robustness #9) [r3
  #7]: `engineBase` becomes per turn: `noteEngineBase` records the engine effort of
  THIS turn's first main step, compared against the previous turn's value
  (`st.engineBase` holds the last turn's, `st.turnEngine` this turn's; at turn end
  `engineBase = turnEngine`). `userMovedEffort` = this turn's engine effort differs
  from the previous turn's: a `/effort` typed between turns. In `mainPlan`, before
  `mainEffort`: `if (userMovedEffort(st, e)) st.turnMain = null` when `turnMain.source
  === 'classifier'` — the guess is dropped on both axes for THIS turn only; `turnModel`
  is NOT touched (no return without a cold-read check; turn end restores `e.model`).
  The `skipTurn` parameter of `mainEffort` (~l.1302) goes away. The next classified
  turn routes again from the new baseline effort.
- User `/model` (correctness #3, robustness #3): NO suspension. A user `/model` sets
  the new baseline (`sessionModel`) and the classifier keeps routing from it; `/route
  classify off` or `/route off` pins the model. The r1 disposition claim is struck; the
  trade-off goes into the BDR amendment and the doctrine line.
- Helper skills inside a run (robustness #1): `routeMainBySkill(st, skill, row,
  typed)`: when `!typed && st.runMain !== null` and the row's tier ranks below the
  run's (rank through `resolveRoute` → `modelRank`, so a phase naming a model is ranked
  too [r3 #15]), write
  `route: { effort: row.route.effort }` only — a model-loaded helper (e.g.
  `using-git-worktrees` inside `/feat`) moves effort, never the orchestrator's model.
  Typed skills and best-tier rows unchanged. Test l.1130 keeps `skill mechanical` in
  the status and gains `expect((await stepOn(…)).model).toBe(FABLE)`.
- Toast hint (correctness #6) [r3 #11]: `skipped(cur, kind, block)` sets `call.why =
  `${kind} skipped: ${block}`` (the bare block text is never the `why`) and `call.log =
  'model-router: ' + why`; `downgradeHeld` matches `why === 'switch off'` OR
  `why.startsWith('downgrade skipped')`; hint: switch → unchanged text; cap → `, held:
  <why>`. Test (m) covers the cap hint.
- Texts (`show` ~l.1463, `statusLine` ~l.1475): `switch: on (downgrade, cap 120000
  tokens cold)` / `switch: off (downgrade)`; status line [gated 2026-10-13]: ` · switch
  off` only when off, the ` · switch on` fragment is dropped.
- In-file comments (correctness #9): rewrite l.3438-3441 ("never a model move"),
  l.3535 and l.3546 to the new rule (effort + a downward tier under the switch and the
  cold-read cap).
- Doctrine (`lib/effort-shift.md` Limits bullet): "A plain typed prompt with no route
  in force is classified by a small model: the guessed phase sets the turn's effort
  and, under `mainModelSwitch` and `downgradeMaxTokens` (max cold read, default
  120000), may move main DOWN, never up; a user `/model` only moves the baseline the
  guess starts from (`/route classify off` to stop guessing; never `-p`)."

## Edge cases
- Context size unknown: both caps block, logged once (upgrade per turn, downgrade per
  cap crossing); the window re-check does not fire on an unknown size.
- Compaction (`tokens` below a served entry): that entry is stale, the move is cold.
- TTL (60 min const) is an assumption of this account's cache; residual in TODO.
- Target down (breaker): `resolveName` yields the first available alias; a guessed route
  ranks against the session model, so its fallback stays between sonnet and fable.
- Main already down, context grows past the downgrade cap mid-turn: `wanted` unchanged
  → keep; a best route later moves up (cold read of Fable = delta since its last step,
  usually under 200k); no re-down unless Sonnet's cold read fits — which it does while
  Sonnet is warm. Turn end resets `turnModel`; next turn starts on `e.model`.
- Haiku on main and the context passes 200k: window re-check returns main to the
  session model.
- `/route switch off`: identical to today (refusal text `switch off`).
- Classifier `chat`/unknown: nothing written.
- Non-best session (`/model opus`): coding guess → sonnet (downgrade); design guess →
  stays opus (never up by a guess); prompt RULES still upgrade as today.
- Unrowed sub-agent with no explicit model spawned during a demoted turn may inherit
  the demoted `parentModel` (robustness #10): accepted residual, all repo agents are
  rowed and built-ins carry `model=`; logged in TODO.
- `session.usage().context.tokens` may lag the new prompt (robustness #11): accepted,
  the cap is an economic guard, not a hard limit; logged in TODO.

## Tests (register.test.ts) — contract letters
- Rig: add `usageVar(on, initial)` returning `{ set(n) }` over ONE bottom
  `session.usage` hook with a mutable count (never a second `on('session.usage')`);
  `bootRig` gains an optional `usage` handle or a sibling `bootRigVar`.
- Re-expressed (default flip), never weakened: l.305-315 (`/route model: alias
  resolved…` → `switch off` first), l.605-614 and l.1665-1672 (toggle survival →
  `switch off` / `switch: off`), l.747 (`switch off` first), l.754 (drop the `switch on`
  line: default proves it), l.951-958 (`show reflects /model opus` → `switch off`
  first), l.2934-2943 (toast: `switch off` first, hint text unchanged), l.4576 (`route
  carries no tier` → `carries the tier`), l.4783-4799 (`classify guard: a route landing
  during the call wins` → `switch off` first [r3 #8]), every status-line assertion on
  ` · switch on` (grep) → asserts the fragment is ABSENT by default and present as
  ` · switch off` after `switch off`. `bootCls` gains a `tokens` option (ClsOpts) for (f)
  [r3 #13].
- (a) `cap: a downgrade under the cold-read cap moves main` (fable, 1000 tokens, route
  mechanical → haiku, no `switch on`).
- (b) `cap: a downgrade above the cold-read cap keeps main` (fable, 300000, route
  mechanical → `{ model: FABLE, effort: 'low' }`, log contains `downgrade skipped: cold
  read 300000 tokens over 120000`); second step same turn: no second log line.
- (c) `cap: unknown usage blocks the downgrade` (tokens null).
- (d) `cap: a warm model is cheap to return to, a cold one is capped` [r3 #2] — rig
  with `usageVar` at 100000: route implement, step → SONNET (served sonnet@100000);
  `endTurn`; step on FABLE unrouted → FABLE (served fable@100000, the unrouted write);
  `endTurn`; `set(210000)`; route implement, step → SONNET (moved from FABLE: cold read
  110000 ≤ 120000 although the context is 210000); `endTurn`; CONTROL: route judge
  (opus, never served, ranks below fable), step → FABLE kept, log contains `downgrade
  skipped: cold read 210000 tokens over 120000`.
- (e) `classify: coding moves main to sonnet medium under the cap` (fable, 1000).
- (f) `classify: coding above the cap keeps fable at medium` (fable, 300000).
- (g) `downgrade: switch off keeps today's behavior` (= l.747 re-expressed).
- (h) `classify: a user /effort drops the model guess too` (step effort ≠ engine base →
  FABLE at the step's effort, `/route show` agrees: `session defaults`).
- (i) `classify: a design guess never moves a sonnet session up` (= l.4568 renamed).
- (j) `run slot: a model-loaded helper skill moves effort only` (= l.1130 extended).
- (k) `window: haiku outgrown returns main to the session model` (route mechanical on
  fable at 1000 → haiku; `set(250000)`; next step → FABLE, log once).
- (l) `config: a quoted "false" mainModelSwitch reads as off with a warning` (`/route
  show` contains `switch: off`) [r3 #5].
- (m) `toast: a downgrade held by the cap says so` (`, held: downgrade skipped: cold
  read …`) [r3 #11].
- (n) `cap: the served record expires after the TTL` (clock advanced 61 min: cold =
  whole context, downgrade above cap refused) [r3 #13].
- (o) `cap: /route reload forgets the served record`; `cap: the skip line is said once
  until a downgrade succeeds` (two turns above cap → one line; a downgrade under cap on
  a later turn; above cap again → one new line) [r3 #13].
- (p) `cap: a smaller context than the record is cold` (set(50000) after served@100000
  → downgrade to a never-served model refused only if 50000 > cap; use cap override
  `downgradeMaxTokens: 40000` in `home` → refused, entry dropped) [r3 #6].
- (q) `classify: a mid-turn ultrathink floor still reaches fable max` (classifier coding
  → sonnet; mid-turn prompt `ultrathink` → next step FABLE/max) [r3 #4].
- (r) `classify: a guessed sonnet rate-limited falls to opus, never haiku` (coding →
  sonnet; `failWith('rate_limit')` → next step OPUS) [r3 #3].
- (s) `classify: a user /effort drops the guess for one turn only` (turn 1 engine effort
  high = base; turn 2 engine effort low (user /effort) → guess dropped, FABLE; turn 3
  engine effort low → coding guess routes again → SONNET) [r3 #7].
- Run: `make test suite=lib/tests/mods.test.sh`.

## Disposition (STEP 0.6)
- honors BDR-115 (one writer per axis, full ids): cap and served record live in
  `decideMain`'s path, the only writer of main's model; full ids only.
- honors LRN-204 (cold read per switch INTO a model, warm return): the cap measures
  exactly that quantity; no bypass needed.
- supersedes one clause of BDR-116 amendment W4-B ("EFFORT ONLY: main model never
  moves on a guess") by user decision 2026-10-13, DOWN only, under the switch and the
  cold-read cap; the `/effort` guard stays (route dropped on both axes); the `/model`
  guard is NOT kept (baseline moves, guess follows) — stated trade-off for the BDR.
- honors BDR-107 effort rungs: no effort value changes.

## CHALLENGE SUMMARY (r1 → r2 → r3)
- correctness #1 / simplicity #1 / robustness #4-#6 → cold-read cap + served record,
  bypass dropped. correctness #2 / simplicity #3 / robustness #3 → downgrades only.
  correctness #3 → claim struck, trade-off surfaced. correctness #4 / simplicity #6 →
  full test list, letters aligned. simplicity #2 / correctness #6-#7 / robustness #9 →
  drop the guessed route on both axes in `mainPlan`. simplicity #4 → one `coldBlock`.
  simplicity #5 → moot. robustness #1 → helper-skill effort-only inside a run.
  robustness #2 → window re-check. robustness #7 → pickSwitch. robustness #8 → once per
  cap crossing. robustness #10/#11 → accepted residuals (TODO). correctness #9 →
  comments + USAGE.md/README to STEP 6.
- Confirmation pass (r2, FATAL(7)): BLOCKER #1 → served written on EVERY main step
  (tokens + clock read per step). #2 → test (d) with `endTurn` between legs. #3 → guess
  ranked against the session model. #4 → floor model wins over a guess. #5 → fail-closed
  switch picker. #6 → stale entry = cold, `served` not kept across /clear. #7 →
  per-turn `engineBase`, no `turnModel` reset. #8/#13 → tests added. #9 → slot-sourced
  predicate. #10 → window re-check guards. #11 → `why` pinned through `skipped()`. #12 →
  `capSaid` in `mainPlan`. #14 → TTL const + TODO. #15 → rank via `resolveRoute`.
- Deferred BLOCKERs: none. Re-challenge budget consumed (1 extra pass); verifier and
  security gates follow.
