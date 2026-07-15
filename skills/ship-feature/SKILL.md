---
name: ship-feature
description: 'Use when shipping a new feature end-to-end — needs design brainstorm, planning, TDD implementation with subagents, error recovery, code review, and finish. Multi-agent orchestrator (9-step pipeline). Triggers: "ship feature", "ship-feature", "build and merge", "feature end-to-end", "implement and ship".'
argument-hint: <feature description>
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: SHIP FEATURE

## MODEL GATE (blocking — run before any other step)

Run `$HOME/.claude/lib/model-gate.md`. Reflection here (planning, audit
judgment, loop decisions) requires Fable/Opus. Verdict `small` → STOP: the
gate prints the remedy; end the turn — no later step, no dispatch. Nominal
(big) path is silent.

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

## STEP 0d — ANALYZE BEFORE PLAN (code + memory, read-before)
Dispatch the analyzer subagent (fresh context) on the request — it produces the
read-before digest the plan must not form without:

  Agent(subagent_type="analyzer", description="ship-feature — read-before", prompt="""
    Read-only analysis to PRIME a feature plan (NOT debug). REQUEST: <$ARGUMENTS>.
    1. CODE — locate the zone the feature touches: grep/glob the request's nouns /
       identifiers across the tree → candidate files (PASS 1), read them (PASS 2).
       >50 candidates → scoped sweep per your EDGE CASES, list zones, don't read all.
       Too vague to locate → report ambiguous zones, do NOT block.
    2. MEMORY — run the scan per $HOME/.claude/lib/analyze-before-plan.md, emit
       RELATED MEMORY (disposed).
    Output your standard ANALYSIS + RELATED MEMORY. No solutions.""")

The returned digest (ANALYSIS + RELATED MEMORY) stays in the orchestrator's context — it
is FED to STEP 1 and STEP 2 and reconciled at STEP 3. Degradation: request too vague →
analyzer flags ambiguous zones, does not block (STEP 1 refines). `.claude/memory/` empty or
absent → analyzer omits RELATED MEMORY (no-op); the step still returns the code ANALYSIS.
Additive — distinct from STEP 5 VERIFY + SECURE (post-impl) and STEP 4b DEBUG.

## STEP 0e — CONTRACT

Run `$HOME/.claude/lib/contract-interview.md`. REQUEST verbatim = the feature
request as typed; initial ACCEPTANCE CRITERIA from the request; FILE SCOPE
seeded from 0d's KEY COMPONENTS. It writes
`.claude/tasks/contracts/<date>-<slug>-<HHMM>.md`; keep the path — the design
approved at STEP 3 ENRICHES it, and STEP 5's verifier judges the diff against
the ENRICHED contract. This is the only flow where the contract grows mid-run.

## STEP 1 — BRAINSTORM
Invoke `superpowers:brainstorming` — but FEED it the STEP 0d digest as binding context,
not the raw request alone:
  "Feature request: <$ARGUMENTS>.
   In-force constraints (must hold): <only the IN-FORCE + ALREADY-SEEN items from 0d's
     RELATED MEMORY, detailed>.
   Existing code that bears: <ANALYSIS CONTEXT / KEY COMPONENTS from 0d>.
   Brainstorm WITHIN these — don't re-explore a direction an in-force BDR rejects or a
   BLK already closed."
Inject ONLY what constrains: the NON-BINDING count does NOT enter the brainstorm input
(the injection inherits the OUTPUT filter — detail what binds, drop what doesn't).
Consumption = INPUT INJECTION (we can't modify the external skill; we control its input).
Refine request into validated design via Socratic questioning. Don't proceed until design approved.

## STEP 2 — PLAN
Invoke `superpowers:writing-plans` with the validated design AND the 0d digest: every task
must be consistent with the in-force constraints; where a task implements or affects one,
note the ID inline. Break design into tasks (2-5 min each). Each task: exact file paths, full code, verification steps.

## STEP 3 — VALIDATION GATE ★ MANDATORY STOP
```
SHIP FEATURE — VALIDATION GATE
FEATURE: <n> | TASKS: <count>
<numbered task list>

RELATED MEMORY — disposition CLAIMED by this plan (review each):
  - BDR-026 [in force]     — plan honors it by: <how>
  - LRN-050 [in force]     — plan applies it by: <how>
  - BLK-009 [already seen] — <how avoided / why N-A>

Review the claims above — flag any item the plan does NOT actually honor.
Approve and execute? (yes / request changes)
```
This block EXPOSES each in-force item with the plan's CLAIMED disposition, for human
review — it does NOT auto-detect conflicts. An agent blind to a conflict won't list it;
forcing a per-item claim is what gives the reviewer the surface to catch it. A display,
never a guarantee (same discipline as the memory-commit `✅<hash>`: show what's true, never
assert a check not performed). No RELATED MEMORY from 0d → omit the block.
Changes → back to STEP 2. Approved → continue.

**On approval — ENRICH the STEP 0e contract.** The design just validated adds
detail the raw request lacked: append the design-derived acceptance criteria
to the contract's ACCEPTANCE CRITERIA, each tagged `[gated <date>]` (this is
the human micro-gate that authorizes contract growth). STEP 5's verifier
judges the diff against this ENRICHED contract, not the STEP 0e seed — so a
criterion the design introduced is verified, not lost.

## STEP 4 — IMPLEMENT
Start the feature branch off develop, then implement on it:
```bash
bash "$HOME/.claude/lib/gitflow.sh" start feature <name>
```
Invoke `superpowers:subagent-driven-development` for the per-task implement loop
**and** the final whole-branch review **only**. Do NOT run its terminal
`finishing-a-development-branch` step — this orchestrator owns integration via
`gitflow finish` (STEP 9). When SDD's flow reaches "Use
finishing-a-development-branch", stop and return.

**Model routing (BDR-066):** every subagent dispatched under SDD — per-task
implementers AND its reviewers — MUST carry `model: "sonnet"` in the Agent
call. The plan is closed; execution and plan-conformity review are sonnet
work. Reflection (task decomposition, review verdict arbitration) stays in
this loop.

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

## STEP 5 — VERIFY + SECURE (fresh gates, bounded loops)
Run the two fresh gates per `$HOME/.claude/lib/verify-secure-loop.md` with
`CONTRACT` = the STEP 0e path (ENRICHED at STEP 3), `DIFF` = the branch diff
(`develop..HEAD`), `TEST` = the project suite:
- GATE 1 — a FRESH verifier judges the branch against the ENRICHED contract
  (all criteria, including the `[gated]` design ones). CONFORME → GATE 2.
  ECARTS → hand the dev the gap list, fix, re-verify, max 3 → STOP + human
  escalation with the CRITERIA table.
- GATE 2 — a FRESH security-auditor (`MODE: gate`, `SCOPE: develop..HEAD`)
  scans the branch. PASS → STEP 6. BLOCK → fix, re-verify the request THEN
  re-scan, max 3 → escalate.

This replaces the old informal "analyze for regressions" with a verdict
against the contract. It is a DISTINCT axis from STEP 6 code review (contract
conformity + security vs. craft/design) — both run, neither subsumes the
other ([[LRN-095]]).

## STEP 6 — CODE REVIEW
Invoke `superpowers:requesting-code-review`. Fix all CRITICAL before proceeding.

## STEP 7 — CAPITALIZE (memory registries)
Feature shipped implies at least one design decision worth capturing. Run this BEFORE STEP 9 FINISH — the implementation commits (STEP 4) already exist, so the entries' hash references are valid, and the memory commit lands on the branch that FINISH integrates (otherwise it strands outside the PR):

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

**Language rule**: written entries are ALWAYS in English (see CLAUDE.md "Memory registries" § Language). The interactive gate above may mirror the user's language; the appended entries must not.

If nothing substantive to log → print `CAPITALIZE: nothing substantive to log` and skip.

**Then commit the memory** — follow `$HOME/.claude/lib/capitalize-commit.md`: it
surgically commits what capitalize just wrote (`.claude/memory` + `.claude/tasks`
only, never `git add -A`) as one `chore(memory)` commit, reports the memory-commit
hash, and no-ops if nothing was written. It runs BEFORE STEP 9 FINISH so the
memory is integrated with the branch, not stranded outside the PR.

## STEP 8 — DOC SYNC
Run BEFORE STEP 9 FINISH. doc-syncer PATCHES public docs but does NOT commit them, and
`gitflow finish` integrates only COMMITTED history — so a patch left
uncommitted (or committed after) never reaches the merge/PR. Same PR-stranding class as the
STEP 7 capitalize fix (BDR-034).

Load `$HOME/.claude/agents/doc-syncer.md`. Execute in automatic mode:
`auto-mode scope: <list of files modified during this session>`

**Then commit the docs** — follow `$HOME/.claude/lib/doc-commit.md`: it surgically commits
ONLY the files doc-syncer patched (its `PATCHED_FILES` output, one path per line → one argv
arg each), never `git add -A`, never `.claude/`/`CLAUDE.md`, and no-ops if nothing was
patched. Report per its rc table — rc 4 = a LOUD upstream BDR-022 anomaly (doc-syncer
surfaced a forbidden path), not a silent skip. It runs BEFORE FINISH so the doc commit lands
on the branch FINISH integrates.

## STEP 9 — FINISH
Tests pass, build clean. Integrate the feature into develop — **only on the
user's explicit go** (the `gitflow` finish gate):
```bash
bash "$HOME/.claude/lib/gitflow.sh" finish   # feature/<name> → develop
```

---

## RULES
- No skipping steps. No merged agent responsibilities.
- No implement without user approval at STEP 3.
- Subagents isolated — no shared context between tasks.
- Fix all CRITICAL review issues before proceeding.
- Stop if requirements unclear at any step.
- STEP 4 errors → STEP 4b gate required before any fix. Never auto-patch a failing subagent.

---

## FAILURE PATHS (orchestrator-level)

The pipeline must handle these without aborting silently:

| Situation | Behavior |
|---|---|
| STEP 0b — `CLAUDE.md` missing | STOP with the printed message ("Run `/onboard` first…"). Do not proceed. |
| STEP 0c — `ctx7` not installed but fast-libs detected | Skip pre-fetch silently. During STEP 4, log `📚 ctx7 cache miss for <lib>` and continue with vanilla model knowledge. |
| STEP 0d — request too vague for analyzer to locate a code zone | analyzer reports ambiguous zones and does NOT block; STEP 1 brainstorm refines scope. The memory disposition is still produced. |
| STEP 0d — `.claude/memory/` absent (project not yet onboarded) | analyzer's guarded scan no-ops (the `[ -d ]` guard fires — a bare glob would error); proceed with the code ANALYSIS alone. STEP 7 creates registries later. |
| STEP 1 — brainstorming returns "design unclear" twice | Escalate: ask user "Switch to /init-project (greenfield-style design) or refine the feature request?" |
| STEP 3 — user replies "request changes" | Loop back to STEP 2 with user's notes. Cap at 3 iterations; on the 3rd "request changes" without approval, ask "Pause and rescope this feature?" |
| STEP 4 — subagent crashes (tool error, not test failure) | Treat as STEP 4b error path, present hypothesis-led gate. |
| STEP 4b — option A retried 2× still failing | Force fall-through to B or C. Do not loop a 3rd time. |
| STEP 6 — review returns CRITICAL items | Loop back to STEP 4 for those items only. Cap at 2 review-cycle iterations; if still CRITICAL, escalate. |
| STEP 7 — `.claude/memory/` missing | Create the registry files from `~/.claude/templates/memory/` first, then proceed. |

---

## FINAL OUTPUT
```
FEATURE SHIPPED: <n>
TASKS: <N>/<N> | TESTS: ✅/❌ | REVIEW: APPROVED/CHANGES REQUIRED
REMAINING ISSUES: <list or none>
```
