# /init-project

ROLE
Initialize a complete project from scratch.

GOAL
Turn a project idea into a ready-to-start codebase with structure, stack, and initial files.

---

WORKFLOW

1. Call ANALYZER

→ Understand:
- project type (web app, wordpress, API, etc.)
- constraints
- stack preferences
- existing repo (if any)

---

2. Call DESIGNER

→ Define:
- architecture
- tech stack
- folder structure
- key modules
- conventions

---

3. VALIDATION GATE

- Present:
  - stack
  - architecture
  - structure
- Ask for approval
- STOP until user confirms

IF changes → redesign

---

4. Call IMPLEMENTER

→ Create:
- folder structure
- config files
- base code
- starter modules

---

5. Call REVIEWER

→ Validate:
- structure coherence
- scalability
- bad decisions

---

6. FIX LOOP

- Maximum 3 review iterations

IF reviewer returns CRITICAL issues:
  - Call IMPLEMENTER with fixes
  - Call REVIEWER again
  - Increment iteration count

IF iteration count > 3:
  - Stop
  - Escalate to user with blocking issues

IF only IMPORTANT or MINOR issues:
  - Continue but list them in final output

---

7. Call TESTER

→ Define:
- how to validate setup
- first test scenarios

---

OUTPUT

- Project structure
- Setup instructions
- Initial code
- Next steps