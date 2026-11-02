# CONTRACT — router-ask-tier
- date: 2026-11-02 | flow: feat | branch: feature/router-ask-tier (to be started off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
/feat « model-router : demander avant de router vers Fable ». La spécification est l'entrée en tête du TODO :
- clé askTier, `/route ask-tier on|off` ;
- une question par span, avec la raison (phase et about, origine) ;
- options : Fable, Opus à la place, ne plus demander cette session ;
- jamais de question en -p.

(user, 2026-11-02, step 2 of the session brief. The TODO entry it points at, `.claude/tasks/TODO.md` line 73 at develop 3cc4e0d:)
- [ ] **model-router: ask before routing to Fable** (user ask 2026-11-02, after the phase 5 merge: both touch `mods/model-router/routing.json`). `/feat` on the mod: a `routing.json` key `askTier` (default `best`; `/route ask-tier on|off`) makes the router ask, once per span, BEFORE applying a route whose resolved model sits in that tier, with the reason (phase + its `about`, origin: skill row / `/route` / prompt rule / agent row) and the options `Fable` · `Opus instead (big tier)` · `stop asking this session`; no memory in `confirmed` (the existing first-use confirmation stays as is); never asks in `-p` (`askOr` already falls back to LATER). Files: mods/model-router/hooks/register.ts (+ register.test.ts), routing.json, USAGE.md (`/route` section).

Session constraints (same brief): default model opus; verifier, security-auditor and plan-challengers pinned on opus; never commit a `/model` or UI write of settings.json (LRN-253); plan text through Write/Edit, never a nested heredoc (BLK-039).

## CLARIFICATIONS
Pass A (gaps): none blocking — outcome, scope and constraints are in the TODO entry. Facts verified in the code before the plan:
- "resolved model sits in that tier": `best` = [fable, opus, sonnet] (DEFAULT_CONFIG.tiers), so opus also "sits in" best. Read as: the resolved model is the HEAD of the `askTier` tier (`tiers[askTier][0]`, fable), and the loop or agent is not on it already.
- prompt rules write effort-only routes (BLK-032 / 786ee13): they never resolve a model, so that origin never asks today; the plan keeps the origin word for a rule that would one day carry a tier.
- `askOr` returns LATER on a rejected `$.ui.ask` (headless `-p`, no surface, dismissed dialog): the plan maps LATER to "apply the route as today" (fable), nothing blocked.
Pass B `[gated 2026-11-02]` (user: "défauts partout", plan r3 § Pass B): A. a dismissed dialog (Esc / free text) runs the span on Fable and is not asked again in that span; B. a best-tier skill the model loads on main asks too (skill row, BDR-123); C. sub-agents: one answer per agent type per session; F. held-head residual accepted (no question when Fable is held or the cold read is over the cap at the route event; a later lapse of the hold upgrades main unasked, today's breaker behaviour, documented in USAGE); D. "Opus instead" runs the phase's own effort; E. `askTier` accepts `best` or `false` only. Plan r3 approved for dispatch.
Executor deviations `[gated 2026-11-02, internal, orchestrator]`: (1) the invalid-`askTier` log is emitted by `warnAskTier(st, log)` from `applyLoaded`, deduped through `st.logged` (buildMemory has no state; AC1 "once per session" holds); (2) the derived `orchestrate` route (`pushOrchestrate`) inherits the span's `tierChoice` like any same-run helper slot, so a dispatch after "Opus instead" never lifts main unasked; (3) `inheritedChoice` takes the first of [turnMain, runMain] holding a choice for the same tier (a choice-less derived slot does not hide the run's); `failOnce` shares a `logOnce` helper with `tierFailOnce`; `routedTo` is `phaseWord` plus its prefix.

## ACCEPTANCE CRITERIA
1. `routing.json` carries a top-level `askTier` key (shipped value `"best"`), serialized after `ask` (ROUTING_ORDER); the machine override `~/.claude/model-router.json` `askTier` wins over it like `ask`; accepted values `"best"` and `false` (r2: other tier names are out of scope, the option labels are the user's exact words); an absent key reads `best` silently, a missing or unreadable routing.json reads off, any other value is logged once per session and read as `best` (asking is the safe side).
   CHECK: cd /home/bchanot/Documents/claude && jq -e '.askTier == "best"' mods/model-router/routing.json >/dev/null && grep -q "'ask', 'askTier'" mods/model-router/hooks/register.ts && echo ASKTIER-KEY-OK
   EXPECT: ASKTIER-KEY-OK
   EVIDENCE: MET exit=0 marker-found :: ASKTIER-KEY-OK
2. Main loop: when a route is set on main by a rowed skill (typed, or loaded by the model through the Skill tool), a main-loop `route` tool call with a phase, or a typed `/route <phase>`, and the real decision (`decideMain`, as `snapshot` reads it) would move the main loop onto the head model of the `askTier` tier from a model that is not it, one `$.ui.ask` opens BEFORE the route takes effect at the next step (for `/route`, the sticky slot is assigned only after the answer), with: the origin (`Skill /<name>`, `Route tool`, `/route`), the phase and its `about` line, the head id and the effort the step would run; options exactly `Fable`, `Opus instead (big tier)`, `Stop asking this session` (the second dropped when opus is marked down: the label must be true when answered). No question when the decision would not land on the head (`mainUpgrade` off, cold-read cap, window, held head), when the slot is not the effective one (a sticky route outranks it), when the route names an explicit model (`/route model=…`, `/model` hand picks), from the prompt classifier, or when `$.session.surfaces()` is empty (headless, `-p`).
3. Answers: `Fable` applies the route as today. `Opus instead (big tier)` makes the span resolve through the `big` tier minus the head (opus; sonnet only as the mid-span fallback when opus goes down later; the head only when nothing else is up) at the phase's own effort (no stand-in notch); the choice is a tier name on the slot (`Routed.tierChoice`), stamped on the turn slot AND the run slot the event armed and inherited by every later main route of that run that names the same tier (a work or cheap route never inherits it; a typed rowed skill opens a new span and asks again), so a run asks once and survives the turn end; `/route show` names the choice. `Stop asking this session` silences the ask until the session ends (`resetSession`; `/clear` re-arms), nothing written. A dismissed dialog or a free-text answer applies the route as today and stamps the span (not asked again in that span); an answer arriving after `$.session.id()` changed is dropped.
4. Sub-agents: a rowed spawn from main (no explicit `model`, not inside an agent, not a fork or workflow) whose resolved target is the head model asks the same question with origin `Agent <type>`, once per agent type per session (`State.tierSpawn`, cleared with the session); `Opus instead (big tier)` spawns it on the first non-head model of `big` that is up (resolved at each spawn); the first-use dialog, when it fires on the same spawn, runs first and the tier ask runs whatever it returned. Never inside an agent, never headless.
5. One dialog at a time: the ask holds the existing `asking` slot; a concurrent use finds it set and routes unasked (fable), like the first-use dialog.
6. `/route ask-tier on|off` writes `askTier` (`"best"` / `false`) into routing.json through `writeRouting` (serialized, capped, refused when the file is missing), answers `ask-tier on|off` with the override note when the machine file wins; any other argument answers `usage: /route ask-tier on|off`; `/route show` prints `ask-tier: best|off` plus ` (paused this session)` after a Stop answer; the `/route` argument hint names `ask-tier on|off`.
7. Nothing is written to `confirmed`, `changed` or `projects` by this dialog; `/route pending` and the first-use dialog are unchanged (their tests stay green).
8. Tests in `mods/model-router/hooks/register.test.ts` (fixture default `askTier: false`, opt-in per test like `ask`) cover the plan's D7 list: question text and exact options on a typed skill from an opus session; `Fable` → fable; `Opus instead` → opus at the phase effort, no second ask on a later route-tool call, still opus after the turn end; `Stop asking` → silent + `show` paused; already on fable → no ask; headless (no surface) → no ask; dismissed → fable, span not re-asked; route tool main asks, `agentId` does not; `/route plan` asks and assigns after the answer, `/route model=fable` does not; sticky `/route model=opus` → no ask; `mainUpgrade` off → no ask; opus down → two options; model-loaded `Skill` on main asks; rowed spawn (verifier on audit) asks once per type, `Opus instead` → opus spec, explicit model and nested spawn never ask, a work-tier spawn never asks; first-use then tier ask on one event with the outcome asserted; `asking` held → unasked; `/route ask-tier off|on` writes and silences, bad arg → usage, override wins note; invalid value logged once and read as best; absent routing.json → no ask; the existing `/route ask` and key-order tests stay green with `askTier` added to the order.
   CHECK: cd /home/bchanot/Documents/claude && for n in 'ask-tier' 'Opus instead (big tier)' 'Stop asking this session' 'paused this session'; do grep -qF -- "$n" mods/model-router/hooks/register.test.ts || exit 1; done && a=$(make test suite=lib/tests/mods.test.sh 2>&1) && printf '%s\n' "$a" | grep -q 'all suites green' && echo MOD-TESTS-OK
   EXPECT: MOD-TESTS-OK
   EVIDENCE: MET exit=0 marker-found :: MOD-TESTS-OK
9. The repo suites that read routing.json stay green (`lib/tests/model-routing.test.sh`, `lib/tests/effort-routing.test.sh`, `lib/tests/doctrine-citers.test.sh`); `make test` all suites green.
   CHECK: cd /home/bchanot/Documents/claude && t=$(make test 2>&1) && printf '%s\n' "$t" | grep -q 'all suites green' && echo MAKE-TEST-OK
   EXPECT: MAKE-TEST-OK
   EVIDENCE: MET exit=0 marker-found :: MAKE-TEST-OK
10. Docs: USAGE.md `/route` row and the model-router paragraph name `ask-tier on|off` and the question (one sentence each); the code's own comment block "first use" gains the ask-tier rule. README.md and CHANGELOG `[Unreleased]` follow through the doc-sync step.
    CHECK: cd /home/bchanot/Documents/claude && grep -q 'ask-tier' USAGE.md && echo USAGE-OK
    EXPECT: USAGE-OK
    EVIDENCE: MET exit=0 marker-found :: USAGE-OK
11. settings.json is untouched by the branch (no UI write, no `model`), the contract and plan ride the memory commit.
    CHECK: cd /home/bchanot/Documents/claude && [ -z "$(git diff develop...HEAD --stat -- settings.json)" ] && echo SETTINGS-UNTOUCHED
    EXPECT: SETTINGS-UNTOUCHED
    EVIDENCE: MET exit=0 marker-found :: SETTINGS-UNTOUCHED

## FILE SCOPE
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
- mods/model-router/routing.json (`askTier` key only)
- USAGE.md (`/route` row + model-router paragraph)
- README.md, CHANGELOG.md through STEP 6 doc-sync only
- .claude/tasks/contracts/2026-11-02-router-ask-tier-1434.md, .claude/tasks/plans/2026-11-02-router-ask-tier-1434.md (run artifacts, memory commit)
