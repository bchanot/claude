---
name: code-clean
description: |
  Full codebase cleanup: dead code, style/norm enforcement, structural
  issues. Two-phase: read-only audit, then approved fixes only
  (refactorer agent).
  Triggers: "code-clean", "remove dead code", "cleanup", "nettoyage du
  code", "code hygiene".
  Targeted refactor without audit → /refactor. Bugs found → logged to
  .claude/audits/BUGS-FOUND.md, not fixed here.
argument-hint: <file, directory, or blank for entire project>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

# /code-clean — cleanup orchestrator (audit inline, execution dispatched)

MODEL GATE (blocking): run `$HOME/.claude/lib/model-gate.md` BEFORE any
step below. Verdict `small` → STOP — print the gate's remedy, end the
turn, dispatch nothing.

## TARGET
$ARGUMENTS

If blank → entire project from repository root.

The audit (STEPS 1-3) runs inline, on the session model — reading code and
judging severity is reflection. Once the user approves a scope (STEP 4),
execution is dispatched to the sonnet-pinned `code-cleaner` executor
(STEP 5). The iron law is unchanged across both halves: zero behavior
change — identical observable output before and after.

---

## STEP 1 — LOAD PROJECT NORMS

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

## STEP 2 — SCAN

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

## STEP 3 — BUILD REPORT

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

## STEP 4 — VALIDATION GATE (interactive)

Present the report from STEP 3. Then ask:

```
AskUserQuestion:
  Approve which items for execution? (all / <item numbers> / clarify <item>)
```

- `all` → every item in the report is approved for execution.
- `<item numbers>` (e.g. `A1,A3,B2`) → only those items are approved; the
  rest stay untouched.
- `clarify <item>` → discuss the item, then re-ask.

**Exported / public-API symbols**: any dead-code item flagged as exported or
part of a public API requires EXPLICIT per-item confirmation before it can
be approved — even if it appears unused internally. Ask for it by name; do
not fold it into a blanket `all`. This consent lives HERE, at the gate —
the dispatched executor never asks, it only executes what this step already
cleared.

**Do NOT proceed to STEP 5 until the user explicitly approves.** If nothing
is approved, stop — no dispatch.

## STEP 5 — PERSIST SCOPE + DISPATCH

1. **Persist the approved scope.** Write the approved items to
   `.claude/audits/CODE-CLEAN-SCOPE.md` (run `mkdir -p .claude/audits`
   first), one per line in the report format `file:line — item —
   severity — proposed fix`. This is the executor's scope-of-work on
   disk — named, auditable, the same contract discipline as the dev
   gates (verifier reads its contract from disk).
2. **Dispatch the executor** — sonnet by frontmatter pin, do not override:

   ```
   Agent(subagent_type="code-cleaner")
   prompt: "SCOPE: .claude/audits/CODE-CLEAN-SCOPE.md
   APPROVED: <the approved item list, incl. any per-item exported-symbol clears>
   BRANCH: <current branch — verify with git branch --show-current, never switch>
   Execute PHASE 2 on the approved scope only. Zero behavior change. No commit.
   Finish with the CODE-CLEAN-EXEC REPORT."
   ```

3. Parse the `CODE-CLEAN-EXEC REPORT`:
   - `STATUS : DONE` → STEP 6.
   - `STATUS : BLOCKED` → surface the blocker to the user, stop.

## STEP 6 — SUMMARY

Translate the executor's `CODE-CLEAN-EXEC REPORT` into the user-facing
summary:

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

No commit here — code-clean has never auto-committed. Leave the working
tree for the user, or a follow-up `/commit-change`.

---

## RULES

- Zero behavior change. If unsure whether a deletion changes behavior,
  leave it and flag it — never guess.
- No "while we're here" scope creep. Only items approved at STEP 4 reach
  the executor.
- Exported/public API symbols require explicit per-item user consent AT
  THE GATE (STEP 4) before approval — even if they appear unused. The
  executor never asks; it only executes what the gate already cleared.
- Bugs go to `.claude/audits/BUGS-FOUND.md`, not fixed in this workflow.
- If the codebase has no tests and the changes are non-trivial, warn the
  user about the risk before dispatching.
- No plugin check (lightweight skill).
- If the audit reveals systemic issues requiring architecture changes,
  stop and suggest `/ship-feature` for a proper redesign.
