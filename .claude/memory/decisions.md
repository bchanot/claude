---
type: decisions_registry
entry_prefix: BDR
schema:
  id: BDR-XXX
  date: YYYY-MM-DD
  title: string (<= 80 chars)
  decision: string (what was chosen)
  why: string (motivation, context)
  alternatives: list of strings (what was rejected + why)
  status: [proposed | accepted | deprecated | superseded]
  supersedes: BDR-XXX (optional)
rules:
  - Append-only. Never rewrite past entries - add new one with status superseded if needed.
  - One entry per non-trivial choice. Trivial = reversible under 10 min, no cross-file impact.
  - Capture why more carefully than what - what rots, why lasts.
---

# Decisions registry (BDR)

## Index

| ID | Date | Title | Status |
|----|------|-------|--------|
| BDR-001 | 2026-04-22 | Uniform --help helper via session-start hook (option C) | accepted · won't-build 2026-06-30 |
| BDR-002 | 2026-04-23 | Move tasks/ + introduce memory + audits under .claude/ | accepted |
| BDR-003 | 2026-04-23 | Gitignore wildcard + negations pattern for .claude/ | accepted |
| BDR-004 | 2026-04-27 | Adopt auto permission mode as default | accepted |
| BDR-005 | 2026-04-27 | `motion` as default animation library; advisor stays read-only | accepted |
| BDR-006 | 2026-05-03 | Caveman as 4th always-on plugin (output compression) | accepted |
| BDR-007 | 2026-05-04 | Skill profiles partition gstack by usage (design / dev / qa / audit / minimal) | accepted |
| BDR-008 | 2026-05-04 | Profile system v2: extend to plugins + MCPs + CLIs (web/seo/web-full/backend) | accepted |
| BDR-009 | 2026-05-05 | Mandate caveman format on .claude/memory/ registries | accepted |
| BDR-010 | 2026-05-07 | Gate GEO independently at ≥17/20 in client-handover pipeline | accepted |
| BDR-011 | 2026-05-07 | Client handover deliverable: 4-chapter structure + ZenQuality branded HTML/PDF | superseded by BDR-013 |
| BDR-012 | 2026-05-07 | client-handover cover: white bg + green accents + PNG logo default | accepted |
| BDR-013 | 2026-05-11 | client-handover: 6-chapter doc — promote scores §2 + NAP §4 | accepted |
| BDR-014 | 2026-05-11 | Personal SKILL.md descriptions: "Use when [triggers]…" pattern + 1024-char spec limit | accepted |
| BDR-015 | 2026-05-12 | Exclude broken gstack symlinks from /darwin-skill scope (external ownership) | accepted |
| BDR-016 | 2026-05-15 | doc-syncer: README AUTO+unconditional, DEPLOY.md prod-only + 14-section VPS template | accepted |
| BDR-017 | 2026-05-18 | `full` profile = web-full + plan + dev superset for /init-project MVP | accepted |
| BDR-018 | 2026-06-02 | `profile gstack on/off` verb — toggle gstack keeping active-profile label | accepted |
| BDR-019 | 2026-06-09 | Remove `disable-model-invocation` repo-wide — align skills with CLAUDE.md routing | accepted |
| BDR-020 | 2026-06-11 | `/audit-delta`: per-axis SHA markers + always-on fix gate + unreachable-first-run = full report-only | accepted |
| BDR-021 | 2026-06-27 | CLAUDE.md restructure: contradiction purge, project-specific sections labeled, critical sections never compressed | accepted |
| BDR-022 | 2026-06-18 | doc-syncer scoped to public docs; `.claude/` + `CLAUDE.md` read-only context, never targets; conventions + clean mode | accepted |
| BDR-023 | 2026-06-19 | Merge /close into /capitalize — 2 modes + TODO reconcile; /close alias | accepted |
| BDR-024 | 2026-06-27 | `profile show --plain` = claude-free parse contract for the design gate | accepted |
| BDR-025 | 2026-06-27 | Design gate profile-based; remedy `/profile design`; magic required-but-manual; unknown → fail-visible; claude via PATH-repair | accepted |
| BDR-026 | 2026-06-27 | Secret source-of-truth outside the repo (`~/.claude/.env`) reached via a `repo/.env` symlink | accepted |
| BDR-027 | 2026-06-27 | Minimal npm-via-nvm bootstrap over a centralized prereq lib | accepted |
| BDR-028 | 2026-06-27 | Hand-curated config install-immutable (auto-revert guard) + de-vendor installer-managed skills | accepted |
| BDR-029 | 2026-06-27 | Installer auto-fixes gstack browser on an OS newer than its pinned Playwright supports | accepted |
| BDR-030 | 2026-06-27 | gstack skills activated ON-DEMAND per profile, not pre-installed; OFF by default stays | accepted |
| BDR-031 | 2026-06-27 | global CLAUDE.md lightening = COMPRESSION, not path-scope / externalization | accepted |
| BDR-032 | 2026-06-27 | skill `/validate` → `/web-validate` (rename user surface, keep internals) | accepted |
| BDR-033 | 2026-06-27 | design-gate §4: anim-lib suggestion — suggest-only, non-blocking, stateless 1-line | accepted |
| BDR-034 | 2026-06-26 | Coupled-capitalize invariant v1 — memory commit auto per dev flow (Frame 2) | accepted |
| BDR-035 | 2026-06-26 | Analyze-before-plan invariant v1 — read-before bookend of coupled-capitalize | accepted |
| BDR-036 | 2026-06-27 | Doc-sync coupled invariant — commit docs doc-syncer patches (twin of BDR-034, BUILT not reordered) | accepted |
| BDR-037 | 2026-06-27 | v2 capitalize Stop-hook rejected → wire /capitalize+/close to the include | accepted |
| BDR-038 | 2026-06-27 | deploy skill: per-project learning runbook, two-moment cold-resume | accepted |
| BDR-039 | 2026-06-29 | Gitea branch protection = Option-1 owner-pushable, not require-PR | accepted |
| BDR-040 | 2026-06-29 | doc-syncer MINOR-shape oracle: deterministic floor under LLM's MINOR call | accepted |
| BDR-041 | 2026-06-30 | /reconcile = deterministic declared-vs-real engine + thin gated skill (reconciler, not lister) | accepted |
| BDR-042 | 2026-06-30 | /release-candidate = thin orchestrator over gitflow release; the tag lives in the skill, not the lib | accepted |
| BDR-043 | 2026-06-30 | BDR-015 trigger cleared — 5 ex-broken gstack symlinks repaired → darwin re-baseline back in scope (unblocked, NOT run) | accepted |
| BDR-044 | 2026-06-30 | auto-skill-dispatch won't-build — under-routing fear inverted to over-routing by cartography, then measured: model discriminates (clear→route, ambiguous→ask, trivial→abstain) | accepted · won't-build |
| BDR-045 | 2026-07-01 | Standalone memory/doc skills branch to chore/* via aiguillage (hook exemption kept) | accepted |
| BDR-046 | 2026-07-01 | Claude Code installs via official native installer (curl claude.ai/install.sh), drop npm from install.sh | accepted |
| BDR-047 | 2026-07-01 | ECC audit → zero import; local config ahead of reference | accepted |
| BDR-049 | 2026-07-03 | verifier = fresh + blind (no iteration history) + disk-contract + PROOF-or-fail; mute ≠ PASS; scope enrichment via human micro-gate | accepted |

---

## BDR-001 — Uniform --help helper via session-start hook (option C)

- **Date**: 2026-04-22
- **Status**: accepted
- **Decision**: every skill expose `--help` via shared snippet injected by session-start hook, not duplicate helper in each SKILL.md.
- **Why**: 25+ skills — keep same helper synced across every file guarantees drift. Single injection point = single source of truth.
- **Alternatives rejected**:
  - Option A (copy helper into each SKILL.md) — rejected: maintenance entropy.
  - Option B (external wrapper `/help <skill>`) — rejected: breaks "one command = one skill" experience.
- **Reference**: commit 3968a29.
- **Won't-build (2026-06-30)**: accepted but never built. MEASURED before building — behavioral RED, 6 reps (`/web-validate` + `/harden`, no instruction): **6/6 already render rich help AND stop without dispatching** (even `/harden` didn't start its audit). The intended behavior is already spontaneous (universal `--help` convention); the ONLY residual value of the global instruction = format CONSISTENCY across 6 divergent shapes — judged not worth ~5 lines in a [[BDR-031]]-compressed CLAUDE.md on a solo repo. Not "abandoned" — measured non-rentable. Per-skill option stays rejected (original Decision above). See [[LRN-080]], [[LRN-075]].

## BDR-002 — Move tasks/ + introduce memory + audits under .claude/

- **Date**: 2026-04-23
- **Status**: accepted
- **Decision**: migrate `./tasks/` to `.claude/tasks/`, create `.claude/memory/` (5 registries BDR/LRN/BLK/journal/EVAL) and `.claude/audits/` for AUDIT_* files. Adapt skills/agents/CLAUDE.md. Integrate CAPITALIZE step into completion skills (ship-feature, feat, bugfix, hotfix, commit-change), add `/close` skill for session-end ritual.
- **Why**: group all meta-project state (AI config + tasks + memory + audits) under `.claude/` isolate Claude governance from real code. Aligned with official Claude Code memory docs. Without integration in completion skills, registries stay empty (aspirational text).
- **Alternatives rejected**:
  - Keep `./tasks/` at root — rejected: clutters repo, mixes code signal with governance signal.
  - Use `.claude/agent-memory/` for everything — rejected: `agent-memory/` has distinct role (already used by other tools).
  - Ritual as aspirational text only in CLAUDE.md — rejected: zero execution guarantee, registries stay empty.
  - `Stop` hook to ask 3 questions every turn — rejected: too noisy.

## BDR-003 — Gitignore wildcard + negations pattern for `.claude/`

- **Date**: 2026-04-23
- **Status**: accepted
- **Decision**: use `.claude/*` (wildcard match of immediate children) + negations `!.claude/tasks/`, `!.claude/memory/`, etc., not `.claude/` (recursive ignore).
- **Why**: when parent ignored via `.claude/`, git no descend (performance optimization) and negations on children **ignored** — documented in `gitignore(5)`. With `.claude/*`, git matches each child individually, negations active.
- **Alternatives rejected**:
  - `.claude/` + `!.claude/tasks/` (naive) — rejected: negations no effect, everything stays ignored.
  - Drop `.claude/` from gitignore entirely — rejected: `.claude/settings.local.json` and `.claude/agent-memory/` must stay ignored (per-machine).
  - Track paths via `.gitattributes` or external tool — rejected: over-engineering, git handles natively.
- **Reference**: commit `499cd07`, `git check-ignore -v` verified on 4 paths (2 tracked, 2 ignored).

## BDR-004 — Adopt auto permission mode as default

- **Date**: 2026-04-27
- **Status**: accepted
- **Decision**: set `permissions.defaultMode` to `"auto"` in user-scope `settings.json`, drop `disableAutoMode: "disable"`. Auto mode runs classifier on every action, blocks risky operations (`curl|bash`, prod deploys, force push, IAM grants, mass deletes, exfiltration to external endpoints), auto-approves local edits, lockfile-declared dep installs, read-only HTTP.
- **Why**: prompt fatigue under `default` mode big on multi-step autonomous work. Auto mode keeps safety net (classifier review) without per-tool friction. Classifier re-evaluates conversation-stated boundaries ("don't push", "wait for review") on every check, verbal constraints carry weight.
- **Alternatives rejected**:
  - Keep `default` — too many prompts, breaks flow on long tasks.
  - `acceptEdits` — eliminates prompts but no classifier, blanket trust on Bash beyond filesystem helpers.
  - `bypassPermissions` — skips all checks, no prompt-injection guard. Only for isolated containers.
  - `dontAsk` — full denylist, breaks anything not pre-approved. Suited to CI, not interactive work.
- **Caveats**: requires Claude Code v2.1.83+, plan ≠ Pro (Max/Team/Enterprise/API only), Sonnet 4.6 / Opus 4.6 / Opus 4.7, Anthropic API provider. On entering auto mode, blanket allow rules (`Bash(*)`, `Bash(python*)`, package-manager run, `Agent`) dropped, restored on exit.
- **Reference**: commit `1421578`.

## BDR-005 — `motion` as default animation library; advisor stays read-only

- **Date**: 2026-04-27
- **Status**: accepted
- **Decision**: when project stack supports it, framework installs `motion` (or `motion-v` for Vue 3 / Nuxt) as default animation library. Install **automatic** in `/init-project` STEP 5e (post-scaffold), **opt-in** in `/onboard` STEP 2.5 (existing projects). `plugin-advisor` only **detects and reports** status — never runs `npm install` itself. Detection logic in `lib/animation-lib-check.sh` (sourced by all three layers).
- **Why**: framer-motion rebranded `motion` in November 2024 (single package supporting React `motion/react`, Svelte, vanilla JS; `motion-v` parallel package for Vue). Bake new name now to avoid legacy-import sprawl across new projects. Split init-vs-onboard behavior follows trust gradient: at init, user just validated entire scaffold so silent install fine; at onboard, touching existing `package.json` invasive without explicit consent. Plugin-advisor kept read-only to preserve "Never modify files" contract (PHASE 4 already mutates plugin state with confirmation; piling npm installs on top blurs responsibility).
- **Alternatives rejected**:
  - Pin `framer-motion` (legacy name) — rejected: package in maintenance mode, every new project inherits old import path.
  - Auto-install during `/onboard` without asking — rejected: silently adds runtime dep + ~50 KB gzip to project user did not ask to modify.
  - Make `plugin-advisor` install missing libs — rejected: violates read-only spec, breaks separation of concerns (advisor advises; orchestrators mutate).
  - React-only scope — rejected: Vue/Svelte teams should benefit; `motion-v` makes Vue case clean.
- **Eligibility rules** (helper output):
  - `eligible|motion`: React, Next.js, Remix, Astro+React, Svelte/SvelteKit
  - `eligible|motion-v`: Vue 3, Nuxt
  - `no|-`: backend, CLI, embedded, Flutter, static HTML, **React Native** (use `react-native-reanimated`), Astro without UI integration, no `package.json`
- **Reference**: helper at `lib/animation-lib-check.sh`; integration in `skills/init-project/SKILL.md` STEP 5e, `skills/onboard/SKILL.md` STEP 2.5, `agents/plugin-advisor.md` PHASE 1/2/3, `lib/design-gate.md`.

## BDR-006 — Caveman as 4th always-on plugin (output compression)

- **Date**: 2026-05-03
- **Status**: accepted
- **Decision**: install `JuliusBrussee/caveman` in always-on tier alongside `security-guidance`, `superpowers`, `rtk`. "Full" install = plugin (`/caveman` + cavecrew agents + plugin-scoped SessionStart/UserPromptSubmit hooks) + standalone hooks (statusline + stats badge in `~/.claude/hooks/`) + `caveman-shrink` MCP scaffold (NOT auto-registered — proxy needs upstream wrapper). `install-plugins.sh` STEP 5.5 calls `enable_plugin "caveman" "caveman"` to write into `enabledPlugins`. Hook paths in `settings.json` normalized to `~/.claude/hooks/...` post-install so user home dir no leak across machines.
- **Why**: caveman compresses Claude output ~75% via caveman-speak, preserves technical substance. Symmetrical with rtk (input compression hook) — rtk shrinks tool I/O, caveman shrinks model output. Both hooks pay zero passive cost in clean session, amortize across long runs. Always-on justified: plugin auto-deactivates with phrases like "stop caveman" / "normal mode", toggle would be friction without benefit.
- **Alternatives rejected**:
  - Toggle plugin (start OFF) — rejected: misses by-default benefit; user need remember `claude plugin enable caveman@caveman` per session, negates auto-compression value.
  - `--minimal` install (plugin only) — rejected: loses standalone stats badge surfacing token-saving telemetry.
  - `--all` install (adds per-repo `caveman-rules.md` etc. into `$PWD`) — rejected: would litter THIS config repo (cwd at install time) with rule files meant for project repos. Let users opt in per-repo when wanted.
  - Auto-register `caveman-shrink` MCP — rejected: proxy errors with "missing upstream command" without upstream MCP to wrap, fails health checks. Print snippet instead, let user pick which upstream they want compressed (filesystem, github, …).
- **Caveats**:
  - Caveman `hooks/install.sh` writes absolute paths (`$HOME/.claude/hooks/caveman-*.js`) into `settings.json`. `settings.json` symlinked into repo, absolute path commits username. STEP 5.5 runs Python post-process to rewrite to portable `~/.claude/hooks/...` form (bash expands `~` before passing to `node`).
  - Caveman hook files materialize in `hooks/` (repo dir, not `~/.claude/hooks/`) because latter is symlink. Added to `.gitignore` to prevent accidental commit of user-scope state.
- **Reference**: install-plugins.sh STEP 5.5, lib/detect-plugins.sh `detect_caveman*` + `plugin_enabled`, doctor.sh caveman block, commit `9b20b84`.

## BDR-007 — Skill profiles partition gstack by usage (design / dev / qa / audit / minimal)

- **Date**: 2026-05-04
- **Status**: accepted
- **Decision**: ship `lib/profile.sh` + `lib/profiles/*.profile` to give user fine-grained, task-shaped activation of skills. Profile = plain-text file listing skill names + types (`gstack`, `external`, `personal`, `plugin`, `mcp`). `profile set <name>` enables listed skills, disables every gstack-origin skill not in profile, by moving symlinks between `skills/` and `skills-disabled/`. `profile reset` re-enables all of gstack. Plugin/MCP entries advisory — script prints manual `claude plugin enable` / `claude mcp add` command but never runs it. Surface area: one CLI (`bash lib/profile.sh`), one slash command (`/profile`), four Makefile targets, section in `agents/plugin-advisor.md`.
- **Why**: when user works on focused kind of task (design only, qa only, audit only) full gstack (~38 skills) injects irrelevant skill descriptions into every session. Existing `lib/toggle-external.sh enable|disable gstack` too coarse — disables whole gstack including infrastructure skills user does want (checkpoint, ship, learn). Profiles give curated middle ground: keep gstack repo installed, hide skills not relevant to this session.
- **Alternatives rejected**:
  - Fork SKILL.md files to strip ~70-line gstack preamble — rejected: every gstack upgrade needs re-fork, preamble already degrades gracefully (`|| true`) when `gstack/bin/` unavailable. Hiding skill cheaper than rewriting.
  - Per-skill toggle via `claude plugin enable/disable` — rejected: gstack skills not marketplace plugins, symlinks owned by `skills-external/gstack/`. CLI no reach them.
  - Disable via removing symlinks (rm + recreate on enable) — rejected: lossy if user has local edits, re-creation requires running gstack own setup. Move-based toggle preserves symlink intact.
  - Auto-toggle plugins (`ui-ux-pro-max`) and MCPs as part of `set` — rejected: those affect global Claude Code state, may carry API keys (magic). Keep advisory; user runs CLI command knowingly.
  - Build giant `gstack-profile` CLI wrapping `gstack/bin/*` directly — rejected: scope creep into gstack internals. Repo already has own toggle infra (`lib/toggle-external.sh`); profile.sh sits alongside as finer tool.
- **Caveats**:
  - Profiles do NOT change `gstack/bin/` infrastructure — preamble in disabled skills still references it, re-enabling restores normal behavior. No telemetry/learnings data touched.
  - `cmd_set` only auto-disables skills returned by `gstack_skills()` (those with `SKILL.md` under `skills-external/gstack/*/`). Personal skills (real dirs in `skills/`) never auto-disabled by `set` — only added back if listed in profile.
  - `cmd_current` returns "full" when nothing disabled, even if profile happens to be 100% covered by current state. Active-profile heuristic requires at least one `gstack__*` entry in `skills-disabled/` so we no lie about profile being "set" when no `set` ever ran.
  - Personal skills use `external`-style move (no `gstack__` prefix) so name-collision with gstack skills cannot happen during disable.
- **Reference**: `lib/profile.sh`, `lib/profiles/{design,dev,qa,audit,minimal}.profile`, `skills/profile/SKILL.md`, `agents/plugin-advisor.md` (DETECT block + TOGGLING EXTERNAL TOOLS section), `Makefile` targets `profile*`, `lib/toggle-external.sh` header pointer.

## BDR-008 — Profile system v2: extend to plugins + MCPs + CLIs (web/seo/web-full/backend)

- **Date**: 2026-05-04
- **Status**: accepted
- **Decision**: extend `profile.sh` to actually toggle Claude plugins (`claude plugin enable|disable <name>@<marketplace>`) and MCP servers (delegated to `lib/toggle-external.sh` for `magic` MCP, advisory for others), add CLI status reporting. New profile syntax uses `plugin@<marketplace>` so script knows where to enable from. New profiles shipped: `web` (frontend website), `seo` (SEO/GEO/W3C audit), `web-full` (web + seo combined), `backend` (API/system dev — no design, no SEO). Reverted v1 decision (BDR-007 alternative #4 "advisory only for plugins/MCPs"): user explicitly asked for actual toggling so `set web` actively enables `ui-ux-pro-max` + `magic`, `set seo` actively disables `ui-ux-pro-max`. Always-on plugins (`caveman`, `security-guidance`, `superpowers`) protected by both allowlist (`MANAGED_PLUGINS`) and denylist (`PROTECTED_PLUGINS`).
- **Why**: v1 profiles only managed skills (symlink toggle). User feedback: "active TOUT le splugins necessaire pour tel profile et desactive les autre". Pure-skill toggling left ui-ux-pro-max/magic always loaded regardless of profile, passive token cost no drop as much as expected when switching to non-design profile. Auto-toggling plugins shifts design from "show me right skills" to "set up right session" — closer to what user actually wants.
- **Alternatives rejected**:
  - Keep plugins advisory + add `--apply-plugins` flag — rejected: user has to type flag every time, defeats "switch profile to switch context" workflow.
  - Disable ALL non-listed plugins (including third-party user-installed ones) — rejected: too aggressive. Profile system has no business touching plugins user installed for own reasons. Solution: explicit `MANAGED_PLUGINS` allowlist (currently 3 entries) — script touches only those.
  - Treat MCPs identically to plugins (auto-toggle any MCP) — rejected: MCPs typically need env vars / API keys / specific commands. Auto-registering with wrong config produces broken MCPs (LRN-006). Compromise: auto-toggle ONLY `magic` because already have its config in `lib/toggle-external.sh`. Other MCPs stay advisory.
  - Track plugin state across `set/reset` cycles, restore on reset — rejected: complexity not worth it. `reset` re-enables gstack skills only. To re-enable managed plugin, user runs `apply <profile>` or explicit `claude plugin enable` command. Documented in `info` line printed at end of `reset`.
- **Caveats**:
  - `MANAGED_PLUGINS` hardcoded — adding new toggle-managed plugin requires editing `profile.sh`. Acceptable for now (3 entries, rarely changes); revisit if grows.
  - `claude plugin enable` returns success even for already-enabled plugins, parser greps for "enabled|already" in stdout/stderr. Works on current Claude CLI; brittle if CLI rewords messages. Acceptable risk.
  - `current` heuristic now counts `installed` (CLI status) as available. Without that, profiles listing CLIs would never reach 100% match. Tiebreaker: when two profiles tie on %, larger total wins (web-full > web > design when all are 100%).
  - `cmd_show` widened TYPE column to 30 chars to fit `plugin@ui-ux-pro-max-skill` without breaking alignment.
  - `mcp magic` toggle delegates to `lib/toggle-external.sh enable magic` which requires `MAGIC_API_KEY` in `.env`. If key missing, profile.sh prints info line and continues — rest of profile still applies.
- **Reference**: `lib/profile.sh` (`MANAGED_PLUGINS`/`PROTECTED_PLUGINS` arrays, `skill_status` plugin@/cli/mcp branches, `enable_skill`/`disable_skill` plugin@ + mcp branches, `cmd_set` plugin disable loop, `cmd_current` available-counting), `lib/profiles/{web,seo,web-full,backend}.profile`, refined `lib/profiles/{design,dev,qa,audit}.profile` (use `plugin@<marketplace>` syntax + `cli` entries), `skills/profile/SKILL.md` (updated profile table + mechanism table), `agents/plugin-advisor.md` (extended profile recommendation table).

## BDR-009 — Mandate caveman format on .claude/memory/ registries

- **Date**: 2026-05-05
- **Status**: accepted
- **Decision**: all writes to `.claude/memory/*.md` (decisions, learnings, blockers, journal, evals) MUST use caveman style — drop articles (a/an/the), drop filler (just/really/basically/actually/simply), fragments OK, short synonyms (big not extensive, fix not "implement a solution for"). Keep technical terms exact, code blocks unchanged, error messages quoted exact, IDs (BDR-XXX, LRN-XXX, BLK-XXX, EVAL-XXX) and dates unchanged. Pattern: `[thing] [action] [reason]. [next step].` Rule added to `CLAUDE.md` "Memory registries" section. Applied retroactively to existing 5 registries via `/caveman:compress`. Pre-compression backups saved as `*.original.md` (gitignored).
- **Why**: registries loaded every session start (per CLAUDE.md "Session start" step 1) — every token compressed cuts permanent input cost. Measured ~40% input-token reduction across 5 files (164→97 lines on average per registry). Caveman style preserves all technical substance (code, IDs, error strings, refs) while dropping prose padding that no engineer needs at re-read. Rule mirrors English-only rule that already governs registries — both about read-efficiency, not aesthetics.
- **Alternatives rejected**:
  - Compress only on new entries, leave existing prose untouched — rejected: every session-start still pays 40% prose tax on legacy entries (largest part of file). Mixed-style file harder to scan than uniform compressed file.
  - Use lighter compression (drop only fillers, keep articles) — rejected: half-measure. Caveman lite saves ~15%, full saves ~40%. Cost identical (one /caveman:compress run).
  - Move registries to JSON/YAML for max density — rejected: registries are narrative (BDR rationale, LRN context). YAML/JSON would lose nuance, force schema rigidity. Caveman keeps prose readable, just compressed.
  - Skip rule, rely on writers to compress organically — rejected: untested writers (skills, future agents) revert to verbose prose. Explicit rule + caveman-mode-active hook ensures consistency without per-skill enforcement.
- **Caveats**:
  - Code blocks, error strings, commit refs, IDs, dates, file paths MUST stay byte-exact — caveman applies to prose only.
  - User-facing CAPITALIZE prompts may stay verbose / mirror user language; rule applies only to written entry.
  - `*.original.md` backups gitignored (BDR-009 commit `639486a`) — recoverable via git history of pre-compression commit.
  - Existing registries entries compressed in commit `e4a9259`; new entries written caveman from start (BDR-009 itself is first such entry).
- **Reference**: `CLAUDE.md` "Format — registries ALWAYS caveman" section, commits `520188a` (rule added), `e4a9259` (5 registries compressed), `639486a` (gitignore backups).

## BDR-010 — Gate GEO independently at ≥17/20 in client-handover pipeline

- **Date**: 2026-05-07
- **Status**: accepted
- **Decision**: client-handover gates SEO classique AND GEO (IA) independently — both must reach `≥17/20`. Was: combined display only, gate fired on first `/20` line found (de facto SEO classique alone). Now: `ALL_PASS = (SEO_AFTER ≥ 17) AND (GEO_AFTER ≥ 17) AND (HARDEN_AFTER ≥ 17) AND (VALIDATE_AFTER ≥ 17 OR SKIPPED)`. SEO subagent re-dispatched if either axis below threshold (same agent fixes both). Score table + roadmap + client doc §4 split rows accordingly.
- **Why**: handover deliverable claims "site ready" — bar must hold on classical search (Google/Bing) AND AI search (ChatGPT/Perplexity) given AI traffic growth. Combined gate (e.g. global pondéré ≥17) lets GEO stay weak while combined passes — false confidence shipped to client. Independent gates close gap.
- **Alternatives rejected**:
  - Gate on `Score global pondéré ≥17` only — rejected: SEO=20 + GEO=10 → global=18 → passes despite GEO=10. Same false-confidence issue.
  - Keep GEO informational (Phase A initial design) — rejected: breaks "every gated audit ≥17 or stop" rule. Two-tier system (gated vs informational) confuses client + breaks score-table semantics.
  - Lower GEO threshold to ≥15 — rejected by user: weakens signal. Real fix is optimize GEO, not lower bar.
  - Split into two parallel subagents (one SEO, one GEO) — rejected: /seo skill runs both inside one envelope-merge dispatcher. Splitting at handover layer duplicates context discovery (STEP 0) + doubles wall-clock.
- **Caveats**:
  - GEO ≥17 hard on existing sites — most lack llms.txt, Speakable/QAPage Schema, entity SEO (sameAs/Wikidata @id), TL;DR/Q→A content shape. Expect more fix-loop iterations on GEO than SEO. Override option C still per-axis with explicit user consent.
  - `SCORE_GEO_AFTER = "UNKNOWN"` treated as fail — legacy single-score SEO.md triggers re-dispatch with explicit demand for both labeled lines (`Score SEO (classique) : X.X / 20` + `Score GEO (IA) : X.X / 20`).
  - Backward compat split: `extract_score_labeled` SEO uses `allow_fallback=yes` (legacy single-score parses as SEO classique); GEO uses `allow_fallback=no` (no silent duplicate of SEO score).
  - Loop logic axis-aware: `while (SEO < 17 OR GEO < 17) AND iter ≤ MAX`. Re-dispatch prompt labels both scores with PASS/FAIL + lists axis-specific fixes (SEO: meta/canonical/sitemap; GEO: llms.txt/Schema AI/entity SEO).
- **Reference**: commit `5569a80`, `agents/client-handover-writer.md` (STEP 3 `extract_score_labeled`, STEP 4 axis-aware loop + re-dispatch prompt, STEP 8 gate rule + score table + threshold strictness, STEP 12 §4 client doc table), `skills/client-handover/SKILL.md`.

## BDR-011 — Client handover deliverable: 4-chapter structure + ZenQuality branded HTML/PDF

- **Date**: 2026-05-07
- **Status**: superseded by BDR-013
- **Decision**: client handover doc restructured to 4 chapters — §1 *Ce qu'il fallait faire (et pourquoi)* (briefing+motivation, 100–180 words), §2 *Ce qui a été fait* (lay summary, **≤300 words hard cap, zero jargon, no internal tool/skill names**), §3 *Ce qui vous reste à faire* (action-only checklist with cadences), §4 *Détails techniques (pour les curieux)* (scores, key choices, phases, optional glossary — internal labels allowed here only). Plus optional §5 (external platforms, web), §6 (build & deploy). Replaces old 9-section structure. Output now triple: `LIVRAISON.md` (editable source) + `LIVRAISON.html` (always, branded) + `LIVRAISON.pdf` (when PDF engine on host). HTML/PDF use ZenQuality identity — green palette `#1A3A25 / #2D5A3D / #4A7C59 / #87A878`, cream BG `#F5F0EB`, fonts Inter (body) + Playfair Display (headings), cover page with logo + tagline "La sérénité numérique, la qualité en plus", running header (project name) + footer (page N/M, `ZenQuality — zenquality.fr`). Renderer cascade: MD→HTML via pandoc > python markdown > `npx marked`; HTML→PDF via weasyprint > wkhtmltopdf > chromium > headless Chrome. STEP 15 enforces gates before render: chapter 2 word count ≤300 (`wc -w`) AND forbidden-token grep on chapters 1–3 (no `/seo`, `/harden`, `/validate`, `/cso`, `seo-analyzer`, `SEO.md`, `SCORE_*`, etc.).
- **Why**: client reads top-down, may stop after §2 — old 9 sections diluted the read. Bare markdown unreadable by non-tech client. Branded PDF = professional deliverable matching company identity (ZenQuality), suitable to email/print/sign. Per-section gates prevent regression to skill-name leaks or jargon bloat.
- **Alternatives rejected**:
  - Keep 9-chapter structure + bolt PDF wrapper on top — rejected: doesn't fix dilution + leak risk; client still scans through "Lessons learned (optional)" / "Pour aller plus loin" before useful actions.
  - Render PDF only (no HTML intermediate) — rejected: no fallback if engine missing; HTML doubles as browser preview + manual print-to-PDF route. Triple output (`md` + `html` + `pdf`) covers all cases.
  - Single PDF engine (e.g. weasyprint only) — rejected: assumes Python installed; cascade gives graceful degradation. Order chosen: weasyprint (best CSS), wkhtmltopdf (mature), chromium (always-bundled on dev hosts).
  - Pandoc with custom template only — rejected: pandoc often not installed (was missing on this host); shell cascade with multiple converters more portable.
  - Soft 300-word target — rejected: without hard `wc -w` gate, drift inevitable. Cap+gate forces rewrite when over.
- **Caveats**:
  - Word-count + leak gates run at STEP 15 *after* synthesis, not during. Worst case: re-write step needed. Acceptable trade-off vs in-flight enforcement (would require word counter inside agent prompt — fragile).
  - ZenQuality logo URL hardcoded as `https://zenquality.fr/logo-horizontal.svg`; `LOGO_URL` env var allows local file override (bake into PDF for offline robustness if branding changes / SVG breaks).
  - PDF cascade detects via `command -v` only — assumes engines on `$PATH`. Custom installs need `$PATH` adjusted before invocation.
  - Bash heredoc + stdin-pipe collision bug in v1 (silent empty output) — fixed via env-var pass-through (LRN-012).
  - Renderer always outputs HTML + tries PDF; on PDF failure exits 2, prints install hints. STEP 16 reports `PDF: NOT GENERATED` with hints in final report.
  - Optional glossary in §4.4 listed terms (HSTS, CSP, WCAG, Schema.org, llms.txt, SEO/GEO) — only renders if ≥4 of these appear in §4 body.
- **Reference**: commit `e06b52a`, `agents/client-handover-writer.md` (STEP 12 4-chapter doc structure + tone rules, STEP 15 word-count + leak gates, STEP 16 RENDER pipeline, STEP 17 final report), `skills/client-handover/scripts/handover-to-pdf.sh` (cascade renderer), `skills/client-handover/resources/branding/zenquality.css` (ZenQuality print stylesheet), `skills/client-handover/resources/branding/zenquality-template.html` (HTML wrapper with placeholders).
---

## BDR-012 — client-handover cover: white bg + green accents + PNG logo default

- **Date**: 2026-05-07
- **Context**: original `.cover` CSS used cream `--white-cream` (#F5F0EB) bg + 8mm green stripe top. Washed out. SVG logo `logo-horizontal.svg` blended into cream bg = low contrast. User feedback: "couleur du fond n'est pas bon", "utiliser une icone non white". Tried green-dark bg first (rejected — too heavy for client-facing doc, hurt readability of long meta block).
- **Choice**: `.cover` bg → `--white-pure` with two subtle radial tints (sage top-right rgba(135,168,120,0.18), green-forest bottom-left rgba(45,90,61,0.06)). Body text → `--black-deep`. Title `--black-deep`. Eyebrow/meta labels/footer → `--green-forest` (medium green). Meta border-left + meta-strong → `--green-forest`. Removed `.cover::before` 8mm stripe. Default `LOGO_URL` → `https://zenquality.fr/assets/logo-horizontal-1024.png`.
- **Alt rejected**: (a) cream `#F5F0EB` bg — washed-out, original problem. (b) solid green-dark bg — too heavy, hurt long-text readability, felt like marketing brochure not deliverable. (c) generic white + black — no brand signal.
- **Why**: light theme with green accents matches zenquality.fr without overpowering. White bg keeps long client-facing text readable. Green-forest on white = WCAG AA contrast + brand cue. Subtle radial gradients add depth without weight.
- **Status**: shipped.
- **How to apply**: ZenQuality client-facing print docs default to white bg + green-forest accents. Body interior keeps cream `--white-cream` as accent (code blocks, blockquote bg) — not as page bg. Solid green-dark reserved for marketing covers, not deliverables.
- **Reference**: `skills/client-handover/resources/branding/zenquality.css` `.cover` block (line 71-86 bg, 119-149 typography); `scripts/handover-to-pdf.sh` line 107 (LOGO_URL default); `agents/client-handover-writer.md` line 1218-1222 (doc updated).

---

## BDR-013 — client-handover: 6-chapter doc — promote scores §2 + NAP §4

- **Date**: 2026-05-11
- **Status**: accepted (supersedes BDR-011 4-chapter structure)
- **Decision**: deliverable restructured 4→6 chapters. §1 brief+why (100–180 words). **§2 NEW = score table (avant/après)** promoted from old §4 technical annex to top of doc. §3 = lay summary ≤300 words zero jargon (formerly §2). **§4 NEW = NAP single-source-of-truth table** (Nom/Adresse/Téléphone/Email/Catégorie/Description courte/Horaires) promoted from §7 annex. §5 = action checklist by cadence (formerly §3). §6 = tech details for curious (formerly §4, score table removed — now in §2). §7/§8 still optional annexes (external platforms, build+deploy).
- **Why**: local-business client opens deliverable, scans first 30s — needs **immediate visual proof of impact** (scores §2) before reading prose. Tested with handover clients: scores up-front converts "what did I pay for?" doubt within 30 seconds. NAP §4 prerequisite chapter before §5 todo list — client's todos reference NAP values constantly ("create Google Business with these values"); if NAP buried in §7 annex, client scrolls deep mid-todo, types inconsistent values across platforms, degrades Google NAP-consistency signal.
- **Alternatives rejected**:
  - Keep 4-chapter + add score sentence inside §2 prose — rejected: lost the visual proof-of-impact moment, table reads stronger than prose.
  - Keep NAP in §7 external-platforms annex — rejected: client types 10 different descriptions/addresses while working through §5 todos before reaching §7.
  - Compact 3-chapter doc with scores+NAP inline — rejected: too dense, kills lay-summary flow + chapter 3 word-count gate harder to enforce.
  - Two-doc deliverable (summary PDF + NAP/todos PDF) — rejected: doubles attachments, client opens only one.
- **Caveats**:
  - Forbidden-token grep gate at STEP 15 now covers §1–§3 (was §1–§3 already, no change). §4 NAP table contains only client input placeholders [À COMPLÉTER] — no tool/skill leak risk.
  - Pandoc requires `gfm+gfm_auto_identifiers` extension to resolve `[§4](#nap)` internal links (LRN-014).
  - §2 score lecture-rapide must stay plain French — numbers OK but no internal labels (`Score SEO classique` allowed because vulgarized; `seo-analyzer`/`SEO.md` forbidden).
- **Reference**: commit `b15b275`, `agents/client-handover-writer.md` (chapter list lines 20–60, prose framing §2 + §4 rationale lines 30–55, STEP 12 template), `skills/client-handover/scripts/handover-to-pdf.sh` line 121 (pandoc gfm_auto_identifiers).

---

## BDR-014 — Personal SKILL.md descriptions: "Use when [triggers]…" pattern + 1024-char spec limit

- **Date**: 2026-05-11
- **Status**: accepted
- **Decision**: all personal SKILL.md descriptions must follow `Use when [specific triggering conditions and symptoms]` pattern. Workflow summaries forbidden in description (e.g. `Ship feature: design → plan → implement → review`). Frontmatter total ≤1024 chars per agentskills.io spec. Workflow detail belongs in SKILL.md body, not description. Triggers list compressed and deduped.
- **Why**: superpowers:writing-skills documented (with test evidence) that workflow summaries in description create **shortcut risk** — Claude reads description, treats it as the skill, and skips reading the body. Test case: description "code review between tasks" caused Claude to do ONE review when skill flowchart had TWO. Removing workflow summary → Claude read flowchart, did 2 reviews. Description's job is to TRIGGER retrieval, not to BE the skill. 1024-char cap is the platform spec limit (agentskills.io/specification); 5 personal skills (client-handover, doc, seo, geo, validate) were 1050–1920 chars — non-compliant.
- **Alternatives rejected**:
  - Free-form descriptions (status quo) — rejected: drift + shortcut risk, 5 skills already spec-violating.
  - Hard cap ≤500 chars per writing-skills target — preferred for new skills but hard retrofit on multi-language trigger lists (FR+EN keywords blow past 500). Use 1024 as enforced ceiling, ≤500 as aspirational.
  - Per-skill judgment with no rule — rejected: inconsistent, no enforcement gate.
  - Move trigger keywords to body — rejected: triggers in description is what Claude uses for routing; body content doesn't help routing.
- **Caveats**:
  - Orchestrators still describe orchestration role explicitly (e.g. client-handover: "Multi-agent orchestrator: dispatches the client-handover-writer agent which spawns parallel /seo + /harden subagents") — that's role identification, not workflow summary.
  - Other 10 personal skills (analyze, bugfix, code-clean, commit-change, feat, hotfix, plugin-check, refactor, status, skills-perso) still partially summarize workflow but stay under 1024 chars. Not retrofitted in this pass — flagged for follow-up only if shortcut symptoms observed.
- **Reference**: commit `1da6a31`, 8 SKILL.md files (client-handover, doc, geo, seo, validate, ship-feature, init-project, onboard), superpowers:writing-skills "CSO" section, agentskills.io/specification.

---

## BDR-015 — Exclude broken gstack symlinks from /darwin-skill scope (external ownership)

- **Date**: 2026-05-12
- **Status**: accepted
- **Decision**: 5 dirs in `~/Documents/claude/skills/` whose `SKILL.md` symlinks point to non-existent gstack paths (`skills-external/gstack/<name>/SKILL.md` missing) — `benchmark-models`, `context-restore`, `context-save`, `make-pdf`, `plan-tune` — are excluded from `/darwin-skill` baseline + optimization. Marked `status=error` in `results.tsv` with note `broken gstack symlink — out of scope`. NOT scored, NOT optimized, NOT deleted.
- **Why**: darwin-skill constraint #1 forbids changing a skill's core function — implies external/gstack-owned skills are out of scope. Symlinks resolve to `skills-external/gstack` which is third-party submodule. Plus the targets are broken — gstack's actual layout (`benchmark/`, `health/`, `qa/`, etc.) doesn't include these 5 names, suggesting upstream rename or removal. Repairing them is a separate triage task, not darwin's concern.
- **Alternatives rejected**:
  - Fix symlinks first then darwin-optimize → out of scope, blocks the optimization queue on gstack archaeology.
  - Score them with `FILE_NOT_FOUND` and include in averages → biases stats, mixes signal with infrastructure issue.
  - Optimize the gstack source files directly → external ownership, never modify.
  - Delete the broken symlinks → would obscure that the user once expected these to exist; leave for triage.
- **Caveats**:
  - If/when symlinks are repaired (real gstack target exists), re-run baseline to bring them in scope.
  - Bigger picture: `benchmark-models` looks like a deliberate rename of gstack's `benchmark` to disambiguate from the gstack-skill called `/benchmark`. Could be a planned migration that stalled. Worth a one-line ticket separate from darwin.

---

## BDR-016 — doc-syncer: README AUTO+unconditional, DEPLOY.md prod-only + 14-section VPS template

- **Date**: 2026-05-15
- **Status**: accepted
- **Decision**: `agents/doc-syncer.md` STEP 5/6/8/A4 rewritten. README creation now AUTO + unconditional in both interactive and AUTO modes. Validation gate offers only `yes` or `edit` for README — no `skip`/`no`. Any project-level "no README" opt-out (e.g. `CLAUDE.md` "Exceptions: No README at scaffold") gets struck through during same patch. README template expanded: features, Stack, Quick start (dev), Verifying a change, Build & deploy, Documentation, License — all rendered from real manifest/`.env.example`/scripts data, no placeholders. DEPLOY.md becomes prod-only, expanded into 14-section VPS-deploy structure (topology table, env vars, VPS provisioning, two-layer firewall, Docker tuning, first-time setup, routine deploys, persistence, backups, TLS, observability, hardening, rollback, runbook). Dev quick-start lives ONLY in README "Quick start (dev)" section; mixed dev/prod DEPLOY.md flagged as drift, dev content proposed for move to README during same patch round.
- **Why**: README opt-out makes repo look abandoned to anyone landing on it — universal "always render" beats opt-in. Mixed dev/prod DEPLOY.md was drift source: devs read DEPLOY for local setup, ops read DEPLOY for prod, both edit independently, conflicts pile up. Clean audience split — README = dev + features audience, DEPLOY = ops + SRE audience — gives each doc one owner mental model. 14-section VPS template mirrors real Scaleway/Hetzner/OVH/DO/Vultr deploy shape (reference: Scaleway DEV1-S walkthrough) so the doc maps 1:1 to the runbook ops actually execute.
- **Alternatives rejected**:
  - Keep README gated on HUMAN approval (status quo) — rejected: opt-outs proliferated, repos shipped with no README. Friction wins.
  - Single ARCHITECTURE+DEPLOY doc — rejected: mixed-audience doc is the drift source we're fixing. Don't recombine.
  - Trim DEPLOY.md to single "Production" section — rejected: real VPS deploys need topology + firewall + Docker tuning + backups + TLS + observability. Single section becomes wall-of-text nobody reads.
  - Optional README in AUTO mode (default skip) — rejected: AUTO mode purpose is friction removal. README is most-missed doc; auto-render it.
  - Auto-write the README without surfacing draft — rejected: rendered draft still shown at validation gate so user can `edit` before write. "No skip" ≠ "no review".
- **Caveats**:
  - Real-project-data rule still binds — license = "Not specified — set one before public release" (explicit gap, not fabricated SPDX).
  - 14-section DEPLOY template drops sections that don't apply (e.g. "Managed DB" if no DB). Template = ceiling not floor.
  - If `DEPLOY_COMPLEXITY == TRIVIAL`, no DEPLOY.md created — deploy stays in README. Threshold = no Docker + no compose + no fly.toml + no k8s + no scripts/deploy.* → trivial.
  - Existing DEPLOY.md with `Local development` / `Dev setup` section → surfaced as drift, content moved to README, section removed from DEPLOY. Not a silent rewrite.
- **Reference**: commit `7ee9b42`, `agents/doc-syncer.md` STEP 5 (README mandatory clause + template lines 223–335), STEP 6 (14-section DEPLOY.md template lines 338–541), STEP 8 (validation gate `yes/edit` for README, `yes/no/edit` for HUMAN), STEP A4 (AUTO MODE README-missing → SIGNIFICANT). Linked to [[doc-syncer-two-doc-split]] (LRN-019).

---

## BDR-017 — `full` profile = web-full + plan + dev superset for /init-project MVP

- **Date**: 2026-05-18
- **Status**: accepted
- **Decision**: New `lib/profiles/full.profile` covers brainstorm → design → architecture review → scaffold → implement → ship → audit pipeline in one profile. Superset of `web-full` (design + dev + seo/geo/validate/harden + perf) plus plan-mode reviews (office-hours, plan-ceo/eng/design/devex-review, autoplan), full dev stack (investigate, code-clean, land-and-deploy, setup-deploy, codex), full audit (cso), full QA (qa), docs (doc, document-release), session hygiene (close, prune-memory, status, learn, retro, careful/freeze/unfreeze/guard), and `pr-review-toolkit` plugin + `gsd` CLI. Sentinel "full" in `cmd_current` renamed to "none" to avoid collision with profile name.
- **Why**: `/init-project` orchestrates 13 steps that touch nearly every skill family — brainstorm, plan, design, scaffold, implement, ship, audit. Existing profiles only cover a slice (web-full = website end-to-end but no plan/dev breadth, dev = code only, audit = audit only). Without a maximal profile, init-project users must either run `reset` (everything on, noisy) or piece together `apply web-full && apply dev && apply audit` (3 commands). One named profile = one command = right tool for MVP scaffolding sessions.
- **Alternatives rejected**:
  - Extend `web-full` to absorb plan + dev — rejected: `web-full` is "production website end-to-end"; init-project covers non-website projects too (CLI, library, backend MVP). Different semantic.
  - Make init-project profile-agnostic (just run with all skills enabled) — rejected: noise. `/profile reset` exists for that; named profile gives explicit signal "this session is MVP-scale".
  - Multiple sub-profiles chained — rejected: 3 `apply` commands less ergonomic than one `set full`; profile-of-profiles not supported by current schema.
- **Caveats**:
  - `full` excludes a few rarely-used gstack skills (devex-review, pair-agent, gstack-upgrade, skills-perso). `set full` will disable those; user can `apply <profile>` after to add back.
  - Sentinel rename "full" → "none" is breaking for any tooling that grepped `cmd_current` output for literal "full". No known consumers in this repo.
- **Reference**: commit message references `lib/profiles/full.profile` (new), `lib/profile.sh:421` sentinel, `skills/profile/SKILL.md` table row. Linked to [[profile-sentinel-collision]] (LRN-020).

---

## BDR-018 — `profile gstack on|off` verb keeps active-profile label

- **Date**: 2026-06-02
- **Status**: accepted
- **Decision**: New `cmd_gstack()` in `lib/profile.sh`. `gstack on` = re-enable all parked gstack (move `skills-disabled/gstack__*` back), DON'T touch `.active-profile`. `gstack off` = disable gstack skills not in active profile (errors if active=none). Wired into `main()` dispatch + `usage()` + header block + `skills/profile/SKILL.md` (argument-hint + examples + output-policy).
- **Why**: User wanted central command for "enable all gstack" + "disable gstack not needed by profile". Both ops existed (`reset`, `set`) but `reset` clobbers `.active-profile` to "none" — loses profile context in statusline. New verb does same skill-toggle WITHOUT clearing label, so user layers full gstack on top of current profile (e.g. `dev`) and statusline still reads `dev`.
- **Alternatives rejected**:
  - 3 new profiles (current+gstack, current+gsd, current+gsd+gstack) — rejected: `gsd` = standalone CLI (not profile-toggleable, always-on, 0 passive token), so 2 of 3 meaningless. `full` already = current+gstack+gsd advisory. `apply` already additive.
  - Just document `reset`/`set` — rejected: user wanted clearer centralized verb + label preservation.
- **Impl note**: extracted 3 shared helpers (`enable_all_gstack`, `disable_gstack_not_in`, `parked_gstack_count`); `cmd_reset`+`cmd_set` refactored to reuse (behavior preserved exact, verified by test). See [[dry-helper-extract-sibling-command]] (LRN-024).
- **Reference**: `lib/profile.sh` cmd_gstack + helpers, `skills/profile/SKILL.md`. Linked to [[full-profile-superset-init-project]] (BDR-017), [[gstack-source-only-skills-unlinked]] (BLK-007).

---

## BDR-019 — Remove `disable-model-invocation` repo-wide, align skills with CLAUDE.md routing

- **Date**: 2026-06-09
- **Status**: accepted
- **Decision**: Stripped `disable-model-invocation` frontmatter key from all 19 editable `skills/*/SKILL.md`. Absent key = default = model invocation ENABLED. 8 were `true` (blocked model + orchestrator routing: `status`, `plugin-check`, `analyze`, `onboard`, `refactor`, `init-project`, `pdf-translate`, `ship-feature`); 11 were `false` (already enabled, line was noise).
- **Why**: `true` blocked model AND orchestrator from self-routing to those skills — contradicted CLAUDE.md "Skill routing" intent (e.g. "multi-file feature → ship-feature", "refactor → /refactor"). User hit it live: model detected feature intent, wanted `ship-feature`, couldn't fire. Setting binary (no per-caller granularity) → enabling orchestrator-chaining also enables model auto-fire; accepted as the cost.
- **Alternatives rejected**:
  - Keep `true` on 4 heavy orchestrators (`init-project`, `ship-feature`, `onboard`, `refactor`) — rejected: "destructive" framing wrong. `ship-feature` only commits + pushes a feature branch + opens PR (reversible, gated by internal STEPs); no prod deploy (that's `land-and-deploy`/`canary`). Real destructive ops (`rm -rf`, force-push, prod deploy) guarded by careful/guard hooks INDEPENDENT of this flag — verified live (`rm -rf` blocked this session). Flag bought ~0 data-safety, only suppressed auto-fire (token/time cost) while breaking routing.
  - Remove only the 8 `true` ones — rejected: leaves 11 noise `false` lines; uniform removal cleaner.
- **Durability**: all 8 ex-`true` skills are repo-only files (not gstack submodule) → edits not clobbered on gstack upgrade.
- **Reference**: 18 `skills/*/SKILL.md` modified + `skills/capitalize/` new. Linked to [[disable-model-invocation-false-not-blocking]] (LRN-026).

---

## BDR-020 — `/audit-delta` design: per-axis SHA markers, always-on fix gate, unreachable-first-run = full report-only

- **Date**: 2026-06-11
- **Status**: accepted
- **Decision**: New skill `skills/audit-delta/SKILL.md` — recurring multi-axis audit (conformity/errors/deadcode/security) scoped to delta since last run. 3 design choices: (1) state = `.claude/audits/audit-delta-state.json`, SHA marker PER AXIS (partial runs would desync single marker); (2) approval gate per axis ALWAYS fires — advance pre-auth ("fix what you find") never skips it, findings unknown at request time; user unreachable → audit + report only, no fix, marker still advances; (3) first-run axis + unreachable user → default full codebase report-only, never "from HEAD" (would skip entire existing codebase silently). Axis order fixed security→errors→conformity→deadcode (critical first, session-death safe). Re-verify = same-axis re-audit on modified files + project checks, lint alone insufficient. Built via superpowers:writing-skills TDD (RED 7 gaps / GREEN pass under pressure / REFACTOR 1 hole patched + re-tested).
- **Alternatives rejected**:
  - Extend `/code-clean` or `/health` — rejected: no recurrence state (health re-scans all, tracks scores not scope; code-clean one-shot), no multi-axis checkbox selection, cost not proportional to delta.
  - 4 separate skills (1 per axis) — rejected: user wants checkbox combo in one run; shared marker protocol + gate + re-verify loop would quadruplicate.
  - Single global marker — rejected: run "security only" then "conformity" → conformity range wrong.
  - Date-based boundary — rejected: drifts on rebase/timezone/amend (baseline agent failure, see LRN-027).
- **Reference**: `skills/audit-delta/SKILL.md`. Linked to [[periodic-skill-state-file]] (LRN-027), [[capitalize-skill]] (skill TDD precedent, BDR-019 era).

---

## BDR-021 — CLAUDE.md restructure: contradiction purge, project-specific sections labeled, critical sections never compressed

- **Date**: 2026-06-12
- **Status**: accepted
- **Decision**: Full refactor global CLAUDE.md (commit e7e9dac), Fable 5 audit. 4 contradictions resolved (2 graphify sections merged conditional on graph.json existing; "in doubt skip plan" no longer cancels plan mandate — borderline = single-file small obvious change; deviations minor/justified→after vs significant/shaky→before; append-only reconciled with /prune-memory). 3 dead refs fixed (/caveman-compress, design-gate → ~/.claude/lib/ portable, LESSONS note). Structure: Tooling & skills + "This repo only" top-level sections — Health Stack/routing/graphify no longer nested under Communication mode. Routing +8 skills + explicit gstack-OFF rule. Compression caveman on workflow/memory/routing ONLY: **Architecture decisions + Security stay verbatim — ambiguity there costs more than tokens saved**. Net -1471 chars despite added content.
- **Alternatives rejected**:
  - Compress whole file incl. Security/Architecture — rejected: precision > tokens on non-negotiable rules; misread security default = real damage.
  - Split global vs repo-specific into 2 files — rejected: symlink setup (~/.claude/CLAUDE.md → repo) means 1 file everywhere; "This repo only" section header cheaper than 2-file sync.
  - Delete graphify section (graph.json absent) — rejected: conditional phrasing keeps rules dormant-but-ready; regenerating graph re-activates without doc edit.
- **Durability**: heading "Design work — full toolchain (tiered by scope)" preserved verbatim — design-toolchain-reminder.sh quotes it. Norms 25/80/5/5 unchanged — audit-delta conformity axis cites them.
- **Reference**: CLAUDE.md, commit e7e9dac. Linked to [[audit-delta-design]] (BDR-020), LRN-029 (exception edits need blanket-rule cross-ref — applied here).

---

## BDR-022 — doc-syncer scoped to public docs only; `.claude/` + `CLAUDE.md` read-only context

- **Date**: 2026-06-18
- **Status**: accepted
- **Decision**: Rewrote `agents/doc-syncer.md`. Sync targets = PUBLIC docs ONLY: README, INSTALL, CONFIGURE, USAGE, DEPLOY, CONTRIBUTING, CHANGELOG, SECURITY, ARCHITECTURE, LICENSE, docs/**. `.claude/**` + `CLAUDE.md` = read-only context: agent MAY read them to understand archi/features/constraints, NEVER modifies them, NEVER lists as targets, NEVER copies their content into a public doc. Removed STEP 4 blocks auditing TODO.md / audits/*.md / decisions-learnings-blockers. Added normative CONVENTIONS (Standard-Readme, Diátaxis doc-type split, Keep a Changelog + SemVer, Conventional Commits). README lean — dropped Status + Project layout, forbids roadmap/todo/internal-state, links to Diátaxis docs not duplicate. Added CLEAN mode (`clean` arg) → propose removal of out-of-convention sections + copied-`.claude/` content from existing public docs, HUMAN-gated. Conserved: stack detection, 14-section DEPLOY gate, validation gate, AUTO/HUMAN tagging, never-invent, AUTO MODE (input `auto-mode scope:` unchanged → callers unaffected).
- **Alternatives rejected**:
  - Keep `.claude/` + `CLAUDE.md` as sync targets (old behavior) — rejected: leaked internal state (TODO/roadmap/decisions) into public-facing docs; doc-syncer writing under `.claude/` blurred the read-only registry boundary (registries are `/prune-memory`-curated, not doc-synced).
  - Drop only `.claude/`, keep `CLAUDE.md` writable (old strike-through README opt-out) — rejected: CLAUDE.md = agent config not public doc, absent from the modifiable-targets list; uniform read-only treatment cleaner.
  - Inline config table in README — rejected: violates Diátaxis (CONFIGURE.md = single config reference); README must link, not duplicate.
- **Reference**: `agents/doc-syncer.md`, commit edff761. Extends [[doc-syncer-readme-deploy-policy]] (BDR-016, README-AUTO + DEPLOY 14-section — conserved, not superseded).

---

## BDR-023 — Merge /close into /capitalize — 2 modes + TODO reconcile; /close alias

- **Date**: 2026-06-19
- **Status**: accepted (supersedes /close-creation part of BDR-002)
- **Decision**: `/close` merged into `/capitalize`. capitalize 2 modes: default (pre-wipe flush) + `--ritual` (adds 3-question end-of-session reflection; trigger = `--ritual` flag OR "close"/"ritual" in `$ARGUMENTS`, OR `/close`). Both modes dedup (STEP 2) + reconcile `.claude/tasks/TODO.md` (new STEP 2B). STEP 2B: PASS A done-detection = restraint rule only (flip `[ ]`→`[x]` only on clean task↔commit map; partial/umbrella/vague stay unchecked, never guess); PASS B explicit-capture + anti-noise filter (never track commit/deploy/push/release/tag) + orientation-directive→decisions.md (BDR) routing. Ritual answers go thru dedup, footer shows existing ID — unlike legacy /close (wrote fresh). STEP 3 gate gains separate TODO block; journal+handoff report TODO ops. TODO stays plain prose (caveman = registries only). `/close` kept = thin alias → `/capitalize --ritual`, zero duplicated logic.
- **Why**: /close + /capitalize overlapped (both flush session memory), /close never deduped → re-logged on re-run. 1 skill 2 modes kills dup + gives /close dedup; TODO reconcile = new capability. Alias file (not merged-triggers-only) because /close resolves by directory name — deleting dir breaks literal `/close` command.
- **Alternatives rejected**:
  - Merged-triggers-only (drop close dir, fold triggers into capitalize desc) — breaks literal `/close` command (dir-name resolution).
  - Keep 2 separate skills — duplication persists + /close never dedups.
- **TDD**: built via superpowers:writing-skills. RED v1 baseline too easy (passed). RED v2 (pressured fixture: semantic dup + ambiguous umbrella task + parasite-as-task + orientation directive + rushed prompt) failed on anti-noise (folded push/tag into TODO) + invented subtask + no approval stop. GREEN passed. Gate STOP itself UNTESTED (non-interactive harness printed gate then proceeded "all approved") — flagged in skill Red flag + TDD note; verify on first real use.
- **Reference**: `skills/capitalize/SKILL.md`, `skills/close/SKILL.md`, commits 9dc2b83 (skill) + be0f047 (docs routing) + 765e9d7 (PASS A trim). Linked to [[BDR-002]] (close created), [[BDR-019]] (capitalize created), [[LRN-031]] (skill-value lesson).

---

## BDR-024 — `profile show --plain` = claude-free parse contract for the design gate

- **Date**: 2026-06-19
- **Status**: accepted
- **Decision**: added `profile.sh show <name> --plain` → one `type<TAB>name` per line, grouped by type (gstack/external/personal/plugin/mcp/cli order), NO status, ZERO claude calls, derived purely from the `.profile`. Bare `show` keeps runtime status (human value) + grouped layout; `--plain` = machine path. Canonical names verbatim (`magic` stays `magic`; plugin marketplace `plugin@<mp>` collapsed to category `plugin`).
- **Why**: upcoming design gate must derive "which profile contains tool X". Needs fast + hook-safe parse. Bare `show` calls `claude plugin list`/`claude mcp list` per plugin/mcp entry → slow + fails in non-terminal/hook context (degrades to "disabled").
- **Alternatives rejected**:
  - Gate re-reads `.profile` directly — duplicates `read_profile` parsing in the gate; two parsers drift.
  - Gate parses full `show` output — pays claude calls per plugin/mcp, fragile in hook context.
- **Reference**: `lib/profile.sh` `cmd_show` (+ `--plain` branch), `skills/profile/SKILL.md`, commit 5776195. Linked to [[BDR-018]] (prior `profile.sh` command addition).

---

## BDR-025 — Design gate = profile-based; remedy always `/profile design`; magic required-but-manual; unknown → fail-visible; claude resolved via PATH-repair

- **Date**: 2026-06-21
- **Status**: accepted
- **Decision**: `design-tool-gate.sh` checks whether the `design` profile's design-core tools are active and, if not, points at ONE command — `/profile design`, never an atomic per-tool toggle. **tier = profil**: every non-trivial tier (Build / design-system / review) draws from the one `design` profile (a superset of all tiers) → the gate checks that profile, so ZERO hardcoded tier→tools list. Gate scope = the `# GATE-BLOCK:` allowlist in `design.profile` (only real design tools trip; bundled browser/plan/shotgun/graphify ignored). Structure + types from `profile.sh show design --plain` (BDR-024 contract); per-tool state per channel (skill symlink / `claude plugin list` / `claude mcp list` / `command -v`), mirroring `profile.sh:skill_status()`. Three outcomes: blocking/manual → INCOMPLETE exit 10; unknown-only → READY-BUT-UNVERIFIED exit 11 (fail-visible); else READY exit 0. **magic = required-but-manual** class: TRIPS the gate (NOT advisory), names the `MAGIC_API_KEY` step. **claude resolved via `ensure_claude_on_path()`** (probe known dirs + nvm glob `sort -V | tail -1` = newest, prepend the bin dir carrying claude AND node) — because `command -v claude` depends on PATH carrying the nvm bin, absent in a sanitized subshell/hook; integral to the final gate design, not a detail.
- **Why**: single source of truth = profile system → no CLAUDE.md tier→tools dup (P3/P5 just removed it), no tool→profile map to drift. Credible gate: trips only on real design tools, not bundled infra → not ignored by reflex. magic is the load-bearing design tool, so silence on it would defeat the gate's purpose. Gate runs from hooks/skills where PATH may be sanitized → robust claude resolution is required for it to verify at all.
- **Alternatives rejected**:
  - Hardcoded tier→tools list — reintroduces the CLAUDE.md dup just removed; drifts when a tool is added to a profile.
  - magic advisory (mention, don't trip) — fail-OPEN on the very tool the gate exists to catch.
  - Strict fail-closed on unknown — false blocks when claude merely slow/unreachable → gate gets ignored. fail-VISIBLE (exit 11) chosen.
  - Depend on `command -v claude` alone — fails in sanitized-PATH hook → unknown. Proven by `PATH=/usr/bin:/bin` test (magic-on → READY/0, magic-off → INCOMPLETE/10).
- **Reference**: `lib/design-tool-gate.sh`, `lib/design-gate.md`, `lib/profiles/design.profile` (`# GATE-BLOCK:`), commits 3eefb8a / 4d19135 / f963318. Linked to [[BDR-024]] (the `--plain` parse contract this consumes), [[LRN-036]] (`command -v` PATH dependence, the real cause), [[LRN-037]] (proven on the real subject in real context).

---

## BDR-026 — Secret source-of-truth outside the repo (`~/.claude/.env`) reached via a `repo/.env` symlink

- **Date**: 2026-06-21
- **Status**: accepted
- **Decision**: real secret lives in `~/.claude/.env` (outside the git tree); `repo/.env` is a symlink → it. `source "$REPO/.env"` follows the symlink transparently → ZERO change to any read path (`toggle-external.sh` `load_env`, `install-plugins.sh` check, gate). `link.sh` `link_env()` creates the symlink defensively: links only when `repo/.env` is absent or already the right link; a residual REAL `repo/.env` is left untouched with a migrate hint — never clobbered, so the secret can't be destroyed. Idempotent. `.gitignore` hardened to `.env` + `.env.*` + `!.env.example`. Messages point at `~/.claude/.env` (the canonical edit location).
- **Why**: secret never enters the git tree — not as content (it's a link) nor by accident (gitignored). Even a stray `git add .` can't stage the real key. Repo stays usable: the symlink is visible/editable from the repo. Read paths follow the link → no script logic changed.
- **Alternatives rejected**:
  - Secret in `repo/.env`, gitignored (status quo) — one `git add -f` or a `.gitignore` slip leaks it; the secret physically sits in the tree.
  - Scripts read `~/.claude/.env` directly — makes the symlink redundant but rewrites every read path and loses repo-local visibility.
- **Reference**: `link.sh` `link_env()`, `.gitignore`, `lib/toggle-external.sh`, `install-plugins.sh`, `.env.example`, commits 131d0bc / f9cc866. Linked to [[BDR-025]] (magic's `MAGIC_API_KEY`, consumed by the gate's required-but-manual class).
- **Update 2026-07-02 (incident — copies of secrets)**: `claude mcp add --env` MATERIALIZES the key into `~/.claude.json` (`mcpServers.magic.env`) — a 2nd live copy OUTSIDE the `~/.claude/.env` canonical and outside the repo deny rules' reach. An audit query printed it into a session transcript → key rotated (21st.dev). Rule: secrets have COPIES (tool configs, transcripts, caches) — protect/audit the copies, not just the canonical; when inspecting MCP config, filter env fields (`jq 'del(.. | .env?)'`). Same audit: `~/.claude/.env` hardened 0664→0600.

---

## BDR-027 — Minimal npm-via-nvm bootstrap over centralized prereq lib (reverses the reverted approach)

- **Date**: 2026-06-23
- **Status**: accepted (supersedes the reverted `lib/install-prereqs.sh` centralization, commit 1ddeed1 removed from history)
- **Decision**: the only real bootstrap blocker = `npm` absent on fresh machine. `install.sh` now installs current LTS via nvm (`v0.39.7` → `nvm install --lts`) ONLY when node/npm missing (`install_node_via_nvm`). Keep the inline per-tool prereq blocks in `install-plugins.sh` (no shared `ensure_*` lib). Re-add `jq` inline (Step 1) + `doctor.sh` fail-level — `jq` is an active-hook dep that was never installed.
- **Why**: a 1-function fallback fixes the actual blocker. Folding 9 prereqs into a 245-line lib was scope-creep for "npm missing"; user reverted it. Inline blocks stay readable + co-located with their step.
- **Alternatives rejected**: centralized `lib/install-prereqs.sh` (commit 1ddeed1 — over-engineered for the real blocker, reverted); leave `npm` as a hard `err` (the original bug — aborts before the CLI install).
- **Reference**: `install.sh` `install_node_via_nvm`, `install-plugins.sh` Step 1 jq, `doctor.sh`, commits b6cc8b1 / 2194b11. Linked to [[BLK-008]] (the chromium half of the same fresh-Ubuntu-26.04 session).

---

## BDR-028 — Hand-curated config is install-immutable (auto-revert guard) + de-vendor installer-managed skills

- **Date**: 2026-06-23
- **Status**: accepted
- **Decision**: `install-plugins.sh` snapshots `CLAUDE.md` + `settings.json` + `.claude/settings.json` at start, restores them on EXIT (trap) → installer never mutates hand-curated config. `frontend-design` un-tracked (`git rm --cached` + gitignore `skills-external/frontend-design/`) — re-synced from the example-skills plugin cache every run, so vendoring = pure churn. npx-skills pollution (`/.agents/`, `/skills-lock.json`) gitignored, anchored so our `agents/` stays tracked.
- **Why**: a fresh `make install` drifted all 4: graphify clobbered `CLAUDE.md` (deleted the `# This repo only` header) + injected aggressive MANDATORY pre-tool hooks; `claude plugin install` flipped `example-skills`→true + added `plugin-dev`; frontend-design diffed on every upstream update; darwin-skill polluted repo `.agents/` at project scope. Guard = these files maintained by hand+commit only; gitignore = generated artifacts never tracked.
- **Caveat**: guard makes the 3 config files install-immutable — anything the installer SHOULD add must be committed by hand. Safe today: committed `settings.json` already carries the rtk hook (install skips init). `update-all.sh` needs no guard (only `claude plugin update`, no enable flips, no graphify reconfig).
- **Alternatives rejected**: `git checkout` post-install (nukes legit uncommitted edits, depends on git state); surgical JSON/markdown patching (fragile); accept graphify's generic CLAUDE.md (loses curation).
- **Reference**: `install-plugins.sh` guard block + `restore_curated_configs` trap, `.gitignore`, commits 51afe9b / 7de8761. Linked to [[LRN-039]].

---

## BDR-029 — Installer auto-fixes gstack browser on OS newer than its pinned Playwright supports

- **Date**: 2026-06-23
- **Status**: accepted
- **Decision**: `install-plugins.sh` makes gstack's browser work on too-new distros without manual steps. (1) `gstack_bump_playwright_if_unsupported()` runs before `./setup`: if the pinned Playwright's support list lacks the running distro (grep `node_modules/playwright-core/lib` for the `ubuntuXX.04` tag), `bun add playwright@latest` in the submodule, then `./setup`'s frozen-lockfile install picks it up + rebuilds the browse binary. Idempotent (skips when already supported). (2) Persist `GSTACK_CHROMIUM_NO_SANDBOX=1` to the shell profile, gated on `sysctl kernel.apparmor_restrict_unprivileged_userns=1`.
- **Why**: fresh `make install` on Ubuntu 26.04 must yield a working gstack browser. Submodule pins Playwright 1.58.2; upstream hasn't bumped; can't wait. Local bump in the installer = "just works" + self-heals after a `git submodule update` (re-applies next run).
- **Caveats**: the installer EDITS the submodule (goes dirty each run on a too-new OS) — invasive, but the user chose it over waiting upstream. `bun add playwright@latest` could pull a Playwright that breaks gstack's build → non-fatal (`./setup` fail warns, install continues). The local bump is reset by `git submodule update`. The `.bashrc` env can be wiped if the user restores a hand-managed `.bashrc` (theirs is managed — the first install's lines were already lost that way).
- **Alternatives rejected**: `PLAYWRIGHT_HOST_PLATFORM_OVERRIDE` (fallback build HANGS at extraction — [[BLK-008]]); wait for gstack upstream Playwright bump (no ETA); leave browser unavailable (user wanted it); system chromium + executablePath (needs gstack code change).
- **Reference**: `install-plugins.sh` `gstack_bump_playwright_if_unsupported()` + Step 9 sysctl-gated env, commit 3b8ffb1. Linked to [[LRN-040]], [[BLK-008]].

---

## BDR-030 — gstack skills activated ON-DEMAND per profile, not pre-installed; OFF by default stays

- **Date**: 2026-06-23
- **Status**: accepted
- **Decision**: gstack stays OFF by default (no per-skill symlink in `skills/`, zero context cost) — but `profile.sh set <profile>` that LISTS a gstack skill activates it for that profile. `enable_skill gstack` gained a branch: skill not in `skills/` and not parked in `skills-disabled/` but present in the `skills-external/gstack/<name>` submodule → `ln -s` it into `skills/`. `disable_gstack_not_in()` parks it again when an unrelated profile is set. The gstack/bin + browse/dist infra those skills need is created independently by `link.sh`.
- **Why**: user wanted `make install` self-sufficient AND `set full` (lists 35 gstack skills) to work without 35 `missing — try: bash link.sh` warnings, WITHOUT abandoning gstack's OFF-by-default context-cost policy ([[BDR-029]] install comment). On-demand-per-profile threads both: gstack invisible until a profile needs it, then auto-on for exactly that profile. Source of truth = the submodule (`gstack_skills()` already reads `skills-external/gstack/*/SKILL.md`), so activation needs no gstack `./setup` skill-registration (which this gstack version writes to the WRONG dir anyway — [[LRN-042]]).
- **Caveats**: the symlink form (`skills/<name> -> skills-external/gstack/<name>`) differs from what gstack `./setup` would create (real dir + symlinked SKILL.md) — fine here because `./setup` never populates `skills/` in this layout, so no mixed-form collision. Browse RUNTIME still needs the built binary + sandbox env ([[BDR-029]]) — on-demand makes the skill DISCOVERABLE, not the browser functional on an unsupported OS. The old "try: bash link.sh" message was wrong (link.sh never creates gstack skills) → replaced with submodule-aware messages.
- **Alternatives rejected**: full gstack integration (make `./setup` install into `skills/`) — user picked option 1, too invasive/version-fragile; leave `full` broken with honest 1-line warning — worse UX; pre-symlink all gstack at install — violates OFF-by-default context policy.
- **Reference**: `lib/profile.sh` `GSTACK_SRC` + `enable_skill` gstack branch. Verified: `set full` → 0 missing, 35 on-demand; `minimal`↔`full` cycle re-parks/restores; git clean (gstack symlinks gitignored, [[LRN-025]]). Linked to [[LRN-042]], [[LRN-022]], [[BDR-018]] (gstack on/off verb).

---

## BDR-031 — global CLAUDE.md lightening = COMPRESSION, not path-scope / externalization

- **Date**: 2026-06-25
- **Status**: accepted
- **Decision**: lighten the universal global CLAUDE.md (`~/.claude/CLAUDE.md`, loaded every session in every project) by COMPRESSION only — denser prose, drop name-obvious routing lines, trim decorative whitespace. NOT by path-scoping rules under `~/.claude/rules/`, NOT by externalizing sections to on-demand files. Result: 317 → 275 lines.
- **Why**: user-level path-scoped rules (`paths:` frontmatter under `~/.claude/rules/`) do NOT load in CC 2.1.190 (#21858, [[BLK-009]]) — proven by probe. Conditional/scoped loading is therefore an unreliable lever for this user; compression is the only mechanism that actually cuts every-session token cost without depending on the broken feature.
- **Caveats**: future GLOBAL memory must stay tiny — with conditional loading broken, anything global loads in EVERY project unconditionally; fold that constraint into the global-memory design once a backup exists. Caveman pass to ~250 was explicitly DECLINED: marginal ~25-line gain vs real risk (changes the nature of instructions-to-follow; no evidence caveman is followed better than prose; CLAUDE.md is the most-edited file → caveman = painful to re-read/amend). 275 readable > 250 caveman.
- **Alternatives rejected**: path-scoped `~/.claude/rules/` (broken, [[BLK-009]]); externalize sections to on-demand-loaded files (same conditional-load dependency); caveman to ~250 (readability + instruction-fidelity risk).
- **Reference**: `~/.claude/CLAUDE.md` (symlink → `~/Documents/claude/CLAUDE.md`), commits ba743cf (compress routing+design+graphify) + 990318c (trim separators/blanks). Linked to [[BLK-009]], [[LRN-043]], [[LRN-044]].

---

## BDR-032 — skill `/validate` → `/web-validate` (rename user surface, keep internals)

- **Date**: 2026-06-25
- **Status**: accepted (shipped `e5e673a`)
- **Decision**: rename W3C+WCAG skill `/validate` → `/web-validate` (clearer scoped name, less generic). Renamed the USER-FACING surface ONLY: folder (`git mv`), frontmatter `name`, H1, command refs, CLAUDE.md routing line, 6 `lib/profiles/*.profile` entries (FUNCTIONAL — profiles activate skills by folder name, a miss = broken activation), cross-refs (harden/seo/depth-matrix/client-handover), agent dispatch refs, README + USAGE tables. Leak-guard regex extended to `web-validate|validate` ([[LRN-045]]).
- **Why — 4 deliberate KEEPs**:
  - agent `validator-analyzer` name KEPT — internal, lockstep with `subagent_type=` + harness registry; rename = wider blast radius, zero discoverability gain.
  - `.validate-cache/` + `VALIDATE.md` KEPT — names derive from the AUDIT TYPE, family `{SEO,GEO,HARDEN,CSO,VALIDATE}.md`; renaming makes VALIDATE the odd one out + orphans already-generated reports (`MIGRATION.md` cleanup loop hardcodes the name). Same logic kept the dispatch label `description="validate — ..."`.
  - `.claude/` history KEPT (memory + completed TODO block) — append-only, true at the time. The forward-pointing OPEN TODO item was ANNOTATED additively (`désormais /web-validate`), not rewritten — append-only protects history, not pointers to future actions.
  - CHANGELOG old entry KEPT, new "renamed" entry ADDED (Keep-a-Changelog: don't rewrite the past).
  - NL trigger keywords ("validate"/"validation") KEPT in the description so "validate my site" still routes here.
- **Alternatives rejected**: rename agent + artifacts too (cosmetic symmetry, ~45 extra edits, breaks audit-file family + report back-compat); blind `sed s/validate/web-validate/` (breaks third-party `html-validate`, `validator.nu`, English-verb prose — discrimination must be at the `/validate` token, proven by `.validate-cache/html-validate.json` staying intact).
- **Reference**: commit `e5e673a` (18 files). Verified complete: `/validate` = 0 in active code (only `.claude/` history + CHANGELOG), `html-validate` = 15 intact, regex `client-handover-writer.md:1462` shows both names. Linked to [[LRN-045]], [[BDR-031]] (CLAUDE.md routing), [[LRN-043]] (validate routing line).

## BDR-033 — design-gate §4: anim-lib suggestion — suggest-only, non-blocking, stateless 1-line

- **Date**: 2026-06-25
- **Status**: accepted
- **Decision**: `lib/design-gate.md` gains §4. When a non-trivial design task hits a MOTION signal (`animation`/`transition`/`hover`/`motion`/`animate`, added to §DETECTION) AND `detect_anim_eligibility`=`eligible` AND `is_anim_lib_installed` finds none → surface ONE line suggesting the recommended `motion` pkg. Suggest-only (install ONLY on explicit consent, never auto), non-blocking (sole STOP stays §3 exit 10), stateless (ALWAYS the single line, no marker). Calls the helper — no 3rd copy of the lib list.
- **Why**: gate runs mid-build; a 2nd blocking stop on an OPTIONAL dep = friction. Dedup goal is not "prevent re-fire" but "make the surface minimal enough that re-fire is never noise" → deterministic by construction (nothing to remember → no fragile behavioral guard, cf [[LRN-046]]/[[LRN-047]]). **Conditional to stakes**: the deduped thing here is a NON-DESTRUCTIVE 1-line cosmetic note → re-fire is annoyance, not risk, so importing marker-grade infra (file + gitignore + permanent state) is not justified. On a DESTRUCTIVE op a deterministic marker IS worth its cost — that is where [[LRN-046]]/[[LRN-047]] were forged. Same determinism bar, opposite cost/benefit; pick by stake. Self-heal: condition-3 (`is_anim_lib_installed`, 10 libs incl gsap/react-spring/lottie) kills it the instant any anim lib lands → re-fire only ever hits "eligible + pure-CSS + actively declined".
- **Alternatives rejected**:
  - File marker `.design-anim-suggested` (once-forever) — "session"→"forever-per-project" (1 decline = permanent silence, no cleanup but manual rm); adds write + gitignore mgmt to a non-mutating doctrine; `.claude/` tracked here → suppression leaks via git.
  - Blocking yes/skip prompt à la `/onboard` STEP 2.5 — a 2nd STOP mid-build on an optional dep.
  - Prose "agent remembers not to re-suggest" — fragile behavioral guard, contradicts [[LRN-046]]/[[LRN-047]].
- **Reference**: commit `11792cc`, `lib/design-gate.md` §4 + §DETECTION (`+motion`/`+animate`). Helper `lib/animation-lib-check.sh` unchanged. Live via symlink (`~/.claude/lib/`→repo). Builds on [[BDR-005]]. See [[LRN-049]].

## BDR-034 — Coupled-capitalize invariant v1 — memory commit auto per dev flow (Frame 2)

- **Date**: 2026-06-26
- **Status**: accepted
- **Decision**: Dev flows committing code now auto-commit memory same breath, via include `lib/capitalize-commit.md` + helper `lib/memory-commit.sh` (surgical: stages+commits `.claude/memory`+`.claude/tasks` only, pathspec, never `git add -A`). 4 inline flows (feat/hotfix/bugfix/commit-change) ref the include at their capitalize step; ship-feature reordered (CAPITALIZE STEP 7 before FINISH STEP 8 — fixes memory committed after push/PR + stranded outside it); init-project gains STEP 10b founding-decisions capitalize. 1 memory commit/flow (F3). Capitalize CONTENT keeps its approval gate — only the COMMIT of approved entries is automated.
- **Why**: Real pain = the 2nd (memory) commit forgotten/manual — ~42% of recent history (17/40 commits) was emergent `chore(memory)`. Frame chosen = "couplé après-code" not "avant commit": keeps hash-anchoring (>50% entries carry `Reference: commit`) + code/memory concern separation; attacks the forgetting, not the ordering. "Capitalize before commit" rejected — inverts a deliberate property AND can't anchor the code hash (hash exists only post-commit).
- **Alternatives rejected**:
  - (a) each orchestrator calls capitalize-before-commit — duplicated across 5+ flows (each has bespoke inline capitalize), breaks hash-anchoring, forgettable on next skill added.
  - (b) commit-change as the single gate — not on the path of feat/hotfix/bugfix/ship-feature/init-project (they commit inline or via external superpowers); can't detect "pending capitalize".
  - (c) single commit chokepoint — doesn't exist; 3 distinct commit mechanisms, one external/unmodifiable (`superpowers:finishing-a-development-branch`).
  - Frame 3 (single unified commit, drop hash) — sacrifices >50% entries' anchoring for history aesthetics.
- **Reference**: commits `58cb91d` (helper+tests) · `bbef41c` (hash/stdout + T6/T7) · `b44791b` (include) · `2763678` (4 flows) · `e8eff7e` (ship-feature reorder) · `df60df6` (init-project). Hook (v2, Stop-hook non-blocking BDR-033-style) + doc-sync twin chantier (same PR bug, reorder before FINISH) deferred. See [[LRN-051]], [[LRN-052]], [[EVAL-007]].

## BDR-035 — Analyze-before-plan invariant v1 — read-before bookend of coupled-capitalize

- **Date**: 2026-06-26
- **Status**: accepted
- **Decision**: Dev flows now READ related memory before planning (ship-feature also reads related code), mirroring how [[BDR-034]] made them WRITE memory after. Shared include `lib/analyze-before-plan.md` (tête-bêche of `lib/capitalize-commit.md`). Invariant = DISPOSITION, not reading: the plan must NAME each surfaced ID (in-force / already-seen / non-binding) — a verifiable trace in the artifact, not "did it look". Two-pass: grep `## <PREFIX>-` body headings → select on titles → full-read only the selected bodies. Wiring: ship-feature STEP 0d (analyzer subagent code+memory, fed to brainstorm/plan by INPUT INJECTION + STEP 3 reconciliation gate); bugfix STEP 2.5 (blockers-first); feat STEP 0.6 (decisions-first, MINI-PLAN names in-force or states none); hotfix opt-in blockers-only; init-project + onboard = no-op exceptions. Guarded no-op (`[ -d .claude/memory ]`).
- **Why**: coupled-capitalize gave every flow a write-after; NO flow read the memory it feeds — bookend half-open. A bugfix wrote BLK at the end but never checked blockers.md for the same root cause already solved. Closes Gap B (memory, universal) + Gap A (code, ship-feature — the lone cold-planner).
- **Alternatives rejected**:
  - Index two-pass — `## Index` drifted on this mature repo (decisions 11/34, learnings 21/52, blockers 2/9 missing) in scattered blocks → an Index-based selector silently misses a large unpredictable fraction. Body headings drift-immune (100% coverage). See [[LRN-055]].
  - Extend analyzer only — inline flows (feat/bugfix/hotfix) never call analyzer pre-plan → would close Gap B for none. Needed both: include + analyzer RELATED MEMORY section.
  - PASS-2 skip-if-already-in-context — no deterministic oracle for "in context"; reintroduces the behavioral guard. See [[LRN-054]].
- **Reference**: commit `67c6a81`, `lib/analyze-before-plan.md`, `agents/analyzer.md`. Bookend of [[BDR-034]]. See [[LRN-053]], [[LRN-054]], [[LRN-055]], [[LRN-056]], [[LRN-057]].

## BDR-036 — Doc-sync coupled invariant — commit the docs doc-syncer patches (twin of BDR-034, BUILT not reordered)

- **Date**: 2026-06-27
- **Status**: accepted
- **Decision**: doc-sync flows now COMMIT the public docs doc-syncer patches, via new `lib/doc-commit.sh` (helper) + `lib/doc-commit.md` (include) — mirror of memory-commit/capitalize-commit, 4 DELTAS: (Δ1) dynamic scope = patched files as argv, not a fixed pathspec; (Δ2) INVERSE exclusion = fail-closed + loud guard rejecting `.claude/**`+`CLAUDE.md` (dedicated exit 4), opposite of memory-commit which TARGETS `.claude/`; (Δ3) no hash anchoring (docs carry no SHA, [[LRN-052]]); (Δ4) `docs:` msg. doc-syncer emits `PATCHED_FILES` (one path/line) → agent splits on newline → each as DISTINCT argv (space-safe, [[LRN-060]]). 2 orchestrators reordered DOC SYNC before FINISH (ship-feature STEP 9→8, init-project STEP 12→10c, GSD 13→12); 3 inline flows wired (feat/bugfix/hotfix DOC SYNC). Consumption MECHANICAL ([[LRN-057]] case a, = BDR-034).
- **Why**: doc-syncer PATCHED docs but COMMITTED nothing (grep-proven, zero git commit) → push/PR path = docs stranded outside PR (orchestrators); inline = docs left dirty. Twin of [[BDR-034]] but NOT same fix: memory ALREADY had a commit helper (only mis-timed); doc-sync had NONE → had to BUILD the mechanism, not just reorder. "Reorder alone" (the deferred note's framing) REFUTED in read-phase ([[LRN-058]]).
- **Honest scope/choices** (engraved, not glossed):
  - (a) MINOR doc content stays NON-gated yet auto-committed — CONSCIOUS, not memory's always-gated content; the VISIBLE surface (files + AGENT-composed change summary, not a bare count) REPLACES the gate as the review surface. Strengthening the MINOR gate = separate doc-syncer chantier.
  - (b) init-project PARTIAL — scaffold + bootstrap-README commit gap ([[BLK-010]], unborn HEAD + worktree) + GSD ROADMAP post-FINISH ([[BLK-011]]) deferred = NEW work, not replication.
  - (c) scope EXPANDED mid-chantier via the ref-sweep to 3 inline flows — asymmetry vs memory (BDR-034 wired ALL flows) was the decider.
- **Alternatives rejected**:
  - Reorder-only (the deferred note) — refuted: doc-syncer commits nothing, reordering uncommitted docs still misses the merge.
  - Static-glob scope (`*.md`/`docs/`) — over-reach onto a user-edited doc / `MIGRATION.md`; chose touched-files argv (in-thread list already in hand).
  - Silent-filter the forbidden path — masks an upstream BDR-022 bug; guard must REFUSE-ALL loudly ([[LRN-060]]).
- **Reference**: commits `ae1f218` (helper+tests) · `4a54a65` (include) · `fb1f359` (doc-syncer PATCHED_FILES) · `636b491` (ship-feature reorder) · `e81f629` (init-project reorder) · `1b01b95` (3 inline flows). See [[BDR-034]], [[LRN-058]], [[LRN-059]], [[LRN-060]], [[BLK-010]], [[BLK-011]], [[EVAL-008]].

## BDR-037 — v2 capitalize Stop-hook REJECTED → wire /capitalize+/close to the include

- **Date**: 2026-06-27
- **Status**: accepted
- **Decision**: Deferred "v2 hook" ([[BDR-033]]-style non-blocking stateless Stop-hook nagging dirty `.claude/memory`) REJECTED — no code written. No Claude Code event supports an end-of-session nag: `Stop` fires PER-TURN (self-defeating — would nag during /capitalize's own write→commit window, [[LRN-047]]); `SessionEnd` is debug-log-only (can't nag) + would bypass the content gate (half-written entries). Real gap ≠ forgetting → CÂBLAGE manquant: `/capitalize` + `/close` never call `lib/capitalize-commit.md`. Redirect: wire the include into `/capitalize` STEP 5B (`/close` = thin alias, follows free), same one-liner as the 6 dev flows. Content gate (STEP 3) first → commit of approved entries automated ([[BDR-034]] contract). Deterministic, zero-noise, at source.
- **Why**: 3 git proofs — (1) memory already committed by hand 35× as pure `chore(memory)` (zero code mixed); (2) orphans self-heal — `commit_memory` stages whole `.claude/memory` dir, next flow sweeps up; (3) cost on common path (per-turn noise / non-gated commit), benefit marginal (residual self-healing) → a hook polices a discipline already in evidence. OUBLI not choice: include + helper born 2026-06-26; `/capitalize` last edit 2026-06-19 (created 2026-06-09), `/close` 2026-04-23 — skills predate the machinery 7-60d; wiring commits (`2763678`/`e8eff7e`/`df60df6`) touched neither. No control removed: the commit was never gated, just done by hand in the exact `chore(memory): <IDs> — <ctx>` style the include reproduces.
- **Alternatives rejected**:
  - (a) Stop per-turn memory-only wrapper — fires during the very flush it nags about → [[LRN-047]] self-defeat (frequent ignored nag = risk, not annoyance).
  - (b) SessionEnd auto-commit (FAIT) — bypasses STEP 3 content gate, embarks half-written entries, can't report actionably.
  - (c) abandon with no redirect — leaves the real wiring gap open; fix for an unwired skill = wire it.
- **Reference**: read-phase analysis (no hook code ever written); wiring commit (capitalize STEP 5B) follows. Completes [[BDR-034]] rollout; applies [[BDR-033]] doctrine to REJECT (not all nudges — the determinism split is [[LRN-061]]). See [[LRN-061]], [[LRN-047]], [[LRN-049]], [[LRN-054]].

## BDR-038 — deploy skill: per-project learning runbook, two-moment cold-resume
- **date**: 2026-06-27
- **status**: accepted
- **decision**: New `/deploy` skill = per-project runbook in `.claude/deploy/`. 5 artifacts: `PROCEDURE.md` (runbook, in-place edits), `INCIDENTS.md` (`DEP-NNN` ledger, append-only), `STATE.json` (deploy oracle, committed), `PENDING.json` (cold-resume bridge, gitignored), `NEXT.sh` (instantiated checklist, gitignored, hand-run). Two-moment spine: BEFORE (delta-instantiate `NEXT.sh` + hand back) → user deploys OUT-OF-BAND → AFTER (react: MARK success or LEARN from failure). Cold cross-session resume via `PENDING.json` (disk = only memory across the gap). Learn = atomic patch+incident (one `deploy-commit.sh` call, both files). New helper `lib/deploy-commit.sh` (allowlist `.claude/deploy/`). Built via subagent-driven-development (4 tasks).
- **why**: deployment memory that LEARNS (runbook patched in place per failure) beats a frozen runbook; disk-bridge so a resume survives session loss.
- **alternatives**: tag-oracle (rejected — lightweight-tag date unreliable, rebase-fragile, [[LRN-063]]); separate append-only ERRORS log (rejected — git history of `PROCEDURE.md`+`INCIDENTS.md` suffices, no `resolved-by` field); `NEXT.sh`-as-bridge (rejected — ephemeral ≠ persistent → separate `PENDING.json`); reuse doc/memory-commit (rejected — neither can commit `.claude/deploy/`, [[LRN-064]]).
- **reference**: `skills/deploy/SKILL.md`, `lib/deploy-commit.sh`, `templates/deploy/`; branch `feat/deploy-skill` (b210e8d..79741e3, kept un-merged); spec `docs/specs/2026-06-27-deploy-skill-design.md`, plan `docs/plans/2026-06-27-deploy-skill.md`.

## BDR-039 — Gitea branch protection = Option-1 owner-pushable, not require-PR
- **date**: 2026-06-29
- **status**: accepted
- **decision**: Protect `main` + `develop` on every gitflow-migrated Gitea repo with **Option 1 (owner-pushable)**: `enable_push=true` + `enable_push_whitelist=true` + `push_whitelist_usernames=[owner]`. Blocks force-push, branch deletion, and pushes by non-owners — while letting the owner push their LOCAL gitflow merges directly. NOT require-PR / required-review.
- **why**: gitflow integrates by **local directed merges** — `gitflow finish` runs `git merge --no-ff` on the owner's machine then pushes the merge commit. require-PR would REJECT those pushes: every feature/bugfix/release merge would need a manual PR, and the **hotfix fan-out** (hotfix → main + develop + each open `release/*`) becomes 3+ manual PRs per hotfix. For a solo-owner Gitea, required reviews add zero review value, only friction. Owner-pushable keeps the protection's real teeth (no force-push, no deletion, no non-owner push) without breaking the local-merge workflow. Protection is a BACKSTOP — the per-repo pre-commit hook + the "finish only on an explicit human signal" rule are the primary controls.
- **alternatives**: require-PR + required reviews (rejected — breaks `gitflow finish`'s local merges; the 3-way hotfix fan-out becomes manual PRs; no review value for a solo owner, pure friction); no protection (rejected — leaves force-push + branch deletion + accidental non-owner push open; it is the deterministic backstop the advisory rules can't guarantee); protect `main` only (rejected — `develop` is equally a protected base in the model, needs the same force-push/deletion guard).
- **reference**: `lib/gitflow-migrate.sh` `_protect()` (POST `/repos/{o}/{r}/branch_protections`, owner whitelist); applied to all 6 repos 2026-06-29 (journal). Hook backstop in `lib/gitflow.sh` (pre-commit); CLAUDE.md "Version control — gitflow (universal)". Pairs with [[LRN-069]] (the `git push` ASK gate at the tool-call layer).

## BDR-040 — doc-syncer MINOR-shape oracle: deterministic floor under LLM's MINOR call
- **date**: 2026-06-29
- **status**: accepted
- **Problem**: doc-syncer AUTO MODE classifies drift NONE/MINOR/SIGNIFICANT by LLM judgment, no deterministic backstop. SIGNIFICANT mislabeled MINOR → silent auto-patch + auto-commit, skips the SIGNIFICANT gate (RISK-1). Follow-up [[BDR-036]] flagged.
- **Decision**: `lib/doc-shape.sh` re-checks SHAPE of each MINOR patch BEFORE the silent auto-commit. Envelope (per path, `git diff HEAD`): adds ATX heading | added > DOC_SHAPE_MAX_ADDED (def 20) | removed > MAX_REMOVED (def 20) | new/untracked file | non-doc → EXCEEDS. Aggregate: ANY path exceeds → whole set escalates to the EXISTING SIGNIFICANT gate (STEP A4 `Apply? yes/no/select`; no=revert all, select=keep subset). Thresholds env-overridable.
- **Oracle NOT a blocking gate (B rejected)**: [[BDR-036]] graved MINOR-non-gated as CONSCIOUS (visible surface replaces gate; blocking gate = friction disproportionate). Oracle does NOT gate genuine MINOR (auto-commit untouched, zero friction) — only re-routes shape-suspect patches. Tightens the DEFINITION of MINOR deterministically ([[LRN-046]] oracle > judge), adds no gate. Option B (human gate on every MINOR) REJECTED — contradicts [[BDR-036]], rejects the premise the reading refuted.
- **ENGRAVED LIMIT — do not over-read the guarantee**: oracle catches STRUCTURAL/size significance, NOT semantic. A 3-line edit that CHANGES MEANING, no heading, small → still reads MINOR (rc 0) and auto-commits. Deterministic FLOOR under LLM judgment = REDUCTION of RISK-1's gross cases, NOT elimination. LLM owns the semantic call above the floor; the visible surface ([[BDR-036]]) stays the content backstop.
- **Scope tranché**: ① oracle + ② [[LRN-071]] masked-commit fix built. ③ branch-guard (doc-commit refusing main/develop) DEFERRED — duplicates the protected-base predicate a 3rd time (lib + gitflow hook + here); migrated repos have the hook → ③ guards a state that shouldn't exist. Reconsider only for repos outside `gitflow init`.
- **Build**: TDD RED→GREEN. run-doc-shape.sh 19/19 (incl. threshold boundary + env-override) + behavioral Scenario D. Wired doc-syncer STEP A4 + doc-commit.md ACKNOWLEDGMENTS coherence. shellcheck clean.

## BDR-041 — /reconcile = deterministic declared-vs-real engine + thin gated skill (reconciler, not lister)
- **Date**: 2026-06-30
- **Status**: accepted
- **Decision**: `/reconcile` answers "what work is REALLY open?" by confronting DECLARATIVE sources (TODO `[x]`/`[ ]`/`[~]`, registry statuses, `## Index`) against REAL state (git/fs, registry BODY). Split: `lib/reconcile.sh` (deterministic engine — body enumeration, `reconcile_oracle_*`, BLK last-block-wins, lexical deferral sweep, contradiction candidates, pure `reconcile_verdict` kernel) + `skills/reconcile/SKILL.md` (thin orchestration + A/B/C write-back gate). Founding principle = RECURSIVE COHERENCE: never use a declarative source as oracle (Index/checkbox/status/path-name) — enumerate from BODY `## ID` headings, decide done/stale from git/fs. TESTED: run-reconcile.sh T1 reds if engine reads `## Index` (shim → 51≠72, canary LRN-020 dropped). Registries READ-ONLY (curation = /prune-memory).
- **Why**: RED proved a capable agent reconciles when GUIDED ("use git + justify") but MIRRORS the TODO when not (false positives + missed contradiction), and even guided hits the compound-status trap (BLK-008). Value = determinism + cheapness + gate, NOT teaching ([[LRN-031]], [[LRN-075]]). Mechanical 80% → script; judgment 20% → thin skill (writing-skills: automate mechanical, document judgment).
- **Alternatives rejected**: monolithic teaching/discipline skill (agents reconcile when guided → no teaching value); `grep '[ ]'` lister (reproduces the lie); trust Index (drift, [[LRN-055]]); blocking write-back gate (friction — A/B/C surface chosen).
- **Honest limits (graven)**: deferral detection LEXICAL (marked-only; unmarked "à reprendre quand X" missed); contradictions = CANDIDATES (token overlap), surfaced not asserted; cross-repo "not verifiable here"; cross-ref verdicts ("[~] done because chantier X below complete") surfaced, not auto-resolved.
- **Reference**: `lib/reconcile.sh`, `lib/tests/run-reconcile.sh` (20/20) + `lib/tests/fixtures/` (neutral-named, [[LRN-077]]), `skills/reconcile/SKILL.md`, CLAUDE.md "Skill routing". Born of the 2026-06-29 manual inventory (its known-good oracle). Built via superpowers:writing-skills. See [[LRN-075]], [[LRN-076]], [[EVAL-011]].

## BDR-042 — /release-candidate = thin orchestrator over gitflow release; the tag lives in the skill
- **Date**: 2026-06-30
- **Status**: accepted
- **Decision**: `/release-candidate <X.Y.Z>` cuts a release by ORCHESTRATING the existing `lib/gitflow.sh` mechanic, NOT rewriting it. Flow: preconditions (clean tree, identity, develop ahead of main) → `gitflow start release` → prep (version.txt + CHANGELOG, breaking documented) → run-tests gate → HUMAN "WHEN to release" gate → `gitflow finish` (fan-out main+develop+delete, lib L108-111) → **`git tag -a vX.Y.Z main`** → push gated. The `git tag` lives in the SKILL, lib UNTOUCHED — the tag is release-specific (version + message + human call), the lib's fan-out is generic. Scheme `vX.Y.Z`, CONTINUES the version.txt/CHANGELOG lineage (never restart at v1.0.0 — desyncs from a CHANGELOG already at 3.x).
- **Why**: gitflow release was wired (start base=develop L49, finish fan-out main+develop L108-111) but had NO tag step (grep-confirmed: zero `git tag` in gitflow.sh). The tag is the only gap; an orchestrator supplies it without touching the tested mechanic.
- **Consequence (accepted)**: a release cut by calling `gitflow finish` directly, bypassing the skill, fans out but is NOT tagged → `/release-candidate` is the CANONICAL sole release path. Acceptable for a solo repo; revisit (tag in lib) only if direct-lib releases become a need.
- **Alternatives rejected**: tag inside `gitflow_finish` (atomic but modifies the tested generic mechanic for a release-specific concern — lib=mechanic/skill=judgment); restart tags at v1.0.0 (desyncs tag↔CHANGELOG lineage).
- **Reference**: `skills/release-candidate/SKILL.md`, `lib/tests/run-release-candidate.sh` (RED no-tag → GREEN 5/5), CLAUDE.md routing. Built via writing-skills TDD. Consumes the gitflow model [[BDR-039]]. See [[LRN-078]], [[LRN-079]], [[EVAL-012]].

## BDR-043 — BDR-015 trigger cleared: 5 ex-broken gstack symlinks repaired → darwin re-baseline back in scope
- **Date**: 2026-06-30
- **Status**: accepted (requalifies [[BDR-015]] — append-only, BDR-015 left intact)
- **Decision**: the 5 dirs [[BDR-015]] excluded from `/darwin-skill` (`benchmark-models`, `context-restore`, `context-save`, `make-pdf`, `plan-tune`) are no longer broken. gstack now ships those skills — all GENERATED by `gen-skill-docs` in the `make plugin` run → real submodule targets exist, symlinks resolve. VÉRIF audit 2026-06-30 = 0 broken among 83 symlinks (skills/ 41 + skills-disabled/ 33 + nested 5 + top-level 4). Per BDR-015's own caveat ("if/when symlinks repaired → re-run baseline to bring them in scope"), the 5 RETURN to darwin scope → re-baseline UNBLOCKED.
- **Why**: BDR-015's exclusion was CONDITIONAL on the targets being broken (external-ownership + missing-target). Precondition gone → exclusion no longer applies to these 5.
- **Action (NOT done)**: verify `~/.agents/skills/darwin-skill/results.tsv` still marks these 5 `status=error` ("broken gstack symlink — out of scope"); if so, re-run darwin baseline to bring them in. Status = UNBLOCKED, execution PENDING — do NOT read as "re-baselined".
- **Distinct from [[BLK-007]]**: BLK-007/`f928a53` (2026-06-02) = a DIFFERENT symlink episode (`spec` + 5 iOS device-farm skills, source-only after a submodule bump; fixed by linking `spec`, skipping iOS). NOT the 5 of BDR-015 — kept separate to avoid a false causal link.
- **Reference**: VÉRIF audit (subagent, filesystem-only, 2026-06-30). [[BDR-015]] caveat. darwin eval log `results.tsv`.

---

## BDR-044 — auto-skill-dispatch won't-build: under→over reframe, measured — model already discriminates
- **Date**: 2026-06-30
- **Status**: accepted · won't-build
- **Decision**: do NOT add L2 routing prose to CLAUDE.md for "auto-trigger skills on intent". Chantier retired won't-build — 3rd measured moot of the session (after [[BDR-001]] --help + [[BDR-043]]/[[LRN-082]] darwin re-baseline).
- **Why — the dependent variable inverted**: the initial fear was UNDER-routing (model ignores skills, does the task by hand). Cartography refuted it — routing is a STACK and L1 (superpowers "1% chance → you MUST invoke") already SUR-determines invocation → "does it route?" = "already yes". The real open question became DISCERNMENT (clear→route, ambiguous→ASK, trivial→abstain), and the real hazard inverted to OVER-routing. Measured in REAL fresh main-loop sessions (8 prompts, 3 classes): CLEAR→routes ✓, AMBIGUOUS→asks (refuses to guess, investigates to ask a USEFUL question) ✓, TRIVIAL→abstains ✓. The L1-vs-Workflow-rules textual tension ("1% → MUST invoke" vs "ask one question if needed / pragmatic on trivial") is resolved well in behavior — the model balances. Adding L2 bounding prose = phantom value AND risks DEGRADING an already-good discernment.
- **Alternatives rejected**:
  - Add a routing-reinforcement instruction (original intent) → phantom value: L1 already over-determines routing; more mandate worsens the only real risk (over-routing).
  - Add an over-routing bound (clear→route / ambiguous→ask / trivial→abstain) at L2 → measurement shows the model ALREADY does this; codifying it risks perturbing it, zero upside.
  - Keyword hook on intent verbs → too noisy — the design-hook mis-fired on "design" in "auto-skill-dispatch" 3× this session; intent verbs (corrige/crée) are everywhere.
- **Reference**: cartography L0–L4 + discernment-RED (user-run, fresh sessions). Subagent under-routing RED RETIRED as non-discriminating ([[LRN-083]]). [[LRN-080]] (measure-first), [[LRN-049]] (bound noise). TODO "auto-skill-dispatch" → won't-build.

## BDR-045 — Standalone memory/doc skills branch to `chore/*` via the aiguillage (hook exemption kept)

- **Date**: 2026-07-01
- **Status**: accepted
- **Decision**: Standalone memory/doc skills (`/capitalize` `/close` `/prune-memory` `/reconcile`) run the gitflow aiguillage BEFORE writing: on a protected base they `gitflow start chore <name>` off develop → commit lands on `chore/*`, not direct on main/develop. New `chore` type in `lib/gitflow.sh` (`base_for`→develop, `branch_type`, `finish`→develop like feature/bugfix); hook UNCHANGED (`chore/*` non-protected; the `.claude/**`-on-main exemption KEPT — T3 still green). `gitflow-aiguillage.md` broadened (caller→type map); 3 skills wired (`capitalize` covers `/close` via alias, `prune-memory`, `reconcile`); tests +T1 chore predicates +T6b finish chore→develop +T10 coherence chore/m → 64/64. Reused the EXISTING aiguillage include, not a new mechanism. Commit `e8807a7`.
- **Why**: the `.claude/**` exemption is scoped to the SIDE-CAR ([[BDR-034]]: memory following a code branch). When memory IS the work (standalone reconcile/prune/capitalize) there is no branch to follow → it fell back to `main`. A multi-repo raccord committed 5 `chore(memory)` direct on `main` and nothing flagged it — the exemption worked as designed, masking the divergence with the "all via branch" rule ([[LRN-084]]). The aiguillage closes the SKILL path without taxing the side-car. The hook can NEVER enforce "from develop" (only "not on a protected base") → that half lives ONLY in `gitflow_start`.
- **Alternatives rejected**:
  - (A) remove the `.claude/**` exemption — breaks standalone `/capitalize`+`/close` on main/develop (commit in place, no branch of their own — `memory-commit.sh` has no protected-base guard) AND every side-car commit; over-reaches the leak.
  - (C) codify exemption + human habit — enforces NOTHING mechanically; goal was automatic.
  - (D) narrow the exemption by size/scope in the hook — fuzzy, false positives.
- **Honest residual**: a MANUAL `git commit` of `.claude/**` on `main` still passes — B covers the skill path only. Non-blocking hook WARN on manual `.claude/**`-on-main = DEFERRED. See [[BDR-034]], [[BDR-039]], [[LRN-084]].

---

## BDR-046 — Claude Code installs via the official native installer, not npm

- **Date**: 2026-07-01
- **Decision**: install.sh fresh-machine branch installs Claude Code via `curl -fsSL https://claude.ai/install.sh | bash` (official native installer), not `npm install -g @anthropic-ai/claude-code`. Skip-if-present guard unchanged. update-all.sh stays channel-aware (native → `claude update`, legacy npm → npm).
- **Why**: official quickstart (code.claude.com/docs) lists Native (recommended) / Homebrew / WinGet / apt only — npm is NO longer a documented channel. npm collided with the native symlink `~/.local/bin/claude` → EEXIST ([[BLK-014]]), and npm bypasses native background auto-update. install-plugins.sh already pointed to code.claude.com (native) — install.sh was the npm outlier; this aligns them.
- **Alternatives rejected**:
  - (A) keep npm on fresh install — deprecated channel, re-introduces the EEXIST class on any machine with a prior native install, no auto-update.
  - (B) `claude install` subcommand — needs claude already present (chicken-and-egg on fresh machine); curl bootstrap is the documented first-time path.
  - (C) Homebrew/apt — platform-specific; curl covers macOS/Linux/WSL uniformly and matches the doc's "recommended".
- **Honest residual**: `curl | bash` = pipe-to-remote-bash (accepted: official Anthropic domain, same pattern already used for nvm at install.sh:29). node/npm still installed as prereqs — needed by the plugins step (gsd-pi), not by claude. PATH export added so the auth step finds the freshly-installed binary. See [[BLK-014]], [[LRN-085]].
- **Status**: accepted. Commits 8dc4027 + 6be627e, branch bugfix/install-claude-idempotent, pending merge.
- **Update 2026-07-01**: MERGED `2393ca5` → develop, pushed — supersedes "pending merge".

---

## BDR-047 — ECC audit → zero import; local config ahead of reference

- **Date**: 2026-07-01
- **Status**: accepted
- **Decision**: audited affaan-m/ECC (legit original, NOT the arabicapp malware
  clone) read-only for value vs this config. Result: ZERO import. Nothing taken.
  Clean measure-first outcome — analysis closed.
- **Safety** (durable, avoids re-audit): ECC = genuine original — 2232 commits,
  ~1480 by Affaan Mustafa, real contributor long-tail, sequential PRs. No payload:
  postinstall = echo, install.sh runs only its 3 reputable deps (@iarna/toml, ajv,
  sql.js), ships own supply-chain IOC scanner. Zero injection flags across ALL
  categories. NOTE: ECC install.sh auto-runs `npm install` → never run their
  installer casually; this analysis stayed read-only.
- **Why zero import** (each intuition CHALLENGED, not confirmed):
  - RULES (122 files, by-language): ~80% redundant w/ CLAUDE.md, rest dormant
    reference. INERT at ECC — nothing reads rules/, their README admits "plugins
    cannot distribute rules automatically", `paths:` frontmatter aspirational (no
    auto-routing exists). "take all" refuted.
  - CONTEXTS (dev/research/review, 3 tiny files): least load-bearing. Delivery via
    `claude --system-prompt "$(cat)"` would OVERWRITE global CLAUDE.md. Harmful
    as-shipped. "important" refuted.
  - GUIDELINES: ECC itself demoted to docs/example. Per-project CLAUDE.md
    (git-tracked) superior.
  - INSTRUCTION FILES (AGENTS/RULES/SOUL/WORKING-CONTEXT): redundant or
    ECC-specific. AGENTS.md "proactive delegation" already mandated here.
  - MEMORY/learning: auto hook-capture → confidence-scored instincts. CONFLICTS
    measure-first (observe-first vs approve-first). Instinct schema parked (gated
    only).
  - eval-harness (the spike): DOCS-ONLY — 271-line SKILL.md, no runner,
    `/eval define|check|report` exist NOWHERE. Same "belle méthodo / câblage
    vaporware" pattern as rules. Executable-eval ALREADY covered locally:
    lib/tests/run-*.sh (code graders) + darwin dim8 (with/without-baseline
    sub-agent effect testing + git ratchet) + RED-before-GREEN discipline. evals.md
    = ledger of REAL runs (EVAL-011 ran 20/20, dogfooded) — spike premise
    "descriptif pas exécuté" was FALSE, corrected.
- **Lesson**: external repo — even prestigious / "d'un boss" — judged on REAL added
  value to THIS config's axes (typed memory, real harness, gitflow), NOT author
  reputation. Measuring it revealed local config AHEAD on those axes. Taking a thing
  "since we analyzed" = sunk-cost. Zero is the honest conclusion. Don't re-propose
  auditing ECC expecting treasure.
- **2 real gaps FOUND (not rejected — the only concrete fruit of the audit)**:
  1. pass@k / reliability-under-repetition — local harness proves PRESENCE (guard
     fires, often N=1), not RELIABILITY (right output 9/10 under repetition). Blind
     spot for non-deterministic skill/agent behavior (EVAL-006 flagged "N=6 fleet
     NOT exhausted").
  2. re-runnable regression battery indexed on model upgrades — bespoke
     per-chantier tests, no one-command "re-run behavioral evals for load-bearing
     skills" when model changes. darwin optimizes on-demand, not a standing gate.
  - **Both = home-grown ~10-line bash over darwin's test-prompts.json if ever
    wanted — NOT ECC imports.** eval-harness delivers neither (no runner). Separate
    later decision.
- **Alternatives rejected**:
  - Import eval-harness anyway (sunk-cost "we analyzed it") — rejected: docs-only,
    capability already covered, adds vocabulary not machinery.
  - Import rules by-language + build wiring hook — parked: low ROI (bash/md, not
    polyglot); hookify-rules would be the mechanism, someday-if-polyglotte.
  - Adopt instinct auto-capture — rejected: conflicts measure-first.
- **Optional zero-cost nicety** (not now): tag evals.md entries w/ grader-type + k
  (e.g. `method: code-grader, pass^3`) — writing convention, not an import.
- **Reference**: read-only clone (scratchpad), 4 parallel analyzer agents +
  eval-harness spike, this session. No branch on ECC, no import. See [[BDR-045]]
  (chore/ aiguillage), [[BDR-009]] (caveman registries).
- **Corroboration 2026-07-03** (Opus 4.8 re-audit; repo UNCHANGED — HEAD 81af407
  2026-06-29, 2232 commits identical, zero commits since 01/07): 6 parallel analyzer
  agents re-verified every BDR-047 fact w/ fresh file:line. rules/ inert (paths: 0
  consumers, rules/README.md:333 "cannot distribute rules automatically"); contexts/
  overwrite (the-longform-guide.md:68-74 `--system-prompt`); eval-harness no runner
  (/eval absent; gan-harness.sh + skill-improvement/evaluate.js exist but hors-scope,
  deliver NEITHER pass@k nor model-upgrade battery); memory auto-capture conflicts
  approve-first (continuous-learning-v2 observer-loop.sh:160-164 "Do NOT ask for
  permission"); distribution = product scaffolding, N/A. ZERO factual divergence.
  ONE scope gap: BDR-047 never opened hooks/ — ECC's only WIRED subsystem. Fruit:
  config-protection hook (own idiom, NOT ECC import), shipped
  feature/config-protection-hook. Lesson holds + refined by [[LRN-090]].

## BDR-049 — Verifier doctrine: fresh + blind + disk-contract + proof-or-fail

- **Date**: 2026-07-03
- **Decision**: conformity verdict comes ONLY from a FRESH verifier subagent per iteration. Input = contract PATH (read from disk — dev restatement structurally unable to interpose) + diff range + optional test cmd. NEVER iteration history: blind, complete verification every time (cost bounded by the main-loop max-3 cap, [[LRN-083]]: loops decided in main loop). CONFORME ⇔ all criteria MET + zero out-of-scope. PROOF line mandatory ([[LRN-048]]). Mute/unparsable verifier NEVER a PASS: 1 fresh retry, 2nd structural failure = human escalation. Dev-justified out-of-scope enters FILE SCOPE only via a human micro-gate (`[gated]` marker) — else the dev justifies everything and scope constrains nothing. Contract on DISK at creation (`.claude/tasks/contracts/<date>-<slug>-<HHMM>.md`, committed; aborted run → deleted or `status: aborted`, never left dirty).
- **Rationale**: dev self-score is always confident → not a gate. Verifier fed history anchors on prior verdicts → telescopic drift. Context-only contract dies at compaction, the verbatim with it.
- **Alternatives rejected**: dev self-assessment as gate; cumulative verifier context ("cheaper" but anchored); gitignored run files (lose escalation reference + session-death survival).
- **Reference**: lib/contract-interview.md + agents/verifier.md + lib/tests/contract-verifier.test.sh (31 locks) — branch feature/contract-verifier `6aed5ee`. Behavioral GREEN: planted-gap → ECARTS(2) exact; conform-under-injected-history → CONFORME (blindness held). Twin of [[BDR-048]] (security gate). Conditions [[LRN-048]], [[LRN-083]].
