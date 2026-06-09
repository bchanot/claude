---
name: hotfix
description: |
  Quick fix for superficial bugs: typos, CSS issues, config errors,
  off-by-one, wrong variable name, missing import, broken link.
  Use when the root cause is obvious and the fix is 1-2 files max.
  Trigger: "hotfix", "quick fix", "typo", "fix this small thing",
  "c'est juste un petit bug", "patch rapide".
  Do NOT use for bugs requiring investigation — use /bugfix instead.
argument-hint: <bug description or error message>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

Load and follow strictly:
- $HOME/.claude/agents/hotfixer.md

Execute the HOTFIXER agent on the following target:

$ARGUMENTS
