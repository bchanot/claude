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
   "opus"` skill-runners) → explicit `effort=` on the Agent call (`xhigh`
   for opus reviewers, `high` for skill-runners). A main route never
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
  a model above the session model: Fable on main comes only from a hand
  pick (`/model`, picker), a typed `/route model=fable`, a phase naming
  `model: fable` or a machine override that puts fable in a tier (no
  shipped tier or phase holds it, BDR-150).
- Mod off: typed agents fall back to their `model:`/`effort:` frontmatter.
- First use of a row asks once, with context (Later, Keep or Change: model,
  then effort, then Everywhere or this project only); the answer is kept in
  `mods/model-router/routing.json`. `/route pending` lists what is still
  unconfirmed, `/route ask off|on` toggles the dialog, `/route ask-tier
  off|on` the ask before a route lifts main or a rowed agent onto Fable
  (inert unless a machine override heads `best` with fable),
  `/route forget <name|all|projects>` takes a decision back.

Measure the split any time: `python3 ~/.claude/lib/effort-audit.py`
(thinking/output/cache tokens per scope, model and effort).

## Advisor

Fable runs as the advisor (settings `advisorModel`), never a route or pin
target (BDR-150). It is a server tool: the router cannot see or refuse it.

Main loop, at least at these points (for work outside them, see the
triggers in CLAUDE.global.md § Workflow):
1. Before settling an approach: on the written plan, before the
   challengers see it (`lib/challenge-plan.md`), at most once per skill run.
2. When stuck: once per verify-secure run, at the first gate loop to fail
   twice (floor, conformity, security, or a second structural failure),
   before re-dispatching or escalating. At a cap the STOP diagnosis
   reuses that advice and says whether it predates the last iteration. The
   advice stays in the main loop: it feeds the main loop's own decision
   (a contract micro-gate, an early escalation, the STOP diagnosis) and
   never enters an executor brief.
3. Before proposing a merge (`gitflow finish`) or calling a long task
   done. Wired at the commit step of feat and bugfix, at the end step
   of ship-feature, init-project, a11y, guardrails, audit-delta and
   tour, and at the release gate of release-candidate: one end-of-run
   call per skill run, never skipped for an earlier plan or stuck call.
   Two skips only: audit-delta and tour when the run applied no fix;
   feat and bugfix when GATE 0 said MET, the verifier CONFORME and
   security PASS (not DEGRADED), each on its first attempt (any other
   verdict, a retry, a loop iteration or a verdict no longer in view
   runs the call), their summary then reading
   `skipped (gates clean on first pass)`. A skipped call discharges
   its point and the trigger it covers. In the six flows that run the
   gates (feat, bugfix, ship-feature, init-project, a11y, guardrails),
   the main loop first prints the run's diff stat, a fix the answer
   drives goes back through the gates, and a later merge proposal
   reuses the last run's answer, or its skip, and names any code commit
   made after it (doc and memory commits excepted). Elsewhere the
   answer is reported only and a fix it calls for is a new run.

Inside a skill run, the points above also cover the triggers of
CLAUDE.global.md § Workflow; no second call for the same recommendation.

Sub-agents, when dispatched: plan-challenger, verifier, security-auditor
and `analyzer` call it at most once per dispatch, before their verdict or
report; executors and every other sub-agent do not, even when the tool is
listed. The analyzer file loaded inline by the main loop follows the
main-loop points.

Advisor absent or erroring (Fable out of credits, for example) → proceed
as written. Advice is input, never consent: it waives no gate, cap or
guard; at a loop cap it feeds the STOP diagnosis.

## Never

- A route inside a dispatched agent: its row rules there.
- Max is for diagnosis, not for retrying the same fix harder.
