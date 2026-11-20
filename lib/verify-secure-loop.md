# Verify + secure loop — shared orchestrator include (feat, bugfix, guardrails, a11y)

Runs in the ORCHESTRATOR MAIN LOOP after the dev step completes (its first
section runs before the dev step is dispatched). Turns a
finished diff into a verified, security-cleared change through two fresh
gates and bounded loops. Loop decisions live here, in the main loop
(LRN-083: subagents = execution + report). The dev step is a dispatched
sonnet executor (feat's `feater`, bugfix's `bugfixer`): "hand the dev"
below means re-dispatch a FRESH executor with exactly those inputs.

Inputs the caller must have ready:
- `CONTRACT`: path to the contract file written by `contract-interview.md`.
- `DIFF`: the range/file-list the dev just produced (e.g. `HEAD` vs the
  pre-dev SHA, or the working-tree diff before commit).
- `TEST`: the project test command, if known.

Nominal path is cheap — a free floor run, then
one verifier dispatch + one security dispatch, done. The loop only costs
more when it actually loops.

## BEFORE THE FIRST DISPATCH: contract dry run (main loop)

When the flow wrote a contract with `CHECK:` lines, the main loop does two
things before the dev step is dispatched:

1. Records the run's start commit in the contract header, once:
   `- run-base: <git rev-parse HEAD>` (a SHA, never a branch name;
   `lib/capitalize-commit.md` counts the run's TODO movement from it).
2. Copies the contract to a `mktemp -d` path and, from the project root,
   runs `bash ~/.claude/lib/gates.sh run <copy>`, so the real ledger stays
   `pending`. Expected: no `ERROR(n)` (malformed ledger: fix it here),
   NOT-MET rows only where the work is not done yet, each failing for that
   reason and not for a syntax error, a missing tool or a wrong path. A row
   already MET is valid only when the work must keep it green (a suite, a
   line cap); any other is vacuous. A marker that can never match fails
   like undone work: for oracles that grep prose, apply the planned text
   to a scratch copy of the repo and run the CHECKs there (LRN-296).

A bad oracle is fixed in the contract here, before any floor loop.

## GATE 0 — DETERMINISTIC FLOOR (no dispatch, no model)

Before spending a verifier dispatch, execute the oracles the contract itself
declares:

```bash
bash ~/.claude/lib/gates.sh run "$CONTRACT"
```

It runs every `CHECK:` fail-closed (MET requires exit 0 AND the `EXPECT:`
marker) and writes the outcome back over each `EVIDENCE:` line. Parse its
single `GATES — VERDICT:` line:

- `MET` → floor green, go to GATE 1. An all-manual contract lands here too
  (`RUNNABLE: 0 of n`) and passes straight through.
- `UNMET(n)` → hand the dev the CONTRACT path + the `NOT-MET` rows verbatim,
  nothing else; re-run GATE 0. **No verifier is dispatched** — a red build or
  a red suite is not a judgement call, and paying an LLM to discover it is
  waste. **Max 3 floor iterations** → `mcp__model-router__route(phase="escalate")` (route: cap reached, diagnose at max before escalating; send it with the first tool call that gathers the escalation evidence), then STOP + human escalation with the rows.
  A second UNMET with no main-loop advisor call since GATE 0 first ran →
  the main loop calls it before the re-dispatch
  (`lib/effort-shift.md` § Advisor); the answer stays here, never
  in the dev brief.
- `ABANDONED(n)` → floor green but a handoff stands. Continue to GATE 1; the
  verifier surfaces it and its `ABANDONED(n)` verdict routes to the human
  gate.
- `ERROR(n)` → the ledger is malformed (partial oracle, duplicate id,
  unindented attribute, runnable criterion with no `EVIDENCE:` line). The
  contract is the ORCHESTRATOR's own artifact — fix it here in the main loop,
  never dispatch a dev for it.

Floor iterations are counted separately from GATE 1's: a cheap loop here does
not eat the conformity budget. GATE 0 also runs unchanged after every
security fix round, before re-verifying the request.

## GATE 1 — REQUEST CONFORMITY (fresh verifier)

Dispatch a FRESH verifier subagent (`subagent_type: verifier`, or load
`agents/verifier.md`). Pass ONLY: the `CONTRACT` path, the `DIFF` range, the
`TEST` command. Never pass the dev's summary, never pass a prior iteration's
gaps — the verifier reads the contract from disk and judges blind.

The verifier's STEP 3 (`agents/verifier.md`) runs `lib/floor-guard.sh`
against the diff before it renders any verdict — a deterministic,
diff-scoped check for a quietly weakened quality bar (a suppressed
lint/type check, a skipped or deleted test, a dropped assertion, a lowered
coverage threshold) that an LLM verdict alone can miss or be talked past
one line at a time. Its findings fold straight into that same verifier's
`ECARTS` count unless the contract's `CLARIFICATIONS` explicitly authorizes
the exact weakening; there is no separate gate and no extra dispatch, it
rides this GATE 1 call. A `floor-guard: allow` waiver outside a test file
is a finding too unless the contract's `CLARIFICATIONS` names it: the
waiver is self-service, the contract is human-gated (BDR-102 amendment).

Parse its single `VERIFY — VERDICT:` line:

- `CONFORME` → go to GATE 2. (First-pass conforme = no loop.)
- `ECARTS(n)` → hand the dev the CONTRACT path + the exact `CRITERIA` gap
  lines (NOT-MET / out-of-scope), nothing else: re-dispatch a FRESH executor
  with those inputs only, never redo the fix by hand. Then re-run GATE 0 and
  re-dispatch a FRESH verifier. Repeat.
  **Max 3 conformity iterations** → `mcp__model-router__route(phase="escalate")` (route: cap reached, diagnose at max before escalating; send it with the first tool call that gathers the escalation evidence), then STOP + human escalation with the
  CRITERIA table (the contract-vs-realized diff).
  A second ECARTS with no main-loop advisor call since GATE 0 first ran →
  the main loop calls it before the re-dispatch
  (`lib/effort-shift.md` § Advisor); the answer stays here, never
  in the dev brief.
- `ABANDONED(n)` → direct human gate, never a dev loop (a dev cannot close
  what was proven impossible). The human lifts the abandonment or accepts
  the partial delivery; either way the run is never reported as fully
  complete, and the abandonment is named in the final report.
- Remaining `UNVERIFIABLE` while all else MET → direct human gate (a dev
  cannot fix unverifiability); do not spend a loop on it.
- Out-of-scope files: a dev justification is accepted ONLY through the human
  micro-gate that appends `[gated <date>]` to the contract's FILE SCOPE;
  otherwise the dev removes the file. Run artifacts are in scope by
  default (`agents/verifier.md`, STEP 4).
- Structural failure (`ERROR(…)`, missing/duplicated VERDICT line,
  unparsable, crash, `CONFORME` without `PROOF` or without `FLOOR`) → retry
  ONCE with a fresh verifier; a 2nd structural failure → human escalation.
  A mute verifier is NEVER a PASS.
  A 2nd structural failure with no main-loop advisor call since GATE 0
  first ran → the main loop calls it before escalating
  (`lib/effort-shift.md` § Advisor).

## GATE 2 — SECURITY (fresh security-auditor)

Only after GATE 1 is `CONFORME`. Dispatch a FRESH security-auditor
(`subagent_type: security-auditor`, or load `agents/security-auditor.md`)
with `MODE: gate`, `SCOPE: <DIFF>`. No report path (gate mode is
stdout-only, no Write).

Parse its single `SECURITY — VERDICT:` line:

- `PASS` → read the `TOOL:` line first: DEGRADED (semgrep absent) shows
  there, never on the VERDICT line; a PASS with no `TOOL:` line is a
  structural failure (below). Then done, proceed to commit; a DEGRADED
  PASS also surfaces the checklist result + recommends `make plugin`
  (the tool's absence never blocks).
- `BLOCK(n)` → hand the dev the `BLOCKING` list + the CONTRACT path
  (re-dispatch a FRESH executor, never fix by hand). Then re-run GATE 0, then
  **re-verify the REQUEST first** (GATE 1, fresh verifier) — a security fix
  can drift the behavior — **then re-run GATE 2** (fresh auditor), in that
  order. **Max 3 security iterations** → `mcp__model-router__route(phase="escalate")` (route: cap reached, diagnose at max before escalating; send it with the first tool call that gathers the escalation evidence), then STOP + human escalation with the
  BLOCKING table. Every STOP text names the level reached (`$CLAUDE_EFFORT`)
  and suggests relaunching with `ultrathink` in the prompt (turn floor) or
  `/route effort=max` (sticky, `/route clear` after).
  A second BLOCK with no main-loop advisor call since GATE 0 first ran →
  the main loop calls it before the re-dispatch
  (`lib/effort-shift.md` § Advisor); the answer stays here, never
  in the dev brief.
- Structural failure → retry ONCE fresh; 2nd → human escalation. A mute
  auditor is NEVER a PASS.
  A 2nd structural failure with no main-loop advisor call since GATE 0
  first ran → the main loop calls it before escalating
  (`lib/effort-shift.md` § Advisor).

Every cap or escalation STOP above: when the main loop consulted the advisor
since GATE 0 first ran, the STOP carries its answer and says whether it
predates the last iteration.

## Order invariant

Every re-loop replays the gates in order: **GATE 0 → GATE 1 → GATE 2**,
never a subset and never reversed.

The floor runs first because it is free, and because a red build makes the
verifier's verdict meaningless. REQUEST conformity is
always re-checked BEFORE security on any re-loop — a security fix that breaks
the feature must not slip through because only the security gate re-ran.
Never the reverse order.

## DONE: oracles green, reopened only on evidence

A run is done when its oracles are green: GATE 0 MET (the suite criterion
included), GATE 1 CONFORME and GATE 2 PASS on the same diff. After done, a
review (the end-of-run advisor call, a code review, a re-read) reopens the
run only with reproducible evidence: a command that fails on HEAD, or real
output shown wrong. A plausible scenario alone does not reopen the run:
the main loop tries once to turn it into a failing command, and if it
cannot, the finding is a MINOR (below). A behavioural claim ("agents obey
the rule") is done at its locks green, one live probe and one dated
measurement: a TODO line that carries the date and the tripwires that
would reopen it.

## MINOR triage: fold before dispatch, or drop

A MINOR finding on the run's plan or diff (from a challenger, a review, an
advisor) is either folded into the plan before the dispatch or dropped. No
fix round after the gates for a MINOR: it costs a full gate cycle. A drop
is one line, `MINOR dropped: <finding>`, in the run report and appended to
the run's plan file; nothing goes to TODO.md, BUGS-FOUND.md or any
registry. The backlog takes only findings with reproducible evidence, or
what the user asks for. Never a droppable MINOR: a security finding (a
GATE 2 `REPORTED` item, a secret, an injection, authorization or exposure
issue from any review) goes to the user, who decides fix or record.
Untouched by this triage: doc-syncer's `[MINOR]` patch class, the safety
guardrails, every gate, and the user's questions on visible, public-name
and scope choices.
