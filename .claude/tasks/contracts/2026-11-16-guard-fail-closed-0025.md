# CONTRACT — guard-fail-closed (BDR-125 gap audit A6)
- date: 2026-11-16 | flow: feat | branch: feature/guard-fail-closed (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
A6 (BDR-125 gap audit, phase 2 shared rule "guards fail closed", user choice 2026-11-12): the model-router write guard (mods/model-router/hooks/register.ts registerGuard, ~:4441-4464) fails open: when guardWrite throws, the .catch logs and lets the Edit/Write/NotebookEdit through. Make it fail closed for the guard's own failure: a main-loop code write the guard could not decide is denied with "model-router: the write guard failed (<error kind>), so this write is held. Enter /hotfix, /feat, /bugfix or /ship-feature, or re-enter the skill you were running, then make this edit." Sub-agents, writes inside a skill run, and doc files still pass without touching the code that can fail. Errors from the downstream tool (next) keep today's behavior. Tests in mods/model-router/hooks/register.test.ts.

## CLARIFICATIONS
- [gated 2026-11-16] deny text chosen by the user: "Same redirect + cause" (the text quoted in REQUEST, `<error kind>` = `errWord(err)`).
- [internal 2026-11-16, challenge r1] plan .claude/tasks/plans/2026-11-16-guard-fail-closed-0025.md section r2 wins. Real throw sources are session.root and a raw ui.log in the config load (config READ errors never throw; an unreadable override turns the router off, unchanged). The config-load log goes through tryLog; the Skill and skill.prompt .catch paths latch so entering a skill stays a working exit. guardWrite returns the deny text; own warnOnce key 'write guard'. Rig gains a World `root: 'fail'` knob. Amends BDR-136 point (4) (guard fail-open) per the user's 2026-11-12 choice; recorded at capitalize.
- [internal 2026-11-16, re-challenge r2] plan section r3 wins over r2: guardWrite unchanged; the three guard .catch blocks use the engine's documented `next.called` split (called → replay next(e) as today; not called → hold a main-loop out-of-run non-doc write with the user-chosen text, else pass). No tryLog or .catch-latch changes. Gate 0 note: criterion 1 CHECK runs `claude plugin test` (the kit `claude-code/testing` exists only under the engine; bare `bun test` cannot load it), as lib/tests/mods.test.sh does. Scope extension under the user's "fill every gap found" instruction: the Skill latch no longer opens on an `isError` output (BDR-137: engine refusals carry isError, not deny).

- [gated 2026-11-16, after verify] user accepted as built: the deny's kind is `next.error.kind` (throw | timeout, never a path), not `errWord(err)`; sub-agents, skill runs and doc files pass through the `.catch` fallback after the guard ran (engine-documented next.called pattern), not by being decided before code that can fail. Outcome unchanged and tested.

## ACCEPTANCE CRITERIA
1. model-router suite green, with the new fail-closed tests.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH claude plugin test mods/model-router </dev/null 2>&1 | grep -cE '(^| )0 fail'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
2. Full make test green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
3. The deny tests (main Write, Edit, NotebookEdit held when session.root fails) and the isError-latch test fail on the pre-change register.ts; the doc, sub-agent, in-run and exit tests pass after the change; type-check clean if the repo has one for mods; lines ≤ 80 columns in the touched files (manual).

## FILE SCOPE
mods/model-router/hooks/register.ts (guard region ~:4397-4465 and its comment, Skill handler latch predicate ~:4577), mods/model-router/hooks/register.test.ts (rig World type and session.root mock ~:40-212, GUARD section ~:7288-7470).
