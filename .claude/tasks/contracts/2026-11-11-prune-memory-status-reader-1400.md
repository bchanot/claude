# CONTRACT — prune-memory-status-reader
- date: 2026-11-11 | flow: feat | branch: feature/prune-memory-status-reader
- status: active

## REQUEST (verbatim — IMMUTABLE)
D4 from .claude/tasks/TODO.md § Release 3.0.0 scope (user decision 2026-11-11 [gated]: "D4 /prune-memory reads statuses through memory.sh (v1+v2), example IDs 9xx"). Evidence: .claude/tasks/plans/2026-11-09-bdr125-obsolescence-clean-1650.md D4: skills/prune-memory/SKILL.md STEP 1.A/3 detection rules (:33-34,81-82,87-89,157-159,252,260-261) still describe per-entry frontmatter and raw `status:` lines; reading statuses through the shared reader (`memory.sh index`, lib/reconcile.sh reconcile_blk_current_status / memory_entry_status / memory_legacy_status per BDR-129) works on v1 and v2; example IDs must stay 9xx (run-deterministic.sh RED-7). Line numbers may have moved: re-locate. Regression test in the existing prune-memory / skill census harness if one fits. make test needs GATES_TIMEOUT=600 + PATH=$HOME/.bun/bin:$PATH (LRN-271). Foreign-code style. In force: BDR-129 (strict v2, legacy v1, never the Index), BDR-133, BDR-142 n/a, LRN-276 (test the shipped snippet), LRN-277 (executor briefs forbid stdin readers), LRN-275.

## CLARIFICATIONS
Q: plan? / A: .claude/tasks/plans/2026-11-11-prune-memory-status-reader-1400.md r3 is binding (orchestrator, after two challenge rounds)
Q: decision reader, given `memory.sh index decision` reads no status on game 107/107, config 19/19, faunosteo 76/80? / A: one classifier for decisions and blockers: generalize reconcile_blk_classify to a prefix (strict v2, one-word v1) (user, 2026-11-11) [gated]
Q: unreadable statuses in the plan? / A: one count line per registry, info only, outside "all", never written by the skill, word from the user per ID; dialect migration logged as a follow-up (user, 2026-11-11) [gated]
Q: STEP 4 status drift check (round 2)? / A: dropped from D4, logged as follow-up (orchestrator, simplicity finding: ungated new gate)

## ACCEPTANCE CRITERIA
1. The prune-memory deterministic suite runs RED-9 and is all green.
   CHECK: cd /home/bchanot/Documents/claude && out=$(bash skills/prune-memory/tests/run-deterministic.sh 2>&1); printf '%s\n' "$out" | grep -q '^RED-9: GREEN' && printf '%s\n' "$out" | grep -q 'SUITE: all GREEN' && echo PRUNE-OK
   EXPECT: PRUNE-OK
   EVIDENCE: MET exit=0 marker-found :: PRUNE-OK
2. SKILL.md reads statuses through the classifier and keeps no raw status or frontmatter wording.
   CHECK: cd /home/bchanot/Documents/claude && S=skills/prune-memory/SKILL.md && grep -q 'reconcile_status_classify' $S && grep -q 'Status unreadable' $S && [ "$(/usr/bin/grep -c 'status: ' $S)" = 0 ] && [ "$(/usr/bin/grep -c 'frontmatter' $S)" = 0 ] && echo SKILL-OK
   EXPECT: SKILL-OK
   EVIDENCE: MET exit=0 marker-found :: SKILL-OK
3. The classifier is generic and the BLK wrapper stays.
   CHECK: cd /home/bchanot/Documents/claude && grep -q '^reconcile_status_classify()' lib/reconcile.sh && grep -q 'reconcile_status_classify "$1" BLK' lib/reconcile.sh && grep -q 'MEM_LEGACY_RE:-' lib/memory.sh && echo LIB-OK
   EXPECT: LIB-OK
   EVIDENCE: MET exit=0 marker-found :: LIB-OK
4. Full suite green and shellcheck clean on the touched scripts.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -S warning lib/reconcile.sh lib/memory.sh skills/prune-memory/tests/run-deterministic.sh && GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test 2>&1 | tail -1 | grep -q 'all suites green' && echo GREEN
   EXPECT: GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN

## FILE SCOPE
lib/memory.sh (memory_legacy_status `<end>` branch selector only), lib/reconcile.sh, skills/prune-memory/SKILL.md, skills/prune-memory/tests/run-deterministic.sh
