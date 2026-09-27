---
paths: ["**/api/**", "**/routes/**", "**/controllers/**", "**/*.route.*", "**/*.controller.*", "**/openapi.*", "**/*.openapi.*"]
---

# REST API — contract, errors, lists, idempotency

## Contract first
Order: typed input/output → schemas (server-generated fields like id,
createdAt apart from client input) → error codes → implementation.
Validate at boundaries only (route handlers, external responses, env
loading); trust internal code and your own database reads.

## Errors
One envelope everywhere: `{ error: { code, message, details? } }`.
HTTP map: 400 invalid · 401 auth · 403 forbidden · 404 missing ·
409 conflict · 422 semantic · 500 server (never leak internals).
Never mix throw / null / envelope styles across endpoints.

## Lists
Every list endpoint paginated: `page`, `pageSize`, `totalItems`,
`totalPages`. Filters as query params (`?status=x&createdAfter=…`),
never in the body.

## Idempotency
Key from intent, not attempt (`charge:v1:${orderId}`, never
`randomUUID()` or a timestamp). Claim atomically via a unique
constraint — check-then-insert is a race, not a guard. Same key,
different payload: fail loudly, never replay the first response.
Pick the in-flight-duplicate policy on purpose: 409 reject, bounded
wait, or 202 + status URL. Retention outlives the longest retry
path, dead-letter replay included.

## Naming
Plural nouns for endpoints (`/api/tasks`), no verbs. camelCase query
params and response fields. UPPER_SNAKE enum values. Boolean fields
prefixed is/has/can.

## Hyrum's law
Every observable behavior — undocumented quirks, error text, timing —
becomes a de facto contract once someone depends on it.

## Versioning
CLAUDE.md § Web APIs — always versioned. Not repeated here.
