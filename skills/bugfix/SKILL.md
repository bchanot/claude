---
name: bugfix
description: |
  Structured bug fix with root cause investigation. For bugs where
  the cause isn't immediately obvious, spans multiple files, or
  requires careful analysis before fixing. Includes hypothesis-driven
  investigation and a fix plan.
  Trigger: "bugfix", "debug this", "fix this bug", "pourquoi ca marche pas",
  "investigate and fix", "find and fix", "root cause + fix".
  For obvious 1-2 file fixes → use /hotfix instead.
  For bugs that need investigation only (no fix) → use /analyze.
argument-hint: <bug description, error message, or stack trace>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
---

# /bugfix — root-cause orchestrator (reflection inline, execution dispatched)

MODEL GATE (blocking): run `$HOME/.claude/lib/model-gate.md` BEFORE any
step below. Verdict `small` → STOP — print the gate's remedy, end the
turn, dispatch nothing.

## REQUEST
$ARGUMENTS

---

## STEP 1 — GATHER CONTEXT

Understand the current state:

```bash
git status
git log --oneline -5
```

Read the error message, stack trace, or bug description.
Identify:
- **What** is broken (symptom)
- **Where** it manifests (file, line, endpoint, UI element)
- **When** it started (recent commit? always? after a deploy?)

```bash
# If the user mentions "it was working before":
git log --oneline -20 --all -- <suspected files>
```

## STEP 1.5 — DESIGN GATE

Follow `$HOME/.claude/lib/design-gate.md`:
- Scan $ARGUMENTS and target files for design/UI/style signals (CSS, component, layout, animation).
- If signals found → run `design-tool-gate.sh`; if it reports INCOMPLETE,
  tell the user to run `/profile design` before proceeding.
- If no signals → skip (zero overhead).

## STEP 2 — INVESTIGATE

Trace the bug from symptom to root cause:

1. Read the code path involved (follow the data flow).
2. Check recent changes to the affected files:
   ```bash
   git log --oneline -10 -- <file>
   git diff HEAD~5 -- <file>  # if recent regression suspected
   ```
3. Look for related tests — do they pass? Do they cover
   the broken case?
4. Search for similar patterns elsewhere that might have
   the same bug:
   ```bash
   # grep for the same pattern to assess blast radius
   ```

## STEP 2.5 — MEMORY READ-BEFORE (blockers-first)

Run the scan per `$HOME/.claude/lib/analyze-before-plan.md`, blockers-weighted: a resolved
BLK may already name THIS exact root cause; an in-force BDR may constrain the fix. Emit
RELATED MEMORY. Consumption is NATURAL — the reflection that emits this IS what writes STEP 3's
diagnosis (reader = planner, no external skill to inject into).

TEETH: STEP 3's DIAGNOSIS must name any binding prior (`PRIOR: BLK-xxx — known cause/fix`,
or `honors BDR-xxx`) OR the RELATED MEMORY line states none bears. Reading blockers then
diagnosing without naming a match is the read-then-ignore failure this prevents.
`.claude/memory/` absent → guarded no-op, proceed.

## STEP 3 — DIAGNOSE + PLAN

Present findings before dispatching a fix:

```
BUGFIX — DIAGNOSIS
BUG     : <one-line symptom>
ROOT CAUSE: <what is actually wrong and why>
EVIDENCE: <what confirmed it — test, trace, diff>
BLAST RADIUS: <other places affected, or "isolated">

FIX PLAN:
  1. <file:line> — <what to change>
  2. <file:line> — <what to change>
  [3. <test file> — add/update test for this case]

RISK: <low/medium — what could go wrong>
```

- If the root cause is still unclear after investigation,
  say so explicitly. List remaining hypotheses ranked by
  probability. Ask the user before proceeding.
- If the fix is trivial after investigation (1-2 lines):
  proceed directly — no need to wait for approval on an
  obvious fix.
- If the fix is significant (>10 lines, multiple files,
  behavior change): wait for user approval.

## STEP 3b — CHALLENGE THE FIX PLAN (before the contract)
Unless the fix is the trivial 1-2 line case STEP 3 already fast-paths, the
DIAGNOSIS + FIX PLAN is a reflection worth attacking before it hardens into a
contract. Persist it to `.claude/tasks/plans/<date>-<slug>-<HHMM>.md`, then run
`$HOME/.claude/lib/challenge-plan.md` with `PLAN` = that file, `KIND` = `build-plan`,
`SCOPE` = the FIX PLAN files, `CONSTRAINTS` = the STEP 2 in-force BDR/LRN/BLK
dispositions. Three blind challengers attack it (correctness = is the root cause
right; robustness = blast radius / regressions; simplicity = is the fix minimal);
RE-THINK every aspect a BLOCKER lands, re-challenge once if the plan materially
changed. STEP 3.5 writes the contract from the REVISED plan. Print a CHALLENGE SUMMARY
(BLOCKERs addressed / deferred / lenses returned), folding any deferred BLOCKER into
the STEP 3 approval gate.

## STEP 3.5 — CONTRACT

Run `$HOME/.claude/lib/contract-interview.md` (main loop). The DIAGNOSIS
feeds it: REQUEST verbatim = the bug report as received; ACCEPTANCE CRITERIA
= the symptom reproduced-then-gone + a regression test present and passing;
FILE SCOPE = the FIX PLAN files. Questions stay proportional (a clear,
reproduced bug → zero). It writes the contract to
`.claude/tasks/contracts/<date>-<slug>-<HHMM>.md`; keep the path — the
executor reads it first and GATE 1 (STEP 6) hands it to a fresh verifier.

## STEP 4 — BRANCH

**Gitflow aiguillage (before dispatch):** follow `$HOME/.claude/lib/gitflow-aiguillage.md`
— your type = `bugfix`. On `main`/`develop` it branches first; on a working
branch it's a no-op (commit in place). Never `finish`.

## STEP 5 — DISPATCH EXECUTOR

Dispatch the executor — sonnet by frontmatter pin, do not override:

```
Agent(subagent_type="bugfixer")
prompt: "CONTRACT: <path from STEP 3.5>
DIAGNOSIS: <ROOT CAUSE + EVIDENCE from STEP 3>
FIX PLAN: <the STEP 3 FIX PLAN — exact edits + the regression test to add>
BRANCH: <current branch — verify with git branch --show-current, never switch>
Apply the fix to the letter + the regression test. No commit, no branch
ops, no security dispatch. Finish with the BUGFIX-EXEC REPORT."
```

Parse the `BUGFIX-EXEC REPORT`:
- `STATUS : DONE` → STEP 6.
- `STATUS : NEED-DECISION` → make the decision HERE (that is reflection),
  append it to the plan, re-dispatch a FRESH bugfixer with plan + decision.
  Max 2 decision round-trips → escalate to the user.
- `STATUS : BLOCKED` → surface the blocker to the user, stop.

## STEP 6 — VERIFY + SECURE + PRE-COMMIT GATE + COMMIT (main loop, LRN-083)

1. Run the two fresh gates per `$HOME/.claude/lib/verify-secure-loop.md` with
   `CONTRACT` = the STEP 3.5 path, `DIFF` = the executor's working-tree diff,
   `TEST` = the suite named in its report:
   - GATE 1 — a FRESH verifier judges the fix against the contract (bug gone
     + regression test present). CONFORME on the first pass → straight to
     GATE 2, no loop. ECARTS → the "dev" of the loop is the dispatched
     executor: re-dispatch a FRESH bugfixer with the CONTRACT path + the
     exact gap lines, nothing else. Max 3 → escalate.
   - GATE 2 — a FRESH security-auditor (`MODE: gate`) scans the diff (a bug
     fix can introduce a vuln). PASS → the pre-commit gate below. BLOCK →
     re-dispatch a FRESH bugfixer with the BLOCKING list + the CONTRACT
     path; re-verify the request THEN re-scan, max 3 → escalate.

   Loop decisions stay HERE, in the main loop (LRN-083). Nominal = one
   executor + one verifier + one security dispatch.

2. **Pre-commit confirmation gate.** Before running `git commit`, present the diff
   summary and the proposed message, then wait for approval:

   ```
   BUGFIX — READY TO COMMIT
   FILE(S) : <list>
   DIFF    : <git diff --stat>
   MESSAGE :
     fix(<scope>): <root cause description>

     <what was wrong and why>
     <what the fix does>

   Commit now? (yes / edit message / skip / amend last)
   ```

   - `yes` → run `git commit`.
   - `edit message` → user provides corrected message; redraw gate.
   - `skip` → leave changes uncommitted, exit cleanly.
   - `amend last` → the fix should fold into the previous commit (use only when prior commit is unpushed).

3. Commit using conventional format (after approval):
   ```
   fix(<scope>): <root cause description>

   <what was wrong and why>
   <what the fix does>
   ```
4. Print summary:
   ```
   BUGFIX COMPLETE
   BUG        : <symptom>
   ROOT CAUSE : <one-line>
   FILE(S)    : <changed files>
   TEST(S)    : <added/updated tests, or "none — verified manually">
   REGRESSION : <checked areas>
   ```

## STEP 7 — DOC SYNC (automatic)

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

## STEP 8 — CAPITALIZE (memory registries)

A bugfix with an understood root cause is almost always worth one entry:

1. Propose a `BLK-XXX` entry in `.claude/memory/blockers.md` pre-filled from STEP 3 diagnosis:
   - `friction` = symptom
   - `real_cause` = root cause identified
   - `solution` = the fix applied
   - `status` = resolved
2. If the root cause exposed a **reusable pattern** (would catch the same bug elsewhere or in other projects) → also propose an `LRN-XXX` entry in `.claude/memory/learnings.md`.
3. Present as:
   ```
   CAPITALIZE — proposé
     BLK-XXX — <friction> — resolved
     [LRN-XXX — <pattern>]   (optionnel)
   Valider ? (all / blockers-only / edit / skip)
   ```
4. Append approved entries + update the Index. Add a line to today's heading in `.claude/memory/journal.md`.

**Language rule**: written entries are ALWAYS in English (see CLAUDE.md "Memory registries" § Language). The interactive gate may mirror the user's language; the appended entries must not.

If the bug was trivial and the root cause not transferable → skip with `CAPITALIZE: trivial, skip`.

**Then commit the memory** — follow `$HOME/.claude/lib/capitalize-commit.md`: it
surgically commits what capitalize just wrote (`.claude/memory` + `.claude/tasks`
only, never `git add -A`) as one `chore(memory)` commit, reports the memory-commit
hash, and no-ops if nothing was written.

---

## RULES
- No fix without understanding the root cause first (STEP 2/3).
- Reflection (GATHER, INVESTIGATE, DIAGNOSIS, contract, loop decisions) NEVER
  leaves this main loop; execution NEVER stays in it — the executor is the
  sonnet-pinned bugfixer subagent (BDR-066).
- The executor is re-dispatched FRESH on every round-trip (NEED-DECISION,
  ECARTS, BLOCK) — feedback travels as contract path + named
  gaps/decisions, never as transcript.
- Design gate only if UI/style signals detected. See STEP 1.5.
- If investigation reveals a design flaw requiring significant
  refactoring → stop, explain, suggest `/ship-feature` for the
  proper fix.
- Always add a regression test when possible.
- Keep the fix scoped. No "while we're here" cleanups.
- If >5 files need changes → reconsider if `/ship-feature`
  is more appropriate.
