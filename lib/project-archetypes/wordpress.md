---
name: wordpress
category: cms
public: true
database: required
hosting_hints:
  - shared
  - vps
  - managed-wp
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

# WordPress

CMS PHP/MySQL classique. Thème custom OU thème acheté + plugins. Peut inclure WooCommerce (overlay séparé).

## Detection signals

### Strong signals (×3)
- FILE: `wp-config.php`
- FILE: `wp-config-sample.php`
- DIR: `wp-admin/`
- DIR: `wp-includes/`

### Medium signals (×2)
- DIR: `wp-content/`
- DIR: `wp-content/themes/`
- DIR: `wp-content/plugins/`
- STRING_IN_FILE: `wp-content/themes/*/style.css` contient "Theme Name:"
- STRING_IN_FILE: `composer.json` contient "johnpbloch/wordpress" OR "roots/wordpress"

### Weak signals (×1)
- FILE: `.htaccess` contient "RewriteRule ^index\.php$"
- EXT: 20+ fichiers .php
- FILE: `wp-cli.yml`
- DIR: `mu-plugins/`

### Composition overlays
- **WooCommerce** : DIR `wp-content/plugins/woocommerce/` OR DEP `woocommerce` → appliquer overlay e-commerce
- **Multisite** : STRING_IN_FILE `wp-config.php` contient "WP_ALLOW_MULTISITE" → noter

## Implications
- **Hébergement** : shared hosting (OVH, IONOS, Hostinger), VPS, ou managed-WP (WP Engine, Kinsta)
- **Base de données** : MySQL/MariaDB REQUISE
- **SEO/GEO** : CRITIQUE
- **Surface sécurité** : GRANDE — plugins tiers, wp-admin exposé, XML-RPC, attaques massives bruteforce
- **UI/UX** : dépend du thème (custom ou acheté)

## Typical pain points
- Plugins obsolètes / non mis à jour (failles critiques)
- Pas d'environnement staging
- Images non optimisées (poids page énorme)
- Pas de cache (page cache, object cache)
- wp-admin accessible publiquement sans 2FA
- XML-RPC exposé (pingback DDoS, bruteforce)
- Base de données : tables `wp_options` gonflées par transients
- SEO plugin (Yoast / RankMath / SEOPress) mal configuré ou absent
- Thème custom non testé sur mobile / a11y
- Backup absent ou manuel
- PHP version obsolète (< 8.1)

## Interview questions (adaptive)
En plus du set minimum business :
- Hébergeur actuel ? (shared / VPS / managed-WP — lequel)
- Version PHP et WordPress ?
- Thème : custom (code propre) ou acheté (ThemeForest / autre) ?
- Plugins critiques ? (nombre total + liste des plus importants)
- Environnement staging dispo ? (oui / non / souhaité)
- Dernier audit sécurité ? (date / jamais)
- Stratégie de backup actuelle ? (quotidien / manuel / aucun)
- SEO plugin installé ? (Yoast / RankMath / SEOPress / aucun)
- WooCommerce installé ? (oui / non) `[if: signal matches WooCommerce]`
- Accès SSH / WP-CLI disponible ? (oui / non)
- Trafic mensuel estimé ? (pour dimensionnement perf)

## Plugin recommendations
- **ui-ux-pro-max** : OPTIONAL — ON si thème custom en dev
- **gstack** : OPTIONAL — pour audit Lighthouse/Axe sur staging
- **context7** : OFF — WP évolue lentement, pas de doc fast-libs

## Example project layout
```
wp-config.php
wp-admin/
wp-includes/
wp-content/
  themes/
    mon-theme/
      style.css
      functions.php
      index.php
  plugins/
    yoast-seo/
    woocommerce/  (overlay e-commerce)
  uploads/
```
