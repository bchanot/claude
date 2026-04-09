# claude-config

Global Claude Code configuration — agents, skills, plugins, and project templates.

> **Guide d'utilisation complet :** voir [`USAGE.md`](./USAGE.md) — workflows typiques, exemples par type de projet (mobile, web, CLI, firmware, monorepo), arbre de décision "quel skill utiliser ?", cas de figure validés, et table des erreurs fréquentes.

---

## Overview

This repo is your personal Claude Code setup, versioned and reproducible across machines.

```
claude-config/
├── CLAUDE.md              # Global coding preferences (style, rules, workflow)
├── settings.json          # Global permissions (100 deny / 18 ask / 57 allow rules)
├── install-plugins.sh     # One-shot installer: prerequisites + all plugins (reads plugins.lock.json)
├── link.sh                # Symlinks this repo into ~/.claude/
├── doctor.sh              # Setup diagnostic — checks symlinks, plugins, permissions, token budget
├── update-all.sh          # One-command update for all components
├── Makefile               # Unified entry point: make install / doctor / update
├── plugins.lock.json      # Version pinning for non-marketplace dependencies (RTK, GSD v2, ruflo)
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
│   ├── onboarder.md       # Onboard existing project — CLAUDE.md, settings, optional GSD ROADMAP
│   ├── status-reporter.md  # Consolidated project status — read-only snapshot
│   ├── plugin-advisor.md  # Plugin check: detect signals, apply compatibility matrix, block if needed
│   ├── readme-updater.md  # Update README from git history + codebase
│   ├── refactorer.md      # Surgical refactoring with norm enforcement
│   └── scaffolder.md      # Full project generation (CLAUDE.md, README, code)
├── skills/
│   ├── analyze/           # /analyze — deep factual analysis
│   ├── health/            # /health — run setup diagnostic
│   ├── init-project/      # /init-project — full project initialization
│   ├── onboard/           # /onboard — onboard existing project into claude-config
│   ├── status/            # /status — consolidated project snapshot
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
        └── SETTINGS.md           # Rule syntax reference (rule types, patterns, defaultMode values)
```

**Architecture principle:**
- `skills/` = entry points you invoke via `/skill-name`
- `agents/` = execution units called by skills (never invoked directly by user)
- `lib/` = shared shell functions sourced by scripts (plugin detection)
- `templates/` = symlinked to `~/.claude/templates/` — copy into projects via per-project setup
- Custom skills use **Superpowers** agents for implementation phases (required — auto-detected)
- **Plugins** (Superpowers, GStack, GSD v2, ruflo, etc.) install separately and complement custom skills

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

# 4. Context7 CLI (optional — for fast-evolving libs like Next.js, React, Prisma)
npm install -g ctx7
ctx7 setup --claude    # configures MCP + rules for Claude Code (OAuth login)
# Or use standalone: ctx7 docs /vercel/next.js "middleware"

# 5. Verify setup
bash doctor.sh

# 6. Restart Claude Code — plugins load automatically
```

All scripts use their own location to find the repo — run them from anywhere or from the repo directory.
Symlinks point to the repo's actual path, so renaming or moving the repo requires re-running `bash link.sh`.

The install script handles: git, Node.js 22, Rust/Cargo, Python 3, RTK, GStack (submodule), GSD v2,
and all marketplace plugins on Linux (apt/dnf/pacman) and macOS (brew).

RTK and GSD v2 versions are pinned in `plugins.lock.json`. The install script reads those versions
automatically. Marketplace plugins install to `~/.claude/plugins/` (user scope).

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
| `/onboard` | Onboard an existing project — generate CLAUDE.md, settings, optional GSD v2 ROADMAP |

### Superpowers skills (auto-invoked or explicit)

> **Required dependency.** Superpowers must be active for `/init-project` and `/ship-feature`.
> The plugin-advisor (STEP 0) blocks and shows install instructions if Superpowers is missing.

| Command | When it auto-activates |
|---|---|
| `superpowers:brainstorming` | When you describe something to build |
| `superpowers:writing-plans` | After design is approved |
| `superpowers:subagent-driven-development` | With an approved plan |
| `superpowers:requesting-code-review` | Auto — after a feature step |
| `superpowers:finishing-a-development-branch` | After review is approved |

### GStack skills (Garry Tan — full-product projects only)

> Installed as a git submodule at `skills-external/gstack/`, symlinked to `~/.claude/skills/gstack/`.
> **Use when:** project has UI + design + deploy + browser QA. Skip for backend/lib/CLI projects.
> Full command reference: `~/.claude/skills/gstack/README.md` or run `/office-hours` to start.

### GSD v2 — standalone CLI (multi-session large features)

> **Architecture change from v1:** GSD v2 (`gsd-pi`) is a standalone TypeScript CLI built on the Pi SDK.
> It is **not** a Claude Code plugin — it runs as an external process with its own session management.
> The `/gsd ...` commands are GSD-internal and are typed inside a `gsd` terminal session, not in Claude Code.
>
> **Install:** `npm install -g gsd-pi` (pinned version in `plugins.lock.json`)
>
> **Use when:** a feature spans multiple days/sessions, you need crash recovery, cost tracking per unit,
> parallel workers across milestones, or automatic context-fresh execution per task.

```bash
# Start a GSD session in your terminal (from your project directory)
gsd

# Or jump straight to autonomous mode — walk away and come back to built software
gsd          # then inside the session:
/gsd auto    # autonomous mode: research → plan → execute → commit → repeat
/gsd         # step mode: pause between each unit for review
/gsd status  # progress dashboard
/gsd discuss # talk through architecture decisions
/gsd quick   # atomic quick task without full planning overhead
```

**Key commands inside a GSD session:**

| Command | Description |
|---|---|
| `/gsd auto` | Autonomous mode — research, plan, execute, commit, repeat until milestone done |
| `/gsd` or `/gsd next` | Step mode — execute one unit at a time, pause between each |
| `/gsd quick` | Quick atomic task with GSD guarantees (no full planning overhead) |
| `/gsd stop` | Stop auto mode gracefully |
| `/gsd status` | Progress dashboard (token usage, cost, milestone progress) |
| `/gsd discuss` | Discuss architecture decisions (works alongside auto mode) |
| `/gsd steer` | Hard-steer plan documents during execution |
| `/gsd prefs` | Model selection, timeouts, budget ceiling |
| `/gsd doctor` | Runtime health checks |
| `/gsd migrate` | Migrate a v1 `.planning` directory to `.gsd` format |
| `/gsd export --html` | Generate self-contained HTML report for a milestone |
| `/worktree` | Git worktree lifecycle — create, switch, merge, remove |

**GSD v2 vs v1:**

| | v1 (deprecated) | v2 (current) |
|---|---|---|
| Runtime | Claude Code slash commands | Standalone CLI (Pi SDK) |
| Context management | None — fills up | Fresh session per task |
| Auto mode | LLM self-loop | State machine with `.gsd/` files |
| Crash recovery | None | Lock files + session forensics |
| Cost tracking | None | Per-unit token/cost ledger |
| Git strategy | LLM writes git commands | Worktree isolation, squash merge |

### Ruflo MCP (enterprise multi-agent orchestration)

> Ruflo (formerly claude-flow) is a heavy enterprise MCP server — 310+ tools, 100+ agent types,
> WASM kernel, self-learning architecture. ~500-1500 tokens passive cost when active.
>
> **Use when:** project explicitly requires coordinating 5+ specialized agents simultaneously,
> parallel swarm execution, or enterprise-grade multi-agent orchestration.
> **For standard multi-session work, GSD v2 is sufficient and much lighter.**
>
> **Install:**
> ```bash
> # Full install (~340MB)
> npm install -g ruflo@latest
> # Or minimal (faster, no ML/embeddings)
> npm install -g ruflo@latest --omit=optional
>
> # Register as MCP server in Claude Code
> claude mcp add --scope user ruflo -- npx ruflo mcp start
>
> # Verify
> claude mcp list | grep ruflo
> ```

### Bundled skills (Claude Code built-in, always available)

| Command | Description |
|---|---|
| `/batch <instruction>` | Large-scale parallel refactoring — decomposes into 5–30 units, spawns one background agent per unit in isolated git worktrees |
| `/debug [description]` | Enable debug logging for the session, analyze the session debug log |
| `/simplify [focus]` | Review recent changes for code reuse, quality, efficiency issues |

### Other plugin commands

| Command | Plugin | Description |
|---|---|---|
| `/pr-review-toolkit:review-pr` | pr-review-toolkit | Multi-agent PR review (6 specialized agents) |
| `/context7:docs <lib>` | context7 | Manual doc lookup for a specific library (via ctx7 CLI) |

---

## Workflow patterns

### Pattern A — Nouveau projet (court, 1 session)
```
/plugin-check "description"   → configure plugins
/init-project "description"   → interview → scaffold → implement v1
/ship-feature "feature"       → ship feature by feature
```

### Pattern B — Nouveau projet (long, multi-session)
```
/plugin-check "description"
/init-project "description"   → à la fin, STEP 13 propose d'init GSD v2
                                 → répondre "yes"
# Ensuite dans un terminal :
gsd                            → démarrer une session GSD
/gsd auto                      → mode autonome — walk away
/gsd status                    → vérifier la progression
/gsd discuss                   → décisions d'architecture en cours de route
```
**À chaque reprise de session :**
```
/status                        → snapshot : plugins, token, git state, milestone GSD en cours
```

### Pattern C — Projet existant (onboarding)
```
cd mon-projet-existant/
# Dans Claude Code :
/onboard                       → génère CLAUDE.md + settings + .claudeignore
                                 → optionnel : ROADMAP.md pour GSD v2
/status                        → confirmer que l'onboarding est complet + état du projet
/plugin-check "type de projet"
/ship-feature "prochaine feature"
```

### Pattern D — Hotfix / modification ponctuelle
```
# Pas de /init-project, pas de GSD
/analyze src/module-cible.py   → rapport factuel sans solution
/ship-feature "corriger X"     → brainstorm + plan + gate + impl + review
```

### Pattern E — Refactoring ciblé
```
/analyze src/legacy.py         → liste les violations
/refactor src/legacy.py        → corrections sans changement de comportement
```

### Choisir entre /ship-feature et gsd auto

| Critère | /ship-feature | gsd auto |
|---|---|---|
| Durée estimée | < 1 journée | > 1 journée |
| Nombre de tâches | < 10 | > 10 |
| Crash recovery nécessaire | non | oui |
| Suivi de coût par tâche | non | oui |
| Workers parallèles | non | oui (parallel mode) |
| Contexte fresh par tâche | non (même session) | oui (Pi SDK) |

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
Warns if ruflo is active with no multi-agent signal, or if GSD v2 CLI is not installed for multi-session work.

```
/plugin-check "I want to build a React + FastAPI SaaS"

→ Detects active plugins
→ Scans filesystem for project signals (frontend? design? deploy? multi-agent?)
→ Applies compatibility matrix
→ Produces recommendation table with passive cost estimate
→ Warns about plugin conflicts (gstack + ruflo, etc.)
→ Blocks with OPTIONS if critical plugins are missing
→ Or confirms "proceed" if config is optimal
```

---

## Plugin compatibility matrix

### Quick reference

| Pair | Relation | Notes |
|---|---|---|
| frontend-design ↔ ui-ux-pro-max | ⚠️ Overlap | Keep both for design-heavy. Drop ui-ux-pro-max for simple UI. |
| gstack ↔ gsd v2 | ✅ Complementary | Different scopes — CC workflow vs CLI orchestration |
| gstack ↔ ruflo | ⚠️ Overlap | Both orchestrate multi-step work. Use one or the other. ~3250-4250t combined. |
| gsd v2 ↔ ruflo | ⚠️ Overlap | Sequential (GSD) vs parallel swarm (ruflo). Pick based on need. |
| superpowers ↔ gsd v2 | ✅ Complementary | Single-session engine + multi-session CLI = no conflict |
| superpowers ↔ gstack | ✅ Complementary | Used together by orchestrators |
| context7 ↔ any | ✅ Independent | Doc lookup CLI (ctx7) — always safe to combine |

### Recommended sets by project type

| Project type | Plugins ON | OFF | Passive cost |
|---|---|---|---|
| Backend API / microservice | superpowers, context7* | frontend-design, ui-ux-pro-max, gstack, ruflo | ~800t |
| Frontend SPA / SSR | superpowers, frontend-design, ui-ux-pro-max, context7 | gstack, ruflo | ~1600t |
| Full-stack SaaS | superpowers, gstack, frontend-design, ui-ux-pro-max, context7 | ruflo | ~4400t |
| CLI tool / library | superpowers | all toggles | ~800t |
| Multi-session large feature | superpowers + gsd v2 CLI (external) | ruflo | ~800t CC |
| Quick fix / hotfix | superpowers | all toggles | ~800t |
| Design system / component lib | superpowers, frontend-design, ui-ux-pro-max | gstack, ruflo, gsd | ~1600t |
| Enterprise multi-agent | superpowers, ruflo + gsd v2 CLI (external) | others | ~2300t CC |

> *context7 only if using fast-evolving libs (Next.js, React 18+, Prisma, Supabase)
> security-guidance and rtk are ALWAYS ON (0 tokens) — omitted from estimates

---

## Plugins reference

All plugins below are installed by `install-plugins.sh`.

### How loading works

Only each skill's `description` field is pre-loaded into the system prompt at session start —
the full skill body is loaded on demand when the skill is invoked. `CLAUDE.md` is the only file
loaded in full at every session. Disabling a plugin prevents even its description from loading.

A `hooks/session-start.sh` hook shows plugin toggle status at every session start.
Run `/plugin-check` anytime to get a recommendation for the current project type.

| Plugin | Status | Passive cost | When to use | Installed by |
|---|---|---|---|---|
| **security-guidance** | ✅ ALWAYS ON | 0 tokens (hook only) | — | claude-code-plugins |
| **RTK** | ✅ ALWAYS ON | 0 tokens (hook only) | — | cargo (pinned in plugins.lock.json) |
| **Superpowers** | ✅ REQUIRED | ~600–1000 tokens | — required by orchestrators | superpowers-marketplace |
| **GStack** | 🔄 TOGGLE | ~2500–3000 tokens | Full-product: UI + design + deploy + browser QA | git submodule |
| **GSD v2** | 🖥️ CLI | 0 tokens (external CLI) | Multi-day features, crash recovery, cost tracking, parallel workers | npm (pinned in plugins.lock.json) |
| **ruflo** | 🔄 TOGGLE | ~500–1500 tokens | Enterprise multi-agent swarm (5+ concurrent agents) | npm + MCP manual |
| **plugin-dev** | 🔄 TOGGLE | ~100 tokens | Creating plugins or custom skills | claude-code-plugins |
| **pr-review-toolkit** | 🔄 TOGGLE | ~300 tokens | PR review sessions | claude-code-plugins |
| **frontend-design** | 🔄 TOGGLE | ~200 tokens | Any project with a UI | claude-code-plugins |
| **ui-ux-pro-max** | 🔄 TOGGLE | ~400 tokens | Design system, color/typography choices | ui-ux-pro-max-skill |
| **Context7 CLI** | 🔄 TOGGLE | ~200 tokens | Fast-evolving libs (Next.js, React, Prisma…) | npm (ctx7) + optional ctx7 setup --claude |

**Rule:** toggle plugins are OFF by default. `/plugin-check` signals when to enable them.
If you use `/init-project` or `/ship-feature`, plugin-check runs automatically as STEP 0
and **blocks if Superpowers is not active**.

### Marketplaces

Plugins are installed from GitHub-hosted marketplaces. Three are used by this config:

| Marketplace | GitHub repo | Plugins | Auto-available |
|---|---|---|---|
| `claude-plugins-official` | `anthropics/claude-plugins-official` | Anthropic-curated third-party plugins | ✅ yes |
| `claude-code-plugins` | `anthropics/claude-code` | Anthropic bundled plugins (security-guidance, frontend-design, pr-review-toolkit, plugin-dev) | ❌ add manually |
| `superpowers-marketplace` | `obra/superpowers-marketplace` | Superpowers workflow plugin | ❌ add manually |
| `ui-ux-pro-max-skill` | `nextlevelbuilder/ui-ux-pro-max-skill` | UI/UX Pro Max design plugin | ❌ add manually |

`install-plugins.sh` adds all required marketplaces automatically.

**Manual install example:**
```bash
# Add the marketplace (once)
claude plugin marketplace add anthropics/claude-code

# Install a plugin from it
claude plugin install --scope user frontend-design@claude-code-plugins

# Browse all available plugins
/plugin   # → Discover tab
```

### Version pinning

RTK, GSD v2, and ruflo versions are pinned in `plugins.lock.json`:

```json
{
  "rtk":   { "source": "https://github.com/rtk-ai/rtk", "version": "v0.34.3" },
  "gsd":   { "source": "npm:gsd-pi",  "version": "2.64.0" },
  "ruflo": { "source": "npm:ruflo",   "version": "3.5.58" }
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
    "gstack@gstack": false
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

100 deny rules, 18 ask rules, 57 allow rules.

| Section | Purpose |
|---|---|
| `deny` — secrets (Read) | Blocks `Read` on `.env`, `.pem`, `.key`, SSH keys, cloud credentials |
| `deny` — secrets (Bash) | Blocks `cat`, `head`, `tail`, `grep`, `less`, `more` on `.env` and secret files |
| `deny` — env leak | Blocks `env`, `printenv`, `export *` — prevents secret exposure via process environment |
| `deny` — secret move | Blocks `cp`/`mv` on `.env*` and `secrets/` — closes copy-then-read bypass |
| `deny` — destructive | Blocks `rm -rf`, `git push --force`, `chmod 777` |
| `deny` — system | Blocks `sudo`, `ssh`, `scp`, `crontab`, `systemctl` |
| `deny` — injection | Blocks `curl \| bash`, `wget \| sh` |
| `deny` — escalation | Blocks `bash -c`, `eval`, `exec`, `find -delete`, `perl -e`, `ruby -e` |
| `deny` — runtime exec | Blocks `python3 -c *`, `node -e *`, `source /dev/stdin`, `mkfifo *` |
| `deny` — exfiltration | Blocks `xargs * .env*`, `tar * .env*`, `zip * .env*`, `base64 .env*` |
| `ask` — risky | Prompts before `git push`, `docker run`, package managers |
| `ask` — write tools | Prompts before `xargs`, all `sed` (including in-place) |
| `ask` — stash destructive | Prompts before `git stash pop`, `drop`, `clear` |
| `allow` — safe reads | Auto-approves git read-only, `ls`, `cat`, `grep`, `find` |
| `allow` — stash safe | Auto-approves `git stash` (push), `list`, `show` |
| `disableBypassPermissionsMode` | Prevents YOLO mode globally |
| `disableAutoMode` | Prevents auto mode globally |

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
cp "$CONF/templates/project-CLAUDE.md" CLAUDE.md
```

---

## Updating

### One-command update (recommended)

```bash
# From the repo directory
bash update-all.sh
# Pulls config, prompts before updating GStack (tracks main), updates RTK + GSD v2 (pinned),
# updates ruflo if installed, refreshes symlinks, runs doctor
```

### Manual updates

#### This repo
```bash
git pull
# Symlinks → changes active immediately
```

#### GStack (submodule)
```bash
# Option A — inside Claude Code (recommended)
/gstack-upgrade

# Option B — via submodule (from the repo directory)
# Note: GStack tracks branch = main, review upstream commits before updating
git submodule update --remote skills-external/gstack
cd skills-external/gstack && ./setup
git add skills-external/gstack
git commit -m "chore: update gstack to latest"
```

#### RTK
```bash
# Uses the version pinned in plugins.lock.json
bash update-all.sh

# Or manually
cargo install --git https://github.com/rtk-ai/rtk --tag v0.34.3 --force
```

#### GSD v2
```bash
# Uses the version pinned in plugins.lock.json
bash update-all.sh

# Or manually
npm install -g gsd-pi@2.64.0
```

#### Ruflo MCP
```bash
# Uses the version pinned in plugins.lock.json
bash update-all.sh

# Or manually
npm install -g ruflo@3.5.58
```

#### Marketplace plugins
```bash
/plugin marketplace update    # inside Claude Code
```

---

## Adding a new custom skill

**Fastest way:**
```bash
make new-skill name=myskill
# Creates agents/myskill.md + skills/myskill/SKILL.md with templates filled
# Edit both files, then: bash link.sh
```

**Manually:**
1. Create `agents/myagent.md` — role, tasks, rules, output format
2. Create `skills/myskill/SKILL.md`:

```markdown
---
name: myskill
description: What this skill does — front-load key use case (max 250 chars)
argument-hint: <what to pass>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

Load and follow strictly:
- $HOME/.claude/agents/myagent.md

Execute on:

$ARGUMENTS
```

3. Or use `/plugin-dev:create-plugin` to generate a skill from conversation.

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
/health       # full diagnostic (symlinks, plugins, permissions, token budget)
/status       # project snapshot at session start (plugins, git, GSD milestone)

# Unified commands via Makefile (from the repo directory)
make doctor     # diagnostic
make update     # pull + submodules + symlinks + doctor
make install    # link.sh + install-plugins.sh
make onboard    # reminder to run /onboard in Claude Code
make new-skill name=myskill  # scaffold agent + skill files
```

`doctor.sh` checks 7 axes: symlinks, GStack submodule (with pinning warning), prerequisites
(git, Node, Cargo, Python, Claude Code), plugins (RTK, Superpowers, Context7, GSD v2, ruflo),
permissions (deny count, bypass mode), token budget (breakdown vs Pro session budget), and
config consistency (frontmatter, CRLF detection).

`session-start.sh` runs a quick health check at every session start (filesystem only, no subprocesses)
and displays toggle plugin status, GSD v2 CLI status, with `/plugin-check` and `/health` hints.

Both scripts source `lib/detect-plugins.sh` for consistent plugin detection logic.

### Updating

```bash
# One-command update (from the repo directory)
bash update-all.sh

# Or step by step
git pull                                                # this repo
# GStack: prompts for confirmation (tracks main branch)
git submodule update --remote skills-external/gstack
bash link.sh                                            # refresh symlinks
bash doctor.sh                                          # verify
```

---

## Troubleshooting

### "command not found" after install
Restart your shell or run `source ~/.bashrc` / `source ~/.zshrc`.

### Orchestrator blocks at STEP 0 — Superpowers missing
Install: `claude plugin marketplace add obra/superpowers-marketplace && claude plugin install --scope user superpowers@superpowers-marketplace`
Then re-run the orchestrator.

### "agent not found" or hallucinated agent content
Symlinks are broken. `cd` into your config repo and run `bash link.sh`, then verify with `bash doctor.sh`.

### GStack skills not showing up
Run `bash link.sh` and verify: `ls -la ~/.claude/skills/gstack`.
If missing: `cd` into your config repo and run `git submodule update --init`.

### GStack submodule "directory not found after init"
The submodule is not registered in `.gitmodules` (never added). Fix:
```bash
cd ~/Documents/claude   # chemin de ton config repo
git submodule add https://github.com/garrytan/gstack skills-external/gstack
git submodule update --init --recursive
bash link.sh
git add .gitmodules skills-external/gstack && git commit -m "chore: add gstack submodule"
```

### link.sh warns "is a real directory"
If `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/lib/`, or `~/.claude/templates/` exist as real
directories, the script skips them to avoid data loss. Rename or remove the directory, then re-run `link.sh`.

### GSD v2 — "command not found: gsd"
npm's global bin directory is not in `$PATH`. Run `npm prefix -g` to find it, then add `$(npm prefix -g)/bin`
to your PATH. See the [GSD troubleshooting guide](https://github.com/gsd-build/gsd-2/blob/main/docs/troubleshooting.md).

### GSD v2 — migrating from v1 projects
If you have old projects with `.planning` directories from GSD v1, migrate them:
```bash
cd your-project
gsd          # start a session
/gsd migrate # migrate .planning → .gsd format
```

### Ruflo MCP not detected by doctor.sh
Ruflo must be registered as an MCP server. Run:
```bash
claude mcp add --scope user ruflo -- npx ruflo mcp start
claude mcp list | grep ruflo
```

### Token budget exceeded — skills truncated at session start
Too many plugins active. Run `/plugin-check` to optimize.
Run `bash doctor.sh` for a token budget breakdown (vs Pro ~11k session budget).

### settings.json not applying
Check precedence: deny always wins over allow at any level. `.claudeignore` overrides all permission rules.
Verify deny count: `cat ~/.claude/settings.json | python3 -c "import json,sys; print(len(json.load(sys.stdin)['permissions']['deny']))"`
Expected: 100 deny rules.

### Claude reads .env despite deny rules
The `Read(**/.env)` deny rule blocks the Read tool. `Bash(cat .env)` and similar commands have separate
deny rules (included in this config). For hard exclusion regardless of tool, use `.claudeignore`.

### install-plugins.sh failed — where are the logs?
Check `install-YYYYMMDD-HHMMSS.log` in your config repo directory.

---

## Known limitations

- **Deny rules are pattern-based, not sandboxed.** Core bypass vectors (`bash -c`, `eval`, `python3 -c *`, `node -e *`, `source /dev/stdin`, `mkfifo *`, `xargs * .env*`, `base64 .env*`) are blocked. Process substitution (`<(cmd)`, `>(cmd)`), here strings (`<<<`), and `/dev/fd/*` access remain possible without explicit patterns — `.claudeignore` is the only hard file exclusion mechanism.
- **`disableAutoMode` syntax not verified** against CC v2.1.89 — added as `"disableAutoMode": "disable"` by analogy with `disableBypassPermissionsMode`. # TODO: VERIFY
- **Superpowers is a hard dependency** for `/init-project` and `/ship-feature`. The plugin-advisor (STEP 0) auto-detects and blocks if missing, with install instructions. No manual fallback mode.
- **Marketplace plugin versions are not pinned.** They install latest. Non-marketplace tools (RTK, GSD v2, ruflo) are pinned in `plugins.lock.json`.
- **Token budget:** `CLAUDE.md` loads in full every session (~420t). Skill bodies load on-demand. Plugin descriptions load passively. With all toggles active, passive plugin cost can reach ~50% of the Pro session budget (~11k tokens/5h). Run `/health` or `bash doctor.sh` for a breakdown.
- **GSD v2 is a standalone CLI**, not a Claude Code plugin. `/gsd ...` commands are GSD-internal and do not work in the Claude Code slash command bar.
- **Ruflo is heavy** (~340MB default, ~500-1500t passive tokens). Only enable for genuine enterprise multi-agent needs. For multi-session work, GSD v2 is lighter and sufficient.
- **Agent frontmatter fields** `model`, `memory`, `effort` are enforced by Claude Code v2.1.x.
- **`bypassPermissions` mode is disabled** via `disableBypassPermissionsMode`.
- **GStack submodule is pinned to `branch = main`**, not a commit hash. `update-all.sh` now prompts for confirmation before updating. Review upstream commits before accepting.
- **`disable-model-invocation: true` on orchestrator skills** (`/init-project`, `/ship-feature`): behavior when a skill with this flag invokes sub-agents via loaded agent files has not been fully verified in CC v2.1.89. # TODO: VERIFY
