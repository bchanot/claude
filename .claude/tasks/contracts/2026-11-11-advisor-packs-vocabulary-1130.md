# CONTRACT — advisor-packs-vocabulary
- date: 2026-11-11 | flow: feat | branch: feature/banner-drop-plugin-dev (RUN B, commits in place after RUN A)
- status: active

## REQUEST (verbatim — IMMUTABLE)
D2 + D3 from .claude/tasks/TODO.md § Release 3.0.0 scope (user decisions 2026-11-11, [gated]). D2: plugin-dev was dropped 2026-07-02 but the banner prints "OFF : plugin-dev": remove plugin-dev everywhere (lib/detect-plugins.sh `detect_plugin_dev` :43-47, hooks/session-start.sh :106,111,180,210, agents/plugin-advisor.md :59,181,199,242,250-255); the ⚫ OFF row disappears when empty. D3: rewrite agents/plugin-advisor.md and USAGE.md to the packs vocabulary (report .claude/tasks/plans/2026-11-09-bdr125-obsolescence-clean-1650.md D3: :99 PROFILE template in the old `profile.sh current` format, :126-129 toggle+rollback (plugin-gate says atomic), gstack ON/OFF rules :81-85,139-149,209,216,226,259, "context7 ON" :144,233; USAGE.md :181,232,233,1090,1092,1095), no budget/token claims, plus the G2 add-ons (TODO "D3 add-ons from G2": plan-budget WARN :317, :42, :105, :222, "0t passive" claims :226 :227 :268 :269; USAGE.md :248, :494, :923; lib/tests/session-banner.test.sh SB10 `gone()` must fail on a missing file). Line numbers predate the G1-G5 merges: re-locate. Regression tests in lib/tests/session-banner.test.sh. make test needs GATES_TIMEOUT=600 + PATH=$HOME/.bun/bin:$PATH (LRN-271). Foreign-code style. In force: BDR-134 (profiles single source), BDR-100 (patch every citer), BDR-125, LRN-274, LRN-275.

## CLARIFICATIONS
Q: one run or two? / A: two sequential /feat runs; RUN A (banner side) committed on this branch; THIS contract = RUN B (agents/plugin-advisor.md incl. its plugin-dev lines, lib/plugin-gate.md, USAGE.md, lib/tests/session-banner.test.sh) (orchestrator)
Q: plan? / A: .claude/tasks/plans/2026-11-11-advisor-packs-vocabulary-1000.md r3 § RUN B is binding (orchestrator, after two challenge rounds)
Q: profile mapping? / A: Backend API → dev (+ctx7 if fast libs); Frontend SPA/SSR → design; public website → web; Full-stack SaaS → full; CLI / library → dev; quick fix → minimal; design system → design; multi-session / enterprise → current profile or dev + gsd CLI (user, 2026-11-11) [gated]
Q: when may the advisor propose `profile.sh set`? / A: only when the project has no profile yet; otherwise per-pack enable/disable deltas; any set line lists what it turns off (user, 2026-11-11) [gated]
Q: USAGE scope? / A: every non-COST line of the plan's step 6 list rewritten; the 6 transcript `COST: ~Nt` lines and the Pattern-header estimates untouched (user, 2026-11-11) [gated]
Q: CHECK 3 matched `120000 tokens` (USAGE:202, literal /route show sample) via `0 token`? / A: oracle defect, pattern anchored `(^|[^0-9])0 token` as in SB10 (orchestrator, 2026-11-11, after GATE 0 run 1)
Q: GATE 1 ECARTS(2) + GATE 2 PASS with MEDIUM/LOW findings: fold all into one fresh-executor round? / A: yes; gap list `.claude/tasks/plans/2026-11-11-advisor-packs-vocabulary-round2-gaps.md`; FILE SCOPE adds skills/onboard/SKILL.md (ctx7 setup citer, BDR-100) (orchestrator, 2026-11-11)
Q: hotfix / quick-fix request on a project without profile: SET minimal (mapping) or no change? / A: no profile change; a hotfix request only points to /hotfix or /bugfix; minimal stays reachable from project-level signals only (user, 2026-11-11) [gated]
Q: GATE 1 round 2 ECARTS(2) + GATE 2 round 2 LOWs? / A: one fresh-executor round 3, gap list `.claude/tasks/plans/2026-11-11-advisor-packs-vocabulary-round3-gaps.md` (orchestrator, 2026-11-11)
Q: GATE 1 round 3 CONFORME, GATE 2 BLOCK(1) (onboard `make plugin` in a foreign cwd) + MEDIUM (max via SET) + verifier notes? / A: one fresh-executor security round, gap list `.claude/tasks/plans/2026-11-11-advisor-packs-vocabulary-security1-gaps.md`; FILE SCOPE adds skills/plugin-check/SKILL.md:14-17 (BDR-100 citer; RUN B now 6 files, over the /feat cap of 5 by two one-line citers, accepted) (orchestrator, 2026-11-11)

## ACCEPTANCE CRITERIA
1. Advisor in packs vocabulary: no plugin-dev, PLAN, plan budget, "0t passive", rollback, "gstack ON/OFF", `[plugin]` slot, `ctx7 setup`, "passive tokens"; DECISION TABLE and Recommended sets table gone; full ids for managed plugins; `↻ SET` slot gated on source=default.
   CHECK: cd /home/bchanot/Documents/claude && ! grep -qE 'plugin-dev|PLAN:|plan budget|0t passive|rollback|gstack ON|gstack OFF|\[plugin\]|ctx7 setup|passive tokens|## DECISION TABLE|Recommended sets' agents/plugin-advisor.md && grep -q 'ui-ux-pro-max@ui-ux-pro-max-skill' agents/plugin-advisor.md && grep -q 'pr-review-toolkit@claude-code-plugins' agents/plugin-advisor.md && grep -q '↻ SET' agents/plugin-advisor.md && grep -q 'source=default' agents/plugin-advisor.md && echo ADVISOR-OK
   EXPECT: ADVISOR-OK
   EVIDENCE: MET exit=0 marker-found :: ADVISOR-OK
2. Gate: the main loop prints `profile.sh diff` for a SET, applies only at the git root, SET first, disable form present, no ctx7 pre-fetch, no bare ui-ux-pro-max enable.
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'diff' lib/plugin-gate.md && grep -q 'rev-parse --show-toplevel' lib/plugin-gate.md && grep -q 'disable' lib/plugin-gate.md && grep -q 'unset' lib/plugin-gate.md && ! grep -qE 'Pre-fetch ctx7|Enable ui-ux-pro-max \(' lib/plugin-gate.md && echo GATE-OK
   EXPECT: GATE-OK
   EVIDENCE: MET exit=0 marker-found :: GATE-OK
3. USAGE: no old-vocabulary or zero-token claim outside the kept COST lines.
   CHECK: cd /home/bchanot/Documents/claude && ! grep -E '0 t passif|(^|[^0-9])0 token|gstack ON|gstack OFF|context7 ON|tout OFF|\(~[1-9][0-9]*t\)|DISABLE: .*context7' USAGE.md | grep -qv 'COST' && echo USAGE-OK
   EXPECT: USAGE-OK
   EVIDENCE: MET exit=0 marker-found :: USAGE-OK
4. Regression locks + full suite green.
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'lib/plugin-gate.md' lib/tests/session-banner.test.sh && grep -q 'USAGE.md' lib/tests/session-banner.test.sh && GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test 2>&1 | tail -1 | grep -q 'all suites green' && shellcheck -S warning lib/tests/session-banner.test.sh && echo GREEN
   EXPECT: GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN

## FILE SCOPE
agents/plugin-advisor.md, lib/plugin-gate.md, USAGE.md, lib/tests/session-banner.test.sh, skills/onboard/SKILL.md (:254-257 ctx7 install lines only), skills/plugin-check/SKILL.md (:14-17 only)
