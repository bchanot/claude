---
name: commit-change
version: 1.0.0
description: |
  Analyze all changes since the last commit (staged, unstaged, untracked files)
  and create well-structured commits grouped by logical unit. Use this skill
  whenever the user says "commit my changes", "smart commit", "auto commit",
  "commit everything", "analyse et commit", or any variation of wanting to
  commit their pending work intelligently. Also trigger when the user has
  been working on multiple things and wants to create clean, atomic commits
  from their messy working directory. Works in any git repository.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

Load and follow strictly:
- $HOME/.claude/agents/commit-changer.md

Execute the COMMIT-CHANGER agent on the current working directory.

$ARGUMENTS
