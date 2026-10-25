# CONTRACT — router-haiku-table
- date: 2026-10-25 | flow: bugfix | branch: feature/model-scope-dialog (in place, aiguillage WORKING)
- status: active

## REQUEST (verbatim — IMMUTABLE)
model-router models table stale: `haiku` → `claude-haiku-4-5-20251001` in DEFAULT_CONFIG (mods/model-router/hooks/register.ts ~l.256), while the native alias now resolves to `claude-haiku-5-5`. Evidence: integration_alphalink transcript 2026-10-25T16:22:53Z "model-router: claude-haiku-5-5 unknown to the models table; no switch". Impact: no switch on haiku sessions, and `/model haiku` → This project (BDR-126) would write the stale 4.5 id. Check the rest of the table (windows entry keyed on the old id, tiers, tests, census, docs citing the old id).

## CLARIFICATIONS
- Facts (claude-api skill model table, cached 2026-10-06): `claude-haiku-5-5` context 1M, effort low–max (default medium); `claude-haiku-4-5` 200K, no effort.
- [gated 2026-10-25] The "haiku takes no effort" strip (register.ts effortWord, step plan, isHaiku sites, census skip lib/tests/effort-routing.test.sh:170) is OUT of scope: separate /bugfix after this one (user pick).
- Internal: the `windows` table becomes `{}` (5.5 is 1M like every other table model); the mechanism and the override key stay.
- Rest of table checked: sonnet `claude-sonnet-5-5`, opus `claude-opus-5-5`, fable `claude-fable-5-1` are current. No doc (README, USAGE, CHANGELOG, MIGRATION) cites the 4.5 id.

## ACCEPTANCE CRITERIA
1. DEFAULT_CONFIG maps `haiku` to `claude-haiku-5-5` and `windows` holds no `claude-haiku-4-5*` key; no `claude-haiku-4-5` string left in register.ts or register.test.ts.
   CHECK: a=$(grep -c "haiku: 'claude-haiku-5-5'" mods/model-router/hooks/register.ts); b=$(grep -c 'claude-haiku-4-5' mods/model-router/hooks/register.ts mods/model-router/hooks/register.test.ts | awk -F: '{s+=$2} END{print s}'); echo "table=$a/$b"
   EXPECT: table=1/0
   EVIDENCE: MET exit=0 marker-found :: table=1/0
2. A regression test in register.test.ts: a session whose model is `claude-haiku-5-5` is known to the table (no "unknown to the models table" log) and a route on it moves main like any table model.
3. The tests that depended on the 200K haiku window still prove the window mechanism, now with an explicit `windows` override in their fixture (never deleted or weakened).
4. Mod suite green.
   CHECK: make test suite=lib/tests/mods.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
5. Full suite green.
   CHECK: make test 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
6. Diff since 20c6623 touches only the FILE SCOPE.
   CHECK: git diff --name-only 20c6623 -- . ':!.claude' | grep -vcE '^(mods/model-router/hooks/register.ts|mods/model-router/hooks/register.test.ts)$' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0
7. No new lint or test suppression.
   CHECK: git diff -U0 20c6623 -- . ':!.claude' | grep -E '^\+' | grep -cE 'eslint-disable|@ts-ignore|@ts-expect-error|shellcheck disable' | sed 's/^/n=/'
   EXPECT: n=0
   EVIDENCE: MET exit=0 marker-found :: n=0

## FILE SCOPE
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
