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

### Decision rules (apply in order — first match wins)

| Rule | Trigger | Action |
|---|---|---|
| 1 | Estimated diff < 2 files AND no logic (config value, copy fix, missing field) | DOWNGRADE → load `$HOME/.claude/agents/hotfixer.md` |
| 2 | New external dependency (`npm install <x>`, `pip install`, `cargo add`) required | ESCALATE → `/ship-feature` (dep choices need design gate) |
| 3 | New route family / new top-level module / new DB migration | ESCALATE → `/ship-feature` |
| 4 | Estimated diff > 5 files | ESCALATE → `/ship-feature` |
| 5 | User wording is uncertain ("not sure how", "what do you think") | ESCALATE → `/ship-feature` (needs brainstorming) |
| 6 | UI feature on a stack with a design system AND the design toolchain incomplete | Proceed in `/feat`, but flag it in STEP 0.5 design gate |
| 7 | Otherwise | PROCEED in `/feat` |

### Worked examples

- "Add `/health` endpoint returning `{status:"ok",version}`" → 1-2 files, no new dep, route added to existing router → **PROCEED**.
- "Add a dark-mode toggle bound to `prefers-color-scheme`" → 2-3 files, design system exists → **PROCEED** (design gate triggers in STEP 0.5).
- "Add OAuth login (Google + GitHub providers)" → new deps, new routes, secrets handling → **ESCALATE** to `/ship-feature`.
- "Show a 'New' badge on items created this week" → 1-2 files, pure UI predicate → **PROCEED**.
- "Fix copy: 'Sign In' → 'Sign in'" in 1 file → **DOWNGRADE** to `/hotfix`.

Print a one-line scope confirmation (use the rule that fired):
```
FEAT: <feature name> — rule <N>, ~<N> files, <brief approach>
```

## STEP 0.5 — DESIGN GATE

Follow `$HOME/.claude/lib/design-gate.md`:
- Scan $ARGUMENTS and target files for design/UI/style signals.
- If signals found → run `design-tool-gate.sh`; if it reports INCOMPLETE,
  tell the user to run `/profile design` before proceeding.
- If no signals → skip (zero overhead).

## STEP 0.6 — MEMORY READ-BEFORE (decisions-first)

Run the scan per `$HOME/.claude/lib/analyze-before-plan.md`, decisions-weighted: a BDR may
already constrain or forbid the approach; an LRN may name a gotcha to apply. Emit RELATED
MEMORY; feed STEP 1 MINI-PLAN. Inline consumption — reader = planner, no injection.
`.claude/memory/` absent → guarded no-op (zero overhead on a memory-less repo).

## STEP 1 — MINI-PLAN

Quick mental model, not a formal plan document:

1. List the files to create or modify (with line references).
2. Describe the approach in 2-5 bullet points.
3. Note any edge cases to handle.
4. If tests exist for the area, note which tests to add/update.
5. Disposition (from STEP 0.6): name each in-force BDR/LRN this plan honors
   (`honors BDR-xxx by …`), or state `no in-force decision constrains this feature`.
   A plan with neither = read-then-ignore; the disposition must surface as a trace.

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

**Then commit the docs** — follow `$HOME/.claude/lib/doc-commit.md`: it surgically commits
ONLY the files doc-syncer patched (its `PATCHED_FILES` output), never `git add -A`, never
`.claude/`/`CLAUDE.md` (rc 4 = a loud BDR-022 anomaly, not a silent skip), and no-ops when
nothing was patched — the common case for a trivial change. No FINISH in an inline flow, so
it just commits the docs on the current branch (no ordering concern).

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

**Language rule**: written entries are ALWAYS in English (see CLAUDE.md "Memory registries" § Language). The interactive gate may mirror the user's language; the appended entries must not.

If no substantive capture candidate → skip with `CAPITALIZE: nothing to log`.

**Then commit the memory** — follow `$HOME/.claude/lib/capitalize-commit.md`: it
surgically commits what capitalize just wrote (`.claude/memory` + `.claude/tasks`
only, never `git add -A`) as one `chore(memory)` commit, reports the memory-commit
hash, and no-ops if nothing was written.

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
