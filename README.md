# claude-config

Global Claude Code configuration — agents, skills, plugins, and project templates.

> **Guide d'utilisation complet :** voir [`USAGE.md`](./USAGE.md) — workflows typiques, exemples par type de projet (mobile, web, CLI, firmware, monorepo), arbre de décision "quel skill utiliser ?".

---

## Overview

This repo is your personal Claude Code setup, versioned and reproducible across machines.

```
claude-config/
├── CLAUDE.md              # Global coding preferences (style, rules, workflow)
├── settings.json          # Global permissions (100 deny / 18 ask / 57 allow rules)
├── install.sh             # Bootstrap: Claude Code CLI + auth + shell env vars + link + plugins
├── install-plugins.sh     # One-shot installer: prerequisites + all plugins (reads plugins.lock.json)
├── link.sh                # Symlinks this repo into ~/.claude/
├── doctor.sh              # Setup diagnostic — checks symlinks, plugins, permissions, token budget
├── update-all.sh          # One-command update for all components
├── Makefile               # Unified entry point: make install / doctor / update
├── plugins.lock.json      # Version pinning for non-marketplace dependencies (RTK, GSD v2)
├── version.txt            # Semver version of this config
├── CHANGELOG.md           # Release history
├── lib/
│   └── detect-plugins.sh  # Shared plugin detection — sourced by all scripts
├── hooks/
│   ├── session-start.sh   # Health check + toggle plugin status at session start
│   ├── statusline.sh      # Claude Code status line configuration
│   └── rtk-rewrite.sh     # RTK hook for code rewrites
├── skills-external/
│   └── gstack/            # Git submodule — garrytan/gstack (symlinked to ~/.claude/skills/gstack)
├── .gitmodules            # Submodule declaration
├── agents/
│   ├── analyzer.md        # Factual codebase analysis (read-only)
│   ├── bugfixer.md        # Structured bug fix with root cause investigation
│   ├── code-cleaner.md    # Dead code removal, style/norm enforcement
│   ├── commit-changer.md  # Smart commit grouping from staged/unstaged changes
│   ├── doc-syncer.md      # Detect stale docs, audit, and patch
│   ├── feater.md          # Small feature implementation (1-5 files)
│   ├── hotfixer.md        # Quick fix for superficial bugs (max 2 files)
│   ├── interviewer.md     # Project questionnaire → PROJECT BRIEF
│   ├── onboarder.md       # Onboard existing project — CLAUDE.md, settings, optional GSD ROADMAP
│   ├── plugin-advisor.md  # Plugin check: detect signals, apply compatibility matrix, block if needed
│   ├── refactorer.md      # Surgical refactoring with norm enforcement
│   ├── scaffolder.md      # Full project generation (CLAUDE.md, README, code)
│   ├── seo-analyzer.md    # Full SEO/GEO audit and fix
│   └── status-reporter.md # Consolidated project status — read-only snapshot
├── skills/
│   ├── analyze/           # /analyze — deep factual analysis
│   ├── bugfix/            # /bugfix — structured bug fix with root cause investigation
│   ├── code-clean/        # /code-clean — dead code removal, style enforcement
│   ├── commit-change/     # /commit-change — smart commit grouping
│   ├── doc/               # /doc — documentation audit and sync
│   ├── feat/              # /feat — small feature implementation (1-5 files)
│   ├── graphify/          # /graphify — codebase knowledge graph navigation
│   ├── health/            # /health — run setup diagnostic
│   ├── hotfix/            # /hotfix — quick fix for superficial bugs
│   ├── init-project/      # /init-project — full project initialization
│   ├── onboard/           # /onboard — onboard existing project into claude-config
│   ├── plugin-check/      # /plugin-check — check plugin config vs project needs
│   ├── refactor/          # /refactor — improve code without changing behavior
│   ├── seo/               # /seo — full SEO/GEO audit and optimization
│   ├── ship-feature/      # /ship-feature — ship a feature end-to-end
│   ├── skills-perso/      # /skills-perso — list personal (user-created) skills
│   └── status/            # /status — consolidated project snapshot
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
- **Plugins** (Superpowers, GStack, GSD v2, etc.) install separately and complement custom skills

---

## Fresh install (new machine)

```bash
# 1. Clone with submodules — choose any location
git clone --recurse-submodules git@github.com:youruser/claude-config.git
cd claude-config

# 2. Bootstrap (installs Claude Code CLI, authenticates, sets up shell env vars, then runs link.sh + install-plugins.sh)
bash install.sh
# Or step by step:
#   bash link.sh                # symlink into ~/.claude/
#   bash install-plugins.sh     # prerequisites + all plugins

# 4. Context7 CLI (optional — fast-evolving libs docs lookup)
npm install -g ctx7
ctx7 setup --claude    # configures rules for Claude Code
# Higher rate limits: ctx7 login (OAuth) or use --api-key from context7.com/dashboard

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
| `/bugfix` | Structured bug fix with root cause investigation |
| `/code-clean` | Dead code removal, style/norm enforcement |
| `/commit-change` | Smart commit grouping from staged/unstaged changes |
| `/doc` | Documentation audit and sync — detect stale docs, patch |
| `/feat` | Small feature implementation (1-5 files, lightweight) |
| `/graphify` | Codebase knowledge graph — navigation for large-scope tasks |
| `/health` | Run setup diagnostic — check symlinks, plugins, permissions, token budget |
| `/hotfix` | Quick fix for superficial bugs (typos, CSS, config — max 2 files) |
| `/init-project` | Initialize a complete project from scratch (full orchestrator) |
| `/onboard` | Onboard an existing project — generate CLAUDE.md, settings, optional GSD v2 ROADMAP |
| `/plugin-check` | Check active plugins vs project needs — recommend enable/disable |
| `/refactor` | Improve code quality without changing behavior (strict norms) |
| `/seo` | Full SEO/GEO audit and optimization |
| `/ship-feature` | Ship a feature end-to-end with validation gates (full orchestrator) |
| `/skills-perso` | List personal (user-created) skills |
| `/status` | Consolidated project snapshot — plugins, git, GSD milestone |

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

### GStack (Garry Tan — full-product projects only)

> Full-product workflow skills for UI + design + deploy + browser QA. Installed as a git submodule.
> Skip for backend/lib/CLI projects. Docs: [github.com/garrytan/gstack](https://github.com/garrytan/gstack)

### GSD v2 — standalone CLI (multi-session large features)

> Standalone TypeScript CLI for multi-session work: crash recovery, per-unit cost tracking, parallel workers,
> context-fresh execution per task. Not a Claude Code plugin — runs as an external process.
> Docs: [github.com/gsd-build/gsd-2](https://github.com/gsd-build/gsd-2)

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
# Bug superficiel (typo, mauvais import, CSS cassé — max 2 fichiers, cause évidente) :
/hotfix "le bouton submit est invisible sur mobile"

# Bug plus complexe (investigation root cause nécessaire) :
/bugfix "les notifications ne partent plus depuis mardi"
```

### Pattern E — Refactoring ciblé
```
/analyze src/legacy.py         → liste les violations
/refactor src/legacy.py        → corrections sans changement de comportement
```

### Pattern F — Petite feature (1-5 fichiers)
```
# Pas d'orchestration lourde, pas de brainstorming superpowers
/feat "ajouter un endpoint GET /api/v1/users/:id/stats"
# → planning léger, implémentation directe, tests
```

### Choisir entre /ship-feature, /feat, /hotfix et /bugfix

| Critère | /ship-feature | /feat | /bugfix | /hotfix |
|---|---|---|---|---|
| Scope | Feature complète | 1-5 fichiers | Bug complexe | Bug superficiel |
| Orchestration | Superpowers pipeline | Léger | Investigation | Direct |
| Fichiers touchés | Illimité | ≤ 5 | Variable | ≤ 2 |
| Validation gate | Oui | Non | Non | Non |
| Code review | Auto (superpowers) | Non | Régression test | Non |

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
Warns if GSD v2 CLI is not installed for multi-session work.

```
/plugin-check "I want to build a React + FastAPI SaaS"

→ Detects active plugins
→ Scans filesystem for project signals (frontend? design? deploy? multi-agent?)
→ Applies compatibility matrix
→ Produces recommendation table with passive cost estimate
→ Warns about plugin conflicts
→ Blocks with OPTIONS if critical plugins are missing
→ Or confirms "proceed" if config is optimal
```

---

## Plugin compatibility matrix

### Quick reference

| Pair | Relation | Notes |
|---|---|---|
| gstack ↔ gsd v2 | ✅ Complementary | Different scopes — CC workflow vs CLI orchestration |
| superpowers ↔ gsd v2 | ✅ Complementary | Single-session engine + multi-session CLI = no conflict |
| superpowers ↔ gstack | ✅ Complementary | Used together by orchestrators |
| context7 ↔ any | ✅ Independent | Doc lookup CLI (ctx7) — always safe to combine |

### Recommended sets by project type

| Project type | Plugins ON | OFF | Passive cost |
|---|---|---|---|
| Backend API / microservice | superpowers, context7* | ui-ux-pro-max, gstack | ~800t |
| Frontend SPA / SSR | superpowers, ui-ux-pro-max, context7 | gstack | ~1400t |
| Full-stack SaaS | superpowers, gstack, ui-ux-pro-max, context7 | — | ~4200t |
| CLI tool / library | superpowers | all toggles | ~800t |
| Multi-session large feature | superpowers + gsd v2 CLI (external) | — | ~800t CC |
| Quick fix / hotfix | superpowers | all toggles | ~800t |
| Design system / component lib | superpowers, ui-ux-pro-max | gstack, gsd | ~1200t |
| Enterprise multi-agent | superpowers + gsd v2 CLI (external) | others | ~800t CC |

> *context7 only if using fast-evolving libs (Next.js, React 18+, Prisma, Supabase)
> security-guidance and rtk are ALWAYS ON (0 tokens) — omitted from estimates

---

## Intelligent self-management

This config doesn't just provide tools — it manages itself. The interconnection between plugins, skills, and agents creates an autonomous quality layer.

### Plugin advisor — automatic configuration

`/plugin-check` (or STEP 0 in orchestrators) analyzes your project and recommends the optimal plugin configuration:

- **Signal detection:** scans filesystem for project type signals (frontend frameworks, mobile SDKs, embedded toolchains, monorepo markers, deploy configs)
- **Compatibility matrix:** knows which plugins overlap, complement, or conflict with each other
- **Cost awareness:** estimates passive token cost per plugin combination and warns when approaching budget limits
- **Blocking gate:** orchestrators (`/init-project`, `/ship-feature`) refuse to start if critical plugins are missing

### Token budget management

Every plugin has a passive cost (loaded at session start). The system tracks this:

- `session-start.sh` hook displays current passive cost and % of session budget at every session start
- `/health` and `doctor.sh` provide detailed token budget breakdowns
- `/plugin-check` recommends disabling unnecessary plugins to reclaim budget
- Rule: toggle plugins are OFF by default — only enabled when project signals justify the cost

### Tool and skill synergies

Skills and tools are designed to work together, not in isolation:

| Synergy | How it works |
|---|---|
| `/plugin-check` → `/init-project` | Plugin-check runs as STEP 0, blocks if config is wrong |
| `/analyze` → `/refactor` | Analyzer produces violation report, refactorer uses it as input |
| `/status` → `gsd auto` | Status shows GSD milestone progress, informs session resumption |
| `/init-project` STEP 13 → GSD v2 | Orchestrator detects multi-session need, proposes GSD init |
| `/ship-feature` STEP 0b → `/onboard` | Detects missing CLAUDE.md, redirects to onboarding first |
| `doctor.sh` → `link.sh` | Doctor diagnoses broken symlinks, link.sh fixes them |
| `/doc` → auto-mode | Other skills can trigger doc-sync automatically after changes |
| Superpowers → custom agents | Orchestrators use Superpowers for brainstorm/plan/review phases, custom agents for analysis/scaffolding |

### Passive vs active cost model

```
Passive (always loaded):        Active (loaded on demand):
├─ CLAUDE.md (~420t)            ├─ Skill body (when /skill invoked)
├─ Plugin descriptions          ├─ Agent content (when skill loads agent)
├─ Hook configs                 └─ Context7 docs (when ctx7 queried)
└─ Session-start output
```

The system minimizes passive cost by loading skill bodies and agent content only when invoked. Plugin descriptions are the main passive cost lever — hence why `/plugin-check` exists.

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
| **plugin-dev** | 🔄 TOGGLE | ~100 tokens | Creating plugins or custom skills | claude-code-plugins |
| **pr-review-toolkit** | 🔄 TOGGLE | ~300 tokens | PR review sessions | claude-code-plugins |
| **ui-ux-pro-max** | 🔄 TOGGLE | ~400 tokens | Design system, color/typography choices | ui-ux-pro-max-skill |
| **Context7 CLI** | 🔄 TOGGLE | ~200 tokens | Fast-evolving libs (Next.js, React, Prisma…) | npm (ctx7 CLI) |

**Rule:** toggle plugins are OFF by default. `/plugin-check` signals when to enable them.
If you use `/init-project` or `/ship-feature`, plugin-check runs automatically as STEP 0
and **blocks if Superpowers is not active**.

### Marketplaces

Plugins are installed from GitHub-hosted marketplaces. Three are used by this config:

| Marketplace | GitHub repo | Plugins | Auto-available |
|---|---|---|---|
| `claude-plugins-official` | `anthropics/claude-plugins-official` | Anthropic-curated third-party plugins | ✅ yes |
| `claude-code-plugins` | `anthropics/claude-code` | Anthropic bundled plugins (security-guidance, pr-review-toolkit, plugin-dev) | ❌ add manually |
| `superpowers-marketplace` | `obra/superpowers-marketplace` | Superpowers workflow plugin | ❌ add manually |
| `ui-ux-pro-max-skill` | `nextlevelbuilder/ui-ux-pro-max-skill` | UI/UX Pro Max design plugin | ❌ add manually |

`install-plugins.sh` adds all required marketplaces automatically.

**Manual install example:**
```bash
# Add the marketplace (once)
claude plugin marketplace add anthropics/claude-code

# Install a plugin from it
claude plugin install --scope user pr-review-toolkit@claude-code-plugins

# Browse all available plugins
/plugin   # → Discover tab
```

### Version pinning

Non-marketplace tools are pinned in `plugins.lock.json`:

```json
{
  "rtk":             { "source": "https://github.com/rtk-ai/rtk", "version": "v0.34.3" },
  "gsd":             { "source": "npm:gsd-pi",  "version": "2.64.0" },
  "ctx7":            { "source": "npm:ctx7",    "version": "latest" },
  "graphifyy":       { "source": "pypi:graphifyy", "managed_by": "pipx" },
  "emil-design-eng": { "source": "https://github.com/emilkowalski/skill", "managed_by": "curl" }
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
# Updates Claude CLI, pulls config, prompts before updating GStack (tracks main),
# updates RTK + GSD v2 (pinned), updates ctx7 + graphifyy,
# refreshes marketplace plugins, refreshes symlinks, runs doctor
```

### Manual updates

```bash
git pull          # this repo — symlinks make changes active immediately
bash link.sh      # refresh symlinks if needed
```

All third-party tools (RTK, GSD v2, GStack, ctx7, marketplace plugins) are updated
automatically by `update-all.sh`. Versions are pinned in `plugins.lock.json`.

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

## Personal skills (skills-perso)

List your personal skills (created in `~/.claude/skills/`) with:
```
/skills-perso
```

This lists all skills you've created outside of this repo — useful to remember what custom skills are available across projects.

To create a personal skill:
```bash
# Quick way (from this repo)
make new-skill name=myskill
bash link.sh

# Or manually
mkdir -p ~/.claude/skills/myskill/
# Create SKILL.md with frontmatter (see "Adding a new custom skill" above)
```

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
make install    # bootstrap: Claude Code CLI + auth + symlinks + plugins
make plugin     # install prerequisites + all plugins only
make onboard    # reminder to run /onboard in Claude Code
make new-skill name=myskill  # scaffold agent + skill files
```

`doctor.sh` checks 7 axes: symlinks, GStack submodule (with pinning warning), prerequisites
(git, Node, Cargo, Python, Claude Code), plugins (RTK, Superpowers, Context7, GSD v2),
permissions (deny count, bypass mode), token budget (breakdown vs Pro session budget), and
config consistency (frontmatter, CRLF detection).

`session-start.sh` runs a quick health check at every session start (filesystem only, no subprocesses)
and displays toggle plugin status, GSD v2 CLI status, with `/plugin-check` and `/health` hints.

Both scripts source `lib/detect-plugins.sh` for consistent plugin detection logic.

