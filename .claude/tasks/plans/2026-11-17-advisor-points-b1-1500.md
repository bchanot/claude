# PLAN — advisor call points, run B1 (r4)
Contract: .claude/tasks/contracts/2026-11-17-advisor-points-b1-1500.md
Branch: feature/advisor-points-b1 (off develop)

## Why
User 2026-11-17 "oui a, b et c dans la run B": outside the named points,
advisor use rested on judgment and under-fired. (a) the main loop's plan point
moves into lib/challenge-plan.md, wired into 12 skills (9 core + seo, geo,
web-validate packs), once per skill run; (b) the dispatched `analyzer` joins the
judgment agents; (c) trigger "before recommending a change to the doctrine, the
architecture or a public interface". Stuck point: inline at the verify-secure
loop sites, counting main-loop calls only. B2 (separate run): stuck trigger in
the gate bullets of skills/feat, bugfix, ship-feature, init-project; merge lines
(ship-feature STEP 9, release-candidate STEP 4); security-auditor severity
direction; file count settled there.

## Exact edit (deterministic)
The edits are the blocks below, applied by
/tmp/claude-1000/-home-bchanot-Documents-claude/4ba4524e-88fb-4f6c-a31d-fedd261f8925/scratchpad/b1/apply.py
(`python3 apply.py <blocks dir> <repo root>`; blocks dir = .../scratchpad/b1).
It asserts every anchor occurs exactly once and fails loudly otherwise.
Summary of what it does, by file:
1. CLAUDE.global.md § Workflow: the whole "- Stronger model needed … (BDR-150)."
   bullet → block A (file 315 → 316 lines, guard 320).
2. lib/effort-shift.md § Advisor: item 1 (2 lines) → B1; the line "   reuses that
   advice and says it predates the last iteration. The" → B1b; after item 3
   ("…calling a long task\n   done.") insert I; the "Sub-agents: …listed."
   paragraph → B2.
3. lib/challenge-plan.md: after "— which is the point." insert H; before
   "Dispatch THREE fresh" insert C; the 2-line CHALLENGE SUMMARY bullet in
   § OUTPUT → F.
4. lib/verify-secure-loop.md (inserts only): Dfloor after "then STOP + human
   escalation with the rows."; Dconf after "  CRITERIA table (the
   contract-vs-realized diff)."; Dstruct after "  A mute verifier is NEVER a
   PASS."; Dsec after "  `/route effort=max` (sticky, `/route clear` after).";
   Dstruct after "  auditor is NEVER a PASS."; G before "## Order invariant".
5. agents/analyzer.md § RULES: E after "- Do not modify files".

### Block A
```
- Stronger model needed (an approach to settle before building, a stuck
  problem, a long task before calling it done, before recommending a change
  to the doctrine, the architecture or a public interface) → the main loop
  calls the advisor tool when it is listed (settings `advisorModel`,
  Fable, set by /advisor), at least at the points of
  `~/.claude/lib/effort-shift.md` § Advisor; dispatched plan-challenger,
  verifier, security-auditor and `analyzer` at most once, before their
  verdict or report; other sub-agents do not. Fable is never routed or
  pinned: the router tops out at opus (BDR-150).
```

### Block B1
```
1. Before settling an approach: on the written plan, before the
   challengers see it (`lib/challenge-plan.md`), at most once per skill run.
```

### Block B1b
```
   reuses that advice and says whether it predates the last iteration. The
```

### Block I
```
Inside a skill run, the points above also cover the triggers of
CLAUDE.global.md § Workflow; no second call for the same recommendation.
```

### Block B2
```
Sub-agents, when dispatched: plan-challenger, verifier, security-auditor
and `analyzer` call it at most once per dispatch, before their verdict or
report; executors and every other sub-agent do not, even when the tool is
listed. The analyzer file loaded inline by the main loop follows the
main-loop points.
```

### Block H
```
The main loop's advisor call before the dispatch (below) is the costliest
single item: once per skill run.
```

### Block C
```
**Advisor first (main loop).** Before the first dispatch, with no main-loop
advisor call since the skill run started (so at most once per skill run, not
before a re-challenge), the main loop reads the `PLAN` file unless its full
text is already in this conversation, then calls the advisor when the tool
is listed (`lib/effort-shift.md` § Advisor). An answer that lands a real
flaw revises the `PLAN` file on disk before the dispatch, as plain plan
text: no advisor attribution, no "changes after review" section; the
summary's `Advisor:` row carries it (OUTPUT below). Absent or erroring →
dispatch as written.
The advice never enters a challenger brief: they stay blind.

```

### Block F
```
- a CHALLENGE SUMMARY: each BLOCKER raised → the named change that closed it;
  anything `[deferred]`; any lens that failed to return; and an `Advisor:`
  row, added to whatever summary template the caller prints: each plan
  change an advisor answer drove, `called, no change`, or
  `not called (absent | error | already called this run)`.
```

### Block Dfloor
```
  A second UNMET with no main-loop advisor call since GATE 0 first ran →
  the main loop calls it before the re-dispatch
  (`lib/effort-shift.md` § Advisor); the answer stays here, never
  in the dev brief.
```

### Block Dconf
```
  A second ECARTS with no main-loop advisor call since GATE 0 first ran →
  the main loop calls it before the re-dispatch
  (`lib/effort-shift.md` § Advisor); the answer stays here, never
  in the dev brief.
```

### Block Dsec
```
  A second BLOCK with no main-loop advisor call since GATE 0 first ran →
  the main loop calls it before the re-dispatch
  (`lib/effort-shift.md` § Advisor); the answer stays here, never
  in the dev brief.
```

### Block Dstruct
```
  A 2nd structural failure with no main-loop advisor call since GATE 0
  first ran → the main loop calls it before escalating
  (`lib/effort-shift.md` § Advisor).
```

### Block G
```
Every cap or escalation STOP above: when the main loop consulted the advisor
since GATE 0 first ran, the STOP carries its answer and says whether it
predates the last iteration.

```

### Block E
```
- Advisor, when dispatched as a sub-agent: at most one call, after the last
  TASKS or PROCESS step and before the OUTPUT, whatever the harness prompt
  schedules; absent or erroring → proceed. Advice may point you back to
  the code; every OUTPUT line rests on what you read, never on the advice
  alone. Advice proposing a design or a fix counts only where the brief
  asks for a fix.
```

## Edge cases
- Every new line ≤ 80 columns; every `§ Label` citation on one line followed by
  `)` or `;` (census extractor: 6 × effort-shift § Advisor, 2 × CLAUDE.global.md
  § Workflow) — checked by script.
- Contract CHECKs 1-5 simulated on a scratch copy with apply.py: all equal EXPECT.
- Stuck-call unit counts main-loop calls only; plan point skipped when the main
  loop already consulted the advisor in this skill run.
- lib/tests pin "NEVER a PASS" lines: unchanged.

## Tests
None added (prose). Oracles: contract greps; fast census
`bash lib/tests/doctrine-citers.test.sh`; full `make test`.

## Disposition
- amends BDR-150 (6ef3069): plan point in challenge-plan; analyzer joins; (c).
- honors LRN-294 / BUGS-FOUND residual: prose; run C measures.
- honors BDR-066 / LRN-083: advice stays in the main loop, never in an executor
  or challenger brief, never attributed in the plan file.
- applies LRN-295 cost: at most one plan call per skill run, at most one stuck
  call per verify-secure run, no second call for the same recommendation.
