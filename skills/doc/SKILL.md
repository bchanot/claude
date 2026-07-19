---
name: doc
description: |
  Use when documentation may be out of sync with code — features
  added/removed vs README / INSTALL / DEPLOY / CHANGELOG. Stack-aware
  audit, cross-references git history, patches approved items.
  Triggers: "doc", "sync docs", "update readme", "documentation drift",
  "stale docs", "docs à jour ?", "create README", "should I have a
  DEPLOY doc".
argument-hint: [leave empty for full audit, or list specific files/docs to check]
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
---

Run the two-mode doc pipeline (BDR-077 — audit judgment on opus, patch on
the sonnet pin, the validation gate in THIS loop; a dispatched agent cannot
hold a gate):

1. AUDIT — dispatch:
   `Agent(subagent_type="doc-syncer", model="opus")`
   prompt: "MODE: audit. Audit public docs for this project. Context from
   the user: $ARGUMENTS. Emit the DOC SYNC REPORT + PATCH PLAN — no writes."

2. GATE — present the report and run the DOC SYNC — VALIDATION GATE from
   the agent's DISPATCHER PROTOCOL (AUTO yes/select/cancel; HUMAN, CREATE,
   CLEAN per-item; README CREATE has no skip). Wait for explicit approval.
   `DOC SYNC: all docs current` → stop here.

3. PATCH — re-dispatch:
   `Agent(subagent_type="doc-syncer")` (sonnet pin)
   prompt: "MODE: patch." + the APPROVED PATCH PLAN verbatim (approved item
   lines + rendered drafts for approved CREATE items). A `SHAPE ESCALATION`
   in its report → re-gate the named set here, then re-dispatch patch with
   the kept subset.

4. COMMIT — from THIS loop per `$HOME/.claude/lib/doc-commit.md` (surgical:
   only the report's `PATCHED_FILES`, summary composed from its
   `CHANGE SUMMARY` block, never `.claude/`/`CLAUDE.md`, no-op if nothing
   patched).
