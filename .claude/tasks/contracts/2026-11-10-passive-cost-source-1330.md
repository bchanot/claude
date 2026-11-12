# CONTRACT — passive-cost-source
- date: 2026-11-10 | flow: bugfix | branch: bugfix/passive-cost-source
- status: active

## REQUEST (verbatim — IMMUTABLE)
G2 from .claude/audits/BUGS-FOUND.md (code-clean 2026-11-09): passive-cost constants disagree. hooks/session-start.sh:177-183 (`_plugin_costs`: gstack 2750, ui-ux-pro-max 400, plugin-dev 100, context7 200, graphify 300) and agents/plugin-advisor.md:193,197,211,226,233,263 vs doctor.sh:520-526 (gstack/context7/graphify dropped 2026-09-28 as double counting, ui-ux-pro-max 670); agents/status-reporter.md:26-30 names doctor.sh's constants block as the source of truth. Fix: one source of truth for the constants (doctor.sh's block or a shared lib file both read), banner and advisor aligned to it; regression test. Mark BUGS-FOUND G2 FIXED. Note: detect_uiux_pro_max now follows the effective profile (bugfix/banner-effective-profile, a655b06). make test needs GATES_TIMEOUT=600 + PATH=$HOME/.bun/bin:$PATH (LRN-271). Foreign-code style. Advisor output vocabulary (D3) out of scope.

## CLARIFICATIONS
Q: single source of truth? / A: measured at runtime from the real skill descriptions (user, 2026-11-10) [gated]
Q: banner 💰 row (per-plan budget denominator)? / A: remove it (user, 2026-11-10) [gated]
Q: after two challenge rounds the measured-cost API proved a feature; scope? / A: split: this /bugfix removes the stale hand figures and the dead banner path (detect_plan included); the measured-cost API becomes a /ship-feature in the TODO; doctor keeps its measured 670 until then (user, 2026-11-10) [gated]
Q: binding plan? / A: .claude/tasks/plans/2026-11-10-passive-cost-source-1330.md r3 "Fix plan (r3)" (orchestrator)

## ACCEPTANCE CRITERIA
1. Symptom gone: no stale per-plugin token figure left in the banner, status-reporter or plugin-advisor (the deferred plan-budget WARN line excepted); the 💰 row and detect_plan are gone; regression cases present and green.
   CHECK: cd /home/bchanot/Documents/claude && make test suite=lib/tests/session-banner.test.sh 2>&1 | tail -1 | grep -q 'all suites green' && grep -q 'SB9' lib/tests/session-banner.test.sh && grep -q 'SB10' lib/tests/session-banner.test.sh && ! grep -qE '_plugin_costs|TOKEN_WARN|detect_plan' hooks/session-start.sh && ! grep -q 'detect_plan' lib/detect-plugins.sh && ! grep -qE '~[1-9][0-9-]*t' agents/status-reporter.md && ! grep -v 'plan budget' agents/plugin-advisor.md | grep -qE '~[1-9][0-9-]*t' && echo SYMPTOM-GONE
   EXPECT: SYMPTOM-GONE
   EVIDENCE: MET exit=0 marker-found :: SYMPTOM-GONE
2. Recursion-guard suite renamed and green without the detect_plan cases.
   CHECK: cd /home/bchanot/Documents/claude && [ ! -e lib/tests/detect-plan.test.sh ] && make test suite=lib/tests/hook-recursion-guard.test.sh 2>&1 | tail -1 | grep -q 'all suites green' && ! grep -q 'detect_plan' lib/tests/hook-recursion-guard.test.sh && echo GUARD-OK
   EXPECT: GUARD-OK
   EVIDENCE: MET exit=0 marker-found :: GUARD-OK
3. Build/tests green (full suite, GATES_TIMEOUT=600, bun on PATH); shellcheck at warning level clean on the touched shell files.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -S warning hooks/session-start.sh lib/detect-plugins.sh lib/tests/session-banner.test.sh lib/tests/hook-recursion-guard.test.sh && make test 2>&1 | tail -1 | grep -q 'all suites green' && echo GREEN
   EXPECT: GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN

## FILE SCOPE
hooks/session-start.sh, lib/detect-plugins.sh, lib/tests/detect-plan.test.sh → lib/tests/hook-recursion-guard.test.sh (git mv), agents/status-reporter.md, agents/plugin-advisor.md, lib/tests/session-banner.test.sh; bookkeeping (orchestrator): .claude/audits/BUGS-FOUND.md, .claude/tasks/TODO.md
