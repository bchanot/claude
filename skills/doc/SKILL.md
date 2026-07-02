---
name: doc
description: |
  Use when documentation may be out of sync with code — features
  added/removed vs README / INSTALL / DEPLOY / CHANGELOG. Stack-aware
  audit, cross-references git history, patches approved items.
  Triggers: "doc", "sync docs", "update readme", "documentation drift",
  "stale docs", "docs à jour ?", "create README", "should I have a
  DEPLOY doc".
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
