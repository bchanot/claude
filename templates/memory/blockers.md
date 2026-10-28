---
format: 2
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
  - Entries in English, caveman format (BDR-009): drop articles + filler, fragments OK, technical terms exact.
---

# Blockers registry (BLK)

<!-- Written only by `bash ~/.claude/lib/memory.sh add blocker --title "<friction>"
--body-file <file> [--status open]` (it allocates the ID). Entry shape:

  ## BLK-NNN — <friction> [open] (YYYY-MM-DD)
  - **Friction**: <what was blocked>
  - **Real cause**: <root cause>
  - **Solution**: <workaround or fix>

Later status: `bash ~/.claude/lib/memory.sh status BLK-NNN "resolved <hash>"`.
-->
