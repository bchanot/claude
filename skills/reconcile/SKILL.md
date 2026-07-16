---
name: reconcile
description: Use when you need the REAL open-work state of a project and the TODO or memory registries may be stale — "is the queue empty?", "what's left open?", "qu'est-ce qui reste", before /close, after a break, or when a checkbox/status looks doubtful. Confronts declared status (TODO checkboxes, registry statuses) against real git/fs state and surfaces the gaps. NOT memory curation (that is /prune-memory).
---

# /reconcile — declared vs real

## Overview
The open-work queue lies whenever a `[x]`/`[ ]` checkbox, a registry status, or an `## Index` row has drifted from what git/fs actually show. `/reconcile` answers "what is really left?" by **verifying**, never by **believing** a declarative source.

**Founding principle — recursive coherence:** never use a declarative source as an oracle (not the Index, not a checkbox, not a status claim, not a path name). Truth = registry BODY (`## ID —` headings), git, fs. The skill practices what it preaches — `lib/tests/run-reconcile.sh` T1 reds if the engine ever reads the Index.

## When to use
- "Is the queue empty / what's left to do?" — the naive answer (`grep '[ ]'`) is a mirror of the TODO and inherits all its lies.
- A checkbox or status looks doubtful; work suspected stale after merges/pushes.
- Before `/close`, or re-orienting after a break.

Not for: curating/compressing registries → `/prune-memory`. The skill never edits registry content (read-only here).

## How it runs
**REQUIRED ENGINE:** `lib/reconcile.sh` does the mechanical truth-probing. A capable agent CAN reconcile by hand — but burns ~50k tokens, depends on the question being phrased well, and still hits traps (compound status, a disclaimer instead of a check). The engine is deterministic, cheap, repeatable. Source it, then:

1. Enumerate registry entries from BODY headings (`reconcile_enumerate_ids`, never the Index).
2. Per declared item, run the matching oracle (`reconcile_oracle_*`, `reconcile_blk_current_status` = last block wins) and apply `reconcile_verdict`.
3. Classify into the four categories.
4. **Gate the write-back** (below).

## Output — four categories
1. **Actionable now** — open AND real state confirms not done.
2. **Blocked (external)** — `reconcile_blk_open`: current status upstream/open, not our code.
3. **Deferred** — lexically-marked follow-ups + `[~]` items (conditional triggers).
4. **TODO↔real gap** — declared ≠ verdict (open-but-done, done-but-open, partial-but-done).

Plus **contradiction candidates** — `reconcile_contradiction_candidates`: accepted-BDR ⇄ open-chantier overlap, surfaced for human review.

## The gate (mandatory)
**Before applying (A/B):** follow `$HOME/.claude/lib/gitflow-aiguillage.md` — TYPE `chore`. On `main`/`develop` the write-back branches to `chore/<name>` off develop first, so a reconciled TODO never lands direct on a protected base; on a working branch it applies in place. Never `gitflow finish` (human-gated).

Reconciling the TODO edits a tracked file → never silent. Show the proposed diff, then ask: **A** apply all · **B** select a subset · **C** touch nothing. Registries stay READ-ONLY (append-only; curation is `/prune-memory`).

## Honest limits (do not over-read the guarantee)
- Deferral detection is **lexical** — catches MARKED deferrals, misses unmarked ("à reprendre quand X"). Deterministic on the detectable; surface the ambiguous for human review, never assert.
- Contradictions are **candidates** (token overlap), not verdicts — a human confirms.
- Cross-repo items (oracle in another repo) → "not verifiable here", never flagged stale.
- Cross-reference verdicts ("[~] done because chantier X below is complete") are SURFACED, not auto-resolved.

## Common mistakes
- Grepping `[ ]` and reporting it as open → reproduces the lie. Run the oracle.
- Reading the `## Index` for status → inherits its drift (T1 forbids it).
- Writing a disclaimer ("à vérifier si déjà fait") instead of verifying → the engine verifies, it never hedges-and-advances.

## Validation
`bash lib/tests/run-reconcile.sh` → 25/25, shellcheck clean. Oracle of record = the 2026-06-29 inventory (7 gaps + 3 blocked + 5 deferred + 1 contradiction), fixtures frozen under neutral names in `lib/tests/fixtures/`.
