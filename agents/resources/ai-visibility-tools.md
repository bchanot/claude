# AI visibility monitoring tools — 2026

Tools that track whether your brand appears in AI-generated answers
across ChatGPT, Perplexity, Gemini, Copilot, Claude, and Google AI
Overviews.

Context: Google AI Overviews trigger on ~48% of searches; ChatGPT
processes 2.5B queries/day; Gartner projects commercial organic
search traffic will drop 25% by 2026. Monitoring is no longer optional.

## Commercial tools

| Tool | Platforms covered | Strong points | Weak points |
|---|---|---|---|
| **OtterlyAI** (otterly.ai) | ChatGPT, Perplexity, Gemini, AI Overviews, Copilot | Mature, 20k+ users, Gartner-recognised | Pricing mid-to-high |
| **Peec AI** (peec.ai) | ChatGPT, Perplexity, Gemini, AI Overviews | Good SaaS-brand focus, sentiment analysis | Narrower platform scope |
| **Profound** (tryprofound.com) | ChatGPT, Perplexity, Gemini, Copilot | Enterprise-grade, full-response capture | Enterprise pricing |
| **ZipTie** (ziptie.dev) | ChatGPT, Perplexity, AI Overviews | Competitive benchmarking, source attribution | Smaller team, newer |
| **HubSpot AEO** (hubspot.com/products/aeo) | ChatGPT, Gemini, Perplexity | Integrates with HubSpot ecosystem | Best if already HubSpot user |
| **Trendos** (trendos by Tesonet) | ChatGPT, Gemini, AI Search, Perplexity, DeepSeek | Added DeepSeek coverage, 2026 launch | Unproven longevity |
| **SE Ranking AI Tracker** (seranking.com) | ChatGPT, Perplexity, Gemini, AI Mode, AI Overviews | Bundled with classical SEO suite | Less specialised |
| **LLMrefs** (llmrefs.com) | ChatGPT, Perplexity, Gemini, Claude | GEO focus, research-backed | Newer, less tested |

## Free / manual methods (zero budget)

For clients/projects with no monitoring budget, a manual process works
at lower frequency. Recommended cadence: monthly for established
brands, weekly during optimization sprints.

### Query list construction

Build a list of 20-40 queries covering:

1. **Branded queries** — "what is [brand]", "is [brand] good", "[brand] reviews"
2. **Generic category queries** — "best [category] in [location]", "how to [problem]"
3. **Comparison queries** — "[brand] vs [competitor]", "alternatives to [brand]"
4. **Problem queries** — the actual questions the target persona asks

### Manual check workflow

For each query, run across:

- **ChatGPT** (web version with search enabled, chatgpt.com)
- **Perplexity** (perplexity.ai)
- **Google AI Overviews** (google.com — appears for ~48% of searches)
- **Claude** (claude.ai with web search)
- **Gemini** (gemini.google.com)
- **Copilot** (copilot.microsoft.com)
- **Brave Search AI** (search.brave.com)
- **DuckAssist** (duckduckgo.com)

Record for each:
- Mentioned? (yes/no)
- Cited with link? (yes/no + which page)
- Position in answer? (1st mention / buried / listed)
- Sentiment? (positive / neutral / negative / misleading)

### Spreadsheet template

| Date | Query | ChatGPT | Perplexity | Google AIO | Claude | Gemini | Copilot |
|---|---|---|---|---|---|---|---|
| 2026-04-21 | best plombier Évry | Mentioned, ranked 3, cited | Not mentioned | Top 3, no cite | — | — | — |

## KPIs to track

From GEO research and industry consensus (GenOptima, HubSpot 2026):

| Metric | Definition | Benchmark |
|---|---|---|
| **Mention Rate** | % of AI answers that mention brand name | Varies; track trend, not absolute |
| **Citation Rate** | % of AI answers with a clickable link to domain | Target 20%+ for established brands |
| **Position** | When cited, is brand 1st mention vs buried? | First mention = best |
| **Sentiment** | Tone of brand mention (positive/neutral/negative) | Track for negative drift |
| **Source Diversity** | Which of your pages get cited? | Aim for 5+ distinct pages/domain |
| **Competitor Share** | % of category queries where competitor cited vs brand | Track gap |

## Integration into SEO.md

In `SEO.md §11 — Actions utilisateur requises`:

> ### Monitor AI visibility monthly
>
> **Automatisation possible avec:** OtterlyAI, Peec AI, ZipTie, HubSpot
> AEO, SE Ranking AI Tracker. Budget: 50-500 EUR/mois selon le tool.
>
> **Alternative manuelle gratuite:** template spreadsheet + 20 queries
> testées mensuellement sur ChatGPT, Perplexity, Google AI Overviews.
> Temps: ~1h/mois.

## Methodology caveats

- AI engines are **non-deterministic**. Same query twice can return
  different answers. Always take 3 samples and track the median.
- **Personalisation** affects results. Test in logged-out / private
  mode for reproducibility.
- **Geographic bias** — ChatGPT's answers about local businesses vary
  by IP. Test from the target market's geography.
- **Freshness lag** — content updates take days to weeks to propagate
  into AI answers. Don't expect instant reflection of changes.
