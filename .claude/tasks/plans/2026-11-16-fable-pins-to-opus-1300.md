# PLAN — fable-pins-to-opus (BDR-150 follow-up)

## APPROACH
1. agents/client-handover-writer.md: the 7 `model: "fable"` occurrences
   become `model: "opus"`, `effort="high"` kept on each. In the BDR-077
   paragraph (~:268-271) the sentence keeps its meaning: skill-runners carry
   `model: "opus"` and `effort="high"`, never inherit the session model; add
   "(BDR-150: Fable is the advisor, never a dispatch target)".
2. skills/client-handover/SKILL.md ~:34: "skill-runner children dispatched
   `model: "fable"`" → `model: "opus"`.
3. lib/model-gate.md Dispatch tiers paragraph: "`model: "fable"` when the
   child reflects/orchestrates for the main loop (skill-runners), else its
   tier (opus = dispatched judgment, ...)" → "`model: "opus"` for
   skill-runners (the child reflects/orchestrates for the main loop) and
   for dispatched judgment, sonnet = execution, haiku = mechanical probes;
   Fable is never a dispatch target, it is the advisor (BDR-150)". The
   gate's answer table stays (a fable id still proceeds: a hand-picked
   Fable session may run a skill); its STOP text stays "require Fable or
   Opus".
4. lib/tests/model-routing.test.sh block 12 (~:88-95): comment says
   skill-runner children are pinned opus since BDR-150 (Fable = advisor);
   `has client-handover-writer.md 'model: "opus"'`, `has model-gate.md
   'model: "opus" for skill-runners'` (the new phrase), plus `lacks` on
   'model: "fable"' in client-handover-writer.md, skills/client-handover/
   SKILL.md and model-gate.md.
5. lib/tests/effort-routing.test.sh ~:224-225: count the `model: "opus"`
   lines of client-handover-writer.md (must be ≥ 1, else ko: a vacuous
   pass) and require every one to carry `effort="high"`.

## EDGE CASES
- lib/effort-shift.md ("`high` for fable runners", wiring point 5) is the
  doctrine run's file, out of scope here; it stays stale until that run
  (next, same session).
- README.md:107 and :132 citers → doc-sync step.

## DISPOSITION
Amends BDR-077 W1 (skill-runner pins fable → opus) per BDR-150. Honors
BDR-108 (pins stay tier aliases).

## FILES
agents/client-handover-writer.md, skills/client-handover/SKILL.md,
lib/model-gate.md, lib/tests/model-routing.test.sh,
lib/tests/effort-routing.test.sh.

## r2 (challenge r1: correctness CONCERNS(1), robustness CONCERNS(1), simplicity SOLID) — amends APPROACH 1-5
1. client-handover-writer.md: swap the 7 `model: "fable"` for `model: "opus"`
   only; `model: "opus"` and `effort="high"` stay on the SAME physical line
   at each site; no BDR-150 parenthetical in this file.
2. model-gate.md Dispatch tiers paragraph: one tier list, e.g. "its tier:
   `model: "opus"` = skill-runners (the child reflects/orchestrates for the
   main loop) and dispatched judgment, sonnet = execution, haiku =
   mechanical probes; never fable (BDR-150, the advisor)." Keep the file
   short (≤ 31 lines). Gate table: add one row: the answer says the model
   is `fixed at spawn` (the route tool called inside a sub-agent, e.g. a
   pinned skill-runner running a gated skill) → proceed, SILENT.
3. model-routing.test.sh block 12: replace the whole block comment (spike
   lines included) with: skill-runner children pinned opus since BDR-150
   (Fable is the advisor, never a dispatch target). Assertions: `has
   client-handover-writer.md 'model: "opus"'`, `has lib/model-gate.md
   'model: "opus"'` (no backtick in the needle; the string is absent from
   model-gate.md today), `has lib/model-gate.md 'fixed at spawn'`, and ONE
   repo-wide census: `git -C "$R" grep -nE 'model ?[:=] ?"fable"' --
   agents skills lib ':!lib/tests'` must print nothing (ko with the hits).
4. effort-routing.test.sh ~:224-225: following the onboard idiom
   (:220-222): count the lines of client-handover-writer.md holding
   `model: "opus"`; require `-eq 7` and that the same 7 carry
   `effort="high"` (equal counts).
5. Tracking (closing step, not the executor): TODO.md Actionable line for
   lib/effort-shift.md:30-32 (wiring point 5 still names fable runners) +
   README.md:109, :134, plan-challenger.md:111,:115, challenge-plan.md:48,
   :51, skills/tour/SKILL.md:83 → the doctrine run (next); TODO.md:151
   residual ("explicit Agent(model:"fable") pins … fail w/o credits")
   rewritten: now an opus runner failure marks opus down in the breaker
   and demotes main to the sonnet stand-in for the cooldown (accepted
   residual, BDR-150).
