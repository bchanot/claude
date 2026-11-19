# Feat plan: merge-reuse clause at the feat/bugfix end lines (TODO:14, run 2 of 2)

## Why
Run 1 (af846d6) restated lib/effort-shift.md § Advisor item 3's merge-reuse clause at the a11y,
guardrails, ship-feature and init-project end steps. User 2026-11-19: all 6 sites; feat and bugfix
are the other two gate flows. Their end lines cite `lib/effort-shift.md` § Advisor without loading
it (LRN-297), and leaving them bare is the uneven restatement LRN-297 warns about. Same branch
feature/advisor-merge-reuse (/feat 5-file cap split the 6 sites in two runs).

## Disposition
- honors LRN-297: one clause read ahead at the run's end (feat/bugfix never propose the merge
  themselves; it comes at the user's later "merge it"), the lib keeps the full rule.
- honors LRN-268 / user wording: the scope question offered feat/bugfix "reuses the last run's
  answer, or its skip" (they can skip, unlike the four run-1 flows); text = item 3 verbatim.
- honors LRN-093 (single-line lock fragments), LRN-296 (scratch simulation), LRN-298 (lock 1
  anchored on "the gates." = placement after the gates sentence).
- 9814720's eight feat/bugfix skip locks sit on lines this run does not touch: the clause is
  appended after the final "through the gates." of each end line.
- BDR-100: "merge proposal" cited only by lib/effort-shift.md:132 and the run-1 sites.

## FIX PLAN (exact text; each `old` occurs exactly once in its file)

1. skills/feat/SKILL.md
### Block feat-old
```
goes into the summary's `ADVISOR` field, and a fix it drives goes back
through the gates.

Print summary:
```
### Block feat-new
```
goes into the summary's `ADVISOR` field, and a fix it drives goes back
through the gates. A later merge proposal reuses the last run's answer,
or its skip, and names any code commit made after it (doc and memory
commits excepted).

Print summary:
```

2. skills/bugfix/SKILL.md
### Block bug-old
```
   goes into the summary's `ADVISOR` field, and a fix it drives goes back
   through the gates.
4. Print summary:
```
### Block bug-new
```
   goes into the summary's `ADVISOR` field, and a fix it drives goes back
   through the gates. A later merge proposal reuses the last run's answer,
   or its skip, and names any code commit made after it (doc and memory
   commits excepted).
4. Print summary:
```

3. lib/tests/loops-light.test.sh — extend run 1's section (its loop's lock 1 ends "reuses this",
which does not match the feat/bugfix wording, so the two sites get their own loop).
### Block t-old
```
  tf "$n names later commits"  "$f" "names any code commit made after it"
  tf "$n doc/memory excepted"  "$f" "commits excepted)."
done
```
### Block t-new
```
  tf "$n names later commits"  "$f" "names any code commit made after it (doc and memory"
  tf "$n doc/memory excepted"  "$f" "commits excepted)."
done
for f in "$FSK" "$BSK"; do
  n=$(basename "$(dirname "$f")")
  tf "$n merge reuses answer"  "$f" "the gates. A later merge proposal reuses the last run's answer,"
  tf "$n reuse covers skip"    "$f" "or its skip, and names any code commit made after it (doc and memory"
  tf "$n doc/memory excepted"  "$f" "commits excepted)."
done
```
91 → 97 pass. Each fragment sits on one line in both indents. Lock 2 now reaches "(doc and memory" in
both loops (run 1's loop widened in place, same file, count unchanged) so the exception is pinned.
Each skill block runs through the next line ("Print summary:"), so a second apply finds no `old`
and fails loudly instead of doubling the clause.

## Edge cases
- New prose widths: feat 71/68/18, bugfix 74/71/21 (≤ 80).
- "the last run's answer" at a feat/bugfix site = this run's answer unless a later gate flow ran on
  the same branch; "names any code commit made after it" keeps the proposal truthful either way.

## Tests
lib/tests/loops-light.test.sh; full make test.
RISK: low — prose only, rule unchanged; behavior changes: a merge after a clean-first-pass feat/bugfix
run reuses the skip instead of re-calling the advisor (the gated trade-off, item 3).

## Deferred (challenge MINORs, logged at bookkeeping, not this run)
- merge-time gap: the merge proposal happens at the gitflow finish gate (skills/gitflow/SKILL.md
  :68-89, 0 advisor mentions); if compaction drops the skill body the reuse rule is not in view.
- "names any code commit made after it" has no anchor: the ADVISOR field records no HEAD SHA, so
  commits made outside the session are invisible; candidate: record short SHA with the answer
  (visible format change, user's call).
