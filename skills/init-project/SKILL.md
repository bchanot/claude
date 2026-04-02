---
name: init-project
description: Initialize a complete project from scratch. Structure, stack, base files, conventions. Full orchestration with user validation.
argument-hint: <project idea or description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: INIT PROJECT

Load and follow strictly:
- .claude/agents/analyzer.md
- .claude/agents/designer.md
- .claude/agents/implementer.md
- .claude/agents/reviewer.md
- .claude/agents/tester.md

---

## PROJECT

$ARGUMENTS

---

## WORKFLOW

### 1. ANALYZER
Understand:
- Project type (web app, API, lib, CLI, etc.)
- Constraints and stack preferences
- Existing repo (if any)
- Missing critical decisions

### 2. DESIGNER
Define:
- Architecture
- Tech stack
- Folder structure
- Key modules
- Project conventions

### 3. VALIDATION GATE — MANDATORY STOP
Present:
- Chosen stack
- Architecture
- Folder structure

Ask for explicit approval.
**DO NOT CONTINUE without a response.**

IF changes requested → return to DESIGNER

IF approved → continue

### 4. IMPLEMENTER
Create:
- Folder structure
- Config files (build, lint, format)
- Project CLAUDE.md (from templates/project-CLAUDE.md)
- README.md
- Base code (entry point, main modules)
- Test structure

### 5. REVIEWER
Validate:
- Structure coherence
- Scalability
- Bad initial decisions

### 6. FIX LOOP — max 3 iterations

IF CRITICAL issues:
- Call IMPLEMENTER with fixes
- Call REVIEWER again
- Increment iteration counter

IF counter > 3:
- STOP
- Escalate to user

IF only IMPORTANT or MINOR issues:
- Continue but list in final output

### 7. TESTER
Define:
- How to validate the initial setup
- First test scenarios

---

## FINAL OUTPUT

- Created project structure
- Setup instructions
- Initial code
- Recommended next steps
