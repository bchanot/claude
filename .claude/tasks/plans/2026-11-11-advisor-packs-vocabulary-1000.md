# FEAT — advisor-packs-vocabulary (D2+D3, 2026-11-11) — r3 after two challenge rounds (final)

Source: .claude/tasks/TODO.md § Release 3.0.0 scope (user decisions 2026-11-11 [gated]); evidence .claude/tasks/plans/2026-11-09-bdr125-obsolescence-clean-1650.md D2/D3; TODO "D3 add-ons from G2".
Two /feat runs, sequential: RUN A = D2 banner side (3 files), RUN B = D3 advisor side + the plugin-dev advisor lines (4 files; lib/plugin-gate.md makes 6 files for one run, over the /feat cap).

## Context
- plugin-dev dropped 2026-07-02 (install-plugins.sh:527-529 history comment stays). Live citers: `detect_plugin_dev` (lib/detect-plugins.sh:67-71), banner toggle loop (hooks/session-start.sh:106,111), `_toggle_owned` (:173), plugin-advisor (:63, :185, :203, :246, :254-260). Banner prints `⚫ OFF : plugin-dev`.
- Packs (BDR-134): every switch is `lib/profile.sh` (`set <profile>`, `unset`, `enable|disable <pack | plugin id>`, `diff <profile>` prints `id: on → off` lines). `set` merges the WHOLE fragment (every managed key) into `<root>/.claude/settings.local.json`; root = git root (find_root walks up to .claude/, CLAUDE.md or .git below $HOME; no root → rc 2). gstack = packs gstack-dev / gstack-browser / gstack-design; impeccable + design-motion-principles = pack design; managed plugins (full id only, the bare name resolves to a non-existent pack, rc 2): `ui-ux-pro-max@ui-ux-pro-max-skill` (on in design, web, full, max), `pr-review-toolkit@claude-code-plugins` (on in audit, max); context7 = `ctx7` CLI (find-docs skill always loads), gsd = external CLI; `dev` = gstack-dev on.
- `source=default` + `profile=full` = no project profile and the manifest defaults; `source=default` with another profile name = pack keys from shared/user scope (custom).
- Under `source=flag` every profile.sh write affects other sessions only (lib/profile.sh:196-199).
- The advisor has no Bash (tools: Read, Glob, Grep): it can never run `profile.sh diff`; the gate (main loop) can.

## User decisions [gated]
- D2: remove plugin-dev everywhere; ⚫ OFF row disappears when empty.
- D3: advisor + USAGE in packs vocabulary, no budget/token claims.
- Profile mapping approved: Backend API → dev (+ctx7 if fast libs); Frontend SPA/SSR → design; public website → web; Full-stack SaaS → full; CLI / library → dev; quick fix → minimal; design system → design; multi-session / enterprise → current profile or dev + gsd CLI.
- Profile switch policy: `set <profile>` ONLY when the project has no profile yet; otherwise per-pack `enable` / `disable` deltas. Any `set` line lists what it turns off.
- USAGE scope: the 6 transcript `COST: ~Nt` lines (:363 :497 :551 :649 :711 :1018) and the Pattern-header session estimates stay; every other non-COST line in the sweep list below is rewritten (user 2026-11-11, round 2).

## RUN A — D2 banner side (/feat, 3 files)
1. `lib/detect-plugins.sh`: delete `detect_plugin_dev` (:67-71).
2. `hooks/session-start.sh`:
   - toggle loop `for plugin in gstack uiux_pro_max context7 graphifyy`, with a comment that the four display names (38 chars) must fit the 40-char field (a fifth toggle needs a split again); delete the `plugin_dev)` case line; `_toggle_owned` drops `plugin-dev`.
   - collapse the toggle rows (:202-232) to `printf "│  🟢 ON  : %-40s│\n" "${TOGGLE_ACTIVE[*]:-none}"` and `if [ ${#TOGGLE_INACTIVE[@]} -gt 0 ]; then printf "│  ⚫ OFF : %-40s│\n" "${TOGGLE_INACTIVE[*]}"; fi`; delete ACTIVE_STR / INACTIVE_STR / `_active_count` / `_inactive_count` and their unsets; drop the stale "split across 2 lines if >4" comment; reword the ✅ row comment (:183-185) so it no longer cites the toggle row's split policy (the ✅ row keeps its greedy split, unchanged).
3. `lib/tests/session-banner.test.sh`:
   - printf `ctx7` and `graphify` stub executables into `$WORK/stub` next to rtk (already first on PATH).
   - SB11 on SB3's existing `out` (h1 + pfull): 🟢 ON row has gstack, ui-ux-pro-max, context7, graphify (= 1 each, the positive control); `row '⚫ OFF'` is empty.
   - `gone()` echoes 0 when `$ROOT/$1` is missing; SB10 adds `gone lib/detect-plugins.sh detect_plugin_dev` = 1 and `gone hooks/session-start.sh 'plugin.dev'` = 1.
   - SB1-toggle-off-uiux (existing) keeps proving the OFF row prints when non-empty.

## RUN B — D3 advisor side (/feat, 4 files)
4. `agents/plugin-advisor.md` (voice kept). File-wide rule: every recommendation names a pack, a profile, a managed plugin by full id, or a CLI (ctx7, gsd); "gstack ON/OFF" never appears (gstack = the three packs).
   a. INPUT: delete the PLAN paragraph (:40-43).
   b. PHASE 2: delete the `skill-creation` row (:63).
   c. PHASE 2.5 tiers (:85-91) in profiles: simple → `minimal` (or `dev` for code work), moderate → current profile + ctx7 if fast-libs, complex → + pack gstack-browser if browser-QA, gsd if multi-session; graphify 200-file rule unchanged (BDR-097). Never "no gstack" next to a profile that enables gstack-dev.
   d. PHASE 3 template: `ACTIVE:` unchanged; `PROFILE: <profile> (source=<local|flag|default>)`; `↻ SET : <profile> — [reason]` ONLY when source=default AND profile=full AND the target differs from full (target = full → `✅ KEEP`, no SET); the SET line names the profile only (the gate prints what it turns off); with a SET line every ENABLE / DISABLE is a delta against the TARGET profile (a pack the target turns off but the project needs = ENABLE); `✅ KEEP : [pack or plugin] — [reason]`; `⚡ ENABLE : [pack or plugin] — [reason] — bash $HOME/.claude/lib/profile.sh enable <pack | full plugin id>`; `⚠️ DISABLE : [pack or plugin] — [reason] — bash $HOME/.claude/lib/profile.sh disable <pack | full plugin id>`, emitted only from project-level probe signals (manifests, deps, file counts), never from REQUEST-only signals (simple, hotfix, "this task"); `ℹ️ OPTIONAL: [pack or plugin] — [marginal benefit]`; under source=flag: no profile.sh command at all, only `relaunch: cc <name> <profile>` when a needed pack is off; delete the `PLAN:` line (:106).
   e. Apply note (:130-134): "Apply and confirmation are the DISPATCHER'S job" (the word "rollback" goes); atomic profile.sh writes; "emits the EXACT profile.sh commands".
   f. DECISION TABLE (:138-153) deleted: the Conditional RULES become the only signal → recommendation source (every table row has its RULE twin; the backend row :152 lives in the WRITING table). The RULES in packs vocabulary: mobile → packs gstack-browser + gstack-design off; deploy + browser-qa → packs gstack-dev + gstack-browser; browser-qa alone → pack gstack-browser; frontend / design-system → one line "pack design ON" (impeccable + design-motion-principles) + `ui-ux-pro-max@ui-ux-pro-max-skill` per the existing condition; the design-system WARN fires when pack design and ui-ux-pro-max are both off; fast-libs → "ctx7 CLI installed (find-docs skill always loads)", never ENABLE/DISABLE; gsd lines (:155, :234, :240) → "external CLI, nothing loads in Claude Code"; drop every "0t passive", "Saves passive tokens", "passive tokens saved". Keep the "Skill routing by task size" subsection (:157-171) as is.
   g. Recommended sets table (:191-207) deleted. WRITING A PROFILE table (:283-294): fold the approved labels into the existing rows' Signal cells (backend / API / CLI / library → dev, + ctx7 if fast libs; frontend SPA/SSR, heavy UI, design system → design; public website → web; quick fix / narrow session → minimal); add rows only for full-stack SaaS → full and multi-session / enterprise → current profile or dev + gsd CLI. The id list (:296-297) adds `ui-ux-pro-max@ui-ux-pro-max-skill` and `pr-review-toolkit@claude-code-plugins` (full ids). The section states the switch policy (set only at source=default + profile=full; else deltas; under flag only relaunch).
   h. Monorepo RULE (:217-222): one profile for the whole repo (profile.sh writes at the git root) = the union of the packages' needs, plus enable deltas; delete the per-package recommendation lines and "passive cost estimate" (:222).
   i. Embedded RULE: "all packs off (profile `minimal`)"; simple/hotfix RULE: "profile `minimal` when source=default, else nothing (no task-scoped DISABLE)"; delete the two plugin-dev RULEs (:254-260) and the compat row `plugin-dev ↔ superpowers` (:185); compat gstack rows say "gstack packs".
   j. BLOCK: delete "Full-product + gstack not installed" (:311). WARN: delete the plan-budget line (:317); "Active toggle plugins not needed for this task (dead passive cost)" → "Active packs no project signal needs"; context7 WARN fix (:320) → "`make plugin` (installs ctx7 and wires find-docs)", drop `ctx7 setup --claude`.
5. `lib/plugin-gate.md`:
   - step 4 (present, main loop): for a `↻ SET <profile>` line run `bash "$HOME/.claude/lib/profile.sh" -C <PROJECT_ROOT> diff <profile>` and print its `→ off` lines under it as "turns off" (none → "turns off: nothing").
   - step 5 (apply): trigger = a `↻ SET`, `⚡ ENABLE` or `⚠️ DISABLE` line. Apply only when `git -C <PROJECT_ROOT> rev-parse --show-toplevel` equals PROJECT_ROOT; otherwise print the commands and apply nothing ("no git root yet: run them after git init"). Order: the SET first, then the deltas (after "customize" too). Command forms: `set <name>`, `enable <pack | full plugin id>`, `disable <pack | full plugin id>`. The confirmation says the change is project-wide and persists in `<root>/.claude/settings.local.json`. Undo printed after a write: after a SET `profile.sh unset`, after deltas the inverse enable/disable. PROPOSED CHANGES example: `↻ Set profile dev (backend detected) — turns off: <diff lines>`, `⚡ Enable pack design (frontend detected)`, `⚡ Enable ui-ux-pro-max@ui-ux-pro-max-skill`; no ctx7 pre-fetch line. Under source=flag nothing is applied (relaunch line only).
6. `USAGE.md` (French, voice kept). Rewrite to the packs vocabulary and the approved mapping, drop every "0 token / 0 t passif / 0t / sans coût passif / ~Nt" claim, on these lines only: :181, :229, :232, :233, :236, :237, :240 (GSD: "CLI externe, rien ne se charge dans Claude Code"), :326 ("cso si le pack gstack-dev est actif"), :417-418, :494-496, :547, :550, :647-648, :709-710, :715 (drop "3000t de"), :810, :923, :1021-1023, :1031, :1055, :1078, :1090, :1092, :1094, :1095, :1096. Untouched: the 6 COST lines, Pattern-header estimates (:250 :271 :298 :359 :366 :369 :383 :400), :248 (already points to make doctor), :978. Transcript advisor lines show what the new advisor can emit (packs, profiles, full ids; context7 only as "ctx7 installé" / WARN).
7. `lib/tests/session-banner.test.sh` SB10: `gone agents/plugin-advisor.md 'plugin-dev|PLAN:|plan budget|0t passive|rollback|gstack ON|gstack OFF|\[plugin\]|ctx7 setup|passive tokens'` = 1 (the old `'plan budget'` filter arg is dropped); `gone lib/plugin-gate.md 'Pre-fetch ctx7|Enable ui-ux-pro-max \('` = 1; `has` lib/plugin-gate.md `profile.sh" -C` + `diff` and `rev-parse --show-toplevel` = 1; `has` agents/plugin-advisor.md `ui-ux-pro-max@ui-ux-pro-max-skill` = 1; `gone USAGE.md '0 t passif|0 token|gstack ON|gstack OFF|context7 ON|~[1-9][0-9]*t\)'` = 1 with a filter that keeps the 6 COST lines (`'COST'`).

## Edge cases
- Banner width: 40-char field, longest toggle row 38 (comment in the loop).
- A stale user-scope `plugin-dev@…: true` key would now show in the ✅ row: truthful, by design (none on this machine).
- doctor.sh / status-reporter do not call `detect_plugin_dev` (grep 2026-11-11).
- /init-project STEP 0 runs before `git init`: the gate shows the commands and applies nothing (step 5 git-root check); applying after STEP 5f is left to the user (skills/init-project not in scope).
- source=default with a non-full profile (shared or user scope pack keys): no SET, deltas only.
- source=flag: no write at all.
- CHANGELOG history lines naming plugin-dev stay.

## Disposition
honors BDR-134 (profile.sh single switch, project-scoped, never user scope), BDR-100 + LRN-169 (every citer patched), BDR-125 (D2 deletes what the plugin-dev drop obsoleted), BDR-097 (graphify rule untouched), LRN-093 (SB11 positive control), LRN-274 (detect-plugins: deletion only), LRN-275, LRN-271.

## Files
RUN A: lib/detect-plugins.sh, hooks/session-start.sh, lib/tests/session-banner.test.sh.
RUN B: agents/plugin-advisor.md, lib/plugin-gate.md, USAGE.md, lib/tests/session-banner.test.sh.

## Challenge summary
- Round 1: correctness FATAL(3), robustness CONCERNS(3), simplicity CONCERNS(3) → r2 (run split, SET slot, full ids, monorepo union, banner collapse, tests).
- Round 2 (cap reached, no round 3): correctness CONCERNS(2), robustness CONCERNS(4), simplicity CONCERNS(3), no BLOCKER. Folded into r3: the turns-off list moves to the gate (advisor has no Bash), SET only at default+full and never equal to full, deltas against the target, SET first, git-root apply check, DISABLE from project signals only, undo lines, no writes under flag, DECISION TABLE deleted (RULES = one source), WRITING table folded not appended, pack design one line, pr-review-toolkit full id, USAGE sweep widened (user), SB11 on SB3's output.
