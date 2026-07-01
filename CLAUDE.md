# Global coding preferences

Apply unless repo-specific instructions override.

## Code style
- Simple, readable, maintainable > clever or compact.
- One responsibility per function/method.
- Preserve existing behavior unless asked.
- Scope changes to task — no unrelated edits.

## Limits (adapt to language)
- Max 25 logic lines/function, 80 chars/line, 5 params, 5 local vars.
  Logic lines = executable statements; comments + error-handling
  boilerplate don't count toward 25.
- Too many params → struct/object. Too many vars → split/extract.
- No global state. Explicit data flow.

## Comments & readability
- Document intent, not mechanics. Use project doc style (docstring, JSDoc…).
- Explicit, consistent, meaningful names. Straight control flow,
  no hidden side effects.

## Refactoring
- Priority: safety → readability → consistency.
- Remove dead code, stale comments, obsolete flags after changes.
- Non-trivial change: ask "more elegant solution exists?"
  Hacky fix → rebuild clean, no over-engineering.

## Session start
1. Read `.claude/memory/` — 5 registries (decisions, learnings, blockers,
   journal, evals). Apply before touching anything.
2. Read `.claude/tasks/TODO.md` — current state.
3. Either missing → create before starting
   (templates: `~/.claude/templates/memory/`).

## Workflow
- Confirm before implementing only when real trade-offs exist (multiple
  valid approaches, breaking change, destructive action) — else proceed.
- Minimal changes unless broader refactor requested. State trade-offs.
- Sub-agents keep main context clean — one task per sub-agent.
  More compute on hard problems. Task fans out across independent
  items (many files, parallel searches, multi-point checks) → delegate
  to sub-agents, don't iterate serially. Default to delegation for
  multi-file exploration. Counters Opus 4.8 tendency to under-delegate.
- One question upfront if needed — don't interrupt mid-task.
  *Exception: skill-mandated gates and checkpoints (orchestrator
  validation gates, approval gates, darwin checkpoints) always fire.*
- Bug received → fix directly: check logs, find root cause, resolve
  autonomously.
- Something goes wrong → STOP, re-plan. Never push through.
- Deviations: minor or clearly justified → do, explain after.
  Significant or shaky justification → ask before deviating.
- Root causes only. No temp fixes. Never assume — verify paths, APIs,
  variables before use.

## Planning & TODO (`.claude/tasks/TODO.md`)

- When to plan: task touches logic (new behavior, control flow, state,
  API, dependencies) → write it in `.claude/tasks/TODO.md` first,
  decomposed into subtasks. One complex task still needs a plan.
  Borderline case (single file, small obvious logic change) → skip plan,
  stay pragmatic.
- Exempt (skip TODO.md): pure reads, explanations, questions, typos,
  cosmetic CSS, single config-value change. Same scope as `/hotfix`
  (≤2 files, obvious fix).
- How to track, once a task qualifies:
  1. Plan → task written before code.
  2. Decompose → one subtask = one coherent change.
  3. Track → check off as you go.
  4. Summarize → high-level note at each milestone.

## After code changes
1. Run tests, lint, build, type-check if available.
2. Report what verified, what not.
3. List remaining risks, surviving deviations.
4. Don't mark complete without proof it works.
   Bar: "would staff engineer approve?"
5. Correction or notable event → capitalize to right registry
   (see "Memory registries").

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

**Language — registries always English.** Rationale: consistent vocab,
lower token cost, cross-project reuse. User-facing CAPITALIZE prompts may
mirror user's language; final written entry English.

**Format — registries always caveman.** Drop articles + filler, fragments
OK, short synonyms. Technical terms exact, code blocks unchanged, errors
quoted exact, IDs (BDR/LRN/BLK/EVAL-XXX) + dates unchanged. Pattern:
`[thing] [action] [reason]. [next step].` Rationale: registries load
every session — caveman cuts ~40% input tokens, zero substance loss.
Applies to direct writes AND skill CAPITALIZE steps (close, ship-feature,
feat, bugfix, hotfix, commit-change). Legacy entries (pre-format-rule):
compress manually or via claude.ai on demand.

**Routing — what goes where:**
- Choice with tradeoffs you'd defend → `decisions.md`.
- Pattern worth reusing → `learnings.md`.
- Dead end with root cause identified → `blockers.md`.
- One-line log of session → `journal.md`.
- Did Claude's output actually work? → `evals.md`.

**Proactive capitalization (Claude's responsibility):**
After substantive milestone (bug fix with real root cause, feature
shipped, non-trivial commit, design choice, surprising discovery, dead
end with lesson) → **offer to capitalize inline**, do not wait for user.
Pre-fill entry from context; user approves/edits before write.
Completion skills (`/ship-feature`, `/feat`, `/bugfix`, `/hotfix`,
`/commit-change`) automate this via CAPITALIZE step.

**Session-close ritual** (`/close` = `/capitalize --ritual`, or inline when asked):
1. What decided? → `decisions.md` (if non-trivial).
2. What learned? → `learnings.md` (if reusable).
3. What blocked? → `blockers.md`.

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
- **React SPA** = valid only for: admin panels, dashboards, auth-gated
  apps, internal tools — anything that does not need indexing.
- **Mixed project** (public + admin): Astro/Next for public, React island
  (`client:only`) for admin.
- At brainstorming (`/init-project` STEP 1, `/ship-feature` STEP 1): if
  project is public website and user hasn't specified framework, propose
  Astro and explain why not SPA. Never silently pick React CRA.

## Web APIs — always versioned

All web API endpoints must be versioned from day one: `/api/v1/...`.
- New project → start at `/api/v1/`, no bare `/api/` routes.
- Breaking changes → new version (`v2`). Old version stays functional —
  clients migrate at own pace.
- Non-breaking additions (new fields, new endpoints) → current version.
- Each version is self-contained contract. Don't modify existing version
  behavior to match newer one.
- Router structure reflects versioning explicitly (e.g. `api/v1/routes/`).

## Version control — gitflow (universal)

Every git action follows gitflow — inside a skill AND for ad-hoc commits made
outside one on direct request. The model is universal across all projects.

### Branch model
`main` (prod) · `develop` (integration, off main) · `feature/*` + `bugfix/*` +
`chore/*` (off develop → develop; `chore/*` = memory/doc maintenance, e.g.
standalone `/capitalize` `/prune-memory` `/reconcile`) · `release/*` (off develop →
main + back-merge develop) · `hotfix/*` (off main → main + develop [+ any open
release/*]). `master`→`main` everywhere.

### Rules for every git action
- **Never commit code directly on `main` or `develop`.** Branch first from the
  correct base, named `<type>/<name>`. (`.claude/**` memory/config commits are
  hook-exempt — they follow the work; but *standalone* memory/doc skills branch to
  `chore/*` via the aiguillage rather than lean on that exemption.)
- **Branch + merge via the lib, never by hand** — the directed-merge + hotfix
  fan-out logic lives there once:
  `bash ~/.claude/lib/gitflow.sh start <type> <name>` · `… finish`.
- **`gitflow finish` (merge) only on an explicit human signal** ("merge it",
  "feature OK") — never because tests pass, a plan step says "merge", or a verb
  ("ship") implied it.
- **Assistance flows** (`/feat` `/bugfix` `/hotfix`) AND **standalone memory/doc
  skills** (`/capitalize` `/close` `/prune-memory` `/reconcile`, type `chore`)
  auto-branch on a protected base (the aiguillage); on a working branch they commit
  in place, never finish.
- **New/onboarded projects** get the model + the versioned pre-commit hook via
  `gitflow init` (init-project STEP 5f, onboard STEP 2.6).

### Enforcement layers
Advisory — it can be forgotten on a long conversation (no reliable oracle). The
deterministic backstops are the per-repo **pre-commit hook** (`gitflow init`
installs it: blocks code commits on main/develop, exempts `.claude/**` + merges +
the root commit) and **Gitea branch protection** on `main`/`develop` (set up by
the migration). Don't lean on `--no-verify` to bypass them.

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

# Tooling & skills
## Skill routing

Request matches a skill → invoke via Skill tool first, before any direct
answer or other tool. Most skills route by name — match the request to the
skill whose description fits (full list is in context). Rules below cover
only the non-obvious cases: gstack fallbacks, disambiguation, cryptic names.

- Product idea, "worth building?" → office-hours
- Bug / error / 500 → investigate (bugfix if gstack off)
- feat / hotfix / bugfix distinguished by file count → see descriptions
- Ship / deploy / PR → ship (ship-feature if gstack off)
- Cut a release / tag a version (develop ahead of main) → release-candidate
- Docs post-ship → document-release (doc if gstack off); stale-doc audit → doc
- Audit of changes since last run → audit-delta
- Open-work inventory / "queue empty?" / stale TODO vs real git → reconcile
- Design / UI (build, system, audit, polish) → see "Design work" below
- Architecture review → plan-eng-review
- Before /clear or /compact → capitalize; end-of-session ritual → close
- SEO+GEO → seo (GEO only → geo)
- W3C + WCAG a11y (HTML/CSS validity, axe, pa11y) → web-validate
- Security audit (secrets, CVE, OWASP) → cso
- New project → init-project; onboard existing repo → onboard

gstack OFF → its skills (investigate, ship, qa, review, health, retro,
office-hours, context-save…) are gone: use the fallback above, else say so.

## Design work — full toolchain (tiered by scope)

Trigger = UI work: editing a component/style file (.tsx/.vue/.svelte/.css…)
OR a design/UI request — not the keyword "design" alone in a prompt. Single
source for design routing; the design-toolchain hook reinforces it.
- Trivial (≤2 files, one cosmetic value) → /hotfix, no toolchain.
- Build UI (component, page, redesign) → ui-ux-pro-max + frontend-design
  (anti-slop) + Magic MCP /ui + emil-design-eng (polish) +
  design-motion-principles (if motion) + design-html (if static).
- Design system / brand → design-consultation first, then the build tools.
- Review / audit → design-review + emil-design-eng + design-motion-principles.
Scope doubt → don't silently skip: ask, or default to Build tier.
Gate: lightweight skills run `~/.claude/lib/design-gate.md`; orchestrators via
plugin-check. Magic MCP costs API calls — generation, not micro-tweaks.

## graphify

ALL rules apply only if `graphify-out/graph.json` exists — else read files
directly.
- Codebase-wide question → `graphify query`; relationships → `path A B`;
  concept → `explain`. Scoped subgraph beats raw grep.
- Known file / small task → read directly, no graphify.
- `wiki/index.md` → broad-nav entry; `GRAPH_REPORT.md` → whole-architecture.
- After editing code → `graphify update .` (AST-only, free).

# This repo only (claude-config)

Apply when working directory = the claude-config repo itself.

## Health Stack
- shell: `shellcheck *.sh hooks/*.sh lib/*.sh`
