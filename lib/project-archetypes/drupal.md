---
name: drupal
category: cms
public: true
database: required
hosting_hints:
  - shared
  - vps
  - acquia
  - pantheon
  - platform-sh
  - docker
audit_stack:
  - analyze
  - code-clean
  - seo
  - design-review
  - perf
  - cso
  - a11y
  - doc
plugins:
  context7: no
  ui-ux-pro-max: optional
  gstack: optional
---

# Drupal

CMS PHP/MySQL enterprise. Architecture modulaire. Thèmes custom, modules contrib + custom. Headless possible (Drupal API + frontend découplé).

## Detection signals

### Strong signals (×3)
- FILE: `sites/default/settings.php`
- FILE: `core/lib/Drupal.php`
- DIR: `core/`
- STRING_IN_FILE: `composer.json` contient "drupal/core" OR "drupal/core-recommended"

### Medium signals (×2)
- DIR: `modules/contrib/`
- DIR: `modules/custom/`
- DIR: `themes/custom/`
- DIR: `web/` (Composer-based install, `composer create-project drupal/recommended-project`)
- FILE: `composer.lock` contenant deps drupal
- FILE: `.drush/`

### Weak signals (×1)
- DIR: `vendor/`
- FILE: `.htaccess` contenant "RewriteRule .*\.php"
- FILE: `update.php`
- EXT: 20+ fichiers .php

### Composition overlays
- **Multisite** : STRING_IN_FILE `sites/sites.php` contient "$sites[" → noter multisite
- **Headless/decoupled** : DEP JSON:API activée (`core/modules/jsonapi/`) + frontend séparé → composer avec l'archetype frontend détecté

## Implications
- **Hébergement** : shared (rare pour Drupal), VPS, Acquia Cloud, Pantheon, platform.sh, Docker
- **Base de données** : MySQL/MariaDB/PostgreSQL REQUISE
- **SEO/GEO** : CRITIQUE
- **Surface sécurité** : TRÈS GRANDE — cœur + modules contrib + thème custom + permissions complexes
- **UI/UX** : thème-dependent

## Typical pain points
- Drupal core obsolète (Drupal 7 EOL, migration vers 10/11 critique)
- Modules contrib obsolètes → failles sécurité
- `settings.php` committé avec credentials DB
- DB_SECRET / hash_salt en dur
- Pas d'environnement staging / CI
- Permissions roles/users mal configurées
- Cache (Redis/Memcache) absent
- Vues complexes non optimisées (queries multi-joins)
- Composer.lock obsolète (drupal deps avec vulnérabilités)
- PHP version obsolète (< 8.1)
- Entity references sans index → slow queries
- Pas de CI pour les tests (PHPUnit/Behat ignorés)
- Configuration management non utilisé (changements DB non versionnés)

## Interview questions (adaptive)
En plus du set minimum business :
- Version Drupal ? (7 / 8 / 9 / 10 / 11)
- Hébergeur actuel ? (shared / VPS / Acquia / Pantheon / autre)
- Thème : custom ou contrib ?
- Modules custom importants (nombre + fonctionnalités) ?
- Architecture : monolithique ou headless (JSON:API / GraphQL) ?
- Configuration Management utilisé ? (yml exportés dans config/sync)
- Staging / CI pipeline existant ?
- Stratégie de backup DB ?
- Dernier audit sécurité ?
- Composer workflow (core-recommended vs legacy) ?
- Drush / Drupal Console utilisé ?
- Trafic mensuel + dimensionnement serveur ?

## Plugin recommendations
- **ui-ux-pro-max** : OPTIONAL — ON si thème custom en dev
- **gstack** : OPTIONAL — audit Lighthouse/Axe sur staging
- **context7** : OFF — Drupal évolue lentement

## Example project layout
```
composer.json
composer.lock
web/
  core/
  modules/
    contrib/
    custom/
      mon_module/
        mon_module.info.yml
        mon_module.module
  themes/
    custom/
      mon_theme/
        mon_theme.info.yml
        mon_theme.libraries.yml
  sites/
    default/
      settings.php
      files/
config/
  sync/
vendor/
```
