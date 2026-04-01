---
name: ship-feature
description: Ship a feature end-to-end via multi-agent orchestrator
argument-hint: <description de la feature à implémenter>
---

Load and follow strictly these agent files:
- .claude/agents/ship-feature.md
- .claude/agents/analyzer.md
- .claude/agents/designer.md
- .claude/agents/implementer.md
- .claude/agents/reviewer.md
- .claude/agents/tester.md

Execute the orchestrator defined in .claude/agents/ship-feature.md with the following request:

$ARGUMENTS
