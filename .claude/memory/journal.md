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

- Restructuré l'arborescence : `tasks/` → `.claude/tasks/`, créé `.claude/memory/` (5 registres) + `.claude/audits/`.
- Adapté CLAUDE.md + skills `onboard`, `init-project` + agent `onboarder` + `lib/project-archetypes/dotfiles-meta.md`.
- Ajouté un step CAPITALIZE dans `ship-feature`, `bugfix`, `hotfix`, `feat`, `commit-change` + créé skill `/close` pour rituel de fin de session.
- 2e verify-gate user → bugs catchés : `.gitignore` cassait le tracking (fixé BDR-003), dispatchers bash harden/validate cassés après le move audit (LRN-002).
- Audits routés vers `.claude/audits/` (seo/geo/harden/validate/code-clean) + `MIGRATION.md` écrit pour projets existants.
- 9 commits atomiques (`c721a36..a9606aa`) via `/commit-change` — première exécution réelle de la Phase 4 CAPITALIZE.
- Décisions actées : BDR-002, BDR-003. Learnings : LRN-002. Blockers : BLK-002.
