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

# /geo — GEO (AI-search) audit + fix dispatcher

Dispatches the `geo-analyzer` subagent (audit + fix bundle), then applies
the bundle from THIS main loop at **L1** — same shape as `/web-validate`
and `/seo`. The analyzer never edits files: it emits a `## FIX BUNDLE`
terminated by `READY TO APPLY — awaiting dispatcher confirmation`, and this
skill applies it. Applying from here (one dispatch level, no nested spawn)
is what makes fixes land on any Claude Code version.

## STEP 1 — Dispatch geo-analyzer (audit + bundle)

```
Agent(subagent_type="geo-analyzer")
prompt: """
Dispatched from /geo. Execute your full spec at
~/.claude/agents/geo-analyzer.md (STEP 0 onward — gather depth + business
context as needed; if you must ask the user, ask and I relay).

Produce your report:
- If .claude/audits/SEO.md already exists → merge findings into its
  §7 — Optimisation GEO / IA.
- Else write .claude/audits/GEO.md.

Then emit the `## FIX BUNDLE` (STEP 13) terminated by the verbatim
`READY TO APPLY — awaiting dispatcher confirmation` sentinel. Do NOT apply
any fix and do NOT dispatch any sub-agent — /geo applies your bundle.

$ARGUMENTS
"""
```

## STEP 2 — Apply the fix bundle (from THIS main loop, at L1)

The analyzer returned a `## FIX BUNDLE`. Apply it by dispatching
`hotfixer`/`feater` at **L1** (one dispatch level, no nested spawn).

**Skip this step if intervention mode = conservative (audit-only)** — leave
the bundle in the report as ready-to-apply.

**Tier recognition (tolerant of the analyzer's batch labels).** Classify by
intent, not header wording: **AUTO** = no-confirmation items (G1–G4/G6);
**GATED** = items marked NEEDS CONFIRMATION / visible (G5); **USER ACTIONS**
= G7.

### AUTO tier — no confirmation

For each AUTO item, dispatch its `applier` at L1, passing the item verbatim:

```
Agent(subagent_type="hotfixer")     # or "feater" per the item's applier
prompt: "<paste the bundle item: files, concern, current, expected,
  framework note + shared-file discipline>.
  Context: GEO audit fix, autonomous scope — no confirmation needed.
  Do NOT commit — apply and self-verify only."
```

### GATED tier — confirmation required

Present every GATED item (G5.x) in ONE gate:

```
GEO — gated content-shape changes need approval (visible):
  G5.1 <change> — impact: <visible change>
Approve all / select (ids) / skip all?
```

Apply approved items via `feater` at L1. Unapproved → report §9 (medium
term). NEVER apply a GATED item before explicit approval.

### After applying

1. Build/lint if available (`npm run build`, `npm run lint`) — revert any
   applied fix that breaks the build; invalid JSON-LD reverted immediately.
2. Record each applied change in the report change-log section.
3. USER ACTIONS from the bundle → report §11 (each with automation-catalog ref).

### Audit-end deliverables + trajectory (ALWAYS — both modes)

Same contract as /seo:
- The report carries the analyzer's actual AND projected code-only scores
  plus its `TRAJECTORY TO 17/20` block (ranked code fixes to 17, or the
  honest code ceiling + the user actions that unlock the rest) — the
  geo-analyzer spec (STEP 10) makes these mandatory in the envelope.
- Regenerate `.claude/audits/HUMAN-ACTIONS.md` from the user actions
  (checkbox format, one `- [ ]` per action with automation ref + effort)
  right after the report is written, EVEN in conservative mode — an
  audit-only run must leave the user immediately actionable.
- Console summary includes: actual + projected scores, the trajectory
  one-liner, and the HUMAN-ACTIONS.md path.

## Note on integration

If `.claude/audits/SEO.md` already exists, geo-analyzer merges its findings
into that file's `§7 — Optimisation GEO / IA` section rather than writing a
separate `GEO.md`. This keeps a single consolidated report when both /seo
and /geo have been run.
