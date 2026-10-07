# Architecture — claude-config

Repo layout and structural principles. Command workflows live in
[`USAGE.md`](./USAGE.md); version history in [`CHANGELOG.md`](./CHANGELOG.md).

## Project layout

```
claude-config/
├── CLAUDE.global.md       # Global coding preferences — deployed as ~/.claude/CLAUDE.md
├── CLAUDE.md              # Project-scope instructions (this repo only)
├── README.md / USAGE.md / ARCHITECTURE.md / CHANGELOG.md / MIGRATION.md
├── version.txt            # Current release version
├── .env.example           # Placeholder template for ~/.claude/.env (secrets never committed)
├── settings.json          # Global permissions (deny / ask / allow) + autoMode classifier tiers
├── install.sh             # Bootstrap: Claude Code CLI + auth + submodules + link + plugins
├── install-plugins.sh     # One-shot installer: prerequisites + all plugins + default profile
├── link.sh                # Symlinks this repo into ~/.claude/, sets git's global core.hooksPath
├── doctor.sh              # Setup diagnostic
├── update-all.sh          # One-command update for all components
├── Makefile               # Unified entry point: make install / doctor / update / test (make help)
├── plugins.lock.json      # Version pinning for non-marketplace dependencies and vendored skills
├── hooks/                 # Claude Code hooks: session start, statusline, RTK rewrite, ctx7 + design-toolchain reminders, attention notify, unpushed-work guard, manual-mode push guard
├── githooks/              # Generated git hooks (pre-commit, post-commit, post-merge, reference-transaction), git's global core.hooksPath
├── .githooks/             # This repo's own copy of the same hooks
├── rules/                 # Rule files deployed to ~/.claude/rules (path-scoped or always-on)
├── agents/                # Execution units called by skills (never invoked directly)
├── skills/                # Entry points invoked via /skill-name
├── skills-external/       # Vendored skill packs: gstack submodule, design skills, superpowers, agent-skills, MengTo scroll skills, 21st and Higgsfield packs (machine-owned copies gitignored)
├── templates/             # Per-project templates (CLAUDE.md, settings, memory registries, deploy runbook, gitignore)
└── lib/                   # Shared libs: gitflow, profiles, vendoring, effort pins, gates, archetypes, tests
```

## Architecture principles

- `skills/` = entry points you invoke via `/skill-name`
- `agents/` = execution units called by skills (never invoked directly by user)
- `templates/` = symlinked to `~/.claude/templates/` — copy into projects via `/onboard` or manually
- **Graphify** builds a knowledge graph of any codebase (`/graphify query`), producing a navigable wiki in `graphify-out/wiki/`. This map helps Claude understand project structure, find relevant code faster, and reason across files. Essential for large-scope tasks (multi-file features, complex bugs, architectural changes). Small tasks should skip it and read files directly. Proposed only from 200 tracked code files: the session-start banner informs, the user decides; nothing builds a graph without that go.
