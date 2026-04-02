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
rm -rf ~/claude/agents ~/claude/skills ~/claude/CLAUDE.md ~/claude/settings.json

ln -sf ~/claude-config/agents    ~/.claude/agents
ln -sf ~/claude-config/skills    ~/.claude/skills
ln -sf ~/claude-config/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/claude-config/settings.json ~/.claude/settings.json
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

## Settings and permissions

Claude Code uses three settings files to control what it can and cannot do.
Each file has a different scope and purpose.

### `~/.claude/settings.json` — global rules (all projects)

**What it contains and why:**

| Section | What it blocks / controls |
|---|---|
| `deny` — secrets | Prevents Claude from reading `.env`, `.pem`, `.key`, SSH keys, cloud credentials |
| `deny` — destructive Bash | Blocks `rm -rf`, `git push --force`, `git reset --hard`, `chmod 777` |
| `deny` — system access | Blocks `sudo`, `ssh`, `scp`, `netcat`, `crontab`, `systemctl` |
| `deny` — code injection | Blocks `curl \| bash`, `wget \| sh` patterns |
| `ask` — risky but needed | Prompts before `git push`, `docker run`, `brew/apt install` |
| `allow` — safe read ops | Auto-approves `git status/log/diff`, `ls`, `cat`, `grep`, `find` |
| `disableBypassPermissionsMode` | Prevents switching to "no prompts at all" mode mid-session |

These rules apply to every project on your machine. They cannot be
overridden by project-level settings — **deny always wins globally**.

---

### `.claude/settings.json` — project rules (committed to git)

Copy the project template into each new project:

```bash
mkdir -p .claude
cp ~/claude-config/templates/settings/settings.json .claude/settings.json
```

**What it contains and why:**

| Section | What it allows / controls |
|---|---|
| `allow` — build commands | Auto-approves `npm run *`, `cargo build/test`, `make`, `pytest`, `flutter *`, etc. |
| `allow` — language tools | Auto-approves formatters, linters, type checkers (ruff, mypy, clippy...) |
| `allow` — runtime commands | Auto-approves `node`, `python`, `php`, `dart` within the project |
| `ask` — database commands | Prompts before `psql`, `mysql`, `mongosh`, `redis-cli` |
| `ask` — deploy commands | Prompts before `make deploy`, `npm run deploy`, `cargo publish` |

Only put project-specific rules here. Generic security rules belong
in `~/.claude/settings.json`, not repeated per project.

Shared with the team via git — keep it stack-appropriate and avoid
personal paths or machine-specific commands.

---

### `.claude/settings.local.json` — personal overrides (never committed)

Copy the template and add to `.gitignore`:

```bash
cp ~/claude-config/templates/settings/settings.local.json .claude/settings.local.json
echo ".claude/settings.local.json" >> .gitignore
```

**What it contains and why:**

| Section | What it controls |
|---|---|
| `allow` — trusted WebFetch | Auto-approves fetching from specific doc domains (docs.rs, MDN, flutter.dev...) |
| `additionalDirectories` | Grants Claude access to directories outside the project root (personal shared libs, etc.) |
| Personal overrides | Any rule you want on your machine that shouldn't affect teammates |

This file has the highest priority of all file-based settings.
Use it for anything environment-specific or personal.

---

### `.claudeignore` — hard file exclusion (committed to git)

Copy to each project root:

```bash
cp ~/claude-config/templates/settings/.claudeignore .claudeignore
```

**What it does and why it is different from `deny` rules:**

`deny` rules in `settings.json` block specific tools from accessing files.
`.claudeignore` goes further — it removes files from Claude's awareness
entirely, regardless of which tool is used.

| Excluded by default | Why |
|---|---|
| `.env`, `.env.*` | Secrets must never appear in Claude's context |
| `*.pem`, `*.key`, `*.p12` | Private keys and certificates |
| `id_rsa*`, `id_ed25519*`, `.ssh/` | SSH credentials |
| `.aws/`, `.azure/`, `.gcloud/` | Cloud provider credentials |
| `node_modules/`, `dist/`, `build/` | Generated artifacts — noise, no value |
| `*.png`, `*.jpg`, `*.pdf`, `*.zip`... | Binaries Claude cannot process usefully |
| `*.log`, `*.sqlite`, `*.db` | Runtime state, not source |

A `.env` file excluded via `.claudeignore` cannot be read by Claude even
if a `Bash(cat .env)` would otherwise be allowed. Use both layers for
defense in depth.

---

### Precedence summary

```
Highest
  managed-settings.json   — enterprise-wide, cannot be overridden
  CLI flags               — --allowedTools / --disallowedTools (session only)
  settings.local.json     — personal machine overrides
  settings.json           — project rules (team, committed)
  ~/.claude/settings.json — global user rules
Lowest

DENY always wins over ALLOW at any level.
.claudeignore applies independently of all permission rules.
```

---

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