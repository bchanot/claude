# CONTRACT — router-probe-before-route
- date: 2026-10-14 | flow: bugfix | branch: bugfix/router-probe-before-route
- status: active
- plan: .claude/tasks/plans/2026-10-14-router-probe-before-route-0005.md (r3)

## REQUEST (verbatim — IMMUTABLE)
dans le model-router, quand on a plus d'usage fable 5, comme maintenant, il essaie quand meme de router vers fable 5, il faudrait detecter quand il n'y a plus de credit fable, alors il faut utiliser opus 5.5 xhigh ou max a la place. et donc verifier si fable est dispo avant de router vers fable

## CLARIFICATIONS
Q: Opus effort when it stands in for Fable? / A: one notch up (orchestrate medium→high, reflect high→xhigh, plan xhigh→max, escalate max) [gated 2026-10-14]
Q: Explicit Agent(model:"fable") pins (client-handover)? / A: leave them (BDR-115 kept), log a TODO residual [gated 2026-10-14]
Q: Approve plan r3? / A: yes [gated 2026-10-14]
Q: Config key `probe` (bool, default true) in ~/.claude/model-router.json to turn the probe off alone? / A: yes [gated 2026-10-14]
Q: plan test 8 records FABLE then OPUS probes (leaveDown leaves the held explicit fable for opus, an unverified move target)? / A: accepted (orchestrator, internal) — fable probed once, no spin; criterion = no re-probe of a held id [gated 2026-10-14]
Q: criterion 9 (Esc) has no regression test: claude-code/testing cannot abort the dispatch signal? / A: accepted (orchestrator, internal) — verifier judges the code path; residual noted [gated 2026-10-14]

## ACCEPTANCE CRITERIA
1. The model-router mod test suite passes with zero failures.
   CHECK: cd /home/bchanot/Documents/claude && out=$(claude plugin test mods/model-router 2>&1); rc=$?; printf '%s\n' "$out" | tail -4; [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Eq '^ *0 fail$' && ! printf '%s\n' "$out" | grep -q '^(fail)' && echo SUITE_GREEN
   EXPECT: SUITE_GREEN
   EVIDENCE: MET exit=0 marker-found :: 497 pass 0 fail Ran 497 tests across 1 file. [23.89s] SUITE_GREEN
2. Regression tests for the probe exist and pass: at least 9 passing tests whose names start with `probe:` (plan §3 tests 1-4, 6-11), among them one where the fable probe times out and the first step of a plan route lands on opus with exactly one model.complete call and no StopFailure.
   CHECK: cd /home/bchanot/Documents/claude && out=$(claude plugin test mods/model-router 2>&1); n=$(printf '%s\n' "$out" | grep -c '^(pass) probe:'); f=$(printf '%s\n' "$out" | grep -c '^(fail) probe:'); echo "probe pass=$n fail=$f"; [ "$n" -ge 9 ] && [ "$f" -eq 0 ] && echo PROBE_TESTS_PASS
   EXPECT: PROBE_TESTS_PASS
   EVIDENCE: MET exit=0 marker-found :: probe pass=16 fail=0 PROBE_TESTS_PASS
3. Regression tests for the stand-in effort exist and pass: at least 5 passing tests whose names start with `stand-in:` (plan §3 test 5 cases).
   CHECK: cd /home/bchanot/Documents/claude && out=$(claude plugin test mods/model-router 2>&1); n=$(printf '%s\n' "$out" | grep -c '^(pass) stand-in:'); f=$(printf '%s\n' "$out" | grep -c '^(fail) stand-in:'); echo "stand-in pass=$n fail=$f"; [ "$n" -ge 5 ] && [ "$f" -eq 0 ] && echo STANDIN_TESTS_PASS
   EXPECT: STANDIN_TESTS_PASS
   EVIDENCE: MET exit=0 marker-found :: stand-in pass=9 fail=0 STANDIN_TESTS_PASS
4. The mods census (manifest, link, `claude plugin validate`, `claude plugin test`) passes.
   CHECK: cd /home/bchanot/Documents/claude && out=$(make test suite=lib/tests/mods.test.sh 2>&1); printf '%s\n' "$out" | tail -3; printf '%s\n' "$out" | grep -Eq '^mods: [0-9]+ pass, 0 fail$' && ! printf '%s\n' "$out" | grep -q '^FAIL ' && echo MODS_GREEN
   EXPECT: MODS_GREEN
   EVIDENCE: MET exit=0 marker-found :: PASS model-router: plugin test passed mods: 4 pass, 0 fail all suites green MODS_GREEN
5. Probe semantics (plan §1): the probe fires only in `decideFor`, AFTER `decideMain`, only when the call moves main to a table model that is neither verified nor held down; it probes the bare canonical id via `$.model.complete` raced against PROBE_MS (8000) through one `raceTimeout` helper shared with the classifier; no hook abort signal on the probe; timeout or rejection → `markDown(id, 'probe')` then ONE re-decision without a further probe; success (any resolved shape) → verified only if not held at resolution; `markDown` drops the id from `verified` and logs through `tryLog`; `verified` survives `/clear`; the current model is never probed; the spawn path is unchanged.
6. Stand-in effort (plan §2): main only; one notch up on LEVELS (max stays max) exactly when the counterfactual rule holds (tier route, head held down, decided model = tier resolution ranked below head, and with the head available the router would have run it: classifier ceiling, upgrade switch, cold-read cap, window); never when the effort came from a different slot than the tier route, an explicit effort (`explicitEffort` flag via parseRoute and Picked→applyRoute), a prompt floor, or a non-Level engine effort; computed once and carried on the Verdict; `effortWord`, `mainRoutedText` and the verbose transition line report it ("stands in", "stand-in").
7. Truthful route answer: with the fable probe failing, `route(phase=reflect)` answers an opus id, never `claude-fable-5-1`.
8. Config key `probe` (boolean, default true) parsed and validated like `classify`, settable in `~/.claude/model-router.json`, shown in `/route show`; `probe: false` → no `model.complete` call at all.
9. Esc during a probe: the mark stands but `mainPlan` writes no turn state (`turnModel`, served record, prompt estimate, `lastPlan`) when the dispatch signal has aborted.
10. Existing tests whose expectations change under the bump are updated, not deleted (e.g. 'fallback: a rate limit on fable moves plan to opus xhigh' now expects max); `boot` installs a default successful `model.complete` answer.
11. No edit outside FILE SCOPE; the user's uncommitted `mods/model-router/routing.json` and `settings.json` changes are left untouched.

## FILE SCOPE
mods/model-router/hooks/register.ts
mods/model-router/hooks/register.test.ts
