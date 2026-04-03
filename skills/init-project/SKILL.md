---
name: init-project
description: Initialize a complete project from scratch. Plugin check → interview → analyze → design → validate → scaffold skeleton → plan v1 features → validate plan → implement (TDD, subagents) → analyze → review → finish. Same implementation rigor as ship-feature.
argument-hint: <project idea or description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: INIT PROJECT

## AGENTS AND SKILLS LOADED

Custom agents (this config):
- .claude/agents/plugin-advisor.md   ← plugin configuration check
- .claude/agents/interviewer.md      ← project questionnaire
- .claude/agents/analyzer.md         ← risk/constraint analysis
- .claude/agents/scaffolder.md       ← project skeleton (NO features, skeleton only)

Superpowers skills (design + implementation):
- superpowers:brainstorming                 ← architecture design
- superpowers:writing-plans                 ← v1 feature decomposition
- superpowers:subagent-driven-development   ← isolated TDD implementation
- superpowers:requesting-code-review        ← final review
- superpowers:finishing-a-development-branch ← cleanup + verification

---

## INITIAL REQUEST

$ARGUMENTS

---

## WORKFLOW

---

### STEP 0a — BRANCH SETUP

Load the BRANCH SETUP section from: `.claude/agents/git-workflow.md`

Before anything else, ensure we are NOT on a protected branch.

```bash
git branch --show-current
```

**If on `main`, `master`, `develop`, or any protected branch:**

Derive a branch slug from the initial request:
- Take the first 3–4 meaningful words
- Lowercase, hyphen-separated
- Max 50 chars

```bash
git fetch origin
git pull origin <current> --ff-only 2>/dev/null || true
git checkout -b feature/<project-slug>
```

Print: `✅ Working branch created: feature/<project-slug>`

**If already on a feature branch:**
Run the CONFLICT-SAFE REBASE procedure from git-workflow.md
to sync with main before starting.

Print: `✅ Branch: <current> (synced with main)`

**Do not proceed until the branch is clean and ready.**

---

### STEP 0b — PLUGIN CHECK

Load and follow: `.claude/agents/plugin-advisor.md`

Feed it the initial request above.

**If `ACTION REQUIRED: YES`:**
```
================================================================
⚠️  PLUGIN CHECK — ACTION REQUIRED
================================================================
[paste full RECOMMENDATIONS block]
----------------------------------------------------------------
A) Enable recommended plugins then re-run /init-project
B) Type "force" to proceed without them
================================================================
```
**STOP. Wait for user response.**
- Re-run → restart from STEP 0b
- "force" → note missing plugins, continue to STEP 1

**If `ACTION REQUIRED: NO`:**
Print one line and continue:
`✅ Plugin check passed — [active plugins]`

---

### STEP 1 — INTERVIEWER

Load and follow: `.claude/agents/interviewer.md`

Identify what is already provided in the initial request.
Ask only what is genuinely missing. Single structured block of questions.

**MANDATORY STOP — do not continue until user has answered.**

Produce the PROJECT BRIEF. This is the single source of truth
for all subsequent steps.

---

### STEP 2 — ANALYZER

Load and follow: `.claude/agents/analyzer.md`

Analyze the PROJECT BRIEF:
- Existing repo or code to integrate
- Stack constraints and compatibility issues
- Infrastructure constraints
- Risks that could affect the design
- Open decisions from the PROJECT BRIEF

Produce an ANALYSIS REPORT.

---

### STEP 3 — ARCHITECTURE DESIGN

Invoke skill: `superpowers:brainstorming`

Feed it the PROJECT BRIEF + ANALYSIS REPORT.

Produce a complete DESIGN covering:
- Finalized tech stack with exact versions
- Complete folder structure (full tree)
- Module responsibilities and data flow
- Key interfaces and data models (signatures only — no implementation)
- Config and tooling setup
- Test strategy
- Any open decisions resolved with justification
- Prerequisites list (what must be installed on dev machine)

---

### STEP 4 — VALIDATION GATE #1 — ARCHITECTURE

**MANDATORY STOP — present to the user and wait for approval.**

```
================================================================
INIT PROJECT — ARCHITECTURE VALIDATION
================================================================

PROJECT SUMMARY
---------------
<3–5 line recap of what will be built>

STACK
-----
<finalized stack with versions>

PREREQUISITES TO INSTALL
-------------------------
<list of tools / runtimes / services with versions>

FOLDER STRUCTURE
----------------
<full tree from the DESIGN>

V1 FEATURES TO IMPLEMENT
-------------------------
<numbered list from PROJECT BRIEF — these will be implemented
 in the pipeline AFTER the skeleton is scaffolded>

CONVENTIONS
-----------
<naming, doc style, test strategy>

EXCEPTIONS TO GLOBAL RULES
---------------------------
<list or "none">

================================================================
Approve this architecture? (yes / request changes)
================================================================
```

IF changes → return to STEP 3.
IF approved → proceed.

---

### STEP 5 — SCAFFOLD SKELETON

Load and follow: `.claude/agents/scaffolder.md`

Pass to the scaffolder:
- Full PROJECT BRIEF
- Approved DESIGN
- `~/.claude/templates/project-CLAUDE.md`
- `~/.claude/CLAUDE.md`

The scaffolder creates:
1. `CLAUDE.md` — filled from global template, no placeholders
2. `.claude/settings.json` — adapted to this stack
3. `.claudeignore` — extended for this project
4. Complete folder structure
5. Config files (package.json, Cargo.toml, etc.)
6. Empty entry points and module files (structure only, no business logic)
7. `.gitignore`, `.env.example`

**The scaffolder does NOT create the README and does NOT implement any features.**
README is handled by readme-updater (STEP 5b).
Features are handled by the implementation pipeline (STEPs 6–9).

The scaffolder must verify: `git init` + build passes on empty project.

---

### STEP 5b — CREATE README

Load and follow: `.claude/agents/readme-updater.md`

Context: `README.md` does not exist yet → CREATE mode activates automatically.

The readme-updater reads `CLAUDE.md`, the folder structure, and manifests
to generate the full README (About, Prerequisites with OS-specific install
commands, Installation, Running, Project structure, Configuration, Contributing).

No stop required — prints confirmation and continues immediately.

---

### STEP 6 — PLAN V1 FEATURES

Invoke skill: `superpowers:writing-plans`

Using the PROJECT BRIEF v1 features list and the scaffolded skeleton as context:
- Break each v1 feature into granular tasks (2–5 min each)
- Each task must reference exact file paths from the scaffolded structure
- Each task must include: what to implement, expected behavior, verification steps
- Apply TDD: tests are written before implementation code

---

### STEP 7 — VALIDATION GATE #2 — IMPLEMENTATION PLAN

**MANDATORY STOP — present the plan to the user.**

```
================================================================
INIT PROJECT — IMPLEMENTATION PLAN VALIDATION
================================================================

SKELETON STATUS : ✅ build passes
V1 FEATURES     : <N> features → <M> tasks

<numbered task list with file paths>

================================================================
Approve this plan and start implementation? (yes / request changes)
================================================================
```

IF changes → return to STEP 6.
IF approved → proceed.

---

### STEP 8 — IMPLEMENT V1 FEATURES

Invoke skill: `superpowers:subagent-driven-development`

Execute each task with isolated subagents.
Mandatory TDD: `superpowers:test-driven-development` applies.
Two-stage review per task: spec compliance → code quality.

Each subagent works on a clean context with:
- The task description
- Relevant file paths
- PROJECT BRIEF context
- CLAUDE.md conventions

---

### STEP 9 — ANALYZE

Load and follow: `.claude/agents/analyzer.md`

Run the ANALYZER on the completed implementation:
- Verify no regressions
- Verify no plan deviations
- Verify no stale scaffold code left (empty files not yet populated)
- Verify conventions are respected

---

### STEP 10 — CODE REVIEW

Invoke skill: `superpowers:requesting-code-review`

Full review scope:
- Code quality vs CLAUDE.md conventions and global rules
- Security issues
- Missing or incomplete v1 features
- README accuracy
- Generated CLAUDE.md completeness (no placeholder remaining)
- Test coverage

Fix all CRITICAL issues before proceeding.

---

### STEP 11 — FINISH

Invoke skill: `superpowers:finishing-a-development-branch`

Verify:
- All tests pass
- Build is clean
- No leftover scaffold placeholders
- Initial commit prepared

---

### STEP 12 — SYNC README

Load and follow: `.claude/agents/readme-updater.md`

Context: call with argument "sync".

SYNC mode — no stop required. The readme-updater:
- Detects any drift between README and the implemented code
- Updates commands, env vars, folder structure if changed during implementation
- Adds a `## Recent changes` entry summarizing v1 features
- Prints one-line confirmation

---

## RULES

- Never skip STEP 0a — branch setup is mandatory. Never commit on main/master.
- Never skip STEP 0b — plugin check is mandatory.
- Never skip STEP 1 — no assumptions about missing info.
- Never implement without explicit user approval at STEP 4.
- Never implement without explicit user approval at STEP 7.
- The scaffolder only creates the skeleton — zero business logic.
- All feature implementation goes through the subagent pipeline (STEP 8).
- Apply CLAUDE.md norms throughout.
- A broken skeleton or a broken build is not acceptable output.

---

## FINAL OUTPUT

```
================================================================
PROJECT INITIALIZED: <project name>
================================================================

LOCATION    : <project root>
STACK       : <finalized stack>
BUILD       : ✅ / ❌ <e>
TESTS       : ✅ <N> passing / ❌ <detail>

V1 FEATURES
-----------
✅ <feature>
✅ <feature>
⚠️ <feature> — partial: <reason>

REMAINING ISSUES
----------------
<IMPORTANT and MINOR issues, or "none">

QUICK START
-----------
<exact commands to run the project right now>

CLAUDE.md  : ✅ complete
README.md  : ✅ created (STEP 5b) + synced (STEP 12)
SETTINGS   : ✅ .claude/settings.json + .claudeignore generated
================================================================
```
