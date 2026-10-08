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
2. Engine-laid files are ignored: a mod's root `tsconfig.json` and anything under its `.claude-plugin/types/`; the tracked mod files are not ignored.
   CHECK: git check-ignore -q mods/model-router/tsconfig.json && git check-ignore -q mods/model-router/.claude-plugin/types/claude-code/index.d.ts && ! git check-ignore -q mods/model-router/hooks/register.ts && ! git check-ignore -q mods/model-router/.claude-plugin/plugin.json && echo IGNORE-OK
   EXPECT: IGNORE-OK
   EVIDENCE: pending
3. `lib/tests/mods.test.sh` passes on the repo and fails on a fixture that lacks the loading link (positive control through `MODS_ROOT`).
   CHECK: make test suite=lib/tests/mods.test.sh >/dev/null 2>&1 && W=$(mktemp -d) && mkdir -p "$W/mods" "$W/skills" && cp -R mods/model-router "$W/mods/" && ! MODS_ROOT="$W" bash lib/tests/mods.test.sh >/dev/null 2>&1 && ln -s ../mods/model-router "$W/skills/model-router" && MODS_ROOT="$W" bash lib/tests/mods.test.sh >/dev/null 2>&1 && echo MODS-SUITE-OK
   EXPECT: MODS-SUITE-OK
   EVIDENCE: pending
4. `doctor.sh` prints a `── Mods ──` section with a ✓ line for the model-router loading link.
   CHECK: out=$(bash doctor.sh 2>&1); echo "$out" | sed -n '/── Mods ──/,/^$/p' | grep -q '✓.*model-router' && echo DOCTOR-MODS-OK
   EXPECT: DOCTOR-MODS-OK
   EVIDENCE: pending
5. `CLAUDE.md` has a `## mods/` section naming the `skills/<name>` relative symlink, the `@skills-dir` origin, why not `CLAUDE_CODE_PLUGIN_DIRS`, the gitignored engine-laid files, `~/.claude/<name>.json`, the suite command and how to turn a mod off.
   CHECK: grep -q '^## mods/' CLAUDE.md && grep -q '@skills-dir' CLAUDE.md && grep -q 'CLAUDE_CODE_PLUGIN_DIRS' CLAUDE.md && grep -q 'mods.test.sh' CLAUDE.md && grep -q '<name>.json' CLAUDE.md && grep -q '@skills-dir": false' CLAUDE.md && echo CLAUDEMD-OK
   EXPECT: CLAUDEMD-OK
   EVIDENCE: pending
6. Health stack on the touched shell files, doctrine census green.
   CHECK: shellcheck lib/tests/mods.test.sh doctor.sh && make test suite=lib/tests/doctrine-citers.test.sh >/dev/null 2>&1 && echo HEALTH-OK
   EXPECT: HEALTH-OK
   EVIDENCE: pending
7. Judged by reading: no change to settings.json, link.sh or any install script; the user's settings.json working-tree diff is untouched; the suite SKIPs (explicit SKIP line, exit 0 for that part) only the `claude`-dependent checks when `claude` is absent, and fails when no mod is found at all; doctor's new section never increments the core-link counter (`_LINK_PASS`) and never fails on a missing `claude`; the CLAUDE.md section is terse English matching the file's style.

## FILE SCOPE
skills/model-router (new symlink) · .gitignore · lib/tests/mods.test.sh (new) · doctor.sh · CLAUDE.md
