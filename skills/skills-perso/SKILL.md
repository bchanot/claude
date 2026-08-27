---
name: skills-perso
description: |
  List personal (user-created) skills from ~/.claude/skills/.
  Excludes framework/gstack skills and symlinked/external skills.
  Shows only skills the user wrote themselves.
  Trigger: "skills-perso", "mes skills", "list my skills", "quels skills", "skills perso".
argument-hint: ""
allowed-tools:
  - Bash
  - Read
  - Glob
---

# skills-perso

List only **user-created** skills from `~/.claude/skills/`, excluding framework
(gstack) skills, symlinked directories, and external skills.

## How to detect user-created skills

The install convention (`link.sh`) IS the discriminator — no content heuristics:

1. **External/framework skills are symlinks** (gstack, npx skills, third-party) → excluded.
2. **Personal skills are real directories** containing a `SKILL.md` → included.
3. **Machine-generated skills** (e.g. `find-docs`, written by `install-plugins.sh`)
   are real dirs but gitignored in the config repo → excluded via `git check-ignore`.

Run this command to get the list of personal skills:

```bash
SKILLS_DIR=$(readlink -f ~/.claude/skills)   # resolves into the config repo when wired by link.sh

found=0 excluded=0
for dir in ~/.claude/skills/*/; do
  d=${dir%/}
  skill=$(basename "$d")
  if [ -L "$d" ]; then excluded=$((excluded + 1)); continue; fi          # symlink = external/framework
  if [ ! -f "$d/SKILL.md" ]; then excluded=$((excluded + 1)); continue; fi # container dir, not a skill
  if git -C "$SKILLS_DIR" check-ignore -q "$skill" 2>/dev/null; then
    excluded=$((excluded + 1)); continue                                  # gitignored = machine-generated
  fi
  echo "$skill"
  found=$((found + 1))
done
echo "(excluded: $excluded external/framework/generated)" >&2

if [ "$found" -eq 0 ]; then
  echo "⚠️ No personal skills detected. Either none exist yet, or ~/.claude/skills" >&2
  echo "   is not wired by link.sh (externals must be symlinks for this split to hold)." >&2
  exit 1
fi
```

## Steps

1. Run the detection command above to get the list of personal skill names.
2. For each personal skill, read the first 20 lines of its `SKILL.md`.
3. Extract `description` from the YAML frontmatter. Handle BOTH formats:
   - **Inline**: `description: Some text here` → take everything after `description: `
   - **Block scalar**: `description: |` → take the next indented line, trimmed
4. Also extract the agent file it references (the `.md` filename from `~/.claude/agents/`), or `—` for self-contained skills.
5. Display a clean table with three columns: **Skill**, **Agent**, and **Description** (first line of description only, trimmed).
6. At the end, show the total count of personal skills (and mention how many framework skills were excluded).

## Output format

```
## Personal Skills (~/.claude/skills/)

| Skill | Agent | Description |
|-------|-------|-------------|
| feat  | feater.md | Small feature implementation (1-5 files)... |
| ...   | ... | ... |

**Total: N personal skills** (M framework/external skills excluded)
```

Keep descriptions to one line (~80 chars max, truncate with "..." if needed).

## Known limits of the detection heuristic

- **False positive:** a framework skill COPIED (not symlinked) into
  `~/.claude/skills/` reads as personal. Mitigation: keep externals symlinked —
  `link.sh` does; re-run it if an install went sideways.
- **Machine-generated dirs** are caught only when `~/.claude/skills` resolves
  into a git repo whose `.gitignore` marks them; outside that layout they are
  listed as personal. The stderr `excluded:` count makes an implausible split
  visible (e.g. `excluded: 0` on a tree known to hold gstack symlinks).
- **Description extract edge cases:** plain multi-line YAML (no `|`/`>`) is
  read as first line only. For users of `description: |` block scalars this is
  intended; otherwise inspect raw `SKILL.md` if a description looks truncated.
- **Override:** to adopt a framework skill as your own, fork it into a real
  directory under `~/.claude/skills/` (drop the symlink). The fork is then
  yours to maintain and is listed as personal.
