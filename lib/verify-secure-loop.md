# Verify + secure loop — shared orchestrator include (feat, bugfix)

Runs in the ORCHESTRATOR MAIN LOOP after the dev step completes. Turns a
finished diff into a verified, security-cleared change through two fresh
gates and bounded loops. Loop decisions live here, in the main loop
(LRN-083: subagents = execution + report). The dev step is a dispatched
sonnet executor (feat's `feater`, bugfix's `bugfixer`): "hand the dev"
below means re-dispatch a FRESH executor with exactly those inputs.

Inputs the caller must have ready:
- `CONTRACT`: path to the contract file written by `contract-interview.md`.
- `DIFF`: the range/file-list the dev just produced (e.g. `HEAD` vs the
  pre-dev SHA, or the working-tree diff before commit).
- `TEST`: the project test command, if known.

Nominal path is cheap — a free floor run, then
one verifier dispatch + one security dispatch, done. The loop only costs
more when it actually loops.

## GATE 0 — DETERMINISTIC FLOOR (no dispatch, no model)

Before spending a verifier dispatch, execute the oracles the contract itself
declares:

```bash
bash ~/.claude/lib/gates.sh run "$CONTRACT"
```

It runs every `CHECK:` fail-closed (MET requires exit 0 AND the `EXPECT:`
marker) and writes the outcome back over each `EVIDENCE:` line. Parse its
single `GATES — VERDICT:` line:

- `MET` → floor green, go to GATE 1. An all-manual contract lands here too
  (`RUNNABLE: 0 of n`) and passes straight through.
- `UNMET(n)` → hand the dev the CONTRACT path + the `NOT-MET` rows verbatim,
  nothing else; re-run GATE 0. **No verifier is dispatched** — a red build or
  a red suite is not a judgement call, and paying an LLM to discover it is
  waste. **Max 3 floor iterations** → STOP + human escalation with the rows.
- `ABANDONED(n)` → floor green but a handoff stands. Continue to GATE 1; the
  verifier surfaces it and its `ABANDONED(n)` verdict routes to the human
  gate.
- `ERROR(n)` → the ledger is malformed (partial oracle, duplicate id,
  unindented attribute, runnable criterion with no `EVIDENCE:` line). The
  contract is the ORCHESTRATOR's own artifact — fix it here in the main loop,
  never dispatch a dev for it.

Floor iterations are counted separately from GATE 1's: a cheap loop here does
not eat the conformity budget. GATE 0 also runs unchanged after every
security fix round, before re-verifying the request.

## GATE 1 — REQUEST CONFORMITY (fresh verifier)

Dispatch a FRESH verifier subagent (`subagent_type: verifier`, or load
`agents/verifier.md`). Pass ONLY: the `CONTRACT` path, the `DIFF` range, the
`TEST` command. Never pass the dev's summary, never pass a prior iteration's
gaps — the verifier reads the contract from disk and judges blind.

Parse its single `VERIFY — VERDICT:` line:

- `CONFORME` → go to GATE 2. (First-pass conforme = no loop.)
- `ECARTS(n)` → hand the dev the CONTRACT path + the exact `CRITERIA` gap
  lines (NOT-MET / out-of-scope), nothing else. Inline dev fixes in place;
  a dispatched dev is re-dispatched FRESH with those inputs only. Then
  re-run GATE 0 and re-dispatch a FRESH verifier. Repeat.
  **Max 3 conformity iterations** → STOP + human escalation with the
  CRITERIA table (the contract-vs-realized diff).
- `ABANDONED(n)` → direct human gate, never a dev loop (a dev cannot close
  what was proven impossible). The human lifts the abandonment or accepts
  the partial delivery; either way the run is never reported as fully
  complete, and the abandonment is named in the final report.
- Remaining `UNVERIFIABLE` while all else MET → direct human gate (a dev
  cannot fix unverifiability); do not spend a loop on it.
- Out-of-scope files: a dev justification is accepted ONLY through the human
  micro-gate that appends `[gated <date>]` to the contract's FILE SCOPE;
  otherwise the dev removes the file.
- Structural failure (`ERROR(…)`, missing/duplicated VERDICT line,
  unparsable, crash, `CONFORME` without `PROOF`) → retry ONCE with a fresh
  verifier; a 2nd structural failure → human escalation. A mute verifier is
  NEVER a PASS.

## GATE 2 — SECURITY (fresh security-auditor)

Only after GATE 1 is `CONFORME`. Dispatch a FRESH security-auditor
(`subagent_type: security-auditor`, or load `agents/security-auditor.md`)
with `MODE: gate`, `SCOPE: <DIFF>`. No report path (gate mode is
stdout-only, no Write).

Parse its single `SECURITY — VERDICT:` line:

- `PASS` → done, proceed to commit.
- `BLOCK(n)` → hand the dev the `BLOCKING` list + the CONTRACT path (inline
  fix, or FRESH executor re-dispatch). Then re-run GATE 0, then
  **re-verify the REQUEST first** (GATE 1, fresh verifier) — a security fix
  can drift the behavior — **then re-run GATE 2** (fresh auditor), in that
  order. **Max 3 security iterations** → STOP + human escalation with the
  BLOCKING table.
- `DEGRADED` (semgrep absent) → does NOT block on the tool's absence; surface
  the checklist result + recommend `make plugin`. A DEGRADED run that still
  BLOCKs (grep-caught secret/injection) blocks like any other.
- Structural failure → retry ONCE fresh; 2nd → human escalation. A mute
  auditor is NEVER a PASS.

## Order invariant

Every re-loop replays the gates in order: **GATE 0 → GATE 1 → GATE 2**,
never a subset and never reversed.

The floor runs first because it is free, and because a red build makes the
verifier's verdict meaningless. REQUEST conformity is
always re-checked BEFORE security on any re-loop — a security fix that breaks
the feature must not slip through because only the security gate re-ran.
Never the reverse order.
