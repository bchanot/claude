# CONTRACT — session-digest-claude-stub
- date: 2026-11-06 | flow: hotfix | branch: feature/memory-recall
- status: active

## REQUEST (verbatim — IMMUTABLE)
BLK-043 Part B on feature/memory-recall: in lib/tests/session-digest.test.sh add a suite-wide PATH stub for `claude` (log path expanded at creation, chmod +x, positive control first: call `claude` via PATH, assert 1 logged line), then a final cumulative check that the stub log has no line from any hook run of the suite. Plan: .claude/tasks/plans/2026-11-06-detect-plan-fork-bomb-0030.md r2 (R2, R5, R6: first run under `systemd-run --user --scope -q -p TasksMax=256`). Single test file.

## CLARIFICATIONS
Q: safety / A: every run of the suite goes through `systemd-run --user --scope -q -p TasksMax=256`; never run the real `claude` CLI. [gated 2026-11-06]

## ACCEPTANCE CRITERIA
1. Stub present, reached, and hook runs log no call; suite green, contained.
   CHECK: cd /home/bchanot/Documents/claude && systemd-run --user --scope -q -p TasksMax=256 bash lib/tests/session-digest.test.sh >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/sd.out 2>&1 && grep -q 'failed$' /home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/sd.out && echo C1_GREEN
   EXPECT: C1_GREEN
2. The stub is written with the log path expanded at creation, `chmod +x`, exported on PATH before the first case; a positive control (SD0) asserts 1 logged line; the log is then emptied; a final check (SD15) after all cases asserts 0 lines.
   (judged from the suite source)
3. shellcheck clean.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck lib/tests/session-digest.test.sh && echo C3_LINT
   EXPECT: C3_LINT

## FILE SCOPE
- lib/tests/session-digest.test.sh
