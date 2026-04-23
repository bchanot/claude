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

<!-- Append entries below. Template:

## BDR-XXX - <titre>

- **Date** : YYYY-MM-DD
- **Statut** : proposed | accepted | deprecated | superseded
- **Décision** : <ce qui a été choisi>
- **Pourquoi** : <motivation>
- **Alternatives rejetées** :
  - Option A - <raison du rejet>
  - Option B - <raison du rejet>
- **Référence** : <commit / PR / fichier>

-->
