---
name: status
description: Consolidated project snapshot — plugins active, token cost, git state, recent commits, GSD v2 milestone progress. Read-only. Run at session start or after a break.
argument-hint: (no arguments needed)
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

Load and follow strictly:
- $HOME/.claude/agents/status-reporter.md

Produce the full PROJECT STATUS report for the current working directory.

$ARGUMENTS
