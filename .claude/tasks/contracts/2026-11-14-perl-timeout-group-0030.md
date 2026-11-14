# CONTRACT — perl-timeout-group (phase 4b-4d residual, GATE 2 LOW 2026-11-13)
- date: 2026-11-14 | flow: bugfix | branch: bugfix/perl-timeout-group (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
session-start perl fallback (TODO phase 4b-4d line, GATE 2 LOW 2026-11-13, H4b): hooks/session-start.sh:45-46 `_SS_TMO=(perl -e "alarm shift; exec { \$ARGV[0] } @ARGV" 2)` used when neither timeout nor gtimeout exists (stock macOS). alarm kills only the exec'd bash; a background or hung child of memory.sh that inherited stdout keeps the command-substitution pipe open, so the digest call at :320 (and :263, :425) still blocks past 2 s. Upgrade: fork + setpgrp + kill the process group on alarm, exit 124 like timeout(1).

## CLARIFICATIONS
- [gated 2026-11-14, challenge r2/r3] perl setpgrp's ITSELF before fork, ALRM kills `-$$` (rc 137, not 124: callers test non-zero only); after a normal exit, TERM to leftovers (perl ignores TERM); child alarm backstop; double-quoted program with `\$` escapes (single quotes = SC2016). Tests timing + banner `registry v1: 1 file(s)`, `</dev/null` kept, no digest-line assertion (no digest without tty on the perl path). Plan: .claude/tasks/plans/2026-11-14-perl-timeout-group-0030.md § r2 + r3.

## ACCEPTANCE CRITERIA
1. Runner forks into its own group and kills the group.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'setpgrp(0, 0)' hooks/session-start.sh)$(grep -c "kill 'KILL', -" hooks/session-start.sh)$(grep -c 'alarm shift; exec' hooks/session-start.sh)
   EXPECT: 110
   EVIDENCE: MET exit=0 marker-found :: 110
2. session-digest suite green with SD19 (child holding the pipe) and SD19b (straggler).
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'SD19b' lib/tests/session-digest.test.sh | grep -c '^[2-9]')$(PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/session-digest.test.sh 2>&1 | tail -1)
   EXPECT: 1all suites green
   EVIDENCE: MET exit=0 marker-found :: 1all suites green
3. shellcheck -x clean on both files, no new directive.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -x hooks/session-start.sh lib/tests/session-digest.test.sh && echo SC-OK
   EXPECT: SC-OK
   EVIDENCE: MET exit=0 marker-found :: SC-OK
4. Flip: with the old runner line restored on a copy, SD19 and SD19b go red (≥ 8 s); make test green (manual, bun on PATH).

## FILE SCOPE
hooks/session-start.sh (:39-47), lib/tests/session-digest.test.sh (SD19 area). TODO line + design-tool-gate.sh residue → STEP 8.
