# CONTRACT — dispatcher-applies

## REQUEST (verbatim — IMMUTABLE)
Agent description losses: user pick 2026-10-31 = restore "(dispatcher applies)" on geo-analyzer + seo-analyzer only; the rest closed (bodies keep it).

## CLARIFICATIONS
none (hotfix autofill)

## ACCEPTANCE CRITERIA
1. Symptom gone: both descriptions say the fix bundle is applied by the dispatcher; nothing else in the frontmatter changes.
   CHECK: cd /home/bchanot/Documents/claude && grep -q '^description: GEO audit agent.*emits a fix bundle (dispatcher applies) and a scored report' agents/geo-analyzer.md && grep -q "^description: 'Classical SEO audit agent.*Emits a fix bundle (dispatcher applies) + scored report" agents/seo-analyzer.md && [ "$(git diff develop -- agents/geo-analyzer.md agents/seo-analyzer.md | grep -c '^[-+][^-+]')" = 4 ] && echo DESC-OK
   EXPECT: DESC-OK
   EVIDENCE: pending
2. Build/tests green: agent frontmatter / routing suites pass.

## FILE SCOPE
- agents/geo-analyzer.md
- agents/seo-analyzer.md
