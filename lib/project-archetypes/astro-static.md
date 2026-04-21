---
name: astro-static
category: framework
public: true
database: optional
hosting_hints:
  - netlify
  - cloudflare-pages
  - vercel
  - github-pages
  - shared
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

# Astro (static / islands)

Framework statique avec islands (React/Vue/Svelte). Zéro JS par défaut. Idéal portfolio, docs, blog, landing.

## Detection signals

### Strong signals (×3)
- FILE: `astro.config.mjs` OR `astro.config.ts` OR `astro.config.js`
- DEP: `package.json` contient "astro"

### Medium signals (×2)
- DIR: `src/pages/` AVEC FILE `.astro`
- EXT: 3+ fichiers .astro
- DIR: `src/components/`
- DIR: `src/layouts/`

### Weak signals (×1)
- DIR: `src/content/` (Content Collections)
- DEP: `@astrojs/*` (integrations : react, tailwind, mdx, sitemap)
- FILE: `tsconfig.json` avec "extends": "astro/tsconfigs/*"

### Composition overlays
- Islands framework : DEP `@astrojs/react`, `@astrojs/vue`, `@astrojs/svelte` → noter
- SSR activé : `astro.config.*` contient `output: 'server'` → change implications (pas 100% static)

## Implications
- **Hébergement** : Netlify, Cloudflare Pages, Vercel, GitHub Pages, shared (static)
- **Base de données** : OPTIONNELLE — rare en mode statique, possible via Astro DB ou backend externe
- **SEO/GEO** : EXCELLENT — HTML statique au build, parfait pour AI crawlers
- **Surface sécurité** : PETITE (pas de backend en mode static) / MOYENNE (mode SSR)
- **UI/UX** : CRITIQUE

## Typical pain points
- `@astrojs/sitemap` non installé/configuré
- `@astrojs/mdx` mal configuré (pas de frontmatter type-safe)
- Content Collections sans schéma Zod
- Images non optimisées (pas `<Image>` d'Astro)
- `client:load` utilisé partout (défait l'intérêt des islands)
- Pas de `robots.txt`
- Pas de JSON-LD / Schema.org
- View Transitions non utilisées alors que pertinentes
- RSS feed manquant (blog)

## Interview questions (adaptive)
En plus du set minimum business :
- Type de site : portfolio / blog / docs / landing / e-commerce / autre ?
- Islands framework si besoin d'interactivité : React / Vue / Svelte / Solid / aucun ?
- Content Collections utilisées ? (articles / projets / autre)
- Mode : static (par défaut) ou SSR (output: 'server') ?
- Déploiement : Netlify / Cloudflare / Vercel / GitHub Pages / autre ?
- i18n prévu ? (oui + quelles langues / non) `[if: public=true]`
- CMS headless couplé ? (Sanity / Contentful / Notion / aucun)

## Plugin recommendations
- **context7** : OPTIONAL — ON si Astro version récente + integrations nombreuses
- **ui-ux-pro-max** : ON — Astro est souvent choisi pour sites "beaux"
- **gstack** : OPTIONAL — utile pour Lighthouse

## Example project layout
```
astro.config.mjs
src/
  pages/
    index.astro
    about.astro
    blog/[slug].astro
  layouts/
    Base.astro
  components/
    Header.astro
    Card.tsx  (React island)
  content/
    blog/*.md
public/
  favicon.svg
```
