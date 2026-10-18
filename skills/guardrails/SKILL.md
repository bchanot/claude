---
name: guardrails
effort: high
description: 'Use when auditing a project against the baseline guardrails: hosting (rate limit, CDN and firewall, spend cap), accessibility (keyboard, visible focus, alt text, field labels), Supabase (RLS on every table, owner-scoped policies, no service_role key client-side), SMS and email (recorded consent, unsubscribe, STOP), cloud functions (no self-trigger, instance cap, budget stop), plus API and access hygiene (auth on every route, CORS, secrets, password storage). Runs a deterministic scanner, judges each hit, writes .claude/audits/GUARDRAILS.md. Optional read-only live probe confirms a hole from outside on a target the user owns and names. Triggers: "guardrails", "garde-fous", "RLS activée ?", "audit supabase", "consentement sms", "plafond de dépense", "mots de passe en clair ?", "teste la sécurité de base du projet", "teste-le en conditions réelles", "sonde le projet en direct". Headers and TLS → /harden; secrets, CVE, OWASP → /cso; full WCAG → /web-validate.'
argument-hint: '[project path] [--domain api,hosting,a11y,supabase,messaging,functions] [--exclude paths] [--live <url you own>]'
---

# /guardrails

Checks a project against `rules/secure-by-default.md`. A scanner reads the
tree as data and finds what text can prove. This skill then judges the hits,
covers what text cannot prove, lists what only a dashboard can set, and, on
request, probes a running target the user owns to confirm a hole from outside.

The scanner proves absence of a protection, never presence of security. A
clean scan means "no static finding", and the report says exactly that. A
live probe proves the opposite direction: that a door is actually open.

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

## STEP 5: Live probe (only on `--live`, read-only)

The static scan shows a protection is missing in the code. A probe shows the
door is actually open. Run it only when the user asks, and only against a
target the user owns and names: their local dev server first, a staging or
production URL only on an explicit, specific go. Never a URL you inferred,
never a third party.

1. **Build the plan** `references/checks.md` describes. From the static
   findings fill a JSON plan: `base_url`, the Supabase `url` and `tables`,
   the `routes` (mark the ones meant to be public), `cors`, and a
   `rate_limit` route if the user wants that one burst. Secrets never go in
   the plan or the command line: export `GUARDRAILS_ANON_KEY` and, for the
   cross-user probe, `GUARDRAILS_JWT2`, from test keys, never `service_role`.
2. **Run it**, confirming ownership with `--authorized`:
   ```
   python3 -B "$HOME/.claude/skills/guardrails/scripts/probe.py" \
     plan.json --authorized
   ```
   It sends GET, HEAD and OPTIONS only (the rate-limit burst is the one
   POST, opt-in in the plan, capped at 25 requests). It never writes data,
   never follows a redirect to another host, and stops at a request budget.
   Exit 1 means at least one OPEN verdict.
3. **Cross the verdicts with the static findings.** A verdict is an
   observation, not a conclusion: OPEN means the request returned data or a
   200, CLOSED means it was refused or empty. A static FAIL confirmed OPEN in
   the probe leads the report. A CLOSED probe on a static FAIL still needs the
   fix: the dev target may differ from production.
4. **Guardrails on the probe itself**: read-only, test keys only, the
   loopback or a URL the user named. A login burst can lock the user's own
   account, so run it only with a throwaway test account and the user's go.
   Never fuzz, never POST to anything but a named login route, never probe a
   target you were not told to. That is pentest territory, another contract.

## STEP 6: Manual checklist

Print each MANUAL item as a step the user performs: spend cap, WAF and DDoS
rules, budget alert wired to a stop, live RLS queries. Provider limits change:
name the setting, tell the user to confirm it in the current provider docs.
Never run a live probe against production without the user's explicit go, and
never claim a MANUAL item done.

## STEP 7: Report

Write `.claude/audits/GUARDRAILS.md`: one table per domain with status PASS,
FAIL, WARN, MANUAL or N/A, the evidence, and the fix in one line. PASS means
"no static finding". When a live probe ran, add a line for its verdict next
to the matching static finding. Keep it short; no filler sections.

## STEP 8: Hand over

Reply with counts, the FAILs with file:line and a one-line fix each, any OPEN
probe verdicts, and the MANUAL items. This skill audits; it does not fix. A
fix goes through `/bugfix`, `/feat` or `/hotfix`.
