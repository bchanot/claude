# FIX — gates-abandon-id (/hotfix, 2026-11-20 18:11)

Contract: `.claude/tasks/contracts/2026-11-20-gates-abandon-id-1811.md`. Branch bugfix/gates-abandon-id
off develop 23c5802.

## Root cause
lib/gates.sh:110 `^ABANDON:[[:space:]]*([0-9]+)?[[:space:]]*(.*)$`: the id group is optional and
unanchored, so `ABANDON: 1b moved` captures id `1` and reason `b moved`. Criterion 1 is then
reported ABANDONED (rc 3) instead of a ledger error. Reproduced on a scratch contract.

## Exact edit
lib/gates.sh, `_absorb`, replace the two ABANDON lines (110-111):

```
  elif [[ "$1" =~ ^ABANDON:[[:space:]]*([0-9]+)?[[:space:]]*(.*)$ ]]; then
    _ABANDON_ID+=("${BASH_REMATCH[1]}"); _ABANDON_WHY+=("${BASH_REMATCH[2]}")
```
with
```
  elif [[ "$1" =~ ^[[:space:]]*ABANDON:[[:space:]]*([0-9]+)([[:space:]]+(.*))?$ ]]; then
    _ABANDON_ID+=("${BASH_REMATCH[1]}"); _ABANDON_WHY+=("${BASH_REMATCH[3]}")
  elif [[ "$1" =~ ^[[:space:]]*ABANDON: ]]; then
    _err "malformed ABANDON at line $2 (want \`ABANDON: N reason\`)"
```
The second branch is required: with only the anchored regex, `ABANDON: 1b` would match no branch
and be silently dropped, losing the handoff and letting the ledger read MET.

lib/tests/gates.test.sh, after the "abandonment naming nothing" case, three cases of this
exact shape (same as gates.test.sh:277-287), the last line varying:

```
gate "abandonment id 1b is malformed" run "malformed ABANDON" 2 <<'EOF'
## ACCEPTANCE CRITERIA
1. green
   CHECK: echo "M"
   EXPECT: M
   EVIDENCE: pending
2. manual

ABANDON: 1b moved after renumber
EOF
```
plus one valid case, same fixture with `   ABANDON: 2 upstream offline` (3 leading spaces),
label "indented abandonment counts", `run "GATES — VERDICT: ABANDONED(1)" 3`.
Malformed labels / last lines: "abandonment id 1.1 is malformed" / `ABANDON: 1.1 moved after
renumber`; "abandonment without id is malformed" / `ABANDON: upstream offline` (was
"unknown criterion: ''", now malformed); "indented malformed abandonment" /
`   ABANDON: 1b moved` (3 leading spaces) expecting `run "malformed ABANDON" 2`.

## Edge cases
- `ABANDON: 1` (no reason): still matches (group 2 optional) → existing "blank reason" test.
- `ABANDON: 1   reason` with extra spaces: `[[:space:]]+` then `(.*)` → reason trimmed by
  `_trim` at the blank check.
- Both ABANDON branches accept leading whitespace: an `ABANDON:` written indented under its
  criterion (the game ledger 2026-09-30-verify-qual-deparse-1925.md:31) was silently dropped
  (status MET); it now counts (ABANDONED). Prose `ABANDONED`/`ABANDONMENT` never matches (the
  colon is required). No attribute line starts with `ABANDON:`.
- Punctuation right after the id (`ABANDON: 4: reason`, `5, reason`, `3—reason`) was ABANDONED
  and is now the malformed ERROR, on purpose: the documented form is `ABANDON: <n> <reason>`
  (contract-interview.md), fail closed; no real ledger uses it (all refs grepped).

## Challenge r1 (correctness SOLID, robustness CONCERNS(1), simplicity SOLID)
- robustness MAJOR: indented `ABANDON:` silently dropped, real instance in the game repo →
  leading whitespace accepted in both branches + indented test case.
- simplicity MINOR: fixture spelled out literally (above).
- correctness MINOR: punctuation after the id declared malformed on purpose (Edge cases).
- MINOR dropped: ABANDON line outside `## ACCEPTANCE CRITERIA` ignored (no real instance found).
- MINOR dropped: bulleted `- ABANDON: …` still ignored (no real instance found).

## Challenge r2 (confirmation, robustness: SOLID)
- MINORs taken: 5th test case (indented malformed); criterion 5 reads the game ledger at a
  pinned revision (`git -C … show develop:…`).
- Limit named: an indented code fence under a criterion is not a fence to the parser
  (`_parse` toggles column-0 fences only), so an example `ABANDON:` line nested there now
  counts; no contract has one (10 repos grepped); indented CHECK lines already share this.
- MINOR dropped: indented ABANDON id not checked against its enclosing criterion (rc 3 still
  routes to the human gate; no real ledger misplaces one).

## Replay (real ledgers)
phase2-guards-1545 status ABANDONED(2) before; must stay. levers-followup-1725 lives on
feature/levers-followup (ABANDONED(1), `ABANDON: 4 deferred …`): matches the anchored form.
Cross-repo (robustness challenger, `^[[:space:]]*ABANDON` over the contracts of the 9 other
repos' working trees): only the game ledger above, which goes MET → ABANDONED(1).

## Advisor
Covered by the end-of-run call of the levers-followup run, made just before this run started:
it named the silent fall-through and the replay. No second call.
