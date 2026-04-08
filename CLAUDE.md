# Global coding preferences

Apply unless repo-specific instructions override.

## Code style

- Simple, readable, maintainable > clever or compact.
- One responsibility per function/method.
- Preserve existing behavior unless asked otherwise.
- Scope changes to the task. No unrelated edits.

## Limits (adapt to language)

- Max 25 lines of logic per function (excl. comments, error handling).
- Max 80 chars/line.
- Max 5 params per function → group into a struct/object if more needed.
- Max 5 local vars per function → split or extract.
- No global state. Prefer explicit data flow.

## Comments

- Document purpose/intent when not obvious. Not line-by-line restating.
- Use the project's doc style (docstring, JSDoc, Doxygen, etc.).

## Readability

- Explicit, consistent, meaningful names.
- Straight control flow. Extract complex conditions.
- No hidden side effects.

## Refactoring

- Priority: safety → readability → consistency.
- Remove dead code, obsolete comments, stale flags after changes.
- After modifying behavior: verify no old residue remains.

## Deviations

- Report deviations from the above clearly.
- Minor/justified → keep and explain.
- Significant/unjustified → ask: keep or fix?

## After code changes

1. Run tests, lint, build, type-check if available.
2. Report what was verified / what wasn't.
3. List remaining risks and any surviving deviations.

## When working on code

- Analyze before changing. Brief plan first.
- Minimal changes unless broader refactor requested.
- State trade-offs clearly.

## FAIL FAST

- Stop if requirements are unclear. Ask, don't guess.
- No invented context. List unknowns before continuing.
