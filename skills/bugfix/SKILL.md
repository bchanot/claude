---
name: bugfix
description: |
  Structured bug fix with root cause investigation. For bugs where
  the cause isn't immediately obvious, spans multiple files, or
  requires careful analysis before fixing. Includes hypothesis-driven
  investigation and a fix plan.
  Trigger: "bugfix", "debug this", "fix this bug", "pourquoi ca marche pas",
  "investigate and fix", "find and fix", "root cause + fix".
  For obvious 1-2 file fixes → use /hotfix instead.
  For bugs that need investigation only (no fix) → use /analyze.
argument-hint: <bug description, error message, or stack trace>
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
- $HOME/.claude/agents/bugfixer.md

Execute the BUGFIXER agent on the following target:

$ARGUMENTS
