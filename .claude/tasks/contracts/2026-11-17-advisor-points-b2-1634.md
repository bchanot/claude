# CONTRACT — advisor-points-b2
- date: 2026-11-17 | flow: ship-feature | branch: feature/advisor-points-b2 (off develop, created at STEP 4)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Run B2 of the advisor call points (follow-up to BDR-150, runs A 6ef3069 and B1 58a5273, both merged into develop).

Read first:
- .claude/tasks/TODO.md, the "Advisor call points" block: the "Run B2" line holds the full scope
- lib/effort-shift.md § Advisor (the source of truth for the call points)
- .claude/audits/BUGS-FOUND.md, the advisor entries (block E LOW, verifier/security-auditor not limited to dispatch, plan-challenger mirror)
- LRN-295, LRN-296, LRN-284; the B1 contract and plan as a model: .claude/tasks/{contracts,plans}/2026-11-17-advisor-points-b1-1500.md

Scope (10 files):
1. A "stuck" trigger line in the gate step of the 6 skills that restate the verify-secure loop: feat, bugfix, ship-feature, init-project, a11y, guardrails. It points to lib/verify-secure-loop.md and lib/effort-shift.md § Advisor (second failure of a gate loop, main-loop calls only since GATE 0, the advice never goes into an executor's brief).
2. Merge point: ONE line in lib/capitalize-commit.md (the shared tail of feat, bugfix, hotfix, ship-feature, init-project, audit-delta, tour), plus skills/release-candidate STEP 4.
3. agents/security-auditor.md: the class severity applies only when it is higher, and "Advice never removes, lowers or waives…".
4. agents/verifier.md and agents/security-auditor.md: advisor rule limited to "when dispatched".
5. agents/plan-challenger.md: the ORCHESTRATOR PROTOCOL mirror gains the "Advisor first" step and the `Advisor:` row.
Optional, low: blank line before block I in effort-shift § Advisor (it renders as part of item 3).

Over /feat's 5-file cap: ask me first whether this goes through /ship-feature or through two /feat runs (skills, then libs + agents).

Method (lessons from A and B1):
- Apply the advisor rules you're editing: advisor on the written plan before the challengers, before the merge.
- Write each text into a file, apply the edit with an exact-match script on a scratch copy (mktemp, never rm -rf through a variable), and run every contract CHECK on it before dispatch (LRN-296).
- Every marker and every `§ Label` citation stays on a single line, followed by `)` or `;`. Never label a criterion `Nb.` (LRN-284). Use GATES_TIMEOUT=400 for the full make test.
- Gates in order: GATE 0, then the verifier, then security only after CONFORME. Never in parallel.
- At capitalize: call memory_pending first; add a BDR-150 status line; update the BUGS-FOUND entries you fixed.
- Docs: README/USAGE/CHANGELOG [Unreleased], the "Advisor doctrine" bullet.

## CLARIFICATIONS
- Q: route (11 files, 12 with the optional effort-shift line; two /feat runs hold at most 10) / A: /ship-feature, one run [gated 2026-11-17]
- Q: which flows the end-of-run advisor line applies to / A: code flows, no hotfix: feat, bugfix, ship-feature, init-project, audit-delta, tour; hotfix and the memory-only flows (capitalize, prune-memory, memory-feedback, deploy) excluded [gated 2026-11-17]
- Q: plugin gate SET dev / A: no, profile full kept [gated 2026-11-17]
- Q: merge point host (capitalize-commit is read whole only by feat, bugfix, ship-feature, init-project, plus hotfix, /capitalize, commit-changer; audit-delta and tour reach only § WRITE on an accepted offer) / A: each flow's own end step; lib/capitalize-commit.md stays untouched [gated 2026-11-17]
- Q: a11y and guardrails in the merge point / A: yes, included [gated 2026-11-17]
- Q: agents/plan-challenger.md advisor bullet scoped "when dispatched" too / A: yes [gated 2026-11-17]
- Q: TODO low item "12 skills send their reflect route with the challenger dispatch" / A: out of B2, own TODO line [gated 2026-11-17]
- Q: plan r3 deviations from the chat design (feat/bugfix end call before the COMPLETE summaries; audit-delta/tour call only when a fix was applied; route lines in ship-feature, init-project, release-candidate; `Advisor:` line in summaries; tour runner and STEP 0b wiring; effort-shift item 3 carries budget, skips and gate-flow fix path) / A: approved at the STEP 3 validation gate [gated 2026-11-17]

## ACCEPTANCE CRITERIA
1. Each of the 6 verify-secure skills (feat, bugfix, ship-feature, init-project, a11y, guardrails) carries, in its gate step, a stuck trigger citing `lib/verify-secure-loop.md` and `lib/effort-shift.md` § Advisor: second failure of a gate loop, main-loop calls only since GATE 0 first ran, the advice never enters an executor brief.
2. The merge point (effort-shift § Advisor item 3) is wired for the flows of CLARIFICATIONS and in skills/release-candidate STEP 4, citing `lib/effort-shift.md` § Advisor; hotfix, commit-changer and the memory-only flows gain no call.
3. agents/security-auditor.md advisor bullet: a STEP 3 class severity replaces the STEP 2 one only when higher; the sentence that advice never removes, lowers or waives a finding stays.
4. agents/verifier.md and agents/security-auditor.md advisor bullets apply when dispatched as a sub-agent.
5. agents/plan-challenger.md ORCHESTRATOR PROTOCOL mirrors lib/challenge-plan.md: the main-loop "Advisor first" step before the dispatch and the CHALLENGE SUMMARY `Advisor:` row.
6. lib/effort-shift.md § Advisor: a blank line separates item 3 from the "Inside a skill run" paragraph.
   CHECK: cd /home/bchanot/Documents/claude && awk '/^Inside a skill run, the points above/{print (prev=="" ? "BLANK-BEFORE-I" : "NO-BLANK")} {prev=$0}' lib/effort-shift.md
   EXPECT: BLANK-BEFORE-I
   EVIDENCE: MET exit=0 marker-found :: BLANK-BEFORE-I
7. Citation census green (fast oracle).
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/doctrine-citers.test.sh </dev/null 2>&1 | tail -1
   EXPECT: FAIL=0
   EVIDENCE: MET exit=0 marker-found :: PASS=23 FAIL=0
8. Full make test green (run gates.sh with GATES_TIMEOUT=400).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
9. Every test-locked phrase in the touched files stays on one unbroken line; touched lines ≤ 80 columns; no wording changed outside the planned blocks (manual).
10. [gated 2026-11-17] Stuck paragraph in each gate skill, citing the lib and § Advisor.
   CHECK: cd /home/bchanot/Documents/claude && for s in feat bugfix ship-feature init-project a11y guardrails; do f=skills/$s/SKILL.md; printf '%s:%s/%s ' "$s" "$(/usr/bin/grep -c 'Stuck: a gate loop fails twice with no main-loop advisor call since GATE 0' "$f")" "$(/usr/bin/grep -cF '(`lib/effort-shift.md` § Advisor); the answer never enters an executor brief.' "$f")"; done; echo
   EXPECT: feat:1/1 bugfix:1/1 ship-feature:1/1 init-project:1/1 a11y:1/1 guardrails:1/1
   EVIDENCE: MET exit=0 marker-found :: feat:1/1 bugfix:1/1 ship-feature:1/1 init-project:1/1 a11y:1/1 guardrails:1/1
11. [gated 2026-11-17] The stuck paragraph sits in the gate step (after a GATE 2 line, no heading between).
   CHECK: cd /home/bchanot/Documents/claude && for s in feat bugfix ship-feature init-project a11y guardrails; do awk -v s="$s" '/GATE 2/{g=NR} /^## /{h=NR} /Stuck: a gate loop fails twice/{m=NR; ok=(g>h)} END{printf "%s:%s ", s, (m&&ok)?"in-gate":"OUT"}' "skills/$s/SKILL.md"; done; echo
   EXPECT: feat:in-gate bugfix:in-gate ship-feature:in-gate init-project:in-gate a11y:in-gate guardrails:in-gate
   EVIDENCE: MET exit=0 marker-found :: feat:in-gate bugfix:in-gate ship-feature:in-gate init-project:in-gate a11y:in-gate guardrails:in-gate
12. [gated 2026-11-17] The end-of-run marker is in exactly the 9 flows (no hotfix, lib, agent or memory-only flow).
   CHECK: cd /home/bchanot/Documents/claude && echo "[$(/usr/bin/grep -rlF 'end-of-run advisor call (`lib/effort-shift.md` § Advisor)' skills lib agents | LC_ALL=C sort | tr '\n' ' ')]"
   EXPECT: [skills/a11y/SKILL.md skills/audit-delta/SKILL.md skills/bugfix/SKILL.md skills/feat/SKILL.md skills/guardrails/SKILL.md skills/init-project/SKILL.md skills/release-candidate/SKILL.md skills/ship-feature/SKILL.md skills/tour/SKILL.md ]
   EVIDENCE: MET exit=0 marker-found :: [skills/a11y/SKILL.md skills/audit-delta/SKILL.md skills/bugfix/SKILL.md skills/feat/SKILL.md skills/guardrails/SKILL.md skills/init-project…
13. [gated 2026-11-17] Each end marker occurs once, before its flow's done or merge moment.
   CHECK: cd /home/bchanot/Documents/claude && for t in 'feat|^## STEP 5 |^FEAT COMPLETE' 'bugfix|^## STEP 6 |BUGFIX COMPLETE' 'ship-feature|^## STEP 9 |finish   # feature' 'init-project|^## STEP 11 |finish   # feature' 'a11y|^## STEP 10:|^2[.] .mcp__model-router' 'guardrails|^## STEP 12:|^2[.] .mcp__model-router' 'audit-delta|^## STEP 4 |AUDIT-DELTA COMPLETE' 'tour|^Checks: pytest PASS|^TOUR COMPLETE' 'release-candidate|^### STEP 4 |^AskUserQuestion:'; do IFS='|' read -r s a b <<<"$t"; awk -v s="$s" -v a="$a" -v b="$b" '!sa && $0~a {sa=NR} index($0,"end-of-run advisor call (`lib/effort-shift.md` § Advisor)"){n++; m=NR} sa && !sb && NR>sa && $0~b {sb=NR} END{printf "%s:%s ", s, (n==1 && sa<m && m<sb)?"ok":"BAD"}' "skills/$s/SKILL.md"; done; echo
   EXPECT: feat:ok bugfix:ok ship-feature:ok init-project:ok a11y:ok guardrails:ok audit-delta:ok tour:ok release-candidate:ok
   EVIDENCE: MET exit=0 marker-found :: feat:ok bugfix:ok ship-feature:ok init-project:ok a11y:ok guardrails:ok audit-delta:ok tour:ok release-candidate:ok
14. [gated 2026-11-17] verifier, security-auditor and plan-challenger advise only when dispatched.
   CHECK: cd /home/bchanot/Documents/claude && for a in verifier security-auditor plan-challenger; do printf '%s:%s/%s ' "$a" "$(/usr/bin/grep -c '^- Advisor, when dispatched as a sub-agent: at most one call' "agents/$a.md")" "$(/usr/bin/grep -c 'Advisor (when listed)' "agents/$a.md")"; done; echo
   EXPECT: verifier:1/0 security-auditor:1/0 plan-challenger:1/0
   EVIDENCE: MET exit=0 marker-found :: verifier:1/0 security-auditor:1/0 plan-challenger:1/0
15. [gated 2026-11-17] security-auditor: a raise applies only upward, a no-op raise is neither tagged nor counted, advice never removes, lowers or waives.
   CHECK: cd /home/bchanot/Documents/claude && echo "[$(/usr/bin/grep -c 'A raise applies only when its class.s severity' agents/security-auditor.md)/$(/usr/bin/grep -c 'changes nothing: no tag,' agents/security-auditor.md)/$(/usr/bin/grep -c '^  Advice never removes, lowers or waives a finding from semgrep' agents/security-auditor.md)/$(/usr/bin/grep -c 'overrides the STEP 2 mapping' agents/security-auditor.md)/$(/usr/bin/grep -c 'It never removes' agents/security-auditor.md)]"
   EXPECT: [1/1/1/0/0]
   EVIDENCE: MET exit=0 marker-found :: [1/1/1/0/0]
16. [gated 2026-11-17] plan-challenger ORCHESTRATOR PROTOCOL: ADVISOR FIRST (pointer to the lib, its guards) before the dispatch bullet, `Advisor:` row in ADVISORY.
   CHECK: cd /home/bchanot/Documents/claude && echo "[$(/usr/bin/grep -c '^- ADVISOR FIRST (main loop): per `lib/challenge-plan.md`' agents/plan-challenger.md)/$(/usr/bin/grep -c 'with no main-loop advisor call since the skill run started; absent or' agents/plan-challenger.md)/$(/usr/bin/grep -cF 'an `Advisor:` row) feed the' agents/plan-challenger.md)/$(awk '/^## ORCHESTRATOR PROTOCOL/{p=NR} /^- ADVISOR FIRST/{a=NR} /^- Dispatch THREE fresh challengers/{d=NR} END{print (p && p<a && a<d)}' agents/plan-challenger.md)]"
   EXPECT: [1/1/1/1]
   EVIDENCE: MET exit=0 marker-found :: [1/1/1/1]
17. [gated 2026-11-17] effort-shift § Advisor item 3 keeps its generic trigger, names its sites, its own budget, the audit-delta/tour skip and the gate-flow-only fix path; § Advisor still names no STEP.
   CHECK: cd /home/bchanot/Documents/claude && sec() { sed -n '/^## Advisor/,/^## Never/p' lib/effort-shift.md; }; echo "[$(sec | /usr/bin/grep -c 'done. Wired at the end step of feat, bugfix,')/$(sec | /usr/bin/grep -c 'release gate of release-candidate: one end-of-run call per skill')/$(sec | /usr/bin/grep -c 'never skipped for an earlier plan or stuck call')/$(sec | /usr/bin/grep -c 'and tour skip it when the run applied no fix')/$(sec | /usr/bin/grep -c 'the answer is reported only and a fix it calls for is a new run')/$(sec | /usr/bin/grep -c STEP)]"
   EXPECT: [1/1/1/1/1/0]
   EVIDENCE: MET exit=0 marker-found :: [1/1/1/1/1/0]
18. [gated 2026-11-17] Every added line in the 13 files is at most 80 columns.
   CHECK: cd /home/bchanot/Documents/claude && n=$(/usr/bin/git diff develop -U0 -- skills/feat/SKILL.md skills/bugfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md skills/a11y/SKILL.md skills/guardrails/SKILL.md skills/audit-delta/SKILL.md skills/tour/SKILL.md skills/release-candidate/SKILL.md agents/verifier.md agents/security-auditor.md agents/plan-challenger.md lib/effort-shift.md | /usr/bin/grep '^+[^+]' | cut -c2- | LC_ALL=C.UTF-8 awk 'length>80' | wc -l); [ "$n" -eq 0 ] && echo WIDTH-OK
   EXPECT: WIDTH-OK
   EVIDENCE: MET exit=0 marker-found :: WIDTH-OK
19. [gated 2026-11-17] Tour fan-out: the main loop makes the call (STEP 0b list) only when a fix was applied, runners never do.
   CHECK: cd /home/bchanot/Documents/claude && f=skills/tour/SKILL.md; echo "[$(/usr/bin/grep -c 'when any row reports a fix, makes the' $f)/$(/usr/bin/grep -c 'STEP 3 end-of-run advisor call; then prints the global summary' $f)/$(/usr/bin/grep -c 'them; never call the advisor. Every rule' $f)/$(/usr/bin/grep -c '^Main loop only, never a runner: when the tour applied any fix' $f)]"
   EXPECT: [1/1/1/1]
   EVIDENCE: MET exit=0 marker-found :: [1/1/1/1]
20. [gated 2026-11-17] ship-feature and init-project route back to their plan level, release-candidate up to reflect, before the end call.
   CHECK: cd /home/bchanot/Documents/claude && echo "[$(/usr/bin/grep -cF 'route(phase="plan")` first (route: end-of-run review).' skills/ship-feature/SKILL.md)/$(/usr/bin/grep -cF 'route(phase="plan")` first (route: end-of-run review).' skills/init-project/SKILL.md)/$(/usr/bin/grep -cF 'route(phase="reflect")` first (route: end-of-run review).' skills/release-candidate/SKILL.md)]"
   EXPECT: [1/1/1]
   EVIDENCE: MET exit=0 marker-found :: [1/1/1]
21. [gated 2026-11-17] In ship-feature and init-project the stuck paragraph follows the "This …" paragraph it would otherwise split from the gates.
   CHECK: cd /home/bchanot/Documents/claude && for t in 'ship-feature|^This replaces the old informal' 'init-project|^This adds the security gate'; do IFS='|' read -r s a <<<"$t"; awk -v s="$s" -v a="$a" '$0~a{t=NR} /Stuck: a gate loop fails twice/{m=NR} END{printf "%s:%s ", s, (t && m>t)?"after-this":"BAD"}' "skills/$s/SKILL.md"; done; echo
   EXPECT: ship-feature:after-this init-project:after-this
   EVIDENCE: MET exit=0 marker-found :: ship-feature:after-this init-project:after-this

## FILE SCOPE
[gated 2026-11-17] (replaces the STEP 0e seed below) skills/feat/SKILL.md (gate
step, STEP 5 summary), skills/bugfix/SKILL.md (gate step, STEP 6 summary),
skills/{ship-feature,init-project}/SKILL.md (gate step, FINISH head),
skills/{a11y,guardrails}/SKILL.md (Gates item, Commit and hand over item 1),
skills/audit-delta/SKILL.md (STEP 4 head), skills/tour/SKILL.md (runner
prompt, STEP 0b list, before the global summary),
skills/release-candidate/SKILL.md (STEP 4 head), agents/verifier.md and
agents/security-auditor.md (advisor bullet), agents/plan-challenger.md
(advisor bullet, ORCHESTRATOR PROTOCOL), lib/effort-shift.md (§ Advisor item 3
and the blank line before block I); transient, purged by `gitflow finish`:
docs/superpowers/plans/2026-11-17-advisor-points-b2.md and
docs/superpowers/plans/2026-11-17-advisor-points-b2/apply.py; this contract.
`lib/capitalize-commit.md` is not touched. Seed criterion 2's "flows of
CLARIFICATIONS" = the end steps of feat, bugfix, ship-feature, init-project,
a11y, guardrails, audit-delta and tour.

Seed (STEP 0e, superseded): skills/{feat,bugfix,ship-feature,init-project,a11y,guardrails}/SKILL.md (gate step), lib/capitalize-commit.md, skills/release-candidate/SKILL.md (STEP 4), agents/security-auditor.md, agents/verifier.md, agents/plan-challenger.md (advisor bullet, ORCHESTRATOR PROTOCOL), lib/effort-shift.md (§ Advisor blank line). Final list settled at STEP 3.
