---
name: gitflow
description: Use when a project needs gitflow branch operations — bootstrapping main+develop, starting a typed branch (feature/bugfix/release/hotfix), or integrating finished work by directed merge — or when an orchestrator must branch or merge under the gitflow model. Use when about to merge any branch into develop or main.
---

# gitflow

## Overview

The one place gitflow branch logic lives. The mechanics — branch, merge, hotfix
fan-out, init, `.gitignore` reconcile, the protected-base predicate — are in
`~/.claude/lib/gitflow.sh` (tested, deterministic). This skill governs **when**,
and bulletproofs the single judgment call: **`finish` merges only on an explicit
human signal.**

Replaces `finishing-a-development-branch` for gitflow flows — that skill is
single-target and cannot do the directed / fan-out merges below.

## When to Use

- An orchestrator (`ship-feature`) or an assistance skill (`feat`/`bugfix`/`hotfix`) must branch or merge.
- Bootstrapping a repo's branch model (`init-project`, `onboard`).
- You are about to integrate a finished branch into `develop` or `main`.

## Branch model

`main` (prod) · `develop` (integration, off main) · `feature/*` and `bugfix/*`
(off develop → develop) · `release/*` (off develop → main + back-merge develop)
· `hotfix/*` (off main → main + develop [+ any open release/*]).

## Operations — all via the lib

```
bash ~/.claude/lib/gitflow.sh init [msg]          # main+develop; root-commit (fresh) or ensure (existing); reconcile .gitignore; install hook
bash ~/.claude/lib/gitflow.sh start <type> <name> # branch from the correct base
bash ~/.claude/lib/gitflow.sh finish              # directed merge of the CURRENT branch — HUMAN-GATED (below)
bash ~/.claude/lib/gitflow.sh protected-base [br] # rc 0 on main/develop — the shared predicate
```

`finish` merges by the current branch's type:

| Current branch | Merges into | then |
|---|---|---|
| `feature/*` · `bugfix/*` | develop | delete |
| `release/*` | main + develop | delete |
| `hotfix/*` | main + develop + any open `release/*` | delete |

## The finish gate — merge ONLY on an explicit human signal

`finish` writes to shared branches (`develop`, `main`). Run it ONLY when the user
gives a **real-time, explicit go for THIS merge** — "merge it", "feature OK",
"finish it". Dev and testing happen out of git; finish never auto-fires.

**Violating the letter of this gate violates its spirit.**

| Rationalization | Reality |
|---|---|
| "Tests pass, so I'll merge." | Green = *ready to* merge, not *authorized*. Present "ready — merge?" and wait. |
| "The user said 'ship' / 'implement and ship'." | "Ship" ends at ready-to-merge **and ask**. The verb is not a merge signal. Pushing or opening a PR is still initiating integration — ask first. |
| "The plan's next step says 'merge into develop'." | A step written *before* the work cannot consent to integrating it. Stop at that step and ask. |
| "finish is the last pipeline step — I'll chain it." | The orchestrator STOPS at the finish gate and asks. Reaching it ≠ permission. |

### Red flags — STOP, do not finish

- About to run `gitflow finish` / `git merge` into develop or main, and the user has not, in THIS exchange, explicitly said to merge.
- The authorization you're leaning on is a plan step, a task description, or the word "ship" — not a live "merge it".
- "It's obviously done — surely they want it merged."

All of these mean: present the merge as a question, then wait for the explicit go.

## Aiguillage (assistance + standalone memory/doc skills)

On a protected base, assistance skills (`feat`/`bugfix`/`hotfix`) AND the standalone
memory/doc skills (`capitalize`/`close`/`prune-memory`/`reconcile`, TYPE `chore`)
call `start <type>` to branch first; on a working branch they commit in place. Same
`protected-base` predicate the out-of-skill hook uses. Caller→type map + rationale:
`lib/gitflow-aiguillage.md`.

## Common Mistakes

- Using `finishing-a-development-branch` for a gitflow merge → it can't do directed/fan-out merges. Use `gitflow finish`.
- Hand-writing `git merge` instead of `gitflow finish` → loses fan-out, branch delete, base sync.
- Calling `finish` because the work *looks* done → see the gate.
