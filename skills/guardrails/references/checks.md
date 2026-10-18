# Guardrail checks

Rule ids the scanner emits, what each proves, and the fix. Severity is the
default; a judged hit can be a false positive.

## api

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| API-SECRET-LITERAL | FAIL | provider key or private key block in source | env var, rotate the key |
| API-PUBLIC-ENV-SECRET | FAIL | `NEXT_PUBLIC_`, `VITE_`, `PUBLIC_` style prefix on a SERVICE_ROLE, SECRET, PRIVATE or PASSWORD name | drop the prefix, read it server-side |
| API-ENV-NOT-IGNORED | FAIL | `.env*` file with values, not in `.gitignore` | ignore it, rotate what was exposed |
| API-CORS-WILDCARD | FAIL / WARN | any origin allowed; FAIL when credentials are on | explicit origin allowlist |
| API-ROUTE-NO-AUTH | WARN | route file with no authentication evidence | add auth, or document why it is public and rate limit it |
| API-PASSWORD-PLAINTEXT | FAIL | password column typed as text with no hashing library anywhere; stored password compared with `==` or in a SQL `where password = $1` | argon2id, bcrypt or scrypt hash, verified with the library's check |
| API-PASSWORD-WEAK-HASH | FAIL | md5, sha1, sha256 or `createHash().update()` fed a password | argon2id, scrypt or bcrypt |
| API-PASSWORD-LOGGED | FAIL | `console.log`, `logger.*`, `print`, `println!`, `error_log` with a password identifier among its arguments, template interpolations included | never log credentials |
| API-PASSWORD-LITERAL | WARN | `password: "..."`, `DB_PASSWORD=...` with a value of 8+ characters that is not a placeholder, hash, validation rule or label | env var and rotate; a dev default is documented as such |

## hosting

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| HOST-NO-RATE-LIMIT | FAIL | no rate limiting anywhere in code or config | per IP and per account on login, signup, reset, send, upload |
| HOST-ORIGIN-EXPOSED | WARN | origin platform with no CDN or firewall mention | put a CDN and WAF in front |
| HOST-WAF-DDOS | MANUAL | firewall, DDoS and bot rules are dashboard settings | enable and confirm in the dashboard |
| HOST-SPEND-CAP | MANUAL | hard spend cap is a plan setting | enable the cap; else budget alert plus a written kill switch |

## a11y

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| A11Y-IMG-ALT | FAIL | `img` or `Image` without `alt` | describe it, or `alt=""` if decorative |
| A11Y-FIELD-LABEL | FAIL | native input, select, textarea with no label | `label for`, wrapping label or `aria-label` |
| A11Y-CLICK-NO-KEYBOARD | FAIL | click handler on a div or span lacking role, tabindex or key handler | use a `button` |
| A11Y-FOCUS-OUTLINE | FAIL / WARN | focus outline removed; WARN when a `:focus-visible` style exists elsewhere | style `:focus-visible` instead |
| A11Y-TABINDEX-POSITIVE | WARN | `tabindex` above 0 | use 0 or -1 and fix the DOM order |

## supabase

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| SB-RLS-MISSING | FAIL | table created in migrations, RLS never enabled | `alter table ... enable row level security` in the same migration |
| SB-RLS-LIVE | MANUAL | dashboard-created tables are invisible to a static scan | run the live queries below |
| SB-POLICY-OPEN-WRITE | FAIL | `using (true)` or `with check (true)` on a write | scope to `(select auth.uid())` |
| SB-POLICY-ANON-WRITE | FAIL | write policy open to anon or public, not owner-scoped | `to authenticated` plus owner check |
| SB-POLICY-PUBLIC-READ | WARN | read policy `true` | confirm the data is public |
| SB-POLICY-NOT-OWNER | WARN | policy with no `auth.uid()` or `auth.jwt()` | tie to the owner, or to a reviewed helper |
| SB-VIEW-INVOKER | WARN | view runs as its owner and bypasses RLS | `with (security_invoker = true)` |
| SB-MATVIEW-EXPOSED | WARN | materialized views cannot have RLS | move out of the exposed schema or revoke |
| SB-DEFINER-SEARCH-PATH | WARN | `security definer` without a pinned `search_path` | `set search_path = ''` |
| SB-DEFINER-EXECUTE | WARN | definer function callable by anon | `revoke execute ... from public, anon` |
| SB-BUCKET-PUBLIC | WARN | public storage bucket | private plus storage policies |
| SB-EDGE-NO-JWT | WARN | edge function with `verify_jwt = false` | fine for webhooks that verify a signature |
| SB-SERVICE-ROLE-CLIENT | FAIL | service role or secret key referenced in client-reachable code | server only |
| SB-SERVICE-ROLE-LITERAL | FAIL | service_role JWT pasted in a file | rotate it, move to server env |

## messaging

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| MSG-NO-CONSENT-RECORD | FAIL / WARN | sender code, no stored consent anywhere; WARN when every sender looks transactional (contact form, reset, receipt) and no subscriber storage exists | store who, when, channel, source, wording |
| MSG-SEND-UNCHECKED | WARN | sender file never checks consent or suppression | check before every send |
| MSG-NO-UNSUBSCRIBE | FAIL / WARN | email sent, no unsubscribe anywhere; same transactional downgrade | link in every email |
| MSG-NO-LIST-UNSUBSCRIBE | WARN | no `List-Unsubscribe` header | add it, with one-click post |
| MSG-SMS-NO-STOP | FAIL / WARN | SMS sent, no `STOP` text; same transactional downgrade | add "Reply STOP" to marketing SMS |
| MSG-SMS-NO-OPTOUT-STORE | FAIL / WARN | no opt-out storage; same transactional downgrade | record STOP replies, check before sending |

## functions

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| FN-NO-MAX-INSTANCES | FAIL | Firebase, AWS Lambda or Google Cloud with no instance or concurrency cap | set it |
| FN-CAP-UNVERIFIED | MANUAL | platform with no cap the scanner can read | check the provider docs; rely on spend cap |
| FN-BUDGET-STOP | MANUAL | budget alert wired to an automatic stop | set it; confirm in the console |
| FN-SELF-TRIGGER | FAIL / WARN | function writes the resource that fires it (WARN when guarded or file-level heuristic) | `WHEN` guard or idempotency flag |
| FN-SELF-INVOKE | FAIL | edge function invokes itself | remove, or cap the depth |

## Blind spots

The scanner is regex over text. It cannot see:

- tables, policies or buckets made in the dashboard
- whether a policy names the right owner column
- whether consent was actually collected before the stored timestamp
- whether a STOP reply reaches your store from the provider webhook
- loops through queues, storage events, schedulers or third-party webhooks
- keyboard traps, focus order, modal focus handling, color contrast
- client-reachable code in unusual layouts (the rule uses path and
  `use client` heuristics, `.astro` is never flagged)
- values built at runtime, minified bundles, anything over 1 MB
- keys committed in the past: only the working tree is read, use
  `gitleaks git <repo>` for history
- a password written in clear by code when a hashing library exists
  elsewhere: the column rule fires only when no library is found anywhere,
  so trace the write point by hand (STEP 4)
- a log call spanning several lines, or `req.body` dumped to a log

Sender classification is by file path only: names with contact, reset, verify,
otp, receipt and the like count as transactional, names with newsletter,
campaign, promo and the like as marketing, anything else as unknown. Test files
never count as senders. A shared mailer class is therefore judged by the
project: a contact form beside it and no subscriber storage gives WARN.

The scanner skips log files and cache directories, and never follows symlinks.

By design the scanner ignores: policies granted only to `service_role`,
fields that are never rendered (`hidden`, `display: none`), click handlers
that only stop propagation or sit on `role="presentation"`, focus styles
that swap the outline for a border or shadow, UI route components, keys
inside git-ignored env files, and password literals in test, fixture and
i18n files.

## Live Supabase checks (the user runs them in the SQL editor)

```sql
-- tables in the public schema without RLS
select tablename from pg_tables
where schemaname = 'public' and not rowsecurity;

-- every policy, to read the owner scoping by eye
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies where schemaname = 'public' order by tablename, cmd;

-- views that bypass RLS
select c.relname from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v'
  and coalesce(c.reloptions::text, '') not like '%security_invoker=true%';

-- definer functions callable by anon
select p.proname, p.proconfig from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef
  and has_function_privilege('anon', p.oid, 'execute');

-- public buckets
select id from storage.buckets where public;
```

Two probes on the user's own project, read-only. With the anon key, a GET on
each private table must return an empty list or 401. With a second test
user's token, a GET on the first user's rows must return nothing.

## Manual items by domain

- **Hosting**: rate rules and DDoS or bot protection on at the CDN; a hard
  spend cap if the plan has one; a budget alert and a written kill-switch step.
- **Functions**: budget alert wired to an automatic stop (throttle concurrency
  to zero, revoke invoke rights, or disable billing); a timeout on every
  function.
- **Messaging**: provider-side STOP handling on, a webhook storing opt-outs,
  a retention rule for consent proof.
- **Supabase**: the live queries above; spend cap on the plan; redirect URLs
  and email confirmation settings reviewed.
