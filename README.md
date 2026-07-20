# claude-config

One repo that turns Claude Code into a reproducible engineering system —
skills, agents, hooks, plugins, and per-project memory, versioned and
symlinked into `~/.claude/`. Clone it on any machine, run one command,
and every project gets the same assistant with the same rules.

## What it is

Not a collection of prompts — an operating layer on top of Claude Code:

- **Skills** (`/feat`, `/bugfix`, `/ship-feature`, `/seo`, `/tour`…) are the
  entry points: each one encodes a complete workflow, from quick fix to
  full feature pipeline with validation gates.
- **Agents** are the execution units skills dispatch to — each pinned to
  the cheapest model that can do the job (haiku collects, sonnet executes,
  opus judges, the session model only reflects).
- **Hooks and permissions** are deterministic guardrails: gitflow enforced
  by a pre-commit hook, deny-first permission rules, secrets kept in
  `~/.claude/.env` and never in config files.
- **Templates and memory** seed every project with persistent registries
  (decisions, learnings, blockers) — what a session learns, the next
  session knows.

## How it works

```bash
git clone --recurse-submodules https://github.com/bchanot/claude
cd claude
make install     # CLI + auth + symlinks + plugins (pinned in plugins.lock.json)
make doctor      # verify everything
```

`link.sh` symlinks the repo into `~/.claude/`, so editing here updates the
live config — and `git log` is the audit trail of your entire setup.
Day to day:

```bash
/onboard            # bring an existing repo into the framework
/ship-feature "…"   # brainstorm → plan → adversarial challenge → TDD → review → merge
/feat "…"           # same idea, 1-5 files, no ceremony
/close              # flush decisions and learnings to memory before quitting
make update         # keep CLI, plugins, and submodules current
```

## Why it's good

- **Reproducible.** One clone rebuilds the whole environment; versions are
  locked, `make doctor` proves it works.
- **Cost-shaped.** Model tiering routes reflection to the big model and
  execution to cheap ones — the expensive context does only what it must.
- **Safe by default.** Protected branches, ask-before-run on risky tools,
  parameterized secrets: the guardrails are code, not good intentions.
- **It compounds.** Memory registries, audit skills, and doc-sync keep every
  project's knowledge growing across sessions instead of evaporating.

---

Everything below is the reference manual — model routing, components,
commands, settings, secrets, maintenance.

---

## Agent model routing (model-tiering v2)

Doctrine: the session model (Fable) does main-loop reflection ONLY —
brainstorm, plan, contract, audit judgment, gates, loop decisions — enforced
by a blocking gate (`lib/model-gate.md` + `lib/model-check.sh`) at the entry
of the 13 reflection orchestrators. Nothing dispatched inherits silently:
typed agents carry a frontmatter pin, built-ins get an explicit `model=` at
every call site.

| Agent | Model | Tier |
|---|---|---|
| feater, hotfixer, bugfixer | sonnet (pinned) | executors — code from a closed plan (feat), fix from a closed diagnosis (bugfix), fix-bundle appliers |
| verifier, security-auditor | sonnet (pinned) | fresh gates (≤3×/loop) |
| commit-changer, release-executor, code-cleaner | sonnet (pinned) | dispatched execution — grouping+commit / release spans / approved cleanup (audit + approval gates stay in the dispatcher) |
| onboarder, scaffolder, refactorer, validator-analyzer, plugin-probe | sonnet (pinned) | workers — config generation, scaffold, refactor, deterministic W3C/WCAG runner, mechanical plugin probe |
| status-reporter | haiku (pinned) | mechanical collector |
| analyzer, plan-challenger, plugin-advisor | opus (pinned) | dispatched judgment — pre-plan analysis, 3-lens adversarial plan challenge (`/ship-feature` STEP 2b), plugin-fit reasoning |
| seo-analyzer, geo-analyzer | opus pin (judge mode); collect/template spans dispatched `model="sonnet"` | 3-mode audit pipelines — judgment fail-closed on opus, mechanical collect + templating on sonnet |
| doc-syncer | sonnet pin; audit mode dispatched `model="opus"` | two-mode: audit (drift judgment, opus) / patch (mechanical apply, sonnet) |
| handover-doc-writer | sonnet pin; synthesize mode dispatched `model="opus"` | two-mode: synthesize (opus) / render (sonnet) — client deliverable |
| interviewer, client-handover-writer | unpinned (inline-load = session model) | they ARE the main loop — a frontmatter pin would be inert |
| Explore (built-in) | inherit session (Fable/Opus) | search feeds reflection — kept on the big model, not pinned down |

The pure-execution skills `/doc`, `/status`, `/commit-change`,
`/release-candidate` **dispatch** their agent (instead of inline-loading it)
so the pin takes effect and the work leaves the big session model; `/hotfix`
was split like `/feat` (reflection inline + gate, `hotfixer` executor) and so
joins the gated group (13th); `/client-handover`'s nested skill-runner
children are dispatched `model:"fable"` (they carry reflection).

---

## Install notes

All scripts use their own location to find the repo — run them from anywhere.
The plugins step logs to `install-YYYYMMDD-HHMMSS.log`.

**Optional — Context7** (fast doc lookup for React / Next.js / Prisma…): the plugins
step installs the `ctx7` CLI and wires it into Claude Code. The doc-fetch surface is
the `find-docs` skill alone (the generated `rules/context7.md` is purged by
design; if you run `ctx7 setup` manually, delete that rule or re-run `make plugin`).
A once-per-session `ctx7-reminder` hook nudges toward it when the current project
carries fast-moving libs (`lib/fast-libs.sh`) — a scoped second surface, a
refinement of the single-surface rule, not a reversal.

```bash
ctx7 login                 # optional: OAuth / API key for higher rate limits
```

---

## Installed components

| Component | Type | Description | Docs |
|---|---|---|---|
| **Superpowers** | Plugin (required) | Brainstorming, planning, subagent-driven dev, code review, branch finishing. Required by `/init-project` and `/ship-feature`. | [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace) |
| **GStack** | Plugin (toggle) | Full-product workflow: UI + design + deploy + browser QA. Skip for backend/CLI projects. | [garrytan/gstack](https://github.com/garrytan/gstack) |
| **GSD v2** | External CLI | Multi-session orchestration: crash recovery, cost tracking, parallel workers, context-fresh execution. | [gsd-build/gsd-2](https://github.com/gsd-build/gsd-2) |
| **RTK** | Plugin (always on) | Code rewrite hook. Zero passive cost. | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) |
| **security-guidance** | Plugin (always on) | Security hook. Zero passive cost. | [anthropics/claude-code](https://github.com/anthropics/claude-code) |
| **ui-ux-pro-max** | Plugin (toggle) | Design system, color/typography choices. Enable for design-heavy projects. | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) |
| **Context7** | Plugin (toggle) | Fast-evolving libs doc lookup (Next.js, React, Prisma...). Works anonymously; optional `ctx7 login` raises rate limits. | [context7.com](https://context7.com/) |
| **pr-review-toolkit** | Plugin (toggle) | Multi-agent PR review. | [anthropics/claude-code](https://github.com/anthropics/claude-code) |
| **Graphify** | Python CLI | Codebase → knowledge graph → navigable wiki. Helps Claude map and search projects efficiently. | [pypi: graphifyy](https://pypi.org/project/graphifyy/) |

Versions are pinned in `plugins.lock.json`. To update: edit the file, then re-run `install-plugins.sh`.

Graphify installs via **pipx/PyPI only, never npm/npx**: a different publisher
squats the same `graphifyy` name on npm (version-shadowing shim re-exporting
a different package, ships its own conflicting `graphify` bin) — see
`plugins.lock.json`'s `graphifyy` note.

---

## Slash commands

| Command | Description |
|---|---|
| `/init-project` | Initialize a complete project from scratch (full orchestrator, 12+ steps) |
| `/ship-feature` | Ship a feature end-to-end with validation gates (full orchestrator) |
| `/onboard` | Onboard an existing project — generate CLAUDE.md, settings, .claudeignore |
| `/feat` | Small feature implementation (1-5 files, lightweight) |
| `/bugfix` | Structured bug fix with root cause investigation |
| `/hotfix` | Quick fix for superficial bugs (typos, CSS, config — max 2 files) |
| `/analyze` | Deep factual analysis of code before any modification |
| `/refactor` | Improve code quality without changing behavior |
| `/code-clean` | Dead code removal, style/norm enforcement |
| `/doc` | Documentation audit and sync — detect stale docs, patch |
| `/seo` | Full SEO/GEO audit — real Search Console + CrUX field data when a Google account is connected (`make seo-connect`) |
| `/impeccable` | Design verbs (audit, polish, bolder…) + deterministic anti-slop detector (`npx impeccable detect`) |
| `/commit-change` | Smart commit grouping from staged/unstaged changes |
| `/gitflow` | Gitflow branch operations — bootstrap main+develop, start a typed branch, directed merge |
| `/release-candidate` | Cut a versioned release — finalize version.txt + CHANGELOG, merge develop→main, tag, push |
| `/deploy` | Run a project's deploy from its committed runbook — instantiate the delta, resume cold |
| `/graphify` | Codebase knowledge graph — navigation for large-scope tasks |
| `/plugin-check` | Check active plugins vs project needs — recommend enable/disable |
| `/health` | Code quality dashboard (gstack) — setup diagnostic is `make doctor` |
| `/status` | Consolidated project snapshot — plugins, git, GSD milestone |
| `/skills-perso` | List personal (user-created) skills |
| `/audit-delta` | Recurring audit of changes since last run (norms, bugs, dead code, security) |
| `/capitalize` | Flush uncapitalized context + reconcile TODO before /clear or /compact (`--ritual` adds the end-of-session reflection) |
| `/prune-memory` | Curate and compress the .claude/memory/ registries |
| `/reconcile` | Confront declared status (TODO, registries) against real git/fs state — surface stale items |
| `/pdf-translate` | Translate a PDF to another language, output as HTML (via Vision) |
| `/close` | End-of-session ritual — alias for `/capitalize --ritual` (dedup + TODO reconcile + 3-question reflection) |
| `/harden` | Web hardening audit — HTTPS/TLS, HSTS, CSP, security headers |
| `/web-validate` | W3C HTML/CSS validity + WCAG 2.1 accessibility audit |
| `/geo` | GEO-only audit — AI-search visibility (ChatGPT, Perplexity, Claude, Gemini…) |
| `/client-handover` | Final project delivery — audits + branded deliverable (Markdown / HTML / PDF) |
| `/profile` | Activate a skill profile (web / seo / web-full / full / backend / design / dev / qa / audit / minimal) |
| `/tour` | Grouped all-axes sweep — cleanup + security + reconcile + doc, fix and loop until clean |

> This table lists personal skills. Gstack skills (investigate, review, retro,
> office-hours, context-save, context-restore, cso…) and marketplace plugins add
> many more — run `/skills-perso` to list your hand-written skills, or browse `skills/`.

---

## Three core workflows

### From scratch — `/init-project`

```
/plugin-check "description"     # configure plugins (also runs as STEP 0)
/init-project "description"     # interview → scaffold → implement → review
/ship-feature "next feature"    # ship feature by feature
```

### Existing project — `/onboard`

```
cd my-existing-project/
/onboard                        # generates CLAUDE.md + settings + .claudeignore
/plugin-check "project type"
/ship-feature "next feature"
```

### New feature — `/ship-feature`

```
/ship-feature "feature description"
# → STEP 0: plugin check
# → STEP 1-2: brainstorm + plan (superpowers)
# → STEP 2b: adversarial plan-challenge (3 lenses, report-only)
# → STEP 3: validation gate — user approval required
# → STEP 4-7: implement (TDD) → review → capitalize (memory)
# → STEP 8: sync README (doc-sync)
# → STEP 9: finish (merge / PR)
```

For small features (1-5 files), use `/feat` instead — no orchestration overhead.

---

## Settings and permissions

Settings follow a hierarchy (highest priority first):

```
managed-settings.json   → enterprise (cannot be overridden)
CLI flags               → session only
.claude/settings.local  → personal machine overrides (gitignored)
.claude/settings.json   → project rules (committed)
~/.claude/settings.json → global user rules (this repo)
```

DENY always wins over ALLOW at any level. `.claudeignore` applies independently.

Templates for per-project settings are in `templates/settings/`. Copy them with `/onboard` or manually:
```bash
CONF="$(dirname "$(readlink ~/.claude/CLAUDE.md)")"
cp "$CONF/templates/settings/settings.json" .claude/settings.json
cp "$CONF/templates/settings/.claudeignore" .claudeignore
```

See [`templates/settings/SETTINGS.md`](templates/settings/SETTINGS.md) for the full rule syntax reference (rule types, patterns, `defaultMode` values).

---

## Adding an MCP server that needs a secret

`claude mcp add <name> --env KEY=VALUE ...` writes `VALUE` **literally** into
`~/.claude.json` (or the project's `.mcp.json`) — if you pass the real secret
on that command line, it materializes as a second plaintext copy outside
`~/.claude/.env`, invisible to the repo's `.gitignore`/allowlist reach (this
bit us once).

Claude Code expands `${VAR}` and `${VAR:-default}` in `mcpServers` config —
in `env`, `command`, `args`, `url`, and `headers` — for both project (`.mcp.json`)
and user (`~/.claude.json`) scope. Use that instead of a literal value:

```bash
MAGIC_API_KEY=<Enter your magic api key here from https://21st.dev/settings/api-keys >
# single-quoted so bash doesn't expand it; Claude Code expands it at
# launch, reading the var from its own process environment:
claude mcp add magic --scope user --env 'API_KEY=${MAGIC_API_KEY}' -- npx -y @21st-dev/magic@latest
```

The var still has to exist in the **environment of the process that starts
`claude`** — sourcing `~/.claude/.env` into your everyday interactive shell
would defeat the point (every subprocess, every stray `env`/`printenv`, would
then see it). This repo's `~/.bashrc` instead wraps the `claude` command
itself: a `claude()` shell function sources `~/.claude/.env` into a subshell
and `exec`s the real binary, so the var reaches `claude` and its children only
— never the ambient shell. See `lib/toggle-external.sh`'s `magic` case for
the pattern to copy for a new MCP server.

There is no `claude mcp add` flag that writes the reference form for you —
the `${VAR}` syntax has to be typed by hand (or via a wrapper script), same as
above.

### SEO data layer (`/seo` FULL) — Google OAuth + CrUX keys

The same `~/.claude/.env` also feeds `lib/seo-data`, which pulls real Google
Search Console and Chrome UX Report data into `/seo` FULL audits. Add these
three vars (template with the GCP console steps in `.env.example`):

```bash
# OAuth Desktop client — GCP console → APIs & Services → Credentials →
# OAuth client (Desktop). Consent scope: webmasters.readonly only.
GOOGLE_OAUTH_CLIENT_ID=<your-client-id.apps.googleusercontent.com>
GOOGLE_OAUTH_CLIENT_SECRET=<your-client-secret>
# CrUX + PageSpeed API key — GCP console → Credentials → API key,
# restricted to those two APIs. https://developer.chrome.com/docs/crux/api
CRUX_API_KEY=<your-crux-api-key>
```

Then run the one-time consent flow: `make seo-connect` (per-label token
store, multi-site safe). Missing credentials never break an audit — `/seo`
degrades gracefully to anonymous PageSpeed lab data.

### magic MCP (`@21st-dev/magic`) — known callback-injection risk

`21st_magic_component_builder` opens an **unauthenticated** local callback
server (`127.0.0.1:9221+`, `Access-Control-Allow-Origin: *`, no token/origin
check) for up to 10 minutes per call; any local process or open browser tab
can `POST` to it and that body is injected **verbatim** into the tool result
the model consumes (job8 audit, `dist/utils/callback-server.js:36`). This is
in the third-party package's code, not this repo's config — **we don't patch
it**. The mitigation lives entirely on our side: `settings.json`
`permissions.ask` explicitly lists all 4 `mcp__magic__*` tools,
so every call — builder included — requires a live confirmation and can
never auto-execute. Don't allowlist
`21st_magic_component_builder` or `21st_magic_component_refiner` (arbitrary
absolute-path read → vendor exfil, same audit) under any circumstance.

---

## Diagnostic and maintenance

```bash
# Terminal
bash doctor.sh              # full diagnostic (symlinks, plugins, permissions, token budget)
bash update-all.sh          # update all components (CLI, plugins, submodules, symlinks)

# Claude Code
/health                     # gstack code-quality dashboard (doctor.sh -> make doctor)
/status                     # project snapshot (plugins, git, GSD milestone)
/plugin-check "description" # audit plugin config vs project needs

# Makefile (from repo directory)
make install                # bootstrap: CLI + auth + symlinks + plugins
make plugin                 # install plugins only
make link                   # create/update symlinks into ~/.claude/
make doctor                 # diagnostic
make update                 # update Claude Code, config, submodules, plugins, and verify
make test                   # run deterministic tests (lib/tests/*.test.sh + lib/seo-data/*.test.sh + lib/gitflow-test.sh + lib/tests/run-*.sh)
make onboard                # onboard an existing project (run from its dir)
make seo-connect            # connect a Google account for /seo FULL (OAuth consent)
make profile cmd="set X"    # activate a skill profile (web/seo/web-full/full/backend/design/dev/qa/audit/minimal)
make profile-list           # list skill profiles
make profile-current        # show the active profile
make profile-reset          # re-enable all gstack skills
make new-skill name=myskill # scaffold agent + skill files
```

`doctor.sh` checks: symlinks, GStack submodule, prerequisites (git, Node, Cargo, Python, Claude Code), plugins, permissions, token budget, config consistency.

---

## Going further

[`USAGE.md`](./USAGE.md) — workflows and skill decision tree ·
[`ARCHITECTURE.md`](./ARCHITECTURE.md) — layout and principles ·
[`CHANGELOG.md`](./CHANGELOG.md) — version history.
