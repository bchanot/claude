# CONTRACT — manual-push-guard-residuals-d2 (run D2 of manual-push mode)
- date: 2026-10-07 | flow: feat | branch: feature/manual-push-mode (after D1)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (fr): "ok enchaine sur le run D"
Run D as consolidated in `.claude/tasks/TODO.md`; D2 slice: "push-guard residuals (inner-quote/backslash tokens, lone-surrogate payload, `*) deny` default, up-front tool check, T42 base, literal `true` test)", session-start banner on an invalid value, tour `<abs project>` quoting in hints.

## CLARIFICATIONS
Q: single reader / A: push-guard SOURCES the lib once (absolute path resolved at the top) and calls `gitflow_push_mode` per candidate (no bash spawn per candidate); lib missing → deny with its own reason. The banner calls the verb through the existing `_gf_lib`; lib missing → no lock line. [orchestrator — revised]
Q: inner-quote/backslash tokens / A: challenge r1 — the extraction regex must capture the whole shell word (adjacent quoted and unquoted segments). A token fully enclosed in one quote pair is stripped and resolved (an inner apostrophe inside `"…"` is fine); a token that MIXES quoted and unquoted parts is DENIED (fail closed, user-gated rule for pathological commands); a backslash-escaped space in an unquoted token is unescaped deterministically (no eval) and resolved, not denied. [orchestrator — revised]
Q: unparseable payload / A: `field` fails → the raw payload is the text to scan, with the two-character JSON escapes folded to spaces, through the unchanged `is_push`; a match → static deny via the EXIT trap (mode-blind); no match → allow. Accepted limit: a `description` mentioning a push also denies on a broken payload. [orchestrator — revised]
Q: missing core tools (grep, sed, sort, head) / A: same policy as jq: one stderr warning, allow — a guard that denies every Bash call when PATH is broken makes the session unusable; PATH is not command-controlled. Documented. [orchestrator]
Q: T42 base / A: compare the deny list against `main:settings.json` (the last release; `git describe --tags` fails here because v2.0.0 is not an ancestor of the branch) instead of HEAD: "no deny entry present on main was removed" stays meaningful after the branch merges into develop. Fallback `origin/main:settings.json`; neither readable → the check prints SKIP, never FAIL. [orchestrator]

## ACCEPTANCE CRITERIA
1. push-guard: `mode_in` reads the mode through the sourced lib verb (manual/auto/invalid + its stderr line), lib missing → deny with its own reason; the `case "$mode"` has a `*)` deny default; a dir token mixing quoted and unquoted parts → deny naming it, a fully-quoted token with an inner apostrophe or a backslash-escaped space → resolved normally; unparseable payload with push-looking raw text (JSON escapes folded) → static deny, without → allow; missing core tools → stderr warning + allow; a repo with `gitflow.autopush = true` → allow. All existing cases stay green. Locked by the suite (new cases T51–T57, incl. T52b/c, T54b/c).
   CHECK: out=$(make test suite=lib/tests/push-guard.test.sh 2>&1); printf '%s' "$out" | grep -q '^FAIL' && exit 1; grep -qE 'PASS=(8[0-9]|9[0-9]|[1-9][0-9]{2}) FAIL=0' <<<"$out" && grep -q 'push-mode' hooks/push-guard.sh && ! grep -q -- '--default true' hooks/push-guard.sh && echo PUSH-GUARD-OK
   EXPECT: PUSH-GUARD-OK
   EVIDENCE: MET exit=0 marker-found :: PUSH-GUARD-OK
2. T42 compares the current deny list against the fresher of `origin/main` and `main` (SKIP if neither resolves; FAIL if the base deny list is empty): every entry present there is still present; the test prints `T42 base: <ref>`.
   CHECK: grep -q 'T42 base' lib/tests/push-guard.test.sh && ! grep -q 'base=HEAD' lib/tests/push-guard.test.sh && grep -q 'SKIP T42' lib/tests/push-guard.test.sh && echo T42-OK
   EXPECT: T42-OK
   EVIDENCE: MET exit=0 marker-found :: T42-OK
3. session-start banner reads the mode through the lib verb: `manual` → existing line; `invalid` → `🔒 push : manual (autopush bad) — ! git push` (41 chars, fits the box); `auto` or lib missing → nothing. No `--default true gitflow.autopush` read left in hooks/session-start.sh or hooks/push-guard.sh (hooks/unpushed-guard.sh is D1's; the whole-hooks grep is run after D1's commit). Locked by push-guard.test.sh banner cases (T44–T46 + new T57).
   CHECK: grep -q 'push-mode' hooks/session-start.sh && grep -q 'autopush bad' hooks/session-start.sh && ! grep -q -- '--default true gitflow.autopush' hooks/session-start.sh hooks/push-guard.sh && out=$(make test suite=lib/tests/push-guard.test.sh 2>&1) && ! grep -qE '^FAIL T(4[4-6]|57)' <<<"$out" && echo BANNER-OK
   EXPECT: BANNER-OK
   EVIDENCE: MET exit=0 marker-found :: BANNER-OK
4. skills/tour/SKILL.md: every `<abs project>` inside a command or hint is double-quoted (`git -C "<abs project>"`).
   CHECK: [ "$(grep -c 'git -C <abs project>' skills/tour/SKILL.md)" = 0 ] && [ "$(grep -c 'git -C "<abs project>"' skills/tour/SKILL.md)" -ge 3 ] && echo TOUR-OK
   EXPECT: TOUR-OK
   EVIDENCE: MET exit=0 marker-found :: TOUR-OK
5. shellcheck clean on hooks/push-guard.sh, hooks/session-start.sh, lib/tests/push-guard.test.sh; no new suppression; floor guard clean; doctrine citers green; every hermetic suite green except the declared environmental red.
   CHECK: shellcheck hooks/push-guard.sh hooks/session-start.sh lib/tests/push-guard.test.sh && [ "$(git diff -- hooks/push-guard.sh hooks/session-start.sh lib/tests/push-guard.test.sh | grep -c '^+.*shellcheck disable')" -eq 0 ] && make test suite=lib/tests/doctrine-citers.test.sh >/dev/null 2>&1 && fail=0 && for t in $(ls lib/tests/*.test.sh lib/seo-data/*.test.sh lib/gitflow-test.sh lib/tests/run-*.sh | grep -v design-tool-gate.test.sh); do make test suite="$t" >/dev/null 2>&1 || fail=1; done && [ $fail -eq 0 ] && echo SUITES-OK
   EXPECT: SUITES-OK
   EVIDENCE: MET exit=0 marker-found :: SUITES-OK
6. Judged by reading: no `eval`; the strict/loose/alias regexes unchanged; the 20-token cap unchanged; `bash -n` clean; sourcing the lib brings no `set -e`/`set -o pipefail` into the hook; the header DENIED/MISSES/LIMITS list updated; no file outside FILE SCOPE; the tour example row with `~/proj/site` stays unquoted.

## FILE SCOPE
hooks/push-guard.sh · lib/tests/push-guard.test.sh · hooks/session-start.sh · skills/tour/SKILL.md
