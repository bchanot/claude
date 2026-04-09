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

# GStack skills count (toggle CC plugin)
ls $HOME/.claude/skills/gstack/skills/ 2>/dev/null | wc -l || echo "0"

# Ruflo CLI
command -v ruflo &>/dev/null && ruflo --version 2>/dev/null | head -1 || echo "ruflo-not-installed"

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

---

## PHASE 3 — OUTPUT

```
PLUGIN CHECK
ACTIVE: [plugin — status, one line each]
SIGNALS: [detected signals]
COST ESTIMATE: ~Xt passive tokens (all active plugins combined)

RECOMMENDATIONS:
  ✅ KEEP    : [plugin] — [reason]
  ⚡ ENABLE  : [plugin] — [reason] — [install/enable cmd]
  ⚠️  DISABLE : [plugin] — [token cost saved, not needed here]
  ℹ️  OPTIONAL: [plugin] — [marginal benefit, low priority]
  🖥️  CLI     : [gsd v2] — [run 'gsd' in terminal if multi-session]

CONFLICTS: [plugin A ↔ plugin B — overlap on X] or none
BLOCKING: [issues] or none
ACTION REQUIRED? YES / NO
```

---

## DECISION TABLE

| Signal | Enable / Use | Disable / Skip | Notes |
|---|---|---|---|
| `frontend` | frontend-design, ui-ux-pro-max | — | Both complement each other |
| `mobile` (React Native/Expo/Flutter) | frontend-design | gstack (no browser QA), Docker N/A | ui-ux-pro-max optional |
| `monorepo` | per-package plugin recommendations | avoid recommending gstack for whole repo if only one package has browser QA | Specify which plugin applies to which package |
| `design-system` | frontend-design, ui-ux-pro-max | — | High overlap but both useful |
| `deploy` + `browser-qa` | gstack | — | Full-product workflow |
| `multi-session` | gsd v2 CLI | — | Run `gsd` in terminal, not CC plugin |
| `fast-libs` | context7 | — | Doc freshness critical |
| `multi-agent` + `complex-arch` | ruflo (CLI) | — | Only if genuine swarm needed |
| `simple` / single-session | — | gsd, gstack, ruflo, ui-ux-pro-max | Saves ~3000-5000t |
| `embedded` / firmware | — | all toggles; superpowers optional | workflow: /analyze → edit or /ship-feature |
| backend/lib/CLI only | — | frontend-design, ui-ux-pro-max, gstack | ~3100t saved |
| small project / hotfix | — | gstack, ruflo, gsd | Overhead exceeds value |

**GSD v2 note:** `gsd-pi` is a standalone CLI (Pi SDK), not a Claude Code plugin. Zero passive token cost in CC sessions. Recommend when: feature > 1 day, multiple isolated context windows needed, crash recovery, cost tracking, or parallel workers. Usage: `gsd` in terminal → `/gsd auto`.

**Ruflo note:** `ruflo` is a heavy CLI tool (310+ tools, ~500-1500t passive when hooks active). Only recommend when the project explicitly requires coordinating 5+ specialized agents simultaneously or swarm/parallel-orchestration architecture. For standard multi-session work, GSD v2 is sufficient and lighter. Install: `npm install -g ruflo@latest --omit=optional`. Init: `ruflo init --wizard`.

---

## COMPATIBILITY MATRIX

### Conflicts and overlaps

| Pair | Relation | Verdict |
|---|---|---|
| frontend-design ↔ ui-ux-pro-max | ⚠️ Overlap | Both do UI styling. Keep both for design-heavy projects; drop ui-ux-pro-max for simple UIs. ~600t combined. |
| gstack ↔ gsd v2 | ✅ Complementary | GStack = full-product CC workflow. GSD v2 = multi-session CLI. Different scopes, no conflict. |
| gstack ↔ ruflo | ⚠️ Overlap | Both orchestrate multi-step workflows. GStack is CC-native; ruflo is CLI swarm. High combined overhead (~3250-4250t). Use one or the other. |
| gsd v2 ↔ ruflo | ⚠️ Overlap | GSD v2 = sequential session pipeline. Ruflo = parallel agent swarm. Pick one per project; ruflo only if genuinely parallel work needed. |
| superpowers ↔ gsd v2 | ✅ Complementary | Superpowers = single-session execution. GSD v2 = multi-session CLI orchestration. No conflict. |
| superpowers ↔ gstack | ✅ Complementary | Used together in /init-project and /ship-feature. Superpowers = engine, GStack = full-product skills. |
| superpowers ↔ ruflo | ⚠️ Overlap | Both can orchestrate agent sub-tasks. Together only for advanced hybrid setups. |
| context7 ↔ any | ✅ Independent | Doc lookup CLI (ctx7), no workflow overlap. Always safe to combine. |
| plugin-dev ↔ superpowers | ⚠️ Minor overlap | Superpowers can create skills too. Keep plugin-dev only when actively building new plugins/skills. |
| frontend-design ↔ gstack | ✅ Complementary | GStack = deploy/QA layer; frontend-design = UI quality layer. Different concerns. |
| pr-review-toolkit ↔ superpowers | ✅ Complementary | superpowers:requesting-code-review and /pr-review-toolkit:review-pr cover different review styles. |
| rtk ↔ any | ✅ Independent | Hook-only token compression. Zero interaction with any plugin. |
| security-guidance ↔ any | ✅ Independent | Hook-only security rules. Zero interaction. |

### Recommended sets by project type

| Project type | Plugins ON | OFF | Passive cost |
|---|---|---|---|
| Backend API / microservice | superpowers, context7 (if fast libs) | frontend-design, ui-ux-pro-max, gstack, ruflo | ~800t |
| Frontend SPA / SSR | superpowers, frontend-design, ui-ux-pro-max, context7 | gstack, ruflo | ~1600t |
| Full-stack SaaS | superpowers, gstack, frontend-design, ui-ux-pro-max, context7 | ruflo | ~4400t |
| CLI tool / library | superpowers | all toggles | ~800t |
| Multi-session large feature | superpowers + gsd v2 CLI (external) | ruflo (unless parallel) | ~800t CC |
| Quick fix / hotfix | superpowers | all toggles | ~800t |
| Design system / component lib | superpowers, frontend-design, ui-ux-pro-max | gstack, ruflo, gsd | ~1600t |
| Fast-evolving libs (Next.js etc.) | superpowers, context7, frontend-design | ruflo | ~1200t |
| Enterprise multi-agent orchestration | superpowers, ruflo + gsd v2 (external) | plugin-dev | ~2300t CC |

> security-guidance and rtk are ALWAYS ON (0 tokens) — omitted from cost estimates for clarity.

### Conditional rules

```
RULE: IF "mobile" signal (React Native/Expo/Flutter detected):
  → frontend-design ON (~200t) — mobile UI components
  → gstack OFF — no browser QA on mobile
  → Docker NOT relevant — no server-side containerization for mobile
  → ui-ux-pro-max OPTIONAL (~400t) — only if design system complexity is high

RULE: IF "monorepo" signal detected:
  → scan each top-level package individually for frontend/deploy/fast-libs signals
  → recommend plugins per-package, NOT for the whole repo
  → if only apps/web/ has frontend: enable frontend-design for web package only
  → if only apps/api/ has deploy: gstack only if apps/api/ has browser QA too
  → NOTE in output: "Plugin X recommended for apps/web/ — disable for apps/api/"
  → passive cost estimate = highest-cost package profile (other packages add nothing)

RULE: IF "frontend" signal OR .tsx/.jsx count > 0:
  → frontend-design ON (~200t)
  → ui-ux-pro-max ON if "design-system" signal (~400t additional)

RULE: IF "deploy" AND "browser-qa" signals:
  → gstack ON (~2750t) — full-product workflow

RULE: IF "multi-session" OR multi-day feature:
  → Recommend gsd v2 CLI: npm install -g gsd-pi → gsd → /gsd auto
  → Zero passive CC token cost

RULE: IF "fast-libs" (Next.js/React 18+/Prisma/Supabase/Drizzle):
  → context7 ON (~200t)

RULE: IF "multi-agent" AND "complex-arch":
  → ruflo CLI ON (~500-1500t)
  → IF gstack also ON: WARN overlap (~3250-4250t combined)

RULE: IF "simple" OR "hotfix":
  → Disable all toggles. ~800t base only.

RULE: IF "embedded" signal (firmware, bare-metal, microcontroller, or Makefile+C without Node/Rust/Go):
  → Disable ALL toggles including gstack, context7, ruflo, plugin-dev
  → superpowers OPTIONAL: useful for initial design brainstorm on complex drivers,
    but unnecessary for single-function patches — user decides
  → GSD v2 CLI: not recommended (sessions are short, tasks are atomic)
  → Recommend workflow: /analyze <file> → Edit direct (hotfix) or /ship-feature (multi-file)
  → NOTE: print "embedded project detected — minimal plugin footprint recommended"

RULE: IF gstack ON AND ruflo ON:
  → WARN: functional overlap on multi-step orchestration
  → Suggest: gstack for CC-native workflow, ruflo only if parallel swarm needed

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
  → frontend-design ON (~200t)
  → ui-ux-pro-max ON (~400t)
  → WARN if both are OFF with this signal: significant design gap

RULE: IF `complex-arch` signal (multiple services, event bus, distributed system):
  → ruflo CLI ON (~500-1500t)
  → gsd v2 CLI recommended for multi-session coordination
  → IF gstack also ON: WARN combined cost ~3250-4250t — consider disabling one
```

---

## BLOCK if

- Superpowers not active → install: `claude plugin marketplace add obra/superpowers-marketplace && claude plugin install --scope user superpowers@superpowers-marketplace`
- Significant frontend signal + frontend-design AND ui-ux-pro-max both off
- Full-product (UI+deploy+QA) + gstack not installed

## WARN (no block)

- Active toggle plugins not needed for this task (dead passive cost)
- gstack ON + ruflo ON simultaneously (overlap, ~3250-4250t)
- ruflo ON with no multi-agent signal detected
- Multi-session feature + `gsd` CLI not installed → `npm install -g gsd-pi`
- Total passive cost > 5500t (~50% of Pro session budget)
- **Next.js/React 18+/Prisma/Supabase detected + context7 not configured**
  → Risk: Claude may generate code using outdated APIs (App Router changes frequently)
  → Fix: `npm install -g ctx7 && ctx7 setup --claude`
  → Or standalone: `ctx7 docs /vercel/next.js "middleware"`
  → Free higher rate limits: `ctx7 login` (OAuth) or API key from context7.com/dashboard
  → Type "force" to proceed without context7 (not recommended for fast-evolving libs)

Never modify files. If action required → stop and wait. If not → say "proceed".
