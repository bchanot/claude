# CONTRACT — model-router-wiring (wave 1-B2: active in every session, tests, doctor)
- date: 2026-10-08 | flow: feat | branch: feature/model-router-mod
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (fr, first message of the session): "Et le mieux que ca soit configurable et qu'on puisse l'installer et qu'il soit actif sur toutes les session en userscope".
AskUserQuestion 2026-10-08, question on the loading mechanism (CLAUDE_CODE_PLUGIN_DIRS needs an absolute path, no $HOME expansion in settings `env`, settings.json is tracked and shared): answer "1 . Mais ce n'est pas un skill on est d'accord ? C'est un mod. don cplus u plugin. ET du coup pourquoi pqs link directement ule dossier mod vers le .claude/mods directement via le link.sh ? Pourquoi passer par skills ?" (option 1 = "Lien sous skills/ (Recommended)").
Explanation given to the user the same turn: a mod is a plugin, not a skill; Claude Code loads a plugin only from a marketplace, an absolute `CLAUDE_CODE_PLUGIN_DIRS` path, a claude.ai sync, or a plugin folder (`.claude-plugin/plugin.json`) under `~/.claude/skills/` (origin `@skills-dir`, loaded in place); a `~/.claude/mods` link alone loads nothing.
Same question batch, settings answer: "Je gère moi-même" (the user's uncommitted `/model` change to settings.json).

## CLARIFICATIONS
Q: loading mechanism / A: `skills/<name>` = relative symlink `../mods/<name>`, tracked in git; loads as `<name>@skills-dir`, in place, on every machine where link.sh links `~/.claude/skills`. No settings.json change, no link.sh change. Probe 2026-10-08 in an isolated HOME: listed, enabled, "Status: ✔ loaded". [gated 2026-10-08]
Q: settings.json / A: the working-tree change (model → opus, env block moved) stays untouched and out of every commit. [gated 2026-10-08]
Q: override convention / A: a mod's optional user config lives at `~/.claude/<name>.json` (model-router already reads `~/.claude/model-router.json`). [orchestrator]
Q: doctor scope / A: per mod: the loading link resolves into the repo mod dir; `claude plugin list --json` lists `<name>@skills-dir` enabled (warn, not fail, when absent, disabled, or `claude` missing); the override file parses as JSON when present. [orchestrator]

## ACCEPTANCE CRITERIA
1. `skills/model-router` is a symlink whose target is exactly `../mods/model-router`, and git does not ignore it.
   CHECK: [ -L skills/model-router ] && [ "$(readlink skills/model-router)" = "../mods/model-router" ] && ! git check-ignore -q skills/model-router && echo LINK-OK
   EXPECT: LINK-OK
   EVIDENCE: pending
2. Engine-laid files are ignored for ANY mod: a mod's root `tsconfig.json` (root `.gitignore`; the `.claude-plugin/types/` folder ignores itself); the tracked mod files are not ignored.
   CHECK: git check-ignore -q mods/model-router/tsconfig.json && git check-ignore -q mods/zz-future/tsconfig.json && ! git check-ignore -q mods/model-router/hooks/register.ts && ! git check-ignore -q mods/model-router/.claude-plugin/plugin.json && [ -z "$(git status --short mods/)" ] && echo IGNORE-OK
   EXPECT: IGNORE-OK
   EVIDENCE: pending
3. `lib/tests/mods.test.sh` passes on the repo, fails on a fixture that lacks the loading link, fails on an empty `mods/`, and SKIPs (exit 0) the CLI checks when `claude plugin test` is unavailable (probe by capability, PATH-shadowed `claude` in the control).
   CHECK: make test suite=lib/tests/mods.test.sh >/dev/null 2>&1 && W=$(mktemp -d) && mkdir -p "$W/mods" "$W/skills" "$W/bin" && cp -R mods/model-router "$W/mods/" && ! MODS_ROOT="$W" bash lib/tests/mods.test.sh >/dev/null 2>&1 && ln -s ../mods/model-router "$W/skills/model-router" && MODS_ROOT="$W" bash lib/tests/mods.test.sh >/dev/null 2>&1 && printf '#!/bin/sh\nexit 1\n' > "$W/bin/claude" && chmod +x "$W/bin/claude" && PATH="$W/bin:$PATH" MODS_ROOT="$W" bash lib/tests/mods.test.sh 2>&1 | grep -q '^SKIP' && E=$(mktemp -d) && mkdir -p "$E/mods" "$E/skills" && ! MODS_ROOT="$E" bash lib/tests/mods.test.sh >/dev/null 2>&1 && echo MODS-SUITE-OK
   EXPECT: MODS-SUITE-OK
   EVIDENCE: pending
4. `doctor.sh` prints a `── Mods ──` section with a ✓ line for model-router; with the link absent (HOME pointed at a scratch `.claude` whose `skills/` lacks the link) the section prints an info line, doctor reaches its summary and exits 0 for that section's sake (no new error).
   CHECK: out=$(bash doctor.sh 2>&1); echo "$out" | sed -n '/── Mods ──/,/^$/p' | grep -q '✓.*model-router' && H=$(mktemp -d) && mkdir -p "$H/.claude/skills" && o2=$(HOME="$H" bash doctor.sh 2>&1); echo "$o2" | sed -n '/── Mods ──/,/^$/p' | grep -qi 'not linked' && echo "$o2" | grep -q '═══' && echo DOCTOR-MODS-OK
   EXPECT: DOCTOR-MODS-OK
   EVIDENCE: pending
4b. The mod is enabled through the tracked link in a FRESH process: `claude plugin list --json` lists `model-router@skills-dir` with `enabled: true` (run after the dev-mods link is removed, see W6).
   CHECK: claude plugin list --json 2>/dev/null | python3 -c 'import json,sys; rows=json.load(sys.stdin); ok=any(r.get("id")=="model-router@skills-dir" and r.get("enabled") is True for r in rows); sys.exit(0 if ok else 1)' && echo LOADED-OK
   EXPECT: LOADED-OK
   EVIDENCE: pending
5. `CLAUDE.md` has a `## mods/` section naming the `skills/<name>` relative symlink, the `@skills-dir` origin, why not `CLAUDE_CODE_PLUGIN_DIRS`, the gitignored engine-laid files, `~/.claude/<name>.json`, the suite command and how to turn a mod off.
   CHECK: grep -q '^## mods/' CLAUDE.md && grep -q '@skills-dir' CLAUDE.md && grep -q 'CLAUDE_CODE_PLUGIN_DIRS' CLAUDE.md && grep -q 'mods.test.sh' CLAUDE.md && grep -q '<name>.json' CLAUDE.md && grep -q '@skills-dir": false' CLAUDE.md && echo CLAUDEMD-OK
   EXPECT: CLAUDEMD-OK
   EVIDENCE: pending
6. Health stack on the touched shell files, doctrine census green.
   CHECK: shellcheck lib/tests/mods.test.sh doctor.sh && make test suite=lib/tests/doctrine-citers.test.sh >/dev/null 2>&1 && echo HEALTH-OK
   EXPECT: HEALTH-OK
   EVIDENCE: pending
7. Judged by reading: no change to settings.json, link.sh or any install script; the suite probes the CAPABILITY (`claude plugin test --help`), bounds every CLI call in time, captures `2>&1`, SKIPs with a reason, fails when no mod is found; doctor's section is fail-soft under `set -euo pipefail` (existence test before readlink, `-ef` comparison, one guarded `claude plugin list --json`, python exits 0 with `unknown` on any parse error), never increments `_LINK_PASS`, says "enabled" not "loaded", treats a missing link as info; the link step is idempotent; CLAUDE.md names the per-machine `"enabled": false` switch, the tracked-settings cost of `enabledPlugins`, and the dev-copy shadowing rule; the CLAUDE.md section is terse English matching the file's style.
Q (r2): ordering / A: this contract runs after the floor contract (`2026-10-08-model-router-floor-1835`) is committed and green. [orchestrator]
Q (r2): update-all `claude plugin update` over `@skills-dir` / A: accepted residual (one recurring warn), logged in TODO; out of FILE SCOPE. [orchestrator]

## FILE SCOPE
skills/model-router (new symlink) · .gitignore · lib/tests/mods.test.sh (new) · doctor.sh · CLAUDE.md
