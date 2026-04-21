---
name: ghost
category: cms
public: true
database: required
hosting_hints:
  - ghost-pro
  - vps
  - docker
  - digitalocean-marketplace
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
  context7: optional
  ui-ux-pro-max: yes
  gstack: optional
---

# Ghost (publishing CMS, Node.js)

CMS de publication Node.js orienté blog / newsletter / membership. Thème Handlebars. Database MySQL (SQLite en dev).

## Detection signals

### Strong signals (×3)
- DEP: `package.json` contient "ghost" (au niveau du thème : engines.ghost)
- FILE: `package.json` contient `"engines": { "ghost": "..." }` (thème)
- FILE: `config.production.json` OR `config.development.json` (install Ghost)
- DIR: `content/themes/`

### Medium signals (×2)
- DIR: `partials/` AVEC `.hbs`
- FILE: `default.hbs` OR `index.hbs` OR `post.hbs`
- DIR: `assets/css/` AVEC `source/` (stylesheets SCSS)
- FILE: `gulpfile.js` OR `rollup.config.js` (build Ghost theme)
- EXT: 5+ fichiers .hbs

### Weak signals (×1)
- DIR: `content/images/`
- DIR: `content/data/` (SQLite dev)
- FILE: `ghost.service` (systemd)
- DEP: `@tryghost/content-api` OR `@tryghost/admin-api` (headless usage)

### Composition overlays
- **Headless Ghost** : usage via Content API avec frontend séparé → traiter comme API producer + frontend archetype

## Implications
- **Hébergement** : Ghost(Pro) managed, VPS (Ghost-CLI), Docker, DigitalOcean marketplace
- **Base de données** : MySQL prod REQUISE, SQLite dev
- **SEO/GEO** : CRITIQUE (blog / content)
- **Surface sécurité** : MOYENNE — admin panel, API, member auth, Stripe integration
- **UI/UX** : theme-dependent

## Typical pain points
- Version Ghost obsolète (cycle release rapide)
- Thème incompatible avec version Ghost courante (GSCAN warnings)
- `config.production.json` committé avec DB credentials
- Mailgun API key en dur (delivery newsletter)
- Stripe secret key exposée (membership)
- Pas de backup automatique (content/images + DB)
- Members non conformes RGPD (pas de double opt-in, pas de unsubscribe)
- Pas de robots.txt / sitemap custom (Ghost génère mais pas configurable)
- Perf : images non optimisées, Handlebars non cache
- Newsletter : HTML email non testé clients (Outlook catastrophique)
- CDN absent (images/assets servis depuis serveur)
- Intégrations Zapier / custom webhooks : secrets rotation absente

## Interview questions (adaptive)
En plus du set minimum business :
- Hébergement : Ghost(Pro) / self-hosted VPS / Docker ?
- Thème : custom (avec source .hbs) ou acheté ?
- Usage principal : blog / newsletter / membership / combinaison ?
- Members payants ? (Stripe intégration)
- Version Ghost actuelle ?
- Backup strategy (content/images + DB) ?
- Intégrations : Mailgun / SendGrid / Postmark pour emails ?
- CDN / image optimization ?
- Headless / découplé ? (Content API + frontend séparé)
- i18n prévu (Ghost n'a pas i18n natif) ?
- GSCAN check passe-t-il ?

## Plugin recommendations
- **context7** : OPTIONAL — Ghost release cycle rapide
- **ui-ux-pro-max** : ON — theming orienté contenu
- **gstack** : OPTIONAL — audit Lighthouse sur posts clés

## Example project layout (theme)
```
package.json           ("engines": { "ghost": "^5.0.0" })
default.hbs
index.hbs
post.hbs
page.hbs
tag.hbs
author.hbs
partials/
  header.hbs
  footer.hbs
  post-card.hbs
assets/
  css/
    source/
      screen.scss
  js/
  images/
gulpfile.js
```
