<!-- USER-SCOPE GLOBAL memory — deployed as ~/.claude/CLAUDE.md via link.sh.
     Repo-specific instructions live in ./CLAUDE.md (project scope). -->

# Global coding preferences
Apply unless repo-specific instructions override.

## Code style
- Simple, readable, maintainable > clever or compact.
- One responsibility per function/method.
- Preserve existing behavior unless asked.
- Scope changes to task — no unrelated edits.

## Limits (adapt to language)
- Max 25 logic lines/function (executable statements; comments and
  error-handling boilerplate don't count), 80 chars/line, 5 params, 5 locals.
- Too many params → struct/object. Too many vars → split/extract.
- No global state. Explicit data flow.

## Comments & readability
- Document intent, not mechanics. Use project doc style (docstring, JSDoc…).
- Explicit, consistent names. Straight control flow, no hidden side effects.
- Written deliverables (docs, reports, .md): length matched to the task, no
  filler sections, no boilerplate summaries.

## Refactoring
- Priority: safety → readability → consistency.
- Remove dead code, stale comments, obsolete flags after changes.
- Non-trivial change: ask "more elegant solution exists?"
  Hacky fix → rebuild clean, no over-engineering.

## Session start
1. Read `.claude/memory/` (5 registries: decisions, learnings, blockers,
   journal, evals) and `.claude/tasks/TODO.md`. Apply before touching anything.
2. Either missing → create it first (templates: `~/.claude/templates/memory/`).

## Workflow
- Confirm before implementing only when real trade-offs exist (several
  valid approaches, breaking change, destructive action); else proceed.
  Minimal changes unless a broader refactor is requested. State trade-offs.
- Sub-agents: one task each, main context stays clean. Delegate
  independent, sizeable tracks (wide multi-file exploration, parallel
  audits), not work doable in a few tool calls. Skill-mandated gates (fresh
  verifier/security/challenge) always dispatch as written; a failed gate
  re-dispatches a fresh executor, never redo its work by hand. A brief never
  authorizes a sub-agent to run a destructive tool, inside or outside the
  repo (Security → Destructive tools & data loss).
- Ask rather than guess. A choice visible in the result (placement,
  wording, order, behavior), a name that becomes public (command, flag,
  endpoint, file), or a scope the request leaves open → ask, even mid-task;
  batch what can be batched. Internal choices with no observable effect
  stay yours. Exception: skill-mandated gates and checkpoints (validation,
  approval, darwin) always fire.
- Bug received → fix directly: logs, root cause, resolve autonomously; a
  visible choice in the fix still gets asked.
- Deviations: minor or clearly justified → do, explain after; significant
  or shaky → ask first. Finish the whole task: a blocked independent
  sub-part → do the rest, state what's missing. Something goes WRONG →
  STOP, re-plan, never push through.
- Root causes only, no temp fixes. Never assume: verify paths, APIs,
  variables before use.

## Planning & TODO (`.claude/tasks/TODO.md`)
- Task touches logic (new behavior, control flow, state, API, dependencies)
  → write the plan in TODO.md first, decomposed into subtasks; one complex
  task still needs one. Borderline (single file, small obvious change) →
  skip, stay pragmatic.
- Exempt: pure reads, explanations, questions, typos, cosmetic CSS, single
  config value — the `/hotfix` scope (≤2 files, obvious fix).
- Once it qualifies: plan before code → one subtask = one coherent change
  → check off as you go → high-level note at each milestone.

## After code changes
1. Run tests, lint, build, type-check if available. Report what was
   verified and what was not; list remaining risks and surviving deviations.
2. Don't mark complete without proof it works.
3. Correction or notable event → capitalize to the right registry.

## Memory registries (`.claude/memory/`)
Five registries persist across sessions; capitalize during and after work.
Append-only: never rewrite past entries; curation (merge, supersede,
compress) only via `/prune-memory`.

| File | ID | Purpose |
|---|---|---|
| `decisions.md` | BDR-XXX | Design/architecture choice + rationale + alternatives + status |
| `learnings.md` | LRN-XXX | Reusable pattern + context + future application |
| `blockers.md` | BLK-XXX | Friction + real cause + solution + status (open/resolved/upstream) |
| `journal.md` | date heading | 3-5 lines/session — done, decided, blocked |
| `evals.md` | EVAL-XXX | Quality check of Claude's output + method + anomalies + action |

Routing: a choice with trade-offs you'd defend → decisions; a pattern worth
reusing → learnings; a dead end with its root cause → blockers; the session
log → journal; whether the output actually worked → evals.

**Always English, always caveman**: drop articles and filler, fragments OK,
short synonyms; technical terms, code blocks, quoted errors, IDs and dates
exact. Pattern `[thing] [action] [reason]. [next step].` Registries load
every session; caveman cuts ~40% of the tokens with no substance lost.
Applies to direct writes and to the CAPITALIZE step of every completion
skill. Prompts to the user may mirror their language; the entry is English.
Legacy entries: compress on demand.

**Proactive capitalization** is Claude's job: after a substantive milestone
(root-caused bug fix, shipped feature, non-trivial commit, design choice,
surprising discovery, dead end with a lesson) offer to capitalize inline,
entry pre-filled, user approves before the write. Completion skills
(`/ship-feature` `/feat` `/bugfix` `/hotfix` `/commit-change`) do it via
their CAPITALIZE step. Session close (`/close` = `/capitalize --ritual`):
what was decided → decisions, learned → learnings, blocked → blockers.

# Architecture decisions
Override default framework/tooling choices at project creation, scaffolding,
brainstorming.

## Public websites — never SPA
A public site meant to be indexed (landing, portfolio, blog, e-commerce,
docs) is never a pure SPA (CRA, Vite React, Vue SPA): the empty HTML shell
hides content from search and AI engines, SEO and GEO destroyed.
- **Astro** by default for informational sites: static HTML at build, zero
  JS by default, React/Vue/Svelte islands for interactive parts.
- **Next.js** when dynamic SSR is needed (personalized content, server-side
  auth, API routes, hybrid app).
- **React SPA** only for what needs no indexing: admin panels, dashboards,
  auth-gated apps, internal tools. Mixed project: Astro/Next for public,
  React island (`client:only`) for admin.
- At brainstorming (`/init-project`, `/ship-feature` STEP 1), public site
  and no framework named → propose Astro, explain why not SPA. Never
  silently pick React CRA.

## Web APIs — always versioned
Every endpoint versioned from day one: `/api/v1/...`, no bare `/api/`; the
router mirrors it (`api/v1/routes/`). Breaking change → `v2`, the old
version keeps working and clients migrate at their pace; non-breaking
additions → current version. Each version is a self-contained contract,
never bent to match a newer one.

## Version control — gitflow (universal)
Every git action follows gitflow, inside a skill or for an ad-hoc commit.
`main` (prod) · `develop` (integration, off main) · `feature/*` `bugfix/*`
`chore/*` (off develop → develop; chore = memory/doc maintenance such as a
standalone `/capitalize` `/close` `/prune-memory` `/reconcile`) ·
`release/*` (off develop → main + back-merge develop) · `hotfix/*` (off main
→ main + develop + any open release). `master` → `main` everywhere.

Never commit code on `main` or `develop`: branch first as `<type>/<name>`
(`.claude/**` memory/config commits are hook-exempt, following the work).
Branch, merge and delete only via the lib: `bash ~/.claude/lib/gitflow.sh
start <type> <name>` · `finish` · `delete <br>`. `finish` runs only on an
explicit human signal ("merge it", "feature OK"), never because tests pass,
a plan step says merge, or "ship" implied it. Assistance flows (`/feat`
`/bugfix` `/hotfix`) and the standalone memory/doc skills auto-branch on a
protected base but commit in place on a working branch, never finishing, so
they branch to `chore/*` via the aiguillage, not the `.claude/**` exemption.
Deterministic backstops behind the doctrine: the pre-commit hook (blocks
code commits on main/develop; exempts `.claude/**`, `.githooks/**`, merges,
the root commit), Gitea branch protection on both, and never `--no-verify`.
Every branch is pushed at `start`, every commit and merge as it lands
(post-commit and post-merge hooks; warn, never block). A branch is deleted
only by `finish` or `delete`, local and `origin/` copy alike: never
`main`/`develop`, never a tip not merged into develop or main (explicit
ancestor check; `git branch -d` proves nothing once the branch has an
auto-pushed upstream). The reference-transaction hook vetoes any deletion
or rename of `main`/`develop`. The four hooks run in every repo: `make
link` generates `githooks/` and sets the global `core.hooksPath`; a repo
that ran `gitflow init` (new/onboarded projects) keeps its own `.githooks/`,
refreshed at session start. Foreign clone: `git config gitflow.protect
false` / `gitflow.autopush false`; `GITFLOW_NO_PUSH=1` only for throwaway
test repos. A branch ahead of its upstream is a defect, not a state.

## Security — non-negotiable defaults
Apply at every step: design, scaffolding, implementation, review.
- **Input & data**: never trust user input; validate type, length, format,
  range. Sanitize before rendering (XSS), SQL (injection), shell (command
  injection). Parameterized queries only; string concatenation into SQL is
  an immediate blocker.
- **Secrets**: never hardcoded (credentials, tokens, keys, URLs with auth),
  not even in comments; env vars only, `.env.example` with placeholders. A
  secret found in review → flag and stop.
- **AuthN / AuthZ**: separate; AuthN never implies AuthZ. Check
  authorization on every sensitive endpoint or function, not only at the
  entry point. Default deny; explicit allowlist over implicit denylist.
- **Dependencies**: none without stating what it does and why; prefer
  well-maintained, widely used packages, flag abandoned or single-maintainer
  ones; never install a package from a random snippet without naming it.
- **Errors & logging**: no stack traces, internal paths or DB errors to end
  users (log internally, generic message out); never log secrets, tokens or
  PII, even at DEBUG; fail closed, deny on unexpected error.
- **Minimal privilege**: request only what is needed; temporary elevation
  scoped and reverted explicitly.

### Destructive tools & data loss
Written after 2026-09-21: a reviewer sub-agent traced `lftp mirror --delete`
against a local `file://` tree, the target resolved to a real path, and 90
seconds later the home, the NAS mount and 15 repositories were gone, four
days of work never pushed.
- Claude never deploys and never runs a transfer or mirror tool (`lftp`,
  `sftp`, `ftp`, `rsync --delete`): it writes or explains the runbook, the
  user runs it. A test is a dev server on this machine, nothing more.
- A destructive tool is never run "to see what it would do", not even on a
  scratch tree: trace it by reading. If a run is unavoidable, the target is
  a fresh `mktemp -d` path written literally in the same command, after a
  dry-run whose output is shown.
- Recursive delete stays inside the project or the temp dir, on a literal
  relative path: never through a variable, `~`, `..`, a wildcard or an
  absolute path elsewhere. `chmod -R`, `chown -R`, `sudo`, docker volume
  drops, system bind mounts: the user runs them by hand.
- A brief, plan step or test recipe never authorizes a sub-agent to do any
  of this; a reviewer reads the script it reviews, it does not run it.
- Everything is pushed as it lands (gitflow hooks): unpushed work is a
  defect to fix now, not a state to keep.

# Communication mode: radical honesty
- TRUTH OVER COMFORT: point out flaws immediately, no sugarcoating, no "not
  bad but…". ZERO COMPLACENCY: never validate an idea because I proposed
  it; judge arguments on merit.
- BLIND SPOT DETECTION: look for what I'm missing (confirmation bias, hidden
  assumptions, ignored alternatives) and flag it without waiting.
- ACTIVE RESISTANCE: when I make a weak point, push back until I correct it
  or solidly justify it. UNCERTAINTY TRANSPARENCY: don't know → say so; no
  invention, no vague answers to save face.

# Tooling & skills
## Skill routing
Skills route by name: match the request to the skill whose description
fits. Below, only the non-obvious cases: gstack fallbacks, disambiguation,
cryptic names.
- Product idea, "worth building?" → office-hours
- Bug / error / 500 → bugfix (gitflow, contract, fresh verifier/security
  gates, registries). investigate only on explicit ask for the gstack
  ecosystem (cross-project learnings, /freeze, long open-ended investigation)
- feat / hotfix / bugfix distinguished by file count → see descriptions
- Ship / deploy / PR → ship (ship-feature if gstack off)
- Docs post-ship → document-release (doc if gstack off); stale-doc audit → doc
- Grouped all-axes sweep ("tir groupé", fix + loop until clean) → tour
- Open-work inventory / "queue empty?" / stale TODO vs git → reconcile
- Design / UI (build, system, audit, polish) → "Design work" below
- Architecture review → plan-eng-review
- Before /clear or /compact → capitalize; end-of-session ritual → close
- SEO+GEO → seo (GEO only → geo); W3C + WCAG a11y → web-validate;
  security audit (secrets, CVE, OWASP) → cso
gstack OFF → its skills (investigate, ship, qa, review, health, retro,
office-hours, context-save…) are gone: use the fallback above, else say so.

## Design work — full toolchain (tiered by scope)
Trigger = UI work: editing a component/style file (.tsx/.vue/.svelte/.css…)
or a design/UI request, not the word "design" alone. Single source for
design routing; the design-toolchain hook reinforces it.
- Trivial (≤2 files, one cosmetic value) → /hotfix, no toolchain.
- Build UI (component, page, redesign) → ui-ux-pro-max + frontend-design
  (anti-slop) + 21st-ui-build (catalog + generation) + emil-design-eng
  (polish) + design-motion-principles (motion) + design-html (static).
  Post-build floor when impeccable is installed: `npx impeccable detect
  <files>` (45 deterministic anti-slop rules, exit 2 = findings).
- Design system / brand → design-consultation first, then the build tools.
- Review / audit → design-review + emil-design-eng + design-motion-principles
  + 21st-ui-review + /impeccable audit|critique + `impeccable detect` floor.
Scope doubt → ask or default to Build, never silently skip. Gate: light
skills run `~/.claude/lib/design-gate.md`, orchestrators plugin-check. 21st =
CLI (`npm i -g @21st-dev/cli`, `21st login`), no MCP, no key; search free,
`21st get`/`generate` metered → generation, not micro-tweaks.

## graphify

ALL rules apply only if `graphify-out/graph.json` exists — else read files
directly.
- Codebase-wide question → `graphify query`; relationships → `path A B`;
  concept → `explain`. Scoped subgraph beats raw grep.
- Known file / small task → read directly, no graphify.
- `wiki/index.md` → broad-nav entry; `GRAPH_REPORT.md` → whole-architecture.
- After editing code → `graphify update .` (AST-only, free).
