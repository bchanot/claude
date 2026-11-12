---
paths: ["skills/graphify/**", "install-plugins.sh"]
---

# Machine-owned: the vendored graphify skill

`skills/graphify/SKILL.md`, `skills/graphify/references/` and
`.graphify_version` are written by `graphify install` (default platform
claude; `install-plugins.sh` STEP graphify), which lands in the repo
because `~/.claude/skills` is a symlink to `skills/`. They are gitignored: a
`pipx upgrade graphifyy` used to dirty the tree and cost a
`chore(graphify): sync vendored skill X -> Y` commit each time.

Two graphify commands, easy to confuse, and only one restores the skill:
- `graphify install --platform claude` copies SKILL.md + `references/` +
  `.graphify_version` into `skills/graphify/`, and appends a `# graphify`
  block to `~/.claude/CLAUDE.md` = `CLAUDE.global.md` (graphifyy 0.9.67).
  This is the recovery command; then delete that trailing block (one EOF
  hunk in `git diff`), never check out the whole file.
- `graphify claude install` writes the CLAUDE.md graphify section and the
  `.claude/settings.json` PreToolUse hooks in the current directory. It
  **rewrites both guarded configs** (EVAL-020, verified again 2026-09-15),
  so revert them after. It does NOT copy the skill.

`make plugin` runs both (`install-plugins.sh` STEP graphify) behind the
guarded-config EXIT trap, so a fresh clone is covered; `install-plugins.sh`
runs the second from `$REPO`, whatever the caller's cwd.

Trade-off accepted: an upstream release can now change the skill's prompt
with no diff to review. `skills/graphify/test-prompts.json` is hand-written
for darwin and stays tracked.

Gotcha, learned the hard way: `git rm --cached` keeps the working file,
but if the branch you merge into still tracks it, the merge deletes it
from disk. Untrack and merge, then restore with the command above.
