---
name: refactor
description: Improve code quality without changing behavior — strict norm enforcement. Triggers: "refactor", "clean up code", "normaliser".
argument-hint: <file, function, or module to refactor>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

Load and follow strictly: `$HOME/.claude/agents/refactorer.md`.

If unreachable, emit `Refactorer agent missing.` and STOP. Never improvise — silent behavior change is unsafe.

$ARGUMENTS
