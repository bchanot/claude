# Handoff plan: done, triage and loop levers (user 2026-11-20)

User ask (2026-11-20, verbatim): "Et comment faire pour avoir une loop sans qu'on ait en boucle
des low-priority qui se développent. De façon à ce qu'on loop jusqu'à ce qu'on soit sûr de ce
qu'on a développé et qu'on dise : bah c'est fini jusqu'à preuve du contraire par les tests ?"
then "oui lance une session neuve avec les six leviers et faire ça dedans". Run as one /feat
(5 files). It creates a mechanism (not a placement), so it keeps its plan challenge.

## Evidence (session c9afbcbf, 2026-11-19/20)
- Open TODO 44 → 50 over the session although items were closed; BUGS-FOUND 67 bullets.
- No doctrine rule requires logging a MINOR: "never silently carried" covers BLOCKERs only
  (lib/challenge-plan.md:12-13); feat/bugfix/ship-feature, verifier and security-auditor never
  name BUGS-FOUND. The minor → TODO/BUGS-FOUND flow was the main loop's habit (and some advisor
  instructions), copied from earlier runs.
- Where reviews paid: DEGRADED bugfix (a terminal PASS bullet ahead of the DEGRADED note),
  advisor leak (a false root cause overturned by the challenge: CLAUDE.md already reached
  sub-agents), Run C (window loss, Infinity lastRun; marginal).
- Where they did not: TODO:14 runs 1-2, each placing a clause the user had decided: 6 challengers
  + 2 plan advisor calls, no MAJOR. The 3 verifier ECARTS of the advisor run were all bookkeeping
  from the main loop's own contract text (locals in a test callback, plan artifacts and 4 agent
  files outside FILE SCOPE, a lint suppression); both first-run GATE 0 failures were contract
  wording. Two post-gate fix rounds each cost a full gate cycle (plus one scope question).
- Each main-loop advisor call resends the whole transcript (700k+ tokens late in the session).

## The six levers (reviewed with the advisor 2026-11-20)
1. Done = oracles green. A run is done when the contract criteria are MET, the tests pass and
   the gates are clean. After done, a review reopens it only with reproducible evidence: a
   command that fails on HEAD, or real output shown wrong. A plausible scenario alone does not
   reopen. A behavioural claim ("agents obey") is done at locks green + one live probe + one
   dated measurement (TODO line with date and tripwires). Trade accepted: the advisor-run opus
   review's allowance finding would have gone to the dated check, not a fix round.
2. MINOR triage: a MINOR is fixed before dispatch (folded into the plan) or dropped. No post-gate
   fix of a MINOR (it costs a full gate cycle). A drop is one line in the run report, nothing in
   any registry. The backlog only takes findings with reproducible evidence, or what the user asks.
3. Challenge only when a decision is open. A run that only places a decision the user already
   made (exact text dictated by that decision, no new design) skips the plan challenge and its
   plan advisor call; gates still run. The split is NOT code vs text. Check against the five runs
   of session c9afbcbf: only TODO:14 runs 1-2 go gates-only; DEGRADED, Run C and the advisor leak
   keep their challenge.
4. Loop with a frozen list. An autonomous "do the TODOs" loop works the list that exists when
   the user starts it (plus items the user adds). Items born during the loop are reported, not
   run, unless they break what the loop shipped. Termination by construction; this formalizes
   the user's own "sauf si tu vois que ça se répète".
5. Contract hygiene (main loop): before any dispatch, `gates.sh status` on the contract and a dry
   run of each CHECK; transient plan artifacts (docs/superpowers/plans/**, the run's
   .claude/tasks contract and plan) are in FILE SCOPE by default (verifier side).
6. Visibility: every run summary prints `TODO +n / -m` (items added / closed by the run).

Cut after review: a TODO cap or expiry (50 open: a cap of 10 starts violated; /prune-memory
curates registries, not TODO.md); a "fix if under five minutes" exit after the gates.

## Carriers (where it is written; the permission to drop must be written, else the next
session repeats the habit)
- lib/verify-secure-loop.md — levers 1 and 2 (done, reopen evidence, MINOR triage).
- lib/challenge-plan.md — lever 3 (placement skips the challenge and its advisor call; summary
  row says so).
- CLAUDE.global.md — lever 4, one line (319/320 budget: exactly one line left).
- lib/capitalize-commit.md — lever 6 (`TODO +n / -m` beside the memory-commit hash).
- agents/verifier.md — lever 5 scope default for transient plan artifacts; the main-loop dry run
  rides lever 1's text in lib/verify-secure-loop.md.
Not loosened: safety guardrails (destructive tools, gitflow, secrets), GATE 0, verifier,
security gate, user gates on visible / public-name / scope choices.

## Proof of the change
After ~5 runs: dispatches per run, `TODO +n / -m` per run, and any post-merge bug traced to a
dropped MINOR (BUGS-FOUND entry naming a merged run). Log as an EVAL.
