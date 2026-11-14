# CONTRACT — mods-test-tty-hang
- date: 2026-11-14 | flow: hotfix | branch: bugfix/mods-test-tty-hang (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
lib/tests/mods.test.sh hangs forever when `make test` runs from an interactive terminal (user report 2026-11-14, stuck after "model-routing census: 141 pass" at "== lib/tests/mods.test.sh"; ps: `timeout 120 claude plugin validate --strict /tmp/…/cleanfix` and the claude child both in state T for 4h30). Root cause: timeout(1) without --foreground puts the command in its own (background) process group; the claude CLI inherits the tty on stdin and touches it, SIGTTOU stops the whole group including timeout, whose alarm then never fires. Non-tty runs (Claude sessions) are unaffected. Fix: `bounded()` (lib/tests/mods.test.sh:20-33) runs the command with stdin from /dev/null in both branches (timeout line :23 and the background fallback :26). 1 file.

## CLARIFICATIONS
- [gated 2026-11-14] challenge skipped (stdin redirect, no control-flow change). Proof = pty reproduction with util-linux `script` before/after.

## ACCEPTANCE CRITERIA
1. Both branches of bounded() read stdin from /dev/null.
   CHECK: cd /home/bchanot/Documents/claude && sed -n '/^bounded()/,/^}/p' lib/tests/mods.test.sh | grep -c '</dev/null'
   EXPECT: 2
   EVIDENCE: MET exit=0 marker-found :: 2
2. shellcheck clean.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -x lib/tests/mods.test.sh && echo SC-OK
   EXPECT: SC-OK
   EVIDENCE: MET exit=0 marker-found :: SC-OK
3. Under a pty (`script`), the mods suite finishes (before the fix it stops in state T); make test green (manual).

## FILE SCOPE
lib/tests/mods.test.sh (bounded, :20-33).
