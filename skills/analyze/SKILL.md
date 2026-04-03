---
name: analyze
description: Deep factual code analysis — read-only, no solutions proposed
argument-hint: <code, file, or area to analyze>
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Load and follow strictly:
- .claude/agents/analyzer.md

Execute the ANALYZER agent on the following target:

$ARGUMENTS
