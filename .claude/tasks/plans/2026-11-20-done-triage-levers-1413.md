# PLAN r3 — done-triage-levers (/feat, 2026-11-20 14:13)

Source: handoff plan `.claude/tasks/plans/2026-11-20-done-and-triage-levers.md` (six levers,
five carriers, user-approved). Contract: `.claude/tasks/contracts/2026-11-20-done-triage-levers-1413.md`.
Base: develop 68a4d8b. Branch: feature/done-triage-levers.

## Mechanism (exact text: § EXACT DIFF below)

- [ ] lib/verify-secure-loop.md
  - header line 3: the include runs after the dev step, except its first section (before dispatch).
  - new `## BEFORE THE FIRST DISPATCH: contract dry run (main loop)` before `## GATE 0` (lever 5,
    main-loop side), only when the flow wrote a contract with `CHECK:` lines: (1) record
    `- run-base: <git rev-parse HEAD>` in the contract header (a SHA; feeds lever 6); (2) from
    the project root, `gates.sh run` on a `mktemp -d` copy of the contract (real ledger stays
    pending): no ERROR, NOT-MET only for undone work and for that reason, a row already MET
    valid only when the work must keep it green; prose oracles: simulate the planned text on a
    scratch copy and run the CHECKs there (LRN-296, stated inline). Bad oracle fixed before any
    floor loop.
  - out-of-scope bullet: "Run artifacts are in scope by default (`agents/verifier.md`, STEP 4)."
  - after `## Order invariant`: `## DONE: oracles green, reopened only on evidence` (lever 1,
    one attempt to turn a scenario into a failing command) and
    `## MINOR triage: fold before dispatch, or drop` (lever 2: findings on the run's plan or diff;
    drop line in the report and the run's plan file; security findings never droppable, to the
    user; doc-syncer `[MINOR]` patch class untouched).
  - unchanged: the three `route(phase="escalate")` (effort-routing lock = 3).
- [ ] lib/challenge-plan.md
  - new `## SKIP: a placed decision` before `## DISPATCH` (lever 3): three required conditions
    (dictated text; the decision is the user's own words or was challenged in the run that wrote
    it; the caller runs verify-secure-loop.md after its dispatch); open-choice test, in doubt
    challenge; the skip is the include's own path (user decision 2026-11-20) and discharges the
    plan point of effort-shift § Advisor; the `Challenge: skipped (…)` line replaces the summary.
  - second paragraph, outside the skip condition: the two dry-run actions restated inline, before
    the executor dispatch, citing § BEFORE THE FIRST DISPATCH (pre-dispatch reach of lever 5).
  - SYNTHESIZE MINOR bullet: fold or drop, drop format inline, security → user, cites § MINOR triage.
- [ ] CLAUDE.global.md — Planning & TODO last bullet (lever 4): "A TODO loop notes its start SHA
  in TODO.md, runs that list + user adds; new items: report, run if one breaks its work."
  319 → 320 lines (guard fires only above 320).
- [ ] lib/capitalize-commit.md — DO step 1, before step 2's commit (lever 6): compute `<todo>`;
  `run_base` = the contract's `- run-base:` SHA, else `git rev-parse HEAD` then (`shortcut:`:
  only pending TODO edits); 6-line snippet, `--no-color --no-ext-diff`, root pathspec
  `:/.claude/tasks/TODO.md`; failing diff → `TODO n/a`; step 3 and both rc 0 templates carry
  `· <todo>`.
- [ ] agents/verifier.md — STEP 4 (lever 5), with `--name-status` plus untracked: in scope by
  default = a plan file the diff ADDS under `.claude/tasks/plans/` or `docs/superpowers/plans/`;
  appended `MINOR dropped:` lines on an existing plan; the CONTRACT handed to the verifier, whole
  when untracked or added, else only its `EVIDENCE:`, `- run-base:`, `[gated]` lines; any other
  plan or contract change stays out of scope.

## Executor steps
1. Extract the EXACT DIFF block of this file and apply it atomically:
   `t=$(mktemp -d); awk '/^```diff$/{p=1;next} p&&/^```$/{exit} p'
   /home/bchanot/Documents/claude/.claude/tasks/plans/2026-11-20-done-triage-levers-1413.md
   > "$t/levers.patch"`, then, from the repo root, `git apply --check "$t/levers.patch"` and
   `git apply "$t/levers.patch"` (same shell call, so `$t` survives). git apply is
   all-or-nothing; recovery if anything goes wrong: `git checkout -- lib/verify-secure-loop.md
   lib/challenge-plan.md CLAUDE.global.md lib/capitalize-commit.md agents/verifier.md`.
2. `bash ~/.claude/lib/gates.sh run .claude/tasks/contracts/2026-11-20-done-triage-levers-1413.md`
   → `GATES — VERDICT: MET`.
3. No other edit. No commit.

## Edge cases
- CLAUDE.global.md at exactly 320 lines: the session-start guard fires only above 320.
- `run_base` unknown SHA or failing diff → `TODO n/a`; start SHA counts uncommitted and
  committed edits, from a subdirectory too; `HEAD` taken before the commit counts pending edits
  (all fixture-tested, criterion 8).
- `- run-base:` header line: `gates.sh status` parses it unchanged (PENDING(12) checked).
- `§` citations (§ BEFORE THE FIRST DISPATCH, § MINOR triage, § Advisor): resolved by the
  doctrine-citers census, flip-tested (renaming a heading turns T6 red).
- Contract CHECKs pinned to 68a4d8b, not `develop`.

## Proof done before dispatch
Fresh scratch clone + r3 text: 12/12 criteria MET (10 suites green, fixture 4 cases, 8 removed
lines). Positive control on the
untouched tree: 10 NOT-MET, the 2 keep-green suite rows MET.

## Challenge r1 (3 lenses: correctness CONCERNS(3), robustness CONCERNS(4), simplicity CONCERNS(1))
- `base` never recorded (3 lenses) → `- run-base:` SHA written at the dry run, `HEAD` fallback,
  name distinct from the gitflow base, `--no-color --no-ext-diff`.
- verifier scope too wide, `.claude/tasks` mislabelled transient (2 lenses) → only ADDED plan
  files and EVIDENCE/run-base/[gated] contract changes; edits to existing plans stay out.
- dry run unreached before dispatch → header line 3 fixed, actions restated inline in
  challenge-plan.md outside the skip; unreached flows named below.
- security findings droppable → never a droppable MINOR, to the user.
- post-gate review precedence → DONE binds ship-feature STEP 6 / init-project STEP 10.
- MINORs taken: `gates.sh run` on a mktemp copy instead of hand runs; LRN-296 reduced to a
  citation; SKIP conditions (user's own words or challenged; caller has gates), discharges the
  advisor plan point; drop line also in the plan file (tripwire traceable); doc-syncer `[MINOR]`
  untouched; triage limited to plan or diff findings; frozen list anchored on the start SHA;
  applier dropped for `git apply` of this diff (atomic, named recovery); drop format inline at
  SYNTHESIZE; dry run conditional on a contract with CHECKs.
- MINOR dropped: tripwire "open TODO still growing" confounded by measurement lines; the dated
  measurement lines are counted apart at the EVAL, no text change.

## Challenge r2 (confirmation, correctness: CONCERNS(2)), closed in r3
- `HEAD` fallback read after step 2's commit → silent `+0 / -0` → count moved to DO step 1,
  before the commit; fixture adds the committed and subdirectory cases.
- DONE claimed to bind ship-feature STEP 6 / init-project STEP 10, act sites unchanged → sentence
  dropped; both sites go to the pass B scope question.
- MINORs taken: verifier clause keyed on the handed CONTRACT (untracked/added = whole) and on
  appended `MINOR dropped:` lines of an existing plan, `--name-status` + untracked; dry run cwd
  = project root; LRN-296 procedure inline, "never" dropped; skip grounded in the user decision
  of 2026-11-20; lever-4 start SHA written into TODO.md by the loop; executor step names the
  plan's absolute path and keeps `$t`; root pathspec `:/`; ship-feature and init-project named
  unreached below.
- No further re-challenge: lib/challenge-plan.md allows one confirmation pass.

## This run under lever 1 (a behavioural claim)
Locks: the three `§` citations (census T6) and this contract's CHECKs. Live probe: the next
/feat or /bugfix run (dry run + run-base, SKIP decision, MINOR drops, `TODO +n / -m` line).
Dated measurement: the TODO line written at capitalize, "2026-11-20 levers: after ~5 runs, log
dispatches/run, TODO +n/-m per run (measurement lines apart), `MINOR dropped:` lines per plan,
any post-merge bug traced to a dropped MINOR (EVAL)"; tripwires: a BUGS-FOUND entry whose cause
matches a `MINOR dropped:` line of a merged run, or net open TODO growing run over run.

## User answers (pass B, 2026-11-20): CLAUDE.global line kept, both strings OK, scope (a)+(b) yes → follow-up /feat (3 files) after this run

## Questions asked (pass B)
- The CLAUDE.global.md line wording (loaded in every session).
- The strings `MINOR dropped: <finding>` and `Challenge: skipped (placed decision: …)`.
- Scope beyond five files: (a) lib/contract-interview.md STEP 4 would reach the dry run +
  run-base from every contract-writing flow; (b) ship-feature STEP 6 (:262/:344) and
  init-project STEP 10 (:280/:382) still say "Fix all CRITICAL", unbound by lever 1.

## Not done (named)
- No skill file changes (five-file limit). Unreached by the pre-dispatch pointer: guardrails and
  a11y (contract + executor, no challenge-plan.md), bugfix's trivial fast path and hotfix's
  cosmetic skip (no challenge read), bugfix STEP 3b (reads challenge-plan.md before its contract
  exists), ship-feature and init-project (dispatch in a later turn, after a human gate).
  Contract-less flows count `TODO` from `HEAD` (pending edits only).
- Lever 1 does not bind ship-feature STEP 6 / init-project STEP 10 (their text unchanged).
- Proof of the change after ~5 runs (EVAL) stays a TODO line, per the handoff plan.

## Disposition (STEP 0.6)
- honors BDR-062/BDR-098: CLAUDE.global.md ≤ 320 (one line added).
- honors BDR-065 (amendment: `.claude/tasks/{contracts,plans}` durable): the verifier default
  covers only plan files a run ADDS and EVIDENCE/run-base/[gated] contract changes; an edit to
  an existing plan stays a gap.
- honors BDR-075: the three-lens challenge stays for every run with an open choice; the skip is
  limited to placement of a user's own or already-challenged decision (user approval of lever 3).
- honors BDR-049/BDR-083: fresh blind verifier and GATE 0 untouched.
- applies LRN-296 (scratch simulation), LRN-297 (pointer restates the actions at the act site),
  LRN-298 (placement by line order in CHECKs 3 and 6), LRN-281/LRN-173 (EVIDENCE lines, literal
  markers, CHECKs run on the precedent and on the untouched tree).

## EXACT DIFF (against develop 68a4d8b)

```diff
diff --git a/CLAUDE.global.md b/CLAUDE.global.md
index 778434e..e87a323 100644
--- a/CLAUDE.global.md
+++ b/CLAUDE.global.md
@@ -113,7 +113,8 @@ code" wins. Repo-specific instructions override both.
 - Once it qualifies: plan before code → one subtask = one coherent change
   → check off as you go → high-level note at each milestone. A plan a skill
   persists (`.claude/tasks/plans/`, contract) satisfies the rule; TODO.md
-  then carries one line per run.
+  then carries one line per run. A TODO loop notes its start SHA in TODO.md,
+  runs that list + user adds; new items: report, run if one breaks its work.
 
 ## After code changes
 1. Run tests, lint, build, type-check if available. Report what was
diff --git a/agents/verifier.md b/agents/verifier.md
index cd3f0ec..15b7b5b 100644
--- a/agents/verifier.md
+++ b/agents/verifier.md
@@ -101,8 +101,15 @@ Parse the single `FLOOR GUARD:` line:
 ## STEP 4 — SCOPE CHECK
 
 List the files actually touched (`git diff --name-only` over `DIFF`).
-Compare against the contract's `FILE SCOPE`. Report every out-of-scope
-file. Disposition is NOT your call: the orchestrator treats each one as a
+Compare against the contract's `FILE SCOPE` (`git diff --name-status`
+plus untracked files). Run artifacts are in scope by default, whatever
+`FILE SCOPE` says: a plan file the diff ADDS under `.claude/tasks/plans/`
+or `docs/superpowers/plans/`; on an existing plan, appended
+`MINOR dropped:` lines only; the CONTRACT you were handed, whole when
+untracked or added, else only its `EVIDENCE:` lines, `- run-base:` line and
+`[gated]` entries. Any other change to a plan or a contract stays out of
+scope. Report every other out-of-scope file.
+Disposition is NOT your call: the orchestrator treats each one as a
 gap — the dev removes it or justifies it, and an accepted justification
 only enters the contract through a human micro-gate.
 
diff --git a/lib/capitalize-commit.md b/lib/capitalize-commit.md
index 59bc2ac..de907ec 100644
--- a/lib/capitalize-commit.md
+++ b/lib/capitalize-commit.md
@@ -63,14 +63,30 @@ never a shell argument.
    - `chore(memory): BLK-010 resolved — bugfix profile path`
    - `chore(memory): journal — hotfix copy typo`   (journal-only, nothing else)
 
+   Then, still before step 2, count the run's TODO movement as `<todo>`:
+   `TODO +n / -m`, the open TODO items the run added and removed (closed or
+   dropped); a reworded open item counts on both sides. `run_base` is a SHA,
+   never the gitflow base branch: the contract's `- run-base:` line
+   (`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH), else
+   `git rev-parse HEAD` now (shortcut: without a contract only the pending
+   TODO edits count; edits committed earlier in the run are missed). A
+   failing `git diff` → `TODO n/a`, never a silent `+0 / -0`.
+
+       if d=$(git diff --no-color --no-ext-diff "$run_base" \
+           -- ':/.claude/tasks/TODO.md' 2>/dev/null); then
+         n=$(printf '%s\n' "$d" | grep -c '^+ *- \[ \]')
+         m=$(printf '%s\n' "$d" | grep -c '^- *- \[ \]')
+         todo="TODO +$n / -$m"
+       else todo="TODO n/a"; fi
+
 2. Commit surgically via the helper, capturing the memory-commit hash it prints:
 
        mem_hash=$(bash "$HOME/.claude/lib/memory-commit.sh" commit "<message>")
        rc=$?
 
-3. Report by (rc, mem_hash):
-   - rc 0, mem_hash non-empty → `✅ mémoire committée <mem_hash>`
-   - rc 0, mem_hash empty     → `CAPITALIZE: rien à committer` (helper no-op)
+3. Report by (rc, mem_hash). Every report line ends with `· <todo>` (step 1):
+   - rc 0, mem_hash non-empty → `✅ mémoire committée <mem_hash> · <todo>`
+   - rc 0, mem_hash empty     → `CAPITALIZE: rien à committer · <todo>` (helper no-op)
    - rc 3                     → unsafe git state (detached / merge in progress);
                                 memory stays in the working tree for a manual
                                 commit — surface the helper's stderr.
diff --git a/lib/challenge-plan.md b/lib/challenge-plan.md
index fd69e67..2941ff1 100644
--- a/lib/challenge-plan.md
+++ b/lib/challenge-plan.md
@@ -30,6 +30,27 @@ SOLID, synthesis is a no-op. It only costs more when a lens lands a real finding
 The main loop's advisor call before the dispatch (below) is the costliest
 single item: once per skill run.
 
+## SKIP: a placed decision
+
+A run that only places a decision the user already made skips this phase:
+no challengers and no plan advisor call. Three conditions, all required:
+the exact text or change is dictated by that decision (no new design); the
+decision's text is the user's own words, or was challenged in the run that
+wrote it; and the caller runs `lib/verify-secure-loop.md` after its
+dispatch, so the gates still run. The test is whether the run settles an
+open choice of its own (a mechanism, a condition, a threshold, wording the
+user did not dictate), never code versus text; in doubt, challenge. The
+skip is this include's own path (user decision 2026-11-20): a skill's
+challenge step that reads this section runs as written, and the skip
+discharges the plan point (`lib/effort-shift.md` § Advisor). The caller prints
+`Challenge: skipped (placed decision: <the user's decision, date>)` in
+place of its CHALLENGE SUMMARY.
+
+Challenged or skipped: when the flow wrote a contract with `CHECK:` lines,
+before the executor dispatch the main loop records `- run-base:` in the
+contract and runs `gates.sh run` on a `mktemp -d` copy of it
+(`lib/verify-secure-loop.md` § BEFORE THE FIRST DISPATCH).
+
 ## DISPATCH — three fresh challengers, in parallel, blind
 
 **Advisor first (main loop).** Before the first dispatch, with no main-loop
@@ -88,6 +109,10 @@ Parse each `CHALLENGE — LENS: … — VERDICT:` line and merge the FINDINGS:
 - **Severity-driven, not consensus.** Any `[BLOCKER]` from ANY single lens is
   must-address — the lenses are orthogonal, so a lone security/rollback finding
   is real, never outvoted by lens-count. Cross-lens agreement only RANKS the MINORs.
+  Each MINOR is folded into the plan now or dropped: a drop is one
+  `MINOR dropped: <finding>` line in the report and the plan file, nothing
+  in TODO.md or a registry; a security finding goes to the user
+  (`lib/verify-secure-loop.md` § MINOR triage).
 - **RE-THINK the aspect the challenge pointed at.** For each BLOCKER (and each
   MAJOR you accept): revise the plan on THAT aspect — a NAMED, diffable change to
   the plan, never a self-authored "addressed" line. A BLOCKER you consciously keep
diff --git a/lib/verify-secure-loop.md b/lib/verify-secure-loop.md
index b2aaa32..1141a1e 100644
--- a/lib/verify-secure-loop.md
+++ b/lib/verify-secure-loop.md
@@ -1,6 +1,7 @@
 # Verify + secure loop — shared orchestrator include (feat, bugfix, guardrails, a11y)
 
-Runs in the ORCHESTRATOR MAIN LOOP after the dev step completes. Turns a
+Runs in the ORCHESTRATOR MAIN LOOP after the dev step completes (its first
+section runs before the dev step is dispatched). Turns a
 finished diff into a verified, security-cleared change through two fresh
 gates and bounded loops. Loop decisions live here, in the main loop
 (LRN-083: subagents = execution + report). The dev step is a dispatched
@@ -17,6 +18,26 @@ Nominal path is cheap — a free floor run, then
 one verifier dispatch + one security dispatch, done. The loop only costs
 more when it actually loops.
 
+## BEFORE THE FIRST DISPATCH: contract dry run (main loop)
+
+When the flow wrote a contract with `CHECK:` lines, the main loop does two
+things before the dev step is dispatched:
+
+1. Records the run's start commit in the contract header, once:
+   `- run-base: <git rev-parse HEAD>` (a SHA, never a branch name;
+   `lib/capitalize-commit.md` counts the run's TODO movement from it).
+2. Copies the contract to a `mktemp -d` path and, from the project root,
+   runs `bash ~/.claude/lib/gates.sh run <copy>`, so the real ledger stays
+   `pending`. Expected: no `ERROR(n)` (malformed ledger: fix it here),
+   NOT-MET rows only where the work is not done yet, each failing for that
+   reason and not for a syntax error, a missing tool or a wrong path. A row
+   already MET is valid only when the work must keep it green (a suite, a
+   line cap); any other is vacuous. A marker that can never match fails
+   like undone work: for oracles that grep prose, apply the planned text
+   to a scratch copy of the repo and run the CHECKs there (LRN-296).
+
+A bad oracle is fixed in the contract here, before any floor loop.
+
 ## GATE 0 — DETERMINISTIC FLOOR (no dispatch, no model)
 
 Before spending a verifier dispatch, execute the oracles the contract itself
@@ -92,7 +113,8 @@ Parse its single `VERIFY — VERDICT:` line:
   cannot fix unverifiability); do not spend a loop on it.
 - Out-of-scope files: a dev justification is accepted ONLY through the human
   micro-gate that appends `[gated <date>]` to the contract's FILE SCOPE;
-  otherwise the dev removes the file.
+  otherwise the dev removes the file. Run artifacts are in scope by
+  default (`agents/verifier.md`, STEP 4).
 - Structural failure (`ERROR(…)`, missing/duplicated VERDICT line,
   unparsable, crash, `CONFORME` without `PROOF` or without `FLOOR`) → retry
   ONCE with a fresh verifier; a 2nd structural failure → human escalation.
@@ -147,3 +169,31 @@ verifier's verdict meaningless. REQUEST conformity is
 always re-checked BEFORE security on any re-loop — a security fix that breaks
 the feature must not slip through because only the security gate re-ran.
 Never the reverse order.
+
+## DONE: oracles green, reopened only on evidence
+
+A run is done when its oracles are green: GATE 0 MET (the suite criterion
+included), GATE 1 CONFORME and GATE 2 PASS on the same diff. After done, a
+review (the end-of-run advisor call, a code review, a re-read) reopens the
+run only with reproducible evidence: a command that fails on HEAD, or real
+output shown wrong. A plausible scenario alone does not reopen the run:
+the main loop tries once to turn it into a failing command, and if it
+cannot, the finding is a MINOR (below). A behavioural claim ("agents obey
+the rule") is done at its locks green, one live probe and one dated
+measurement: a TODO line that carries the date and the tripwires that
+would reopen it.
+
+## MINOR triage: fold before dispatch, or drop
+
+A MINOR finding on the run's plan or diff (from a challenger, a review, an
+advisor) is either folded into the plan before the dispatch or dropped. No
+fix round after the gates for a MINOR: it costs a full gate cycle. A drop
+is one line, `MINOR dropped: <finding>`, in the run report and appended to
+the run's plan file; nothing goes to TODO.md, BUGS-FOUND.md or any
+registry. The backlog takes only findings with reproducible evidence, or
+what the user asks for. Never a droppable MINOR: a security finding (a
+GATE 2 `REPORTED` item, a secret, an injection, authorization or exposure
+issue from any review) goes to the user, who decides fix or record.
+Untouched by this triage: doc-syncer's `[MINOR]` patch class, the safety
+guardrails, every gate, and the user's questions on visible, public-name
+and scope choices.
```
