---
name: react-spa
category: framework
public: false
database: optional
hosting_hints:
  - netlify
  - cloudflare-pages
  - vercel
  - s3-cloudfront
  - docker
audit_stack:
  - analyze
  - code-clean
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

# React SPA (admin / dashboard / internal)

Application React pure côté client (CRA legacy / Vite / Webpack custom). PAS indexée — si public avec besoin SEO, utiliser Astro ou Next.js.

## ⚠️  Avertissement SEO (à afficher si projet public-facing)

**Une React SPA n'est pas indexable par les moteurs de recherche classiques (Google/Bing) ni par les moteurs IA (ChatGPT/Perplexity/Claude).**

Raison : le HTML servi est une coquille vide (`<div id="root"></div>`). Le contenu n'apparaît qu'APRÈS exécution JavaScript côté navigateur. Les crawlers :
- Google peut *parfois* rendre le JS, mais lentement et partiellement (pas d'indexation fiable)
- Bing : rendu JS limité
- ChatGPT/Perplexity/Claude/Gemini crawlers : **ne rendent pas de JS du tout** → ils voient une page vide → contenu invisible

**Si ce projet est public (site vitrine, blog, landing, e-commerce, docs) :**
- Migration recommandée : **Astro** (statique, SEO parfait, React islands possibles) ou **Next.js App Router** (SSR/SSG, SEO parfait)
- Coût migration : moyen (logique métier réutilisable, routing à reprendre)
- Alternative temporaire : pré-rendu (react-snap, rendertron) — fragile, déconseillé en 2026

**Si ce projet est interne (admin panel, dashboard, outil métier auth-gated) :**
- Aucun souci, le SEO n'est pas nécessaire
- React SPA est un choix valide dans ce cas

→ L'orchestrateur `/onboard` DOIT poser la question "public / interne" et afficher ce bloc si réponse = public.

## Detection signals

### Strong signals (×3)
- DEP: `package.json` contient "react" ET "react-dom"
- FILE: `vite.config.ts` OR `vite.config.js`
- FILE: `webpack.config.js` (custom bundler)
- DEP: `react-scripts` (CRA legacy)

### Medium signals (×2)
- FILE: `index.html` AVEC STRING "<div id=\"root\">"
- FILE: `src/main.tsx` OR `src/main.jsx` OR `src/index.tsx` OR `src/index.jsx`
- FILE: `src/App.tsx` OR `src/App.jsx`
- DEP: `react-router-dom` OR `@tanstack/react-router`

### Weak signals (×1)
- DIR: `src/components/`
- DIR: `src/pages/` OR `src/routes/`
- DEP: `tailwindcss`, `@mui/material`, `antd`, `chakra-ui`
- DEP: `redux`, `zustand`, `jotai`, `@tanstack/react-query`

### Counter-signals (exclusion)
- DEP: `next` → c'est Next.js (archétype nextjs-app-router)
- DEP: `astro` → c'est Astro
- FILE: `remix.config.js` → Remix (archétype à créer)
- FILE: `react-native.config.js` → mobile (archétype mobile-react-native)

## Implications
- **Hébergement** : Netlify / Cloudflare Pages / Vercel (SPA mode) / S3+CloudFront / Docker statique
- **Base de données** : OPTIONNELLE — souvent consommée via API séparée
- **SEO/GEO** : NON (rendu client-only) — si SEO critique, c'est un mauvais choix, flag à soulever
- **Surface sécurité** : MOYENNE (état côté client, auth token storage)
- **UI/UX** : CRITIQUE

## Typical pain points
- Bundle JS énorme (absence de code-splitting par route)
- Token JWT stocké dans localStorage (XSS → vol)
- Pas de CSP
- Pas de tests E2E (Playwright / Cypress absent)
- State management mal dimensionné (Redux pour 3 états simples, ou au contraire `useState` partout dans une app grosse)
- Suspense / Error Boundary non utilisés
- A11y : focus management, ARIA roles manquants
- Pas de skeleton / optimistic UI
- Fetch sans cache (pas de `@tanstack/react-query` ou SWR)
- "Public website" en SPA → SEO mort (signal d'alerte majeur à remonter en audit)

## Interview questions (adaptive)
En plus du set minimum business :
- **Usage : admin panel / dashboard interne / outil métier / webapp publique / autre ?**
  - **Si "publique" → afficher en PREMIER le bloc d'avertissement SEO ci-dessus**
  - **Puis demander : "Sachant ça, confirmez-vous que vous voulez rester en SPA, ou préférez-vous explorer une migration Astro/Next.js ?"**
  - La réponse alimente la synthèse `ONBOARD_REPORT.md` (STEP 7) en proposition d'amélioration P0 si stay=SPA+public.
- Backend : API séparée (URL) / BaaS (Supabase/Firebase) / aucune ?
- Auth : quel provider ? stockage token ?
- Routing : react-router / TanStack Router / autre ?
- State : Redux / Zustand / Jotai / context / React Query seul ?
- Tests E2E : Playwright / Cypress / aucun ?
- Bundle size cible ?
- Bundler actuel : Vite / Webpack / CRA (à migrer ?) ?

## Plugin recommendations
- **context7** : ON — React 18+/19, TanStack, etc. évoluent vite
- **ui-ux-pro-max** : ON
- **gstack** : OPTIONAL — pour E2E / Lighthouse

## Example project layout
```
index.html
vite.config.ts
src/
  main.tsx
  App.tsx
  routes/
  components/
  hooks/
  lib/
public/
```
