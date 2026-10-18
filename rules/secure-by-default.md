# Secure by default: five domains and every API

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

## 2. Accessibility
- Everything reachable and usable by keyboard, focus always visible.
  `:focus-visible` styled, never `outline: none` without a replacement.
- Every image has an `alt` (empty when decorative). Every field has a label;
  a placeholder is not a label.

## 3. Supabase
- RLS enabled on every table, in the migration that creates it.
- Policies limited to the owner: `(select auth.uid())` per operation, role
  `authenticated`. No `using (true)` on writes, no anon write.
- No `service_role` or secret key client-side: not in a bundle, not in a
  `NEXT_PUBLIC_`, `VITE_` or `PUBLIC_` variable.
- Views `security_invoker`. `security definer` functions pin `search_path`
  and revoke execute from anon. Buckets private by default.

## 4. SMS and email
- Prior consent recorded per contact: who, when, channel, source, wording.
  No send without a consent row; check the suppression list before each send.
- Every email has an unsubscribe link and `List-Unsubscribe`. Every marketing
  SMS says STOP, and a STOP reply is processed and stored automatically.

## 5. Cloud functions
- No function re-triggers itself: never write to the resource that fires it,
  never invoke itself. If unavoidable, guard with an idempotency flag.
- Max instances (or reserved concurrency) and a timeout on every function.
- Budget alert wired to an automatic stop beyond the budget.
