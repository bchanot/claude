# Verify + secure loop — shared orchestrator include (feat, bugfix)

Runs in the ORCHESTRATOR MAIN LOOP after the dev step completes. Turns a
finished diff into a verified, security-cleared change through two fresh
gates and bounded loops. The dev stays inline (LRN-083: subagents =
execution + report; loop decisions live here, in the main loop).

Inputs the caller must have ready:
- `CONTRACT`: path to the contract file written by `contract-interview.md`.
- `DIFF`: the range/file-list the dev just produced (e.g. `HEAD` vs the
  pre-dev SHA, or the working-tree diff before commit).
- `TEST`: the project test command, if known.

Nominal path is cheap: one verifier dispatch + one security dispatch, done.
The loop only costs more when it actually loops.

## GATE 1 — REQUEST CONFORMITY (fresh verifier)

Dispatch a FRESH verifier subagent (`subagent_type: verifier`, or load
`agents/verifier.md`). Pass ONLY: the `CONTRACT` path, the `DIFF` range, the
`TEST` command. Never pass the dev's summary, never pass a prior iteration's
gaps — the verifier reads the contract from disk and judges blind.

Parse its single `VERIFY — VERDICT:` line:

- `CONFORME` → go to GATE 2. (First-pass conforme = no loop.)
- `ECARTS(n)` → hand the dev the CONTRACT path + the exact `CRITERIA` gap
  lines (NOT-MET / out-of-scope), nothing else. Dev fixes inline, then
  re-dispatch a FRESH verifier. Repeat. **Max 3 conformity iterations** →
  STOP + human escalation with the CRITERIA table (the contract-vs-realized
  diff).
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
- `BLOCK(n)` → hand the dev the `BLOCKING` list + the CONTRACT path. Dev
  fixes inline. Then **re-verify the REQUEST first** (GATE 1, fresh
  verifier) — a security fix can drift the behavior — **then re-run GATE 2**
  (fresh auditor), in that order. **Max 3 security iterations** → STOP +
  human escalation with the BLOCKING table.
- `DEGRADED` (semgrep absent) → does NOT block on the tool's absence; surface
  the checklist result + recommend `make plugin`. A DEGRADED run that still
  BLOCKs (grep-caught secret/injection) blocks like any other.
- Structural failure → retry ONCE fresh; 2nd → human escalation. A mute
  auditor is NEVER a PASS.

## Order invariant

REQUEST conformity is always re-checked BEFORE security on any re-loop — a
security fix that breaks the feature must not slip through because only the
security gate re-ran. Never the reverse order.
