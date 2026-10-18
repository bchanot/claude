#!/usr/bin/env python3
"""Static guardrails scan: API, hosting, a11y, Supabase, messaging, functions.

Reads a project tree as data and never executes it. Exit codes:
0 no FAIL, 1 at least one FAIL, 2 usage error.

Two check modes replace the report and its exit code:
--assert-absent RULE:path,...  exit 0 and print GUARDRAILS-CLEAR only when
    none of these FAIL/WARN pairs remain (a fix contract's oracle);
--baseline before.json  compare with an earlier --json run, exit 0 and
    print GUARDRAILS-NO-NEW only when no FAIL/WARN hit appeared.
"""
import argparse
import json
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from checks import a11y, apis, functions, hosting, messaging, supabase
from checks.common import Project

DOMAINS = {
    "api": apis,
    "hosting": hosting,
    "a11y": a11y,
    "supabase": supabase,
    "messaging": messaging,
    "functions": functions,
}
SEVERITY_RANK = {"FAIL": 0, "WARN": 1, "MANUAL": 2}
RULE_DOMAINS = {
    "API": "api", "HOST": "hosting", "A11Y": "a11y", "SB": "supabase",
    "MSG": "messaging", "FN": "functions",
}
MANUAL_RULES = {
    "HOST-WAF-DDOS", "HOST-SPEND-CAP", "SB-RLS-LIVE", "FN-CAP-UNVERIFIED",
    "FN-BUDGET-STOP",
}
GATED = ("FAIL", "WARN")


@dataclass(frozen=True)
class Result:
    findings: list
    applicable: list
    skipped: list


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("path", help="project root to scan")
    parser.add_argument(
        "--domain", default=",".join(DOMAINS),
        help="comma list among: " + ", ".join(DOMAINS))
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


def run_checks(project, names):
    findings, applicable, skipped = [], [], []
    for name in names:
        module = DOMAINS[name]
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


def render_text(project, result):
    lines = [
        f"guardrails scan: {project.root} ({len(project.files)} files)",
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


def _rule_domain(rule):
    return RULE_DOMAINS.get(rule.split("-", 1)[0])


def _pairs(value):
    """'RULE:path,RULE:path' -> [(rule, path)]; a missing path stays ''."""
    return [tuple(p.strip() for p in item.partition(":")[::2])
            for item in _split(value)]


def _assert_error(value):
    for rule, path in _pairs(value):
        if not path or not _rule_domain(rule):
            return f"bad --assert-absent item {rule}:{path}, want RULE:path"
        if rule in MANUAL_RULES:
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


def _usage_error(args):
    unknown = [n for n in _split(args.domain) if n not in DOMAINS]
    if unknown:
        return f"unknown domain {unknown}"
    if not Path(args.path).is_dir():
        return f"not a directory: {args.path}"
    return _assert_error(args.assert_absent) or _baseline_error(args.baseline)


def _pair_status(hits, applicable, pair):
    rule, path = pair
    if _rule_domain(rule) not in applicable:
        return False, f"  CONTROL {rule} {path}: domain not scanned, " \
            "absence proves nothing"
    if hits[pair]:
        plural = "s" if hits[pair] > 1 else ""
        return False, f"  PRESENT {rule} {path} ({hits[pair]} hit{plural})"
    return True, f"  CLEAR   {rule} {path}"


def assert_absent(project, result, pairs):
    """Positive control first: an empty tree or an unscanned domain fails."""
    rows = [_pair_status(_hits(result.findings), result.applicable, p)
            for p in pairs]
    lines = [text for _, text in rows]
    if not project.files:
        lines.insert(0, "  CONTROL no file scanned, absence proves nothing")
    ok = bool(project.files) and all(passed for passed, _ in rows)
    return ok, lines + ([f"GUARDRAILS-CLEAR {len(pairs)}"] if ok else [])


def _moved(more, less):
    """Pairs where `more` holds extra hits over `less`, with the surplus."""
    return [(key, more[key] - less[key]) for key in sorted(more)
            if more[key] > less[key]]


def _rows(tag, moved, sign):
    return [f"  {tag:<5} {rule} {path} ({sign}{n})"
            for (rule, path), n in moved]


def baseline_report(before, result):
    after = _hits(result.findings)
    fixed, new = _moved(before, after), _moved(after, before)
    summary = (f"baseline: {sum(n for _, n in fixed)} fixed, "
               f"{sum((before & after).values())} remaining, "
               f"{sum(n for _, n in new)} new")
    lines = _rows("FIXED", fixed, "-") + _rows("NEW", new, "+") + [summary]
    return not new, lines + ([] if new else ["GUARDRAILS-NO-NEW"])


def _check_modes(project, result, args):
    checks = []
    if args.assert_absent:
        checks.append(
            assert_absent(project, result, _pairs(args.assert_absent)))
    if args.baseline:
        checks.append(
            baseline_report(_load_baseline(args.baseline), result))
    return checks


def _scan(args):
    project = Project(Path(args.path), _split(args.exclude))
    result = run_checks(project, _split(args.domain))
    checks = _check_modes(project, result, args)
    if not checks:
        render = render_json if args.json else render_text
        print(render(project, result))
        return 1 if any(f.severity == "FAIL" for f in result.findings) else 0
    for _, lines in checks:
        print("\n".join(lines))
    return 0 if all(ok for ok, _ in checks) else 1


def main(argv):
    args = parse_args(argv)
    error = _usage_error(args)
    if error:
        print(f"usage error: {error}", file=sys.stderr)
        return 2
    return _scan(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
