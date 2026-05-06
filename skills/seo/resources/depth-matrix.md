# SEO + GEO depth-decision matrix

Use this table during STEP 0 when the user has not already specified depth.

| Signal in `$ARGUMENTS` or environment | Depth | Why |
|---|---|---|
| `local`, `code-only`, `quick`, `rapide`, `pre-deploy` | LOCAL | No live URL needed; fast feedback in CI or local dev. |
| `full`, `complet`, `externe`, `live`, `production`, includes `https://...` URL | FULL | Live verification + Core Web Vitals + AI visibility require external calls. |
| Local-business signals (NAP detected: phone, address, opening hours, GMB) | FULL recommended (warn if LOCAL chosen) | NAP audit requires reading the live site + cross-checking directories. |
| User asks "ranking", "GMB", "fiche Google", "Knowledge Panel" | FULL | These are live-only signals. |
| Repository has `<lang>.html`/`hreflang` but no production URL provided | LOCAL with note | Cannot validate hreflang resolution without live URL — flag as user action. |
| `--no-external` flag set | LOCAL forced | Honour explicit override even if FULL signals present. |

# Score-weight table (out of /20)

| Axis | LOCAL weight | FULL weight |
|---|---|---|
| Meta + canonical + lang | 3 | 3 |
| JSON-LD / Schema.org | 3 | 3 |
| Sitemap + robots.txt + llms.txt | 3 | 3 |
| Headings + alt + i18n | 3 | 3 |
| Core Web Vitals | 0 | 3 |
| Security + redirects + indexability | 4 | 2 |
| External presence (GMB, citations, Wikidata) | 0 | 3 |
| Content shape (TL;DR, definition lead, citable stats) | 4 | 0 |

LOCAL caps at 20. FULL caps at 20. Never report above 20.

# Dedup rules — overlap with sibling skills

| Finding type | Owner skill | If reported by /seo, what to do |
|---|---|---|
| HTML validity errors (W3C nu validator) | /validate | Drop from /seo report; note `"see /validate report for HTML validity"`. |
| WCAG accessibility | /validate | Drop. |
| Missing CSP / HSTS / 404 page / HTTP→HTTPS | /harden | Drop unless it directly affects indexability (then mention with cross-link). |
| Wikidata / sameAs / Knowledge Panel | /seo (GEO) | Owned here. |
| llms.txt | /seo (GEO) | Owned here. |

# Envelope schema for `.claude/audits/SEO.md`

```
# SEO + GEO Audit — <date>
DEPTH: LOCAL | FULL
SITE: <root path or production URL>
SCORE_CLASSICAL: <n>/20
SCORE_GEO: <n>/20

## §1 Critical alerts
## §2 Score breakdown
## §3 Classical SEO findings (meta, sitemap, JSON-LD, headings, …)
## §4 Local SEO / NAP (only if local-business)
## §5 Core Web Vitals (FULL only)
## §6 Security + indexability cross-refs (link to /harden)
## §7 GEO / AI optimisation
## §8 Fix bundle (auto-applied in aggressive mode)
## §9 User actions (manual)
```
