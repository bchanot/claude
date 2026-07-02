---
name: code-clean
description: |
  Full codebase cleanup: dead code, style/norm enforcement, structural
  issues. Two-phase: read-only audit, then approved fixes only
  (refactorer agent).
  Triggers: "code-clean", "remove dead code", "cleanup", "nettoyage du
  code", "code hygiene".
  Targeted refactor without audit → /refactor. Bugs found → logged to
  .claude/audits/BUGS-FOUND.md, not fixed here.
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
