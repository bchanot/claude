# Secure by default: six domains and every API

Scope: any project that has a public surface, an API, a database, messaging,
a cloud function or a UI. Applies at design, scaffolding, implementation and
review. A request that breaks one of these gets flagged, not silently done.
What only a provider dashboard can set (spend cap, WAF, budget alert) is
never claimed done: write it as a manual step in the project's deploy notes.
`/guardrails` audits all of it and fixes what the user accepts.

## Every API and every access
- Default deny. Authentication and authorization checked server-side on every
  route, function, RPC and webhook, never only at the entry point.
- Webhooks verify a signature. CORS is an allowlist, never `*` with credentials.
- Keys are least privilege and server-side. Responses carry only needed fields.
- Validate every input at the boundary. Rate limit every unauthenticated or
  costly route.
- Passwords hashed with argon2id (bcrypt or scrypt otherwise), never stored
  or compared in clear, never logged, never a literal in code or config.
  Delegated auth (Supabase, Firebase, Clerk) keeps them out of your tables.
  Reset tokens hashed, single-use, expiring.

## 1. Hosting
- Rate limit per IP and per account on login, signup, reset, send and upload.
- CDN and firewall (WAF, DDoS protection) in front of the origin.
- Hard spend cap if the host offers one. Otherwise a budget alert plus a
  written kill-switch step.

## 2. Injection
- Raw escapes (`$queryRawUnsafe`, `knex.raw`, `text()`, `.raw()`) take
  bound values only; dynamic SQL in a function goes through `format()`
  with `%I` / `%L` and `USING`.
- A filter object never comes straight from the request: allowlist the
  fields, cast the values. No shell command carries input into a DB tool.

## 3. Exposure (what the browser can see)
- No data in the browser console, no source map in production, no debug
  flag in a committed config.
- Hydrated state, `data-*` attributes, hidden fields and shipped HTML
  comments carry no token, hash, key or secret.

## 4. Supabase
- RLS on every table, never a service_role or secret key client-side.
  Full domain: ~/.claude/rules/supabase.md; Read it before writing a
  migration, policy or client (a new file's Write loads no path rule).

## 5. SMS and email
- Prior consent recorded per contact: who, when, channel, source, wording.
  No send without a consent row; check the suppression list before each send.
- Every email has an unsubscribe link and `List-Unsubscribe`. Every marketing
  SMS says STOP, and a STOP reply is processed and stored automatically.

## 6. Cloud functions
- Max instances and a timeout on every function, never a self-trigger.
  Full domain: ~/.claude/rules/cloud-functions.md; Read it before
  writing a function (a new file's Write loads no path rule).
