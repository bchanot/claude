---
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
  - Replaces the previous LESSONS.md format. Old file was empty - no content to migrate.
---

# Learnings registry (LRN)

## Index

| ID | Date | Pattern | Applies to |
|----|------|---------|------------|
| LRN-001 | 2026-04-22 | `rtk` shape-compression breaks pipes | any pipeline chaining `rtk curl/cat/read` into `jq`, `python -c`, `awk` |
| LRN-002 | 2026-04-23 | Moving report-file paths requires grepping bash READS, not just WRITES | any refactor that moves a generated file used by a dispatcher |

---

## LRN-001 — `rtk` shape-compression silently breaks downstream parsers

- **Date**: 2026-04-22
- **Pattern**: when a tracking tool (`rtk`) intercepts stdout and returns a schematized/compressed representation instead of the raw payload, every downstream parser breaks silently — because the user (or the LLM) never sees `rtk`'s output, only the parser error.
- **Context**: `rtk curl` replaces raw JSON output with a tokenized version, regardless of TTY vs pipe. Claude Code hooks auto-rewrite `curl` → `rtk curl`, so the behavior is impossible to anticipate without knowing the hook.
- **Future application**: for any tool that auto-rewrites standard commands, explicitly verify pipe behavior. Documented workaround: `exclude_commands=["curl"]` in `~/.config/rtk/config.toml`, or `rtk proxy`. See `BLK-001`.

## LRN-002 — Moving report-file paths requires grepping bash READS, not just WRITES

- **Date**: 2026-04-23
- **Pattern**: when moving the write path of a generated file (report, artifact, cache), you must also grep the places that READ that file — not only those that write it. Dispatchers (orchestrator skills that dispatch to an agent and then parse the result) typically contain bash commands like `test -s X.md`, `grep ... X.md`, `wc -l X.md` — these refs are invisible if you only grep for "write" or "output path".
- **Context**: `.claude/audits/` refactor (commit `5c5e82c`). First pass: I updated write paths across 5 skills (seo/geo/harden/validate/code-clean) and 3 agents. The user asked for a verify-gate. They re-grepped and found 10+ bare bash refs (e.g. `test -s HARDEN.md`, `grep -oE ... VALIDATE.md`) I had missed — the dispatchers were broken (looking at project root while the agent was writing to `.claude/audits/`). Fixed in commit `5c5e82c` (bundled with the same commit).
- **Future application**:
  - Before declaring a file-path migration "complete", grep the **basename** (`grep -rn "HARDEN\.md"`) in addition to the full path — to catch bare bash usages.
  - If the file is used in pipelines (`test`, `grep`, `wc`, `cat`, `head`), search for those verbs explicitly.
  - **Verify-gates save work**: one extra round asked by the user forced exhaustive re-grepping. Without it, two dispatchers would have shipped broken.
