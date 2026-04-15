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

Apply the fix following the plan:

- Fix the root cause, not the symptom.
- Add or update tests to cover the bug case (regression test).
- If no test framework exists: document what you verified.
- Keep changes minimal — fix the bug, nothing else.

## STEP 5 — VERIFY + COMMIT

1. Run the full relevant test suite:
   ```bash
   # detect and run tests
   ```
2. If a build step exists, verify it passes.
3. Check for regressions in related functionality.
4. Commit using conventional format:
   ```
   fix(<scope>): <root cause description>

   <what was wrong and why>
   <what the fix does>

   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
5. Print summary:
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

---

## RULES
- No fix without understanding the root cause first.
- No plugin check (lightweight skill, not an orchestrator).
- If investigation reveals a design flaw requiring significant
  refactoring → stop, explain, suggest `/ship-feature` for the
  proper fix.
- Always add a regression test when possible.
- Keep the fix scoped. No "while we're here" cleanups.
- If >5 files need changes → reconsider if `/ship-feature`
  is more appropriate.
