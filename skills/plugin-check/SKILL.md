---
name: plugin-check
description: Audit active plugins vs project needs. Recommends enable/disable actions.
argument-hint: [ex: "React + FastAPI" or "Rust CLI, no frontend"]
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

Load and follow strictly:
- $HOME/.claude/agents/plugin-advisor.md

Analyze active plugins and the following context,
then produce the full PLUGIN ADVISOR REPORT:

$ARGUMENTS
