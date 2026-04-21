---
name: rest-api-node
category: api
public: false
database: optional
hosting_hints:
  - vps
  - docker
  - k8s
  - render
  - railway
  - fly
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

# REST API (Node.js)

API backend Node.js pure (Express / Fastify / Koa / Hapi / NestJS), sans frontend inclus.

## Detection signals

### Strong signals (×3)
- DEP: `package.json` contient l'un de : "express", "fastify", "koa", "@hapi/hapi", "@nestjs/core"
- FILE: `src/app.ts` OR `src/server.ts` OR `src/main.ts` AVEC STRING "listen(" OR "createServer"

### Medium signals (×2)
- FILE: `src/routes/` OR `src/controllers/` OR `src/handlers/`
- DEP: ORM — `prisma`, `typeorm`, `sequelize`, `drizzle-orm`, `mongoose`, `knex`
- DEP: Validation — `zod`, `joi`, `yup`, `class-validator`

### Weak signals (×1)
- DEP: `jsonwebtoken`, `passport`, `bcrypt`, `argon2`
- DEP: `pino`, `winston`, `morgan` (logging)
- FILE: `Dockerfile`
- DIR: `tests/` OR `src/__tests__/`

### Counter-signals (exclusion)
- DEP: `react`, `next`, `astro`, `vue` → frontend présent, c'est un fullstack (archetype à créer plus tard) ou SPA+API séparé (monorepo)
- DEP: `react-native` → mobile

## Implications
- **Hébergement** : VPS, Docker (Render, Railway, Fly.io), K8s, AWS ECS/Lambda
- **Base de données** : FORTEMENT PROBABLE — la plupart des API backend ont une DB
- **SEO/GEO** : N/A (API non indexée)
- **Surface sécurité** : GRANDE — point d'entrée principal pour attaques (injections, auth, rate limit)
- **UI/UX** : N/A

## Typical pain points
- Pas de versioning API (/api/v1/) — flag CLAUDE.md : "Web APIs always versioned"
- Validation input absente (pas de Zod/Joi/class-validator)
- SQL injections (string concat dans queries brutes)
- Auth faible (pas de hash password, ou MD5/SHA1)
- JWT secret en dur / faible / court
- CORS `*` en production
- Pas de rate limiting (`express-rate-limit`, `@fastify/rate-limit`)
- Pas de helmet / CSP
- Secrets dans le repo (.env committé)
- Logs qui fuient PII / tokens
- Pas de health check (`/healthz`) pour load balancer
- Pas d'observability (Sentry / OTel)
- Pas de tests (intégration absente)
- Deps obsolètes (npm audit non exécuté)

## Interview questions (adaptive)
En plus du set minimum business :
- Framework : Express / Fastify / NestJS / Koa / Hapi ?
- Base de données : PostgreSQL / MySQL / MongoDB / SQLite / autre / aucune ?
- ORM : Prisma / Drizzle / TypeORM / Sequelize / Mongoose / raw SQL ?
- Auth : JWT / OAuth / session / API key / aucun ?
- Consommateurs : frontend propre / mobile / tierce partie / interne ?
- Rate limiting en place ? (oui + comment / non)
- Observability : Sentry / OpenTelemetry / logs seulement / aucun ?
- Tests : unitaires + intégration ? couverture cible ?
- Déploiement : VPS / Docker / Lambda / autre ?
- Documentation API : OpenAPI/Swagger / Postman / aucune ?

## Plugin recommendations
- **context7** : ON — Prisma/Drizzle/Fastify évoluent vite
- **ui-ux-pro-max** : OFF
- **gstack** : OFF (API non navigable)

## Example project layout
```
src/
  app.ts
  server.ts
  routes/
    v1/
      users.ts
      orders.ts
  controllers/
  services/
  middlewares/
  schemas/   (Zod / Joi)
tests/
Dockerfile
```
