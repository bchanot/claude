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
  by a pre-commit hook in every repo (`make link` points git's global
  `core.hooksPath` at `~/.claude/githooks`), every commit pushed by
  post-commit and post-merge hooks, `main`/`develop` undeletable by a reference-transaction hook,
  deny-first permission rules, secrets kept in `~/.claude/.env` and
  never in config files.
- **Templates and memory** seed every project with persistent registries
  (decisions, learnings, blockers, journal, evals) — what a session
  learns, the next session knows.

## How it works

```bash
git clone --recurse-submodules https://git.bchanot.fr/bchanot/claude
cd claude
make install     # CLI + auth + symlinks + plugins (pinned in plugins.lock.json)
make doctor      # verify everything
```

`link.sh` symlinks the repo into `~/.claude/`, so editing here updates the
live config — and `git log` is the audit trail of your entire setup.
Day to day:

```bash
/onboard            # bring an existing repo into the framework
/ship-feature "…"   # brainstorm → plan → adversarial challenge → TDD → verify + security gates → review → merge on your go
/feat "…"           # same idea, 1-5 files, no ceremony
/close              # flush decisions and learnings to memory before quitting
make update         # keep CLI, plugins, and submodules current
```

## Why it's good

- **Reproducible.** One clone rebuilds the whole environment; versions are
  locked, `make doctor` proves it works.
- **Cost-shaped.** Model tiering routes reflection to the big model and
  execution to cheap ones — the expensive context does only what it must.
- **Safe by default.** Protected branches, deny rules and auto-mode soft/hard blocks on
  risky tools, transfer and mirror tools denied outright, parameterized
  secrets: the guardrails are code, not good intentions.
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
of the 15 reflection skills (the orchestrators plus `/analyze`). Nothing dispatched inherits silently:
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
joins the gated group; `/client-handover`'s nested skill-runner
children are dispatched `model:"fable"` (they carry reflection).

## Effort routing (BDR-107, BDR-108)

Second axis of the same table: how hard each phase thinks. Session default
`high`. Every typed agent carries an `effort:` pin next to its `model:` (low
appliers, medium executors, high judgment, xhigh challengers and gates; none
on haiku, which rejects the parameter). Every user-invoked skill carries an
entry level (`/status` low … `/ship-feature` xhigh); the vendored externals
(design stack, superpowers, agent-skills, MengTo scroll skills, 21st) get theirs from
`lib/effort-pins.txt`, re-applied by `lib/effort-pins.sh` after every
vendoring step. Orchestrators shift per phase through the `effort-low` …
`effort-max` skills (`lib/effort-shift.md`, always sent with another tool
call: a lone Skill call applies nothing). Model pins stay tier aliases
(`sonnet`, `opus`, `haiku`, `fable`): the latest version of a tier is also
the cheapest or same-priced, so the quality/price trade-off is tier × effort,
never version. Census `lib/tests/effort-routing.test.sh`; transcript audit
`python3 lib/effort-audit.py`.

---

## Install notes

All scripts use their own location to find the repo — run them from anywhere.
The plugins step logs to `install-YYYYMMDD-HHMMSS.log`.
The last step applies the default profile, `full`, when none is selected, and re-applies an existing selection.

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
| **Superpowers skills** | Vendored (7, always on) | brainstorming, writing-plans, subagent-driven development, TDD, code review request, git worktrees, writing-skills — pinned v6.4.1 in plugins.lock.json, no plugin, no session injection | [obra/superpowers](https://github.com/obra/superpowers) |
| **GStack** | Git submodule (per profile) | Product workflow skills: plan reviews, design, browser QA, security (`cso`), `health`. Linked per profile; 9 broken or doctrine-breaking skills are denylisted in `lib/gstack-removed.sh`. | [garrytan/gstack](https://github.com/garrytan/gstack) |
| **GSD v2** | External CLI | Multi-session orchestration: crash recovery, cost tracking, parallel workers, context-fresh execution. | [gsd-build/gsd-2](https://github.com/gsd-build/gsd-2) |
| **RTK** | CLI + hook (always on) | Rust Token Killer: the `hooks/rtk-rewrite.sh` PreToolUse hook rewrites Bash commands through `rtk` to cut output tokens. Zero passive cost. | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) |
| **security-guidance** | Plugin (always on) | Security hook. Regex layer and commit/push review on; the Stop-time diff review is off (`ENABLE_STOP_REVIEW=0`). | [anthropics/claude-code](https://github.com/anthropics/claude-code) |
| **ui-ux-pro-max** | Plugin (toggle) | Design system, color/typography choices. Enable for design-heavy projects. | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) |
| **Context7** | CLI (`ctx7`) | Doc lookup for fast-evolving libs (Next.js, React, Prisma...), used through the `find-docs` skill. Works anonymously; optional `ctx7 login` raises rate limits. | [context7.com](https://context7.com/) |
| **pr-review-toolkit** | Plugin (toggle) | Multi-agent PR review. | [anthropics/claude-code](https://github.com/anthropics/claude-code) |
| **Graphify** | Python CLI | Codebase → knowledge graph → navigable wiki. Helps Claude map and search projects efficiently. | [pypi: graphifyy](https://pypi.org/project/graphifyy/) |
| **21st.dev** | External CLI + skill pack | Component catalog and UI generation (`21st`), browser login, no API key. 7 skills in `skills-external/21st-*`, linked per profile (see the 21st.dev CLI section). | [npm: @21st-dev/cli](https://www.npmjs.com/package/@21st-dev/cli) |
| **Higgsfield** | External CLI + skill pack (off by default) | Image, video, audio and brand media generation, metered credits (see the Higgsfield CLI section). | [higgsfield-ai/skills](https://github.com/higgsfield-ai/skills) |
| **Semgrep** | Python CLI (pinned) | SAST engine behind the security gate (`security-auditor`). | [pypi: semgrep](https://pypi.org/project/semgrep/) |
| **Impeccable** | npm CLI + skill (pinned) | Deterministic anti-slop detector (`npx impeccable detect`, 45 rules) and the `/impeccable` design verbs. | [npm: impeccable](https://www.npmjs.com/package/impeccable) |
| **Design skills** | Vendored | `emil-design-eng`, `frontend-design` (Anthropic example-skills), `design-motion-principles`: UI polish, anti-slop build, motion. | [emilkowalski/skill](https://github.com/emilkowalski/skill) · [kylezantos/design-motion-principles](https://github.com/kylezantos/design-motion-principles) |
| **agent-skills** | Vendored (commit-pinned) | `observability-and-instrumentation`, `deprecation-and-migration`, `ci-cd-and-automation`. | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) |
| **MengTo scroll skills** | Vendored (commit-pinned) | Five scroll-choreography skills: `scroll-world-storytelling`, `build-threejs-scroll-worlds`, `scroll-scrubbed-visual-sequence`, `scroll-scrubbed-word-reveal`, `scroll-progress-timeline`. | [MengTo/Skills](https://github.com/MengTo/Skills) |

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
| `/onboard` | Onboard an existing project: CLAUDE.md, settings, .claudeignore, archetype audits, report and a sequenced TODO backlog |
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
| `/deploy` | Compose the deploy checklist from a project's committed runbook (delta only); you run it, the skill resumes cold on your report |
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
| `/profile` | Activate a skill profile (web / seo / web-full / full / max / backend / design / dev / qa / audit / minimal) (default: full) |
| `/tour` | Grouped all-axes sweep — cleanup + security + reconcile + doc, fix and loop until clean |
| `/site-motion` | Site-level motion: scroll engine choice, page transitions, pin/scrub sequencing across a page or Astro route (design stack) |
| `/effort-low` … `/effort-max` | Effort shifters the orchestrators send per phase; type `/effort-max` to re-run a stuck turn at maximum |

> This table lists personal skills. Gstack skills (investigate, review, retro,
> office-hours, cso…) and marketplace plugins add many more — run
> `/skills-perso` to list your hand-written skills, or browse `skills/`.

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
# → STEP 0: plugin check, project context, contract
# → STEP 1-2: brainstorm + plan (vendored superpowers skills)
# → STEP 2b: adversarial plan-challenge (3 lenses, report-only)
# → STEP 3: validation gate — user approval required
# → STEP 4: implement (TDD)
# → STEP 5: verify + secure (fresh verifier and security-auditor gates)
# → STEP 6-7: review → capitalize (memory)
# → STEP 8: doc sync (public docs, committed before finish)
# → STEP 9: finish, `gitflow finish` into develop on your explicit go
```

For small features (1-5 files), use `/feat` instead — no orchestration overhead.

---

## Settings and permissions

Settings follow a hierarchy (highest priority first):

```
managed-settings.json   → enterprise (cannot be overridden)
CLI flags               → session only
.claude/settings.local.json → personal machine overrides (gitignored)
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
# single-quoted so bash doesn't expand it; Claude Code expands it at
# launch, reading the var from its own process environment:
claude mcp add <name> --scope user --env 'API_KEY=${SOME_API_KEY}' -- <command>
```

The var still has to exist in the **environment of the process that starts
`claude`** — sourcing `~/.claude/.env` into your everyday interactive shell
would defeat the point (every subprocess, every stray `env`/`printenv`, would
then see it). Wrap the `claude` command instead: a `claude()` shell function
that sources `~/.claude/.env` into a subshell and `exec`s the real binary, so
the var reaches `claude` and its children only, never the ambient shell.

This config registers no MCP server today. The pattern stays documented for
the next one that needs a secret.

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

### 21st.dev CLI

`@21st-dev/cli` (bin `21st`) is the 21st.dev integration; it replaced the
former Magic MCP server this config used to register. Same endpoint, one
browser login, no API key, and nothing loaded into a session that isn't using
it:

```bash
npm i -g @21st-dev/cli
21st login                  # browser flow, token saved in ~/.config/21st
```

`make plugin` does both (Step 8.7 installs the CLI, then offers the login in
an interactive terminal) and installs the skill pack that drives it:
`21st-ui-build`, `-ui-explore`, `-ui-review`, `-cli-use`, `-ai`, plus the two
publishing skills `-registry` and `-design-sync`. Of the five design skills, `21st-ui-build` and
`21st-cli-use` follow the active profile: on under `full`, the default profile, and under `design`,
`web` and `web-full`. The other three, `-ui-explore`, `-ui-review` and
`-ai`, are on under `max` only. The two publishing skills,
`-registry` and `-design-sync`, are in no profile and stay parked until
`bash lib/toggle-external.sh enable 21st` turns on all seven.

The pack is machine-owned and gitignored. It cannot be installed the way
upstream documents it (`21st install-skill`, i.e. `21st skills install
--global`): that writes into `~/.claude/skills/`, and the installer refuses to
follow a symlink anywhere on that path, while `~/.claude/skills` is itself a
symlink to this repo's `skills/`. So the install runs under a throwaway `HOME`
and the result is moved into `skills-external/21st-*`, where
`toggle-external.sh` and `profile.sh` symlink it in on demand.

The permission gate is now one `autoMode.soft_deny` entry covering the
outward-facing verbs (`21st publish*`, `submit`, `edit`, `delete`,
`remove-from-catalog`, `profile set|upload`), because publishing a component
puts it on a public listing under your account. That tier rather than `ask`:
under `defaultMode: auto` (this config's default) `ask` rules were observed
auto-approving with no prompt raised (LRN-153), so an `ask` entry would have
declared an intent without gating anything.

### Higgsfield CLI

`@higgsfield/cli` (bins `higgsfield` and `higgs`) generates images, video,
audio and brand media from the terminal. One browser login, no API key.
Generation spends account credits.

```bash
npm i -g @higgsfield/cli
higgsfield auth login       # browser flow
```

`make plugin` does both (Step 8.6 installs the CLI, then offers the login in
an interactive terminal) and clones the skills of
[higgsfield-ai/skills](https://github.com/higgsfield-ai/skills) into
`skills-external/higgsfield-*`. `make update` refreshes the skills, and the
CLI when npm installed it; `make doctor` reports the CLI and its session.
The copies are machine-owned and gitignored. They follow upstream `main`,
so a prompt change arrives with no diff to review, and a skill that
upstream removes keeps its last local copy.

The pack is off by default and belongs to no profile. It costs nothing until
you ask for it, and no `profile set` touches it:

```bash
bash lib/toggle-external.sh enable higgsfield            # media skills
bash lib/toggle-external.sh enable higgsfield-websites   # landing-page aid
bash lib/toggle-external.sh disable higgsfield
bash lib/toggle-external.sh disable higgsfield-websites
```

`higgsfield` links a fixed list of seven media skills: generate, soul-id,
product-photoshoot, brandkit, marketplace-cards, video-explainer and
youtube-thumbnail. The list is `HIGGSFIELD_MEDIA_SKILLS` in
`lib/toggle-external.sh`. A skill that upstream adds later is synced, and
every `enable higgsfield` names it, the pack being on or not. It stays
unlinked until it is added to the list.

`higgsfield-websites` is kept apart. It helps with landing pages inside the
design stack (assets, references), and `higgsfield website
create|deploy|publish` stays unused. Claude enables either toggle itself on
an explicit ask (Skill routing in `CLAUDE.global.md`) and checks the price
with `higgsfield generate cost` before a paid run.

The skills are cloned, not installed with `npx skills add`: that installer
links every skill into `~/.claude/skills` on each refresh, which would undo
the off-by-default state.

After the first login, select a workspace once: `higgsfield workspace list`,
then `higgsfield workspace set <id>`. Until then the account commands answer
"No workspace selected", even though the session is active.

The package ships its binary through a postinstall script. If npm holds that
script back, `higgsfield` exists on PATH and fails at once; reinstall with
`npm install -g --allow-scripts=@higgsfield/cli @higgsfield/cli`.

---

## Diagnostic and maintenance

```bash
# Terminal
bash doctor.sh              # full diagnostic (symlinks, plugins, permissions, token budget)
bash update-all.sh          # update all components (CLI, plugins, submodules, symlinks)

# Claude Code
/health                     # gstack code-quality dashboard (setup diagnostic: make doctor)
/status                     # project snapshot (plugins, git, GSD milestone)
/plugin-check "description" # audit plugin config vs project needs

# Makefile (from repo directory)
make install                # bootstrap: CLI + auth + symlinks + plugins
make plugin                 # install plugins only
make link                   # create/update symlinks into ~/.claude/
make doctor                 # diagnostic
make update                 # update Claude Code, config, submodules, plugins, and verify
make test [suite=lib/tests/x.test.sh]  # hermetic deterministic tests: every suite, or one
make scan-secrets [repos="…"]  # gitleaks sweep of this repo's history and ~/.claude, reports in .audit/ (never committed)
make help                   # list make targets
make onboard                # onboard an existing project (run from its dir)
make seo-connect            # connect a Google account for /seo FULL (OAuth consent)
make profile cmd="set X"    # activate a skill profile (web/seo/web-full/full/max/backend/design/dev/qa/audit/minimal)
make profile-list           # list skill profiles
make profile-current        # show the active profile (full when none selected)
make profile-reset          # go to the default profile (full)
make new-skill name=myskill # scaffold agent + skill files
```

`doctor.sh` checks: symlinks, GStack submodule, vendored skills (curl-pinned externals in `plugins.lock.json` + `link.sh`'s `EXTERNAL_SKILLS`, per the active profile), Playwright browser cache, prerequisites (git, Node, Cargo, Python, Claude Code), plugins, permissions, token budget, config consistency, git hooks (global core.hooksPath + generated githooks/), scratchpad (TMPDIR quota), Higgsfield CLI and session, seo-data layer.

---

## Going further

[`USAGE.md`](./USAGE.md) — workflows and skill decision tree ·
[`ARCHITECTURE.md`](./ARCHITECTURE.md) — layout and principles ·
[`CHANGELOG.md`](./CHANGELOG.md) — version history ·
[`MIGRATION.md`](./MIGRATION.md): upgrade guides ·
[`templates/settings/SETTINGS.md`](templates/settings/SETTINGS.md): permission tiers and guardrails

## License

MIT, see [LICENSE](./LICENSE).
