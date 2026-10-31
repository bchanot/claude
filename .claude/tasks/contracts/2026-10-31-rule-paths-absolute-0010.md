# CONTRACT — rule-paths-absolute

## REQUEST (verbatim — IMMUTABLE)
Two relative rule paths beside absolute ones: agents/interviewer.md:27 and skills/guardrails/SKILL.md:10-11 cite `rules/secure-by-default.md`, `rules/supabase.md`, `rules/cloud-functions.md`, `rules/a11y.md` while the same files use `~/.claude/lib/…` absolute paths; a reader in a project repo resolves `rules/` against that project. Make them `~/.claude/rules/<name>.md` (TODO phase 1 minor).

## CLARIFICATIONS
none (hotfix autofill)

## ACCEPTANCE CRITERIA
1. Symptom gone: no bare `rules/<name>.md` path left in the two files; each now reads `~/.claude/rules/<name>.md`.
   CHECK: cd /home/bchanot/Documents/claude && ! grep -nE '(^|[^/~.a-z])rules/[a-z0-9-]+\.md' agents/interviewer.md skills/guardrails/SKILL.md && grep -q '~/.claude/rules/supabase.md' agents/interviewer.md && grep -q '~/.claude/rules/supabase.md' skills/guardrails/SKILL.md && echo PATHS-OK
   EXPECT: PATHS-OK
   EVIDENCE: pending
2. Build/tests green: `make test` suites touching these files (routing, citers) pass.

## FILE SCOPE
- agents/interviewer.md
- skills/guardrails/SKILL.md
