# CONTRACT — banner-effective-profile
- date: 2026-11-10 | flow: bugfix | branch: bugfix/banner-effective-profile
- status: active

## REQUEST (verbatim — IMMUTABLE)
G1+G4 from .claude/audits/BUGS-FOUND.md (code-clean 2026-11-09). G1: hooks/session-start.sh:200-217 banner "ALWAYS ON" row + ui-ux-pro-max toggle row, and lib/detect-plugins.sh:49-52 `detect_uiux_pro_max`, read user-scope settings.json / plugin cache, not the effective profile (`bash lib/profile.sh current --plain`, BDR-134 single source of truth): a dev or minimal project shows ui-ux-pro-max on; pr-review-toolkit on in max/audit is not shown. G4: agents/status-reporter.md:35 + agents/plugin-probe.md:22-23,69 report installed (cache) or user-scope `claude plugin list` state as "active"; the per-project state is the PROFILE line (`current --plain`). Fix: per-project effective state from profile.sh in the banner rows and detection, and agents report active per the profile, installed separately. Regression test in the existing session-start / detect-plugins test suites. Mark both BUGS-FOUND entries FIXED. make test needs GATES_TIMEOUT=600 + PATH=$HOME/.bun/bin:$PATH (LRN-271). Foreign-code style (keep file style).

## CLARIFICATIONS
Q: once the ✅ ON row reads the effective profile, model-router (on in every profile) appears; show it? / A: show it (user, 2026-11-10) [gated]
Q: regression test location ("existing session-start / detect-plugins suites" do not exist; only session-digest.test.sh runs the hook)? / A: new lib/tests/session-banner.test.sh, same harness style (orchestrator, internal) 
Q: plan revisions? / A: plan r3 after two challenge rounds: .claude/tasks/plans/2026-11-10-banner-effective-profile-1015.md is the binding FIX PLAN (orchestrator)

## ACCEPTANCE CRITERIA
1. Symptom gone: in a project whose local profile is dev, the banner's 🟢 row omits ui-ux-pro-max; under audit the ✅ row shows pr-review-toolkit; `detect_uiux_pro_max` follows the effective profile and stays correct under `set -euo pipefail`; regression suite present and green.
   CHECK: cd /home/bchanot/Documents/claude && make test suite=lib/tests/session-banner.test.sh 2>&1 | tail -1 | grep -q 'all suites green' && grep -q 'SB1' lib/tests/session-banner.test.sh && grep -q 'SB2' lib/tests/session-banner.test.sh && grep -q 'pipefail' lib/tests/session-banner.test.sh && grep -q '^list_on_plugins()' lib/detect-plugins.sh && echo SYMPTOM-GONE
   EXPECT: SYMPTOM-GONE
   EVIDENCE: MET exit=0 marker-found :: SYMPTOM-GONE
2. Agents report per-project state: status-reporter derives Plugins ON from `list_on_plugins` (no `bash -c`), cache = installed only; plugin-probe comment and plugin-advisor INPUT name PROFILE as the per-project source.
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'list_on_plugins' agents/status-reporter.md && ! grep -q 'for active marketplace plugins' agents/status-reporter.md && ! grep -q 'bash -c' agents/status-reporter.md && grep -q 'profile-unavailable' agents/status-reporter.md && grep -q 'per-project state = PROFILE' agents/plugin-probe.md && grep -q 'never per-project' agents/plugin-advisor.md && echo AGENTS-OK
   EXPECT: AGENTS-OK
   EVIDENCE: MET exit=0 marker-found :: AGENTS-OK
3. Build/tests green (full suite, GATES_TIMEOUT=600, bun on PATH); shellcheck at warning level clean on the touched shell files.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -S warning lib/detect-plugins.sh hooks/session-start.sh lib/tests/session-banner.test.sh && make test 2>&1 | tail -1 | grep -q 'all suites green' && echo GREEN
   EXPECT: GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN

## FILE SCOPE
lib/detect-plugins.sh, hooks/session-start.sh (✅ row source + comment only), agents/status-reporter.md, agents/plugin-probe.md (:22 comment only), agents/plugin-advisor.md (one INPUT sentence), lib/tests/session-banner.test.sh (new); bookkeeping (orchestrator): .claude/audits/BUGS-FOUND.md
