---
name: geo
description: |
  Use when a web project needs AI-search visibility audit — ChatGPT,
  Perplexity, Gemini, AI Overviews, Copilot… Standalone GEO; dispatches
  the geo-analyzer agent.
  Triggers: "geo", "AI search", "llms.txt", "AI crawlers", "entity SEO",
  "Wikidata", "generative engine optimization", "référencement IA".
  Combined SEO+GEO → /seo.
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

If `.claude/audits/SEO.md` already exists, the geo-analyzer will
merge its findings into that file's `§7 — Optimisation GEO / IA`
section (rather than writing a separate `GEO.md`). This keeps a
single consolidated report when both /seo and /geo have been run.

If no `.claude/audits/SEO.md` exists, the agent writes `.claude/audits/GEO.md` (run `mkdir -p .claude/audits` first).
