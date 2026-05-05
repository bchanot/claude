---
type: journal
schema:
  entry: one date heading per working session
  body: 3-5 lines max - what was done, decided, blocked
rules:
  - One heading per date (YYYY-MM-DD), not per session.
  - Append at end. Never edit past entries.
  - Keep terse. Details belong in decisions/learnings/blockers - timeline only.
---

# Journal

## 2026-04-23

- Restructured tree: `tasks/` → `.claude/tasks/`, created `.claude/memory/` (5 registries) + `.claude/audits/`.
- Adapted CLAUDE.md + skills `onboard`, `init-project` + agent `onboarder` + `lib/project-archetypes/dotfiles-meta.md`.
- Added CAPITALIZE step in `ship-feature`, `bugfix`, `hotfix`, `feat`, `commit-change` + created `/close` skill for session-end ritual.
- 2nd user verify-gate caught bugs: `.gitignore` broke tracking (fixed BDR-003); harden/validate dispatcher bash broken after audit move (LRN-002).
- Audits routed to `.claude/audits/` (seo/geo/harden/validate/code-clean) + `MIGRATION.md` written for existing projects.
- 9 atomic commits (`c721a36..a9606aa`) via `/commit-change` — first real exec of Phase 4 CAPITALIZE.
- Decisions logged: BDR-002, BDR-003. Learnings: LRN-002. Blockers: BLK-002.
- English-only rule enforced in all CAPITALIZE specs (commit `bfcca72`); 9 existing entries retrofitted to English in follow-up commit.

## 2026-04-27

- Settings: switched `permissions.defaultMode` from `"default"` to `"auto"` and dropped `disableAutoMode: "disable"` (BDR-004); reorganised top-level keys + added `effortLevel: "xhigh"`; removed stale root `TODO.md` (already migrated to `.claude/tasks/TODO.md`).
- Learning: Claude Code `disable*` settings use sentinel string `"disable"`, not boolean (LRN-003).
- 3 atomic commits (`f7f033f..1421578`) via `/commit-change`.
- Animation lib autoflow added: new helper `lib/animation-lib-check.sh` + STEP 5e in `/init-project` (auto-install) + STEP 2.5 in `/onboard` (opt-in) + read-only detection in `plugin-advisor` PHASE 1/2/3 + signal in `lib/design-gate.md` + scaffolder note. `motion` chosen over legacy `framer-motion` (BDR-005, LRN-004).

## 2026-05-03

- Added `JuliusBrussee/caveman` as 4th always-on plugin (BDR-006). Full install: plugin + standalone hooks + caveman-shrink MCP scaffold (snippet only, not auto-registered — proxy needs upstream wrapper, LRN-006).
- Discovered two co-masking bugs: `claude plugin install` doesn't enable (LRN-005) + `session-start.sh` hardcoded "✅ ON: security-guidance rtk superpowers" regardless of actual state. Added `enable_plugin()` helper + `plugin_enabled()` detector reading `enabledPlugins` from `settings.json`. Banner now reflects reality.
- Side fix: doctor.sh exited under `set -euo pipefail` when gstack/skills/ missing — wrapped find in brace + `|| true`.
- 3 atomic commits (`0184818..2ec7935`).

## 2026-05-04

- Built skill profile system (BDR-007): `lib/profile.sh` + `lib/profiles/{design,dev,qa,audit,minimal}.profile` partition gstack + personal skills by purpose. Activation toggles symlinks `skills/` ↔ `skills-disabled/`.
- Wired into `agents/plugin-advisor.md` (DETECT call to `profile.sh current` + new `PROFILE` line in OUTPUT + new "Skill profiles" subsection in TOGGLING EXTERNAL TOOLS), `lib/toggle-external.sh` (header pointer), `Makefile` (4 targets), `skills/profile/SKILL.md` (`/profile` slash command).
- `cmd_current` honestly reports "full" when no `gstack__*` entry exists in `skills-disabled/` — avoids "100% match" trap when full gstack on.
- Tested end-to-end: list/show/current/diff/set/reset/apply all green; shellcheck clean; symlink state restored after reset.
- Profile system v2 (BDR-008): extended `profile.sh` to toggle Claude plugins (`claude plugin enable|disable`) + MCP servers (`magic` via `lib/toggle-external.sh`). Added 4 new profiles: `web`, `seo`, `web-full`, `backend`. Refined existing profiles to use `plugin@<marketplace>` syntax + `cli` entries. Always-on plugins protected by `MANAGED_PLUGINS` allowlist + `PROTECTED_PLUGINS` denylist.
- Verified: `set web` enables ui-ux-pro-max + magic; `set seo` disables ui-ux-pro-max; `set minimal` disables ui-ux-pro-max but spares caveman/security-guidance/superpowers. `current` heuristic respects ties (web-full beats web at 100%).

## 2026-05-05

- Mandated caveman format on all `.claude/memory/*.md` writes (BDR-009). Rule added to CLAUDE.md "Memory registries" section. Self-applied: CLAUDE.md prose compressed in same pass.
- Compressed 5 existing registries via `/caveman:compress` (decisions, learnings, blockers, journal, evals) — ~40% input-token reduction per session-start load.
- Side chores: disabled `example-skills@anthropic-agent-skills` plugin in settings.json; gitignored `*.original.md` compress backups (recoverable via git history).
- 4 atomic commits (`0275eed..639486a`) via `/commit-change`.