# CONTRACT — skill-routing-census
- date: 2026-09-27 | flow: feat (ad-hoc dispatch, /feat gates replayed by the orchestrator) | branch: feature/agent-skills-borrow
- status: active

## REQUEST (verbatim — IMMUTABLE)
> Build `lib/tests/skill-routing-census.test.sh`: a deterministic census of skill-description collisions across the live catalog, adapted from addyosmani/agent-skills evals Tier 2. Catalog = every `SKILL.md` under `~/.claude/skills/*/` (symlinks resolved) plus plugin skills under `~/.claude/plugins/cache/*/*/*/skills/*/SKILL.md` and `~/.claude/plugins/cache/*/*/*/.claude/skills/*/SKILL.md` (roots overridable via `SKILL_ROUTING_ROOTS`, colon-separated dirs, for fixtures). Extract `description` (scalar or `|`/`>` block), tokenize (lowercase, `[a-z][a-z0-9-]+`, stopwords, suffix stemming s/es/ed/ing), TF-IDF cosine over all pairs. Print `skills with description: N`, the top 10 pairs as `0.52  a  ~  b`, WARN lines for pairs >= `SKILL_ROUTING_WARN` (default 0.50), FAIL for pairs >= `SKILL_ROUTING_FAIL` (default 0.75). Self-test on fixtures: a near-duplicate pair must FAIL (`FIXTURE_COLLISION_DETECTED`), a distinct pair must pass (`FIXTURE_DISTINCT_OK`). Measured today: 120 skills, max 0.52 (careful ~ guard), 0 pairs >= 0.75 → green with one WARN. User go 2026-09-27 ("ok pour les 4", case 2 item 3).

## CLARIFICATIONS
- python3 embedded in the bash suite is allowed (precedent run-review-guards.sh). If the python body exceeds ~120 lines, put it in `lib/skill-routing-census.py` and keep the suite as the wrapper.
- Reference implementation (read it, reuse the logic, harden the block-description parsing): `/tmp/claude-1000/-home-bchanot-Documents-claude/977f1703-f01d-497a-b794-5b69fafcd35f/scratchpad/census.py`.
- Thresholds stay at the upstream defaults; no allowlist file; a WARN never fails the suite.
- Dedup by skill directory name: first path wins.
- Out of scope (follow-up): positive/negative prompt ranking per skill.
- The live census is machine-dependent by design (it audits this machine's catalog); the fixture self-test is the hermetic part. On a machine with an empty catalog the live pass prints `skills with description: 0` and passes.

## ACCEPTANCE CRITERIA
1. Suite green on the live catalog, catalog non-trivial here.
   CHECK: out=$(make test suite=lib/tests/skill-routing-census.test.sh 2>&1); echo "$out" | grep -qE "FAIL=[1-9]" && { echo "$out" | tail -15; exit 1; }; echo "$out" | grep -qE "skills with description: *[0-9]{2,}" && echo LIVE_GREEN
   EXPECT: LIVE_GREEN
   EVIDENCE: MET exit=0 marker-found :: LIVE_GREEN
2. Fixture flip: collision detected, distinct pair passes.
   CHECK: out=$(make test suite=lib/tests/skill-routing-census.test.sh 2>&1); echo "$out" | grep -q "FIXTURE_COLLISION_DETECTED" && echo "$out" | grep -q "FIXTURE_DISTINCT_OK" && echo FLIP_TESTED
   EXPECT: FLIP_TESTED
   EVIDENCE: MET exit=0 marker-found :: FLIP_TESTED
3. Report shape: top pairs with two-decimal scores.
   CHECK: out=$(make test suite=lib/tests/skill-routing-census.test.sh 2>&1); echo "$out" | grep -qE "^0\.[0-9]{2}  [a-z0-9:_-]+  ~  [a-z0-9:_-]+" && echo REPORT_SHAPE
   EXPECT: REPORT_SHAPE
   EVIDENCE: MET exit=0 marker-found :: REPORT_SHAPE
4. shellcheck clean.
   CHECK: shellcheck lib/tests/skill-routing-census.test.sh && echo SHELLCHECK_OK
   EXPECT: SHELLCHECK_OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK_OK

## FILE SCOPE
- lib/tests/skill-routing-census.test.sh (new); optional lib/skill-routing-census.py (new)
- CHANGELOG.md (Unreleased entry)

## PLAN
1. Roots: default globs; `SKILL_ROUTING_ROOTS` override; dedup by dir name.
2. Description extraction: scalar `description: text`; block `description: |` or `>` → join the indented continuation lines.
3. Tokens / TF-IDF / cosine as in census.py: stopword set, stem(), (1+log tf)·log(N/df), L2 norm, cosine over combinations.
4. Report + thresholds + rc. Suite: run live (a FAIL line → suite RED), then two fixture dirs under mktemp: A/B near-duplicate descriptions → expect a FAIL line → print FIXTURE_COLLISION_DETECTED; C/D distinct → expect rc 0 → print FIXTURE_DISTINCT_OK. `PASS=n FAIL=m` summary like the other suites.
