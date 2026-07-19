---
name: feat
description: |
  Small feature implementation (1-5 files). Reflection inline (scope,
  plan, contract — session model), execution dispatched to the
  sonnet-pinned feater executor. For features that don't need the full
  /ship-feature pipeline (no design brainstorm, no plugin check gate).
  Trigger: "feat", "small feature", "add this", "petite feature",
  "quick feature", "ajoute ca", "implement this small thing".
  For multi-file features needing design → use /ship-feature.
  For bug fixes → use /hotfix or /bugfix.
argument-hint: <feature description>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
---

# /feat — small-feature orchestrator (reflection inline, execution dispatched)

MODEL GATE (blocking): run `$HOME/.claude/lib/model-gate.md` BEFORE any
step below. Verdict `small` → STOP — print the gate's remedy, end the
turn, dispatch nothing.

## REQUEST
$ARGUMENTS

---

## STEP 0 — SCOPE CHECK

Before starting, verify this is actually a small feature:

```bash
git status
git log --oneline -3
```

Read the relevant existing code to understand the context.

### Decision rules (apply in order — first match wins)

| Rule | Trigger | Action |
|---|---|---|
| 1 | Estimated diff < 2 files AND no logic (config value, copy fix, missing field) | DOWNGRADE → route to `/hotfix` (its orchestrator does LOCATE + dispatches the hotfixer executor; never load the bare agent file) |
| 2 | New external dependency (`npm install <x>`, `pip install`, `cargo add`) required | ESCALATE → `/ship-feature` (dep choices need design gate) |
| 3 | New route family / new top-level module / new DB migration | ESCALATE → `/ship-feature` |
| 4 | Estimated diff > 5 files | ESCALATE → `/ship-feature` |
| 5 | User wording is uncertain ("not sure how", "what do you think") | ESCALATE → `/ship-feature` (needs brainstorming) |
| 6 | UI feature on a stack with a design system AND the design toolchain incomplete | Proceed in `/feat`, but flag it in STEP 0.5 design gate |
| 7 | Otherwise | PROCEED in `/feat` |

### Worked examples

- "Add `/health` endpoint returning `{status:"ok",version}`" → 1-2 files, no new dep, route added to existing router → **PROCEED**.
- "Add a dark-mode toggle bound to `prefers-color-scheme`" → 2-3 files, design system exists → **PROCEED** (design gate triggers in STEP 0.5).
- "Add OAuth login (Google + GitHub providers)" → new deps, new routes, secrets handling → **ESCALATE** to `/ship-feature`.
- "Show a 'New' badge on items created this week" → 1-2 files, pure UI predicate → **PROCEED**.
- "Fix copy: 'Sign In' → 'Sign in'" in 1 file → **DOWNGRADE** to `/hotfix`.

Print a one-line scope confirmation (use the rule that fired):
```
FEAT: <feature name> — rule <N>, ~<N> files, <brief approach>
```

## STEP 0.5 — DESIGN GATE

Follow `$HOME/.claude/lib/design-gate.md`:
- Scan $ARGUMENTS and target files for design/UI/style signals.
- If signals found → run `design-tool-gate.sh`; if it reports INCOMPLETE,
  tell the user to run `/profile design` before proceeding.
- If no signals → skip (zero overhead).

## STEP 0.6 — MEMORY READ-BEFORE (decisions-first)

Run the scan per `$HOME/.claude/lib/analyze-before-plan.md`, decisions-weighted: a BDR may
already constrain or forbid the approach; an LRN may name a gotcha to apply. Emit RELATED
MEMORY; feed STEP 1 PLAN. Inline consumption — reader = planner, no injection.
`.claude/memory/` absent → guarded no-op (zero overhead on a memory-less repo).

## STEP 0.7 — CONTRACT

Run `$HOME/.claude/lib/contract-interview.md` (main loop — you are it). It
captures the request verbatim, asks 0-3 questions PROPORTIONAL to ambiguity
(a complete request → zero questions, silent), derives testable acceptance
criteria + file scope, and writes the contract to
`.claude/tasks/contracts/<date>-<slug>-<HHMM>.md`. Keep the path — the
executor reads it first and GATE 1 (STEP 4) hands it to a fresh verifier.

## STEP 1 — PLAN (dispatch-ready)

The executor follows this plan to the letter and CANNOT ask questions —
close every decision here:

1. Files to create or modify (with line references).
2. Approach in 2-5 bullets — name every choice (naming, data shape, API
   surface); an open choice left here comes back as a NEED-DECISION
   round-trip.
3. Edge cases to handle.
4. Tests to add/update (exact files).
5. Disposition (from STEP 0.6): name each in-force BDR/LRN this plan honors
   (`honors BDR-xxx by …`), or state `no in-force decision constrains this feature`.
   A plan with neither = read-then-ignore; the disposition must surface as a trace.

Print the plan as a compact checklist:
```
PLAN:
  [ ] <file> — <what to do>
  [ ] <file> — <what to do>
  [ ] <test file> — <test to add>
```

If the approach is ambiguous: ask the user ONE focused question BEFORE
dispatching — never after (the executor cannot relay questions).

## STEP 1b — CHALLENGE THE PLAN (before branching)
The STEP 1 plan is a reflection worth attacking before a branch is spent on it.
Persist it to `.claude/tasks/plans/<date>-<slug>-<HHMM>.md`, then run
`$HOME/.claude/lib/challenge-plan.md` with `PLAN` = that file, `KIND` = `build-plan`,
`SCOPE` = the STEP 1 files, `CONSTRAINTS` = the STEP 0.6 in-force BDR/LRN dispositions.
Three blind challengers attack it; RE-THINK every aspect a BLOCKER lands (a named
plan change, or `[deferred]`), re-challenge once if the plan materially changed. The
STEP 3 executor receives the REVISED plan. Before dispatch, print a CHALLENGE SUMMARY
(BLOCKERs addressed / deferred / lenses returned), surfacing any deferred BLOCKER via
STEP 1's one-question gate.

## STEP 2 — BRANCH

**Gitflow aiguillage (before dispatch):** follow `$HOME/.claude/lib/gitflow-aiguillage.md`
— your type = `feature`. On `main`/`develop` it branches first; on a working
branch it's a no-op (commit in place). Never `finish`.

## STEP 3 — DISPATCH EXECUTOR

Dispatch the executor — sonnet by frontmatter pin, do not override:

```
Agent(subagent_type="feater")
prompt: "CONTRACT: <path from STEP 0.7>
PLAN: <the STEP 1 checklist + approach bullets + edge cases, verbatim>
BRANCH: <current branch — verify with git branch --show-current, never switch>
Implement the plan to the letter. Tests alongside code. No commit, no
branch ops, no new dependencies, no files outside the contract FILE SCOPE.
Finish with the FEAT-EXEC REPORT."
```

Parse the `FEAT-EXEC REPORT`:
- `STATUS : DONE` → STEP 4.
- `STATUS : NEED-DECISION` → make the decision HERE (that is reflection),
  append it to the plan, re-dispatch a FRESH feater with plan + decision.
  Max 2 decision round-trips → escalate to the user.
- `STATUS : BLOCKED` → surface the blocker to the user, stop.

## STEP 4 — VERIFY + SECURE (fresh gates, bounded loops)

Run the two fresh gates per `$HOME/.claude/lib/verify-secure-loop.md` with
`CONTRACT` = the STEP 0.7 path, `DIFF` = the working-tree diff the executor
produced, `TEST` = the suite named in its report:

- GATE 1 — a FRESH verifier judges the diff against the contract (blind).
  CONFORME on the first pass → straight to GATE 2, no loop. ECARTS → the
  "dev" of the loop is the dispatched executor: re-dispatch a FRESH feater
  with the CONTRACT path + the exact gap lines, nothing else. Max 3 →
  escalate.
- GATE 2 — a FRESH security-auditor (`MODE: gate`) scans the diff. PASS →
  STEP 5. BLOCK → re-dispatch a FRESH feater with the BLOCKING list + the
  CONTRACT path; re-verify the request THEN re-scan, max 3 → escalate.

Loop decisions stay HERE, in the main loop (LRN-083). Nominal (clear
request, conform first pass, clean diff) = one executor + one
verifier + one security dispatch.

## STEP 5 — COMMIT

Commit using conventional format:
```
feat(<scope>): <what was added>

<brief description of the feature>
```

If the feature touched multiple concerns (e.g., feature + config +
test), consider splitting into 2-3 atomic commits grouped by logical
unit — or run `/commit-change` on the pending work (it dispatches the
sonnet commit-changer; never inline-load the bare agent, it is now a
propose/apply executor).

Print summary:
```
FEAT COMPLETE
FEATURE  : <name>
FILE(S)  : <created/modified files>
TEST(S)  : <added tests>
VERIFIED : <what was checked>
```

## STEP 6 — DOC SYNC (automatic)

Dispatch the doc pipeline (BDR-077 — audit judgment on opus, patch on the
sonnet pin, gate HERE):
1. `Agent(subagent_type="doc-syncer", model="opus")` — `MODE: audit` +
   `auto-mode scope: <list of files modified during this session>`.
2. Silence (NONE) → done. `[MINOR]` PATCH PLAN → re-dispatch
   `Agent(subagent_type="doc-syncer")` with `MODE: patch` + the plan
   verbatim (no gate — auto behavior preserved; a `SHAPE ESCALATION` in
   its report comes back here, gated as SIGNIFICANT).
3. SIGNIFICANT → gate here (`Apply? yes / no / select`), then
   `MODE: patch` with the approved subset.

**Then commit the docs** — follow `$HOME/.claude/lib/doc-commit.md`: it surgically commits
ONLY the files doc-syncer patched (its `PATCHED_FILES` output), never `git add -A`, never
`.claude/`/`CLAUDE.md` (rc 4 = a loud BDR-022 anomaly, not a silent skip), and no-ops when
nothing was patched — the common case for a trivial change. No FINISH in an inline flow, so
it just commits the docs on the current branch (no ordering concern).

## STEP 7 — CAPITALIZE (memory registries)

A small feature may or may not involve a design choice. Scan the work for:

- **Non-trivial design choice** (even small: a library pick, a naming convention, a data-model tradeoff) → propose `BDR-XXX` in `.claude/memory/decisions.md` with alternatives considered.
- **Reusable pattern or gotcha encountered** → propose `LRN-XXX` in `.claude/memory/learnings.md`.

Present the candidates grouped:
```
CAPITALIZE — proposé
  [decisions.md]   BDR-XXX — <titre> (optionnel)
  [learnings.md]   LRN-XXX — <pattern> (optionnel)
Valider ? (all / <IDs> / edit / skip)
```

Always append a 1-line entry to today's heading in `.claude/memory/journal.md`.

**Language rule**: written entries are ALWAYS in English (see CLAUDE.md "Memory registries" § Language). The interactive gate may mirror the user's language; the appended entries must not.

If no substantive capture candidate → skip with `CAPITALIZE: nothing to log`.

**Then commit the memory** — follow `$HOME/.claude/lib/capitalize-commit.md`: it
surgically commits what capitalize just wrote (`.claude/memory` + `.claude/tasks`
only, never `git add -A`) as one `chore(memory)` commit, reports the memory-commit
hash, and no-ops if nothing was written.

---

## RULES
- Max 5 files. If more needed → `/ship-feature`.
- Reflection (scope, plan, contract, loop decisions) NEVER leaves this main
  loop; execution NEVER stays in it — the executor is the sonnet-pinned
  feater subagent (BDR-066).
- The executor is dispatched FRESH on every round-trip — feedback travels
  as contract path + named gaps/decisions, never as transcript.
- Design gate only (not full plugin check). See STEP 0.5.
- No brainstorm/design phase (if needed → `/ship-feature`).
- Keep scope tight. If scope creep happens mid-work, stop
  and suggest splitting into `/feat` + follow-up task.
- Follow existing code patterns. Don't introduce new patterns
  for a small feature.
