# CONTRACT — advisor-points-b3
- date: 2026-11-18 | flow: ship-feature | branch: feature/advisor-points-b3
- status: active

## REQUEST (verbatim — IMMUTABLE)
corrige les deux bugs mis dans le todos puis passe a C

Answers 2026-11-18 that scope this run: "Did 'les deux bugs' also mean TODO:10-11?" → "Yes, do 10-11 first". Route line wording → "First challenge call (Recommended)": "(route: own level before the challenge; send it with the first tool call of lib/challenge-plan.md, the advisor call when one is due)". BUGS-FOUND :114 Advisor row → "Yes, same run (Recommended)". Flow → "/ship-feature (Recommended)". TODO:11 → "Skip when gates clean": feat/bugfix skip the end-of-run call when GATE 0, verifier and security passed first try and no stuck call ran; doctrine edit in effort-shift item 3 + 2 skills.

Skill args (/ship-feature): Advisor run B3 (TODO:10-11 + BUGS-FOUND :114 residual; user 2026-11-18). (1) The challenge route line in 12 skills (feat, bugfix, hotfix, ship-feature, init-project, audit-delta, code-clean, onboard, harden, pack-seo seo + geo, pack-web-validate web-validate) reads "(route: own level before the challenge; send it with the challenger dispatch)"; lib/challenge-plan.md now puts the main-loop advisor call (and a plan read) before the dispatch. User wording: "(route: own level before the challenge; send it with the first tool call of lib/challenge-plan.md, the advisor call when one is due)". (2) Same 12 skills: each CHALLENGE SUMMARY template gains the `Advisor:` row lib/challenge-plan.md OUTPUT requires; BUGS-FOUND :114 residual → FIXED. (3) TODO:11 user decision "skip when gates clean": /feat and /bugfix skip the end-of-run advisor call when GATE 0, the verifier and security all passed on their first run and no stuck call ran; doctrine in lib/effort-shift.md § Advisor item 3 + skills/feat + skills/bugfix end lines; TODO:11 closed, BDR-150 status line. Method as B2: blocks in files + exact-once applier, simulated on a mktemp scratch copy with every contract CHECK before dispatch (LRN-296); markers and `§ Label` citations on one line followed by `)` or `;`; criteria plain `N.` labels (gates.sh now rejects others); full make test at the gates.sh default timeout; gates in order GATE 0 → verifier → security after CONFORME; at capitalize memory_pending first; docs CHANGELOG [Unreleased] Advisor doctrine bullet, README/USAGE only if they cite the changed lines.

## CLARIFICATIONS
Q: route line wording / A: user wording above [gated 2026-11-18]
Q: fold BUGS-FOUND :114 Advisor row into the run / A: yes [gated 2026-11-18]
Q: flow / A: /ship-feature [gated 2026-11-18]
Q: TODO:11 decision / A: skip when gates clean, feat and bugfix only [gated 2026-11-18]
Q: route wording vs a PLAN Read first / A: keep verbatim [gated 2026-11-18]
Q: Advisor row format / A: row with its three values inline; one-line summaries gain "/ advisor" [gated 2026-11-18]
Q: "gates clean" / A: strict: GATE 0 MET, verifier CONFORME, security PASS (not DEGRADED), each first attempt; anything else runs the call [gated 2026-11-18]
Q: add-ons / A: ADVISOR field in FEAT/BUGFIX COMPLETE; item 3 "end step" wording (BUGS-FOUND :118 wording part) [gated 2026-11-18]
Q: STEP 3 dispositions (plan "Dispositions shown at the STEP 3 gate": verdict out of view runs the call; all-manual GATE 0 MET counts; NEED-DECISION / deferred BLOCKER / REPORTED findings count as clean; a skip discharges its point and trigger; bugfix end route kept; reuse clause names later code commits) / A: approved as listed [gated 2026-11-18]

## ACCEPTANCE CRITERIA
1. No skill keeps the old route annotation "send it with the challenger dispatch". [gated 2026-11-18]
   CHECK: cd /home/bchanot/Documents/claude && n=$(git grep -c 'send it with the challenger dispatch' -- skills | wc -l); [ "$n" -eq 0 ] && echo OLD-ROUTE-GONE
   EXPECT: OLD-ROUTE-GONE
   EVIDENCE: MET exit=0 marker-found :: OLD-ROUTE-GONE
2. Each of the 12 challenge callers carries the new route annotation exactly once, on its `mcp__model-router__route(phase=…)` line. [gated 2026-11-18]
   CHECK: cd /home/bchanot/Documents/claude && n=0; for f in skills/feat/SKILL.md skills/bugfix/SKILL.md skills/hotfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md skills/audit-delta/SKILL.md skills/code-clean/SKILL.md skills/onboard/SKILL.md skills/harden/SKILL.md skills/pack-seo/skills/seo/SKILL.md skills/pack-seo/skills/geo/SKILL.md skills/pack-web-validate/skills/web-validate/SKILL.md; do c=$(grep -F 'mcp__model-router__route(phase=' "$f" | grep -cF '(route: own level before the challenge; send it with the first tool call of lib/challenge-plan.md, the advisor call when one is due).'); [ "$c" -eq 1 ] && n=$((n+1)); done; [ "$n" -eq 12 ] && echo ROUTE-12
   EXPECT: ROUTE-12
   EVIDENCE: MET exit=0 marker-found :: ROUTE-12
3. In the 9 block-form CHALLENGE SUMMARY templates, the line right after `Lenses returned` is the `Advisor:` row, its noun equal to the noun of the block's own `BLOCKERs addressed` row. [gated 2026-11-18]
   CHECK: cd /home/bchanot/Documents/claude && n=0; for f in skills/ship-feature/SKILL.md skills/init-project/SKILL.md skills/audit-delta/SKILL.md skills/code-clean/SKILL.md skills/onboard/SKILL.md skills/harden/SKILL.md skills/pack-seo/skills/seo/SKILL.md skills/pack-seo/skills/geo/SKILL.md skills/pack-web-validate/skills/web-validate/SKILL.md; do awk 'BEGIN{ok=0} /BLOCKERs addressed : <n>/{if (match($0,/named [a-z-]+ change/)) x=substr($0,RSTART+6,RLENGTH-13)} p{if (x!="" && index($0,"Advisor            : <the " x " change it drove | called, no change | not called (absent | error | already called this run)>")) ok=1; p=0} /Lenses returned    : correctness/{p=1} END{exit !ok}' "$f" && n=$((n+1)); done; [ "$n" -eq 9 ] && echo ROWS-9
   EXPECT: ROWS-9
   EVIDENCE: MET exit=0 marker-found :: ROWS-9
4. feat, bugfix and hotfix name the advisor in their one-line CHALLENGE SUMMARY. [gated 2026-11-18]
   CHECK: cd /home/bchanot/Documents/claude && n=0; for f in feat bugfix hotfix; do grep -qF 'lenses returned / advisor)' skills/$f/SKILL.md && grep -qF 'CHALLENGE SUMMARY' skills/$f/SKILL.md && n=$((n+1)); done; [ "$n" -eq 3 ] && echo SENTENCES-3
   EXPECT: SENTENCES-3
   EVIDENCE: MET exit=0 marker-found :: SENTENCES-3
5. lib/effort-shift.md § Advisor item 3 keeps "never skipped for an earlier plan or stuck call" and names its two skips (audit-delta/tour with no fix; feat/bugfix on the strict rule, "(not DEGRADED)" and the verdict-out-of-view clause included); a skipped call discharges its point; feat/bugfix sit at their commit step; for the six gate flows a later merge proposal reuses the last run's answer or skip and names any later code commit (doc and memory commits excepted); "end step of feat" and "predates the newer commits" are gone. [gated 2026-11-18]
   CHECK: cd /home/bchanot/Documents/claude && t=$(awk '/^3\. Before proposing a merge/{p=1} p&&/^$/{exit} p' lib/effort-shift.md | tr '\n' ' ' | tr -s ' '); for s in 'Wired at the commit step of feat and bugfix, at the end step of ship-feature' 'never skipped for an earlier plan or stuck call. Two skips only:' 'feat and bugfix when GATE 0 said MET, the verifier CONFORME and security PASS (not DEGRADED), each on its first attempt (any other verdict, a retry, a loop iteration or a verdict no longer in view runs the call)' '`skipped (gates clean on first pass)`' 'A skipped call discharges its point and the trigger it covers.' 'a later merge proposal reuses the last run' 'and names any code commit made after it (doc and memory commits excepted).'; do printf '%s' "$t" | grep -qF -- "$s" || exit 1; done; printf '%s' "$t" | grep -qF 'end step of feat' && exit 1; printf '%s' "$t" | grep -qF 'predates the newer commits' && exit 1; echo ITEM3-OK
   EXPECT: ITEM3-OK
   EVIDENCE: MET exit=0 marker-found :: ITEM3-OK
6. skills/feat and skills/bugfix restate the skip condition ("(not DEGRADED)" and the verdict-out-of-view clause included) at their end-of-run line, before the COMPLETE summary, and the summary template carries the `ADVISOR` field with its three values; the old "as an `Advisor:` line" wording is gone. [gated 2026-11-18]
   CHECK: cd /home/bchanot/Documents/claude && for f in skills/feat/SKILL.md skills/bugfix/SKILL.md; do t=$(tr '\n' ' ' < "$f" | tr -s ' '); for s in 'end-of-run advisor call (`lib/effort-shift.md` § Advisor), skipped when GATE 0 said MET, the verifier CONFORME and security PASS (not DEGRADED), each on its first attempt; any other verdict, a retry, a loop iteration or a verdict no longer in view runs the call.' '`ADVISOR` field, and a fix it drives goes back through the gates.' ': <one-line answer | skipped (gates clean on first pass) | not called (absent | error)>'; do printf '%s' "$t" | grep -qF -- "$s" || exit 1; done; printf '%s' "$t" | grep -qF 'goes into the summary as an `Advisor:` line' && exit 1; a=$(grep -n '§ Advisor), skipped when' "$f" | cut -d: -f1); c=$(grep -nE '^ *(FEAT|BUGFIX) COMPLETE$' "$f" | tail -1 | cut -d: -f1); d=$(grep -n 'ADVISOR .*: <one-line answer' "$f" | cut -d: -f1); [ -n "$a" ] && [ -n "$c" ] && [ -n "$d" ] && [ "$a" -lt "$c" ] && [ "$c" -lt "$d" ] || exit 1; done; echo FEAT-BUGFIX-SKIP
   EXPECT: FEAT-BUGFIX-SKIP
   EVIDENCE: MET exit=0 marker-found :: FEAT-BUGFIX-SKIP
7. CHANGELOG [Unreleased] "Advisor doctrine" bullet names the new callers, the summary row and route, the feat/bugfix skip (not DEGRADED), their commit step, the `ADVISOR` field and the reuse clause that names later code commits; "It sits at the end step of feat, bugfix" and "the answer goes into the reply, summary or finish proposal" are gone. [gated 2026-11-18]
   CHECK: cd /home/bchanot/Documents/claude && u=$(awk '/^## \[Unreleased\]/{p=1;next} /^## \[/{p=0} p' CHANGELOG.md); for s in 'skills/{feat,bugfix,hotfix,ship-feature,init-project,onboard,code-clean,harden,a11y,guardrails,audit-delta,tour,release-candidate}/SKILL.md' 'the CHALLENGE SUMMARY of every caller gains an `Advisor:` row' 'with the first tool call of `lib/challenge-plan.md`' 'feat and bugfix skip it when GATE 0 said MET, the verifier CONFORME and security PASS (not DEGRADED), each on its first attempt' 'It sits at the commit step of feat and bugfix and at the end step of ship-feature' 'and a later merge proposal reuses the last run' 'names any code commit made after it (doc and memory commits excepted).' 'or into the feat/bugfix summary'; do printf '%s' "$u" | grep -qF -- "$s" || exit 1; done; printf '%s' "$u" | grep -qF 'It sits at the end step of feat, bugfix' && exit 1; printf '%s' "$u" | grep -qF 'the answer goes into the reply, summary or finish proposal' && exit 1; echo CHANGELOG-OK
   EXPECT: CHANGELOG-OK
   EVIDENCE: MET exit=0 marker-found :: CHANGELOG-OK
8. Full make test green. [gated 2026-11-18]
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
9. No wording changed outside the planned edits; every marker and `§ Label` citation stays on one line followed by `)` or `;`; new prose lines ≤ 80 columns, except by name the 12 route lines and the template rows (`Advisor` row, `ADVISOR` field), which run as wide as the rows beside them, and the CHANGELOG bullet (one unwrapped line, like every bullet in that file) (manual). [gated 2026-11-18]

## FILE SCOPE
skills/feat/SKILL.md, skills/bugfix/SKILL.md, skills/hotfix/SKILL.md, skills/ship-feature/SKILL.md, skills/init-project/SKILL.md, skills/audit-delta/SKILL.md, skills/code-clean/SKILL.md, skills/onboard/SKILL.md, skills/harden/SKILL.md, skills/pack-seo/skills/seo/SKILL.md, skills/pack-seo/skills/geo/SKILL.md, skills/pack-web-validate/skills/web-validate/SKILL.md, lib/effort-shift.md, CHANGELOG.md
(bookkeeping: .claude/tasks/TODO.md, .claude/audits/BUGS-FOUND.md, .claude/memory via memory.sh, this contract; transient plan under docs/superpowers/plans/)
