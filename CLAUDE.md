# Global coding preferences

Apply unless repo-specific instructions override.

## Code style
- Simple, readable, maintainable > clever or compact.
- One responsibility per function/method.
- Preserve existing behavior unless asked otherwise.
- Scope changes to task. No unrelated edits.

## Limits (adapt to language)
- Max 25 logic lines/function, 80 chars/line, 5 params, 5 local vars (excl. comments, error handling).
- Too many params → struct/object. Too many vars → split/extract.
- No global state. Explicit data flow.

## Comments & readability
- Document intent, not mechanics. Use project doc style (docstring, JSDoc, etc.).
- Explicit, consistent, meaningful names. Straight control flow. No hidden side effects.

## Refactoring
- Priority: safety → readability → consistency.
- Remove dead code, stale comments, obsolete flags after changes.
- Non-trivial change: ask "more elegant solution exists?" Hacky fix → rebuild cleanly. No over-engineer.

## Session start
1. Read `.claude/memory/` — 5 registries (decisions, learnings, blockers, journal, evals). Apply before touching anything.
2. Read `.claude/tasks/TODO.md` — understand current state.
3. If `.claude/memory/` or `.claude/tasks/TODO.md` missing, create before starting (templates at `~/.claude/templates/memory/`).

## Workflow
- Write/modify task touching logic (new behavior, control flow, state, API, dependencies): plan in `.claude/tasks/TODO.md` first, decomposed into subtasks. Task count irrelevant — one complex task still needs plan. When in doubt about complexity, skip plan (be pragmatic).
- Confirm before implementing only when real trade-offs exist (multiple valid approaches, breaking change, destructive action) — else proceed.
- Exempt from `.claude/tasks/TODO.md`: pure reads, explanations, questions, typos, cosmetic CSS tweaks, single config-value changes. Aligns with `/hotfix` scope (≤2 files, obvious fix).
- Minimal changes unless broader refactor requested. State trade-offs.
- Use sub-agents to keep main context clean — one task per sub-agent. Invest more compute on hard problems.
- One question upfront if needed — never interrupt mid-task. *(Exception: orchestrators' mandatory validation gates — example, /init-project STEP 4/7, /ship-feature STEP 3 — exempt.)*
- Bug received → fix directly: check logs, find root cause, resolve autonomously.
- Something goes wrong: STOP and re-plan — never push through.
- Report deviations: minor/justified → explain. Significant/unjustified → ask.
- Root causes only. No temp fixes. Never assume — verify paths, APIs, variables before use.

## After code changes
1. Run tests, lint, build, type-check if available.
2. Report what verified, what not.
3. List remaining risks and surviving deviations.
4. Never mark complete without proof it works. Bar: "would staff engineer approve this?"
5. After any correction or notable event, capitalize to right registry in `.claude/memory/` (see "Memory registries" below).

## Task tracking (`.claude/tasks/TODO.md`)

Applies to any write/modify task touching logic, regardless of count. Skip for reads and trivial edits (see Workflow).

1. Plan → write task in `.claude/tasks/TODO.md` before touching code.
2. Decompose → split each complex task into subtasks (one subtask = one coherent change).
3. Track → check off subtasks as you go.
4. Summarize → high-level summary at each milestone.

## Memory registries (`.claude/memory/`)

Five append-only registries persist across sessions. Read all at session start. Capitalize during/after work.

| File | ID format | Purpose |
|------|-----------|---------|
| `decisions.md` | BDR-XXX | Design/architecture choices with rationale + alternatives + status |
| `learnings.md` | LRN-XXX | Reusable patterns observed + context + future application (replaces LESSONS) |
| `blockers.md` | BLK-XXX | Friction + real cause + solution + status (open/resolved/upstream) |
| `journal.md` | date heading | 3-5 lines/session — what done, decided, blocked |
| `evals.md` | EVAL-XXX | Quality check of Claude's output + method + anomalies + action |

**Language — registries ALWAYS English:**
All persisted entries (decisions, learnings, blockers, journal, evals) must be English. Rationale: consistent vocab for re-read efficiency, lower token cost, easier cross-project reuse. User-facing CAPITALIZE prompts may mirror user's language; only final written entry is English.

**Format — registries ALWAYS caveman:**
All writes to `.claude/memory/*.md` (decisions, learnings, blockers, journal, evals) MUST use caveman style — drop articles (a/an/the), drop filler (just/really/basically/actually/simply), fragments OK, short synonyms (big not extensive, fix not "implement a solution for"). Keep technical terms exact, code blocks unchanged, error messages quoted exact, IDs (BDR-XXX, LRN-XXX, BLK-XXX, EVAL-XXX) and dates unchanged. Pattern: `[thing] [action] [reason]. [next step].` Rationale: registries loaded every session start — caveman cuts ~40% input tokens with zero loss of technical substance. Applies to direct writes AND skill-driven CAPITALIZE steps (close, ship-feature, feat, bugfix, hotfix, commit-change). Existing entries: compress on demand via `/caveman:compress <file>`.

**Routing — what goes where:**
- Choice with tradeoffs you'd defend → `decisions.md`.
- Pattern worth reusing → `learnings.md`.
- Dead end with root cause identified → `blockers.md`.
- One-line log of session → `journal.md`.
- Did Claude's output actually work? → `evals.md`.

**Proactive capitalization (Claude's responsibility):**
After any substantive milestone (bug fix with real root cause, feature shipped, non-trivial commit, design choice, surprising discovery, dead end with lesson), **offer to capitalize inline** — do NOT wait for user. Use right registry; pre-fill entry from conversation context; let user approve/edit before writing.

Completion skills (`/ship-feature`, `/feat`, `/bugfix`, `/hotfix`, `/commit-change`) include CAPITALIZE step that automates this.

**Session-close ritual** (invoke manually via `/close`, or answer inline when asked):
1. What did I decide? → `decisions.md` (if non-trivial).
2. What did I learn? → `learnings.md` (if reusable).
3. What am I blocked on? → `blockers.md`.

## Context Navigation (graphify)
- Use `/graphify query` ONLY for large-scope tasks: multi-file features, complex bug investigations, architectural changes, major refactors.
- Small tasks (hotfix, typo, single-file change, quick lookup): read files directly — do NOT invoke graphify.
- Before answering architecture/codebase questions, read `graphify-out/GRAPH_REPORT.md` for god nodes and community structure. If `graphify-out/wiki/index.md` exists, use as navigation entrypoint.
- After modifying code files, run `/graphify <path> --update` to keep graph current (AST-only, no API cost for code-only changes).

---

# Architecture decisions

Override default framework/tooling choices. Apply at project creation, scaffolding, brainstorming.

## Public websites — never SPA

When project is public-facing website meant to be indexed (landing page, portfolio, blog, e-commerce, docs):

- **FORBIDDEN**: pure SPA (CRA, Vite React SPA, Vue SPA) for public pages. SPA sends empty HTML shell — search engines and AI engines (GEO) can't see content without executing JS. SEO and AI visibility destroyed.
- **Astro** = default for informational sites (portfolio, docs, blog, landing). Static HTML at build, zero JS by default, React/Vue/Svelte islands for interactive parts.
- **Next.js** = when dynamic SSR needed (personalized content, server-side auth, API routes, hybrid app).
- **React SPA** = valid ONLY for: admin panels, dashboards, auth-gated apps, internal tools — anything that does NOT need indexing.
- **Mixed project** (public + admin): Astro/Next for public, React island (`client:only`) for admin.
- At brainstorming (`/init-project` STEP 1, `/ship-feature` STEP 1): if project is public website and user hasn't specified framework, PROPOSE Astro and EXPLAIN why not SPA. Never silently pick React CRA.

## Web APIs — always versioned

All web API endpoints MUST be versioned from day one: `/api/v1/...`, `/api/v2/...`.

- New project → start at `/api/v1/`. No bare `/api/` routes.
- Breaking changes → new version (`v2`). Old version stays functional — clients migrate at own pace.
- Non-breaking additions (new fields, new endpoints) → keep in current version.
- Each version is self-contained contract. Never modify existing version behavior to match newer one.
- Router structure must reflect versioning explicitly (e.g. `api/v1/routes/`, `api/v2/routes/`).

## Security — non-negotiable defaults

Apply at every dev step: design, scaffolding, implementation, review.

### Input & data
- Never trust user input. Validate type, length, format, range before use.
- Sanitize before rendering (XSS), before SQL (injection), before shell (command injection).
- Use parameterized queries / prepared statements. String concatenation into SQL = immediate blocker.

### Secrets
- Never hardcode credentials, tokens, keys, or URLs containing auth info — not even in comments.
- Always use env vars. Provide `.env.example` with placeholder values only.
- If secret appears in code during review, flag and stop — do not proceed.

### Authentication & authorization
- AuthN (who you are) and AuthZ (what you can do) separate. Never assume AuthN implies AuthZ.
- Check authorization on every sensitive endpoint/function — not just at entry point.
- Default to deny. Explicit allowlist > implicit denylist.

### Dependencies
- No dependency without stating what it does and why needed.
- Prefer well-maintained, widely-used packages. Flag abandoned or single-maintainer packages.
- Never `npm install` or `pip install` package found in random code snippet without naming it explicitly.

### Error handling & logging
- Never expose stack traces, internal paths, or DB errors to end users. Log internally, return generic message.
- Never log secrets, passwords, tokens, or PII — even at DEBUG level.
- Fail closed: on unexpected error, deny access rather than grant.

### Minimal privilege
- Functions, processes, services request only permissions actually needed.
- Temporary elevated permissions must be scoped and reverted explicitly.

---

# Communication mode: radical honesty

- TRUTH OVER COMFORT — Point out flaws immediately. No sugarcoating, no "not bad but…".
- ZERO COMPLACENCY — Never validate idea just because I proposed it. Evaluate arguments on merit.
- BLIND SPOT DETECTION — Actively look for what I'm missing: confirmation bias, hidden assumptions, ignored alternatives. Flag without waiting for permission.
- ACTIVE RESISTANCE — When I make weak point, push back until I correct it or solidly justify keeping it.
- UNCERTAINTY TRANSPARENCY — If you don't know, say so. No invention, no vague answers to save face.

## Health Stack

- shell: shellcheck *.sh hooks/*.sh lib/*.sh

## Skill routing

When user's request matches available skill, ALWAYS invoke via Skill
tool as FIRST action. Do NOT answer directly, do NOT use other tools first.
Skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate, or bugfix if no gstack
- Small feature (1-5 files, lightweight) → invoke feat
- Quick fix (typo, CSS, config, max 2 files) → invoke hotfix
- Ship, deploy, push, create PR → invoke ship, or ship-feature if no gstack
- QA, test site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release, or doc if no gstack
- Stale docs audit, doc sync → invoke doc
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation and use ui-ux-pro-max if available
- Visual audit, design polish → invoke design-review which call ui-ux-pro-max
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
- Refactor without behavior change → invoke refactor
- Dead code, style cleanup → invoke code-clean
- SEO/GEO audit → invoke seo
- Web hardening (SSL/TLS, HSTS, CSP, HTTP→HTTPS, canonical, 404, .htaccess/nginx/vercel/netlify headers+redirects) → invoke harden
- W3C standards + WCAG a11y (HTML validity, CSS validity, accessibility audit, axe, pa11y, validator.w3.org, normes W3C) → invoke validate
- Deep analysis before any modification → invoke analyze
- Smart commit grouping → invoke commit-change
- Security audit (secrets, deps CVE, OWASP code-level) → invoke cso
- Initialize new project from scratch → invoke init-project
- Onboard existing project (config + archetype detection + full audit pipeline + backlog) → invoke onboard

Design gate (automatic):
All lightweight skills (feat, hotfix, bugfix) include design gate that auto-detects
UI/style signals in task. If design signals found and ui-ux-pro-max inactive,
agent asks user whether to activate before proceeding.
Gate spec: lib/design-gate.md. Orchestrators (ship-feature, init-project) already
handle via STEP 0 plugin-check.

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
