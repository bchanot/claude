# prune-memory — test backlog (future REDs)

## RED-7 (candidate) — example-priming in the merge pass
Observed during the 2026-06-25 real-data measurement on the live
`learnings.md`: the skill merged **LRN-014 + LRN-016** — the EXACT pair
named as the worked example in `SKILL.md` STEP 2
("LRN-014 + LRN-016 — both pandoc rendering quirks → merge into NEW
LRN-017"). 

Hypothesis: the skill's own illustrative example PRIMED the merge on real
data, rather than a genuine content overlap between those two entries.

If confirmed, this is a design defect: a skill's example must not steer its
behavior on real registries.
- VERIFY FIRST: read the real LRN-014 / LRN-016 — do they actually overlap,
  or did the example drive the merge?
- RED (if priming confirmed): fixture with entries at LRN-014/016 that do
  NOT overlap (distinct topics) → assert the skill does NOT merge them.
- GREEN: fictionalize the SKILL.md example (obviously-fake IDs, or an
  explicit "hypothetical" framing) so example IDs cannot match real entries.

Status: RESOLVED 2026-06-29. VERIFY-FIRST done — the real LRN-014 (pandoc header-id
stripping) and LRN-016 (pandoc checkbox CSS overlap) are COMPLEMENTARY (different
angles), NOT overlapping: the SKILL.md example modeled a *wrong* merge AND used live
IDs that primed it on real data. GREEN: the whole STEP-2 example fictionalized to 9xx
IDs (cannot match any live registry) + the merge example now models a same-concept
merge with an explicit "merge ONLY same-concept" note. Closed by a DETERMINISTIC test
(run-deterministic.sh RED-7: the STEP-2 example must carry only 9xx ids) — not the
flaky behavioral fixture originally proposed, per LRN-046 (deterministic oracle >
semantic judge on a destructive skill). Test caught its own ugrep false-green first.

## RED-8 (candidate) — added-negation inversion (documented limit, not a test yet)
The RED-5 fidelity guard flags negation/permanent token DROPS; it cannot catch
an ADDED negation that inverts meaning ("X works" -> "X never works") — that is
a count INCREASE. The STEP 3.4 NEGATION GUARD only protects sentences that
ALREADY contain a negation, so it does not stop a non-negation sentence being
rewritten WITH a negation. So NEITHER guard closes this case — a real hole,
documented honestly rather than claimed covered.

Practically remote: caveman compression and merge SUBTRACT tokens (drop filler);
they do not author new negations. Producing "X never works" from "X works"
requires ADDING a word, contrary to an operation that shortens.
- RED (if pursued): assert no op INCREASES an existing entry's negation count.
- Caveat: must exclude new/merged-entry ids (HEAD count 0 -> N is legitimate),
  so an increase-check needs care to avoid its own false positives.
Status: CONSCIOUSLY ACCEPTED as a documented limit 2026-06-29 (re-reviewed, not built).
Rationale held on re-read: (1) remote — caveman/merge SUBTRACT tokens; authoring a new
negation runs against the operation; no evidence in the real-data measurement (the
"+7 not/no" in EVAL-006 is new/merged-entry ids going 0→N, NOT an existing entry
inverted). (2) An FP-safe increase-check is non-trivial: the census only emits non-zero
counts, so a 0→1 ADD produces a working-line with NO HEAD-line to compare — catching it
needs the HEAD entry-id set to exclude legitimately-new/merged ids. A noisy increase-check
= a guard you learn to ignore (LRN-047), worse than the honest documented limit on a
destructive skill. Revisit only if a real inversion is ever observed.
