---
name: ship-feature
description: Ship a feature end-to-end via multi-agent orchestration. Analyze → Design → Validate → Implement → Review → Test.
argument-hint: <feature description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: SHIP FEATURE

Load and follow strictly:
- .claude/agents/analyzer.md
- .claude/agents/designer.md
- .claude/agents/implementer.md
- .claude/agents/reviewer.md
- .claude/agents/tester.md

---

## FEATURE

$ARGUMENTS

---

## WORKFLOW

### 1. ANALYZER
Analyze the existing context relevant to the feature.

### 2. DESIGNER
Design the solution based on the analysis.

### 3. VALIDATION GATE — MANDATORY STOP
- Present the design clearly to the user
- Ask for explicit approval
- **DO NOT CONTINUE without a response**

IF changes requested:
- Call DESIGNER with feedback
- Repeat validation

IF approved → continue

### 4. IMPLEMENTER
Implement according to the validated design.

### 5. REVIEWER
Strict review of the produced code.

### 6. FIX LOOP — max 3 iterations

IF CRITICAL issues:
- Call IMPLEMENTER with fixes
- Call REVIEWER again
- Increment iteration counter

IF counter > 3:
- STOP
- Escalate to user with blocking issues

IF only IMPORTANT or MINOR issues:
- Continue but list them in final output

### 7. TESTER
Generate and run tests for the feature.

---

## RULES

- Never skip analysis
- Never skip validation
- Never implement without approval
- Keep agents isolated in their responsibilities
- Enforce CLAUDE.md norms strictly

---

## FINAL OUTPUT

- Validated design
- Final implementation
- Review summary
- Test plan and results
