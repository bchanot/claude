---
name: onboard
description: Onboard an existing project into claude-config — generates CLAUDE.md, settings, .claudeignore, optional GSD v2 ROADMAP. Use on repos not created via /init-project.
argument-hint: [optional hints: "Python FastAPI" | "add gsd" | "Next.js monorepo"]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

Load and follow strictly:
- $HOME/.claude/agents/onboarder.md

Run the ONBOARDER agent on the current working directory.

Additional hints from user (if any):
$ARGUMENTS
