---
name: guardrails
effort: high
description: 'Use when auditing a project against the baseline guardrails: hosting (rate limit, CDN and firewall, spend cap), accessibility (keyboard, visible focus, alt text, field labels), Supabase (RLS on every table, owner-scoped policies, no service_role key client-side), SMS and email (recorded consent, unsubscribe, STOP), cloud functions (no self-trigger, instance cap, budget stop), plus API and access hygiene (auth on every route, CORS, secrets, password storage). Runs a deterministic scanner, judges each hit, writes .claude/audits/GUARDRAILS.md. Triggers: "guardrails", "garde-fous", "RLS activée ?", "audit supabase", "consentement sms", "plafond de dépense", "mots de passe en clair ?", "teste la sécurité de base du projet". Headers and TLS → /harden; secrets, CVE, OWASP → /cso; full WCAG → /web-validate.'
argument-hint: '[project path] [--domain api,hosting,a11y,supabase,messaging,functions] [--exclude paths]'
---

# /guardrails

Checks a project against `rules/secure-by-default.md`. A scanner reads the
tree as data and finds what text can prove. This skill then judges the hits,
covers what text cannot prove, and lists what only a dashboard can set.

The scanner proves absence of a protection, never presence of security. A
clean scan means "no static finding", and the report says exactly that.

## STEP 1: Scope

Work in the project the user names, else the current directory. Say in one
line what you will scan. Domains: `api`, `hosting`, `a11y`, `supabase`,
`messaging`, `functions`. The scanner skips the ones that do not apply.

## STEP 2: Run the scanner

```
python3 -B "$HOME/.claude/skills/guardrails/scripts/scan.py" <path>
```

Add `--domain a,b` to narrow, `--exclude a/b,c` to skip copies or
vendored code, `--json` for machine output. Exit 0 means no
FAIL, 1 means at least one, 2 is a usage error. It never executes project
code. Severities:

- **FAIL**: a protection is provably absent or a key is exposed.
- **WARN**: a pattern that is often wrong; judgment needed.
- **MANUAL**: only a provider dashboard can set or show it.

## STEP 3: Judge every FAIL and WARN

Read the file around each line. Label it CONFIRMED, FALSE POSITIVE (say why)
or ACCEPTED RISK (the user decides, never you). A key sitting in a
git-ignored env file is not reported, that is where local keys belong; whether
it ever reached git history is a separate check (`gitleaks git <repo>`).
Heuristic blind spots are in `references/checks.md`: check them before
calling a hit false.

## STEP 4: Cover what the scanner cannot

Read the code for the domains that apply and answer, with file:line evidence:

- **API**: does each route check authorization on the object, not only
  authentication? Is any id in a URL usable to read another user's data?
  Where is a password written? Trace sign-up and password change to the
  column: an argon2id, bcrypt or scrypt hash is what must land there.
- **Supabase**: does each policy name the right owner column, per operation?
  Is every table created in the dashboard also covered? Give the user the live
  queries from the reference file.
- **Messaging**: does consent get written at the sign-up point with source and
  wording? Is a STOP reply wired from the provider webhook to the store?
- **Functions**: trace every trigger to the resource it writes, including
  queues, storage events, schedulers and third-party webhooks.
- **A11y**: with a dev server running, walk the main flow with Tab only
  (`/browse`). Otherwise mark the keyboard walk-through as not done.

## STEP 5: Manual checklist

Print each MANUAL item as a step the user performs: spend cap, WAF and DDoS
rules, budget alert wired to a stop, live RLS queries. Provider limits change:
name the setting, tell the user to confirm it in the current provider docs.
Never run a live probe against production, and never claim a MANUAL item done.

## STEP 6: Report

Write `.claude/audits/GUARDRAILS.md`: one table per domain with status PASS,
FAIL, WARN, MANUAL or N/A, the evidence, and the fix in one line. PASS means
"no static finding". Keep it short; no filler sections.

## STEP 7: Hand over

Reply with counts, the FAILs with file:line and a one-line fix each, and the
MANUAL items. This skill audits; it does not fix. A fix goes through
`/bugfix`, `/feat` or `/hotfix`.
