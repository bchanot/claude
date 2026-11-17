# Advisor call points, run B2 — Implementation Plan (r3 + STEP 6 review fix)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the remaining advisor call points of `lib/effort-shift.md` § Advisor into the skills that run them (stuck point, end-of-run point) and fix three advisor bullets in the judgment agents.

**Architecture:** Prose doctrine edits only. Every edit is a block below, applied by `docs/superpowers/plans/2026-11-17-advisor-points-b2/apply.py`, which reads the blocks from THIS file and asserts each anchor occurs exactly once (LRN-296). No other wording changes.

**Tech Stack:** Markdown doctrine, Python 3 applier, bash contract oracles (`lib/gates.sh`), `make test`.

**Spec:** design approved in chat 2026-11-17 (bounded path); contract `.claude/tasks/contracts/2026-11-17-advisor-points-b2-1634.md` (REQUEST verbatim + CLARIFICATIONS [gated]).

## Global Constraints

- Branch `feature/advisor-points-b2` off develop; commits `docs(doctrine): …`.
- 13 doctrine files: skills/{feat,bugfix,ship-feature,init-project,a11y,guardrails,audit-delta,tour,release-candidate}/SKILL.md, agents/{verifier,security-auditor,plan-challenger}.md, lib/effort-shift.md. `lib/capitalize-commit.md` untouched (user 2026-11-17).
- Every new line ≤ 80 columns; every marker and every `§ Label` citation on one line, followed by `)` or `;` (doctrine-citers census).
- Advice stays in the main loop, never in an executor, gate or challenger brief (BDR-066, LRN-083, LRN-208); advice is input, never the go (BDR-136, effort-shift "Advice is input, never consent").
- Stuck unit unchanged from B1: main-loop calls only, "since GATE 0 first ran" (`lib/verify-secure-loop.md` holds the rule; skills only point to it).
- The end-of-run call has its own budget: one per skill run, never skipped for an earlier plan or stuck call (item 3 says it once; the skill lines say "its end-of-run advisor call").
- SDD runs in place, in the main checkout on `feature/advisor-points-b2`: decline the using-git-worktrees offer (every command below is rooted at `/home/bchanot/Documents/claude`).
- Contract criteria integer-labelled (LRN-284); CHECKs one line, `/usr/bin/grep`, `/usr/bin/git` (LRN-171, LRN-176); full suite with `GATES_TIMEOUT=400`.

## Review Focus

- End call read as the run's whole advisor budget after a plan or stuck call → item 3 states its own budget; the skill lines name "its end-of-run advisor call".
- End call placed after the run was already declared done (feat FEAT COMPLETE at STEP 5, bugfix BUGFIX COMPLETE at STEP 6 item 4) → placed just before those summaries (criterion 13).
- Tour fan-out: runners (sub-agents) execute STEP 3, the main loop follows STEP 0b's list → STEP 3 line says "Main loop only, never a runner", STEP 0b item 2 names the call, the runner prompt says "never call the advisor" (criterion 19).
- security-auditor: an advisor raise mapped to a lower STEP 3 class must not lower a semgrep HIGH/CRITICAL, and a raise that does not apply is neither tagged nor counted (criterion 15).
- A census-invisible citation or a test-locked phrase moved → every new citation is `(`lib/effort-shift.md` § Advisor)` on one line; simulated with the full suite on a scratch clone before dispatch.

---

## Edit table (what apply.py does)

| # | File | Anchor (exact, once) | Action |
|---|------|----------------------|--------|
| E1 | skills/feat/SKILL.md | `Loop decisions stay HERE, in the main loop (LRN-083). Nominal (clear` | insert Block stuck + blank line before |
| E2 | skills/bugfix/SKILL.md | `   Loop decisions stay HERE, in the main loop (LRN-083). Nominal = one` | insert Block stuck (3-space indent) + blank line before |
| E3 | skills/ship-feature/SKILL.md | `other ([[LRN-095]]).\n\n## STEP 6 — CODE REVIEW` (end of STEP 5) | insert Block stuck + blank line before the heading |
| E4 | skills/init-project/SKILL.md | `([[LRN-095]]) — both run.\n\n## STEP 10 — CODE REVIEW` (end of STEP 9) | insert Block stuck + blank line before the heading |
| E5 | skills/a11y/SKILL.md, skills/guardrails/SKILL.md | `   the include's; loop decisions stay in this main loop.\n` (end of item 6 Gates) | append Block stuck (3-space indent) inside item 6 |
| E6 | skills/feat/SKILL.md | `\nPrint summary:\n```\nFEAT COMPLETE` (STEP 5, after the commit and the reflect route) | insert Block end-report + blank line before `Print summary:` |
| E7 | skills/bugfix/SKILL.md | `   two sentences of body).\n4. Print summary:` (STEP 6, after the commit) | append Block route-reflect + Block end-report (3-space indent) to item 3 |
| E8 | skills/ship-feature/SKILL.md (`## STEP 9 — FINISH\n`), skills/init-project/SKILL.md (`## STEP 11 — FINISH\n`) | heading line | insert Block end-finish + blank line after the heading |
| E9 | skills/a11y/SKILL.md, skills/guardrails/SKILL.md | `   commit, project convention else 50 words at most.\n2. \`mcp__model-router__route` | append Block end-handover (3-space indent) to item 1, before the apply route |
| E10 | skills/audit-delta/SKILL.md | `## STEP 4 — FINAL SUMMARY\n\n` | insert Block end-audit + blank line after |
| E11 | skills/tour/SKILL.md | `Global summary inline, one line per project (append` | insert Block end-tour + blank line before |
| E12 | skills/tour/SKILL.md | `2. Prints the global summary (STEP 3 format) once ALL runners returned.\n` (STEP 0b main-loop list) | replace with Block tour-dispatch |
| E13 | skills/tour/SKILL.md | runner prompt lines `    Skip STEP 0/0b (routing) and the global summary — the dispatcher owns\n    them. Every rule of the skill applies unchanged: max 3 iterations,\n` | replace with Block tour-runner |
| E14 | skills/release-candidate/SKILL.md | `### STEP 4 — HUMAN GATE: when to release\n` | insert Block end-release + blank line after the heading |
| E15 | agents/verifier.md | first 3 lines of the `- Advisor (when listed):` bullet | replace with Block verifier-head |
| E16 | agents/security-auditor.md | the whole `- Advisor (when listed):` bullet (12 lines) | replace with Block auditor |
| E17 | agents/plan-challenger.md | the whole `- Advisor (when listed):` bullet (5 lines) | replace with Block challenger |
| E18 | agents/plan-challenger.md | `- Dispatch THREE fresh challengers IN PARALLEL, one per lens\n` | insert Block protocol-first before |
| E19 | agents/plan-challenger.md | the 3-line `- ADVISORY:` bullet | replace with Block protocol-advisory |
| E20 | lib/effort-shift.md | `3. Before proposing a merge (\`gitflow finish\`) or calling a long task\n   done.\n` | replace with Block item3 (ends with a blank line before block I) |

Groups: `skills` = E1-E14 (17 edits), `agents` = E15-E20 (6 edits).
`review1` (STEP 6 code-review fix, from HEAD 24354d9): rewrites the end-report,
end-finish and end-handover blocks in the six gate flows (diff stat, fix back
through the gates), end-release ("makes hold the recommended answer"), and adds
Block route-reflect before the bugfix end call (7 edits).

## Contract additions at STEP 3 (`[gated 2026-11-17]`)

Inserted into the contract's ACCEPTANCE CRITERIA after criterion 9, before
`## FILE SCOPE`, each line tagged `[gated 2026-11-17]`; simulated on a scratch
clone before dispatch (LRN-296). Seed criteria 1-9 stay as written.

```
10. [gated 2026-11-17] Stuck paragraph in each gate skill, citing the lib and § Advisor.
   CHECK: cd /home/bchanot/Documents/claude && for s in feat bugfix ship-feature init-project a11y guardrails; do f=skills/$s/SKILL.md; printf '%s:%s/%s ' "$s" "$(/usr/bin/grep -c 'Stuck: a gate loop fails twice with no main-loop advisor call since GATE 0' "$f")" "$(/usr/bin/grep -cF '(`lib/effort-shift.md` § Advisor); the answer never enters an executor brief.' "$f")"; done; echo
   EXPECT: feat:1/1 bugfix:1/1 ship-feature:1/1 init-project:1/1 a11y:1/1 guardrails:1/1
   EVIDENCE: pending
11. [gated 2026-11-17] The stuck paragraph sits in the gate step (after a GATE 2 line, no heading between).
   CHECK: cd /home/bchanot/Documents/claude && for s in feat bugfix ship-feature init-project a11y guardrails; do awk -v s="$s" '/GATE 2/{g=NR} /^## /{h=NR} /Stuck: a gate loop fails twice/{m=NR; ok=(g>h)} END{printf "%s:%s ", s, (m&&ok)?"in-gate":"OUT"}' "skills/$s/SKILL.md"; done; echo
   EXPECT: feat:in-gate bugfix:in-gate ship-feature:in-gate init-project:in-gate a11y:in-gate guardrails:in-gate
   EVIDENCE: pending
12. [gated 2026-11-17] The end-of-run marker is in exactly the 9 flows (no hotfix, lib, agent or memory-only flow).
   CHECK: cd /home/bchanot/Documents/claude && echo "[$(/usr/bin/grep -rlF 'end-of-run advisor call (`lib/effort-shift.md` § Advisor)' skills lib agents | LC_ALL=C sort | tr '\n' ' ')]"
   EXPECT: [skills/a11y/SKILL.md skills/audit-delta/SKILL.md skills/bugfix/SKILL.md skills/feat/SKILL.md skills/guardrails/SKILL.md skills/init-project/SKILL.md skills/release-candidate/SKILL.md skills/ship-feature/SKILL.md skills/tour/SKILL.md ]
   EVIDENCE: pending
13. [gated 2026-11-17] Each end marker occurs once, before its flow's done or merge moment.
   CHECK: cd /home/bchanot/Documents/claude && for t in 'feat|^## STEP 5 |^FEAT COMPLETE' 'bugfix|^## STEP 6 |BUGFIX COMPLETE' 'ship-feature|^## STEP 9 |finish   # feature' 'init-project|^## STEP 11 |finish   # feature' 'a11y|^## STEP 10:|^2[.] .mcp__model-router' 'guardrails|^## STEP 12:|^2[.] .mcp__model-router' 'audit-delta|^## STEP 4 |AUDIT-DELTA COMPLETE' 'tour|^Checks: pytest PASS|^TOUR COMPLETE' 'release-candidate|^### STEP 4 |^AskUserQuestion:'; do IFS='|' read -r s a b <<<"$t"; awk -v s="$s" -v a="$a" -v b="$b" '!sa && $0~a {sa=NR} index($0,"end-of-run advisor call (`lib/effort-shift.md` § Advisor)"){n++; m=NR} sa && !sb && NR>sa && $0~b {sb=NR} END{printf "%s:%s ", s, (n==1 && sa<m && m<sb)?"ok":"BAD"}' "skills/$s/SKILL.md"; done; echo
   EXPECT: feat:ok bugfix:ok ship-feature:ok init-project:ok a11y:ok guardrails:ok audit-delta:ok tour:ok release-candidate:ok
   EVIDENCE: pending
14. [gated 2026-11-17] verifier, security-auditor and plan-challenger advise only when dispatched.
   CHECK: cd /home/bchanot/Documents/claude && for a in verifier security-auditor plan-challenger; do printf '%s:%s/%s ' "$a" "$(/usr/bin/grep -c '^- Advisor, when dispatched as a sub-agent: at most one call' "agents/$a.md")" "$(/usr/bin/grep -c 'Advisor (when listed)' "agents/$a.md")"; done; echo
   EXPECT: verifier:1/0 security-auditor:1/0 plan-challenger:1/0
   EVIDENCE: pending
15. [gated 2026-11-17] security-auditor: a raise applies only upward, a no-op raise is neither tagged nor counted, advice never removes, lowers or waives.
   CHECK: cd /home/bchanot/Documents/claude && echo "[$(/usr/bin/grep -c 'A raise applies only when its class.s severity' agents/security-auditor.md)/$(/usr/bin/grep -c 'changes nothing: no tag,' agents/security-auditor.md)/$(/usr/bin/grep -c '^  Advice never removes, lowers or waives a finding from semgrep' agents/security-auditor.md)/$(/usr/bin/grep -c 'overrides the STEP 2 mapping' agents/security-auditor.md)/$(/usr/bin/grep -c 'It never removes' agents/security-auditor.md)]"
   EXPECT: [1/1/1/0/0]
   EVIDENCE: pending
16. [gated 2026-11-17] plan-challenger ORCHESTRATOR PROTOCOL: ADVISOR FIRST (pointer to the lib, its guards) before the dispatch bullet, `Advisor:` row in ADVISORY.
   CHECK: cd /home/bchanot/Documents/claude && echo "[$(/usr/bin/grep -c '^- ADVISOR FIRST (main loop): per `lib/challenge-plan.md`' agents/plan-challenger.md)/$(/usr/bin/grep -c 'with no main-loop advisor call since the skill run started; absent or' agents/plan-challenger.md)/$(/usr/bin/grep -cF 'an `Advisor:` row) feed the' agents/plan-challenger.md)/$(awk '/^## ORCHESTRATOR PROTOCOL/{p=NR} /^- ADVISOR FIRST/{a=NR} /^- Dispatch THREE fresh challengers/{d=NR} END{print (p && p<a && a<d)}' agents/plan-challenger.md)]"
   EXPECT: [1/1/1/1]
   EVIDENCE: pending
17. [gated 2026-11-17] effort-shift § Advisor item 3 keeps its generic trigger, names its sites, its own budget, the audit-delta/tour skip and the gate-flow-only fix path; § Advisor still names no STEP.
   CHECK: cd /home/bchanot/Documents/claude && sec() { sed -n '/^## Advisor/,/^## Never/p' lib/effort-shift.md; }; echo "[$(sec | /usr/bin/grep -c 'done. Wired at the end step of feat, bugfix,')/$(sec | /usr/bin/grep -c 'release gate of release-candidate: one end-of-run call per skill')/$(sec | /usr/bin/grep -c 'never skipped for an earlier plan or stuck call')/$(sec | /usr/bin/grep -c 'and tour skip it when the run applied no fix')/$(sec | /usr/bin/grep -c 'the answer is reported only and a fix it calls for is a new run')/$(sec | /usr/bin/grep -c STEP)]"
   EXPECT: [1/1/1/1/1/0]
   EVIDENCE: pending
18. [gated 2026-11-17] Every added line in the 13 files is at most 80 columns.
   CHECK: cd /home/bchanot/Documents/claude && n=$(/usr/bin/git diff develop -U0 -- skills/feat/SKILL.md skills/bugfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md skills/a11y/SKILL.md skills/guardrails/SKILL.md skills/audit-delta/SKILL.md skills/tour/SKILL.md skills/release-candidate/SKILL.md agents/verifier.md agents/security-auditor.md agents/plan-challenger.md lib/effort-shift.md | /usr/bin/grep '^+[^+]' | cut -c2- | LC_ALL=C.UTF-8 awk 'length>80' | wc -l); [ "$n" -eq 0 ] && echo WIDTH-OK
   EXPECT: WIDTH-OK
   EVIDENCE: pending
19. [gated 2026-11-17] Tour fan-out: the main loop makes the call (STEP 0b list) only when a fix was applied, runners never do.
   CHECK: cd /home/bchanot/Documents/claude && f=skills/tour/SKILL.md; echo "[$(/usr/bin/grep -c 'when any row reports a fix, makes the' $f)/$(/usr/bin/grep -c 'STEP 3 end-of-run advisor call; then prints the global summary' $f)/$(/usr/bin/grep -c 'them; never call the advisor. Every rule' $f)/$(/usr/bin/grep -c '^Main loop only, never a runner: when the tour applied any fix' $f)]"
   EXPECT: [1/1/1/1]
   EVIDENCE: pending
20. [gated 2026-11-17] ship-feature and init-project route back to their plan level, release-candidate up to reflect, before the end call.
   CHECK: cd /home/bchanot/Documents/claude && echo "[$(/usr/bin/grep -cF 'route(phase="plan")` first (route: end-of-run review).' skills/ship-feature/SKILL.md)/$(/usr/bin/grep -cF 'route(phase="plan")` first (route: end-of-run review).' skills/init-project/SKILL.md)/$(/usr/bin/grep -cF 'route(phase="reflect")` first (route: end-of-run review).' skills/release-candidate/SKILL.md)]"
   EXPECT: [1/1/1]
   EVIDENCE: pending
21. [gated 2026-11-17] In ship-feature and init-project the stuck paragraph follows the "This …" paragraph it would otherwise split from the gates.
   CHECK: cd /home/bchanot/Documents/claude && for t in 'ship-feature|^This replaces the old informal' 'init-project|^This adds the security gate'; do IFS='|' read -r s a <<<"$t"; awk -v s="$s" -v a="$a" '$0~a{t=NR} /Stuck: a gate loop fails twice/{m=NR} END{printf "%s:%s ", s, (t && m>t)?"after-this":"BAD"}' "skills/$s/SKILL.md"; done; echo
   EXPECT: ship-feature:after-this init-project:after-this
   EVIDENCE: pending
```

FILE SCOPE replaced at STEP 3 (`[gated 2026-11-17]`): skills/feat/SKILL.md (gate
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

## Blocks (verbatim; apply.py reads them from here)

### Block stuck
```
Stuck: a gate loop fails twice with no main-loop advisor call since GATE 0
first ran → the main loop calls the advisor per `lib/verify-secure-loop.md`
(`lib/effort-shift.md` § Advisor); the answer never enters an executor brief.
```

### Block end-report
```
Before the summary, the main loop prints the run's diff stat, then makes its
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its answer
goes into the summary as an `Advisor:` line, and a fix it drives goes
back through the gates.
```

### Block route-reflect
```
`mcp__model-router__route(phase="reflect")` first (route: end-of-run review).
```

### Block end-finish
```
`mcp__model-router__route(phase="plan")` first (route: end-of-run review).
Before proposing the finish, the main loop prints the run's diff stat,
then makes its end-of-run advisor call (`lib/effort-shift.md` § Advisor);
its answer goes with the proposal as an `Advisor:` line, and a fix it
drives goes back through the gates.
```

### Block end-handover
```
Before the reply, the main loop prints the run's diff stat, then makes its
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its answer
goes into the reply as an `Advisor:` line, and a fix it drives goes
back through the gates.
```

### Block end-audit
```
When the run applied a fix, before the summary, the main loop makes its
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its answer
goes into the summary as an `Advisor:` line, and a fix it calls for
waits for a new run.
```

### Block end-tour
```
Main loop only, never a runner: when the tour applied any fix, before
the global summary, the main loop makes its
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its answer
goes into the summary as an `Advisor:` line, and a fix it calls for
waits for a new run.
```

### Block tour-dispatch
```
2. Once ALL runners returned: when any row reports a fix, makes the
   STEP 3 end-of-run advisor call; then prints the global summary (STEP 3
   format).
```

### Block tour-runner
```
    Skip STEP 0/0b (routing) and the global summary — the dispatcher owns
    them; never call the advisor. Every rule of the skill applies
    unchanged: max 3 iterations,
```

### Block end-release
```
`mcp__model-router__route(phase="reflect")` first (route: end-of-run review).
Before the ask, the main loop makes its
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its answer
goes with the ask as an `Advisor:` line, and a fix it calls for makes
hold the recommended answer.
```

### Block verifier-head
```
- Advisor, when dispatched as a sub-agent: at most one call, after STEP 4
  and before STEP 5, whatever the harness prompt schedules; absent or
  erroring → proceed. Advice may send you back to a criterion: a
```

### Block auditor
```
- Advisor, when dispatched as a sub-agent: at most one call, after
  STEP 4 and before STEP 5 and any REPORT write, whatever the harness
  prompt schedules; absent or erroring → proceed. Advice may add a
  finding or raise a severity, cited at a file:line you read. An added
  finding's rule/check is `advisor:<STEP 3 class>`; it takes that
  class's severity, for that finding only, and is REPORTED as LOW when
  it matches no class. A raise applies only when its class's severity
  is higher than the finding's own: it keeps the finding's line, its
  rule/check becoming `<rule>+advisor`, so it counts once. A raise
  that does not apply, or matches no class, changes nothing: no tag,
  no PROOF count. An added or applied finding enters STEP 5's dedup and
  BLOCK(n) like any other, and PROOF ends with
  `; advisor <n> added/raised`.
  Advice never removes, lowers or waives a finding from semgrep, the
  checklist or STEP 4.
```

### Block challenger
```
- Advisor, when dispatched as a sub-agent: at most one call, after
  drafting your findings and before the verdict, whatever the harness
  prompt schedules; absent or erroring → proceed. Advice may add or
  sharpen a finding. Advice alone never drops or lowers one: a change
  rests on your own re-read, cited at file:line.
```

### Block protocol-first
```
- ADVISOR FIRST (main loop): per `lib/challenge-plan.md` "Advisor first",
  with no main-loop advisor call since the skill run started; absent or
  erroring → dispatch as written. The advice never enters a challenger
  brief: they stay blind.
```

### Block protocol-advisory
```
- ADVISORY: the revised plan + a challenge summary (raised / addressed /
  deferred / any lens that failed to return / an `Advisor:` row) feed the
  orchestrator's existing human gate. The human decides — this is not a
  hard block.
```

### Block item3
```
3. Before proposing a merge (`gitflow finish`) or calling a long task
   done. Wired at the end step of feat, bugfix, ship-feature,
   init-project, a11y, guardrails, audit-delta and tour, and at the
   release gate of release-candidate: one end-of-run call per skill
   run, never skipped for an earlier plan or stuck call; audit-delta
   and tour skip it when the run applied no fix. In the six flows that
   run the gates, the main loop first prints the run's diff stat, a fix
   the answer drives goes back through the gates, and a later proposal
   reuses the answer and says it predates the newer commits. Elsewhere
   the answer is reported only and a fix it calls for is a new run.

```

---

### Orchestrator, at branch start (not a dispatched task)

After `gitflow.sh start feature advisor-points-b2`, commit this plan and its
applier on the branch so the executors and reviewers read them from disk
(transient artifacts, purged by `gitflow finish`):
`git add docs/superpowers/plans/2026-11-17-advisor-points-b2.md docs/superpowers/plans/2026-11-17-advisor-points-b2/apply.py && git commit -m "chore(plan): advisor points run B2 plan and applier"`

### Task 1: Skills — stuck trigger and end-of-run line (9 skill files)

**Files:**
- Modify: `skills/feat/SKILL.md` (STEP 4 before "Loop decisions"; STEP 5 before "Print summary:")
- Modify: `skills/bugfix/SKILL.md` (STEP 6 item 1 before "Loop decisions"; STEP 6 end of item 3)
- Modify: `skills/ship-feature/SKILL.md` (end of STEP 5; STEP 9 head)
- Modify: `skills/init-project/SKILL.md` (end of STEP 9; STEP 11 head)
- Modify: `skills/a11y/SKILL.md` (STEP 8 item 6; STEP 10 item 1 end)
- Modify: `skills/guardrails/SKILL.md` (STEP 10 item 6; STEP 12 item 1 end)
- Modify: `skills/audit-delta/SKILL.md` (STEP 4 head)
- Modify: `skills/tour/SKILL.md` (runner prompt; STEP 0b list item 2; before the global summary)
- Modify: `skills/release-candidate/SKILL.md` (STEP 4 head)

**Interfaces:**
- Consumes: `lib/verify-secure-loop.md` stuck lines (B1, unchanged); `lib/effort-shift.md` § Advisor items 2 and 3 (item 3 rewritten in Task 2).
- Produces: the stuck marker in 6 files, the end marker `end-of-run advisor call (\`lib/effort-shift.md\` § Advisor)` in exactly 9 files.

- [ ] **Step 1: Confirm the oracles fail before the edit**

Run the CHECK lines of contract criteria 10, 11, 12, 13, 19, 20 and 21 by hand
(copy each `CHECK:` line; do NOT run `lib/gates.sh`, the orchestrator owns the
floor and its EVIDENCE lines).
Expected: none prints its `EXPECT:` marker.

- [ ] **Step 2: Apply the skills group**

Run: `cd /home/bchanot/Documents/claude && python3 docs/superpowers/plans/2026-11-17-advisor-points-b2/apply.py docs/superpowers/plans/2026-11-17-advisor-points-b2.md . skills`
Expected: `applied 17 edits (skills)`; any anchor count ≠ 1 → it exits 1 and writes nothing.

- [ ] **Step 3: Run the skills oracles**

Run the same seven CHECK lines again.
Expected: each prints its `EXPECT:` marker.

- [ ] **Step 4: Run the locked-phrase suites**

Run: `cd /home/bchanot/Documents/claude && for s in loops-light loops-heavy effort-routing model-routing doctrine-citers; do make test suite=lib/tests/$s.test.sh </dev/null 2>&1 | tail -1; done`
Expected: `all suites green` five times.

- [ ] **Step 5: Commit**

```bash
cd /home/bchanot/Documents/claude
git add skills/feat/SKILL.md skills/bugfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md skills/a11y/SKILL.md skills/guardrails/SKILL.md skills/audit-delta/SKILL.md skills/tour/SKILL.md skills/release-candidate/SKILL.md
git commit -m "docs(doctrine): advisor stuck trigger in gate skills, end-of-run call in code flows"
```

### Task 2: Agents and effort-shift (4 files)

**Files:**
- Modify: `agents/verifier.md` (advisor bullet head)
- Modify: `agents/security-auditor.md` (advisor bullet)
- Modify: `agents/plan-challenger.md` (advisor bullet; ORCHESTRATOR PROTOCOL)
- Modify: `lib/effort-shift.md` (§ Advisor item 3 + blank line before block I)

**Interfaces:**
- Consumes: `agents/analyzer.md` "Advisor, when dispatched as a sub-agent" wording (precedent); `lib/challenge-plan.md` "Advisor first" guards and the `Advisor:` row (mirror source).
- Produces: criteria 6, 14, 15, 16, 17 markers.

- [ ] **Step 1: Apply the agents group**

Run: `cd /home/bchanot/Documents/claude && python3 docs/superpowers/plans/2026-11-17-advisor-points-b2/apply.py docs/superpowers/plans/2026-11-17-advisor-points-b2.md . agents`
Expected: `applied 6 edits (agents)`.

- [ ] **Step 2: Run the agents and lib oracles and the fast suites**

Run the CHECK lines of contract criteria 6, 14, 15, 16, 17 and 18 by hand, then:
`cd /home/bchanot/Documents/claude && for s in plan-challenger security-auditor contract-verifier gates doctrine-citers; do make test suite=lib/tests/$s.test.sh </dev/null 2>&1 | tail -1; done`
Expected: each CHECK prints its `EXPECT:` marker; `all suites green` five times.
Do NOT run `lib/gates.sh` or the full `make test`: the orchestrator runs the
whole floor (GATE 0, `GATES_TIMEOUT=400`) after this task.

- [ ] **Step 3: Commit**

```bash
cd /home/bchanot/Documents/claude
git add agents/verifier.md agents/security-auditor.md agents/plan-challenger.md lib/effort-shift.md
git commit -m "docs(doctrine): judgment agents advise only when dispatched; auditor raises only upward; protocol mirror; end-of-run point sites"
```

### Orchestrator, after the gates (STEP 7 and STEP 8, not dispatched)

- STEP 7 CAPITALIZE: `memory_pending` first; BDR-150 status line (B2: stuck and
  end-of-run points in the skills, three agents dispatch-scoped); BUGS-FOUND
  advisor entries updated: :109 FIXED (raise only upward), :110 FIXED for the
  bullets with the inline-load tail kept, :111 FIXED for the mirror with the
  template-row tail kept; TODO Run B2 line checked, the reflect-route item as
  its own line.
- STEP 8 DOC SYNC: doc-syncer audit scope includes CHANGELOG.md (the
  [Unreleased] "Advisor doctrine" bullet, the stale auditor "that class's
  severity" wording at :23), README.md and USAGE.md advisor lines.

## Disposition

- amends BDR-150 (6ef3069, 58a5273): stuck point and end-of-run point reach the skills; three agents scoped to dispatch.
- honors BDR-034 / LRN-029: `lib/capitalize-commit.md` keeps its single concern (memory commit).
- honors BDR-066 / LRN-083 / LRN-208: no advice in any brief; tour runners never call.
- honors BDR-084: tour's main loop owns the end call in fan-out mode.
- honors BDR-136: advice is never the go; the finish ask stays.
- applies LRN-295: one end call per skill run, skipped by audit-delta and tour when nothing was fixed; the stuck call counts main-loop calls only (B1 unit).
- applies LRN-296 / LRN-284 / LRN-171 / LRN-176: blocks in one file, exact-once applier, simulation on a scratch clone, integer labels, one-line CHECKs.
- Residual (BUGS-FOUND :110 tail): `lib/verify-secure-loop.md` still offers "or load agents/<x>.md" inline; unused today, kept logged.
- Residual (BUGS-FOUND :111 tail): the 12 skills' own CHALLENGE SUMMARY templates still lack the `Advisor:` row (the lib says to append it anyway); kept logged.
- Out of B2 (user 2026-11-17): the 12 skills' reflect route with the challenger dispatch → own TODO line.
