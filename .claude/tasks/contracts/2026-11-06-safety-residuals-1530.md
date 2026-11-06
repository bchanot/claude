# CONTRACT — safety-residuals
- date: 2026-11-06 | flow: bugfix | branch: bugfix/safety-residuals (off develop ddb04f4)
- status: active
- plan: .claude/tasks/plans/2026-11-06-safety-residuals-1530.md (r3)

## REQUEST (verbatim — IMMUTABLE)
dans ce cas merge it.  puis on fait le bugfix pours 1 2 3 4 5 et on verra ensuite pour la 4d

(context: the 5 items of the /reconcile 2026-11-06 report: 1 suites that can reach the real claude CLI; 2 `rtk read -n .env` passes every deny; 3 session-start `memory.sh check` unbounded; 4 memory.sh awk reads an assignment-shaped path as an assignment; 5 pre-commit `.claude/**` exemption too wide.)

## CLARIFICATIONS
Q: item 5 allowlist? / A: .claude/memory, .claude/tasks, .claude/audits, .claude/deploy (+ .githooks); .claude/settings.json NOT exempt. [gated 2026-11-06]
Q: shape? / A: one bugfix branch, one commit per item, order 4, 3, 1, 2, 5; final gates over the range. [gated 2026-11-06]
Q: safety / A: every hook-running suite, lib/gitflow-test.sh and the bench run under `systemd-run --user --scope -q -p TasksMax=256`; the real claude CLI runs only inside the bench's run.sh (--setting-sources local); bench run from a cwd with no .env; settings.json written via jq to tmp, `jq empty`, mv. [gated 2026-11-06]
Q: criterion 8 scope (GATE 1 ECARTS 2026-11-06) / A: orchestrator ruling: "shellcheck clean" means no NEW finding vs develop (ddb04f4) on every touched shell file; the 4 findings already on develop's memory.test.sh (SC2016 x3, SC1090) are out of scope. No new `# shellcheck disable` anywhere in the range. [gated 2026-11-06]
Q: item 2 gate / A: deny lines added ONLY if R3, R4, R6, R7 DENIED and R5 RAN, each `sent` = its cmd, every control RAN; otherwise item 2 stops, nothing added, reported. [gated 2026-11-06]

## ACCEPTANCE CRITERIA
1. Item 4: assignment-shaped body file and check dir are read as files; existing output unchanged; memory suite green.
   CHECK: cd /home/bchanot/Documents/claude && grep -q '_mem_path_safe' lib/memory.sh && systemd-run --user --scope -q -p TasksMax=256 env PATH="$HOME/.bun/bin:$PATH" bash lib/tests/memory.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/c1.out 2>&1 && echo C1_GREEN
   EXPECT: C1_GREEN
   EVIDENCE: MET exit=0 marker-found :: C1_GREEN
   (amended 2026-11-06 by the orchestrator: bun prepended to PATH, T18 needs it and the Bash tool PATH lacks ~/.bun/bin)
2. Item 3: the session-start `memory.sh check` call is time-bounded; session-digest suite (with its new hang case) green.
   CHECK: cd /home/bchanot/Documents/claude && systemd-run --user --scope -q -p TasksMax=256 bash lib/tests/session-digest.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/c2.out 2>&1 && echo C2_GREEN
   EXPECT: C2_GREEN
   EVIDENCE: MET exit=0 marker-found :: C2_GREEN
3. Item 1: shared helper fails closed; its own suite and every adopting suite green.
   CHECK: cd /home/bchanot/Documents/claude && test -f lib/tests/claude-stub.sh && for t in claude-stub detect-plan graphify-gate push-guard cc; do systemd-run --user --scope -q -p TasksMax=256 bash lib/tests/$t.test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/c3-$t.out 2>&1 || exit 1; done && echo C3_GREEN
   EXPECT: C3_GREEN
   EVIDENCE: MET exit=0 marker-found :: C3_GREEN
4. Item 1: every hook-running suite sources the helper and ends with a zero-call check; no inline `claude probe` left outside the helper.
   CHECK: cd /home/bchanot/Documents/claude && for t in detect-plan session-digest graphify-gate memory push-guard; do grep -q 'claude-stub.sh' lib/tests/$t.test.sh || exit 1; done && ! grep -l '^claude probe' lib/tests/*.test.sh | grep -q . && echo C4_WIRED
   EXPECT: C4_WIRED
   EVIDENCE: MET exit=0 marker-found :: C4_WIRED
5. Item 2: bench evidence recorded in results.tsv for R3-R7 and, only if every row met its want, the 2 deny rules are present and settings.json is valid JSON.
   (judged by the verifier from results.tsv and settings.json; push-guard T63 pins both rules when added)
6. Item 5: allowlist hook; rules, settings.json and a rules→tasks rename blocked on develop; memory, tasks, deploy, audits allowed; both hook copies equal the emitter.
   CHECK: cd /home/bchanot/Documents/claude && grep -q -- '--no-renames' lib/gitflow.sh && cmp -s githooks/pre-commit .githooks/pre-commit && systemd-run --user --scope -q -p TasksMax=256 bash lib/gitflow-test.sh </dev/null >/home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/c6.out 2>&1 && echo C6_GREEN
   EXPECT: C6_GREEN
   EVIDENCE: MET exit=0 marker-found :: C6_GREEN
7. Item 5 citers: no doctrine line still says `.claude/**` is exempt.
   CHECK: cd /home/bchanot/Documents/claude && ! grep -n '\.claude/\*\*' CLAUDE.global.md lib/gitflow-aiguillage.md settings.json | grep -i 'exempt' && echo C7_CITERS
   EXPECT: C7_CITERS
   EVIDENCE: MET exit=0 marker-found :: C7_CITERS
8. shellcheck clean on every touched shell file.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck lib/memory.sh hooks/session-start.sh lib/gitflow.sh lib/tests/claude-stub.sh lib/tests/claude-stub.test.sh lib/tests/detect-plan.test.sh lib/tests/session-digest.test.sh lib/tests/cc.test.sh .claude/tasks/plans/2026-11-02-phase2-bench/bench.sh .claude/tasks/plans/2026-11-02-phase2-bench/run.sh && echo C8_LINT
   EXPECT: C8_LINT
   EVIDENCE: MET exit=0 marker-found :: C8_LINT
9. Each regression test is red against develop's code and green after (memory x=1.md, session-start hang, helper fail-closed, hook rename/rules cases).
   (judged by the verifier from the executor reports: each item report names its red-before evidence)

## FILE SCOPE
- lib/memory.sh, lib/tests/memory.test.sh
- hooks/session-start.sh, lib/tests/session-digest.test.sh
- lib/tests/claude-stub.sh (new), lib/tests/claude-stub.test.sh (new), lib/tests/{detect-plan,graphify-gate,push-guard,cc}.test.sh
- .claude/tasks/plans/2026-11-02-phase2-bench/{bench.sh,run.sh,README.md,cases.tsv,results.tsv}, settings.json
- lib/gitflow.sh, lib/gitflow-test.sh, githooks/pre-commit, .githooks/pre-commit, CLAUDE.global.md, lib/gitflow-aiguillage.md

## EXECUTION LOG (orchestrator, from executor reports + own reruns)
- Item 4 9b3961e — red on HEAD lib: `FAIL T19-assign-body-heading-rc`, `FAIL T19b-assign-body-written`, `FAIL T19c-assign-dir-read`; after: memory PASS=268 FAIL=0 (bun on PATH).
- Item 3 d93f06c — red with develop's hook: `FAIL SD16-hang-bounded: got[no] want[yes]`; after: session-digest 55/0.
- Item 1 dc5f127 — red with a helper copy lacking `stub_first_or_die claude`: `FAIL Ta-message`, `FAIL Ta-sentinel-absent` (fake claude reached); after: claude-stub 5/0, detect-plan 8/0, session-digest 54/0, graphify-gate 18/0, memory 269/0, push-guard 130/0, cc 30/0.
- Item 2 97c6afc — bench results.tsv: R3 DENIED, R4 DENIED, R5 RAN, R6 DENIED, R7 DENIED, every -ctl RAN, every `sent` = cmd, mode auto; red: push-guard T63 FAIL before the settings edit, 130/0 after; settings.json valid JSON, diff = 2 added deny lines.
- Item 5 c5bd0f8 — red on the old emitter: T21d, T21e, T21f, T21h FAIL (196/4); after: gitflow-test 200/0, review-guards 5/0 (G5 drift green). Deviation: `githooks/` regenerated through `_gitflow_write_hook` (the writer `global-hooks` calls) instead of `global-hooks`, which may run `git config --global core.hooksPath`; `cmp githooks/pre-commit .githooks/pre-commit` holds.
