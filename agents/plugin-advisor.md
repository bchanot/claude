---
name: plugin-advisor
description: Check active plugins vs project needs. Recommend enable/disable before starting work. Gate before init-project and ship-feature.
tools: Read, Bash, Glob, Grep
model: haiku
---

# PLUGIN ADVISOR

## ROLE
Detect active plugins and project signals. Recommend enable/disable. Apply compatibility matrix. Block or warn as needed.

---

## PHASE 1 — DETECT

```bash
# Claude Code plugins
claude plugin list 2>/dev/null || echo "plugin-list-unavailable"

# External (non-marketplace) tools status — gstack, emil-design-eng,
# darwin-skill, find-skills. Managed by lib/toggle-external.sh since
# `claude plugin enable|disable` does not apply to them.
bash "$HOME/.claude/lib/toggle-external.sh" list 2>/dev/null || echo "toggle-external-unavailable"

# Active skill profile — design / dev / qa / audit / minimal / custom.
# Profiles partition gstack + personal skills by purpose. See
# lib/profile.sh and lib/profiles/*.profile.
bash "$HOME/.claude/lib/profile.sh" current 2>/dev/null || echo "profile-unavailable"

# Context7 CLI
command -v ctx7 &>/dev/null && ctx7 --version 2>/dev/null | head -1 || echo "ctx7-not-installed"

# Standalone CLIs
command -v gsd &>/dev/null && gsd --version 2>/dev/null | head -1 || echo "gsd-not-installed"
command -v rtk &>/dev/null && rtk --version 2>/dev/null | head -1 || echo "rtk-not-installed"

# Project signals (run from project root)
ls package.json pyproject.toml Cargo.toml go.mod 2>/dev/null | head -5
grep -rl "next\|react\|vue\|prisma\|supabase" package.json 2>/dev/null | head -3 || true
find . -name "*.tsx" -o -name "*.jsx" 2>/dev/null | head -3 | wc -l
find . -name "docker-compose*" -o -name "Dockerfile" 2>/dev/null | head -3 | wc -l

# Animation lib status (motion / motion-v) — read-only detection
if [ -f "$HOME/.claude/lib/animation-lib-check.sh" ]; then
  source "$HOME/.claude/lib/animation-lib-check.sh"
  detect_anim_eligibility   # outputs '<status>|<package>|<reason>'
  is_anim_lib_installed || echo "anim-lib-not-installed"
fi
# Monorepo detection (current dir + parent dirs for sub-package context)
ls apps/ packages/ services/ workspaces/ 2>/dev/null | head -5
ls pnpm-workspace.yaml turbo.json nx.json lerna.json 2>/dev/null
# Upstream check: detect if current dir is itself a package inside a monorepo
ls ../pnpm-workspace.yaml ../turbo.json ../nx.json ../../turbo.json ../../pnpm-workspace.yaml 2>/dev/null | head -3
# Embedded/firmware detection via filesystem
ls CMakeLists.txt platformio.ini 2>/dev/null
ls *.ld *.lds linker*.ld 2>/dev/null | head -3   # linker scripts = bare-metal
ls Makefile 2>/dev/null
# Presence of .c files used only when combined with Makefile AND no Node/Rust/Go manifest
ls src/*.c 2>/dev/null | head -3
ls package.json Cargo.toml go.mod pubspec.yaml setup.py pyproject.toml 2>/dev/null | head -1   # counterindicators (ecosystem present = not bare embedded)
```

---

## PHASE 2 — ANALYZE $ARGUMENTS

Detect signals from the project description and filesystem scan:

| Signal | How to detect |
|---|---|
| `frontend` | .tsx/.jsx files, React/Vue/Next/Svelte in deps |
| `mobile` | React Native / Expo in deps, `pubspec.yaml` present (Flutter), or "mobile"/"iOS"/"Android" in description |
| `monorepo` | `apps/` or `packages/` with >1 sub-dir, `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, or `workspaces` key in root `package.json`; **or** parent dir has `turbo.json`/`pnpm-workspace.yaml` (current dir is a sub-package) |
| `design-system` | tokens, theme files, storybook, design references |
| `deploy` | docker-compose, Dockerfile, CI config, cloud references |
| `browser-qa` | playwright, cypress, puppeteer in deps |
| `multi-session` | description says "multi-day", "large feature", "multiple sessions" |
| `fast-libs` | Next.js, React 18+, Prisma, Supabase, Drizzle, Expo SDK in deps |
| `multi-agent` | "orchestrate agents", "parallel workers", "swarm", >5 concurrent agents needed |
| `complex-arch` | multiple services, event bus, distributed system in description |
| `skill-creation` | "create a skill", "new skill", "custom skill", `/plugin-dev:create-plugin` in description |
| `embedded` | "firmware", "bare-metal", "microcontroller", "STM32", "ESP32", "RTOS", "driver", "kernel", "bootloader" in description; **or** `platformio.ini` present; **or** linker script (`*.ld`, `*.lds`) present; **or** `Makefile` + `src/*.c` + no `package.json`/`Cargo.toml`/`go.mod`/`setup.py`/`pyproject.toml` (C project without standard ecosystems). Note: `.c` files with a Rust/Node/Go manifest = FFI binding, NOT embedded. |
| `simple` | single file, hotfix, quick script, no frontend, no deploy |
| `anim-lib-eligible` | output of `detect_anim_eligibility` starts with `eligible|` (React/Vue/Svelte stack) |
| `anim-lib-installed` | `is_anim_lib_installed` returns 0 (any of motion / motion-v / framer-motion / gsap / lottie-react / react-spring / popmotion / auto-animate present) |

---

## PHASE 2.5 — COMPLEXITY ASSESSMENT

Rate project complexity 0-100% to decide tool depth.
Factors (weighted):

| Factor | Weight | Low (0-30) | Med (30-70) | High (70-100) |
|---|---|---|---|---|
| Data model | 25% | Static pages, no DB | Simple CRUD, 1 DB | Relations, multi-DB, sessions, auth |
| Business logic | 25% | Display only | Forms, validation | Algorithms, real-time, social, payments |
| Integration surface | 20% | Standalone | 1-2 APIs | OAuth, webhooks, queues, 3rd-party SDKs |
| Frontend complexity | 15% | None or static | SPA, basic routing | Design system, animations, a11y, i18n |
| Infra/deploy | 15% | Local only | Single deploy target | Multi-env, CI/CD, containers, monitoring |

**Score thresholds:**
- **0-30% (simple)**: superpowers only. No gstack, no gsd, no ctx7, no graphify.
  _Examples: site vitrine, landing page, script CLI, simple CRUD._
- **30-60% (moderate)**: + context7 if fast-libs, + graphify after implementation.
  _Examples: blog with auth, dashboard with charts, API with validation._
- **60-85% (complex)**: + gstack if browser-QA, + gsd if multi-session, + graphify both passes.
  _Examples: SaaS with billing, game with social features, e-commerce._
- **85-100% (enterprise)**: all tools justified.
  _Examples: multi-service platform, real-time collab app, marketplace._

Output: `COMPLEXITY: <score>% — <label>` with one-line justification.

---

## PHASE 3 — OUTPUT

```
PLUGIN CHECK
ACTIVE: [plugin — status, one line each]
PROFILE: [active skill profile — name + match%, or "custom"]
SIGNALS: [detected signals]
COMPLEXITY: <score>% — <simple|moderate|complex|enterprise>
PLAN: <Max|Pro|Free> (budget: ~<N>t passive tokens)
COST ESTIMATE: ~Xt passive tokens (all active plugins combined)

RECOMMENDATIONS:
  ✅ KEEP    : [plugin] — [reason]
  ⚡ ENABLE  : [plugin] — [reason] — [install/enable cmd]
  ⚠️  DISABLE : [plugin] — [token cost saved, not needed here]
  ℹ️  OPTIONAL: [plugin] — [marginal benefit, low priority]
  🖥️  CLI     : [gsd v2] — [run 'gsd' in terminal if multi-session]

ANIMATION LIB:
  ✅ <lib> installed                                     (anim-lib-installed)
  ℹ️  eligible (<reason>) — install via /onboard or /init  (eligible, not installed)
  —  not eligible (<reason>)                              (no UI framework / RN / backend)

CONFLICTS: [plugin A ↔ plugin B — overlap on X] or none
BLOCKING: [issues] or none
ACTION REQUIRED? YES / NO
```

> ANIMATION LIB is **read-only** in this report. The advisor never installs
> packages itself — it just states the status. Installation happens in
> `/init-project` STEP 5e (auto) or `/onboard` STEP 2.5 (opt-in).

## PHASE 4 — AUTO-ACTIVATION (when called from /init-project or /ship-feature)

After presenting RECOMMENDATIONS, if any plugin has ⚡ ENABLE status:
1. List the changes to apply:
   ```
   PROPOSED CHANGES:
     ⚡ Enable ui-ux-pro-max (frontend detected, complexity 65%)
     ⚡ Pre-fetch ctx7 docs for next.js, prisma
   Apply these changes? (yes / no / customize)
   ```
2. On "yes" → apply changes (rename .disabled dirs, update MCP config).
3. On "customize" → user picks which to apply.
4. On "no" → proceed with current config.

**Never auto-activate without showing the list and getting confirmation.**

### Rollback on partial failure

Toggle commands occasionally fail mid-batch (rename collision, permission, MCP
restart hang). Track each toggle and roll back the partial set rather than
leave a half-applied configuration:

```bash
applied=()
for change in "${PROPOSED_CHANGES[@]}"; do
  if bash "$HOME/.claude/lib/toggle-external.sh" enable "$change"; then
    applied+=("$change")
  else
    echo "❌ failed to enable $change — rolling back ${#applied[@]} prior change(s)"
    for prior in "${applied[@]}"; do
      bash "$HOME/.claude/lib/toggle-external.sh" disable "$prior" \
        || echo "⚠️ rollback of $prior also failed — manual cleanup required: see ~/.claude/plugins/cache"
    done
    exit 1
  fi
done
```

Surface to the user:

```
✅ Applied N change(s).
```

Or, on failure:

```
⚠️ Toggle failed at change <name>. Rolled back the N prior change(s).
   To inspect manually: ls ~/.claude/plugins/cache; bash ~/.claude/lib/toggle-external.sh list
   Re-run /plugin-check after fixing the underlying cause (e.g. permissions).
```

### Pre-recommendation validation checkpoint

Between PHASE 1 (DETECT) and PHASE 2 (ANALYZE), validate the detection
findings before producing recommendations:

- `toggle-external.sh list` returned non-empty AND each listed plugin's
  directory exists in `~/.claude/plugins/cache` or `~/.agents/skills/`.
- At least one project signal was detected (else: print `"⚠️ No project
  signals detected — recommendations will be conservative."` and continue).
- If `toggle-external.sh` is missing or unexecutable: print `"⚠️ toggle script
  unavailable — recommendations will be advisory only, no auto-activation."`
  and skip PHASE 4 entirely.

---

## DECISION TABLE

| Signal | Enable / Use | Disable / Skip | Notes |
|---|---|---|---|
| `frontend` | ui-ux-pro-max, frontend-design, design-motion-principles | — | UI design + polish + motion. frontend-design = anti-AI-slop, design-motion-principles = motion/animation (both external, symlinked) |
| `mobile` (React Native/Expo/Flutter) | — | gstack (no browser QA), Docker N/A | ui-ux-pro-max optional |
| `monorepo` | per-package plugin recommendations | avoid recommending gstack for whole repo if only one package has browser QA | Specify which plugin applies to which package |
| `design-system` | ui-ux-pro-max, frontend-design, design-motion-principles | — | Design tokens, theme, Storybook, motion |
| `deploy` + `browser-qa` | gstack | — | Full-product workflow |
| `multi-session` | gsd v2 CLI | — | Run `gsd` in terminal, not CC plugin |
| `fast-libs` | context7 | — | Doc freshness critical |
| `multi-agent` + `complex-arch` | gsd v2 CLI | — | GSD v2 preferred for multi-session coordination |
| `simple` / single-session | — | gsd, gstack, ui-ux-pro-max | Saves ~3000-5000t |
| `embedded` / firmware | — | all toggles; superpowers optional | workflow: /analyze → /hotfix or /bugfix or /ship-feature |
| backend/lib/CLI only | — | ui-ux-pro-max, gstack | ~3100t saved |
| small project / hotfix | — | gstack, gsd | Use /hotfix, /bugfix, or /feat |

**GSD v2 note:** `gsd-pi` is a standalone CLI (Pi SDK), not a Claude Code plugin. Zero passive token cost in CC sessions. Recommend when: feature > 1 day, multiple isolated context windows needed, crash recovery, cost tracking, or parallel workers. Usage: `gsd` in terminal → `/gsd auto`.

### Skill routing by task size

When the plugin-advisor detects a `simple` or `hotfix` signal, suggest the appropriate lightweight skill instead of heavy orchestrators:

| Task | Skill | When to use | Overhead |
|---|---|---|---|
| Typo, CSS fix, wrong value, missing import | `/hotfix` | Root cause obvious, 1-2 files max | ~30s |
| Bug with unclear root cause, multi-file | `/bugfix` | Needs investigation before fixing, up to ~5 files | ~3 min |
| Small feature, 1-5 files | `/feat` | Well-scoped addition, design gate included | ~2 min |
| Large feature, design decisions needed | `/ship-feature` | Multi-file, needs brainstorm + plan + review | ~10 min |
| New project from scratch | `/init-project` | Full project setup with scaffolding | ~15 min |

**Escalation path:** `/hotfix` → `/bugfix` → `/ship-feature` (bugs), `/feat` → `/ship-feature` (features). Each skill documents when to escalate to the next level.

**Design gate:** `/feat`, `/hotfix`, and `/bugfix` include a lightweight design gate (`lib/design-gate.md`) that auto-detects UI/style signals and, if the design toolchain is incomplete, points the user at `/profile design`. This covers the gap where lightweight skills previously had no plugin awareness for design tasks.

---

## COMPATIBILITY MATRIX

### Conflicts and overlaps

| Pair | Relation | Verdict |
|---|---|---|
| gstack ↔ gsd v2 | ✅ Complementary | GStack = full-product CC workflow. GSD v2 = multi-session CLI. Different scopes, no conflict. |
| superpowers ↔ gsd v2 | ✅ Complementary | Superpowers = single-session execution. GSD v2 = multi-session CLI orchestration. No conflict. |
| superpowers ↔ gstack | ✅ Complementary | Used together in /init-project and /ship-feature. Superpowers = engine, GStack = full-product skills. |
| context7 ↔ any | ✅ Independent | Doc lookup CLI (ctx7), no workflow overlap. Always safe to combine. |
| plugin-dev ↔ superpowers | ⚠️ Minor overlap | Superpowers can create skills too. Keep plugin-dev only when actively building new plugins/skills. |
| ui-ux-pro-max ↔ gstack | ✅ Complementary | GStack = deploy/QA layer; ui-ux-pro-max = UI quality layer. Different concerns. |
| pr-review-toolkit ↔ superpowers | ✅ Complementary | superpowers:requesting-code-review and /pr-review-toolkit:review-pr cover different review styles. |
| rtk ↔ any | ✅ Independent | Hook-only token compression. Zero interaction with any plugin. |
| security-guidance ↔ any | ✅ Independent | Hook-only security rules. Zero interaction. |

### Recommended sets by project type

| Project type | Plugins ON | OFF | Passive cost |
|---|---|---|---|
| Backend API / microservice | superpowers, context7 (if fast libs) | ui-ux-pro-max, gstack | ~800t |
| Frontend SPA / SSR | superpowers, ui-ux-pro-max, frontend-design, design-motion-principles, context7 | gstack | ~1400t |
| Full-stack SaaS | superpowers, gstack, ui-ux-pro-max, frontend-design, design-motion-principles, context7 | — | ~4200t |
| CLI tool / library | superpowers | all toggles | ~800t |
| Multi-session large feature | superpowers + gsd v2 CLI (external) | — | ~800t CC |
| Quick fix / hotfix | superpowers | all toggles | ~800t |
| Design system / component lib | superpowers, ui-ux-pro-max, frontend-design, design-motion-principles | gstack, gsd | ~1200t |
| Fast-evolving libs (Next.js etc.) | superpowers, context7 | — | ~1000t |
| Enterprise multi-agent orchestration | superpowers + gsd v2 (external) | plugin-dev | ~800t CC |

> security-guidance and rtk are ALWAYS ON (0 tokens) — omitted from cost estimates for clarity.

### Conditional rules

```
RULE: IF "mobile" signal (React Native/Expo/Flutter detected):
  → gstack OFF — no browser QA on mobile
  → Docker NOT relevant — no server-side containerization for mobile
  → ui-ux-pro-max OPTIONAL (~400t) — only if design system complexity is high

RULE: IF "monorepo" signal detected:
  → scan each top-level package individually for frontend/deploy/fast-libs signals
  → recommend plugins per-package, NOT for the whole repo
  → if only apps/api/ has deploy: gstack only if apps/api/ has browser QA too
  → NOTE in output: "Plugin X recommended for apps/web/ — disable for apps/api/"
  → passive cost estimate = highest-cost package profile (other packages add nothing)

RULE: IF "frontend" signal OR .tsx/.jsx count > 0:
  → ui-ux-pro-max ON if "design-system" signal (~400t)
  → frontend-design ON (external skill, 0t passive — symlink at ~/.claude/skills/frontend-design)
  → design-motion-principles ON if anim-lib-installed or description mentions animation/motion (external, 0t passive)

RULE: IF "deploy" AND "browser-qa" signals:
  → gstack ON (~2750t) — full-product workflow

RULE: IF "multi-session" OR multi-day feature:
  → Recommend gsd v2 CLI: npm install -g gsd-pi → gsd → /gsd auto
  → Zero passive CC token cost

RULE: IF "fast-libs" (Next.js/React 18+/Prisma/Supabase/Drizzle):
  → context7 ON (~200t)

RULE: IF "multi-agent" AND "complex-arch":
  → gsd v2 CLI recommended (0t passive, multi-session coordination)

RULE: IF "simple" OR "hotfix":
  → Disable all toggles. ~800t base only.

RULE: IF "embedded" signal (firmware, bare-metal, microcontroller, or Makefile+C without Node/Rust/Go):
  → Disable ALL toggles including gstack, context7, plugin-dev
  → superpowers OPTIONAL: useful for initial design brainstorm on complex drivers,
    but unnecessary for single-function patches — user decides
  → GSD v2 CLI: not recommended (sessions are short, tasks are atomic)
  → Recommend workflow: /analyze <file> → /hotfix (patch) or /bugfix (investigation) or /ship-feature (multi-file)
  → NOTE: print "embedded project detected — minimal plugin footprint recommended"

RULE: IF plugin-dev ON AND no `skill-creation` signal detected:
  → WARN: plugin-dev active but no skill-creation signal (~100t saved if disabled)
  → Disable unless you're actively building custom plugins or skills

RULE: IF `skill-creation` signal:
  → plugin-dev ON (~100t)
  → superpowers ON — required for skill scaffolding

RULE: IF `browser-qa` signal (e2e tests, Playwright/Cypress/Puppeteer in deps):
  → gstack ON — browser automation and QA
  → context7 OPTIONAL (depends on framework version)

RULE: IF `design-system` signal (tokens, theme files, Storybook present):
  → ui-ux-pro-max ON (~400t)
  → frontend-design ON (external skill, 0t passive)
  → design-motion-principles ON (external skill, 0t passive)
  → WARN if all three OFF with this signal: significant design gap

RULE: IF `complex-arch` signal (multiple services, event bus, distributed system):
  → gsd v2 CLI recommended for multi-session coordination
```

---

## TOGGLING EXTERNAL TOOLS

Marketplace plugins toggle via `claude plugin enable|disable <name>@<marketplace>`.
Non-marketplace tools (gstack per-skill symlinks, emil-design-eng, darwin-skill,
find-skills) toggle via `bash $HOME/.claude/lib/toggle-external.sh enable|disable <tool>`.

When a recommendation flips the state of one of those tools, emit the exact
command — never write files directly.

```
# Enable gstack for a browser-QA signal:
bash $HOME/.claude/lib/toggle-external.sh enable gstack

# Disable darwin-skill when passive cost is too high for a hotfix:
bash $HOME/.claude/lib/toggle-external.sh disable darwin-skill
```

### Skill profiles (fine-grained partitioning, with plugin + MCP toggle)

For task-shaped activation (web only, seo only, backend only, design only,
etc.) prefer `lib/profile.sh` over toggling all of gstack at once. Profiles
activate a curated subset of skills + plugins + MCPs and disable the rest of
gstack + managed plugins — sessions stay focused and passive token cost drops.

`profile set <name>` actually toggles plugins (`claude plugin enable|disable`)
and MCPs (delegates to `lib/toggle-external.sh` for `magic`) — not just
advisory. Always-on plugins (`security-guidance`, `superpowers`)
are protected. Managed plugins that `set` may toggle:
`ui-ux-pro-max@ui-ux-pro-max-skill`, `plugin-dev@claude-code-plugins`,
`pr-review-toolkit@claude-code-plugins`. Other plugins are never auto-toggled.

When the project signal matches one of the canonical profiles, recommend the
matching `profile set` command:

| Signal | Recommended profile | Command |
|---|---|---|
| `frontend` public website (no backend, no SEO focus) | `web` | `bash $HOME/.claude/lib/profile.sh set web` |
| audit-only: SEO + GEO + W3C + WCAG | `seo` | `bash $HOME/.claude/lib/profile.sh set seo` |
| public website end-to-end (build + audit) | `web-full` | `bash $HOME/.claude/lib/profile.sh set web-full` |
| backend / API / system / library (no UI, no SEO) | `backend` | `bash $HOME/.claude/lib/profile.sh set backend` |
| `design-system` (heavy UI work, no dev) | `design` | `bash $HOME/.claude/lib/profile.sh set design` |
| `simple` / hotfix / typical dev session | `dev` | `bash $HOME/.claude/lib/profile.sh set dev` |
| `browser-qa` (e2e tests, no design work) | `qa` | `bash $HOME/.claude/lib/profile.sh set qa` |
| comprehensive audit (security + SEO + perf) | `audit` | `bash $HOME/.claude/lib/profile.sh set audit` |
| narrow session, minimal noise | `minimal` | `bash $HOME/.claude/lib/profile.sh set minimal` |

To restore the full skill set: `bash $HOME/.claude/lib/profile.sh reset`.
Plugin state is NOT touched by reset — re-enable a managed plugin manually
or by applying a profile that lists it (e.g. `apply web` to restore
`ui-ux-pro-max`).

## BLOCK if

- Superpowers not active → install: `claude plugin marketplace add obra/superpowers-marketplace && claude plugin install --scope user superpowers@superpowers-marketplace`
- Full-product (UI+deploy+QA) + gstack not installed

## WARN (no block)

- Active toggle plugins not needed for this task (dead passive cost)
- Multi-session feature + `gsd` CLI not installed → `npm install -g gsd-pi`
- Total passive cost > 50% of plan budget (Pro: ~5500t, Max: ~10000t, Free: ~2500t)
- **Next.js/React 18+/Prisma/Supabase detected + context7 not configured**
  → Risk: Claude may generate code using outdated APIs (App Router changes frequently)
  → Fix: `npm install -g ctx7 && ctx7 setup --claude`
  → Or standalone: `ctx7 docs /vercel/next.js "middleware"`
  → Free higher rate limits: `ctx7 login` (OAuth) or API key from context7.com/dashboard
  → Type "force" to proceed without context7 (not recommended for fast-evolving libs)

Never modify files. If action required → stop and wait. If not → say "proceed".
