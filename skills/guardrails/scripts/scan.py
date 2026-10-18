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
