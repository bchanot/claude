---
name: ship-feature
description: Ship feature end-to-end: design → plan → implement (TDD) → review → finish
argument-hint: <feature description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: SHIP FEATURE

## REQUEST
$ARGUMENTS

---

## STEP 0 — PLUGIN CHECK + AUTO-ACTIVATE
Load `$HOME/.claude/agents/plugin-advisor.md`. Feed request.
- ACTION REQUIRED → show RECOMMENDATIONS block, offer: A) fix plugins B) type "force". STOP.
- PROPOSED CHANGES exist → show list, ask "Apply? (yes / no / customize)". Apply on confirm.
- OK → `✅ Plugin check passed — [active plugins] — complexity: <score>%`, continue.

## STEP 0b — PROJECT CONTEXT CHECK
Verify the project has a `CLAUDE.md` and print a brief orientation summary:
```bash
ls CLAUDE.md .claude/CLAUDE.md 2>/dev/null | head -1
git branch --show-current 2>/dev/null || echo "not a git repo"
git log --oneline -3 --format="%h %<(50,trunc)%s" 2>/dev/null || true
ls .gsd/ROADMAP.md 2>/dev/null | head -1
```
- **CLAUDE.md found** → read it silently, then print orientation header (informational, not a gate):
  ```
  📋 PROJECT CONTEXT
  Project : <name from CLAUDE.md>
  Stack   : <stack from CLAUDE.md>
  Branch  : <current git branch>
  Recent  : <last 3 commit messages>
  GSD     : <current milestone if .gsd/ROADMAP.md exists, else "not initialized">
  ```
  Continue to STEP 1.
- **Not found** →
  Print: "⚠️ No CLAUDE.md found in this directory.
  This project has not been onboarded into claude-config.
  Run `/onboard` first to generate CLAUDE.md and project settings,
  then re-run `/ship-feature`."
  STOP.

## STEP 0c — CTX7 CACHE CHECK (if fast-libs in project)
Check if the project uses fast-evolving libs (scan `package.json` for next, react, prisma, supabase, drizzle, expo):
1. If `.ctx7-cache/` exists with recent files (<7 days old) → print `📚 ctx7 cache found: <libs>` and continue.
2. If `.ctx7-cache/` missing or stale AND `ctx7` is installed AND fast-libs detected:
   ```bash
   mkdir -p .ctx7-cache
   # Fetch docs for each detected fast-lib (adapt to actual deps):
   ctx7 docs /vercel/next.js "app router middleware routing" > .ctx7-cache/nextjs-core.md 2>/dev/null || true
   ctx7 docs /prisma/prisma "schema client queries" > .ctx7-cache/prisma-core.md 2>/dev/null || true
   ```
   Print: `📚 ctx7 docs pre-fetched for: <libs>`
3. If no fast-libs or `ctx7` not installed → skip silently.

During implementation (STEP 4), when making decisions about fast-lib APIs:
- Read the relevant `.ctx7-cache/<lib>.md` file before writing code.
- This avoids repeated ctx7 calls and keeps docs available without context cost.

## STEP 1 — BRAINSTORM
Invoke `superpowers:brainstorming`. Refine request into validated design via Socratic questioning. Don't proceed until design approved.

## STEP 2 — PLAN
Invoke `superpowers:writing-plans`. Break design into tasks (2-5 min each). Each task: exact file paths, full code, verification steps.

## STEP 3 — VALIDATION GATE ★ MANDATORY STOP
```
SHIP FEATURE — VALIDATION GATE
FEATURE: <n> | TASKS: <count>
<numbered task list>
Approve and execute? (yes / request changes)
```
Changes → back to STEP 2. Approved → continue.

## STEP 4 — IMPLEMENT
Invoke `superpowers:subagent-driven-development`. Isolated subagents. 2-stage review per task: spec compliance → code quality.

## STEP 4b — ERROR RECOVERY (if STEP 4 fails)
If a subagent returns a build error, failing test, or type error:
1. Load `$HOME/.claude/agents/analyzer.md` in DEBUG MODE on the exact error output.
   Produce: root cause hypotheses (ordered), affected files, what NOT to touch.
2. Present gate:
```
SHIP FEATURE — ERROR IN STEP 4
TASK    : <task name that failed>
ERROR   : <one-line summary>
HYPOTHESES:
  1. [HIGH] <cause> — evidence: <…>
  2. [MED]  <cause> — evidence: <…>
OPTIONS :
  A) Apply fix for hypothesis 1 and re-run this task
  B) Skip this task and continue with remaining tasks
  C) Abort feature — preserve work done so far
```
3. Wait for user choice. Do NOT auto-fix. Do NOT proceed without explicit approval.
4. If A → apply minimal fix, re-run STEP 4 for the failed task only. Max 2 retry attempts.
   If still failing after 2 → fall back to options B or C.
   If B → before skipping: scan remaining task list for tasks that depend on the failed task
     (look for references to the same file or function in subsequent tasks).
     If dependents found → present: "Tasks [N, M] depend on the skipped task.
       Skip them too? (yes / keep and accept partial implementation)"
     If no dependents → skip cleanly and continue.

## STEP 5 — ANALYZE
Load `$HOME/.claude/agents/analyzer.md`. Check: no regressions, no stale code, no plan deviations.

## STEP 6 — CODE REVIEW
Invoke `superpowers:requesting-code-review`. Fix all CRITICAL before proceeding.

## STEP 7 — FINISH
Invoke `superpowers:finishing-a-development-branch`. Tests pass, build clean, ready to merge.

## STEP 8 — DOC SYNC
Load `$HOME/.claude/agents/doc-syncer.md`.
Execute in automatic mode:
`auto-mode scope: <list of files modified during this session>`

## STEP 9 — CAPITALIZE (memory registries)
Feature shipped implies at least one design decision worth capturing. Run this before declaring done:

1. Scan conversation context for:
   - **Design / architecture choices with rationale** → candidate for `decisions.md` (BDR-XXX).
   - **Reusable patterns, surprising discoveries** → candidate for `learnings.md` (LRN-XXX).
   - **Dead-ends with identified root cause** → candidate for `blockers.md` (BLK-XXX).
2. For each candidate, pre-fill a full entry (ID, date, title, body per registry schema) from conversation context.
3. Present them grouped:
   ```
   CAPITALIZE — registres proposés
   
   [ decisions.md ]
     BDR-XXX — <titre> — <1-line why>
   [ learnings.md ]
     LRN-XXX — <pattern>
   [ blockers.md ]
     (aucun)
   
   Valider lesquels ? (all / <IDs> / edit / skip)
   ```
4. Append approved entries to the registries. Update the Index table at the top of each file.
5. Append a one-line entry to `.claude/memory/journal.md` under today's date heading (`## YYYY-MM-DD`).

If nothing substantive to log → print `CAPITALIZE: rien à logger (travail trivial)` and skip.

---

## RULES
- No skipping steps. No merged agent responsibilities.
- No implement without user approval at STEP 3.
- Subagents isolated — no shared context between tasks.
- Fix all CRITICAL review issues before proceeding.
- Stop if requirements unclear at any step.
- STEP 4 errors → STEP 4b gate required before any fix. Never auto-patch a failing subagent.

---

## FINAL OUTPUT
```
FEATURE SHIPPED: <n>
TASKS: <N>/<N> | TESTS: ✅/❌ | REVIEW: APPROVED/CHANGES REQUIRED
REMAINING ISSUES: <list or none>
```
