---
name: geo
description: |
  Standalone GEO (Generative Engine Optimization) audit for AI search
  engines: ChatGPT, Perplexity, Claude, Gemini, Google AI Overviews,
  Microsoft Copilot, Brave AI, DuckAssist, You.com, Apple Intelligence.
  Audits AI crawler directives, llms.txt / llms-full.txt, Schema.org
  types optimised for AI extraction (QAPage, Speakable, Person+Article,
  HowTo, Organization graph), entity SEO (Wikidata, sameAs, @id,
  Knowledge Panel), content shape for LLM extraction (Definition Lead,
  TL;DR, Q→A structure, citable stats, freshness), and live AI
  visibility monitoring.
  For full SEO + GEO combined audit → use /seo (runs seo + geo in parallel).
  For classical SEO only → use /seo and skip the GEO section.
  Trigger: "geo", "AI search", "ChatGPT visibility", "Perplexity optimisation",
  "llms.txt", "AI crawlers", "Google AI Overview", "entity SEO", "Wikidata",
  "generative engine optimization", "référencement IA", "optimisation IA".
argument-hint: optional keywords/scope, e.g. "SaaS B2B content GEO" or "audit llms.txt et entity SEO"
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
  - WebFetch
  - WebSearch
---

Load and follow strictly:
- $HOME/.claude/agents/geo-analyzer.md

Execute the GEO-ANALYZER agent on the following target:

$ARGUMENTS

## Note on integration

If `SEO.md` already exists at project root, the geo-analyzer will
merge its findings into that file's `§7 — Optimisation GEO / IA`
section (rather than writing a separate `GEO.md`). This keeps a
single consolidated report when both /seo and /geo have been run.

If no `SEO.md` exists, the agent writes `GEO.md` at project root.
