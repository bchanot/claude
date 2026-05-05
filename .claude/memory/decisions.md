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
  - Append-only. Never rewrite past entries - add a new one with status superseded if needed.
  - One entry per non-trivial choice. Trivial = reversible in under 10 min with no cross-file impact.
  - Capture why more carefully than what - the what rots, the why lasts.
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

---

## BDR-001 — Uniform --help helper via session-start hook (option C)

- **Date**: 2026-04-22
- **Status**: accepted
- **Decision**: every skill exposes `--help` via a shared snippet injected by the session-start hook, rather than duplicating the helper in each SKILL.md.
- **Why**: 25+ skills — keeping the same helper synced across every file guarantees drift. A single injection point = single source of truth.
- **Alternatives rejected**:
  - Option A (copy the helper into each SKILL.md) — rejected: maintenance entropy.
  - Option B (external wrapper `/help <skill>`) — rejected: breaks the "one command = one skill" experience.
- **Reference**: commit 3968a29.

## BDR-002 — Move tasks/ + introduce memory + audits under .claude/

- **Date**: 2026-04-23
- **Status**: accepted
- **Decision**: migrate `./tasks/` to `.claude/tasks/`, create `.claude/memory/` (5 registries BDR/LRN/BLK/journal/EVAL) and `.claude/audits/` for AUDIT_* files. Adapt skills/agents/CLAUDE.md. Integrate a CAPITALIZE step into completion skills (ship-feature, feat, bugfix, hotfix, commit-change) and add a `/close` skill for the session-end ritual.
- **Why**: grouping all meta-project state (AI config + tasks + memory + audits) under `.claude/` isolates Claude governance from real code. Aligned with the official Claude Code memory docs. Without integration in completion skills, the registries would stay empty (aspirational text).
- **Alternatives rejected**:
  - Keep `./tasks/` at root — rejected: clutters the repo, mixes code signal with governance signal.
  - Use `.claude/agent-memory/` for everything — rejected: `agent-memory/` has a distinct role (already used by other tools).
  - Ritual as aspirational text only in CLAUDE.md — rejected: zero execution guarantee, registries would stay empty.
  - `Stop` hook to ask the 3 questions every turn — rejected: too noisy.

## BDR-003 — Gitignore wildcard + negations pattern for `.claude/`

- **Date**: 2026-04-23
- **Status**: accepted
- **Decision**: use `.claude/*` (wildcard match of immediate children) + negations `!.claude/tasks/`, `!.claude/memory/`, etc., rather than `.claude/` (recursive ignore).
- **Why**: when a parent is ignored via `.claude/`, git does not descend into it (performance optimization) and negations on children are **ignored** — documented in `gitignore(5)`. With `.claude/*`, git matches each child individually, making negations active.
- **Alternatives rejected**:
  - `.claude/` + `!.claude/tasks/` (naive) — rejected: negations have no effect, everything stays ignored.
  - Drop `.claude/` from gitignore entirely — rejected: `.claude/settings.local.json` and `.claude/agent-memory/` must stay ignored (per-machine).
  - Track paths via `.gitattributes` or an external tool — rejected: over-engineering, git handles this natively.
- **Reference**: commit `499cd07`, `git check-ignore -v` verified on 4 paths (2 tracked, 2 ignored).

## BDR-004 — Adopt auto permission mode as default

- **Date**: 2026-04-27
- **Status**: accepted
- **Decision**: set `permissions.defaultMode` to `"auto"` in user-scope `settings.json` and drop `disableAutoMode: "disable"`. Auto mode runs a classifier on every action and blocks risky operations (`curl|bash`, prod deploys, force push, IAM grants, mass deletes, exfiltration to external endpoints) while auto-approving local edits, lockfile-declared dep installs, and read-only HTTP.
- **Why**: prompt fatigue under `default` mode is significant on multi-step autonomous work. Auto mode keeps a safety net (classifier review) without the per-tool friction. The classifier also re-evaluates conversation-stated boundaries ("don't push", "wait for review") on every check, so verbal constraints carry weight.
- **Alternatives rejected**:
  - Keep `default` — too many prompts, breaks flow on long tasks.
  - `acceptEdits` — eliminates prompts but no classifier, blanket trust on Bash beyond filesystem helpers.
  - `bypassPermissions` — skips all checks, no prompt-injection guard. Only for isolated containers.
  - `dontAsk` — full denylist, breaks anything not pre-approved. Suited to CI, not interactive work.
- **Caveats**: requires Claude Code v2.1.83+, plan ≠ Pro (Max/Team/Enterprise/API only), Sonnet 4.6 / Opus 4.6 / Opus 4.7, Anthropic API provider. On entering auto mode, blanket allow rules (`Bash(*)`, `Bash(python*)`, package-manager run, `Agent`) are dropped and restored on exit.
- **Reference**: commit `1421578`.

## BDR-005 — `motion` as default animation library; advisor stays read-only

- **Date**: 2026-04-27
- **Status**: accepted
- **Decision**: when a project's stack supports it, the framework installs `motion` (or `motion-v` for Vue 3 / Nuxt) as the default animation library. Install is **automatic** in `/init-project` STEP 5e (post-scaffold) and **opt-in** in `/onboard` STEP 2.5 (existing projects). `plugin-advisor` only **detects and reports** the status — it never runs `npm install` itself. Detection logic lives in `lib/animation-lib-check.sh` (sourced by all three layers).
- **Why**: framer-motion was rebranded `motion` in November 2024 (single package supporting React `motion/react`, Svelte, vanilla JS; `motion-v` is the parallel package for Vue). Baking the new name in now avoids legacy-import sprawl across new projects. The split init-vs-onboard behavior follows the trust gradient: at init, the user has just validated the entire scaffold so silent install is fine; at onboard, we are touching an existing `package.json`, which is invasive without explicit consent. Plugin-advisor was kept read-only to preserve its "Never modify files" contract (PHASE 4 already mutates plugin state with confirmation; piling npm installs on top would blur its responsibility).
- **Alternatives rejected**:
  - Pin `framer-motion` (legacy name) — rejected: the package is in maintenance mode, every new project would inherit the old import path.
  - Auto-install during `/onboard` without asking — rejected: silently adds a runtime dep + ~50 KB gzip to a project the user did not ask to modify.
  - Make `plugin-advisor` install missing libs — rejected: violates its read-only spec and breaks separation of concerns (advisor advises; orchestrators mutate).
  - React-only scope — rejected: Vue/Svelte teams should also benefit; `motion-v` makes the Vue case clean.
- **Eligibility rules** (helper output):
  - `eligible|motion`: React, Next.js, Remix, Astro+React, Svelte/SvelteKit
  - `eligible|motion-v`: Vue 3, Nuxt
  - `no|-`: backend, CLI, embedded, Flutter, static HTML, **React Native** (use `react-native-reanimated`), Astro without UI integration, no `package.json`
- **Reference**: helper at `lib/animation-lib-check.sh`; integration in `skills/init-project/SKILL.md` STEP 5e, `skills/onboard/SKILL.md` STEP 2.5, `agents/plugin-advisor.md` PHASE 1/2/3, `lib/design-gate.md`.

## BDR-006 — Caveman as 4th always-on plugin (output compression)

- **Date**: 2026-05-03
- **Status**: accepted
- **Decision**: install `JuliusBrussee/caveman` in the always-on tier alongside `security-guidance`, `superpowers`, and `rtk`. "Full" install = plugin (`/caveman` + cavecrew agents + plugin-scoped SessionStart/UserPromptSubmit hooks) + standalone hooks (statusline + stats badge in `~/.claude/hooks/`) + `caveman-shrink` MCP scaffold (NOT auto-registered — proxy needs upstream wrapper). `install-plugins.sh` STEP 5.5 calls `enable_plugin "caveman" "caveman"` to write it into `enabledPlugins`. Hook paths in `settings.json` are normalized to `~/.claude/hooks/...` post-install so this user's home dir doesn't leak across machines.
- **Why**: caveman compresses Claude's output ~75% via caveman-speak while preserving technical substance. Symmetrical with rtk (input compression hook) — rtk shrinks tool I/O, caveman shrinks model output. Both hooks pay zero passive cost in a clean session and amortize across long runs. Always-on is justified: the plugin auto-deactivates with phrases like "stop caveman" / "normal mode", so toggle would be friction without benefit.
- **Alternatives rejected**:
  - Toggle plugin (start OFF) — rejected: misses the by-default benefit; the user would need to remember `claude plugin enable caveman@caveman` per session, which negates the auto-compression value.
  - `--minimal` install (plugin only) — rejected: loses the standalone stats badge that surfaces token-saving telemetry.
  - `--all` install (adds per-repo `caveman-rules.md` etc. into `$PWD`) — rejected: would litter THIS config repo (the cwd at install time) with rule files meant for project repos. Let users opt in per-repo when they want it.
  - Auto-register `caveman-shrink` MCP — rejected: the proxy errors with "missing upstream command" without an upstream MCP to wrap, fails health checks. Print a snippet instead and let the user pick which upstream they want compressed (filesystem, github, …).
- **Caveats**:
  - Caveman's `hooks/install.sh` writes absolute paths (`$HOME/.claude/hooks/caveman-*.js`) into `settings.json`. Since `settings.json` is symlinked into the repo, the absolute path would commit a username. STEP 5.5 runs a Python post-process to rewrite to portable `~/.claude/hooks/...` form (bash expands `~` before passing to `node`).
  - Caveman's hook files materialize in `hooks/` (the repo dir, not `~/.claude/hooks/`) because the latter is a symlink. They're added to `.gitignore` to prevent accidental commit of user-scope state.
- **Reference**: install-plugins.sh STEP 5.5, lib/detect-plugins.sh `detect_caveman*` + `plugin_enabled`, doctor.sh caveman block, commit `9b20b84`.

## BDR-007 — Skill profiles partition gstack by usage (design / dev / qa / audit / minimal)

- **Date**: 2026-05-04
- **Status**: accepted
- **Decision**: ship `lib/profile.sh` + `lib/profiles/*.profile` to give the user fine-grained, task-shaped activation of skills. A profile is a plain-text file listing skill names + types (`gstack`, `external`, `personal`, `plugin`, `mcp`). `profile set <name>` enables the listed skills and disables every gstack-origin skill not in the profile, by moving symlinks between `skills/` and `skills-disabled/`. `profile reset` re-enables all of gstack. Plugin/MCP entries are advisory — script prints the manual `claude plugin enable` / `claude mcp add` command but never runs it. Surface area: one CLI (`bash lib/profile.sh`), one slash command (`/profile`), four Makefile targets, and a section in `agents/plugin-advisor.md`.
- **Why**: when the user works on a focused kind of task (design only, qa only, audit only) the full gstack (~38 skills) injects irrelevant skill descriptions into every session. The existing `lib/toggle-external.sh enable|disable gstack` is too coarse — it disables the whole gstack including infrastructure skills the user does want (checkpoint, ship, learn). Profiles give the user a curated middle ground: keep the gstack repo installed, hide the skills not relevant to this session.
- **Alternatives rejected**:
  - Fork SKILL.md files to strip the ~70-line gstack preamble — rejected: every gstack upgrade would need to re-fork, and the preamble already degrades gracefully (`|| true`) when `gstack/bin/` is unavailable. Hiding the skill is cheaper than rewriting it.
  - Per-skill toggle via `claude plugin enable/disable` — rejected: gstack skills are not marketplace plugins, they're symlinks owned by `skills-external/gstack/`. The CLI doesn't reach them.
  - Disable via removing symlinks (rm + recreate on enable) — rejected: lossy if the user has local edits, and re-creation requires running gstack's own setup. Move-based toggle preserves the symlink intact.
  - Auto-toggle plugins (`ui-ux-pro-max`) and MCPs as part of `set` — rejected: those affect global Claude Code state and may carry API keys (magic). Keep them advisory; user runs the CLI command knowingly.
  - Build a giant `gstack-profile` CLI that wraps `gstack/bin/*` directly — rejected: scope creep into gstack internals. The repo already has its own toggle infra (`lib/toggle-external.sh`); profile.sh sits alongside it as a finer tool.
- **Caveats**:
  - Profiles do NOT change `gstack/bin/` infrastructure — preamble in disabled skills still references it, and re-enabling restores normal behavior. No telemetry/learnings data is touched.
  - `cmd_set` only auto-disables skills returned by `gstack_skills()` (those with a `SKILL.md` under `skills-external/gstack/*/`). Personal skills (real dirs in `skills/`) are never auto-disabled by `set` — only added back if listed in the profile.
  - `cmd_current` returns "full" when nothing has been disabled, even if a profile happens to be 100% covered by the current state. The active-profile heuristic requires at least one `gstack__*` entry in `skills-disabled/` so we don't lie about a profile being "set" when no `set` ever ran.
  - Personal skills use `external`-style move (no `gstack__` prefix) so name-collision with gstack skills can't happen during disable.
- **Reference**: `lib/profile.sh`, `lib/profiles/{design,dev,qa,audit,minimal}.profile`, `skills/profile/SKILL.md`, `agents/plugin-advisor.md` (DETECT block + TOGGLING EXTERNAL TOOLS section), `Makefile` targets `profile*`, `lib/toggle-external.sh` header pointer.

## BDR-008 — Profile system v2: extend to plugins + MCPs + CLIs (web/seo/web-full/backend)

- **Date**: 2026-05-04
- **Status**: accepted
- **Decision**: extend `profile.sh` to actually toggle Claude plugins (`claude plugin enable|disable <name>@<marketplace>`) and MCP servers (delegated to `lib/toggle-external.sh` for the `magic` MCP, advisory for others), and add CLI status reporting. New profile syntax uses `plugin@<marketplace>` so the script knows where to enable from. New profiles shipped: `web` (frontend website), `seo` (SEO/GEO/W3C audit), `web-full` (web + seo combined), `backend` (API/system dev — no design, no SEO). Reverted v1 decision (BDR-007 alternative #4 "advisory only for plugins/MCPs"): user explicitly asked for actual toggling so `set web` actively enables `ui-ux-pro-max` + `magic` and `set seo` actively disables `ui-ux-pro-max`. Always-on plugins (`caveman`, `security-guidance`, `superpowers`) are protected by both an allowlist (`MANAGED_PLUGINS`) and a denylist (`PROTECTED_PLUGINS`).
- **Why**: v1 profiles only managed skills (symlink toggle). User feedback: "active TOUT le splugins necessaire pour tel profile et desactive les autre". Pure-skill toggling left ui-ux-pro-max/magic always loaded regardless of profile, so passive token cost didn't drop as much as expected when switching to a non-design profile. Auto-toggling plugins shifts the design from "show me the right skills" to "set up the right session" — closer to what the user actually wants.
- **Alternatives rejected**:
  - Keep plugins advisory + add a `--apply-plugins` flag — rejected: user would have to type the flag every time, defeating the "switch profile to switch context" workflow.
  - Disable ALL non-listed plugins (including third-party user-installed ones) — rejected: too aggressive. Profile system has no business touching plugins the user installed for their own reasons. Solution: explicit `MANAGED_PLUGINS` allowlist (currently 3 entries) — the script touches only those.
  - Treat MCPs identically to plugins (auto-toggle any MCP) — rejected: MCPs typically need env vars / API keys / specific commands. Auto-registering with wrong config produces broken MCPs (LRN-006). Compromise: auto-toggle ONLY `magic` because we already have its config in `lib/toggle-external.sh`. Other MCPs stay advisory.
  - Track plugin state across `set/reset` cycles and restore on reset — rejected: complexity not worth it. `reset` re-enables gstack skills only. To re-enable a managed plugin, the user runs `apply <profile>` or the explicit `claude plugin enable` command. Documented in the `info` line printed at the end of `reset`.
- **Caveats**:
  - `MANAGED_PLUGINS` is hardcoded — adding a new toggle-managed plugin requires editing `profile.sh`. Acceptable for now (3 entries, rarely changes); revisit if it grows.
  - `claude plugin enable` returns success even for already-enabled plugins, so the parser greps for "enabled|already" in stdout/stderr. Works on the current Claude CLI; brittle if the CLI rewords its messages. Acceptable risk.
  - The `current` heuristic now counts `installed` (CLI status) as available. Without that, profiles listing CLIs would never reach 100% match. Tiebreaker: when two profiles tie on %, the larger total wins (web-full > web > design when all are 100%).
  - `cmd_show` widened the TYPE column to 30 chars to fit `plugin@ui-ux-pro-max-skill` without breaking alignment.
  - `mcp magic` toggle delegates to `lib/toggle-external.sh enable magic` which requires `MAGIC_API_KEY` in `.env`. If the key is missing, profile.sh prints an info line and continues — the rest of the profile still applies.
- **Reference**: `lib/profile.sh` (`MANAGED_PLUGINS`/`PROTECTED_PLUGINS` arrays, `skill_status` plugin@/cli/mcp branches, `enable_skill`/`disable_skill` plugin@ + mcp branches, `cmd_set` plugin disable loop, `cmd_current` available-counting), `lib/profiles/{web,seo,web-full,backend}.profile`, refined `lib/profiles/{design,dev,qa,audit}.profile` (use `plugin@<marketplace>` syntax + `cli` entries), `skills/profile/SKILL.md` (updated profile table + mechanism table), `agents/plugin-advisor.md` (extended profile recommendation table).
