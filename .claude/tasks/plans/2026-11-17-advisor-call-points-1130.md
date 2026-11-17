# PLAN — advisor call points, run A (r4 after re-challenge)
Contract: .claude/tasks/contracts/2026-11-17-advisor-call-points-1130.md
Branch: feature/advisor-call-points (off develop)

## Why
User 2026-11-17 approved points 1 and 2 after transcript data: since /advisor
(2026-11-16 16:19Z) the main loop called the advisor 2 times in 3 skill runs
(served by Opus, 409k and 680k uncached input tokens each); 18 of 20 opus
sub-agents called it (19 calls, Fable, median 70k tokens, 1.46M total); 0 of 8
sonnet sub-agents. The doctrine of c3507ea ("main loop only") is inverted by the
data on both use and cost. Reverses BDR-150's "sub-agents do not" for the three
judgment agents.

## Files (5)
1. CLAUDE.global.md § Workflow, lines 81-85: replace the whole "- Stronger model
   needed …" bullet with block A (verbatim; 8 lines, file 312 → 315, guard 320).
2. lib/effort-shift.md § Advisor (lines 101-110): replace the section body
   (heading kept) with block B (verbatim). Nothing else in the file changes.
3. agents/plan-challenger.md § RULES: append block C as the last bullet of the
   RULES list (before `## ORCHESTRATOR PROTOCOL`).
4. agents/verifier.md § RULES: append block D as the last bullet of the RULES
   list (before `## ORCHESTRATOR PROTOCOL`).
5. agents/security-auditor.md § RULES: append block E as the last bullet of the
   RULES list (before the next `## ` heading).

### Block A (CLAUDE.global.md)
```
- Stronger model needed (an approach to settle before building, a stuck
  problem, a long task before calling it done) → the main loop calls
  the advisor tool when it is listed (settings `advisorModel`, Fable,
  set by /advisor), at least at the points of
  `~/.claude/lib/effort-shift.md` § Advisor; plan-challenger, verifier
  and security-auditor at most once, before the verdict; other
  sub-agents do not. Fable is never routed or pinned: the router tops
  out at opus (BDR-150).
```

### Block B (lib/effort-shift.md § Advisor body)
```
Fable runs as the advisor (settings `advisorModel`), never a route or pin
target (BDR-150). It is a server tool: the router cannot see or refuse it.

Main loop, at least at these points (for work outside them, see the
triggers in CLAUDE.global.md § Workflow):
1. Before settling an approach: ahead of writing a skill's plan (`/feat`,
   `/bugfix`, `/ship-feature`).
2. When stuck: once per verify-secure run, at the first gate loop to fail
   twice (floor, conformity, security, or a second structural failure),
   before re-dispatching or escalating. At a cap the STOP diagnosis
   reuses that advice and says it predates the last iteration. The
   advice stays in the main loop: it feeds the main loop's own decision
   (a contract micro-gate, an early escalation, the STOP diagnosis) and
   never enters an executor brief.
3. Before proposing a merge (`gitflow finish`) or calling a long task
   done.

Sub-agents: plan-challenger, verifier and security-auditor call it at most
once per dispatch, before their verdict; executors and every other
sub-agent do not, even when the tool is listed.

Advisor absent or erroring (Fable out of credits, for example) → proceed
as written. Advice is input, never consent: it waives no gate, cap or
guard; at a loop cap it feeds the STOP diagnosis.
```

### Block C (agents/plan-challenger.md)
```
- Advisor (when listed): at most one call, after drafting your findings
  and before the verdict, whatever the harness prompt schedules; absent
  or erroring → proceed. Advice may add or sharpen a finding. Advice
  alone never drops or lowers one: a change rests on your own re-read,
  cited at file:line.
```

### Block D (agents/verifier.md)
```
- Advisor (when listed): at most one call, after STEP 4 and before
  STEP 5, whatever the harness prompt schedules; absent or
  erroring → proceed. Advice may send you back to a criterion: a
  resulting NOT-MET cites the file:line you read, ends with
  `(advisor-prompted)` and counts in STEP 5 like any other. Advice adds
  no gap outside the contract's criteria. Advice alone never clears a
  gap and is never evidence for a MET: any change rests on your own
  re-read or run (STEP 2).
```

### Block E (agents/security-auditor.md)
```
- Advisor (when listed): at most one call, after STEP 4 and before
  STEP 5 and any REPORT write, whatever the harness prompt schedules;
  absent or erroring → proceed. Advice may add a finding or raise a
  severity, cited at a file:line you read. An added finding's rule/check
  is `advisor:<STEP 3 class>`; a raised one keeps its own line, its
  rule/check becoming `<rule>+advisor`, so it counts once. The severity
  is that STEP 3 class's, which overrides the STEP 2 mapping for that
  finding only; an added finding matching no class is REPORTED as LOW,
  and a raise matching no class changes nothing. It enters STEP 5's
  dedup and BLOCK(n) like any other, and PROOF ends with `; advisor <n>
  added/raised`. It never removes, lowers or waives a finding from
  semgrep, the checklist or STEP 4.
```

## Edge cases
- Each block's lines ≤ 80 columns (block A keeps the 2-space bullet indent).
- Blocks C-E sit inside the RULES list, keeping its blank-line-between-bullets
  style if the list uses one.
- No other wording in the five files changes (wiring points, Limits, ask-tier,
  `## Never` untouched).

## Tests
No hermetic test asserts this prose (grep lib/tests: none). Oracles are the
contract's grep criteria + full `make test`. The doctrine-citers census (T6,
lib/tests/doctrine-citers.test.sh:213-214) also scans CLAUDE.global.md, so block
A's `~/.claude/lib/effort-shift.md` § Advisor citation is checked once it sits
on one line (the extractor is per line; r4 keeps it on one line), and block
B's `CLAUDE.global.md § Workflow` citation too.

## Split (user 2026-11-17)
- Run A (this plan): doctrine + three judgment agents, 5 files.
- Run B: inline advisor call lines at the step sites (plan step of skills/feat,
  skills/bugfix, skills/ship-feature; second-failure and cap sites in
  lib/verify-secure-loop.md; the merge proposal), citing
  `lib/effort-shift.md § Advisor`.
- Run C (point 3): advisor usage counter as a section of /memory-feedback
  (user choice); dedupe usage rows by message.id, model from the
  `advisor_message` iteration, main transcript vs subagents/*.jsonl.
- Stale citers for doc-sync / capitalize: README, USAGE, CHANGELOG
  [Unreleased] advisor bullet, BUGS-FOUND d292911 residual, BDR-150 status,
  LRN-294.

## Disposition
- amends BDR-150 (its "sub-agents do not" clause, c3507ea) by allowing the three
  judgment agents one call; keeps "never routed or pinned".
- applies LRN-294 only partly: sub-agents get the tool, CLAUDE.global.md and a
  harness prompt asking for "at least once before … and once before declaring
  done"; blocks C-E say the one-call rule overrides it, but that is prose
  against a harness instruction: logged as a BUGS-FOUND residual at capitalize.
- honors BDR-066/LRN-083: loop decisions stay in the main loop; advice is input.

## r3 changes (challenge round 1: correctness FATAL(2), robustness CONCERNS(3), simplicity CONCERNS(1))
- C1 BLOCKER oracle: contract criterion 2 counts STEP inside § Advisor only.
- C2 BLOCKER + R5: block E routes an advisor-added/raised finding into STEP 5's
  merge and BLOCK(n), tagged `advisor-added` / `advisor-raised from <sev>` in
  <why>; REPORT written after the advisor call (R6).
- R3: block D mirrors E (never clears NOT-MET, UNVERIFIABLE, FLOOR, out-of-scope;
  may add a gap at file:line); C5: MET evidence defers to STEP 2.
- R4: block C "may add or sharpen, never drop or lower".
- S1 + C4: block A minimal: keeps its generic triggers, points to
  `~/.claude/lib/effort-shift.md` § Advisor, no copied list.
- S4 + R1 + C8: block B = the approved points only. One stuck call per loop at
  its second failure (structural failures included), the cap reuses it; "any
  non-trivial change" dropped; done + merge one point.
- R2: second-failure advice stays in the main loop, never enters an executor
  brief (verify-secure-loop "nothing else" briefs kept).
- S2: cost sentence and sub-agent evidence sentence moved out of block B (the
  rationale goes to the BDR-150 amendment).
- R6 + C7: blocks C-E say "whatever the harness prompt schedules"; block B names
  the residual.
- C6: main-loop calls served by Opus are explained by the /advisor output in
  this conversation ("keeps Opus until /clear"); doctrine names the advisor by
  `advisorModel`.
- S3 rejected in part: the advice-specific clauses in C and D stay, because
  R3/R4 need them (they now carry new rules, not repeats).

## r4 changes (re-challenge: correctness CONCERNS(3), robustness CONCERNS(3), simplicity CONCERNS(1); no third round, these go to the CHALLENGE SUMMARY)
- RC1/RR1: block A keeps "`~/.claude/lib/effort-shift.md` § Advisor" on one
  line so the per-line census extractor sees it; criterion 1 greps it.
- RC2: contract criteria 1-5 carry `EVIDENCE: pending` (gates.sh ERROR otherwise).
- RC3/RR2/RS2: block D: advice can only send the verifier back to a criterion;
  a resulting NOT-MET is tagged `(advisor-prompted)` and counts in STEP 5; no
  gap outside the criteria; advice alone never clears; no copied gap list.
- RR3/RC5/RC6/RS3/RR8: block E: rule/check `advisor:<STEP 3 class>` or
  `<rule>+advisor`; severity = the matching STEP 3 class (overrides the STEP 2
  mapping for that finding only); no matching class → REPORTED, non-blocking
  (so one opinion cannot BLOCK, hence no /hotfix revert on opinion alone);
  PROOF gets `; advisor <n> added/raised`.
- RR4: calls placed late: verifier/auditor after STEP 4 before STEP 5;
  challenger after drafting findings.
- RS1/RR5/RC4: "advice alone never drops/lowers/clears": a change rests on the
  agent's own re-read, cited.
- RR6: main loop stuck call once per verify-secure run; the STOP says the
  advice predates the last iteration.
- RC7: block B points are a floor ("at least"), CLAUDE.global.md § Workflow
  triggers cover work outside them.
- RS4: block B residual sentence dropped (BUGS-FOUND carries it); "whatever the
  harness prompt schedules" kept (one verifier made 2 calls on 2026-11-16).
- RR7: live-install note: ~/.claude/CLAUDE.md and ~/.claude/agents are symlinks
  into this repo, so the edits apply to every session as soon as written,
  including this run's own verifier and security-auditor. Rollback:
  `git restore` of the five files on the branch.
- Execution NEED-DECISION (internal, 2026-11-17): census read "§ Workflow
  names" as heading "Workflow names" (T3 DANGLING). Block B line reworded so the
  citation ends at "§ Workflow)". Agent RULES bullets sit tight under the
  previous bullet (the lists are tight), accepted.
- Gate findings (security PASS + verifier CONFORME, 2026-11-17): block E r5.
  A raise keeps its own line (rule/check `<rule>+advisor`) so STEP 5 dedup counts
  it once; an added no-class finding is REPORTED as LOW; a raise with no class
  changes nothing.
