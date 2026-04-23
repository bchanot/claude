---
name: dotfiles-meta
category: meta
public: false
database: none
hosting_hints:
  - git-repo-personal
  - github
audit_stack:
  - analyze
  - code-clean
  - cso
  - doc
plugins:
  context7: no
  ui-ux-pro-max: no
  gstack: no
---

# Dotfiles / Meta-tooling / Config framework

Repo qui ne produit pas d'application mais du **configuration / scripts / conventions** — dotfiles personnels, framework de config partagée, collection de scripts de provisionning, hooks, templates.

Exemple : un repo `claude-config` avec scripts shell + settings JSON + templates + agents, sans langage applicatif compilé.

## Detection signals

### Strong signals (×3)
- FILE: `install.sh` OR `install-*.sh`
- FILE: `Makefile` AVEC STRING "install:" OR "link:" OR "setup:"
- DIR: `hooks/` (PAS git/.git/hooks — hooks custom projet)
- DIR: `templates/` AVEC contenu de config (non-code applicatif)
- FILE: `settings.json` à la racine (hors dossier d'app type .vscode/)
- STRING_IN_FILE: `README.md` contient "dotfiles" OR "config framework" OR "provisioning"

### Medium signals (×2)
- EXT: 5+ fichiers .sh
- EXT: 10+ fichiers .md
- FILE: `link.sh` OR `symlink.sh` OR `bootstrap.sh`
- DIR: `agents/` OR `skills/` OR `scripts/` (sans code applicatif associé)
- FILE: `plugins.lock.json` OR `plugins.json`

### Weak signals (×1)
- FILE: `CHANGELOG.md` de releases de config (pas d'app)
- FILE: `.gitmodules` (sub-projects config)
- FILE: `doctor.sh` OR `health.sh`
- DIR: `lib/` contenant surtout du .sh ou .md (pas du code applicatif)

### Counter-signals (exclusion — si matché, rejette)
- FILE: `package.json` AVEC DEPS applicatives (react/next/express/etc.)
- FILE: `pyproject.toml` AVEC `[project.scripts]` OR deps applicatives
- FILE: `Cargo.toml` AVEC `[[bin]]`
- FILE: `index.html` au root → web project
- FILE: `wp-config.php` → WordPress

## Implications
- **Distribution** : git clone personnel / GitHub public / fork
- **Base de données** : aucune
- **SEO/GEO** : N/A
- **Surface sécurité** : MOYENNE — scripts exécutés sur machine utilisateur, risque élevé si compromis (exécution arbitraire en shell)
- **UI/UX** : N/A

## Typical pain points
- Scripts shell sans `set -euo pipefail` → échecs silencieux
- Pas de `shellcheck` en CI
- Symlinks / installation non idempotents (re-run casse l'état)
- Pas de test / dry-run mode
- Pas de détection OS (cmd Linux-only qui casse sur macOS, ou inverse)
- Secrets en dur dans templates (API keys, tokens)
- `curl | sh` dans README (risque MITM, pas de checksum)
- Versioning flou (pas de CHANGELOG cohérent)
- Breaking changes non signalés aux utilisateurs
- Dépendances externes non vérifiées (brew/apt/npm auto-install sans consentement)
- Uninstall / rollback absent
- Documentation incomplète (comment étendre, comment contribuer)
- Pas de `LICENSE`

## Interview questions (adaptive)
En plus du set minimum business :
- Audience : personnel (dotfiles privés) / équipe / public open source ?
- OS cibles : Linux / macOS / WSL / Windows natif / tous ?
- Shell cible : bash / zsh / fish / multi ?
- Idempotence : les scripts peuvent-ils être re-exécutés sans casser ? (oui / non / à vérifier)
- Mode dry-run / preview disponible ? (oui / non / souhaité)
- Tests automatiques : shellcheck / bats / aucun ?
- Distribution : git clone manuel / installer en un liner / brew tap / autre ?
- Dépendances externes auto-installées ? (brew/apt/npm/pip) — avec consentement utilisateur ?
- Uninstall prévu ? (oui / non)
- Versioning : semver / dates / aucun ?
- `CHANGELOG.md` maintenu ? (oui / non)
- Hébergement : GitHub public / privé / GitLab / autre ?

## Plugin recommendations
- **context7** : OFF — pas de fast-libs
- **ui-ux-pro-max** : OFF
- **gstack** : OFF

## Example project layout
```
install.sh
link.sh
doctor.sh
Makefile
CLAUDE.md          (si le repo lui-même est un contexte Claude)
README.md
CHANGELOG.md
settings.json      (config globale outil)
plugins.lock.json  (lockfile d'extensions)
agents/            (agents custom)
skills/            (skills custom)
hooks/             (hooks projet, pas git)
templates/         (templates config fournis)
lib/               (helpers shell)
.claude/tasks/
.claude/memory/
.claude/audits/
```
