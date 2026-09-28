# Effort tiering — design

Date: 2026-09-28 · Branch: `feature/effort-tiering` · Status: draft for review

## 1. Intent

Adapt the reasoning effort along a development run, not hold the whole
session at `xhigh`. The user's five-rung scale is the contract:

| Rung | User definition | Examples |
|---|---|---|
| low | fix a line, rename a file, run a script | journal, commit, release bookkeeping |
| medium | day-to-day work | implement a closed plan, orchestrate between dispatches |
| high | a refactor, a bug that resists | investigation, diagnosis, contract drafting |
| xhigh | architecture, audit before validation | brainstorm, plan, challenge synthesis, gates |
| max | a stuck error, an error that cannot be recovered, or judged need | loop caps, error recovery |

Automatic wherever the harness allows it. Where it does not, the user gets a
one-keystroke lever, never a silent default.

Effort is a second axis on the BDR-077 routing table: BDR-077 fixed WHICH
MODEL runs each role and forbade inherit; this design fixes HOW HARD it
thinks, with the same no-inherit principle.

## 2. What the harness allows (verified on Claude Code 2.1.283, 2026-09-28)

Sources: code.claude.com/docs (model-config, skills, sub-agents, hooks),
the CHANGELOG (2.1.120, 2.1.149, 2.1.267, 2.1.280) and live probes in this
repo.

| Mechanism | Verified behaviour | Evidence |
|---|---|---|
| Session level | Resolution order: `CLAUDE_CODE_EFFORT_LEVEL` env > `--effort` / `/effort` > settings (`modelSettings` per model, else top-level `effortLevel`) > model default (`high` on Fable 5.1). `max` is session-only, never persisted. `/effort auto` clears the per-model saved level only; a top-level `effortLevel` still applies. | docs |
| Subagent frontmatter `effort:` | Applied to the subagent. Absent → **inherits the session level**. | built-in on sonnet printed `xhigh`; impeccable agent pinned `medium` printed `medium` |
| Skill frontmatter `effort:`, user-typed `/skill` | Applied for the **rest of the turn**, AskUserQuestion included. | headless `/effort-probe-low`: every request at `low` |
| Skill frontmatter `effort:`, loaded by Claude through the Skill tool, **interactive** session | Applied for the rest of the turn. Last loaded skill wins, up and down. | this session: `xhigh` → probe max → `$CLAUDE_EFFORT=max`, request records `effort=max` → probe xhigh → back to `xhigh` |
| Same, **headless** (`-p`) | **Not applied** (neither `effort:` nor `model:`). | three `-p` runs, transcript effort unchanged |
| Prompt cache on a mid-turn shift | **Preserved** on Fable 5.1: first request at max read 206,996 cached tokens, wrote 1,164. | this session |
| Agent tool call site | No `effort` parameter (only `model`). One agent file = one effort. | tool schema |
| Hooks | Read `$CLAUDE_EFFORT` / `effort.level`; **cannot change** the level. | docs |
| `ultrathink` keyword | In-context nudge only; the effort sent to the API is unchanged. | docs |
| Env var | `CLAUDE_CODE_EFFORT_LEVEL` beats every frontmatter override. Unset on this machine. | docs + `env` |

## 3. What the numbers say (6 days of local transcripts, all projects, 10,955 requests)

Weights relative to input price: output ×5, cache read ×0.1, cache write ×1.25.

| Item | Share |
|---|---|
| Cache reads (context re-read per request) | 53 % of weighted spend |
| All output tokens | 16 % |
| of which thinking | 8 % |
| Thinking located in the main loop | 97 % of thinking |
| Mean thinking per request: Fable main loop / sonnet subagent at xhigh | 1,430 / 26 tokens |
| Mean cached context per main-loop request | ~320 k tokens |

Consequences. Executors barely think even at xhigh: pinning them is about
explicitness and future models (Opus 5.5 "thinks more per turn at a given
level"), not savings today. The direct lever of effort is single-digit
percent; the indirect lever (fewer steps at lower effort → fewer requests →
fewer cache reads) is unmeasured and gets an A/B in §9. The dominant cost is
main-loop context size, out of scope here (see `/capitalize`, `/clear`).

## 4. Decisions

### D1. Session default `high`
`settings.json` `effortLevel`: `xhigh` → `high`, explicit rather than
deleted: the statusline reads the key, and LRN-139 wants a visible value to
sweep at every model bump. Interactive chat outside a skill runs at the
model default; the user raises with `/effort xhigh` (session) or the new
`/effort-max` shifter (turn, see D4). `CLAUDE_CODE_EFFORT_LEVEL` must stay
unset (it would silence every override below); the session-start banner
warns if it is set.

### D2. Agent pins (approach A) — repo-authored agents only

| effort | Agents |
|---|---|
| low | hotfixer, release-executor, plugin-probe, validator-analyzer |
| medium | feater, bugfixer, code-cleaner, onboarder, scaffolder (was `high`; citer `skills/init-project/SKILL.md:98` updated) |
| high | refactorer, analyzer, commit-changer, doc-syncer, handover-doc-writer |
| xhigh | plan-challenger, plugin-advisor, verifier, security-auditor, seo-analyzer, geo-analyzer |
| none | interviewer, client-handover-writer (inline-load only, a pin would be inert and misleading, BDR-076 precedent); status-reporter (haiku, no effort support); `impeccable-*` (vendored) |

Rules. One effort per agent file, so a mode-based agent (BDR-077) pins the
level of its **judgment** mode and its mechanical modes over-tier: the
fail-safe direction, and free on sonnet per §3. Built-ins (Explore,
general-purpose, Plan) cannot be pinned at the call site and inherit the
main loop's current level; Explore on Fable thinks ~1 token per request,
so no wrapper agent is created. Verifier and security-auditor sit at xhigh
by the user's own definition ("audit before validation"); on sonnet the
cost difference is nil.

### D3. Skill frontmatter effort (approach B) — the run's entry level
Applies from the user's invocation for the rest of the turn.

| effort | Skills |
|---|---|
| low | status, commit-change, release-candidate, doc, capitalize, close, reconcile, deploy, profile, plugin-check |
| medium | gitflow, prune-memory, find-docs |
| high | feat, hotfix, bugfix, refactor, web-validate, harden, seo, geo |
| xhigh | ship-feature, init-project, onboard, tour, audit-delta, analyze, code-clean, client-handover, spec, skillify, brainstorming, writing-plans |
| unlisted | session default, by design (gstack and plugin skills are external; graphify is machine-owned) |

`brainstorming` and `writing-plans` are vendored superpowers skills: the
one-line patch drifts from upstream at each resync; a census lock (§7)
makes the loss loud.

A skill loaded by Claude as a sub-step (feat → commit-change) also shifts
the level for the rest of the turn (interactive, §2), so orchestrators
re-assert their own level after any nested Skill call whose level differs
(D4 protocol).

### D4. Phase shifts inside a run (approach C)
Five one-line skills, no body beyond a sentence, user-invocable:
`effort-low`, `effort-medium`, `effort-high`, `effort-xhigh`, `effort-max`.
Descriptions as pre-validated against the routing census (pairwise
similarity ≤ 0.03). Protocol in a shared include `lib/effort-shift.md`,
mirroring `lib/model-gate.md`:

- A shift is a `Skill(effort-<level>)` call on the main loop. Never inside a
  dispatched agent (agents run on their pin). One tool round-trip,
  cache-safe (§2).
- Orchestrator wiring, three points each: `effort-medium` when the plan is
  closed and the dispatch phase starts; `effort-low` before the
  capitalize / journal / doc-commit tail; `effort-max` at an escalation
  point, then the skill's own level again once the diagnosis is produced.
- Re-assert the skill's own level after any nested `Skill(...)` call whose
  frontmatter carries a different effort (D3): the nested level would
  otherwise hold for the rest of the turn.
- **Escalation points (automatic max)**: verify-secure loop GATE 1 cap
  (3 conformity rounds) and GATE 2 cap (3 security rounds), before the
  human-escalation table is composed; ship-feature STEP 4b, so the
  inline analyzer DEBUG read runs at max. Full conversation context is the
  asset here; a fresh diagnoser agent was considered and dropped (YAGNI:
  no context, one more agent, same effort).
- **Not automatic, by doctrine**: the challenge fail-safe (a mute
  challenger is an infrastructure failure, not a reasoning problem) and
  the "gone WRONG → STOP" rule (STOP precedes any further reasoning). Both
  STOP messages name the level reached and suggest `/effort-max` for the
  relaunch: a turn-scoped max the user gets by typing one command.
- **Turn reset**: a prose gate that ends the turn (model-gate STOP, loop
  cap STOP, and the four prose gates found in bugfix, ship-feature ×2,
  init-project) drops the resumed turn to the session level. The plan
  audits each such gate: if the resumed phase is reflection, the resume
  step re-asserts with `Skill(effort-xhigh)`; if it is dispatch or
  orchestration, session `high` is adequate and nothing is added.
- **Headless limitation**: `-p`, `claude agents` and SDK sessions ignore
  skill-level effort (§2); runs there stay at the session level. Documented
  in the include, no mitigation.

### D5. Visibility
`hooks/statusline.sh` shows `$CLAUDE_EFFORT` when set (the live level,
shifts included) and falls back to the settings key. `/tasks` already shows
each subagent's effort (2.1.243).

## 5. Alternatives rejected

- **Keep xhigh, pin executors only**: executors think ~26 tokens per
  request; the burn is in the main loop (§3).
- **Escalation diagnoser agent (`model: fable`, `effort: max`)**: chosen
  before the interactive probe proved C viable; dropped because the
  main-loop shift keeps the full failure context and adds no agent.
- **Move reflection into `model: fable` skill-runner children with
  `effort: xhigh`, session at medium**: loses conversation context and
  interactivity (BDR-077 retention criteria), heavy re-architecture for a
  lever C delivers in five one-line files.
- **Rewrite settings.json mid-run to shift effort**: global side effect on
  every session, LRN-098 drift class, fights the harness.
- **`maxEffortLevel` cap on sonnet**: pins already bound each agent; a cap
  would hide a mis-pin instead of failing it in the census.

## 6. Files touched

| Area | Change |
|---|---|
| `settings.json` | `effortLevel` → `high` (curated config: read the diff, LRN-098) |
| `agents/*.md` (20) | `effort:` line per D2; `skills/init-project/SKILL.md:98` citer |
| `skills/*/SKILL.md` (33) | `effort:` line per D3, including the two vendored superpowers skills |
| `skills/effort-{low,medium,high,xhigh,max}/SKILL.md` | new, frontmatter + one sentence |
| `lib/effort-shift.md` | new include: protocol, wiring points, escalation, turn reset, headless note |
| `lib/model-gate.md` §4 | one paragraph: effort is the second axis, pointer to the include |
| `lib/verify-secure-loop.md` | `Skill(effort-max)` before each cap's human-escalation table; STOP text names the level |
| `lib/challenge-plan.md` | STOP text names the level, suggests `/effort-max` |
| orchestrator SKILL.md (feat, hotfix, bugfix, ship-feature, init-project, onboard, tour, code-clean, seo, geo, harden, web-validate, client-handover, audit-delta) | include line + the three wiring points; ship-feature 4b max |
| `hooks/statusline.sh`, `hooks/session-start.sh` | live effort display; env-var warning |
| `lib/tests/effort-routing.test.sh` | new census suite (§7) |
| `CHANGELOG.md`, `.claude/memory/*` | release note; BDR + LRN + EVAL + journal (§8) |

## 7. Tests and census (`make test`)

New suite `lib/tests/effort-routing.test.sh`, `grep -qF` locks in the
`model-routing.test.sh` style, flip-tested first (BDR-100):

1. Every repo-authored agent outside the "none" list has `effort: <level>`
   in its first 10 frontmatter lines, level in the allowed set; the "none"
   list has no `effort:`.
2. Tier locks per D2 (one `has` per agent).
3. Skill locks per D3 (one `has` per skill), including `brainstorming` and
   `writing-plans` (the resync alarm).
4. The five shifter skills exist with the exact `name:` and `effort:`.
5. `lib/effort-shift.md` is included by every orchestrator in the §6 list;
   `verify-secure-loop.md` and `ship-feature/SKILL.md` contain the
   `Skill(effort-max)` lock.
6. `settings.json` `effortLevel` is `high`.
7. `skill-routing-census` stays green with the five new descriptions
   (pre-validated).
8. `doctrine-citers` stays green: no new `CLAUDE.md "…"` citation; the
   doctrine lives in `lib/`.

Per-wave smoke, planted input, disk-verified (BDR-077 precedent):
W1 dispatch a pinned agent that echoes `$CLAUDE_EFFORT`; W2 invoke `/status`
and read `effort=low` in the transcript; W3 run a skill through a shift
and read the request sequence; W4 statusline shows the live level.

## 8. Rollout

Four waves on `feature/effort-tiering`, one commit each, smoke as merge
gate, human signal for `gitflow finish`:

- W1 settings + agent pins + test suite + model-gate paragraph.
- W2 skill frontmatter (D3) + superpowers patch.
- W3 shifter skills + `lib/effort-shift.md` + orchestrator wiring +
  escalation points + turn-reset audit.
- W4 statusline + banner warning + CHANGELOG + registries.

Registries: BDR (effort tiering, this spec's decisions and rejected
alternatives), LRN (skill effort applies on user invocation and on
interactive Skill-tool loads, not in `-p`; shifts are cache-safe), EVAL
(the §3 measurement and its method), journal line.

## 9. Measurement after rollout

A/B on a repeatable skill run (`/reconcile` on this repo, session `high`
vs `xhigh`): requests, output tokens, thinking tokens, wall time, from the
transcript. Records whether the indirect lever exists. Goes to EVAL.

## 10. Out of scope

Main-loop context size (the 53 %), gstack and plugin skills, the
`impeccable-*` agents, `graphify` (machine-owned), headless sessions.
