---
name: commit-change
version: 1.0.0
description: |
  Analyze all pending changes (staged, unstaged, untracked) and create
  atomic commits grouped by logical unit, retracing the work. Any git
  repository.
  Triggers: "commit my changes", "smart commit", "auto commit", "commit
  everything", "analyse et commit", or any variation of committing messy
  pending work intelligently.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

Load and follow strictly: `$HOME/.claude/agents/commit-changer.md`.

If unreachable, emit `Commit-changer agent missing.` and STOP. Never auto-commit blind — a wrong group is harder to undo than not committing.

Pre-flight checks (the agent should also perform, but flag here):
- Detached HEAD or unmerged conflicts → STOP, report state.
- Identity unconfigured (`git config user.email` empty) → STOP, ask user.

$ARGUMENTS
