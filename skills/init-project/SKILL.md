---
name: init-project
description: Initialize a complete project from scratch. Asks all necessary questions, designs the architecture, generates a filled CLAUDE.md from the global template, writes a cross-platform README with setup instructions, installs dependencies, and delivers a working first version covering all v1 features.
argument-hint: <project idea or description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: INIT PROJECT

## AGENTS LOADED

Load and follow strictly:
- .claude/agents/interviewer.md
- .claude/agents/analyzer.md
- .claude/agents/designer.md
- .claude/agents/scaffolder.md
- .claude/agents/reviewer.md
- .claude/agents/tester.md

---

## INITIAL REQUEST

$ARGUMENTS

---

## WORKFLOW

---

### STEP 1 — INTERVIEWER

Run the INTERVIEWER agent.

Using the initial request above as a starting point:
- Identify which information is already clearly provided.
- Ask only what is genuinely missing or ambiguous.
- Present all remaining questions in a single structured block.

**MANDATORY STOP — do not continue until the user has answered.**

After receiving answers, produce the PROJECT BRIEF as defined
in interviewer.md. The PROJECT BRIEF is the single source of
truth for all subsequent steps.

---

### STEP 2 — ANALYZER

Run the ANALYZER agent on the PROJECT BRIEF.

Focus on:
- Existing repo or code to integrate (if any)
- Stack constraints and compatibility issues
- Infrastructure or environment constraints
- Risks that could affect the design
- Any open decisions listed in the PROJECT BRIEF

Output an ANALYSIS REPORT.

---

### STEP 3 — DESIGNER

Run the DESIGNER agent using the PROJECT BRIEF and ANALYSIS REPORT.

Produce a complete DESIGN covering:
- Final tech stack with exact versions
- Complete folder structure (full tree)
- Module responsibilities and data flow
- Key interfaces and data models
- Config and tooling setup (lint, format, CI)
- Test strategy and tooling
- Any open decisions resolved with justification
- Prerequisites list (what must be installed on the dev machine)

---

### STEP 4 — VALIDATION GATE

**MANDATORY STOP — present the following to the user and wait
for explicit approval before proceeding.**

```
================================================================
INIT PROJECT — VALIDATION GATE
================================================================

PROJECT BRIEF SUMMARY
---------------------
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
<numbered list from PROJECT BRIEF>

CONVENTIONS
-----------
<naming, doc style, test strategy>

EXCEPTIONS TO GLOBAL RULES
---------------------------
<list or "none">

================================================================
Approve this plan? (yes / request changes)
================================================================
```

IF user requests changes:
- Return to STEP 3 (DESIGNER) with the feedback.
- Repeat STEP 4.

IF approved → proceed to STEP 5.

---

### STEP 5 — SCAFFOLDER

Run the SCAFFOLDER agent with:
- The full PROJECT BRIEF
- The approved DESIGN
- Reference to `~/.claude/templates/project-CLAUDE.md`
- Reference to `~/.claude/CLAUDE.md`

The SCAFFOLDER will, in order:

1. **Generate CLAUDE.md** — fill the global template with real
   content from the PROJECT BRIEF. No placeholders. No examples.

2. **Generate README.md** — cross-platform setup instructions
   (Windows / Linux / macOS) covering:
   - All prerequisites with exact versions and install commands
   - Step-by-step installation
   - How to run in development and production
   - How to run tests
   - Environment configuration

3. **Scaffold structure** — create every folder and file from
   the DESIGN with real content.

4. **Implement v1 features** — real working code for every
   feature in the PROJECT BRIEF. No stubs. No TODOs.

5. **Write initial tests** — at minimum one happy path and one
   edge case per module.

6. **Install and build** — actually run the install command,
   build, and test suite. Fix any failures before reporting.

---

### STEP 6 — REVIEWER

Run the REVIEWER agent on the scaffolded project.

Review scope:
- Structure coherence vs approved DESIGN
- Code quality vs CLAUDE.md conventions and global rules
- Security issues in initial implementation
- README completeness and accuracy
- Generated CLAUDE.md completeness (no placeholder left)
- Missing or incomplete v1 features

---

### STEP 7 — FIX LOOP

Maximum 3 iterations.

IF CRITICAL issues found:
- Run SCAFFOLDER with the list of issues to fix.
- Run REVIEWER again.
- Increment iteration counter.

IF counter > 3:
- STOP.
- Present blocking issues to the user and ask how to proceed.

IF only IMPORTANT or MINOR issues:
- Proceed to STEP 8.
- List all remaining issues in the final output.

---

### STEP 8 — TESTER

Run the TESTER agent on the scaffolded project.

Produce:
- Verification that existing tests cover v1 features
- Additional test cases for identified edge cases
- Regression risk assessment
- Confirmation that the test command in CLAUDE.md is correct

---

## RULES

- Never skip the INTERVIEWER step.
- Never start design or implementation with unanswered questions.
- Never implement without explicit user approval of the DESIGN.
- The generated CLAUDE.md must be complete — no placeholders.
- The README must work on Windows, Linux, and macOS.
- The first version must install, build, and run.
  A broken scaffold is not acceptable output.
- Keep agents isolated in their responsibilities.

---

## FINAL OUTPUT

```
================================================================
PROJECT INITIALIZED: <project name>
================================================================

LOCATION         : <project root path>
STACK            : <finalized stack>
INSTALL          : ✅ / ❌ <error>
BUILD            : ✅ / ❌ <error>
TESTS            : ✅ <N> passing / ❌ <detail>

V1 FEATURES
-----------
✅ <feature>
✅ <feature>
⚠️ <feature> — partial: <reason>

REMAINING ISSUES
----------------
<IMPORTANT and MINOR issues from reviewer, or "none">

QUICK START
-----------
<exact commands to get the project running right now>

NEXT STEPS
----------
1. <recommended first action>
2. <recommended second action>

CLAUDE.md        : ✅ complete
README.md        : ✅ Windows / Linux / macOS
================================================================
```
