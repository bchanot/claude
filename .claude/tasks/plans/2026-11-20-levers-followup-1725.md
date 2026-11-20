# PLAN r4 — levers-followup (/feat, 2026-11-20 17:25)

Contract: `.claude/tasks/contracts/2026-11-20-levers-followup-1725.md`. Base: develop 23c5802.
Branch: feature/levers-followup. Source decisions: user answers of 2026-11-20 in the
done-triage-levers run (pass B scope (a)+(b), GATE 2 REPORTED (1)+(2)), BDR-151.

## Mechanism (exact text: § EXACT DIFF)
- [ ] lib/contract-interview.md STEP 4: one paragraph after the print line. Before the first
  dev-step dispatch, after the flow's branch step, a contract with `CHECK:` lines gets its dry
  run: `- run-base:` recorded (start SHA for the TODO count) and `gates.sh run` on a `mktemp -d`
  copy from the project root (§ BEFORE THE FIRST DISPATCH). Every flow that writes such a
  contract, challenged or not; a flow's own positive control on the unfixed tree counts as the
  `gates.sh` half (guardrails, a11y) and `- run-base:` is still recorded. No template
  placeholder; a run-base written before the branch step (challenge-plan is read before it) is
  replaced by `git rev-parse HEAD` right after the branch step.
- [ ] skills/ship-feature/SKILL.md + skills/init-project/SKILL.md: STEP 6 / STEP 10 "Fix all
  CRITICAL" → fix every CRITICAL or Important finding that carries reproducible evidence; else
  one attempt at a failing command, else MINOR; security → user; both citations path-prefixed
  (census-locked, both flip-tested). RULES lines and the ship-feature loop-back table row say
  "CRITICAL or Important" with reproducible evidence. Right after each `gitflow.sh start` block (STEP 4 / STEP 8, a later turn): a
  pointer to the contract dry run on that branch.
- [ ] lib/capitalize-commit.md: `[[ $run_base =~ ^[0-9a-f]{7,40}$ ]]` guard + `--end-of-options`;
  prose: non-SHA `run_base` → `TODO n/a`.
- [-] agents/verifier.md: DEFERRED (contract criterion 4 ABANDON): see Challenge r2.

## Executor steps
1. One shell call from /home/bchanot/Documents/claude: `t=$(mktemp -d); awk '/^```diff$/{p=1;next}
   p&&/^```$/{exit} p' /home/bchanot/Documents/claude/.claude/tasks/plans/2026-11-20-levers-followup-1725.md
   > "$t/p.patch" && git apply --check "$t/p.patch" && git apply "$t/p.patch" && git diff --numstat`.
   Recovery: `git checkout -- lib/contract-interview.md skills/ship-feature/SKILL.md
   skills/init-project/SKILL.md lib/capitalize-commit.md agents/verifier.md`.
2. `bash ~/.claude/lib/gates.sh run <contract>` → `GATES — VERDICT: MET`.

## Edge cases
- hotfix contracts carry no `CHECK:` → no dry run, no run-base → capitalize uses `HEAD`
  (pending edits only, existing shortcut).
- `run_base` short SHA accepted; `HEAD`, branch names, `-`-led values → `TODO n/a` (fixture,
  `--output=x` writes no file).
- ship-feature table row keeps its pre-existing em-dash (criterion 5 excludes that one line).

## Proof before dispatch
Scratch clone r3: criteria 1-5 MET, census green, both new citations flip-tested; untouched
tree: 1-5 NOT-MET. CHECKs use shell variables, no temp files.

## Advisor (plan point)
Drove: [gated] exit path, run-base write site, dispatch-step pointers, the citer grep.

## Challenge r1 (3 lenses: correctness CONCERNS(2), robustness CONCERNS(1), simplicity CONCERNS(1))
- `[gated]` routing unwired and self-contradicting, init-project contract tracked (3 lenses) →
  `GATED:` OUTPUT line outside the ECARTS count + PROTOCOL bullet (robustness/correctness fix,
  inside verifier.md); "Rare" dropped.
- run-base written with the contract = before the branch switch, wrong base (correctness) →
  template line dropped; written at the dry run after the branch step; pointers moved below
  `gitflow.sh start`.
- MINORs taken: one run-base write site (no placeholder); "first dev-step dispatch";
  positive control counts as the dry run; second citation path-prefixed (census-locked);
  Important findings follow the same evidence rule; CHECK temp files → variables;
  challenge-plan.md copy named below.
- MINOR dropped: capitalize-commit:70 source pointer (still correct: the dry run writes run-base).

## Challenge r2 (confirmation, correctness: CONCERNS(3)), closed in r4
- `GATED:` routing lives where no orchestrator reads it (GATE 1 parsing in verify-secure-loop,
  init-project STEP 9) + removing an entry leaves its CONFORME (2 MAJOR) → item (2) DEFERRED:
  every in-verifier version grew mechanism; the fix belongs at the GATE 1 act sites, outside
  this run. agents/verifier.md untouched, criterion 4 ABANDON with handoff, TODO line for the
  user. Run reports ABANDONED, never "fully complete".
- run-base timing claim false; challenge-plan (read before the branch) can record it early
  (MAJOR) → contract-interview: an early value is replaced by `git rev-parse HEAD` right after
  the branch step; false parenthetical removed.
- MINORs taken: positive control = `gates.sh` half, run-base still recorded; "CRITICAL or
  Important" in RULES lines and table row. MINORs 5, 6, 7, 9 concerned the deferred verifier
  change: moot here, carried into the TODO handoff.

## Disposition
- honors BDR-151: places levers 1, 2, 5, 6 at the act sites.
- applies LRN-297 (act-site restatement), LRN-304 (counter guard + fixture), LRN-296, LRN-281.

## Not done
- The dry-run rule now lives at: verify-secure-loop § BEFORE THE FIRST DISPATCH (source),
  challenge-plan "Challenged or skipped" paragraph, contract-interview STEP 4, ship-feature
  STEP 4, init-project STEP 8. A change to it patches all five.
- Item (2) of the request (`[gated]` only on an untracked contract): deferred, user decision
  in TODO (fix at verify-secure-loop GATE 1 + init-project STEP 9, or keep today's behaviour).
- verify-secure-loop.md:26 "Records … once" not reworded; contract-interview states the
  replacement after the branch step.
- Vendored skills-external/requesting-code-review/SKILL.md:44-46 "Fix Critical immediately /
  Fix Important before proceeding / Note Minor for later" (foreign, not edited): the
  orchestrator's STEP 6 / STEP 10 text is the act-site rule.
- skills/tour/SKILL.md:161 audit fix policy, not a post-gate review reopen; untouched.
- MEASURE line from BDR-151 stays open.

## EXACT DIFF (against develop 23c5802)

```diff
diff --git a/lib/capitalize-commit.md b/lib/capitalize-commit.md
index de907ec..34a44f8 100644
--- a/lib/capitalize-commit.md
+++ b/lib/capitalize-commit.md
@@ -70,9 +70,11 @@ never a shell argument.
    (`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH), else
    `git rev-parse HEAD` now (shortcut: without a contract only the pending
    TODO edits count; edits committed earlier in the run are missed). A
-   failing `git diff` → `TODO n/a`, never a silent `+0 / -0`.
+   `run_base` that is not a 7-40 hex SHA, or a failing `git diff` →
+   `TODO n/a`, never a silent `+0 / -0`.
 
-       if d=$(git diff --no-color --no-ext-diff "$run_base" \
+       if [[ $run_base =~ ^[0-9a-f]{7,40}$ ]] && d=$(git diff --no-color \
+           --no-ext-diff --end-of-options "$run_base" \
            -- ':/.claude/tasks/TODO.md' 2>/dev/null); then
          n=$(printf '%s\n' "$d" | grep -c '^+ *- \[ \]')
          m=$(printf '%s\n' "$d" | grep -c '^- *- \[ \]')
diff --git a/lib/contract-interview.md b/lib/contract-interview.md
index 1c453a6..def4925 100644
--- a/lib/contract-interview.md
+++ b/lib/contract-interview.md
@@ -141,6 +141,17 @@ Q: <question> / A: <answer>   (pass B and mid-run entries: [gated <YYYY-MM-DD>])
 Print one line to the user, then continue the flow:
 `CONTRACT: <path> — <n> criteria, scope <files|repo-wide>, <q> questions asked`
 
+Before the first dev-step dispatch, after the flow's branch step, a
+contract with `CHECK:` lines gets its dry run: the main loop records
+`- run-base:` (the run's start SHA, for the TODO count of
+`lib/capitalize-commit.md`; a value written before the branch step is
+replaced by `git rev-parse HEAD` right after it) and, from the project
+root, runs `bash ~/.claude/lib/gates.sh run` on a `mktemp -d` copy of the
+contract (`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH). Every
+flow that writes such a contract does this, whether or not it challenges
+its plan; a flow's own positive control on the unfixed tree counts as the
+`gates.sh` half, and `- run-base:` is still recorded.
+
 ## MID-RUN CLARIFICATION (the channel executors halt into)
 
 An executor cannot talk to the human. It halts with `NEED-DECISION`, the
diff --git a/skills/init-project/SKILL.md b/skills/init-project/SKILL.md
index 40066ab..2a73752 100644
--- a/skills/init-project/SKILL.md
+++ b/skills/init-project/SKILL.md
@@ -224,6 +224,9 @@ Start the MVP feature branch off develop, then implement on it:
 ```bash
 bash "$HOME/.claude/lib/gitflow.sh" start feature mvp
 ```
+Then, before the first dispatch, the contract dry run on this branch
+(`lib/contract-interview.md` STEP 4;
+`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH).
 Invoke `subagent-driven-development` (vendored superpowers skill) for the per-task implement loop
 **and** the final whole-branch review **only**. Do NOT run its terminal
 `finishing-a-development-branch` step — this orchestrator owns integration via
@@ -277,7 +280,12 @@ Invoke `requesting-code-review` (vendored superpowers skill). **Model routing (B
 review subagent it dispatches MUST carry `model: "opus"` and `effort="xhigh"` in the Agent call —
 craft review is dispatched judgment, never inherited from the session.
 Add to its brief: "you may call the `advisor` tool once, before your
-verdict" (code review, BDR-150). Fix all CRITICAL before proceeding.
+verdict" (code review, BDR-150). Fix every CRITICAL or Important finding
+that carries reproducible evidence (a command that fails on HEAD, or real
+output shown wrong) before proceeding. Without it, one attempt at a failing
+command, else it is a MINOR; a security finding goes to the user
+(`lib/verify-secure-loop.md` § DONE;
+`lib/verify-secure-loop.md` § MINOR triage).
 
 ## STEP 10b — CAPITALIZE FOUNDING DECISIONS (memory registries)
 A greenfield's founding architecture decisions are the highest-value BDRs — the
@@ -379,7 +387,8 @@ bash "$HOME/.claude/lib/gitflow.sh" finish   # feature/mvp → develop
 - Scaffolder = skeleton only, zero logic.
 - Features → subagent pipeline only.
 - Broken build = unacceptable output.
-- Fix all CRITICAL review issues before proceeding.
+- Fix every CRITICAL or Important review issue that carries
+  reproducible evidence before proceeding (STEP 10).
 - Stop if requirements unclear at any step.
 
 ---
diff --git a/skills/ship-feature/SKILL.md b/skills/ship-feature/SKILL.md
index 81ae90a..4996778 100644
--- a/skills/ship-feature/SKILL.md
+++ b/skills/ship-feature/SKILL.md
@@ -186,6 +186,9 @@ Start the feature branch off develop, then implement on it:
 ```bash
 bash "$HOME/.claude/lib/gitflow.sh" start feature <name>
 ```
+Then, before the first dispatch, the contract dry run on this branch
+(`lib/contract-interview.md` STEP 4;
+`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH).
 Invoke `subagent-driven-development` (vendored superpowers skill) for the per-task implement loop
 **and** the final whole-branch review **only**. Do NOT run its terminal
 `finishing-a-development-branch` step — this orchestrator owns integration via
@@ -259,7 +262,12 @@ Invoke `requesting-code-review` (vendored superpowers skill). **Model routing (B
 review subagent it dispatches MUST carry `model: "opus"` and `effort="xhigh"` in the Agent call —
 craft review is dispatched judgment, never inherited from the session.
 Add to its brief: "you may call the `advisor` tool once, before your
-verdict" (code review, BDR-150). Fix all CRITICAL before proceeding.
+verdict" (code review, BDR-150). Fix every CRITICAL or Important finding
+that carries reproducible evidence (a command that fails on HEAD, or real
+output shown wrong) before proceeding. Without it, one attempt at a failing
+command, else it is a MINOR; a security finding goes to the user
+(`lib/verify-secure-loop.md` § DONE;
+`lib/verify-secure-loop.md` § MINOR triage).
 
 ## STEP 7 — CAPITALIZE (memory registries)
 Call memory_pending first, per /capitalize STEP 1 "Captured first".
@@ -341,7 +349,8 @@ bash "$HOME/.claude/lib/gitflow.sh" finish   # feature/<name> → develop
 - No skipping steps. No merged agent responsibilities.
 - No implement without user approval at STEP 3.
 - Subagents isolated — no shared context between tasks.
-- Fix all CRITICAL review issues before proceeding.
+- Fix every CRITICAL or Important review issue that carries
+  reproducible evidence before proceeding (STEP 6).
 - Stop if requirements unclear at any step.
 - STEP 4 errors → STEP 4b gate required before any fix. Never auto-patch a failing subagent.
 
@@ -361,7 +370,7 @@ The pipeline must handle these without aborting silently:
 | STEP 3 — user replies "request changes" | Loop back to STEP 2 with user's notes. Cap at 3 iterations; on the 3rd "request changes" without approval, ask "Pause and rescope this feature?" |
 | STEP 4 — subagent crashes (tool error, not test failure) | Treat as STEP 4b error path, present hypothesis-led gate. |
 | STEP 4b — option A retried 2× still failing | Force fall-through to B or C. Do not loop a 3rd time. |
-| STEP 6 — review returns CRITICAL items | Loop back to STEP 4 for those items only. Cap at 2 review-cycle iterations; if still CRITICAL, escalate. |
+| STEP 6 — review returns CRITICAL or Important items with reproducible evidence | Loop back to STEP 4 for those items only. Cap at 2 review-cycle iterations; if still CRITICAL, escalate. |
 | STEP 7 — `.claude/memory/` missing | Create the registry files from `~/.claude/templates/memory/` first, then proceed. |
 
 ---
```
