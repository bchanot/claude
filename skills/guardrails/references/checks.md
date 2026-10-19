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

## injection

Patterns are per language: a Postgres `$1` placeholder, a tagged template
(`sql\`…\``, `sql<T>\`…\``), an argv array and test or fixture paths are
silent by design.

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| INJ-SQL-RAW-UNSAFE | WARN | `$queryRawUnsafe`, `$executeRawUnsafe`, `knex.raw`, `sequelize.query`, `Sequelize.literal`, Django `.objects.raw()` / `.extra()`, SQLAlchemy `text()` fed a variable (a variable may hold a constant)| show it is a constant with bound values, else bind them; or the tagged `$queryRaw` |
| INJ-SQL-CONCAT | FAIL | a SQL statement (select … from … where, insert into, update … set, delete … where, create/drop/alter) built with `${}`, `+`, an f-string, `%`, `.format`, PHP `$var`, Ruby `#{}` (ActiveRecord `where("… #{}")` included), `format!`, `Sprintf` | placeholders and a parameter list |
| INJ-SQL-DYNAMIC-EXEC | WARN | plpgsql `EXECUTE '…' \|\| x` | `format('… %I %L', …)` and `USING` |
| INJ-POSTGREST-FILTER | WARN | supabase-js `.or()`, `.filter()`, `.not()`, `.match()`, `.textSearch()` with an interpolated string, in a file that uses supabase | `.eq()` and friends, validated values |
| INJ-NOSQL-OPERATOR | WARN | Mongo `$where` with a string; a filter taken from `req.body`, `req.query` or `req.params` | allowlist the fields, cast to string, `sanitizeFilter` |
| INJ-SHELL-DB-TOOL | FAIL | a shell call naming psql, mysql, mysqldump, pg_dump, mongosh, redis-cli, sqlite3… with an interpolated argument (an argv array and a bare `$ENV_VAR` stay silent; in PHP every `$name` counts) | an argv array, no shell, validated input |

## exposure

| Rule | Sev | Catches | Fix |
|---|---|---|---|
| EXP-CONSOLE-DATA | WARN | `console.log/info/debug/dir/table` in client-reachable code with a data argument (user, session, response, token, body…); string literals are ignored | strip console calls in the production build, log server-side |
| EXP-SOURCEMAP-PUBLIC | FAIL / WARN | `productionBrowserSourceMaps: true`, vite `sourcemap: true` or `'inline'`, `GENERATE_SOURCEMAP=true` in a committed non-dev env file, webpack `devtool` readable maps (FAIL in `webpack.prod*`, WARN elsewhere), a real `.map` under `public/` or `static/` (any size; vendored and `.min.` maps excluded); angular `sourceMap: true` (WARN) | off, or `hidden` and upload to the error tracker |
| EXP-HYDRATED-SENSITIVE | WARN | a token, secret, key, password or ssn-like key returned by `getServerSideProps`, `getStaticProps`, a Remix `loader`, a SvelteKit `load` or set on `window.__STATE__`; a TS type member is skipped | return only the fields the page renders |
| EXP-MARKUP-COMMENT | WARN | `<!-- -->` shipped to the browser (html, astro, php, ejs, hbs, twig, njk, liquid) with todo, fixme, debug, password, token, internal, staging, admin… | delete it, or move it to a code comment the build strips |
| EXP-DATA-ATTR-SENSITIVE | WARN | `data-*` attribute or hidden input named secret, api-key, password, jwt, private, credential (csrf, xsrf, authenticity, nonce excluded) | keep it server-side, send an opaque id |
| EXP-ERROR-STACK | FAIL | in any server file: `err.stack`, the error object, `traceback.format_exc()` or `getTraceAsString()` in a response | generic message out, full error in the server log |
| EXP-ERROR-MESSAGE | WARN | in any server file: `err.message`, `str(e)`, `$e->getMessage()` sent as is | map to a safe message; validation errors are fine, DB errors are not |
| EXP-DEBUG-ON | FAIL | `DEBUG = True` in a settings module (not dev/local/test), `APP_DEBUG=true` / `FLASK_DEBUG=1` in a committed non-dev env file, `app.debug = True`, `consider_all_requests_local = true`, `errorhandler()` mounted without an environment guard | env-driven, false in production |
| EXP-RESPONSE-WIDE | WARN | a route returning `select *` / `select('*')` on a users-like table, or a single-line Prisma `findUnique/findFirst/findMany` without `select` or `omit` | an explicit field list |

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
UI route components, keys
inside git-ignored env files, and password literals in test, fixture and
i18n files, tagged SQL templates, placeholders with a separate parameter list, an argv array handed to a DB tool, console calls in server code, logging calls that carry a stack, `sourcemap: 'hidden'`, a debug flag read from the environment, dev, local and test env files and settings modules, minified files and built directories, and a hidden input or data attribute named csrf, xsrf, authenticity or nonce.

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

## Live probe (`--live`, read-only)

`probe.py` observes a running target the user owns and names. It is driven by
a plan JSON built from the static findings; secrets come from the environment,
never the plan or the command line. It sends GET, HEAD and OPTIONS only, with
one opt-in POST burst for the rate-limit check, and stops at a request budget.

```json
{
  "base_url": "http://localhost:5173",
  "supabase": {
    "url": "http://localhost:54321",
    "tables": ["notes", "contacts"],
    "cross_user_paths": ["/rest/v1/notes?select=*"]
  },
  "routes": [
    {"path": "/api/v1/notes"},
    {"path": "/api/v1/health", "public": true}
  ],
  "cors": true,
  "cors_path": "/api/v1/notes",
  "rate_limit": {"path": "/api/v1/auth/login", "method": "POST",
                 "count": 20, "body": "{\"email\":\"t@t.io\",\"password\":\"x\"}"},
  "exposure": {"error_routes": ["/api/v1/notes/not-a-number"]}
}
```

Environment, from test keys only, never `service_role`:
`GUARDRAILS_ANON_KEY` (anon-read), `GUARDRAILS_JWT2` (cross-user).
The fields probe sends `GUARDRAILS_JWT2` as a bearer when it is set. Every path in the plan starts with `/`: a path that could leave the named host is a usage error.

| Probe | id | OPEN means | Read it against |
|---|---|---|---|
| anon-read | `anon-read:<table>` | the anon key read a row | SB-RLS-MISSING, SB-POLICY-* |
| cross-user | `cross-user:<path>` | a second user's token read these rows | policy owner column (STEP 4) |
| no-auth route | `no-auth:<path>` | the route answered 200 with no token | API-ROUTE-NO-AUTH, object authz |
| cors-reflect | `cors-reflect` | a foreign origin was reflected with credentials | API-CORS-WILDCARD |
| rate-limit | `rate-limit` | the burst saw no 429 | HOST-NO-RATE-LIMIT |
| sourcemap | `sourcemap:<script>` | a source map with sources answered 200 for a page script, or the script carries an inline map | EXP-SOURCEMAP-PUBLIC |
| error-body | `error-body:<path>` | a 404 or a named error route returned a stack trace or an internal path | EXP-ERROR-STACK, EXP-DEBUG-ON |
| fields | `fields:<path>` | a JSON 200 carried a password, salt, token, hash, key or secret-like key (`private` only as private_key; identifier-shaped names printed, never values) | EXP-RESPONSE-WIDE, EXP-HYDRATED-SENSITIVE |

A verdict is an observation, not a verdict on the project. OPEN is a returned
200 or returned rows; CLOSED is a refusal or an empty body; SKIPPED is a
missing key; ERROR is a transport failure. A static FAIL confirmed OPEN leads
the report. A CLOSED probe on a static FAIL still needs the fix: the dev
target may differ from production. An exposure target the probe could not observe (unreachable page, no same-host script, a refused or non-JSON route, a map fetch that failed) is SKIPPED or ERROR, never CLOSED. Run the exposure block against a production build or a staging URL: a dev server serves maps and tracebacks by design, and its OPEN verdicts are dev artefacts, not findings.

Safety, enforced by the script and by the skill: `--authorized` is required;
read-only methods only; the loopback or a URL the user named, never one you
inferred; a login burst only with a throwaway test account on the user's go,
because it can lock the user's own account; a redirect to another host is
never followed, so a key never leaves the named host. A script on another host is never fetched. An error route is a path you own and name; the probe never guesses one beyond its single random 404. Fuzzing, writes beyond
the named login route, or probing a third party are out of scope: that is
pentest, another contract.

## Fix loop: oracles and re-pass

Every accepted fix is proven by the scanner itself, never by the executor's
word. Two check modes replace the report and its exit code:

| Mode | Passes when | Marker | Used by |
|---|---|---|---|
| `--assert-absent RULE:path,...` | none of these FAIL/WARN pairs remains, the domain was scanned, the tree is not empty | `GUARDRAILS-CLEAR <n>` | a contract `CHECK:` run by `lib/gates.sh` (GATE 0) |
| `--baseline before.json` | no FAIL/WARN hit appeared since the earlier `--json` run | `GUARDRAILS-NO-NEW` | STEP 11 re-pass |

Pairs match on rule and file, not line: a fix moves lines. A MANUAL rule
cannot be asserted (exit 2): no static scan proves a dashboard setting. An
unscanned domain or an empty tree fails the assertion, because absence there
proves nothing. Run every oracle once before the fix: it must fail.

The baseline lists `FIXED` and `NEW` pairs with their hit counts and a
remaining total. A `NEW` hit after a fix is a regression the fix made.
