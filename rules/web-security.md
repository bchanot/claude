---
paths: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx", "**/*.vue", "**/*.svelte", "**/*.astro", "**/*.php", "**/*.py"]
---

# Web app security — specifics

Extends `~/.claude/rules/secure-by-default.md` (always on). If a request
breaks one of these rules, say so instead of doing it.

- Row Level Security enabled on every table (Supabase/Postgres and kin).
- No IDOR: changing an id in a URL must never expose another user's
  data. Authorize object access on every request.
- Session cookies httpOnly + secure + sameSite.
- Uploads restricted by type and size.
- HTTPS forced.
- Security headers set.
