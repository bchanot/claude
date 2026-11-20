# CONTRACT — advisor-subagent-scope
- date: 2026-11-19 | flow: ship-feature | branch: feature/advisor-subagent-scope
- status: active

## REQUEST (verbatim — IMMUTABLE)
corrige la fuite advisor des sous-agents et fais les todos, et si il y en a d'autre ensuite fais les, tant que des todos apparaissent fais les sauf si tu vois que ca se repete

Scope of this run (main loop): the advisor sub-agent leak (TODO advisor-leak), escalated from /bugfix (>5 files). Diagnosis and probes: .claude/tasks/plans/2026-11-19-subagent-advisor-hook-1905.md.

## CLARIFICATIONS
Q: fix layers / A: "Both": SDD sonnet pin + never-call lines in opus-served agent prompts and opus briefs + a SubagentStart hook backstop [gated 2026-11-19]
Q: opus judgment reviewers / A: "Allow code reviews once": the opus code review (ship-feature STEP 6, init-project STEP 10, standalone SDD final review) may call the advisor at most once before its verdict; other judgment children never [gated 2026-11-19]
Q: merges in the TODO loop / A: gitflow finish per item once gates are clean [gated 2026-11-19]
Q: design / A: approved: carriers = CLAUDE.global.md § Skill routing (SDD pin) + § Workflow (allowed set, brief rule, hook) + lib/effort-shift.md § Advisor detail; six agent prompts (plugin-advisor, seo-analyzer, geo-analyzer, doc-syncer, commit-changer, handover-doc-writer); onboard's six opus briefs; client-handover-writer routing paragraph (not its top prompt: inline-loaded by the main loop); tour Phase B; ship-feature STEP 6 + init-project STEP 10 allowance; silent SubagentStart hook, timeout 5; vendored skills-external files NOT edited (update-all.sh overwrites them, BDR-106, BLK-024) [gated 2026-11-19]
Q: Advisor row of a skill run by a sub-agent / A: add `sub-agent` to the `not called (...)` reasons in lib/challenge-plan.md OUTPUT and the 9 caller template rows [gated 2026-11-19]
Q: plugin profile SET dev / A: no, keep full [gated 2026-11-19]

Q: 3-lens challenge fixes (hook line: agent definition or dispatcher's brief, the tool's own instructions never an allowance, ~/.claude path; all SDD workers sonnet incl. fix rounds, no opus carve-out; imperative code-review brief line; agent lines scoped "when you run as a sub-agent"; atomic applier; tripwire redefined for general-purpose) / A: main loop, internal; no gated choice reopened [2026-11-19]

Q: STEP 3 validation gate, plan docs/superpowers/plans/2026-11-19-advisor-subagent-scope.md (1 task, 33-check suite) / A: yes, execute [gated 2026-11-20]

Q: GATE 1 round 1 ECARTS(4): plan artifacts outside FILE SCOPE + SC2016 shellcheck disable (FLOOR) / A: main loop: the docs/superpowers plan + apply.py are transient run artifacts committed during the run and purged by gitflow finish (BDR-065), added to FILE SCOPE; the disable is removed (double quotes with escaped backticks, as loops-light), no suppression authorized [2026-11-20]

Q: STEP 6 opus review (With fixes: 2 Important) / A: main loop: fixed as plan section "Review fix round 1" (allowed agents' lines reworded "one call allowed" and locked T20; CLAUDE.global parenthetical clarified; hook prohibition locked T2c; plan-challenger mirror; effort-shift "other opus-served agents"; agent lines cite ~/.claude path; test lines ≤ 80); suite 38 checks; other minors to TODO [2026-11-20]

Q: add agents/{plan-challenger,verifier,security-auditor,analyzer}.md to FILE SCOPE (review fix: "one call allowed", locked T20) / A: yes [gated 2026-11-20]

## ACCEPTANCE CRITERIA
1. The new suite lib/tests/subagent-advisor.test.sh (hook output + wiring + carrier locks) is green.
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/subagent-advisor.test.sh 2>&1 | tail -1 | grep -qE '^subagent-advisor: [0-9]+ pass, 0 fail$' && echo SA-GREEN
   EXPECT: SA-GREEN
   EVIDENCE: MET exit=0 marker-found :: SA-GREEN
2. The hook emits one valid SubagentStart JSON object naming the advisor tool, whatever its stdin, and exits 0.
   CHECK: cd /home/bchanot/Documents/claude && for i in '{"agent_type":"general-purpose"}' '' 'not json'; do o=$(printf '%s' "$i" | bash hooks/subagent-advisor.sh); [ $? -eq 0 ] || exit 1; printf '%s' "$o" | jq -e '.hookSpecificOutput.hookEventName == "SubagentStart" and (.hookSpecificOutput.additionalContext | test("advisor"))' >/dev/null || exit 1; done && echo HOOK-OK
   EXPECT: HOOK-OK
   EVIDENCE: MET exit=0 marker-found :: HOOK-OK
3. settings.json wires SubagentStart to the hook with timeout 5.
   CHECK: cd /home/bchanot/Documents/claude && jq -e '.hooks.SubagentStart[0].hooks[0] | .command == "bash ~/.claude/hooks/subagent-advisor.sh" and .timeout == 5' settings.json >/dev/null && echo WIRED
   EXPECT: WIRED
   EVIDENCE: MET exit=0 marker-found :: WIRED
4. The 9 caller template rows and lib/challenge-plan.md carry the `sub-agent` reason; no row keeps the old closing.
   CHECK: cd /home/bchanot/Documents/claude && n=$(grep -l 'already called this run | sub-agent)' skills/init-project/SKILL.md skills/code-clean/SKILL.md skills/onboard/SKILL.md skills/audit-delta/SKILL.md skills/ship-feature/SKILL.md skills/harden/SKILL.md skills/pack-seo/skills/seo/SKILL.md skills/pack-seo/skills/geo/SKILL.md skills/pack-web-validate/skills/web-validate/SKILL.md lib/challenge-plan.md | wc -l); [ "$n" -eq 10 ] && ! git grep -q 'already called this run)' -- skills lib ':!lib/tests' && echo ROWS-10
   EXPECT: ROWS-10
   EVIDENCE: MET exit=0 marker-found :: ROWS-10
5. CLAUDE.global.md stays within its 320-line density budget.
   CHECK: cd /home/bchanot/Documents/claude && [ "$(wc -l < CLAUDE.global.md)" -le 320 ] && echo BUDGET-OK
   EXPECT: BUDGET-OK
   EVIDENCE: MET exit=0 marker-found :: BUDGET-OK
6. Full make test green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
7. Live delivery: a headless run with a scratch settings file wiring the real hooks/subagent-advisor.sh shows a sub-agent quoting the injected rule (manual, recorded by the main loop; this session may not reload settings). Behavioural proof is NOT claimed here: it is the next /memory-feedback advisor usage table plus a per-dispatch transcript check (dated TODO; tripwires: every typed non-allowed type → 0 calls, sonnet stays 0, general-purpose at most 1 call per dispatch and only in code-review dispatches, checked by hand until advisor.ts splits general-purpose by dispatch; revert = drop the settings entry).
8. No vendored skills-external file edited; no wording changed outside the plan's blocks; new prose lines ≤ 80 columns (manual).

## FILE SCOPE
hooks/subagent-advisor.sh (new), lib/tests/subagent-advisor.test.sh (new), settings.json, CLAUDE.global.md, lib/effort-shift.md, lib/challenge-plan.md, agents/{plugin-advisor,seo-analyzer,geo-analyzer,doc-syncer,commit-changer,handover-doc-writer,client-handover-writer}.md, skills/onboard/SKILL.md, skills/tour/SKILL.md, skills/ship-feature/SKILL.md, skills/init-project/SKILL.md, skills/{code-clean,audit-delta,harden}/SKILL.md, skills/pack-seo/skills/{seo,geo}/SKILL.md, skills/pack-web-validate/skills/web-validate/SKILL.md, docs/superpowers/plans/2026-11-19-advisor-subagent-scope.md + docs/superpowers/plans/2026-11-19-advisor-subagent-scope/apply.py (transient, BDR-065), agents/{plan-challenger,verifier,security-auditor,analyzer}.md (review fix round 1, gated)
