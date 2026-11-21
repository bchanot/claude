# PLAN — deferred-citers (/feat, 2026-11-21 21:08)

Contract: `.claude/tasks/contracts/2026-11-21-deferred-citers-2108.md`. Base 828f328.

Challenge: skipped (placed decision: deferred-stop rule ca65852, user 2026-11-21). The three conditions hold: the text only repoints three citers at the rule; the rule was challenged in the run that wrote it and the user answered its deferred points; /feat runs lib/verify-secure-loop.md after its dispatch. The skip discharges the plan advisor point.

PLAN:
  [ ] skills/feat/SKILL.md:135-136: "surfacing any deferred BLOCKER in the STEP 1 pass B batch" → "and stop once on any `[deferred]` point (keep / cut / reopen, `lib/challenge-plan.md` § OUTPUT)".
  [ ] skills/bugfix/SKILL.md:140-141: same repoint (was "folding any deferred BLOCKER into the STEP 3 approval gate").
  [ ] skills/hotfix/SKILL.md:105-106: insert "A `[deferred]` point: /hotfix asks keep / cut / reopen itself (`lib/challenge-plan.md` § OUTPUT)." before the BLOCKER-escalation sentence, which stays.

Disposition: honors BDR-151 lever 3 (placed-decision skip) and the ca65852 rule; LRN-297 (rule restated at the act site).

## EXACT DIFF (against 828f328)

```diff
diff --git a/skills/bugfix/SKILL.md b/skills/bugfix/SKILL.md
index 223e7cd..fea2981 100644
--- a/skills/bugfix/SKILL.md
+++ b/skills/bugfix/SKILL.md
@@ -137,8 +137,8 @@ dispositions. Three blind challengers attack it (correctness = is the root cause
 right; robustness = blast radius / regressions; simplicity = is the fix minimal);
 RE-THINK every aspect a BLOCKER lands, re-challenge once if the plan materially
 changed. STEP 3.5 writes the contract from the REVISED plan. Print a CHALLENGE SUMMARY
-(BLOCKERs addressed / deferred / lenses returned / advisor), folding any
-deferred BLOCKER into the STEP 3 approval gate.
+(BLOCKERs addressed / deferred / lenses returned / advisor), and stop once on any
+`[deferred]` point (keep / cut / reopen, `lib/challenge-plan.md` § OUTPUT).
 
 ## STEP 3.5 — CONTRACT
 
diff --git a/skills/feat/SKILL.md b/skills/feat/SKILL.md
index 9f6ffcb..35ab68a 100644
--- a/skills/feat/SKILL.md
+++ b/skills/feat/SKILL.md
@@ -132,8 +132,8 @@ Persist it to `.claude/tasks/plans/<date>-<slug>-<HHMM>.md`, then run
 Three blind challengers attack it; RE-THINK every aspect a BLOCKER lands (a named
 plan change, or `[deferred]`), re-challenge once if the plan materially changed. The
 STEP 3 executor receives the REVISED plan. Before dispatch, print a CHALLENGE SUMMARY
-(BLOCKERs addressed / deferred / lenses returned / advisor), surfacing any
-deferred BLOCKER in the STEP 1 pass B batch.
+(BLOCKERs addressed / deferred / lenses returned / advisor), and stop once on any
+`[deferred]` point (keep / cut / reopen, `lib/challenge-plan.md` § OUTPUT).
 
 ## STEP 2 — BRANCH
 
diff --git a/skills/hotfix/SKILL.md b/skills/hotfix/SKILL.md
index 2c7b62e..de1d556 100644
--- a/skills/hotfix/SKILL.md
+++ b/skills/hotfix/SKILL.md
@@ -103,7 +103,8 @@ contract's acceptance criteria. Three blind challengers attack the fix; the main
 loop RE-THINKS any aspect a BLOCKER lands (a named change to the fix, or
 `[deferred]`) and re-challenges once if it materially changed. Print a
 CHALLENGE SUMMARY (BLOCKERs addressed / deferred / lenses returned / advisor).
-A BLOCKER that shows the fix is wrong or incomplete means this was never
+A `[deferred]` point: /hotfix asks keep / cut / reopen itself
+(`lib/challenge-plan.md` § OUTPUT). A BLOCKER that shows the fix is wrong or incomplete means this was never
 a hotfix — escalate to `/bugfix` (its STEP 3b runs the same phase under the full
 verify+secure loop).
 
```
