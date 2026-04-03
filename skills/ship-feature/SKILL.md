---
name: ship-feature
description: Ship a feature end-to-end using the Superpowers workflow. Starts with a plugin check, then Brainstorm → Plan → Implement (subagent-driven) → Review → Finish branch.
argument-hint: <feature description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: SHIP FEATURE

## AGENTS AND SKILLS LOADED

Custom agents (this config):
- .claude/agents/plugin-advisor.md   ← plugin configuration check
- .claude/agents/analyzer.md         ← post-implementation verification

Superpowers skills:
- superpowers:brainstorming
- superpowers:writing-plans
- superpowers:subagent-driven-development
- superpowers:requesting-code-review
- superpowers:finishing-a-development-branch

---

## FEATURE REQUEST

$ARGUMENTS

---

## WORKFLOW

---

### STEP 0 — PLUGIN CHECK (mandatory gate)

Load and follow: `.claude/agents/plugin-advisor.md`

Feed it the feature request above as context for signal detection.

The advisor will:
1. Detect which plugins are currently active
2. Analyze the feature description for signals
3. Produce a recommendation table

**If the advisor output says `ACTION REQUIRED: YES`:**

Print this block and STOP COMPLETELY:

```
================================================================
⚠️  PLUGIN CHECK — ACTION REQUIRED
================================================================

[paste the full RECOMMENDATIONS block from the advisor]

----------------------------------------------------------------
Options:
  A) Enable the recommended plugins, then re-run /ship-feature
  B) Type "force" to proceed without the recommended plugins
     (you will miss capabilities — see warnings above)
================================================================
```

Wait for user response.
- If user re-runs `/ship-feature` → start from STEP 0 again
- If user types "force" → note missing plugins and continue to STEP 1

**If the advisor output says `ACTION REQUIRED: NO`:**
Print one line and continue immediately:
```
✅ Plugin check passed — [active plugins in one line]
```

---

### STEP 1 — BRAINSTORM
Invoke skill: `superpowers:brainstorming`

Refine the feature request into a validated design through
Socratic questioning. Do not proceed until the design is approved.

---

### STEP 2 — PLAN
Invoke skill: `superpowers:writing-plans`

Break the approved design into granular tasks (2–5 min each).
Each task must have: exact file paths, complete code, verification steps.

---

### STEP 3 — VALIDATION GATE

**MANDATORY STOP — present the plan to the user.**

```
================================================================
SHIP FEATURE — VALIDATION GATE
================================================================
FEATURE  : <name>
TASKS    : <count>
<numbered task list>
================================================================
Approve and execute? (yes / request changes)
================================================================
```

IF changes → return to STEP 2.
IF approved → proceed.

---

### STEP 4 — IMPLEMENT
Invoke skill: `superpowers:subagent-driven-development`

Execute each task with isolated subagents.
Two-stage review per task: spec compliance → code quality.

---

### STEP 5 — ANALYZE (custom)
Load and follow: `.claude/agents/analyzer.md`

Run the ANALYZER on the produced implementation.
Verify no regressions, no stale code, no plan deviations.

---

### STEP 6 — CODE REVIEW
Invoke skill: `superpowers:requesting-code-review`

Dispatch the code-reviewer agent on the full implementation.
Fix any CRITICAL issues before proceeding.

---

### STEP 7 — FINISH BRANCH
Invoke skill: `superpowers:finishing-a-development-branch`

Verify all tests pass, cleanup, prepare for merge.

---

### STEP 8 — SYNC README

Load and follow: `.claude/agents/readme-updater.md`

Context: call with argument "sync".

SYNC mode — no stop required. The readme-updater:
- Detects any drift between README and the new feature
- Updates commands, env vars, folder structure if changed
- Adds a `## Recent changes` entry with the shipped feature
- Prints one-line confirmation

---

## RULES

- Never skip STEP 0 — plugin check is mandatory.
- Never skip brainstorming.
- Never implement without explicit user approval of the plan.
- Keep subagents isolated — no shared context between tasks.
- Apply CLAUDE.md norms throughout.

---

## FINAL OUTPUT

```
================================================================
FEATURE SHIPPED: <name>
================================================================
TASKS COMPLETED : <N>/<N>
TESTS           : ✅ passing / ❌ <detail>
REVIEW          : APPROVED / CHANGES REQUIRED

REMAINING ISSUES (IMPORTANT/MINOR):
- <issue or "none">
================================================================
```
