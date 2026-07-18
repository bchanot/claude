---
name: hotfix
description: |
  Quick fix for superficial bugs: typos, CSS issues, config errors,
  off-by-one, wrong variable name, missing import, broken link.
  Use when the root cause is obvious and the fix is 1-2 files max.
  Trigger: "hotfix", "quick fix", "typo", "fix this small thing",
  "c'est juste un petit bug", "patch rapide".
  Do NOT use for bugs requiring investigation — use /bugfix instead.
argument-hint: <bug description or error message>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
---

# /hotfix — quick-fix orchestrator (reflection inline, execution dispatched)

MODEL GATE (blocking): run `$HOME/.claude/lib/model-gate.md` BEFORE any
step below. Verdict `small` → STOP — print the gate's remedy, end the
turn, dispatch nothing.

## REQUEST
$ARGUMENTS

---

## STEP 1 — LOCATE (reflection)

Find the bug. Use the description and any error message to go
straight to the source:

```bash
git status
git log --oneline -3
```

- Read the relevant file(s). Confirm the root cause is obvious
  and superficial (typo, wrong value, missing import, etc.).
- If the bug turns out to be deeper than expected (unclear cause,
  multiple files involved, logic error): STOP and say:
  "This looks deeper than a hotfix — it needs investigation. Re-run this
  as `/bugfix` (root-cause investigation, then a scoped fix)."
- Settle the proposed fix HERE — the executor cannot ask questions, so the
  exact edit (what changes, in which file(s)) must be closed before dispatch.

OPTIONAL — memory check (exempt by default; hotfix = obvious fix, mirror of its capitalize
skip). For a RECURRING or urgent bug only, a quick blockers-only glance may save time:

      [ -d .claude/memory ] && grep -nE '^## BLK-' .claude/memory/blockers.md   # "déjà vu ?"

If a prior BLK names this bug, jump to its solution. Not mandatory; no RELATED MEMORY
disposition required at hotfix weight.

## STEP 1.5 — DESIGN GATE

Follow `$HOME/.claude/lib/design-gate.md`:
- Scan $ARGUMENTS and target files for design/UI/style signals (CSS, component, styling, animation).
- If signals found → run `design-tool-gate.sh`; if it reports INCOMPLETE,
  tell the user to run `/profile design` before proceeding.
- If no signals → skip (zero overhead).

## STEP 1.7 — CONTRACT (silent autofill)

Run `$HOME/.claude/lib/contract-interview.md` at hotfix weight: **zero
questions ever** (a hotfix is an obvious fix by definition). Autofill the
contract — REQUEST verbatim = the bug description as given; ACCEPTANCE
CRITERIA = "symptom gone; build/tests green"; FILE SCOPE = the 1-2 target
files from STEP 1. It writes `.claude/tasks/contracts/<date>-<slug>-<HHMM>.md`.
This is the reference the executor reads first, and the scope for STEP 4's
security gate and the escalation report if a gate fails. No verifier is
dispatched at hotfix weight — STEP 4's smoke result already verifies these
trivial criteria; the gate hotfix adds is security (STEP 4).

## STEP 1.8 — CHALLENGE THE FIX (logic fixes only)
GUARD — this is the one place the plan-challenge phase is kept proportionate to
hotfix's speed. SKIP entirely for a purely cosmetic fix (CSS value, copy/typo, a
broken link): there is nothing for three lenses to bite on, and speed is the
point. Run it ONLY when the settled fix touches control flow or behaviour — an
off-by-one, a wrong operator/variable, a behaviour-changing config value, or a
missing import that alters execution. In doubt → it is probably a `/bugfix`.

For a logic fix: persist the STEP 1 located fix (root cause + the exact edit) to
`.claude/tasks/plans/<date>-<slug>-<HHMM>.md`, then run
`$HOME/.claude/lib/challenge-plan.md` with `PLAN` = that file, `KIND` =
`build-plan`, `SCOPE` = the 1-2 target files, `CONSTRAINTS` = the STEP 1.7
contract's acceptance criteria. Three blind challengers attack the fix; the main
loop RE-THINKS any aspect a BLOCKER lands (a named change to the fix, or
`[deferred]`) and re-challenges once if it materially changed. Print a
CHALLENGE SUMMARY (BLOCKERs addressed / deferred / lenses returned). A BLOCKER
that shows the fix is wrong or incomplete means this was never
a hotfix — escalate to `/bugfix` (its STEP 3b runs the same phase under the full
verify+secure loop).

## STEP 2 — PRE-FLIGHT

**Gitflow aiguillage (before dispatch):** follow `$HOME/.claude/lib/gitflow-aiguillage.md`
— your type = `hotfix`. On `main`/`develop` it branches first; on a working
branch it's a no-op (commit in place). Never `finish`.

Snapshot current state so revert is possible:

```bash
git diff HEAD --stat   # confirm working tree is clean OR carries only the
                       # in-progress hotfix area; if unrelated dirty files are
                       # present, ask user whether to stash them first
git rev-parse HEAD     # capture the SHA to revert to on failure
```

If the working tree contains unrelated uncommitted changes the user has not
mentioned: STOP and ask `"working tree dirty: stash and continue, or abort?"`.

## STEP 3 — DISPATCH EXECUTOR

Dispatch the executor — sonnet by frontmatter pin, do not override:

```
Agent(subagent_type="hotfixer")
prompt: "CONTRACT: <path from STEP 1.7>
LOCATED: <file(s) found in STEP 1 + the confirmed root cause>
FIX: <the proposed minimal fix, closed in STEP 1>
BRANCH: <current branch — verify with git branch --show-current, never switch>
Apply the minimal fix. No refactoring, no commit, no branch ops, no
security dispatch, no revert. Finish with the HOTFIX-EXEC REPORT."
```

Parse the `HOTFIX-EXEC REPORT`:
- `STATUS : DONE` → STEP 4 (the SMOKE line in the report decides pass/fail
  there; DONE here means execution completed, not that it verified clean).
- `STATUS : BLOCKED` → if any edits were made, `git restore .` to the
  pre-flight SHA (STEP 2); surface the blocker to the user; STOP. One
  attempt only — hotfix never re-dispatches (escalate to `/bugfix` for
  deeper work).

## STEP 4 — VERIFY + SECURE + COMMIT (main loop, LRN-083)

1. Read the SMOKE line from the executor's report. **Failure branch** — if
   it reports a failing test/build result:
   - Print the failure output verbatim (under 30 lines).
   - Run `git restore .` to revert the working-tree edits to the pre-flight
     SHA (STEP 2). (Files were not yet staged — restore is safe.)
   - STOP and tell user: `"Hotfix introduced a regression. Reverted.
     Escalate to /bugfix or /analyze for deeper investigation."`
   - Do NOT commit a broken fix.
2. **Security gate (fresh auditor) — failure REVERTS, never loops.** Dispatch
   a FRESH security-auditor (`subagent_type: security-auditor`, or load
   `agents/security-auditor.md`) with `MODE: gate`, `SCOPE:` the working-tree
   diff vs the pre-flight SHA. Parse its `SECURITY — VERDICT:` line:
   - `PASS` (or `DEGRADED` with no BLOCK) → proceed to commit.
   - `BLOCK(n)` → this is hotfix: do NOT loop. Run `git restore .` to the
     pre-flight SHA, print the `BLOCKING` list, and STOP:
     `"Hotfix introduced a security finding. Reverted. Escalate to /bugfix
     for a fix under the full verify+security loop."` The hotfix model is
     one attempt; any gate failure (smoke OR security) reverts and escalates.
   - Structural failure (mute / unparsable / no VERDICT line) → treat as a
     failed gate: retry ONCE fresh; a 2nd structural failure → revert +
     escalate. A mute auditor is never a PASS.
3. Commit using conventional format (only after smoke AND security pass):
   ```
   fix(<scope>): <what was wrong>
   ```
4. Print summary:
   ```
   HOTFIX APPLIED
   FILE(S) : <changed files>
   FIX     : <one-line description>
   VERIFIED: <test name or smoke check that passed>
   SECURITY: <PASS | DEGRADED (checklist only)>
   ```

## STEP 5 — DOC SYNC (automatic)

Load `$HOME/.claude/agents/doc-syncer.md`.
Execute in automatic mode:
`auto-mode scope: <list of files modified during this session>`

**Then commit the docs** — follow `$HOME/.claude/lib/doc-commit.md`: it surgically commits
ONLY the files doc-syncer patched (its `PATCHED_FILES` output), never `git add -A`, never
`.claude/`/`CLAUDE.md` (rc 4 = a loud BDR-022 anomaly, not a silent skip), and no-ops when
nothing was patched — the common case for a trivial hotfix. No FINISH in an inline flow, so
it just commits the docs on the current branch (no ordering concern).

## STEP 6 — CAPITALIZE (memory registries, lightweight)

Hotfixes are often trivial (typo, config, import) — skip by default. But if the fix revealed something non-obvious:

- Wrong default that should never have been merged → propose `LRN-XXX` in `.claude/memory/learnings.md`.
- Bug that cost real time to locate despite being "superficial" → propose `BLK-XXX` in `.claude/memory/blockers.md` (status: resolved).

Default behaviour: `CAPITALIZE: hotfix trivial, skip` (no prompt, no output).
Ask the user only when there is an actual candidate to propose.

Always append a 1-line entry to today's heading in `.claude/memory/journal.md` (even trivial hotfix — journal is timeline, not signal).

**Language rule**: the journal line and any proposed BLK/LRN entries are ALWAYS written in English (see CLAUDE.md "Memory registries" § Language).

**Then commit the memory** — follow `$HOME/.claude/lib/capitalize-commit.md`: it
surgically commits what capitalize just wrote (`.claude/memory` + `.claude/tasks`
only, never `git add -A`) as one `chore(memory)` commit, reports the memory-commit
hash, and no-ops if nothing was written. The always-on journal line means a
trivial hotfix still produces a `chore(memory): journal — …` commit (Frame 2 / F3).

---

## RULES
- Max 2 files changed. If more needed → `/bugfix`.
- Reflection (LOCATE, contract, gate decisions) NEVER leaves this main
  loop; execution NEVER stays in it — the executor is the sonnet-pinned
  hotfixer subagent (BDR-066).
- The executor is dispatched FRESH, once — hotfix never re-dispatches (no
  decision round-trips; a blocked or failed attempt reverts and escalates
  to `/bugfix`, it does not retry).
- Design gate only if CSS/style signals detected. See STEP 1.5.
- **Revert-not-loop preserved**: smoke FAIL or security BLOCK → `git
  restore .` to the pre-flight SHA + STOP + escalate to `/bugfix`; hotfix
  never loops. No verifier is dispatched at hotfix weight.
- If root cause is unclear → escalate to `/bugfix` (STEP 1).
- If fix touches >5 lines of logic → reconsider if this is
  truly a hotfix.
