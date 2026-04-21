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

### Submit to AI indexes directly

- **Bing Webmaster Tools** → submits to Bing + Copilot + ChatGPT Search (which uses Bing index)
- **IndexNow protocol** (indexnow.org) → proactive ping to Bing/Yandex
- **Google Search Console + URL Inspection** → request indexing (no ChatGPT index direct submit exists in 2026)

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

## Technical SEO actions

### Generate sitemaps

- **Framework plugin** — `@astrojs/sitemap`, `next-sitemap`, `@nuxtjs/sitemap`, `rails-sitemap-generator`, etc.
- **Yoast / RankMath** (WordPress) → auto-generate
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
