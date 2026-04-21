---
name: library
category: library
public: false
database: none
hosting_hints:
  - npm-registry
  - pypi
  - crates-io
  - maven-central
  - nuget
  - github-packages
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

# Library / Package

Bibliothèque réutilisable (API publique stable), distribuée via registry. Pas d'entry point CLI, pas de serveur, pas de frontend applicatif.

## Detection signals

### Strong signals (×3)
- STRING_IN_FILE: `package.json` contient "\"main\":" OR "\"exports\":" SANS "\"bin\":"
- STRING_IN_FILE: `pyproject.toml` contient "[project]" SANS "[project.scripts]"
- STRING_IN_FILE: `Cargo.toml` contient "[lib]" SANS "[[bin]]"
- STRING_IN_FILE: `package.json` contient "\"private\": false" OR absent ET "\"name\":" commence par "@"

### Medium signals (×2)
- FILE: `src/index.ts` OR `src/lib.rs` OR `src/__init__.py`
- DIR: `src/` AVEC code uniquement (pas de server.ts, pas de app.py)
- FILE: `tsconfig.json` AVEC STRING "\"declaration\": true" OR "\"emitDeclarationOnly\""
- FILE: `rollup.config.*` OR `tsup.config.*` OR `vite.config.*` en mode lib

### Weak signals (×1)
- FILE: `README.md` AVEC STRING "## API" OR "## Installation"
- FILE: `CHANGELOG.md`
- FILE: `LICENSE` OR `LICENSE.md`
- DIR: `examples/` OR `docs/`
- FILE: `.npmignore`

### Counter-signals (exclusion)
- STRING_IN_FILE: `package.json` contient "\"bin\":" → CLI
- DEP: `express`, `fastapi`, `react`, `next` → app, pas lib
- FILE: `index.html` → web

## Implications
- **Distribution** : npm / PyPI / crates.io / Maven / NuGet
- **Base de données** : aucune
- **SEO/GEO** : N/A (sauf page de doc dédiée, rare)
- **Surface sécurité** : INDIRECTE — les failles de la lib se propagent à ses consommateurs
- **UI/UX** : N/A

## Typical pain points
- Versioning non semver-strict → breaking changes surprise les consommateurs
- CHANGELOG absent ou vague
- Docstrings / JSDoc / rustdoc incomplets
- Exports publics instables (API leakage depuis internes)
- Pas de tests de régression / snapshot
- Couverture tests faible (< 80%)
- Pas de benchmarks (si performance critique)
- TypeScript : types trop lâches (`any`), pas d'export de types
- Rust : `#[non_exhaustive]` manquant sur enums publics
- Python : pas de `py.typed` marker → typing ignoré par consommateurs
- Deps transitives avec failles (supply chain)
- Pas de fichier `SECURITY.md`
- Pas de CI qui publie automatiquement (releases manuelles)
- Tests sur une seule version de Node/Python/Rust

## Interview questions (adaptive)
En plus du set minimum business :
- Langage + runtime cible : Node (version min) / Python (version min) / Rust (MSRV) / autre ?
- Audience : publique (open source) / privée (interne org) / mixte ?
- Stabilité actuelle : pré-1.0 / stable / LTS ?
- API : stable / en évolution / expérimentale ?
- Distribution : npm public / npm privé / PyPI / GitHub Packages / multiple ?
- Bundler si applicable : tsup / rollup / vite / esbuild ? (ESM + CJS + types ?)
- Documentation : README / docs site dédié / typedoc / Sphinx / autre ?
- Tests : coverage cible ? snapshots ? property-based ?
- CI / CD : auto-publish on tag ? semver auto (changesets / semantic-release) ?
- Politique de support : combien de versions majeures maintenues en parallèle ?
- Benchmarks requis ? (oui si lib perf-critique)

## Plugin recommendations
- **context7** : OFF — lib stable par nature, peu de doc fast-libs
- **ui-ux-pro-max** : OFF
- **gstack** : OFF

## Example project layout
```
package.json          OR   pyproject.toml       OR   Cargo.toml
src/
  index.ts            OR   __init__.py          OR   lib.rs
  core/
  utils/
tests/
docs/
examples/
README.md  (API + Installation + Examples)
CHANGELOG.md
LICENSE
```
