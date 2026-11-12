# CONTRACT — analyzer-memory-field

## REQUEST (verbatim — IMMUTABLE)
Remove the dead `memory: project` field from agents/analyzer.md (auto memory off drops it, LRN-240).

## CLARIFICATIONS
none (hotfix autofill)

## ACCEPTANCE CRITERIA
1. Symptom gone: agents/analyzer.md frontmatter has no `memory:` line; the other frontmatter keys are unchanged.
   CHECK: cd /home/bchanot/Documents/claude && ! sed -n '1,/^---$/{p}' agents/analyzer.md | sed -n '2,$p' | grep -q '^memory:' && [ "$(sed -n '2,6p' agents/analyzer.md | cut -d: -f1 | tr '\n' ' ')" = "name description tools model effort " ] && echo FIELD-OK
   EXPECT: FIELD-OK
   EVIDENCE: pending
2. Build/tests green: agent frontmatter suites pass.

## FILE SCOPE
- agents/analyzer.md
