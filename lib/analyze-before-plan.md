# ANALYZE-BEFORE-PLAN — couple the memory read to the dev flow

Inline snippet. Include at the START of a dev flow, BEFORE the plan forms. This is the
HEAD of analyze; `capitalize-commit.md` is the TAIL. Read-before / write-after — the two
ends of one bookend: a flow consults the decisions / blockers / learnings it will later add to.

It does NOT decide the plan. It hands the planner a DISPOSED list of prior entries that
bear on the work, so the plan cannot form blind to a decision already in force or a
blocker already solved.

## WHEN TO RUN

- Inline flow (feat / bugfix): main thread, AFTER the related code is read, BEFORE the
  mini-plan / diagnosis. PASS 2 is bounded-tiny (selection narrows it); no subagent —
  preserves stay-light.
- Orchestrator with a code-analysis step (ship-feature / init-project): run it INSIDE the
  analyzer subagent. Its fresh context reads code + memory with zero redundancy against
  the main thread; only its compact digest returns. The analyzer's RELATED MEMORY output
  section IS this snippet's OUTPUT.
- hotfix: not wired by default (mirror of its capitalize skip). Available opt-in for a
  blockers-only quick check ("urgent bug déjà vu ?").

## DO

1. PRECONDITION — NO-OP unless `.claude/memory/` exists AND holds at least one registry
   file. TESTED reality: a bare `grep … .claude/memory/*.md` on an ABSENT dir (or a dir
   with no `.md`) does NOT no-op — the unmatched glob is passed literally and grep ERRORS
   (`No such file or directory`, exit 2). So the GUARD makes "absent → no-op", never the
   grep. This is init-project's STEP 2 reality: the registries are created at STEP 5, so at
   analyze time they are ABSENT — the guard must fire on absent, not merely on empty.

2. PASS 1 — list every entry, drift-proof, GUARDED:

       [ -d .claude/memory ] && ls .claude/memory/*.md >/dev/null 2>&1 \
         && grep -nE '^## (BDR|LRN|BLK|EVAL)-[0-9]+' .claude/memory/*.md

   One `ID — title` line per entry, for 100% of entries by construction (an entry IS its
   heading). A present-but-template-empty registry (header only) → grep exits 1 (clean
   no-match) → no-op naturally; only the ABSENT / no-file case needed the guard. The REGEX
   is the filter, not the file list: the glob also reads journal.md (date-keyed
   `## YYYY-MM-DD`) and any non-entry file, which contribute zero matches — no need to
   exclude them. Do NOT read the `## Index` table: it drifts (entries land in the body, the
   manual Index update lapses — measured 32-40% missing on a mature repo); headings cannot.

3. SELECT — IDs whose title bears on $REQUEST. Judge on titles (one dense line each), not
   on bodies. Over-inclusion is SAFE: an entry that proves non-binding costs one bare ref
   in OUTPUT, not a paragraph (see DISPOSITION) — so err toward including on a dense cluster.

4. PASS 2 — full-read ONLY the selected bodies (heading to next `##`) to recover
   status / why / solution / alternatives. Unconditional for the selected set — see THE
   INVARIANT for why there is no "skip if already in context" branch.

5. DISPOSE — emit RELATED MEMORY (OUTPUT). Every surfaced ID gets a verdict.

## OUTPUT — RELATED MEMORY (disposition, not a dump)

    RELATED MEMORY (read-before):
      IN FORCE — must constrain this work (detail each — they bite):
        - BDR-026 — <title> — <how it constrains> [accepted]
        - LRN-050 — <title> — <how it applies>
      ALREADY SEEN — known cause/fix, don't re-derive (detail each):
        - BLK-009 — <title> [upstream]
      NON-BINDING — superseded / N-A, COUNTED not detailed:
        - <c> surfaced, none binding — BDR-013, LRN-022, …   (bare refs, one line)
      SELECTION: scanned <N> headings / 4 registries —
                 surfaced <K> = in-force <a> + seen <b> + non-binding <c>.

- Disposition rule: DETAIL what binds (IN FORCE, ALREADY SEEN); COUNT what doesn't
  (NON-BINDING) as one line + bare refs. The collective verdict still disposes each
  non-binding ID — its bare ref under "none binding" IS its disposition — but a per-entry
  paragraph on a non-binding match dilutes the in-force ones that bite. On a dense cluster
  (K up to ~14) this is what keeps the 3 that matter from drowning under 11 that don't.
- Compact even for binding ones: ID + title + one-clause bearing. Bodies were read to
  JUDGE; only the disposition persists — never paste bodies into the plan.
- a + b + c = K: every surfaced ID is accounted for. An unaccounted surfaced ID is the gap
  this prevents.
- Nothing bears → `RELATED MEMORY: none of <N> entries bears on this task` (still proves
  PASS 1 ran — LRN-048).

## THE INVARIANT — disposition, not reading

The guarantee is NOT "the agent read the memory" (an act, unverifiable after the fact).
It is "the plan disposed of every relevant prior entry" (a list, verifiable in OUTPUT).
LRN-048 one step further: the teeth are "did it STATE a verdict on each surfaced ID?",
not "did it look?".

So there is no "skip PASS 2 if already in context" branch. "Already in context" has no
deterministic oracle: self-judgment is the rejected behavioral guard (LRN-046); a session
marker records "was read", not "still present", so it false-skips after a compaction (and
is the marker cost BDR-033 priced); the agent cannot grep its own window. PASS 2 reads the
selected set unconditionally — cheap by construction — and the invariant bites on the
disposition, which holds whether a body was freshly read or recalled.

A decision WRITTEN earlier in the same conversation (ship-feature posts BDR-035, then a
bugfix runs) MUST still be surfaced and disposed as in-force: content sitting in context
is not the current flow having TREATED it as a constraint. Re-surfacing is the feature.

## HARD RULE — read-only

Touches nothing. No write, no Index update, no memory mutation. Symmetric to
capitalize-commit's surgical scope (there: stage ONLY memory; here: stage NOTHING). Index
backfill, if ever wanted, is `/prune-memory` passe D — never this snippet.

## ORDERING (orchestrators only)

`superpowers:brainstorming` / `writing-plans` are external skills — we cannot make them
read our registries. So this runs BEFORE them, pre-loading the disposition into the plan
they form. Mirror of capitalize-commit running BEFORE finishing-a-development-branch: there
the memory commit must precede integration; here the memory read must precede planning.

## NO-OP / IDEMPOTENT

Empty or absent registries → silent no-op (greenfield init-project; onboard, which CREATES
memory and has none prior). Pure read → safe to run twice; naturally idempotent.

## WHAT THIS DOES NOT DO

- Does NOT read the related CODE — the flow does that (feat STEP 0, bugfix STEP 2). Sole
  exception: ship-feature, where the analyzer subagent this runs in reads code too (Gap A).
- Does NOT decide the plan — it primes it with a disposed list of constraints.
- Does NOT write or mutate memory — read-only; capitalize (write-after) is the other bookend.
- Does NOT depend on the `## Index` table — keys off `## <PREFIX>-` headings (drift-immune).
- Does NOT skip PASS 2 on an "already in context" guess — no oracle for it; the read is cheap.
