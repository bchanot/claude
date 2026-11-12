# CONTRACT — manual-push-failclosed-d1 (run D1 of manual-push mode)
- date: 2026-10-07 | flow: feat | branch: feature/manual-push-mode (runs A, B, C landed)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (fr): "ok enchaine sur le run D"
Run D as consolidated in `.claude/tasks/TODO.md`: "fail-CLOSED on an unparseable `gitflow.autopush` in every reader at once (lib `_gitflow_push_off`, the two emitted push hooks + githooks regen, unpushed-guard) so the \"invalid → lib/hooks still push\" caveat in CHANGELOG/SETTINGS/skills can be removed; push-guard residuals (inner-quote/backslash tokens, lone-surrogate payload, `*) deny` default, up-front tool check, T42 base, literal `true` test); verb stderr: `LC_ALL=C` done, truncation marker + sanitizer test; client-handover: stale \"COMMIT + PUSH\" headings, `<abs project>` quoting in tour hints; release-executor own version regex".

## CLARIFICATIONS
Q: scope split / A: D1 (this contract) = fail-closed readers: lib `_gitflow_push_off`, the emitted push hooks (+ regenerated `.githooks/` and `githooks/`), `hooks/unpushed-guard.sh`, their tests. D2 = push-guard residuals + session-start banner on an invalid value + tour hint quoting. D3 = skill/agent prose (remove the "until run D" caveats, stale headings, release-executor version regex) + doc-sync. [orchestrator — scope]
Q: semantics / A: for every reader, `gitflow.autopush` unset or `true` → auto (push); `false` → manual (no push); anything else (unparseable, corrupt config, git failure) → NO push, reported as "invalid, treated as manual push mode". The lib verb `push-mode` already prints `invalid`; `_gitflow_push_off` reuses it (`!= auto` → off). The emitted hooks stay standalone `#!/bin/sh` (foreign repos, no lib): same rule inline. [orchestrator — the user chose fail-closed for the guard in run B; this extends it to every reader]
Q: regeneration of installed hooks / A: files only, with no config read or write: `bash lib/gitflow.sh emit-hook <name> > <dir>/<name>` for post-commit and post-merge under `.githooks/` and `githooks/`, in the same step as the emitter edit. NOT `install-hook` (writes a local hooks-path entry) and NOT `global-hooks` (writes the GLOBAL config when `~/.gitconfig` lacks the value — true since a dotfiles installer overwrote it at 15:39 today). `.git/config` hash unchanged and `~/.gitconfig` untouched are part of the evidence. [orchestrator — revised twice]
Q: run precondition / A: the user's `~/.gitconfig` must be restored first (identity + hooksPath); the executor checks `name =` is not `@USER@` by reading, else BLOCKED. [orchestrator]
Q: silence vs naming / A: a stopped push is NAMED on stderr by every reader (hook: one line per commit; lib: the verb's line passes through `_gitflow_push_off`): D1 must not remove the terminal user's only signal. [orchestrator — revised after challenge]
Q: unpushed-guard mode source / A: the guard reads the mode through the lib verb (`$(dirname "${BASH_SOURCE[0]}")/../lib/gitflow.sh push-mode`, the same relative path session-start uses), one reader for hooks that live next to the lib; its invalid line becomes "treated as manual push mode (nothing pushes); fix the value by hand". [orchestrator — internal]

## ACCEPTANCE CRITERIA
1. Lib: with `gitflow.autopush` set to an unparseable value, `gitflow start` creates the branch locally without pushing and prints the verb's `not a boolean` line, a commit on it is not pushed by the post-commit hook which prints a `NOT pushed` line, `gitflow finish` merges locally and origin/develop is unchanged; with `true` the post-commit hook pushes (tips equal, positive control). `_gitflow_push_off` reads the mode through `gitflow_push_mode`. Locked by the new isolated gitflow-test block T18q1–T18q5 (q5 skipped with `ok` when shellcheck is absent).
   CHECK: out=$(make test suite=lib/gitflow-test.sh 2>&1); printf '%s' "$out" | grep -q '  FAIL ' && exit 1; for t in "T18q1" "T18q2" "T18q3" "T18q4" "T18q5"; do grep -qF "ok   $t" <<<"$out" || exit 1; done; echo FAILCLOSED-LIB-OK
   EXPECT: FAILCLOSED-LIB-OK
   EVIDENCE: MET exit=0 marker-found :: FAILCLOSED-LIB-OK
2. Emitted hooks (`_gitflow_emit_push_hook`): `#!/bin/sh`-portable rule — push only when `git config --bool gitflow.autopush` returns rc 0 `true` or rc 1 (unset); `false` exits 0 silently; any other result prints one stderr line (`NOT pushed, treated as manual push mode`) and exits 0. `.githooks/` and `githooks/` regenerated (files only) and identical to the emitters (T19a–e green); no `--default true gitflow.autopush` left in the four regenerated files; auto-mode T18a–h and manual T18m green.
   CHECK: out=$(make test suite=lib/gitflow-test.sh 2>&1); printf '%s' "$out" | grep -q '  FAIL ' && exit 1; for t in T19a T19b T19c T19e T19d T18a T18b T18h T18i T18j T18k; do grep -q "ok   $t" <<<"$out" || exit 1; done; ! grep -q -- '--default true gitflow.autopush' .githooks/post-commit .githooks/post-merge githooks/post-commit githooks/post-merge && grep -q 'NOT pushed' .githooks/post-commit && echo HOOKS-OK
   EXPECT: HOOKS-OK
   EVIDENCE: MET exit=0 marker-found :: HOOKS-OK
3. `hooks/unpushed-guard.sh`: mode read through the lib verb (absolute lib path resolved before any `cd`; no temp file); anything other than `auto` behaves as manual (silent at Stop; SessionStart `ℹ manual push mode:` line); `invalid` names the value and says "treated as manual push mode (nothing pushes)"; an unreadable verb result says so. Auto and manual behaviour unchanged (T1–T13, T15–T16 green); T14 rewritten for the new semantics.
   CHECK: out=$(make test suite=lib/tests/unpushed-guard.test.sh 2>&1); printf '%s' "$out" | grep -q '^FAIL' && exit 1; grep -qE 'PASS=(2[8-9]|[3-9][0-9]) FAIL=0' <<<"$out" && grep -q 'treated as manual push mode' hooks/unpushed-guard.sh && grep -q 'gitflow.sh" push-mode\|gitflow.sh push-mode\|push-mode' hooks/unpushed-guard.sh && ! grep -q -- '--default true' hooks/unpushed-guard.sh && echo GUARD-OK
   EXPECT: GUARD-OK
   EVIDENCE: MET exit=0 marker-found :: GUARD-OK
4. No `--default true gitflow.autopush` read remains in lib/gitflow.sh or hooks/unpushed-guard.sh (the `gitflow.protect` reads keep `--default true`; `hooks/session-start.sh` is D2). shellcheck clean on lib/gitflow.sh, lib/gitflow-test.sh, hooks/unpushed-guard.sh; no new suppression; floor guard clean.
   CHECK: ! grep -q -- '--default true gitflow.autopush' lib/gitflow.sh hooks/unpushed-guard.sh && shellcheck lib/gitflow.sh lib/gitflow-test.sh hooks/unpushed-guard.sh && [ "$(git diff -- lib/gitflow.sh lib/gitflow-test.sh hooks/unpushed-guard.sh lib/tests/unpushed-guard.test.sh | grep -c '^+.*shellcheck disable')" -eq 0 ] && echo SHELLCHECK-OK
   EXPECT: SHELLCHECK-OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK-OK
5. Every hermetic suite green except the declared environmental red `lib/tests/design-tool-gate.test.sh`.
   CHECK: fail=0; for t in $(ls lib/tests/*.test.sh lib/seo-data/*.test.sh lib/gitflow-test.sh lib/tests/run-*.sh | grep -v design-tool-gate.test.sh); do make test suite="$t" >/dev/null 2>&1 || { fail=1; echo "RED $t"; }; done; [ $fail -eq 0 ] && echo SUITES-OK
   EXPECT: SUITES-OK
   EVIDENCE: MET exit=0 marker-found :: SUITES-OK
6. Judged by reading: `GITFLOW_NO_PUSH=1` semantics unchanged; `gitflow_push_mode` stdout contract unchanged; the emitted hooks remain standalone POSIX sh (no bash-isms, no lib dependency); no file outside FILE SCOPE changed except the regenerated `.githooks/{post-commit,post-merge}` and `githooks/{post-commit,post-merge}`; `pre-commit` and `reference-transaction` emitted files unchanged byte for byte; `.git/config` unchanged (hash before/after in the executor report); the `left in place` note text unchanged.

## FILE SCOPE
lib/gitflow.sh · lib/gitflow-test.sh · hooks/unpushed-guard.sh · lib/tests/unpushed-guard.test.sh · generated: .githooks/post-commit, .githooks/post-merge, githooks/post-commit, githooks/post-merge
