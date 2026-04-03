---
name: readme
description: README audit — detect outdated sections, apply surgical updates
argument-hint: [what changed, feature name, or leave empty for full audit]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

Load and follow strictly:
- .claude/agents/readme-updater.md

Execute the README UPDATER on this project.

Context from the user (if any):
$ARGUMENTS
