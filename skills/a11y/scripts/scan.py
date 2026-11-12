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
