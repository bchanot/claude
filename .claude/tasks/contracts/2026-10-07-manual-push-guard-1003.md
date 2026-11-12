# CONTRACT — manual-push-guard (run B of manual-push mode)
- date: 2026-10-07 | flow: feat | branch: feature/manual-push-mode (run A landed as 2fc8830; run C = skills that push, separate)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (fr): "ok enchaine sur le run B"
Run B as scoped in `.claude/tasks/contracts/2026-10-06-manual-push-mode-1632.md` CLARIFICATIONS and `.claude/tasks/TODO.md` "manual-push-mode": `hooks/push-guard.sh` PreToolUse (deny `git push` in manual mode) + test + settings.json (hook wiring, widen `gitflow.*` deny: `git config * gitflow.*`, `git -c gitflow.*`, `GIT_CONFIG_COUNT=*`; environment prose ~480/~499) + session-start banner push mode. User decisions (2026-10-06): mechanical block of `git push` chosen; only `! git push` (the user, in the terminal) passes; hook name `hooks/push-guard.sh` + `lib/tests/push-guard.test.sh`.

## CLARIFICATIONS
Q: hook deny form / A: documented JSON on stdout, exit 0: `hookSpecificOutput.permissionDecision = "deny"` + `permissionDecisionReason` (code.claude.com/docs/en/hooks.md). Reason reaches Claude as the tool error. [orchestrator, internal]
Q: middle wildcards in `permissions.deny` Bash patterns / A: supported (`Bash(git * main)` documented), `*` matches any text incl. spaces, literal match on the whole command string. [orchestrator, verified via docs]
Q: fail-CLOSED on an unparseable `gitflow.autopush` value / A: user: refuse the push. In the GUARD only (deny, reason names the invalid value); lib and emitted hooks stay fail-open until run D (every reader at once, emitters included). [gated 2026-10-07]
Q: banner wording / A: user picked `push : manual`; final line (43 chars, fits the 44-char box): `🔒 push : manual (autopush=false) — ! git push`. [gated 2026-10-07]
Q: `git push --dry-run` / `-n` in manual mode / A: denied like any push (one rule, no carve-out; the user runs it). [orchestrator — simplest, stated]
Q: challenge r1 — deny widening vs run C's read / A: widen WRITE forms only (`git *config *gitflow.* *`, `*unset*`, `-c`, `--config-env`, `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT`, Edit/Write of `.git/config` and `.gitconfig`); the read `git config --bool --default true gitflow.autopush` stays reachable for run C. `Bash(env GIT_CONFIG_COUNT*)` dropped (covered by the existing `env GIT_CONFIG*`). [gated 2026-10-07, orchestrator — scope]
Q: challenge r1 — no-jq fallback / A: dropped; jq is a hard dependency (install-plugins.sh); the guard warns on stderr and allows, like every sibling hook. Fail-closed EXIT trap kept for internal errors once a push is detected. [orchestrator — internal]
Q: challenge r1 — mode read outside a repo / A: no work-tree gate; `git config` reads global/system there (work-machine `--global` deployment). Candidate dirs = cwd + literal `-C`/`cd` tokens; unresolvable → skipped, never an allow. [orchestrator — internal, fail-closed]
Q: challenge r1 — classifier coverage / A: one soft_deny entry added for pushes in manual mode in any form (scripts, aliases, subshells, sub-agents); env prose no longer names the hook as the whole defence. Matcher `Bash|Monitor` in its own hook group, timeout 10 s. [orchestrator]
Q: confirmation r2 — bare read / A: a trailing ` *` in a permission glob also matches end-of-string (evidence in plan Context), so the bare read `git config … gitflow.autopush` is denied for Claude after run B; hooks and lib keep it (not tool calls). Run C reads the mode through a lib verb (`gitflow.sh push-mode`), recorded in TODO. The deny list is simplified to `Bash(git *config *gitflow.*)` + section-level and env/edit forms (18 entries). [gated 2026-10-07, orchestrator — scope, surfaced to the user]
Q: confirmation r2 — oracles / A: settings.json assertions live in the test file (T40–T43), never in a CHECK command or a commit message: the new tokens would deny the command that names them. [orchestrator]
Q: hardening gate — two cases where the mode cannot be read safely (more than 20 distinct `cd`/`-C` dir tokens in one command; a named dir that exists but cannot be entered) deny the push even when the cwd is in auto mode; the verifier flagged this against criterion 2's "zero noise outside manual mode" / A: user: refuse the push (fail closed). Criterion 2 is read with this exception: auto-mode silence holds for every command whose named dirs can all be evaluated and number at most 20. [gated 2026-10-07]
Q: full-suite criterion / A: every suite except `lib/tests/design-tool-gate.test.sh`, a pre-existing environmental red on this machine (21st CLI present; reproduced on develop fa67664 without run A; TODO "test hermeticity"). Declared upfront, not loosened after a red. [orchestrator]

## ACCEPTANCE CRITERIA
1. `hooks/push-guard.sh` (PreToolUse) denies any Bash command that runs `git push` — plain, `git -C <dir> push`, `git -c k=v push`, `--no-pager`, `--dry-run`/`-n`, inside `cd x && git push`, `(…)`, `bash -c '…'`, after `;`/`&&`/`|`, absolute `/usr/bin/git`, backslash-newline split — when `gitflow.autopush` reads false (or unparseable) in the payload cwd or in any literal `-C`/`cd` dir the command names (global config counts outside a repo). JSON deny form; the reason names manual push mode and tells the user to run it with `! <command>`.
   CHECK: out=$(make test suite=lib/tests/push-guard.test.sh 2>&1); printf '%s' "$out" | grep -q '^FAIL' && exit 1; printf '%s' "$out" | grep -qE 'PASS=(4[0-9]|[5-9][0-9]) FAIL=0' && echo PUSH-GUARD-OK
   EXPECT: PUSH-GUARD-OK
   EVIDENCE: MET exit=0 marker-found :: PUSH-GUARD-OK
2. Zero noise outside manual mode: auto mode (key unset or true, no global key) → the hook prints nothing and exits 0 for every command, `git push` included, except the two fail-closed cases gated in CLARIFICATIONS (more than 20 distinct dir tokens; a named dir that exists but cannot be entered) [gated 2026-10-07]; in manual mode every non-push command (`git status`, `git commit -m "fix push guard"`, `gitflow.sh finish`, `git pushd`, `git stash`, `echo pushed`) → nothing, exit 0. An unparseable value (e.g. `flase`) → deny, reason says the value is not a boolean. No jq → stderr warning, allow (sibling-hook behaviour, jq is a hard dependency). Locked by the same test file.
3. `settings.json`: (a) `hooks.PreToolUse` gains its own group `matcher "Bash|Monitor"` running `bash ~/.claude/hooks/push-guard.sh` with `timeout` 10; (b) `permissions.deny` gains the 18 entries listed in the plan (key writes in any `git … config` spelling, section removal/rename, `-c`/env overrides, direct edits of git config files); (c) one new soft_deny entry on pushing in manual-push mode in any form with the no-clearance clause, and the routing-around hard_deny names PreToolUse hook refusals; (d) prose: "Branch deletion by hand" stays unconditional with a manual-mode parenthetical, "**Push discipline**" gains the exception. Valid JSON; no existing entry removed, reworded or weakened. Locked by push-guard.test.sh T40–T43 (file-content assertions).
   CHECK: jq . settings.json >/dev/null && out=$(make test suite=lib/tests/push-guard.test.sh 2>&1) && ! grep -qE '^FAIL T4[0-3]' <<<"$out" && grep -qE 'PASS=[0-9]+ FAIL=0' <<<"$out" && echo SETTINGS-OK
   EXPECT: SETTINGS-OK
   EVIDENCE: MET exit=0 marker-found :: SETTINGS-OK
4. `hooks/session-start.sh` banner: when `gitflow.autopush` reads false from the session cwd (local or global), one extra line `🔒 push : manual (autopush=false) — ! git push` inside the box, right border aligned (`%-46s`: bash pads by bytes, `—` is 3); nothing otherwise. Locked by push-guard.test.sh T44–T46 (fixture in the suite, `SESSION_START_OFFLINE=1`, positive control before the absence check).
   CHECK: grep -q 'gitflow.autopush' hooks/session-start.sh && grep -q 'push : manual (autopush=false)' hooks/session-start.sh && grep -q '%-46s' hooks/session-start.sh && out=$(make test suite=lib/tests/push-guard.test.sh 2>&1) && ! grep -qE '^FAIL T4[4-6]' <<<"$out" && echo BANNER-OK
   EXPECT: BANNER-OK
   EVIDENCE: MET exit=0 marker-found :: BANNER-OK
5. shellcheck clean on `hooks/push-guard.sh`, `hooks/session-start.sh`, `lib/tests/push-guard.test.sh`; `bash -n` on all three.
   CHECK: shellcheck hooks/push-guard.sh hooks/session-start.sh lib/tests/push-guard.test.sh && bash -n hooks/push-guard.sh hooks/session-start.sh lib/tests/push-guard.test.sh && echo SHELLCHECK-OK
   EXPECT: SHELLCHECK-OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK-OK
6. Every hermetic suite green except the declared environmental red `lib/tests/design-tool-gate.test.sh` (CLARIFICATIONS).
   CHECK: fail=0; for t in $(ls lib/tests/*.test.sh lib/seo-data/*.test.sh lib/gitflow-test.sh lib/tests/run-*.sh | grep -v design-tool-gate.test.sh); do make test suite="$t" >/dev/null 2>&1 || { fail=1; echo "RED $t"; }; done; [ $fail -eq 0 ] && echo SUITES-OK
   EXPECT: SUITES-OK
   EVIDENCE: MET exit=0 marker-found :: SUITES-OK
7. No change to lib/gitflow.sh, hook emitters, githooks/, .githooks/, hooks/unpushed-guard.sh, skills/, CLAUDE.global.md; no new config key or env var; `hooks/rtk-rewrite.sh` untouched (integrity pin); no `eval` in the guard. Floor guard clean (no new suppression).

## FILE SCOPE
hooks/push-guard.sh (new) · lib/tests/push-guard.test.sh (new) · settings.json · hooks/session-start.sh
