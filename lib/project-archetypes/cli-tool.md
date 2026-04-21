---
name: cli-tool
category: cli
public: false
database: none
hosting_hints:
  - npm-registry
  - pypi
  - crates-io
  - homebrew
  - github-releases
audit_stack:
  - analyze
  - code-clean
  - cso
  - doc
plugins:
  context7: optional
  ui-ux-pro-max: no
  gstack: no
---

# CLI Tool

Outil en ligne de commande — distribué via un registry (npm, PyPI, crates.io, Homebrew) ou binaire.

## Detection signals

### Strong signals (×3)
- STRING_IN_FILE: `package.json` contient "\"bin\":" (entry point CLI)
- STRING_IN_FILE: `setup.py` OR `pyproject.toml` contient "console_scripts" OR "[project.scripts]"
- STRING_IN_FILE: `Cargo.toml` contient "[[bin]]"
- FILE: `cmd/*/main.go` (convention Go CLI)

### Medium signals (×2)
- DEP: "commander", "yargs", "clap" (Rust), "click" (Python), "typer", "cobra" (Go), "argparse"
- FILE: `bin/*` executable
- FILE: `src/cli.ts` OR `src/cli.py` OR `src/cli.rs` OR `src/main.rs`

### Weak signals (×1)
- DEP: "chalk", "kleur", "colorama", "termcolor" (output coloré)
- DEP: "inquirer", "prompts", "questionary" (prompts interactifs)
- FILE: `README.md` AVEC STRING "Usage:" OR "Installation:"
- FILE: `CHANGELOG.md`

### Counter-signals (exclusion)
- DEP: `react`, `next`, `vue`, `fastapi`, `express` → web, pas CLI
- FILE: `index.html` → web

## Implications
- **Distribution** : npm / PyPI / crates.io / Homebrew / binaires GitHub Releases
- **Base de données** : aucune (sauf outil qui manipule une DB externe)
- **SEO/GEO** : N/A
- **Surface sécurité** : MOYENNE — deps externes, exécution locale, parfois privilèges élevés
- **UI/UX** : N/A (interface texte)

## Typical pain points
- Pas de versioning semver strict (breaking changes silencieux)
- CHANGELOG absent ou pas à jour
- Tests des commandes absents (pytest-click, oclif-test, etc.)
- Pas de help text cohérent (`--help` incomplet)
- Exit codes incohérents (0 toujours, même en erreur)
- Output pas parseable (pas de `--json`)
- Pas de shell completion (bash/zsh/fish)
- Deps avec failles (npm audit / cargo audit / pip-audit non exécuté)
- Pas de cross-platform test (Win/macOS/Linux)
- Logs vers stdout au lieu de stderr (casse les pipes)
- Pas de gestion des signaux (SIGINT → cleanup ?)
- Installation instructions incomplètes dans README

## Interview questions (adaptive)
En plus du set minimum business :
- Langage : Node.js / Python / Rust / Go / autre ?
- Framework CLI : Commander / Clap / Click / Cobra / argparse / autre ?
- Distribution : npm / PyPI / crates.io / Homebrew / binaires GitHub / multiple ?
- OS cibles : Linux / macOS / Windows / WSL ?
- Interactivité : prompts interactifs / pure arguments CLI ?
- Output : texte formaté / JSON / les deux (`--json`) ?
- Shell completion fournie ? (oui / non / souhaité)
- Tests : couverture actuelle / cible ?
- Releases : manuelles / CI (goreleaser, semantic-release, release-please) ?
- Deps externes binaires requis ? (git, docker, ffmpeg, etc.)

## Plugin recommendations
- **context7** : OPTIONAL — ON si framework CLI récent
- **ui-ux-pro-max** : OFF (pas d'UI graphique)
- **gstack** : OFF

## Example project layout
```
package.json          OR   pyproject.toml       OR   Cargo.toml
src/
  cli.ts              OR   cli.py               OR   main.rs
  commands/
    init.ts
    build.ts
bin/
  my-tool
tests/
README.md (Usage + Installation)
CHANGELOG.md
```
