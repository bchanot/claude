# Coupled-capitalize Invariant — Implementation Plan (v1)

> Frozen 2026-06-26. Frame 2 (capitalize AFTER code commit, hash anchoring kept,
> 2 commits kept) — make the memory commit automatic & never-forgotten, coupled
> per dev flow. Hook = v2 (separate). doc-sync = twin chantier (same PR bug,
> queued). NO `git add -A` ever — safety lives in the pathspec.

**Goal:** every dev flow that commits code also capitalizes AND commits its
memory automatically, in the same breath, via a shared include — without
duplicating logic and without ever embarking dangling code.

**Architecture:** `lib/memory-commit.sh` (detect + surgical commit scoped to
`.claude/memory` + `.claude/tasks`, never `-A`) + include `lib/capitalize-commit.md`
referenced by the 6 flows (design-gate.md pattern). ship-feature reordered
(capitalize before FINISH) to fix the PR-stranding bug.

## Global Constraints (verbatim, apply to every task)
- Stage: `git add -- .claude/memory .claude/tasks`. Commit: `git commit -m <msg> -- .claude/memory .claude/tasks`. NEVER `git add -A` / `git add .` / `git commit -a`.
- Idempotent: clean tree → no-op, exit 0, no commit.
- Fail-closed on broken state: detached HEAD / merge / rebase / cherry-pick in progress → no commit, skip (exit 3).
- Registries always English. Commit msg style: `chore(memory): <IDs> — <flow> <short>`.
- Capitalize CONTENT keeps its approval gate (unchanged); only the COMMIT of approved entries becomes automatic.
- shellcheck clean on `lib/memory-commit.sh` + test harness.

## File Structure
| Action | File | Responsibility |
|---|---|---|
| Create | `lib/memory-commit.sh` | detect + surgical commit (CLI + sourceable) |
| Create | `lib/capitalize-commit.md` | include protocol |
| Create | `lib/tests/run-deterministic.sh` | T1–T5 + T2-bis, git fixture via mktemp |
| Create | `lib/tests/run-behavioral.md` | end-to-end manual per-flow check |
| Modify | `agents/feater.md` | STEP 6 → reference include |
| Modify | `agents/hotfixer.md` | STEP 5 → reference include |
| Modify | `agents/bugfixer.md` | STEP 7 → reference include |
| Modify | `agents/commit-changer.md` | Phase 4 → reference include |
| Modify | `skills/ship-feature/SKILL.md` | reorder capitalize before FINISH + reference |
| Modify | `skills/init-project/SKILL.md` | net-new capitalize founding decisions (F5) before FINISH |
| Modify | `CHANGELOG.md` + `.claude/memory/` | document the invariant (BDR + LRN) |

## Tasks
- **Task 1** — `lib/memory-commit.sh` (TDD). Tests T1, T2, **T2-bis**, T3, T4, T5
  MUST be REALLY EXECUTED with real outputs reported before Task 2 (user hard
  requirement — no presumed git behavior).
  - T1: untracked dangling code NOT embarked.
  - T2: pre-staged dangling code NOT embarked, remains staged.
  - **T2-bis: stale-staged memory (version A) vs working-tree (version B) →
    commit must contain B (what capitalize wrote), not A.** Proves `git add --`
    re-stage neutralizes stale index. If raw pathspec-commit took A → guard needed.
  - T3: idempotence (clean → no-op exit 0). T4: unsafe state → skip exit 3.
    T5: TODO.md embarked.
- **Task 2** — `lib/capitalize-commit.md` include (WHEN / DO / HARD RULE / ORDERING / IDEMPOTENT).
- **Task 3** — wire feater/hotfixer/bugfixer/commit-changer (1-line reference each).
- **Task 4** — ship-feature reorder: 7=CAPITALIZE(+include), 8=FINISH, 9=DOC SYNC; renumber FAILURE PATHS; doc-sync stays post-FINISH (twin chantier note).
- **Task 5** — init-project: add STEP 10.6 CAPITALIZE FOUNDING DECISIONS (F5 filter table: structuring decision = capitalize, scaffold detail = skip) before STEP 11 FINISH.
- **Task 6** — behavioral verify + shellcheck + CHANGELOG + BDR/LRN (dogfood the include).

## Deferred (explicit, by design not by omission)
- Hook (Stop, non-blocking, stateless, BDR-033 style) → v2.
- doc-sync PR-stranding (same reorder-before-FINISH) → twin chantier.
- hash-anchoring vs squash-merge → known blind spot, out of scope.
