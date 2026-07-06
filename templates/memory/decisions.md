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
  - Entries in English, caveman format (BDR-009): drop articles + filler, fragments OK, technical terms exact.
---

# Decisions registry (BDR)

## Index

| ID | Date | Title | Status |
|----|------|-------|--------|

<!-- Append entries below. Template:

## BDR-XXX - <title>

- **Date**: YYYY-MM-DD
- **Status**: proposed | accepted | deprecated | superseded
- **Decision**: <what was chosen>
- **Why**: <motivation>
- **Rejected alternatives**:
  - Option A - <why rejected>
  - Option B - <why rejected>
- **Reference**: <commit / PR / file>

-->
