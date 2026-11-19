# Feat plan: merge-reuse clause at the end-of-run sites (TODO:14, run 1 of 2)

## Why
lib/effort-shift.md § Advisor item 3 (:131-134): "In the six flows that run the gates (...), a later
merge proposal reuses the last run's answer, or its skip, and names any code commit made after it
(doc and memory commits excepted)." The end steps of a11y, guardrails, ship-feature, init-project
cite `lib/effort-shift.md` § Advisor but do not load it (LRN-297): at merge time the reuse rule is
not in front of the main loop, so a merge proposal either re-calls the advisor or reuses a stale
answer without naming the commits made since. User 2026-11-19: all 6 sites; this run = the 4
TODO:14 names (feat/bugfix next run, same branch; /feat 5-file cap).

## Disposition
- honors LRN-297 by restating one clause at the acting site, the lib keeps the full rule.
- honors LRN-268 / user "verbatim where it fits": item 3 wording, "the last run's answer, or its
  skip" → "this answer" (these four flows have no skip; "this" = the answer just named on the line).
- honors LRN-093: locks are single-line fragments; LRN-296: simulated on a scratch clone.
- honors BDR-100: grep "merge proposal" across skills/lib/agents/README/USAGE/CLAUDE.global → only
  lib/effort-shift.md:132 (unchanged, the source); no other citer to patch.
- BDR-150 unchanged (no new call point, no skip).

## FIX PLAN (exact text; each `old` occurs exactly once in its file)

1. skills/a11y/SKILL.md and 2. skills/guardrails/SKILL.md — same block in both.
### Block ag-old
```
   goes into the reply as an `Advisor:` line, and a fix it drives goes
   back through the gates.
```
### Block ag-new
```
   goes into the reply as an `Advisor:` line, and a fix it drives goes
   back through the gates. A later merge proposal reuses this answer and
   names any code commit made after it (doc and memory commits excepted).
```

3. skills/ship-feature/SKILL.md and 4. skills/init-project/SKILL.md — same block in both.
### Block si-old
```
its answer goes with the proposal as an `Advisor:` line, and a fix it
drives goes back through the gates.
```
### Block si-new
```
its answer goes with the proposal as an `Advisor:` line, and a fix it
drives goes back through the gates. A later merge proposal reuses this
answer and names any code commit made after it (doc and memory
commits excepted).
```

5. lib/tests/loops-light.test.sh
### Block t-vars-old
```
EFF="$REPO/lib/effort-shift.md"
```
### Block t-vars-new
```
EFF="$REPO/lib/effort-shift.md"
SFK="$REPO/skills/ship-feature/SKILL.md"
ISK="$REPO/skills/init-project/SKILL.md"
```
### Block t-locks-old
```
echo ""
echo "loops-light structure locks: $PASS pass, $FAIL fail"
```
### Block t-locks-new
```
echo "── end-of-run merge reuse at the site (TODO:14, LRN-297) ──"
tf "effort-shift merge reuse"  "$EFF" "reuses the last run's answer, or its skip, and names any code commit"
for f in "$ASK" "$GSK" "$SFK" "$ISK"; do
  n=$(basename "$(dirname "$f")")
  tf "$n merge reuses answer"  "$f" "the gates. A later merge proposal reuses this"
  tf "$n names later commits"  "$f" "names any code commit made after it"
  tf "$n doc/memory excepted"  "$f" "commits excepted)."
done

echo ""
echo "loops-light structure locks: $PASS pass, $FAIL fail"
```
Each fragment sits on one line in both wrap shapes (ag: 3-space indent; si: column 0); lock 1 anchors
the clause right after the gates sentence, lock 3 pins the polarity word, the `$EFF` lock pins the
source (lib/effort-shift.md:133). 78 → 91 pass.

## Edge cases
- ship-feature/init-project: the finish proposal follows the call in the same step; "later" covers a
  finish proposed after more commits land (user defers the go). Same sentence everywhere, no
  per-flow variant.
- Prose lines ≤ 80 cols (ag 72/73, si 70/70/62/18).

## Tests
lib/tests/loops-light.test.sh section above; full make test.
RISK: low — prose only, no rule change (item 3 already binds; the site now restates it).

## Deferred (challenge MINORs, logged at bookkeeping, not this run)
- item 3 reuse clause has no fallback when the end-of-run answer is absent (advisor absent/error) or out
  of view at the merge signal → candidate: "answer absent or out of view → the merge proposal runs the
  call" in lib/effort-shift.md item 3 (source, not the sites).
- end sites restate the call but not "one end-of-run call per skill run": a fix that goes back
  through the gates may re-enter the end step and call again.
- one branch can carry two end-of-run answers (a11y then guardrails): "this answer" = the latest run's;
  "names any code commit made after it" keeps the proposal truthful.
- run 2 (feat:210, bugfix:236) gets its own TODO line when TODO:14 is ticked; the branch is not
  merge-ready before run 2 lands.
