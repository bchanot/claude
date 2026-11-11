# CONTRACT — banner-drop-plugin-dev
- date: 2026-11-11 | flow: feat | branch: feature/banner-drop-plugin-dev
- status: active

## REQUEST (verbatim — IMMUTABLE)
D2 + D3 from .claude/tasks/TODO.md § Release 3.0.0 scope (user decisions 2026-11-11, [gated]). D2: plugin-dev was dropped 2026-07-02 but the banner prints "OFF : plugin-dev": remove plugin-dev everywhere (lib/detect-plugins.sh `detect_plugin_dev` :43-47, hooks/session-start.sh :106,111,180,210, agents/plugin-advisor.md :59,181,199,242,250-255); the ⚫ OFF row disappears when empty. D3: rewrite agents/plugin-advisor.md and USAGE.md to the packs vocabulary (report .claude/tasks/plans/2026-11-09-bdr125-obsolescence-clean-1650.md D3: :99 PROFILE template in the old `profile.sh current` format, :126-129 toggle+rollback (plugin-gate says atomic), gstack ON/OFF rules :81-85,139-149,209,216,226,259, "context7 ON" :144,233; USAGE.md :181,232,233,1090,1092,1095), no budget/token claims, plus the G2 add-ons (TODO "D3 add-ons from G2": plan-budget WARN :317, :42, :105, :222, "0t passive" claims :226 :227 :268 :269; USAGE.md :248, :494, :923; lib/tests/session-banner.test.sh SB10 `gone()` must fail on a missing file). Line numbers predate the G1-G5 merges: re-locate. Regression tests in lib/tests/session-banner.test.sh. make test needs GATES_TIMEOUT=600 + PATH=$HOME/.bun/bin:$PATH (LRN-271). Foreign-code style. In force: BDR-134 (profiles single source), BDR-100 (patch every citer), BDR-125, LRN-274, LRN-275.

## CLARIFICATIONS
Q: one run or two? / A: two sequential /feat runs (advisor side needs lib/plugin-gate.md: 6 files > /feat cap). THIS contract = RUN A (D2 banner side: lib/detect-plugins.sh, hooks/session-start.sh, lib/tests/session-banner.test.sh); the plugin-dev lines of agents/plugin-advisor.md go to RUN B with D3 (orchestrator)
Q: plan? / A: .claude/tasks/plans/2026-11-11-advisor-packs-vocabulary-1000.md r3 § RUN A is the binding plan (orchestrator, after two challenge rounds)
Q: OFF row when every toggle is on? / A: no line at all (user, 2026-11-11) [gated]

## ACCEPTANCE CRITERIA
1. plugin-dev gone from the banner side and the OFF row absent when every toggle is on, with a positive control; `gone()` fails on a missing file; suite green.
   CHECK: cd /home/bchanot/Documents/claude && GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/session-banner.test.sh 2>&1 | tail -1 | grep -q 'all suites green' && grep -q 'SB11' lib/tests/session-banner.test.sh && ! grep -qi 'plugin.dev' lib/detect-plugins.sh hooks/session-start.sh && grep -q 'ctx7' lib/tests/session-banner.test.sh && echo BANNER-OK
   EXPECT: BANNER-OK
   EVIDENCE: MET exit=0 marker-found :: BANNER-OK
2. The dead >4 split branches of the toggle rows are gone; the 40-char budget is named in a comment.
   CHECK: cd /home/bchanot/Documents/claude && ! grep -q '_inactive_count\|_active_count\|INACTIVE_STR\|ACTIVE_STR=' hooks/session-start.sh && grep -q '40' hooks/session-start.sh && echo COLLAPSED
   EXPECT: COLLAPSED
   EVIDENCE: MET exit=0 marker-found :: COLLAPSED
3. Build/tests green (full suite); shellcheck at warning level clean on the touched shell files.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -S warning lib/detect-plugins.sh hooks/session-start.sh lib/tests/session-banner.test.sh && GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test 2>&1 | tail -1 | grep -q 'all suites green' && echo GREEN
   EXPECT: GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN

## FILE SCOPE
lib/detect-plugins.sh, hooks/session-start.sh, lib/tests/session-banner.test.sh
