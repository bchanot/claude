# Challenge the plan — shared orchestrator include

Runs in the ORCHESTRATOR MAIN LOOP after a plan / reflection is elaborated and
BEFORE it is executed. Turns a fresh plan into a hardened one by attacking it
from three independent angles, then RE-THINKING every aspect a challenger lands.
Loop + synthesis decisions live here, in the main loop (BDR-066: reflection runs
on the big model; `verify-secure-loop.md`: fresh blind gates, decisions in the
loop). It never merges, executes, or edits code — it hardens the plan and hands
it to the orchestrator's existing human gate.

The challenge is ADVISORY into that gate — no new hard block — but a BLOCKER is
never silently carried past: it is either closed by a NAMED plan change or
explicitly deferred for the human.

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

## DISPATCH — three fresh challengers, in parallel, blind

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

**MODEL (BDR-066):** plan critique is AUDIT JUDGMENT — do NOT pin
`model: "sonnet"`; the challengers inherit the big session model. (The executor
gates stay sonnet; the challenger does not.)

**Lens framing by `KIND`** (the agent's three lenses, read against the artifact):
- `build-plan` — will it WORK / will it BREAK / is it needlessly COMPLEX.
- `proposals` — are these the RIGHT items & priorities / what did the audit MISS
  or under-rate as risk / is the backlog over- or under-scoped.
- `fix-bundle` — will each fix ACHIEVE its goal / could it BREAK or regress the
  page / is there a simpler fix, or an unnecessary one.

## FAIL-SAFE — never fail open

A challenger that returns a malformed/empty verdict, a missing `PROOF`, or dies →
retry ONCE with a fresh challenger; a 2nd failure on that lens → STOP and escalate
to the human, NAMING the lens. Never carry "plan challenged" into the gate on a
silently dropped lens (`verify-secure-loop.md`: "a mute verifier is NEVER a PASS").

## SYNTHESIZE + RE-THINK (main loop, big model)

Parse each `CHALLENGE — LENS: … — VERDICT:` line and merge the FINDINGS:

- **Severity-driven, not consensus.** Any `[BLOCKER]` from ANY single lens is
  must-address — the lenses are orthogonal, so a lone security/rollback finding
  is real, never outvoted by lens-count. Cross-lens agreement only RANKS the MINORs.
- **RE-THINK the aspect the challenge pointed at.** For each BLOCKER (and each
  MAJOR you accept): revise the plan on THAT aspect — a NAMED, diffable change to
  the plan, never a self-authored "addressed" line. A BLOCKER you consciously keep
  is tagged `[deferred <date>]` for the human to accept at the gate.
- **Re-challenge once if the plan materially changed** — a fix can open a new
  flaw. Re-persist the revised `PLAN`, dispatch ONE fresh confirmation challenger,
  max 1 extra pass, then the gate.

## OUTPUT — into the existing human gate

Feed the orchestrator's gate:
- the REVISED plan, and
- a CHALLENGE SUMMARY: each BLOCKER raised → the named change that closed it;
  anything `[deferred]`; and any lens that failed to return.

The human remains the decider.
