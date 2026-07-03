# Contract interview — mandatory upstream passage (all orchestrators)

Produces the CONTRACT: the single reference passed verbatim to the plan, the
dev subagents, and the verifier. The contract is what lets the orchestrator
delegate execution without subagents ever needing a human gate (LRN-083:
subagents = execution + report only; gates and loop decisions live in the
main loop).

Run this in the ORCHESTRATOR MAIN LOOP, never in a subagent — STEP 2 may
talk to the human. Mandatory passage in every flow; questions are optional
and proportional — a complete request goes through silently.

## STEP 1 — CAPTURE (verbatim)

Copy the user's request EXACTLY as typed (`$ARGUMENTS` + the triggering
message). No paraphrase, no cleanup, no translation, no summarizing. This
section is IMMUTABLE for the life of the run — every later consumer
(planner, dev, verifier) reads THESE words, never a restatement.

## STEP 2 — AMBIGUITY CHECK (questions optional, proportional)

Ask ONLY if one of these is missing AND not derivable from the repo:
- a testable expected outcome
- an unambiguous scope (what is allowed to change)
- non-contradictory constraints

Complete request → ZERO questions, stay silent. Otherwise: max 3 questions,
one single batch (house rule: one question upfront, never mid-task). Never
ask what the repo can answer — verify paths/APIs/behavior yourself first.

## STEP 3 — DERIVE

- ACCEPTANCE CRITERIA: numbered; each one testable — a fresh reader must be
  able to mark it MET / NOT-MET against the real code, without having seen
  this conversation.
- FILE SCOPE: paths/zones expected to change, or `repo-wide — <reason>`.

## STEP 4 — WRITE TO DISK (immediately, before any next step)

Path: `.claude/tasks/contracts/<YYYY-MM-DD>-<slug>-<HHMM>.md`
(`mkdir -p` the directory; unique per run: date + short kebab slug + HHMM —
two runs on the same day never collide). A contract that lives only in
context dies at compaction, and the verbatim request with it.

Template:

```markdown
# CONTRACT — <slug>
- date: <YYYY-MM-DD> | flow: <ship-feature|feat|bugfix|hotfix|init-project|onboard> | branch: <branch>
- status: active

## REQUEST (verbatim — IMMUTABLE)
<the user's exact words>

## CLARIFICATIONS
Q: <question> / A: <answer>
(or: none — request complete)

## ACCEPTANCE CRITERIA
1. <testable criterion>
2. <testable criterion>

## FILE SCOPE
<paths/zones>
(or: repo-wide — <reason>)
```

Print one line to the user, then continue the flow:
`CONTRACT: <path> — <n> criteria, scope <files|repo-wide>, <q> questions asked`

## Lifecycle

- **REQUEST**: immutable, for the life of the run. Never rewritten, never
  "cleaned up".
- **CRITERIA / FILE SCOPE enrichment**: ONLY at a human gate, each added
  entry marked `[gated <YYYY-MM-DD>]`. A dev subagent NEVER enriches the
  contract. An out-of-scope edit the dev justifies is accepted ONLY through
  this micro-gate: human approves → FILE SCOPE gains the entry `[gated]`;
  human declines → the dev removes the edit. Without this gate the dev
  justifies everything and scope constrains nothing.
- **Deep re-scope** (the request itself changes): NEW contract file with
  `supersedes: <old path>` in its header — never a rewrite of the old one.
- **Aborted run**: delete the contract file, or commit it with
  `status: aborted` in the header. NEVER left dirty in the working tree.
- **Commit**: the contract rides the existing memory commit —
  `lib/capitalize-commit.md` already covers the `.claude/tasks` pathspec.
  No new plumbing.

## Weight per flow

| Flow | Weight |
|------|--------|
| hotfix | Silent autofill — criteria: "symptom gone; build/tests green"; scope = the 1-2 target files. Zero questions ever. |
| feat / bugfix | Proportional. bugfix: the DIAGNOSIS feeds the criteria (symptom reproduced-then-gone + regression test present). |
| ship-feature | Full. Design decisions approved at the validation gate append criteria `[gated <date>]` — the human validates the enriched contract, the verifier receives that version. |
| init-project | Full. The interviewer's PROJECT BRIEF pours into the contract (V1 features → criteria). |
| onboard | Audit-scope contract (interview answers → what to audit, which axes). |

## Hand-off rule

Downstream consumers (plan step, dev subagents, verifier) receive the
contract PATH, not a restatement of its content — the file on disk is the
only authoritative copy, and reading it from disk is what makes the dev's
reformulation structurally unable to interpose.
