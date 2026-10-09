# PLAN — model-router wave 1-B1: user effort floor for the turn (dispatch-ready)
Contract: .claude/tasks/contracts/2026-10-08-model-router-floor-1835.md
Code: mods/model-router/hooks/register.ts (read it in full first) and
register.test.ts. API truth: the engine-laid declarations under
mods/model-router/.claude-plugin/types/ (claude-code/index.d.ts,
claude-code-tools/index.d.ts).

## Why
Today the prompt rule (`ultrathink` → escalate) and a typed `/effort-<l>`
share ONE slot (`turnMain`) with the model's `route` calls and the
`Skill(effort-*)` bridge: last writer wins, and a later skill load resets
the slot to the session default. A user's explicit level is therefore lost
mid-turn. The user chose FLOOR semantics: their level is a minimum for the
whole main turn; derived routes may go above it, never below; it also
lifts a lower sticky `/route`.

## Precedence after the change (main loop only)
- model axis (unchanged order, floor last): `userMain ?? turnMain ?? turnFloor`
  route's `model`, applied only with `mainModelSwitch` and the window guard.
- effort axis: `base = (userMain ?? turnMain)?.route.effort ?? e.effort`;
  `effort = floored(base, turnFloor?.route.effort)`.
- `floored(effort, floor)`: no floor → `effort`; `effort` is a Level whose
  LEVELS index ≥ the floor's → `effort`; otherwise (lower Level, a number,
  or undefined) → `floor`.
- The haiku omission (`effort: undefined` when the model sent starts with
  `claude-haiku`) still runs AFTER flooring.
- Sub-agent steps (`e.agentId` set) never read `turnFloor`.

## Changes in register.ts (names as in the current file)
1. `State`: add `turnFloor: Routed | null` with the comment `user-explicit
   level for this turn (prompt rule, typed /effort-<l>): a floor, main loop
   only`; reword the `turnMain` comment to `model route tool, skill table
   row, Skill(effort-*) bridge; dropped at turn end`. `newState`:
   `turnFloor: null`.
2. Helpers (new, small): `const rank = (l: Level): number => LEVELS.indexOf(l)`;
   `function floored(effort: StepIn['effort'], floor: Level | undefined)`
   per the rule above. A helper `floorLevel(st)` returning
   `st.turnFloor?.route.effort` is allowed if it keeps call sites short.
3. `mainPlan`: compute `base` and `effort = floored(base, floorLevel(st))`;
   `wanted = set?.route.model ?? st.turnFloor?.route.model`; the rest
   (switch, window guard) unchanged.
4. `registerPrompt` / `prompt.submit`: the non-queued branch writes
   `st.turnFloor = routed` (instead of `st.turnMain`); the queued branch
   (`e.turnId !== undefined && e.wait`) keeps writing `st.pendingPrompt`.
5. `slashEffort`: write `st.turnFloor = { phase: skill, route: { effort:
   level }, source: 'slash' }`; returned text line becomes `Effort floor
   <level> set by model-router for this turn: nothing below it runs.`
   followed by `\n` + the original text (prepend, never replace).
6. `onSkillLoad` (main branch): `st.turnMain = null` unconditionally (the
   slot no longer holds prompt or slash routes), then the table row as now.
   `turnFloor` is never touched there.
7. `clearRoutes` (`/route clear`): also `st.turnFloor = null`.
   `clearLoop` (model `route({clear})`, main branch): `turnMain` only, as now.
8. `endMainTurn`: `st.turnFloor = st.pendingPrompt; st.pendingPrompt =
   null; st.turnMain = null;` then the existing resets.
9. Truthful answers (main branch only; agent branches unchanged):
   - `effortBridge`: keep the sticky sentence when `st.userMain` is set;
     else when the floor ranks above `level`: `model-router: <skill>
     recorded, but the user's floor <f> for this turn keeps main at <f>;
     the <skill> skill text was not loaded.`; else the current sentence.
   - `routedText`: keep the sticky branch; else when `p.route.effort` is
     set and the floor ranks above it, print the effort as `<f> (user
     floor; asked <asked>)`.
10. Display: `mainText` appends ` · floor <f> (<phase>)` when `turnFloor` is
    set (also after `main: session defaults`); `statusLine` appends
    ` · floor <f>`.

## Tests in register.test.ts (keep every existing test; adapt only what
the new slot changes, e.g. the `ultrathink` test now expects the floor on
the `main:` line). Add at least six tests whose names contain `floor`,
using the existing boot helper, full typed inputs and bottom hooks, and
asserting on the `main:` line or on what the bottom `turn.step` hook
receives (drain the stream with `for await`, then `.result`):
- `floor: ultrathink survives a model route` — prompt `ultrathink`
  (composer, `wait: false`, no `turnId`) then route tool `orchestrate` →
  a main step with engine effort `high` reaches the bottom at `max`.
- `floor: a typed /effort-medium floors a lower route and allows a higher
  one` — `$.skill.prompt({ skill: 'effort-medium', text: 'x' })` (no Skill
  call in flight) → route tool `mechanical` → main step at `medium`;
  then route tool `escalate` → main step at `max`.
- `floor: survives a skill load` — ultrathink, route tool `orchestrate`,
  then a non-effort `Skill` call (bottom `tool.call` hook registered) →
  main step at `max`, and `main:` line no longer names `orchestrate`.
- `floor: lifts a lower sticky route, then ends with the turn` — `/route
  effort=low` then ultrathink → main step at `max`; fire a main
  `turn.complete` → next main step at `low`.
- `floor: main only` — ultrathink, spawn `Explore` (bottom `agent.spawn`
  hook returning an `agentId`), then a step for that `agentId` → reaches
  the bottom at `medium`, not `max`.
- `floor: /route clear removes it` — ultrathink, `/route clear` → main
  step keeps the engine effort.
Optional seventh: the bridge context line names the floor when it wins.

## Constraints
- Style: ≤ 25 logic lines per function, 80 chars per line, no `any`, no
  module-level mutable state, doc comments state intent.
- Do not touch: the agent axis, the spawn table, config loading, the
  hardening (caps, warnOnce, safely), the route tool schema.
- Verify (paste outputs): `claude plugin validate .`, the contract's tsc
  command, `claude plugin test .`, then from the repo root
  `bash ~/.claude/lib/gates.sh run .claude/tasks/contracts/2026-10-08-model-router-floor-1835.md`.

## Disposition
- honors BDR-115 (one writer per axis, calling-loop writes, truthful
  answers) and the wave plan's routing rule (explicit user choice beats the
  derived phase); supersedes the 1-A contract's one-slot precedence for
  prompt and slash sources.
- LRN-206 (kit facts) applies to every new test.

## r2 — challenge round (3 lenses, 0 BLOCKER, 4 MAJOR): BINDING, overrides the sections above where they conflict
R1. ONE decision helper, used by `mainPlan` AND by every answer text:
    `mainEffort(st, engine: StepIn['effort'])` → `{ effort, by }` with
    `by` ∈ `'floor' | 'sticky' | 'turn' | 'engine'`.
    `base = (st.userMain ?? st.turnMain)?.route.effort
            ?? st.turnFloor?.route.effort ?? engine`
    `effort = floored(base, st.turnFloor?.route.effort)`; `by = 'floor'`
    when the floor raised or supplied the value, else the slot it came from.
    The user's level is therefore BOTH the turn's default (when no sticky
    or turn route names an effort) AND its minimum: a typed `/effort-low`
    lowers a turn that has no route (engine `high` → `low`), and a route
    can still go higher. No text function compares ranks on its own.
R2. Model axis, one rule written once (contract updated):
    `st.userMain?.route.model ?? st.turnMain?.route.model ?? st.turnFloor?.route.model`,
    switch and window guard unchanged.
R3. Prompt rule with `e.turnId !== undefined` (typed while a turn runs;
    `wait` is IGNORED: the engine queues every mid-turn prompt either way):
    write the floor NOW (higher of the existing floor and the new one)
    AND set `pendingPrompt` to it, so the turn that reads the prompt has it
    whichever it is. No `turnId` → write the floor (higher of two).
    `endMainTurn` promotes `pendingPrompt` into `turnFloor`. Two floors in
    one turn always keep the higher one (prompt rule and typed slash).
R4. Truthful texts, all phrased from `mainEffort` (main branch only):
    - Skill bridge, route tool, typed `/effort-<l>`: when `by === 'floor'`
      and the result differs from what was asked, name the floor and its
      source (`ultrathink rule` or `typed /effort-<l>`) and add
      `/route clear to drop it`; when `by === 'sticky'`, the sticky
      sentence; the old fixed "sticky wins" sentences go.
    - `/effort-<l>` text: `Effort <l> set by model-router for the main loop
      this turn (minimum; a higher route still applies).` plus the floor
      or sticky outcome when one changes it.
    - main loop on a haiku model: print `effort - (haiku takes none)`.
    - model `route({clear})` on main with a floor set: append `; user floor
      <f> (<source>) still holds — /route clear drops it`.
R5. Display: `mainText` / `statusLine` show ` · floor <f>` only when the
    floor carries an effort AND the router is on; the `skill.prompt` hook
    calls `refresh($, st)` after the slash write.
R6. Persistent per-machine off switch (wiring challenge, user's "configurable"):
    config key `enabled: boolean` (default `true`) in
    `~/.claude/model-router.json` (untracked, per machine). `false` →
    `st.off = true` after every config load (session start, `/route
    reload`); `/route on` re-enables for the session only; `show` and the
    status line say `off (config)` vs `off`. Merged with `pickBool` like
    the other scalars; `DEFAULT_CONFIG.enabled = true`.
R7. Tests (replace the list above where it differs): `runStep` takes a
    full `TurnStepInput` (from 'claude-code'); every floor test steps with
    engine effort `high` (or `xhigh`); every `test('…', async (` line ≤ 80
    chars with `floor` in the single-line name. At least 8 floor tests:
    ultrathink survives a model route · typed /effort-medium clamps low,
    lets max pass · typed /effort-low lowers an unrouted turn (engine high
    → low) · survives a skill load · lifts a lower sticky then ends with
    the turn · main only (agent step unaffected) · /route clear removes it
    · mid-turn prompt (turnId + wait) is applied now AND promoted after the
    main turn.complete · mandatory text test: sticky `/route effort=low`,
    ultrathink, route tool `plan` → the answer names the floor.
    `enabled: false` cannot be reached in the kit (no fs, LRN-206): cover
    the off path through `/route off` and say so in a comment.
R8. Residuals accepted (logged in TODO, not built): floor expiry depends on
    a main `turn.complete` reaching this mod (another plugin answering it
    without `next` would keep it); `skill.prompt` cannot tell a typed
    `/effort-<l>` from a sub-agent preload (no agentId; no repo agent
    preloads one); an incidental "ultrathink" in pasted text floors the
    turn (mitigated by R4 naming the source and the `/route clear` hint).
