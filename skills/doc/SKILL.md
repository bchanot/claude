---
name: doc
description: |
  Use when documentation may be out of sync with code — added features
  missing from docs, removed features still documented, or README / INSTALL
  / DEPLOY / CHANGELOG drift detected. Stack-aware audit, cross-references
  git history, patches approved items.
  Triggers: "doc", "sync docs", "audit docs", "update readme", "check
  documentation", "are docs up to date", "documentation drift", "stale docs",
  "new feature not documented", "removed feature still in docs",
  "create README", "should I have a DEPLOY doc".
argument-hint: [leave empty for full audit, or list specific files/docs to check]
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
