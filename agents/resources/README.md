# SEO/GEO shared resources

Knowledge base shared by `seo-analyzer` and `geo-analyzer` agents.
Loaded on demand — keep each file focused and current.

| File | Owner agents | Topic |
|---|---|---|
| `ai-crawlers-2026.md` | seo + geo | User-agent strings, categories (training vs search), robots.txt strategy |
| `llms-txt-template.md` | geo | `/llms.txt` + `/llms-full.txt` structure, generation patterns |
| `geo-schemas.md` | geo | Schema.org types for AI extraction (QAPage, Speakable, Person, Article) + deprecated list |
| `entity-seo.md` | geo | Wikidata QID, sameAs network, Knowledge Graph wiring |
| `content-shape-for-ai.md` | geo | Definition Lead, TL;DR, Q→A, stats, citations — content patterns LLMs cite |
| `ai-visibility-tools.md` | geo | Monitoring tools (OtterlyAI, Peec, Trendos, ZipTie, HubSpot AEO, SE Ranking) |
| `automation-catalog.md` | seo + geo | For every user-action in SEO.md §11 — what tool can automate it |

## Update policy

These files capture state as of 2026-04. Crawler lists, Schema.org
deprecations, and tool landscape shift fast. Agents MUST cross-check
via WebSearch on each run when FULL depth is selected.

## Loading pattern

Agents reference resources like this:

```
Load: ~/.claude/agents/resources/ai-crawlers-2026.md
```

Do not inline these contents into agent prompts — read them at step time.
