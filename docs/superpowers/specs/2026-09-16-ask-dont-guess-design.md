# Ask, don't guess: clarification doctrine for the orchestrators

Date: 2026-09-16. Branch: `feature/ask-dont-guess`. Status: draft for user review.

## Problem

The orchestrators (`/ship-feature`, `/feat`, `/bugfix`, `/hotfix`,
`/init-project`) settle choices the user never made. Reported symptom: "add a
share icon" ships with the icon wherever the executor put it; nobody asked
left or right.

Two causes, both written in the doctrine:

1. `lib/contract-interview.md` STEP 2 asks a question only when a testable
   outcome, a scope, or a non-contradictory constraint is missing. A request
   can pass all three and still leave every visible choice open. Taste is
   invisible to the trigger, so raising the 3-question cap would change
   nothing.
2. When an executor halts with `NEED-DECISION`, `skills/feat/SKILL.md:153`
   and `skills/bugfix/SKILL.md:165` instruct the orchestrator to "make the
   decision HERE", twice, before escalating. The question reaches the user
   after two guesses.

The parent rule both inherit is `CLAUDE.global.md:51`: "One question upfront
if needed — don't interrupt mid-task."

## Decisions taken with the user (2026-09-15/16)

- The global rule changes, for all work, skill or not. `/hotfix` included.
- Three classes of open choice trigger a question: VISIBLE (placement, label,
  wording, color, order, click behavior), PUBLIC NAME (command, flag,
  endpoint, env var, file the user reads), SCOPE (should X change too, X
  unnamed in the request). Class 4, internal technical choices with no
  observable effect, never triggers one.
- Questions are asked when they arise, mid-task included, batched when
  possible.

## Design

### 1. Parent rule, `CLAUDE.global.md`

Line 51 becomes:

    - Ask rather than guess. A choice visible in the result (placement,
      wording, order, behavior), a name that becomes public (command, flag,
      endpoint, file), or a scope the request does not settle → ask, even
      mid-task. Batch what can be batched. Internal technical choices with
      no observable effect stay yours.
      *Exception: skill-mandated gates and checkpoints (orchestrator
      validation gates, approval gates, darwin checkpoints) always fire.*

The exception line is kept as is.

The rule "Bug received → fix directly: check logs, find root cause, resolve
autonomously." gains "; a visible choice in the fix still gets asked" so the
two lines do not contradict each other. `link.sh:20` symlinks this file to
`~/.claude/CLAUDE.md`; no other copy exists.

### 2. Shared trigger, `lib/contract-interview.md` STEP 2

STEP 2 is renamed CLARIFY and split into two passes. Pass A keeps the three
existing gap checks and runs at contract time, against the request. Pass B is
the open-choice sweep: defined here, run once per flow at the PLAN step
(section 3), against the plan just written, because that is where a visible
choice becomes concrete. Replacement text:

    ## STEP 2 — CLARIFY (ask, never guess)

    Two passes, both in the main loop, both may talk to the human.

    **Pass A — gaps.** Run here, against the request. Ask if one of these is
    missing AND not derivable from the repo:
    - a testable expected outcome
    - an unambiguous scope (what is allowed to change)
    - non-contradictory constraints

    **Pass B — open choices.** Defined here, run ONCE at the flow's PLAN step
    (see "Where pass B fires"), against the plan just written — that is
    where choices become concrete. Enumerate every choice the run will
    settle that the request leaves open; keep those in these classes:
    1. VISIBLE — the user would see it in the result: placement, label,
       wording, color, order, what a click does.
    2. PUBLIC NAME — a name that outlives the run: command, flag, endpoint,
       env var, a file the human will read.
    3. SCOPE — "should X change too?", where the request does not name X.

    NEVER ask class 4 — internal technical choices with no observable
    effect (function decomposition, data shape, local naming, layout inside
    an already-scoped zone). Those are delegated; asking them is the noise
    that makes classes 1-3 ignorable. Never ask what the repo or the
    request already answers — verify paths/APIs/behavior yourself first.

    No question cap. Each pass asks what it finds, in ONE batch. A request
    that leaves nothing open goes through silently. More than 5 open
    choices in pass B = the request is under-specified: list them, say so,
    stop — do not fire a questionnaire. "You decide" / "peu importe" is an
    answer: record it as `A: delegated — <default taken>` and never re-ask.

    Pass B answers land in the contract's CLARIFICATIONS marked
    `[gated <YYYY-MM-DD>]` — the contract is already on disk by then.

Two new sections follow STEP 4 in the same file:

    ## MID-RUN CLARIFICATION (the channel executors halt into)

    An executor cannot talk to the human. It halts with `NEED-DECISION`,
    the exact question, the options it sees, and a `CLASS:` tag (visible |
    public-name | scope | internal). `/hotfix`: the hotfixer keeps
    `DONE | BLOCKED`; a BLOCKED carrying the tag follows the same routing
    instead of escalating to `/bugfix`. The orchestrator re-reads the
    class — the tag is a hint, not a verdict — then routes:
    - visible / public-name / scope → ASK THE HUMAN, verbatim question and
      options. Never decide these yourself, never spend a round-trip
      guessing.
    - internal → decide here, note the decision, re-dispatch. The only case
      the orchestrator settles alone; max 2 such round-trips → escalate.

    Every answer, human or orchestrator, appends to the contract's
    CLARIFICATIONS marked `[gated <YYYY-MM-DD>]` — the same micro-gate as
    scope enrichment — and to the plan handed to the FRESH re-dispatched
    executor, which reads the decision from disk, never from a transcript.

    ## HOW TO ASK (LRN-102)

    The harness reliably renders only the turn's FINAL text; text printed
    before a tool call may be swallowed. So:
    - up to 4 questions → one `AskUserQuestion` call; option descriptions
      carry the context; print nothing the user needs before the call.
    - more than 4, or a list handed back for re-specification → plain
      text, end the turn.

The per-flow weight table row for hotfix changes from "Zero questions ever"
to "Pass A silent autofill. Pass B runs at LOCATE against the 1-2 target
files' visible effect; a typo fix asks nothing."

### 3. Where pass B fires, per flow

| Flow | Pass B runs at | Against |
|---|---|---|
| feat | STEP 1 PLAN, before 1b CHALLENGE | the PLAN checklist |
| bugfix | STEP 3 FIX PLAN | the FIX PLAN |
| hotfix | STEP 1 LOCATE | the 1-2 target files' visible effect |
| ship-feature | STEP 2 PLAN, after the brainstorm | the plan, minus what the brainstorm already settled (in CLARIFICATIONS) |
| init-project | STEP 3 DESIGN, before VALIDATION GATE #1 | the DESIGN, minus what the interview and brainstorm settled |
| onboard | unchanged | its STEP 3 interview already asks scope in one block; the global rule covers leftovers |

Each listed step gains one line: "Run pass B of
`$HOME/.claude/lib/contract-interview.md` against this plan; ask the batch
before continuing."

### 4. Per-flow edits

- `skills/feat/SKILL.md`: STEP 1's "If the approach is ambiguous: ask the
  user ONE focused question BEFORE dispatching — never after (the executor
  cannot relay questions)" is replaced by the pass B line. STEP 3's
  `NEED-DECISION` handling is replaced by a pointer to MID-RUN CLARIFICATION.
  STEP 1b's "surfacing any deferred BLOCKER via STEP 1's one-question gate"
  is repointed to the pass B batch.
- `skills/bugfix/SKILL.md`: STEP 3 gains the pass B line; STEP 5's
  `NEED-DECISION` handling is replaced by the pointer. The RULES line
  "re-dispatched FRESH on every round-trip (NEED-DECISION, …)" stays true.
- `skills/hotfix/SKILL.md`: STEP 1 gains the pass B line. STEP 1.7's
  "**zero questions ever**" becomes "pass A silent autofill; pass B was
  asked at STEP 1". The hotfixer keeps `DONE | BLOCKED` and its
  revert-not-loop identity; STEP 4 relays a tagged BLOCKED as a question
  instead of escalating to `/bugfix`.
- `skills/ship-feature/SKILL.md`: STEP 2 PLAN gains the pass B line.
- `skills/init-project/SKILL.md`: line 62's "No new questions (the interview
  already asked)" becomes "Pass A is covered by the interview; pass B runs
  at STEP 3 against the DESIGN". STEP 3 gains the pass B line.
- `agents/interviewer.md`: the FAILURE MODES rows and the 2-round budget
  keep working for gaps. A class 1-3 item still open after round 2 gets ONE
  more targeted question; it never lands in OPEN DECISIONS as `(assumed)`.
  The DO NOT entry "Exceed the 2-round budget" gains "except the one
  targeted class 1-3 question".
- `agents/feater.md`, `agents/bugfixer.md`: the halt trigger "A plan hole or
  an open choice (naming, data shape, API surface, dependency)" gains "a
  user-visible choice (placement, wording, behavior)". The NOTES grammar for
  `NEED-DECISION` gains `CLASS: visible | public-name | scope | internal`.
- `agents/hotfixer.md`: the NOTES grammar for BLOCKED gains the same
  `CLASS:` tag when the blocker is an open choice.

### 5. Locks and tests

`lib/tests/contract-verifier.test.sh`: drop `"silent when complete" "ZERO
questions"` and `"question budget" "max 3 questions"`. Add locks on:
`"goes through silently"`, `"No question cap"`, `"PUBLIC NAME"`, `"NEVER ask
class 4"`, `"More than 5 open choices"`, `"delegated —"`, `"## MID-RUN
CLARIFICATION"`, `"CLASS:"`, `"## HOW TO ASK"`.

`lib/tests/loops-light.test.sh:84`: `"hotfix zero questions" "questions
ever"` becomes `"hotfix pass B at locate" "pass B"`.

`lib/tests/gates.test.sh` locks on `contract-interview.md` (oracle doctrine)
are untouched; the ORACLES section does not move.

Behavioral check, run once by hand after the edits, in a fixture repo:
`/feat "add a share icon to the header"` must ask placement before
dispatching; `/feat "add a share icon at the right end of the header, label
Share, opens the native share sheet"` must ask nothing.

### 6. Out of scope

- `README.md`, `USAGE.md`, `ARCHITECTURE.md`: none mentions the question
  doctrine (grep 2026-09-16). A `/doc` pass after merge covers any flow
  description that drifts.
- `CHANGELOG.md` entry and registries (a BDR superseding the "one question
  upfront" rule) happen at the CAPITALIZE step, not in this spec.
- TODO.md line 199 (C2 self-contradiction audit of `CLAUDE.global.md`) stays
  open; this spec fixes only the contradiction it exposes.

### 7. Risks

- Chattiness. Three classes, a mid-run channel, no cap. The class 4
  exclusion and the over-5 guard are the two brakes. Watch in real use;
  LRN-047 records that a frequent ignored nag is itself a risk.
- `/hotfix` identity. Its value is speed and silence. Pass B at LOCATE adds
  one possible batch before touching anything. If it fires on most
  hotfixes, the class definitions are too wide, not the flow.
- Executor mis-tagging. A class 4 tagged as visible offloads a decision to
  the user. The orchestrator re-reads the class; the tag is a hint.
