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
| BDR-001 | 2026-04-22 | Uniform --help helper via session-start hook (option C) | accepted |
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
| BDR-022 | 2026-06-18 | doc-syncer scoped to public docs; `.claude/` + `CLAUDE.md` read-only context, never targets; conventions + clean mode | accepted |
| BDR-023 | 2026-06-19 | Merge /close into /capitalize — 2 modes + TODO reconcile; /close alias | accepted |

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
