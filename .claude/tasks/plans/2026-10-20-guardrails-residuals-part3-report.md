# Part 3 report (B10 per-variant locks)
STATUS DONE. Files: lib/tests/guardrails-scan.test.sh, skills/guardrails/scripts/checks/injection.py, skills/guardrails/references/checks.md.
- `== per-variant` section: 17 end-to-end mutants (Rust format!, objects.raw, extra, knex.raw, executeRawUnsafe, sequelize.query/literal, GENERATE_SOURCEMAP, vite true, angular WARN, Rails, FLASK_DEBUG, app.debug, Rust/Ruby shell-db, PHP getTraceAsString, flask str(e)) + 2 benign locks. mutant lines 86 -> 103.
- Python table in $WORK/timing.py: ~75 alternation rows (CONCAT, DYNAMIC_EXEC, POSTGREST, NOSQL, SENDING x ERROR_STACK/MESSAGE, SHELL_DB heads x interps incl. Command::new), regex.search per row.
- One real miss: SHELL_INTERP lacked Rust positional `{}` (Command::new("psql").arg(format!("-c {}", q))). Widened with `\{\}(?=[^"{}\n]{0,12}"\s*,)` (bounded, `{}` must close a format string before `,`). Benign locks: execSync("psql ...", {}) and Rust argv. Timing case `system(psql {} ` x5000 (0.65 s at 90 KB; first widening with {0,200} took 1.85 s, narrowed). checks.md INJ-SHELL-DB-TOOL row updated.
- Regex edits: 1 (limit 5).
- Results: scan suite 241 passed 0 failed; make test all green; shellcheck ok; gates VERDICT MET (22/22).
- Concern: SHELL_DB is pre-existing quadratic on single-line non-matching input (~0.5 s at 84 KB), margin to the 1 s timing lock is thin on slow machines.
