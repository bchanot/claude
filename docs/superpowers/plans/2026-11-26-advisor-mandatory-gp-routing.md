# Mandatory advisor and untyped sub-agent routing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the advisor call certain where it is allowed, put two main-loop advisor calls in every challenged plan, and route untyped sub-agents by the nature of their work.

**Architecture:** Prose doctrine only. Each rule is reworded in the file where the acting loop or agent reads it; exact-string locks in `lib/tests` change first (red), then the text (green). No new mechanism, no router logic change.

**Tech Stack:** Markdown doctrine (`lib/`, `agents/`, `skills/`, `CLAUDE.global.md`), bash (`hooks/`, `lib/tests/*.test.sh`), one string constant in a TypeScript mod (`mods/model-router/hooks/register.ts`).

**Spec:** `docs/superpowers/specs/2026-11-26-advisor-mandatory-gp-routing-design.md`. Where the spec and this plan differ, this plan wins: its r2 section lists what changed after the challenge (synthesis trigger, scope of the grammar, three tasks instead of four, the audit-delta dispatch).
**Contract:** `.claude/tasks/contracts/2026-11-26-advisor-mandatory-gp-routing-1934.md`

## Global Constraints

- Work from the repo root `/home/bchanot/Documents/claude`, on the branch the orchestrator created. Never switch branch.
- Never stage or edit `settings.json` (it carries an unrelated uncommitted change). Stage files by name, never `git add -A` or `git add .`.
- Never edit anything under `skills-external/` nor `skills/subagent-driven-development`, `skills/writing-plans`, `skills/brainstorming`, `skills/requesting-code-review` (vendored, BDR-106).
- Never write `model: "fable"` or `model="fable"` anywhere (BDR-150).
- Tests run only through `make test suite=<path>` or `make test`. Success ends with the line `all suites green`.
- A locked sentence is an exact single-line string (LRN-166): type each new block exactly as given, line breaks included. Do not rewrap neighbouring lines.
- `CLAUDE.global.md` must end every task at 320 lines or fewer (BDR-062). Check with `wc -l CLAUDE.global.md`.
- No capitalised MUST-style wording in new text (BDR-081). Use the sentences given.
- Do not call the `advisor` tool: you are an executor.
- Commit messages: subject `<type>(<scope>): <what>`, 72 chars max, whole message 50 words max.
- Public docs (README.md, USAGE.md, ARCHITECTURE.md, CHANGELOG.md) are out of scope: a later doc-sync step patches them.

- Baseline: before Task 1 the orchestrator runs `make test` once and records any suite already red. A suite that was red before this plan is not yours to fix: report it and go on.
- A `make test` run that fails prints the runner's summary `<n> suite(s) red: …` and then make's own `Error 1` line: the summary line is the one to read.

## Contract amendments (made by the orchestrator at the validation gate, not by a task)

FILE SCOPE gains `skills/{a11y,guardrails,audit-delta,tour,release-candidate}/SKILL.md` and `docs/superpowers/specs/`. Criterion 1 names the second call's condition (a lens returned a BLOCKER or a MAJOR) and the first call's (no main-loop call yet in the run). Criterion 2 allows drafting of already-decided changes by a sonnet agent. Criterion 9 puts the summary in `CLAUDE.global.md` and the full list (skill-runners, tour exception) in `lib/model-gate.md`.

## r2 (after the challenge: correctness CONCERNS(3), robustness CONCERNS(2), simplicity SOLID)

Named changes: the Effect-line paragraph moves after the SDD sentence (Task 1 Step 9); each agent's `ADVISOR:` explanation is folded into its advisor bullet; the security-auditor audit-mode sentence is edited instead of adding a carve-out; the analyzer line is marked "(dispatched only)" in both OUTPUT blocks; the synthesis call triggers once the synthesis is done, revised plan or not, and is due whatever earlier call the run made; the protocol mirror carries the sub-agent skip; a drafted revision is read against the decided list; the seven end-of-run lines carry the full grammar; the CLAUDE.global.md rule sits in § Workflow and names the tour exception; `skills/audit-delta/SKILL.md` gives its fallback general-purpose dispatch a model; the TODO check gets a real revert path and position-based tripwires; Task 3 lints only the suite the contract names; red-check steps say what make prints; the TS lock's SKIP case is stated.
MINOR dropped: reword `lib/effort-shift.md` point 3 from "answer" to "effect" (the answer is the input, the line reports its effect; the neighbouring sentences are locked).
MINOR dropped: `lib/model-gate.md` tiers as one sentence instead of a list (four tiers and an exception read better as a list).
MINOR dropped: skill-runners in the `CLAUDE.global.md` line (no room at 320 lines; `lib/model-gate.md` carries it and every skill that dispatches a runner names its model).

## r3 (confirmation pass: correctness CONCERNS(1))

Folded: the drafted revision is re-read change by change (an untracked plan has no diff); the audit-delta fallback brief forbids the advisor; the TODO revert path reverts the merge; reports "carry" the `ADVISOR:` line (the audit-mode auditor still ends with `REPORT_WRITTEN:`, lock T23c); verifier and security-auditor `ERROR` verdicts carry no line; effort-shift point 1 says "on the plan after the first synthesis".
[deferred 2026-11-26] MAJOR, confirmation pass, on a point r2 touched: "The reworded row sentence (Task 2 Step 3) makes the CHALLENGE SUMMARY `Advisor:` row 'cover both calls (plan, synthesis)' and adds the value `not called (all SOLID)`. The nine caller templates the main loop actually prints still have one slot with the old one-call list, and no task updates them." Asked to the human once: keep, cut or reopen. Answer 2026-11-26: reopen with one sentence. Named change: the row sentence of `lib/challenge-plan.md` says the row is printed in two parts whatever the caller's template shows (lock T25d), and hotfix's `ADVISOR` field carries each call of the run. The nine caller templates are not edited.

## Review Focus

1. A caller reads "exactly one call" as "retry until served" when the call errors. Expected: one attempt, then proceed. Pinned by lock T22b (Task 1).
2. An old "at most / once" survives because it is split over two lines. Expected: none left. Pinned by lock T24 on newline-joined text, with a positive control (Task 1).
3. The security auditor writes its `ADVISOR:` trace into an audit REPORT file, or prints it after `REPORT_WRITTEN:`. Expected: the REPORT block omits the line and `REPORT_WRITTEN:` stays last. Pinned by lock T23 (Task 1).
4. A plan-challenger `ERROR(<reason>)` verdict grows an `ADVISOR:` line and breaks "ERROR carries only the PLAN line". Expected: none on ERROR. Pinned by lock T23b (Task 1).
5. A skill run inside a sub-agent makes the new synthesis call. Expected: it skips both calls. Pinned by lock T19 (Task 2).

---

### Task 1: Allowed sub-agents make exactly one advisor call and report its effect

**Files:**
- Test: `lib/tests/subagent-advisor.test.sh`
- Modify: `agents/plan-challenger.md`, `agents/verifier.md`, `agents/security-auditor.md`, `agents/analyzer.md`, `hooks/subagent-advisor.sh`, `skills/ship-feature/SKILL.md`, `skills/init-project/SKILL.md`, `lib/effort-shift.md`, `CLAUDE.global.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the effect grammar `changed: <what>` | `no change` | `not called (<reason>)`, defined in `lib/effort-shift.md` under the paragraph that starts `Effect line.` Task 2 appends one sentence to that paragraph.

- [ ] **Step 1: Update the locks (they must fail first)**

In `lib/tests/subagent-advisor.test.sh`:

Replace
```
    'Advisor, when dispatched as a sub-agent: one call allowed')" yes
```
with
```
    'Advisor, when dispatched as a sub-agent: exactly one call when')" yes
```

Replace
```
    "Add to its brief: \"you may call the \`advisor\` tool once")" yes
```
with
```
    "Add to its brief: \"make exactly one \`advisor\` call when the tool is")" yes
```

Replace
```
  'and an opus code review at most')" yes
```
with
```
  'and an opus code review exactly')" yes
```

Insert this block just before the line `echo "subagent-advisor: $pass pass, $fail fail"`:
```bash
# exactly one call and its effect line (user decision 2026-11-26)
check T21-hook-exactly "$(in_ctx "$(ctx '{}')" \
  'When allowed: exactly one call, before your verdict or report.')" yes
for a in plan-challenger verifier security-auditor analyzer; do
  check "T22 $a effect line" "$(has "agents/$a.md" \
    'ADVISOR: changed: <what> | no change | not called (absent | error)')" yes
  check "T22b $a no retry" "$(has "agents/$a.md" \
    'erroring → proceed, no retry.')" yes
done
check T22c-effect-grammar "$(has lib/effort-shift.md \
  "grammar: \`changed: <what>\` | \`no change\` | \`not called (<reason>)\`.")" yes
check T23-sec-report-clean "$(has agents/security-auditor.md \
  "this same block without its \`ADVISOR:\` line")" yes
check T23c-report-written-last "$(has agents/security-auditor.md \
  "\`REPORT_WRITTEN: <path>\`, after the \`ADVISOR:\` line.")" yes
check T23b-error-none "$(has agents/plan-challenger.md \
  "verdict carries no \`ADVISOR:\` line.")" yes
old_re='at most once, before|at most once per dispatch|one call allowed'
old_re="$old_re|tool once, before|may call once|allowing one"
joined() { tr '\n' ' ' < "$ROOT/$1" | tr -s ' '; }
check T24-control \
  "$(printf 'x at most once, before y' | grep -cE "$old_re")" 1
for f in CLAUDE.global.md lib/effort-shift.md agents/plan-challenger.md \
  agents/verifier.md agents/security-auditor.md agents/analyzer.md \
  skills/ship-feature/SKILL.md skills/init-project/SKILL.md; do
  check "T24 $f" "$(joined "$f" | grep -cE "$old_re")" 0
done
check T24-hook "$(ctx '{}' | grep -cE "$old_re")" 0

```

- [ ] **Step 2: Run the suite, confirm it is red**

Run: `make test suite=lib/tests/subagent-advisor.test.sh 2>&1 | tail -40`
Expected: `FAIL` lines for T20 (4), T12 (2), T14, T21, T22 (4), T22b (4), T22c, T23, T23c, T23b, T24 on every listed file and T24-hook; `T24-control` does not fail; then the summary `1 suite(s) red: lib/tests/subagent-advisor.test.sh`.

- [ ] **Step 3: `agents/plan-challenger.md`**

In the OUTPUT code block, add one line after the `PROOF:` line, so the block ends:
```
PROOF: read <n> files, inspected <what>, checked plan §<…>
ADVISOR: changed: <what> | no change | not called (absent | error)
```

Replace
```
- Advisor, when dispatched as a sub-agent: one call allowed, after
  drafting your findings and before the verdict, whatever the harness
  prompt schedules; absent or erroring → proceed. Advice may add or
  sharpen a finding. Advice alone never drops or lowers one: a change
  rests on your own re-read, cited at file:line.
```
with
```
- Advisor, when dispatched as a sub-agent: exactly one call when the
  `advisor` tool is listed, after drafting your findings and before the
  verdict, whatever the harness prompt schedules; tool not listed or call
  erroring → proceed, no retry. Advice may add or sharpen a finding.
  Advice alone never drops or lowers one: a change rests on your own
  re-read, cited at file:line. The OUTPUT's `ADVISOR:` line traces the
  call: `changed:` names the findings it added or sharpened; `not called`
  when the tool is not listed or the call errored. An `ERROR(<reason>)`
  verdict carries no `ADVISOR:` line.
```

- [ ] **Step 4: `agents/verifier.md`**

In the OUTPUT code block, add after the `PROOF:` line:
```
ADVISOR: changed: <what> | no change | not called (absent | error)
```

Replace
```
- Advisor, when dispatched as a sub-agent: one call allowed, after STEP 4
  and before STEP 5, whatever the harness prompt schedules; absent or
  erroring → proceed. Advice may send you back to a criterion: a
```
with
```
- Advisor, when dispatched as a sub-agent: exactly one call when the
  `advisor` tool is listed, after STEP 4 and before STEP 5, whatever the
  harness prompt schedules; tool not listed or call
  erroring → proceed, no retry. Advice may send you back to a criterion: a
```

In the same bullet replace its last line
```
  re-read or run (STEP 2).
```
with
```
  re-read or run (STEP 2). The OUTPUT's `ADVISOR:` line traces the call:
  `changed:` names the NOT-MET rows it prompted; `not called` when the
  tool is not listed or the call errored. An `ERROR(<reason>)` verdict
  carries no `ADVISOR:` line.
```

- [ ] **Step 5: `agents/security-auditor.md`**

In the OUTPUT code block, add after the `PROOF:` line:
```
ADVISOR: changed: <what> | no change | not called (absent | error)
```

Replace
```
- Advisor, when dispatched as a sub-agent: one call allowed, after
  STEP 4 and before STEP 5 and any REPORT write, whatever the harness
  prompt schedules; absent or erroring → proceed. Advice may add a
  finding or raise a severity, cited at a file:line you read. An added
```
with
```
- Advisor, when dispatched as a sub-agent: exactly one call when the
  `advisor` tool is listed, after STEP 4 and before STEP 5 and any REPORT
  write, whatever the harness prompt schedules; tool not listed or call
  erroring → proceed, no retry. Advice may add a finding or raise a
  severity, cited at a file:line you read. An added
```

In the same bullet replace its last line
```
  checklist or STEP 4.
```
with
```
  checklist or STEP 4. The OUTPUT's `ADVISOR:` line traces the call:
  `changed:` counts the findings it added or raised; `not called` when
  the tool is not listed or the call errored. An `ERROR(<reason>)` verdict
  carries no `ADVISOR:` line.
```

Just below the OUTPUT code block replace
```
In audit mode, ALSO write this same block (plus per-finding detail) to
`REPORT`, and end stdout with `REPORT_WRITTEN: <path>`.
```
with
```
In audit mode, ALSO write this same block without its `ADVISOR:` line
(plus per-finding detail) to `REPORT`, and end stdout with
`REPORT_WRITTEN: <path>`, after the `ADVISOR:` line.
```

- [ ] **Step 6: `agents/analyzer.md`**

The file has two OUTPUT code blocks: the one whose first line is `ANALYSIS: <target>` (its last line starts `- SELECTION:`) and the DEBUG MODE one whose first line is `DEBUG ANALYSIS:` (its last line starts `  - <file or logic that is NOT the cause`). At the end of each block, add a blank line and:
```
ADVISOR: changed: <what> | no change | not called (absent | error)   (dispatched only)
```

Replace
```
- Advisor, when dispatched as a sub-agent: one call allowed, after the last
  TASKS or PROCESS step and before the OUTPUT, whatever the harness prompt
  schedules; absent or erroring → proceed. Advice may point you back to
  the code; every OUTPUT line rests on what you read, never on the advice
  alone. Advice proposing a design or a fix counts only where the brief
  asks for a fix.
```
with
```
- Advisor, when dispatched as a sub-agent: exactly one call when the
  `advisor` tool is listed, after the last TASKS or PROCESS step and before
  the OUTPUT, whatever the harness prompt schedules; tool not listed or call
  erroring → proceed, no retry. Advice may point you back to
  the code; every OUTPUT line rests on what you read, never on the advice
  alone. Advice proposing a design or a fix counts only where the brief
  asks for a fix. Dispatched, end the OUTPUT with the `ADVISOR:` line:
  `changed:` names what the advice sent you back to read; `not called`
  when the tool is not listed or the call errored.
```

- [ ] **Step 7: `hooks/subagent-advisor.sh`**

Replace
```
msg="$msg own instructions are never an allowance. When allowed: at most"
msg="$msg once, before your verdict or report."
```
with
```
msg="$msg own instructions are never an allowance. When allowed: exactly"
msg="$msg one call, before your verdict or report."
```

- [ ] **Step 8: review briefs in `skills/ship-feature/SKILL.md` and `skills/init-project/SKILL.md`**

In both files replace
```
Add to its brief: "you may call the `advisor` tool once, before your
verdict" (code review, BDR-150). Fix every CRITICAL or Important finding
```
with
```
Add to its brief: "make exactly one `advisor` call when the tool is
listed, before your verdict, and end your report with one line:
`ADVISOR: changed: <what> | no change | not called (absent | error)`"
(code review, BDR-150). Fix every CRITICAL or Important finding
```

- [ ] **Step 9: `lib/effort-shift.md`**

Replace
```
STEP 10, a standalone subagent-driven-development final review) call it
at most once per dispatch, before their verdict or report; executors and
every other sub-agent never call it, even when the tool is listed. The
rule rides each sub-agent's own text: the allowed agents' prompts, a
`never call` line in the other opus-served agents and the opus briefs we
write (a brief sending a general-purpose agent to opus says which rule
applies; a code review's says it may call once), and, for every spawn
including built-ins such as `Plan`, the SubagentStart hook
```
with
```
STEP 10, a standalone subagent-driven-development final review) make
exactly one call per dispatch when the tool is listed, before their
verdict or report, and put an `ADVISOR:` effect line in that report;
executors and every other sub-agent never call it, even when the tool is
listed. The rule rides each sub-agent's own text: the allowed agents'
prompts, a `never call` line in the other opus-served agents and the
opus briefs we write (a brief sending a general-purpose agent to opus
says which rule applies; a code review's asks for the one call and the
line), and, for every spawn including built-ins such as `Plan`, the
SubagentStart hook
```
The next two lines stay as they are:
```
hooks/subagent-advisor.sh. A skill run by a sub-agent reads
`not called (sub-agent)` in its `Advisor:` row.
```

The paragraph runs on for five more lines and ends with the line `file loaded inline by the main loop follows the main-loop points.` Right after that line (and before the blank line that precedes `Advisor absent or erroring`), add a blank line and this paragraph:
```
Effect line. An advisor trace says what the call changed, in one
grammar: `changed: <what>` | `no change` | `not called (<reason>)`.
A sub-agent's report carries
`ADVISOR: changed: <what> | no change | not called (absent | error)`;
the line is a trace for the transcript tally, never a gate: a report
without it stands.
```

- [ ] **Step 10: `CLAUDE.global.md`**

Replace
```
  verifier, security-auditor, `analyzer` and an opus code review at most
```
with
```
  verifier, security-auditor, `analyzer` and an opus code review exactly
```

Replace these 2 lines
```
- subagent-driven-development standalone: workers sonnet (task reviews and
  fix rounds too); final review opus, its brief allowing one `advisor` call
```
with these 2 lines
```
- subagent-driven-development standalone: workers sonnet (task reviews, fix
  rounds); final review opus, brief asks one `advisor` call + `ADVISOR:` line
```

Run: `wc -l CLAUDE.global.md`
Expected: `320 CLAUDE.global.md`

- [ ] **Step 11: Suite green, shellcheck clean, leftovers census**

Run: `make test suite=lib/tests/subagent-advisor.test.sh 2>&1 | tail -5`
Expected: `subagent-advisor: <n> pass, 0 fail` then `all suites green`.

Run: `shellcheck hooks/subagent-advisor.sh lib/tests/subagent-advisor.test.sh && echo clean`
Expected: `clean`

Run:
```bash
git grep -n -e 'one call allowed' -e 'tool once, before' -e 'allowing one' \
  -e 'may call once' -- agents skills lib hooks mods CLAUDE.global.md \
  ':!lib/tests'
```
Expected: no output. Any hit is a citer of the old rule: reword it to the new rule in this same commit, or stop and report it if its meaning is unclear.

- [ ] **Step 12: Full suite**

Run: `make test 2>&1 | tail -3`
Expected: last line `all suites green`. A red suite other than the one edited here means another lock held one of the changed lines: read its FAIL line, fix the text or the lock so both say the new rule, re-run.

- [ ] **Step 13: Commit**

```bash
git add lib/tests/subagent-advisor.test.sh agents/plan-challenger.md \
  agents/verifier.md agents/security-auditor.md agents/analyzer.md \
  hooks/subagent-advisor.sh skills/ship-feature/SKILL.md \
  skills/init-project/SKILL.md lib/effort-shift.md CLAUDE.global.md
git commit -m "feat(doctrine): allowed sub-agents call the advisor exactly once" \
  -m "Challenger, verifier, security auditor, dispatched analyzer and the opus code review make one advisor call when it is listed and end their report with an ADVISOR effect line."
```

---

### Task 2: Two main-loop advisor calls per challenge, synthesis kept in the loop, effect on every main-loop line

**Files:**
- Test: `lib/tests/subagent-advisor.test.sh`, `mods/model-router/hooks/register.test.ts`
- Modify: `lib/challenge-plan.md`, `lib/effort-shift.md`, `agents/plan-challenger.md`, `CLAUDE.global.md`, `skills/hotfix/SKILL.md`, `skills/feat/SKILL.md`, `skills/bugfix/SKILL.md`, `skills/a11y/SKILL.md`, `skills/guardrails/SKILL.md`, `skills/ship-feature/SKILL.md`, `skills/init-project/SKILL.md`, `skills/audit-delta/SKILL.md`, `skills/tour/SKILL.md`, `skills/release-candidate/SKILL.md`, `mods/model-router/hooks/register.ts`

**Interfaces:**
- Consumes: the `Effect line.` paragraph Task 1 added to `lib/effort-shift.md`.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Update the locks (they must fail first)**

In `lib/tests/subagent-advisor.test.sh` replace
```
  'A skill run inside a sub-agent skips this call')" yes
```
with
```
  'A skill run inside a sub-agent skips both calls')" yes
```

Insert this block just before the line `echo "subagent-advisor: $pass pass, $fail fail"`:
```bash
# two main-loop calls per challenge, synthesis kept in the loop, effect
# on every main-loop line (user decisions 2026-11-26)
check T25-synthesis-call "$(has lib/challenge-plan.md \
  '**Advisor on the first synthesis (main loop).**')" yes
check T25b-none-after "$(has lib/challenge-plan.md \
  'No call after the confirmation pass.')" yes
check T26-no-handoff "$(has lib/challenge-plan.md \
  'or deferred, and the named change that closes it, are never handed to')" yes
check T27-mirror "$(has agents/plan-challenger.md \
  'ADVISOR ON THE SYNTHESIS (main loop)')" yes
check T27b-mirror-skip "$(has agents/plan-challenger.md \
  'never enters a challenger brief. A skill run inside a sub-agent skips it')" yes
check T25c-due-anyway "$(has lib/challenge-plan.md \
  'This call is due whatever earlier call the run made.')" yes
check T25d-two-part-row "$(has lib/challenge-plan.md \
  "two parts, \`plan: <value>; synthesis: <value>\`.")" yes
check T28-effort-point1 "$(has lib/effort-shift.md \
  'challengers see it, and on the plan after the first synthesis')" yes
check T28b-every-point "$(has CLAUDE.global.md 'at every point of')" yes
check T28c-effort-header "$(has lib/effort-shift.md \
  'Main loop, a call at each of these points when the tool is listed')" yes
check T29-hotfix-field "$(has skills/hotfix/SKILL.md \
  'ADVISOR : <changed: <what> | no change | not called (absent | error)>')" yes
check T29b-hotfix-cosmetic "$(has skills/hotfix/SKILL.md \
  "A skipped challenge still makes the run's advisor call here")" yes
for s in feat bugfix; do
  check "T30 $s field" "$(has "skills/$s/SKILL.md" \
    ': <changed: <what> | no change | skipped (gates clean on first pass) | not called (absent | error)>')" yes
done
for s in a11y guardrails ship-feature init-project audit-delta tour \
  release-candidate; do
  check "T31 $s effect" "$(has "skills/$s/SKILL.md" \
    "\`no change\` or \`not called (<reason>)\`) goes")" yes
done
check T31b-no-old-answer "$(cd "$ROOT" && git grep -c 'Advisor); its answer' \
  -- skills | wc -l | tr -d ' ')" 0
check T32-router-note "$(has mods/model-router/hooks/register.ts \
  'a challenge step makes its own calls')" yes

```

In `mods/model-router/hooks/register.test.ts`, in the test `'advisor note: a main feat load carries it'`, add one line after `expect(body.startsWith(NOTE)).toBe(true)`:
```ts
  expect(body).toContain('a challenge step makes its own calls')
```

- [ ] **Step 2: Run the suite, confirm it is red**

Run: `make test suite=lib/tests/subagent-advisor.test.sh 2>&1 | tail -30`
Expected: `FAIL` lines for T19, T25, T25b, T25c, T25d, T26, T27, T27b, T28, T28b, T28c, T29, T29b, T30 (2), T31 (7), T31b, T32; then the summary `1 suite(s) red: lib/tests/subagent-advisor.test.sh`.

Run: `make test suite=lib/tests/mods.test.sh 2>&1 | tail -8`
Expected: either a failure naming `model-router: plugin test` (the new `toContain` is red), or a line starting `SKIP: claude plugin test unavailable`. On SKIP the TypeScript lock does not run on this machine: say so in your report; lock T32 is then the proof of the note.

- [ ] **Step 3: `lib/challenge-plan.md`**

Replace
```
The main loop's advisor call before the dispatch (below) is the costliest
single item: once per skill run.
```
with
```
The main loop's advisor calls (below) are the costliest items: one before
the dispatch, one on the first synthesis when a lens found a BLOCKER or MAJOR.
```

Replace
```
**Advisor first (main loop).** Before the first dispatch, with no main-loop
advisor call since the skill run started (so at most once per skill run, not
before a re-challenge), the main loop reads the `PLAN` file unless its full
```
with
```
**Advisor first (main loop).** Before the first dispatch, with no main-loop
advisor call since the skill run started (never
before a re-challenge), the main loop reads the `PLAN` file unless its full
```

Replace
```
dispatch as written. A skill run inside a sub-agent skips this call (its
```
with
```
dispatch as written. A skill run inside a sub-agent skips both calls (its
```

In `## SYNTHESIZE + RE-THINK`, insert this bullet between the bullet that starts `- **RE-THINK the aspect the challenge pointed at.**` and the bullet that starts `- **Re-challenge once if the plan materially changed**`:
```
- **Advisor on the first synthesis (main loop).** When any lens of the
  first pass returned a BLOCKER or a MAJOR, once every finding is accepted,
  dropped or deferred (the `PLAN` revised and re-persisted where a change
  was accepted) and before any confirmation challenger, the main loop calls
  the advisor on the plan and its synthesis decisions, when the tool is
  listed. This call is due whatever earlier call the run made. An answer
  that lands a real flaw revises the `PLAN` again, as plain plan text. All
  lenses SOLID: no call. No call after the confirmation pass. Absent or
  erroring → go on. The advice never enters a challenger brief.
```

After the last bullet of that section (it ends `  below.`) and before `## OUTPUT`, add a blank line and:
```
The synthesis is this loop's own work. Which finding is accepted, dropped
or deferred, and the named change that closes it, are never handed to
another agent. Applying changes already decided to a long plan file may be
dispatched as drafting: general-purpose, `model: "sonnet"`, a brief that
lists each decided change (`lib/model-gate.md`, dispatch tiers); the loop
then re-reads each decided change in the file before the next step.
```

Replace
```
  row, added to whatever summary template the caller prints: each plan
  change an advisor answer drove, `called, no change`, or
  `not called (absent | error | already called this run | sub-agent)`.
```
with
```
  row, added to whatever summary template the caller prints, covering both
  calls (plan, synthesis): each plan change an advisor answer drove and
  which call drove it, `called, no change`, or
  `not called (absent | error | already called this run | sub-agent)`;
  a synthesis call that was not due reads `not called (all SOLID)`.
  Whatever single slot a caller's template shows, the row is printed in
  two parts, `plan: <value>; synthesis: <value>`.
```

- [ ] **Step 4: `lib/effort-shift.md`**

Replace
```
Main loop, at least at these points (for work outside them, see the
triggers in CLAUDE.global.md § Workflow):
```
with
```
Main loop, a call at each of these points when the tool is listed (for
work outside them, see the triggers in CLAUDE.global.md § Workflow):
```

Replace
```
1. Before settling an approach: on the written plan, before the
   challengers see it (`lib/challenge-plan.md`), at most once per skill run;
   skipped with the challenge for a placed decision (`lib/challenge-plan.md` § SKIP).
```
with
```
1. Before settling an approach: on the written plan, before the
   challengers see it, and on the plan after the first synthesis
   when a lens returned a BLOCKER or a MAJOR (`lib/challenge-plan.md`);
   none after the confirmation pass; both
   skipped with the challenge for a placed decision (`lib/challenge-plan.md` § SKIP).
```

In the `Effect line.` paragraph (added by Task 1), replace
```
the line is a trace for the transcript tally, never a gate: a report
without it stands.
```
with
```
the line is a trace for the transcript tally, never a gate: a report
without it stands. The main loop's `ADVISOR` fields and end-of-run
`Advisor:` lines use the same grammar, plus their `skipped (<reason>)`
values; the CHALLENGE SUMMARY row keeps its own (`lib/challenge-plan.md`).
```

- [ ] **Step 5: `agents/plan-challenger.md` (protocol mirror)**

In `## ORCHESTRATOR PROTOCOL`, insert these two bullets between the bullet that starts `- CLOSE each BLOCKER with a NAMED, diffable plan change` and the bullet that starts `- RE-CHALLENGE ONCE if synthesis materially changed the plan`:
```
- ADVISOR ON THE SYNTHESIS (main loop): when a lens returned a BLOCKER or
  a MAJOR, once the first synthesis is done the main loop calls the advisor
  once more, when the tool is listed, before any confirmation challenger;
  none after the confirmation pass; absent or erroring → go on. The advice
  never enters a challenger brief. A skill run inside a sub-agent skips it
  (`lib/challenge-plan.md`, SYNTHESIZE step).
- THE SYNTHESIS STAYS IN THE LOOP: accepting, dropping or deferring a
  finding, and the plan change that closes it, are never handed to another
  agent (`lib/challenge-plan.md`, SYNTHESIZE step).
```

- [ ] **Step 6: `CLAUDE.global.md`**

Replace
```
  `advisorModel`, Fable, set by /advisor), at least at the points of
```
with
```
  `advisorModel`, Fable, set by /advisor), at every point of
```

Run: `wc -l CLAUDE.global.md`
Expected: `320 CLAUDE.global.md`

- [ ] **Step 7: `skills/hotfix/SKILL.md`**

In `## STEP 1.8`, replace
```
missing import that alters execution. In doubt → it is probably a `/bugfix`.
```
with
```
missing import that alters execution. In doubt → it is probably a `/bugfix`.
A skipped challenge still makes the run's advisor call here, on the located
fix, when the tool is listed (`lib/effort-shift.md` § Advisor). The
summary's `ADVISOR` field carries each call of the run (a challenged fix
prints `plan: …; synthesis: …`).
```

In the HOTFIX APPLIED block, replace
```
   SECURITY: <PASS | DEGRADED (checklist only)>
```
with
```
   SECURITY: <PASS | DEGRADED (checklist only)>
   ADVISOR : <changed: <what> | no change | not called (absent | error)>
```

- [ ] **Step 8: `skills/feat/SKILL.md` and `skills/bugfix/SKILL.md`**

`skills/feat/SKILL.md`: replace
```
"long task before calling it done" trigger. The answer, or the skip,
```
with
```
"long task before calling it done" trigger. What it changed, or the skip,
```
and replace
```
ADVISOR  : <one-line answer | skipped (gates clean on first pass) | not called (absent | error)>
```
with
```
ADVISOR  : <changed: <what> | no change | skipped (gates clean on first pass) | not called (absent | error)>
```

`skills/bugfix/SKILL.md`: replace
```
   "long task before calling it done" trigger. The answer, or the skip,
```
with
```
   "long task before calling it done" trigger. What it changed, or the skip,
```
and replace
```
   ADVISOR    : <one-line answer | skipped (gates clean on first pass) | not called (absent | error)>
```
with
```
   ADVISOR    : <changed: <what> | no change | skipped (gates clean on first pass) | not called (absent | error)>
```

- [ ] **Step 9: the seven end-of-run lines**

`skills/a11y/SKILL.md` and `skills/guardrails/SKILL.md` (same text in both): replace
```
   end-of-run advisor call (`lib/effort-shift.md` § Advisor); its answer
   goes into the reply as an `Advisor:` line, and a fix it drives goes
```
with
```
   end-of-run advisor call (`lib/effort-shift.md` § Advisor); its effect
   (`changed: <what>`, `no change` or `not called (<reason>)`) goes
   into the reply as an `Advisor:` line, and a fix it drives goes
```

`skills/ship-feature/SKILL.md` and `skills/init-project/SKILL.md` (same text in both): replace
```
its answer goes with the proposal as an `Advisor:` line, and a fix it
```
with
```
its effect (`changed: <what>`, `no change` or `not called (<reason>)`) goes
with the proposal as an `Advisor:` line, and a fix it
```

`skills/audit-delta/SKILL.md` and `skills/tour/SKILL.md` (same text in both): replace
```
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its answer
goes into the summary as an `Advisor:` line, and a fix it calls for
```
with
```
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its effect
(`changed: <what>`, `no change` or `not called (<reason>)`) goes
into the summary as an `Advisor:` line, and a fix it calls for
```

`skills/release-candidate/SKILL.md`: replace
```
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its answer
goes with the ask as an `Advisor:` line, and a fix it calls for makes
```
with
```
end-of-run advisor call (`lib/effort-shift.md` § Advisor); its effect
(`changed: <what>`, `no change` or `not called (<reason>)`) goes
with the ask as an `Advisor:` line, and a fix it calls for makes
```

Do not touch the lines that follow each block (`back through the gates. A later merge proposal reuses this …`): other suites lock them.

- [ ] **Step 10: `mods/model-router/hooks/register.ts`**

In the `ADVISOR_NOTE` constant replace
```
  'or reports. A call this run already made at an advisor point counts. ' +
```
with
```
  'or reports. A call this run already made at an advisor point counts; ' +
  'a challenge step makes its own calls (`challenge-plan.md`). ' +
```

- [ ] **Step 11: Suites green**

Run: `make test suite=lib/tests/subagent-advisor.test.sh 2>&1 | tail -5`
Expected: `subagent-advisor: <n> pass, 0 fail` then `all suites green`.

Run: `make test suite=lib/tests/mods.test.sh 2>&1 | tail -8`
Expected: a line containing `model-router: plugin test passed`, then `all suites green`. A `SKIP: claude plugin test unavailable` line means the TypeScript test did not run: report it as not verified by that suite (T32 still proves the note text).

Run: `shellcheck lib/tests/subagent-advisor.test.sh && echo clean`
Expected: `clean`

Run:
```bash
git grep -n -e 'its answer goes' -e 'one-line answer' \
  -e 'The answer, or the skip' -e 'at least at the points' \
  -e 'skips this call' -e 'at most once per skill run' \
  -- agents skills lib hooks mods CLAUDE.global.md ':!lib/tests'
```
Expected: no output.

- [ ] **Step 12: Full suite**

Run: `make test 2>&1 | tail -3`
Expected: last line `all suites green`.

- [ ] **Step 13: Commit**

```bash
git add lib/tests/subagent-advisor.test.sh \
  mods/model-router/hooks/register.ts mods/model-router/hooks/register.test.ts \
  lib/challenge-plan.md lib/effort-shift.md agents/plan-challenger.md \
  CLAUDE.global.md skills/hotfix/SKILL.md skills/feat/SKILL.md \
  skills/bugfix/SKILL.md skills/a11y/SKILL.md skills/guardrails/SKILL.md \
  skills/ship-feature/SKILL.md skills/init-project/SKILL.md \
  skills/audit-delta/SKILL.md skills/tour/SKILL.md \
  skills/release-candidate/SKILL.md
git commit -m "feat(doctrine): advisor on the plan and on its first synthesis" \
  -m "A challenged plan gets a second main-loop advisor call after the first synthesis, which never leaves the loop. Hotfix calls on every run. Every advisor line states what the call changed."
```

---

### Task 3: Untyped dispatches by nature, SDD final review on sonnet, session note, tripwires

**Files:**
- Test: `lib/tests/model-routing.test.sh`, `lib/tests/subagent-advisor.test.sh`
- Modify: `lib/model-gate.md`, `CLAUDE.global.md`, `skills/ship-feature/SKILL.md`, `skills/init-project/SKILL.md`, `skills/audit-delta/SKILL.md`, `lib/effort-shift.md`, `.claude/tasks/TODO.md`

**Interfaces:**
- Consumes: `CLAUDE.global.md` as Tasks 1 and 2 left it (advisor bullet says `exactly` and `at every point of`).
- Produces: nothing.

- [ ] **Step 1: Update the locks (they must fail first)**

In `lib/tests/model-routing.test.sh`, insert this block just before the line `printf 'model-routing census: %d pass, %d fail\n' "$pass" "$fail"`:
```bash
# 14) untyped dispatch by nature; SDD final review on sonnet under an
#     orchestrator (user decisions 2026-11-26; BDR-084 exception kept)
has "lib/model-gate.md" 'chosen by the nature of the work, never by the session model'
has "lib/model-gate.md" 'fixes, HTML mockups, writing, plan drafting'
has "lib/model-gate.md" 'the tour multi-project runner carries no model'
has "CLAUDE.global.md" "Untyped dispatch (general-purpose, bar /tour's runner): explicit"
has "CLAUDE.global.md" 'judgment opus; fixes, mockups, writing, collection sonnet; probes haiku'
# shellcheck disable=SC2016  # literal backticks — no expansion intended
has "skills/audit-delta/SKILL.md" 'else general-purpose with `model: "opus"`'
for s in ship-feature init-project; do
  has "skills/$s/SKILL.md" "This includes SDD's final whole-branch review"
done
has "skills/ship-feature/SKILL.md" 'draft or prototype of plan tasks is a general-purpose dispatch'
has "lib/effort-shift.md" 'under ship-feature and init-project the final whole-branch review is one'

```

In `lib/tests/subagent-advisor.test.sh`, insert just before the line `echo "subagent-advisor: $pass pass, $fail fail"`:
```bash
check T33-session-note "$(has lib/effort-shift.md \
  "Type \`/advisor\` in such a session, or relaunch it.")" yes

```

- [ ] **Step 2: Run both suites, confirm they are red**

Run: `make test suite=lib/tests/model-routing.test.sh 2>&1 | tail -12`
Expected: failures naming the ten new strings; then the summary `1 suite(s) red: lib/tests/model-routing.test.sh`.

Run: `make test suite=lib/tests/subagent-advisor.test.sh 2>&1 | tail -4`
Expected: `FAIL T33-session-note`; then the summary `1 suite(s) red: lib/tests/subagent-advisor.test.sh`.

- [ ] **Step 3: `lib/model-gate.md`**

Replace
```
(general-purpose / Explore / Plan) carry an explicit `model=` at every call
site, its tier: `model: "opus"` = skill-runners (the child reflects or
orchestrates for the main loop) and dispatched judgment, sonnet = execution,
haiku = mechanical probes; never fable (BDR-150, the advisor). A built-in
judgment dispatch also carries an explicit `effort=` (`lib/effort-shift.md`).
```
with
```
(general-purpose / Explore / Plan) carry an explicit `model=` at every call
site, chosen by the nature of the work, never by the session model:
- `model: "opus"` = skill-runners (the child reflects or orchestrates for
  the main loop) and dispatched judgment (review, verification, diagnosis);
- sonnet = execution: fixes, HTML mockups, writing, plan drafting or
  prototyping from a brief whose decisions are closed, collection;
- haiku = mechanical probes;
- never fable (BDR-150, the advisor).

One exception: the tour multi-project runner carries no model (BDR-084).
An SDD worker follows its orchestrator's pin (`lib/effort-shift.md` § Advisor).
A built-in judgment dispatch also carries an explicit `effort=` (`lib/effort-shift.md`).
```

- [ ] **Step 4: `CLAUDE.global.md` (net-zero lines)**

Replace these 7 lines
```
  the main loop calls the advisor tool when it is listed (settings
  `advisorModel`, Fable, set by /advisor), at every point of
  `~/.claude/lib/effort-shift.md` § Advisor; dispatched plan-challenger,
  verifier, security-auditor, `analyzer` and an opus code review exactly
  once, before their verdict or report; other sub-agents never (each opus
  brief you write states its rule; a SubagentStart hook restates it). Fable
  is never routed or pinned: the router tops out at opus.
```
with these 5 lines
```
  the main loop calls the advisor tool when it is listed, at every point of
  `~/.claude/lib/effort-shift.md` § Advisor; dispatched plan-challenger,
  verifier, security-auditor, `analyzer` and an opus code review exactly
  once, before their verdict or report; other sub-agents never (each opus
  brief you write states its rule). Fable is never routed or pinned.
```

In `## Workflow`, right after the `Sub-agents:` bullet and before the `Stronger model needed` bullet, replace
```
  file or other shell. Hermetic tests run through `make test [suite=…]` only.
```
with these 3 lines
```
  file or other shell. Hermetic tests run through `make test [suite=…]` only.
- Untyped dispatch (general-purpose, bar /tour's runner): explicit `model`:
  judgment opus; fixes, mockups, writing, collection sonnet; probes haiku
```

Run: `wc -l CLAUDE.global.md`
Expected: `320 CLAUDE.global.md`

- [ ] **Step 5: `skills/ship-feature/SKILL.md` and `skills/init-project/SKILL.md` (SDD final review)**

In `skills/ship-feature/SKILL.md` replace
```
call. The plan is closed; execution and plan-conformity review are sonnet
work. Reflection (task decomposition, review verdict arbitration) stays in
this loop.
```
with
```
call. The plan is closed; execution and plan-conformity review are sonnet
work. Reflection (task decomposition, review verdict arbitration) stays in
this loop.
This includes SDD's final whole-branch review, its re-reviews and its fix
rounds at any round: dispatch them on sonnet too, whatever the SDD skill's
Model Selection says about the most capable model or a tier above; the
opus craft review is STEP 6.
```

In `skills/init-project/SKILL.md` make the same replacement, with the last line reading
```
opus craft review is STEP 10.
```

- [ ] **Step 6: `skills/ship-feature/SKILL.md` (plan step)**

Replace
```
note the ID inline. Break design into tasks (2-5 min each). Each task: exact file paths, full code, verification steps.
```
with
```
note the ID inline. Break design into tasks (2-5 min each). Each task: exact file paths, full code, verification steps.
The plan's design choices are settled here, in the main loop. A delegated
draft or prototype of plan tasks is a general-purpose dispatch with
`model: "sonnet"` and a brief whose decisions are closed (`lib/model-gate.md`).
```

- [ ] **Step 7: `lib/effort-shift.md`**

Replace
```
(BDR-066), as ship-feature and init-project pin it; run standalone, its
final whole-branch review runs on opus as a code review. The analyzer
file loaded inline by the main loop follows the main-loop points.
```
with
```
(BDR-066), as ship-feature and init-project pin it;
under ship-feature and init-project the final whole-branch review is one
of those sonnet workers (their own opus code review follows); run
standalone, its final whole-branch review runs on opus as a code review.
The analyzer file loaded inline by the main loop follows the main-loop points.
```

After the paragraph that starts `Advisor absent or erroring (Fable out of credits, for example) → proceed` (it ends `at a loop cap it feeds the STOP diagnosis.`), add a blank line and:
```
A session opened before the `advisorModel` setting may never call the
Fable advisor: in the one case observed (2026-11-26) such a session made
no call in 4,390 requests. Type `/advisor` in such a session, or relaunch it.
```

- [ ] **Step 7b: `skills/audit-delta/SKILL.md`**

Replace
```
Dispatch a subagent (analyzer type if available, else general) with the
```
with
```
Dispatch a subagent (analyzer type if available, else general-purpose with `model: "opus"` and `effort="xhigh"`, its brief saying never call the `advisor` tool: an audit is judgment) with the
```

- [ ] **Step 8: `.claude/tasks/TODO.md`**

Replace the whole line that starts `- [ ] 2026-11-27 or later, after a fresh session: advisor leak behavioural check.` with this single line:
```
- [ ] After the merge of feature/advisor-mandatory-gp-routing and a fresh session: advisor behavioural check, one window for both changes (the leak fix 7979b9b and this feature). Run /memory-feedback (advisor usage table) plus a per-dispatch transcript tally since the merge (a call = a served `advisor_message` iteration, LRN-301). Tripwires, leak fix: every typed agent outside the allowed five 0 calls; sonnet and haiku callers 0; general-purpose only in code-review dispatches. Tripwires, this feature: plan-challenger, verifier, security-auditor, dispatched analyzer and opus code review make exactly 1 call per dispatch that reached its verdict where the tool is listed (0 = the "exactly one call" line not read, 2+ = over; an `ERROR` early exit is not counted) and their reports carry an `ADVISOR:` line; main loop on a challenged plan: one call before the first challenger dispatch unless the run had already called, plus one between the first synthesis and any confirmation challenger when a lens returned a BLOCKER or MAJOR (placed-decision skips and sub-agent runs excluded, end-of-run calls counted apart); SDD workers and the SDD final review under ship-feature served sonnet; no general-purpose dispatch without `model` outside /tour's runner. Revert path for this feature: revert its merge into develop (`git revert -m 1 <merge sha>`); the SubagentStart hook stays (dropping it reopens the leak). Then mark BUGS-FOUND :107 FIXED or reopen (advisor-subagent-scope, medium)
```

- [ ] **Step 9: Suites green**

Run: `make test suite=lib/tests/model-routing.test.sh 2>&1 | tail -3`
Expected: `model-routing census: <n> pass, 0 fail` then `all suites green`.

Run: `make test suite=lib/tests/subagent-advisor.test.sh 2>&1 | tail -3`
Expected: `subagent-advisor: <n> pass, 0 fail` then `all suites green`.

Run: `shellcheck lib/tests/subagent-advisor.test.sh && echo clean`
Expected: `clean` (`lib/tests/model-routing.test.sh` already carries two shellcheck notes on lines this plan does not touch: do not lint it, do not fix them).

Run: `git grep -nE 'model ?[:=] ?"fable"' -- agents skills lib ':!lib/tests'`
Expected: no output (BDR-150).

- [ ] **Step 10: Full suite**

Run: `make test 2>&1 | tail -3`
Expected: last line `all suites green`.

- [ ] **Step 11: Commit**

```bash
git add lib/tests/model-routing.test.sh lib/tests/subagent-advisor.test.sh \
  lib/model-gate.md CLAUDE.global.md skills/ship-feature/SKILL.md \
  skills/init-project/SKILL.md skills/audit-delta/SKILL.md \
  lib/effort-shift.md .claude/tasks/TODO.md
git commit -m "feat(doctrine): untyped sub-agents take their model from the work" \
  -m "General-purpose dispatches always name a model: judgment on opus, fixes, mockups, writing and collection on sonnet, probes on haiku. Under an orchestrator the SDD final review runs on sonnet."
```
