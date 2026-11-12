# RUN B — round 3 gaps (GATE 1 round 2 ECARTS(2) + GATE 2 round 2 LOWs), 2026-11-11

Apply on top of the current working tree (RUN B rounds 1-2 in place, uncommitted). Binding: plan r3 (.claude/tasks/plans/2026-11-11-advisor-packs-vocabulary-1000.md), round-2 gaps (…-round2-gaps.md), contract CLARIFICATIONS.

## User decision (2026-11-11) [gated]
A hotfix / quick-fix REQUEST never changes the profile: it only points to /hotfix or /bugfix. `minimal` stays reachable from project-level signals only (embedded RULE, "narrow session" row). This replaces the "quick fix → minimal" mapping row.

## Verifier gaps (must close)
R1. agents/plugin-advisor.md WRITING table: rows whose profile is `full` (public website end-to-end ~:252, full-stack SaaS ~:255) emit `✅ KEEP` (no SET), per the PHASE 3 rule "target = full → ✅ KEEP, no SET".
R2. USAGE.md :648 and :711: the SET line names the profile only: `↻ SET : dev`. Drop the parenthetical turns-off list (it was wrong: `profile.sh diff dev` from full lists 7 ids). If the transcript shows the gate's line, it must be the real one: `turns off: pack-design, pack-scroll3d, pack-seo, pack-web-validate, pack-gstack-browser, pack-gstack-design, ui-ux-pro-max@ui-ux-pro-max-skill`.

## Hotfix decision (apply)
R3. agents/plugin-advisor.md: the WRITING row "quick fix, narrow session → ↻ SET : minimal" (~:258) becomes "narrow session (project-level) → ↻ SET : minimal"; quick fix / hotfix appears only in the simple/hotfix RULE (no SET, no DISABLE, skill pointer). USAGE.md :237 and :1097 ("Hotfix → profil minimal") → "Hotfix / script rapide → aucun changement de profil (/hotfix ou /bugfix)".

## Security LOWs + verifier notes (fix)
R4. lib/plugin-gate.md:46 profile check path anchored: `$HOME/.claude/lib/profiles/<name>.json` (the gate runs from a consumer project's main loop).
R5. lib/plugin-gate.md closed pack list: `higgsfield` is NOT accepted from advisor tokens (paid service, explicit user ask only); say so next to the list.
R6. lib/plugin-gate.md:54-55: correct the premise: `diff` fails on a bad name, unknown profile or missing dir (not "no project root": find_root returns rc 0); on any non-zero exit print "turns off: unknown" and continue.
R7. lib/plugin-gate.md: keep `-C "<PROJECT_ROOT>"` and its argument on one line in every template (no line break right after `-C`), so the one-line lock catches an unquoted root.
R8. USAGE.md :551 Example 3: drop the OPTIONAL line that suggests packs `full` already turns on (target full = KEEP).
R9. agents/plugin-advisor.md:165-166: remove the double blank line.

## Tests
T2. lib/tests/session-banner.test.sh SB10: `gone agents/plugin-advisor.md 'SET : full'` = 1; `gone USAGE.md 'le gate liste ce que le profil coupe'` = 1; `has` lib/plugin-gate.md `$HOME/.claude/lib/profiles/` = 1; `gone lib/plugin-gate.md -- '-C *$'` = 1 (no `-C` at line end). Keep every existing lock green.

## Logged, not fixed (orchestrator → BUGS-FOUND)
- worktree: gate compares `--show-toplevel` but profile.sh writes at the parent of `--git-common-dir`; in a linked worktree the confirmed path and the written path differ (same repo).
- `"<PROJECT_ROOT>"` double quotes still expand `$(…)`; value comes from the main loop.
