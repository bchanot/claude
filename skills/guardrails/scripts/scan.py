#!/usr/bin/env python3
"""Static guardrails scan: API, hosting, Supabase, messaging, functions,
injection, exposure.

See scanner.py for the modes and exit codes.
"""
import sys

import scanner
from checks import (
    apis, exposure, functions, hosting, injection, messaging, supabase,
)

CATALOGUE = scanner.Catalogue(
    name="guardrails",
    domains={
        "api": apis,
        "hosting": hosting,
        "supabase": supabase,
        "messaging": messaging,
        "functions": functions,
        "injection": injection,
        "exposure": exposure,
    },
    rule_domains={
        "API": "api", "HOST": "hosting", "SB": "supabase",
        "MSG": "messaging", "FN": "functions",
        "INJ": "injection", "EXP": "exposure",
    },
    manual_rules=frozenset({
        "HOST-WAF-DDOS", "HOST-SPEND-CAP", "SB-RLS-LIVE",
        "FN-CAP-UNVERIFIED", "FN-BUDGET-STOP",
    }),
)

if __name__ == "__main__":
    sys.exit(scanner.main(sys.argv[1:], CATALOGUE))
