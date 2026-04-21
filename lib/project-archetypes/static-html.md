---
name: static-html
category: static
public: true
database: none
hosting_hints:
  - shared
  - netlify
  - cloudflare-pages
  - github-pages
  - vercel
audit_stack:
  - analyze
  - code-clean
  - seo
  - design-review
  - perf
  - a11y
  - doc
plugins:
  context7: no
  ui-ux-pro-max: yes
  gstack: optional
---

# Static HTML Site

Site statique pur — HTML/CSS/JS écrits à la main, sans framework, sans build step (ou build minimal type `sass`).

## Detection signals

### Strong signals (×3)
- FILE: `index.html`
- STRING_IN_FILE: `index.html` contient "<!DOCTYPE html>"

### Medium signals (×2)
- DIR: `css/` OR `styles/`
- DIR: `js/` OR `scripts/`
- DIR: `img/` OR `images/` OR `assets/`
- EXT: 3 fichiers .html (multi-pages)

### Weak signals (×1)
- FILE: `.htaccess` (hébergement Apache classique)
- FILE: `CNAME` (GitHub Pages)
- FILE: `netlify.toml` OR `_redirects`
- FILE: `robots.txt`
- FILE: `sitemap.xml`

### Counter-signals (exclusion, si matchés → rejette)
- FILE: `package.json` AVEC DEP react/vue/svelte/astro/next
- FILE: `wp-config.php` → c'est WordPress
- DIR: `node_modules/` (suggère framework)

## Implications
- **Hébergement** : shared hosting classique, GitHub Pages, Netlify, Cloudflare Pages
- **Base de données** : aucune (formulaires via services tiers : Formspree, Netlify Forms)
- **SEO/GEO** : CRITIQUE — souvent le seul canal d'acquisition
- **Surface sécurité** : petite (si pas de formulaires/PHP) / moyenne (avec contact form ou CMS caché)
- **UI/UX** : critique — c'est toute l'expérience

## Typical pain points
- Meta tags manquants/incomplets (description, OG, Twitter Card)
- Pas de schema.org / JSON-LD
- Images non optimisées (pas de WebP/AVIF, pas de lazy loading, pas de srcset)
- Vidéos non optimisées : auto-play bloquant LCP, pas de poster image, codec unique (pas de fallback), pas de preload="metadata"
- Embeds tiers (Calendly, YouTube, Typeform, Mapbox iframe) → CLS + TBT + cookies RGPD + invisibles aux crawlers
- CSS/JS non minifiés
- Pas de robots.txt ou sitemap
- Pas de favicon/manifeste PWA
- Liens cassés internes (pas de vérification automatique)
- Accessibilité : alt manquants, contraste insuffisant, pas de landmarks
- Pas de Core Web Vitals monitoring
- Pas de gestion 404/redirections

## Interview questions (adaptive)
En plus du set minimum business :
- Hébergement actuel / cible ? (shared / Netlify / Cloudflare / GitHub Pages / autre)
- Nom de domaine configuré ? (oui + lequel / pas encore)
- Multi-langue prévu ? (oui + langues / non) `[if: public=true]`
- Formulaire de contact / newsletter ? (oui + via quel service / non)
- Analytics ? (Plausible / GA4 / aucun / autre)
- Widgets / embeds tiers ? (Calendly, YouTube, Typeform, Mapbox, etc. — impacte perf + RGPD)
- Vidéos intégrées ? (hébergement : local / YouTube / Vimeo / Cloudflare Stream — poids, poster, codecs)
- Contraintes légales France : cookies, mentions légales, RGAA a11y ? (liste)
- Déjà un compte Google Search Console / Bing Webmaster ? (oui / non)

## Plugin recommendations
- **ui-ux-pro-max** : ON — l'UI/UX est 100% du produit
- **gstack** : OPTIONAL — utile pour audit Lighthouse/Axe si site déployé
- **context7** : OFF — pas de fast-libs

## Example project layout
```
index.html
about.html
contact.html
css/
  style.css
js/
  main.js
img/
  logo.svg
robots.txt
sitemap.xml
```
