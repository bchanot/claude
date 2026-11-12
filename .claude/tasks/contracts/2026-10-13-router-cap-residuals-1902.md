# CONTRACT — router-cap-residuals
- date: 2026-10-13 | flow: feat | branch: feature/router-downgrade-cap (working branch, commit in place)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User: "tres bien, fix les residus"
(the residuals = the three accepted residuals of the downgrade-cap run, TODO.md 2026-10-13 entry, items (1)-(3); item (4) "model unknown to the table" was a one-off observation, not a residual to code)

/feat arguments: model-router: close the three residuals of the downgrade-cap run (TODO 2026-10-13). (1) An unrowed sub-agent with no explicit model spawned while main is demoted (turnModel set) must not inherit the demoted parentModel: spawn it on the session model. (2) The cap reads `session.usage().context.tokens`, which may not include the prompt just submitted: estimate the submitted prompt's size at prompt.submit and add it to the tokens of that turn's first main step before the cap check. (3) `CACHE_TTL_MS` is a 60 min constant: adopt the engine's `cache_ttl` carried by PostModelSwitch events when present (parse `5m`/`1h` forms), fall back to the constant. Same branch feature/router-downgrade-cap.

## CLARIFICATIONS
Q: prompt-size estimate unit / A: delegated — code points / 3, rounded up (conservative: French and code tokenize denser than English)
Q: add the estimate blindly, or detect whether usage already counts the prompt? / A: delegated — detect: usage read at prompt.submit vs at the turn's first main step; the estimate is added only when the growth is under half the estimate (the prompt was not counted)
Q: hand-off log word for a spawn pinned to the session model / A: delegated — `session` (model cause), verbose line only
Q: `/route show` shows the TTL? / A: delegated — yes, inside the switch word: `on (downgrade, cap 120000 tokens cold, ttl 60 min)`
Q: which spawns may be pinned? / A: [r2, challenge BLOCKER] only built-in types with no frontmatter model (`general-purpose`), main's own non-fork non-workflow children, when main sits BELOW the session model; the hook cannot see a frontmatter `model:`, so any wider rule would override agents' own pins
Q: estimate consumption / A: [r2] first main step after the submit; carried across a turn end when unconsumed; texts read the same adjusted size (pure peek); the served record stays raw

## ACCEPTANCE CRITERIA
1. `spawnTarget` pins a spawn to `st.sessionModel` (verbatim) ONLY when: no explicit `model`, no row, not a fork, no workflow, `parentAgentId` undefined (main's own child), `subagentType` in the allowlist `INHERITING_AGENTS` (`general-purpose`: built-in types with no frontmatter model) AND offered with source `built-in` (`st.offers`; a shadowing repo/user agent of that name, or no offer record, is never pinned), `turnModel` set AND ranking BELOW the session model (demotion or breaker fallback, never an upgrade), session model ranked and not down. Everything else is untouched. Hand-off bookkeeping: `wanted` set, model cause `session`. A `shortcut:` comment names the frontmatter blind spot.
2. Prompt-size estimate: `prompt.submit` (any origin; text plus `context` entries) and `skill.prompt` (ONLY main's typed skill, never a sub-agent preload) ADD `ceil(codePoints / 3)` to a pending estimate (sum; the FIRST entry's usage read is the baseline); a `document` attachment marks the estimate unknown. A mid-turn submit (`turnId` set) is pending for the NEXT turn (baseline reset at promotion). A pure `withEstimate(st, raw)` returns `raw + estimate` when the baseline is unknown or usage grew by less than half the estimate, `undefined` when unknown, else `raw`; it is applied in the shared reading path (`readingFor`, texts) AND in `mainPlan` (step), so both agree. `noteServed` records the RAW size. The estimate is consumed by the first main step of its turn; an unconsumed one is carried across the turn end with its baseline reset (added at the next step), never dropped.
3. TTL: `State.cacheTtlMs` initialised to `CACHE_TTL_MS` (60 min), replaced on a PostModelSwitch event whose `cache_ttl` is one of the engine's two values (`'5m'` → 5 min, `'1h'` → 60 min; anything else ignored); events carrying `agent_id` change neither the TTL nor `sessionModel`. `coldRead` uses `st.cacheTtlMs`. The TTL survives `/clear` and is NOT reset by `/route reload`.
4. `/route show` switch word reads `on (downgrade, cap <N> tokens cold, ttl <M> min)` when on; `off (downgrade)` unchanged; the existing show test is migrated.
5. Tests in `hooks/register.test.ts`: (a) general-purpose during a demoted turn → session model; (b) no route → untouched; (b2) rowed feater → row wins; (b3) fork → untouched; (b4) nested spawn → untouched; (b5) non-allowlisted unrowed type → untouched; (b6) upgraded main (haiku session → fable) → untouched; (d) pasted prompt counted before the first step (cap 110000, raw 100000, estimate 20000 → refused); (e) growth = half → not added → allowed, growth < half → added → refused; (f) consumed by the first step, carried across turn end when unconsumed; (g) `'5m'` → 6 min old record cold, `'1h'` → 59 min old warm; (h) sub-agent switch event leaves TTL and sessionModel; (i) `/clear` keeps the TTL; (j) show ttl text default and after `'5m'`; (k) document attachment blocks the first step's switch; (l) typed skill body counted, (l2) a preload during an in-flight spawn adds nothing; (b7) a shadowed `general-purpose` (source `projectSettings`) is never pinned. Estimate tests run with `classify: false`. Migrated existing tests, expectations re-derived, never weakened: the show text test (ttl suffix) and `toast: a downgrade held by the cap says so` (its cold-read figure now includes the typed `/feat` prompt's estimate, 6 tokens for 17 code points, plus any typed body counted).
6. Whole mod suite green.
   CHECK: make test suite=lib/tests/mods.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
7. `coldRead` reads `st.cacheTtlMs`, not the constant; the allowlist exists.
   CHECK: cd mods/model-router && ! grep -n "CACHE_TTL_MS" hooks/register.ts | grep -q "now - hit.at" && grep -q "cacheTtlMs" hooks/register.ts && grep -q "INHERITING_AGENTS" hooks/register.ts && echo CRIT7-OK
   EXPECT: CRIT7-OK
   EVIDENCE: MET exit=0 marker-found :: CRIT7-OK

## FILE SCOPE
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
(README/USAGE/CHANGELOG via STEP 6 doc-sync)
