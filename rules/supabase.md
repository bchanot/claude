---
paths: ["**/supabase/**", "**/*supabase*.*"]
---

# Supabase — secure by default, domain 4

Path-scoped body of `rules/secure-by-default.md` domain 4 (BDR-125 phase 1);
the always-on line there keeps RLS and the client-side key ban.

- RLS enabled on every table, in the migration that creates it.
- Policies limited to the owner: `(select auth.uid())` per operation, role
  `authenticated`. No `using (true)` on writes, no anon write.
- No `service_role` or secret key client-side: not in a bundle, not in a
  `NEXT_PUBLIC_`, `VITE_` or `PUBLIC_` variable.
- Views `security_invoker`. `security definer` functions pin `search_path`
  and revoke execute from anon. Buckets private by default.
