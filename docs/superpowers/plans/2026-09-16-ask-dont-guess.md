# Ask, don't guess — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The orchestrators ask the user about every open VISIBLE / PUBLIC NAME / SCOPE choice, upfront at plan time and mid-run through the executor's `NEED-DECISION`, instead of settling it themselves.

**Architecture:** One shared doctrine file (`lib/contract-interview.md`) gains a two-pass STEP 2 (gaps, then open choices), a MID-RUN CLARIFICATION channel and a HOW TO ASK section. The parent rule in `CLAUDE.global.md` changes. Each orchestrator wires pass B at its plan step with one line and routes `NEED-DECISION` on a `CLASS:` tag the executors now emit. Structure-lock tests are the reviewer: every doctrine change is preceded by its lock.

**Tech Stack:** Markdown doctrine files, bash structure-lock tests (`lib/tests/*.test.sh`, `make test`), gitflow on `feature/ask-dont-guess`.

**Spec:** `docs/superpowers/specs/2026-09-16-ask-dont-guess-design.md`

## Global Constraints

- A locked phrase must sit on ONE unbroken line in the doctrine file (learnings.md:1386). Reflow around it, never through it.
- `lib/tests/gates.test.sh` oracle locks on `contract-interview.md` (`### ORACLES`, `Both attributes or neither`, `url-guard.sh`, `**ABANDONMENT**`, `NEVER deleted`…) must keep passing: the ORACLES section and the Lifecycle section do not move.
- Skill and agent files keep their house style (`→`, `—`, bold markers). The writing-style rule applies to user-facing prose, not to these templates.
- No attribution trailers in commits. Commit on `feature/ask-dont-guess` only; never `finish`.
- `CLAUDE.global.md` stays under the 320-line density budget (308 lines today).
- Every task ends with the relevant test file green, then a commit.

---

### Task 1: Shared doctrine — `lib/contract-interview.md`

**Files:**
- Modify: `lib/contract-interview.md` (intro §, STEP 2, template CLARIFICATIONS line, new sections before `## Lifecycle`, weight table hotfix row)
- Test: `lib/tests/contract-verifier.test.sh:51-52`

**Interfaces:**
- Produces: section names `## STEP 2 — CLARIFY`, `## MID-RUN CLARIFICATION`, `## HOW TO ASK`, the phrase "pass B", the tag grammar `CLASS: visible | public-name | scope | internal`. Every later task points at these by name.

- [ ] **Step 1: Replace the two obsolete locks and add nine**

In `lib/tests/contract-verifier.test.sh`, replace:
```
tf  "silent when complete"            "$LIB" "ZERO questions"
tf  "question budget"                 "$LIB" "max 3 questions"
```
with:
```
tf  "silent when nothing open"        "$LIB" "goes through silently"
tf  "no question cap"                 "$LIB" "No question cap"
tf  "pass B classes"                  "$LIB" "PUBLIC NAME"
tf  "class 4 excluded"                "$LIB" "NEVER ask class 4"
tf  "over-5 guard"                    "$LIB" "More than 5 open choices"
tf  "delegated answer"                "$LIB" "delegated —"
tf  "mid-run channel"                 "$LIB" "## MID-RUN CLARIFICATION"
tf  "class tag"                       "$LIB" "CLASS:"
tf  "how to ask"                      "$LIB" "## HOW TO ASK"
```

- [ ] **Step 2: Run the lock test, expect the nine new locks red**

Run: `bash lib/tests/contract-verifier.test.sh 2>&1 | grep -E "FAIL"`
Expected: nine `FAIL` lines (silent when nothing open … how to ask); the verifier.md locks stay PASS.

- [ ] **Step 3: Edit the intro paragraph**

Old:
```
Run this in the ORCHESTRATOR MAIN LOOP, never in a subagent — STEP 2 may
talk to the human. Mandatory passage in every flow; questions are optional
and proportional — a complete request goes through silently.
```
New:
```
Run this in the ORCHESTRATOR MAIN LOOP, never in a subagent — STEP 2 may
talk to the human, at contract time (pass A) and again at the flow's PLAN
step (pass B). Questions follow the open choices, never a quota — a complete
request goes through silently.
```

- [ ] **Step 4: Replace STEP 2 entirely**

Old (from `## STEP 2 — AMBIGUITY CHECK` through `verify paths/APIs/behavior yourself first.`):
```
## STEP 2 — AMBIGUITY CHECK (questions optional, proportional)

Ask ONLY if one of these is missing AND not derivable from the repo:
- a testable expected outcome
- an unambiguous scope (what is allowed to change)
- non-contradictory constraints

Complete request → ZERO questions, stay silent. Otherwise: max 3 questions,
one single batch (house rule: one question upfront, never mid-task). Never
ask what the repo can answer — verify paths/APIs/behavior yourself first.
```
New:
```
## STEP 2 — CLARIFY (ask, never guess)

Two passes, both in the main loop, both may talk to the human.

**Pass A — gaps.** Run here, against the request. Ask if one of these is
missing AND not derivable from the repo:
- a testable expected outcome
- an unambiguous scope (what is allowed to change)
- non-contradictory constraints

**Pass B — open choices.** Defined here, run ONCE at the flow's PLAN step
(see "Where pass B fires" below), against the plan just written — that is
where choices become concrete. Enumerate every choice the run will settle
that the request leaves open; keep those in these classes:
1. VISIBLE — the user would see it in the result: placement, label, wording,
   color, order, what a click does.
2. PUBLIC NAME — a name that outlives the run: command, flag, endpoint, env
   var, a file the human will read.
3. SCOPE — "should X change too?", where the request does not name X.

NEVER ask class 4 — internal technical choices with no observable effect
(function decomposition, data shape, local naming, layout inside an
already-scoped zone). Those are delegated; asking them is the noise that
makes classes 1-3 ignorable. Never ask what the repo or the request already
answers — verify paths/APIs/behavior yourself first.

No question cap. Each pass asks what it finds, in ONE batch. A request that
leaves nothing open goes through silently. More than 5 open choices in pass B
= the request is under-specified: list them, say so, stop — do not fire a
questionnaire. "You decide" / "peu importe" is an answer: record it as
`A: delegated — <default taken>` and never re-ask it.

Pass B answers land in the contract's CLARIFICATIONS marked
`[gated <YYYY-MM-DD>]` — the contract is already on disk by then.

### Where pass B fires

| Flow | Pass B runs at | Against |
|------|----------------|---------|
| feat | STEP 1 PLAN, before 1b CHALLENGE | the PLAN checklist |
| bugfix | STEP 3 FIX PLAN, before 3b | the FIX PLAN |
| hotfix | STEP 1 LOCATE | the 1-2 target files' visible effect |
| ship-feature | STEP 2 PLAN, after the brainstorm | the plan, minus what the brainstorm settled |
| init-project | STEP 3 DESIGN, before VALIDATION GATE #1 | the DESIGN, minus what the interview and brainstorm settled |
| onboard | its STEP 3 interview, unchanged | scope, in one block |
```

- [ ] **Step 5: Mark gated entries in the template**

Old: `Q: <question> / A: <answer>`
New: `Q: <question> / A: <answer>   (pass B and mid-run entries: [gated <YYYY-MM-DD>])`

- [ ] **Step 6: Insert the two new sections right before `## Lifecycle`**

```
## MID-RUN CLARIFICATION (the channel executors halt into)

An executor cannot talk to the human. It halts with `NEED-DECISION`, the
exact question, the options it sees, and a `CLASS:` tag (visible |
public-name | scope | internal). `/hotfix`: the hotfixer keeps
`DONE | BLOCKED`; a BLOCKED carrying the tag follows the same routing instead
of escalating to `/bugfix`. The orchestrator re-reads the class — the tag is
a hint, not a verdict — then routes:
- visible / public-name / scope → ASK THE HUMAN, verbatim question and
  options. Never decide these yourself, never spend a round-trip guessing.
- internal → decide here, note the decision, re-dispatch. The only case the
  orchestrator settles alone; max 2 such round-trips → escalate.

Every answer, human or orchestrator, appends to the contract's
CLARIFICATIONS marked `[gated <YYYY-MM-DD>]` — the same micro-gate as scope
enrichment — and to the plan handed to the FRESH re-dispatched executor,
which reads the decision from disk, never from a transcript.

## HOW TO ASK (LRN-102)

The harness reliably renders only the turn's FINAL text; text printed before
a tool call may be swallowed. So:
- up to 4 questions → one `AskUserQuestion` call; option descriptions carry
  the context; print nothing the user needs before the call.
- more than 4, or a list handed back for re-specification → plain text, end
  the turn.

```

- [ ] **Step 7: Rewrite the hotfix row of the weight table**

Old:
```
| hotfix | Silent autofill — criteria: "symptom gone; build/tests green"; scope = the 1-2 target files. Zero questions ever. |
```
New:
```
| hotfix | Pass A silent autofill — criteria: "symptom gone; build/tests green"; scope = the 1-2 target files. Pass B runs at LOCATE against the 1-2 target files' visible effect; a typo fix asks nothing. |
```

- [ ] **Step 8: Run both lock suites, expect green**

Run: `bash lib/tests/contract-verifier.test.sh 2>&1 | grep -E "FAIL|PASS="; bash lib/tests/gates.test.sh 2>&1 | grep -E "FAIL|bad|PASS=|ok=" | tail -3`
Expected: no `FAIL` line in contract-verifier; gates oracle locks all `ok`.

- [ ] **Step 9: Commit**

```bash
git add lib/contract-interview.md lib/tests/contract-verifier.test.sh
git commit -m "feat(contract): STEP 2 CLARIFY, mid-run channel, how-to-ask"
```

---

### Task 2: Parent rule — `CLAUDE.global.md`

**Files:**
- Modify: `CLAUDE.global.md:51-55`
- Test: `wc -l CLAUDE.global.md` (≤ 320) and `bash lib/tests/curated-config-guard.test.sh`

**Interfaces:**
- Produces: the sentence "Ask rather than guess." as the house rule every skill inherits.

- [ ] **Step 1: Replace lines 51-53**

Old:
```
- One question upfront if needed — don't interrupt mid-task.
  *Exception: skill-mandated gates and checkpoints (orchestrator
  validation gates, approval gates, darwin checkpoints) always fire.*
```
New:
```
- Ask rather than guess. A choice visible in the result (placement,
  wording, order, behavior), a name that becomes public (command, flag,
  endpoint, file), or a scope the request does not settle → ask, even
  mid-task. Batch what can be batched. Internal technical choices with
  no observable effect stay yours.
  *Exception: skill-mandated gates and checkpoints (orchestrator
  validation gates, approval gates, darwin checkpoints) always fire.*
```

- [ ] **Step 2: Reconcile the bug line**

Old:
```
- Bug received → fix directly: check logs, find root cause, resolve
  autonomously.
```
New:
```
- Bug received → fix directly: check logs, find root cause, resolve
  autonomously; a visible choice in the fix still gets asked.
```

- [ ] **Step 3: Verify budget and guard**

Run: `wc -l CLAUDE.global.md; grep -c "One question upfront" CLAUDE.global.md lib/contract-interview.md; bash lib/tests/curated-config-guard.test.sh 2>&1 | tail -2`
Expected: ≤ 320 lines; both grep counts `0`; guard test green.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.global.md
git commit -m "feat(rules): ask rather than guess replaces one-question-upfront"
```

---

### Task 3: `/feat` wiring

**Files:**
- Modify: `skills/feat/SKILL.md` (STEP 0.7 §, STEP 1 tail, STEP 1b tail, STEP 3 parse)
- Test: `bash lib/tests/loops-light.test.sh`

**Interfaces:**
- Consumes: `pass B`, `MID-RUN CLARIFICATION`, `CLASS:` from Task 1.

- [ ] **Step 1: STEP 0.7 wording**

Old:
```
captures the request verbatim, asks 0-3 questions PROPORTIONAL to ambiguity
(a complete request → zero questions, silent), derives testable acceptance
criteria + file scope, and writes the contract to
```
New:
```
captures the request verbatim, runs pass A (gaps: outcome, scope,
constraints — a complete request goes through silently), derives testable
acceptance criteria + file scope, and writes the contract to
```

- [ ] **Step 2: STEP 1 tail — replace the one-question rule with pass B**

Old:
```
If the approach is ambiguous: ask the user ONE focused question BEFORE
dispatching — never after (the executor cannot relay questions).
```
New:
```
Then run pass B of `$HOME/.claude/lib/contract-interview.md` against this
plan: every VISIBLE / PUBLIC NAME / SCOPE choice the plan settles that the
request left open → one batch of questions BEFORE dispatching; answers land
in the contract's CLARIFICATIONS `[gated]` and in the plan. A choice that
surfaces only during execution comes back as `NEED-DECISION` (STEP 3).
```

- [ ] **Step 3: STEP 1b tail**

Old: `surfacing any deferred BLOCKER via\nSTEP 1's one-question gate.`
New: `surfacing any deferred BLOCKER in\nthe STEP 1 pass B batch.`

- [ ] **Step 4: STEP 3 parse**

Old:
```
- `STATUS : NEED-DECISION` → make the decision HERE (that is reflection),
  append it to the plan, re-dispatch a FRESH feater with plan + decision.
  Max 2 decision round-trips → escalate to the user.
```
New:
```
- `STATUS : NEED-DECISION` → route on its `CLASS:` per MID-RUN CLARIFICATION
  in `$HOME/.claude/lib/contract-interview.md`: visible / public-name / scope
  → ask the user, verbatim; internal → decide HERE (max 2 such round-trips
  → escalate). Append the answer to the contract `[gated]` and to the plan,
  re-dispatch a FRESH feater with plan + decision.
```

- [ ] **Step 5: Test and commit**

Run: `grep -n "ONE focused question\|decision HERE (that is reflection)" skills/feat/SKILL.md; bash lib/tests/loops-light.test.sh 2>&1 | grep -E "FAIL|PASS="`
Expected: grep empty; `FAIL=0`.
```bash
git add skills/feat/SKILL.md
git commit -m "feat(feat): pass B at PLAN, NEED-DECISION routed on class"
```

---

### Task 4: `/bugfix` wiring

**Files:**
- Modify: `skills/bugfix/SKILL.md` (STEP 3 bullets, STEP 3.5 §, STEP 5 parse)
- Test: `bash lib/tests/loops-light.test.sh`

- [ ] **Step 1: STEP 3 — add pass B after the approval bullets**

After:
```
- If the fix is significant (>10 lines, multiple files,
  behavior change): wait for user approval.
```
add:
```
- Then run pass B of `$HOME/.claude/lib/contract-interview.md` against the
  FIX PLAN: every VISIBLE / PUBLIC NAME / SCOPE choice it settles that the
  bug report left open → one batch of questions, before STEP 3b. The trivial
  fast-path is not exempt: a 1-line fix with a visible choice still asks.
```

- [ ] **Step 2: STEP 3.5 wording**

Old: `Questions stay proportional (a clear,\nreproduced bug → zero). It writes the contract to`
New: `Pass A only here (pass B ran at STEP 3); a clear,\nreproduced bug asks nothing. It writes the contract to`

- [ ] **Step 3: STEP 5 parse**

Old:
```
- `STATUS : NEED-DECISION` → make the decision HERE (that is reflection),
  append it to the plan, re-dispatch a FRESH bugfixer with plan + decision.
  Max 2 decision round-trips → escalate to the user.
```
New:
```
- `STATUS : NEED-DECISION` → route on its `CLASS:` per MID-RUN CLARIFICATION
  in `$HOME/.claude/lib/contract-interview.md`: visible / public-name / scope
  → ask the user, verbatim; internal → decide HERE (max 2 such round-trips
  → escalate). Append the answer to the contract `[gated]` and to the plan,
  re-dispatch a FRESH bugfixer with plan + decision.
```

- [ ] **Step 4: Test and commit**

Run: `grep -n "decision HERE (that is reflection)\|stay proportional" skills/bugfix/SKILL.md; bash lib/tests/loops-light.test.sh 2>&1 | grep -E "FAIL|PASS="`
Expected: grep empty; `FAIL=0`.
```bash
git add skills/bugfix/SKILL.md
git commit -m "feat(bugfix): pass B at FIX PLAN, NEED-DECISION routed on class"
```

---

### Task 5: `/hotfix` wiring (lock first)

**Files:**
- Modify: `skills/hotfix/SKILL.md` (STEP 1 bullet, STEP 1.7 §, STEP 3 parse, RULES)
- Test: `lib/tests/loops-light.test.sh:84`

- [ ] **Step 1: Replace the lock**

Old: `tf "hotfix zero questions"      "$HSKL" "questions ever"`
New: `tf "hotfix pass B at locate"    "$HSKL" "run pass B of"`

- [ ] **Step 2: Run, expect red**

Run: `bash lib/tests/loops-light.test.sh 2>&1 | grep -E "FAIL"`
Expected: one FAIL, `hotfix pass B at locate`.

- [ ] **Step 3: STEP 1 — add pass B after the "Settle the proposed fix HERE" bullet**

After:
```
- Settle the proposed fix HERE — the executor cannot ask questions, so the
  exact edit (what changes, in which file(s)) must be closed before dispatch.
```
add:
```
- Then run pass B of `$HOME/.claude/lib/contract-interview.md` against that
  edit: a VISIBLE / PUBLIC NAME / SCOPE choice the bug description leaves
  open (which way the icon aligns, the label's wording) → ask before
  dispatch. A typo or a wrong value asks nothing.
```

- [ ] **Step 4: STEP 1.7 wording**

Old:
```
Run `$HOME/.claude/lib/contract-interview.md` at hotfix weight: **zero
questions ever** (a hotfix is an obvious fix by definition). Autofill the
```
New:
```
Run `$HOME/.claude/lib/contract-interview.md` at hotfix weight: pass A is a
silent autofill (a hotfix is an obvious fix by definition); pass B already
ran at STEP 1, ask nothing more here. Autofill the
```

- [ ] **Step 5: STEP 3 parse — a tagged BLOCKED is a question, not a revert**

Insert before the existing `- \`STATUS : BLOCKED\` → if any edits were made, revert ONLY the executor's` bullet:
```
- `STATUS : BLOCKED` with `CLASS: visible | public-name | scope` in NOTES →
  the executor halted at an open choice before editing (nothing to revert):
  ask the user per MID-RUN CLARIFICATION in
  `$HOME/.claude/lib/contract-interview.md`, append the answer to the
  contract `[gated]`, re-dispatch ONCE with the closed choice. This is the
  one re-dispatch hotfix allows; it is not a retry of a failed attempt.
```
and change the following bullet's head from `- \`STATUS : BLOCKED\` → if any edits were made,` to `- \`STATUS : BLOCKED\` otherwise → if any edits were made,`.

- [ ] **Step 6: RULES**

Old:
```
- The executor is dispatched FRESH, once — hotfix never re-dispatches (no
  decision round-trips; a blocked or failed attempt reverts and escalates
  to `/bugfix`, it does not retry).
```
New:
```
- The executor is dispatched FRESH, once — hotfix never re-dispatches after
  a failed or blocked attempt (it reverts and escalates to `/bugfix`, it
  does not retry). Sole exception: a class-tagged BLOCKED answered by the
  user (STEP 3), re-dispatched once with the closed choice.
```

- [ ] **Step 7: Run, expect green, commit**

Run: `grep -n "questions ever" skills/hotfix/SKILL.md; bash lib/tests/loops-light.test.sh 2>&1 | grep -E "FAIL|PASS="`
Expected: grep empty; `FAIL=0`.
```bash
git add skills/hotfix/SKILL.md lib/tests/loops-light.test.sh
git commit -m "feat(hotfix): pass B at LOCATE, class-tagged BLOCKED relayed as a question"
```

---

### Task 6: `/ship-feature` and `/init-project` wiring

**Files:**
- Modify: `skills/ship-feature/SKILL.md` (STEP 2), `skills/init-project/SKILL.md` (contract §, STEP 3)
- Test: `bash lib/tests/loops-heavy.test.sh`

- [ ] **Step 1: ship-feature STEP 2**

After:
```
note the ID inline. Break design into tasks (2-5 min each). Each task: exact file paths, full code, verification steps.
```
add:
```
Then run pass B of `$HOME/.claude/lib/contract-interview.md` against the plan:
every VISIBLE / PUBLIC NAME / SCOPE choice the plan settles that neither the
request nor the STEP 1 brainstorm settled (check the contract's CLARIFICATIONS
first) → one batch before STEP 2b; answers append to the contract `[gated]`.
```

- [ ] **Step 2: init-project contract paragraph**

Old: `FILE SCOPE = the planned tree. No new questions\n(the interview already asked). It writes`
New: `FILE SCOPE = the planned tree. Pass A is covered by\nthe interview; pass B runs at STEP 3 against the DESIGN. It writes`

- [ ] **Step 3: init-project STEP 3**

After the line ending `test strategy, resolved decisions, prereqs list.` add:
```
Then run pass B of `$HOME/.claude/lib/contract-interview.md` against the DESIGN
(minus what the BRIEF and the brainstorm settled): one batch before STEP 4;
answers append to the contract `[gated]`.
```

- [ ] **Step 4: Test and commit**

Run: `grep -n "No new questions" skills/init-project/SKILL.md; bash lib/tests/loops-heavy.test.sh 2>&1 | grep -E "FAIL|PASS="`
Expected: grep empty; `FAIL=0`.
```bash
git add skills/ship-feature/SKILL.md skills/init-project/SKILL.md
git commit -m "feat(ship-feature,init-project): pass B at the plan and design steps"
```

---

### Task 7: interviewer — no `(assumed)` on a visible choice

**Files:**
- Modify: `agents/interviewer.md:17,23,80`
- Test: `bash lib/tests/run-review-guards.sh` (G3 strict-YAML frontmatter)

- [ ] **Step 1: Budget line (17)**

Old:
```
- Hard budget: 2 question rounds total (initial block + one follow-up). The BRIEF ships after round 2 no matter what — gaps become OPEN DECISIONS, never a third round.
```
New:
```
- Hard budget: 2 question rounds total (initial block + one follow-up) for gaps. The BRIEF ships after round 2 — gaps become OPEN DECISIONS. Sole exception: a VISIBLE, PUBLIC NAME or SCOPE choice (a user-facing placement or wording, a public command/flag/endpoint name, whether X is in scope) still open after round 2 gets ONE more targeted question; it never ships as `(assumed)`.
```

- [ ] **Step 2: Failure-mode row (23)**

Old:
```
| Answer vague/ambiguous | One targeted follow-up on that item only | Record item in OPEN DECISIONS with the safest reading, marked `(assumed)` — never invent a confident value |
```
New:
```
| Answer vague/ambiguous | One targeted follow-up on that item only | Gap: record it in OPEN DECISIONS with the safest reading, marked `(assumed)` — never invent a confident value. Visible / public-name / scope item: one more targeted question instead, never `(assumed)` |
```

- [ ] **Step 3: DO NOT line (80)**

Old: `- Exceed the 2-round budget, whatever is still missing.`
New: `- Exceed the 2-round budget for gaps; the only extra question is the single targeted one a visible / public-name / scope item earns.`

- [ ] **Step 4: Test and commit**

Run: `bash lib/tests/run-review-guards.sh 2>&1 | grep -E "G3|RED"`
Expected: `GREEN ✓ G3`, no RED.
```bash
git add agents/interviewer.md
git commit -m "feat(interviewer): a visible or public choice is asked, never assumed"
```

---

### Task 8: Executors emit the class (lock first)

**Files:**
- Modify: `agents/feater.md` (halt bullet, NOTES), `agents/bugfixer.md` (halt bullet, NOTES), `agents/hotfixer.md` (new rule bullet, NOTES)
- Test: `lib/tests/gates.test.sh` after line 313

- [ ] **Step 1: Add the locks**

After `lock "bugfixer test must fail" "$BF" "A test that passes both ways"` add:
```
lock "feater class tag"        "$FE" "CLASS:"
lock "bugfixer class tag"      "$BF" "CLASS:"
lock "hotfixer class tag"      "$REPO/agents/hotfixer.md" "CLASS:"
```

- [ ] **Step 2: Run, expect three red**

Run: `bash lib/tests/gates.test.sh 2>&1 | grep -E "bad|FAIL" | head`
Expected: three `bad` lines (class tag).

- [ ] **Step 3: feater halt bullet**

Old:
```
- Follow the plan to the letter. A plan hole or an open choice (naming,
  data shape, API surface, dependency) → STOP, report `NEED-DECISION` with
  the precise question. Never improvise a design decision.
```
New:
```
- Follow the plan to the letter. A plan hole or an open choice (naming,
  data shape, API surface, dependency, a user-visible choice such as
  placement, wording or behavior) → STOP, report `NEED-DECISION` with the
  precise question and its `CLASS:`. Never improvise a design decision.
```

- [ ] **Step 4: feater NOTES**

Old:
```
NOTES    : <DONE: deviations (must be none) | NEED-DECISION: the exact
           question + the options you see | BLOCKED: the blocker verbatim>
```
New:
```
NOTES    : <DONE: deviations (must be none) | NEED-DECISION: the exact
           question + the options you see + CLASS: visible | public-name |
           scope | internal | BLOCKED: the blocker verbatim>
```

- [ ] **Step 5: bugfixer halt bullet**

Old:
```
- Apply the FIX PLAN to the letter — fix the ROOT CAUSE named in DIAGNOSIS,
  not the symptom. A plan hole or an open choice (naming, data shape, API
  surface, dependency) → STOP, report `NEED-DECISION` with the precise
  question. Never re-investigate or improvise a different fix.
```
New:
```
- Apply the FIX PLAN to the letter — fix the ROOT CAUSE named in DIAGNOSIS,
  not the symptom. A plan hole or an open choice (naming, data shape, API
  surface, dependency, a user-visible choice such as placement, wording or
  behavior) → STOP, report `NEED-DECISION` with the precise question and
  its `CLASS:`. Never re-investigate or improvise a different fix.
```

- [ ] **Step 6: bugfixer NOTES**

Old:
```
NOTES    : <DONE: deviations (must be none) | NEED-DECISION: the exact
           question + the options you see | BLOCKED: the blocker verbatim>
```
New:
```
NOTES    : <DONE: deviations (must be none) | NEED-DECISION: the exact
           question + the options you see + CLASS: visible | public-name |
           scope | internal | BLOCKED: the blocker verbatim>
```

- [ ] **Step 7: hotfixer rule + NOTES**

After the `- Stay inside the scope you were given.` bullet (ends `apply only those.`) add:
```
- An open user-visible choice the contract does not settle (placement,
  wording, behavior) → `STATUS BLOCKED` with `CLASS: visible | public-name |
  scope` in NOTES, BEFORE editing anything. The orchestrator asks the user
  and re-dispatches once.
```
Old NOTES: `NOTES   : <BLOCKED: the blocker; DONE: none>`
New NOTES:
```
NOTES   : <BLOCKED: the blocker, + CLASS: visible | public-name | scope when
          you halted at an open choice before editing; DONE: none>
```

- [ ] **Step 8: Run, expect green, commit**

Run: `bash lib/tests/gates.test.sh 2>&1 | grep -E "bad|FAIL|PASS=|ok=" | tail -3; bash lib/tests/run-review-guards.sh 2>&1 | grep -E "G3|RED"`
Expected: no `bad`; G3 GREEN.
```bash
git add agents/feater.md agents/bugfixer.md agents/hotfixer.md lib/tests/gates.test.sh
git commit -m "feat(executors): NEED-DECISION and BLOCKED carry a CLASS tag"
```

---

### Task 9: Full suite, changelog, closure

**Files:**
- Modify: `CHANGELOG.md` ([Unreleased] → Changed), `.claude/tasks/TODO.md`
- Test: `make test`

- [ ] **Step 1: Full suite**

Run: `timeout 300 make test 2>&1 | grep -E "RED|FAIL=" | grep -vE " 0 RED|FAIL=0"`
Expected: empty output.

- [ ] **Step 2: CHANGELOG entry under `### Changed`**

```
- **Ask, don't guess: the orchestrators ask about open choices instead of
  settling them.** `CLAUDE.global.md` replaces "one question upfront, never
  mid-task" with: a choice visible in the result, a name that becomes
  public, or a scope the request does not settle → ask, even mid-task;
  internal technical choices stay Claude's. `lib/contract-interview.md`
  STEP 2 becomes CLARIFY: pass A (the three gap checks, at contract time)
  and pass B (the open-choice sweep in three classes, run once at each
  flow's PLAN step, no question cap, over-5 guard, "you decide" recorded as
  delegated). New MID-RUN CLARIFICATION section: an executor's
  `NEED-DECISION` carries a `CLASS:` tag; visible / public-name / scope go
  to the user verbatim, internal is decided in the loop; answers land in
  the contract `[gated]`. New HOW TO ASK section (LRN-102). `/feat`,
  `/bugfix`, `/hotfix`, `/ship-feature`, `/init-project` wire pass B at
  their plan step; `/feat` and `/bugfix` stop deciding `NEED-DECISION`
  themselves; `/hotfix` drops "zero questions ever" and allows one
  re-dispatch for a class-tagged BLOCKED; the interviewer never ships a
  visible / public-name / scope item as `(assumed)`; feater, bugfixer and
  hotfixer report the class. Locks updated in the `contract-verifier`,
  `loops-light` and `gates` tests.
```

- [ ] **Step 3: Tick the TODO section, commit**

```bash
git add CHANGELOG.md .claude/tasks/TODO.md
git commit -m "docs(changelog): ask-don't-guess doctrine"
```

- [ ] **Step 4: Behavioral check (manual, before merge)**

In a fixture repo: `/feat "add a share icon to the header"` must ask placement before dispatching; `/feat "add a share icon at the right end of the header, label Share, opens the native share sheet"` must ask nothing. Record the outcome in `evals.md` at capitalize.
