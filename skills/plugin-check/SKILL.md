---
name: plugin-check
description: Audit active plugins vs project needs. Recommends enable/disable actions.
argument-hint: [project description or feature to build]
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

Load and follow strictly:
- .claude/agents/plugin-advisor.md

Analyze active plugins and the following context,
then produce the full PLUGIN ADVISOR REPORT:

$ARGUMENTS
