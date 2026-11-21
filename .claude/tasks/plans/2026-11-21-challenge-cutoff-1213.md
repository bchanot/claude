# FIX r3 — challenge-cutoff (/hotfix, 2026-11-21 12:13)

Contract: `.claude/tasks/contracts/2026-11-21-challenge-cutoff-1213.md`. Base develop 1d21b75.

## Why
- Cutoff: 2026-11-20 runs found MAJORs inside their own fixes at every confirmation pass (levers 9 then 2, follow-up 4 then 3); the `[gated]` point ended only because the main loop deferred it by judgement. The rule writes that judgement: the point is not revised again; it takes the existing `[deferred]` meaning (for the human to accept at the gate).
- Measure: the `TODO +n / -m` count lived only in chat; the memory-commit message now ends with it (examples included), readable with `git log --grep`.

## Edge cases
- "Touched" = a line one of the revision's named changes edited (challenge-plan already requires named changes); a finding elsewhere goes through normal synthesis, still capped at one extra pass.
- /hotfix has no human stop before its dispatch: a deferred point escalates to /bugfix (its existing BLOCKER path).
- /capitalize and /close write their own memory-commit messages (skills/capitalize STEP 5B) without the count: the MEASURE reads dev runs only; it starts at this commit (the MEASURE TODO line is re-anchored at capitalize).

## Challenge r1 (correctness CONCERNS(3), robustness CONCERNS(3), simplicity CONCERNS(1))
- ABANDON coupling + "the rest of the plan proceeds" (all three lenses, MAJOR): mechanism not asked for, contradicts ABANDON's "proven impossible", no path to GATE 2, missing in bugfix (contract after challenge) and hotfix (no gate) → both dropped; `[deferred]` keeps its existing meaning, the human decides before dispatch; hotfix escalates.
- "third time" off by one → "not revised again".
- MINORs taken: "touched" defined; message examples carry the suffix; /capitalize gap named.
- MINOR dropped: agents/plan-challenger.md protocol mirror (:136-137) restates the re-challenge without the cutoff (incomplete, not contradictory; hotfix 2-file cap).

## Challenge r2 (confirmation, correctness: CONCERNS(2)) — rule applied to its own run
- Both MAJORs landed on r2's additions (the "before any dispatch" stop, the /hotfix escape clause): four callers (feat, bugfix, seo, geo) have no human stop before dispatch; `[deferred]` got two meanings in one section. Not revised again: the additions are dropped back to the request's wording and the existing `[deferred]` meaning; the stop-before-dispatch question is deferred to the user (contract CLARIFICATIONS, TODO USER DECISION).
- MINOR taken: the message template carries ` · <todo>` too.
- MINOR dropped: "touched" over/under-capture (definition removed with the r2 text); reopen continuation (no reopen path in the shipped text); memory-feedback commits also carry the suffix through § DO (the MEASURE filters on dev flow subjects).

## EXACT DIFF (against develop 1d21b75)

```diff
diff --git a/lib/capitalize-commit.md b/lib/capitalize-commit.md
index 34a44f8..c6215a5 100644
--- a/lib/capitalize-commit.md
+++ b/lib/capitalize-commit.md
@@ -58,10 +58,10 @@ never a shell argument.
 ## DO
 
 1. Compose the message from the IDs just written + the flow, matching repo style
-   `chore(memory): <IDs> — <flow> <short>`. Examples:
-   - `chore(memory): BDR-034 + LRN-051 — feat dark-mode toggle`
-   - `chore(memory): BLK-010 resolved — bugfix profile path`
-   - `chore(memory): journal — hotfix copy typo`   (journal-only, nothing else)
+   `chore(memory): <IDs> — <flow> <short> · <todo>`. Examples:
+   - `chore(memory): BDR-034 + LRN-051 — feat dark-mode toggle · TODO +1 / -0`
+   - `chore(memory): BLK-010 resolved — bugfix profile path · TODO +0 / -1`
+   - `chore(memory): journal — hotfix copy typo · TODO +0 / -0`   (journal-only)
 
    Then, still before step 2, count the run's TODO movement as `<todo>`:
    `TODO +n / -m`, the open TODO items the run added and removed (closed or
@@ -81,6 +81,9 @@ never a shell argument.
          todo="TODO +$n / -$m"
        else todo="TODO n/a"; fi
 
+   The message composed above ends with ` · <todo>`, as in the examples, so
+   each run's movement reads in `git log --oneline --grep '· TODO'`.
+
 2. Commit surgically via the helper, capturing the memory-commit hash it prints:
 
        mem_hash=$(bash "$HOME/.claude/lib/memory-commit.sh" commit "<message>")
diff --git a/lib/challenge-plan.md b/lib/challenge-plan.md
index 2941ff1..51197b9 100644
--- a/lib/challenge-plan.md
+++ b/lib/challenge-plan.md
@@ -119,7 +119,10 @@ Parse each `CHALLENGE — LENS: … — VERDICT:` line and merge the FINDINGS:
   is tagged `[deferred <date>]` for the human to accept at the gate.
 - **Re-challenge once if the plan materially changed** — a fix can open a new
   flaw. Re-persist the revised `PLAN`, dispatch ONE fresh confirmation challenger,
-  max 1 extra pass, then the gate.
+  max 1 extra pass, then the gate. A BLOCKER or MAJOR that confirmation pass
+  still lands on a point the revision touched is not revised again: it is
+  tagged `[deferred <date>]` with the finding quoted, for the human to
+  accept at the gate.
 
 ## OUTPUT — into the existing human gate
 
```
