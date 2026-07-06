---
name: plugin-check
description: 'Audit active plugins vs project needs. Read-only advisory recommending enable/disable. Triggers: "plugin-check", "quels plugins".'
argument-hint: '[ex: "React + FastAPI" or "Rust CLI, no frontend"]'
allowed-tools: Read, Bash, Glob, Grep
---

Load and follow strictly: `$HOME/.claude/agents/plugin-advisor.md`.

Analyze active plugins + context below, produce PLUGIN ADVISOR REPORT.

If `$HOME/.claude/agents/plugin-advisor.md` unreachable: emit `Plugin advisor agent missing.` and STOP. Never write — user toggles via `claude plugin enable/disable`.

$ARGUMENTS
