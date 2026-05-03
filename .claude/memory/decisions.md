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
