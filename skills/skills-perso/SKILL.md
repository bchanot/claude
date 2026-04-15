---
name: skills-perso
description: |
  List all personal skills installed in ~/.claude/skills/.
  Shows only local skills (excludes symlinked/external skills like gstack or emil-design-eng).
  For each skill, displays its name and description from SKILL.md frontmatter.
  Trigger: "skills-perso", "mes skills", "list my skills", "quels skills", "skills perso".
argument-hint: ""
disable-model-invocation: false
allowed-tools:
  - Bash
  - Read
  - Glob
---

# skills-perso

List all personal skills from `~/.claude/skills/`, excluding symlinked/external directories.

## Steps

1. List all directories in `~/.claude/skills/` that are NOT symlinks (use `find ~/.claude/skills -maxdepth 1 -mindepth 1 -type d -not -type l | sort`).
2. For each directory found, read the first 15 lines of `SKILL.md` if it exists.
3. Extract `name` and `description` from the YAML frontmatter.
4. Display a clean table with two columns: **Skill** and **Description** (first line of description only, trimmed).
5. At the end, show the total count.

## Output format

```
## Personal Skills (~/.claude/skills/)

| Skill | Description |
|-------|-------------|
| feat  | Small feature implementation (1-5 files)... |
| ...   | ... |

**Total: N skills**
```

Keep descriptions to one line (~80 chars max, truncate with "..." if needed).
Do NOT include symlinked directories (they point to external/shared skills).
