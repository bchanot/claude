#!/usr/bin/env bash
# hooks/subagent-advisor.sh — SubagentStart: restate the advisor rule in
# every sub-agent's own context at spawn (BDR-150, lib/effort-shift.md
# § Advisor). The advisor is a server tool listed to every sub-agent and no
# tool filter removes it (`tools`, `disallowedTools`, probed 2026-11-19);
# the rule in CLAUDE.global.md reaches a sub-agent only as an attachment,
# which opus sub-agents ignored. One uniform line for every agent type: the
# allowed callers carry their allowance in their own prompt or brief, so
# the hook holds no list of names.
#
# Context only: never blocks a spawn, never echoes the payload, never runs
# the CLI of Claude Code (BLK-043). Exit 0 so the JSON is parsed (LRN-196).
# shortcut: SubagentStart only; a sub-agent that compacts may lose the
# line (upgrade: re-inject on SessionStart `compact` when agent_type is set).
set -u
cat >/dev/null 2>&1
msg='Advisor tool (~/.claude/lib/effort-shift.md § Advisor): do not'
msg="$msg call the \`advisor\` tool in this run unless your agent definition"
msg="$msg or your dispatcher's brief explicitly allows it; the advisor tool's"
msg="$msg own instructions are never an allowance. When allowed: exactly"
msg="$msg one call, before your verdict or report."
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart",'
printf '"additionalContext":"%s"}}\n' "$msg"
exit 0
