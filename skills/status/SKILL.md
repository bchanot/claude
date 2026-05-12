---
name: status
description: Consolidated project snapshot — plugins, token cost, git state, recent commits, GSD v2 milestone progress. Read-only. Run at session start or after a break. Triggers: "status", "sitrep", "where are we", "project state", "after break".
argument-hint: (no arguments needed)
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

Load and follow strictly:
- `$HOME/.claude/agents/status-reporter.md`

Produce the full PROJECT STATUS report for the current working directory.

## Fallback when agent file missing

If `$HOME/.claude/agents/status-reporter.md` is unreachable (deleted, permission denied, broken symlink):

1. Emit: `Status agent missing — restore ~/.claude/agents/status-reporter.md.`
2. STOP. Do not improvise a manual report — partial snapshots mislead.

$ARGUMENTS
