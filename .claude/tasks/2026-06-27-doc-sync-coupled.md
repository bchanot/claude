# Doc-sync Coupled — Implementation Plan (v1)

> Frozen 2026-06-27. Twin of coupled-capitalize ([[BDR-034]]), same PR-stranding
> class — but NOT the same fix. The deferred note ("reorder before FINISH") was
> REFUTED in analysis: doc-syncer commits NOTHING (proven, zero `git commit`/`add`),
> so reordering uncommitted docs still misses the merge/PR. Real fix = REORDER **+**
> CREATE a doc-commit mechanism (it does not exist; memory already had one).
> NO `git add -A` ever — safety lives in the (dynamic) pathspec.

**Goal:** every orchestrator flow that syncs public docs also COMMITS those docs
automatically, on the branch, BEFORE FINISH integrates it — so doc patches reach
the merge/PR instead of stranding uncommitted in the working tree.

**Architecture:** `lib/doc-commit.sh` (surgical commit of ONLY the files doc-sync
patched this run, passed as args, filtered to changed paths, never `-A`, hard-guard
excluding `.claude/`+`CLAUDE.md`) + include `lib/doc-commit.md` referenced by the 2
orchestrators at their doc-sync step. Both orchestrators reordered (doc-sync before
FINISH). Mirror of `memory-commit.sh` + `capitalize-commit.md` with **4 deltas**:

| # | memory-commit (twin) | doc-commit (this) | Why |
|---|---|---|---|
| Δ1 | fixed scope `.claude/memory`+`.claude/tasks` | **dynamic** — patched-file list as args | docs scatter across an enumerable set; commit only what was touched |
| Δ2 | TARGETS `.claude/` | **hard-guard EXCLUDES** `.claude/`+`CLAUDE.md` | BDR-022 — inverse scope; defense-in-depth |
| Δ3 | 2-hash dance (code hash anchored in entries) | **no hash** — docs carry no SHA | LRN-052 — anchoring N-A to docs |
| Δ4 | `chore(memory): <IDs> — <flow>` | `docs: <summary> — <flow>` | separate concern, mirror |

**Consumption = MECHANICAL** ([[LRN-057]] case a, = BDR-034): commit on the branch
before FINISH, the merge carries it. No external-cognitive injection needed.

## Conscious acknowledgments (state them, don't paper over)
- **Partial init-project fix.** After this chantier: ship-feature FULLY fixed;
  init-project PARTIAL — doc-sync ok, but scaffold + 5b-bootstrap-README commit
  gap stays open ([[BLK-010]]). doc-commit must NOT ramasse the bootstrap README —
  not its job (would re-create the over-reach we ban). Do NOT believe init-project
  repaired while the scaffold hole remains.
- **MINOR doc content is non-gated yet auto-committed.** This is a CONSCIOUS choice,
  NOT "same as memory": memory CONTENT was always gated, so auto-commit only ever
  embarked approved entries. doc-sync auto-mode patches MINOR silently (no gate).
  Resolution: surface-don't-block. MINOR is factual (command/param/path/version/dead
  link — same bar as AUTO patches); a blocking gate = friction disproportionate, and
  the PR diff re-shows it. The doc-commit's **visible** surface REPLACES the gate as
  the review surface — `✅ committed README, USAGE — <summary of what changed>`,
  NOT a bare count. Strengthening the MINOR gate itself = separate doc-syncer chantier.

## Global Constraints (verbatim, apply to every task)
- Stage/commit ONLY the files doc-sync patched this run, passed as args. NEVER `git add -A` / `git add .` / `git commit -a`. NEVER stage anything under `.claude/**` or `CLAUDE.md` (hard guard — BDR-022, inverse of memory-commit).
- Dynamic pathspec: filter the passed list to paths with real pending changes (LRN-051 — `git commit -- <no-match>` ABORTS the whole commit; `git add` tolerates). A clean/absent passed path is dropped, not fatal.
- Partial-commit safety: `git commit -- <changed-paths>` ignores the rest of the index → dangling code (untracked OR pre-staged) is never embarked.
- Idempotent: empty list / clean tree → no-op, exit 0, no commit.
- Fail-closed: detached HEAD / merge / rebase / cherry-pick in progress → no commit, skip (exit 3).
- NO hash anchoring — docs carry no SHA (LRN-052). Commit msg `docs: <summary> — <flow>`.
- Surface is VISIBLE: report committed files + a one-line change summary, not just a count.
- shellcheck clean on `lib/doc-commit.sh` + test harness.

## File Structure
| Action | File | Responsibility |
|---|---|---|
| Create | `lib/doc-commit.sh` | dynamic-scope surgical doc commit (CLI + sourceable), inverse-exclusion guard |
| Create | `lib/doc-commit.md` | include protocol (mirror capitalize-commit, 4 deltas, visible surface) |
| Create | `lib/tests/run-doc-commit.sh` | TDD: inverse-exclusion + dynamic-pathspec + dangling + stale-index + idempotent + unsafe, real git fixture |
| Modify | `agents/doc-syncer.md` | add `PATCHED_FILES:` block to OUTPUT (STEP 9) + AUTO MODE (STEP A4); no logic change, callers unaffected |
| Modify | `agents/feater.md` · `bugfixer.md` · `hotfixer.md` | **Task 6b (sweep-found scope expansion)** — wire doc-commit into each DOC SYNC step |
| Modify | `skills/ship-feature/SKILL.md` | reorder DOC SYNC before FINISH + doc-commit include; DELETE HTML comment (lines 196–198); renumber FAILURE PATHS / FINAL OUTPUT |
| Modify | `skills/init-project/SKILL.md` | move SYNC README before FINISH (new STEP 10c) + doc-commit include; renumber `/13` PROGRESS PROTOCOL headers; conscious partial-fix note ([[BLK-010]]) |
| Modify | `README.md` · `USAGE.md` · `CHANGELOG.md` | ref-sweep (README:153, USAGE:196/256) + changelog entry |
| Append | `.claude/memory/` (BDR + LRN) | document the invariant at close |
| Append | `.claude/memory/blockers.md` | BLK-010 scaffold gap, BLK-011 GSD ROADMAP — **done this turn** |

## Tasks
- **Task 1** — `lib/doc-commit.sh` (TDD, same hard requirement as memory-commit:
  every test REALLY EXECUTED with real outputs reported before Task 2 — no presumed
  git behavior; Δ2 + Δ1 especially must be proven on real git).
  - **T1 inverse exclusion (Δ2):** a passed path under `.claude/` (e.g. `.claude/memory/x.md`) or `CLAUDE.md` is REJECTED — not committed, guard fires. The load-bearing delta vs memory-commit; prove it on real git.
  - **T2 dynamic pathspec (Δ1):** pass `[README.md, USAGE.md, DEPLOY.md]` where only README+USAGE changed → commit contains exactly README+USAGE; the clean DEPLOY.md path is filtered, commit does NOT abort (LRN-051).
  - **T3 dangling not embarked:** untracked AND pre-staged non-doc code (`src/x`) NOT in the doc commit, stays untracked/staged.
  - **T4 stale-index:** doc staged as version A, working-tree version B → commit contains B (`git add --` re-stage neutralizes stale index). Mirror of memory T2-bis.
  - **T5 idempotent:** empty list / clean → no-op exit 0, no commit. **T6 unsafe:** detached HEAD / merge in progress → exit 3, no commit.
- **Task 2** — `lib/doc-commit.md` include (WHEN / DO / HARD RULE surgical / ORDERING before FINISH / IDEMPOTENT / VISIBLE-SURFACE report / no-hash note / inverse-scope vs capitalize-commit). State the 2 conscious acknowledgments inline.
- **Task 3** — `agents/doc-syncer.md`: add `PATCHED_FILES:` (newline-separated real paths, or empty) to STEP 9 OUTPUT + AUTO MODE STEP A4. Additive, no logic change, `auto-mode scope:` contract unchanged → callers unaffected (BDR-022 preserved). Future-proofs the isolated-subagent invocation; in-thread, the list is already in hand.
- **Task 4** — ship-feature reorder: STEP 8 = DOC SYNC (was 9, + doc-commit include), STEP 9 = FINISH (was 8). DELETE the twin-chantier HTML comment. Renumber FAILURE PATHS + FINAL OUTPUT refs. Pipeline stays "9-step".
- **Task 5** — init-project reorder: new STEP 10c = DOC SYNC (moved from 12, + doc-commit include) after STEP 10b CAPITALIZE, before STEP 11 FINISH; old STEP 13 GSD → STEP 12. Update PROGRESS PROTOCOL `/13` headers. Add the conscious partial-fix note pointing at [[BLK-010]] (scaffold/bootstrap still open) + [[BLK-011]] (GSD ROADMAP).
- **Task 6** — ref-sweep: README:153, USAGE:196, USAGE:256, CHANGELOG. Grep READS not just WRITES (LRN-002/LRN-045). Result: live refs all fixed in Task 4/5, no old headers survive, historicals left. **Sweep also caught the inline-flow gap → Task 6b.**
- **Task 6b — SCOPE EXPANSION (sweep-found, NOT in the original frozen plan — honesty).** feat/bugfix/hotfix each have a DOC SYNC step that patched docs but committed nothing → docs left dirty (milder than PR-strand, same class; the asymmetry vs memory is the decider — BDR-034 wired ALL flows). Wire doc-commit into each (1-line include + paragraph, mirror of capitalize-commit). Set = the 3 flows that doc-sync, NOT all 4 capitalize flows: commit-change has no DOC SYNC. hotfix IS wired (its DOC SYNC is unconditional; only its CAPITALIZE is skip-by-default; the include no-ops on empty). We extend the mechanical REPLICATION of a built+tested mechanism; we defer NEW work (BLK-010/011).
- **Task 7** — behavioral verify doc (`lib/tests/` end-to-end check, ship-feature + init-project paths) + shellcheck + CHANGELOG entry + close with BDR + LRN. The closing BDR states the surface-replaces-gate choice HONESTLY (MINOR non-gated auto-committed) — not glossed as memory-equivalent.

## Deferred / flagged separate (by design, not omission)
- **[[BLK-010]]** scaffold + bootstrap-README commit gap (init-project; unborn HEAD + worktree) → own chantier. **Flagged this turn.**
- **[[BLK-011]]** GSD STEP 13 ROADMAP.md post-FINISH (3rd post-FINISH artifact) → own thread. **Flagged this turn.**
- Strengthening doc-sync's MINOR gate → separate doc-syncer chantier.
- doc-sync as isolated subagent (vs in-thread) → `PATCHED_FILES:` already future-proofs it; no work now.
