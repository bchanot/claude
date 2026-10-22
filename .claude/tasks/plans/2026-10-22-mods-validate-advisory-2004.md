# BUGFIX PLAN r3 — mods.test.sh reads the advisory plugin-directory section as a warning

## DIAGNOSIS
BUG: `make test suite=lib/tests/mods.test.sh` fails on develop with
`FAIL model-router: validate printed a warning` (pre-existing, proven on
develop's copy via git archive in the previous session).
ROOT CAUSE: Claude Code CLI 2.1.306 `claude plugin validate` prints a
"Plugin directory checks for <dir>" section (the submission catalogue's
checks) that says "Found 1 plugin directory warning:" (ICON_MISSING).
lib/tests/mods.test.sh:57 greps the WHOLE output case-insensitively for
`warning`, so an advisory the CLI itself reports as `blocking: false`
(`--json`, `directory.findings[].blocking`) fails the suite. The same grep
also matches the hooks notes that quote register.ts identifiers (`warnOnce`
today is safe, a future `logWarning` is not) and any checkout path holding
"warning": prose scraping, fail-open and fail-closed at once.
EVIDENCE: `claude plugin validate mods/model-router` rc 0; `--strict` rc 0
(per-file warnings are the only ones `--strict` turns into rc 1:
`manifest.warnings` and `contents[].warnings` are empty); `--strict
--profile directory` rc 1 (the advisory counts only under that profile).
A scratch plugin whose manifest is `{"name":"warnfix"}` gives `⚠ Found N
warnings:` (version, description, author) and `--strict` rc 1, plain rc 0.
BLAST RADIUS: the fix touches lib/tests/mods.test.sh only. doctor.sh:211
names the command in a hint. Three historical contracts carry the same
scrape as a CHECK oracle (`grep -q 'Validation passed' && ! … grep -qi
'warning'`): .claude/tasks/contracts/2026-10-08-model-router-w1a-1533.md:22,
2026-10-08-model-router-floor-1835.md:22, 2026-10-09-model-router-tiers-1237.md:23.
Re-run on CLI 2.1.306 they fail on ICON_MISSING: known-stale oracles, left
unedited (historical), named at CAPITALIZE so a re-run is not read as a
model-router regression. `advice[]` (third top-level `--json` field) is
empty on every fixture tried; whether `--strict` escalates it is unverified.
PRIOR: none bears. RELATED MEMORY: BLK-030..033 are model-router runtime /
guardrails, not the CLI validate output; no BDR constrains the suite shape.

## CHALLENGE r1 → r2 → r3
Three lenses (correctness, robustness, simplicity), 0 BLOCKER, 5 MAJOR, all
closed by this revision: the sed range on a closing marker the CLI prints
only when findings > 0 (fail-open to EOF, hides `✔ Validation passed with
warnings`) is dropped for the CLI's own contract, the `--strict` exit code;
the tautological SAMPLE_UNTERMINATED and the invented warning samples are
dropped; the blocking branch is now exercised by a real CLI run on a
fixture plugin instead of a copy of the grep. r3 (one re-challenge, 1 MAJOR):
the control now runs through the gate's own helper, a clean sibling fixture
pins the cause (only per-file warnings differ), the ko tail names the rerun
command, WORK is script-level.

## FIX PLAN (one file: lib/tests/mods.test.sh)
1. New helper, next to `bounded`:
   `validate_strict() { STRICT_OUT=$(bounded claude plugin validate --strict "$1"); }`
   returns the rc of `bounded` (last command), output in the script-level
   `STRICT_OUT` (same pattern as LAST_OUT in lib/tests/a11y-scan.test.sh:13).
2. check_cli, validate half (lines 53-59): `validate_strict "$dir" || rc=$?`.
   rc 124 → `ko "$name: validate timed out after ${CLI_TIMEOUT}s"` (unchanged);
   rc ≠ 0 → `ko "$name: validate --strict rc=$rc: $(printf '%s' "$STRICT_OUT" | grep -E '^(✘|error:|⚠ Found)' | head -2 | tr '\n' ' ') (rerun: claude plugin validate --strict $dir)"`;
   rc 0 → `ok "$name: validate --strict passed"`.
   The `Validation passed` substring check and the `grep -qi warning` are
   removed: the exit code is the verdict. The plugin-test half (lines 60-65)
   is unchanged.
3. Positive control. Script-level, right after `pass=0; fail=0`:
   `WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT` (top-level, as in
   lib/tests/a11y-scan.test.sh:12, never inside a function). New function
   `strict_discriminates`, called once after the `use_cli` block, only when
   `use_cli` = 1. It writes two scratch plugins:
   - `$WORK/warnfix/.claude-plugin/plugin.json` = `{"name":"warnfix"}`
     (per-file warnings: version, description, author);
   - `$WORK/cleanfix/.claude-plugin/plugin.json` =
     `{"name":"cleanfix","version":"0.1.0","description":"d","author":{"name":"x"}}`
     (no per-file warning; the directory findings README_MISSING,
     LICENSE_MISSING, ICON_MISSING are printed for both).
   Then, through the helper of step 1:
   - `validate_strict "$WORK/cleanfix"` → `check "strict control: clean fixture passes --strict" "$rc" 0`;
   - `validate_strict "$WORK/warnfix"` → `check "strict control: per-file warnings fail --strict" "$rc" 1`;
   rc 124 on either → `ko "strict control: validate timed out"`.
   The pair differs only in the per-file warnings, so a parse error (CLI
   without `--strict`: rc 1 on both) or a scrape added back turns the
   control red; the control covers the gate's own code path.
4. Header comment (lines 4-5): "passes `claude plugin validate --strict`
   (per-file warnings are errors; the advisory plugin-directory section
   does not change the exit code) and `claude plugin test`".
5. No new tracked file; the two manifests are written by the suite.

## EDGE CASES
- CLI without `--strict` (older than its introduction): commander rejects
  the unknown option with rc 1 on every call → check_cli red with the
  `error: unknown option` line in its tail, and the clean-fixture control
  red too. Accepted: `cli_unavailable` already requires `claude plugin
  test`, which post-dates `--strict`.
- Icon added later to mods/model-router: no effect, the directory profile
  is never requested.
- The fixture's directory findings never affect rc (no `--profile`).

## RISK: low. Test-only file, no runtime behaviour.
