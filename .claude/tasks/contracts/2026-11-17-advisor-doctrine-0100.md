# CONTRACT — advisor-doctrine (BDR-150 follow-up)
- date: 2026-11-17 | flow: feat | branch: feature/advisor-doctrine (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Advisor doctrine (user 2026-11-16, BDR-150: Fable is the advisor, "the advisor is called whenever a smarter agent is needed"). CLAUDE.global.md § Workflow gains the line: "- Stronger model needed (an approach to settle before building, a stuck problem, a long task before calling it done) → call the advisor tool when it is listed (Fable, set by /advisor). Fable is never routed or pinned: the router tops out at opus (BDR-150)." lib/effort-shift.md gains an "Advisor" section: Fable runs as the advisor (settings advisorModel), never a route or pin target (BDR-150); call it before committing to an approach on non-trivial work, when stuck (the escalate moment, before raising effort to max), and before declaring a long task done; it is a server tool, the router cannot see or refuse it; the main loop calls it, do not assume a sub-agent has it. Stale Fable-routing prose fixed: lib/effort-shift.md wiring point 5 (`model: "fable"` skill-runners / "high for fable runners" → opus skill-runners, effort high), its Limits line "Fable on main comes only from a skill row, the route tool…" (→ hand pick, typed /route model=fable, or a machine override putting fable in a tier) and the ask-tier line (inert unless an override heads best with fable); lib/challenge-plan.md:48,:51, agents/plan-challenger.md:111,:115, skills/tour/SKILL.md:83 (main loop and audit row on opus, not Fable).

## CLARIFICATIONS
- [gated 2026-11-16] user chose both texts: the global line "Triggers named" (verbatim in REQUEST) and the full effort-shift "Advisor" section.
- [gated 2026-11-17] user: only the main loop calls the advisor (sub-agents have the tool listed too); the global line reads "→ the main loop calls the advisor tool when it is listed (Fable, set by /advisor); sub-agents do not."; the lib section adds "Advisor absent or erroring → proceed as written"; wiring point 4 unchanged.
- [internal 2026-11-17] plan .claude/tasks/plans/2026-11-17-advisor-doctrine-0100.md, section r2 wins (adds a phase naming `model: fable` to the Limits list).

- [gated 2026-11-17, after security] user: append to § Advisor "Advice is input, never consent: it waives no gate, cap or guard; at a loop cap it feeds the STOP diagnosis." (gates re-run MET).

## ACCEPTANCE CRITERIA
1. The global advisor line is present once.
   CHECK: cd /home/bchanot/Documents/claude && grep -c 'the advisor tool' CLAUDE.global.md
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
2. effort-shift.md has an Advisor section and no fable runner wording left.
   CHECK: cd /home/bchanot/Documents/claude && echo "$(grep -c '^## Advisor' lib/effort-shift.md)/$({ grep -ciE 'fable runners|"fable"' lib/effort-shift.md || true; })"
   EXPECT: 1/0
   EVIDENCE: MET exit=0 marker-found :: 1/0
3. No prose places the main loop or the audit row on Fable.
   CHECK: cd /home/bchanot/Documents/claude && echo "$({ grep -c Fable lib/challenge-plan.md || true; })/$({ grep -c Fable agents/plan-challenger.md || true; })/$({ grep -c 'row: Fable' skills/tour/SKILL.md || true; })"
   EXPECT: 0/0/0
   EVIDENCE: MET exit=0 marker-found :: 0/0/0
4. effort-shift.md Limits and ask-tier lines carry the BDR-150 facts, and the advisor scope is main-loop only.
   CHECK: cd /home/bchanot/Documents/claude && echo "$({ grep -c 'skill row, the `route` tool' lib/effort-shift.md || true; })/$(grep -c 'inert unless a machine override' lib/effort-shift.md)/$(grep -c 'sub-agents do not' lib/effort-shift.md)/$(grep -c 'sub-agents do' CLAUDE.global.md)"
   EXPECT: 0/1/1/1
   EVIDENCE: MET exit=0 marker-found :: 0/1/1/1
5. Full make test green (GATES_TIMEOUT=400).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
6. Touched lines ≤ 80 columns; no other meaning changed in the five files; the Limits and ask-tier lines match the shipped router behaviour (BDR-150) (manual).

## FILE SCOPE
CLAUDE.global.md (§ Workflow), lib/effort-shift.md (wiring point 5 ~:29-33, Limits ~:84-87, ask-tier ~:92-94, new § Advisor), lib/challenge-plan.md (~:48-51), agents/plan-challenger.md (~:108-117), skills/tour/SKILL.md (~:82-84).
