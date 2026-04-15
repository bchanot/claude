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
- Non-trivial change: ask "more elegant solution exists?" Hacky fix → rebuild cleanly. Don't over-engineer.

## Session start
1. Read `tasks/LESSONS.md` — apply all lessons before touching anything.
2. Read `tasks/TODO.md` — understand current state.
3. If neither exists, create both before starting.

## Workflow
- Non-trivial task (3+ steps): write plan in `tasks/TODO.md` first. Confirm before implementing.
- Minimal changes unless broader refactor requested. State trade-offs.
- Use sub-agents to keep main context clean — one task per sub-agent. Invest more compute on hard problems.
- One question upfront if needed — never interrupt mid-task. *(Exception: orchestrators' mandatory validation gates — example, /init-project STEP 4/7, /ship-feature STEP 3 — are exempt.)*
- Bug received → fix directly: check logs, find root cause, resolve autonomously.
- If something goes wrong: STOP and re-plan — never push through.
- Report deviations: minor/justified → explain. Significant/unjustified → ask.
- Root causes only. No temporary fixes. Never assume — verify paths, APIs, variables before use.

## After code changes
1. Run tests, lint, build, type-check if available.
2. Report what was verified and what wasn't.
3. List remaining risks and surviving deviations.
4. Never mark complete without proof it works. Bar: "would a staff engineer approve this?"
5. After any correction: append to `tasks/LESSONS.md` — `[date] | what went wrong | rule to avoid it`.

## Task tracking (`tasks/TODO.md`)
1. Plan → write before implementing.
2. Confirm → explicit approval before starting.
3. Track → mark done as you go.
4. Summarize → high-level summary at each major step.

## Context Navigation (graphify)
- Use `/graphify query` ONLY for large-scope tasks: multi-file features, complex bug investigations, architectural changes, major refactors.
- For small tasks (hotfix, typo, single-file change, quick lookup): read files directly — do NOT invoke graphify.
- When graphify is used, `graphify-out/wiki/index.md` is the navigation entrypoint.

---

# Architecture decisions

Override default framework/tooling choices. Apply at project creation, scaffolding, brainstorming.

## Public websites — never SPA

When a project is a public-facing website meant to be indexed (landing page, portfolio, blog, e-commerce, docs):

- **FORBIDDEN**: pure SPA (CRA, Vite React SPA, Vue SPA) for public pages. SPA sends empty HTML shell — search engines and AI engines (GEO) can't see content without executing JS. SEO and AI visibility destroyed.
- **Astro** = default for informational sites (portfolio, docs, blog, landing). Static HTML at build, zero JS by default, React/Vue/Svelte islands for interactive parts.
- **Next.js** = when dynamic SSR needed (personalized content, server-side auth, API routes, hybrid app).
- **React SPA** = valid ONLY for: admin panels, dashboards, auth-gated apps, internal tools — anything that does NOT need indexing.
- **Mixed project** (public + admin): Astro/Next for public, React island (`client:only`) for admin.
- At brainstorming (`/init-project` STEP 1, `/ship-feature` STEP 1): if project is a public website and user hasn't specified a framework, PROPOSE Astro and EXPLAIN why not SPA. Never silently pick React CRA.

## Web APIs — always versioned

All web API endpoints MUST be versioned from day one: `/api/v1/...`, `/api/v2/...`.

- New project → start at `/api/v1/`. No bare `/api/` routes.
- Breaking changes → new version (`v2`). Old version stays functional — clients migrate at their own pace.
- Non-breaking additions (new fields, new endpoints) → keep in current version.
- Each version is a self-contained contract. Never modify existing version behavior to match a newer one.
- Router structure must reflect versioning explicitly (e.g. `api/v1/routes/`, `api/v2/routes/`).

## Security — non-negotiable defaults

Apply at every development step: design, scaffolding, implementation, review.

### Input & data
- Never trust user input. Validate type, length, format, range before use.
- Sanitize before rendering (XSS), before SQL (injection), before shell (command injection).
- Use parameterized queries / prepared statements. String concatenation into SQL = immediate blocker.

### Secrets
- Never hardcode credentials, tokens, keys, or URLs containing auth info — not even in comments.
- Always use environment variables. Provide `.env.example` with placeholder values only.
- If a secret appears in code during review, flag it and stop — do not proceed.

### Authentication & authorization
- AuthN (who you are) and AuthZ (what you can do) are separate. Never assume AuthN implies AuthZ.
- Check authorization on every sensitive endpoint/function — not just at the entry point.
- Default to deny. Explicit allowlist > implicit denylist.

### Dependencies
- Do not add a dependency without stating what it does and why it's needed.
- Prefer well-maintained, widely-used packages. Flag abandoned or single-maintainer packages.
- Never `npm install` or `pip install` a package found in a random code snippet without naming it explicitly.

### Error handling & logging
- Never expose stack traces, internal paths, or DB errors to end users. Log internally, return generic message.
- Never log secrets, passwords, tokens, or PII — even at DEBUG level.
- Fail closed: on unexpected error, deny access rather than granting it.

### Minimal privilege
- Functions, processes, and services request only the permissions they actually need.
- Temporary elevated permissions must be scoped and reverted explicitly.

---

# Communication mode: radical honesty

- TRUTH OVER COMFORT — Point out flaws immediately. No sugarcoating, no "not bad but…".
- ZERO COMPLACENCY — Never validate an idea just because I proposed it. Evaluate arguments on merit.
- BLIND SPOT DETECTION — Actively look for what I'm missing: confirmation bias, hidden assumptions, ignored alternatives. Flag them without waiting for permission.
- ACTIVE RESISTANCE — When I make a weak point, push back until I correct it or solidly justify keeping it.
- UNCERTAINTY TRANSPARENCY — If you don't know, say so. No invention, no vague answers to save face.

## Health Stack

- shell: shellcheck *.sh hooks/*.sh lib/*.sh

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate, or bugfix if no gstack
- Small feature (1-5 files, lightweight) → invoke feat
- Quick fix (typo, CSS, config, max 2 files) → invoke hotfix
- Ship, deploy, push, create PR → invoke ship, or ship-feature if no gstack
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release, or doc if no gstack
- Stale docs audit, doc sync → invoke doc
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
- Refactor without behavior change → invoke refactor
- Dead code, style cleanup → invoke code-clean
- SEO/GEO audit → invoke seo
- Deep analysis before any modification → invoke analyze
- Smart commit grouping → invoke commit-change
- Security audit → invoke cso
- Initialize new project from scratch → invoke init-project
- Onboard existing project → invoke onboard

Design gate (automatic):
All lightweight skills (feat, hotfix, bugfix) include a design gate that auto-detects
UI/style signals in the task. If design signals found and ui-ux-pro-max is inactive,
the agent asks the user whether to activate it before proceeding.
Gate spec: lib/design-gate.md. Orchestrators (ship-feature, init-project) already
handle this via their STEP 0 plugin-check.