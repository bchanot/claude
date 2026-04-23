---
type: blockers_registry
entry_prefix: BLK
schema:
  id: BLK-XXX
  date: YYYY-MM-DD
  friction: string (what was blocked)
  real_cause: string (root cause, not symptom)
  solution: string (workaround or fix)
  status: [open | resolved | upstream]
rules:
  - Open a blocker as soon as friction > 15 min wasted. Close it with a real cause, not "moved on".
  - Link to upstream issue / PR / commit when applicable.
  - If cause is a bug in a dependency, set status upstream with a pointer to the tracker.
---

# Blockers registry (BLK)

## Index

| ID | Date | Friction | Status |
|----|------|---------|--------|
| BLK-001 | 2026-04-22 | `rtk curl` breaks JSON pipelines | upstream |

---

## BLK-001 — `rtk curl` returns compressed schema in pipes

- **Date** : 2026-04-22
- **Friction** : toute pipeline `rtk curl ... | python -c "json.load(sys.stdin)"` (ou `jq`, `awk`) échoue sans message clair.
- **Cause réelle** : `rtk curl` auto-compresse stdout indépendamment du TTY — documenté dans `.claude/tasks/rtk-upstream-issue.md`.
- **Solution** :
  - Workaround court terme : `exclude_commands=["curl"]` dans `~/.config/rtk/config.toml`.
  - Workaround alternatif : utiliser `rtk proxy`.
  - Fix upstream : issue reportée, voir `.claude/tasks/rtk-upstream-issue.md`.
- **Statut** : upstream (bug chez `rtk`, workaround appliqué).
