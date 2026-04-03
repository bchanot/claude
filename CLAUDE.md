# Global coding preferences

Apply these preferences across all projects unless repository-specific
instructions override them.

## General philosophy

I prefer clean, readable, maintainable code with strong structural discipline,
inspired by 42-style constraints but adapted pragmatically to each language,
framework, and project.

These rules are important, but they are not absolute dogma:
- apply them by default
- report clearly when code does not follow them
- if a deviation is justified, keep it and explain why
- if a deviation is not clearly justified, ask whether it should be kept or fixed

## Design principles

- Prefer simple, readable, maintainable code over clever or overly compact code.
- Each function, method, or equivalent unit should have one clear responsibility.
- Preserve existing behavior unless explicitly asked to change it.
- Avoid unrelated changes during a fix or refactor.
- Keep modifications scoped and intentional.

## Function and method size

- Prefer keeping the core logic of a function or method within 25 useful lines.
- Empty lines do not count toward this limit.
- Multi-line wrapped statements count as one logical instruction for this rule.
- Error handling may extend the total size when necessary, but the main logic
  should remain compact and easy to understand.
- If a unit becomes too large, split it into small helpers.
- Use private/internal/file-local helpers when the language supports them.

## Line length

- Prefer a maximum of 80 characters per line when reasonably possible.
- If a line is too long, split it cleanly for readability.
- Long calls, conditions, and expressions should be formatted clearly.

## Parameters

- Prefer no more than 5 parameters per function or method.
- If more inputs are needed, group them into a meaningful structure adapted
  to the language, such as an object, record, struct, dataclass, DTO,
  config object, or equivalent.

## Local variables

- Prefer no more than 5 local variables per function or method.
- If more local state is needed, consider:
  - splitting the logic
  - extracting a helper
  - introducing a dedicated small structure adapted to the language

## Shared and global state

- Global state is discouraged.
- Prefer explicit data flow through parameters, return values, objects,
  context structures, dependency injection, or another justified mechanism.
- If shared or global state is used, mention it explicitly and justify it.

## Comments and documentation

- Functions and methods should be documented when their purpose, parameters,
  return value, or intent are not immediately obvious.
- The comment should help explain intent and usage, not restate the code line by line.
- Apply the documentation style that fits the language and project conventions
  (docstring, block comment, JSDoc, Doxygen, XML docs, etc.).
- Internal/private helpers are not exempt if their role is unclear.

## Readability

- Use explicit, consistent, and meaningful names.
- Prefer straightforward control flow.
- Simplify or extract complex conditions.
- Avoid hidden side effects unless clearly necessary.
- Prefer code that is easy to review, test, and modify.

## Refactoring and modifications

- During refactoring, prioritize:
  1. safety
  2. readability
  3. consistency with the project
- Keep behavior unchanged unless explicitly asked otherwise.
- After modifying a function, feature, or behavior, verify that no residue from
  the previous implementation remains.
- Remove obsolete code, dead branches, unused helpers, stale flags, outdated
  comments, legacy conditions, and old-version leftovers when they are no longer needed.
- If something from the previous implementation is intentionally retained,
  explain why.

## Handling deviations from the standard

- Treat these rules as strong preferences, not rigid mechanical laws.
- If existing code is outside the standard, report it clearly.
- If the deviation is minor and acceptable, mention it briefly.
- If the deviation is significant and not obviously justified, ask whether to:
  - keep the deviation
  - or refactor toward compliance
- If a deviation is clearly justified by language constraints, framework style,
  performance needs, safety requirements, or project architecture, keep it and explain it.

## Language adaptation

- Adapt these rules to the language and ecosystem instead of applying C/C++
  terminology blindly.
- Interpret "function" broadly as the relevant unit of logic:
  function, method, procedure, hook, handler, endpoint, callback, class method, etc.
- Interpret "structure" broadly as any suitable grouping construct:
  struct, object, class, record, dataclass, DTO, tuple wrapper, options object,
  config object, context object, or equivalent.

## Expected workflow after code changes

After making changes, when applicable:
1. run relevant tests
2. run lint, format, build, and type-check steps if available
3. report what was verified
4. report what could not be verified
5. summarize remaining risks or uncertainties
6. mention any remaining deviation from these preferences
7. confirm whether old implementation residue remains or has been removed

## Interaction preferences

When working on code:
- first analyze before changing
- explain the plan briefly
- keep changes minimal unless a broader refactor is requested
- mention trade-offs clearly
- after changes, summarize what was done and what remains uncertain

## STRICT MODE

These rules are always active in orchestrator skills (/init-project,
/ship-feature) and during code review. They apply automatically.

These rules override all other instructions.

- Never skip workflow steps
- Never merge agent responsibilities
- Always enforce user validation before implementation
- Always run review loop until no CRITICAL issues remain
- Stop execution if requirements are unclear

## FAIL FAST MODE

These rules are always active in every interaction. They apply automatically.

These rules override all other instructions.

- Stop immediately if requirements are unclear
- Ask clarifying questions instead of guessing
- Do not invent missing context
- Do not proceed with partial understanding
- Explicitly list unknowns before continuing