---
format: 2
type: learnings_registry
entry_prefix: LRN
schema:
  id: LRN-XXX
  date: YYYY-MM-DD
  pattern: string (what was observed, abstracted)
  context: string (where/when it happened - concrete)
  future_application: string (when to recall this)
rules:
  - Capture learnings that apply beyond the current task.
  - Abstract from the incident - the pattern is what is reusable, not the one-shot fact.
  - Link to source (commit, file, PR) when possible.
  - Entries in English, caveman format (BDR-009): drop articles + filler, fragments OK, technical terms exact.
---

# Learnings registry (LRN)

<!-- Written only by `bash ~/.claude/lib/memory.sh add learning
--title "<abstract pattern>" --body-file <file>` (it allocates the ID). Entry shape:

  ## LRN-NNN — <abstract pattern> (YYYY-MM-DD)
  - **Pattern**: <what was observed, phrased for reuse>
  - **Context**: <where and when, concrete>
  - **Future application**: <when to recall this>

-->
