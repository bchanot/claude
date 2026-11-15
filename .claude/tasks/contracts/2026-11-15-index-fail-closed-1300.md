# CONTRACT — index-fail-closed (BDR-125 gap audit A3, BUGS-FOUND:87)
- date: 2026-11-15 | flow: bugfix | branch: bugfix/index-fail-closed (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
A3 (BDR-125 gap audit): memory_index on an unreadable or non-regular blockers.md (permission denied, a directory, a FIFO) must return non-zero so the session digest prints `- open: unknown (memory.sh index failed)` instead of `- open: none`. Today an unreadable blockers.md can yield `- open: none`, a false all-clear. Re-pin session-digest tests SD9b/SD9c to the new behavior.

## CLARIFICATIONS
- [internal 2026-11-15, challenge r1-r3] plan .claude/tasks/plans/2026-11-15-index-fail-closed-1200.md: r2 + r3 win over the original FIX PLAN. Strict (kind named) → rc 2; lax (no kind, used live by mods/memory register.ts) → skip bad registry with stderr line, rc 0. Existing unknown line reused verbatim. Empty/unknown status words stay not-open (v1 rows in game/config).

## ACCEPTANCE CRITERIA
1. session-digest suite green (SD9b/SD9c re-pinned to unknown, SD9f/g/h added).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/session-digest.test.sh </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
2. memory suite green (strict rc 2 on dir/FIFO, lax rc 0 with stderr, healthy rc 0 and byte-identical output).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/memory.test.sh </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
3. SD9b and SD9c assert the unknown line, not none.
   CHECK: cd /home/bchanot/Documents/claude && grep -cE 'check SD9[bc]-unknown' lib/tests/session-digest.test.sh
   EXPECT: 2
   EVIDENCE: MET exit=0 marker-found :: 2
4. Full make test green; shellcheck clean on touched shell files; plan r3 items all implemented; regression tests fail on the pre-fix lib (manual).

## FILE SCOPE
lib/memory.sh (memory_index, usage line :12), hooks/session-start.sh (_digest_blockers), lib/tests/session-digest.test.sh, lib/tests/memory.test.sh, agents/handover-doc-writer.md (:120 one sentence).
