# PLAN — perl-timeout-group (phase 4b-4d residual, GATE 2 LOW 2026-11-13) r1
Scope: hooks/session-start.sh (:39-47), lib/tests/session-digest.test.sh (SD19 area).

DIAGNOSIS: `_SS_TMO=(perl -e "alarm shift; exec { \$ARGV[0] } @ARGV" 2)` (fallback when neither timeout nor gtimeout is on PATH, stock macOS). alarm's SIGALRM kills the exec'd process only. A child of memory.sh (background job, subshell) inherits stdout/stderr; the callers capture them (:263 `$(… 2>&1 >/dev/null)` stderr, :320 `rows=$(…)` stdout), so the command substitution waits for EOF until that child exits: the 2 s bound does not hold. timeout(1) has the same single-process limit only without --kill-after... (GNU timeout signals the child only too, but runs it in its own foreground handling; out of scope: timeout/gtimeout paths unchanged). SD19 (`exec sleep 8` stub) passes because the hung process IS the exec'd one.
RELATED MEMORY: none bears (no BLK/LRN on perl alarm or process groups); honors BDR-136 spirit (hooks fail open: digest prints `unknown` on rc 124).

FIX PLAN:
1. hooks/session-start.sh:45-46: perl runner forks; child `setpgrp(0,0)` then `exec { $ARGV[0] } @ARGV` (exit 127 on exec failure); parent `setpgrp($pid,$pid)` too (closes the race before the child's own call; failure after exec ignored), `$SIG{ALRM}` → `kill 'KILL', -$pid; exit 124`; `alarm $t; waitpid $pid, 0`; exit with the child's status (`$? & 127` → 128+signal, else `$? >> 8`); fork failure → exit 125. Single-quoted perl program (no `\$` escapes). Comment :39-40 updated: "perl forks the command into its own process group and kills the group, so a child holding the pipe dies too."
2. lib/tests/session-digest.test.sh: new SD19b after SD19: memory.sh stub `sleep 8 & exec sleep 8`… no: `( sleep 8 ) &` then `sleep 8` (the background child keeps stdout/stderr open after the main process dies); same no-timeout PATH; assert run < 6 s and the digest shows `- open: unknown (memory.sh index failed)`. Flip: old runner → ≥ 8 s, red.
3. SD19 unchanged (direct hang still bounded).
RISK: low. KILL (not TERM) on the group: the bound is the goal, memory.sh read-only calls hold no lock state worth a graceful stop. Linux/macOS perl both have setpgrp/fork/kill negative pid.

## r2 (correctness FATAL(3), robustness CONCERNS(3), simplicity CONCERNS(1); all folded) — r2 WINS over r1
- DIAGNOSIS corrected: timeout(1) (GNU and uutils) by default runs the command in a new process group and signals the whole group (only `--foreground` leaves children untimed); the perl fallback signals one process. Fix = parity with timeout/gtimeout, whose paths stay unchanged. Hook-time victim on the perl path = :263 only (the digest :320/:425 runs on the perl path only from a manual tty run, :21/:35).
- Runner (keeps the DOUBLE-quoted program with `\$` escapes, the form 1f107c3 shipped shellcheck-clean; single quotes = SC2016). perl moves ITSELF into a new group before forking, so the child is born in it (no race, one setpgrp), and the alarm lives in perl, outside the hook's foreground group (Ctrl-C or a harness group kill of the hook does not reach it; the alarm still fires and bounds the group):
  ```
  _SS_TMO=(perl -e "
    my \$t = shift; \$SIG{CHLD} = 'DEFAULT'; setpgrp(0, 0);
    my \$pid = fork; defined \$pid or exit 125;
    if (!\$pid) { alarm(\$t + 1); exec { \$ARGV[0] } @ARGV; exit 127 }
    \$SIG{ALRM} = sub { kill 'KILL', -\$\$ };
    alarm \$t; my \$w = waitpid(\$pid, 0); my \$st = \$?; alarm 0;
    \$SIG{TERM} = 'IGNORE'; kill 'TERM', -\$\$;
    exit(\$w < 0 ? 125 : (\$st & 127) ? 128 + (\$st & 127) : \$st >> 8)" 2)
  ```
  - timeout: KILL to the whole group incl. perl → rc 137 (callers test non-zero only: :263 discards, :320 `|| {…}`, :425 `|| true`).
  - normal end: stragglers still in the group (a background job left after the command exited) get TERM, perl ignores it; memory.sh and memory-feedback-remind.sh start no background job (read, both challengers), so TERM suffices.
  - child backstop `alarm(\$t + 1)` survives exec: if perl itself is SIGKILLed, the direct child still ends.
  - `-\$\$` never 0: a failed setpgrp leaves `-\$\$` naming no group (ESRCH, harmless); fork failure exit 125 before any kill; waitpid -1 (SIGCHLD ignored upstream, reset to DEFAULT anyway) → 125.
- Comment :39-40: "timeout, else gtimeout, else perl: each runs the command in its own process group and kills the group at the deadline, so a child holding the pipe dies too. Trade-off (as timeout without --foreground): in a terminal run the command is a background job of the tty (no stdin read; under `stty tostop` a tty write stops it until the deadline)."
- Tests (lib/tests/session-digest.test.sh, `</dev/null` kept, timing only, no digest-line assertion): SD19 stub becomes `( sleep 8 ) & exec sleep 8` (direct hang + a child holding stderr at :263); new SD19b stub `( sleep 8 ) & exit 0` (straggler after the command exits). Both assert `SECONDS < 6` and stay under the no-timeout PATH. Flip: the old runner → ≥ 8 s on both.
- Residue (TODO line, not this fix): lib/design-tool-gate.sh:70 `perl -e 'alarm shift; exec @ARGV' 15 21st whoami` has the same single-process limit.

## r3 (confirmation CONCERNS(1), folded; FINAL)
- Tests prove the command RAN, not only the bound: both stubs print `echo "memory: v1: x" >&2` before hanging/straggling; SD19/SD19b capture the hook output (not `>/dev/null`) and assert it holds `registry v1: 1 file(s)` (measured: r2 runner gives v1=1 for both) plus `SECONDS < 6`. A fast-failing runner (missed `\$` escape, exec failure) goes red.
- Comment :39-40 names the asymmetry: timeout/gtimeout kill the group at the deadline; the perl runner also TERMs leftovers after a normal exit (timeout does not; a leftover that ignores TERM is unbounded, none of the three callers starts one).
