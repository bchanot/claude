# CONTRACT — citers-blind-spots

## REQUEST (verbatim — IMMUTABLE)
Close the doctrine-citers census blind spots (TODO phase 1): lib/tests/doctrine-citers.test.sh (1) `_citers_extract_files` regex `(rules|lib)/[a-z0-9-]+\.md` misses nested `lib/<dir>/x.md § Y` (e.g. lib/project-archetypes/*.md); (2) the real-census FILES list scans `skills agents lib rules hooks` only, not `templates/` nor `.claude/rules/`; (3) a citation of `.claude/rules/<f>.md § X` is read as `rules/<f>.md` (header comment admits it). Measured 2026-10-31: 0 real citations in these spots today, so the fix is preventive; each extension needs a flip-test fixture proving it bites.

## CLARIFICATIONS
- Plan r2: `.claude/tasks/plans/2026-10-31-citers-blind-spots-0100.md`. T3 keeps its old scan roots; a bare `.claude/rules/` resolves by citer (this repo's .claude/rules → itself; skills/agents/templates → templates/project-rules). `~/.claude/…` and `$HOME/.claude/…` prefixes map to this repo's tree; a bare `.claude/rules/` is a project path.

## ACCEPTANCE CRITERIA
1. The citers suite is green and holds the new checks T8a-T8h (plan r2); existing T1-T7c unchanged and green.
   CHECK: cd /home/bchanot/Documents/claude && out=$(make test suite=lib/tests/doctrine-citers.test.sh 2>&1) && printf '%s\n' "$out" | grep -q 'FAIL=0' && for n in T8a-nested-lib-resolves T8b-nested-lib-dangling T8c-project-rules-resolve T8d-project-rules-not-user-rules T8e-home-prefix-maps-to-repo T8f-scan-lists T8g-left-boundary T8h-template-rules-path; do grep -q "$n" lib/tests/doctrine-citers.test.sh || exit 1; done && echo CITERS-OK
   EXPECT: CITERS-OK
   EVIDENCE: MET exit=0 marker-found :: CITERS-OK
2. The new checks bite: with the extraction, mapping and scan lists reverted to develop's versions (fixtures kept), T8a/T8b/T8c/T8d/T8f/T8g/T8h fail (the executor reports which); T8e fails against the r3 ERE with the home-prefix alternative removed (its own negative control). Judged by the verifier (the executor reports the negative control).
3. Shellcheck clean, no added line over 80 columns, BSD-portable ERE (no grep -P).
   CHECK: cd /home/bchanot/Documents/claude && shellcheck lib/tests/doctrine-citers.test.sh && [ "$(git diff develop -- lib/tests/doctrine-citers.test.sh | grep '^+' | grep -v '^+++' | awk 'length($0) > 81' | wc -l)" = 0 ] && ! git diff develop -- lib/tests/doctrine-citers.test.sh | grep '^+' | grep -q 'grep -P' && echo LINT-OK
   EXPECT: LINT-OK
   EVIDENCE: MET exit=0 marker-found :: LINT-OK

## FILE SCOPE
- lib/tests/doctrine-citers.test.sh
