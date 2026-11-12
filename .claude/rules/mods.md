---
paths: ["mods/**", "skills/model-router/**", "lib/tests/mods.test.sh"]
---

# mods/ — function-hooks plugins (Claude Code mods)

A mod lives in `mods/<name>/` (`.claude-plugin/plugin.json` + hooks). It
loads through the tracked relative symlink `skills/<name>` -> `../mods/<name>`
(`~/.claude/skills` links to `skills/`) as `<name>@skills-dir`, in place,
live at the next session or `/reload-plugins`. New mod: `ln -s ../mods/<name>
skills/<name>` from the repo root (guard with `[ -L ]`, a re-run nests a link).
Not `CLAUDE_CODE_PLUGIN_DIRS` (absolute path, settings `env` has no `$HOME`
expansion, settings.json is tracked), nor a local marketplace (`add` writes
an absolute path into settings.json).
- The engine lays `mods/<name>/tsconfig.json` and `.claude-plugin/types/`;
  both are gitignored.
- Optional user config: `~/.claude/<name>.json`. Its `"enabled": false` is the
  per-machine off switch (untracked). `"<name>@skills-dir": false` in
  `enabledPlugins` also works but lands in the TRACKED settings.json and
  dirties every machine's tree.
- A dev copy of the same name (`--plugin-dir`, hot-reload link in
  `~/.claude/dev-mods/<session>/`) shadows the skills-dir copy for that
  session: remove it before reading `/reload-plugins` as a test of the link.
- Tests: `make test suite=lib/tests/mods.test.sh` (manifest, link,
  `claude plugin validate`, `claude plugin test`). `doctor.sh` has a Mods section.
