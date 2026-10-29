---
paths: ["**/functions/**", "**/serverless.*", "**/firebase.json"]
---

# Cloud functions — secure by default, domain 6

Path-scoped body of `rules/secure-by-default.md` domain 6 (BDR-125 phase 1);
the always-on line there keeps the instance cap and the self-trigger ban.

- No function re-triggers itself: never write to the resource that fires it,
  never invoke itself. If unavoidable, guard with an idempotency flag.
- Max instances (or reserved concurrency) and a timeout on every function.
- Budget alert wired to an automatic stop beyond the budget.
