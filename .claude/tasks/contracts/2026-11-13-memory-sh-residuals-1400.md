# CONTRACT — memory-sh-residuals (phase 4a leftovers + BUGS-FOUND memory.sh items, block H2)
- date: 2026-11-13 | flow: bugfix | branch: bugfix/memory-sh-residuals (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
BLK-038 residuals (gates 2026-10-30, non-blocking): v1 line echoed on stderr unfiltered (CWE-150 LOW, terminal control chars from a foreign registry; same as existing "upgrade lost" path); no fixture asserts the "wrote upgrade status" / "dated status line kept" messages; the real-data replay oracle lives in the session scratchpad (`up4a/realdata.sh`), not re-runnable: port to a `make` target over fixture copies if the upgrade is touched again; `memory.sh journal` leaves two blank lines before a new date heading on files ending with a blank line (commit-changer note). BUGS-FOUND: lib/memory.sh `upgrade` (`mem_want`, `_mem_verdict_diff` skips Index-stated IDs) may take a stale v1 `## Index` cell over a `**Statut** :` body line (UNVERIFIED). lib/memory.sh `memory_legacy_status` default range (`## ID` to the next `## BLK-`): a `### BLK-` entry after a `## BLK-` entry feeds its status line to the `##` entry. lib/memory.sh:657 `memory_legacy_status` reads `MEM_LEGACY_RE` from the environment: an ambient export widens upgrade's readers; fix: explicit positional argument, drop the env read. `memory_legacy_status` `<end>` range on v1 decisions: the last BDR entry runs to EOF, so a `## Index` after it would be read.

## CLARIFICATIONS
- [gated 2026-11-13, oracle fixes after the executor report] CHECK 1 no longer counts the live `MEM_GREP` use at reconcile.sh:139 (heading ids) nor the substring `MEM_LEGACY_RE` (the executor renamed `_MEM_LEGACY_RE` → `_MEM_LEGACY_BLK_RE` and used `${!re}` indirection to satisfy the old counts: the rename stays, the indirection is replaced by an explicit `case` in round 2). CHECK 6 runs through `make test suite=` (a direct run trips the global gitflow hooks on the fixture's `main`). CHECK 7 excludes the test file's 4 pre-existing findings.
- [gated 2026-11-13, challenge r2] the body label beats the Index by WRITING the v1 word as the dated upgrade line (a `**Statut** :` line is unreadable by the strict reader, so "keeping the body" would reopen the entry); one effective status feeds flush, Index-stated and the oracle; a mixed v1 label falls to the existing name-and-refuse path. `<end>` derived from the ID prefix; label selector = 3rd positional. The lexical range stops at `## Index` only (not every `##`). The real-data replay oracle is replaced by the fixture cases (the scratchpad script is gone). Plan: .claude/tasks/plans/2026-11-13-memory-sh-residuals-1400.md § r2.

## ACCEPTANCE CRITERIA
1. No env read of MEM_LEGACY_RE; the BDR selector lives in memory.sh; reconcile has no MEM_GREP prefix on the legacy calls.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'MEM_LEGACY_RE:-\|\${!re' lib/memory.sh)$(grep -c '_MEM_LEGACY_BDR_RE' lib/memory.sh | grep -c '^[1-9]')$(grep -B1 'memory_legacy_status' lib/reconcile.sh | grep -c MEM_GREP)
   EXPECT: 010
   EVIDENCE: MET exit=0 marker-found :: 010
2. One lexical range reader (no sed path) stopping at `## Index`.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'sed -n "/^## ${2} /' lib/memory.sh)$(grep -c '"## Index"' lib/memory.sh | grep -c '^[3-9]')
   EXPECT: 01
   EVIDENCE: MET exit=0 marker-found :: 01
3. Effective status helper present and consumed by the three sites.
   CHECK: cd /home/bchanot/Documents/claude && grep -c '_mem_v1_words' lib/memory.sh | grep -c '^[4-9]'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
4. memory.test.sh green with the r2 (f) cases.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH bash lib/tests/memory.test.sh 2>&1 | tail -1
   EXPECT: FAIL=0
   EVIDENCE: MET exit=0 marker-found :: PASS=298 FAIL=0
5. New cases exist (Statut fixtures, journal endings, control chars, trailing Index).
   CHECK: cd /home/bchanot/Documents/claude && grep -c 'Statut\|dropped Index\|tail -c1\|x1b\|trailing' lib/tests/memory.test.sh | grep -c '^[6-9]\|^[1-9][0-9]'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
6. Reconcile suites green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/run-reconcile.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
7. shellcheck -x clean on lib/memory.sh lib/reconcile.sh; the test file keeps its 4 pre-existing findings (SC2016 x3, SC1090; same count at HEAD), none new.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -x lib/memory.sh lib/reconcile.sh && [ "$(shellcheck -x lib/tests/memory.test.sh 2>&1 | grep -c '^In ')" = 4 ] && echo SC-OK
   EXPECT: SC-OK
   EVIDENCE: MET exit=0 marker-found :: SC-OK
8. make test green (manual, bun on PATH); new functions ≤ 25 logic lines / 5 locals; changed lib lines ≤ 80 cols.
   (manual: run 2026-11-13 on the round-2 tree, `PATH=$HOME/.bun/bin:$PATH make test` → "SUITE: all GREEN / all suites green", rc=0)

## FILE SCOPE
lib/memory.sh, lib/reconcile.sh, lib/tests/memory.test.sh (+ fixtures under lib/tests/fixtures/ if the suite uses files). CHANGELOG + MIGRATION.md:209 note → STEP 7 doc sync. TODO/BUGS-FOUND lines → STEP 8.
