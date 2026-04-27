---
type: journal
schema:
  entry: one date heading per working session
  body: 3-5 lines max - what was done, decided, blocked
rules:
  - One heading per date (YYYY-MM-DD), not per session.
  - Append at the end. Never edit past entries.
  - Keep it terse. Details belong in decisions/learnings/blockers - this is a timeline only.
---

# Journal

## 2026-04-23

- Restructured tree: `tasks/` → `.claude/tasks/`, created `.claude/memory/` (5 registries) + `.claude/audits/`.
- Adapted CLAUDE.md + skills `onboard`, `init-project` + agent `onboarder` + `lib/project-archetypes/dotfiles-meta.md`.
- Added CAPITALIZE step in `ship-feature`, `bugfix`, `hotfix`, `feat`, `commit-change` + created `/close` skill for the session-end ritual.
- 2nd user verify-gate caught bugs: `.gitignore` was breaking tracking (fixed in BDR-003); harden/validate dispatcher bash was broken after the audit move (LRN-002).
- Audits routed to `.claude/audits/` (seo/geo/harden/validate/code-clean) + `MIGRATION.md` written for existing projects.
- 9 atomic commits (`c721a36..a9606aa`) via `/commit-change` — first real execution of Phase 4 CAPITALIZE.
- Decisions logged: BDR-002, BDR-003. Learnings: LRN-002. Blockers: BLK-002.
- English-only rule enforced in all CAPITALIZE specs (commit `bfcca72`); 9 existing entries retrofitted to English in follow-up commit.

## 2026-04-27

- Settings: switched `permissions.defaultMode` from `"default"` to `"auto"` and dropped `disableAutoMode: "disable"` (BDR-004); reorganised top-level keys and added `effortLevel: "xhigh"`; removed stale root `TODO.md` (already migrated to `.claude/tasks/TODO.md`).
- Learning: Claude Code `disable*` settings use the sentinel string `"disable"`, not a boolean (LRN-003).
- 3 atomic commits (`f7f033f..1421578`) via `/commit-change`.
- Animation lib autoflow added: new helper `lib/animation-lib-check.sh` + STEP 5e in `/init-project` (auto-install) + STEP 2.5 in `/onboard` (opt-in) + read-only detection in `plugin-advisor` PHASE 1/2/3 + signal in `lib/design-gate.md` + scaffolder note. `motion` chosen over legacy `framer-motion` (BDR-005, LRN-004).
