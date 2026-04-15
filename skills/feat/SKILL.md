---
name: feat
description: |
  Small feature implementation (1-5 files). Light planning, direct
  implementation, no heavy orchestration. For features that don't
  need the full /ship-feature pipeline (no design brainstorm, no
  subagents, no plugin check gate).
  Trigger: "feat", "small feature", "add this", "petite feature",
  "quick feature", "ajoute ca", "implement this small thing".
  For multi-file features needing design → use /ship-feature.
  For bug fixes → use /hotfix or /bugfix.
argument-hint: <feature description>
disable-model-invocation: false
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
---

Load and follow strictly:
- $HOME/.claude/agents/feater.md

Execute the FEATER agent on the following target:

$ARGUMENTS
