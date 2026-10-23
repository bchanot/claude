# CONTRACT — router-keyword-cap (feat C of the routing policy, BLK-032)
- date: 2026-10-23 | flow: feat | branch: feature/router-keyword-cap
- status: active

## REQUEST (verbatim — IMMUTABLE)
push tout ce qui doit etre push et suprprime ce qui doit etre supprime et apres passe au feat C !
lance le /feat il ne cdevrait pas etre bloque je comprend pas

/feat args: feat C: model-router keyword rules capped at the session model (BDR-123 deferred item: keyword-lift gap), closes BLK-032. Context: .claude/memory/decisions.md BDR-123, blockers.md BLK-032, journal 2026-10-19..22. Uncommitted mods/model-router/routing.json adds "audit": "audit" in the phases map (dialog write from feat A).

TODO.md:10 (the feat C definition the request points at): "feat C: cap the default keyword prompt rules (plan|design|architecture, why|review|audit|analyze, ultrathink) at the session model, effort only like the classifier; close BLK-032 after"

## CLARIFICATIONS
- Internal: the cap reuses the classifier's ceiling (`wantedModel` + `wouldRunHead` in register.ts): a route whose source is `prompt` (default keyword rules AND prompt floor rules such as `ultrathink`, user-added rules from the machine config included) never names a model ranked above the session model; above it → no model move (main keeps its current model), the phase's effort still applies. Same semantics as the classifier, one shared predicate.
- Internal: the route tool (`source: model`), skill rows (`skill`/`run`), sticky `/route` (`user`) and derived dispatches stay uncapped: they are the sanctioned paths to Fable (BDR-123).
- Internal: an unknown or unranked session model leaves the cap inert, like the classifier; harmless because main is never switched off an unranked model (test `unknown: a session model absent from the table is never switched`).
- Internal: the mods/model-router/routing.json `"audit": "audit"` line (feat A dialog write, flagged out of scope by the BLK-034 verifier) is committed on this branch as its own commit by the orchestrator before dispatch; it is not part of the executor's diff.

- [gated 2026-10-23, after challenge r1] MECHANISM CHANGED (supersedes the first 3 internal bullets above): prompt rules (default keyword rules, `ultrathink` floor, user-added rules) and the derived `orchestrate` route on a main Agent dispatch write EFFORT-ONLY routes (`belowRun` pattern), so they never name a model; the model axis falls through to a held run slot or stays on the current model. `wantedModel`/`wouldRunHead` (classifier ceiling) are not edited. Reason: the r1 cap shadowed a held best-tier run slot (keyword reply inside /feat dropped Fable) and failed open on an unknown session model.
- [gated 2026-10-23] Derived orchestrate (background agent dispatch) capped too, same mechanism (user pick: "Oui, effort seul aussi").
- [gated 2026-10-23] Accepted edges (plan r2 §Edge cases): haiku session → keywords are no-ops; session model held down → keyword turn follows the plain-turn fallback; mid-turn ultrathink after a classifier demotion keeps the guessed model for that turn (amends BDR-115 2026-10-13 clause "floor model beats guess"); no stand-in notch on keyword turns.

## ACCEPTANCE CRITERIA
1. The mods suite is green (manifest, link, validate --strict, `claude plugin test` running register.test.ts).
   CHECK: cd /home/bchanot/Documents/claude && make test suite=lib/tests/mods.test.sh 2>&1 | tail -3
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: PASS model-router: plugin test passed mods: 6 pass, 0 fail all suites green
2. On an opus session, a typed default keyword prompt of the `plan` rule (e.g. `plan the billing migration`) runs the next main step on opus, never fable, at the plan phase's effort (xhigh). A dedicated test named `keyword cap: a plan keyword on an opus session stays on opus at xhigh` exists in register.test.ts.
   CHECK: grep -c "test('keyword cap: a plan keyword on an opus session stays on opus at xhigh'" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
3. On an opus session, a typed `reflect` keyword prompt (e.g. `why does the cache miss`) runs on opus at the reflect phase's effort (high). Test `keyword cap: a reflect keyword on an opus session stays on opus at high`.
   CHECK: grep -c "test('keyword cap: a reflect keyword on an opus session stays on opus at high'" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
4. On an opus session, `ultrathink` runs on opus at effort max (floor kept, model capped). Test `keyword cap: ultrathink on an opus session stays on opus at max`.
   CHECK: grep -c "test('keyword cap: ultrathink on an opus session stays on opus at max'" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
5. The sanctioned lifts still reach fable on an opus session: a keyword turn followed by a route tool call `phase: 'plan'` runs on fable. Test `keyword cap: a route tool call after a keyword still lifts to fable`.
   CHECK: grep -c "test('keyword cap: a route tool call after a keyword still lifts to fable'" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
6. A capped keyword is never a stand-in: on an opus session with fable held down, a `plan` keyword runs on opus at xhigh (no +1 stand-in notch), and no probe of fable is made. Test `keyword cap: a held fable gives no stand-in notch to a capped keyword`.
   CHECK: grep -c "test('keyword cap: a held fable gives no stand-in notch to a capped keyword'" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
7. [gated 2026-10-23] Fable-session tests keep their expectations, except the ones plan r2 §Tests B names (l.935 rebased, l.5300 renamed, l.5690 effort max→xhigh), each edit carrying a one-line comment saying why (verifier reads the diff).
8. [gated 2026-10-23] The probe tests l.5564, l.5597, l.5636 lift through `planRoute($)` as plan r2 §Tests B spells out; their subject (probe of fable, hold lengths, in-flight failure leaves the target unverified) is still asserted; expectation edits limited to what plan r2 names, each commented.
9. [gated 2026-10-23] `defaultFromPrompt`, the floor branch of `routeFromPrompt` and `pushOrchestrate` write routes with an `effort` and no `tier`/`model` (one shared helper); `wantedModel` and `wouldRunHead` are byte-identical to develop; `mainModelSlot` no longer reads `turnFloor`.
   CHECK: cd /home/bchanot/Documents/claude && f=mods/model-router/hooks/register.ts && a=$(git show HEAD:$f | sed -n '/^function wantedModel/,/^}/p;/^function wouldRunHead/,/^}/p' | md5sum) && b=$(sed -n '/^function wantedModel/,/^}/p;/^function wouldRunHead/,/^}/p' $f | md5sum) && c=$(sed -n '/^function mainModelSlot/,/^}/p' $f | grep -c turnFloor || true) && d=$(sed -n '/^function defaultFromPrompt/,/^}/p;/^function routeFromPrompt/,/^}/p;/^function pushOrchestrate/,/^}/p' $f | grep -c 'phaseRoute(' || true) && e=$(grep -c '^function mainModelSlot' $f || true) && [ "$a" = "$b" ] && [ "$e" = 1 ] && echo "ceiling-same slot-floor=$c phaseRoute-in-writers=$d"
   EXPECT: ceiling-same slot-floor=0 phaseRoute-in-writers=0
   EVIDENCE: MET exit=0 marker-found :: ceiling-same slot-floor=0 phaseRoute-in-writers=0
10. lib/effort-shift.md "Limits" states that keyword prompt rules, `ultrathink` and a background agent dispatch set the turn's effort only, never a model above the session model, Fable on main coming only from a skill row, the `route` tool or a typed `/route`; lines ≤ 80 columns.
    CHECK: f=/home/bchanot/Documents/claude/lib/effort-shift.md; a=$(tr '\n' ' ' < $f | tr -s ' ' | grep -c 'never a model above the session model'); b=$(awk 'length($0)>80' $f | wc -l); echo "cap=$a/long=$b"
    EXPECT: cap=1/long=0
    EVIDENCE: MET exit=0 marker-found :: cap=1/long=0
11. The executor's diff touches only the FILE SCOPE.
    CHECK: cd /home/bchanot/Documents/claude && git diff --name-only HEAD | grep -v -x -e mods/model-router/hooks/register.ts -e mods/model-router/hooks/register.test.ts -e lib/effort-shift.md | wc -l | sed 's/^/outside=/'
    EXPECT: outside=0
    EVIDENCE: MET exit=0 marker-found :: outside=0
12. [gated 2026-10-23] A keyword reply inside a held best-tier run keeps main on fable (opus session). Test `keyword cap: a keyword inside a held best-tier run keeps the run on fable`.
    CHECK: grep -c "test('keyword cap: a keyword inside a held best-tier run keeps the run on fable'" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts
    EXPECT: 1
    EVIDENCE: MET exit=0 marker-found :: 1
13. [gated 2026-10-23] An unknown session model ('') never lets a keyword lift main. Test `keyword cap: an unknown session model never lets a keyword lift main`.
    CHECK: grep -c "test('keyword cap: an unknown session model never lets a keyword lift main'" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts
    EXPECT: 1
    EVIDENCE: MET exit=0 marker-found :: 1
14. [gated 2026-10-23] A main background dispatch outside a run keeps main on the opus session model at orchestrate's effort. Test `keyword cap: a dispatch outside a run keeps main on the session model`.
    CHECK: grep -c "test('keyword cap: a dispatch outside a run keeps main on the session model'" /home/bchanot/Documents/claude/mods/model-router/hooks/register.test.ts
    EXPECT: 1
    EVIDENCE: MET exit=0 marker-found :: 1

## FILE SCOPE
- mods/model-router/hooks/register.ts
- mods/model-router/hooks/register.test.ts
- lib/effort-shift.md
