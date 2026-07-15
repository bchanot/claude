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
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
---

MODEL GATE (blocking): run `$HOME/.claude/lib/model-gate.md` BEFORE loading
the agent below. Verdict `small` → STOP — print the gate's remedy, end the
turn, do not load the agent.

Load and follow strictly:
- $HOME/.claude/agents/feater.md

Execute the FEATER agent on the following target:

$ARGUMENTS
