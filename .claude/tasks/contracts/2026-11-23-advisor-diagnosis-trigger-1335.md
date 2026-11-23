# CONTRACT — advisor diagnosis trigger (hotfix weight)

## REQUEST (verbatim)
User 2026-11-23: "A" — add lever 3 only: out-of-skill main-loop advisor
trigger "before handing the user a root-cause diagnosis or commands to run
on their machine", in CLAUDE.global.md § Workflow advisor bullet.

## ACCEPTANCE CRITERIA
1. The advisor bullet's parenthesized trigger list ends with "before handing
   the user a root-cause diagnosis or commands to run on their machine".
   CHECK: cd /home/bchanot/Documents/claude && tr '\n' ' ' < CLAUDE.global.md | tr -s ' ' | grep -c 'public interface, before handing the user a root-cause diagnosis or commands to run on their machine) → the main loop calls the advisor tool'
   EXPECT: 1
2. CLAUDE.global.md stays within the 320-line budget.
   CHECK: wc -l < /home/bchanot/Documents/claude/CLAUDE.global.md
   EXPECT: 320
3. Nothing else in the file changes; build/tests green (`make test`).

## FILE SCOPE
- CLAUDE.global.md (lines 81-86 only)
