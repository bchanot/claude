# CONTRACT — advisor-mandatory-gp-routing
- date: 2026-11-26 | flow: ship-feature | branch: feature/advisor-mandatory-gp-routing
- status: active
- run-base: bb964c92af7aae9f166f2221f07dad7dd445a1d3

## REQUEST (verbatim — IMMUTABLE)
User message 1:
analyse ces resultats et inclu l'appel a l'advisor. sinon il faudrait corriger les deviance A B C et pour D
(pasted: two rows of table 5 of the usage report, group D "doctrine muette : rédaction de plan déléguée", general-purpose, attendu "non défini", servi opus 11 runs 62,13 M 5,44 %, servi sonnet 1 run 3,55 M 0,31 %)
c'est la redaction de plan ou la reflexion d'un plan ?  Pour la reflexion il faut que ca soit fable, pour la redaction sonnet c'est bien pas opus. et il faudrait qu'on pousse l'advisor au maximum du maximum pour que ca advise le plus possible de choses

User message 2 (answers to the four decisions the assistant listed):
1. a , 2. a 3. sonnet, 4. ok

The four decisions as listed to the user (assistant text, context for message 2):
1. Réflexion de plan sur Fable, contredit BDR-150. (a) Advisor seulement : la boucle sur opus décide et synthétise, avec un appel advisor obligatoire sur le plan et sur chaque synthèse. BDR-150 reste intact. (b) boucle routée sur Fable. (c) sous-agent épinglé Fable.
2. Advisor « au maximum ». (a) Obligatoire là où il est permis (« exactement un appel » au lieu de « au plus un »), hotfix inclus, session game corrigée, plus une ligne dans chaque rapport disant ce que l'avis a changé. (b) plus les agents de jugement et de rédaction de plan hors liste. (c) maximum littéral, exécutants compris.
3. Revue finale SDD sous ship-feature : sonnet (ship-feature) ou modèle le plus capable (skill SDD). Recommandé : sonnet, la revue opus de STEP 6 suit.
4. Règle pour general-purpose hors SDD : correctifs, maquettes HTML, rédaction et collecte sur sonnet, jugement sur opus, sondes sur haiku, `model` toujours explicite.

Skill arguments (/ship-feature, written by the assistant from the above):
Doctrine: routage des sous-agents non typés et advisor obligatoire. Décisions utilisateur du 2026-11-26 (déjà prises, ne pas re-demander) :
1. Réflexion de plan = advisor seulement (BDR-150 intact) : la boucle principale sur opus décide et synthétise ; appel advisor OBLIGATOIRE sur le plan écrit et sur chaque synthèse de challenge ; la synthèse de challenge ne se délègue jamais à un sous-agent ; rédaction ou prototypage de plan délégués = general-purpose model sonnet avec brief aux décisions closes.
2. Advisor obligatoire là où il est permis : « exactement un appel » au lieu de « au plus un » pour plan-challenger, verifier, security-auditor, analyzer dispatché, revue de code opus ; points boucle principale obligatoires, hotfix inclus ; chaque rapport d'appelant porte une ligne disant ce que l'avis a changé (ou « no change ») ; note sur les sessions ouvertes avant le réglage advisorModel (retaper /advisor ou relancer). Advisor absent ou en erreur → proceed, inchangé. Exécutants : toujours jamais.
3. Sous ship-feature, la revue finale de branche du SDD part sur sonnet (STEP 6 opus suit) : lever la tension avec le skill SDD par une phrase explicite.
4. Règle nouvelle pour general-purpose hors SDD : model toujours explicite ; correctifs, maquettes HTML, rédaction, collecte → sonnet ; jugement (revue, vérification, diagnostic) → opus ; sondes → haiku.
Surface attendue : lib/effort-shift.md, CLAUDE.global.md, lib/challenge-plan.md, agents (plan-challenger, verifier, security-auditor, analyzer), hooks/subagent-advisor.sh, note du model-router, skills ship-feature/hotfix/feat/bugfix/writing-plans, tests citers. Ne pas toucher au settings.json déjà modifié dans l'arbre.

## CLARIFICATIONS
Q: plugin gate proposed profile dev for this project / A: no, keep the current profile [gated 2026-11-26]
Q: do the three user-decided skips survive "mandatory" (feat/bugfix end-of-run when gates are clean on first pass; placed decision, challenge-plan § SKIP; audit-delta/tour with no fix applied) / A: keep all three [gated 2026-11-26]
Q: main-loop advisor calls per challenge phase / A: two: on the written plan before the challengers, and on the revised plan after the first synthesis (r1); none after the confirmation pass [gated 2026-11-26]
Q: tour multi-project runner (general-purpose with NO model, BDR-084) under "model always explicit" / A: kept as the one named exception [gated 2026-11-26]
Q: same "SDD final whole-branch review on sonnet" sentence in init-project / A: yes, same rule [gated 2026-11-26]
Q: design presented in chat (two-call challenge only when a lens returned BLOCKER or MAJOR; a missing `ADVISOR:` line never invalidates a report; no router guard; net-zero CLAUDE.global.md) / A: approved, then the written spec approved [gated 2026-11-26]
Q: room for the general-purpose rule in CLAUDE.global.md (320/320 lines) / A: drop three asides of the advisor bullet that lib/effort-shift.md already carries ("settings advisorModel, Fable, set by /advisor", "a SubagentStart hook restates it", "the router tops out at opus") [gated 2026-11-26]
Spec: docs/superpowers/specs/2026-11-26-advisor-mandatory-gp-routing-design.md. Plan: docs/superpowers/plans/2026-11-26-advisor-mandatory-gp-routing.md (three tasks: the spec's fourth is folded into the third).
Q: deferred MAJOR of the confirmation pass (the nine callers' `Advisor:` row templates have one slot for two calls) / A: reopen with one sentence in lib/challenge-plan.md (the row is printed in two parts whatever the template shows); the nine templates are not edited [gated 2026-11-26]
Q: validation gate (three tasks, plan r3 after the challenge, the two CLAUDE.global.md lines, the audit-delta opus fallback, the amendments below) / A: approved [gated 2026-11-26]
Amendments [gated 2026-11-26]: criteria 1, 2 and 9 reworded; criteria 16-20 added from the approved design and plan; FILE SCOPE widened.
Orchestrator note 2026-11-27 (dry run): criterion 13's oracle now puts bun on PATH; on the run base the only red suite was lib/tests/memory-feedback.test.sh ("bun not on PATH"), green once bun is found. Baseline with bun: all suites green.
Orchestrator notes 2026-11-26 (interpretations, shown at the validation gate):
- "Synthesis never delegated" binds the loop that dispatched the challengers: it revises the plan itself and never hands the revision to another agent. A skill run by a sub-agent (client-handover children) is its own loop and keeps its row `not called (sub-agent)`.
- Skill-runner dispatches keep `model: "opus"` (lib/model-gate.md, unchanged); decision 4 adds the nature mapping for the other general-purpose dispatches.
- The built-in `Plan` row and the vendored superpowers text (BDR-106) are not edited: rules reach SDD, writing-plans and requesting-code-review through our caller text, lib and CLAUDE.global.md.
- Measured basis: usage report of 2026-11-26 (scratchpad, sections 5, 9, 10), not a tracked file.

## ACCEPTANCE CRITERIA
1. Plan call and r1 synthesis call: `lib/challenge-plan.md` and
   `lib/effort-shift.md` § Advisor state two main-loop advisor calls per
   challenge phase: on the written plan before the challengers (with no
   main-loop advisor call yet in the run), and on the plan after the first
   synthesis when a lens returned a BLOCKER or a MAJOR, whatever earlier
   call the run made; none after the confirmation pass. The
   placed-decision SKIP still waives the phase's calls.
   [amended, gated 2026-11-26]
2. The loop that dispatched the challengers makes the synthesis decisions
   itself (accept, drop, defer, the named change that closes a finding):
   `lib/challenge-plan.md` and the protocol mirror in
   `agents/plan-challenger.md` say they are never handed to another agent.
   Applying changes already decided to a long plan file may be dispatched
   as drafting (general-purpose, `model: "sonnet"`), the loop re-reading
   each change. Delegated plan drafting or prototyping is a
   general-purpose dispatch with `model: "sonnet"` and a brief whose
   decisions are closed. [amended, gated 2026-11-26]
3. plan-challenger, verifier, security-auditor, a dispatched analyzer and
   the opus code review make exactly one advisor call per dispatch when the
   tool is listed: the rule rides each agent definition, the review briefs
   of ship-feature and init-project, `lib/effort-shift.md`,
   `CLAUDE.global.md` and the SubagentStart hook line. No "at most once" or
   "one call allowed" wording is left for these callers, split-line forms
   included. Advisor absent or erroring: proceed, as today. Executors and
   every other sub-agent still never call.
4. Each of those five callers' reports carries one line saying what the
   advice changed, or that it changed nothing, or that no call was served
   (absent or error). The existing verdict grammar lines stay parseable
   (their tests pass).
5. Main loop: the `ADVISOR` field of feat and bugfix and the `Advisor:`
   lines of the other flows say what the advice changed, or no change, or
   the skip, or not called. hotfix makes one advisor call on every run and
   prints an ADVISOR field in HOTFIX APPLIED.
6. The three skips of the CLARIFICATIONS remain, worded as today.
7. `lib/effort-shift.md` § Advisor carries the note on sessions opened
   before the `advisorModel` setting (retype `/advisor` or relaunch).
8. ship-feature and init-project each say in one explicit sentence that the
   SDD final whole-branch review runs on sonnet, that this outranks the SDD
   skill's "most capable model" sentence, and that the opus code review
   step follows.
9. General-purpose outside SDD: `CLAUDE.global.md` states that the model is
   always explicit (the tour runner excepted), judgment on opus, fixes,
   mockups, writing and collection on sonnet, probes on haiku;
   `lib/model-gate.md` carries the full list, with skill-runners on opus,
   plan drafting on sonnet and the tour runner named as the one exception.
   [amended, gated 2026-11-26]
10. `CLAUDE.global.md` stays within the density guard.
    CHECK: cd /home/bchanot/Documents/claude && n=$(wc -l < CLAUDE.global.md) && [ "$n" -le 320 ] && echo "global-within-320"
    EXPECT: global-within-320
    EVIDENCE: MET exit=0 marker-found :: global-within-320
11. The model-router advisor note and its test constant agree with
    `lib/effort-shift.md` § Advisor; no Fable pin appears anywhere
    (BDR-150).
12. The pending behavioural check in `.claude/tasks/TODO.md` (advisor leak,
    2026-11-27) has its tripwires rewritten for the new rule.
13. Full suite green.
    CHECK: cd /home/bchanot/Documents/claude && PATH="$HOME/.bun/bin:$PATH" make test 2>&1 | tail -1
    EXPECT: all suites green
    EVIDENCE: MET exit=0 marker-found :: all suites green
14. shellcheck clean on the hook and its suite.
    CHECK: cd /home/bchanot/Documents/claude && shellcheck hooks/subagent-advisor.sh lib/tests/subagent-advisor.test.sh && echo hook-clean
    EXPECT: hook-clean
    EVIDENCE: MET exit=0 marker-found :: hook-clean
15. The branch does not touch `settings.json`.
    CHECK: cd /home/bchanot/Documents/claude && printf 'settings.json\n' | grep -qx 'settings.json' && l=$(git diff --name-only develop...HEAD) && ! printf '%s\n' "$l" | grep -qx 'settings.json' && echo settings-untouched
    EXPECT: settings-untouched
    EVIDENCE: MET exit=0 marker-found :: settings-untouched

16. The new locks exist in the suites, so their green is not vacuous.
    [gated 2026-11-26]
    CHECK: cd /home/bchanot/Documents/claude && n=$(grep -cE 'check "?T(2[1-9]|3[0-3])' lib/tests/subagent-advisor.test.sh) && [ "$n" -ge 20 ] && grep -q "bar /tour's runner" lib/tests/model-routing.test.sh && echo locks-present
    EXPECT: locks-present
    EVIDENCE: MET exit=0 marker-found :: locks-present
17. `skills/audit-delta/SKILL.md`: the fallback general-purpose dispatch
    carries `model: "opus"`, an effort and a brief that forbids the
    advisor. [gated 2026-11-26]
    CHECK: cd /home/bchanot/Documents/claude && grep -qF 'else general-purpose with `model: "opus"` and `effort="xhigh"`, its brief saying never call the `advisor` tool' skills/audit-delta/SKILL.md && echo audit-delta-pinned
    EXPECT: audit-delta-pinned
    EVIDENCE: MET exit=0 marker-found :: audit-delta-pinned
18. The CHALLENGE SUMMARY `Advisor:` row is printed in two parts (plan,
    synthesis) whatever the caller's template shows; the nine caller
    templates are unchanged. [gated 2026-11-26]
19. The `ADVISOR:` line is marked "(dispatched only)" in both analyzer
    OUTPUT blocks; the security auditor leaves it out of `REPORT` and
    still ends with `REPORT_WRITTEN:`; an `ERROR` verdict of
    plan-challenger, verifier or security-auditor carries none; a report
    without the line is not a structural failure. [gated 2026-11-26]
20. No old wording is left in the carriers. [gated 2026-11-26]
    CHECK: cd /home/bchanot/Documents/claude && printf 'one call allowed\n' | grep -q -e 'one call allowed' && ! git grep -q -e 'one call allowed' -e 'tool once, before' -e 'allowing one' -e 'may call once' -e 'its answer goes' -e 'one-line answer' -e 'at least at the points' -e 'skips this call' -- agents skills lib hooks mods CLAUDE.global.md ':!lib/tests' && echo old-wording-gone
    EXPECT: old-wording-gone
    EVIDENCE: MET exit=0 marker-found :: old-wording-gone

## FILE SCOPE
lib/effort-shift.md, lib/challenge-plan.md, lib/model-gate.md,
lib/verify-secure-loop.md, CLAUDE.global.md,
agents/{plan-challenger,verifier,security-auditor,analyzer}.md,
hooks/subagent-advisor.sh,
mods/model-router/hooks/register.ts and register.test.ts (advisor note only),
skills/{ship-feature,init-project,feat,bugfix,hotfix}/SKILL.md,
skills/{a11y,guardrails,audit-delta,tour,release-candidate}/SKILL.md
[gated 2026-11-26],
docs/superpowers/specs/ and docs/superpowers/plans/ (run artifacts)
[gated 2026-11-26],
lib/tests/*.test.sh (locks on the changed wording),
.claude/tasks/TODO.md, public docs through the doc-sync step
(README.md, USAGE.md, ARCHITECTURE.md, CHANGELOG.md).
Out: settings.json, skills-external/ (vendored), mods/model-router/routing.json.
