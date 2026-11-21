# CONTRACT — challenge-cutoff
- date: 2026-11-21 | flow: hotfix | branch: bugfix/challenge-cutoff
- status: active
- run-base: 1d21b759a0a59ea58c062eadad2157b2820d2911

## REQUEST (verbatim — IMMUTABLE)
Deux règles validées par l'utilisateur le 2026-11-21 ("fais les 4 points de ce qui manque et tourne encore en rond") : (1) lib/challenge-plan.md, re-challenge : si la confirmation trouve encore un problème majeur (BLOCKER ou MAJOR) sur un même point, ce point est reporté avec sa preuve au lieu d'être révisé une troisième fois ; (2) lib/capitalize-commit.md : le message du commit mémoire se termine par `· <todo>` (TODO +n / -m) pour que la mesure "après ~5 runs" se lise dans git log au lieu du chat.

## CLARIFICATIONS
none — request complete
[deferred 2026-11-21, confirmation challenger r2, rule applied to its own run] Whether a deferred point must stop the flow before its dispatch where the gate is past or after the dispatch (feat, bugfix, seo, geo), and whether /hotfix escalates on one: two r2 MAJORs landed on that text; it is not revised again, the core rule ships with the existing `[deferred]` meaning, the question goes to the user (TODO).

## ACCEPTANCE CRITERIA
1. lib/challenge-plan.md re-challenge bullet: a BLOCKER or MAJOR the confirmation pass still lands on a point the revision touched is not revised again; it is tagged `[deferred <date>]` with the finding quoted, for the human to accept at the gate (the existing `[deferred]` meaning). No ABANDON coupling, no new stop.
   CHECK: s=$(awk '/^## SYNTHESIZE/{p=1;next} /^## /{p=0} p' lib/challenge-plan.md); grep -q '^  max 1 extra pass, then the gate. A BLOCKER or MAJOR that confirmation pass$' <<<"$s" && grep -q '^  still lands on a point the revision touched is not revised again: it is$' <<<"$s" && grep -q '^  tagged `\[deferred <date>\]` with the finding quoted, for the human to$' <<<"$s" && grep -q '^  accept at the gate.$' <<<"$s" && [ "$(grep -c 'ABANDON' <<<"$s")" -eq 0 ] && echo CUTOFF_OK
   EXPECT: CUTOFF_OK
   EVIDENCE: MET exit=0 marker-found :: CUTOFF_OK
2. lib/capitalize-commit.md DO step 1: the message template and the three examples end with ` · TODO +n / -m`, and after the counting snippet, before step 2, the composed memory-commit message ends with ` · <todo>`, readable with `git log --oneline --grep '· TODO'`.
   CHECK: f=lib/capitalize-commit.md; a=$(grep -n '^   The message composed above ends with ` · <todo>`, as in the examples, so$' $f | cut -d: -f1); c=$(grep -n '^2. Commit surgically' $f | cut -d: -f1); s=$(grep -n 'else todo="TODO n/a"; fi$' $f | cut -d: -f1); [ -n "$a" ] && [ "$s" -lt "$a" ] && [ "$a" -lt "$c" ] && grep -q "each run's movement reads in \`git log --oneline --grep '· TODO'\`.\$" $f && [ "$(grep -c '^   - `chore(memory): .* · TODO +[0-9] / -[0-9]`' $f)" -eq 3 ] && grep -q '^   `chore(memory): <IDs> — <flow> <short> · <todo>`. Examples:$' $f && echo MSG_OK
   EXPECT: MSG_OK
   EVIDENCE: MET exit=0 marker-found :: MSG_OK
3. Locking suites stay green and only the two files change (5 removed lines: the re-challenge line, the template and the three examples).
   CHECK: [ "$(git diff --name-only 1d21b759a0a59ea58c062eadad2157b2820d2911 -- lib | wc -l)" -eq 2 ] && [ "$(git diff --numstat 1d21b759a0a59ea58c062eadad2157b2820d2911 -- lib | awk '{d+=$2} END{print d+0}')" -eq 5 ] && make test suite="lib/tests/doctrine-citers.test.sh lib/tests/plan-challenger.test.sh lib/tests/subagent-advisor.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green

## FILE SCOPE
- lib/challenge-plan.md
- lib/capitalize-commit.md
- this contract and .claude/tasks/plans/2026-11-21-challenge-cutoff-1213.md (run artifacts)
