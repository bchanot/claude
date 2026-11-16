# CONTRACT — router-no-fable (user 2026-11-16: Fable = advisor, never auto-routed)
- date: 2026-11-16 | flow: feat | branch: feature/router-no-fable (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Router: Fable leaves auto-routing (user 2026-11-16: Fable is now the advisor via /advisor; Opus becomes the strongest model the router routes to). In mods/model-router/hooks/register.ts DEFAULT_CONFIG: tiers.best and tiers.big become ['opus', 'sonnet']; fable stays in `models` and at the head of `fallback` (capability rank, so a hand-picked Fable session never ranks below opus); the mergeRouting "tiers.best does not lead the fallback chain" warning must not fire on these defaults. mods/model-router/routing.json: "askTier": false (the ask-before-head dialog was a Fable credit guard, BLK-030). Fable stays selectable by hand in the /model dialog (user choice). lib/tests/effort-routing.test.sh tier_floor: the best-tier "2nd alias" floor special case goes (floor = tier head for every tier). Tests in mods/model-router/hooks/register.test.ts: the shipped defaults route plan/judge/audit to opus, best and big never pick fable even with opus down, a hand-picked fable session is not treated as below opus, no "does not lead" log.

## CLARIFICATIONS
- [gated 2026-11-16] user: Fable is the advisor (/advisor, settings advisorModel fable, bdbf1cd); "on ne doit plus autorouter sur fable, opus devient le model le plus puissant a autorouter"; Fable stays selectable by hand in the /model dialog.
- [internal 2026-11-16] plan .claude/tasks/plans/2026-11-16-router-no-fable-1100.md, section r2 wins. Explicit `model: "fable"` sub-agent pins and the advisor doctrine are separate runs (file cap).
- [gated 2026-11-16] user: Fable leaves the row Change dialog (CHOICE_ALIASES); the bare /model dialog keeps Fable, labelled "fable (custom)".
- [internal 2026-11-16, challenge r1] deviation from REQUEST: routing.json is NOT edited (askTier stays "best"). The mod runs live from this tree; old-code sessions reading `askTier: false` would route to Fable without consent. Instead tierHead asks nothing when best's head equals big's head (true on shipped tiers), so the dialog is inert whatever askTier says, and comes back if an override puts Fable at the head of best. The "does not lead" check is deleted, not reworded.
- [internal 2026-11-16, re-challenge r2] plan section r3 amends r2 (final): ask-before-Fable fires only when the alias at the head of `best` is `fable` (stored "instead" answers ignored otherwise; `/route ask-tier` replies say `inert`); targetPhase step dropped (already shipped); test buckets SHIPPED / LEGACY / REWRITTEN with test names reported; one-pass edit order (live install).

- [gated 2026-11-16, after verify] user: keep routing.json as is (askTier stays "best", inert on shipped tiers). Security MEDIUM fixed: stored "Opus instead" answers gate on fableHeadsBest, not tierHead (survive `/route ask-tier off`), test added.

## ACCEPTANCE CRITERIA
1. model-router suite green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH claude plugin test mods/model-router </dev/null 2>&1 | grep -cE '(^| )0 fail'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
2. effort-routing suite green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/effort-routing.test.sh </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
3. Default best and big tiers are opus then sonnet.
   CHECK: cd /home/bchanot/Documents/claude && grep -cE "^    (best|big): \['opus', 'sonnet'\],$" mods/model-router/hooks/register.ts
   EXPECT: 2
   EVIDENCE: MET exit=0 marker-found :: 2
4. The "does not lead the fallback chain" check is gone.
   CHECK: cd /home/bchanot/Documents/claude && { grep -c 'does not lead the fallback chain' mods/model-router/hooks/register.ts || true; }
   EXPECT: 0
   EVIDENCE: MET exit=0 marker-found :: 0
5. Full make test green (run gates with GATES_TIMEOUT=400: the full suite takes ~135 s).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
6. New tests on the SHIPPED defaults (plan r2 step 9 as amended by r3 step 6) exist; (i) plan/audit, (ii), (v) and (vi) options are red on the pre-change register.ts, (v) also red without r3 step 2; LEGACY-bucket tests keep their assertions unchanged; test names reported per bucket. `claude plugin validate --strict mods/model-router` passes; touched lines ≤ 80 columns (manual).

## FILE SCOPE
mods/model-router/hooks/register.ts (DEFAULT_CONFIG tiers ~:298-303, mergeRouting check ~:618-621, CHOICE_ALIASES ~:226, tierHead ~:1177, nextAvailable ~:1147, wantedModel ~:1608, spawnTier ~:3247, flagCommand/askTierWord, comment ~:2802), mods/model-router/hooks/register.test.ts (rig fixture defaults and new tests), lib/tests/effort-routing.test.sh (tier_floor and its flip-test fixture ~:50-110).
