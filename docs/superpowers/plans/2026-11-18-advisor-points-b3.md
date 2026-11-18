# Advisor call points, run B3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 12 plan-challenge callers send their route with the first tool call of `lib/challenge-plan.md` and print the `Advisor:` summary row, and let /feat and /bugfix skip their end-of-run advisor call when every gate passed at its first attempt.

**Architecture:** Prose doctrine edits only. Every edit is a block below or a fixed old/new pair in `docs/superpowers/plans/2026-11-18-advisor-points-b3/apply.py`, which reads the blocks from THIS file and asserts each anchor occurs exactly once before writing anything (LRN-296). No other wording changes.

**Tech Stack:** Markdown doctrine, Python 3 applier, bash contract oracles (`lib/gates.sh`), `make test`.

**Spec:** design approved in chat 2026-11-18 (bounded path); contract `.claude/tasks/contracts/2026-11-18-advisor-points-b3-1056.md` (REQUEST verbatim + CLARIFICATIONS [gated]).

## Global Constraints

- Branch `feature/advisor-points-b3` off develop; SDD runs in place in `/home/bchanot/Documents/claude` (decline a worktree); commits `docs(doctrine): …`.
- Files: the 12 challenge callers skills/{feat,bugfix,hotfix,ship-feature,init-project,audit-delta,code-clean,onboard,harden}/SKILL.md, skills/pack-seo/skills/{seo,geo}/SKILL.md, skills/pack-web-validate/skills/web-validate/SKILL.md; lib/effort-shift.md; CHANGELOG.md. Nothing else.
- Route annotation verbatim (user 2026-11-18, LRN-268): `(route: own level before the challenge; send it with the first tool call of lib/challenge-plan.md, the advisor call when one is due).` The `mcp__model-router__route(phase="…")` marker and its phase stay as they are (effort-routing lock).
- Skip rule (user 2026-11-18, strict): feat and bugfix skip the end-of-run call only when GATE 0 said MET, the verifier CONFORME and security PASS, each on its first attempt; any other verdict, a retry or a loop iteration runs the call. ship-feature, init-project, a11y and guardrails keep the call with no skip.
- `lib/effort-shift.md` keeps "one end-of-run call per skill run, never skipped for an earlier plan or stuck call" and names the two skips beside it (LRN-029). The feat and bugfix end lines restate the skip condition at the site: those steps cite the lib, they do not load it (LRN-297).
- Every marker and every `§ Label` citation on one line, followed by `)` or `;`; new prose lines ≤ 80 columns. Exempt by name: the 12 route lines (one line each, as before: the marker and its annotation never wrap) and the template rows (`Advisor` row, `ADVISOR` field), which run as wide as the rows beside them, and the CHANGELOG bullet (one unwrapped line, like every bullet in that file).
- Advice stays in the main loop, never in an executor, gate or challenger brief (BDR-066, LRN-083).

## Review Focus

- A skip read as "skip whenever nothing failed loudly" → the condition names the three verdicts and "each on its first attempt", and says what runs the call (criteria 5, 6).
- A skipped call that looks forgotten → the COMPLETE templates carry an `ADVISOR` field with `skipped (gates clean on first pass)` (criterion 6).
- The blanket "never skipped" contradicted by the new skip → item 3 keeps it and states "Two skips only" right after (criterion 5).
- A row noun that disagrees with the block's own `BLOCKERs addressed` row (plan / bundle / scope / proposals / finding-set) → criterion 3 compares them per file.
- A test-locked phrase moved (feat "verifier + one security dispatch", seo `## FIX BUNDLE`, the route phase markers) → simulated with the scoped suites and the full suite on a scratch clone before dispatch.

## Dispositions shown at the STEP 3 gate

- A first-attempt verdict no longer in view (after a compaction) counts as not clean: the call runs (stated in item 3 and both end lines).
- A security PASS on a DEGRADED scan (semgrep absent, checklist only; the auditor prints `PASS` with `DEGRADED` on its TOOL line) is not clean: the call runs. This is the "strict" choice; it is spelled "security PASS (not DEGRADED)" everywhere.
- An all-manual contract (`RUNNABLE: 0 of n`) that GATE 0 reports MET counts as MET: the verifier still judges every criterion, and its CONFORME is the second condition. (The stricter alternative: "GATE 0 said MET with at least one runnable oracle".)
- A skipped call discharges its point and the global "long task before calling it done" trigger it covers (item 3), so a literal reader does not make the call anyway.
- bugfix STEP 6 item 3 keeps its `mcp__model-router__route(phase="reflect")` line "(route: end-of-run review)" unchanged: on a skip it still sets the level of the tail (summary, doc sync); cost one idle route call. feat's reload route stays too.
- Item 3 also takes the wording part of BUGS-FOUND :118 beyond "commit step": the six gate flows are named, and "says it predates the newer commits" (always true in feat and bugfix, since doc and memory commits follow the call) becomes "names any code commit made after it (doc and memory commits excepted)", for all six flows, with "the last run's answer, or its skip" (a branch can carry several runs). :118 is marked partly fixed at bookkeeping (its stuck-budget half stays open).
- Counted as clean by the rule as written (the rule names gate verdicts only): an internal NEED-DECISION the main loop settled, a `[deferred]` challenge BLOCKER, a security PASS that carries REPORTED (non-blocking) findings. The trivial /bugfix path skips the plan challenge, so a clean trivial run makes no advisor call at all.
- Residual, not tested here: pairing the route call with the server-side advisor call is unverified in this repo (`lib/effort-shift.md`: the router cannot see the advisor tool). The route applies from the next request either way; pairing only saves a request.
- Residual: no standing test locks the skip sentence; a TODO line proposes a loops-light lock (a test file is outside this run's file scope).

## Acceptance criteria (the contract's final list)

The contract on disk already holds this final list with its CHECK lines (written before the gate so the plan, the contract and the simulation use one numbering; it replaced the 7-row seed written before the design, keeping its meanings: seed 2 → 2, seed 3 → 3 + 4, seed 4 → 5, seed 5 → 6, seed 6 → 7, seed 7 → 8; 9 is new). On approval its criteria are tagged `[gated 2026-11-18]`; the contract text is the one the verifier judges. Tokens: 1 OLD-ROUTE-GONE, 2 ROUTE-12, 3 ROWS-9, 4 SENTENCES-3, 5 ITEM3-OK, 6 FEAT-BUGFIX-SKIP, 7 CHANGELOG-OK, 8 `all suites green` (full `make test`, default gates timeout), 9 manual.

1. No skill keeps "send it with the challenger dispatch".
2. Each of the 12 callers carries the new route annotation once, on its `mcp__model-router__route(phase=…)` line.
3. In the 9 block templates the line right after `Lenses returned` is the `Advisor` row, its noun equal to the block's own `BLOCKERs addressed` noun.
4. feat, bugfix and hotfix name `advisor` in their one-line CHALLENGE SUMMARY.
5. Item 3 keeps "never skipped for an earlier plan or stuck call" and names its two skips (audit-delta/tour with no fix; feat/bugfix on the strict rule, including "(not DEGRADED)" and the verdict-out-of-view clause); a skipped call discharges its point; feat/bugfix sit at their commit step; for the six gate flows a later merge proposal reuses the last run's answer or skip and names any later code commit; "end step of feat" and "predates the newer commits" are gone.
6. feat and bugfix restate the skip at their end-of-run line, before the COMPLETE template, whose `ADVISOR` field lists the three values; "as an `Advisor:` line" is gone from both skills.
7. The CHANGELOG [Unreleased] "Advisor doctrine" bullet carries the cl-* blocks; "It sits at the end step of feat, bugfix" and "the answer goes into the reply, summary or finish proposal" are gone.
8. Full make test green.
9. Manual: no wording changed outside the planned edits; markers and `§ Label` citations on one line followed by `)` or `;`; the line-width rule of Global Constraints.

Every oracle was simulated on a scratch clone: red before the applier, green after; criteria 3 and 6 also turn red on a moved row, a mismatched noun and an `ADVISOR` field placed above the template.

---

## Edit table (what apply.py does)

| # | File(s) | Anchor (exact, once) | Action |
|---|---------|----------------------|--------|
| E1 | the 12 callers | `send it with the challenger dispatch).` | replace with Block route-new |
| E2 | the 9 block-form callers | `\n<indent>Lenses returned    : correctness / robustness / simplicity (NAME any that failed to return)\n` | append `<indent>` + Block row, `{noun}` = the noun of the block's own `BLOCKERs addressed` row |
| E3 | skills/feat/SKILL.md | `(BLOCKERs addressed / deferred / lenses returned), surfacing any deferred BLOCKER in\nthe STEP 1 pass B batch.\n` | replace with Block feat-summary |
| E4 | skills/bugfix/SKILL.md | `(BLOCKERs addressed / deferred / lenses returned), folding any deferred BLOCKER into\nthe STEP 3 approval gate.\n` | replace with Block bugfix-summary |
| E5 | skills/hotfix/SKILL.md | `CHALLENGE SUMMARY (BLOCKERs addressed / deferred / lenses returned). A BLOCKER\nthat shows the fix is wrong or incomplete means this was never\n` | replace with Block hotfix-summary |
| E6 | skills/feat/SKILL.md | the 4-line end-of-run paragraph of STEP 5 (`Before the summary, … back through the gates.`) | replace with Block end-report |
| E7 | skills/bugfix/SKILL.md | the same paragraph in STEP 6 item 3, 3-space indent | replace with Block end-report, 3-space indent |
| E8 | skills/feat/SKILL.md | `VERIFIED : <what was checked>\n` | append Block feat-field |
| E9 | skills/bugfix/SKILL.md | `   REGRESSION : <checked areas>\n` | append Block bugfix-field, 3-space indent |
| E10 | lib/effort-shift.md | item 3 (10 lines, `3. Before proposing a merge` … `is a new run.`) | replace with Block item3 |
| E11 | CHANGELOG.md | `skills/{feat,bugfix,ship-feature,init-project,a11y,guardrails,audit-delta,tour,release-candidate}/SKILL.md` | replace with Block cl-files |
| E12 | CHANGELOG.md | ``and the CHALLENGE SUMMARY gains an `Advisor:` row;`` | replace with Block cl-row |
| E13 | CHANGELOG.md | `never skipped for an earlier plan or stuck call. It sits at the end step of feat, bugfix, ship-feature, init-project, a11y and guardrails:` | replace with Block cl-skip |
| E14 | CHANGELOG.md | `and a later proposal reuses the answer and says it predates the newer commits.` | replace with Block cl-reuse |
| E15 | CHANGELOG.md | ``the answer goes into the reply, summary or finish proposal as an `Advisor:` line,`` | replace with Block cl-answer |

Row nouns (E2): ship-feature plan, init-project plan, audit-delta finding-set, code-clean scope, onboard proposals, harden bundle (5-space indent), seo bundle, geo bundle, web-validate bundle; every other block uses a 2-space indent.

Groups: `skills` = E1-E9 (12 + 9 + 3 + 2 + 2 = 28 edits), `lib` = E10-E15 (6 edits), `all` = both. `all` counts every anchor of both groups before it writes any file, so an ABORT leaves the tree untouched (no half-applied doctrine reaches the live `~/.claude` symlinks).

## Blocks

Each block body is inserted as written (the applier strips the final newline of an inline block: route-new, row, the five cl-* blocks). The row noun is a deliberate per-template choice: it repeats the noun of the block's own `BLOCKERs addressed` row (plan, bundle, scope, proposals, finding-set).

### Block route-new
```
send it with the first tool call of lib/challenge-plan.md, the advisor call when one is due).
```

### Block row
```
Advisor            : <the {noun} change it drove | called, no change | not called (absent | error | already called this run)>
```

### Block feat-summary
```
(BLOCKERs addressed / deferred / lenses returned / advisor), surfacing any
deferred BLOCKER in the STEP 1 pass B batch.
```

### Block bugfix-summary
```
(BLOCKERs addressed / deferred / lenses returned / advisor), folding any
deferred BLOCKER into the STEP 3 approval gate.
```

### Block hotfix-summary
```
CHALLENGE SUMMARY (BLOCKERs addressed / deferred / lenses returned / advisor).
A BLOCKER that shows the fix is wrong or incomplete means this was never
```

### Block end-report
```
Before the summary, the main loop prints the run's diff stat, then makes its
end-of-run advisor call (`lib/effort-shift.md` § Advisor), skipped when
GATE 0 said MET, the verifier CONFORME and security PASS (not DEGRADED),
each on its first attempt; any other verdict, a retry, a loop iteration or
a verdict no longer in view runs the call. The answer, or the skip, goes
into the summary's `ADVISOR` field, and a fix it drives goes back through
the gates.
```

### Block feat-field
```
ADVISOR  : <one-line answer | skipped (gates clean on first pass) | not called (absent | error)>
```

### Block bugfix-field
```
ADVISOR    : <one-line answer | skipped (gates clean on first pass) | not called (absent | error)>
```

### Block item3
```
3. Before proposing a merge (`gitflow finish`) or calling a long task
   done. Wired at the commit step of feat and bugfix, at the end step
   of ship-feature, init-project, a11y, guardrails, audit-delta and
   tour, and at the release gate of release-candidate: one end-of-run
   call per skill run, never skipped for an earlier plan or stuck call.
   Two skips only: audit-delta and tour when the run applied no fix;
   feat and bugfix when GATE 0 said MET, the verifier CONFORME and
   security PASS (not DEGRADED), each on its first attempt (any other
   verdict, a retry, a loop iteration or a verdict no longer in view
   runs the call), their summary then reading
   `skipped (gates clean on first pass)`. A skipped call discharges
   its point and the trigger it covers. In the six flows that run the
   gates (feat, bugfix, ship-feature, init-project, a11y, guardrails),
   the main loop first prints the run's diff stat, a fix the answer
   drives goes back through the gates, and a later merge proposal
   reuses the last run's answer, or its skip, and names any code commit
   made after it (doc and memory commits excepted). Elsewhere the
   answer is reported only and a fix it calls for is a new run.
```

### Block cl-files
```
skills/{feat,bugfix,hotfix,ship-feature,init-project,onboard,code-clean,harden,a11y,guardrails,audit-delta,tour,release-candidate}/SKILL.md`, `skills/pack-seo/skills/{seo,geo}/SKILL.md`, `skills/pack-web-validate/skills/web-validate/SKILL.md
```

### Block cl-row
```
and the CHALLENGE SUMMARY of every caller gains an `Advisor:` row (the plan change it drove, `called, no change` or `not called (absent | error | already called this run)`), each caller sending its route before the challenge with the first tool call of `lib/challenge-plan.md`;
```

### Block cl-skip
```
never skipped for an earlier plan or stuck call, except that feat and bugfix skip it when GATE 0 said MET, the verifier CONFORME and security PASS (not DEGRADED), each on its first attempt, their summary's `ADVISOR` field then reading `skipped (gates clean on first pass)`. It sits at the commit step of feat and bugfix and at the end step of ship-feature, init-project, a11y and guardrails:
```

### Block cl-reuse
```
and a later merge proposal reuses the last run's answer, or its skip, and names any code commit made after it (doc and memory commits excepted).
```

### Block cl-answer
```
the answer goes into the reply or finish proposal as an `Advisor:` line, or into the feat/bugfix summary's `ADVISOR` field,
```

---

### Task 1: apply the run (12 skills, item 3, CHANGELOG), one commit

**Files:**
- Modify: skills/{feat,bugfix,hotfix,ship-feature,init-project,audit-delta,code-clean,onboard,harden}/SKILL.md, skills/pack-seo/skills/{seo,geo}/SKILL.md, skills/pack-web-validate/skills/web-validate/SKILL.md, lib/effort-shift.md, CHANGELOG.md

**Interfaces:**
- Consumes: the plan blocks and `apply.py` committed as the branch's first commit by the controller (`chore(plan): …`).
- Produces: nothing a later task reads.

Stop rule for every step: an `ABORT` line, a CHECK that does not print its EXPECT token, or a suite that is not green → first `git restore -- skills/feat/SKILL.md skills/bugfix/SKILL.md skills/hotfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md skills/audit-delta/SKILL.md skills/code-clean/SKILL.md skills/onboard/SKILL.md skills/harden/SKILL.md skills/pack-seo/skills/seo/SKILL.md skills/pack-seo/skills/geo/SKILL.md skills/pack-web-validate/skills/web-validate/SKILL.md lib/effort-shift.md CHANGELOG.md` (these files are live through the `~/.claude` symlinks), then stop and report the output verbatim. Never edit a doctrine file by hand and never re-run the applier on a partly applied tree; the controller decides.

- [ ] **Step 1: Confirm the base**

Run: `cd /home/bchanot/Documents/claude && git branch --show-current && git status --short && git log --oneline -1`
Expected: `feature/advisor-points-b3`, no modified tracked file, HEAD is the `chore(plan)` commit.

- [ ] **Step 2: Apply both groups at once**

Run: `cd /home/bchanot/Documents/claude && python3 docs/superpowers/plans/2026-11-18-advisor-points-b3/apply.py docs/superpowers/plans/2026-11-18-advisor-points-b3.md . all`
Expected: `applied 34 edits (all)`. An `ABORT` line means nothing was written.

- [ ] **Step 3: Contract criteria 1-7**

Run: `cd /home/bchanot/Documents/claude && bash lib/gates.sh status .claude/tasks/contracts/2026-11-18-advisor-points-b3-1056.md | tail -1`, then the CHECK of criteria 1 to 7 one by one (copy each `CHECK:` line from the contract).
Expected: `PENDING(8)`, then OLD-ROUTE-GONE, ROUTE-12, ROWS-9, SENTENCES-3, ITEM3-OK, FEAT-BUGFIX-SKIP, CHANGELOG-OK.

- [ ] **Step 4: Scoped suites**

Run: `cd /home/bchanot/Documents/claude && for s in plan-challenger effort-routing doctrine-citers loops-light loops-heavy seo-geo-contract; do make test suite=lib/tests/$s.test.sh 2>&1 | tail -1; done`
Expected: six lines `all suites green`.

- [ ] **Step 5: Commit (one commit: the skills' skip and item 3 land together)**

```bash
cd /home/bchanot/Documents/claude && git add skills/feat/SKILL.md skills/bugfix/SKILL.md skills/hotfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md skills/audit-delta/SKILL.md skills/code-clean/SKILL.md skills/onboard/SKILL.md skills/harden/SKILL.md skills/pack-seo/skills/seo/SKILL.md skills/pack-seo/skills/geo/SKILL.md skills/pack-web-validate/skills/web-validate/SKILL.md lib/effort-shift.md CHANGELOG.md && git commit -m "docs(doctrine): challenge route rides the first challenge call; summary Advisor row; feat/bugfix skip the end call on clean gates" && git status --short
```
Expected: no modified tracked file left.

---

## Review fix (STEP 6 opus review, applied on top of 55edd0a)

Important 1: the security auditor prints `SECURITY — VERDICT: PASS` on a DEGRADED scan (DEGRADED shows on its `TOOL:` line only), while lib/verify-secure-loop.md teaches reading DEGRADED off the VERDICT line, so "(not DEGRADED)" can be checked against the wrong line. Minor 1: the "skip settles the global trigger" clause lives only in the lib, which feat and bugfix do not load. Minor 3: the CHANGELOG reads as if feat and bugfix were the only skip. The root fix of Important 1 (verify-secure-loop.md and the auditor protocol) is out of scope: BUGS-FOUND.

| # | File(s) | Anchor (exact, once) | Action |
|---|---------|----------------------|--------|
| R1 | skills/feat/SKILL.md | Block end-tail-old | replace with Block end-tail-new |
| R2 | skills/bugfix/SKILL.md | Block end-tail-old, 3-space indent | replace with Block end-tail-new, 3-space indent |
| R3 | CHANGELOG.md | `except that feat and bugfix skip it when` | replace with Block cl-skips |

Group `review1` = R1-R3 (3 edits). Criteria 6 and 7 keep their needles whole (the new text sits after "runs the call." and before "`ADVISOR` field, and a fix it drives goes back through the gates.").

### Block end-tail-old
```
a verdict no longer in view runs the call. The answer, or the skip, goes
into the summary's `ADVISOR` field, and a fix it drives goes back through
the gates.
```

### Block end-tail-new
```
a verdict no longer in view runs the call. DEGRADED shows on the
auditor's `TOOL:` line, beside a PASS. A skip also settles the global
"long task before calling it done" trigger. The answer, or the skip,
goes into the summary's `ADVISOR` field, and a fix it drives goes back
through the gates.
```

### Block cl-skips
```
except that audit-delta and tour skip it when the run applied no fix and feat and bugfix skip it when
```

### Task R: apply the review fix, one commit

Stop rule as Task 1 (restore `skills/feat/SKILL.md skills/bugfix/SKILL.md CHANGELOG.md` first on any red step).

- [ ] **Step 1:** `cd /home/bchanot/Documents/claude && python3 docs/superpowers/plans/2026-11-18-advisor-points-b3/apply.py docs/superpowers/plans/2026-11-18-advisor-points-b3.md . review1` → `applied 3 edits (review1)`.
- [ ] **Step 2:** run the CHECK of contract criteria 6 and 7 → FEAT-BUGFIX-SKIP, CHANGELOG-OK; then `for s in loops-light doctrine-citers; do make test suite=lib/tests/$s.test.sh 2>&1 | tail -1; done` → two lines `all suites green`.
- [ ] **Step 3:** `git add skills/feat/SKILL.md skills/bugfix/SKILL.md CHANGELOG.md && git commit -m "docs(doctrine): feat/bugfix skip names where DEGRADED shows and the global trigger; changelog names both skips"`
