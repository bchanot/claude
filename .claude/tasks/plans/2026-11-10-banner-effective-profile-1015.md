# FIX — banner-effective-profile (/bugfix G1+G4, 2026-11-10) — r3 after two challenge rounds

Source: .claude/audits/BUGS-FOUND.md entries G1 (session-start banner) and G4 (status-reporter, plugin-probe).

## Diagnosis
Symptom: the session banner and two agents report user-scope / installed plugin state as the project's active state.
- `lib/detect-plugins.sh` `detect_uiux_pro_max` only tests the plugin cache: installed = on. A project whose effective profile disables it (dev, minimal, seo, qa, audit) still shows `ui-ux-pro-max` in the 🟢 ON row.
- `hooks/session-start.sh` ✅ ON row (≈:200-219) greps `"<name>@<mkt>": true` in `$HOME/.claude/settings.json` (user scope). A project profile that enables `pr-review-toolkit` (max, audit) is not shown; one that disables a user-enabled plugin still shows it.
- `PROFILE_PLAIN` (session-start ≈:98-100, one `profile.sh -C "$PWD" current --plain` run, exported) already holds the effective state: `pack-*=on|off` lines and `plugin:<id>=on|off` lines for every id managed by lib/profiles/*.json (one shared key set of 15 ids; 6 non-pack: model-router@skills-dir, security-guidance@claude-code-plugins, ui-ux-pro-max@ui-ux-pro-max-skill, pr-review-toolkit@claude-code-plugins, example-skills@anthropic-agent-skills, brightdata-plugin@synced). `detect_gstack` already reads it.
- G4: `agents/status-reporter.md:23` "Active plugins (from session-start detection)" and :35 "Check `~/.claude/plugins/cache` for active marketplace plugins" (cache = installed, not active); :181 error row ties ON to the cache. `agents/plugin-probe.md:22` labels `claude plugin list` "(ids, enabled state)" and the PROBE REPORT `PLUGINS` field (:69) carries it raw; plugin-advisor (`ACTIVE:` block, plugin-advisor.md:98) has no rule saying which field holds per-project state, so it can read PLUGINS as active.
Evidence: fake HOME (lib + skills symlinked, cache dir, user settings ui-ux-pro-max true) + project settings.local.json = lib/profiles/dev.json → `profile.sh current --plain` prints `plugin:ui-ux-pro-max@ui-ux-pro-max-skill=off`, banner prints `🟢 ON  : gstack ui-ux-pro-max context7 graphify`.
Blast radius: doctor.sh:528 calls `detect_uiux_pro_max` for its passive-cost sum (repo cwd; after the fix it follows the cwd profile, intended; constants are G2). No other caller.

## Rule (r3, after round 2: doctor pipefail BLOCKER, scope trimmed)
ENABLED for this project and conversation = `plugin:<id>=on` in the effective profile for the ids lib/profiles manages (BDR-134); for an id the profile does not list, `"<id>": true` in user-scope `$HOME/.claude/settings.json` (today's behavior, LRN-005); `pack-*@skills-dir` ids are never plugins here. Profile empty (profile.sh failed) → every id falls to the user-scope rule.
No new install check: the ✅ row never had one; `detect_uiux_pro_max` keeps its existing cache glob AND adds ENABLED.
Round-2 findings deliberately NOT taken (named in the shortcut comment, deferred to a later run): a mod's per-machine off switch (`~/.claude/model-router.json` enabled false still shows model-router); unmanaged skills-dir mods absent from every scope (memory@skills-dir, pre-existing omission, not a regression); project/local scope for unmanaged ids; install checks for the `synced` marketplace and for local-scope installs (moot without an install check on the ✅ row).

## Fix plan
1. `lib/detect-plugins.sh`:
   - header lines 6-7: `detect_*` return 0/1 silently; `detect_plan` and `list_on_plugins` print to stdout.
   - new function `list_on_plugins` above `# --- Toggle plugins ---` (or in a short "Effective plugin state" block), pipefail-safe, always `return 0`, no pipeline whose status matters, set difference in awk (no `grep -f` on a possibly empty file):
   ```bash
   list_on_plugins() {
     # Enabled plugin ids for this project and conversation, one per line:
     # the effective profile for the ids lib/profiles manages (BDR-134),
     # user-scope true for the others (LRN-005). Always returns 0.
     # shortcut: unmanaged ids read user scope only (not project/local) and
     # a skills-dir mod set in no scope (memory) is not seen, nor a mod's
     # ~/.claude/<name>.json off switch; upgrade = jq merge of the scopes +
     # plugin manifests.
     local plain="${PROFILE_PLAIN:-}" user
     [ -n "$plain" ] || plain="$(bash "$HOME/.claude/lib/profile.sh" -C "$PWD" \
       current --plain 2>/dev/null)" || plain=""
     user="$(grep -oE '"[A-Za-z0-9_-]+@[A-Za-z0-9_-]+"[[:space:]]*:[[:space:]]*true' \
       "$HOME/.claude/settings.json" 2>/dev/null)" || user=""
     awk -F= 'FNR == NR { if (sub(/^plugin:/, "", $1)) { m[$1] = 1
         if ($2 == "on") print $1 }; next }
       { sub(/^"/, ""); sub(/".*$/, "") }
       $0 != "" && !($0 in m) && $0 !~ /^pack-.*@skills-dir$/' \
       <(printf '%s\n' "$plain") <(printf '%s\n' "$user")
     return 0
   }
   ```
   (printf always emits at least one line, so FNR == NR stays a valid first-file test even when `plain` is empty. Executor may tidy, keeping: awk set difference, explicit return 0, no pipe into the status.)
   - `detect_uiux_pro_max`: keep the cache-glob test, then `&& grep -q '^ui-ux-pro-max@' <<<"$(list_on_plugins)"` (here-string, not a pipe), one comment line (installed AND enabled for this project).
2. `hooks/session-start.sh` ✅ ON row: the while-loop reads `done < <(sed 's/@.*//' <<<"$(list_on_plugins)")` instead of the user-settings grep; toggle-owned exclusion unchanged; rewrite the comment above it (effective profile for managed ids, user scope for the others, same function as detect_uiux_pro_max and /status). User decision 2026-11-10: `model-router` shown; real order on a default project: `rtk model-router security-guidance` (profile lines sort by id). Empty lines skipped.
3. `agents/status-reporter.md`:
   - PHASE 1 bash block: replace the :23 comment; add (no `bash -c`: settings.json asks on it) `. "$HOME/.claude/lib/detect-plugins.sh" && list_on_plugins || echo "plugins-unavailable"` and `bash "$HOME/.claude/lib/profile.sh" -C "$PWD" current --plain 2>/dev/null | grep -E '^(profile|pack-[a-z0-9-]+)=' || echo "profile-unavailable"`.
   - :35 → `~/.claude/plugins/cache` = installed, not active; `Plugins ON:` = rtk (if present) + the names printed by `list_on_plugins` (part before `@`) + the `pack-*=on` packs.
   - Error table :181 → cache unreadable: no effect on `Plugins ON:`; `profile-unavailable` → `Plugins ON:` from `list_on_plugins` (user-scope fallback) with suffix `(profile.sh unavailable: user scope)`; `plugins-unavailable` → `Plugins ON: unknown (detect-plugins.sh unavailable)`.
   - Passive-cost rule unchanged (G2 separate).
4. `agents/plugin-probe.md`: :22 comment only → "Marketplace plugins installed; the enabled column may not reflect the project profile or --settings: per-project state = PROFILE above". PROBE REPORT template unchanged (one carrier for the rule: the advisor, step 5).
5. `agents/plugin-advisor.md` INPUT section (after :22-27), one sentence: "`ACTIVE:` = the managed ids from `PROFILE` (`pack-*=on`, `plugin:<id>=on`); an id absent from PROFILE keeps its `PLUGINS` enabled state (user scope); CLIs from `CLIS`. `PLUGINS` alone is installed state, never per-project." No output-format change (D3 untouched).
6. Regression test: new `lib/tests/session-banner.test.sh` (Makefile SUITES glob picks it up), `set -u` like its neighbours, summary line `session-banner: %d passed, %d failed` (session-digest format; exit 1 on any fail).
   Fixtures with mkdir/printf only, never links of the real ~/.claude (no mkhome copy); no `rm` in the body:
   - `WORK=$(mktemp -d)`, cleanup only by the `trap 'rm -rf "$WORK"' EXIT` of session-digest.test.sh; it removes the two lib/skills links without following them (assert `[ -L ]` on both right after creating them).
   - fake HOME `$WORK/h1`: `.claude/lib` → `$ROOT/lib` and `.claude/skills` → `$ROOT/skills` (the only two symlinks); real file `.claude/settings.json` = `{"enabledPlugins":{"ui-ux-pro-max@ui-ux-pro-max-skill":true,"security-guidance@claude-code-plugins":true,"foo-extra@somewhere":true,"pack-seo@skills-dir":true}}`; real dir `.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max`.
   - `$WORK/h2` = h1 without the cache dir. `$WORK/h3` = h1 without the `.claude/lib` symlink (profile.sh unreachable). `$WORK/h4` = h1 with user settings holding only managed ids (`ui-ux-pro-max@ui-ux-pro-max-skill`, `security-guidance@claude-code-plugins` true).
   - Guard before writing any fixture file: `[ ! -L "$h/.claude/settings.json" ] && [ ! -L "$h/.claude/plugins" ]`, else exit 1.
   - rtk pinned: executable `rtk` stub (`exit 0`) in the claude stub dir on PATH. claude stub (lib/tests/claude-stub.sh, BLK-043); `SESSION_START_OFFLINE=1`.
   - every fixture project has a `.claude/` dir: `pdev` (settings.local.json = copy of `$ROOT/lib/profiles/dev.json`), `paudit` (audit.json), `pfull` (empty `.claude/`).
   - helper `onrow` = the `✅ ON` line plus the next line when it is a continuation (`│` + 13 spaces); `toggleon` = `🟢 ON` line plus continuation; `toggleoff` = `⚫ OFF` line plus continuation. Every assertion, positive and negative, runs over these.
   Cases:
   - SB1 dev (h1): toggleon lacks `ui-ux-pro-max`, toggleoff has it; onrow has `rtk`, `model-router`, `security-guidance`, `foo-extra`; lacks `pr-review-toolkit`, `pack-seo`.
   - SB2 audit (h1): onrow has `pr-review-toolkit`; toggleon lacks `ui-ux-pro-max`.
   - SB3 full (h1): toggleon has `ui-ux-pro-max`; onrow lacks `pr-review-toolkit`.
   - SB4 `detect_uiux_pro_max` sourced from `$ROOT/lib/detect-plugins.sh`, PROFILE_PLAIN unset: dev/h1 → 1; full/h1 → 0; full/h2 → 1 (not installed).
   - SB5 profile.sh unreachable (h3, pdev): `detect_uiux_pro_max` → 0 (user-scope true + installed); `list_on_plugins` prints `security-guidance@claude-code-plugins`, `ui-ux-pro-max@ui-ux-pro-max-skill`, `foo-extra@somewhere`, not `pack-seo@skills-dir`.
   - SB6 pipefail (h4, pfull), in a subshell with `set -euo pipefail` (doctor.sh options): `detect_uiux_pro_max` → 0 and `list_on_plugins` rc 0 and the subshell survives.
   Red before the fix: SB1 (ui-ux in 🟢), SB2 (pr-review hidden), SB4 dev/h1, SB5/SB6 (function absent).
7. Bookkeeping (orchestrator): BUGS-FOUND G1 and G4 FIXED continuation lines.

## Edge cases
- Profile empty (profile.sh missing/failed, no jq): user-scope view for every id; ui-ux still cache-checked.
- Id managed and user-enabled: profile wins, no duplicate.
- Profile-enabled but not installed (pr-review-toolkit on a host without it): shown in ✅ (no install check, as today for user-enabled ids); ui-ux-pro-max keeps its cache check.
- `pack-*@skills-dir` true at user scope: excluded.
- doctor.sh (`set -euo pipefail`): `detect_uiux_pro_max` and `list_on_plugins` never return non-zero through a pipe (SB6).
- Row width: line 2 of the ✅ row pads but never truncates (pre-existing, unchanged).

## In-force
BDR-134 (profile = single source of truth for per-project state), LRN-005 (never hide a user-enabled plugin), BLK-043 (claude stub in hook tests), LRN-271 (make test env). Foreign-code style: keep file style. Files: 5 code/prompt + 1 new test (the advisor line is the G4 consumer side; > 5 by one, justified: one-sentence edit).
