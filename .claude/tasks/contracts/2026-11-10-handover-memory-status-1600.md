# CONTRACT — handover-memory-status
- date: 2026-11-10 | flow: bugfix | branch: bugfix/handover-memory-status
- status: active

## REQUEST (verbatim — IMMUTABLE)
G5 from .claude/audits/BUGS-FOUND.md (code-clean 2026-11-09): agents/handover-doc-writer.md:77-84 parses memory registry statuses by hand ("open vs resolved"), the class behind the BLK-032..034 false-open (BDR-129). A fix must read `bash ~/.claude/lib/memory.sh -C <project> index` on v2 registries and keep the `## Index` read on v1 registries never upgraded (`memory.sh index` ignores a v1 Index; lib/memory.sh:21-23). Severity medium (client deliverable). Regression test if the repo has a harness for agent prompts or memory.sh index on v1/v2 fixtures. Mark BUGS-FOUND G5 FIXED. make test needs GATES_TIMEOUT=600 + PATH=$HOME/.bun/bin:$PATH (LRN-271). Foreign-code style. Lessons in force: LRN-274 (pipefail), LRN-275 (never silence git add, check commit stat).

## CLARIFICATIONS
Q: which blockers are "open" for §5? / A: status not closed (closed = resolved | superseded | deprecated): open and upstream both listed (user, 2026-11-10) [gated]
Q: a blocker whose status cannot be read? / A: kept out of §5, flagged in the SYNTH REPORT, relayed to the user by the orchestrator (user, 2026-11-10) [gated]
Q: "cannot be read" = ? / A: no reader maps the status to exactly one known word of $_MEM_WORDS (empty, prose, mixed, `closed`, `###` entry); reading of the gated decision (orchestrator, from both r2 challenge lenses)
Q: the request's "keep the `## Index` read on v1"? / A: dropped after challenge round 1 (BLOCKER: the Index drifts, BDR-129/LRN-055); v1 uses the legacy lexical reader, never the Index (orchestrator)
Q: plan revisions? / A: plan r3 after two challenge rounds: .claude/tasks/plans/2026-11-10-handover-memory-status-1600.md is the binding FIX PLAN (orchestrator)

## ACCEPTANCE CRITERIA
1. Symptom gone: STEP 9 reads blocker statuses through `reconcile_blk_classify` rooted on the PACKAGE root, never by hand; the shipped snippet run on v1/v2 fixtures lists open/upstream blockers, omits closed ones (an Index row saying open does not reopen a resolved body), and puts unreadable ones (empty, `closed`, mixed, negated-only, `###` heading) in the unreadable bucket; regression suite present and green.
   CHECK: cd /home/bchanot/Documents/claude && GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/handover-memory-contract.test.sh 2>&1 | tail -1 | grep -q 'all suites green' && grep -q 'HM3' lib/tests/handover-memory-contract.test.sh && grep -q '^reconcile_blk_classify()' lib/reconcile.sh && ! grep -q 'parse manually' agents/handover-doc-writer.md && echo SYMPTOM-GONE
   EXPECT: SYMPTOM-GONE
   EVIDENCE: MET exit=0 marker-found :: SYMPTOM-GONE
2. Report contract: the SYNTH REPORT is a fenced template with a mandatory `MEMORY:` line; the orchestrator treats a missing MEMORY line, or `no blockers file` / `reader unavailable` while blockers.md exists, as malformed, prints any other non-`none` value and carries it into the 9.7 report.
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'MEMORY: unreadable BLK:' agents/handover-doc-writer.md && grep -q 'reader-unavailable' agents/handover-doc-writer.md && grep -q 'MEMORY:' agents/client-handover-writer.md && grep -q -- '- Memory:' agents/client-handover-writer.md && ! grep -q 'bash -c' agents/handover-doc-writer.md && echo REPORT-OK
   EXPECT: REPORT-OK
   EVIDENCE: MET exit=0 marker-found :: REPORT-OK
3. Build/tests green (full suite, GATES_TIMEOUT=600, bun on PATH); shellcheck at warning level clean on the touched shell files.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -S warning lib/reconcile.sh lib/tests/handover-memory-contract.test.sh && GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test 2>&1 | tail -1 | grep -q 'all suites green' && echo GREEN
   EXPECT: GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN

## FILE SCOPE
lib/reconcile.sh (new function + Layers line only), agents/handover-doc-writer.md (STEP 9, §5 source line, SYNTH REPORT template), agents/client-handover-writer.md (SYNTH REPORT parse, 9.7 report bullet), lib/tests/handover-memory-contract.test.sh (new); bookkeeping (orchestrator): .claude/audits/BUGS-FOUND.md
