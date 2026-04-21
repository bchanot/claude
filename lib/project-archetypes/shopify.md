---
name: shopify
category: cms
public: true
database: managed
hosting_hints:
  - shopify-managed
audit_stack:
  - analyze
  - code-clean
  - seo
  - design-review
  - perf
  - a11y
  - doc
plugins:
  context7: optional
  ui-ux-pro-max: yes
  gstack: optional
---

# Shopify (theme / custom app)

Thème Shopify custom (Liquid + JSON templates) ou custom app. DB gérée par Shopify. Déploiement via Shopify CLI. Hébergement Shopify-exclusive.

## Detection signals

### Strong signals (×3)
- DIR: `sections/` AVEC `.liquid` files
- DIR: `templates/` AVEC `.liquid` OR `.json`
- FILE: `config/settings_schema.json`
- DEP: `package.json` contient "@shopify/cli" OR "@shopify/cli-hydrogen" OR "@shopify/theme"

### Medium signals (×2)
- DIR: `snippets/` AVEC `.liquid`
- DIR: `layout/` AVEC `theme.liquid`
- DIR: `locales/` AVEC `.json` (i18n Shopify)
- FILE: `.shopifyignore`
- FILE: `config/settings_data.json`

### Weak signals (×1)
- DIR: `assets/` avec theme assets
- FILE: `package.json` avec scripts "shopify theme dev"
- EXT: 10+ fichiers .liquid

### Composition overlays
- **Hydrogen** (headless Shopify + Remix) : DEP `@shopify/hydrogen` → archetype devient hybride (traiter comme Remix/React + Shopify API)

## Implications
- **Hébergement** : Shopify managed (aucun serveur à gérer)
- **Base de données** : gérée par Shopify (produits, clients, commandes)
- **SEO/GEO** : CRITIQUE (e-commerce)
- **Surface sécurité** : MOYENNE — Shopify sécurise l'infra ; côté thème = XSS possible via Liquid mal échappé, secrets dans config
- **UI/UX** : CRITIQUE (conversion)

## Typical pain points
- Liquid non échappé (`{{ product.description }}` sans `| escape` → XSS si contenu user)
- Images produits non optimisées (pas de responsive srcset)
- JS tiers accumulés (reviews, chat, upsell, tracker) → perf morte
- Sections `<script>` inline sans defer
- Core Web Vitals mauvais (LCP > 4s typique)
- Pas de JSON-LD Product schema
- Meta tags produits générés auto mal personnalisés
- Langues multiples : `locales/` incomplet
- Theme check warnings ignorés (`shopify theme check`)
- Pas de version control sur `settings_data.json` (conflits entre dev et prod)
- Accessibilité : cart drawers sans focus trap, modals sans ARIA

## Interview questions (adaptive)
En plus du set minimum business :
- Thème : custom (OS 2.0 avec sections JSON) ou thème acheté ?
- Hydrogen (headless) ou thème classique ?
- Plan Shopify : Basic / Standard / Advanced / Plus ?
- Multi-langue / multi-devise ? (Shopify Markets)
- Apps installées critiques (nombre + top 5) ?
- Custom code actuel : ampleur (juste tweaks, ou theme from scratch) ?
- Volume commandes mensuel (dimensionnement) ?
- Intégrations : ERP / CRM / fulfillment ?
- Checkout customization (Plus only) ?
- Theme check passe-t-il sans erreur ?

## Plugin recommendations
- **context7** : OPTIONAL — Hydrogen/Remix évolue vite
- **ui-ux-pro-max** : ON — e-commerce UX = conversion
- **gstack** : OPTIONAL — pour audit Lighthouse live sur le store

## Example project layout
```
config/
  settings_schema.json
  settings_data.json
sections/
  header.liquid
  product-form.liquid
templates/
  index.json
  product.json
snippets/
  price.liquid
layout/
  theme.liquid
assets/
  theme.css
  theme.js
locales/
  en.default.json
  fr.json
.shopifyignore
```
