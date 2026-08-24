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

### ORACLES — a criterion a command can decide carries one

Give such a criterion an indented `CHECK:` (the command), `EXPECT:` (a
success-only marker), and `EVIDENCE: pending`.
`bash ~/.claude/lib/gates.sh run <contract>` executes it fail-closed — MET
requires exit 0 **AND** the marker — and writes the result back over the
`EVIDENCE:` line. That persisted evidence is what the fresh verifier reads
as fact instead of trusting the executor's report (GATE 0 in
`lib/verify-secure-loop.md`).

Both attributes or neither. `CHECK:` without `EXPECT:` is a parse error, not
a manual criterion — the runner refuses the whole ledger. Leave a criterion
oracle-free when no command can decide it; the verifier judges those.

Four authoring rules — a gate that cannot fail proves nothing:

1. **Observe the named artifact.** The check reads the file, service, or
   measurement the criterion's own words name — never a proxy for it.
   `1. invoices reconcile` + `CHECK: echo ok` is valid and worthless.
2. **Success-only marker.** The script runs every assertion, exits nonzero
   on any failure, and prints the `EXPECT:` string only after all pass.
3. **Positive control before any absence check.** Run the same logic against
   a fixture known to trip it and confirm it fails. A missing file, a wrong
   path, and a broken pattern all look exactly like valid absence.
4. **Recompute supplied numbers.** Never copy a figure from the request into
   `EXPECT:` — the script derives it from source and prints its own marker.
   A number that is its own proof proves nothing.

`CHECK:` is shell code run with our privileges. It is safe only because we
author it in our own repo — never build one out of externally-supplied text
(a scraped URL, a client string); route those through `lib/url-guard.sh`.

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
1. <criterion a command can decide>
   CHECK: <command>
   EXPECT: <success-only marker>
   EVIDENCE: pending
2. <criterion only human judgement can decide — no CHECK/EXPECT>

(ABANDON: <n> <non-blank reason> — only for a criterion proven impossible)

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
- **ABANDONMENT**: a criterion proven impossible within the authorized task
  is NEVER deleted and never quietly downgraded. Keep it, append
  `ABANDON: <n> <non-blank reason + handoff>` under the criteria, and name it
  in the final report. An abandonment is a visible handoff, not a pass: the
  verifier cannot return `CONFORME` while one stands, and the run cannot be
  described as fully complete. This is the structural half of the house rule
  "blocked on an independent sub-part → do the rest, state what's missing".
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

Oracles follow the same proportion. hotfix: none — that flow runs no floor
(and no verifier); the hotfixer runs build/tests itself. feat / bugfix: the
suite criterion at minimum, and for bugfix the regression test the DIAGNOSIS
names — its `CHECK:` runs that test alone, so a green result means the
reproduction actually flipped.
ship-feature / init-project: build, suite, and every criterion a command can
settle. onboard: audit criteria are mostly judgement — leave them oracle-free
rather than invent a check that cannot fail.

## Hand-off rule

Downstream consumers (plan step, dev subagents, verifier) receive the
contract PATH, not a restatement of its content — the file on disk is the
only authoritative copy, and reading it from disk is what makes the dev's
reformulation structurally unable to interpose.
