---
name: status
description: 'Consolidated project snapshot — plugins, token cost, git state, recent commits, GSD v2 milestone progress. Read-only. Run at session start or after a break. Open-work reconciliation (stale TODO vs real git) → /reconcile. Triggers: "status", "sitrep", "where are we", "project state", "after break".'
argument-hint: (no arguments needed)
allowed-tools: Read, Bash, Glob, Grep, Agent
---

Dispatch the status-reporter as a subagent so its `model: haiku` pin takes
effect (read-only collection = cheapest tier, off the big session model):

Agent(subagent_type="status-reporter")
prompt: "Produce the full PROJECT STATUS report for the current working
  directory. $ARGUMENTS"

## Fallback when agent file missing

If `$HOME/.claude/agents/status-reporter.md` is unreachable (deleted, permission denied, broken symlink):

1. Emit: `Status agent missing — restore ~/.claude/agents/status-reporter.md.`
2. STOP. Do not improvise a manual report — partial snapshots mislead.

$ARGUMENTS
