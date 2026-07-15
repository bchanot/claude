---
name: commit-change
description: |
  Analyze all pending changes (staged, unstaged, untracked) and create
  atomic commits grouped by logical unit, retracing the work. Any git
  repository.
  Triggers: "commit my changes", "smart commit", "auto commit", "commit
  everything", "analyse et commit", or any variation of committing messy
  pending work intelligently.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

# /commit-change — propose → confirm → apply dispatcher

Grouping and committing both run on the sonnet-pinned `commit-changer`
subagent (dispatch makes the pin effective). No inline reflection happens
in this dispatcher to protect, so there is no model gate. This dispatcher
owns the two approval gates that used to live inside the subagent:
commit-plan approval and capitalize approval — the subagent never asks;
`MODE: propose` only proposes, `MODE: apply` only executes what this
dispatcher confirms. Never auto-commit blind — a wrong group is harder to
undo than not committing.

## STEP 0 — Pre-flight (STOP conditions, before any dispatch)

```bash
git rev-parse --abbrev-ref HEAD                        # "HEAD" = detached
git status --porcelain=v1 | grep -c '^UU\|^AA\|^DD'     # unmerged conflicts
git status --porcelain=v1 | wc -l                       # nothing pending?
git config user.email
```

- Detached HEAD → STOP, report the state, do not dispatch.
- Any unmerged conflict entries (`UU`/`AA`/`DD`) → STOP, tell the user to
  resolve conflicts first, do not dispatch.
- Nothing pending (`git status --porcelain` empty) → STOP, tell the user
  there's nothing to commit.
- `git config user.email` empty → STOP, ask the user to configure identity
  first, do not dispatch.

On a protected base (`main`/`develop`) the subagent runs the gitflow
aiguillage itself inside `MODE: propose` (its Phase 0) and branches to
`chore/*` before drafting the plan — code never lands directly on a
protected branch.

## STEP 1 — Propose

```
Agent(subagent_type="commit-changer")
prompt: "MODE: propose
$ARGUMENTS"
```

Read the returned `COMMIT PLAN` + `EDGE CASES` + `CAPITALIZE CANDIDATES`,
terminated by `READY TO APPLY — awaiting dispatcher confirmation`.

The subagent reported `BLOCKED: unresolved merge conflicts...` instead of a
plan (a race with STEP 0) → STOP, surface it, do not proceed.

## STEP 2 — Gate 1: commit-plan approval

Show the `COMMIT PLAN` and any `EDGE CASES` verbatim, then:

```
AskUserQuestion:
  Approve the commit plan? (all / <numbers> / edit <n> / skip)
```

- `all` → every step in the plan is approved as-is.
- `<numbers>` (e.g. `1,3`) → only those steps are approved; the rest stay
  uncommitted for a later run.
- `edit <n>` → collect the corrected message/grouping for step N from the
  user, redraw the plan (this dispatcher owns the text, no re-dispatch
  needed), show it again and re-ask.
- `skip` → exit cleanly, no commits created, no `MODE: apply` dispatch.

## STEP 3 — Gate 2: capitalize approval

If the STEP 1 output said `CAPITALIZE: nothing to log`, skip this gate —
treat the capitalize entries as `none` and go straight to STEP 4.

Otherwise show the `CAPITALIZE CANDIDATES` block, then:

```
AskUserQuestion:
  Valider les entrées mémoire ? (all / <IDs> / skip)
```

- `all` → every candidate entry is approved verbatim.
- `<IDs>` (e.g. `BDR-041,LRN-019`) → only those entries are approved.
- `skip` → no memory write; `MODE: apply` still runs for the code commits.

## STEP 4 — Apply

```
Agent(subagent_type="commit-changer")
prompt: "MODE: apply
APPROVED PLAN: <the STEP-2-approved steps — numbers, messages, files,
  exactly as confirmed, including any edits>
APPROVED CAPITALIZE ENTRIES: <the STEP-3-approved entries verbatim, or none>"
```

Parse the `COMMIT-EXEC REPORT`:
- `STATUS: DONE` → report the `COMMITS` + `MEMORY` hashes to the user.
- `STATUS: BLOCKED` → surface the blocker verbatim and stop. Do not retry
  automatically — a blocked step (e.g. one file needs an interactive
  `git add -p` split) needs a human decision.
