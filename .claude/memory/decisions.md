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