# Guardrails a11y split, injection and exposure domains — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move accessibility out of `/guardrails` into a standalone `/a11y` skill sharing the scan engine, add the `injection` and `exposure` scanner domains, extend the read-only probe with an `exposure` block, and patch every citer.

**Architecture:** `scan.py` is split into a parametrized engine (`scanner.py`, a `Catalogue` of domains and prefixes) and two thin catalogue CLIs (guardrails, a11y). Two new check modules follow the `apis.py` pattern (module-level compiled regexes, `applies`, `check`, private `_x(project, files)` lists) on shared helpers added to `checks/common.py` (`code_files`, `hits`, `dedupe_lines`, `client_reachable`). The probe gains one `probe_exposure` entry in `PROBES`, fails closed (ERROR / SKIPPED, never CLOSED on an unobserved target), validates every plan path and keeps 4xx/5xx bodies. Doctrine, routing rows, profiles, locks and docs are patched in the same branch.

**Tech Stack:** Python 3 stdlib (`python3 -B`), bash test suites run through `make test suite=<file>`, shellcheck, gitflow lib.

**Spec:** `docs/superpowers/specs/2026-10-18-guardrails-a11y-split-design.md`

**Contract:** `.claude/tasks/contracts/2026-10-18-guardrails-a11y-split-inj-exp-2210.md` (criteria 4, 5 and 11 amended on 2026-10-19 after the plan challenge, shown at the validation gate: real a11y path, `test -f`, non-zero rule counts)

**Revision 2 (after the three-lens challenge):** per-language injection patterns (a `$1` placeholder, a typed `sql<T>` tag, Express `raw()` and UI copy stay silent), compiled regexes with bounded gaps and shared helpers, exposure rules scoped to route files, settings modules and non-dev env files, `.map` files over 1 MB listed by the walker, a fail-closed probe with path validation, exposure probed against a production build, the guardrails description under 1024, routing.json staged alone, web-building and seo/harden citers patched. **Revision 3 (confirmation pass):** quote-matched concat patterns with `+` in every language, the dev env lock scoped to the exposure domain, `DEBUG` anchored at column 0, error rules on every server file, hydrated exclusion limited to type-shaped values, Next pages and a root App counted as client code, sourcemap SKIPPED on a non-200 script, a truncated body, an off-host map or an empty list, plan validation that never raises, conditional stash pop, the contract amended on disk.

## Global Constraints

- Scanner: read-only, stdlib only, never executes project code, severities FAIL / WARN / MANUAL only, exit 0 / 1 / 2. A clean scan means "no static finding".
- Regexes: module-level `re.compile` with explicit flags, run through `common.hits` (`finditer`), never through `project.matches` with `.pattern` (the module's flags would be lost). Every gap that spans a line is bounded (`{0,200}` / `{0,300}` / `{0,400}`), never `[^\n]*` after a cheap anchor. Minified files, built dirs (`public`, `static`, `www`, `assets`) and test paths are out of `code_files`.
- Probe: GET, HEAD, OPTIONS only plus the existing opt-in POST burst; `--authorized` required; every plan path validated as a string starting with `/`; same-host redirects only; shared budget 200; secrets from env only; never print a response value, only identifier-shaped key names. A target that was not observed is ERROR or SKIPPED, never CLOSED.
- Code style: max 25 logic lines per function, 80 columns, 5 params, 5 locals. One check module per domain exposing `DOMAIN`, `applies(project)`, `check(project)`.
- Tests: every rule has a mutant at its default severity; every false-positive class the challenge found has a `benign` lock; the clean fixtures report ` 0 FAIL, 0 WARN`. Portable shell: no `sed -i`, no `grep -P`, no `stat -c`.
- Git: work on `feature/a11y-split-inj-exp`; commit per task with `git add <explicit files>`; never `git add -A`; never stage `settings.json`; `mods/model-router/routing.json` is committed through the Task 6 stash of that one file; never push by hand (hooks push).
- Safety-classifier fallback (BLK-022 class): if an executor's write of `injection.py` or a mutant block is withheld, the main loop writes that file itself with a single full-file Write against the task's test block as its spec, then re-dispatches the rest of the task.
- Rule, heading and label citers are patched in the same task that changes them (BDR-100). Locked single-line strings in SKILL.md files (loops-light) stay on one line.
- Run `make test suite=<file>` for the suites a task touches; one full `make test` in Task 9.

## Review Focus

1. A double-quoted Postgres placeholder (`"… where owner = $1"`) must stay silent: `parameterized-query` lock, Task 2.
2. A typed tagged template (`` sql<number>`select … ${id}` ``) must stay silent: `typed-sql-tag` lock, Task 2.
3. Server-side logging of a stack (`logger.error(…, err.stack)`) must stay silent while `new Response(err.stack)` in a route fails: `logger-stack` lock and `error-stack` mutant, Task 3.
4. An unreachable base page gives a SKIPPED sourcemap row, never CLOSED: `unreachable base page` test, Task 5.
5. A refused or non-JSON route gives a SKIPPED fields row, never CLOSED: `fields on a 401` and `fields on a non-JSON body` tests, Task 5.

---

### Task 1: Extract the scan engine into `scanner.py`

**Files:**
- Create: `skills/guardrails/scripts/scanner.py`
- Modify: `skills/guardrails/scripts/scan.py` (whole file)
- Test: `lib/tests/guardrails-scan.test.sh` (unchanged, must stay green)

**Interfaces:**
- Produces: `scanner.Catalogue(name, domains, rule_domains, manual_rules)` and `scanner.main(argv, catalogue) -> int`. The check-mode markers are `<NAME>-CLEAR <n>` and `<NAME>-NO-NEW` with `NAME = catalogue.name.upper()`.

- [ ] **Step 1: Read the current engine**

Run: `sed -n 1,251p skills/guardrails/scripts/scan.py`. Every function below is the same logic with the module constants replaced by `cat.<field>`.

- [ ] **Step 2: Create `skills/guardrails/scripts/scanner.py`**

```python
#!/usr/bin/env python3
"""Static scan engine shared by the guardrails and a11y scanners.

A Catalogue names the check modules, the rule prefixes and the MANUAL
rules; its name gives the report title and the markers the check modes
print. The engine reads a project tree as data and never executes it.
Exit codes: 0 no FAIL, 1 at least one FAIL, 2 usage error.

Two check modes replace the report and its exit code:
--assert-absent RULE:path,...  exit 0 and print <NAME>-CLEAR only when
    none of these FAIL/WARN pairs remain (a fix contract's oracle);
--baseline before.json  compare with an earlier --json run, exit 0 and
    print <NAME>-NO-NEW only when no FAIL/WARN hit appeared.
"""
import argparse
import json
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from checks.common import Project

SEVERITY_RANK = {"FAIL": 0, "WARN": 1, "MANUAL": 2}
GATED = ("FAIL", "WARN")


@dataclass(frozen=True)
class Catalogue:
    """What one scanner CLI exposes."""
    name: str           # report title and marker prefix (upper-cased)
    domains: dict       # ordered: domain name -> check module
    rule_domains: dict  # rule prefix (before the first '-') -> domain
    manual_rules: frozenset = frozenset()

    @property
    def marker(self):
        return self.name.upper()


@dataclass(frozen=True)
class Result:
    findings: list
    applicable: list
    skipped: list


def parse_args(argv, cat):
    parser = argparse.ArgumentParser(
        description=f"{cat.name} static scan: reads the tree, runs nothing")
    parser.add_argument("path", help="project root to scan")
    parser.add_argument(
        "--domain", default=",".join(cat.domains),
        help="comma list among: " + ", ".join(cat.domains))
    parser.add_argument(
        "--exclude", default="",
        help="comma list of relative paths to skip (copies, vendored code)")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument(
        "--assert-absent", default="", metavar="RULE:path,...",
        help="contract oracle: pass only when these pairs are gone")
    parser.add_argument(
        "--baseline", default="", metavar="JSON",
        help="earlier --json run: report fixed, remaining and new hits")
    return parser.parse_args(argv)


def _split(value):
    return [part.strip() for part in value.split(",") if part.strip()]


def run_checks(project, cat, names):
    findings, applicable, skipped = [], [], []
    for name in names:
        module = cat.domains[name]
        if module.applies(project):
            applicable.append(name)
            findings += module.check(project)
        else:
            skipped.append(name)
    findings.sort(key=lambda f: (
        SEVERITY_RANK[f.severity], f.domain, f.path, f.line))
    return Result(findings, applicable, skipped)


def summarize(findings):
    return {sev: sum(f.severity == sev for f in findings)
            for sev in SEVERITY_RANK}


def _domain_lines(domain, findings):
    rows = [f for f in findings if f.domain == domain]
    return [f"\n[{domain}]"] + (
        [f"  {f.severity:<6} {f.rule:<24} {f.path}:{f.line}  {f.message}"
         for f in rows] or ["  no finding"])


def _summary_line(findings):
    totals = summarize(findings)
    return "\nsummary: " + ", ".join(
        f"{n} {sev}" for sev, n in totals.items())


def render_text(project, cat, result):
    lines = [
        f"{cat.name} scan: {project.root} ({len(project.files)} files)",
        "scanned: " + (", ".join(result.applicable) or "none"),
    ]
    if result.skipped:
        lines.append("not applicable: " + ", ".join(result.skipped))
    for domain in result.applicable:
        lines += _domain_lines(domain, result.findings)
    return "\n".join(lines + [_summary_line(result.findings)])


def render_json(project, result):
    return json.dumps({
        "root": str(project.root), "files": len(project.files),
        "applicable": result.applicable, "not_applicable": result.skipped,
        "summary": summarize(result.findings),
        "findings": [f.as_dict() for f in result.findings],
    }, indent=2)


def _rule_domain(cat, rule):
    return cat.rule_domains.get(rule.split("-", 1)[0])


def _pairs(value):
    """'RULE:path,RULE:path' -> [(rule, path)]; a missing path stays ''."""
    return [tuple(p.strip() for p in item.partition(":")[::2])
            for item in _split(value)]


def _assert_error(cat, value):
    for rule, path in _pairs(value):
        if not path or not _rule_domain(cat, rule):
            return f"bad --assert-absent item {rule}:{path}, want RULE:path"
        if rule in cat.manual_rules:
            return f"{rule} is MANUAL: no static scan can prove it fixed"
    return ""


def _hits(findings):
    return Counter((f.rule, f.path) for f in findings if f.severity in GATED)


def _load_baseline(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    return Counter((f["rule"], f["path"]) for f in data["findings"]
                   if f["severity"] in GATED)


def _baseline_error(path):
    if not path:
        return ""
    try:
        _load_baseline(path)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return f"unreadable baseline {path}: {exc}"
    return ""


def _usage_error(cat, args):
    unknown = [n for n in _split(args.domain) if n not in cat.domains]
    if unknown:
        return f"unknown domain {unknown}"
    if not Path(args.path).is_dir():
        return f"not a directory: {args.path}"
    return (_assert_error(cat, args.assert_absent)
            or _baseline_error(args.baseline))


def _pair_status(cat, hits, applicable, pair):
    rule, path = pair
    if _rule_domain(cat, rule) not in applicable:
        return False, f"  CONTROL {rule} {path}: domain not scanned, " \
            "absence proves nothing"
    if hits[pair]:
        plural = "s" if hits[pair] > 1 else ""
        return False, f"  PRESENT {rule} {path} ({hits[pair]} hit{plural})"
    return True, f"  CLEAR   {rule} {path}"


def assert_absent(project, cat, result, pairs):
    """Positive control first: an empty tree or an unscanned domain fails."""
    hits = _hits(result.findings)
    rows = [_pair_status(cat, hits, result.applicable, p) for p in pairs]
    lines = [text for _, text in rows]
    if not project.files:
        lines.insert(0, "  CONTROL no file scanned, absence proves nothing")
    ok = bool(project.files) and all(passed for passed, _ in rows)
    marker = [f"{cat.marker}-CLEAR {len(pairs)}"] if ok else []
    return ok, lines + marker


def _moved(more, less):
    """Pairs where `more` holds extra hits over `less`, with the surplus."""
    return [(key, more[key] - less[key]) for key in sorted(more)
            if more[key] > less[key]]


def _rows(tag, moved, sign):
    return [f"  {tag:<5} {rule} {path} ({sign}{n})"
            for (rule, path), n in moved]


def baseline_report(cat, before, result):
    after = _hits(result.findings)
    fixed, new = _moved(before, after), _moved(after, before)
    summary = (f"baseline: {sum(n for _, n in fixed)} fixed, "
               f"{sum((before & after).values())} remaining, "
               f"{sum(n for _, n in new)} new")
    lines = _rows("FIXED", fixed, "-") + _rows("NEW", new, "+") + [summary]
    return not new, lines + ([] if new else [f"{cat.marker}-NO-NEW"])


def _check_modes(project, cat, result, args):
    checks = []
    if args.assert_absent:
        checks.append(
            assert_absent(project, cat, result, _pairs(args.assert_absent)))
    if args.baseline:
        checks.append(
            baseline_report(cat, _load_baseline(args.baseline), result))
    return checks


def _scan(cat, args):
    project = Project(Path(args.path), _split(args.exclude))
    result = run_checks(project, cat, _split(args.domain))
    checks = _check_modes(project, cat, result, args)
    if not checks:
        text = (render_json(project, result) if args.json
                else render_text(project, cat, result))
        print(text)
        return 1 if any(f.severity == "FAIL" for f in result.findings) else 0
    for _, lines in checks:
        print("\n".join(lines))
    return 0 if all(ok for ok, _ in checks) else 1


def main(argv, cat):
    args = parse_args(argv, cat)
    error = _usage_error(cat, args)
    if error:
        print(f"usage error: {error}", file=sys.stderr)
        return 2
    return _scan(cat, args)
```

- [ ] **Step 3: Rewrite `skills/guardrails/scripts/scan.py` as the catalogue**

Replace the whole file with (a11y stays in the catalogue for now; Task 4 removes it, Tasks 2 and 3 add the new domains):

```python
#!/usr/bin/env python3
"""Static guardrails scan: the guardrails catalogue on the shared engine.

See scanner.py for the modes and exit codes.
"""
import sys

import scanner
from checks import a11y, apis, functions, hosting, messaging, supabase

CATALOGUE = scanner.Catalogue(
    name="guardrails",
    domains={
        "api": apis,
        "hosting": hosting,
        "a11y": a11y,
        "supabase": supabase,
        "messaging": messaging,
        "functions": functions,
    },
    rule_domains={
        "API": "api", "HOST": "hosting", "A11Y": "a11y", "SB": "supabase",
        "MSG": "messaging", "FN": "functions",
    },
    manual_rules=frozenset({
        "HOST-WAF-DDOS", "HOST-SPEND-CAP", "SB-RLS-LIVE",
        "FN-CAP-UNVERIFIED", "FN-BUDGET-STOP",
    }),
)

if __name__ == "__main__":
    sys.exit(scanner.main(sys.argv[1:], CATALOGUE))
```

- [ ] **Step 4: Run the suite, it must be green with the same counts as before**

Run: `make test suite=lib/tests/guardrails-scan.test.sh`
Expected: `passed: 106  failed: 0` and `all suites green`. Also `python3 -B skills/guardrails/scripts/scan.py lib/tests/fixtures/guardrails-good | head -3` prints `guardrails scan: … (17 files)` then `scanned: api, hosting, a11y, supabase, messaging, functions`.

- [ ] **Step 5: Commit**

```bash
git add skills/guardrails/scripts/scanner.py skills/guardrails/scripts/scan.py
git commit -m "refactor(guardrails): extract the scan engine into scanner.py, scan.py keeps the catalogue"
```

---

### Task 2: Shared helpers in `common.py`, domain `injection`, mutants and benign locks

**Files:**
- Modify: `skills/guardrails/scripts/checks/common.py` (append `TEST_PATH`, `BUILT_SEGMENTS`, `code_files`, `hits`, `dedupe_lines`)
- Create: `skills/guardrails/scripts/checks/injection.py`
- Modify: `skills/guardrails/scripts/scan.py` (catalogue: add `injection` last, prefix `INJ`)
- Test: `lib/tests/guardrails-scan.test.sh` (new `== injection` block, benign locks)

**Interfaces:**
- Produces: `common.code_files(project, exts=SOURCE_EXTS) -> [Path]` (hand-written source: no test, fixture or mock path, no built dir, no minified file), `common.hits(project, files, regex, rule, message) -> [Finding]` (compiled regex, `finditer`), `common.dedupe_lines(findings)` (first finding per (path, line) wins), `common.TEST_PATH`. Rules `INJ-SQL-RAW-UNSAFE`, `INJ-SQL-CONCAT`, `INJ-SHELL-DB-TOOL` (FAIL), `INJ-SQL-DYNAMIC-EXEC`, `INJ-POSTGREST-FILTER`, `INJ-NOSQL-OPERATOR` (WARN). Task 4 re-points the check-mode tests to `INJ-SQL-CONCAT:src/pages/api/notes.ts`.

- [ ] **Step 1: Append the shared helpers to `checks/common.py`**

```python
TEST_PATH = re.compile(
    r"\.(?:test|spec|e2e|stories)\.|(?:^|/)(?:tests?|__tests__|spec|e2e"
    r"|fixtures?|mocks?)/", re.I)
BUILT_SEGMENTS = {"public", "static", "www", "assets"}
MINIFIED_NAME = re.compile(r"\.min\.|\.bundle\.", re.I)
LONG_LINE = 5000


def _minified(project, path):
    if MINIFIED_NAME.search(path.name):
        return True
    return any(len(line) > LONG_LINE
               for line in project.text(path).splitlines())


def code_files(project, exts=SOURCE_EXTS):
    """Hand-written source: no tests, fixtures, built dirs, minified files."""
    return [p for p in non_doc_files(project)
            if p.suffix.lower() in exts
            and not TEST_PATH.search(project.rel(p))
            and not set(project.segments(p)) & BUILT_SEGMENTS
            and not _minified(project, p)]


def hits(project, files, regex, rule, message):
    """One finding per match of a compiled regex over the given files."""
    return [project.found(rule, path, m.start(), message)
            for path in files
            for m in regex.finditer(project.text(path))]


def dedupe_lines(findings):
    """One finding per (path, line): the first emitted wins."""
    seen, out = set(), []
    for finding in findings:
        if (finding.path, finding.line) not in seen:
            seen.add((finding.path, finding.line))
            out.append(finding)
    return out
```

- [ ] **Step 2: Write the failing mutants and benign locks**

In `lib/tests/guardrails-scan.test.sh`, add `API=src/pages/api/notes.ts` next to the other path variables (after `SMS=…`). Right before `echo "== benign patterns stay silent"`, add:

```bash
echo "== injection"
mutant sql-template FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'const q = \`select id from notes where owner = \${owner}\`;' >> $API"
mutant sql-concat FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'const q = \"select id from notes where owner = \" + owner;' >> $API"
mutant sql-fstring FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'cur.execute(f\"delete from notes where id = {note_id}\")' > src/lib/cleanup.py"
mutant sql-php-interpolation FAIL INJ-SQL-CONCAT \
  "printf '%s\n' '<?php \$r = \$db->query(\"select id from notes where owner = \$owner\");' > src/lib/notes.php"
mutant sql-py-concat FAIL INJ-SQL-CONCAT \
  "printf '%s\n' 'cur.execute(\"select id from notes where owner = \" + owner)' > src/lib/cleanup.py"
mutant sql-quoted-value FAIL INJ-SQL-CONCAT \
  "printf '%s\n' \$'const q = \"select id from notes where owner = \\'\" + owner + \"\\'\";' >> $API"
mutant sql-php-dot FAIL INJ-SQL-CONCAT \
  "printf '%s\n' \$'<?php \$r = \$db->query(\"select id from notes where owner = \\'\" . \$owner . \"\\'\");' > src/lib/notes.php"
mutant sql-raw-unsafe FAIL INJ-SQL-RAW-UNSAFE \
  "printf '%s\n' 'const rows = await prisma.\$queryRawUnsafe(statement);' >> $API"
mutant sql-dynamic-exec WARN INJ-SQL-DYNAMIC-EXEC \
  "printf '%s\n' \"execute 'select count(*) from ' || tbl into n;\" >> $SQL"
mutant postgrest-filter WARN INJ-POSTGREST-FILTER \
  "printf '%s\n' 'const { data } = await supabase.from(\"notes\").select().or(\`owner.eq.\${who}\`);' >> $API"
mutant nosql-operator WARN INJ-NOSQL-OPERATOR \
  "printf '%s\n' 'const doc = await Notes.findOne({ owner: req.body.owner });' >> $API"
mutant shell-db-tool FAIL INJ-SHELL-DB-TOOL \
  "printf '%s\n' 'execSync(\`pg_dump --table=\${table} app > backup.sql\`);' > src/lib/backup.ts"
```

And after the existing benign cases, add:

```bash
benign parameterized-query \
  "printf '%s\n' 'const r = await db.query(\"select id from notes where owner = \$1\", [owner]);' >> $API"
benign tagged-sql-template \
  "printf '%s\n' 'const r = await sql\`select id from notes where owner = \${owner}\`;' >> $API"
benign typed-sql-tag \
  "printf '%s\n' 'const r = await sql<Note[]>\`select id from notes where owner = \${owner}\`;' >> $API"
benign express-raw-webhook \
  "printf '%s\n' 'app.post(\"/hook\", express.raw({ type: \"application/json\" }), onHook);' >> $API"
benign ui-copy-select \
  "printf '%s\n' 'const hint = \`Select a plan from the list, \${name}\`;' >> $TSX"
benign ui-copy-delete \
  "printf '%s\n' 'const label = \"Delete from favorites \" + item.title;' >> $TSX"
benign jquery-not \
  "printf '%s\n' 'const rows = \$(\".row\").not(\".row-\" + id);' >> $TSX"
benign argv-db-tool \
  "printf '%s\n' 'spawnSync(\"pg_dump\", [\"--table\", table, \"app\"]);' > src/lib/backup.ts"
benign format-dynamic-exec \
  "printf '%s\n' \"execute format('select count(*) from %I', tbl) into n;\" >> $SQL"
benign test-path-sql \
  "mkdir -p src/__tests__; printf '%s\n' 'const q = \`select id from notes where owner = \${owner}\`;' > src/__tests__/notes.test.ts"
benign minified-bundle \
  "printf '%s\n' 'const q=\`select id from notes where owner = \${o}\`;' > src/lib/app.min.js"
benign long-line-bundle \
  "head -c 6000 /dev/zero | tr '\\0' x > src/lib/bundle.js; printf '%s\n' ' const q=\`select id from notes where owner = \${o}\`;' >> src/lib/bundle.js"
```

- [ ] **Step 3: Run the suite, the twelve mutants must fail**

Run: `make test suite=lib/tests/guardrails-scan.test.sh 2>&1 | grep -c 'FAIL .* raises'`
Expected: `12` (the rules do not exist yet). The two `$'…'` snippets use ANSI-C quoting so the SQL string can hold a single quote; after the outer double quotes are processed, `eval` sees `$'const q = "… = \'" + owner + "\'";'`. The benign locks already pass, which is the point of writing them first.

- [ ] **Step 4: Create `skills/guardrails/scripts/checks/injection.py`**

```python
"""Injection checks: SQL built from input, raw ORM escapes, dynamic SQL,
PostgREST filters, NoSQL operators, a shell into a DB tool."""
import re

from .common import Rule, blank_comments, code_files, dedupe_lines, hits

DOMAIN = "injection"
JS_EXTS = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".svelte",
           ".astro")
SQL_EXTS = (".sql", ".pgsql", ".plpgsql")
GAP = r"[^'\"`]{0,200}"
STMT = (
    rf"(?:select\b{GAP}\bfrom\b{GAP}\b(?:where|join|limit|order\s+by"
    rf"|group\s+by)\b|select\s+\*\s+from\b"
    rf"|insert\s+into\s+[\w.\"]+{GAP}\b(?:values|select)\b"
    r"|insert\s+into\s+[\w.\"]+\s*\(|update\s+[\w.\"]+\s+set\b"
    r"|delete\s+from\s+[\w.\"]+\s+where\b"
    r"|\bwhere\s+[\w.\"]+\s*(?:=|like\b|in\b|<|>)"
    r"|create\s+(?:table|index)\s|drop\s+(?:table|index)\s"
    r"|alter\s+table\s|truncate\s+table\s)")
DQ = r"[^\"\n]{0,200}"
SQ = r"[^'\n]{0,200}"


def _quoted(tail):
    """A double- or single-quoted SQL statement string followed by tail."""
    return rf"\"{DQ}?{STMT}{DQ}\"{tail}|'{SQ}?{STMT}{SQ}'{tail}"


CONCAT = {
    JS_EXTS: re.compile(
        rf"(?<![\w$)\]>])`[^`]{{0,400}}?{STMT}[^`]{{0,400}}?\$\{{|"
        + _quoted(r"\s*\+\s*[\w$(]"), re.I),
    (".py",): re.compile(
        rf"\bf['\"][^'\"\n]{{0,200}}?{STMT}|"
        + _quoted(r"\s*(?:%\s*[\w(]|\.format\(|\+\s*[\w(])"), re.I),
    (".php",): re.compile(
        rf"\"{DQ}?{STMT}{DQ}\$[A-Za-z_]\w*|"
        + _quoted(r"\s*\.\s*\$[A-Za-z_]"), re.I),
    (".rb",): re.compile(rf"\"{DQ}?{STMT}{DQ}#\{{", re.I),
    (".rs",): re.compile(rf"format!\(\s*\"{DQ}?{STMT}", re.I),
    (".go",): re.compile(rf"fmt\.Sprintf\(\s*\"{DQ}?{STMT}", re.I),
}
RAW = {
    JS_EXTS: re.compile(
        r"(?:\$queryRawUnsafe|\$executeRawUnsafe|\bknex\.raw"
        r"|\bsequelize\.query|\b[Ss]equelize\.literal)\s*\(\s*(?![\s'\"`)])"),
    (".py",): re.compile(
        r"\.objects\.raw\(\s*(?![\s'\"`)])|\.extra\(\s*(?![\s'\"`)])"),
    (".rb",): re.compile(r"\.where\(\s*\"[^\"\n]{0,200}#\{"),
}
SQLA_TEXT = re.compile(r"\btext\s*\(\s*(?![\s'\"`)])")
DYNAMIC_EXEC = re.compile(r"\bexecute\s+(?:'[^']*'|\w+)\s*\|\|", re.I)
POSTGREST = re.compile(
    r"\.(?:or|filter|not|match|textSearch)\(\s*(?:`[^`\n]{0,200}\$\{"
    r"|['\"][^'\"\n]{0,200}['\"]\s*\+\s*[\w$])")
NOSQL = re.compile(
    r"\$where\s*:\s*(?:['\"`]|\w)"
    r"|\.(?:find|findOne|findOneAndUpdate|findOneAndDelete|updateOne"
    r"|updateMany|deleteOne|deleteMany|countDocuments|replaceOne)\(\s*"
    r"(?:req\.(?:body|query|params)\b"
    r"|\{\s*\w+\s*:\s*req\.(?:body|query|params)\.\w+\s*[,}])")
SHELL_DB = re.compile(
    r"\b(?:exec|execSync|spawn|spawnSync|system|popen|subprocess\.\w+"
    r"|os\.system|Command::new|shell_exec|passthru|proc_open)\s*\("
    r"[^\n]{0,300}?\b(?:psql|mysql|mysqldump|pg_dump|pg_restore|mongosh"
    r"|mongo|mongodump|redis-cli|sqlite3|clickhouse-client)\b[^\n]{0,300}?"
    r"(?:\$\{|\+\s*[\w$]|#\{|\{\w+\}|%s|\$[A-Za-z_])")


def applies(project):
    return bool(project.with_ext(*JS_EXTS, ".py", ".php", ".rb", ".rs",
                                 ".go", *SQL_EXTS))


def _by_ext(files, exts):
    return [p for p in files if p.suffix.lower() in exts]


def _per_language(project, files, table, rule, message):
    out = []
    for exts, regex in table.items():
        out += hits(project, _by_ext(files, exts), regex, rule, message)
    return out


def _raw_unsafe(project, files):
    rule = Rule(DOMAIN, "INJ-SQL-RAW-UNSAFE", "FAIL")
    msg = "raw SQL escape fed a non-literal: bind the values"
    sqla = [p for p in _by_ext(files, (".py",))
            if "sqlalchemy" in project.text(p)]
    return (_per_language(project, files, RAW, rule, msg)
            + hits(project, sqla, SQLA_TEXT, rule, msg))


def _concat(project, files):
    return _per_language(
        project, files, CONCAT, Rule(DOMAIN, "INJ-SQL-CONCAT", "FAIL"),
        "SQL built from an expression: use placeholders")


def _dynamic_exec(project):
    rule = Rule(DOMAIN, "INJ-SQL-DYNAMIC-EXEC", "WARN")
    out = []
    for path in code_files(project, SQL_EXTS):
        text = blank_comments(project.text(path))
        for m in DYNAMIC_EXEC.finditer(text):
            out.append(project.found(
                rule, path, m.start(),
                "EXECUTE built with ||: use format() with %I/%L and USING"))
    return out


def _postgrest(project, files):
    client = [p for p in _by_ext(files, JS_EXTS)
              if "supabase" in project.text(p)]
    return hits(project, client, POSTGREST,
                Rule(DOMAIN, "INJ-POSTGREST-FILTER", "WARN"),
                "PostgREST filter string built from a value: use .eq()")


def _nosql(project, files):
    return hits(project, _by_ext(files, JS_EXTS), NOSQL,
                Rule(DOMAIN, "INJ-NOSQL-OPERATOR", "WARN"),
                "filter taken from the request: allowlist fields, cast")


def _shell_db(project, files):
    return hits(project, files, SHELL_DB,
                Rule(DOMAIN, "INJ-SHELL-DB-TOOL", "FAIL"),
                "DB tool run through a shell with input: pass an argv")


def check(project):
    files = code_files(project)
    found = _raw_unsafe(project, files) + _concat(project, files)
    found += _dynamic_exec(project) + _postgrest(project, files)
    found += _nosql(project, files) + _shell_db(project, files)
    return dedupe_lines(found)
```

- [ ] **Step 5: Register the domain in `scan.py`**

In `CATALOGUE`: add `injection` to the `from checks import …` line (alphabetical: `a11y, apis, functions, hosting, injection, messaging, supabase`), add `"injection": injection,` as the LAST entry of `domains`, and `"INJ": "injection",` in `rule_domains`.

- [ ] **Step 6: Run the suite**

Run: `make test suite=lib/tests/guardrails-scan.test.sh`
Expected: all PASS, including `clean has no FAIL or WARN` (the fixture's `0001_init.sql` has `execute function …` without `||`) and `empty project marks hosting not applicable` (injection sits after hosting). A mutant or lock that fails is a regex bug: fix the regex against the snippet, never the snippet.

- [ ] **Step 7: Commit**

```bash
git add skills/guardrails/scripts/checks/common.py skills/guardrails/scripts/checks/injection.py skills/guardrails/scripts/scan.py lib/tests/guardrails-scan.test.sh
git commit -m "feat(guardrails): injection domain (INJ-*): per-language SQL concat and raw escapes, dynamic EXECUTE, PostgREST, NoSQL, shell into DB tools; shared code_files/hits/dedupe helpers"
```

---

### Task 3: Domain `exposure`: walker lists large files, `client_reachable` shared, mutants and benign locks

**Files:**
- Modify: `skills/guardrails/scripts/checks/common.py` (walker returns large files; `client_reachable` and its constants)
- Modify: `skills/guardrails/scripts/checks/supabase.py` (use `common.client_reachable` and `common.CLIENT_EXTS`; delete its own `_client_reachable`, `SERVER_SEGMENTS`, `CLIENT_SEGMENTS`, `CLIENT_EXTS`, `SCRIPT_EXTS`)
- Modify: `skills/guardrails/scripts/checks/passwords.py` (rename `_log_args` to `log_args`, public; update its one caller)
- Create: `skills/guardrails/scripts/checks/exposure.py`
- Modify: `skills/guardrails/scripts/scan.py` (catalogue: `exposure` last, prefix `EXP`)
- Test: `lib/tests/guardrails-scan.test.sh`

**Interfaces:**
- Consumes: `apis.ENV_NAME`, `ENV_SAMPLE`, `ignore_patterns`, `is_ignored_env`, `route_files`; `passwords.log_args`, `passwords.LOGGED_NAME`; `common.code_files`, `hits`, `dedupe_lines`.
- Produces: `common.client_reachable(project, path) -> bool`, `common.CLIENT_EXTS`, `Project.large` (regular files over `MAX_BYTES`, never read: paths only). Rules `EXP-CONSOLE-DATA`, `EXP-HYDRATED-SENSITIVE`, `EXP-MARKUP-COMMENT`, `EXP-DATA-ATTR-SENSITIVE`, `EXP-ERROR-MESSAGE`, `EXP-RESPONSE-WIDE` (WARN), `EXP-SOURCEMAP-PUBLIC` (FAIL / WARN), `EXP-ERROR-STACK`, `EXP-DEBUG-ON` (FAIL).

- [ ] **Step 1: Walker: list large files without reading them**

In `checks/common.py` replace `_is_scannable`, `_kept_files` and the `Project.__init__` body:

```python
def _candidate(path):
    """A regular, non-symlink, non-binary file the walker may list."""
    if path.name in SKIP_FILES or path.suffix.lower() in BINARY_EXTS:
        return False
    try:
        return path.is_file() and not path.is_symlink()
    except OSError:
        return False


def _small(path):
    try:
        return path.stat().st_size <= MAX_BYTES
    except OSError:
        return False


def _kept_files(root, base, names, prefixes):
    for name in names:
        path = Path(base) / name
        if _candidate(path) and not _excluded(root, path, prefixes):
            yield path, _small(path)
```

and in `Project.__init__`:

```python
        listed = sorted(_walk(self.root, prefixes))
        self.files = [p for p, small in listed if small]
        self.large = [p for p, small in listed if not small]
```

`_walk` is unchanged (it yields what `_kept_files` yields). Run `make test suite=lib/tests/guardrails-scan.test.sh`: still green (the symlink and size behaviour of `files` is identical).

- [ ] **Step 2: Move `client_reachable` into `common.py`**

Append to `checks/common.py`:

```python
SERVER_SEGMENTS = {
    "functions", "api", "server", "scripts", "tests", "test", "migrations",
    "seed", ".github", "supabase", "tools",
}
CLIENT_SEGMENTS = {
    "components", "public", "static", "client", "browser", "www", "islands",
}
CLIENT_EXTS = (".vue", ".svelte", ".html", ".htm")
CLIENT_SCRIPT_EXTS = (".ts", ".tsx", ".js", ".jsx", ".mjs")


def client_reachable(project, path):
    """Heuristic: this file's text ends up in a browser bundle or page."""
    segments = set(project.segments(path))
    if segments & SERVER_SEGMENTS:
        return False
    if path.suffix.lower() in CLIENT_EXTS:
        return True
    if path.suffix.lower() not in CLIENT_SCRIPT_EXTS:
        return False
    head = project.text(path)[:300]
    return bool(segments & CLIENT_SEGMENTS) or "use client" in head
```

In `supabase.py`: add `CLIENT_EXTS, client_reachable` to the `from .common import …` line; delete the module's `SERVER_SEGMENTS`, `CLIENT_SEGMENTS`, `CLIENT_EXTS`, `SCRIPT_EXTS` constants and its `_client_reachable` function; change the single call site (`if _client_reachable(project, path)`) to `if client_reachable(project, path)`. The `project.with_ext(*SOURCE_EXTS, *CLIENT_EXTS)` line keeps working through the import. In `passwords.py` rename `_log_args` to `log_args` (definition and its one call). Run the suite again: green.

- [ ] **Step 3: Write the failing mutants and benign locks**

Add to `lib/tests/guardrails-scan.test.sh` after the `== injection` block:

```bash
echo "== exposure"
mutant console-data WARN EXP-CONSOLE-DATA \
  "printf '%s\n' 'console.log(\"saved\", session);' >> $TSX"
mutant sourcemap-next FAIL EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'module.exports = { productionBrowserSourceMaps: true };' > next.config.js"
mutant sourcemap-vite-inline FAIL EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'export default { build: { sourcemap: \"inline\" } };' > vite.config.ts"
mutant sourcemap-webpack-warn WARN EXP-SOURCEMAP-PUBLIC \
  "printf '%s\n' 'module.exports = { devtool: \"eval-source-map\" };' > webpack.config.js"
mutant sourcemap-public-dir FAIL EXP-SOURCEMAP-PUBLIC \
  "mkdir -p public/assets; printf '%s\n' '{\"version\":3,\"sources\":[\"src/app.ts\"],\"mappings\":\"AAAA\"}' > public/assets/app.js.map"
mutant sourcemap-large-map FAIL EXP-SOURCEMAP-PUBLIC \
  "mkdir -p public; head -c 1100000 /dev/zero | tr '\\0' a > public/app.js.map"
mutant hydrated-sensitive WARN EXP-HYDRATED-SENSITIVE \
  "printf '%s\n' 'export async function getServerSideProps() { return { props: { accessToken: process.env.CRM_TOKEN } }; }' > src/pages/account.tsx"
mutant markup-comment WARN EXP-MARKUP-COMMENT \
  "printf '%s\n' '<!-- staging login: see the internal wiki before release -->' > src/pages/index.html"
mutant data-attr-sensitive WARN EXP-DATA-ATTR-SENSITIVE \
  "printf '%s\n' '<div data-api-key={key}>x</div>' >> $TSX"
mutant error-stack FAIL EXP-ERROR-STACK \
  "printf '%s\n' 'export function onError(err: Error) { return new Response(err.stack, { status: 500 }); }' >> $API"
mutant error-message WARN EXP-ERROR-MESSAGE \
  "printf '%s\n' 'export function onFail(err: Error) { return Response.json({ error: err.message }, { status: 500 }); }' >> $API"
mutant debug-on FAIL EXP-DEBUG-ON \
  "printf '%s\n' 'DEBUG = True' > src/settings.py"
mutant debug-env FAIL EXP-DEBUG-ON \
  "printf '%s\n' 'APP_DEBUG=true' > .env.production"
mutant response-wide WARN EXP-RESPONSE-WIDE \
  "printf '%s\n' 'const { data } = await db.from(\"profiles\").select(\"*\");' >> $API"
mutant error-stack-single-file FAIL EXP-ERROR-STACK \
  "printf '%s\n' 'app.use((err, req, res, next) => res.status(500).send(err.stack));' > server.js"
mutant hydrated-identifier WARN EXP-HYDRATED-SENSITIVE \
  "printf '%s\n' 'export async function getServerSideProps() { const token = await crm(); return { props: { accessToken: token } }; }' > src/pages/account.tsx"
mutant console-next-page WARN EXP-CONSOLE-DATA \
  "printf '%s\n' 'export default function Home({ user }) { console.log(\"render\", user); return null; }' > src/pages/index.tsx"
```

And these benign locks next to the Task 2 ones:

```bash
benign console-plain-string \
  "printf '%s\n' 'console.log(\"ready\");' >> $TSX"
benign console-string-data \
  "printf '%s\n' 'console.log(\"loading data\");' >> $TSX"
benign console-server-file \
  "printf '%s\n' 'console.log(\"saved\", session);' >> $API"
benign logger-stack \
  "printf '%s\n' 'logger.error(\`notes failed \${res.statusCode}\`, err.stack);' >> $API"
benign client-console-stack \
  "printf '%s\n' 'console.warn(\"load failed\", err.stack);' >> $TSX"
benign vite-hidden-sourcemap \
  "printf '%s\n' 'export default { build: { sourcemap: \"hidden\" } };' > vite.config.ts"
benign vendored-map \
  "mkdir -p static/css; printf '%s\n' '{\"version\":3,\"mappings\":\"AAAA\"}' > static/css/bootstrap.min.css.map"
benign level-map \
  "mkdir -p public/levels; printf '%s\n' 'tiles 10x10' > public/levels/1.map"
benign debug-from-env \
  "printf '%s\n' 'DEBUG = os.environ.get(\"DEBUG\") == \"1\"' > src/settings.py"
benign debug-local-settings \
  "printf '%s\n' 'DEBUG = True' > src/settings_local.py"
benign debug-lowercase-elsewhere \
  "printf '%s\n' '    debug = True' > src/lib/tools.py"
benign errorhandler-dev-guard \
  "printf '%s\n' 'if (process.env.NODE_ENV === \"development\") app.use(errorhandler());' >> $API"
benign flask-config-class \
  "printf '%s\n' 'class DevelopmentConfig(Config):' '    DEBUG = True' > src/config.py"
benign error-generic-message \
  "printf '%s\n' 'export function onFail() { return Response.json({ error: \"internal error\" }, { status: 500 }); }' >> $API"
benign ts-type-token \
  "printf '%s\n' 'export async function getServerSideProps() { return { props: {} }; }' 'type Session = { token: string; };' > src/pages/account.tsx"
benign no-semicolon-type \
  "printf '%s\n' 'export async function getServerSideProps() { return { props: {} }; }' 'interface Props {' '  token: string' '}' > src/pages/account.tsx"
benign prisma-multiline-select \
  "printf '%s\n' 'const u = await prisma.user.findUnique({' '  where: { id },' '  select: { id: true },' '});' >> $API"
benign csrf-hidden-input \
  "printf '%s\n' '<input type=\"hidden\" name=\"csrf_secret\" value={csrf} />' >> $TSX"
benign csrf-data-attr \
  "printf '%s\n' '<form data-csrf-secret={csrf}>x</form>' >> $TSX"
# A committed .env.development trips the api domain's API-ENV-NOT-IGNORED by
# design (the fixture's .gitignore lists .env only), so this lock is scoped
# to the exposure domain: a dev env file must raise no EXP finding.
cp -R "$GOOD" "$WORK/env-dev"
printf '%s\n' 'APP_DEBUG=true' 'GENERATE_SOURCEMAP=true' > "$WORK/env-dev/.env.development"
out=$(scan --domain exposure "$WORK/env-dev")
check "a dev env file raises no exposure finding" \
  "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1
```

- [ ] **Step 4: Run the suite, the seventeen mutants must fail**

Run: `make test suite=lib/tests/guardrails-scan.test.sh 2>&1 | grep -c 'FAIL .* raises'`
Expected: `18`: the seventeen mutants plus the exposure-scoped dev-env check, whose `--domain exposure` is a usage error until the domain exists.

- [ ] **Step 5: Create `skills/guardrails/scripts/checks/exposure.py`**

```python
"""Exposure checks: what the browser can see that it should not."""
import re

from . import passwords
from .apis import ENV_NAME, ENV_SAMPLE, ignore_patterns, is_ignored_env
from .apis import route_files
from .common import Rule, client_reachable, code_files, dedupe_lines, hits

DOMAIN = "exposure"
MARKUP_EXTS = (".html", ".htm", ".astro", ".php", ".ejs", ".hbs", ".twig",
               ".njk", ".liquid")
ATTR_EXTS = MARKUP_EXTS + (".jsx", ".tsx", ".vue", ".svelte")
DEV_TOKEN = re.compile(
    r"(?:^|[._-])(?:dev|development|local|test|testing)(?:[._-]|$)", re.I)
CONSOLE = re.compile(
    r"\bconsole\.(?:log|info|debug|dir|table)\s*\(([^\n]{0,300})")
DATA_NAMES = re.compile(
    r"\b(?:users?|profile|session|token|account|customer|order|payment"
    r"|response|res|data|result|rows|body|headers|props|state|error|err"
    r"|json|payload|record|items?)\b", re.I)
SENSITIVE = (
    r"(?:token|accessToken|refreshToken|secret|apiKey|api_key|password"
    r"|passwordHash|password_hash|serviceRole|service_role|privateKey"
    r"|private_key|ssn|iban|stripeSecret|clientSecret)")
LOADER = re.compile(
    r"getServerSideProps|getStaticProps"
    r"|export\s+(?:async\s+)?function\s+(?:loader|load)\b"
    r"|export\s+const\s+(?:loader|load)\b|window\.__\w+__\s*=")
TYPEISH = (r"(?:string|number|boolean|null|undefined|unknown|any|never"
           r"|[A-Z][\w<>\[\]|]*)")
HYDRATED = re.compile(
    rf"\b{SENSITIVE}\s*:(?!\s*{TYPEISH}\s*(?:[;,}}]|$))", re.M)
COMMENT = re.compile(r"<!--(.*?)-->", re.S)
COMMENT_WORDS = re.compile(
    r"\b(?:todo|fixme|hack|xxx|debug|password|passwd|secret|token"
    r"|api[-_ ]?key|internal|staging|localhost|admin|remove before"
    r"|do not commit|don'?t commit|temporary)\b", re.I)
DATA_ATTR = re.compile(
    r"\b(data-[\w-]*(?:secret|api-?_?key|password|passwd|jwt|private"
    r"|credential|service-?role)[\w-]*)\s*=", re.I)
HIDDEN_INPUT = re.compile(r"<input\b[^>\n]{0,300}>", re.I)
SENSITIVE_NAME = re.compile(
    r"secret|api[-_]?key|password|passwd|jwt|private|credential", re.I)
SAFE_NAME = re.compile(r"csrf|xsrf|authenticity|nonce", re.I)
SENDING = (
    r"(?:\bres\.(?:status|json|send|end|write)\b"
    r"|\breply\.(?:send|code|status)\b|\bctx\.body\b|\bResponse\("
    r"|Response\.json\(|\bjsonify\(|\bJSONResponse\(|\bHTTPException\("
    r"|\bdetail\s*=|\becho\b)")
ERR = r"(?:err|error|e|exc|exception)"
ERROR_STACK = re.compile(
    rf"{SENDING}[^\n]{{0,300}}?(?:\b{ERR}\.stack\b|traceback\.format_exc"
    rf"|getTraceAsString\(\))"
    rf"|\b(?:json|send)\s*\(\s*\{{[^}}\n]{{0,200}}\berror\s*:\s*{ERR}\s*[,}}]")
ERROR_MESSAGE = re.compile(
    rf"{SENDING}[^\n]{{0,300}}?(?:\b{ERR}\.message\b|\bstr\({ERR}\)"
    rf"|\brepr\({ERR}\)|->getMessage\(\))")
SETTINGS_NAME = re.compile(r"^(?:settings|config)", re.I)
DEBUG_SETTINGS = re.compile(r"^DEBUG\s*=\s*True\b", re.M)
DEBUG_ENV = re.compile(
    r"^\s*(?:APP_DEBUG\s*=\s*true|FLASK_DEBUG\s*=\s*1)\b", re.M | re.I)
DEBUG_CODE = re.compile(
    r"app\.debug\s*=\s*True|app\.run\([^)\n]{0,200}debug\s*=\s*True")
DEBUG_HANDLER = re.compile(
    r"^(?![^\n]*(?:development|NODE_ENV))[^\n]*app\.use\(\s*errorhandler\(\)",
    re.M)
DEBUG_RAILS = re.compile(r"consider_all_requests_local\s*=\s*true")
NEXT_MAPS = re.compile(r"productionBrowserSourceMaps\s*:\s*true")
VITE_MAPS = re.compile(r"\bsourcemap\s*:\s*(?:true|['\"]inline['\"])")
WEBPACK_DEVTOOL = re.compile(
    r"\bdevtool\s*:\s*['\"](?:source-map|eval[\w-]*|inline[\w-]*"
    r"|cheap[\w-]*)['\"]")
ENV_MAPS = re.compile(r"^\s*GENERATE_SOURCEMAP\s*=\s*true\b", re.M | re.I)
ANGULAR_MAPS = re.compile(r"\"sourceMap\"\s*:\s*true")
PUBLIC_DIRS = {"public", "static", "assets", "www"}
VENDORED = re.compile(r"\.min\.|vendor|bootstrap|jquery", re.I)
USERS = (r"(?:users|profiles|accounts|customers|members|employees"
         r"|patients|clients)")
WIDE = re.compile(
    rf"\.from\(\s*['\"]{USERS}['\"]\s*\)\s*\.select\(\s*['\"]\*['\"]\s*\)"
    rf"|select\s+\*\s+from\s+{USERS}\b"
    r"|\b(?:user|profile|account|customer|member)\.(?:findUnique|findFirst"
    r"|findMany)\(\s*\{(?![^\n]{0,300}\b(?:select|omit)\s*:)[^\n]{0,300}\}"
    r"\s*\)", re.I)


def applies(project):
    return bool(project.with_ext(".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
                                 ".py", ".php", ".rb", ".vue", ".svelte",
                                 ".astro", *MARKUP_EXTS))


def _named(project, prefix):
    return [p for p in project.files if p.name.startswith(prefix)]


def _client(project, path):
    """client_reachable, plus Next pages and a root App component."""
    if client_reachable(project, path):
        return True
    segments = project.segments(path)
    return (path.suffix.lower() in (".tsx", ".jsx") and "api" not in segments
            and ("pages" in segments or path.stem == "App"))


def _console_data(project, files):
    rule = Rule(DOMAIN, "EXP-CONSOLE-DATA", "WARN")
    out = []
    for path in (p for p in files if _client(project, p)):
        for m in CONSOLE.finditer(project.text(path)):
            if passwords.LOGGED_NAME.search(m.group(1)):
                continue
            if DATA_NAMES.search(passwords.log_args(m.group(1))):
                out.append(project.found(
                    rule, path, m.start(),
                    "data logged to the browser console"))
    return out


def _map_config(project):
    fail = Rule(DOMAIN, "EXP-SOURCEMAP-PUBLIC", "FAIL")
    warn = Rule(DOMAIN, "EXP-SOURCEMAP-PUBLIC", "WARN")
    out = hits(project, _named(project, "next.config"), NEXT_MAPS, fail,
               "production source maps enabled")
    out += hits(project, _named(project, "vite.config"), VITE_MAPS, fail,
                "build source maps enabled: use 'hidden' or false")
    prod = _named(project, "webpack.prod")
    other = [p for p in _named(project, "webpack") if p not in prod]
    out += hits(project, prod, WEBPACK_DEVTOOL, fail,
                "devtool emits readable source maps in production")
    out += hits(project, other, WEBPACK_DEVTOOL, warn,
                "devtool emits readable source maps: confirm not in prod")
    return out + hits(project, project.named("angular.json"), ANGULAR_MAPS,
                      warn, "sourceMap true: confirm not the production build")


def _env_files(project):
    """Committed env files that are not samples and not dev/local/test."""
    patterns = ignore_patterns(project)
    return [p for p in project.files if ENV_NAME.fullmatch(p.name)
            and not p.name.endswith(ENV_SAMPLE)
            and not DEV_TOKEN.search(p.name[4:] or "x")
            and not is_ignored_env(p, patterns)]


def _public_map(project, path):
    return (set(project.segments(path)) & PUBLIC_DIRS
            and not VENDORED.search(project.rel(path)))


def _map_files(project):
    rule = Rule(DOMAIN, "EXP-SOURCEMAP-PUBLIC", "FAIL")
    out = hits(project, _env_files(project), ENV_MAPS, rule,
               "GENERATE_SOURCEMAP=true ships source maps")
    small = [p for p in project.with_ext(".map")
             if _public_map(project, p) and '"mappings"' in project.text(p)]
    large = [p for p in project.large
             if p.suffix.lower() == ".map" and _public_map(project, p)]
    return out + [project.found(rule, p, 0, "source map in a public directory")
                  for p in small + large]


def _hydrated(project, files):
    loaders = [p for p in files if LOADER.search(project.text(p))]
    return hits(project, loaders, HYDRATED,
                Rule(DOMAIN, "EXP-HYDRATED-SENSITIVE", "WARN"),
                "sensitive key in server-to-client state")


def _markup_comments(project):
    rule = Rule(DOMAIN, "EXP-MARKUP-COMMENT", "WARN")
    return [project.found(rule, path, m.start(),
                          "HTML comment shipped to the browser carries "
                          "internal notes")
            for path in project.with_ext(*MARKUP_EXTS)
            for m in COMMENT.finditer(project.text(path))
            if COMMENT_WORDS.search(m.group(1))]


def _hidden_sensitive(tag):
    if not re.search(r"type\s*=\s*[\"']?hidden\b", tag, re.I):
        return False
    name = re.search(r"name\s*=\s*[\"']([^\"']+)", tag, re.I)
    return bool(name and SENSITIVE_NAME.search(name.group(1))
                and not SAFE_NAME.search(name.group(1)))


def _data_attrs(project):
    rule = Rule(DOMAIN, "EXP-DATA-ATTR-SENSITIVE", "WARN")
    out = []
    for path in project.with_ext(*ATTR_EXTS):
        text = project.text(path)
        out += [project.found(rule, path, m.start(),
                              "sensitive value in a data-* attribute")
                for m in DATA_ATTR.finditer(text)
                if not SAFE_NAME.search(m.group(1))]
        out += [project.found(rule, path, m.start(),
                              "sensitive value in a hidden input")
                for m in HIDDEN_INPUT.finditer(text)
                if _hidden_sensitive(m.group(0))]
    return out


def _errors(project, files):
    server = [p for p in files if not client_reachable(project, p)]
    stack = hits(project, server, ERROR_STACK,
                 Rule(DOMAIN, "EXP-ERROR-STACK", "FAIL"),
                 "stack trace or error object sent to the client")
    message = hits(project, server, ERROR_MESSAGE,
                   Rule(DOMAIN, "EXP-ERROR-MESSAGE", "WARN"),
                   "raw exception message sent to the client")
    return dedupe_lines(stack + message)


def _settings_modules(project, files):
    return [p for p in files if p.suffix == ".py"
            and (SETTINGS_NAME.match(p.name)
                 or "settings" in project.segments(p))
            and not DEV_TOKEN.search(p.stem)]


def _debug(project, files):
    rule = Rule(DOMAIN, "EXP-DEBUG-ON", "FAIL")
    out = hits(project, _settings_modules(project, files), DEBUG_SETTINGS,
               rule, "DEBUG = True in a settings module")
    out += hits(project, _env_files(project), DEBUG_ENV, rule,
                "debug mode on in a committed env file")
    out += hits(project, files, DEBUG_CODE, rule,
                "debug mode enabled in code")
    out += hits(project, files, DEBUG_HANDLER, rule,
                "dev error handler mounted without an environment guard")
    return out + hits(project, project.named("production.rb"), DEBUG_RAILS,
                      rule, "full error pages enabled in production")


def _response_wide(project):
    return hits(project, route_files(project), WIDE,
                Rule(DOMAIN, "EXP-RESPONSE-WIDE", "WARN"),
                "whole rows of a user table returned: select the fields")


def check(project):
    files = code_files(project)
    found = _console_data(project, files) + _map_config(project)
    found += _map_files(project) + _hydrated(project, files)
    found += _markup_comments(project) + _data_attrs(project)
    found += _errors(project, files) + _debug(project, files)
    return found + _response_wide(project)
```

Notes: `_env_files` strips the leading `.env` before the dev-token test so `.env.development`, `.env.local` and `.env.test` are skipped while `.env.production` and `.env` are kept (the api domain's API-ENV-NOT-IGNORED still judges whether such a file belongs in git). The error rules scan every non-client source file, so a single-file `server.js` or `app.py` counts; `logger-stack` stays silent because the SENDING prefix requires a real sending call (`res.status` does not match `res.statusCode`), and `client-console-stack` because `ContactForm.tsx` is client-reachable. `DEBUG = True` is anchored at column 0: a Flask `class DevelopmentConfig` attribute is indented and stays silent. `route_files` is still imported for `_response_wide`. `ENV_NAME` and `ENV_SAMPLE` exist in `apis.py`.

- [ ] **Step 6: Register the domain**

In `scan.py`: import `exposure` (alphabetical: `a11y, apis, exposure, functions, hosting, injection, messaging, supabase`), add `"exposure": exposure,` as the LAST `domains` entry (after `injection`), and `"EXP": "exposure",` in `rule_domains`.

- [ ] **Step 7: Run the suite**

Run: `make test suite=lib/tests/guardrails-scan.test.sh`
Expected: every check PASS, `clean has no FAIL or WARN` included (the fixture's hidden `name="token"` carries no sensitive word; `notes.ts` returns `{ ok: true }`). A mutant or lock that fails is a regex bug: fix the regex, never the snippet, unless the snippet contradicts the spec table.

- [ ] **Step 8: Commit**

```bash
git add skills/guardrails/scripts/checks/common.py skills/guardrails/scripts/checks/supabase.py skills/guardrails/scripts/checks/passwords.py skills/guardrails/scripts/checks/exposure.py skills/guardrails/scripts/scan.py lib/tests/guardrails-scan.test.sh
git commit -m "feat(guardrails): exposure domain (EXP-*): console data, source maps (config, public dir, large files), hydrated state, shipped comments, data attributes, error bodies in routes, debug mode, wide responses"
```

---

### Task 4: Split accessibility out: `/a11y` scanner, fixture and suite; guardrails drops the domain

**Files:**
- Move: `skills/guardrails/scripts/checks/a11y.py` → `skills/a11y/scripts/a11y_checks.py` (`git mv`)
- Create: `skills/a11y/scripts/scan.py`
- Move: `lib/tests/fixtures/guardrails-good/src/styles.css` → `lib/tests/fixtures/a11y-good/src/styles.css` (`git mv`; its only users were the a11y focus mutants)
- Create: `lib/tests/fixtures/a11y-good/src/components/ContactForm.tsx` (copy; the guardrails fixture keeps its own for the EXP tests)
- Create: `lib/tests/a11y-scan.test.sh`
- Modify: `skills/guardrails/scripts/scan.py` (drop `a11y` from the catalogue)
- Modify: `lib/tests/guardrails-scan.test.sh` (drop the a11y blocks, re-point check modes and CLI tests)

**Interfaces:**
- Consumes: `scanner.Catalogue`, `scanner.main` (Task 1).
- Produces: `python3 -B skills/a11y/scripts/scan.py <path> [--domain a11y] [--exclude] [--json] [--assert-absent A11Y-…:path] [--baseline f.json]`, markers `A11Y-CLEAR <n>` and `A11Y-NO-NEW`, report header `a11y scan: …`, exit 2 with a named message when the guardrails engine directory is missing.

- [ ] **Step 1: Move the module and fix its import**

```bash
mkdir -p skills/a11y/scripts
git mv skills/guardrails/scripts/checks/a11y.py skills/a11y/scripts/a11y_checks.py
```

In `skills/a11y/scripts/a11y_checks.py` change `from .common import Rule, blank_markup_comments` to `from checks.common import Rule, blank_markup_comments`. Nothing else changes in the file.

- [ ] **Step 2: Create `skills/a11y/scripts/scan.py`**

```python
#!/usr/bin/env python3
"""Static accessibility scan: keyboard, visible focus, alt text, labels.

Runs the guardrails scan engine (skills/guardrails/scripts/scanner.py) on
the a11y catalogue. Same options and exit codes; markers A11Y-CLEAR and
A11Y-NO-NEW.
"""
import importlib
import sys
from pathlib import Path

ENGINE = Path(__file__).resolve().parents[2] / "guardrails" / "scripts"
if not ENGINE.is_dir():
    print(f"usage error: scan engine missing at {ENGINE} "
          "(the guardrails skill must be installed)", file=sys.stderr)
    sys.exit(2)
sys.path.insert(0, str(ENGINE))

scanner = importlib.import_module("scanner")
a11y_checks = importlib.import_module("a11y_checks")

CATALOGUE = scanner.Catalogue(
    name="a11y",
    domains={"a11y": a11y_checks},
    rule_domains={"A11Y": "a11y"},
)

if __name__ == "__main__":
    sys.exit(scanner.main(sys.argv[1:], CATALOGUE))
```

- [ ] **Step 3: Create the a11y fixture**

```bash
mkdir -p lib/tests/fixtures/a11y-good/src/components
git mv lib/tests/fixtures/guardrails-good/src/styles.css lib/tests/fixtures/a11y-good/src/styles.css
cp lib/tests/fixtures/guardrails-good/src/components/ContactForm.tsx lib/tests/fixtures/a11y-good/src/components/ContactForm.tsx
```

- [ ] **Step 4: Create `lib/tests/a11y-scan.test.sh`** (then `chmod +x`)

The suite proves the a11y catalogue: the clean fixture, one mutant per rule, the two benign locks, the A11Y markers, the gates.sh wiring and the rejection of guardrails rules and domains. Engine behaviour (symlinks, size cap, `--exclude`, JSON shape, empty tree) is proven once in `guardrails-scan.test.sh` on the same code.

```bash
#!/usr/bin/env bash
# lib/tests/a11y-scan.test.sh — floor of the /a11y scanner catalogue.
# The clean fixture must scan with zero FAIL and zero WARN. Each mutant breaks
# one rule on a copy of it and must raise that rule at the expected severity
# (positive control). The A11Y-CLEAR / A11Y-NO-NEW markers, the gates.sh
# contract wiring and the rejection of guardrails rules are checked too; the
# shared engine itself is proven in guardrails-scan.test.sh.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCAN="$ROOT/skills/a11y/scripts/scan.py"
GOOD="$ROOT/lib/tests/fixtures/a11y-good"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0; LAST_OUT=""

check() { # check <label> <got> <want>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  PASS $1"
  else FAIL=$((FAIL+1)); echo "  FAIL $1 (got '$2', want '$3')"; fi
}

scan() { python3 -B "$SCAN" "$@"; }

# edit <file> <sed-expr>: in-place edit without sed -i (BSD/GNU portable).
edit() { sed "$2" "$1" > "$1.new" && mv "$1.new" "$1"; }

has() { # has <SEVERITY> <RULE>: the last scan raised it
  printf '%s\n' "$LAST_OUT" | grep -Eq "^ +$1 +$2 " && echo yes || echo no
}

mutant() { # mutant <label> <SEVERITY> <RULE> <snippet run inside a copy>
  local label="$1" sev="$2" rule="$3" snippet="$4" dir
  dir="$WORK/$label"
  cp -R "$GOOD" "$dir" || { check "$label copy" failed ok; return; }
  if ! ( cd "$dir" && eval "$snippet" ) >/dev/null 2>&1; then
    check "$label setup" failed ok; return
  fi
  LAST_OUT=$(scan "$dir")
  check "$label raises $sev $rule" "$(has "$sev" "$rule")" yes
}

benign() { # benign <label> <snippet>: a legitimate pattern raises nothing
  local label="$1" snippet="$2" dir="$WORK/$1" out
  cp -R "$GOOD" "$dir" || { check "$label copy" failed ok; return; }
  if ! ( cd "$dir" && eval "$snippet" ) >/dev/null 2>&1; then
    check "$label setup" failed ok; return
  fi
  out=$(scan "$dir")
  check "$label raises no FAIL or WARN" \
    "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1
}

TSX=src/components/ContactForm.tsx

echo "== clean fixture"
out=$(scan "$GOOD"); rc=$?
check "clean exit code" "$rc" 0
check "clean has no FAIL or WARN" \
  "$(printf '%s\n' "$out" | grep -c ' 0 FAIL, 0 WARN')" 1
check "report is titled a11y" \
  "$(printf '%s\n' "$out" | grep -c '^a11y scan: ')" 1

echo "== rules"
mutant img-alt FAIL A11Y-IMG-ALT "edit $TSX 's/ alt=\"Company logo\"//'"
mutant field-label FAIL A11Y-FIELD-LABEL "edit $TSX '/<label htmlFor=\"email\">/d'"
mutant click-keyboard FAIL A11Y-CLICK-NO-KEYBOARD "edit $TSX 's/ onKeyDown={go}//'"
mutant tabindex-positive WARN A11Y-TABINDEX-POSITIVE \
  "edit $TSX 's/tabIndex={0}/tabIndex={2}/'"
mutant focus-css-warn WARN A11Y-FOCUS-OUTLINE \
  "printf 'a:focus { outline: none; }\n' > src/styles.css"
mutant focus-css-fail FAIL A11Y-FOCUS-OUTLINE \
  "printf 'a:focus { outline: none; }\n' > src/styles.css; edit $TSX 's/outline-none focus-visible:ring-2 focus-visible:ring-blue-500/x/'"
mutant focus-tailwind FAIL A11Y-FOCUS-OUTLINE \
  "edit $TSX 's/outline-none focus-visible:ring-2 focus-visible:ring-blue-500/outline-none/'"

echo "== benign patterns stay silent"
benign comment-with-img-tag \
  "printf '%s\n' '// the <img> below is decorative' >> $TSX"
benign dialog-overlay-click \
  "printf '%s\n' '<div role=\"dialog\" aria-label=\"x\" onClick={go}>y</div>' >> $TSX"

echo "== check modes (contract oracle and re-pass baseline)"
IMG="A11Y-IMG-ALT:$TSX"
cp -R "$GOOD" "$WORK/cm"; edit "$WORK/cm/$TSX" 's/ alt="Company logo"//'
out=$(scan "$WORK/cm" --assert-absent "$IMG"); rc=$?
check "positive control: the oracle fails while the hit is there" "$rc" 1
check "a failing oracle never prints the marker" \
  "$(printf '%s\n' "$out" | grep -c A11Y-CLEAR)" 0
out=$(scan "$GOOD" --assert-absent "$IMG"); rc=$?
check "the oracle passes once the hit is gone" "$rc" 0
check "a passing oracle prints the marker" \
  "$(printf '%s\n' "$out" | grep -c '^A11Y-CLEAR 1$')" 1
scan "$GOOD" --assert-absent "HOST-NO-RATE-LIMIT:$TSX" >/dev/null 2>&1
check "a guardrails rule is unknown here (exit 2)" "$?" 2
scan "$WORK/cm" --json > "$WORK/cm-before.json"
out=$(scan "$GOOD" --baseline "$WORK/cm-before.json"); rc=$?
check "baseline lists the fixed hit" \
  "$(printf '%s\n' "$out" | grep -c '^  FIXED A11Y-IMG-ALT ')" 1
check "baseline with no new hit exits 0 with the marker" \
  "$rc:$(printf '%s\n' "$out" | grep -c '^A11Y-NO-NEW$')" "0:1"
scan "$GOOD" --json > "$WORK/clean-before.json"
out=$(scan "$WORK/cm" --baseline "$WORK/clean-before.json"); rc=$?
check "baseline with a new hit exits 1 without the marker" \
  "$rc:$(printf '%s\n' "$out" | grep -c A11Y-NO-NEW)" "1:0"

# contract <dir> <file>: a fix contract whose oracle is the scanner itself
contract() {
  cat > "$2" <<EOC
# CONTRACT — a11y-oracle-test
## ACCEPTANCE CRITERIA
1. every image in the contact form has an alt
   CHECK: python3 -B '$SCAN' '$1' --assert-absent '$IMG'
   EXPECT: A11Y-CLEAR
   EVIDENCE: pending
## FILE SCOPE
$TSX
EOC
}
contract "$WORK/cm" "$WORK/c-unfixed.md"
bash "$ROOT/lib/gates.sh" run "$WORK/c-unfixed.md" >/dev/null 2>&1
check "gates.sh: the oracle is UNMET before the fix" "$?" 2
contract "$GOOD" "$WORK/c-fixed.md"
bash "$ROOT/lib/gates.sh" run "$WORK/c-fixed.md" >/dev/null 2>&1
check "gates.sh: the oracle is MET after the fix" "$?" 0

echo "== cli"
scan --domain api "$GOOD" >/dev/null 2>&1; check "a guardrails domain exits 2" "$?" 2

echo "---"
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 5: Run the new suite**

Run: `make test suite=lib/tests/a11y-scan.test.sh`
Expected: `failed: 0`. If `import a11y_checks` fails, print `sys.path` from the script: `ENGINE` must resolve to `<repo>/skills/guardrails/scripts`.

- [ ] **Step 6: Remove a11y from the guardrails catalogue**

In `skills/guardrails/scripts/scan.py`: drop `a11y` from the import line and from `domains`, drop `"A11Y": "a11y",` from `rule_domains`. Update the docstring first line to `Static guardrails scan: API, hosting, Supabase, messaging, functions, injection, exposure.` (wrap under 80 columns).

- [ ] **Step 7: Rewrite the a11y-coupled parts of `lib/tests/guardrails-scan.test.sh`**

1. Delete the whole `echo "== a11y"` block (the seven `mutant … A11Y-…` calls).
2. Delete the two benign cases `comment-with-img-tag` and `dialog-overlay-click` (they now live in the a11y suite).
3. In the check-modes block, replace the sample pair and its setup:
   - `IMG="A11Y-IMG-ALT:$TSX"` → `INJ="INJ-SQL-CONCAT:$API"`
   - `cp -R "$GOOD" "$WORK/cm"; edit "$WORK/cm/$TSX" 's/ alt="Company logo"//'` → `cp -R "$GOOD" "$WORK/cm"; printf '%s\n' 'const q = `select id from notes where owner = ${owner}`;' >> "$WORK/cm/$API"`
   - every `"$IMG"` → `"$INJ"`; the `--domain api --assert-absent` line stays on `--domain api` (injection unscanned → CONTROL); `A11Y-IMG-ALT` in the `grep -c '^  FIXED …'` and `'^  NEW   …'` checks → `INJ-SQL-CONCAT`; the "item without a path" line → `scan "$GOOD" --assert-absent INJ-SQL-CONCAT`.
   - In `contract()`: criterion text → `1. no SQL built from input in the notes route`, `'$IMG'` → `'$INJ'`, the `## FILE SCOPE` value → `$API`.
4. In the CLI block:
   - `out=$(scan --domain a11y "$GOOD")` and `check "domain filter keeps a11y" … '^\[a11y\]'` → `out=$(scan --domain injection "$GOOD")` and `check "domain filter keeps injection" … '^\[injection\]'`.
   - add after `bad domain exits 2`: `scan --domain a11y "$GOOD" >/dev/null 2>&1; check "a11y is no longer a guardrails domain (exit 2)" "$?" 2`
   - the `--exclude` test: `edit "$WORK/excl/$TSX" 's/ alt="Company logo"//'` → `printf '%s\n' 'const q = `select id from notes where owner = ${owner}`;' >> "$WORK/excl/$API"` and `--exclude src/components` → `--exclude src/pages`.
5. In the clean-fixture block add: `check "a11y is not scanned" "$(printf '%s\n' "$out" | grep -c '^\[a11y\]')" 0`.

- [ ] **Step 8: Run both suites**

Run: `make test suite='lib/tests/guardrails-scan.test.sh lib/tests/a11y-scan.test.sh'`
Expected: `all suites green`.

- [ ] **Step 9: Commit**

```bash
git add skills/a11y/scripts/scan.py skills/a11y/scripts/a11y_checks.py skills/guardrails/scripts/scan.py lib/tests/a11y-scan.test.sh lib/tests/fixtures/a11y-good lib/tests/fixtures/guardrails-good/src/styles.css lib/tests/guardrails-scan.test.sh
git commit -m "feat(a11y): standalone scanner on the shared engine (A11Y-CLEAR / A11Y-NO-NEW); guardrails drops the a11y domain"
```

---

### Task 5: Probe `exposure`, fail closed: source maps, error bodies, sensitive keys; path validation; `fetch` keeps error bodies

**Files:**
- Modify: `skills/guardrails/scripts/probe.py`
- Test: `lib/tests/guardrails-probe.test.sh`

**Interfaces:**
- Produces: plan key `exposure` (object; optional `scripts: [path]`, `error_routes: [path]`), probe ids `sourcemap:<script path>` (or `sourcemap` for a SKIPPED row), `error-body:<path>`, `fields:<path>`, domain `exposure`. Every plan path (`routes[].path`, `supabase.cross_user_paths[]`, `cors_path`, `rate_limit.path`, `exposure.scripts[]`, `exposure.error_routes[]`) must be a string starting with `/` (exit 2 otherwise). `Response.headers` is the `http.client.HTTPMessage` (case-insensitive `.get`), no longer a `dict`.

- [ ] **Step 1: Extend the fixture server and write the failing tests**

In `lib/tests/guardrails-probe.test.sh`, inside the `do_GET` handler of `server.py`, add before `return self._send(404, b"")`:

```python
        if path == "/":
            return self._send(200, b'<html><script src="/app.js"></script>'
                              b'<script src="/clean.js"></script>'
                              b'<script src=/inline.js></script>'
                              b'<script src="https://cdn.invalid/x.js"></script>'
                              b'</html>')
        if path == "/app.js":
            return self._send(200, b"console.log(1);\n//# sourceMappingURL=app.js.map\n")
        if path == "/app.js.map":
            return self._send(200, b'{"version":3,"sources":["src/app.ts"],"mappings":""}')
        if path == "/clean.js":
            return self._send(200, b"console.log(2);\n")
        if path == "/inline.js":
            return self._send(200, b"console.log(3);\n//# sourceMappingURL="
                              b"data:application/json;base64,eyJ2ZXJzaW9uIjozfQ==\n")
        if path == "/boom":
            return self._send(500, b"Traceback (most recent call last):\n"
                              b'  File "app.py", line 12, in handler\n')
        if path == "/api/me":
            return self._send(200, b'{"id": 1, "email": "t@t.io", '
                              b'"password_hash": "x", "profile": {"api_key": "y"}, '
                              b'"next_page_token": "abc", "hashtags": []}',
                              {"Content-Type": "application/json"})
```

And replace `do_OPTIONS` so header names are lowercase on `/lower`:

```python
    def do_OPTIONS(self):
        origin = self.headers.get("Origin", "")
        upper = ("Access-Control-Allow-Origin", "Access-Control-Allow-Credentials")
        names = tuple(n.lower() for n in upper) if self.path == "/lower" else upper
        self._send(204, b"", {names[0]: origin, names[1]: "true"})
```

Then add a test block before `echo "== JSON output"` (the inner heredocs use `EOF` exactly like the plan files already in this suite):

```bash
echo "== exposure probes"
cat > "$WORK/exposure.json" <<EOF
{"base_url": "$BASE",
 "routes": [{"path": "/api/me"}, {"path": "/api/guarded"}, {"path": "/api/private"}],
 "exposure": {"error_routes": ["/boom"]}}
EOF
OUT="$(probe --authorized "$WORK/exposure.json")"
check "a served source map is OPEN" \
  "$(verdict "$OUT" 'sourcemap:/app.js')" OPEN
check "an inline data: source map is OPEN" \
  "$(verdict "$OUT" 'sourcemap:/inline.js')" OPEN
check "a script with no map is CLOSED" \
  "$(verdict "$OUT" 'sourcemap:/clean.js')" CLOSED
check "a foreign-host script is never probed" \
  "$(printf '%s\n' "$OUT" | grep -c 'cdn.invalid')" 0
check "a traceback in an error body is OPEN" \
  "$(verdict "$OUT" 'error-body:/boom')" OPEN
check "the random 404 path is CLOSED" \
  "$(verdict "$OUT" 'error-body:/guardrails-probe-')" CLOSED
check "sensitive keys in a JSON response are OPEN" \
  "$(verdict "$OUT" 'fields:/api/me')" OPEN
check "the sensitive key names are listed, never the values" \
  "$(printf '%s\n' "$OUT" | grep -A1 'fields:/api/me' | grep -c 'api_key, password_hash$')" 1
check "fields on a 401 is SKIPPED, never CLOSED" \
  "$(verdict "$OUT" 'fields:/api/guarded')" SKIPPED
check "fields on a non-JSON body is SKIPPED" \
  "$(verdict "$OUT" 'fields:/api/private')" SKIPPED
cat > "$WORK/unreachable.json" <<EOF
{"base_url": "http://127.0.0.1:1", "exposure": {}}
EOF
OUT="$(probe --authorized "$WORK/unreachable.json")"
check "an unreachable base page gives a SKIPPED sourcemap row" \
  "$(verdict "$OUT" 'sourcemap')" SKIPPED
printf '{"base_url": "%s", "exposure": {"error_routes": ["boom"]}}\n' "$BASE" > "$WORK/badexp.json"
probe --authorized "$WORK/badexp.json" >/dev/null 2>&1
check "an error route not starting with / exits 2" "$?" 2
printf '{"base_url": "%s", "exposure": []}\n' "$BASE" > "$WORK/badexp2.json"
probe --authorized "$WORK/badexp2.json" >/dev/null 2>&1
check "a non-object exposure block exits 2" "$?" 2
printf '{"base_url": "%s", "exposure": {"scripts": "/app.js"}}\n' "$BASE" > "$WORK/badexp3.json"
probe --authorized "$WORK/badexp3.json" >/dev/null 2>&1
check "a scripts string instead of a list exits 2" "$?" 2
printf '{"base_url": "%s", "routes": [{"path": ".evil.invalid/x"}]}\n' "$BASE" > "$WORK/badroute.json"
probe --authorized "$WORK/badroute.json" >/dev/null 2>&1
check "a route path that could leave the host exits 2" "$?" 2
printf '{"base_url": "%s", "routes": ["/x"]}\n' "$BASE" > "$WORK/badroute2.json"
probe --authorized "$WORK/badroute2.json" >/dev/null 2>&1
check "a route that is not an object exits 2" "$?" 2
printf '{"base_url": "%s", "exposure": true}\n' "$BASE" > "$WORK/badexp4.json"
probe --authorized "$WORK/badexp4.json" >/dev/null 2>&1
check "a boolean exposure block exits 2 without a traceback" "$?" 2
printf '{"base_url": "%s", "exposure": {"scripts": ["/does-not-exist.js"]}}\n' "$BASE" > "$WORK/stale.json"
OUT="$(probe --authorized "$WORK/stale.json")"
check "a listed script that answers 404 is SKIPPED, never CLOSED" \
  "$(verdict "$OUT" 'sourcemap:/does-not-exist.js')" SKIPPED
printf '{"base_url": "%s", "exposure": {"scripts": []}}\n' "$BASE" > "$WORK/noscript.json"
OUT="$(probe --authorized "$WORK/noscript.json")"
check "an empty scripts list still gives a SKIPPED sourcemap row" \
  "$(verdict "$OUT" 'sourcemap')" SKIPPED
cat > "$WORK/lower.json" <<EOF
{"base_url": "$BASE", "cors": true, "cors_path": "/lower"}
EOF
OUT="$(probe --authorized "$WORK/lower.json")"
check "lowercase CORS header names are still read" \
  "$(verdict "$OUT" 'cors-reflect')" OPEN
```

- [ ] **Step 2: Run the suite, the new checks must fail**

Run: `make test suite=lib/tests/guardrails-probe.test.sh 2>&1 | grep -c '  FAIL '`
Expected: at least 14 (the sourcemap, error-body and fields rows are absent; lowercase CORS reads CLOSED; the six exit-2 checks get 1 or 0).

- [ ] **Step 3: Patch `probe.py`**

Imports: add `import re` and change the parse import to `from urllib.parse import quote, urljoin, urlsplit`.

Replace `_response_from` and `fetch` (headers stay the `HTTPMessage`, whose `.get` is case-insensitive; the body of an HTTP error is read instead of dropped):

```python
def _error_body(exc):
    try:
        return exc.read(BODY_CAP)
    except (OSError, ValueError, AttributeError):
        return b""


def _response_from(resp):
    return Response(resp.status, resp.headers, resp.read(BODY_CAP))


def fetch(session, method, url, headers=None, body=None):
    if session.budget <= 0:
        return Response(None, {}, b"", "request budget exhausted")
    session.budget -= 1
    req = urllib.request.Request(
        url, data=body, method=method, headers=headers or {})
    try:
        with session.opener.open(req, timeout=session.timeout) as resp:
            return _response_from(resp)
    except urllib.error.HTTPError as exc:
        return Response(exc.code, exc.headers, _error_body(exc))
    except (urllib.error.URLError, OSError, ValueError) as exc:
        return Response(None, {}, b"", str(exc))
```

`_cors_open` is unchanged. Change the `Response.headers` annotation comment to `headers: object  # http.client.HTTPMessage: .get() ignores case`.

Add the constants after `BODY_CAP`:

```python
SCRIPT_CAP = 10
SCRIPT_SRC = re.compile(r"<script[^>]+src=[\"']?([^\"'\s>]+)", re.I)
MAP_COMMENT = re.compile(r"//[#@]\s*sourceMappingURL=(\S+)")
TRACE_MARKERS = re.compile(
    rb"Traceback \(most recent call last\)|\bat [\w.$<> ]+ \([^)\n]*:\d+:\d+\)"
    rb"|File \"[^\"\n]+\", line \d+|SQLSTATE\[|syntax error at or near"
    rb"|node_modules/|/var/www/|Stack trace:|#\d+ /[\w/.-]+\.php\(\d+\)")
SENSITIVE_KEY = re.compile(
    r"(?:^|_)(?:password|passwd|pwd|salt|secret|api_?key|service_?role"
    r"|private_?key|(?:access|refresh|id|auth|api|session)_token|jwt|ssn"
    r"|iban|cvv|card_?number)(?:$|_)")
IDENT = re.compile(r"[A-Za-z_][\w-]{0,31}")  # used with fullmatch
```

Add the probes before `PROBES = (…)` and place `probe_exposure` BEFORE `probe_rate_limit` in the tuple (the burst is the largest budget consumer; exposure must not starve behind it):

```python
def _same_host(context, url):
    """Absolute url when it stays on context's host, else None."""
    full = urljoin(context, url)
    return full if urlsplit(full).netloc == urlsplit(context).netloc else None


def _page_scripts(session, base):
    """(urls, note): same-host scripts of the base page, or why none."""
    page = fetch(session, "GET", base + "/")
    if page.error:
        return [], f"base page unreachable: {page.error}"
    text = page.body.decode("utf-8", "ignore")
    urls = [u for u in (_same_host(base + "/", s)
                        for s in SCRIPT_SRC.findall(text)) if u]
    urls = list(dict.fromkeys(urls))[:SCRIPT_CAP]
    return urls, "" if urls else "no same-host script on the base page"


def _map_candidates(script_url, resp):
    urls = [script_url + ".map"]
    header = resp.headers.get("sourcemap") or resp.headers.get("x-sourcemap")
    if header:
        urls.append(header)
    tail = resp.body[-600:].decode("utf-8", "ignore")
    comment = MAP_COMMENT.search(tail)
    if comment:
        urls.append(comment.group(1))
    return list(dict.fromkeys(urls))


def _map_verdict(session, script_url, candidates):
    """(verdict, target, note) over the candidate map urls, fail closed."""
    for url in candidates:
        if url.startswith("data:"):
            return "OPEN", script_url, "inline source map in the script"
        target = _same_host(script_url, url)
        if not target:
            return "SKIPPED", url, "map url on another host, not fetched"
        resp = fetch(session, "GET", target)
        if resp.error or resp.status is None:
            return "ERROR", target, resp.error or "no response"
        if resp.status == 200 and b'"sources"' in resp.body:
            return "OPEN", target, "source map served with its sources"
    return "CLOSED", script_url, "no source map served for this script"


def _sourcemap_probe(session, script_url):
    pid = f"sourcemap:{urlsplit(script_url).path}"
    resp = fetch(session, "GET", script_url)
    if resp.error:
        return Probe("exposure", pid, "ERROR", script_url, resp.error)
    if resp.status != 200:
        return Probe("exposure", pid, "SKIPPED", script_url,
                     f"HTTP {resp.status}: script not served, map not read")
    if len(resp.body) >= BODY_CAP:
        return Probe("exposure", pid, "SKIPPED", script_url,
                     "script body truncated: its map comment was not read")
    verdict, target, note = _map_verdict(
        session, script_url, _map_candidates(script_url, resp))
    return Probe("exposure", pid, verdict, target, note)


def _sourcemaps(session, base, cfg):
    listed = cfg.get("scripts")
    if listed is None:
        urls, note = _page_scripts(session, base)
    else:
        urls = [base + s for s in listed][:SCRIPT_CAP]
        note = "" if urls else "no script listed in exposure.scripts"
    if note:
        return [Probe("exposure", "sourcemap", "SKIPPED", base, note)]
    return [_sourcemap_probe(session, u) for u in urls]


def _error_probe(session, base, path):
    target = base + path
    resp = fetch(session, "GET", target)
    return _verdict(
        ("exposure", f"error-body:{path}", target), resp,
        bool(TRACE_MARKERS.search(resp.body)),
        ("error body carries a stack trace or an internal path",
         "error body carries no trace marker"))


def _error_paths(cfg):
    random_path = "/guardrails-probe-" + os.urandom(6).hex()
    return [random_path] + list(cfg.get("error_routes") or [])


def _keys(data, depth=0):
    if depth > 4:
        return []
    if isinstance(data, dict):
        found = [k for k in data if isinstance(k, str)]
        for value in data.values():
            found += _keys(value, depth + 1)
        return found
    if isinstance(data, list):
        found = []
        for value in data[:5]:
            found += _keys(value, depth + 1)
        return found
    return []


def _snake(key):
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", key).replace("-", "_").lower()


def _sensitive_keys(data):
    return sorted({k for k in _keys(data) if SENSITIVE_KEY.search(_snake(k))})


def _key_note(keys):
    """Identifier-shaped key names only; anything else is counted."""
    shown = [k for k in keys if IDENT.fullmatch(k)]
    hidden = len(keys) - len(shown)
    return ", ".join(shown) + (f" (+{hidden} unprintable)" if hidden else "")


def _json_body(resp):
    try:
        return json.loads(resp.body), True
    except ValueError:
        return None, False


def _fields_verdict(resp):
    if resp.error:
        return "ERROR", resp.error
    data, is_json = _json_body(resp)
    if resp.status != 200 or not is_json:
        return "SKIPPED", f"HTTP {resp.status}: no JSON body to read"
    keys = _sensitive_keys(data)
    if keys:
        return "OPEN", "response carries sensitive keys: " + _key_note(keys)
    return "CLOSED", "no sensitive key in the response"


def _bearer():
    token = os.environ.get("GUARDRAILS_JWT2")
    return {"Authorization": f"Bearer {token}"} if token else None


def _fields_probe(session, base, route):
    target = base + route["path"]
    verdict, note = _fields_verdict(fetch(session, "GET", target, _bearer()))
    return Probe("exposure", f"fields:{route['path']}", verdict, target, note)


def probe_exposure(session, plan):
    cfg = plan.get("exposure")
    if cfg is None:
        return []
    base = plan["base_url"].rstrip("/")
    out = _sourcemaps(session, base, cfg)
    out += [_error_probe(session, base, p) for p in _error_paths(cfg)]
    out += [_fields_probe(session, base, r) for r in plan.get("routes", [])]
    return out


PROBES = (probe_supabase, probe_cross_user, probe_routes,
          probe_cors, probe_exposure, probe_rate_limit)
```

Extend plan validation (replace `_plan_error`):

```python
def _obj(plan, key):
    value = plan.get(key)
    return value if isinstance(value, dict) else {}


def _plan_paths(plan):
    """Every path the probe would append to base_url (None when malformed)."""
    routes = plan.get("routes") or []
    cfg, supa, rate = _obj(plan, "exposure"), _obj(plan, "supabase"), \
        _obj(plan, "rate_limit")
    return ([r.get("path") if isinstance(r, dict) else None for r in routes]
            + list(supa.get("cross_user_paths") or [])
            + [plan.get("cors_path", "/"), rate.get("path", "/")]
            + list(cfg.get("scripts") or [])
            + list(cfg.get("error_routes") or []))


def _exposure_error(cfg):
    if cfg is None:
        return ""
    if not isinstance(cfg, dict):
        return "exposure must be an object"
    for key in ("scripts", "error_routes"):
        if cfg.get(key) is not None and not isinstance(cfg[key], list):
            return f"exposure.{key} must be a list"
    return ""


def _plan_error(plan):
    method = plan.get("rate_limit", {}).get("method", "GET").upper()
    if method not in READ_METHODS and method != "POST":
        return f"rate_limit method {method} is not a probe method"
    error = _exposure_error(plan.get("exposure"))
    if error:
        return error
    bad = [p for p in _plan_paths(plan)
           if not isinstance(p, str) or not p.startswith("/")]
    return f"plan path {bad[0]!r} must start with /" if bad else ""
```

Module docstring: after the `GUARDRAILS_JWT2` line add `                        (also sent as bearer by the fields probe when set)`; in the first paragraph add `With an exposure block in the plan it also reads what the page's scripts, error bodies and JSON responses give away; a target it could not observe is ERROR or SKIPPED, never CLOSED.`

- [ ] **Step 4: Run the suite**

Run: `make test suite=lib/tests/guardrails-probe.test.sh`
Expected: `failed: 0`, including the untouched `json reports the open count` = 4 (`plan.json` has no `exposure` block and its paths all start with `/`) and `the burst is capped` = 25. The `next_page_token` and `hashtags` keys of `/api/me` must not appear in the key list (segment matching).

- [ ] **Step 5: Commit**

```bash
git add skills/guardrails/scripts/probe.py lib/tests/guardrails-probe.test.sh
git commit -m "feat(guardrails): exposure probe (source maps served or inline, error bodies, sensitive keys) that fails closed; every plan path validated; fetch keeps error bodies"
```

---

### Task 6: The `/a11y` skill: SKILL.md, references, prompts, lazy rule, routing row, profiles, locks

**Files:**
- Create: `skills/a11y/SKILL.md`, `skills/a11y/references/checks.md`, `skills/a11y/test-prompts.json`, `rules/a11y.md`
- Modify: `rules/web-building.md` (two fragments point at `rules/a11y.md`), `mods/model-router/routing.json` (one row), `lib/profiles/{audit,dev,web,web-full,full,max}.profile`, `lib/tests/model-routing.test.sh`, `lib/tests/loops-light.test.sh`, `lib/verify-secure-loop.md:1`, `lib/contract-interview.md:117`, `agents/bugfixer.md:3`
- Test: `make test suite='lib/tests/effort-routing.test.sh lib/tests/profile-census.test.sh lib/tests/model-routing.test.sh lib/tests/loops-light.test.sh lib/tests/skill-routing-census.test.sh'`

**Interfaces:**
- Consumes: `skills/a11y/scripts/scan.py` (Task 4), `lib/contract-interview.md` (flow `a11y`), `lib/verify-secure-loop.md`, the `bugfixer` agent.
- Produces: the public `/a11y` command, report `.claude/audits/A11Y.md`, branch `bugfix/a11y-<date>`, baseline `.claude/audits/.a11y-baseline.json`.

- [ ] **Step 1: Write `skills/a11y/SKILL.md`**

The description is one single-quoted line (896 characters). The seven locked sentences (`lib/contract-interview.md`, `lib/verify-secure-loop.md`, `subagent_type="bugfixer"`, `EXPECT: A11Y-CLEAR`, `Positive control`, `Nothing is applied without the user's explicit acceptance`, `A11Y-NO-NEW`) and `lib/model-gate.md` must each sit on one line, as below.

````markdown
---
name: a11y
effort: high
description: 'Use when a web project needs its accessibility baseline checked and fixed: everything reachable by keyboard with a visible focus, an alt on every image, a label on every field. Full WCAG conformance (axe, pa11y, W3C) → /web-validate; security guardrails → /guardrails. Deterministic scanner (A11Y-* rules: img alt, field label, click without keyboard, focus outline removed, positive tabindex), judgment, a Tab-only walk of the main flow on --live (through /browse, else marked not done), report .claude/audits/A11Y.md, then fixes proposed with the alt and label wording as visible choices, applied only on acceptance (bugfixer executor, fresh verifier and security gates, the scanner as oracle) and re-scanned to prove each one. Triggers: "a11y", "accessibilité", "accessibility basics", "clavier", "focus visible", "alt manquant", "label sur les champs", "tab order", "corrige l''accessibilité".'
argument-hint: '[project path] [--exclude paths] [--live <url you own>] [--report-only]'
---

# /a11y

Checks a project's accessibility baseline (`rules/a11y.md`), then fixes what
the user accepts and proves each fix. A scanner reads the tree as data and
finds what text can prove: a missing alt, an unlabeled field, a click with no
keyboard path, a focus outline removed, a positive tabindex. This skill judges
the hits, walks the main flow with the keyboard when a browser is available,
proposes fixes, applies the accepted ones and scans again until every accepted
fix is proven.

The scanner proves absence of a baseline, never presence of accessibility. A
clean scan means "no static finding", and the report says exactly that. Full
WCAG conformance (contrast, structure, ARIA semantics, axe or pa11y runs) is
`/web-validate`'s job.

## MODEL GATE (blocking, before any other step)

Run `$HOME/.claude/lib/model-gate.md`. Judging hits and writing alt and label
text requires Fable or Opus. Verdict `small` → STOP: the gate prints the
remedy. ROUTING: follow `$HOME/.claude/lib/effort-shift.md` (phases via
`mcp__model-router__route`); each step below names its phase.

## STEP 1: Scope

Work in the project the user names, else the current directory. Say in one
line what you will scan. `--report-only` stops after STEP 5: audit, no fix.

## STEP 2: Run the scanner

```
python3 -B "$HOME/.claude/skills/a11y/scripts/scan.py" <path>
```

Add `--exclude a/b,c` to skip copies or vendored code, `--json` for machine
output. Exit 0 means no FAIL, 1 means at least one, 2 is a usage error. It
never executes project code. Severities: **FAIL**, the baseline is provably
missing; **WARN**, a pattern that is often wrong, judgment needed.

## STEP 3: Judge every FAIL and WARN

Read the file around each line. Label it CONFIRMED, FALSE POSITIVE (say why)
or ACCEPTED RISK (the user decides, never you). A decorative image with
`alt=""`, a field labeled through `aria-labelledby`, a click handler on a
`role="presentation"` overlay and an outline swapped for a visible border or
ring are the usual false positives; `references/checks.md` lists the blind
spots. Check them before calling a hit false.

## STEP 4: Keyboard walk (on `--live`, read-only)

With a dev server the user names, walk the main flow with Tab only through
`/browse`: every control reached in a sensible order, the focus visible at
each stop, Enter and Space working on what looks clickable, Escape closing
what opened. Record each stop that fails with the page and the element.
Without a browser tool, or without `--live`, the report marks the walk
"not done": a static scan cannot see a keyboard trap, a focus order or a
modal that loses focus.

## STEP 5: Report

Write `.claude/audits/A11Y.md`: one table with status PASS, FAIL, WARN or
N/A per rule, the evidence, the fix in one line, and the keyboard walk's
result (done, with its stops, or not done). PASS means "no static finding".
Keep it short; no filler sections. `--report-only`, or nothing CONFIRMED:
reply with counts, the FAILs with file:line and the walk's stops, then stop.

## STEP 6: Propose fixes

`mcp__model-router__route(phase="plan")`: wording is the deepest thinking in
this run, it goes to the plan row.

One proposal per CONFIRMED finding, grouped by rule and file; merge pairs
that one change closes (one `:focus-visible` rule closes every outline
removal in a stylesheet). FALSE POSITIVE and ACCEPTED RISK get no proposal.
Each proposal:

- **number, rule, file(s)**, and the problem in one line;
- **the fix**, concrete: file:line and the change. A missing alt gets a
  description of what the image shows, or `alt=""` when it is decorative; an
  unlabeled field gets a `label for`, a wrapping label or `aria-label`; a
  clickable `div` becomes a `button`, or gains `role`, `tabindex` and a key
  handler; a removed outline gets a `:focus-visible` style;
- **choices the user sees**: the alt text and the label wording, each with
  your proposed value, named so the user can change it. These are content,
  never invented silently: they ship only with the user's acceptance;
- **risk**: what it can break (`button` reset styles, a changed tab order).
  `DECISION` when no wording is defensible (an image you cannot describe);
- **proof**: the scanner pairs that must disappear (`RULE:path`), and the
  walk stop that must pass when `--live` ran.

Save the proposals to `.claude/tasks/plans/<YYYY-MM-DD>-a11y-<HHMM>.md` and
append them to the report. In the reply, show them as a numbered list, one or
two lines each, DECISION marked.

## STEP 7: Approval (gate, ends the turn)

Nothing is applied without the user's explicit acceptance. Ask once, then
stop the turn:

```
Which fixes do I apply? "all" (every proposal except DECISION ones),
numbers ("1,3,5-7"), "none", or an amendment ("2 with the alt 'Team photo'").
A DECISION proposal needs its number plus your wording.
```

On resume, `mcp__model-router__route(phase="reflect")`. "none" → stop,
proposals stay in the report. An amendment rewrites that proposal in the plan
file before anything else. Accepted set empty → stop.

## STEP 8: Apply

1. **Branch.** Not a git repository → stop: fixes need a diff to review.
   On `main`/`develop`, `bash ~/.claude/lib/gitflow.sh start bugfix
   a11y-<YYYY-MM-DD>`; on a working branch, stay. Never `finish`.
2. **Baseline**, before any edit:
   `python3 -B <scan.py> <root> --json > .claude/audits/.a11y-baseline.json`.
   A derived file: never staged, never committed.
3. **Contract** per `$HOME/.claude/lib/contract-interview.md` (STEP 4
   template, `flow: a11y`). REQUEST = the user's acceptance verbatim plus the
   accepted proposals. One criterion per accepted proposal, its oracle the
   scanner itself:
   ```
   1. <proposal 1 in one line>
      CHECK: python3 -B "$HOME/.claude/skills/a11y/scripts/scan.py" '<abs root>' --assert-absent 'RULE:path,RULE:path'
      EXPECT: A11Y-CLEAR
      EVIDENCE: pending
   ```
   Add one criterion for the project suite when one exists
   (`CHECK: <test command> && echo TESTS-GREEN`, `EXPECT: TESTS-GREEN`). The
   keyboard walk is a criterion without CHECK: STEP 9 settles it. FILE SCOPE
   = the files the accepted proposals name. Paths go in single quotes; a path
   holding a single quote is named to the user, never written into a CHECK.
4. **Positive control.** Run each oracle once on the unfixed tree: it must
   fail. An oracle that passes before the fix proves nothing; drop it, find
   why, and say so.
5. **Dispatch the executor**, one fresh `bugfixer` for the accepted set
   (batches of 8 proposals at most, one after the other on the same branch):
   ```
   mcp__model-router__route(phase="orchestrate")   # send with the Agent call
   Agent(subagent_type="bugfixer")
   prompt: "CONTRACT: <path>
   DIAGNOSIS: <each accepted finding: rule, file:line, evidence>
   FIX PLAN: <the accepted proposals verbatim, with the user's wording; the
   regression check of each is its contract oracle, plus the project test
   the proposal names>
   BRANCH: <current branch>
   Apply to the letter. No commit, no branch ops, no security dispatch.
   Finish with the BUGFIX-EXEC REPORT."
   ```
   `NEED-DECISION` routes per MID-RUN CLARIFICATION of the contract include:
   a wording, visible or scope question goes to the user verbatim.
   `BLOCKED` → surface it, stop.
6. **Gates** per `$HOME/.claude/lib/verify-secure-loop.md`, `CONTRACT` the
   path above, `DIFF` the executor's working-tree diff, `TEST` the suite.
   GATE 0 runs every scanner oracle (the per-fix proof), GATE 1 a fresh
   verifier, GATE 2 a fresh security-auditor. Loop caps and escalation are
   the include's; loop decisions stay in this main loop.

## STEP 9: Re-pass (prove it all)

`mcp__model-router__route(phase="reflect")`. The gates proved each accepted
fix on its own; this pass proves the whole tree.

1. Full scan against the baseline:
   ```
   python3 -B <scan.py> <root> --baseline .claude/audits/.a11y-baseline.json
   ```
   Every accepted pair must show `FIXED`, and the run must end on
   `A11Y-NO-NEW` (exit 0). A `NEW` hit is a regression the fix made.
2. Live: when STEP 4 ran, walk the same flow again once the user has reloaded
   the dev server and says go. Each stop a proposal named must now pass.
3. Add an "after" column to `.claude/audits/A11Y.md`: proposal, before,
   after, evidence.

Anything not fixed, or a NEW hit → one more round from STEP 6, limited to
those items. Two rounds at most: after the second, stop with the residuals
open and say so plainly. Never report a fix the re-pass did not prove.

## STEP 10: Commit and hand over

1. **Commit gate.** Show files, `git diff --stat` and the message, wait for
   the user's go:
   ```
   A11Y: READY TO COMMIT
   FILES   : <list>
   MESSAGE : fix(a11y): <rules fixed, one line>
   ```
   Then `git add <files touched>` (never `-A`, never the baseline file) and
   commit, project convention else 50 words at most.
2. `mcp__model-router__route(phase="apply")` for the tail. Reply with: fixed
   and proven (proposal, rule, file), still open and why, the walk's result,
   the branch name. Merge waits for the user's explicit signal.
3. Offer to capitalize a reusable lesson (a false-positive class, a fix
   pattern), entry pre-filled, written only on approval.
````

Measure the description: `awk 'NR==4' skills/a11y/SKILL.md | sed 's/^description: //' | wc -c` must print 1024 or less (expected about 910 bytes).

- [ ] **Step 2: Write `skills/a11y/references/checks.md`**

```markdown
# Accessibility checks

Rule ids the scanner emits, what each proves, and the fix. Severity is the
default; a judged hit can be a false positive.

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| A11Y-IMG-ALT | FAIL | `img` or `Image` without `alt` | describe it, or `alt=""` if decorative |
| A11Y-FIELD-LABEL | FAIL | native input, select, textarea with no label | `label for`, wrapping label or `aria-label` |
| A11Y-CLICK-NO-KEYBOARD | FAIL | click handler on a div or span lacking role, tabindex or key handler | use a `button` |
| A11Y-FOCUS-OUTLINE | FAIL / WARN | focus outline removed; WARN when a `:focus-visible` style exists elsewhere | style `:focus-visible` instead |
| A11Y-TABINDEX-POSITIVE | WARN | `tabindex` above 0 | use 0 or -1 and fix the DOM order |

## Blind spots

The scanner is regex over markup and styles. It cannot see:

- keyboard traps, focus order, a modal that keeps or loses focus, color
  contrast: the `--live` walk covers the first three, `/web-validate` the
  fourth
- a label wired through `aria-labelledby` to an element in another file
- components whose markup is built at runtime, minified bundles, anything
  over 1 MB
- `.astro` files for the click rule (never flagged)

By design the scanner ignores: fields that are never rendered (`hidden`,
`display: none`), click handlers that only stop propagation or sit on
`role="presentation"`, focus styles that swap the outline for a border or
shadow, and `img` tags inside comments.

## Fix loop: oracles and re-pass

Every accepted fix is proven by the scanner itself, never by the executor's
word. Two check modes replace the report and its exit code:

| Mode | Passes when | Marker | Used by |
|---|---|---|---|
| `--assert-absent RULE:path,...` | none of these FAIL/WARN pairs remains, the domain was scanned, the tree is not empty | `A11Y-CLEAR <n>` | a contract `CHECK:` run by `lib/gates.sh` (GATE 0) |
| `--baseline before.json` | no FAIL/WARN hit appeared since the earlier `--json` run | `A11Y-NO-NEW` | STEP 9 re-pass |

Pairs match on rule and file, not line: a fix moves lines. An empty tree
fails the assertion, because absence there proves nothing. Run every oracle
once before the fix: it must fail. The baseline lists `FIXED` and `NEW`
pairs with their hit counts; a `NEW` hit after a fix is a regression.
```

- [ ] **Step 3: Write `skills/a11y/test-prompts.json`**

```json
[
  {"id": 1, "prompt": "vérifie l'accessibilité de base de ~/Documents/faunosteo : clavier, alt, labels", "expected": "Runs the a11y scanner on the path, reads each A11Y FAIL and WARN in context, marks the keyboard walk not done (no --live), writes .claude/audits/A11Y.md, proposes fixes with alt and label wording as visible choices, stops for approval"},
  {"id": 2, "prompt": "il manque des alt sur les images du site, corrige", "expected": "Scans, confirms each A11Y-IMG-ALT hit, proposes one alt text per image (or alt=\"\" for decorative ones) as a named choice, applies only after acceptance on a bugfix branch with --assert-absent oracles, re-scans against the baseline"},
  {"id": 3, "prompt": "Walk my app at http://localhost:3000 with the keyboard only and tell me where focus gets lost", "expected": "Static scan first, then the Tab walk through /browse on the named localhost target, records each stop with no visible focus or unreachable control, reports them next to the static findings, fixes nothing without approval"},
  {"id": 4, "prompt": "est-ce que mon site passe les critères WCAG AA ?", "expected": "Routes to /web-validate for WCAG conformance; runs /a11y only if the user asks for the keyboard/alt/label baseline"},
  {"id": 5, "prompt": "a11y --report-only sur ce projet", "expected": "Scan and judgment only, report written, counts and file:line in the reply, no proposal, no branch, no edit"}
]
```

- [ ] **Step 4: Write `rules/a11y.md` and point `rules/web-building.md` at it**

`rules/a11y.md`:

```markdown
---
paths: ["**/*.tsx", "**/*.jsx", "**/*.vue", "**/*.svelte", "**/*.astro", "**/*.html", "**/*.css", "**/*.scss"]
---

# Accessibility baseline (audit and fix: `/a11y`)

- Everything reachable and usable by keyboard, focus always visible.
  `:focus-visible` styled, never `outline: none` without a replacement.
- Every image has an `alt` (empty when decorative). Every field has a label;
  a placeholder is not a label.
```

In `rules/web-building.md` (same globs, so both load together on UI files): the fragment `visible `:focus-visible` ring;` in the "Touch targets" bullet becomes `keyboard and focus per `rules/a11y.md`;` and the fragment `alt text on images` in the "Before declaring a public site done" paragraph becomes `accessibility baseline (`rules/a11y.md`)`. Nothing else in that file changes.

- [ ] **Step 5: Add the routing row, committing that one file alone**

```bash
stashed=0
if [ -n "$(git status --short mods/model-router/routing.json)" ]; then
  git stash push -m "pre-existing routing dialog decisions" -- mods/model-router/routing.json && stashed=1
fi
```

Then in `mods/model-router/routing.json`, in the `skills` block, add the line `    "a11y": "reflect",` right after `    "guardrails": "reflect",`. Validate: `python3 -I -c 'import json; json.load(open("mods/model-router/routing.json"))'`.

```bash
git add mods/model-router/routing.json
git commit -m "chore(model-router): a11y skill row (reflect)"
if [ "$stashed" = 1 ]; then git stash pop; fi
git stash list
```

After the pop (only when the push ran), `git stash list` must be empty and `git status --short` must show routing.json `M` again (the pre-existing hunks restored, at line 106 and later; the a11y row sits at line 78). A pop that reports a conflict is a STOP: do not touch the index, do not continue the task; report the conflict to the user with `git status` and wait. `settings.json` is never stashed and never staged.

- [ ] **Step 6: Profiles, locks and flow enums**

1. In `lib/profiles/audit.profile`, `dev.profile`, `web-full.profile`, `full.profile`, `max.profile`: add the line `a11y                              personal` right after the `guardrails …personal` line. In `lib/profiles/web.profile`: add it right after the `web-validate …personal` line. The name column is 34 characters wide: `a11y` plus 30 spaces.
2. `lib/tests/model-routing.test.sh`: add `a11y` at the end of the `for s in ship-feature … guardrails; do` list and change the comment to `# 1) gate wired in the 17 reflection skills (orchestrators, /analyze, /guardrails, /a11y)`.
3. `lib/tests/loops-light.test.sh`: find how `GSK` is defined near the top (`GSK="$R/skills/guardrails/SKILL.md"` or similar) and define `ASK` the same way for `skills/a11y/SKILL.md`. After the guardrails block add:
   ```bash
   echo "── skills/a11y/SKILL.md (fix loop reuses the bugfix circuit) ──"
   tf "a11y contract include" "$ASK" "lib/contract-interview.md"
   tf "a11y uses shared include" "$ASK" "lib/verify-secure-loop.md"
   tf "a11y dispatches bugfixer" "$ASK" 'subagent_type="bugfixer"'
   tf "a11y scanner is the oracle" "$ASK" "EXPECT: A11Y-CLEAR"
   tf "a11y positive control" "$ASK" "Positive control"
   tf "a11y approval gate" "$ASK" "Nothing is applied without the user's explicit acceptance"
   tf "a11y re-pass baseline" "$ASK" "A11Y-NO-NEW"
   ```
4. `lib/verify-secure-loop.md` line 1: `(feat, bugfix, guardrails)` → `(feat, bugfix, guardrails, a11y)`.
5. `lib/contract-interview.md` line 117: `…|onboard|guardrails>` → `…|onboard|guardrails|a11y>`.
6. `agents/bugfixer.md` line 3: `dispatched by /bugfix (or /guardrails for accepted fixes)` → `dispatched by /bugfix (or /guardrails and /a11y for accepted fixes)`.

- [ ] **Step 7: Commit, then run the censuses on the committed tree**

The effort-routing census reads `git ls-files`, so the a11y row is only checked once `skills/a11y/SKILL.md` is committed: commit first, then test.

```bash
git add skills/a11y/SKILL.md skills/a11y/references/checks.md skills/a11y/test-prompts.json rules/a11y.md rules/web-building.md lib/profiles/audit.profile lib/profiles/dev.profile lib/profiles/web.profile lib/profiles/web-full.profile lib/profiles/full.profile lib/profiles/max.profile lib/tests/model-routing.test.sh lib/tests/loops-light.test.sh lib/verify-secure-loop.md lib/contract-interview.md agents/bugfixer.md
git commit -m "feat(a11y): skill (scan, keyboard walk, report, fix loop on the bugfix circuit), lazy rules/a11y.md, profiles, locks"
```

Run: `make test suite='lib/tests/effort-routing.test.sh lib/tests/profile-census.test.sh lib/tests/model-routing.test.sh lib/tests/loops-light.test.sh lib/tests/skill-routing-census.test.sh'`
Expected: `all suites green`. A red census is fixed in place and committed as `fix(a11y): <census> census` before moving on. A skill-routing WARN naming `a11y~web-validate` above 0.50 (the challenge measured 0.18 to 0.23) means the description drifted: trim shared words from the a11y description, never from web-validate's (Task 8 owns that file).

---

### Task 7: `/guardrails` skill text, reference, prompts and the secure-by-default rule

**Files:**
- Modify: `skills/guardrails/SKILL.md`, `skills/guardrails/references/checks.md`, `skills/guardrails/test-prompts.json`, `rules/secure-by-default.md`
- Test: `make test suite='lib/tests/loops-light.test.sh lib/tests/model-routing.test.sh lib/tests/skill-routing-census.test.sh lib/tests/doctrine-citers.test.sh'`

- [ ] **Step 1: `skills/guardrails/SKILL.md` frontmatter**

Replace the `description:` line with this single-quoted line (994 characters, 1002 bytes; then measure: `awk 'NR==4' skills/guardrails/SKILL.md | sed 's/^description: //' | wc -c` must print 1024 or less):

```
description: 'Use when auditing a project against the baseline guardrails and fixing what fails. Headers and TLS → /harden; secrets, CVE, dependencies → /cso; keyboard, alt, labels → /a11y. Domains: hosting (rate limit, CDN, spend cap), Supabase (RLS, owner policies, no service_role client-side), SMS and email (consent, unsubscribe, STOP), cloud functions (no self-trigger, instance cap, budget stop), injection (SQL from input, raw escapes, NoSQL, shell into DB tools), exposure (console data, source maps, hydrated state, error bodies, debug mode, wide responses), plus API hygiene (auth, CORS, secrets, passwords). Scanner, judgment, .claude/audits/GUARDRAILS.md, fixes applied only on acceptance (bugfixer, verifier and security gates), re-scanned to prove them; optional read-only probe of a target you own. Triggers: "guardrails", "garde-fous", "RLS activée ?", "faille sql", "fuite navigateur", "plafond de dépense", "mots de passe en clair ?", "corrige les garde-fous", "sonde le projet en direct".'
```

`argument-hint`: `'[project path] [--domain api,hosting,supabase,messaging,functions,injection,exposure] [--exclude paths] [--live <url you own>] [--report-only]'`.

- [ ] **Step 2: `skills/guardrails/SKILL.md` body**

1. STEP 1: `Domains: \`api\`, \`hosting\`, \`a11y\`, \`supabase\`, \`messaging\`, \`functions\`.` → `Domains: \`api\`, \`hosting\`, \`supabase\`, \`messaging\`, \`functions\`, \`injection\`, \`exposure\`.`
2. STEP 4: replace the `- **A11y**: …` bullet (two lines) with:
   ```
   - **Injection**: for each INJ hit, trace the interpolated value to its
     source. A constant, an allowlisted identifier or a value already cast to
     a number is a FALSE POSITIVE; anything that can come from a request,
     a file or another user's row is CONFIRMED.
   - **Exposure**: read the code behind each EXP hit: is the logged object,
     the hydrated key or the returned row really user data? With `--live`
     against a production build (STEP 5), the probe answers for served
     source maps, error bodies and sensitive keys; without it, say so.
   ```
3. STEP 5, paragraph 1: after `a staging or\nproduction URL only on an explicit, specific go.` add: `The \`exposure\` block runs against a production build or a staging URL (\`next build && next start\`, \`vite preview\`, framework debug off): a dev server serves source maps and tracebacks by design, so its exposure OPEN verdicts are dev artefacts, reported as such, with no proposal and no re-pass requirement.`
4. STEP 5.1: after `and a \`rate_limit\` route if the user wants that one burst.` add: `Add an \`exposure\` block (\`{}\` for the defaults, \`error_routes\` for a route you own that answers an error to a malformed id, never a path you guess) so the probe reads source maps, error bodies and response keys; every path in the plan starts with \`/\`.`
5. STEP 5.3: after `CLOSED means it was refused or empty.` add `SKIPPED and ERROR mean the target was not observed: never read either as proof of a fix.`
6. STEP 8: `A live OPEN verdict\nwith no static finding gets a proposal whose proof is the probe alone.` → `A live OPEN verdict\nwith no static finding gets a proposal whose proof is the probe alone,\nunless STEP 5 marked it a dev artefact.`
7. STEP 8 proposal examples: `the label text for a field.` → `the parameter binding for a query.`; `(label wording, CORS origins, owner column,\n  rate-limit numbers)` → `(allowlisted filter fields, CORS origins, owner column,\n  rate-limit numbers)`.
8. STEP 9 example: `("2 with the label 'Email'")` → `("2 with the fields ['id','status']")`.

Every locked sentence from loops-light stays untouched and on one line.

- [ ] **Step 3: `skills/guardrails/references/checks.md`**

1. Delete the `## a11y` section (heading and table).
2. Add after the `## hosting` section:
   ```markdown
   ## injection

   Patterns are per language: a Postgres `$1` placeholder, a tagged template
   (`sql\`…\``, `sql<T>\`…\``), an argv array and test or fixture paths are
   silent by design.

   | Rule | Sev | Catches | Fix |
   |---|---|---|---|
   | INJ-SQL-RAW-UNSAFE | FAIL | `$queryRawUnsafe`, `$executeRawUnsafe`, `knex.raw`, `sequelize.query`, `Sequelize.literal`, Django `.objects.raw()` / `.extra()`, SQLAlchemy `text()` fed a variable; ActiveRecord `where("… #{}")` | bind the values, or the tagged `$queryRaw` |
   | INJ-SQL-CONCAT | FAIL | a SQL statement (select … from … where, insert into, update … set, delete … where, create/drop/alter) built with `${}`, `+`, an f-string, `%`, `.format`, PHP `$var`, Ruby `#{}`, `format!`, `Sprintf` | placeholders and a parameter list |
   | INJ-SQL-DYNAMIC-EXEC | WARN | plpgsql `EXECUTE '…' \|\| x` | `format('… %I %L', …)` and `USING` |
   | INJ-POSTGREST-FILTER | WARN | supabase-js `.or()`, `.filter()`, `.not()`, `.match()`, `.textSearch()` with an interpolated string, in a file that uses supabase | `.eq()` and friends, validated values |
   | INJ-NOSQL-OPERATOR | WARN | Mongo `$where` with a string; a filter taken from `req.body`, `req.query` or `req.params` | allowlist the fields, cast to string, `sanitizeFilter` |
   | INJ-SHELL-DB-TOOL | FAIL | a shell call naming psql, mysql, mysqldump, pg_dump, mongosh, redis-cli, sqlite3… with an interpolated argument | an argv array, no shell, validated input |

   ## exposure

   | Rule | Sev | Catches | Fix |
   |---|---|---|---|
   | EXP-CONSOLE-DATA | WARN | `console.log/info/debug/dir/table` in client-reachable code with a data argument (user, session, response, token, body…); string literals are ignored | strip console calls in the production build, log server-side |
   | EXP-SOURCEMAP-PUBLIC | FAIL / WARN | `productionBrowserSourceMaps: true`, vite `sourcemap: true` or `'inline'`, `GENERATE_SOURCEMAP=true` in a committed non-dev env file, webpack `devtool` readable maps (FAIL in `webpack.prod*`, WARN elsewhere), a real `.map` under `public/` or `static/` (any size; vendored and `.min.` maps excluded); angular `sourceMap: true` (WARN) | off, or `hidden` and upload to the error tracker |
   | EXP-HYDRATED-SENSITIVE | WARN | a token, secret, key, password or ssn-like key returned by `getServerSideProps`, `getStaticProps`, a Remix `loader`, a SvelteKit `load` or set on `window.__STATE__`; a TS type member is skipped | return only the fields the page renders |
   | EXP-MARKUP-COMMENT | WARN | `<!-- -->` shipped to the browser (html, astro, php, ejs, hbs, twig, njk, liquid) with todo, fixme, debug, password, token, internal, staging, admin… | delete it, or move it to a code comment the build strips |
   | EXP-DATA-ATTR-SENSITIVE | WARN | `data-*` attribute or hidden input named secret, api-key, password, jwt, private, credential (csrf, xsrf, authenticity, nonce excluded) | keep it server-side, send an opaque id |
   | EXP-ERROR-STACK | FAIL | in a route file: `err.stack`, the error object, `traceback.format_exc()` or `getTraceAsString()` in a response | generic message out, full error in the server log |
   | EXP-ERROR-MESSAGE | WARN | in a route file: `err.message`, `str(e)`, `$e->getMessage()` sent as is | map to a safe message; validation errors are fine, DB errors are not |
   | EXP-DEBUG-ON | FAIL | `DEBUG = True` in a settings module (not dev/local/test), `APP_DEBUG=true` / `FLASK_DEBUG=1` in a committed non-dev env file, `app.debug = True`, `consider_all_requests_local = true`, `errorhandler()` mounted without an environment guard | env-driven, false in production |
   | EXP-RESPONSE-WIDE | WARN | a route returning `select *` / `select('*')` on a users-like table, or a single-line Prisma `findUnique/findFirst/findMany` without `select` or `omit` | an explicit field list |
   ```
3. Blind spots list: replace `- keyboard traps, focus order, modal focus handling, color contrast` with
   ```
   - a SQL string assembled across several lines, or passed through a
     variable before the query call (trace it by hand)
   - whether a template literal's tag parameterizes: tagged templates are
     trusted
   - built output (`dist/`, `.next/`) and runtime state such as
     `__NEXT_DATA__`: only the live probe sees a served map or a hydrated
     token
   - a multi-line Prisma call or a value object spread into state: the
     single-line rules stay silent
   - what the console or an XHR carries once the page runs: a browser walk
   ```
4. "By design the scanner ignores" paragraph: remove `fields that are never rendered (\`hidden\`, \`display: none\`), click handlers that only stop propagation or sit on \`role="presentation"\`, focus styles that swap the outline for a border or shadow, ` and append `, tagged SQL templates, placeholders with a separate parameter list, an argv array handed to a DB tool, console calls in server code, logging calls that carry a stack, \`sourcemap: 'hidden'\`, a debug flag read from the environment, dev, local and test env files and settings modules, minified files and built directories, and a hidden input or data attribute named csrf, xsrf, authenticity or nonce` before the final period.
5. Live probe section: in the plan JSON example add, before the closing brace, `,\n  "exposure": {"error_routes": ["/api/v1/notes/not-a-number"]}`; after the `Environment, from test keys only…` sentence add `The fields probe sends \`GUARDRAILS_JWT2\` as a bearer when it is set. Every path in the plan starts with \`/\`: a path that could leave the named host is a usage error.`; add three rows to the probe table:
   ```
   | sourcemap | `sourcemap:<script>` | a source map with sources answered 200 for a page script, or the script carries an inline map | EXP-SOURCEMAP-PUBLIC |
   | error-body | `error-body:<path>` | a 404 or a named error route returned a stack trace or an internal path | EXP-ERROR-STACK, EXP-DEBUG-ON |
   | fields | `fields:<path>` | a JSON 200 carried a password, salt, token, key or secret-like key (identifier-shaped names printed, never values) | EXP-RESPONSE-WIDE, EXP-HYDRATED-SENSITIVE |
   ```
   after the verdict paragraph add `An exposure target the probe could not observe (unreachable page, no same-host script, a refused or non-JSON route, a map fetch that failed) is SKIPPED or ERROR, never CLOSED. Run the exposure block against a production build or a staging URL: a dev server serves maps and tracebacks by design, and its OPEN verdicts are dev artefacts, not findings.`; and in the safety paragraph, after `a redirect to another host is never followed, so a key never leaves the named host.` add `A script on another host is never fetched. An error route is a path you own and name; the probe never guesses one beyond its single random 404.`

- [ ] **Step 4: `skills/guardrails/test-prompts.json`**

Append two entries before the closing `]`:

```json
  {"id": 7, "prompt": "cherche les failles d'injection SQL dans ~/Documents/zenquality", "expected": "Runs the scanner's injection domain, traces each INJ hit to the source of the interpolated value, labels constants and cast values FALSE POSITIVE, proposes parameterized rewrites with the binding as a visible choice, applies only after acceptance with --assert-absent oracles"},
  {"id": 8, "prompt": "est-ce que mon site laisse voir trop de choses dans le navigateur ? console, network, inspecteur", "expected": "Runs the exposure domain, reads each EXP hit in context, offers the live probe with an exposure block against a production build the user names, reports source maps served, error bodies and sensitive keys next to the static findings, never prints a response value, marks dev-server OPENs as dev artefacts"}
```

- [ ] **Step 5: `rules/secure-by-default.md`**

Only what CLAUDE.global.md's Security section and this file's "Every API" section do not already say (parameterized queries, generic errors and "only needed fields" are already there).

1. Line 1: `# Secure by default: five domains and every API` → `# Secure by default: six domains and every API`.
2. Replace the `## 2. Accessibility` section (heading and its two bullets) with:
   ```markdown
   ## 2. Injection
   - Raw escapes (`$queryRawUnsafe`, `knex.raw`, `text()`, `.raw()`) take
     bound values only; dynamic SQL in a function goes through `format()`
     with `%I` / `%L` and `USING`.
   - A filter object never comes straight from the request: allowlist the
     fields, cast the values. No shell command carries input into a DB tool.

   ## 3. Exposure (what the browser can see)
   - No data in the browser console, no source map in production, no debug
     flag in a committed config.
   - Hydrated state, `data-*` attributes, hidden fields and shipped HTML
     comments carry no token, hash, key or secret.
   ```
3. Renumber: `## 3. Supabase` → `## 4. Supabase`, `## 4. SMS and email` → `## 5. SMS and email`, `## 5. Cloud functions` → `## 6. Cloud functions`.
4. Keyboard, alt and label doctrine now lives in `rules/a11y.md` (Task 6): nothing else to add here.

- [ ] **Step 6: Run the suites**

Run: `make test suite='lib/tests/loops-light.test.sh lib/tests/model-routing.test.sh lib/tests/skill-routing-census.test.sh lib/tests/doctrine-citers.test.sh'`
Expected: `all suites green`.

- [ ] **Step 7: Commit**

```bash
git add skills/guardrails/SKILL.md skills/guardrails/references/checks.md skills/guardrails/test-prompts.json rules/secure-by-default.md
git commit -m "docs(guardrails): injection and exposure in the skill, the rule catalogue, the probe plan and secure-by-default; a11y handed to /a11y"
```

---

### Task 8: Docs and routing citers: README, USAGE, CHANGELOG, global routing line, web-validate, seo and harden triggers, interviewer

**Files:**
- Modify: `README.md`, `USAGE.md`, `CHANGELOG.md`, `CLAUDE.global.md:276`, `skills/web-validate/SKILL.md` (description block), `skills/seo/SKILL.md:11`, `skills/harden/SKILL.md:357`, `agents/interviewer.md:27`
- Test: `make test suite='lib/tests/skill-routing-census.test.sh lib/tests/doctrine-citers.test.sh'`; `wc -l CLAUDE.global.md` = 320

- [ ] **Step 1: README.md**

1. Replace the `/guardrails` row with:
   ```
   | `/guardrails` | Audit the six baseline guardrails (hosting, Supabase RLS, SMS/email consent, cloud functions, injection, browser exposure) plus API hygiene (auth, CORS, secrets, password storage): deterministic scanner, then judgment, report in `.claude/audits/GUARDRAILS.md`. Then proposes fixes, applies the ones you accept and re-scans to prove each one. `--live <url you own>` adds a read-only probe that confirms a hole from outside (routes, CORS, rate limit, and against a production build: source maps served, error bodies, sensitive keys) |
   ```
2. Add right after it:
   ```
   | `/a11y` | Accessibility baseline: keyboard reachability with a visible focus, an alt on every image, a label on every field. Deterministic scanner, Tab walk on `--live`, report in `.claude/audits/A11Y.md`, fixes proposed with the wording as your choice, applied on acceptance and re-scanned to prove them. Full WCAG → `/web-validate` |
   ```
3. `/web-validate` row: `W3C HTML/CSS validity + WCAG 2.1 accessibility audit` → `W3C HTML/CSS validity + WCAG 2.1 conformance audit (keyboard/alt/label basics → /a11y)`.

- [ ] **Step 2: USAGE.md**

First table (`| Validité HTML/CSS + a11y | …`): change to `| Validité HTML/CSS + conformité WCAG | \`/web-validate\` |`, add after it `| Accessibilité de base (clavier, alt, labels) puis corriger | \`/a11y\` |`, and change the guardrails row to `| Auditer garde-fous (RLS, consentement, fonctions, mots de passe, injection SQL, fuites navigateur) puis corriger | \`/guardrails\` |`.

Second table: `| \`/web-validate\` | Audit W3C + WCAG a11y | …` → `| \`/web-validate\` | Audit W3C + conformité WCAG | Avant livraison projet web ; bases clavier/alt/labels → /a11y |`; add after it `| \`/a11y\` | Vérifier clavier, focus visible, alt, labels puis corriger | Scanner déterministe, parcours Tab sur \`--live\`, rapport \`.claude/audits/A11Y.md\`, propositions à valider (textes d'alt et de label = ton choix), re-passe qui prouve chaque correction |`; change the guardrails row's first cell to `Vérifier hébergement, Supabase RLS, consentement SMS/email, fonctions cloud, stockage des mots de passe, injection SQL, exposition navigateur` and append to its third cell ` ; sonde \`exposure\` sur un build de production (source maps, corps d'erreur, clés sensibles)`.

- [ ] **Step 3: CHANGELOG.md (Unreleased)**

1. In the `**Secure-by-default guardrails**` bullet: `makes five domains baseline on every project` → `makes six domains baseline on every project`; delete `accessibility (keyboard, visible focus, alt text, field labels), `; after `cloud functions (no self-trigger, instance cap, budget stop)` add `, injection (bound values in raw escapes, `format()` for dynamic SQL, allowlisted filters, no shell into a DB tool), exposure (no data in the console, no production source map, no debug flag, no secret in hydrated state, data attributes, hidden fields or shipped comments)`. After the sentence ending `verdicts OPEN / CLOSED / SKIPPED / ERROR.` add `An `exposure` block in the plan adds three read-only probes, meant for a production build or a staging URL: a served or inline source map for the page's scripts, a stack trace in a 404 or a user-named error route, sensitive keys in a JSON response (identifier-shaped names printed, never values); a target the probe could not observe is SKIPPED or ERROR, never CLOSED, and every plan path must start with `/`.`
2. Add a new bullet right after it:
   ```
   - **/a11y skill**: accessibility leaves `/guardrails` and becomes its own skill. Same A11Y-* rules (img alt, field label, click without keyboard, focus outline removed, positive tabindex) on the shared scan engine (`skills/guardrails/scripts/scanner.py`, a `Catalogue` per CLI; `skills/a11y/scripts/scan.py`, markers `A11Y-CLEAR` / `A11Y-NO-NEW`), a Tab-only walk of the main flow on `--live` through `/browse` (marked not done otherwise), report `.claude/audits/A11Y.md`, fixes proposed with the alt and label wording as the user's choice, applied through the bugfix circuit (`bugfixer`, verify-secure gates, `bugfix/a11y-<date>`), re-pass against a baseline. The keyboard, alt and label doctrine moves from `rules/secure-by-default.md` to the lazy `rules/a11y.md` (loads on UI files only; `rules/web-building.md` points at it). `/guardrails` scans `injection` (INJ-*) and `exposure` (EXP-*) instead, with per-language SQL patterns, shared `code_files` / `hits` / `dedupe_lines` / `client_reachable` helpers and a walker that lists files over 1 MB by path; `--domain a11y` is a usage error there. `/web-validate` keeps full WCAG conformance. Suite `lib/tests/a11y-scan.test.sh`; routing row `reflect`; profiles audit, dev, web, web-full, full, max.
   ```

- [ ] **Step 4: CLAUDE.global.md line 276**

`- SEO+GEO → seo (GEO only → geo); W3C + WCAG a11y → web-validate;` → `- SEO+GEO → seo (GEO only → geo); W3C + WCAG conformance → web-validate;`. Then `wc -l CLAUDE.global.md` must still print 320.

- [ ] **Step 5: `skills/web-validate/SKILL.md`, `skills/seo/SKILL.md`, `skills/harden/SKILL.md`**

web-validate description block: replace the two `Triggers:` lines and the disclaim line with
```
  Triggers: "validate", "w3c", "wcag", "conformité wcag", "axe",
  "pa11y", "conformité web", "validité html".
  Keyboard, alt and label basics and their fixes → /a11y.
  CSP/HSTS/404 → /harden. Meta/sitemap → /seo. AI engines → /geo.
```
and in the first sentence `W3C HTML/CSS validity or WCAG 2.1 accessibility audit` → `W3C HTML/CSS validity or WCAG 2.1 conformance audit`.

`skills/seo/SKILL.md` line 11: `W3C/a11y → /web-validate` → `W3C/WCAG → /web-validate; keyboard, alt, labels → /a11y` (keep the line under 80 columns; wrap inside the description block if needed).

`skills/harden/SKILL.md` line 357: `a11y / WCAG (owned by /web-validate …)` → `WCAG conformance (owned by /web-validate) and the keyboard, alt and label baseline (owned by /a11y)`, keeping the rest of the line.

- [ ] **Step 6: `agents/interviewer.md` line 27**

`note under QUALITY which of the five guardrail domains apply` → `note under QUALITY which of the six guardrail domains apply, and whether the accessibility baseline (\`rules/a11y.md\`) applies`.

- [ ] **Step 7: Run the censuses and the stale-list grep**

Run: `make test suite='lib/tests/skill-routing-census.test.sh lib/tests/doctrine-citers.test.sh'`
Expected: `all suites green`.
Run: `grep -rn 'api,hosting,a11y' skills/guardrails rules agents README.md USAGE.md CHANGELOG.md; grep -n 'five domains\|five guardrail\|five baseline' rules/secure-by-default.md agents/interviewer.md README.md; grep -rn 'a11y → /web-validate\|W3C/a11y' skills/*/SKILL.md CLAUDE.global.md`
Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add README.md USAGE.md CHANGELOG.md CLAUDE.global.md skills/web-validate/SKILL.md skills/seo/SKILL.md skills/harden/SKILL.md agents/interviewer.md
git commit -m "docs: /a11y and the injection and exposure domains in README, USAGE, CHANGELOG; routing boundaries (web-validate, seo, harden, global line, interviewer)"
```

---

### Task 9: Whole-branch verification

**Files:** none modified unless a check fails (then fix in the owning task's files and commit with a `fix:` message).

- [ ] **Step 1: Full suite and shellcheck**

Run: `make test` (expected `all suites green`, or only the two pre-existing `T16a` gitflow failures named in `.claude/tasks/TODO.md`; anything else is a regression of this branch).
Run: `shellcheck *.sh hooks/*.sh lib/*.sh` (expected: no output).

- [ ] **Step 2: Contract oracles**

Run: `bash ~/.claude/lib/gates.sh run .claude/tasks/contracts/2026-10-18-guardrails-a11y-split-inj-exp-2210.md`
Expected: every `CHECK:` criterion `MET`, evidence written back. Criteria 4, 5 and 11 were amended on disk on 2026-10-19 (after the plan challenge, before Task 1): they read `skills/a11y/scripts/a11y_checks.py`, require the file to exist and require a non-zero rule count (15 INJ+EXP rules, 5 A11Y rules), so a wrong path or an empty glob fails instead of passing vacuously. Verify with `grep -n 'a11y_checks.py' <contract>` (three hits) before running the gates.

- [ ] **Step 3: Smoke the two CLIs and the tree by hand**

```bash
python3 -B skills/guardrails/scripts/scan.py lib/tests/fixtures/guardrails-good | head -4
python3 -B skills/a11y/scripts/scan.py lib/tests/fixtures/a11y-good | head -4
git stash list
git status --short
```
Expected: `scanned: api, hosting, supabase, messaging, functions, injection, exposure`; `scanned: a11y`; an empty stash list; in the status only the two pre-existing `M` files (`mods/model-router/routing.json`, `settings.json`) and the untracked contract `?? .claude/tasks/contracts/2026-10-18-guardrails-a11y-split-inj-exp-2210.md`, which the ship-feature memory commit (STEP 7) picks up with its evidence.
