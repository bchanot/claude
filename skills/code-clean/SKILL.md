---
name: code-clean
description: |
  Full codebase cleanup: dead code removal, style/norm enforcement, structural
  issues. Two-phase workflow: audit first (read-only report), then execute
  approved fixes only. Delegates refactoring to the refactorer agent.
  Trigger: "code-clean", "clean up the code", "remove dead code",
  "enforce code style", "cleanup", "nettoyage du code", "code hygiene".
  For targeted refactoring without audit → use /refactor instead.
  For bug fixes discovered during cleanup → logged to .claude/audits/BUGS-FOUND.md, not fixed here.
argument-hint: <file, directory, or blank for entire project>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

Load and follow strictly:
- $HOME/.claude/agents/code-cleaner.md

Execute the CODE-CLEANER agent on the following target:

$ARGUMENTS
