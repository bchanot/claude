# decisions-snapshot — frozen fixture for run-reconcile.sh T3/T5 (SPEC-10, J4-10)
# Neutral name, LRN-077 style: this is NOT the live registry. Carries exactly what
# reconcile_deferrals / reconcile_contradiction_candidates scan against
# fixtures/todo-snapshot.md, so the suite never reds just because the live
# decisions.md gets legitimately pruned or reworded.

## BDR-900 — Uniform --help helper via session-start hook (option C)
- **Decision**: every skill expose `--help` via a shared snippet injected by a
  hook, not a duplicate helper per SKILL.md.
- **Status**: accepted · won't-build — measured non-rentable, see the linked
  TODO chantier (the intended behavior was already spontaneous).
- **Follow-up**: OUT-OF-SCOPE for now; reconsider only if a new skill class
  demonstrably needs a diverging `--help` shape.

## BDR-901 — rename-note follow-up
- Bigger picture: looks like a deliberate rename to disambiguate two
  same-named things. Could be a planned migration that stalled. Worth a
  one-line ticket separate from the main chantier.

## BDR-902 — deferred cleanup
- DEFERRED until the next audit pass; not actionable now.
