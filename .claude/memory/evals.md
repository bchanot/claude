---
type: evals_registry
entry_prefix: EVAL
schema:
  id: EVAL-XXX
  date: YYYY-MM-DD
  output: string (what was produced)
  method: string (how it was evaluated - manual read, test, benchmark, user feedback)
  anomalies: list of strings (what was wrong, missing, surprising)
  action: [keep | correct | deprecate]
rules:
  - Log an eval whenever you validate the quality of something Claude produced (report, audit, plan, generated code).
  - Action keep - the output is fit for purpose as-is.
  - Action correct - needs revision; capture what.
  - Action deprecate - the approach itself is flawed; link to the decision that replaces it.
---

# Evals registry (EVAL)

## Index

| ID | Date | Output | Action |
|----|------|--------|--------|
| EVAL-001 | 2026-04-23 | `.claude/` restructure plan (ship-feature STEP 2) | keep |

---

## EVAL-001 — `.claude/` restructure plan

- **Date**: 2026-04-23
- **Output**: 21-task plan migrate `tasks/` to `.claude/tasks/` + create `.claude/memory/` + `.claude/audits/` + integrate CAPITALIZE across 5 skills + add `/close` skill.
- **Method**: manual review of 5 impacted skills/agents; verified `rtk` path-agnostic; confirmed `~/.claude/CLAUDE.md` symlinks to project (single file edit). Radical-honesty check on session-close ritual: confirmed aspirational without skill integration → scope expanded to Option D.
- **Anomalies**: none blocking. Note: `tasks/LESSONS.md` empty (101B, header only) — migration to `learnings.md` symbolic.
- **Action**: keep — plan validated, ready for execution.