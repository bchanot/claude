# CONTRACT — router-probe-session-model
- date: 2026-10-16 | flow: bugfix | branch: bugfix/router-probe-session-model
- status: active

## REQUEST (verbatim — IMMUTABLE)
pareil on a vait fait en sorte que si on avait plus fable, cela le detectait et il ne reuotait pas vers fable. La ca fait plusierus fois qu'il essaie de router vers fable et comme ya plus de credit il dit que les usages sont depasse blabla alors qu'il devrait ocntinuer apre en allant sur opus max ou xhigh

(pasted log)
⏺ model-router: model-router: downgrade skipped: context size unknown
⏺ model-router: main: fable/high → fable/medium (implement: classifier)
You're out of usage credits. Run /usage-credits to keep using Fable 5.1 or /model to switch models.
⏺ model-router: model-router: claude-fable-5-1 unavailable (rate_limit) for 15 min; routing falls back

(ca vient de le faire) peut etre que j'ai pas bien redeployer le claude

## CLARIFICATIONS
Q: Root cause? / A: 2cccc43 probes only a MOVE target (`unprobed()` requires `call.moved`). A session whose own model is fable (cur) keeps fable unprobed: every new process and every hold lapse (cur = session model, unverified after markDown) loses a turn to the 429. Accepted residual of BLK-030, now reported by the user as the bug. [orchestrator 2026-10-16]
Q: Why was cur excluded originally? / A: plan r1 probed in a loop BEFORE deciding (spin BLOCKER). Current design decides first, probes once, re-decides once without probe: probing the kept model reuses that bounded path. [orchestrator 2026-10-16]
Q: Cost accepted? / A: one tiny completion per model per process (verified kept across /clear); ~1.3 s on a healthy session model at first decision, ≤8 s (PROBE_MS) when it is out of credits, instead of a lost turn. [orchestrator 2026-10-16, reported to user]
Q: Fallback model when the classifier guessed `implement` (work tier → sonnet) while fable is down? / A: out of scope, leaveDown unchanged; reported to the user as an open choice. [orchestrator 2026-10-16]

## ACCEPTANCE CRITERIA
1. The model-router mod test suite passes with zero failures.
   CHECK: cd /Users/b.chanot/Documents/claude && out=$(claude plugin test mods/model-router 2>&1); rc=$?; printf '%s\n' "$out" | tail -4; [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Eq '^ *0 fail$' && ! printf '%s\n' "$out" | grep -q '^(fail)' && echo SUITE_GREEN
   EXPECT: SUITE_GREEN
   EVIDENCE: MET exit=0 marker-found :: 499 pass 0 fail Ran 499 tests across 1 file. [21.41s] SUITE_GREEN
2. Regression test present and passing: a test named starting with `probe: a session model that never answers` boots the session on fable with fable's completion hanging, runs the first main step of a plan route on fable, and asserts the step runs on opus, exactly one model.complete call (fable), and `/route show` lists fable down with reason `(probe)` — with no StopFailure fired.
   CHECK: cd /Users/b.chanot/Documents/claude && out=$(claude plugin test mods/model-router 2>&1); printf '%s\n' "$out" | grep -E '^\((pass|fail)\) probe: a session model that never answers'; printf '%s\n' "$out" | grep -q '^(pass) probe: a session model that never answers' && ! printf '%s\n' "$out" | grep -q '^(fail) probe:' && echo REGRESSION_PASS
   EXPECT: REGRESSION_PASS
   EVIDENCE: MET exit=0 marker-found :: (pass) probe: a session model that never answers leaves for opus on the first step [51.95ms] REGRESSION_PASS
3. A test asserts a healthy session model is probed once and kept: session on fable answering, two turns of steps on fable → every step on fable, model.complete called exactly once (fable).
4. The old test `probe: the current model is never probed` is gone (its expectation is now wrong); no other probe test deleted: tests whose `completions` expectation changes because cur is now probed are updated so they still assert their original intent (e.g. fable never probed when the classifier guess is above the session / upgrade switch off).
   CHECK: cd /Users/b.chanot/Documents/claude && f=mods/model-router/hooks/register.test.ts; ! grep -q "the current model is never probed" $f && grep -q "no probe when the classifier guess is above the session" $f && grep -q "no probe when the upgrade switch refuses the move" $f && grep -q "a lapsed hold probes again and holds longer" $f && echo OLD_TEST_REPLACED
   EXPECT: OLD_TEST_REPLACED
   EVIDENCE: MET exit=0 marker-found :: OLD_TEST_REPLACED
5. Probe semantics: the only behavior change is that `unprobed()` (register.ts) no longer requires `call.moved`: the model the decision LANDS on (moved or kept) is probed when it is a table model, not verified, not held down, probe on, router on. Unchanged: probe after decideMain, one probe, failure → markDown(id,'probe') then ONE re-decision without a further probe, held ids never probed, `probe: false` → no completion, spawn path untouched. Doc comments that state "the current model is never probed" / "move target" are updated to match.
6. The mods census passes.
   CHECK: cd /Users/b.chanot/Documents/claude && out=$(make test suite=lib/tests/mods.test.sh 2>&1); printf '%s\n' "$out" | tail -3; printf '%s\n' "$out" | grep -Eq '^mods: [0-9]+ pass, 0 fail$' && ! printf '%s\n' "$out" | grep -q '^FAIL ' && echo MODS_GREEN
   EXPECT: MODS_GREEN
   EVIDENCE: MET exit=0 marker-found :: PASS model-router: plugin test passed mods: 4 pass, 0 fail all suites green MODS_GREEN
7. No edit outside FILE SCOPE.

## FILE SCOPE
mods/model-router/hooks/register.ts
mods/model-router/hooks/register.test.ts
