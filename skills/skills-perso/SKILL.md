---
name: skills-perso
description: |
  List personal (user-created) skills from ~/.claude/skills/.
  Excludes framework/gstack skills and symlinked/external skills.
  Shows only skills the user wrote themselves.
  Trigger: "skills-perso", "mes skills", "list my skills", "quels skills", "skills perso".
argument-hint: ""
disable-model-invocation: false
allowed-tools:
  - Bash
  - Read
  - Glob
---

# skills-perso

List only **user-created** skills from `~/.claude/skills/`, excluding framework
(gstack) skills, symlinked directories, and external skills.

## How to detect user-created skills

Use git history to identify skills added in bulk commits (framework installs).
A skill is considered **framework** if its SKILL.md was first added in a commit
that also added 5+ other SKILL.md files. User-created skills are added in small
commits (1-3 SKILL.md files at a time).

Run this command to get the list of personal skills:

```bash
for dir in ~/.claude/skills/*/; do
  [ -L "${dir%/}" ] && continue
  skill=$(basename "${dir%/}")
  skill_file="${dir}SKILL.md"
  [ -f "$skill_file" ] || continue
  commit=$(git -C ~/Documents/claude log --diff-filter=A --format='%H' -1 -- "skills/${skill}/SKILL.md" 2>/dev/null)
  [ -z "$commit" ] && continue
  count=$(git -C ~/Documents/claude diff-tree --no-commit-id --name-only -r "$commit" -- 'skills/*/SKILL.md' 2>/dev/null | wc -l)
  [ "$count" -le 3 ] && echo "$skill"
done
```

## Steps

1. Run the detection command above to get the list of personal skill names.
2. For each personal skill, read the first 15 lines of its `SKILL.md`.
3. Extract `name` and `description` from the YAML frontmatter.
4. Display a clean table with two columns: **Skill** and **Description** (first line of description only, trimmed).
5. At the end, show the total count of personal skills (and mention how many framework skills were excluded).

## Output format

```
## Personal Skills (~/.claude/skills/)

| Skill | Description |
|-------|-------------|
| feat  | Small feature implementation (1-5 files)... |
| ...   | ... |

**Total: N personal skills** (M framework skills excluded)
```

Keep descriptions to one line (~80 chars max, truncate with "..." if needed).
