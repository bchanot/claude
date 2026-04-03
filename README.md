# claude-config

Global Claude Code configuration — agents, skills, plugins, and project templates.

---

## Overview

This repo is your personal Claude Code setup, versioned and reproducible across machines.

```
claude-config/
├── CLAUDE.md              # Global coding preferences (style, rules, workflow)
├── settings.json          # Global permissions (77 deny / 16 ask / 57 allow rules)
├── install-plugins.sh     # One-shot installer: prerequisites + all plugins (reads plugins.lock.json)
├── link.sh                # Symlinks this repo into ~/.claude/
├── doctor.sh              # Setup diagnostic — checks symlinks, plugins, permissions, token budget
├── update-all.sh          # One-command update for all components
├── Makefile               # Unified entry point: make install / doctor / update
├── plugins.lock.json      # Version pinning for non-marketplace dependencies (RTK, GSD)
├── version.txt            # Semver version of this config
├── CHANGELOG.md           # Release history
├── lib/
│   └── detect-plugins.sh  # Shared plugin detection — sourced by all scripts
├── hooks/
│   └── session-start.sh   # Health check + toggle plugin status at session start
├── skills-external/
│   └── gstack/            # Git submodule — garrytan/gstack (symlinked to ~/.claude/skills/gstack)
├── .gitmodules            # Submodule declaration
├── agents/
│   ├── analyzer.md        # Factual codebase analysis (read-only)
│   ├── interviewer.md     # Project questionnaire → PROJECT BRIEF
│   ├── plugin-advisor.md  # Plugin check: detect mismatches, block if Superpowers missing
│   ├── readme-updater.md  # Update README from git history + codebase
│   ├── refactorer.md      # Surgical refactoring with norm enforcement
│   └── scaffolder.md      # Full project generation (CLAUDE.md, README, code)
├── skills/
│   ├── analyze/           # /analyze — deep factual analysis
│   ├── health/            # /health — run setup diagnostic
│   ├── init-project/      # /init-project — full project initialization
│   ├── plugin-check/      # /plugin-check — check plugin config vs project needs
│   ├── readme/            # /readme — update README from current state
│   ├── refactor/          # /refactor — improve code without changing behavior
│   └── ship-feature/      # /ship-feature — ship a feature end-to-end
└── templates/
    ├── project-CLAUDE.md  # Template for per-project CLAUDE.md
    └── settings/
        ├── settings.json         # Template for project .claude/settings.json
        ├── settings.local.json   # Template for personal .claude/settings.local.json
        ├── .claudeignore         # Template for project .claudeignore
        └── SETTINGS.md           # Full settings reference
```

**Architecture principle:**
- `skills/` = entry points you invoke via `/skill-name`
- `agents/` = execution units called by skills (never invoked directly by user)
- `lib/` = shared shell functions sourced by scripts (plugin detection)
- Custom skills use **Superpowers** agents for implementation phases (required — auto-detected)
- **Plugins** (Superpowers, GStack, GSD, etc.) install separately and complement custom skills

---

## Fresh install (new machine)

```bash
# 1. Clone with submodules — choose any location
git clone --recurse-submodules git@github.com:youruser/claude-config.git
cd claude-config

# 2. Symlink into ~/.claude/
bash link.sh

# 3. Install prerequisites + all plugins (detects OS, reads pinned versions from plugins.lock.json)
bash install-plugins.sh

# 4. Add Context7 API key (free at context7.com) — manual step
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp --api-key YOUR_KEY

# 5. Verify setup
bash doctor.sh

# 6. Restart Claude Code then run /reload-plugins
```

All scripts use their own location to find the repo — run them from anywhere or from the repo directory.
Symlinks point to the repo's actual path, so renaming or moving the repo requires re-running `bash link.sh`.

The install script handles: git, Node.js 22, Rust/Cargo, Python 3, RTK, GStack (submodule), GSD,
and all marketplace plugins on Linux (apt/dnf/pacman) and macOS (brew).

RTK and GSD versions are pinned in `plugins.lock.json`. The install script reads those
versions automatically. Marketplace plugins install to `~/.claude/plugins/` (user scope).

Install output is logged to `install-YYYYMMDD-HHMMSS.log` in the repo directory for post-mortem debugging.

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
| `/health` | Run setup diagnostic — check symlinks, plugins, permissions, token budget |

### Superpowers skills (auto-invoked or explicit)

> **Required dependency.** Superpowers must be active for `/init-project` and `/ship-feature`.
> The plugin-advisor (STEP 0) blocks and shows install instructions if Superpowers is missing.

| Command | When it auto-activates |
|---|---|
| `/superpowers:brainstorm` | When you describe something to build |
| `/superpowers:write-plan` | After design is approved |
| `/superpowers:execute-plan` | With an approved plan |
| `systematic-debugging` | Auto — when debugging |
| `test-driven-development` | Auto — when implementing |
| `requesting-code-review` | Auto — after a feature step |

### GStack skills (Garry Tan — full-product projects only)

> Installed as a git submodule at `skills-external/gstack/`, symlinked to `~/.claude/skills/gstack/`.
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

STEP 0 blocks if Superpowers is not installed (required for steps 3, 6, 8, 10, 11).

```
/init-project <project idea>
    │
    ├── STEP 0:  PLUGIN CHECK (plugin-advisor)        ← blocks if Superpowers missing or wrong plugins
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

STEP 0 blocks if Superpowers is not installed (required for steps 1, 2, 4, 6, 7).

```
/ship-feature <feature description>
    │
    ├── STEP 0: PLUGIN CHECK (plugin-advisor) ← blocks if Superpowers missing or wrong plugins
    ├── STEP 1: superpowers:brainstorming     → VALIDATED DESIGN
    ├── STEP 2: superpowers:writing-plans     → task plan
    ├── STEP 3: VALIDATION GATE               → user approval required
    ├── STEP 4: superpowers:subagent-driven   → implementation (TDD)
    ├── STEP 5: ANALYZER (custom)             → regression / deviation check
    ├── STEP 6: superpowers:requesting-review → code review
    ├── STEP 7: superpowers:finishing-branch  → cleanup
    └── STEP 8: README-UPDATER sync mode      → sync README with new feature
```

### `/plugin-check`

Standalone command you can run at any time to audit your plugin config
against what you're about to do. Also embedded as STEP 0 in both orchestrators.

Blocks if Superpowers is not active (required by orchestrators).
Blocks if critical project-specific plugins are missing (frontend tools, Context7, GStack).

```
/plugin-check "I want to build a React + FastAPI SaaS"

→ Detects active plugins
→ Analyzes signals: frontend? design? QA? multi-session? fast-evolving libs?
→ Produces recommendation table
→ Blocks with OPTIONS if critical plugins are missing (including Superpowers)
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
| **RTK** | ✅ ALWAYS ON | 0 tokens (hook only) | — | cargo (pinned in plugins.lock.json) |
| **Superpowers** | ✅ REQUIRED | ~600–1000 tokens | — required by orchestrators, auto-detected | marketplace |
| **skill-creator** | ✅ ALWAYS ON | ~100 tokens | — | marketplace |
| **pr-review-toolkit** | ✅ ALWAYS ON | ~300 tokens | — use `/pr-review-toolkit:review-pr` | marketplace |
| **GStack** | 🔄 TOGGLE | ~2500–3000 tokens | Full-product: UI + design + deploy + browser QA | git submodule |
| **GSD** | 🔄 TOGGLE | ~500–800 tokens | Feature spanning multiple days/sessions | npx (pinned in plugins.lock.json) |
| **frontend-design** | 🔄 TOGGLE | ~200 tokens | Any project with a UI | marketplace |
| **ui-ux-pro-max** | 🔄 TOGGLE | ~400 tokens | Design system, color/typography choices | marketplace |
| **Context7 MCP** | 🔄 TOGGLE | ~200 tokens | Fast-evolving libs (Next.js, React, Prisma…) | MCP manual |

**Rule:** toggle plugins are OFF by default. `/plugin-check` signals when to enable them.
If you use `/init-project` or `/ship-feature`, plugin-check runs automatically as STEP 0
and **blocks if Superpowers is not active**.

### Version pinning

RTK and GSD versions are pinned in `plugins.lock.json`:

```json
{
  "rtk": { "version": "v0.34.3" },
  "gsd": { "version": "1.30.0" }
}
```

`install-plugins.sh` reads these versions automatically.
To update a pinned version: edit `plugins.lock.json`, then re-run `install-plugins.sh`.
GStack is pinned via its git submodule pointer.

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

77 deny rules, 16 ask rules, 57 allow rules.

| Section | Purpose |
|---|---|
| `deny` — secrets (Read) | Blocks `Read` on `.env`, `.pem`, `.key`, SSH keys, cloud credentials |
| `deny` — secrets (Bash) | Blocks `cat`, `head`, `tail`, `grep`, `less`, `more` on `.env` and secret files |
| `deny` — destructive | Blocks `rm -rf`, `git push --force`, `chmod 777` |
| `deny` — system | Blocks `sudo`, `ssh`, `scp`, `crontab`, `systemctl` |
| `deny` — injection | Blocks `curl \| bash`, `wget \| sh` |
| `deny` — escalation | Blocks `bash -c`, `eval`, `exec`, `find -delete`, `perl -e`, `ruby -e` |
| `ask` — risky | Prompts before `git push`, `docker run`, package managers |
| `ask` — write tools | Prompts before `xargs`, `sed -i` (in-place file editing) |
| `allow` — safe reads | Auto-approves git read-only, `ls`, `cat`, `grep`, `find`, `sed` (stdout only) |
| `disableBypassPermissionsMode` | Prevents YOLO mode globally |

### Per-project setup

```bash
cd your-project
mkdir -p .claude

# Find the repo from any existing symlink
CONF="$(dirname "$(readlink ~/.claude/CLAUDE.md)")"

# Project settings (commit to project git)
cp "$CONF/templates/settings/settings.json" .claude/settings.json

# Personal overrides (never commit — gitignore it)
cp "$CONF/templates/settings/settings.local.json" .claude/settings.local.json
echo ".claude/settings.local.json" >> .gitignore

# Hard file exclusions (commit to project git)
cp "$CONF/templates/settings/.claudeignore" .claudeignore

# Project CLAUDE.md (commit to project git)
cp "$CONF/templates/project-CLAUDE.md" .claude/CLAUDE.md
```

---

## Updating

### One-command update (recommended)

```bash
# From the repo directory
bash update-all.sh
# Pulls config, updates GStack submodule, updates RTK (pinned version), refreshes symlinks, runs doctor
```

### Manual updates

#### This repo
```bash
# cd into the repo (wherever you cloned it)
git pull
# Symlinks → changes active immediately
```

#### GStack (submodule)
```bash
# Option A — inside Claude Code (recommended)
/gstack-upgrade

# Option B — via submodule (from the repo directory)
git submodule update --remote skills-external/gstack
cd skills-external/gstack && ./setup
git add skills-external/gstack
git commit -m "chore: update gstack to latest"
```

GStack is a git submodule. Its version is pinned in your config repo — reproducible on every machine.

#### RTK
```bash
# Uses the version pinned in plugins.lock.json (from the repo directory)
bash update-all.sh

# Or manually (check latest at https://github.com/rtk-ai/rtk/releases)
cargo install --git https://github.com/rtk-ai/rtk --tag v0.34.3 --force
```

#### Marketplace plugins
```bash
/plugin marketplace update    # inside Claude Code
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
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
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
CONF="$(dirname "$(readlink ~/.claude/CLAUDE.md)")"
cp "$CONF/agents/refactorer.md" .claude/agents/refactorer.md
# Edit .claude/agents/refactorer.md — the local version takes precedence
```

---

## Maintenance

### Diagnostic

```bash
# Quick check from terminal (from the repo directory)
bash doctor.sh

# Or from within Claude Code
/health

# Unified commands via Makefile (from the repo directory)
make doctor     # diagnostic
make update     # pull + submodules + symlinks + doctor
make install    # link.sh + install-plugins.sh
```

`doctor.sh` checks 7 axes: symlinks, GStack submodule, prerequisites (git, Node, Cargo, Python, Claude Code),
plugins (RTK, Superpowers, Context7), permissions, token budget estimate, and config consistency
(frontmatter coherence, CRLF detection).

`session-start.sh` runs a quick health check at every session start (filesystem only, no subprocesses)
and displays toggle plugin status with `/plugin-check` and `/health` hints.

Both scripts source `lib/detect-plugins.sh` for consistent plugin detection logic.

### Updating

```bash
# One-command update (from the repo directory)
bash update-all.sh

# Or step by step
git pull                                                # this repo
git submodule update --remote skills-external/gstack    # GStack
bash link.sh                                            # refresh symlinks
bash doctor.sh                                          # verify
```

---

## Troubleshooting

### "command not found" after install
Restart your shell or run `source ~/.bashrc` / `source ~/.zshrc`.

### Orchestrator blocks at STEP 0 — Superpowers missing
The plugin-advisor blocks `/init-project` and `/ship-feature` if Superpowers is not active.
Install: `claude plugin marketplace add obra/superpowers-marketplace && claude plugin install --scope user superpowers@superpowers-marketplace`
Then re-run the orchestrator.

### "agent not found" or hallucinated agent content
Symlinks are broken. `cd` into your config repo and run `bash link.sh`, then verify with `bash doctor.sh`.

### GStack skills not showing up
Run `bash link.sh` and verify: `ls -la ~/.claude/skills/gstack`.
If missing: `cd` into your config repo and run `git submodule update --init`.

### link.sh warns "is a real directory"
If `~/.claude/agents/`, `~/.claude/skills/`, or `~/.claude/lib/` exist as real directories (not symlinks
from a previous `link.sh` run), the script skips them to avoid data loss. Rename or remove the directory, then re-run `link.sh`.

### Token budget exceeded / skills truncated at session start
Too many plugins active. Run `/plugin-check` to optimize.
Run `bash doctor.sh` for a token budget estimate.

### settings.json not applying
Check precedence: deny always wins over allow at any level. `.claudeignore` overrides all permission rules.
Verify deny count: `cat ~/.claude/settings.json | python3 -c "import json,sys; print(len(json.load(sys.stdin)['permissions']['deny']))"`
Expected: 77 deny rules.

### Claude reads .env despite deny rules
The `Read(**/.env)` deny rule blocks the Read tool. `Bash(cat .env)` and similar commands have separate
deny rules (included in this config). For hard exclusion regardless of tool, use `.claudeignore` in the project root.

### install-plugins.sh failed — where are the logs?
Check `install-YYYYMMDD-HHMMSS.log` in your config repo directory — the script logs all output to a timestamped file.

---

## Known limitations

- **Deny rules are pattern-based, not sandboxed.** Common bypass vectors (`bash -c`, `eval`, `xargs`, `cat .env`) are blocked, but novel indirect patterns are still possible. `.claudeignore` is the only hard file exclusion mechanism.
- **Superpowers is a hard dependency** for `/init-project` and `/ship-feature`. The plugin-advisor (STEP 0) auto-detects and blocks if Superpowers is missing, with install instructions. There is no manual fallback mode.
- **Marketplace plugin versions are not pinned.** They install latest. Non-marketplace tools (RTK, GSD) are pinned in `plugins.lock.json` and read by `install-plugins.sh`.
- **Token budget is finite and not directly observable.** With all toggle plugins active, the description budget can exceed 60%. Run `/health` or `bash doctor.sh` for an estimate.
- **Agent frontmatter fields** like `model` and `memory` are declared but their enforcement by Claude Code is not guaranteed. They serve as documentation more than strict runtime controls.
- **`Bash(cat *)` in allow vs `Bash(cat .env)` in deny** depends on Claude Code resolving deny-wins. This is the expected behavior but cannot be tested outside the runtime.
