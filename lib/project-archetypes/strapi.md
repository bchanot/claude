---
name: strapi
category: cms
public: false
database: required
hosting_hints:
  - vps
  - docker
  - render
  - railway
  - strapi-cloud
audit_stack:
  - analyze
  - code-clean
  - cso
  - perf
  - doc
plugins:
  context7: yes
  ui-ux-pro-max: no
  gstack: no
---

# Strapi (headless CMS, Node.js)

CMS headless Node.js, API REST + GraphQL. Admin panel React intégré. Consomé par frontend séparé (Next/Nuxt/Astro/React/etc.).

## Detection signals

### Strong signals (×3)
- DEP: `package.json` contient "@strapi/strapi" OR "strapi"
- FILE: `config/server.js` OR `config/server.ts`
- FILE: `config/admin.js` OR `config/admin.ts`
- FILE: `config/database.js` OR `config/database.ts`

### Medium signals (×2)
- DIR: `src/api/`
- DIR: `src/components/`
- DIR: `config/env/`
- FILE: `.strapi-updater.json`
- DEP: `@strapi/plugin-*`

### Weak signals (×1)
- DIR: `public/uploads/`
- FILE: `database/migrations/`
- FILE: `favicon.png` (admin panel favicon)
- DEP: "sqlite3" OR "pg" OR "mysql2" (DB adapter)

## Implications
- **Hébergement** : VPS, Docker (Render, Railway, Fly), Strapi Cloud
- **Base de données** : REQUISE — SQLite (dev), PostgreSQL/MySQL (prod)
- **SEO/GEO** : N/A (admin panel non indexé) — mais le frontend qui consomme peut être public
- **Surface sécurité** : GRANDE — API publique, permissions par type de contenu, tokens API
- **UI/UX** : admin panel built-in (rarement customisé)

## Typical pain points
- Permissions roles & users mal configurées (Public peut lire/écrire par défaut)
- API tokens permanents (non expirants) en dur dans frontend
- JWT_SECRET en dur ou faible
- ADMIN_JWT_SECRET non rotaté
- SQLite en production (verrouillage, pas scalable)
- `uploads/` non délégué à CDN/S3 → storage serveur plein
- Content types modifiés en prod sans migration (données perdues)
- Plugins marketplace obsolètes
- Pas de CI (schema.json versionné mais pas de tests API)
- Strapi v3 → v4 migration non effectuée (v3 EOL)
- Webhook secrets en dur
- CORS config mal restrictive
- Rate limiting absent (DDOS admin trivial)
- `config/database.js` committé avec credentials

## Interview questions (adaptive)
En plus du set minimum business :
- Version Strapi ? (v3 / v4 / v5)
- Base de données prod : PostgreSQL / MySQL / SQLite (warn si SQLite) ?
- Plugins marketplace utilisés ? (top 5)
- API consommateurs : frontend(s) propre(s) ? tierces parties ?
- Tokens API : permanents ou revocables ?
- Content-types count et profondeur (nested components) ?
- Uploads : local / S3 / Cloudinary / autre ?
- Déploiement : VPS / Docker / Strapi Cloud ?
- Webhooks configurés ? (revalidate frontend après changement content)
- GraphQL activé ?
- Rate limiting + CORS correctement configurés ?
- Environnement staging ?

## Plugin recommendations
- **context7** : ON — Strapi évolue (v4 → v5 breaking changes fréquents)
- **ui-ux-pro-max** : OFF (admin panel built-in, rarement customisé)
- **gstack** : OFF

## Example project layout
```
package.json
config/
  server.ts
  admin.ts
  database.ts
  plugins.ts
  env/
    production/
      database.ts
src/
  api/
    article/
      controllers/
      routes/
      services/
      content-types/
        article/
          schema.json
  components/
    seo/
      metadata.json
  extensions/
public/
  uploads/
database/
  migrations/
```
