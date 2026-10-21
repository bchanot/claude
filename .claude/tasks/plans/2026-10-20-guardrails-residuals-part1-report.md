# Part 1 report — guardrails residuals (probe.py)

STATUS: DONE (one plan hole fixed, one oracle defect found)

Files: skills/guardrails/scripts/probe.py, skills/guardrails/scripts/checks/common.py
(printable), skills/guardrails/SKILL.md (STEP 5 sentence), lib/tests/guardrails-probe.test.sh.

Applied: shared printable; A1 (supabase url/tables validation, refusal names both
hosts, usage error printable, SKILL.md sentence); A2 (BUDGET_EXHAUSTED,
_BudgetExhausted, _SameHost(session), rate verdict SKIPPED on cut burst); A3
(_rows_state, _rows_verdict, 401/403/404 CLOSED, other non-200 SKIPPED); B1
(METADATA_KEY, _is_sensitive); B2+B13 (_map_outcome, _status_outcome, walk of
all candidates, dedupe on resolved url, data: always OPEN).

Tests: probe suite 84 passed 0 failed (70 passed 14 failed with probe.py and
common.py stashed: negative control OK). a11y-scan 23/0, guardrails-scan 184/0.

Deviations:
1. Plan hole: METADATA_KEY as written does not match `token_expires_in`
   (`_expires?$` needs the key to end there). Made it `expires?(?:_in)?`.
   Required by the plan's own PT and oracle 11.
2. Oracle 12 (contract) is defective: after `cd skills/guardrails/scripts`
   its `grep -q ... lib/tests/...` uses a relative path and fails. The python
   half and both greps pass when run from the repo root. Orchestrator should
   fix the oracle (use an absolute path or a subshell).

Gates: criteria 1-9, 11, 21 MET. 12 NOT-MET for the oracle defect above.
10, 13-20, 22 belong to Parts 2-3 (22 is a diff-wide check, re-run at the end).
settings.json and routing.json untouched by me (pre-existing dirty).
