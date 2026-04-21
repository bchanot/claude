# llms.txt / llms-full.txt — template and strategy

## Status as of 2026-04

**Honest assessment**: llms.txt is a proposed standard by Jeremy Howard
(Answer.AI, Sept 2024). No major AI crawler has publicly confirmed they
extract content via `/llms.txt`. A Search Engine Land study (2025) found
8 of 9 sites saw no measurable traffic change after adoption.

**Why include it anyway**:
- Low cost (small static file).
- Real value for developer-facing sites — AI coding assistants (Cursor,
  Continue, Claude Code, GitHub Copilot Chat) DO read it for doc retrieval.
- Signals intent to AI ecosystem. Early mover advantage if adoption grows.
- Reduces RAG token consumption when third parties ingest your content.

**Do not promise ranking gains.** Frame as "no-regret hedge", not "quick win".

## Where it goes

- `/llms.txt` — root of domain. Index of your content in markdown.
- `/llms-full.txt` — root of domain. Full text of your most important pages
  concatenated. Optional but recommended for docs/blog/knowledge base.

Both MUST be reachable over HTTPS, content-type `text/plain` or
`text/markdown`, and NOT blocked in robots.txt.

## Canonical structure

```markdown
# <Site or Project Name>

> <One-sentence elevator pitch. This is the single line AI systems extract
> as your site summary. Be concrete. Include entity + category + differentiator.>

<Optional free-form paragraph providing more context. Keep under 400 chars.>

## Docs

- [Getting started](https://example.com/docs/getting-started): What it does, how to install.
- [API reference](https://example.com/docs/api): All endpoints with examples.
- [Tutorials](https://example.com/docs/tutorials): Step-by-step walkthroughs.

## Examples

- [Quickstart example](https://example.com/examples/quickstart.md): Minimal working demo.

## Optional

- [Changelog](https://example.com/changelog.md): Version history.
- [Blog](https://example.com/blog/index.md): In-depth articles.
```

## Structure rules (Jeremy Howard spec)

1. First line: `# <Name>` (H1 with project/site name).
2. Second non-comment line: `> summary` (blockquote, one sentence).
3. Optional paragraphs of free-form context after the blockquote.
4. H2 sections grouping links: `## Docs`, `## Examples`, `## Optional`, etc.
5. Each link: `[Title](URL): description.` — description under 120 chars.
6. Any link pointing to a `.md` version of the page is preferred.
7. Total file: target under 8 KB. If larger, split into `llms-full.txt`.

## llms-full.txt

Concatenation of the full text (stripped of nav/footer/ads) of your most
important pages. Separator between pages:

```
---
URL: https://example.com/docs/getting-started
Title: Getting Started
---
<full markdown content of that page>

---
URL: https://example.com/docs/api
Title: API Reference
---
<full markdown content of that page>
```

Target under 500 KB. If your corpus is larger, trim to highest-value pages
(most-linked, most-traffic, most-updated).

## Generation patterns

### Static sites (Astro, Hugo, Jekyll, 11ty, Next.js SSG)

Best practice: generate both files at build time from the same source as
your regular pages. Examples:

**Astro**: add a `src/pages/llms.txt.ts` endpoint:
```typescript
import { getCollection } from 'astro:content';

export async function GET() {
  const docs = await getCollection('docs');
  const body = [
    '# My Project',
    '',
    '> One-sentence pitch.',
    '',
    '## Docs',
    ...docs.map(d => `- [${d.data.title}](https://example.com/docs/${d.slug}): ${d.data.description}`),
  ].join('\n');
  return new Response(body, { headers: { 'Content-Type': 'text/plain' } });
}
```

**Next.js App Router**: `app/llms.txt/route.ts`:
```typescript
export async function GET() {
  // similar — pull from your CMS/MDX/db
  return new Response(body, { headers: { 'Content-Type': 'text/plain' } });
}
```

**Hugo**: custom output format `llms` → `llms.txt` template in layouts.

### CMS (WordPress, Drupal, Ghost)

Use a plugin OR a cron job that regenerates files weekly. Flag stale
files (older than site content) in audits.

### Static HTML / PHP

Hand-maintained file. Flag in audits if older than 90 days.

## Automation tools (for SEO.md §11 "automatisation possible")

- **`llms-txt-action`** (GitHub Action) — generates on each deploy
- **Mintlify** — auto-generates for Mintlify-hosted docs
- **Fern** — auto-generates for Fern-generated API docs
- **`llmstxt-hub`** — community directory of examples
- Custom script + cron — works for any static content source

## What NOT to put in llms.txt

- Login walls / private content
- Pricing tables (change frequently → stale risk)
- Testimonials (authenticity risk if AI quotes them)
- Marketing fluff without factual anchors

## Validation checklist

- [ ] File reachable at `/llms.txt` over HTTPS
- [ ] Content-type `text/plain` or `text/markdown`
- [ ] H1 + blockquote present as first two non-comment lines
- [ ] All linked URLs resolve (200)
- [ ] No broken markdown (valid CommonMark)
- [ ] Mentioned in `/sitemap.xml`? Optional, debated
- [ ] NOT blocked in `/robots.txt`
