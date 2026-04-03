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

### STEP 0a — BRANCH SETUP

Load the BRANCH SETUP section from: `.claude/agents/git-workflow.md`

```bash
git branch --show-current
```

**If on `main`, `master`, `develop`, or any protected branch:**

Derive a branch slug from the feature request:
- Take the first 3–4 meaningful words from $ARGUMENTS
- Lowercase, hyphen-separated, max 50 chars
- Prefix with `feature/`

```bash
git fetch origin
git pull origin <current> --ff-only 2>/dev/null || true
git checkout -b feature/<feature-slug>
```

Print: `✅ Working branch created: feature/<feature-slug>`

**If already on a feature/bugfix/hotfix branch:**
Run the CONFLICT-SAFE REBASE procedure from git-workflow.md
to sync with the base branch before implementing.

Print: `✅ Branch: <current> (synced)`

**Special case — bugfix on a feature branch:**
If the user explicitly says "bugfix" or "fix" in the request AND
the current branch is a feature branch:
```bash
git checkout -b bugfix/<bug-slug>
```
Creates the bugfix branch FROM the feature branch — correct hierarchy.

**Do not proceed until the branch is clean.**

---

### STEP 0b — PLUGIN CHECK (mandatory gate)

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
- If user re-runs `/ship-feature` → start from STEP 0a again
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

### STEP 9 — CREATE PR (optional gate)

Ask the user:
```
================================================================
SHIP FEATURE — PR CREATION
================================================================
Feature is implemented, tested, and README is synced.

Create a PR/MR now?
  yes    → run /git-pr and open a draft PR
  no     → stop here, you can run /git-pr manually later
================================================================
```

**STOP — wait for user response.**

IF yes:
  Load and follow: `.claude/agents/git-workflow.md`
  The git-workflow agent will:
  - Show all changes since branch start (retroactive)
  - Propose a commit plan for approval
  - Push and create a draft PR/MR on GitHub/GitLab/Gogs/Gitea

IF no:
  Print: `✅ Feature shipped. Run /git-pr when ready to open a PR.`
  Stop.

---

## RULES

- Never skip STEP 0a — branch setup is mandatory. Never implement on main/master.
- Never skip STEP 0b — plugin check is mandatory.
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
