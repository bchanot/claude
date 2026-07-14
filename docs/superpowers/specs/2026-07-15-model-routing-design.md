# Model routing — reflection inline (big model) / execution pinned (Sonnet) — design

**Date**: 2026-07-15 · **Status**: approved (user, 2026-07-15) · **Branch**: `feature/model-routing`
**Lifecycle**: transient planning artifact (BDR-065) — committed during the run, deleted post-merge.

## Principle

The session model is assumed to be a big reasoning model (Fable 5, or Opus when
Fable is unavailable). Everything that **thinks** — brainstorming, planning,
technical decisions, audits, loop decisions — runs INLINE in the main
conversation, or in subagents that inherit the session model. Everything that
**executes** a ready-made plan — writing code, applying fix bundles, commits,
deliverable rendering — runs on Sonnet-pinned subagents. A blocking gate
enforces the "session = big model" assumption at the entry of every reflection
orchestrator.

User verdicts baked in (2026-07-14/15):
- Scope = hybrid: ship-feature/init-project execution → sonnet; `/feat`
  re-architected (plan inline → dispatch executor); bugfix/hotfix stay fully
  inline (BDR-050 conserved for them).
- Gate = BLOCKING, not advisory.
- Audit agents inherit the session model (no opus pin); the gate extends to
  audit orchestrators.
- verifier + security-auditor KEEP `model: sonnet` (job9 decision confirmed).
- client-handover-writer → sonnet (requires converting its inline-load to a
  true dispatch; human gates relocate to the main loop).

## 1. Blocking model gate

New `lib/model-check.sh`: resolves the current session model from
`settings.json` (physical path resolution — LRN-023 class), normalizes
(`claude-fable-5[1m]` → fable, `claude-opus-*` → opus, sonnet, haiku), prints
`big|small|unknown`. Exit 0 = big, 2 = small, 3 = unknown.

New `lib/model-gate.md` snippet (same include pattern as `lib/design-gate.md`):
run the check; `small` → STOP the skill: "session model is <X> — reflection
requires Fable/Opus. Switch with /model, then relaunch." `unknown` →
fail-visible: show the raw value, ask the user to confirm or abort (BDR-025
doctrine — unknown never silently passes).

Wired as a STEP 0 line in the reflection orchestrators:
`ship-feature, init-project, feat, bugfix, onboard, seo, geo, web-validate,
harden, audit-delta, tour, code-clean`.
NOT wired in: `hotfix` (trivial by definition), `commit-change`, `doc`,
`status`, `release-candidate`.

Caveats to prove at implementation time:
- `/model` mid-session rewrites settings.json (LRN-098 observed it once —
  re-prove with a live flip-test before trusting the source).
- The helper itself must be flip-tested (LRN-096: an unproven guard is a
  vacuous guard).

## 2. Frontmatter pins (`agents/*.md`)

| Agent | Before | After | Rationale |
|---|---|---|---|
| feater | (inherit) | **sonnet** | executor as subagent: seo/geo L1 applier + new /feat dispatch |
| hotfixer | (inherit) | **sonnet** | L1 applier (seo/geo/web-validate); /hotfix inline unaffected (pin inert on inline load) |
| client-handover-writer | opus | **sonnet** | deliverable executor; pin becomes EFFECTIVE only with §5 dispatch conversion (today's opus pin is inert — the agent is inline-loaded) |
| analyzer | haiku | **(none — inherit)** | analysis feeds the plan = reflection; runs big via the session model |
| verifier | sonnet | keep | F1 confirmed (job9) |
| security-auditor | sonnet | keep | F1 confirmed (job9) |
| seo-analyzer, geo-analyzer, validator-analyzer | (inherit) | keep (inherit) | audit = reflection = session model; covered by the gate |
| code-cleaner | (inherit) | keep (inherit) | audit phase = reflection; fixes hand off to refactorer (sonnet) via CODE-CLEAN-SCOPE.md (job9 H1) |
| doc-syncer, onboarder, scaffolder, refactorer, interviewer, plugin-advisor | sonnet | keep | workers/executors |
| status-reporter | haiku | keep | mechanical collector |
| bugfixer, commit-changer | (inherit) | keep | inline-only playbooks — a pin would be inert |

## 3. `/feat` re-architecture (partial supersede of BDR-050 — feat only)

`skills/feat/SKILL.md` absorbs the reflection: analyze-before-plan, design
gate, MINI-PLAN, contract (`lib/contract-interview.md`) — all inline. Then
dispatches `Agent(subagent_type="feater")` (sonnet via pin) with: the
contract, the plan, the branch name, repo conventions.

`agents/feater.md` is rewritten as a pure executor: implement the plan to the
letter, run project checks, commit (no attribution trailers), return a
structured summary. No user interaction inside feater (subagents cannot ask) —
every decision must be closed pre-dispatch.

The verify-secure loop moves out of feater.md into the /feat main loop
(LRN-083 invariant: loop decisions live in the main loop): fresh verifier →
ECARTS → re-dispatch feater with the verdict deltas, bounded 3×; then the
security gate. Escalation paths unchanged.

## 4. SDD execution pinned (ship-feature STEP 4, init-project STEP 8)

One instruction line in each SKILL.md: every implementation subagent
dispatched under `superpowers:subagent-driven-development` MUST carry
`model: "sonnet"` in the Agent call. No fork of the superpowers skill — the
main loop emits the Agent calls and controls the params.

## 5. client-handover conversion (inline-load → true dispatch)

`skills/client-handover/SKILL.md`: collect params inline (URL, logo, options),
then `Agent(subagent_type="client-handover-writer")` — the sonnet pin becomes
effective. Human gates (per-axis threshold escalation, overrides) RELOCATE to
the main loop: the writer returns a structured `GATE NEEDED` status instead of
asking; the dispatcher asks the user and re-dispatches (or continues via
SendMessage) with the decision. `AskUserQuestion` is removed from the writer's
tools.

OPEN VERIFY POINT: the writer's own nested dispatches (seo/harden re-runs as
general-purpose subagents) — verify at implementation what nested children
inherit (session model vs parent model). If they inherit the sonnet parent,
the re-run audits violate the principle → force the model explicitly in those
nested dispatches or lift them to the main loop.

## 6. web-validate fixes → L1 applier

STEP 3 stops applying fixes via inline Edit; dispatches `hotfixer` (sonnet)
with the fix bundle — same pattern as seo/geo (BDR-061 alignment).

## 7. Memory / doc / tests

- New BDR: model-routing principle (reflection inline big / executors sonnet /
  blocking gate); partial supersede of BDR-050 (feat only); records F1
  (verifier/security stay sonnet) and the analyzer haiku→inherit change.
- README: agent-model table refresh. CHANGELOG Unreleased entry.
- Tests: flip-tests for `model-check.sh` (fable[1m] / opus / sonnet / garbage
  fixtures); gate STOP proven on a small-model fixture (LRN-096); /feat smoke
  on a throwaway repo (LRN-079): plan inline → dispatch carries sonnet →
  verify loop decided in main loop; grep census: no executor dispatch without
  an effective pin.

## Out of scope / accepted deviations

- `/doc` and `/commit-change` stay inline on the session model (judgment and
  execution interleaved; converting them buys little). Revisit under quota
  pressure.
- bugfix/hotfix fully inline (BDR-050 conserved).
- No per-agent "fable-else-opus" fallback exists in the harness — the session
  model IS the fallback mechanism; the gate is its backstop.

## Risks

- Model strings in settings.json may change shape with CC updates →
  model-check must return `unknown` (fail-visible), never guess.
- feater as a subagent loses main-conversation context → the plan becomes the
  contract; weak plans cost verify-loop iterations. Mitigation:
  contract-interview stays mandatory in /feat.
- Nested model inheritance under client-handover-writer unknown → §5 verify
  point.
