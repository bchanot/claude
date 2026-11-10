# FIX — passive-cost-source (/bugfix G2, 2026-11-10) — r3 split after two challenge rounds

Source: .claude/audits/BUGS-FOUND.md entry G2.

## Diagnosis
Symptom: four places state per-plugin passive token costs and disagree.
- hooks/session-start.sh:170-195 `_plugin_costs` (gstack 2750, ui-ux-pro-max 400, plugin-dev 100, context7 200, graphify 300) summed over TOGGLE_ACTIVE, divided by a plan "budget" (detect_plan: max 20000, pro 11000, :163-167), printed as the 💰 row (:270) above 25 %.
- agents/plugin-advisor.md: hardcoded `~400t` (ui-ux, :215 :225 :267), `~2750t` (gstack :230), `~200t` (context7 :237), `~100t` (plugin-dev :255 :259), recommended-sets "Passive cost" column (:196-204: ~0t ~600t ~3400t ~400t ~200t), :150 "Saves ~3000-5000t", :152 "~3100t saved", :243 "~800t base only".
- doctor.sh:520-528 counts only ui-ux-pro-max (670) on top of the skill catalog; gstack/context7/graphify constants were dropped 2026-09-28 (skill-catalog prune) as double counting because their skills sit under ~/.claude/skills and are already in `skill_catalog_stats`.
- agents/status-reporter.md:27-33 greps doctor's `PLUGIN_TOKENS + <n>` lines as the source of truth.
Root cause: hand-copied constants. The 2026-09-28 prune re-measured and fixed doctor (ui-ux 400 → 670, plan .claude/tasks/plans/2026-09-28-skill-catalog-prune-0554.md:240-243) but missed the banner and advisor citers (BDR-100 class).
Evidence (measured 2026-11-10, chars of the `description:` via lib/skill-routing-census.py extract_description, /4): gstack 3 packs 15+8+4 skills 1781 chars → ~445t (constant 2750); ui-ux-pro-max 7 skills 2663 chars → ~666t (doctor 670 ✓, banner/advisor 400 ✗); context7 = find-docs skill 1326 → ~331t (200); graphify skill 371 → ~93t (300).
Second defect on the same row: the 💰 percentage uses a per-plan "budget" denominator, the category error doctor removed (doctor.sh:500-505: passive footprint competes with the context window, not a quota). With measured costs all toggles total ~1500t, below the 25 % threshold, so the row never shows.

## User decisions (2026-11-10) [gated]
- Single source = measured at runtime from the real skill descriptions (same method as doctor's catalog); no hand constants anywhere.
- Banner 💰 row removed (budget calc gone); doctor.sh stays the context-cost estimate (% of the 200k window).

## Split (user decision 2026-11-10, after challenge round 2) [gated]
Two challenge rounds showed the runtime-measurement API is a feature, not a bugfix (open definitions: agent descriptions count, pr-review-toolkit ~1550t / example-skills ~2350t, doctor counts OFF packs, `detect_plugin_dev` globs the wrong cache level and ignores enabled state, `?` for empty units, rc-0 sentinels, profile.sh failure → unknown, python `-I`). This /bugfix (r3) only REMOVES the wrong hand figures and the dead banner path; the measured-cost API goes to the TODO as a /ship-feature with those findings as spec input. doctor.sh keeps its measured ui-ux 670 (the one correct figure) until then.

## Fix plan (r3)
1. `hooks/session-start.sh`: delete the plan/budget block (:162-167), the passive-cost block (:169-196, incl. `_plugin_costs` and the `unset _passive_t _budget_pct _budget` line), the 💰 printf (:270) and `TOKEN_WARN` from the final `unset` (:463). Nothing else reads PLAN / PLAN_LABEL / TOKEN_WARN (grep verified).
2. `lib/detect-plugins.sh`: delete `detect_plan` and its "Plan detection" section (no caller left; BLK-043's fork-bomb source goes with it); header line 7 drops `detect_plan`.
3. `lib/tests/detect-plan.test.sh` → `git mv` to `lib/tests/hook-recursion-guard.test.sh` (Makefile globs `lib/tests/*.test.sh`): delete T1/T2 (detect_plan cases), the `LIB=` line, the maxhome fixture and the `cp … .claude.json` line (only detect_plan needed it); keep T3 (SESSION_START_RUNNING guard) and T4 (child sees guard, no claude calls), green without `.claude.json`; header: the suite guards the hook recursion guard (BLK-043); summary `hook-recursion-guard: %d passed, %d failed`.
4. `agents/status-reporter.md`: delete the doctor-grep block (:27-33); prose: the passive cost is not computed here, `make doctor` measures it; output template `Plugins ON: <list> (~<X>t passive — doctor.sh constants; full audit → /plugin-check)` → `Plugins ON: <list> (passive cost: make doctor; full audit → /plugin-check)`; frontmatter description "plugin roster + passive-cost estimate (doctor.sh constants)" → "plugin roster (passive cost: make doctor)".
5. `agents/plugin-advisor.md`: no per-plugin token figure left (they were stale: gstack 2750 vs ~445 measured over 3 packs, ui-ux 400 vs 666, context7 is a CLI whose find-docs skill always loads):
   - drop the `(~400t)` ×3, `(~2750t)`, `(~100t)` parentheticals; context7 `(~200t)` → `(CLI; its find-docs skill always loads)`; `~100t saved if disabled` → `saves its passive tokens if disabled`; :150 "Saves ~3000-5000t" → "Saves passive tokens"; :152 "~3100t saved" → "passive tokens saved"; :243 "~800t base only" → "base only".
   - recommended-sets table: delete the "Passive cost" column.
   - COST ESTIMATE template line → `COST ESTIMATE: run make doctor (measured; no per-plugin constants here)`.
   - The plan-budget WARN (:317) stays (deferred D3; unreachable: plugin-gate never sends PLAN).
6. `lib/tests/session-banner.test.sh`: SB9: the SB3 banner (full) has no `💰` line and no `budget` text. SB10 census: hooks/session-start.sh has no `_plugin_costs`, `TOKEN_WARN`, `detect_plan`; lib/detect-plugins.sh has no `detect_plan`; agents/status-reporter.md has no `PLUGIN_TOKENS` and no `~[1-9][0-9-]*t`; agents/plugin-advisor.md has no `~[1-9][0-9-]*t` outside the plan-budget WARN line (`grep -v 'plan budget'`).
7. Bookkeeping (orchestrator): BUGS-FOUND G2 FIXED line (hand figures removed; doctor keeps measured 670; measured-cost API in TODO); TODO: /ship-feature "measured passive-cost API" with the round-1/round-2 findings listed; D3 deferred items (plan-budget WARN, "0t passive" pack-design claims); USAGE.md citers :248 :494 :923 for the doc-sync gate.

## Edge cases
- `hook-recursion-guard.test.sh` T3/T4 keep their existing fake HOME (links of ~/.claude/* entries, read-only use), unchanged beyond the deletions.
- Advisor still fails closed on a missing PROBE REPORT field: the field list is unchanged (no COSTS field in r3).

## In-force
LRN-088 (re-measure after catalog change), LRN-274 (pipefail-safe lib functions), BLK-043 (detect_plan fork bomb; removal ends it; claude stub in hook tests), BDR-100 (patch every citer), BDR-125 (delete what the change obsoletes). Foreign-code style.
Files (r3): hooks/session-start.sh, lib/detect-plugins.sh, lib/tests/detect-plan.test.sh → hook-recursion-guard.test.sh, agents/status-reporter.md, agents/plugin-advisor.md, lib/tests/session-banner.test.sh.
