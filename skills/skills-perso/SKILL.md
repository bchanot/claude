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

A skill is **personal** if it satisfies AT LEAST ONE of these signals (in priority order):

1. **Explicit marker** — frontmatter contains `owner: user` (preferred — unambiguous, future-proof)
2. **Agent-reference heuristic** — SKILL.md body references an agent file from `~/.claude/agents/` on a non-comment line
3. **Allowlist** — skill name is in the explicit allowlist below (for self-contained personal skills that do not delegate)

Allowlist of self-contained personal skills (no agent delegation): `skills-perso`.

Framework / gstack skills always FAIL all three signals — that is how they are excluded.

Run this command to get the list of personal skills:

```bash
ALLOWLIST="skills-perso"

is_personal() {
  local skill_file="$1" skill_name="$2"
  # Signal 1: explicit marker
  if grep -qE '^owner:[[:space:]]*user\b' "$skill_file" 2>/dev/null; then
    return 0
  fi
  # Signal 2: agent reference on a non-comment line
  if grep -nE '\$HOME/\.claude/agents/|~/\.claude/agents/|\.claude/agents/' "$skill_file" 2>/dev/null \
     | grep -vE '^[0-9]+:[[:space:]]*(#|<!--|//)' \
     | grep -q .; then
    return 0
  fi
  # Signal 3: allowlist
  for allowed in $ALLOWLIST; do
    [ "$skill_name" = "$allowed" ] && return 0
  done
  return 1
}

found=0
for dir in ~/.claude/skills/*/; do
  [ -L "${dir%/}" ] && continue        # skip symlinks (external)
  skill=$(basename "${dir%/}")
  skill_file="${dir}SKILL.md"
  [ -f "$skill_file" ] || continue
  if is_personal "$skill_file" "$skill"; then
    echo "$skill"
    found=$((found + 1))
  fi
done

if [ "$found" -eq 0 ]; then
  echo "⚠️ No personal skills detected. Either only framework skills installed," >&2
  echo "   or no SKILL.md carries 'owner: user' marker / agent reference." >&2
  echo "   To mark a skill as personal, add 'owner: user' to its frontmatter." >&2
  exit 1
fi
```

## Steps

1. Run the detection command above to get the list of personal skill names.
2. For each personal skill, read the first 20 lines of its `SKILL.md`.
3. Extract `description` from the YAML frontmatter. Handle BOTH formats:
   - **Inline**: `description: Some text here` → take everything after `description: `
   - **Block scalar**: `description: |` → take the next indented line, trimmed
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

## Known limits of the detection heuristic

- **False positive (rare):** agent references buried in fenced code blocks
  (` ``` ... ``` `) match Signal 2 even though they are not active delegations.
  Mitigation: skill author adds `owner: user` (Signal 1) — explicit always wins.
- **False negative:** personal skills that delegate to agents under non-standard
  paths (e.g. `~/.config/myagents/`, `agents-shared/`) won't match Signal 2.
  Mitigation: same — add `owner: user` to frontmatter.
- **Frontmatter malformed / missing:** `is_personal()` returns false (skill
  silently excluded). The "0 personal skills detected" diagnostic catches the
  zero case but not partial misses.
- **Description extract edge cases:** plain multi-line YAML (no `|`/`>`) is
  read as first line only. For users of `description: |` block scalars this is
  intended; otherwise inspect raw `SKILL.md` if a description looks truncated.
- **Override:** to force-include a framework skill, fork it into `~/.claude/skills/`
  and add `owner: user`. The fork is then yours to maintain.
