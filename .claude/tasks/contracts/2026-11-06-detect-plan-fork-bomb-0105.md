# CONTRACT — detect-plan-fork-bomb
- date: 2026-11-06 | flow: bugfix | branch: hotfix/detect-plan-fork-bomb (worktree /home/bchanot/Documents/claude-hotfix-wt, off main 4093cca)
- status: active

## REQUEST (verbatim — IMMUTABLE)
oui lance le bugfix maintenat pour regler cette escalade et met dnas blockers

(context, the bug as received: `make test suite=lib/tests/session-digest.test.sh` filled the RAM, OOM, machine reboot 2026-11-05 23:55; root cause `lib/detect-plugins.sh` `detect_plan` falls back to `claude config get planType`, which starts a full session whose SessionStart hook calls `detect_plan` again: recursive fork bomb. Plan: `.claude/tasks/plans/2026-11-06-detect-plan-fork-bomb-0030.md` r2.)

## CLARIFICATIONS
Q: landing branch? / A: hotfix/* off main, in a separate git worktree; finish merges main + develop; the session-digest stub (Part B) goes to feature/memory-recall after. [gated 2026-11-06]
Q: safety order / A: NEVER run `hooks/session-start.sh`, `make test` (any form) or any suite that runs the hook, in either tree, before fix 1 is on disk in the worktree. The red proof runs `detect_plan` directly (no hook) with the `claude` stub on PATH. Every suite run goes through `systemd-run --user --scope -q -p TasksMax=256`. Never run the real `claude` CLI. [gated 2026-11-06]
Q: BLK entry / A: BLK-043 (fork bomb, open → resolved at commit) and BLK-044 (oom_score_adj -1000, open) written 2026-11-06. [gated 2026-11-06]

## ACCEPTANCE CRITERIA
1. `detect_plan` in the worktree calls no `claude` CLI; the vulnerable call exists on main (positive control).
   CHECK: cd /home/bchanot/Documents/claude-hotfix-wt && git show main:lib/detect-plugins.sh | grep -q 'claude config get planType' && ! grep -nE '(^|[^A-Za-z_./-])claude[[:space:]]+[a-z-]' lib/detect-plugins.sh && echo C1_NO_CLI
   EXPECT: C1_NO_CLI
   EVIDENCE: MET exit=0 marker-found :: C1_NO_CLI
2. Regression suite `lib/tests/detect-plan.test.sh` exists and passes on the fixed tree, contained.
   CHECK: cd /home/bchanot/Documents/claude-hotfix-wt && test -f lib/tests/detect-plan.test.sh && systemd-run --user --scope -q -p TasksMax=256 bash lib/tests/detect-plan.test.sh && echo C2_GREEN
   EXPECT: C2_GREEN
   EVIDENCE: MET exit=0 marker-found :: detect-plan: 9 passed, 0 failed C2_GREEN
3. Symptom reproduced: the same suite FAILS when pointed at main's `lib/detect-plugins.sh` (the suite takes the lib path from `DETECT_PLUGINS_LIB`, default the repo copy), and the stub, not a real `claude`, caught the call.
   CHECK: cd /home/bchanot/Documents/claude-hotfix-wt && git show main:lib/detect-plugins.sh > /home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/fb6518b7-0114-4bfb-9d49-04965b322457/scratchpad/main-detect-plugins.sh && if DETECT_PLUGINS_LIB=/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/fb6518b7-0114-4bfb-9d49-04965b322457/scratchpad/main-detect-plugins.sh systemd-run --user --scope -q -p TasksMax=256 bash lib/tests/detect-plan.test.sh >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/fb6518b7-0114-4bfb-9d49-04965b322457/scratchpad/c3.out 2>&1; then false; else grep -q 'FAIL T1-no-json-calls' /home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/fb6518b7-0114-4bfb-9d49-04965b322457/scratchpad/c3.out && echo C3_RED_BEFORE; fi
   (amended 2026-11-06 by the orchestrator before GATE 0: same check, literal scratchpad paths instead of `rm -rf "$t"`; fail line pinned to the regression case)
   EXPECT: C3_RED_BEFORE
   EVIDENCE: MET exit=0 marker-found :: C3_RED_BEFORE
4. The suite proves its stub is reached (positive control: a `claude` call through PATH logs exactly 1 line before the absence checks), calls `detect_plan` directly with a HOME holding no `.claude.json` and asserts output `pro` with 0 new logged calls.
   (judged by the verifier from the suite source)
5. Recursion guard: `hooks/session-start.sh` exits 0 with no output when `SESSION_START_RUNNING` is set, and otherwise exports `SESSION_START_RUNNING=1` before any child process. The suite asserts both: an early-exit case, and a child of the hook (a PATH stub `git`) that records `1`. The hook comment states the guard is defense-in-depth with no live caller and relies on Claude Code passing env to hooks.
   CHECK: cd /home/bchanot/Documents/claude-hotfix-wt && grep -q 'SESSION_START_RUNNING' hooks/session-start.sh && grep -q 'SESSION_START_RUNNING' lib/tests/detect-plan.test.sh && echo C5_GUARD_PRESENT
   EXPECT: C5_GUARD_PRESENT
   EVIDENCE: MET exit=0 marker-found :: C5_GUARD_PRESENT
6. Dead code removed: `detect_plan` docstring says it returns max or pro (no free); the `free)` arm of the plan `case` in `hooks/session-start.sh` is gone.
   CHECK: cd /home/bchanot/Documents/claude-hotfix-wt && ! grep -nE '^[[:space:]]*free\)' hooks/session-start.sh && ! grep -niE 'max, pro, or free' lib/detect-plugins.sh && echo C6_NO_DEAD
   EXPECT: C6_NO_DEAD
   EVIDENCE: MET exit=0 marker-found :: C6_NO_DEAD
7. shellcheck clean on the three files.
   CHECK: cd /home/bchanot/Documents/claude-hotfix-wt && shellcheck lib/detect-plugins.sh hooks/session-start.sh lib/tests/detect-plan.test.sh && echo C7_LINT
   EXPECT: C7_LINT
   EVIDENCE: MET exit=0 marker-found :: C7_LINT
8. Full suite green once, contained (LRN-209: one full run before finish).
   CHECK: cd /home/bchanot/Documents/claude-hotfix-wt && systemd-run --user --scope -q -p TasksMax=512 make test >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/fb6518b7-0114-4bfb-9d49-04965b322457/scratchpad/hotfix-maketest.log 2>&1; rc=$?; tail -5 /home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/fb6518b7-0114-4bfb-9d49-04965b322457/scratchpad/hotfix-maketest.log; [ "$rc" -eq 0 ] && echo C8_SUITE_GREEN
   EXPECT: C8_SUITE_GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN ✓ G3 strict-YAML: all agents/*.md frontmatter parse GREEN ✓ G4 hermetic: run-reconcile.sh reads fixtures only, not the live registry G…

## FILE SCOPE
In /home/bchanot/Documents/claude-hotfix-wt only:
- lib/detect-plugins.sh (detect_plan)
- hooks/session-start.sh (guard at top; `free)` arm)
- lib/tests/detect-plan.test.sh (new)
Nothing in /home/bchanot/Documents/claude (the feature/memory-recall tree and its uncommitted work).
