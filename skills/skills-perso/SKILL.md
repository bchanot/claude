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

A skill is **personal** if its SKILL.md references an agent file from
`~/.claude/agents/`. All user-created skills delegate work to a dedicated agent,
while framework/gstack skills do not.

Run this command to get the list of personal skills:

```bash
for dir in ~/.claude/skills/*/; do
  [ -L "${dir%/}" ] && continue
  skill=$(basename "${dir%/}")
  skill_file="${dir}SKILL.md"
  [ -f "$skill_file" ] || continue
  if [ "$skill" = "skills-perso" ] || grep -qE '\$HOME/\.claude/agents/|~/\.claude/agents/|\.claude/agents/' "$skill_file" 2>/dev/null; then
    echo "$skill"
  fi
done
```

## Steps

1. Run the detection command above to get the list of personal skill names.
2. For each personal skill, read the first 15 lines of its `SKILL.md`.
3. Extract `name` and `description` from the YAML frontmatter.
4. Also extract the agent file it references (the `.md` filename from `~/.claude/agents/`).
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
