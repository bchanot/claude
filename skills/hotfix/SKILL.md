---
name: hotfix
description: |
  Quick fix for superficial bugs: typos, CSS issues, config errors,
  off-by-one, wrong variable name, missing import, broken link.
  Use when the root cause is obvious and the fix is 1-2 files max.
  Trigger: "hotfix", "quick fix", "typo", "fix this small thing",
  "c'est juste un petit bug", "patch rapide".
  Do NOT use for bugs requiring investigation — use /bugfix instead.
argument-hint: <bug description or error message>
disable-model-invocation: false
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

# HOTFIX — Quick Superficial Fix

Fast-track fix for obvious bugs. No planning overhead, no plugin
check, no subagents. Get in, fix, verify, get out.

## REQUEST
$ARGUMENTS

---

## STEP 1 — LOCATE

Find the bug. Use the description and any error message to go
straight to the source:

```bash
git status
git log --oneline -3
```

- Read the relevant file(s). Confirm the root cause is obvious
  and superficial (typo, wrong value, missing import, etc.).
- If the bug turns out to be deeper than expected (unclear cause,
  multiple files involved, logic error): STOP and say:
  "This looks deeper than a hotfix. Run `/bugfix <description>`
  for a structured investigation."

## STEP 2 — FIX

Apply the minimal change that fixes the bug:

- Edit only what is necessary. No refactoring, no cleanup.
- If tests exist for the affected code, run them:
  ```bash
  # detect and run relevant tests
  ```
- If a build step exists, verify it still passes.

## STEP 3 — VERIFY + COMMIT

1. Verify the fix:
   - Run the test suite or the specific test if available.
   - If no tests: explain what you verified manually.
2. Commit using conventional format:
   ```
   fix(<scope>): <what was wrong>

   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
3. Print summary:
   ```
   HOTFIX APPLIED
   FILE(S) : <changed files>
   FIX     : <one-line description>
   VERIFIED: <test name or manual check>
   ```

---

## RULES
- Max 2 files changed. If more needed → `/bugfix`.
- No refactoring. No "while we're here" improvements.
- No plugin check (overhead > value for a hotfix).
- If root cause is unclear → escalate to `/bugfix`.
- If fix touches >5 lines of logic → reconsider if this is
  truly a hotfix.
