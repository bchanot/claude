# CONTRACT — feedback-followups (phase 4d follow-ups, block H5)
- date: 2026-11-13 | flow: bugfix | branch: bugfix/feedback-followups (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
metricsOf: split rows by the 2026-11-12 fix date and retire the 3rd-pick signal (pre-fix rows keep re-emitting the idle and cap actions; BDR-146 residual). 4d follow-ups (final review + task reviews 2026-11-08, non-blocking): transcript cache holds every parsed file per run (~1 GB at steady state: process per (root, session, agent) and drop); image prompts (array content) become `lost` (counted); no boundary tests for the threshold actions (3rd pick, late, tool, miss, noisy/promotion, idle tie-break), eviction note, torn count, toolItem; `replyAfter` hides `seen.add` in a filter; no `tsc` type check on lib/memory-feedback; kit test pinning the exact field set of a prompt log record (IR11 is toMatchObject since 4d.1, so a future text field would pass); labels.ts minors (fromLine checks column count only, readState accepts non-object JSON, .bak keeps one state, misleading error on an entry label with a cause).

## CLARIFICATIONS
- [gated 2026-11-13, challenge r1-r3; plan .claude/tasks/plans/2026-11-13-feedback-followups-1800.md § r2 + r3 FINAL] fix instant = merge d3d5e6c 2026-11-12T19:53:59Z; split scope and floor per r3; image prompts DROPPED (0 instances, measured); `tsc` not done (no compiler on the machine, a new dependency) and `l:<root>` shortcut kept (49.7 KB of 4 MiB measured): both closed in the TODO with those reasons; `.bak` one state accepted.

## ACCEPTANCE CRITERIA
1. thirdPick retired, fix instant constant present.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'thirdPick' lib/memory-feedback/metrics.ts lib/memory-feedback/thresholds.ts | grep -c ':0$')$(grep -c "GATE1_FIX_AT = Date.parse('2026-11-12T19:53:59Z')" lib/memory-feedback/thresholds.ts)
   EXPECT: 21
   EVIDENCE: PENDING
2. memory-feedback suite green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/memory-feedback.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: PENDING
3. New tests exist (post-fix floor, A,B,A torn read-once, every label kind, two IR11 key-set pins).
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'GATE1_FIX_AT' lib/memory-feedback/metrics.test.ts | grep -c '^[1-9]')$(grep -c 'Skipped 1 torn' lib/memory-feedback/reader.test.ts | grep -c '^[1-9]')$(grep -c 'Object.keys' mods/memory/hooks/register.test.ts | grep -c '^[2-9]')
   EXPECT: 111
   EVIDENCE: PENDING
4. Memory kit green, strict validation green.
   CHECK: cd /home/bchanot/Documents/claude && claude plugin validate --strict mods/memory >/dev/null 2>&1 && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/mods.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: PENDING
5. The live labels.tsv still reads (worksheet on a COPY of ~/.claude/memory-feedback under mktemp, never the real dir).
   (manual: executor runs the reader on a copy and quotes rc 0 + the head lines)
6. Peak RSS of the reader before/after on a copy of the real population (manual, quoted).
7. make test green (manual, bun on PATH); functions ≤ 25 logic lines / 5 params / 5 locals; lines ≤ 80.

## FILE SCOPE
lib/memory-feedback/{metrics,thresholds,transcripts,reader,labels}.ts and their .test.ts, mods/memory/hooks/register.test.ts. CHANGELOG/README → doc sync; TODO lines → STEP 8.
