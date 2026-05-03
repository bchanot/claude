# claude-config

Global Claude Code configuration — agents, skills, plugins, and project templates.

> **Guide d'utilisation complet :** voir [`USAGE.md`](./USAGE.md) — workflows typiques, exemples par type de projet, arbre de décision "quel skill utiliser ?".

---

## Overview

This repo is your personal Claude Code setup, versioned and reproducible across machines.

```
claude-config/
├── CLAUDE.md              # Global coding preferences (style, rules, workflow)
├── settings.json          # Global permissions (deny / ask / allow rules)
├── install.sh             # Bootstrap: Claude Code CLI + auth + shell env vars + link + plugins
├── install-plugins.sh     # One-shot installer: prerequisites + all plugins
├── link.sh                # Symlinks this repo into ~/.claude/
├── doctor.sh              # Setup diagnostic
├── update-all.sh          # One-command update for all components
├── Makefile               # Unified entry point: make install / doctor / update
├── plugins.lock.json      # Version pinning for non-marketplace dependencies
├── hooks/                 # Session start, statusline, RTK rewrite
├── agents/                # Execution units called by skills (never invoked directly)
├── skills/                # Entry points invoked via /skill-name
├── skills-external/       # Git submodules (gstack)
├── templates/             # Per-project config templates (CLAUDE.md, settings, .claudeignore)
└── lib/                   # Shared shell functions (plugin detection)
```

**Architecture principle:**
- `skills/` = entry points you invoke via `/skill-name`
- `agents/` = execution units called by skills (never invoked directly by user)
- `templates/` = symlinked to `~/.claude/templates/` — copy into projects via `/onboard` or manually
- **Graphify** builds a knowledge graph of any codebase (`/graphify query`), producing a navigable wiki in `graphify-out/wiki/`. This map helps Claude understand project structure, find relevant code faster, and reason across files. Essential for large-scope tasks (multi-file features, complex bugs, architectural changes). Small tasks should skip it and read files directly.

---

## Fresh install (new machine)

```bash
# 1. Clone with submodules
git clone --recurse-submodules git@github.com:youruser/claude-config.git
cd claude-config

# 2. Create a free Context7 account at https://context7.com/
#    Copy your API key and set it:
export CONTEXT7_API_KEY="your-key-here"

# 3. Bootstrap (CLI + auth + symlinks + plugins)
bash install.sh

# 4. Verify setup
bash doctor.sh

# 5. Restart Claude Code — plugins load automatically
```

All scripts use their own location to find the repo — run them from anywhere.
Install output is logged to `install-YYYYMMDD-HHMMSS.log`.

---

## Installed components

| Component | Type | Description | Docs |
|---|---|---|---|
| **Superpowers** | Plugin (required) | Brainstorming, planning, subagent-driven dev, code review, branch finishing. Required by `/init-project` and `/ship-feature`. | [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace) |
| **GStack** | Plugin (toggle) | Full-product workflow: UI + design + deploy + browser QA. Skip for backend/CLI projects. | [garrytan/gstack](https://github.com/garrytan/gstack) |
| **GSD v2** | External CLI | Multi-session orchestration: crash recovery, cost tracking, parallel workers, context-fresh execution. | [gsd-build/gsd-2](https://github.com/gsd-build/gsd-2) |
| **RTK** | Plugin (always on) | Code rewrite hook. Zero passive cost. | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) |
| **security-guidance** | Plugin (always on) | Security hook. Zero passive cost. | [anthropics/claude-code](https://github.com/anthropics/claude-code) |
| **ui-ux-pro-max** | Plugin (toggle) | Design system, color/typography choices. Enable for design-heavy projects. | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) |
| **Context7** | Plugin (toggle) | Fast-evolving libs doc lookup (Next.js, React, Prisma...). Requires a free account + API key (see install). | [context7.com](https://context7.com/) |
| **pr-review-toolkit** | Plugin (toggle) | Multi-agent PR review. | [anthropics/claude-code](https://github.com/anthropics/claude-code) |
| **Graphify** | Python CLI | Codebase → knowledge graph → navigable wiki. Helps Claude map and search projects efficiently. | [pypi: graphifyy](https://pypi.org/project/graphifyy/) |
| **Caveman** | Plugin (always on) + hooks | Output token compression (~75%) via caveman-speak. Full install = plugin (`/caveman`, cavecrew, caveman-commit, caveman-review, caveman-stats) + standalone hooks (statusline + stats badge). The optional `caveman-shrink` MCP proxy compresses upstream-server prose — manual config required (it wraps another MCP server). See `install-plugins.sh` STEP 5.5 for the snippet. | [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) |

Versions are pinned in `plugins.lock.json`. To update: edit the file, then re-run `install-plugins.sh`.

---

## Slash commands

| Command | Description |
|---|---|
| `/init-project` | Initialize a complete project from scratch (full orchestrator, 12+ steps) |
| `/ship-feature` | Ship a feature end-to-end with validation gates (full orchestrator) |
| `/onboard` | Onboard an existing project — generate CLAUDE.md, settings, .claudeignore |
| `/feat` | Small feature implementation (1-5 files, lightweight) |
| `/bugfix` | Structured bug fix with root cause investigation |
| `/hotfix` | Quick fix for superficial bugs (typos, CSS, config — max 2 files) |
| `/analyze` | Deep factual analysis of code before any modification |
| `/refactor` | Improve code quality without changing behavior |
| `/code-clean` | Dead code removal, style/norm enforcement |
| `/doc` | Documentation audit and sync — detect stale docs, patch |
| `/seo` | Full SEO/GEO audit and optimization |
| `/commit-change` | Smart commit grouping from staged/unstaged changes |
| `/graphify` | Codebase knowledge graph — navigation for large-scope tasks |
| `/plugin-check` | Check active plugins vs project needs — recommend enable/disable |
| `/health` | Run setup diagnostic |
| `/status` | Consolidated project snapshot — plugins, git, GSD milestone |
| `/skills-perso` | List personal (user-created) skills |

---

## Three core workflows

### From scratch — `/init-project`

```
/plugin-check "description"     # configure plugins (also runs as STEP 0)
/init-project "description"     # interview → scaffold → implement → review
/ship-feature "next feature"    # ship feature by feature
```

### Existing project — `/onboard`

```
cd my-existing-project/
/onboard                        # generates CLAUDE.md + settings + .claudeignore
/plugin-check "project type"
/ship-feature "next feature"
```

### New feature — `/ship-feature`

```
/ship-feature "feature description"
# → STEP 0: plugin check
# → STEP 1-2: brainstorm + plan (superpowers)
# → STEP 3: validation gate — user approval required
# → STEP 4-7: implement (TDD) → review → finish
# → STEP 8: sync README
```

For small features (1-5 files), use `/feat` instead — no orchestration overhead.

---

## Settings and permissions

Settings follow a hierarchy (highest priority first):

```
managed-settings.json   → enterprise (cannot be overridden)
CLI flags               → session only
.claude/settings.local  → personal machine overrides (gitignored)
.claude/settings.json   → project rules (committed)
~/.claude/settings.json → global user rules (this repo)
```

DENY always wins over ALLOW at any level. `.claudeignore` applies independently.

Templates for per-project settings are in `templates/settings/`. Copy them with `/onboard` or manually:
```bash
CONF="$(dirname "$(readlink ~/.claude/CLAUDE.md)")"
cp "$CONF/templates/settings/settings.json" .claude/settings.json
cp "$CONF/templates/settings/.claudeignore" .claudeignore
```

---

## Diagnostic and maintenance

```bash
# Terminal
bash doctor.sh              # full diagnostic (symlinks, plugins, permissions, token budget)
bash update-all.sh          # update all components (CLI, plugins, submodules, symlinks)

# Claude Code
/health                     # runs doctor.sh
/status                     # project snapshot (plugins, git, GSD milestone)
/plugin-check "description" # audit plugin config vs project needs

# Makefile (from repo directory)
make install                # bootstrap: CLI + auth + symlinks + plugins
make doctor                 # diagnostic
make update                 # pull + submodules + symlinks + doctor
make plugin                 # install plugins only
make new-skill name=myskill # scaffold agent + skill files
```

`doctor.sh` checks: symlinks, GStack submodule, prerequisites (git, Node, Cargo, Python, Claude Code), plugins, permissions, token budget, config consistency.
