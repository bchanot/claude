---
name: refactor
description: 'Improve code quality without changing behavior — strict norm enforcement, targeted scope (file/module). Full-codebase audit+cleanup → /code-clean. Triggers: "refactor", "clean up code", "normaliser".'
argument-hint: <file, function, or module to refactor>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
---

Dispatch the refactorer executor — behavior-preserving norm application is
closed execution, so it runs pinned on **sonnet** (not the big session
model). The scope you name is the only reflection; the agent applies norms.

```
Agent(subagent_type="refactorer")
prompt: "Refactor to strict project norms, preserving external behavior
exactly (zero behavioral regression, existing tests must pass). Target:
$ARGUMENTS"
```

If the refactorer agent is unavailable, emit `Refactorer agent missing.` and
STOP — never improvise, silent behavior change is unsafe.
