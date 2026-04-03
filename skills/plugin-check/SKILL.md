---
name: plugin-check
description: Check active plugins vs current project needs. Recommends enabling or disabling based on context signals (frontend, design, QA, deployment, multi-session, fast-evolving libs). Run before init-project or ship-feature on a new project type.
argument-hint: [project description or feature to build]
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

Load and follow strictly:
- .claude/agents/plugin-advisor.md

Analyze active plugins and the following context,
then produce the full PLUGIN ADVISOR REPORT:

$ARGUMENTS
