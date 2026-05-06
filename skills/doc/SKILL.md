---
name: doc
description: |
  Full documentation audit and sync. Auto-detects what doc files the project
  actually has — root docs (README, CLAUDE.md, INSTALL.md, CONFIGURE.md,
  USAGE.md, DEPLOY.md, CONTRIBUTING.md, CHANGELOG.md), docs/**/*.md, project-state
  files in .claude/{tasks,audits,memory}/, and inline comments (JSDoc, docstrings,
  rustdoc, godoc). Stack-aware: detects framework + deploy complexity, proposes
  DEPLOY.md only when non-trivial (Docker, fly.toml, k8s, multi-stage CI), skips
  for trivial deploys (FTP push, single scp, plain static). Enforces README
  presence with typical GitHub layout (title, quick start, links to existing
  sub-docs). Cross-references git history for drift; detects added features
  missing from docs and removed features still documented (feature delta
  detection). Reports drift with commit refs, proposes fixes, patches approved
  items.
  Trigger: "doc", "sync docs", "audit docs", "update readme", "check documentation",
  "are docs up to date", "documentation drift", "stale docs", "new feature not documented",
  "removed feature still in docs", "create README", "should I have a DEPLOY doc".
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
