---
name: commit-change
version: 1.0.0
description: |
  Analyze all changes since the last commit (staged, unstaged, untracked files)
  and create well-structured commits grouped by logical unit. Use this skill
  whenever the user says "commit my changes", "smart commit", "auto commit",
  "commit everything", "analyse et commit", or any variation of wanting to
  commit their pending work intelligently. Also trigger when the user has
  been working on multiple things and wants to create clean, atomic commits
  from their messy working directory. Works in any git repository.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

# Git Smart Commit

Create clean, atomic commits from a messy working directory. The goal is to
turn a pile of mixed changes into a well-organized git history that tells a
clear story — each commit focused on one logical change.

## Workflow

### Phase 1: Gather context

Run these commands to understand the full picture:

```bash
git status
git diff                    # unstaged changes
git diff --cached           # staged changes  
git diff HEAD --stat        # summary of all changes vs last commit
git log --oneline -5        # recent commit style
```

Also check for untracked files that should be included. Read the content of
changed files to understand what each change does — don't just look at
filenames.

### Phase 2: Analyze and group changes

Read the actual diffs and file contents to understand the intent behind each
change. Group changes into logical commits based on:

- **Purpose**: what problem does this change solve or what feature does it add?
- **Scope**: files that work together toward the same goal belong together
- **Type**: separate concerns (a bug fix shouldn't be bundled with a new feature)

Common groupings:
- Feature code + its tests + its docs = one commit
- Config/dependency changes = separate commit
- Unrelated bug fixes = each gets its own commit
- Formatting/style changes = separate from logic changes

### Phase 3: Execute commits

Proceed directly — no confirmation needed. For each logical commit group,
in order:

1. Stage only the files for that commit: `git add <specific-files>`
   - For partially changed files that belong to multiple commits, use
     `git add -p` is not available (interactive), so if a single file
     has changes belonging to different logical groups, mention it to
     the user and ask how they want to handle it (commit together, or
     split manually).
2. Create the commit with the agreed message
3. Verify with `git status` that the right files were committed

### Commit message format

Follow Conventional Commits and match the repo's existing style:

```
<type>(<scope>): <short description>

<optional body — what and why, not how>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`

Keep the first line under 72 characters. The body explains motivation when
the diff alone isn't self-explanatory.

### Edge cases

- **No changes**: tell the user there's nothing to commit
- **Only staged changes**: respect what's already staged — ask if the user
  wants to commit just those, or also include unstaged/untracked changes
- **Merge conflicts**: don't try to commit — tell the user to resolve first
- **Large number of changes**: still group logically, but warn the user if
  the working directory looks like it has many unrelated changes mixed together
- **Single logical change**: don't force multiple commits — one commit is fine
  if all changes serve the same purpose
- **Sensitive files** (.env, credentials, keys): warn the user and exclude
  them from commits by default
