---
name: readme
description: Update the project README to reflect the current state of the codebase. Audits what is outdated, missing, or no longer accurate, then applies surgical updates. Preserves existing structure and style.
argument-hint: [what changed, feature name, or leave empty for full audit]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

Load and follow strictly:
- .claude/agents/readme-updater.md

Execute the README UPDATER on this project.

Context from the user (if any):
$ARGUMENTS
