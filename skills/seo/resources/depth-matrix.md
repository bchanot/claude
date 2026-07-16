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

# Score-weight table

Owned by the agents, not this file — classical SEO weights are in
`agents/seo-analyzer.md` (STEP 9, 7 axes FULL / 4 axes LOCAL, percentage
weights varying by business type); GEO weights are in
`agents/geo-analyzer.md` (STEP 10, 6 axes FULL / 5 axes LOCAL). Combined
score formula (0.80/0.20 classical/GEO local-B2C, 0.75/0.25 SaaS/national) is
in `skills/seo/SKILL.md` (~line 273).

# Dedup rules — overlap with sibling skills

| Finding type | Owner skill | If reported by /seo, what to do |
|---|---|---|
| HTML validity errors (W3C nu validator) | /web-validate | Drop from /seo report; note `"see /web-validate report for HTML validity"`. |
| WCAG accessibility | /web-validate | Drop. |
| Missing CSP / HSTS / 404 page / HTTP→HTTPS | /harden | Drop unless it directly affects indexability (then mention with cross-link). |
| Wikidata / sameAs / Knowledge Panel | /seo (GEO) | Owned here. |
| llms.txt | /seo (GEO) | Owned here. |

# Envelope schema for `.claude/audits/SEO.md`

Owned by `skills/seo/SKILL.md` (~lines 278-352, the real §0-§15 structure),
not this file — both agents' envelopes are keyed to it
(`agents/seo-analyzer.md` STEP 13, `agents/geo-analyzer.md` STEP 14).
