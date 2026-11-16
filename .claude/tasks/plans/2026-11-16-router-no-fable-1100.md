# PLAN — router-no-fable (Fable = advisor, Opus = strongest auto-route)

## CONTEXT
- register.ts DEFAULT_CONFIG (~:290-305): models {haiku, sonnet, opus,
  fable}; tiers best ['fable','opus','sonnet'], big ['opus','fable',
  'sonnet'], work ['sonnet','opus'], cheap ['haiku','sonnet']; fallback
  ['fable','opus','sonnet','haiku'] (rank = index, best first).
- Tiers and fallback are machine keys: the tracked routing.json contributes
  only phases, skills and agents (routingTables ~:887); the override
  `~/.claude/model-router.json` is absent on this machine. So the shipped
  policy lives in DEFAULT_CONFIG.
- mergeRouting (~:608-625) logs "tiers.best does not lead the fallback
  chain; rank comes from the fallback list alone" when tiers.best[0] !==
  fallback[0].
- pickFallback/withEveryAlias (~:473-502): every `models` alias ends up
  ranked; one missing from the chain is appended LAST with a log. So fable
  must stay in `fallback`, at its head (true capability rank).
- askTier (BDR-135): tierHead = head of `best`; with best headed by opus
  the dialog ("Fable" / "Opus instead" / stop, TIER_HEAD hardcoded) would
  ask before every opus route. routing.json sets askTier.
- inTier (~:3857): an agent moves UP from its frontmatter alias to the
  first available model of its tier only if that model is the head or ranks
  above it; else frontmatter kept + "tier … down" log. With best/big =
  [opus, sonnet] and opus down: sonnet ranks below opus → frontmatter
  (opus) kept. Today big-tier agents with opus down move UP to fable; after
  this change they stay on opus frontmatter (by design: never below the
  floor; the engine's own fallback applies). Main loop with opus down:
  breaker fallback goes down the chain to sonnet (unchanged mechanism).
- effort-routing.test.sh tier_floor (~:56-60): for `best` it reads the
  tier's 2nd alias as the agents' frontmatter floor (LRN-224, Fable credit
  outage); for other tiers the head. Its flip-test fixture (~:94-110)
  carries the old fable tiers.
- Test rig (register.test.ts): synthetic routing.json from baseRouting()
  (phases only, ~:87); tiers come from DEFAULT_CONFIG; the machine override
  comes only from `fx.home` (HOME_FILE). 381 FABLE references; many tests
  assume best is headed by fable.

## APPROACH
1. register.ts DEFAULT_CONFIG: `best: ['opus', 'sonnet']`, `big: ['opus',
   'sonnet']`; models unchanged (fable kept); fallback unchanged
   (['fable', 'opus', 'sonnet', 'haiku']). Comment on the tiers block: Fable
   is ranked (hand picks, the advisor model) but never an auto-route target
   (user 2026-11-16); a machine override may add it back to a tier.
2. register.ts mergeRouting warning: fire only when the head of `best`
   ranks BELOW the head of another tier in the fallback chain (a tier
   "better" than best: a real misconfiguration), not merely when it is not
   fallback[0]. Wording: `model-router: tiers.best head <alias> ranks below
   tiers.<name> head <alias> in the fallback chain`. Use keyWord() for the
   names. Defaults: best opus, big opus, work sonnet, cheap haiku → no log.
3. routing.json: `"askTier": false` (replaces "best"). The askTier code
   stays (a machine override with `askTier: "best"` and fable back in best
   still works); TIER_HEAD 'Fable' label hardcoded = residual (dormant).
4. effort-routing.test.sh: tier_floor drops the best-tier special case
   (floor = tier head for every tier); its comment says why (best is headed
   by opus since 2026-11-16, LRN-224's credit floor no longer applies). The
   flip-test fixture moves to the new defaults (best ['opus','sonnet'], big
   ['opus','sonnet']) and still proves the readers reject the wrong
   verdicts.
5. register.test.ts:
   a. Measure first: apply 1-3, run `claude plugin test mods/model-router`,
      count red tests.
   b. If more than 25 are red: add a rig default so existing mechanics
      tests keep a 3-deep tier set: when a fixture gives no `home` and does
      not set `shippedTiers: true`, newWorld writes HOME_FILE with
      `{ tiers: { best: ['fable','opus','sonnet'], big: ['opus','fable',
      'sonnet'] } }` (machine override; nothing else in it). Tests that
      assert the override's absence (source word, askTier machine value,
      `fx.home` users) get `shippedTiers: true` or merge their `home` with
      these tiers, case by case, without changing what they assert. If 25
      or fewer are red: update each red test's expectation to the new
      defaults directly.
   c. New tests, all on the SHIPPED defaults (`shippedTiers: true`, no
      override): (i) typed plan, judge and audit rows route to opus (main
      and spawn); (ii) with opus marked down, a best-tier and a big-tier
      route never choose fable (main falls to sonnet via the breaker; a
      big-tier rowed agent keeps its opus frontmatter, "tier … down" log);
      (iii) a /model hand pick of fable, then a rate limit on fable → main
      moves to opus (fable ranks above opus); (iv) boot logs no "does not
      lead" / "ranks below" line; (v) the warning still fires on a machine
      override whose best head ranks below big's head (e.g. best
      ['sonnet'], big ['opus']).
   d. Red-first: (i), (ii) and (iv) fail on the pre-change register.ts.

## EDGE CASES
- Machine override re-adding fable to a tier: honored (validated by
  acceptTier against models).
- Hand pick of fable through the /model dialog: unchanged (BARE_ALIASES and
  CHOICE_ALIASES keep fable).
- Sessions already on fable (settings model fable): breaker and probe
  unchanged; phases route down to opus only per existing downgrade rules.
- askTier absent in a foreign routing.json: code default "best" now means
  asking before opus routes; acceptable (only this repo's routing.json ships
  the mod) and noted as residual.

## DISPOSITION
Amends BDR-123 (Fable via best-tier rows → no Fable auto-route; session
opus), BDR-135 (askTier off by config; code kept dormant), LRN-224 (2nd-alias
floor no longer applies: head = floor = opus). BDR-077 W1 Fable dispatch
pins handled by the next run (pins). Honors BDR-129-style single source:
the policy lives in DEFAULT_CONFIG, tracked.

## FILES
mods/model-router/hooks/register.ts, mods/model-router/hooks/register.test.ts,
mods/model-router/routing.json, lib/tests/effort-routing.test.sh.

## r2 (challenge r1: correctness CONCERNS(3), robustness CONCERNS(3), simplicity CONCERNS(2)) — SUPERSEDES APPROACH 2-5, EDGE CASES and DISPOSITION above
Landed: (a) the row Change dialog and /model labels change on shipped tiers
(fable heads no phase → dead option; opus heads best AND big → "opus
(best)", and targetPhase maps opus/xhigh to `plan`, judge unreachable)
(corr 1, rob 2, simp 2); (b) askTier is not dormant: `/route ask-tier on`,
a machine `askTier: "best"` or an absent key ask "Run it on fable?" and
"Opus instead" runs SONNET, gates included (corr 2, rob 1, simp 6); (c) the
mod runs live from this working tree: a routing.json `askTier: false` read
by OLD-code sessions on /clear or reload removes the Fable consent guard
while their old tiers still route to Fable (rob 4); (d) a rig default of
legacy tiers would test a config nobody ships and mask (a)/(b) (rob 3,
simp 3); (e) the warning reword is new scope (simp 1); (f) test (iv) is not
red-first, judge in (i) already opus (corr 3, simp 5); (g) flip fixture
must keep distinct heads (corr 8, rob 7, simp 4); (h) unranked `after` in
nextAvailable can display fable (corr 10).
User answers 2026-11-16: Fable leaves the row Change dialog
(CHOICE_ALIASES); /model keeps Fable, label stays "fable (custom)" (no
label code).

1. register.ts DEFAULT_CONFIG: tiers best ['opus','sonnet'], big
   ['opus','sonnet']; models and fallback unchanged (fable kept, fallback[0],
   capability rank). Comment on the tiers block: Fable is ranked (hand
   picks, advisor model) but never an auto-route target (user 2026-11-16);
   a machine override may put it back in a tier.
2. register.ts mergeRouting: DELETE the "tiers.best does not lead the
   fallback chain" check (log only, no consumer). No replacement warning.
3. register.ts CHOICE_ALIASES: ['opus', 'sonnet', 'haiku'] (fable out of
   the row Change dialog). BARE_ALIASES unchanged (fable stays in /model).
4. register.ts targetPhase (~:2834-2841, row Change dialog: model+effort →
   phase): tie-break when several phases match the picked model and effort
   = the row's CURRENT phase first if it matches, else the first match as
   today. So an agent row on `judge` answered "opus, xhigh" stays `judge`.
5. register.ts tierHead (~:1177-1181): return undefined (no tier ask) also
   when the head of `best` equals the head of `big` (the "instead" option
   would not be a different model). So on shipped tiers no ask fires
   whatever askTier says (routing.json, machine override, `/route ask-tier
   on`); a machine override putting fable back at the head of best brings
   the consent dialog back unchanged. routing.json is NOT edited (askTier
   stays "best"): old-code sessions keep their Fable consent guard until
   /reload-plugins. `shortcut:` comment at TIER_HEAD: the ask-tier feature
   is inert on shipped tiers (Fable credit guard, BLK-030); remove it if
   Fable never returns to a tier; harvested into TODO.md by the closing
   step.
6. register.ts nextAvailable (~:1147-1151): when `after` is given and not
   ranked (findIndex -1), return undefined instead of walking from the
   chain's head (display-only fable leak).
7. effort-routing.test.sh: delete tier_floor; field_of (~:64) uses
   tier_head; drop the duplicate assertion (~:123) and make the best-tier
   floor assertion (~:122) expect the fixture's best head. KEEP the
   synthetic flip fixture's distinct heads (fable-headed best, opus-headed
   big) so a wrong-tier read still fails. Comment: best is headed by opus
   since 2026-11-16, the agents' floor is the tier head for every tier.
8. register.test.ts rig: shipped tiers stay the default (DEFAULT_CONFIG).
   New fixture flag `legacyTiers: true` → newWorld merges `{ tiers: {
   best: ['fable','opus','sonnet'], big: ['opus','fable','sonnet'] } }`
   UNDER fx.home (`{ tiers: LEGACY, ...fx.home }`) into HOME_FILE. Measure
   the red tests after steps 1-6; for each red test:
   - the test is about a 3-deep chain or Fable mechanics (breaker or
     stand-in with fable, ask-tier dialog, hand pick of fable, Fable [1m],
     fable efforts) → add `legacyTiers: true`, assertion unchanged;
   - the test is about shipped behavior (row labels, Change dialog options,
     /model labels, rows routed on defaults, noHome / env-less routing) →
     update the expected value to the shipped tiers.
   Tests that set HOME_FILE directly mid-test (:705, :1812, :1835, :2328,
   :2791, :3392, :3735, :4410) keep what they assert: if they need legacy
   tiers, include them in the HOME_FILE they write. Report the count per
   bucket.
9. New tests on the SHIPPED defaults (no legacyTiers), main booted on OPUS:
   (i) typed plan and audit rows route to opus (red-first: plan and audit
   went to fable); (ii) with opus marked down (switchTo(OPUS, SONNET,
   'auto') or the breaker), best and big routes never choose fable: main
   on sonnet, a big-tier rowed agent keeps its opus frontmatter with the
   "tier … down" log (assert the model only; the stand-in effort notch is
   expected) (red-first); (iii) hand pick fable via the /model dialog, then
   a rate limit on fable → main moves to opus; (iv) boot logs no "does not
   lead" line (regression guard, not red-first); (v) askTier "best" in the
   machine override on shipped tiers → no tier question, the audit gates
   are not sent to sonnet (red-first); (vi) row Change dialog options are
   opus/sonnet/haiku labels without fable, and an agent row on `judge`
   answered opus + xhigh stays `judge` (red-first); (vii) bare /model
   dialog still offers fable, labelled "fable (custom)".

EDGE CASES (real behavior):
- Opus outage: best/big agents keep their opus frontmatter and spawn on the
  held opus (the gates fail, verify-secure-loop retries and escalates);
  today they moved up to Fable. Accepted residual (no engine fallback key
  in settings.json; LRN-224 hazard moves from fable to opus).
- A single opus outage now makes sonnet stand in for the head of best and
  big (standInEffort notches the row's effort up).
- A session whose baseline is fable (native /model Everywhere, not a hand
  pick) is routed by the tiers: best phases go to opus, or to sonnet with
  opus held. Accepted (Fable is not an auto-route target).
- Rollout: the working tree is the live install. Open sessions keep old
  code until /reload-plugins; routing.json is untouched so they keep the
  Fable consent dialog meanwhile. Tell the user to /reload-plugins after
  the merge.

DISPOSITION: amends BDR-123 (no Fable via rows; session opus), BDR-135
(ask-tier inert on shipped tiers by rule, kept for overrides), LRN-224
(floor = tier head for every tier). BDR-077 W1 Fable pins: next run.
FILES: register.ts, register.test.ts, lib/tests/effort-routing.test.sh
(routing.json dropped from scope).

## r3 (re-challenge r2: correctness CONCERNS(3 MAJOR), robustness CONCERNS(1 MAJOR)) — amends r2; final
1. r2 step 4 DROPPED: targetPhase already prefers the row's current phase
   (register.ts:2836-2843). Residual: on shipped tiers a SKILL row that
   answers opus + xhigh in the Change dialog lands on `plan` (run-holding)
   rather than `judge`; agents unaffected in effect (plan/judge/audit all
   route opus xhigh).
2. r2 step 5 REPLACED: `tierHead` returns undefined unless the alias at
   the head of `best` is `fable` (the dialog text is fable-specific:
   TIER_HEAD, "Run it on fable?"). So the ask-before-Fable dialog fires
   only when an override puts Fable at the head of best, whatever `big`
   says. Stored answers: `wantedModel` (slot tierChoice ~:1608) and
   `spawnTier` (tierSpawn ~:3247) ignore a stored "instead" answer while
   tierHead(st) is undefined. `/route ask-tier on|off` keeps writing the
   flag; when tierHead is undefined its reply appends ` (inert: best is not
   headed by fable)` and `/route show`'s ask-tier word reads `inert` in that
   case. `shortcut:` comment at TIER_HEAD: the ask-before-Fable dialog only
   runs when an override heads best with fable (BLK-030 credit guard);
   remove the feature if Fable never returns to a tier.
3. register.ts doc comment example at ~:2802 ("fable (best)") updated to a
   shipped label ("opus (best)").
4. Edit order: apply r2 steps 1, 2, 3, 6 and r3 step 2 in ONE pass on
   register.ts before running anything (the tree is the live install: a
   session started mid-edit must never see opus-headed best with the old
   ask armed).
5. Test buckets (replaces r2 step 8's rule), for each red test after the
   code change; report test NAMES per bucket:
   a. SHIPPED (default): update the expected value to the shipped tiers.
      Wins unless the assertion cannot hold on shipped tiers.
   b. LEGACY: `legacyTiers: true`, assertion unchanged, ONLY when the
      assertion needs a tier holding fable or a 3-deep chain (fable
      breaker/stand-in, ask-before-Fable dialog, fable [1m] routing).
   c. REWRITTEN: a test that answers the row Change dialog with
      'fable (best)' (fable efforts loop ~:3058, upgrade toasts ~:3164,
      ~:3173, fableEfforts ~:4527 used at ~:4538, ~:4544): answer
      'opus (best)' on shipped tiers (same [medium, high, xhigh, max]),
      keep the test's intent (residual f: null phase ignored, file
      without phases).
   Shared constants used by both buckets (ROUTED ~:2814, STEP1 ~:6440,
   TO_JUDGE ~:31) are split per bucket (e.g. ROUTED_LEGACY) rather than
   moving a whole group. TO_JUDGE ('opus (big)') users go LEGACY.
   newWorld throws when `legacyTiers` is combined with `noHome`, an empty
   env, `home: 'broken'` or kinds that turn the router off (the override
   cannot be read there; a silent shipped run would lie).
6. New tests (replace r2 step 9 (i) and (v); others stand):
   (i) typed plan, judge and audit rows route to opus on shipped tiers,
   main booted on OPUS (plan and audit red-first; judge a guard).
   (v) two cases on shipped tiers with the machine override's askTier
   "best": (v-a) an audit-row spawn (auditVerifier edit, ~:7162) with an
   "Opus instead" answer queued → no ask, the answer left unconsumed, the
   spawn on OPUS; (v-b) main booted on SONNET types a best row → no ask,
   main on OPUS. Prove (v) red against the change WITHOUT r3 step 2 (a
   scratch copy with steps 1-3, 6 only), not only against the pre-change
   file. (viii) override heading best AND big with fable: the dialog asks
   (fable alias at the head of best).
7. Residuals restated:
   - Rollout: live from the FIRST edit on the checked-out branch (new
     sessions load the tree); open old-code sessions keep their dialog for
     interactive best-tier routes only (old big = [opus, fable, sonnet]
     still sends judge spawns to Fable unasked while opus is held;
     headless runs too). After the merge: /reload-plugins in every open
     session.
   - Fable-baseline session: best phases now demote it to opus (or sonnet
     with opus held) only through downgradeCall, so `mainModelSwitch` and
     the 120k cold-read cap apply (past either, main stays on Fable); on a
     demotion, sessionPin pins general-purpose spawns to the Fable session
     model.
   - Opus outage: best/big agents spawn on the held opus (frontmatter
     floor), the gates fail, verify-secure-loop retries once then
     escalates. Main: sonnet stands in with the effort notch.
FILES (final): mods/model-router/hooks/register.ts,
mods/model-router/hooks/register.test.ts, lib/tests/effort-routing.test.sh.
README.md, USAGE.md and CHANGELOG through the doc-sync step.
