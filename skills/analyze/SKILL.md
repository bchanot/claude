---
name: analyze
description: Deep factual code analysis (read-only) or DEBUG mode (pass error/stack trace) — no solutions proposed, no file modifications
argument-hint: <file/area to analyze — OR paste error/stack trace for DEBUG mode>
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Load and follow strictly:
- $HOME/.claude/agents/analyzer.md

Execute the ANALYZER agent on the following target:

$ARGUMENTS
