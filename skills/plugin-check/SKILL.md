---
name: plugin-check
effort: low
description: 'Audit active plugins vs project needs. Read-only advisory recommending enable/disable. Triggers: "plugin-check", "quels plugins".'
argument-hint: '[ex: "React + FastAPI" or "Rust CLI, no frontend"]'
allowed-tools: Read, Bash, Glob, Grep, Agent
---

Run `$HOME/.claude/lib/plugin-gate.md` on the context below — dispatch
plugin-probe (sonnet) → validation checkpoint → dispatch plugin-advisor
(opus) → present the PLUGIN CHECK block (BDR-077: detection and reasoning
dispatched, gates in this loop).

/plugin-check is READ-ONLY advisory: SKIP the gate's step 5 (apply) — show
the advisor's exact commands for the user instead. Never write: the user runs
them (`lib/profile.sh` `set <profile>` / `enable <pack>` writes the
project's `.claude/settings.local.json`, never the user scope).

If `$HOME/.claude/lib/plugin-gate.md` unreachable: emit `Plugin gate include
missing.` and STOP.

$ARGUMENTS
