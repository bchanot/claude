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
crawler lists and tool names via WebSearch on each run when FULL depth is
selected.

## Citation standard (mandatory for every statistic)

**WebSearch is NOT verification for a number.** It ranks SEO blogs, and SEO
blogs cross-cite each other into a consensus that looks like corroboration.
Two 2026-07-16 audits of this directory show how it fails:

- A "VSI (Visual Stability Index) — new 2026 Core Web Vital" lived in
  `seo-analyzer.md`. Ten blogs asserted it; several claimed CrUX already
  collected it. It is absent from the CrUX API metric list and from
  web.dev. WebSearch returned the echo, not the truth.
- Every stat in this directory was real **and attached to the wrong
  subject**: the GEO paper's 40% (all methods) pinned on one technique;
  LLMrefs' 3x (brand mentions vs backlinks) pinned on freshness decay;
  AccuraCast's 58.9% (Person schema prevalence) pinned on QAPage lift, with
  its meaning inverted; a smart-speaker adoption figure sold as voice-search
  share.

The failure mode is not invention — it is **plausible recombination**, which
is exactly what a model half-remembering a search result produces. So the
format has to make an unsourced number conspicuous:

```
<claim> — <source, year, venue|vendor> — measured: <what the source ACTUALLY
measured> — <link>
```

`measured:` is the field that catches it. All four errors above survive a
source name; none survives having to state the source's real measurement
next to the claim.

Rules:
1. **Primary source or no number.** Peer-reviewed paper, the vendor's own
   published study, or an official API/doc. `developer.chrome.com/docs/crux`
   is decisive for metrics: what CrUX cannot return, we cannot score.
2. **Name the tier.** Peer review ≠ vendor marketing. LLMrefs, AccuraCast,
   Ahrefs publish useful data and sell products — say "vendor".
3. **Never widen scope.** An aggregate result is not a per-technique result.
4. **No number beats a wrong number.** A recommendation that only stands up
   with a fabricated statistic was never standing up. Delete the stat, keep
   the recommendation if it survives on mechanism.
5. **Unverified ⇒ labelled.** `[UNVERIFIED — <date>]` inline. Never quote an
   unverified number to a client: `geo-analyzer.md` ("Cite sources") sends
   these into client reports as research-backed.

## Loading pattern

Agents reference resources like this:

```
Load: ~/.claude/agents/resources/ai-crawlers-2026.md
```

Do not inline these contents into agent prompts — read them at step time.
