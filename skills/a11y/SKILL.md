---
name: a11y
effort: high
description: 'Use when a web project needs its accessibility baseline checked and fixed: everything reachable by keyboard with a visible focus, an alt on every image, a label on every field. Full WCAG conformance (axe, pa11y, W3C) → /web-validate; security guardrails → /guardrails. Deterministic scanner (A11Y-* rules: img alt, field label, click without keyboard, focus outline removed, positive tabindex), judgment, a Tab-only walk of the main flow on --live (through /browse, else marked not done), report .claude/audits/A11Y.md, then fixes proposed with the alt and label wording as visible choices, applied only on acceptance (bugfixer executor, fresh verifier and security gates, the scanner as oracle) and re-scanned to prove each one. Triggers: "a11y", "accessibilité", "accessibility basics", "clavier", "focus visible", "alt manquant", "label sur les champs", "tab order", "corrige l''accessibilité".'
argument-hint: '[project path] [--exclude paths] [--live <url you own>] [--report-only]'
---

# /a11y

Checks a project's accessibility baseline (`rules/a11y.md`), then fixes what
the user accepts and proves each fix. A scanner reads the tree as data and
finds what text can prove: a missing alt, an unlabeled field, a click with no
keyboard path, a focus outline removed, a positive tabindex. This skill judges
the hits, walks the main flow with the keyboard when a browser is available,
proposes fixes, applies the accepted ones and scans again until every accepted
fix is proven.

The scanner proves absence of a baseline, never presence of accessibility. A
clean scan means "no static finding", and the report says exactly that. Full
WCAG conformance (contrast, structure, ARIA semantics, axe or pa11y runs) is
`/web-validate`'s job.

## MODEL GATE (blocking, before any other step)

Run `$HOME/.claude/lib/model-gate.md`. Judging hits and writing alt and label
text requires Fable or Opus. Verdict `small` → STOP: the gate prints the
remedy. ROUTING: follow `$HOME/.claude/lib/effort-shift.md` (phases via
`mcp__model-router__route`); each step below names its phase.

## STEP 1: Scope

Work in the project the user names, else the current directory. Say in one
line what you will scan. `--report-only` stops after STEP 5: audit, no fix.

## STEP 2: Run the scanner

```
python3 -B "$HOME/.claude/skills/a11y/scripts/scan.py" <path>
```

Add `--exclude a/b,c` to skip copies or vendored code, `--json` for machine
output. Exit 0 means no FAIL, 1 means at least one, 2 is a usage error. It
never executes project code. Severities: **FAIL**, the baseline is provably
missing; **WARN**, a pattern that is often wrong, judgment needed.

## STEP 3: Judge every FAIL and WARN

Read the file around each line. Label it CONFIRMED, FALSE POSITIVE (say why)
or ACCEPTED RISK (the user decides, never you). The scanner already
stays silent on a decorative `alt=""`, a `role="presentation"` overlay and an
outline swapped for a border or ring; the hits that are often false are a
label wired through `aria-labelledby` in another file and an outline removal
that a `:focus-visible` rule elsewhere covers (WARN); `references/checks.md` lists the blind
spots. Check them before calling a hit false.

## STEP 4: Keyboard walk (on `--live`, read-only)

With a dev server the user names, walk the main flow with Tab only through
`/browse`: every control reached in a sensible order, the focus visible at
each stop, Enter and Space working on what looks clickable, Escape closing
what opened. Record each stop that fails with the page and the element.
Without a browser tool, or without `--live`, the report marks the walk
"not done": a static scan cannot see a keyboard trap, a focus order or a
modal that loses focus.

## STEP 5: Report

Write `.claude/audits/A11Y.md`: one table with status PASS, FAIL, WARN or
N/A per rule, the evidence, the fix in one line, and the keyboard walk's
result (done, with its stops, or not done). PASS means "no static finding".
Keep it short; no filler sections. `--report-only`, or nothing CONFIRMED:
reply with counts, the FAILs with file:line and the walk's stops, then stop.

## STEP 6: Propose fixes

`mcp__model-router__route(phase="plan")`: wording is the deepest thinking in
this run, it goes to the plan row.

One proposal per CONFIRMED finding, grouped by rule and file; merge pairs
that one change closes (one `:focus-visible` rule closes every outline
removal in a stylesheet). FALSE POSITIVE and ACCEPTED RISK get no proposal.
Each proposal:

- **number, rule, file(s)**, and the problem in one line;
- **the fix**, concrete: file:line and the change. A missing alt gets a
  description of what the image shows, or `alt=""` when it is decorative; an
  unlabeled field gets a `label for`, a wrapping label or `aria-label`; a
  clickable `div` becomes a `button`, or gains `role`, `tabindex` and a key
  handler; a removed outline gets a `:focus-visible` style;
- **choices the user sees**: the alt text and the label wording, each with
  your proposed value, named so the user can change it. These are content,
  never invented silently: they ship only with the user's acceptance;
- **risk**: what it can break (`button` reset styles, a changed tab order).
  `DECISION` when no wording is defensible (an image you cannot describe);
- **proof**: the scanner pairs that must disappear (`RULE:path`), and the
  walk stop that must pass when `--live` ran.

Save the proposals to `.claude/tasks/plans/<YYYY-MM-DD>-a11y-<HHMM>.md` and
append them to the report. In the reply, show them as a numbered list, one or
two lines each, DECISION marked.

## STEP 7: Approval (gate, ends the turn)

Nothing is applied without the user's explicit acceptance. Ask once, then
stop the turn:

```
Which fixes do I apply? "all" (every proposal except DECISION ones),
numbers ("1,3,5-7"), "none", or an amendment ("2 with the alt 'Team photo'").
A DECISION proposal needs its number plus your wording.
```

On resume, `mcp__model-router__route(phase="reflect")`. "none" → stop,
proposals stay in the report. An amendment rewrites that proposal in the plan
file before anything else. Accepted set empty → stop.

## STEP 8: Apply

1. **Branch.** Not a git repository → stop: fixes need a diff to review.
   On `main`/`develop`, `bash ~/.claude/lib/gitflow.sh start bugfix
   a11y-<YYYY-MM-DD>`; on a working branch, stay. Never `finish`.
2. **Baseline**, before any edit:
   `python3 -B <scan.py> <root> --json > .claude/audits/.a11y-baseline.json`.
   A derived file: never staged, never committed.
3. **Contract** per `$HOME/.claude/lib/contract-interview.md` (STEP 4
   template, `flow: a11y`). REQUEST = the user's acceptance verbatim plus the
   accepted proposals. One criterion per accepted proposal, its oracle the
   scanner itself:
   ```
   1. <proposal 1 in one line>
      CHECK: python3 -B "$HOME/.claude/skills/a11y/scripts/scan.py" '<abs root>' --assert-absent 'RULE:path,RULE:path'
      EXPECT: A11Y-CLEAR
      EVIDENCE: pending
   ```
   Add one criterion for the project suite when one exists
   (`CHECK: <test command> && echo TESTS-GREEN`, `EXPECT: TESTS-GREEN`). The
   keyboard walk is a criterion without CHECK: STEP 9 settles it. FILE SCOPE
   = the files the accepted proposals name. Paths go in single quotes; a path
   holding a single quote is named to the user, never written into a CHECK.
4. **Positive control.** Run each oracle once on the unfixed tree: it must
   fail. An oracle that passes before the fix proves nothing; drop it, find
   why, and say so.
5. **Dispatch the executor**, one fresh `bugfixer` for the accepted set
   (batches of 8 proposals at most, one after the other on the same branch):
   ```
   mcp__model-router__route(phase="orchestrate")   # send with the Agent call
   Agent(subagent_type="bugfixer")
   prompt: "CONTRACT: <path>
   DIAGNOSIS: <each accepted finding: rule, file:line, evidence>
   FIX PLAN: <the accepted proposals verbatim, with the user's wording; the
   regression check of each is its contract oracle, plus the project test
   the proposal names>
   BRANCH: <current branch>
   Apply to the letter. No commit, no branch ops, no security dispatch.
   Finish with the BUGFIX-EXEC REPORT."
   ```
   `NEED-DECISION` routes per MID-RUN CLARIFICATION of the contract include:
   a wording, visible or scope question goes to the user verbatim.
   `BLOCKED` → surface it, stop.
6. **Gates** per `$HOME/.claude/lib/verify-secure-loop.md`, `CONTRACT` the
   path above, `DIFF` the executor's working-tree diff, `TEST` the suite.
   GATE 0 runs every scanner oracle (the per-fix proof), GATE 1 a fresh
   verifier, GATE 2 a fresh security-auditor. Loop caps and escalation are
   the include's; loop decisions stay in this main loop.

## STEP 9: Re-pass (prove it all)

`mcp__model-router__route(phase="reflect")`. The gates proved each accepted
fix on its own; this pass proves the whole tree.

1. Full scan against the baseline:
   ```
   python3 -B <scan.py> <root> --baseline .claude/audits/.a11y-baseline.json
   ```
   Every accepted pair must show `FIXED`, and the run must end on
   `A11Y-NO-NEW` (exit 0). A `NEW` hit is a regression the fix made.
2. Live: when STEP 4 ran, walk the same flow again once the user has reloaded
   the dev server and says go. Each stop a proposal named must now pass.
3. Add an "after" column to `.claude/audits/A11Y.md`: proposal, before,
   after, evidence.

Anything not fixed, or a NEW hit → one more round from STEP 6, limited to
those items. Two rounds at most: after the second, stop with the residuals
open and say so plainly. Never report a fix the re-pass did not prove.

## STEP 10: Commit and hand over

1. **Commit gate.** Show files, `git diff --stat` and the message, wait for
   the user's go:
   ```
   A11Y: READY TO COMMIT
   FILES   : <list>
   MESSAGE : fix(a11y): <rules fixed, one line>
   ```
   Then `git add <files touched>` (never `-A`, never the baseline file) and
   commit, project convention else 50 words at most.
2. `mcp__model-router__route(phase="apply")` for the tail. Reply with: fixed
   and proven (proposal, rule, file), still open and why, the walk's result,
   the branch name. Merge waits for the user's explicit signal.
3. Offer to capitalize a reusable lesson (a false-positive class, a fix
   pattern), entry pre-filled, written only on approval.
