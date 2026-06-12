# Global coding preferences

Apply unless repo-specific instructions override.

## Code style
- Simple, readable, maintainable > clever or compact.
- One responsibility per function/method.
- Preserve existing behavior unless asked.
- Scope changes to task. No unrelated edits.

## Limits (adapt to language)
- Max 25 logic lines/function, 80 chars/line, 5 params, 5 local vars.
  Logic lines = executable statements; comments + error-handling
  boilerplate don't count toward 25.
- Too many params → struct/object. Too many vars → split/extract.
- No global state. Explicit data flow.

## Comments & readability
- Document intent, not mechanics. Use project doc style (docstring, JSDoc…).
- Explicit, consistent, meaningful names. Straight control flow.
  No hidden side effects.

## Refactoring
- Priority: safety → readability → consistency.
- Remove dead code, stale comments, obsolete flags after changes.
- Non-trivial change: ask "more elegant solution exists?"
  Hacky fix → rebuild clean. No over-engineering.

## Session start
1. Read `.claude/memory/` — 5 registries (decisions, learnings, blockers,
   journal, evals). Apply before touching anything.
2. Read `.claude/tasks/TODO.md` — current state.
3. Either missing → create before starting
   (templates: `~/.claude/templates/memory/`).

## Workflow
- Task touches logic (new behavior, control flow, state, API,
  dependencies) → plan in `.claude/tasks/TODO.md` first, decomposed into
  subtasks. One complex task still needs plan. Borderline case (single
  file, small obvious logic change) → skip plan, stay pragmatic.
- Confirm before implementing ONLY when real trade-offs exist (multiple
  valid approaches, breaking change, destructive action) — else proceed.
- Exempt from TODO.md: pure reads, explanations, questions, typos,
  cosmetic CSS, single config-value change. Same scope as `/hotfix`
  (≤2 files, obvious fix).
- Minimal changes unless broader refactor requested. State trade-offs.
- Sub-agents keep main context clean — one task per sub-agent.
  More compute on hard problems.
- One question upfront if needed — never interrupt mid-task.
  *Exception: skill-mandated gates and checkpoints (orchestrator
  validation gates, approval gates, darwin checkpoints) always fire.*
- Bug received → fix directly: check logs, find root cause, resolve
  autonomously.
- Something goes wrong → STOP, re-plan. Never push through.
- Deviations: minor or clearly justified → do, explain after.
  Significant or shaky justification → ask BEFORE deviating.
- Root causes only. No temp fixes. Never assume — verify paths, APIs,
  variables before use.

## After code changes
1. Run tests, lint, build, type-check if available.
2. Report what verified, what not.
3. List remaining risks, surviving deviations.
4. Never mark complete without proof it works.
   Bar: "would staff engineer approve?"
5. Correction or notable event → capitalize to right registry
   (see "Memory registries").

## Task tracking (`.claude/tasks/TODO.md`)

Any write/modify task touching logic. Skip reads + trivial edits
(see Workflow).

1. Plan → task written before code.
2. Decompose → one subtask = one coherent change.
3. Track → check off as you go.
4. Summarize → high-level note at each milestone.

## Memory registries (`.claude/memory/`)

Five registries persist across sessions. Read all at session start.
Capitalize during/after work. Append-only by default — never rewrite
past entries; curation (merge, mark superseded, compress) ONLY via
`/prune-memory`.

| File | ID format | Purpose |
|------|-----------|---------|
| `decisions.md` | BDR-XXX | Design/architecture choices + rationale + alternatives + status |
| `learnings.md` | LRN-XXX | Reusable patterns + context + future application |
| `blockers.md` | BLK-XXX | Friction + real cause + solution + status (open/resolved/upstream) |
| `journal.md` | date heading | 3-5 lines/session — done, decided, blocked |
| `evals.md` | EVAL-XXX | Quality check of Claude's output + method + anomalies + action |

**Language — registries ALWAYS English.** Rationale: consistent vocab,
lower token cost, cross-project reuse. User-facing CAPITALIZE prompts may
mirror user's language; final written entry English.

**Format — registries ALWAYS caveman.** Drop articles + filler, fragments
OK, short synonyms. Technical terms exact, code blocks unchanged, errors
quoted exact, IDs (BDR/LRN/BLK/EVAL-XXX) + dates unchanged. Pattern:
`[thing] [action] [reason]. [next step].` Rationale: registries load
every session — caveman cuts ~40% input tokens, zero substance loss.
Applies to direct writes AND skill CAPITALIZE steps (close, ship-feature,
feat, bugfix, hotfix, commit-change). Existing entries: compress via
`/caveman-compress <file>`.

**Routing — what goes where:**
- Choice with tradeoffs you'd defend → `decisions.md`.
- Pattern worth reusing → `learnings.md`.
- Dead end with root cause identified → `blockers.md`.
- One-line log of session → `journal.md`.
- Did Claude's output actually work? → `evals.md`.

**Proactive capitalization (Claude's responsibility):**
After substantive milestone (bug fix with real root cause, feature
shipped, non-trivial commit, design choice, surprising discovery, dead
end with lesson) → **offer to capitalize inline**, do NOT wait for user.
Pre-fill entry from context; user approves/edits before write.
Completion skills (`/ship-feature`, `/feat`, `/bugfix`, `/hotfix`,
`/commit-change`) automate this via CAPITALIZE step.

**Session-close ritual** (`/close`, or inline when asked):
1. What decided? → `decisions.md` (if non-trivial).
2. What learned? → `learnings.md` (if reusable).
3. What blocked? → `blockers.md`.

---

# Architecture decisions

Override default framework/tooling choices. Apply at project creation,
scaffolding, brainstorming.

## Public websites — never SPA

When project is public-facing website meant to be indexed (landing page,
portfolio, blog, e-commerce, docs):

- **FORBIDDEN**: pure SPA (CRA, Vite React SPA, Vue SPA) for public pages.
  SPA sends empty HTML shell — search engines and AI engines (GEO) can't
  see content without executing JS. SEO and AI visibility destroyed.
- **Astro** = default for informational sites (portfolio, docs, blog,
  landing). Static HTML at build, zero JS by default, React/Vue/Svelte
  islands for interactive parts.
- **Next.js** = when dynamic SSR needed (personalized content, server-side
  auth, API routes, hybrid app).
- **React SPA** = valid ONLY for: admin panels, dashboards, auth-gated
  apps, internal tools — anything that does NOT need indexing.
- **Mixed project** (public + admin): Astro/Next for public, React island
  (`client:only`) for admin.
- At brainstorming (`/init-project` STEP 1, `/ship-feature` STEP 1): if
  project is public website and user hasn't specified framework, PROPOSE
  Astro and EXPLAIN why not SPA. Never silently pick React CRA.

## Web APIs — always versioned

All web API endpoints MUST be versioned from day one: `/api/v1/...`.

- New project → start at `/api/v1/`. No bare `/api/` routes.
- Breaking changes → new version (`v2`). Old version stays functional —
  clients migrate at own pace.
- Non-breaking additions (new fields, new endpoints) → current version.
- Each version is self-contained contract. Never modify existing version
  behavior to match newer one.
- Router structure reflects versioning explicitly (e.g. `api/v1/routes/`).

## Security — non-negotiable defaults

Apply at every dev step: design, scaffolding, implementation, review.

### Input & data
- Never trust user input. Validate type, length, format, range before use.
- Sanitize before rendering (XSS), before SQL (injection), before shell
  (command injection).
- Use parameterized queries / prepared statements. String concatenation
  into SQL = immediate blocker.

### Secrets
- Never hardcode credentials, tokens, keys, or URLs containing auth info —
  not even in comments.
- Always use env vars. Provide `.env.example` with placeholder values only.
- If secret appears in code during review, flag and stop — do not proceed.

### Authentication & authorization
- AuthN (who you are) and AuthZ (what you can do) separate. Never assume
  AuthN implies AuthZ.
- Check authorization on every sensitive endpoint/function — not just at
  entry point.
- Default to deny. Explicit allowlist > implicit denylist.

### Dependencies
- No dependency without stating what it does and why needed.
- Prefer well-maintained, widely-used packages. Flag abandoned or
  single-maintainer packages.
- Never `npm install` or `pip install` a package found in a random code
  snippet without naming it explicitly.

### Error handling & logging
- Never expose stack traces, internal paths, or DB errors to end users.
  Log internally, return generic message.
- Never log secrets, passwords, tokens, or PII — even at DEBUG level.
- Fail closed: on unexpected error, deny access rather than grant.

### Minimal privilege
- Functions, processes, services request only permissions actually needed.
- Temporary elevated permissions must be scoped and reverted explicitly.

---

# Communication mode: radical honesty

- TRUTH OVER COMFORT — Point out flaws immediately. No sugarcoating,
  no "not bad but…".
- ZERO COMPLACENCY — Never validate idea just because I proposed it.
  Evaluate arguments on merit.
- BLIND SPOT DETECTION — Actively look for what I'm missing: confirmation
  bias, hidden assumptions, ignored alternatives. Flag without waiting
  for permission.
- ACTIVE RESISTANCE — When I make weak point, push back until I correct
  it or solidly justify keeping it.
- UNCERTAINTY TRANSPARENCY — If you don't know, say so. No invention,
  no vague answers to save face.

---

# Tooling & skills

## Skill routing

Request matches available skill → invoke via Skill tool FIRST. No direct
answer, no other tools before. Skill workflows beat ad-hoc answers.

Key routing rules:
- Product ideas, "worth building?", brainstorming → office-hours
- Bugs, errors, "why broken", 500s → investigate, or bugfix if no gstack
- Small feature (1-5 files) → feat
- Quick fix (typo, CSS, config, ≤2 files) → hotfix
- Ship, deploy, push, PR → ship, or ship-feature if no gstack
- QA, test site, find bugs → qa
- Code review, check diff → review
- Docs update post-ship → document-release, or doc if no gstack
- Stale docs audit, doc sync → doc
- Recurring audit of changes since last run → audit-delta
- Weekly retro → retro
- Design system, brand → design-consultation, then design toolchain below
- Build UI / component / page / screen → design toolchain below
- Visual audit, polish → design-review + emil-design-eng
  + design-motion-principles (audit mode)
- Architecture review → plan-eng-review
- Save/restore working context → context-save / context-restore
- End-of-session ritual → close
- Flush memory before /clear or /compact → capitalize
- Registries too big/noisy → prune-memory
- Skill profiles (design/dev/qa/minimal) → profile
- Code quality dashboard → health
- Refactor without behavior change → refactor
- Dead code, style cleanup → code-clean
- SEO/GEO audit → seo (GEO only → geo)
- Web hardening (SSL/TLS, HSTS, CSP, redirects, headers) → harden
- W3C + WCAG a11y (HTML/CSS validity, axe, pa11y) → validate
- Deep analysis before modification → analyze
- Smart commit grouping → commit-change
- Security audit (secrets, deps CVE, OWASP) → cso
- New project from scratch → init-project
- Onboard existing repo (config + archetype + audits + backlog) → onboard

gstack OFF → gstack skills (investigate, ship, qa, review, health, retro,
office-hours, context-save…) unavailable: use the non-gstack fallback
where listed, else say so instead of improvising.

Design gate (automatic): lightweight skills (feat, hotfix, bugfix) detect
UI/style signals; signals found + ui-ux-pro-max inactive → ask user
before proceeding. Gate spec: `~/.claude/lib/design-gate.md`.
Orchestrators (ship-feature, init-project) handle via STEP 0 plugin-check.

## Design work — full toolchain (tiered by scope)

Task touches design/UI → mobilize tools by scope. Reinforced by
design-toolchain-reminder hook (injects on UI signals).
- Trivial (≤2 files, single cosmetic value) → /hotfix, NO toolchain.
- Build UI (new component, page, screen, redesign) → ui-ux-pro-max
  (plan/build) + frontend-design (anti AI-slop) + Magic MCP `/ui`
  (21st.dev scaffold) + emil-design-eng (polish pass)
  + design-motion-principles (when motion) + design-html (static HTML).
- Design system / brand → design-consultation FIRST (aesthetic, type,
  color, spacing, motion), THEN build tools above.
- Review / audit → design-review (visual QA + fix) + emil-design-eng lens
  + design-motion-principles (audit mode).
Scope doubt (trivial tweak vs real UI change?) → do NOT silently skip
toolchain: ask user, or default to Build tier.
Magic MCP (@21st-dev/magic) costs API calls — component generation only,
not micro-tweaks.

## graphify

Knowledge-graph navigation via graphify CLI. ALL rules conditional:
`graphify-out/graph.json` exists in the project — else skip graphify
entirely, read files directly.

- Codebase-wide question → `graphify query "<question>"` first.
  Relationships → `graphify path "<A>" "<B>"`. Focused concept →
  `graphify explain "<concept>"`. Scoped subgraph beats raw grep.
- Known file/symbol lookup, small task (hotfix, typo, single file) →
  read directly, no graphify.
- `graphify-out/wiki/index.md` exists → broad-navigation entrypoint.
  `GRAPH_REPORT.md` only for whole-architecture review or when
  query/path/explain insufficient.
- After modifying code → `graphify update .` (AST-only, no API cost).

---

# This repo only (claude-config)

Apply when working directory = the claude-config repo itself.

## Health Stack
- shell: `shellcheck *.sh hooks/*.sh lib/*.sh`
