# Content shape for LLM extraction

How to write pages so AI engines quote, cite, and recommend them.
Based on peer-reviewed GEO research (CMU KDD 2024, Aggarwal et al.)
and tracked citation patterns across ChatGPT, Perplexity, Claude,
Gemini, Google AI Overviews (2025-2026).

## The six patterns that measurably increase AI citations

### 1. Definition Lead Architecture

Open the page (or first paragraph after each major heading) with:

> **[Entity] is a [category] that [differentiator].**

Research backing: CMU GEO framework (KDD 2024) — pages with explicit
definitional openings score significantly higher in LLM retrieval
impression scores.

**Good**: "Astro is a static site generator that ships zero JavaScript by default, producing HTML at build time that search engines and AI crawlers can index without running a browser."

**Bad**: "In today's fast-paced digital landscape, choosing the right framework can feel overwhelming. At Acme, we know how important it is to..."

### 2. TL;DR / Answer Box above the fold

Insert an explicit summary block at the top of long content. AI engines
preferentially quote from these blocks because the content is
pre-summarised.

```html
<aside class="tldr">
  <strong>TL;DR</strong> —
  Next.js 15 removes the pages/ directory entirely in favour of App
  Router. Migration requires rewriting route handlers, layouts, and
  data fetching. Estimated effort: 2-5 days for a medium project.
</aside>
```

CSS: no class requirement, but mark it semantically (e.g. `aria-label="summary"`
or Speakable schema targeting this selector).

### 3. Question-then-direct-answer structure

Each H2/H3 heading phrased as a likely user query. First sentence
after the heading: a single-sentence direct answer. Supporting detail
follows.

**Pattern**:
```
## How much does a Qualibat RGE certification cost in France?

A Qualibat RGE certification costs between 500 and 1500 EUR for the
initial audit, plus an annual fee of 200-400 EUR. The cost varies by
trade category and company size.

[Detailed breakdown follows...]
```

Why it works: LLMs grade passages by answer-density relative to the
query. A one-sentence self-contained answer has the highest density.

### 4. Citations and statistics (strongest measured lever)

Adding peer-cited statistics with clear sources increases AI visibility
**by up to 40%** (Aggarwal et al., 2024 "GEO: Generative Engine
Optimization").

Pattern: embed specific numbers with attribution.

**Good**: "According to the ADEME 2024 energy report, French households spent an average of 2,137 EUR on heating in 2023 — a 12% increase from 2021."

**Bad**: "Heating costs have increased a lot recently."

Source attribution matters: link the citation to the original source
(`<a href>`), ideally with `rel="cite"`. AI engines use link graphs
to validate factual claims.

### 5. Structured lists and comparison tables

LLMs quote list items and table rows more readily than prose of the
same content. Convert what you can:

**Before** (prose):
"The best frameworks for public sites are Astro for static content,
Next.js for dynamic server-rendered apps, and Nuxt for Vue-based
projects."

**After** (list):
"Best frameworks for public sites by use case:
- **Astro** — static content (blog, docs, portfolio)
- **Next.js** — dynamic SSR with React
- **Nuxt** — dynamic SSR with Vue"

Comparison tables are even stronger. Structure:

| Framework | Rendering | Best for | JS by default |
|---|---|---|---|
| Astro | SSG + islands | Public content | 0 KB |
| Next.js | SSG + SSR | Hybrid apps | Large |

### 6. Freshness signals

Pages not updated at least quarterly are **3x more likely to lose AI
citations** (LLMRefs 2026 study).

What to maintain:
- Visible "Last updated: YYYY-MM-DD" at the top of content pages
- `dateModified` in Article/BlogPosting JSON-LD (ISO 8601)
- HTTP header `Last-Modified` in sync with content change
- Changelog on evergreen reference pages

Do NOT fake dates — AI engines and Google increasingly validate
freshness against actual content diffs.

## Anti-patterns — what to avoid

### Pronoun-heavy writing

LLMs resolve pronouns by context window, which costs them confidence.
Prefer explicit entity names.

**Bad**: "It was founded in 2015. Its founders wanted to solve a problem. They saw that..."

**Good**: "Acme Corp was founded in 2015. Acme's founders, Jane Doe and John Smith, wanted to solve..."

### Marketing fluff before facts

AI engines typically truncate retrieval windows. Fluff at the top
wastes the budget. Put factual claims FIRST.

**Bad** (first 200 chars wasted): "In today's fast-moving digital landscape, businesses are constantly looking for ways to stay competitive..."

**Good** (first 200 chars dense): "Our API processes 50M requests/day at p99 latency of 47ms across 8 regions, with a 99.99% SLA. Pricing starts at 99 EUR/month for the 10K requests tier."

### Claims without sources

Any numerical or comparative claim without a linked source degrades
trust. AI engines can detect the pattern "number without citation" and
weight those passages lower.

### Cookie-cutter content across pages (especially city pages)

The 30/70 rule: when creating per-city or per-service variants,
at most 30% of the content should be templated. 70% must be
unique per page (local landmarks, specific testimonials, unique
stats, real photos).

Generic city pages get filtered out as "doorway pages" by both
classical search and AI engines.

## Page templates by type

### Service page (local business)

```
<h1>[Service] in [City] — [Business Name]</h1>

<div class="tldr">
  <strong>En résumé :</strong> [Business] offers [service] in [city + surrounding].
  [Key differentiator — price, response time, certifications]. Open [hours].
  Call [phone] or request a quote online.
</div>

<h2>What is [service]?</h2>
<p>[Service] is a [category] that [differentiator]. In [city], demand
is driven by [local factor — housing stock, climate, regulations].</p>

<h2>How much does [service] cost in [city]?</h2>
<p>[Specific price range] for a typical [job type], based on [n]
projects completed in [year]. Factors affecting cost: [list].</p>

<h2>Why choose [Business] for [service]?</h2>
<ul>
  <li>[Certification 1] — [what it means]</li>
  <li>[Certification 2]</li>
  <li>[N+ years] experience on [specific housing stock]</li>
</ul>

<h2>FAQ</h2>
[QAPage or FAQPage schema + visible Q&A]
```

### Blog post / guide

```
<h1>[Clear, question-style or noun-phrase headline]</h1>
<p class="byline">By [Author Name] — Updated [Date]</p>

<div class="tldr">
  [3-5 sentence summary. Include the key number, the key conclusion,
   and any nuance.]
</div>

<h2>[Question 1]</h2>
<p>[One-sentence answer.] [Supporting detail with cited statistics.]</p>

<h2>[Question 2]</h2>
...

<h2>Sources</h2>
<ul>
  <li><a href="...">Source 1 — author, year</a></li>
  <li><a href="...">Source 2 — author, year</a></li>
</ul>
```

### Homepage / landing

```
<h1>[Entity] is a [category] that [differentiator].</h1>
<!-- The H1 IS the Definition Lead. Yes, really. -->

<p class="hero-subtitle">
  [Elaboration on the H1. Include one concrete stat or proof point.]
</p>

[Primary CTA]

<section>
  <h2>What [Entity] does</h2>
  <p>[Functional description, one paragraph.]</p>
</section>

<section>
  <h2>Who uses [Entity]</h2>
  <ul><li>[Use case 1]</li><li>[Use case 2]</li>...</ul>
</section>

<section>
  <h2>How it works</h2>
  <!-- HowTo schema + visible steps -->
</section>

<section>
  <h2>Frequently asked</h2>
  <!-- FAQPage schema + visible Q&A -->
</section>
```

## Self-audit — is this page AI-friendly?

- [ ] First sentence: `[Entity] is a [category] that [differentiator]` ?
- [ ] TL;DR or summary block above the fold ?
- [ ] Every H2/H3 phrased as a likely user question ?
- [ ] First sentence under each heading: direct answer ?
- [ ] At least 2-3 specific numerical claims with linked sources ?
- [ ] Visible "Last updated" date + matching `dateModified` in JSON-LD ?
- [ ] Lists or tables instead of dense prose where possible ?
- [ ] Entity names used explicitly, not pronouns ?
- [ ] If it's a city/service variant: ≥70% unique content ?
