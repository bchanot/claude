# Architecture — claude-config

Repo layout and structural principles. Command workflows live in
[`USAGE.md`](./USAGE.md); version history in [`CHANGELOG.md`](./CHANGELOG.md).

## Project layout

```
claude-config/
├── CLAUDE.global.md       # Global coding preferences — deployed as ~/.claude/CLAUDE.md
├── CLAUDE.md              # Project-scope instructions (this repo only)
├── settings.json          # Global permissions (deny / ask / allow rules)
├── install.sh             # Bootstrap: Claude Code CLI + auth + submodules + link + plugins
├── install-plugins.sh     # One-shot installer: prerequisites + all plugins
├── link.sh                # Symlinks this repo into ~/.claude/
├── doctor.sh              # Setup diagnostic
├── update-all.sh          # One-command update for all components
├── Makefile               # Unified entry point: make install / doctor / update
├── plugins.lock.json      # Version pinning for non-marketplace dependencies
├── hooks/                 # Session start, statusline, RTK rewrite + ctx7 + design-toolchain reminders
├── agents/                # Execution units called by skills (never invoked directly)
├── skills/                # Entry points invoked via /skill-name
├── skills-external/       # Vendored skill packs (gstack submodule + installer-fetched design packs)
├── templates/             # Per-project templates (CLAUDE.md, settings, memory registries, deploy runbook, gitignore)
└── lib/                   # Shared shell libs (gitflow, profiles, commit helpers, archetypes, tests)
```

## Architecture principles

- `skills/` = entry points you invoke via `/skill-name`
- `agents/` = execution units called by skills (never invoked directly by user)
- `templates/` = symlinked to `~/.claude/templates/` — copy into projects via `/onboard` or manually
- **Graphify** builds a knowledge graph of any codebase (`/graphify query`), producing a navigable wiki in `graphify-out/wiki/`. This map helps Claude understand project structure, find relevant code faster, and reason across files. Essential for large-scope tasks (multi-file features, complex bugs, architectural changes). Small tasks should skip it and read files directly.
