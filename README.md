# claude-config

Global Claude Code configuration — agents, skills, plugins, and project templates.

> **Guide d'utilisation complet :** voir [`USAGE.md`](./USAGE.md) — workflows typiques, exemples par type de projet, arbre de décision "quel skill utiliser ?".
> **Historique des versions :** voir [`CHANGELOG.md`](./CHANGELOG.md).

---

## Overview

This repo is your personal Claude Code setup, versioned and reproducible across machines.

```
claude-config/
├── CLAUDE.md              # Global coding preferences (style, rules, workflow)
├── settings.json          # Global permissions (deny / ask / allow rules)
├── install.sh             # Bootstrap: Claude Code CLI + auth + submodules + link + plugins
├── install-plugins.sh     # One-shot installer: prerequisites + all plugins
├── link.sh                # Symlinks this repo into ~/.claude/
├── doctor.sh              # Setup diagnostic
├── update-all.sh          # One-command update for all components
├── Makefile               # Unified entry point: make install / doctor / update
├── plugins.lock.json      # Version pinning for non-marketplace dependencies
├── hooks/                 # Session start, statusline, RTK rewrite, config-protection + design-toolchain guards
├── agents/                # Execution units called by skills (never invoked directly)
├── skills/                # Entry points invoked via /skill-name
├── skills-external/       # Vendored skill packs (gstack submodule + installer-fetched design packs)
├── templates/             # Per-project templates (CLAUDE.md, settings, memory registries, deploy runbook, gitignore)
└── lib/                   # Shared shell libs (gitflow, profiles, commit helpers, archetypes, tests)
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

# 2. Bootstrap (CLI + auth + symlinks + plugins)
bash install.sh

# 3. Verify setup
bash doctor.sh

# 4. Restart Claude Code — plugins load automatically
```

All scripts use their own location to find the repo — run them from anywhere.
The plugins step logs to `install-YYYYMMDD-HHMMSS.log`.

**Optional — Context7** (fast doc lookup for React / Next.js / Prisma…): the plugins
step installs the `ctx7` CLI and wires it into Claude Code itself — single surface =
the `find-docs` skill; the generated `rules/context7.md` is purged by design
(BDR-053). If you run `ctx7 setup` manually, delete that rule or re-run `make plugin`.

```bash
ctx7 login                 # optional: OAuth / API key for higher rate limits
```

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
| **Context7** | Plugin (toggle) | Fast-evolving libs doc lookup (Next.js, React, Prisma...). Works anonymously; optional `ctx7 login` raises rate limits. | [context7.com](https://context7.com/) |
| **pr-review-toolkit** | Plugin (toggle) | Multi-agent PR review. | [anthropics/claude-code](https://github.com/anthropics/claude-code) |
| **Graphify** | Python CLI | Codebase → knowledge graph → navigable wiki. Helps Claude map and search projects efficiently. | [pypi: graphifyy](https://pypi.org/project/graphifyy/) |

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
| `/impeccable` | Design verbs (audit, polish, bolder…) + deterministic anti-slop detector (`npx impeccable detect`) |
| `/commit-change` | Smart commit grouping from staged/unstaged changes |
| `/gitflow` | Gitflow branch operations — bootstrap main+develop, start a typed branch, directed merge |
| `/release-candidate` | Cut a versioned release — finalize version.txt + CHANGELOG, merge develop→main, tag, push |
| `/deploy` | Run a project's deploy from its committed runbook — instantiate the delta, resume cold |
| `/graphify` | Codebase knowledge graph — navigation for large-scope tasks |
| `/plugin-check` | Check active plugins vs project needs — recommend enable/disable |
| `/health` | Code quality dashboard (gstack) — setup diagnostic is `make doctor` |
| `/status` | Consolidated project snapshot — plugins, git, GSD milestone |
| `/skills-perso` | List personal (user-created) skills |
| `/audit-delta` | Recurring audit of changes since last run (norms, bugs, dead code, security) |
| `/capitalize` | Flush uncapitalized context + reconcile TODO before /clear or /compact (`--ritual` adds the end-of-session reflection) |
| `/prune-memory` | Curate and compress the .claude/memory/ registries |
| `/reconcile` | Confront declared status (TODO, registries) against real git/fs state — surface stale items |
| `/pdf-translate` | Translate a PDF to another language, output as HTML (via Vision) |
| `/close` | End-of-session ritual — alias for `/capitalize --ritual` (dedup + TODO reconcile + 3-question reflection) |
| `/harden` | Web hardening audit — HTTPS/TLS, HSTS, CSP, security headers |
| `/web-validate` | W3C HTML/CSS validity + WCAG 2.1 accessibility audit |
| `/geo` | GEO-only audit — AI-search visibility (ChatGPT, Perplexity, Claude, Gemini…) |
| `/client-handover` | Final project delivery — audits + branded deliverable (Markdown / HTML / PDF) |
| `/profile` | Activate a skill profile (design / dev / qa / audit / minimal) |
| `/tour` | Grouped all-axes sweep — cleanup + security + reconcile + doc, fix and loop until clean |

> This table lists personal skills. Gstack skills (investigate, review, retro,
> office-hours, context-save, context-restore, cso…) and marketplace plugins add
> many more — run `/skills-perso` to list your hand-written skills, or browse `skills/`.

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
# → STEP 4-7: implement (TDD) → review → capitalize (memory)
# → STEP 8: sync README (doc-sync)
# → STEP 9: finish (merge / PR)
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
/health                     # gstack code-quality dashboard (doctor.sh -> make doctor)
/status                     # project snapshot (plugins, git, GSD milestone)
/plugin-check "description" # audit plugin config vs project needs

# Makefile (from repo directory)
make install                # bootstrap: CLI + auth + symlinks + plugins
make plugin                 # install plugins only
make link                   # create/update symlinks into ~/.claude/
make doctor                 # diagnostic
make update                 # update Claude Code, config, submodules, plugins, and verify
make test                   # run deterministic tests (lib/tests/*.test.sh + lib/gitflow-test.sh)
make onboard                # onboard an existing project (run from its dir)
make profile cmd="set X"    # activate a skill profile (design/dev/qa/audit/minimal/full)
make profile-list           # list skill profiles
make profile-current        # show the active profile
make profile-reset          # re-enable all gstack skills
make new-skill name=myskill # scaffold agent + skill files
```

`doctor.sh` checks: symlinks, GStack submodule, prerequisites (git, Node, Cargo, Python, Claude Code), plugins, permissions, token budget, config consistency.
