#!/usr/bin/env python3
"""Static guardrails scan: API, hosting, a11y, Supabase, messaging, functions.

Reads a project tree as data and never executes it. Exit codes:
0 no FAIL, 1 at least one FAIL, 2 usage error.
"""
import argparse
import json
import sys
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


def _usage_error(path, names):
    unknown = [n for n in names if n not in DOMAINS]
    if unknown:
        return f"unknown domain {unknown}"
    return "" if Path(path).is_dir() else f"not a directory: {path}"


def _scan(args):
    project = Project(Path(args.path), _split(args.exclude))
    result = run_checks(project, _split(args.domain))
    render = render_json if args.json else render_text
    print(render(project, result))
    return 1 if any(f.severity == "FAIL" for f in result.findings) else 0


def main(argv):
    args = parse_args(argv)
    error = _usage_error(args.path, _split(args.domain))
    if error:
        print(f"usage error: {error}", file=sys.stderr)
        return 2
    return _scan(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
