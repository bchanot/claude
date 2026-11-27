# Challenge the plan — shared orchestrator include

Runs in the ORCHESTRATOR MAIN LOOP after a plan / reflection is elaborated and
BEFORE it is executed. Turns a fresh plan into a hardened one by attacking it
from three independent angles, then RE-THINKING every aspect a challenger lands.
Loop + synthesis decisions live here, in the main loop (BDR-066: reflection runs
on the big model; `verify-secure-loop.md`: fresh blind gates, decisions in the
loop). It never merges, executes, or edits code — it hardens the plan and hands
it to the orchestrator's existing human gate.

The challenge is ADVISORY into that gate (its one hard stop is the deferred
stop of OUTPUT below), but a BLOCKER is never silently carried past: it is
either closed by a NAMED plan change or explicitly deferred for the human.

## Inputs the caller must have ready

- `PLAN`: path to the plan ON DISK. If your plan is still inline (a printed
  checklist / diagnosis / fix plan), FIRST persist it to
  `.claude/tasks/plans/<date>-<slug>-<HHMM>.md` — the challengers read from disk
  and judge blind, exactly like the verifier reads the contract.
- `KIND`: `build-plan` | `proposals` | `fix-bundle` — tunes the lens framing
  below; the mechanism is identical.
- `SCOPE`: the files/dirs the plan touches (grounds the critique).
- `CONSTRAINTS` (optional): the decided trade-offs / rejected alternatives from
  the design step, so a lens does not re-litigate a settled choice.

Nominal path is cheap for a small, clean plan: three parallel challengers return
SOLID, synthesis is a no-op. It only costs more when a lens lands a real finding
— which is the point.
The main loop's advisor calls (below) are the costliest items: one before
the dispatch, one on the first synthesis when a lens found a BLOCKER or MAJOR.

## SKIP: a placed decision

A run that only places a decision the user already made skips this phase:
no challengers and no plan advisor call. Three conditions, all required:
the exact text or change is dictated by that decision (no new design); the
decision's text is the user's own words, or was challenged in the run that
wrote it; and the caller runs `lib/verify-secure-loop.md` after its
dispatch, so the gates still run. The test is whether the run settles an
open choice of its own (a mechanism, a condition, a threshold, wording the
user did not dictate), never code versus text; in doubt, challenge. The
skip is this include's own path (user decision 2026-11-20): a skill's
challenge step that reads this section runs as written, and the skip
discharges the plan point (`lib/effort-shift.md` § Advisor). The caller prints
`Challenge: skipped (placed decision: <the user's decision, date>)` in
place of its CHALLENGE SUMMARY.

Challenged or skipped: when the flow wrote a contract with `CHECK:` lines,
before the executor dispatch the main loop records `- run-base:` in the
contract and runs `gates.sh run` on a `mktemp -d` copy of it
(`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH).

## DISPATCH — three fresh challengers, in parallel, blind

**Advisor first (main loop).** Before the first dispatch, with no main-loop
advisor call since the skill run started (never
before a re-challenge), the main loop reads the `PLAN` file unless its full
text is already in this conversation, then calls the advisor when the tool
is listed (`lib/effort-shift.md` § Advisor). An answer that lands a real
flaw revises the `PLAN` file on disk before the dispatch, as plain plan
text: no advisor attribution, no "changes after review" section; the
summary's `Advisor:` row carries it (OUTPUT below). Absent or erroring →
dispatch as written. A skill run inside a sub-agent skips both calls (its
row reads `not called (sub-agent)`, BDR-150).
The advice never enters a challenger brief: they stay blind.

Dispatch THREE fresh `plan-challenger` subagents IN PARALLEL, one per LENS, each
blind to the others and to this conversation:

```
Agent(subagent_type="plan-challenger", description="challenge:<lens>", prompt="""
  PLAN: <the PLAN path>
  LENS: <correctness | robustness | simplicity>   # one per agent — all three
  SCOPE: <SCOPE>
  CONSTRAINTS: <CONSTRAINTS, if any>
""")
```

**MODEL (BDR-076, supersedes the BDR-066 inherit):** plan critique is AUDIT
JUDGMENT — the challengers are routed to the `judge` row (opus) by the model-router,
the `model: opus` frontmatter being the off-state floor: a big tier, off
the main loop. The main loop (opus through its best-tier row)
keeps only this loop — synthesis, RE-THINK, gate. Never sonnet: that would
silently downgrade the judgment. (The executors stay sonnet; the two merge
gates sit on the `audit` row, opus.)

**Lens framing by `KIND`** (the agent's three lenses, read against the artifact):
- `build-plan` — will it WORK / will it BREAK / is it needlessly COMPLEX.
- `proposals` — are these the RIGHT items & priorities / what did the audit MISS
  or under-rate as risk / is the backlog over- or under-scoped.
- `fix-bundle` — will each fix ACHIEVE its goal / could it BREAK or regress the
  page / is there a simpler fix, or an unnecessary one.

## FAIL-SAFE — never fail open

A challenger that returns a malformed/empty verdict, a missing `PROOF`, or dies →
retry ONCE with a fresh challenger; a 2nd failure on that lens → STOP and escalate
(the STOP text names the level reached, `$CLAUDE_EFFORT`, and suggests relaunching with
`ultrathink` in the prompt (turn floor) or `/route effort=max` (sticky,
`/route clear` after); no shift here: a mute challenger is an infrastructure failure)
to the human, NAMING the lens. Never carry "plan challenged" into the gate on a
silently dropped lens (`verify-secure-loop.md`: "a mute verifier is NEVER a PASS").

## SYNTHESIZE + RE-THINK (main loop, big model)

Parse each `CHALLENGE — LENS: … — VERDICT:` line and merge the FINDINGS:

- **Severity-driven, not consensus.** Any `[BLOCKER]` from ANY single lens is
  must-address — the lenses are orthogonal, so a lone security/rollback finding
  is real, never outvoted by lens-count. Cross-lens agreement only RANKS the MINORs.
  Each MINOR is folded into the plan now or dropped: a drop is one
  `MINOR dropped: <finding>` line in the report and the plan file, nothing
  in TODO.md or a registry; a security finding goes to the user
  (`lib/verify-secure-loop.md` § MINOR triage).
- **RE-THINK the aspect the challenge pointed at.** For each BLOCKER (and each
  MAJOR you accept): revise the plan on THAT aspect — a NAMED, diffable change to
  the plan, never a self-authored "addressed" line. A BLOCKER you consciously keep
  is tagged `[deferred <date>]`, handled per OUTPUT below.
- **Advisor on the first synthesis (main loop).** When any lens of the
  first pass returned a BLOCKER or a MAJOR, once every finding is accepted,
  dropped or deferred (the `PLAN` revised and re-persisted where a change
  was accepted) and before any confirmation challenger, the main loop calls
  the advisor on the plan and its synthesis decisions, when the tool is
  listed. This call is due whatever earlier call the run made. An answer
  that lands a real flaw revises the `PLAN` again, as plain plan text. All
  lenses SOLID: no call. No call after the confirmation pass. Absent or
  erroring → go on. The advice never enters a challenger brief.
- **Re-challenge once if the plan materially changed** — a fix can open a new
  flaw. Re-persist the revised `PLAN`, dispatch ONE fresh confirmation challenger,
  max 1 extra pass, then the gate. A BLOCKER or MAJOR that confirmation pass
  still lands on a point the revision touched is not revised again: it is
  tagged `[deferred <date>]` with the finding quoted, handled per OUTPUT
  below.

The synthesis is this loop's own work. Which finding is accepted, dropped
or deferred, and the named change that closes it, are never handed to
another agent. Applying changes already decided to a long plan file may be
dispatched as drafting: general-purpose, `model: "sonnet"`, a brief that
lists each decided change (`lib/model-gate.md`, dispatch tiers); the loop
then re-reads each decided change in the file before the next step.

## OUTPUT — into the existing human gate

Feed the orchestrator's gate:
- the REVISED plan, and
- a CHALLENGE SUMMARY: each BLOCKER raised → the named change that closed it;
  anything `[deferred]`; any lens that failed to return; and an `Advisor:`
  row, added to whatever summary template the caller prints, covering both
  calls (plan, synthesis): each plan change an advisor answer drove and
  which call drove it, `called, no change`, or
  `not called (absent | error | already called this run | sub-agent)`;
  a synthesis call that was not due reads `not called (all SOLID)`.
  Whatever single slot a caller's template shows, the row is printed in
  two parts, `plan: <value>; synthesis: <value>`.

The human remains the decider.

Every `[deferred]` point, from any pass, stops the run once, at the end of
the challenge step (after any confirmation pass) and before the caller's
next step, whatever gate the caller holds later: one batched question to
the human, each finding quoted and each option's effect stated. Per
point: keep (the plan runs as written), cut (the item leaves the plan,
and the report or envelope the caller applies from when it applies from
one) or reopen (the main loop revises it). After a cut or a reopen the run
goes on with no further challenge unless the human asks for one (then one
confirmation challenger, whose deferred points are asked once, with no
challenger after them). A keep or cut answer binds the rest of the run:
it is appended to the contract's CLARIFICATIONS as `[gated <date>]`, with
every criterion that requires a cut item amended in the same entry, and
it joins the CONSTRAINTS of every later challenge, so it is never
re-asked. /hotfix asks the same question itself, with no escalation. No
human reachable (a sub-agent run, headless): stop and hand the points
back. No `[deferred]` point, no extra stop.
