# AI crawlers — 2026 reference

State as of 2026-04. Cross-check via WebSearch on FULL audits — new
bots and renames ship monthly.

## The two categories that matter

The blanket "block AI" strategy of 2024 is obsolete. Bots now split
into two roles, and treating them the same loses traffic.

### Training bots — scrape content to train future models
No direct user traffic. No citation back. Content vanishes into weights.

| User-agent | Company | Notes |
|---|---|---|
| `GPTBot` | OpenAI | Training for GPT models |
| `Google-Extended` | Google | Opt-out for Gemini training |
| `CCBot` | Common Crawl | Feeds many LLMs (open dataset) |
| `anthropic-ai` | Anthropic | Legacy training bot (being phased out) |
| `ClaudeBot` | Anthropic | Current training bot |
| `Bytespider` | ByteDance / TikTok | Aggressive scraper, frequent complaints |
| `Meta-ExternalAgent` | Meta | Training for Llama family |
| `Meta-ExternalFetcher` | Meta | Per-request fetch |
| `Applebot-Extended` | Apple | Opt-out for Apple Intelligence training |
| `Amazonbot` | Amazon | Alexa + internal LLMs |
| `cohere-ai` | Cohere | Training |
| `Diffbot` | Diffbot | Knowledge Graph construction |
| `omgilibot` | Webz.io | Data resale |
| `img2dataset` | Various | Image dataset builders |
| `Timpibot` | Timpi | Search-index + training hybrid |

### Search / retrieval bots — fetch content to cite in live answers
User asked a question → bot fetches → cites your URL → traffic returns.

| User-agent | Company | Notes |
|---|---|---|
| `OAI-SearchBot` | OpenAI | Powers ChatGPT Search |
| `ChatGPT-User` | OpenAI | On-demand fetch when user asks ChatGPT about a URL |
| `Claude-SearchBot` | Anthropic | Powers Claude web search |
| `Claude-User` | Anthropic | On-demand fetch inside Claude |
| `Claude-Web` | Anthropic | Legacy retrieval bot |
| `PerplexityBot` | Perplexity | Index builder |
| `Perplexity-User` | Perplexity | On-demand fetch |
| `GoogleOther` | Google | Various Google retrieval use cases |
| `FacebookBot` | Meta | Meta AI search |
| `DuckAssistBot` | DuckDuckGo | DuckAssist answers |
| `YouBot` | You.com | You.com retrieval |
| `MistralAI-User` | Mistral | On-demand fetch |

## Recommended default strategy — PERMISSIVE

Rationale: the user's stated goal is to maximise AI visibility. The
future-of-search brief favours being cited over being protected.

```
# robots.txt — PERMISSIVE default (allow everything, block problem bots)

# --- Training bots: allow (contributes to brand visibility long-term) ---
User-agent: GPTBot
Allow: /

User-agent: Google-Extended
Allow: /

User-agent: ClaudeBot
Allow: /

User-agent: Applebot-Extended
Allow: /

User-agent: Meta-ExternalAgent
Allow: /

User-agent: CCBot
Allow: /

# --- Search / retrieval bots: always allow (direct traffic) ---
User-agent: OAI-SearchBot
Allow: /

User-agent: ChatGPT-User
Allow: /

User-agent: Claude-SearchBot
Allow: /

User-agent: Claude-User
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: Perplexity-User
Allow: /

# --- Block only known-abusive bots (aggressive scraping, no return value) ---
User-agent: Bytespider
Disallow: /

User-agent: omgilibot
Disallow: /

User-agent: img2dataset
Disallow: /

# --- Default: allow the rest ---
User-agent: *
Allow: /

Sitemap: https://example.com/sitemap.xml
```

## Alternative — RESTRICTIVE (for premium content, paywalled, regulated)

```
# robots.txt — RESTRICTIVE (block training, allow retrieval)

# Block all training bots
User-agent: GPTBot
Disallow: /

User-agent: Google-Extended
Disallow: /

User-agent: ClaudeBot
Disallow: /

User-agent: anthropic-ai
Disallow: /

User-agent: CCBot
Disallow: /

User-agent: Bytespider
Disallow: /

User-agent: Meta-ExternalAgent
Disallow: /

User-agent: Applebot-Extended
Disallow: /

User-agent: Amazonbot
Disallow: /

User-agent: cohere-ai
Disallow: /

User-agent: Diffbot
Disallow: /

User-agent: Timpibot
Disallow: /

# Allow search/retrieval (keeps citations flowing)
User-agent: OAI-SearchBot
Allow: /

User-agent: ChatGPT-User
Allow: /

User-agent: Claude-SearchBot
Allow: /

User-agent: Claude-User
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: Perplexity-User
Allow: /

User-agent: *
Allow: /

Sitemap: https://example.com/sitemap.xml
```

## Common mistakes

- **Only blocking `ClaudeBot`** — does not block `Claude-SearchBot` or `Claude-User`. Same for other families.
- **Using `GPTBot` to block ChatGPT Search** — wrong. `OAI-SearchBot` and `ChatGPT-User` are the search bots.
- **Blocking `CCBot`** — has knock-on effects across dozens of downstream LLMs that train on Common Crawl.
- **Using wildcards** (e.g. `User-agent: *AI*`) — robots.txt wildcards are not universally supported.
- **Relying on meta robots** — `<meta name="robots">` is less respected than robots.txt by AI crawlers. Use both.

## Verification

Each bot should return 200 for allowed, 403 for blocked, via simulated requests:

```bash
DOMAIN="example.com"
for UA in "GPTBot" "ClaudeBot" "PerplexityBot" "OAI-SearchBot" "ChatGPT-User" "Google-Extended"; do
  CODE=$(curl -sI -A "$UA" -o /dev/null -w "%{http_code}" "https://$DOMAIN/")
  echo "$UA: $CODE"
done
```

This hits the page, not robots.txt directly — but if the origin respects
robots.txt via CDN/WAF rules, you'll see the difference.

## Sources to refresh this doc

- https://platform.openai.com/docs/bots
- https://darkvisitors.com/agents (community-maintained)
- https://github.com/ai-robots-txt/ai.robots.txt
- Anthropic docs: https://docs.anthropic.com/
- Cloudflare AI crawlers dashboard (if account available)
