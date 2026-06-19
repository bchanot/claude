---
name: close
description: |
  End-of-session ritual — flush what was decided, learned, and blocked into
  `.claude/memory/`, reconcile `.claude/tasks/TODO.md`, and log a journal line.
  Alias for `/capitalize --ritual`: same dedup + TODO-reconcile + approval-gate
  pipeline, plus the explicit 3-question reflection. NOT registry curation
  (that is /prune-memory).
  Triggers: "close", "end session", "ferme la session", "session close",
  "checkpoint memory", "what did we learn", "retro rapide", "fin de journée".
argument-hint: (none — runs capitalize in ritual mode on the current conversation)
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
---

# /close — Session-close ritual (alias)

`/close` is an alias for **`/capitalize --ritual`**. All logic lives in the
**capitalize** skill — nothing is duplicated here.

Invoke the `capitalize` skill now and run it in **ritual mode**: the full
pipeline (STEP 0 precheck → STEP 1 auto-scan → STEP 2 dedup → STEP 2B TODO
reconcile → STEP 3 approval gate → STEP 4 write → STEP 5 journal → STEP 6
handoff), PLUS STEP 1B's explicit 3-question reflection (what did you decide /
learn / block).

Ritual answers are deduped like any other candidate — a dup is dropped and its
existing ID shown, not re-logged. This is the upgrade over the legacy `/close`,
which wrote ritual answers fresh with no dedup.

→ Use the Skill tool to launch `capitalize` with argument `--ritual`.
