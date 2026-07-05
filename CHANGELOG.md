# Changelog

All notable changes to claude-config will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Changed
- graphify skill dist refreshed 0.8.45 → 0.9.6 (out-of-band `make plugin`; SKILL.md + query/extraction references updated by the generator).
- `/deploy` NEXT.sh reshaped on first-real-run feedback: runbook steps are **one command per line, interactive-session style** (an early step opens the ssh session; later lines run on the box; local steps say "from your machine") instead of folded `ssh host "cd … && …"` one-liners, and the **hand-back prints the full checklist inline** in the conversation (also on every re-hand-back) so the user never has to open `NEXT.sh` to know what to run. Step = comment header + command lines up to the next blank line; a `@delta:` directive governs the whole block. Template `templates/deploy/PROCEDURE.md` restyled to match.
- `settings.json`: `inputNeededNotifEnabled: true` adopted (harness notification toggle); committed layout otherwise unchanged.

### Added
- **impeccable** (pbakaus, Apache-2.0) wired into the toolchain as the design counterpart of semgrep: the `/impeccable` skill (23 verbs under one command: audit, polish, bolder, quieter…) plus the 45-rule deterministic anti-pattern detector (`npx impeccable detect`, exit 0/2, `--json`). Complementary to `frontend-design` (kept — aesthetic direction at build time); impeccable adds the deterministic audit floor and per-project design context (`/impeccable init`). CLI pinned in `plugins.lock.json` (3.2.0 — a silent rules update would change audit output on unchanged code); dist is machine-owned under `skills-external/impeccable/` (gitignored, ctx7 pattern), staged-installed by `install-plugins.sh` Step 8d, refreshed pin-honored by `update-all.sh`, symlinked by `link.sh`, listed in the design/web/web-full/full profiles and the design-work routing. Requires Node ≥ 24: the install baseline is bumped from 22 to 24 LTS (NodeSource `setup_24.x` / brew `node@24`), so `make plugin` upgrades a too-old host in place; the impeccable steps still skip gracefully if Node stays below 24. Not in the design gate's GATE-BLOCK list yet — promotion deliberate, after first dogfood.
- `/tour` skill — grouped all-axes sweep over one or several projects: security (pinned-semgrep `security-auditor` agent + `/cso` posture when gstack is ON) → cleanup → re-verify → reconcile (report-only, never edits the target TODO/registries) → doc sync, looping until a full pass applies zero fixes (bounded at 3 iterations). Fixes land on a `chore/tour-<date>` branch the skill never merges; each project gets an append-only `.claude/audits/TOUR.md` report with BREAKING tags on contract-changing security fixes. Built TDD (superpowers:writing-skills): baseline run showed silent TODO rewrites, autonomous registry writes, grep-as-security-pass, no persistent report, scope creep and an unbounded loop — each countered and verified on a seeded fixture.

### Fixed
- `gitflow_finish` ignored its `<type> <name>` arguments and always merged the checked-out branch — naming a different branch silently merged the wrong one. The arguments are now an optional safety assertion: if given and not equal to the current branch, `finish` refuses with a clear error instead of merging. No-argument calls (the only real caller) are unchanged.
- `doctor.sh` false-warnings removed (a check that cries wolf is one you learn to ignore): `cargo` absence no longer claims "RTK unavailable" (RTK ships as a prebuilt binary); `check_symlink` no longer flags files reached through directory-level symlinks (e.g. `hooks/session-start.sh`); the GStack check counts the per-skill symlinks instead of a `skills/gstack` link that `link.sh` deliberately removes; the token-budget estimate is measured against the ~200k context window instead of a mis-framed "~11k session budget" that produced a false "92% CRITICAL".

## [4.0.0] — 2026-06-30

### Added
- **Gitflow universal model** — `/gitflow` + `lib/gitflow.sh`: branch model (`main` / `develop` / `feature` / `bugfix` / `release` / `hotfix`) with directed `--no-ff` merges + hotfix fan-out (main + develop + open `release/*`); `start` / `finish` / `init` verbs. `lib/gitflow-migrate.sh` onboards an existing repo (`master`→`main`, seed `develop`, install the pre-commit hook, set Gitea Option-1 owner-pushable protection on `main`+`develop`), applied to all 6 repos. Wired into `/init-project` (STEP 5f `gitflow init` owns the scaffold root commit) + `/onboard` (STEP 2.6). See **BREAKING** under Changed
- `/deploy` — per-project deploy runbook in `.claude/deploy/` (`PROCEDURE.md` / `INCIDENTS.md` ledger / `STATE.json` oracle / `PENDING.json` cold-resume bridge / `NEXT.sh`); two-moment spine (instantiate checklist → out-of-band deploy → MARK success or LEARN from failure, patching the runbook in place); surgical `lib/deploy-commit.sh`; plus `/setup-deploy`
- Analyze-before-plan invariant — dev flows (`feat` / `bugfix` / `hotfix`, `ship-feature`) READ related memory before planning (ship-feature also reads related code) and must NAME each surfaced ID in the plan; shared `lib/analyze-before-plan.md` (read-before bookend of coupled-capitalize)
- Animation-library auto-detection/install — `motion` (`motion-v` for Vue 3 / Nuxt) auto-installed in `/init-project` (STEP 5e), opt-in in `/onboard` (STEP 2.5) on eligible stacks; `plugin-advisor` detects + reports only; logic in `lib/animation-lib-check.sh`
- Design-toolchain gate — `lib/design-tool-gate.sh` + `lib/design-gate.md` + a `design-toolchain-reminder` hook enforce the full design toolchain on UI work (profile-based), with a suggest-only non-blocking anim-lib note when a motion signal hits an eligible stack
- `lib/toggle-external.sh` — enable/disable non-marketplace tools; gstack now OFF by default (opt-in, activated on-demand per profile), Magic MCP (21st-dev) installed disabled by default
- Secrets single source-of-truth — real secret in `~/.claude/.env` reached via a repo `.env` symlink + `.env.example` placeholder; `MAGIC_API_KEY` resolved from it
- `/reconcile` — declared-vs-real reconciler: confronts TODO checkboxes + registry statuses (never the `## Index`) against real git/fs and surfaces the gaps in four categories + contradiction candidates, with a gated TODO write-back. Engine `lib/reconcile.sh` (body enumeration, git/fs oracles, last-block-wins status); thin skill
- `/release-candidate` — orchestrator over the gitflow release mechanic that adds the version tag the lib doesn't: finalize `version.txt` + CHANGELOG, fan-out `develop`→`main` + back, tag `vX.Y.Z`, push (gated). Lib stays the generic mechanic; the skill owns the tag
- Coupled-capitalize: dev flows (feat / hotfix / bugfix / commit-change, ship-feature, init-project) auto-commit their memory in the same breath, via shared `lib/capitalize-commit.md` + `lib/memory-commit.sh` (surgical — `.claude/memory` + `.claude/tasks` only, never `git add -A`)
- Coupled doc-sync: dev flows (feat / bugfix / hotfix, ship-feature, init-project) auto-commit the public docs `doc-syncer` patches, via shared `lib/doc-commit.md` + `lib/doc-commit.sh` (surgical — only the patched files, never `git add -A`, never `.claude/` / `CLAUDE.md`; refuses an out-of-scope path loudly with exit 4). `doc-syncer` surfaces `PATCHED_FILES` (one path per line) as the handoff
- `lib/doc-shape.sh` — deterministic MINOR-shape oracle for `doc-syncer` AUTO MODE: re-checks each LLM-classified MINOR patch (added-heading / size / new-file / non-doc envelope, thresholds env-overridable) and escalates a shape-suspect patch to the existing SIGNIFICANT gate instead of silently auto-committing it. A structural floor under the LLM's classification, not a blocking gate (genuine MINOR still auto-commits, zero friction); catches structural/size significance, not semantic
- `/audit-delta` — recurring multi-axis audit (norms / bugs / dead code / security) scoped to changes since last run, with per-axis SHA markers
- `/capitalize` — flush uncapitalized context to the memory registries before `/clear` or `/compact`
- `/prune-memory` — curate and compress the `.claude/memory/` registries
- `/close` — end-of-session memory ritual (decisions / learnings / blockers)
- `/pdf-translate` — translate a PDF to another language, output as HTML (via Vision)
- `/harden` — web hardening audit (SSL/TLS, HSTS, CSP, headers)
- `/web-validate` — W3C HTML/CSS validity + WCAG accessibility audit
- `/client-handover` — final ship + branded client deliverable (Markdown / HTML / PDF)
- `/profile` — partition skills by usage profile (design / dev / qa / audit / minimal / full)
- `frontend-design` and `design-motion-principles` skills (external marketplaces)
- Project archetype library + detection for `/onboard`
- `.claude/{tasks,memory,audits}/` governance layout + 5 memory registries (decisions, learnings, blockers, journal, evals)

### Changed
- **BREAKING (gitflow):** never commit code directly on `main` / `develop` — branch first (`gitflow start <type> <name>`) and integrate via `gitflow finish`. A generated per-repo pre-commit hook BLOCKS direct code commits on `main` / `develop` (exempts `.claude/**`, merges, the root commit). Existing repos must run `lib/gitflow-migrate.sh`. This workflow rupture is what takes the project from 3.x to 4.0.0
- `settings.json`: `git push` / `git tag` moved to the **ask** permission tier — a tool-call backstop for the "finish / release only on an explicit human signal" rule
- `install.sh` / `install-plugins.sh` made self-sufficient — nvm-installs Node/npm when missing, installs the `jq` prerequisite, runs `npx skills add` from `$HOME`; auto-reverts hand-curated config (`CLAUDE.md` + `settings.json` + `.claude/settings.json`) after install via an EXIT trap (install-immutable guard); auto-fixes the gstack browser on an OS newer than the pinned Playwright supports (Ubuntu 26.04)
- graphify upgraded to 0.8.x (skill pinned 0.8.45) — Gemini backend, monorepo support, CLI export, encoding fixes; CLAUDE.md + the pre-tool hook now prefer `graphify query` over `GRAPH_REPORT.md`
- `/seo` + `/geo`: CMS-plugin-first + shared-file edit discipline; Bing / IndexNow submission now mandatory
- `/ship-feature`: capitalize + memory commit moved before FINISH (was after) — fixes memory committed after a push/PR and stranded outside it
- `/init-project`: new STEP 10b captures founding architecture decisions as BDRs before FINISH
- `/ship-feature` + `/init-project`: DOC SYNC moved before FINISH (was after) — fixes public docs patched then left uncommitted and stranded outside the push/PR (ship-feature STEP 9→8, init-project STEP 12→10c; GSD 13→12)
- `/seo` split into parallel `seo` + `geo` agents with shared resources
- `/onboard` rewritten: archetype-aware pipeline (orchestrator + config-only agent), security audit archetype-aware
- `doc-syncer`: stack-aware audit + deploy-doc gating; later scoped to public docs only, `.claude/` read-only; sync-only ROADMAP handling — planned→shipped reconciliation from code/git, never from `.claude/`; numeric incoherence → HUMAN question
- `CLAUDE.md`: major refactor (contradiction purge, restructure), subagent-delegation rule, design-toolchain mandate, memory-registry governance
- Memory registries: enforced English + caveman format
- `settings.json`: `permissions.defaultMode` → `auto` (classifier-gated autonomy; `disableAutoMode` dropped) + `remoteControlAtStartup` + `skipAutoPermissionPrompt` + `effortLevel: xhigh`; model pin removed

### Removed
- `/init-project`: STEP 12 (speculative GSD v2 auto-bootstrap at project creation) removed — it ran `gsd init` AFTER FINISH, creating `ROADMAP.md` + `.gsd/` stranded outside the merge/PR (BLK-011), to bootstrap a multi-session engine that is opt-in and rarely used. Resolved by removal, not by plumbing a commit: GSD stays initializable on-demand (`/onboard add gsd`, or `gsd init` in a terminal), `/status` still reads `.gsd/`, and plugin-advisor still recommends it for multi-session work. init-project is now an 11-step pipeline
- `disable-model-invocation` frontmatter removed repo-wide (aligns skills with CLAUDE.md routing)
- Caveman plugin always-on integration purged — plugin disabled + uninstalled; SessionStart/UserPromptSubmit hooks, standalone hook files, `install-plugins.sh` STEP 5.5, `update-all.sh` refresh step, `plugins.lock.json` entry, `doctor.sh` checks, and docs removed. On a subscription plan its ~75% output-token compression has no cost benefit, and the always-on hooks added friction on validation gates + client deliverables. The unrelated memory-registry terse-format convention is kept.
- Installer-managed skills de-vendored — `frontend-design` un-tracked + npx-skills artifacts gitignored (re-synced from the plugin cache each run); obsolete `claude --effort max` shell alias removed (`settings.json` `effortLevel` is the source of truth)

### Fixed
- `lib/doc-commit.sh` no longer masks a rejected `git commit` as success: a pre-commit hook / protected branch / signing failure now fails loud with exit 5 and empty stdout (was: false "committed" + the previous HEAD's hash + exit 0, leaving docs silently uncommitted on a dirty tree)
- Numerous skill/agent fixes across darwin optimization rounds (geo-analyzer, onboard, init-project, analyzer, plugin-check, prune-memory, …)

## [3.4.0] — 2026-04-15

### Added
- **9 new skills**: `/bugfix`, `/code-clean`, `/commit-change`, `/doc`, `/feat`, `/graphify`, `/hotfix`, `/seo`, `/skills-perso`
- **7 new agents**: `bugfixer.md`, `code-cleaner.md`, `commit-changer.md`, `doc-syncer.md`, `feater.md`, `hotfixer.md`, `seo-analyzer.md`
- `install.sh`: bootstrap script — installs Claude Code CLI, authenticates, sets up shell env vars, then runs link.sh + install-plugins.sh
- `hooks/statusline.sh`: Claude Code status line configuration hook
- `hooks/rtk-rewrite.sh`: RTK hook for code rewrites
- `plugins.lock.json`: ctx7, graphifyy, and emil-design-eng entries added
- `skills-perso`: lists personal (user-created) skills from `~/.claude/skills/`
- `.graphifyignore`: excludes gstack submodule and install logs from graphify indexing

### Changed
- `Makefile`: `install` target now runs `install.sh` (bootstrap); new `plugin` target runs `install-plugins.sh` only
- `update-all.sh`: now also updates Claude CLI, ctx7, graphifyy, and marketplace plugins
- `install-plugins.sh`: added emil-design-eng skill download step; fixed skill-creator install to use `anthropics/skills` marketplace
- `skills/`: logic extracted from inline SKILL.md into standalone agent `.md` files — skills now delegate to agents
- `skills/commit-change/`: renamed from `git-smart-commit`; confirmation step removed
- `settings.json`: keys reordered for readability
- `CLAUDE.md`: added architecture decisions (no SPA for public sites, versioned APIs, security defaults), communication mode (radical honesty), graphify context navigation guidelines
- `README.md`: file tree, skill table, install section, plugins.lock section, Makefile targets, update-all description all updated for new skills/agents
- `USAGE.md`: command table expanded (9 → 18), decision tree restructured with lightweight skill routing
- `version.txt`: 3.3.0 → 3.4.0

### Removed
- `agents/readme-updater.md`: replaced by `agents/doc-syncer.md` (broader scope — all docs, not just README)
- `skills/readme/`: replaced by `skills/doc/`

### Fixed
- `skills-perso`: YAML description parsing handles both inline and block formats; detects personal skills via agent reference; excludes framework/gstack skills from listing
- `install-plugins.sh`: skill-creator install corrected to use `anthropics/skills` marketplace
- GStack skill symlinks untracked from git — auto-created by `install-plugins.sh`

## [3.3.0] — 2026-04-08

### Fixed
- `install-plugins.sh`: marketplace org was `anthropic` (missing 's') — corrected to `anthropics`
- `install-plugins.sh`: plugins `security-guidance`, `frontend-design`, `pr-review-toolkit` were installed from non-existent marketplace `claude-plugins-official` — corrected to `claude-code-plugins` (from `anthropics/claude-code` repo)
- `install-plugins.sh`: `skill-creator` plugin does not exist — replaced with `plugin-dev@claude-code-plugins` (correct plugin name)

### Changed
- `install-plugins.sh`: adds `anthropics/claude-code` marketplace before installing bundled plugins; install summary updated with correct marketplace sources
- `lib/detect-plugins.sh`: added `detect_security_guidance()`, `detect_plugin_dev()` functions; removed reference to non-existent `detect_skill_creator`
- `hooks/session-start.sh`: added `plugin_dev` to toggle loop and token cost estimate
- `agents/plugin-advisor.md`: all references to `skill-creator` → `plugin-dev`; signal `skill-creation` now recommends `plugin-dev ON`
- `README.md`: plugin table updated with correct marketplace sources per plugin; new "Marketplaces" subsection documenting all 4 marketplace sources and manual install commands; `/plugin-dev:create-plugin` replaces `/skill-creator`
- `USAGE.md`: all references to `skill-creator` → `plugin-dev`
- `version.txt`: 3.2.1 → 3.3.0

## [3.2.1] — 2026-04-07

### Fixed
- `agents/plugin-advisor.md`: 4 signals had entries in the signal table but no conditional rule — added rules for `skill-creation`, `browser-qa`, `design-system`, and `complex-arch`

### Changed
- `version.txt`: 3.2.0 → 3.2.1

## [3.2.0] — 2026-04-07

### Fixed
- `doctor.sh`: EXPECTED_SKILLS pass message uses `${#EXPECTED_SKILLS[@]}` (dynamic count) instead of hardcoded 9
- `agents/plugin-advisor.md`: `setup.py` and `pyproject.toml` added as counterindicators for embedded signal — prevents Python C-extensions from false-triggering embedded
- `agents/status-reporter.md`: PHP phpunit added to manifest fallback (`composer.json` → `./vendor/bin/phpunit`)
- `skills/health/SKILL.md`: post-result guidance added — CRITICAL/WARNING/errors/warnings/all-pass handling

### Added
- `USAGE.md`: "Erreurs fréquentes" — embedded signal not detected entry

### Changed
- `version.txt`: 3.1.0 → 3.2.0

## [3.1.0] — 2026-04-07

### Fixed
- `agents/plugin-advisor.md`: `Makefile` restored as embedded indicator — `Makefile` + `src/*.c` + no Node/Rust/Go manifest = embedded; `.c` files alone still not sufficient (Rust FFI counterindicated)
- `agents/onboarder.md`: PHASE 6 — check `command -v gsd` before generating ROADMAP.md; if absent, ROADMAP.md still generated with install instructions; same pattern as init-project STEP 13

### Added
- `doctor.sh`: expected skills check — verifies all 9 skills (analyze, health, init-project, onboard, plugin-check, readme, refactor, ship-feature, status) present in `~/.claude/skills/`
- `skills/analyze/SKILL.md`: description updated to mention DEBUG mode (read-only analysis OR error/stack trace → DEBUG mode)
- `USAGE.md`: token cost estimates on workflow patterns (Pattern A ~3000-5000t, B ~1500-2500t/session, D ~500-800t, E ~600-900t); budget note at top of Patterns section

### Changed
- `version.txt`: 3.0.0 → 3.1.0

## [3.0.0] — 2026-04-07

### Fixed
- `agents/plugin-advisor.md`: embedded false positive removed — `src/*.c` alone no longer triggers embedded signal (Rust FFI projects have .c files); only `platformio.ini` or `*.ld`/`*.lds` linker scripts are reliable triggers
- `agents/status-reporter.md`: flat awk scoped to `## Milestone` headings — no longer matches `## Prerequisites`, `## Notes`, or other non-milestone `##` headings in ROADMAP.md

### Added
- `agents/status-reporter.md`: Go test runner in manifest fallback (`go.mod` → "go test ./...")
- `USAGE.md`: GSD v2 active/interrupted node in decision tree — /gsd auto, /gsd steer, /gsd forensics
- `skills/analyze/SKILL.md`: argument-hint updated to mention DEBUG mode (pass error/stack trace)

### Breaking
- `agents/plugin-advisor.md`: embedded detection no longer triggers on C/C++ files alone — projects relying on .c file detection must add `platformio.ini` or a `*.ld` linker script

### Changed
- `version.txt`: 2.9.0 → 3.0.0

## [2.9.0] — 2026-04-07

### Fixed
- `agents/plugin-advisor.md`: PHASE 1 — filesystem embedded detection added (platformio.ini, *.ld linker scripts, src/*.c without package.json/Dockerfile); signal description updated
- `agents/status-reporter.md`: PHASE 3 — flat ROADMAP fallback awk command for milestones with tasks directly under ## (no ### slices); marked with "(flat)" in output
- `agents/status-reporter.md`: pytest cache parsing — JSON `{}` = "all passing" instead of "0 failing"; uses python3 for proper JSON parse instead of `cat | head`

### Added
- `USAGE.md`: analyze → refactor → analyze cycle documented in decision tree (refactoring profond)
- `README.md`: link to USAGE.md in intro section

### Changed
- `version.txt`: 2.8.0 → 2.9.0

## [2.8.0] — 2026-04-07

### Fixed
- `agents/status-reporter.md`: awk milestone detection uses `index()` instead of regex negation — portable across macOS nawk and GNU awk
- `agents/status-reporter.md`: Tests field fallback improved — shows "run '<cmd>' to check" when no result found but test manifest exists; shows "N/A" only when no test infrastructure at all

### Added
- `agents/plugin-advisor.md`: `embedded` signal added — firmware/bare-metal/microcontroller detection; DECISION TABLE row; conditional rule disabling all toggles, superpowers optional
- `doctor.sh`: agents pass message now lists all 8 agent names inline for quick visual confirmation
- `USAGE.md`: section "Quel skill utiliser ?" — decision tree for all 9 skills with quick-reference table
- `README.md`: `/status` added to Maintenance Diagnostic section alongside `/health`

### Changed
- `version.txt`: 2.7.0 → 2.8.0

## [2.7.0] — 2026-04-07

### Fixed
- `agents/status-reporter.md`: milestone detection algorithm — uses `awk` to find first `##` heading with pending `###` slices (top-to-bottom scan), not `tail -5` of all `##` headings
- `skills/ship-feature/SKILL.md`: `git log` now uses `--format="%h %<(50,trunc)%s"` to truncate long commit messages at 50 chars

### Added
- `agents/status-reporter.md`: PHASE 2 — best-effort build/test status check (pytest cache, Jest coverage, log files); `Tests` field in output
- `doctor.sh`: `check_symlink "lib"` added; `_EXPECTED_LINKS` updated 6 → 7
- `agents/plugin-advisor.md`: `skill-creation` signal added to PHASE 2; WARN rule if skill-creator active without skill-creation signal
- `USAGE.md`: Exemple 9 — firmware C/C++ STM32, workflow minimaliste sans superpowers ni GSD

### Changed
- `version.txt`: 2.6.0 → 2.7.0

## [2.6.0] — 2026-04-07

### Fixed
- `agents/status-reporter.md`: PHASE 3 now counts slices (### headings) not tasks (- [ ]) — correct progress metric matching GSD v2 dashboard
- `hooks/session-start.sh`: continuation line uses 13-space prefix (verified 60 bytes) for consistent box alignment
- `agents/onboarder.md`: PHASE 5b clarifies .gitignore target path per mode (A=workspace root, B=PACKAGE_ROOT, C=per-package)

### Added
- `skills/ship-feature/SKILL.md`: STEP 0b now prints PROJECT CONTEXT header when CLAUDE.md found — project name, stack, current branch, last 3 commits, GSD milestone
- `USAGE.md`: Exemple 8 — full session resume workflow with /status + GSD v2 step mode + /gsd discuss

### Changed
- `version.txt`: 2.5.0 → 2.6.0

## [2.5.0] — 2026-04-07

### Fixed
- `skills/init-project/SKILL.md`: STEP 1 — checks both `CLAUDE.md` and `.claude/CLAUDE.md`; pre-fills interview from either location
- `agents/status-reporter.md`: PHASE 3 GSD — replaced fragile `STATUS.md` read with robust ROADMAP.md checkbox parsing; handles missing ROADMAP.md; never reads binary `state.db`
- `agents/onboarder.md`: PHASE 5b added — .gitignore safety check; appends `.claude/settings.local.json` to existing .gitignore or creates minimal one; applies to all monorepo options

### Added
- `doctor.sh`: expected agents check in Consistency section — warns if any of 8 expected `.md` agent files are missing from `~/.claude/agents/`
- `README.md` + `USAGE.md`: `/status` added to Pattern B (multi-session) and Pattern C (onboarding) workflows
- `hooks/session-start.sh`: 2-line display for >4 active/inactive plugins — all plugin names shown, split at 4 per line

### Changed
- `version.txt`: 2.4.0 → 2.5.0

## [2.4.0] — 2026-04-07

### Fixed
- `skills/init-project/SKILL.md`: STEP 1 — reads existing CLAUDE.md if present; pre-fills interview answers already documented; asks only genuinely missing fields
- `agents/onboarder.md`: Option B fully implemented — explicit PACKAGE_ROOT scoping; all PHASE 3-5 paths relative to selected package; no root CLAUDE.md generated
- `agents/plugin-advisor.md`: upstream monorepo detection in PHASE 1 — checks `../turbo.json`, `../pnpm-workspace.yaml`, `../../turbo.json` for sub-package context; signal table updated to describe upstream detection

### Added
- `agents/status-reporter.md` + `skills/status/SKILL.md`: new `/status` skill — consolidated read-only snapshot (plugins + token cost + git state + recent commits + GSD v2 milestone)
- `USAGE.md`: section "Erreurs fréquentes" — quick-reference table of 14 common errors with causes and solutions
- `doctor.sh`: symlink counter — reports `N/6 OK` after symlink checks
- `hooks/session-start.sh`: `+N more` display — shows first 2 active/inactive plugins + count of remaining instead of truncated string
- `README.md`: /status added to skill table and file tree

### Changed
- `version.txt`: 2.3.0 → 2.4.0

## [2.3.0] — 2026-04-07

### Fixed
- `skills/ship-feature/SKILL.md`: STEP 0b added — checks for CLAUDE.md before starting; blocks with `/onboard` instruction if missing
- `skills/ship-feature/SKILL.md`: STEP 4b option B enhanced — scans remaining tasks for dependents before skipping a failed task; prompts to skip dependent tasks too
- `agents/onboarder.md`: Option C (sequential monorepo onboarding) fully implemented — iterates all packages, generates per-package CLAUDE.md + settings + .claudeignore, summary table, optional root ROADMAP.md
- `agents/plugin-advisor.md`: `monorepo` signal added to PHASE 1 detection (turbo.json, pnpm-workspace, nx.json), PHASE 2 signal table, DECISION TABLE, and conditional rules — recommends plugins per-package, not for the whole repo
- `doctor.sh`: `check_symlink "templates"` added — detects missing templates/ symlink (pre-v2.0.0 installations)
- `hooks/session-start.sh`: ACTIVE_STR and INACTIVE_STR truncated to 37 chars + `…` indicator when overflow detected

### Added
- `USAGE.md`: Exemple 7 — refactoring module Python legacy; full `/analyze` → `/refactor` → `/analyze` cycle; shows report-before-modify behavior and test-first recommendation

### Changed
- `version.txt`: 2.2.0 → 2.3.0

## [2.2.0] — 2026-04-07

### Fixed (bugs identified via case study simulation)
- `skills/init-project/SKILL.md`: STEP 13 — guard `command -v gsd` before running `gsd init`; prints install instructions if GSD v2 not in PATH instead of failing silently
- `skills/ship-feature/SKILL.md`: STEP 4b added — structured error recovery when a subagent fails (build error, failing test, type error); DEBUG mode analysis + user gate before any fix; max 2 retry attempts; never auto-patches
- `agents/onboarder.md`: monorepo detection added (PHASE 1) — detects `apps/`, `packages/`, `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`; interactive gate (onboard whole workspace / single package / each separately)
- `agents/plugin-advisor.md`: `mobile` signal added to PHASE 2 signal table + DECISION TABLE + conditional rules — React Native / Expo / Flutter explicitly handled; gstack disabled for mobile, Docker N/A
- `doctor.sh`: GStack `skills/` subdirectory check added after symlink verification — warns if GStack is symlinked but has no skills (needs `./setup`)
- `hooks/session-start.sh`: TOKEN_WARN truncated to 44 chars to prevent box overflow with emoji width

### Added
- `USAGE.md`: Exemple 6 — CLI Rust from scratch; illustrates minimal workflow (superpowers only, no frontend plugins, cargo check as verify, no GSD v2)

### Changed
- `version.txt`: 2.1.0 → 2.2.0

## [2.1.0] — 2026-04-07

### Added
- `agents/scaffolder.md`: React Native/Expo + Flutter support — PHASE 0 (Docker exclusion), PHASE 3 (stack templates), PHASE 4 (install commands), PHASE 5 (verify commands per stack)
- `agents/analyzer.md`: DEBUG MODE section — structured error diagnosis with root cause hypotheses, trace, and affected files
- `agents/onboarder.md`: new agent — onboard existing projects (discovery → interview → CLAUDE.md + settings + .claudeignore + optional GSD v2 ROADMAP)
- `skills/onboard/SKILL.md`: new skill `/onboard` invoking the onboarder agent
- `skills/init-project/SKILL.md`: STEP 13 (optional) — propose GSD v2 init at end of init-project when multi-session signal detected
- `Makefile`: `make onboard` target
- `README.md`: Workflow patterns section (5 patterns: new short, new long, onboarding, hotfix, refactor); /onboard in skill table and tree; make onboard in maintenance

### Fixed
- `agents/plugin-advisor.md`: "Next.js + context7 not configured" moved from BLOCK → WARN with force option — Context7 requires manual API key, should not hard-block project start
- `lib/detect-plugins.sh`: `detect_ruflo()` now uses 3-level fallback (npm binary → MCP config grep + ruvnet/claude-flow variants → `claude mcp list`)
- `hooks/session-start.sh`: passive token cost estimate added to session display — warns at >25%, alerts at >50% of Pro session budget

### Changed
- `version.txt`: 2.0.0 → 2.1.0

## [2.0.0] — 2026-04-06

### Breaking
- GSD v1 (`glittercowboy/get-shit-done-cc`) removed entirely
- GSD v1 commands (`/gsd:discuss-phase`, `/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:ship`, `/gsd:next`) no longer available — these were Claude Code slash commands; they do not exist in v2
- GSD v2 (`gsd-pi`) is a standalone CLI (Pi SDK), not a Claude Code plugin — usage model is entirely different

### Added
- **GSD v2 integration** (`gsd-build/gsd-2`, npm: `gsd-pi` 2.64.0) — standalone CLI with autonomous mode (`/gsd auto`), state machine per-task execution, crash recovery, cost tracking, parallel workers, worktree isolation
- **Ruflo plugin** (`ruvnet/ruflo`, npm: `ruflo` 3.5.58) — enterprise multi-agent MCP server (formerly claude-flow), 310+ tools, 100+ agent types, WASM kernel; 🔄 TOGGLE, ~500-1500t passive
- **Full plugin compatibility matrix** in `agents/plugin-advisor.md` — all 12 plugins analyzed pairwise, conditional rules, recommended sets by project type
- **Ruflo auto-detection** in `lib/detect-plugins.sh`, `doctor.sh`, `hooks/session-start.sh`
- **GSD v2 CLI status** in `session-start.sh` — dedicated `🖥️  CLI` line (separate from CC plugin toggles)
- **8 new deny rules** in `settings.json`: `source /dev/stdin`, `mkfifo *`, `python3 -c *`, `node -e *`, `xargs * .env*`, `tar * .env*`, `zip * .env*`, `base64 .env*` — covers runtime secret access and exfiltration vectors
- **`disableAutoMode: "disable"`** added to global `settings.json` # TODO: VERIFY syntax in CC v2.1.89
- **`templates/` symlink** in `link.sh` — `~/.claude/templates/` now resolves correctly for scaffolder and init-project
- **Token budget breakdown** in `doctor.sh` — CLAUDE.md + skill descriptions + plugin passive cost, thresholds vs Pro session budget (~11k tokens/5h)
- **GStack pinning warning** in `doctor.sh` and `update-all.sh` (confirmation prompt before `--remote` update)
- **GStack false-positive fix** in `doctor.sh` — submodule check now requires `.git` presence, not just directory existence
- Ruflo install instructions in `install-plugins.sh` (Step 5, manual — enterprise tool)
- Ruflo update step in `update-all.sh`
- GSD v2 update step in `update-all.sh`

### Changed
- `plugins.lock.json`: GSD v1 (`npm:get-shit-done-cc`) → GSD v2 (`npm:gsd-pi` 2.64.0); ruflo (`npm:ruflo` 3.5.58) added
- `install-plugins.sh`: STEP 4 GSD v2 (`npm install -g gsd-pi`), STEP 5 ruflo (manual instructions), steps renumbered 6-7
- `lib/detect-plugins.sh`: `detect_gsd()` now checks `command -v gsd` (not `~/.claude/skills/` grep); `detect_ruflo()` added
- `doctor.sh`: GSD v2 check, ruflo check, GStack false-positive fix, GStack pinning warning, EXPECTED_DENY 92→100, token budget Pro-aware with breakdown, `readlink -f` portability fix
- `hooks/session-start.sh`: GSD v2 removed from toggle loop → dedicated `🖥️  CLI` line; ruflo added to toggle loop
- `update-all.sh`: GStack confirmation prompt, GSD v2 update step, ruflo update step, steps renumbered 1-7
- `agents/plugin-advisor.md`: complete rewrite — PHASE 1 detection (GSD v2, ruflo), PHASE 2 signal table, full compatibility matrix, conditional rules, recommended sets by project type, WARN/BLOCK updated
- `link.sh`: `templates/` added to symlink loop
- `settings.json`: 92→100 deny rules, `disableAutoMode` added
- `README.md`: comprehensive update — GSD v2 full usage guide, ruflo install/usage, plugin compatibility matrix section, updated plugin table (GSD v2 as CLI, ruflo as TOGGLE), version pinning examples, troubleshooting entries for GSD v2 and ruflo, Known Limitations updated
- `version.txt`: 1.0.4 → 2.0.0

### Fixed
- `link.sh`: `templates/` not symlinked — scaffolder and init-project now find `~/.claude/templates/project-CLAUDE.md`
- `doctor.sh`: GStack submodule check was a false positive when directory existed but submodule was uninitialised
- `doctor.sh`: `readlink -f` fallback made explicit for BSD macOS compatibility
- `doctor.sh`: token budget used incorrect "~8000 tokens" reference — now uses Pro session budget (~11k)
- `doctor.sh`: EXPECTED_DENY hardcoded at 92 — updated to 100 after new deny rules
- `update-all.sh`: GStack update had no confirmation prompt — added; GStack step structure had mismatched `if/fi`
- `agents/plugin-advisor.md`: GSD detection used `ls ~/.claude/skills/ | grep gsd` — broken for v2 (CLI not a skill)
- `hooks/session-start.sh`: GSD v2 (standalone CLI) was in the CC plugin toggle loop — incorrect, moved to dedicated CLI line

## [1.0.4] — 2026-04-05

### Fixed
- `skills/*/SKILL.md`: agent paths changed from `.claude/agents/` to `$HOME/.claude/agents/` — unambiguous user-scope resolution regardless of working directory
- `hooks/session-start.sh`: `CONFIG_VERSION` now displayed in session-start box (was computed but never shown)
- `settings.json` + templates: removed non-standard `_readme` key (silently ignored by Claude Code but triggers schema warnings)
- `agents/plugin-advisor.md`: RTK detection re-added in PHASE 1 (was removed in v1.0.3 compression)
- `skills/health/SKILL.md`: fallback command simplified — removed 3-level quote nesting
- `install-plugins.sh`: removed duplicate "→ Restart Claude Code" line

### Changed
- README: Superpowers command table now shows actual skill names (`superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:subagent-driven-development`, etc.)
- README: install step 6 — replaced `/reload-plugins` (nonexistent command) with "Restart Claude Code — plugins load automatically"
- README: Context7 API key URL corrected from `context7.com` to `upstash.com`
- README: Known Limitations — clarified agent frontmatter fields ARE enforced in v2.1.x; added `disableAutoMode` note
- README: Makefile command list in Maintenance section now includes `make new-skill`
- `lib/detect-plugins.sh`: `detect_context7()` no longer spawns `claude` CLI — reads `~/.claude.json` and `~/.mcp.json` directly (no subprocess overhead at session start)

## [1.0.3] — 2026-04-05

### Token savings (~57% reduction across agents/skills)
- `CLAUDE.md`: 1414t → 418t (-70%) — rewritten as dense rule list, no prose padding
- `agents/plugin-advisor.md`: 1251t → 536t (-57%) — DECISION MATRIX removed (duplicated THRESHOLDS), output template compressed
- `agents/interviewer.md`: 1088t → 438t (-60%) — PROJECT BRIEF ASCII art → compact YAML-style, question groups flattened
- `agents/readme-updater.md`: 2224t → 792t (-64%) — Docker detection unified to one block, template skeleton condensed, phases as tight checklists
- `agents/scaffolder.md`: 2402t → 1041t (-57%) — Dockerfile/compose templates replaced by 3-line descriptions, Phase 0 compressed
- `skills/init-project/SKILL.md`: 2452t → 915t (-63%) — AGENTS LOADED section removed, each STEP condensed to 2-4 lines
- `skills/ship-feature/SKILL.md`: 1236t → 537t (-57%) — same treatment as init-project

### Changed behavior
- `agents/interviewer.md`: if prompt already contains name + purpose + stack + features + architecture → generate BRIEF directly, no questions asked
- `agents/readme-updater.md`: Docker detection defined once at top, referenced in all modes (no duplication)
- `hooks/session-start.sh`: always-on plugins (security-guidance, rtk, superpowers) now explicitly shown in session start display
- `skills/health/SKILL.md`: fallback path when `~/.claude/doctor.sh` not found (follows CLAUDE.md symlink to locate repo)
- `skills/plugin-check/SKILL.md`: argument-hint now shows concrete example

### Added
- `Makefile`: `make new-skill name=<n>` — scaffolds agent + skill files from template in one command
- `templates/project-CLAUDE.md`: inline examples per section (FastAPI-based) — usable without /init-project
- README: bundled skills section (`/batch`, `/debug`, `/simplify`)
- README: accurate progressive loading explanation (description only at startup, body on-demand)
- `link.sh`: idempotent — reports "already up to date" or count of updated symlinks

## [1.0.2] — 2026-04-04

### Security
- `Bash(git add .env*)` and `Bash(git add **/.env*)` added to deny — prevents staging secrets
- `Bash(cp **/id_rsa*)`, `Bash(cp **/id_ed25519*)`, `Bash(cp **/.ssh/*)` added to deny — closes SSH key copy bypass
- `deny` total: 87 → 92 rules
- `npx *` moved from allow to ask in project template settings — arbitrary npm package execution now requires confirmation
- `docker stop *` and `docker rm *` moved from allow to ask in project template settings

### Changed
- `skill-creator` and `pr-review-toolkit` reclassified from ALWAYS ON to TOGGLE — saves ~400 tokens/session by default
- `agents/scaffolder.md`: removed Go, PHP/WordPress, Flutter/Dart stack templates (unused)
- `CLAUDE.md`: STRICT MODE section removed — rules inlined into `skills/init-project/SKILL.md` and `skills/ship-feature/SKILL.md` where they apply, reducing global context weight
- `CLAUDE.md`: FAIL FAST MODE cleaned up (removed contradictory "override all" claim)
- `agents/readme-updater.md`: mode detection changed from substring match to exact first-word match — `/readme update X` no longer silently triggers SYNC mode
- `templates/settings/SETTINGS.md`: stripped sections duplicating README (precedence table, what-goes-where) — 132 → 58 lines
- `plugins.lock.json`: removed unused `install_cmd` and `node` fields
- README: GStack 14-command table collapsed to a single reference line
- README: plugin table updated to reflect new toggle status

### Fixed
- `install-plugins.sh`: GStack `./setup` now runs in subshell with existence+executable guard (same fix as update-all.sh)
- `install-plugins.sh`: log setup guarded against read-only filesystem — no longer crashes before output
- `install-plugins.sh`: `rtk init -g` now skipped if RTK hook already present in settings.json
- `doctor.sh`: CRLF detection ported from `grep -qP` (Linux-only) to `grep -c $'\r'` (portable macOS/Linux)
- `doctor.sh`: token budget breakdown now lists top consumers per file when estimate exceeds 2000 tokens
- `lib/detect-plugins.sh`: removed three never-called functions (`detect_security_guidance`, `detect_skill_creator`, `detect_pr_review_toolkit`)
- `hooks/session-start.sh`: removed unreachable inline fallback — replaced with clean exit message

## [1.0.1] — 2026-04-03

### Security
- `env` and `printenv *` moved from allow to deny — blocks secret exposure via process environment
- `export *` added to deny — prevents environment variable injection
- `cp .env*`, `cp **/.env*`, `mv .env*`, `mv **/.env*` added to deny — closes copy-then-read bypass on secret files
- `cp **/secrets/*`, `mv **/secrets/*` added to deny — extends secret move protection to secrets/ directory
- `sed *` moved from allow to ask — all sed (including in-place `-i`) now requires confirmation
- `sed -i *` and `sed -i'' *` removed from ask (consolidated into `sed *`)

### Changed
- `git stash*` (broad allow) split into safe variants in allow (`git stash`, `push*`, `list*`, `show*`) and destructive variants in ask (`pop*`, `drop*`, `clear`)
- `doctor.sh` token budget estimate now uses full skill/agent file sizes instead of description-only char count — produces accurate token estimates (~4 chars/token)
- `doctor.sh` deny rule count now checks against expected value (87) and warns on mismatch
- `doctor.sh` python3 one-liner wrapped in `|| echo "?"` — diagnosis no longer crashes on missing python3

### Fixed
- `update-all.sh` GStack `./setup` now runs in a subshell — upstream setup failure no longer crashes the update script mid-execution under `set -euo pipefail`
- `update-all.sh` guards `./setup` existence and executable bit before invoking it

## [1.0.0] — 2025-04-03

### Added
- 6 custom agents: analyzer, interviewer, plugin-advisor, readme-updater, refactorer, scaffolder
- 6 custom skills: analyze, init-project, plugin-check, readme, refactor, ship-feature
- 2 orchestrators with validation gates: init-project (13 steps), ship-feature (8 steps)
- Multi-OS install script (apt/dnf/pacman/brew)
- GStack as git submodule at skills-external/gstack
- Session start hook with plugin toggle status and health check
- Global settings.json with deny/ask/allow permission tiers
- Per-project templates: settings.json, settings.local.json, .claudeignore, project-CLAUDE.md
- Settings reference (SETTINGS.md)
- doctor.sh — full setup diagnostic
- update-all.sh — one-command update for all components
- plugins.lock.json — version pinning for non-marketplace dependencies
- /health skill — run doctor.sh from within Claude Code
- Makefile — unified entry point for install/link/doctor/update

### Security
- deny rules cover: destructive commands, secrets access, privilege escalation,
  code injection (eval, bash -c, xargs), pipe-to-shell, and secrets via bash (cat .env)
- disableBypassPermissionsMode enforced globally
- .claudeignore template with comprehensive exclusions
