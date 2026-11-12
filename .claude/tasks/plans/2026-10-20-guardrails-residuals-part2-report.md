# Part 2 report (guardrails-residuals)

STATUS DONE. Suites: guardrails-scan 222/0, a11y-scan 23/0, guardrails-probe 84/0. shellcheck on the scan suite clean.
Gates rows 2,3,10,13-18,20 MET (19 = Part 3, 22 = floor guard, see below).

Files: scanner.py (_safe_text at the 3 text print sites, printable imported), checks/exposure.py (SENSITIVE_WORD, UI_ATTR, HIDDEN_INPUT multi-line, WIDE .select(), _map_config dev exclusion, _large_map "sources" key, _hydrated_spans export chunks + dedupe_lines), checks/injection.py (Go backtick, rf/fr, triple-quoted f, sql/db/trx.raw, $where exclusions), SKILL.md, references/checks.md, lib/tests/guardrails-scan.test.sh, contract (oracle rulings).

Negative control: with scanner/exposure/injection stashed the suite fails 20 checks (mutants, benigns, ESC, timing); restored after.
Timing at ~80 KB: every new case < 0.01 s, chunk builder on 1 MB of `export const load` 0.03 s.

Choices the plan left open
- Test layout: new `== residual misses` section uses `solo`-based `raises` helper; ESC checks in a new `== text output` section; timing python moved to $WORK/timing.py (heredoc inside $(...) broke on quotes/backticks).
- Benigns that must stay 0/0 on the fixture sit under src/lib (src/api is a route dir and raises API-ROUTE-NO-AUTH); select-with-fields appended to $API.
- Contract oracle defects fixed (contract is in scope): 17 gains an index.js (a lone .map leaves exposure not applicable); 15 negative grep narrowed to the INJ-NOSQL-OPERATOR row (g.ts also raises API-ROUTE-NO-AUTH).
- SKILL.md Part 1 sentence reworded "Before adding it" -> "Before adding `--authorized`" so criterion 20's grep matches.
- STEP 3 bullet placed after the blind-spot paragraph; `--json` pairs sentence placed in STEP 10 item 3 (where the RULE:path pairs are written), not STEP 9.
- checks.md blind-spot bullets and by-design list extended as the plan lists.
- A variable named PY in the suite's python made shellcheck read it as heredoc end: renamed PYC.

Concern: criterion 22 floor-guard flags only the contract text itself (line 116 mentions noqa); no suppression added by this diff.
