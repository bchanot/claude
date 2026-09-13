---
name: analyze
description: 'Deep factual code analysis (read-only) or DEBUG mode (pass error/stack trace) — no solutions proposed, no file modifications. Triggers: "analyze", "analyse", "how does X work", "comment ça marche", "investigate only", "root cause only, no fix", "pourquoi ce comportement", "debug analysis". Fix wanted → /bugfix or /hotfix instead.'
argument-hint: <file/area to analyze — OR paste error/stack trace for DEBUG mode>
allowed-tools: Read, Grep, Glob, Bash
---

MODEL GATE (blocking): run `$HOME/.claude/lib/model-gate.md` BEFORE anything
below. Verdict `small` → STOP — print the gate's remedy, end the turn, run
no analysis. Deep factual analysis is reflection; it needs the big model.

Load and follow strictly:
- $HOME/.claude/agents/analyzer.md

Execute the ANALYZER agent on the following target:

$ARGUMENTS
