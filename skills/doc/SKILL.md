---
name: doc
description: |
  Full documentation audit and sync. Detects stale docs by cross-referencing
  git history against README, CLAUDE.md, INSTALL.md, CONFIGURE.md, USAGE.md,
  CONTRIBUTING.md, CHANGELOG.md, docs/**/*.md, and inline comments (JSDoc,
  docstrings, rustdoc, godoc). Reports drift with commit refs, proposes fixes,
  patches approved items. Detects added features missing from docs and removed
  features still documented (feature delta detection).
  Trigger: "doc", "sync docs", "audit docs", "update readme", "check documentation",
  "are docs up to date", "documentation drift", "stale docs", "new feature not documented",
  "removed feature still in docs".
  Replaces the old /readme skill with broader scope.
argument-hint: [leave empty for full audit, or list specific files/docs to check]
disable-model-invocation: false
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

Load and follow strictly:
- $HOME/.claude/agents/doc-syncer.md

Execute the DOC SYNCER on this project.

Context from the user (if any):
$ARGUMENTS
