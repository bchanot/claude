# PLAN — floor-guard-xit-boundary (hotfix, logic fix → challenged) — r2
- r2 after 3 challengers (simplicity SOLID, correctness SOLID, robustness
  CONCERNS(2)): SKIP_IDENT_RE sits right under SKIP_SUBSTRINGS; the waiver
  instruction on the guard's own lines is gone (SKIP never scans
  lib/floor-guard.sh: no `test`/`spec` in its path); the new fixture echo
  lines in the TEST file carry `# floor-guard: allow flip-test fixture`
  OUTSIDE the echoed string (the test path contains `test`, so a later scan
  of that diff would flag the fixture itself); `def fit(` / `function xit(`
  / `xit.each(` stay unmatched or matched as before and are recorded as a
  `shortcut:` comment; fixtures extended to prove the whole alternation.
- date: 2026-09-28 | contract: contracts/2026-09-28-floor-guard-xit-boundary-1648.md
- branch: bugfix/floor-guard-xit-boundary | executor: hotfixer (sonnet)

## Root cause
lib/floor-guard.sh:99-102 SKIP_SUBSTRINGS = ('.skip(', '.only(', 'xit(',
'xdescribe(', 'fit(', 'fdescribe(', 'it.todo(', '@pytest.mark.skip',
'@unittest.skip', 't.Skip('); :188-189 `skip_kind(text)` = `any(p in text …)`.
Plain substring: `xit(` ⊂ `exit(`, `SystemExit(`, `process.exit(`; `fit(` ⊂
`profit(`, `model.fit(`. Only test files are scanned for SKIP (line_findings,
`if test_file:`), so the false positive hits inline python/JS helpers inside
test files — the 2026-09-28 case: `sys.exit(1 if violations else 0)` in
lib/tests/profile-census.test.sh (BLK-023).

## The exact edit (lib/floor-guard.sh)
1. SKIP_SUBSTRINGS keeps only the dotted/decorator forms:
   ('.skip(', '.only(', 'it.todo(', '@pytest.mark.skip', '@unittest.skip', 't.Skip(').
2. New `SKIP_IDENT_RE = re.compile(r'(?<![A-Za-z0-9_.])(?:xit|fit|xdescribe|fdescribe)\(')`
   DIRECTLY UNDER the SKIP_SUBSTRINGS tuple (per-kind grouping, like
   STUB_SUBSTRINGS + its regexes), with two comment lines: bare Jasmine/Jest
   focus-or-skip calls; the lookbehind keeps `exit(`, `SystemExit(`,
   `model.fit(` out. Plus one `# shortcut:` line: `def fit(` / `function
   xit(` still match (space before), `xit (` and `xit.each(` still do not
   (as before); upgrade path `(?<!def )(?<!function )` and `(?:\.each)?\s*\(`.
3. `skip_kind(text)`: return 'SKIP' if any substring matches OR
   `SKIP_IDENT_RE.search(text)`; else None. Still ≤ 25 logic lines, one
   function.
4. No waiver comment on the guard's own new lines: SKIP is only scanned on
   test files (`is_test_file`: `test`/`spec`/`__tests__` in the path) and
   lib/floor-guard.sh is not one; the new lines carry no SUPPRESS/STUB
   trigger either. Header comment line 27 unchanged.

## The exact edit (lib/tests/floor-guard.test.sh)
After the SKIP block (:51-55), two blocks in the same style. Every `echo`
that writes a trigger-looking line ends with the bash comment
`# floor-guard: allow flip-test fixture` AFTER the closing quote (never
inside the string): the test file's path contains `test`, so a later
diff scan would otherwise flag the fixture line itself (informational
WAIVED on a test file).
- SKIP_EXIT_CLEAN: `d=$(mk_repo skipexit)`; append three lines to
  sample.test.js: `process.exit(1); // sys.exit(1)`, `model.fit(x);`,
  `const p = profit(1);`; run; `check_kind SKIP_EXIT_CLEAN "$rc" 0 "$out"
  'FLOOR GUARD: clean'`.
- SKIP_XIT_FLAGS: `d=$(mk_repo skipxit)`; append `  xit('skipped', () => {});`
  (leading spaces on purpose); run; `check_kind SKIP_XIT_FLAGS "$rc" 2
  "$out" 'FLOOR SKIP'`. Then two more repos in the same block proving the
  rest of the alternation: `fit('focused', () => {});` → `check_kind
  SKIP_FIT_FLAGS … 2 … 'FLOOR SKIP'`; `fdescribe('focused', () => {});` →
  `check_kind SKIP_FDESCRIBE_FLAGS … 2 … 'FLOOR SKIP'`.
Header comment (:2-3) gains "plus boundary cases for SKIP" after "one CLEAN
fixture".

## Not changed
Messages, exit codes, waiver syntax, other kinds, test harness helpers.
