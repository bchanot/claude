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
  - Agent
---

Dispatch the doc-syncer as a subagent so its `model: sonnet` pin takes
effect (doc-sync = execution, not the session's big model):

Agent(subagent_type="doc-syncer")
prompt: "Audit + sync public docs for this project. Context from the user:
  $ARGUMENTS. Report PATCHED_FILES and a summary — do NOT commit."

Then commit the patched docs from THIS loop per `$HOME/.claude/lib/doc-commit.md`
(surgical: only doc-syncer's PATCHED_FILES, never `.claude/`/`CLAUDE.md`,
no-op if nothing patched).
