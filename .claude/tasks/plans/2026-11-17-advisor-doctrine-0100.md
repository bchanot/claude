# PLAN — advisor-doctrine (BDR-150 follow-up)

## APPROACH
1. CLAUDE.global.md § Workflow: insert as a new bullet right after the
   "Sub-agents: one task each…" bullet, wrapped ≤ 80 columns, the user's
   text verbatim: "- Stronger model needed (an approach to settle before
   building, a stuck problem, a long task before calling it done) → call
   the advisor tool when it is listed (Fable, set by /advisor). Fable is
   never routed or pinned: the router tops out at opus (BDR-150)."
2. lib/effort-shift.md:
   a. wiring point 5: "(`general-purpose` `model="opus"`, `model: "opus"`
      skill-runners) → explicit `effort=` on the Agent call (`xhigh` for
      opus reviewers, `high` for skill-runners)." Rest unchanged.
   b. Limits bullet: "…set the turn's effort only, never a model above the
      session model: Fable on main comes only from a hand pick (`/model`,
      picker), a typed `/route model=fable` or a machine override that puts
      fable in a tier (no shipped tier holds it, BDR-150)."
   c. ask-tier mention (~:92-94): "`/route ask-tier off|on` the ask before
      a route lifts main or a rowed agent onto Fable (inert unless a
      machine override heads `best` with fable)".
   d. new section "## Advisor" placed before "## Never" (or before
      "## Limits" if "## Never" is absent), ≤ 8 lines: Fable runs as the
      advisor (settings `advisorModel`), never a route or pin target
      (BDR-150). Call it before committing to an approach on non-trivial
      work, when stuck (the `escalate` moment, before raising effort to
      max), and before declaring a long task done. It is a server tool:
      the router cannot see or refuse it. The main loop calls it; do not
      assume a sub-agent has it.
3. lib/challenge-plan.md ~:48 "(Fable through its best-tier row)" → "(opus
   through its best-tier row)"; ~:51 "the two merge gates sit on the
   `audit` row, Fable with an opus floor" → "… on the `audit` row, opus".
4. agents/plan-challenger.md ~:111 "on Fable through its best-tier row" →
   "on opus through its best-tier row"; ~:115 "sit on the `audit` row,
   Fable with an opus floor" → "sit on the `audit` row, opus".
5. skills/tour/SKILL.md ~:83 "security-auditor (`audit` row: Fable, opus
   floor)" → "security-auditor (`audit` row: opus)".

## EDGE CASES
- Do not touch lib/effort-shift.md's /model dialog paragraph (fable is
  still offered there by hand, true).
- doctrine-citers census in make test: headings cited elsewhere must stay
  intact; adding "## Advisor" changes no existing heading.

## DISPOSITION
Honors BDR-150 (Fable = advisor, never routed or pinned) and the user's
2026-11-16 wording choices. Amends nothing else.

## FILES
CLAUDE.global.md, lib/effort-shift.md, lib/challenge-plan.md,
agents/plan-challenger.md, skills/tour/SKILL.md.

## r2 (challenge r1: correctness CONCERNS(1), robustness CONCERNS(1), simplicity CONCERNS(1)) — amends APPROACH; final
User answers 2026-11-17: only the main loop calls the advisor (sub-agents
have the tool listed too: every challenger, gate and executor would send
its whole transcript to Fable outside the router's caps); add the fallback
"advisor absent or erroring → proceed as written"; wiring point 4 unchanged.
1. CLAUDE.global.md § Workflow, new bullet right after the "Sub-agents: one
   task each…" bullet, text (user line, amended by the main-loop answer):
   "- Stronger model needed (an approach to settle before building, a stuck
   problem, a long task before calling it done) → the main loop calls the
   advisor tool when it is listed (Fable, set by /advisor); sub-agents do
   not. Fable is never routed or pinned: the router tops out at opus
   (BDR-150)." Wrap ≤ 80 columns like the neighbouring bullets (2-space
   continuation); the phrase "the advisor tool" stays on one line.
2. lib/effort-shift.md:
   a. wiring point 5 as in APPROACH 2a.
   b. Limits: "Fable on main comes only from a hand pick (`/model`,
      picker), a typed `/route model=fable`, a phase naming `model: fable`
      or a machine override that puts fable in a tier (no shipped tier or
      phase holds it, BDR-150)." Keep "a typed `/route model=fable`" on one
      line.
   c. ask-tier as in APPROACH 2c; keep "inert unless a machine override"
      on one line.
   d. "## Advisor" placed right before "## Never": the APPROACH 2d text,
      with "The main loop calls it; sub-agents do not, even when the tool
      is listed. Advisor absent or erroring (Fable out of credits, for
      example) → proceed as written."
3-5. As APPROACH 3-5. agents/plan-challenger.md: the second target spans
   lines 115-116 ("…sit on the `audit` row, Fable with an" / "opus
   floor.)"): replace across both lines → "…sit on the `audit` row,
   opus.)".
6. Rollback: the five files are live machine-wide from the working tree;
   if anything misbehaves, `git checkout develop -- <the 5 files>`. Do not
   run gates mid-edit.
