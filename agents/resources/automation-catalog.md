# Automation catalog — for SEO.md §11 user actions

For every action that requires the human, this catalog lists tools
that can partially or fully automate it. Both agents cite this file
when emitting user actions into `SEO.md §11`.

**Format rule in SEO.md §11**: every entry MUST include:
```
- **<Action>** — <what to do>
  **Automatisation possible avec:** <tool 1>, <tool 2>, <tool 3>
  **Budget:** <free / XX EUR/mois / one-time XX EUR>
  **Effort manuel:** <time estimate>
```

## Local SEO actions

### Google Business Profile — claim / create / optimize

- **Google Business Profile API** (free, requires Google Cloud project)
  → post updates, reply to reviews, sync hours automatically
- **Yext** (enterprise, 500-5000 EUR/mois) → syncs GMB across
  200+ directories
- **BrightLocal** (30-80 USD/mois) → GMB management + rank tracking
- **Moz Local** (14-33 USD/mois/location) → listing management
- **Uberall** (enterprise) → multi-location listing sync
- **LocalFalcon** (30-60 USD/mois) → GMB rank visualisation
- **PlePer** (~25 EUR/mois) → GMB post scheduling
- Manual workflow: 30 min/week via https://business.google.com

### Review management — collect, reply, aggregate

- **Trustpilot / Google Reviews API** (via GBP API) → read/reply programmatically
- **Birdeye** (290+ USD/mois) → review aggregation + auto-reply
- **Podium** (enterprise) → SMS-based review requests
- **NiceJob** (90 USD/mois) → review request automation
- **Grade.us** (110 USD/mois) → multi-platform aggregation
- Manual: monitor GMB + reply within 48h (legal: L121-1 Code conso FR)

### Directory citations — PagesJaunes, Yelp, Mappy, Bing Places, Apple

- **Yext** → 200+ directories incl. French
- **BrightLocal / Moz Local** → coverage varies, check French support
- **Uberall** → strong in European markets
- **Rio SEO** (enterprise) → big brands
- Manual: one-time 4-8h to register on top 10 directories

## AI visibility actions

### Monitor brand in AI engines

See `ai-visibility-tools.md`. Summary:
- **OtterlyAI, Peec AI, Trendos, ZipTie, HubSpot AEO, SE Ranking** — commercial
- **Manual spreadsheet + 20 queries/mois** — free, ~1h/mois

### Submit to AI indexes directly (MANDATORY user action on FULL audit)

AI engines read from these indexes:
- ChatGPT Search, Copilot, DuckDuckGo, Ecosia → **Bing index**
- Google AI Overviews, Gemini (grounding mode) → **Google index**
- Perplexity, Brave AI → **own crawlers + Bing fallback**

Therefore: submit to GSC + Bing Webmaster minimum on every FULL audit.

- **Bing Webmaster Tools** (FREE) — https://www.bing.com/webmasters
  Critical because ChatGPT Search, Copilot, DuckDuckGo all use Bing.
  Features: URL inspection, sitemap submission, keyword research, SEO
  reports, IndexNow API integration. Plugin for WordPress available.
  Setup: 10 min (verify domain via meta tag or DNS).
- **Google Search Console** (FREE) — https://search.google.com/search-console
  Covers Google search + AI Overviews grounding. URL inspection tool
  requests live re-indexing (faster than waiting for crawl).
- **IndexNow protocol** (FREE) — https://www.indexnow.org
  Proactive ping to Bing + Yandex + Seznam + DuckDuckGo. One-line
  API call per URL change. Plugins: Yoast (built-in), RankMath,
  Cloudflare (zone-level), Cloudflare Workers snippet. For custom
  sites: `curl` POST to `https://api.indexnow.org/indexnow`.
- **Brave Web Discovery** (FREE) — enable in Brave browser settings
  → "Aider Brave Search à découvrir du contenu". Visit your site in
  Brave browser to help its indexation. Brave Search uses this for
  index discovery, and Brave AI answers pull from Brave Search.
- **Kagi submit** (requires Kagi account) — smaller audience but
  growing for privacy-focused search.
- **Apple Business Connect** → Apple Maps + Apple Intelligence local
  discovery. Free but requires Apple ID. https://businessconnect.apple.com
- No direct "submit to ChatGPT" exists in 2026 — submission to Bing
  is the canonical path.

### Maintain llms.txt / llms-full.txt

- **llms-txt-action** (GitHub Action) → rebuild on deploy
- **Mintlify / Fern / ReadMe** → auto-generated for supported docs hosts
- **Custom cron + script** → pull from CMS, regenerate weekly
- Manual: monthly review if content changes rarely

## Entity / Knowledge Graph actions

### Create or optimize Wikidata entry

- **Kalicube** (commercial, custom pricing) → specialised Knowledge Panel + Wikidata
- **InLinks** (40-350 USD/mois) → entity optimization + Schema.org graph
- **WordLift** (30-300 USD/mois) → WordPress plugin with Wikidata linking
- **Entity.ai** → entity signal auditing
- Manual: https://www.wikidata.org, 2-4h initial + sources required

### Claim / optimize Google Knowledge Panel

- **Kalicube** — best specialisation
- **Manual via Google Search** — click "Claim this Knowledge Panel" (requires verification)
- Cannot be forced; appears when entity signals are strong enough

### LinkedIn / Crunchbase / industry directory entities

- **Yext** → includes Crunchbase sync in enterprise tiers
- **Manual** → LinkedIn Company page free, Crunchbase free profile claim
- **Brandify** (enterprise) → multi-directory entity management

## Content production actions

### Create city/service landing pages (30/70 rule)

- **Surfer SEO** (89-219 USD/mois) → content optimization with AI
- **Frase.io** (45-115 USD/mois) → SERP-driven briefs
- **Clearscope** (170+ USD/mois) → keyword + semantic briefs
- **Manual + AI writer** → use Claude/ChatGPT with explicit 30/70 instruction

Agent note: Batch D in `seo-analyzer` triage can handle the
CREATION of these pages if confirmation granted — city pages are
typically batch D (structural change, user approval needed).

### Produce blog content on schedule

- **Frase / Surfer / Clearscope** (see above)
- **MarketMuse** (enterprise) → content planning
- **Jasper AI / Copy.ai** → AI drafting (quality review mandatory)
- Human editor remains the bottleneck — AI drafts need domain expert review

### Refresh existing content quarterly

- **ContentKing** (now part of Conductor) → change detection
- **SEOClarity** (enterprise) → content decay tracking
- **Manual** — spreadsheet of top 50 pages + quarterly review cycle

## CMS plugin-first — install before editing templates

**Rule**: when the site runs on a CMS, the highest-priority SEO action
is to install/configure the SEO plugin. Manual template edits
duplicate the plugin's output and create maintenance debt.

### WordPress (2026 recommendations)

- **RankMath Free** — default recommendation. Most features in free
  tier, including Schema.org (Article, LocalBusiness, FAQ, HowTo,
  Product), breadcrumbs, sitemap, redirect manager, GSC integration,
  GEO-aware (content AI score).
  Install: Plugins → Add New → "Rank Math SEO" → Install → Activate.
  Setup wizard: ~10 min.
- **Yoast SEO Free** — most popular. Strong for meta + sitemap +
  readability. Schema.org basic in free, extended in Premium (99 USD/an).
- **Yoast SEO Premium** (99 USD/an) — redirect manager, internal
  linking suggestions, multiple focus keywords.
- **SEOPress Free** — French origin, GDPR-friendly, good Schema.org
  coverage.
- **SEOPress Pro** (49-99 EUR/an) — white-label, WooCommerce Schema,
  Google Analytics integration.
- **AIOSEO (All-in-One SEO)** — older player, solid baseline.
- **Slim SEO** — minimalist, auto-configuration, good for sites that
  need SEO without admin complexity.

Recommendation if unsure: **RankMath Free** → upgrade to RankMath Pro
(59 USD/an) only if Analytics integration or Schema Pro needed.

### Shopify

- **Plug in SEO** (free + 20 USD/mois) — scans store for SEO issues,
  suggests fixes, handles meta templates for products/collections.
- **Smart SEO** (10-30 USD/mois) — auto-generates alt tags, meta
  tags, JSON-LD (Product, Organization, Breadcrumbs).
- **SEO Manager** (20 USD/mois) — image SEO, structured data, 404
  redirects.
- **Avada SEO** — newer, good GEO-aware features.
- Shopify native: configure via Admin → Online Store → Preferences
  (title, meta description, homepage), + per-product meta fields.

### Drupal (7/8/9/10)

Core SEO stack (install as modules, free):
- **Metatag** — meta tags (OG, Twitter Card, canonical)
- **Simple XML Sitemap** — sitemap generation
- **Pathauto** — clean URLs
- **Schema.org Metatag** — JSON-LD Schema.org output
- **Yoast SEO Drupal** — on-page readability + focus keyword analysis
- **Redirect** — 301 redirects
- **Google Analytics** — GA4 integration

### Magento 1 / 2

Native Magento SEO is decent but limited. Paid extensions dominate:
- **SEO Suite Ultimate (Mageworx)** — canonical, URL rewrites, rich
  snippets, meta templates (~250-500 EUR one-time)
- **Mirasvit SEO Suite** — similar scope, 149-399 USD
- **Amasty SEO Toolkit** — HTML sitemap, rich snippets, meta
  templates
- Free basics: configure native URL rewrites + meta defaults in
  System → Configuration → Catalog → SEO

### PrestaShop

- **PrestaShop SEO Expert** (free + paid) — meta templates, rich
  snippets, image alt rules
- **JMarket SEO Pack** — structured data + breadcrumbs
- **Advanced SEO** module — meta per category/product with
  placeholders
- Native: Configure → Shop Parameters → Traffic & SEO

### Joomla

- **JoomSEF** — URL rewriting + meta management
- **sh404SEF** — commercial (~60 EUR/year), full SEO suite
- **4SEO** — native integration, comprehensive
- **OSMap** — sitemap generator (free)

### Ghost

Native SEO is strong (meta + OG + Twitter Card + JSON-LD Article/Author
out of box). Customization via theme `default.hbs` + routes.yaml.
Plugins unnecessary for most sites.

### Wix / Squarespace / Webflow (hosted CMS)

**No theme file access.** All SEO changes happen in the admin UI:
- **Wix** — SEO panel per page; Wix SEO Wiz for guided setup;
  redirects in Settings → Custom Domain → URL Redirects.
- **Squarespace** — Per-page SEO tab (title, description, image);
  sitewide in Settings → Marketing → SEO; URL slugs editable.
- **Webflow** — Page Settings per page (meta title, description,
  OG image); sitemap at `/sitemap.xml` (auto); robots.txt in Project
  Settings → SEO.

Agent cannot auto-apply anything on these platforms — emit detailed
USER action list per panel.

### Extension of this catalog for NEW CMS

If detected CMS not listed above, agent runs WebSearch:
```
web_search: <CMS name> best SEO plugin 2026
```
and emits findings with pricing in the report.

---

## Technical SEO actions

### Generate sitemaps

- **Framework plugin** — `@astrojs/sitemap`, `next-sitemap`, `@nuxtjs/sitemap`, `rails-sitemap-generator`, etc.
- **Yoast / RankMath / SEOPress** (WordPress) → auto-generate (see CMS plugins section above)
- **Screaming Frog** (200 GBP/an) → crawler-based generation
- Manual: only as last resort, hand-maintained sitemaps go stale fast

### Implement Schema.org at scale

- **Yoast / RankMath / SEOPress** (WordPress) → Article/Organization/LocalBusiness auto-graph
- **Schema App** (enterprise) → multi-CMS
- **Merkle Schema Markup Generator** (free) → one-off generation
- **Manual + `geo-schemas.md` templates** — for frameworks without plugins

### Optimize Core Web Vitals

- **PageSpeed Insights API** (free) → measure + monitor
- **WebPageTest** (free tier + paid) → detailed waterfalls
- **Cloudflare Speed** (free tier with Cloudflare) → CDN-level optimizations
- **Nitropack** (35-175 USD/mois) → WordPress speed automation
- **Vercel Speed Insights** (free for Vercel projects)
- Manual: Lighthouse + manual fixes guided by its recommendations

### Security headers (CSP, HSTS, X-Frame-Options, Referrer-Policy)

- **securityheaders.com** (free audit)
- **Cloudflare Page Rules** → header injection
- **Vercel `next.config.js` headers** → declarative
- **`.htaccess`** → Apache hosts
- Manual: one-time config, ~1-2h setup

## Social presence actions

### Create / maintain social profiles (Facebook, Instagram, LinkedIn, TikTok, YouTube)

- **Buffer** (6-120 USD/mois) → multi-platform scheduling
- **Hootsuite** (99-249 USD/mois) → full social suite
- **Later** (16-80 USD/mois) → visual content scheduling
- **Metricool** (18-50 USD/mois) → analytics + scheduling
- Manual: 30-60 min/semaine for basic maintenance

### Monitor brand mentions on social / forums / Reddit

- **Brand24** (99-299 USD/mois)
- **Mention** (41-149 USD/mois)
- **Google Alerts** (free, basic)
- **Reddit search + saved queries** — free, manual
- **BuzzSumo** (199+ USD/mois) → trend + mention discovery

## Legal compliance actions (FR)

### Install cookie consent management (CMP)

- **Axeptia / Axeptio** (free to 100 EUR/mois) → French-focused CMP
- **Cookiebot** (11-96 USD/mois) → international CMP, CNIL-compliant
- **OneTrust** (enterprise) → enterprise compliance
- **tarteaucitron.js** (free, open source) → CNIL-compliant, self-hosted
- **Didomi** (enterprise) → strong French legal context

### Generate legal pages (mentions légales, politique de confidentialité, CGV)

- **Legalstart / Captain Contrat** (one-time 50-200 EUR) → FR templates
- **Genius Legal** → template generators
- **Legalbuddy** → questionnaire-driven legal pages
- Agent fallback: Batch B in `seo-analyzer` creates templates with
  `[À COMPLÉTER]` placeholders for SIREN, capital, etc.

## Reporting format in SEO.md §11

Example entry generated by the agents:

```markdown
### Créer / réclamer la fiche Google Business Profile

**Action:** Vérifier que la fiche GMB existe, est réclamée, et les
informations sont cohérentes avec le site (NAP).

**Lien direct:** https://business.google.com

**Automatisation possible avec:**
- Google Business Profile API (gratuit, technique)
- BrightLocal (30-80 USD/mois, gestion + rank tracking)
- Yext (500+ EUR/mois, multi-directories)
- LocalFalcon (30-60 USD/mois, rank visualisation)

**Effort manuel:** 30 min initial + 30 min/semaine maintenance
**Impact SEO local:** critique (base du SEO local)
```

## Maintenance of this catalog

Tool landscape shifts fast. Cross-check quarterly:
- Have tool URLs changed?
- Has pricing moved tier?
- Have new tools emerged (especially in AI visibility monitoring)?
- Are deprecated tools still listed?

Use WebSearch on FULL audits to validate before emitting in SEO.md.
