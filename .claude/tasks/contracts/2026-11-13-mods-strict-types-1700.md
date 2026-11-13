# CONTRACT — mods-strict-types (BLK-049, block H4c)
- date: 2026-11-13 | flow: bugfix | branch: bugfix/mods-strict-types (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
BLK-049: make test red on mods.test.sh after the claude CLI auto-updated to 2.1.323: `claude plugin validate --strict` now type-checks the mods and fails on warnings.

## CLARIFICATIONS
- [gated 2026-11-13, analyzer] the failing warnings are TypeScript errors only: mods/memory register.test.ts:191,205,2805 (TS2339) + register.ts:1579 (TS2345, Bash hook return type); mods/model-router register.test.ts:310,1194,1383,1598,1617,1640,2365,2958,4599,4665,5157,6593,6595 + register.ts:4659 (TS2322, AgentSpawnResult incl. `{deny}`). The "gating hook with .catch" lines are informational, not counted. Fix = type narrowing / annotations only, zero runtime behaviour change; the guards' fail-open stays (BDR-136 point 4).

## ACCEPTANCE CRITERIA
1. Both mods pass strict validation.
   CHECK: cd /home/bchanot/Documents/claude && claude plugin validate --strict mods/memory >/dev/null 2>&1 && claude plugin validate --strict mods/model-router >/dev/null 2>&1 && echo STRICT-OK
   EXPECT: STRICT-OK
   EVIDENCE: MET exit=0 marker-found :: STRICT-OK
2. mods suite green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/mods.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
3. Kit tests unchanged in count and green (no test deleted or skipped).
   CHECK: cd /home/bchanot/Documents/claude/mods/model-router && PATH=$HOME/.bun/bin:$PATH timeout 300 claude plugin test . 2>&1 | tail -3
   EXPECT:  0 fail
   EVIDENCE: MET exit=0 marker-found :: 640 pass 0 fail Ran 640 tests across 1 file. [33.62s]
4. Memory kit green.
   CHECK: cd /home/bchanot/Documents/claude/mods/memory && PATH=$HOME/.bun/bin:$PATH timeout 300 claude plugin test . 2>&1 | tail -3
   EXPECT:  0 fail
   EVIDENCE: MET exit=0 marker-found :: 288 pass 0 fail Ran 288 tests across 1 file. [6.92s]
5. make test green (manual, bun on PATH).

## FILE SCOPE
mods/memory/hooks/register.ts (:1579 type only), mods/memory/hooks/register.test.ts, mods/model-router/hooks/register.ts (:4659 type only), mods/model-router/hooks/register.test.ts.
