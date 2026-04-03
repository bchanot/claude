# claude-config

Global Claude Code configuration — agents, skills, plugins, and project templates.

---

## Overview

This repo is your personal Claude Code setup, versioned and reproducible across machines.

```
claude-config/
├── CLAUDE.md              # Global coding preferences (style, rules, workflow)
├── settings.json          # Global permissions (deny/ask/allow + enabledPlugins)
├── install-plugins.sh     # One-shot installer: prerequisites + all plugins
├── link.sh                # Symlinks this repo into ~/.claude/
├── hooks/
│   └── session-start.sh   # Shows toggle plugin status at every session start
├── agents/
│   ├── analyzer.md        # Factual codebase analysis (read-only)
│   ├── interviewer.md     # Project questionnaire → PROJECT BRIEF
│   ├── plugin-advisor.md  # Plugin check: detect mismatches, recommend actions
│   ├── readme-updater.md  # Update README from git history + codebase
│   ├── refactorer.md      # Surgical refactoring with norm enforcement
│   └── scaffolder.md      # Full project generation (CLAUDE.md, README, code)
├── skills/
│   ├── analyze/           # /analyze — deep factual analysis
│   ├── init-project/      # /init-project — full project initialization
│   ├── plugin-check/      # /plugin-check — check plugin config vs project needs
│   ├── readme/            # /readme — update README from current state
│   ├── refactor/          # /refactor — improve code without changing behavior
│   └── ship-feature/      # /ship-feature — ship a feature end-to-end
└── templates/
    ├── project-CLAUDE.md  # Template for per-project CLAUDE.md
    └── settings/
        ├── home-settings.json    # Template for ~/.claude/settings.json
        ├── settings.json         # Template for project .claude/settings.json
        ├── settings.local.json   # Template for personal .claude/settings.local.json
        ├── .claudeignore         # Template for project .claudeignore
        └── SETTINGS.md           # Full settings reference
```

**Architecture principle:**
- `skills/` = entry points you invoke via `/skill-name`
- `agents/` = execution units called by skills (never invoked directly by user)
- Custom skills use **Superpowers** agents for implementation phases
- **Plugins** (Superpowers, GStack, GSD, etc.) install separately and complement custom skills

---

## Fresh install (new machine)

```bash
# 1. Clone this repo
git clone git@github.com:youruser/claude-config.git ~/claude-config

# 2. Symlink into ~/.claude/
cd ~/claude-config && bash link.sh

# 3. Install prerequisites + all plugins (detects OS, installs git/Node/Rust/Python)
bash ~/claude-config/install-plugins.sh

# 4. Add Context7 API key (free at context7.com) — manual step
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp --api-key YOUR_KEY

# 5. Restart Claude Code then run /reload-plugins
```

The install script handles: git, Node.js 22, Rust/Cargo, Python 3, RTK, GStack, GSD,
and all marketplace plugins on Linux (apt/dnf/pacman) and macOS (brew).

---

## Available slash commands

### Custom skills (this repo)

| Command | Description |
|---|---|
| `/analyze` | Deep factual analysis of code before any modification |
| `/refactor` | Improve code quality without changing behavior (strict norms) |
| `/readme` | Full README audit — diff vs codebase, mandatory stop, surgical updates |
| `/plugin-check` | Check active plugins vs project needs — recommend enable/disable |
| `/init-project` | Initialize a complete project from scratch (full orchestrator) |
| `/ship-feature` | Ship a feature end-to-end with validation gates (full orchestrator) |

### Superpowers skills (auto-invoked or explicit)

| Command | When it auto-activates |
|---|---|
| `/superpowers:brainstorm` | When you describe something to build |
| `/superpowers:write-plan` | After design is approved |
| `/superpowers:execute-plan` | With an approved plan |
| `systematic-debugging` | Auto — when debugging |
| `test-driven-development` | Auto — when implementing |
| `requesting-code-review` | Auto — after a feature step |

### GStack skills (Garry Tan — full-product projects only)

> Install: `git clone https://github.com/garrytan/gstack ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup`
> **Use when:** project has UI + design + deploy + browser QA. Skip for backend/lib/CLI projects.

| Command | Description |
|---|---|
| `/office-hours` | Discovery consultant — scope and challenge before code |
| `/plan-ceo-review` | CEO challenges product scope and feature value |
| `/plan-eng-review` | Staff engineer locks architecture decisions |
| `/design-consultation` | Build a design system from scratch |
| `/design-shotgun` | Generate multiple visual variants for comparison |
| `/design-html` | Turn approved mockup into production HTML |
| `/review` | Code review (GStack version) |
| `/ship` | One-command: test → build → deploy |
| `/qa` | QA with real Chrome browser automation |
| `/browse` | Headless Chrome web navigation |
| `/careful` | Activate safety guardrails |
| `/freeze` | Lock edits to current directory |
| `/retro` | Engineering retrospective |
| `/gstack-upgrade` | Self-update GStack |

### GSD skills (glittercowboy — multi-session large features)

> Install: `npx get-shit-done-cc --claude --global`
> **Use when:** feature spans multiple days/sessions. Each session starts fresh with full context from previous phases.

| Command | Description |
|---|---|
| `/gsd:discuss-phase` | Refine spec for a phase through conversation |
| `/gsd:plan-phase` | Generate hierarchical phase plan |
| `/gsd:execute-phase` | Execute phase in an isolated context window |
| `/gsd:ship` | Create PR from verified work |
| `/gsd:next` | Auto-advance to the next phase |

### Other plugin commands

| Command | Plugin | Description |
|---|---|---|
| `/pr-review-toolkit:review-pr` | pr-review-toolkit | Multi-agent PR review (6 specialized agents) |
| `/context7:docs <lib>` | context7 | Manual doc lookup for a specific library |

---

## Orchestrators in detail

### `/init-project`

Same rigor as `/ship-feature`. Two validation gates. Full TDD subagent pipeline for v1 features.
The Scaffolder only creates the skeleton (no features, no README).
readme-updater handles the README in two passes: CREATE then SYNC.

```
/init-project <project idea>
    │
    ├── STEP 0:  PLUGIN CHECK (plugin-advisor)        ← blocks if wrong plugins
    ├── STEP 1:  INTERVIEWER (custom)                 → PROJECT BRIEF
    ├── STEP 2:  ANALYZER (custom)                    → ANALYSIS REPORT
    ├── STEP 3:  superpowers:brainstorming             → VALIDATED DESIGN
    ├── STEP 4:  VALIDATION GATE #1                   → approve architecture
    ├── STEP 5:  SCAFFOLDER (custom)                  → skeleton only (CLAUDE.md +
    │                                                    settings + structure +
    │                                                    empty entry points, NO features,
    │                                                    NO README)
    ├── STEP 5b: README-UPDATER create mode (custom)  → CREATE README from CLAUDE.md
    ├── STEP 6:  superpowers:writing-plans             → decompose v1 features into tasks
    ├── STEP 7:  VALIDATION GATE #2                   → approve task plan
    ├── STEP 8:  superpowers:subagent-driven (TDD)    → implement each feature (isolated)
    ├── STEP 9:  ANALYZER (custom)                    → regression + deviation check
    ├── STEP 10: superpowers:requesting-review         → full code review
    ├── STEP 11: superpowers:finishing-branch          → cleanup + build + tests
    └── STEP 12: README-UPDATER sync mode (custom)    → sync README with implementation
```

### `/ship-feature`

```
/ship-feature <feature description>
    │
    ├── STEP 0: PLUGIN CHECK (plugin-advisor) ← blocks if wrong plugins active
    ├── STEP 1: superpowers:brainstorming     → VALIDATED DESIGN
    ├── STEP 2: superpowers:writing-plans     → task plan
    ├── STEP 3: VALIDATION GATE               → user approval required
    ├── STEP 4: superpowers:subagent-driven   → implementation (TDD)
    ├── STEP 5: ANALYZER (custom)             → regression / deviation check
    ├── STEP 6: superpowers:requesting-review → code review
    └── STEP 7: superpowers:finishing-branch  → cleanup
```

### `/plugin-check`

Standalone command you can run at any time to audit your plugin config
against what you're about to do. Also embedded as STEP 0 in both orchestrators.

```
/plugin-check "I want to build a React + FastAPI SaaS"

→ Detects active plugins
→ Analyzes signals: frontend? design? QA? multi-session? fast-evolving libs?
→ Produces recommendation table
→ Blocks with OPTIONS if critical plugins are missing
→ Or confirms "proceed" if config is optimal
```

---

## Plugins reference

All plugins below are installed by `install-plugins.sh`.

### Quick reference

The mechanism: Claude Code loads every active skill's **description** into a shared context budget
at session start (default 8000 chars). Even if you never invoke the skill, its description
is already consuming tokens. **Disabling a plugin prevents its descriptions from loading entirely.**

A `hooks/session-start.sh` hook shows the current toggle status at the start of every session.
Run `/plugin-check` anytime to get a full recommendation for the current project type.

| Plugin | Status | Passive cost | When to toggle ON | Installed by |
|---|---|---|---|---|
| **security-guidance** | ✅ ALWAYS ON | 0 tokens (hook only) | — | marketplace |
| **RTK** | ✅ ALWAYS ON | 0 tokens (hook only) | — | cargo + rtk init |
| **Superpowers** | ✅ ALWAYS ON | ~600–1000 tokens | — auto-activates when relevant | marketplace |
| **skill-creator** | ✅ ALWAYS ON | ~100 tokens | — | marketplace |
| **pr-review-toolkit** | ✅ ALWAYS ON | ~300 tokens | — use `/pr-review-toolkit:review-pr` | marketplace |
| **GStack** | 🔄 TOGGLE | ~2500–3000 tokens | Full-product: UI + design + deploy + browser QA | git clone |
| **GSD** | 🔄 TOGGLE | ~500–800 tokens | Feature spanning multiple days/sessions | npx |
| **frontend-design** | 🔄 TOGGLE | ~200 tokens | Any project with a UI | marketplace |
| **ui-ux-pro-max** | 🔄 TOGGLE | ~400 tokens | Design system, color/typography choices | marketplace |
| **Context7 MCP** | 🔄 TOGGLE | ~200 tokens | Fast-evolving libs (Next.js, React, Prisma…) | MCP manual |

**Rule:** toggle plugins are OFF by default. `/plugin-check` signals when to enable them.
If you use `/init-project` or `/ship-feature`, plugin-check runs automatically as STEP 0.

### Disabling a plugin for a specific project

```bash
# In Claude Code
/plugin
# → Find the plugin → toggle off for this scope
```

Or in the project's `.claude/settings.json`:
```json
{
  "enabledPlugins": {
    "gstack@gstack": false,
    "gsd@gsd": false
  }
}
```

### Enabling a plugin for a specific project (so teammates can install it)

```json
{
  "enabledPlugins": {
    "ui-ux-pro-max@ui-ux-pro-max-skill": true
  },
  "extraKnownMarketplaces": {
    "ui-ux-pro-max-skill": {
      "source": {
        "source": "github",
        "repo": "nextlevelbuilder/ui-ux-pro-max-skill"
      }
    }
  }
}
```

---

## Settings and permissions

### File hierarchy

```
Highest
  managed-settings.json        — enterprise, cannot be overridden
  CLI flags                    — --allowedTools / --disallowedTools (session only)
  .claude/settings.local.json  — personal machine overrides (gitignored)
  .claude/settings.json        — project rules (committed to project repo)
  ~/.claude/settings.json      — global user rules (this repo's settings.json)
Lowest

DENY always wins over ALLOW at any level.
.claudeignore applies independently of all permission rules.
```

### Global settings (this repo's `settings.json`)

| Section | Purpose |
|---|---|
| `deny` — secrets | Blocks `.env`, `.pem`, `.key`, SSH keys, cloud credentials |
| `deny` — destructive | Blocks `rm -rf`, `git push --force`, `chmod 777` |
| `deny` — system | Blocks `sudo`, `ssh`, `scp`, `crontab`, `systemctl` |
| `deny` — injection | Blocks `curl \| bash`, `wget \| sh` |
| `ask` — risky | Prompts before `git push`, `docker run`, package managers |
| `allow` — safe reads | Auto-approves git read-only, `ls`, `cat`, `grep`, `find` |
| `disableBypassPermissionsMode` | Prevents YOLO mode globally |

### Per-project setup

```bash
cd your-project
mkdir -p .claude

# Project settings (commit to project git)
cp ~/claude-config/templates/settings/settings.json .claude/settings.json

# Personal overrides (never commit — gitignore it)
cp ~/claude-config/templates/settings/settings.local.json .claude/settings.local.json
echo ".claude/settings.local.json" >> .gitignore

# Hard file exclusions (commit to project git)
cp ~/claude-config/templates/settings/.claudeignore .claudeignore

# Project CLAUDE.md (commit to project git)
cp ~/claude-config/templates/project-CLAUDE.md .claude/CLAUDE.md
```

---

## Updating

### This repo
```bash
cd ~/claude-config && git pull
# Symlinks → changes active immediately
```

### GStack
```bash
/gstack-upgrade        # inside Claude Code
# or manually:
git -C ~/.claude/skills/gstack pull && cd ~/.claude/skills/gstack && ./setup
```

### Marketplace plugins
```bash
/plugin marketplace update    # inside Claude Code
```

### RTK
```bash
cargo install --git https://github.com/rtk-ai/rtk --force
```

---

## Adding a new custom skill

1. Create `agents/myagent.md` — role, tasks, rules, output format
2. Create `skills/myskill/SKILL.md`:

```markdown
---
name: myskill
description: What this skill does — front-load the key use case (max 250 chars)
argument-hint: <what to pass>
disable-model-invocation: true
---

Load and follow strictly:
- .claude/agents/myagent.md

Execute MYAGENT on:

$ARGUMENTS
```

3. Or use `/skill-creator` to generate a skill from conversation.

---

## Per-project agent overrides

Override any global agent for a specific project:

```bash
cp ~/claude-config/agents/refactorer.md .claude/agents/refactorer.md
# Edit .claude/agents/refactorer.md — the local version takes precedence
```
