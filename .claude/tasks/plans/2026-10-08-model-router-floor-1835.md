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
