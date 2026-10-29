---
name: guardrails
effort: high
description: 'Use when auditing a project against the baseline guardrails and fixing what fails. Headers and TLS → /harden; secrets, CVE, dependencies → /cso; keyboard, alt, labels → /a11y. Domains: hosting (rate limit, CDN, spend cap), Supabase (RLS, owner policies, no service_role client-side), SMS and email (consent, unsubscribe, STOP), cloud functions (no self-trigger, instance cap, budget stop), injection (SQL from input, raw escapes, NoSQL, shell into DB tools), exposure (console data, source maps, hydrated state, error bodies, debug mode, wide responses), plus API hygiene (auth, CORS, secrets, passwords). Scanner, judgment, .claude/audits/GUARDRAILS.md, fixes applied only on acceptance (bugfixer, verifier and security gates), re-scanned to prove them; optional read-only probe of a target you own. Triggers: "guardrails", "garde-fous", "RLS activée ?", "faille sql", "fuite navigateur", "plafond de dépense", "mots de passe en clair ?", "corrige les garde-fous", "sonde le projet en direct".'
argument-hint: '[project path] [--domain api,hosting,supabase,messaging,functions,injection,exposure] [--exclude paths] [--live <url you own>] [--report-only]'
---

# /guardrails

Checks a project against `rules/secure-by-default.md` (domains 4 and 6 in
full: `rules/supabase.md`, `rules/cloud-functions.md`), then fixes what the
user accepts and proves each fix. A scanner reads the tree as data and finds
what text can prove. This skill judges the hits, covers what text cannot
prove, lists what only a dashboard can set and, on request, probes a running
target the user owns. It then proposes fixes, applies the accepted ones and
runs the scan again until every accepted fix is proven.

The scanner proves absence of a protection, never presence of security. A
clean scan means "no static finding", and the report says exactly that. A
live probe proves the opposite direction: that a door is actually open.

## MODEL GATE (blocking, before any other step)

Run `$HOME/.claude/lib/model-gate.md`. Judging hits and designing fixes
requires Fable or Opus. Verdict `small` → STOP: the gate prints the remedy.
ROUTING: follow `$HOME/.claude/lib/effort-shift.md` (phases via
`mcp__model-router__route`); each step below names its phase.

## STEP 1: Scope

Work in the project the user names, else the current directory. Say in one
line what you will scan. Domains: `api`, `hosting`, `supabase`,
`messaging`, `functions`, `injection`, `exposure`. The scanner skips the ones that do not apply.
`--report-only` stops after STEP 7: audit, no fix.

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

- INJ-SQL-CONCAT on `IN (${placeholders})` where the list is generated
  `?`/`$n` markers and the values travel in a separate array: parameterised,
  confirm by hand and drop it from the proposals.

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
- **Injection**: for each INJ hit, trace the interpolated value to its
  source. A constant, an allowlisted identifier or a value already cast to
  a number is a FALSE POSITIVE; anything that can come from a request,
  a file or another user's row is CONFIRMED.
- **Exposure**: read the code behind each EXP hit: is the logged object,
  the hydrated key or the returned row really user data? With `--live`
  against a production build (STEP 5), the probe answers for served
  source maps, error bodies and sensitive keys; without it, say so.

## STEP 5: Live probe (only on `--live`, read-only)

The static scan shows a protection is missing in the code. A probe shows the
door is actually open. Run it only when the user asks, and only against a
target the user owns and names: their local dev server first, a staging or
production URL only on an explicit, specific go. The `exposure` block runs against a production build or a staging URL (`next build && next start`, `vite preview`, framework debug off): a dev server serves source maps and tracebacks by design, so its exposure OPEN verdicts are dev artefacts, reported as such, with no proposal and no re-pass requirement. Never a URL you inferred,
never a third party.

1. **Build the plan** `references/checks.md` describes. From the static
   findings fill a JSON plan: `base_url`, the Supabase `url` and `tables`,
   the `routes` (mark the ones meant to be public), `cors`, and a
   `rate_limit` route if the user wants that one burst. Add an `exposure` block (`{}` for the defaults, `error_routes` for a route you own that answers an error to a malformed id, never a path you guess) so the probe reads source maps, error bodies and response keys; every path in the plan starts with `/`. Secrets never go in
   the plan or the command line: export `GUARDRAILS_ANON_KEY` and, for the
   cross-user probe, `GUARDRAILS_JWT2`, from test keys, never `service_role`. The fields probe sends
   `GUARDRAILS_JWT2` as a bearer when set, so an OPEN there is what a
   logged-in user sees.
2. **Run it**, confirming ownership with `--authorized`. Before adding `--authorized`, show the user both hosts the plan names (`base_url` and the Supabase `url`, the latter read from the project's config and so untrusted) and get their go on both:
   ```
   python3 -B "$HOME/.claude/skills/guardrails/scripts/probe.py" \
     plan.json --authorized
   ```
   It sends GET, HEAD and OPTIONS only (the rate-limit burst is the one
   POST, opt-in in the plan, capped at 25 requests). It never writes data,
   never follows a redirect to another host, and stops at a request budget.
   Exit 1 means at least one OPEN verdict. Keep the plan file: STEP 11
   replays it.
3. **Cross the verdicts with the static findings.** A verdict is an
   observation, not a conclusion: OPEN means the request returned data or a
   200, CLOSED means it was refused or empty. SKIPPED and ERROR mean the target was not observed: never read either as proof of a fix. A static FAIL confirmed OPEN in
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
`--report-only`, or nothing CONFIRMED and no OPEN verdict: reply with counts,
the FAILs with file:line, any OPEN verdict and the MANUAL items, then stop.

## STEP 8: Propose fixes

`mcp__model-router__route(phase="plan")`: designing a fix is the deepest
thinking in this run, it goes to the plan row.

One proposal per CONFIRMED finding, grouped by rule and file; merge pairs
that one change closes (one middleware closes HOST-NO-RATE-LIMIT for every
route). FALSE POSITIVE and ACCEPTED RISK get no proposal. Each proposal:

- **number, rule, file(s)**, and the problem in one line;
- **the fix**, concrete: file:line and the change, the SQL for a migration,
  the parameter binding for a query. Root cause, never a mask: a missing RLS gets
  owner policies in the same migration, not a disabled check;
- **choices the user sees** (allowlisted filter fields, CORS origins, owner column,
  rate-limit numbers), each with your proposed value, named so the user can
  change it;
- **risk**: what it can break. `BREAKING` when it changes a contract a client
  relies on (RLS without policies blocks the app, a CORS allowlist drops an
  origin, a new required header). `DECISION` when no default is defensible
  (consent model, retention period): the user picks before it can apply;
- **proof**: the scanner pairs that must disappear (`RULE:path`), the probe
  that must turn CLOSED, and a project test when one fits naturally.

MANUAL items stay user steps (STEP 6), never proposals. A live OPEN verdict
with no static finding gets a proposal whose proof is the probe alone,
unless STEP 5 marked it a dev artefact.

Save the proposals to `.claude/tasks/plans/<YYYY-MM-DD>-guardrails-<HHMM>.md`
and append them to the report. In the reply, show them as a numbered list,
one or two lines each, BREAKING and DECISION marked.

## STEP 9: Approval (gate, ends the turn)

Nothing is applied without the user's explicit acceptance. Ask once, then
stop the turn:

```
Which fixes do I apply? "all" (every proposal except DECISION ones),
numbers ("1,3,5-7"), "none", or an amendment ("2 with the fields ['id','status']").
A DECISION proposal needs its number plus your choice.
```

On resume, `mcp__model-router__route(phase="reflect")`. "none" → stop,
proposals stay in the report. An amendment rewrites that proposal in the plan
file before anything else. Accepted set empty → stop.

## STEP 10: Apply

1. **Branch.** Not a git repository → stop: fixes need a diff to review.
   On `main`/`develop`, `bash ~/.claude/lib/gitflow.sh start bugfix
   guardrails-<YYYY-MM-DD>`; on a working branch, stay. Never `finish`.
2. **Baseline**, before any edit:
   `python3 -B <scan.py> <root> --json > .claude/audits/.guardrails-baseline.json`.
   A derived file: never staged, never committed.
3. **Contract** per `$HOME/.claude/lib/contract-interview.md` (STEP 4
   template, `flow: guardrails`). REQUEST = the user's acceptance verbatim
   plus the accepted proposals. One criterion per accepted proposal, its
   oracle the scanner itself:
   ```
   1. <proposal 1 in one line>
      CHECK: python3 -B "$HOME/.claude/skills/guardrails/scripts/scan.py" '<abs root>' --assert-absent 'RULE:path,RULE:path'
      EXPECT: GUARDRAILS-CLEAR
      EVIDENCE: pending
   ```
   Add one criterion for the project suite when one exists
   (`CHECK: <test command> && echo TESTS-GREEN`, `EXPECT: TESTS-GREEN`). A
   proof the scanner cannot run (probe, cross-user, manual SQL) is a
   criterion without CHECK: STEP 11 settles it. FILE SCOPE = the files the
   accepted proposals name. Paths go in single quotes; a path holding a
   single quote is named to the user, never written into a CHECK. The
   RULE:path pairs come from the `--json` output, never from the text report.
4. **Positive control.** Run each oracle once on the unfixed tree: it must
   fail. An oracle that passes before the fix proves nothing; drop it, find
   why, and say so.
5. **Dispatch the executor**, one fresh `bugfixer` for the accepted set
   (batches of 8 proposals at most, one after the other on the same branch):
   ```
   mcp__model-router__route(phase="orchestrate")   # send with the Agent call
   Agent(subagent_type="bugfixer")
   prompt: "CONTRACT: <path>
   DIAGNOSIS: <each accepted finding: rule, file:line, evidence, root cause>
   FIX PLAN: <the accepted proposals verbatim, with the user's choices; the
   regression check of each is its contract oracle, plus the project test
   the proposal names>
   BRANCH: <current branch>
   Apply to the letter. No commit, no branch ops, no security dispatch.
   Finish with the BUGFIX-EXEC REPORT."
   ```
   `NEED-DECISION` routes per MID-RUN CLARIFICATION of the contract include:
   a visible, public-name or scope question goes to the user verbatim.
   `BLOCKED` → surface it, stop.
6. **Gates** per `$HOME/.claude/lib/verify-secure-loop.md`, `CONTRACT` the
   path above, `DIFF` the executor's working-tree diff, `TEST` the suite.
   GATE 0 runs every scanner oracle (the per-fix proof), GATE 1 a fresh
   verifier, GATE 2 a fresh security-auditor. Loop caps and escalation are
   the include's; loop decisions stay in this main loop.

## STEP 11: Re-pass (prove it all)

`mcp__model-router__route(phase="reflect")`. The gates proved each accepted
fix on its own; this pass proves the whole tree.

1. Full scan against the baseline:
   ```
   python3 -B <scan.py> <root> --baseline .claude/audits/.guardrails-baseline.json
   ```
   Every accepted pair must show `FIXED`, and the run must end on
   `GUARDRAILS-NO-NEW` (exit 0). A `NEW` hit is a regression the fix made.
2. Live: when STEP 5 ran, replay the same plan on the same target once the
   user has reloaded or redeployed it and says go. A fix in code is not live
   until it runs. Each fixed proposal's probe must now read CLOSED.
3. Settle the criteria without CHECK, by reading or by the user's answer for
   a manual step.
4. Add an "after" column to `.claude/audits/GUARDRAILS.md`: proposal,
   before, after, evidence.

Anything not fixed, or a NEW hit → one more round from STEP 8, limited to
those items. Two rounds at most: after the second, stop with the residuals
open and say so plainly. Never report a fix the re-pass did not prove.

## STEP 12: Commit and hand over

1. **Commit gate.** Show files, `git diff --stat` and the message, wait for
   the user's go:
   ```
   GUARDRAILS: READY TO COMMIT
   FILES   : <list>
   MESSAGE : fix(security): <rules fixed, one line>
   ```
   Then `git add <files touched>` (never `-A`, never the baseline file) and
   commit, project convention else 50 words at most.
2. `mcp__model-router__route(phase="apply")` for the tail. Reply with: fixed
   and proven (proposal, rule, file), still open and why, MANUAL steps left
   for the user, the branch name. Merge waits for the user's explicit signal.
3. Offer to capitalize a reusable lesson (a false-positive class, a fix
   pattern), entry pre-filled, written only on approval.
