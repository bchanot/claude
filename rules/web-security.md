---
paths: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx", "**/*.vue", "**/*.svelte", "**/*.astro", "**/*.php", "**/*.py"]
---

# Web app security — specifics

Extends the global Security section (input validation, parameterized
queries, secrets in env vars, AuthN/AuthZ, fail closed). If a request
breaks one of these rules, say so instead of doing it.

- No API key in code shipped to the browser. Env vars, server-side only.
- The service/admin key never reaches the client: publishable key only.
- Row Level Security enabled on every table (Supabase/Postgres and kin).
- Authentication verified server-side, never only in the browser.
- No IDOR: changing an id in a URL must never expose another user's
  data. Authorize object access on every request.
- Passwords hashed (bcrypt/argon2). Session cookies httpOnly + secure
  + sameSite.
- API responses return only the fields the client needs.
- Login rate limiting, upload restrictions (type/size), forced HTTPS,
  security headers.
