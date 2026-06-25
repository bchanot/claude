# Decisions

## Index

| ID | status | date | title |
|----|--------|------|-------|
| BDR-009 | accepted | 2026-06-01 | titleless |
| BDR-010 | accepted | 2026-06-02 | has title |

## BDR-009
Body exists. Heading above has NO trailing space and NO title -- this is
the trap. STEP 4 loop-2 checks `^## BDR-009 ` (trailing space required)
and so reports a FALSE ORPHAN even though this body is right here.

## BDR-010 — Has title
Body exists. Control entry: heading has a title, so STEP 4 finds it and
does NOT false-orphan it. Proves the bug is specific to title-less headings.
