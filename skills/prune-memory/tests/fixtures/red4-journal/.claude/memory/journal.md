# Journal

## 2025-11-03
- Shipped v2 auth migration. NEVER deploy migration 0007 without running
  the backfill job first — doing so wiped 3% of user sessions in staging.
  Root cause: FK cascade on the sessions table. This is a PERMANENT rule.
- Minor: bumped eslint to 9.x.

## 2026-01-15
- Refactored billing module. No relation to the auth work above.

## 2026-06-20
- Current session: started prune-memory TDD work.
