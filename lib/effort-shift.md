# Route doctrine — phase-level model and effort on the main loop (BDR-107)

Shared include, companion of `lib/model-gate.md`: the gate fixes WHICH model
reflects, the model-router mod (`mods/model-router`) fixes HOW HARD each
phase thinks. Rungs: low (fix a line, run a script) · medium (day-to-day) ·
high (refactor, resisting bug) · xhigh (architecture, audit before
validation) · max (stuck error, judged need).

## The tool

`mcp__model-router__route` (params `phase` | `effort` | `clear`). It is a
deferred tool: when not loaded, run
`ToolSearch("select:mcp__model-router__route")` once per session. A route
applies from the next request on, paired with
another tool call or not (pairing only saves a request). The answer always
names the id and effort main runs on. A skill with a row routes itself on
load; a skill without one changes nothing, the last ROWED skill wins.

## Wiring points

1. Dispatch span starts → `route(phase="orchestrate")`, sent with the
   dispatch.
2. Reflection resumes (challenge synthesis, verdict, plan revision) →
   `route(phase="reflect")` or `"plan"` per the skill's own level; the line
   before every `lib/challenge-plan.md` call.
3. Bookkeeping tail (memory commit, doc commit) → `route(phase="apply")`.
4. Escalation → `route(phase="escalate")`: verify-secure loop caps and
   ship-feature STEP 4b. Not automatic: the challenge fail-safe and "gone
   WRONG → STOP"; their STOP text names the levers below.
5. Built-in judgment dispatch (`general-purpose` `model="opus"`, `model:
   "fable"` skill-runners) → explicit `effort=` on the Agent call (`xhigh`
   for opus reviewers, `high` for fable runners). A main route never
   reaches a child. Typed agents run on their row, never on a shift.
6. After a prose gate that ends the turn, the resumed reflection phase
   starts with its own route call.

## Run slot and levers

A best-tier skill row survives the end of the turn (a run spans prose
gates); `/route clear`, `/route off` and a user `/model` drop it. Levers for a
relaunch: `ultrathink` in the prompt (turn floor) or `/route effort=max`
(sticky, `/route clear` after).
Builtin `/effort` is NOT a lever inside a run: rows and routes outrank it.

`/model <name>` typed, or a pick in the `/model` picker, with a name the
router knows asks the scope (Esc changes nothing). A bare `/model` asks
which model first (fable, opus, sonnet, or
`Other model (native picker)`, which opens the native picker; haiku goes
through it or `/model haiku`), then Standard or `[1m]`, then the same
scope question, the current model included; Esc changes nothing. The
picker's switch is
held first: the engine prints that a hook blocked it, then the question
comes. This project writes the full id as `model` into
`.claude/settings.local.json` (created if absent: keep it gitignored) and
sets a sticky model route. This conversation sets the sticky route only,
nothing written. Everywhere is the native command: user `settings.json`,
every project. The two non-native answers drop the run slot like a native
switch and keep a sticky effort; Everywhere drops an earlier sticky model.
Picker Default, an unknown name or a run with no surface (`-p`)
go native, no question. A native switch (`/config` Model row included)
drops a hand pick. The file is the session root's: in a worktree, that
worktree's.

A model chosen in that dialog (a hand pick) always switches: no cold-read
cap, no `mainUpgrade` or `mainModelSwitch` flag, an unranked session model
included. A pick held down keeps main where it is (one log) until it is
back; the window guard needs a `windows` entry (none shipped). A typed
`/route model=` keeps the caps. `/clear` drops a hand pick until relaunch.

## Limits

- A skill typed while a background agent is live routes only through the
  typed marker (unverified live 2026-10-10).
- Headless (`-p`, SDK) runs the hooks, so routing works there too.
- A plain typed prompt with no route in force is classified by a small
  model: the guessed phase sets the turn's effort and, under
  `mainModelSwitch` and `downgradeMaxTokens` (max cold read, default
  120000), may move main DOWN, never up. A user `/model` only moves the
  baseline the guess starts from (Everywhere; the two other scopes set a
  sticky route, which the classifier never overrides) (`/route classify
  off` to stop guessing; never `-p`).
- Keyword prompt rules (`plan|design|architecture…`,
  `why|review|audit…`), `ultrathink` and a background agent
  dispatch (derived `orchestrate`) set the turn's effort only, never
  a model above the session model: Fable on main comes only from a
  skill row, the `route` tool, a typed `/route` or a hand pick (`/model`,
  picker).
- Mod off: typed agents fall back to their `model:`/`effort:` frontmatter.
- First use of a row asks once, with context (Later, Keep or Change: model,
  then effort, then Everywhere or this project only); the answer is kept in
  `mods/model-router/routing.json`. `/route pending` lists what is still
  unconfirmed, `/route ask off|on` toggles the dialog, `/route forget
  <name|all|projects>` takes a decision back.

Measure the split any time: `python3 ~/.claude/lib/effort-audit.py`
(thinking/output/cache tokens per scope, model and effort).

## Never

- A route inside a dispatched agent: its row rules there.
- Max is for diagnosis, not for retrying the same fix harder.
