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

<!-- Append entries below. Template:

## BLK-XXX - <friction>

- **Date** : YYYY-MM-DD
- **Friction** : <ce qui était bloqué>
- **Cause réelle** : <cause racine>
- **Solution** : <workaround ou fix>
- **Statut** : open | resolved | upstream

-->
