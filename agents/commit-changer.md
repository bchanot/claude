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

### Phase 2.5: Checkpoint — present plan, get approval

Before any `git add` or `git commit` runs, present the reconstructed plan:

```
COMMIT PLAN — <N> step(s) from working tree

  1. <type>(<scope>): <short description>
     files: <a.ts, b.css, c.md>
  2. <type>(<scope>): <short description>
     files: <d.py>
  ...

Approve? (all / <numbers> / edit <n> / skip)
```

- `all` → execute the full plan in Phase 3.
- `<numbers>` (e.g. `1,3`) → execute only the selected steps.
- `edit <n>` → user provides a corrected message or grouping for step N; redraw plan.
- `skip` → exit cleanly, no commits created.

This gate is mandatory. Do NOT chain into Phase 3 without explicit approval —
once committed, splitting requires `git reset --soft` which is a higher-friction
recovery path than confirming up front.

### Phase 3: Execute commits

After approval in Phase 2.5, for each approved step in chronological order:

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

### Phase 4: Capitalize (memory registries)

After all commits are created, inspect the set as a whole:

- Any commit that represents a **design/architecture choice** (new dependency,
  refactor with rationale, API shape decision) → propose an entry in
  `.claude/memory/decisions.md` (BDR-XXX) with pre-filled alternatives.
- Any commit that resolves a **non-trivial bug with a root cause** → propose
  an entry in `.claude/memory/blockers.md` (BLK-XXX, status: resolved).
- Any commit whose content taught something **reusable beyond the immediate fix**
  (a pattern, a gotcha, a surprising API behaviour) → propose an entry in
  `.claude/memory/learnings.md` (LRN-XXX).

Present grouped candidates:
```
CAPITALIZE — depuis les <N> commits créés
  [decisions.md]   BDR-XXX — <titre> (ref commit <hash>)
  [blockers.md]    BLK-XXX — <friction> — resolved (ref commit <hash>)
  [learnings.md]   LRN-XXX — <pattern>
Valider ? (all / <IDs> / edit / skip)
```

Append approved entries + update the Index of each registry file. Add a line to today's heading in `.claude/memory/journal.md` summarising the commit batch.

**Language rule**: written entries are ALWAYS in English (see CLAUDE.md "Memory registries" § Language). The interactive gate may mirror the user's language; the appended entries must not.

If all commits are pure chore/docs/style with nothing to log → skip with `CAPITALIZE: nothing to log`.

**Then commit the memory** — follow `$HOME/.claude/lib/capitalize-commit.md`: it
surgically commits what capitalize just wrote (`.claude/memory` + `.claude/tasks`
only, never `git add -A`) as one `chore(memory)` commit, reports the memory-commit
hash, and no-ops if nothing was written. This is a separate commit from the Phase 3
code commits — their hashes are already anchored inside the entries.
