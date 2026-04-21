---
name: nextjs-app-router
category: framework
public: true
database: optional
hosting_hints:
  - vercel
  - netlify
  - cloudflare-pages
  - docker
  - k8s
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
  context7: yes
  ui-ux-pro-max: yes
  gstack: optional
---

# Next.js (App Router)

Framework React SSR/SSG/ISR. App Router (`app/` dir) est la convention moderne depuis Next 13+.

## Detection signals

### Strong signals (×3)
- FILE: `next.config.js`
- FILE: `next.config.mjs`
- FILE: `next.config.ts`
- DEP: `package.json` contient "next"
- DIR: `app/` AVEC FILE `app/layout.tsx` OR `app/layout.jsx` OR `app/layout.js`

### Medium signals (×2)
- FILE: `app/page.tsx` OR `app/page.jsx` OR `app/page.js`
- DIR: `app/api/` (route handlers)
- FILE: `middleware.ts` OR `middleware.js`
- FILE: `.env.local`

### Weak signals (×1)
- DIR: `public/` (assets statiques)
- EXT: 5+ fichiers .tsx
- DEP: `tailwindcss` (stack fréquente)
- DEP: `@vercel/*`

### Counter-signals (exclusion)
- DIR: `pages/` AU PREMIER NIVEAU SANS DIR `app/` → c'est Pages Router (archétype à part, à créer plus tard)

### Composition overlays
- ORM détecté : DEP `prisma`, `drizzle-orm`, `@supabase/supabase-js`, `mongoose` → ajouter questions DB
- Auth détectée : DEP `next-auth`, `@clerk/nextjs`, `@auth0/nextjs-auth0` → ajouter questions auth

## Implications
- **Hébergement** : Vercel (first-class), Netlify, Cloudflare Pages, Docker (standalone output)
- **Base de données** : OPTIONNELLE — souvent présente via Prisma/Drizzle/Supabase
- **SEO/GEO** : CRITIQUE (App Router permet SSR/SSG parfaitement indexable si bien configuré)
- **Surface sécurité** : MOYENNE-GRANDE (middleware, API routes, auth)
- **UI/UX** : CRITIQUE

## Typical pain points
- Mix "use client" / Server Components mal maîtrisé (fuite d'état, hydratation)
- `revalidate` / cache ISR mal configuré (contenu obsolète ou trop de builds)
- Metadata API (`generateMetadata`) absente → pas de SEO dynamique
- Pas de `robots.txt` / `sitemap.ts` (SEO)
- Images non optimisées (`next/image` pas utilisé)
- Bundle JS trop gros (analyser avec `@next/bundle-analyzer`)
- `.env` committé / secrets exposés côté client (NEXT_PUBLIC_*)
- Pas de rate limiting sur route handlers
- Middleware lourd (latence sur chaque requête)
- API routes sans validation input (Zod/Yup absent)
- Pas de loading.tsx / error.tsx / not-found.tsx

## Interview questions (adaptive)
En plus du set minimum business :
- Rendu cible : SSR / SSG / ISR / mix ? Stratégie par route ?
- ORM / DB : Prisma / Drizzle / Supabase / autre / aucun ?
- Auth : NextAuth / Clerk / Auth0 / custom / aucun ?
- Déploiement : Vercel / selfhost Docker / Cloudflare / autre ?
- Testing : Playwright / Vitest / Jest / aucun ?
- i18n prévu ? (oui + quelles langues / non)
- CMS headless couplé ? (Sanity / Strapi / Contentful / aucun)
- Trafic cible et budget perf (TTI, LCP) ?

## Plugin recommendations
- **context7** : ON — Next.js évolue vite (App Router changes fréquents)
- **ui-ux-pro-max** : ON
- **gstack** : OPTIONAL — ON pour QA navigateur (Lighthouse, Axe, E2E)

## Example project layout
```
next.config.ts
middleware.ts
app/
  layout.tsx
  page.tsx
  globals.css
  (marketing)/
    about/page.tsx
  api/
    hello/route.ts
public/
  favicon.ico
```
