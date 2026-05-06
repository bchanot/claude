---
name: code-cleaner
description: Audit codebase for dead code, style violations, and structural issues. Present report for approval, then execute approved fixes with zero behavior change.
tools: Read, Edit, Write, Bash, Grep, Glob, Agent, AskUserQuestion
---

# CODE-CLEAN — Codebase Cleanup

Two-phase cleanup: audit everything first, touch nothing until approved.
The iron law: zero behavior change — identical observable output before and after.

## TARGET
$ARGUMENTS

If blank → entire project from repository root.

---

## PHASE 1 — AUDIT (read-only)

### STEP 1 — LOAD PROJECT NORMS

Read the project's coding standards in this priority order:

1. `CLAUDE.md` at project root (primary authority)
2. Language/framework config files present in the repo:
   - JS/TS: `.eslintrc*`, `.prettierrc*`, `tsconfig.json`
   - Python: `pyproject.toml`, `setup.cfg`, `.flake8`, `ruff.toml`
   - PHP: `phpcs.xml`, `.php-cs-fixer.php`
   - Go: `.golangci.yml`
   - General: `.editorconfig`
3. If neither CLAUDE.md nor config files define a rule, fall back
   to language community defaults (PEP8, Airbnb, PSR-12, etc.)

CLAUDE.md rules always win over tool configs when they conflict.

### STEP 2 — SCAN

Systematically scan the target for three categories of issues.

**A. Dead code**
- Unused imports and variables
- Unused functions/methods (not exported, no callers)
- Unreachable code blocks (after return, break, etc.)
- Commented-out code blocks (more than 2 consecutive lines)
- TODO/FIXME comments older than 90 days (check with `git log`)

```bash
# Check age of TODO/FIXME comments
git log --all -p --reverse -S "TODO" -- <file> | head -40
```

**B. Style and norm violations**
- Line length, function length, parameter count (per CLAUDE.md limits)
- Naming inconsistencies (mixed conventions in same scope)
- Missing or outdated docstrings/headers (only where project norms require them)
- Formatting issues not caught by auto-formatters

**C. Structural issues**
- Files in wrong directory (per project conventions)
- Functions with multiple responsibilities (should be split)
- Inconsistent file/module naming patterns
- Circular or tangled dependencies (where detectable by reading imports)

### STEP 3 — BUILD REPORT

Produce a structured report with three sections.
Each item follows this format:
```
file:line — description — severity — proposed fix
```

Severity levels:
- **blocking**: must fix (dead code with side-effect risk, norm violation that breaks build/lint)
- **warn**: should fix (unused code, style violations, naming inconsistencies)
- **info**: optional improvement (minor structural suggestions)

```
CODE-CLEAN AUDIT — <target>
Scanned: <N files, N lines>
Norms source: <CLAUDE.md / .eslintrc / PEP8 fallback / etc.>

═══ DEAD CODE ═══
  1. src/utils.py:42 — unused import `os` — warn — delete import
  2. src/api/handler.ts:118-134 — commented-out block — warn — delete block
  3. ...

═══ STYLE VIOLATIONS ═══
  1. src/core/parser.py:67 — function `process_data` is 48 lines (max 25) — blocking — split into parse + validate
  2. ...

═══ STRUCTURAL ISSUES ═══
  1. lib/helpers/auth.ts — auth logic in helpers/, should be in lib/auth/ — info — move file
  2. ...

TOTALS: <N blocking, N warn, N info>
```

If no issues found: report clean state and stop.

### VALIDATION GATE

Present the report. Ask the user:
- Which items to approve for execution
- Which items to skip
- Any items needing clarification

**Do NOT proceed to Phase 2 until the user explicitly approves.**

If the user says "all" or "go ahead" → approve everything.
If the user cherry-picks → execute only approved items.

#### Empty-approval branch

If the user denies every item, replies "skip", "none", "don't fix anything", or
declines to approve any item:

1. Print:
   ```
   CODE-CLEAN — NO-OP
   APPROVED: 0 items
   ACTION  : audit only — no files modified
   ```
2. Skip Phase 2 entirely. Do NOT run STEP 4–7.
3. Still write the audit report to `.claude/audits/CODE-CLEAN.md` so the
   findings are recorded for next session.
4. Still write `.claude/audits/BUGS-FOUND.md` if STEP 3 detected real bugs
   (those are signal regardless of cleanup approval).
5. Exit cleanly with summary `"Audit recorded. No changes applied."` — do not
   warn or escalate. The user's "no" is a valid outcome.

---

## PHASE 2 — EXECUTION (after approval)

### STEP 4 — DELETE DEAD CODE

Process approved dead-code items first — they're the safest changes:

- Remove unused imports, variables, functions
- Delete commented-out code blocks
- Remove stale TODO/FIXME comments

**Guard rail**: if a symbol is exported or part of a public API,
do NOT delete it even if it appears unused internally. Flag it
and ask for explicit per-item confirmation.

### STEP 5 — STYLE FIXES + STRUCTURAL REFACTORING

For approved style and structural items:

1. Load and follow `$HOME/.claude/agents/refactorer.md`
2. Pass the approved list as the refactoring scope
3. The refactorer handles the actual code changes with its own
   safety process (pre-report, function-by-function, test after each)

Do NOT call the `/refactor` skill — invoke the agent directly.

### STEP 6 — LOG DISCOVERED BUGS

If cleanup reveals actual bugs (not style issues — real defects):

- Append each bug to `.claude/audits/BUGS-FOUND.md` (run `mkdir -p .claude/audits` first):
  ```
  ## [date] Bug found during code-clean
  - **File**: <file:line>
  - **Description**: <what's wrong>
  - **Severity**: <estimate>
  - **Discovered while**: <what cleanup task surfaced it>
  ```
- Do NOT fix bugs here. Cleanup and bugfixing are separate concerns.

### STEP 7 — RE-AUDIT

After all changes are applied:

1. Re-scan only the modified files
2. Verify no new issues were introduced
3. Run tests if available:
   ```bash
   # detect and run project test suite
   ```
4. Run linter/formatter if available

### STEP 8 — SUMMARY

```
CODE-CLEAN COMPLETE — <target>

REMOVED:
- <N> dead code items (unused imports, functions, commented blocks)

REFACTORED:
- <N> style fixes
- <N> structural improvements

SKIPPED (user decision):
- <item> — <reason>

BUGS FOUND: <N> (logged to .claude/audits/BUGS-FOUND.md)

TESTS: passing / no test suite / <failures>
```

---

## RULES

- Zero behavior change. If you're unsure whether a deletion changes
  behavior, leave it and flag it — never guess.
- No "while we're here" scope creep. Only fix approved items.
- Exported/public API symbols require explicit per-item user confirmation
  before deletion — even if they appear unused.
- Bugs go to .claude/audits/BUGS-FOUND.md, not fixed in this workflow.
- If the codebase has no tests and the changes are non-trivial,
  warn the user about the risk before executing.
- No plugin check (lightweight skill, not an orchestrator).
- If the audit reveals systemic issues requiring architecture changes,
  stop and suggest `/ship-feature` for a proper redesign.
