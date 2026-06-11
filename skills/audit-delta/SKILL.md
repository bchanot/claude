---
name: audit-delta
description: |
  Use when the user wants a recurring code audit scoped to everything that
  changed since the previous audit run (full codebase on first run), on one
  or more selectable axes: CLAUDE.md norm conformity, bugs/improvements,
  dead code, security. NOT for one obvious bug (/hotfix, /bugfix), one-shot
  full cleanup (/code-clean), full security posture (/cso), quality
  dashboard (/health), or branch/PR diff review (/review, /code-review).
  Triggers: "audit-delta", "audit since last run", "incremental audit",
  "audit incrémental", "audit les changements", "audit ce qui a changé
  depuis la dernière fois", "periodic audit", "audit périodique",
  "re-run the audit", "relance l'audit", "audit conformité + sécurité".
argument-hint: "[axes among: conformity errors deadcode security — blank = asked]"
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

# /audit-delta — Incremental multi-axis code audit

Audit only what changed since the last run, on the axes the user picks.
Per axis: **audit → approval gate → fix → re-verify → marker update**,
strictly in that order, one axis fully closed before the next starts.

Core principle: **the state file is the only memory between runs.** Never
infer the previous audit's scope from report file dates, commit messages,
or memory registries. Cost is proportional to the delta, not the repo.

## When NOT to use

| Situation | Skill |
|-----------|-------|
| One obvious bug, ≤2 files | `/hotfix` / `/bugfix` |
| One-shot full cleanup, no recurrence | `/code-clean` |
| Full security posture (deps CVE sweep, OWASP) | `/cso` |
| Quality score dashboard with trends | `/health` |
| Review the current branch/PR diff | `/review`, `/code-review` |
| Recurring audit of *what changed since last time* | **this skill** |

## STEP 0 — STATE (marker protocol)

State file: `.claude/audits/audit-delta-state.json` — per-axis last-audited
commit. Read it first:

```bash
cat .claude/audits/audit-delta-state.json 2>/dev/null || echo "NO_STATE"
git rev-parse HEAD   # = AUDIT_HEAD, captured ONCE, same for all axes this run
```

Schema:

```json
{
  "axes": {
    "conformity": { "last_sha": "abc1234", "last_run": "2026-06-11" },
    "errors":     { "last_sha": "abc1234", "last_run": "2026-06-11" },
    "deadcode":   { "last_sha": null,      "last_run": null },
    "security":   { "last_sha": "def5678", "last_run": "2026-06-04" }
  }
}
```

- File missing → first run ever: create it with all four axes `null` (create
  `.claude/audits/` if absent). Do NOT scan `.claude/audits/` for old report
  files to guess a boundary — dated reports are not checkpoints.
- File present but unparseable (invalid JSON, merge-conflict markers) →
  trust NO axis: show the user the corrupt content, ask repair or reset.
  User unreachable → full codebase, **report-only**, file left exactly
  as found (same rule as a dangling marker: corrupted state only the
  user can repair).
- `last_sha` null for a selected axis → first run for that axis: ask the
  user (in STEP 2's question or a follow-up) whether to audit the **full
  codebase** or start from a **given ref** (tag, SHA, `origin/main`).
  User unreachable / no answer possible → default to **full codebase,
  report-only** for that axis and say so in the report. Never default to
  "from HEAD" — a first-run marker set at HEAD without auditing silently
  skips the entire existing codebase.
- `last_sha` no longer exists (`git cat-file -e <sha>^{commit}` fails —
  rebase/force-push) → tell the user, ask for a replacement base. Never
  silently fall back to a guess. User unreachable / no answer possible →
  audit the **full codebase, report-only** for that axis and leave its
  marker **untouched**: a dangling marker is corrupted state only the
  user can repair, so the question re-raises next run. (Unlike first-run
  null — defined semantics — a broken marker never advances on a default.)
- Markers are **per axis** because runs are partial: auditing only
  `security` today must not advance `conformity`'s marker.

## STEP 1 — SCOPE per axis

For each selected axis with marker `S`:

```bash
git diff --name-only S..AUDIT_HEAD     # committed delta
git status --porcelain                 # uncommitted (staged + working tree)
git log --oneline S..AUDIT_HEAD        # commits, for the report header
```

Audit set = union of both lists, filtered:

- Skip: binary files, lockfiles (except for the `security` axis — new
  dependencies ARE in scope there), vendored/generated dirs
  (`node_modules`, `dist`, `*-out/`), submodule pointers.
- **Deleted files stay relevant for `deadcode`**: a deletion can orphan
  callers outside the delta — grep repo-wide for symbols the delta removed.
- Empty audit set for an axis → report "nothing changed since `S`", update
  its marker to AUDIT_HEAD, move on. That is a success, not an error.
- Audit set > 40 files → chunk across parallel read-only subagents
  (by directory), merge findings.

## STEP 2 — AXIS SELECTION

If `$ARGUMENTS` names axes (`conformity`, `errors`, `deadcode`, `security`
— accept French: conformité, erreurs, code mort, sécurité), use them and
skip the question. Otherwise AskUserQuestion (multiSelect: true), one
option per axis, each showing its staleness:

```
[ ] conformity — CLAUDE.md norms          (last: 2026-06-04, 12 commits behind)
[ ] errors     — bugs & improvements      (last: never — full or from ref?)
[ ] deadcode   — dead/zombie code         (last: 2026-06-04, 12 commits behind)
[ ] security   — secrets/injection/authz  (last: 2026-06-04, 12 commits behind)
```

User unreachable / no answer possible AND no axes in `$ARGUMENTS` →
default to **all four axes** (null-marker axes follow STEP 0's first-run
default: full codebase, report-only); state the defaulting in the report
header.

## STEP 3 — PER-AXIS LOOP

Process the selected axes **sequentially, one fully closed before the
next**, in fixed order: `security → errors → conformity → deadcode`
(most critical first — if the session dies midway, the important axes
are done and their markers are saved).

### 3a. AUDIT (read-only)

Dispatch a subagent (analyzer type if available, else general) with the
axis prompt from "Axis specs" below + the audit set + the commit list.
Instruct it explicitly: **read-only, modify nothing, report findings as a
list**: `id | file:line | severity (high/med/low) | finding | proposed fix
(1 line)`. The main thread makes NO edits during this phase either.

### 3b. REPORT

Append to `.claude/audits/AUDIT-DELTA.md` (create if absent), append-only:

```markdown
## Run 2026-06-11 — axis: security — range S..AUDIT_HEAD (+ uncommitted)
| ID | File | Sev | Finding | Status |
|----|------|-----|---------|--------|
| SEC-1 | lib/x.sh:42 | high | unguarded rm -rf "$VAR/" | fixed |
| SEC-2 | hooks/y.sh:7 | low  | token echoed at DEBUG    | declined |
```

Then show the user the same compact table inline.

### 3c. APPROVAL GATE ★ MANDATORY STOP

AskUserQuestion: **fix all / pick which / none**.

- "Fix what you find" said **in the invocation** does NOT skip this gate:
  nobody can approve findings that did not exist yet. The gate is about
  *these specific findings*.
- User unreachable / no answer possible (headless, "I'm in a meeting") →
  audit + report ONLY. No fixes. Marker still updates (3f) — the audit
  itself is complete; findings stay `open` in the report for next time.
  (Exception: dangling-marker and corrupted-state runs — STEP 0 — never
  advance markers, regardless of this rule.)
- "None" → mark findings `declined`, jump to 3f.

### 3d. FIX

Apply approved fixes only. Minimal scoped diffs, CLAUDE.md norms apply.
Unapproved findings stay untouched even if "they're right there".

### 3e. RE-VERIFY ★ before anything else

Mandatory after any fix. Lint alone is NOT re-verification.

1. Fresh read-only subagent, **same axis prompt**, scoped to the files
   modified in 3d. Pass = every approved finding resolved AND zero new
   findings introduced.
2. Project checks if available: tests, lint, build, type-check (e.g. this
   repo's Health Stack: `shellcheck *.sh hooks/*.sh lib/*.sh`).
3. Fail → fix → re-verify again. Max 3 cycles, then STOP and ask the
   user: keep partial / revert this axis's fixes / handle manually.
   User unreachable at this STOP → **revert this axis's fixes** (fail
   closed), findings back to `open`, marker untouched; record the
   revert in the report.

Only a passing re-verify (or a no-fix run) closes the axis.

### 3f. MARKER UPDATE

Set this axis's `last_sha = AUDIT_HEAD`, `last_run = today` in the state
file. Update the report rows' Status (`fixed` / `open` / `declined`).

Fixes are working-tree changes (committing is the user's call, suggest
`/commit-change` at the end). Next run's range starts at AUDIT_HEAD, so
fix commits land inside it and get re-audited — safe overlap, by design.

## STEP 4 — FINAL SUMMARY

```
AUDIT-DELTA COMPLETE — 2026-06-11
  security   : 3 findings → 2 fixed, 1 declined   | marker → fbf3e26
  errors     : 1 finding  → 1 fixed               | marker → fbf3e26
  conformity : nothing changed since last run     | marker → fbf3e26
  deadcode   : (not selected — still at def5678, 2026-06-04)
  report: .claude/audits/AUDIT-DELTA.md
  fixes uncommitted — /commit-change when ready
```

Then offer to capitalize (per CLAUDE.md): recurring finding patterns →
`learnings.md`, audit verdicts → `evals.md`. Behind approval, never silent.

## Axis specs (subagent prompts)

- **security** — scoped to the delta: hardcoded secrets/tokens/keys (also
  in comments), injection (SQL/XSS/command — string concat into
  queries/shells), authN/authZ gaps on new endpoints, fail-open error
  paths, secrets/PII in logs, new dependencies in lockfiles (name them +
  known CVEs), unguarded destructive shell (`rm -rf` with unquoted or
  un-`:?`-guarded vars).
- **errors** — bugs in changed code: logic errors, off-by-one, unhandled
  edge cases (empty/null/unicode/concurrent), race conditions, swallowed
  errors, resource leaks (missing trap/close/finally). Improvements only
  when concrete and local: simplification, dedup against an existing
  helper, obvious perf.
- **conformity** — read project `CLAUDE.md` (+ `~/.claude/CLAUDE.md`)
  FIRST, then check changed code against those norms. This repo's:
  ≤25 logic lines/function, ≤80 chars/line, ≤5 params, ≤5 locals, no
  global state, intent-not-mechanics comments, explicit naming, versioned
  APIs (`/api/v1/`), no-SPA-for-public-sites, security defaults.
- **deadcode** — dead/zombie introduced OR orphaned by the delta: unused
  functions/exports/imports/vars, unreachable branches, stale feature
  flags, commented-out blocks, references to deleted files/symbols
  (repo-wide grep for everything the delta deleted or renamed).

## Rules

- State file = single source of truth. No state → first-run protocol, ask.
- Audit phase is read-only — no edit before the 3c gate, ever.
- Gate is per-axis and mandatory; advance pre-authorization never skips it.
- Re-verify = re-run the axis audit on modified files + project checks.
  A passing linter alone proves nothing about the axis.
- One axis fully closed (3a→3f) before the next opens.
- Marker only moves at 3f. Crash mid-axis → that axis re-runs from the
  old marker next time. Never pre-advance.
- Report and state files: append/update only — never rewrite past runs.
- Memory registries: write only via the STEP 4 capitalize offer, gated.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Guessing the last run from report-file dates in `.claude/audits/` | Dated reports are not checkpoints. State file or first-run protocol. |
| Date-based boundary (`git log --after=...`) | SHA range only. Dates drift (rebase, timezone, amended commits). |
| One global marker for all axes | Partial runs desync axes. Marker is per axis. |
| Fixing right after the audit because the user pre-said "fix everything" | Findings didn't exist at request time. Gate at 3c, always. |
| `shellcheck`/lint passes ⇒ "re-verified" | Re-verify = same-axis re-audit on modified files + project checks. |
| Auditing all four axes in one mixed pass | Sequential per-axis loop. Mixed passes skip gates and re-verifies. |
| Advancing the marker before re-verify passes | Marker moves at 3f only. |
| Writing learnings/journal entries autonomously | Registries only via the gated capitalize offer. |
| Treating an empty delta as an error | "Nothing changed" = success: report it, advance the marker. |
| First-run axis + unreachable user → marker set to HEAD, nothing audited | Silently skips the whole codebase. Default = full codebase, report-only. |
| Dangling marker + unreachable user → full audit, then marker advanced anyway | Marker repair needs a user-approved base. Report-only, marker untouched, ask again next run. |

## Red flags — STOP

- About to `Edit` a file and STEP 3c has not run for this axis.
- About to run `git log --after=<date>` to find the audit boundary.
- About to advance a marker for an axis whose re-verify did not pass.
- About to start axis N+1 while axis N has unverified fixes.
- "The user said fix everything, so the gate is already answered."

## TDD note (skill itself)

Baseline-tested per superpowers:writing-skills (2026-06-11, isolated
worktree, no skill): the agent (1) guessed the boundary from the most
recent file date in `.claude/audits/` — wrong file, date-based; (2) wrote
its checkpoint as prose in a dated report — unparseable next run; (3) kept
no per-axis marker; (4) fixed files with zero approval gate under "I'm in
a meeting" pressure; (5) called shellcheck-passing "verified" without
re-auditing; (6) ran all axes as one mixed pass; (7) wrote memory
registries autonomously. STEP 0/3c/3e and the mistakes table counter each
observed failure.
