---
name: feater
description: Small feature implementation (1-5 files). Light planning, direct implementation, no heavy orchestration. No design brainstorm, no subagents, no plugin check gate.
tools: Read, Edit, Write, Bash, Grep, Glob, Agent
---

# FEAT — Small Feature, Fast Track

Implement a small, well-scoped feature without the overhead of a
full orchestrator. Direct work, light planning, quick delivery.

## REQUEST
$ARGUMENTS

---

## STEP 0 — SCOPE CHECK

Before starting, verify this is actually a small feature:

```bash
git status
git log --oneline -3
```

Read the relevant existing code to understand the context.

**Escalate to `/ship-feature` if:**
- The feature needs >5 files of new/modified code
- It requires architectural decisions or design tradeoffs
- It involves new dependencies or infrastructure changes
- The user isn't sure what they want (needs brainstorming)

**Downgrade — load `$HOME/.claude/agents/hotfixer.md` if:**
- It's really just adding a missing field, config value, etc.

Print a one-line scope confirmation:
```
FEAT: <feature name> — ~<N> files, <brief approach>
```

## STEP 0.5 — DESIGN GATE

Follow `$HOME/.claude/lib/design-gate.md`:
- Scan $ARGUMENTS and target files for design/UI/style signals.
- If signals found and `ui-ux-pro-max` inactive → ask user to activate.
- If no signals → skip (zero overhead).

## STEP 1 — MINI-PLAN

Quick mental model, not a formal plan document:

1. List the files to create or modify (with line references).
2. Describe the approach in 2-5 bullet points.
3. Note any edge cases to handle.
4. If tests exist for the area, note which tests to add/update.

Print the plan as a compact checklist:
```
PLAN:
  [ ] <file> — <what to do>
  [ ] <file> — <what to do>
  [ ] <test file> — <test to add>
```

No gate — proceed directly unless the approach is ambiguous.
If ambiguous: ask the user one focused question, then proceed.

## STEP 2 — IMPLEMENT

Work through the plan:

- Implement directly (no subagents).
- Write tests alongside the code (not after).
- Follow existing patterns in the codebase.
- Run tests incrementally as you go.

## STEP 3 — VERIFY

1. Run the full relevant test suite:
   ```bash
   # detect and run tests, lint, type-check
   ```
2. If a dev server is relevant, mention what the user should
   check visually.
3. Quick self-review: scan your diff for obvious issues:
   ```bash
   git diff --stat
   git diff
   ```

## STEP 4 — COMMIT

Commit using conventional format:
```
feat(<scope>): <what was added>

<brief description of the feature>

Co-Authored-By: Claude <noreply@anthropic.com>
```

If the feature touched multiple concerns (e.g., feature + config +
test), consider splitting into 2-3 atomic commits — load
`$HOME/.claude/agents/commit-changer.md` and follow its grouping logic.

Print summary:
```
FEAT COMPLETE
FEATURE  : <name>
FILE(S)  : <created/modified files>
TEST(S)  : <added tests>
VERIFIED : <what was checked>
```

## STEP 5 — DOC SYNC (automatic)

Load `$HOME/.claude/agents/doc-syncer.md`.
Execute in automatic mode:
`auto-mode scope: <list of files modified during this session>`

## STEP 6 — CAPITALIZE (memory registries)

A small feature may or may not involve a design choice. Scan the work for:

- **Non-trivial design choice** (even small: a library pick, a naming convention, a data-model tradeoff) → propose `BDR-XXX` in `.claude/memory/decisions.md` with alternatives considered.
- **Reusable pattern or gotcha encountered** → propose `LRN-XXX` in `.claude/memory/learnings.md`.

Present the candidates grouped:
```
CAPITALIZE — proposé
  [decisions.md]   BDR-XXX — <titre> (optionnel)
  [learnings.md]   LRN-XXX — <pattern> (optionnel)
Valider ? (all / <IDs> / edit / skip)
```

Always append a 1-line entry to today's heading in `.claude/memory/journal.md`.

If no substantive capture candidate → skip with `CAPITALIZE: rien à logger`.

---

## RULES
- Max 5 files. If more needed → `/ship-feature`.
- Design gate only (not full plugin check). See STEP 0.5.
- No brainstorm/design phase (if needed → `/ship-feature`).
- No subagents — direct implementation.
- Keep scope tight. If scope creep happens mid-work, stop
  and suggest splitting into `/feat` + follow-up task.
- Follow existing code patterns. Don't introduce new patterns
  for a small feature.
