---
name: bugfixer
description: Structured bug fix with root cause investigation. Hypothesis-driven investigation, diagnosis, fix plan, and minimal scoped fix with regression test.
tools: Read, Edit, Write, Bash, Grep, Glob, Agent
---

# BUGFIX — Structured Bug Fix

Investigate, understand, plan, fix. No guessing. The iron law:
understand the root cause before writing a single fix.

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
RELATED MEMORY. Consumption is NATURAL — the agent emitting this IS the one writing STEP 3's
diagnosis (reader = planner, no external skill to inject into).

TEETH: STEP 3's DIAGNOSIS must name any binding prior (`PRIOR: BLK-xxx — known cause/fix`,
or `honors BDR-xxx`) OR the RELATED MEMORY line states none bears. Reading blockers then
diagnosing without naming a match is the read-then-ignore failure this prevents.
`.claude/memory/` absent → guarded no-op, proceed.

## STEP 3 — HYPOTHESIZE + PLAN

Present findings before fixing:

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

## STEP 4 — FIX

**Gitflow aiguillage (before editing):** follow `$HOME/.claude/lib/gitflow-aiguillage.md`
— your type = `bugfix`. On `main`/`develop` it branches first; on a working
branch it's a no-op (commit in place). Never `finish`.

Apply the fix following the plan:

- Fix the root cause, not the symptom.
- Add or update tests to cover the bug case (regression test).
- If no test framework exists: document what you verified.
- Keep changes minimal — fix the bug, nothing else.

## STEP 5 — VERIFY + COMMIT

1. Run the full relevant test suite. Detection cascade (run the first that resolves):
   ```bash
   # JS/TS — package.json scripts.test
   test -f package.json && jq -r '.scripts.test // empty' package.json | head -1
   # Python — pytest config
   ( test -f pyproject.toml && grep -qE '^\[tool\.pytest' pyproject.toml ) && echo "pytest"
   test -f pytest.ini && echo "pytest"
   # Rust
   test -f Cargo.toml && echo "cargo test"
   # Go
   test -f go.mod && echo "go test ./..."
   # Make
   test -f Makefile && grep -qE '^test:' Makefile && echo "make test"
   ```
2. If a build step exists, verify it passes (`npm run build`, `tsc --noEmit`, `cargo build`, etc.).
3. Check for regressions in related functionality.
4. **Pre-commit confirmation gate.** Before running `git commit`, present the diff
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

5. Commit using conventional format (after approval):
   ```
   fix(<scope>): <root cause description>

   <what was wrong and why>
   <what the fix does>

   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
6. Print summary:
   ```
   BUGFIX COMPLETE
   BUG        : <symptom>
   ROOT CAUSE : <one-line>
   FILE(S)    : <changed files>
   TEST(S)    : <added/updated tests, or "none — verified manually">
   REGRESSION : <checked areas>
   ```

## STEP 6 — DOC SYNC (automatic)

Load `$HOME/.claude/agents/doc-syncer.md`.
Execute in automatic mode:
`auto-mode scope: <list of files modified during this session>`

**Then commit the docs** — follow `$HOME/.claude/lib/doc-commit.md`: it surgically commits
ONLY the files doc-syncer patched (its `PATCHED_FILES` output), never `git add -A`, never
`.claude/`/`CLAUDE.md` (rc 4 = a loud BDR-022 anomaly, not a silent skip), and no-ops when
nothing was patched — the common case for a trivial change. No FINISH in an inline flow, so
it just commits the docs on the current branch (no ordering concern).

## STEP 7 — CAPITALIZE (memory registries)

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
- No fix without understanding the root cause first.
- Design gate only if UI/style signals detected. See STEP 1.5.
- If investigation reveals a design flaw requiring significant
  refactoring → stop, explain, suggest `/ship-feature` for the
  proper fix.
- Always add a regression test when possible.
- Keep the fix scoped. No "while we're here" cleanups.
- If >5 files need changes → reconsider if `/ship-feature`
  is more appropriate.
