# CONTRACT — cc-oom-score-adj (BLK-044, block G)
- date: 2026-11-13 | flow: bugfix | branch: bugfix/cc-oom-score-adj (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
BLK-044 (block G): claude processes started via `cc` inherit oom_score_adj -1000. Root cause traced 2026-11-13: /etc/systemd/system/ssh.service.d/override.conf (root, 2026-09-22) sets `OOMScoreAdjust=-1000` on sshd; sshd → tmux → dtach → claude inherit it; `systemd-run --user --scope -p OOMScoreAdjust=500` fails ("Unknown assignment", scopes reject the property); an unprivileged write `echo 500 > /proc/self/oom_score_adj` inside the scope works (raising is allowed). Fix in lib/cc.sh: the inner `bash -c` writes 500 to /proc/self/oom_score_adj (ignore failure, never lower) before `exec claude`, so the OOM killer can pick a runaway claude first; lib/tests/cc.test.sh gains a check (the stub claude prints /proc/self/oom_score_adj or the inner script's write is asserted hermetically); proof = a new `cc` session's `/proc/<pid>/oom_score_adj` = 500 (the user starts one; this session was started before the fix). The sshd override itself is the user's (root) call, left in place.

## CLARIFICATIONS
- [gated 2026-11-13, internal] raise-only guard: the write runs only when the current value is below 500 (`[ "$(cat /proc/self/oom_score_adj)" -lt 500 ]`), stderr to /dev/null; a missing /proc leaves exec untouched. Value 500 = claude dies before shells at 0, after a genuine leak at 1000.
- [gated] test shape: the stub claude prints `oom=<value>`; the check expects 500 when the runner's own value is < 500, else the runner's value unchanged (raise-only property proven either way).

## ACCEPTANCE CRITERIA
1. lib/cc.sh inner script raises oom_score_adj to 500 before exec, raise-only (r1 expected 21; the header comment names it too → 3 lines).
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'oom_score_adj' lib/cc.sh)$(grep -c -- '-lt 500' lib/cc.sh)
   EXPECT: 31
   EVIDENCE: MET exit=0 marker-found :: 31
2. Regression test present and green.
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/cc.test.sh 2>&1 | tail -1
   EXPECT: FAIL=0
   EVIDENCE: MET exit=0 marker-found :: PASS=31 FAIL=0
3. Hermetic proof: the inner script, run with the test stubs, lands claude at 500 when started below 500.
   CHECK: cd /home/bchanot/Documents/claude && grep -c 'oom=' lib/tests/cc.test.sh | grep -c '^[1-9]'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
4. shellcheck clean on lib/cc.sh and lib/tests/cc.test.sh (-x: the test sources claude-stub.sh, SC1091 info predates the fix).
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -x lib/cc.sh lib/tests/cc.test.sh && echo SC-OK
   EXPECT: SC-OK
   EVIDENCE: MET exit=0 marker-found :: SC-OK
5. Live proof (manual, user): a new `cc` session → `cat /proc/<claude pid>/oom_score_adj` prints 500; this session predates the fix.
6. make test green (manual, bun on PATH).
   (manual: run 2026-11-13 on the final tree, `PATH=$HOME/.bun/bin:$PATH make test` → "SUITE: all GREEN / all suites green")

## FILE SCOPE
lib/cc.sh (inner bash -c script + header comment), lib/tests/cc.test.sh. BLK-044 status → STEP 8 via memory.sh; MIGRATION/README mention → STEP 7 doc sync.
