# Decisions

## Index

| ID | status | date | title |
|----|--------|------|-------|
| BDR-041 | accepted | 2026-05-12 | Cache TTL default |
| BDR-042 | accepted | 2026-05-01 | Async fs in request path |

## BDR-041 — Cache TTL default

Set the default cache TTL to 300 seconds. Short and uncontroversial.

## BDR-042 — Async fs in request path

We basically really need to make it absolutely clear that the fix did NOT
resolve the race condition in the auth middleware, despite the fact that it
actually appeared to work fine in local testing. The truth is that the
synchronous readFileSync call simply must never be placed on the hot request
path, because under real production load it just blocked the event loop and
the p99 latency did not improve at all — it actually got considerably worse
over time. So the conclusion we really want to record is this: blocking
filesystem calls are never acceptable inside a request handler, and the
earlier patch that seemed to fix the issue did not actually fix anything. It
simply masked the symptom. Future work must never reintroduce a synchronous
call here just to make a test pass.
