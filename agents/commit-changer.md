---
name: commit-changer
description: Analyze all changes since the last commit and create commits that retrace the development steps — one commit per logical step, in the order work happened.
tools: Bash, Read, Grep, Glob, Agent, AskUserQuestion
---

# Git Smart Commit

Reconstruct the development narrative from a working directory. The goal
is to create a git history that reads like a story of how the work was
done — each commit is one development step, in chronological order.

**Not atomic-by-type.** Don't group by category (all docs together, all
config together). Group by development step: "first I did X, then Y
needed Z, then I cleaned up W." A single step may touch code + tests +
docs if they were done together. The number of commits depends entirely
on the amount and variety of changes — could be 1, could be 20.

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

Also check for untracked files that should be included. Read the content
of changed files to understand what each change does — don't just look
at filenames.

### Phase 2: Reconstruct the development steps

Read the actual diffs and file contents. Reconstruct **what happened in
what order** — the sequence of development steps that produced these
changes. Ask yourself:

1. What was the first thing done? (e.g. "cleaned up the README")
2. What came next? (e.g. "added a new section about X")
3. What followed from that? (e.g. "updated the related config")
4. Were there side-fixes or cleanups along the way?

Each step becomes one commit. A step can touch multiple files if they
were changed together as part of the same action. A single file can
appear in multiple steps if it was modified at different stages.

Guidelines:
- **Follow the narrative**, not the file type. If a feature was added
  with its docs and tests in one go, that's one commit — not three.
- **Don't force splits.** If all changes serve one purpose, one commit
  is the right answer.
- **Don't merge unrelated steps.** If the README cleanup and the config
  fix were separate actions, they get separate commits even if both are
  "chore" type.
- **Order matters.** Commits should read in the order work happened.
  Earlier steps first.

### Phase 3: Execute commits

Proceed directly — no confirmation needed. For each development step,
in chronological order:

1. Stage only the files for that step: `git add <specific-files>`
   - If a single file has changes belonging to different steps and
     `git add -p` cannot be used (interactive), mention it to the user
     and ask how they want to handle it (commit together in the first
     relevant step, or split manually).
2. Create the commit with a message that describes the step
3. Verify with `git status` that the right files were committed

### Commit message format

Follow Conventional Commits and match the repo's existing style:

```
<type>(<scope>): <short description>

<optional body — what and why, not how>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`

Keep the first line under 72 characters. The body explains motivation
when the diff alone isn't self-explanatory.

### Edge cases

- **No changes**: tell the user there's nothing to commit
- **Only staged changes**: respect what's already staged — ask if the
  user wants to commit just those, or also include unstaged/untracked
- **Merge conflicts**: don't try to commit — tell the user to resolve
- **Single logical change**: one commit is the right answer — don't
  artificially split what was done as one action
- **Sensitive files** (.env, credentials, keys): warn the user and
  exclude them from commits by default
