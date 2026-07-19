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

## MODEL GATE (blocking — run before any other step)

Run `$HOME/.claude/lib/model-gate.md`. Reflection here (planning, audit
judgment, loop decisions) requires Fable/Opus. Verdict `small` → STOP: the
gate prints the remedy; end the turn — no later step, no dispatch. Nominal
(big) path is silent.

Dispatches the `geo-analyzer` subagent (audit + fix bundle), then applies
the bundle from THIS main loop at **L1** — same shape as `/web-validate`
and `/seo`. The analyzer never edits files: it emits a `## FIX BUNDLE`
terminated by `READY TO APPLY — awaiting dispatcher confirmation`, and this
skill applies it. Applying from here (one dispatch level, no nested spawn)
is what makes fixes land on any Claude Code version.

## STEP 1 — Run the geo pipeline (collect → judge → template, BDR-077)

Gather depth + business context HERE first (ask the user in this loop if
needed — a dispatched agent cannot ask). Mint `RUNID=$(date +%s)-geo`.
Pass the same CONTEXT block ($ARGUMENTS + gathered context) VERBATIM to
every phase (LRN-126). Clean `.audit/geo-signals-<RUNID>.md` after apply.

**A — collect (sonnet):**
```
Agent(subagent_type="geo-analyzer", model="sonnet")
prompt: "MODE: collect
RUNID: <RUNID>
Dispatched from /geo. Context: <CONTEXT>
Execute STEP 0-5 per your spec, write the signals file + COLLECTION
COMPLETE sentinel, emit the COLLECT REPORT, stop."
```

**B — judge (opus pin, no override):**
```
Agent(subagent_type="geo-analyzer")
prompt: "MODE: judge
RUNID: <RUNID>
Context: <CONTEXT>
Load .audit/geo-signals-<RUNID>.md (fail closed per your spec), run STEP
6-12, report scoring + findings + action plan + triage batches."
```
**ERROR CONTRACT:** `GEO JUDGE — VERDICT: ERROR(…)` or a mute judge →
STOP: no template, no apply. Surface verbatim, retry ONCE with a fresh
collect+judge, then escalate. Never carry a mute/ERROR judge into
templating.

**C — template (sonnet):**
```
Agent(subagent_type="geo-analyzer", model="sonnet")
prompt: "MODE: template
Context: <CONTEXT>
JUDGE REPORT (verbatim, ground truth — never re-derive a score):
<the judge report>
Run STEP 13-15. Produce your report: if .claude/audits/SEO.md already
exists → merge findings into its §7 — Optimisation GEO / IA; else write
.claude/audits/GEO.md. Then emit the `## FIX BUNDLE` terminated by the
verbatim `READY TO APPLY — awaiting dispatcher confirmation` sentinel.
Do NOT apply any fix and do NOT dispatch any sub-agent — /geo applies
your bundle."
```

## STEP 1b — CHALLENGE THE FIX BUNDLE (advisory, before apply)
The analyzer returned a `## FIX BUNDLE` — worth attacking before any edit lands.
**Skip if intervention mode = conservative** (nothing is applied). Else persist the
bundle verbatim to `.claude/tasks/plans/<date>-<slug>-<HHMM>.md`, then run
`$HOME/.claude/lib/challenge-plan.md` with `PLAN` = that file, `KIND` = `fix-bundle`,
`SCOPE` = the target site files the items touch, `CONSTRAINTS` = the geo-analyzer
file-ownership (robots.txt, llms.txt, JSON-LD, content shape) + the shared-file edit
discipline each item carries + intervention mode. Three blind challengers ask, per item:
will it ACHIEVE its goal / could it BREAK or regress the page / is a simpler (or no) fix
better. This main loop RE-THINKS every aspect a BLOCKER lands (a named bundle change, or
`[deferred <date>]`) and re-challenges once if the bundle materially changed. Advisory —
it sits BEFORE (never replaces) the STEP 2 GATED approval; carry its CHALLENGE SUMMARY
into that gate.

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

CHALLENGE SUMMARY (STEP 1b — 3 lenses):
  BLOCKERs addressed : <n> — <finding → the named bundle change that closes it>
  Deferred (human-ack): <list | none>
  Lenses returned    : correctness / robustness / simplicity (NAME any that failed to return)
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
