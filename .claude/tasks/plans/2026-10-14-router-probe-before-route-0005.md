# Bugfix plan — model-router: probe a move target before routing to it (Fable out of credits)

Branch: bugfix/router-probe-before-route (off develop). Skill: /bugfix.
Revision r3 (r1: correctness FATAL(4), simplicity FATAL(3), robustness
CONCERNS(3) → r2 rebuild; r2 confirmation correctness CONCERNS(3), 0 BLOCKER
→ r3 folds its findings; live engine checks).

## Bug
Fable 5.1 out of usage credits. Router still routes best-tier phases (plan,
reflect, orchestrate, escalate) to `claude-fable-5-1`. Next request dies:
`<synthetic>` message "You're out of usage credits. Run /usage-credits to keep
using Fable 5.1 or /model to switch models.", `apiError:
model_requires_usage_credits`, `error: rate_limit`, HTTP 429. Turn lost.

## Root cause
Availability learned only reactively. Breaker (`markDown`, register.ts
~l.1134) fed solely by `classic.StopFailure` (UNAVAILABLE kinds) and
`PostModelSwitch auto`, i.e. AFTER a real user request died. Nothing checks a
move target before main is sent to it. Hold in-memory, backoff 15→30→60…:
each new session and each hold lapse costs one user turn on a 429.

## Evidence
- Session e2ecb2c1 transcript: 21:31:29 `model_requires_usage_credits` →
  "fable unavailable (rate_limit) for 15 min"; hold lapsed; `route(reflect)`
  answered "model claude-fable-5-1 (upgrade)"; 22:04:34 same error → "for 30
  min". `errorDetails` = generic 429 body ("would exceed your account's rate
  limit"), no credits marker → no cheap typed signal to hold longer.
- LIVE CHECK (scratch mod, `claude -p --plugin-dir`, 2026-10-14):
  `$.model.complete({model:'claude-opus-5-5', prompt:'ok', maxTokens:1})`
  RESOLVED in 1308 ms with an OBJECT `{ isAnswered: true, text, usage }` (not
  the documented string; maxTokens 1 not honored: 43 output tokens).
  Same call on `claude-fable-5-1` (no credits): NO settle after >190 s (still
  pending; the client apparently retries the 429). → for the credits case the
  probe's failure signal IS the timeout. Long run: fable never settled
  within 900 s (killed by timeout, rc 124) → never settles in useful time. `isAnswered:false` never
  observed → NOT used as a failure signal.

## Constraints (in force)
- LRN-207: `rateLimits` = account windows, not per model → no pre-check
  there. Breaker per episode, idempotent while held; `/clear` keeps it.
- BDR-115: explicit Agent params never rewritten (user kept it 2026-10-14);
  explicit `Agent(model:"fable")` pins (client-handover) → TODO residual.
- BDR-116 amendments: `decideMain` = THE single main decision, step and every
  text agree; caps; agents move UP within tier only (`inTier`).
- User 2026-10-14: stand-in effort ONE NOTCH UP; no cross-session persistence.

## Fix plan

### 1. Probe the decided move target, once — `hooks/register.ts`
- Decide FIRST, probe after (closes r1 BLOCKERs: no loop, no explicit-alias
  spin, cur never probed, no probe for a refused move). In `decideFor`:
  `call = decideMain(...)`; if `call.moved` AND `id = canonical(call.model)`
  is a table id AND not in `st.verified` AND NOT `st.down.has(id)` (a hold
  already answers it: an explicit route onto a held id is sent as today,
  never re-probed each step) → `ok = await probeModel($, st, id)`. The BARE
  canonical id is probed (`[1m]` acceptance by complete() unverified; a
  separately gated `[1m]` stays the reactive breaker's job).
  - ok → `verified.add(canonical id)` only if `!st.down.has(id)` at
    resolution (a StopFailure during flight wins).
  - not ok → `markDown($, st, id, 'probe', now)`, then re-run `wantedModel`
    + `decideMain` ONCE, no further probe (a double outage stays the reactive
    breaker's job; an explicit alias/id route re-decides to the same id, as
    "explicit, never skipped" already means).
  - Covers every move kind decideMain makes (upgrade, downgrade, leaveDown
    fallback, windowReturn) and every caller of decideFor: the step
    (`mainPlan`), the route tool's answer (`snapshot`/`mainAnswer`, read by
    the model gate), `/route show`, first-use dialog text, `toastChange`.
- `probeModel`: `$.model.complete({ model, prompt: 'ok', maxTokens: 16 })`
  raced against `PROBE_MS` (8000, next to CLASSIFY_MS) through ONE extracted
  helper `raceTimeout($, promise, ms)` shared with `raceClassify` (classify
  keeps its abort signal; the probe passes NO hook signal: a user Esc must not
  mark a model down). Result:
  - resolved, whatever the shape (documented string or observed object) → ok;
  - TIMEOUT → not ok (the live credits case);
  - rejection → not ok (no typed kinds documented for `complete`).
  - Esc during the probe: the probe completes (no signal), the mark stands,
    but `mainPlan` skips its turn-state writes (`turnModel`, `noteServed`,
    `promptEstimate`, `lastPlan`) when the dispatch signal has aborted.
- State: `verified: Set<string>` in State, kept by `resetSession` (account-
  wide like `down`). `markDown` deletes the id from `verified`. No `probing`
  map, `clearBreaker` leaves `verified` alone (a user `/model` target becomes
  cur, never probed).
- `markDown` logs through `tryLog` (it now runs on the step path; a throwing
  `ui.log` must not unroute the step).
- A lapsed hold leaves the id unverified → the next move to it probes again
  instead of spending a user turn.
- Config key `probe` (bool, default true) in DEFAULT_CONFIG + override
  validation like `classify`, and `/route show` lists it: lets a machine turn
  the probe off without `/route off`. [gated: user approval at the gate]

### 2. Stand-in effort, one notch up — `hooks/register.ts`
- One pure helper computes `standIn` and decideFor returns it on the Verdict
  (step and texts read the same value). COUNTERFACTUAL rule: the bump tracks
  a real stand-in, not the head's availability. True when ALL hold:
  (a) the main model slot's route has a `tier` and the head alias's id is
  held down; (b) `canonical(call.model)` equals the tier's `resolveName` id
  and ranks BELOW the head (fallback rank); (c) with the head treated as
  available, the router WOULD have run it: the classifier ceiling of
  `wantedModel` does not refuse the head, and `decideMain(st, cur, headId,
  read)` lands on the head (upgrade on, cap not blocking, window fits).
  Today: best with fable down → opus, only where fable would have run.
- `mainPlan`: effort = `floored(standIn && !explicit ? notchUp(base) :
  base, floor)`, notchUp on LEVELS, max stays max. Precedence of
  `mainEffort` unchanged.
- Only the phase's own effort is bumped: bump iff the slot that SUPPLIED the
  effort (per `mainEffort`'s `by`: sticky→userMain, turn→turnMain or
  runMain) is the same slot whose route names the tier, that slot carries no
  explicit effort, and the base is a Level (never an engine number). A
  floor-supplied base (`by: 'floor'`) is user-explicit → never bumped. Flag
  `explicitEffort` on `Routed`, set when an effort was given: `parseRoute`
  (`/route`), and the route tool through `Picked` → `applyRoute`. Case to
  keep: `/route effort=low` sticky + plan turn route with fable down → low.
- Main only: agents move up within tier, never get a below-head stand-in.
- Texts: `effortWord` and `mainRoutedText` report the bumped level and why,
  e.g. "effort xhigh (opus stands in for fable)"; the bump is recorded on
  `Step.why` so the verbose transition line names "stand-in" as the effort
  cause. `phasesText` unchanged.

### 3. Tests — `hooks/register.test.ts`
- `boot`: default bottom `on('model.complete', …)` answering success so the
  472 existing tests keep every model available; helpers: `probeHangs(on, id)`
  (never settles; advance the mock clock past PROBE_MS), `probeRejects(on,
  id)`, a call counter.
- New tests (boot on OPUS, so a best-tier route is a move):
  1. plan route, fable probe times out → the step lands on opus/max, exactly
     ONE model.complete call (on fable), no StopFailure, `show` lists fable
     down (probe).
  2. route tool answer with the fable probe failing names opus, never fable.
  3. probe success cached: move to fable, end turn, re-route next turn from
     opus → no second call.
  4. hold lapse (clock +15 min) → re-probe; still failing → fable held 30 min,
     main on opus; no step sent on fable.
  5. bump: reflect stand-in → xhigh; orchestrate → high; `route(phase=reflect,
     effort=high)` → high (explicit); fable available → no bump; classifier
     reflect on an opus session with fable down → no bump (ceiling); upgrade
     off → no bump; `/route effort=low` sticky + plan route, fable down → low;
     an ultrathink floor → max, not bumped past.
  6. a probe rejection → marked down like a timeout; a resolved object or
     string answer → ok.
  7. a StopFailure on fable while its probe is in flight → probe success does
     NOT re-verify it.
  8. `/route fable` (explicit) with the probe failing → ONE probe in total
     across `/route` itself, two consecutive steps and a `/route show`.
  11. Esc during a probe: fable marked down, no stale `turnModel` next turn.
  9. no probe when the move is refused (classifier guess above the session
     model; upgrade off) and none for cur.
  10. `probe: false` in the override → no model.complete call. [if gated in]
- Update the existing tests whose expectations change ('fallback: a rate
  limit on fable moves plan to opus xhigh' → opus max under the bump).
- Suite: `claude plugin test mods/model-router` (472 pass baseline) and
  `make test suite=lib/tests/mods.test.sh`.

## Out of scope / residuals (TODO)
- Explicit `Agent(model:"fable")` pins (client-handover) still fail without
  credits (BDR-115 kept).
- Spawn path not probed: no agent row maps to best; `inTier` only reaches
  fable when opus is also down (double outage → reactive breaker).
- Session model itself out of credits (settings `model: fable`): cur never
  probed, first turn fails reactively.
- No cross-session persistence: with fable out of credits each new session
  pays one PROBE_MS stall (≤8 s) at its first best-tier move.
- A timed-out probe's request keeps retrying in the engine (no cancel param).
- `[1m]` gating: the bare id is probed; a separately gated `[1m]` would pass
  the probe and fail reactively, as today.

## Risk
Medium. ≤8 s stall once per model per session on a failing target; ~1.3 s on
a healthy one. A network blip marks the move target down 15 min (main stays
on its current model: errs toward a working one). Probe spends a tiny
completion when the target IS available.
