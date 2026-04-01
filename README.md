# claude-config

Global Claude Code configuration — agents, skills, and project templates.

---

## Overview

This repo contains the global Claude Code setup used across all projects.

```
claude-config/
├── CLAUDE.md              # Global coding preferences (style, rules, workflow)
├── agents/                # Specialized agent definitions (called by skills or orchestrators)
├── skills/                # Slash commands (/analyze, /debug, /ship-feature, ...)
└── templates/
    └── project-CLAUDE.md  # Template for per-project .claude/CLAUDE.md
```

**Architecture principle:**
- `skills/` = entry points you invoke manually via `/skill-name`
- `agents/` = execution units called by skills or by orchestrator agents
- A skill delegates to one or more agents — it never contains logic itself

---

## Installation

Clone the repo and symlink it into `~/.claude/`:

```bash
git clone git@github.com:youruser/claude-config.git ~/claude-config

mkdir -p ~/.claude

ln -sf ~/claude-config/agents    ~/.claude/agents
ln -sf ~/claude-config/skills    ~/.claude/skills
ln -sf ~/claude-config/CLAUDE.md ~/.claude/CLAUDE.md
```

Symlinks mean any update to this repo is immediately active — no manual sync needed.

Verify the skills are loaded:

```bash
claude
/skills
```

You should see all custom skills listed (`analyze`, `debug`, `ship-feature`, etc.).

---

## Available slash commands

| Command | Description |
|---|---|
| `/analyze` | Deep analysis of code or a codebase before any modification |
| `/architect` | Design a robust and scalable system architecture |
| `/debug` | Find root cause and fix an issue precisely |
| `/implement` | Implement a feature following project conventions |
| `/refactor` | Improve code quality without changing behavior |
| `/review` | Strict code review with severity-graded issues |
| `/init-project` | Initialize a complete project from scratch (orchestrator) |
| `/ship-feature` | Deliver a feature end-to-end via multi-agent pipeline (orchestrator) |

Orchestrators (`/init-project`, `/ship-feature`) coordinate multiple agents sequentially with validation gates.
Standalone skills (`/analyze`, `/debug`, etc.) invoke a single specialized agent.

---

## Agent pipeline (ship-feature)

```
/ship-feature <request>
    └── ship-feature (orchestrator)
            ├── analyzer    → understand the problem
            ├── designer    → design the solution
            ├── [validation gate — waits for user approval]
            ├── implementer → write the code
            ├── reviewer    → review loop (max 3 iterations)
            └── tester      → define test strategy
```

---

## Per-project setup

Each project gets its own `.claude/CLAUDE.md` for local context and overrides.

```bash
# In your project root
mkdir -p .claude
cp ~/claude-config/templates/project-CLAUDE.md .claude/CLAUDE.md
```

Then fill in the relevant sections: build commands, test commands, conventions,
architecture, and any exceptions to global rules.

**Override rules:**
- Local `.claude/` takes precedence over global `~/.claude/` for identical filenames
- Files not defined locally fall back to global automatically
- Use local overrides only for project-specific deviations — keep global rules generic

---

## Updating

```bash
cd ~/claude-config
git pull
```

Changes are immediately active via symlinks. No restart needed for agents and skills
(Claude Code reloads them at the start of each session).

---

## Adding a new skill or agent

**New standalone skill** (single agent):

1. Create `agents/myagent.md` — define role, tasks, rules, output format
2. Create `skills/myskill.md`:

```markdown
---
name: myskill
description: One-line description of what this skill does
argument-hint: <what to pass as argument>
---

Load and follow strictly:
- .claude/agents/myagent.md

Execute the MYAGENT agent on the following request:

$ARGUMENTS
```

**New orchestrator skill** (multiple agents):

1. Create `agents/myorchestrator.md` — define the workflow and agent call sequence
2. Create `skills/myorchestrator.md` referencing all involved agents

---

## Extending per project

If a project needs a modified version of an agent, place it in `.claude/agents/`:

```bash
# Override the implementer for a specific project
cp ~/claude-config/agents/implementer.md .claude/agents/implementer.md
# Edit to add project-specific constraints
```

The local version takes precedence. All other agents continue to load from global.