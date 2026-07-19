---
name: plugin-check
description: 'Audit active plugins vs project needs. Read-only advisory recommending enable/disable. Triggers: "plugin-check", "quels plugins".'
argument-hint: '[ex: "React + FastAPI" or "Rust CLI, no frontend"]'
allowed-tools: Read, Bash, Glob, Grep, Agent
---

Run `$HOME/.claude/lib/plugin-gate.md` on the context below — dispatch
plugin-probe (sonnet) → validation checkpoint → dispatch plugin-advisor
(opus) → present the PLUGIN CHECK block (BDR-077: detection and reasoning
dispatched, gates in this loop).

/plugin-check is READ-ONLY advisory: SKIP the gate's step 5 (apply) — show
the advisor's exact toggle commands for the user instead. Never write; user
toggles via `claude plugin enable/disable`.

If `$HOME/.claude/lib/plugin-gate.md` unreachable: emit `Plugin gate include
missing.` and STOP.

$ARGUMENTS
