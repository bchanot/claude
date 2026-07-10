---
name: seo
description: |
  Use when a web project needs SEO + GEO audit or optimization —
  classical search (Google, Bing) AND AI search (ChatGPT, Perplexity, AI
  Overviews). Parallel orchestrator: dispatches seo-analyzer +
  geo-analyzer concurrently, merges into .claude/audits/SEO.md.
  Triggers: "seo", "referencement", "meta tags", "JSON-LD", "sitemap",
  "robots.txt", "local SEO", "llms.txt", "ChatGPT visibility".
  GEO only → /geo. W3C/a11y → /web-validate. Bugs → /bugfix.
argument-hint: optional keywords/scope, e.g. "local SEO plombier 91 94 77" or "SaaS B2B content strategy"
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

# /seo — parallel SEO + GEO dispatcher

This skill orchestrates TWO specialist agents running in parallel, then
merges their output into a single `.claude/audits/SEO.md` report. It is the main
entry point for any SEO/GEO work on a web project.

## Resources

- `resources/depth-matrix.md` — depth-decision rules (LOCAL vs FULL),
  score-weight table per axis, dedup rules with sibling skills (/web-validate,
  /harden), and the envelope schema for `.claude/audits/SEO.md`.

Read `resources/depth-matrix.md` at the start of STEP 0 — it pre-answers
several questions and keeps token cost down by removing repeated explanations.

## STEP -1 — Account management verbs (intercept BEFORE any audit)

If `$ARGUMENTS` starts with `connect`, `accounts`, or `forget`, run the
matching action below and STOP — no audit, no analyzer dispatch, no report.
Tilde paths mandatory (this skill runs from the audited project's directory,
not the claude-config repo). Anything else falls through to STEP 0 unchanged.

**Label safety rule (both verbs):** a label MUST match
`^[A-Za-z0-9][A-Za-z0-9._-]*$` — anything else (spaces, quotes, `;`, `$`,
backticks…), refuse it and ask for another name; the engine also rejects it
(exit 2). ALWAYS single-quote the label when composing the Bash call
(`--label 'client-a'`) — never paste it unquoted into a command line.

- **`connect [label]`** — connect a Google account (one-time OAuth consent):
  1. No label given → ask for one (a client/site name, not an email).
  2. Run in background: `bash ~/.claude/lib/seo-data/connect.sh --label <label>`
     — the wrapper sources `~/.claude/.env` itself and works from any
     directory (from the claude-config repo, `make seo-connect` also works
     and builds the venv first; use it if the venv doesn't exist yet).
  3. Read the background output for the authorization URL it prints and hand
     that URL to the user — they consent in their browser; the localhost
     callback completes the flow on its own.
  4. On success, report the label + discovered Search Console properties.
     On failure, surface the error verbatim (e.g. missing
     `GOOGLE_OAUTH_CLIENT_ID/SECRET` in `~/.claude/.env`, 403 API disabled).
- **`accounts`** — list connected accounts:
  `bash ~/.claude/lib/seo-data/fetch.sh accounts` → render one line per
  label with its properties; `"accounts": []` → say none connected and
  point at `/seo connect`.
- **`forget <label>`** / **`forget --all`** — remove one account / empty the
  store: `bash ~/.claude/lib/seo-data/fetch.sh forget --label <label>` (or
  `forget --all`). Confirm with the user BEFORE `--all`. ALWAYS append this
  notice to the result: local removal deletes the stored refresh token but
  does NOT revoke the grant at Google — for a real revocation, visit
  https://myaccount.google.com/permissions (account concerned) and remove
  the app's access there.

## STEP 0 — Collect shared context (ONCE)

Before spawning any agent, collect the context both agents need.
This avoids asking the user the same questions twice.

### Audit depth

Ask once:
```
AUDIT DEPTH — choose one:

  LOCAL  — Code-only analysis. No external calls.
           Covers: markup, meta, JSON-LD, sitemap, robots.txt,
           llms.txt, content shape audit, legal, security headers,
           schemas for AI, entity signals (code-observable).

  FULL   — LOCAL + live HTTP audit, Core Web Vitals (PageSpeed API),
           external presence (GMB, social, directories), AI visibility
           testing, competitor analysis, Wikidata / Knowledge Panel check.

Which depth? (LOCAL / FULL)
```

If `$ARGUMENTS` contains `local`/`code-only`/`quick`/`rapide` → default LOCAL.
If `$ARGUMENTS` contains `full`/`complet`/`externe`/`live` → default FULL.
If `$ARGUMENTS` contains a production URL → suggest FULL.

### Compte Google (FULL only)

**Skip if LOCAL** — jump straight to Business context.

For FULL depth, offer to attach a connected Google account so the
seo-analyzer can pull real GSC/CrUX data instead of anonymous PageSpeed
only. List connected accounts (**tilde path mandatory** — this skill
runs from the audited project's directory, not the claude-config repo):

```bash
bash ~/.claude/lib/seo-data/fetch.sh accounts
```

```
COMPTE GOOGLE pour cet audit FULL :

  1. <label> — <property 1>, <property 2>, ...
  2. <label> — <property>
  ...
  [connecter un nouveau compte] — `/seo connect <label>` (ou
    `bash ~/.claude/lib/seo-data/connect.sh --label <label>` depuis
    n'importe quel projet ; `make seo-connect` depuis le repo claude-config
    construit aussi la venv), puis relancer /seo
  [Ignorer] — continuer sans GSC/CrUX (PageSpeed anonyme uniquement,
    dégradation normale — cf. SEO.md §11)

Quel compte / quelle property ? (numéro, ou "ignorer")
```

If `fetch.sh accounts` returns an empty list (`"accounts": []`), skip
the numbered list and show only `[connecter un nouveau compte]` /
`[Ignorer]`.

Record the choice in the shared context block:
```
GSC ACCOUNT: <label> | none
GSC PROPERTY: <property> | none
```

### Business context (one grouped block)

**Both depths:**
1. Activity type (B2C local / B2B national / SaaS / e-commerce / service / content/media)
2. Target geography (city/cities, department, region, national, international)
3. Languages served (for i18n/hreflang)
4. Priority keywords and AI queries
5. Intervention mode: **aggressive** (apply fixes) / **conservative** (audit-only)?

**FULL depth only:**
6. Production URL
7. Google Business Profile URL (or "not yet")
8. Social media URLs
9. Known citations (PagesJaunes, Yelp, sector directories)
10. Known competitors
11. Known Wikidata QID / Knowledge Panel status (or "unknown")
12. Time budget for user actions post-audit

Skip questions already answered in `$ARGUMENTS`.

### Plugin check (FULL only)

For FULL depth, verify `WebFetch` and `WebSearch` are available.
They are declared in this skill's `allowed-tools`, so they should
be. If the harness reports them missing, offer to downgrade to LOCAL
or continue with gaps.

Store the collected context as a single block to pass to both agents.

### File ownership (prevents parallel edit conflicts)

Running two agents in parallel on the same repo is safe for ANALYSIS
(read-only). It would race-condition on fixes if both touched the
same file. This matrix is authoritative — pass it to both agents in
their dispatch prompts:

| File / concern | Owner | Notes |
|---|---|---|
| `robots.txt` | **geo-analyzer** | Classical + AI bot directives consolidated here. seo-analyzer reads only. |
| `sitemap.xml` + image/video sitemaps | **seo-analyzer** | |
| `llms.txt` / `llms-full.txt` | **geo-analyzer** | |
| `.htaccess` (redirects, security headers, 404) | **seo-analyzer** | |
| JSON-LD blocks (all schemas, all pages) | **geo-analyzer** | Owns structure + content. seo-analyzer flags NAP inconsistencies vs GMB, geo-analyzer reconciles. |
| Meta tags (title, description, OG, Twitter, canonical, robots meta) | **seo-analyzer** | |
| Heading hierarchy (H1 presence/count, level skips) | **seo-analyzer** | Structure only. |
| H1/H2 content rewrite (Definition Lead, question-style) | **geo-analyzer** | Semantic rewrite for AI extraction. Batch G5 confirmation-gated. |
| TL;DR / summary blocks insertion | **geo-analyzer** | |
| Legal pages (mentions légales, confidentialité, CGV) | **seo-analyzer** | |
| CMP / cookie banner integration | **seo-analyzer** | |
| Images (alt, width/height, compression, WebP/AVIF) | **seo-analyzer** | |
| hreflang | **seo-analyzer** | |
| Footer links (legal + service/city pages) | **seo-analyzer** | |
| New city/service pages | **seo-analyzer** | Batch D confirmation. |
| Video transcripts | **seo-analyzer** (user action) | |

If either agent detects a finding in a file it doesn't own, it emits
a "CROSS-AGENT NOTE" in its envelope. The dispatcher does NOT re-spawn
the owning agent (both have finished by merge time). Instead, cross-agent
findings are escalated into `SEO.md §11 — Actions utilisateur requises`
with an explicit "Automatisation possible avec: ..." block pulled from
`automation-catalog.md`. This is the Option B resolution (chosen by
user): simpler than a coordinator agent, aligns with the "every user
action lists automation" rule, and avoids architectural complexity.

### Shared-file edit discipline (prevents last-writer-wins)

Ownership is by *concern*, not by *file*. A single template
(`Layout.astro`, `index.html`, `base.html.twig`, `_document.tsx`…)
typically contains BOTH concerns simultaneously:
  - meta tags (seo-analyzer)
  - JSON-LD blocks (geo-analyzer)

The analyzers only AUDIT in parallel (read-only, safe). Fixes are applied
LATER and SERIALLY by this dispatcher in STEP 1.5 (seo bundle first, then
geo bundle) — there is no parallel last-writer-wins race. Each bundle item
still carries this rule for its applier:

> On any shared template file (multiple owned concerns), use the `Edit`
> tool with a **narrow, targeted** `old_string` enclosing ONLY the owned
> concern. NEVER use `Write` (full-file rewrite) on a shared template.
> `Write` is reserved for sole-owned files (sitemap.xml, robots.txt,
> llms.txt, legal pages, new city pages, .htaccess).

If `Edit` is insufficient (full-template refactor), the item is escalated
as a cross-agent note → §11 user action instead.

## STEP 1 — Spawn both agents IN PARALLEL

Issue both `Agent` tool calls **in the same message** (parallel tool
calls). The harness runs them concurrently.

```
Agent(subagent_type="seo-analyzer")
prompt: """
Dispatched from /seo. Context:

AUDIT DEPTH: <LOCAL|FULL>
BUSINESS CONTEXT:
  Activity type: ...
  Geography: ...
  Languages: ...
  Priority keywords: ...
  Intervention mode: ...
  Production URL: ... (FULL only)
  GMB URL: ...
  Social URLs: ...
  Known citations: ...
  Known competitors: ...
  Time budget: ...
  GSC account: <label> | none (FULL only)
  GSC property: <property> | none (FULL only)

You are the classical-SEO half of a parallel SEO+GEO audit. Do NOT
audit GEO/AI signals (llms.txt, AI crawlers, QAPage/Speakable schemas,
entity SEO, content shape for AI, AI visibility) — the geo-analyzer
agent runs in parallel and owns those.

FILE OWNERSHIP (authoritative, prevents parallel-edit conflicts):
- YOU OWN (read+write): sitemap.xml, image/video sitemaps, .htaccess,
  meta tags (title, description, OG, Twitter, canonical, robots meta),
  heading structure (H1 count, level skips), legal pages, CMP, images
  (alt/dimensions/compression), hreflang, footer links, new city/service
  pages.
- YOU READ-ONLY: robots.txt (geo-analyzer owns), JSON-LD blocks
  (geo-analyzer owns structure; you flag NAP inconsistencies), llms.txt.
- CROSS-AGENT NOTES: if you find issues in files you don't own, emit
  them in your envelope under "CROSS-AGENT NOTES TO geo-analyzer:".
  Dispatcher escalates each note to SEO.md §11 as user action (with
  automation options). Do NOT attempt direct cross-agent fix.

SHARED-FILE EDIT DISCIPLINE (carried into each bundle item):
- On shared templates (Layout.astro, index.html, base.html.twig, etc.)
  where meta tags + JSON-LD coexist, each FIX BUNDLE item MUST instruct
  its applier (hotfixer/feater) to use `Edit` with a targeted `old_string`
  enclosing ONLY your concern (meta tags). NEVER `Write` on shared templates.
- `Write` is allowed only on sole-owned files: sitemap.xml, .htaccess,
  legal pages, new city/service pages.
- If full-template refactor is needed, emit as a cross-agent note → §11.

Execute your agent spec at ~/.claude/agents/seo-analyzer.md starting
at STEP 2 (skip STEP 0 and STEP 1 — context is provided above).

At STEP 13, emit the STRUCTURED ENVELOPE for merging (not a standalone
SEO.md), INCLUDING the `## FIX BUNDLE` section terminated by the verbatim
`READY TO APPLY — awaiting dispatcher confirmation` sentinel. Do NOT apply
any fix, do NOT dispatch any sub-agent, do NOT write SEO.md — /seo applies
your bundle in STEP 1.5 and merges the reports.
"""

Agent(subagent_type="geo-analyzer")
prompt: """
Dispatched from /seo. Context:

AUDIT DEPTH: <LOCAL|FULL>
BUSINESS CONTEXT:
  (same block as above)

You are the GEO/AI half of a parallel SEO+GEO audit. Do NOT audit
classical SEO signals (meta tags, Core Web Vitals, hreflang, image
compression, classical legal compliance) — the seo-analyzer agent
runs in parallel and owns those. Your focus is AI-engine retrieval:
llms.txt, AI crawlers in robots.txt, QAPage/Speakable/Person+Article
schemas, entity SEO (Wikidata, sameAs, Knowledge Panel), content
shape for LLM extraction, AI visibility testing.

FILE OWNERSHIP (authoritative, prevents parallel-edit conflicts):
- YOU OWN (read+write): robots.txt (all directives — classical + AI),
  llms.txt, llms-full.txt, JSON-LD blocks (all schemas, all pages),
  H1/H2 content rewrite for Definition Lead, TL;DR / summary blocks,
  content shape changes.
- YOU READ-ONLY: sitemap.xml, .htaccess, meta tags, heading structure
  (seo-analyzer owns structure), legal pages, images, hreflang.
- CROSS-AGENT NOTES: if you find issues in files you don't own, emit
  them in your envelope under "CROSS-AGENT NOTES TO seo-analyzer:".
  Dispatcher escalates each note to SEO.md §11 as user action (with
  automation options). Do NOT attempt direct cross-agent fix.

SHARED-FILE EDIT DISCIPLINE (carried into each bundle item):
- On shared templates (Layout.astro, index.html, base.html.twig, etc.)
  where meta tags + JSON-LD coexist, each FIX BUNDLE item MUST instruct
  its applier (hotfixer/feater) to use `Edit` with a targeted `old_string`
  enclosing ONLY your concern (JSON-LD block). NEVER `Write` on shared
  templates.
- `Write` is allowed only on sole-owned files: robots.txt, llms.txt,
  llms-full.txt.
- If full-template refactor is needed, emit as a cross-agent note → §11.

Execute your agent spec at ~/.claude/agents/geo-analyzer.md starting
at STEP 2 (skip STEP 0 and STEP 1 — context is provided above).

At STEP 14, emit the STRUCTURED ENVELOPE for merging (not a standalone
GEO.md), INCLUDING the `## FIX BUNDLE` section terminated by the verbatim
`READY TO APPLY — awaiting dispatcher confirmation` sentinel. Do NOT apply
any fix, do NOT dispatch any sub-agent, do NOT write GEO.md/SEO.md — /seo
applies your bundle in STEP 1.5 and merges the reports.
"""
```

## STEP 1.5 — Apply fix bundles (from THIS main loop, at L1)

Both analyzers returned an envelope containing a `## FIX BUNDLE` section
terminated by `READY TO APPLY — awaiting dispatcher confirmation`. Apply
them **from this dispatcher loop by dispatching `hotfixer`/`feater` at L1**
— one dispatch level, no nested spawn, so fixes land on any Claude Code
version (this is the whole point of the bundle contract).

**Skip this step entirely if intervention mode = conservative (audit-only)**
— leave both bundles in SEO.md as ready-to-apply and go to STEP 2.

**Tier recognition (tolerant of the analyzer's batch labels).** Classify by
intent, not header wording: **AUTO** = no-confirmation items (seo batches
A/B/C · geo G1–G4/G6); **GATED** = items marked NEEDS CONFIRMATION / visible
/ structural (seo D/E · geo G5); **USER ACTIONS** = batch F / G7.

### Serial by ownership (no parallel race)

The two bundles may touch the same shared template (meta vs JSON-LD). Apply
**serially, never in parallel**:
1. seo-analyzer AUTO items first (meta, sitemap, .htaccess, legal, images…).
2. then geo-analyzer AUTO items (robots.txt, JSON-LD, llms.txt…).

### AUTO tier — no confirmation

For each AUTO item, dispatch its `applier` at L1, passing the item verbatim:

```
Agent(subagent_type="hotfixer")     # or "feater" per the item's applier
prompt: "<paste the bundle item: files, concern, current, expected,
  framework note + shared-file discipline>.
  Context: SEO/GEO audit fix, autonomous scope — no confirmation needed.
  Do NOT commit — apply and self-verify only."
```

`applier: bash` items → run the emitted command from this loop, then apply
the `<img>` Edit it enables.

### GATED tier — confirmation required

Collect every GATED item from BOTH bundles and present ONE gate:

```
SEO/GEO — gated changes need approval (visible / structural):
  D1   <change> — impact: <visible change>            [seo]
  G5.1 <change> — impact: <visible change>            [geo]
Approve all / select (ids) / skip all?
```

Apply approved items via `feater` at L1 (same as AUTO). Unapproved →
document in SEO.md §9. NEVER apply a GATED item before explicit approval.

### After applying

1. Build/lint if available (`npm run build`, `npm run lint`) — revert any
   applied fix that breaks the build.
2. Record each applied change for SEO.md §15 (file, change, reason, verified).
3. USER ACTIONS from both bundles → SEO.md §11 (each with automation-catalog ref).

## STEP 2 — Merge envelopes into SEO.md

Both agents return structured envelopes keyed by SEO.md section
numbers. Consolidate them into `.claude/audits/SEO.md`
(run `mkdir -p .claude/audits` first).

### Combined score calculation

Per user decision:
- **Local B2C**: `GLOBAL = 0.80 × SEO_score + 0.20 × GEO_score`
- **SaaS / national / content**: `GLOBAL = 0.75 × SEO_score + 0.25 × GEO_score`

### Final SEO.md structure

```markdown
# Audit SEO + GEO — <Project Name>

**Date** : <YYYY-MM-DD>
**Version** : v<N> (incremented on each run)
**Agents** : seo-analyzer + geo-analyzer (parallel)
**URL** : <production URL>
**Depth** : LOCAL | FULL
**Score SEO (classique)** : XX.X / 20
**Score GEO (IA)**        : XX.X / 20
**Score global pondéré**  : XX.X / 20 (<weights explained>)

---

## 0. Alertes majeures (conformité + risques SEO/GEO)
<Merged from both agents — legal blockers, catastrophic issues>

## 1. Notes globales (/20 par axe + pondérée)
<SEO scoring table from seo-analyzer + GEO scoring table from geo-analyzer + combined score>

## 2. Audit technique (HTTP, CWV, sécurité)
<From seo-analyzer>

## 3. Audit on-page (meta, headings, content, images, video, a11y, i18n)
<From seo-analyzer>

## 4. SEO local / NAP
<From seo-analyzer>

## 5. Présence externe (GMB, réseaux sociaux, citations)
<From seo-analyzer — FULL only>

## 6. Analyse concurrentielle
<From seo-analyzer — FULL only>

## 7. Optimisation GEO / IA
<From geo-analyzer — full dedicated section with sub-sections:>
### 7.1 AI crawlers policy
### 7.2 llms.txt / llms-full.txt
### 7.3 Schema.org pour extraction IA (QAPage, Speakable, Person, Article+author)
### 7.4 Entity SEO (Wikidata, @id, sameAs, Knowledge Panel)
### 7.5 Content shape pour extraction IA (Definition Lead, TL;DR, citations, fraîcheur)
### 7.6 Visibilité IA (tests — FULL only)

## 8. Plan d'action — QUICK WINS (< 7 jours)
<Merged from both agents — AUTO + USER, dedupe overlaps>

## 9. Plan d'action — MOYEN TERME (1-3 mois)
<Merged>

## 10. Plan d'action — LONG TERME (3-6 mois)
<Merged>

## 11. Actions utilisateur requises
<Merged — EVERY entry includes "Automatisation possible avec: <tools>"
 per ~/.claude/agents/resources/automation-catalog.md>

## 12. Recommandations gratuites (outils, méthodes, budget 0 EUR)
<Merged — GSC, PageSpeed, Schema validator, manual AI-visibility spreadsheet, etc.>

## 13. Synthèse 90 jours — objectifs réalistes
<Combined measurable targets: review count, ranking positions, traffic,
 AI mention rate, Wikidata presence>

## 14. Annexe — informations non-auditables automatiquement
<Merged — what couldn't be checked, why>

## 15. Log des modifications appliquées par les agents
<Merged change logs from both agents, grouped by batch>

---

## Historique
<Previous audit summaries preserved here>
```

### Deduplication rules

Both agents may surface overlapping findings (e.g. JSON-LD presence,
Legal compliance). Merge rule:

- **Hard dedupe**: identical finding text → keep one, credit both agents
  in a `<sub>Detected by: seo-analyzer, geo-analyzer</sub>` line
- **Complementary findings**: both agents see the same feature from
  different angles (classical ranking + AI extraction) → keep both,
  group under the same section
- **Conflicting findings**: rare — if one agent says "remove schema X"
  and the other says "keep schema X", flag explicitly in §0 and let
  the user decide

### CROSS-AGENT NOTES handling (Option B — §11 escalation)

When an envelope contains a `CROSS-AGENT NOTES TO <other-agent>:`
block, the dispatcher:

1. Does NOT re-spawn the target agent (it has finished).
2. Converts each note into a §11 user action entry with the format:
   ```
   ### <action title> (cross-agent note from <source-agent>)

   **Contexte:** <source-agent> a détecté ce point dans un fichier
   appartenant à <target-agent>, mais l'audit parallèle s'est terminé
   avant échange.

   **Action:** <what to do>

   **Automatisation possible avec:** <pull from automation-catalog.md>

   **Effort manuel:** <estimate>
   ```
3. Tags it visibly in §0 if it's a legal/compliance blocker.
4. Keeps these notes visible on re-run — they don't silently vanish.

## STEP 3 — Console summary

```
SEO + GEO AUDIT COMPLETE (parallel dispatch)
URL                        : <url>
FRAMEWORK                  : <name + rendering>
DEPTH                      : LOCAL | FULL

NOTE SEO (classique)       : XX.X / 20
NOTE GEO (IA)              : XX.X / 20
NOTE GLOBALE (pondérée)    : XX.X / 20

CHANGEMENTS APPLIQUES  (N) : voir SEO.md §15
ACTIONS UTILISATEUR    (N) : voir SEO.md §11 (avec automatisation)
CONFORMITÉ LÉGALE          : OK | <N> blockers → §0
ALERTES MAJEURES           : <short list>

PROCHAINE ÉTAPE            : <highest-priority immediate action>
```

## Rules

- **Parallel dispatch is mandatory.** Both Agent calls MUST be in the
  same message so the harness runs them concurrently. Sequential
  dispatch doubles wall-clock time and is explicitly forbidden.
- **Context collected once.** STEP 0 runs before any agent call.
  Do not let either agent re-ask the user questions that STEP 0
  already answered.
- **Neither agent writes SEO.md.** Only the dispatcher (this skill)
  writes the consolidated report. Agents return envelopes.
- **Merge, don't overwrite.** On re-run, previous SEO.md's Historique
  section is preserved. Current content moves to Historique with
  summary (date + score + key changes).
- **Every user action has automation options.** Mandatory per the agents'
  spec, sourced from `automation-catalog.md`.
- **Scoring weights per user decision**: GEO = 20% local B2C, 25%
  SaaS/national/content. Combined score formula is explicit in §1.
