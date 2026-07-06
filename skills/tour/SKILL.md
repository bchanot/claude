---
name: tour
description: |
  Use when the user wants ONE grouped pass over a whole project (or a
  list of projects) covering all hygiene axes together: code cleanup +
  security (semgrep/cso) + TODO-vs-reality check + doc sync, auto-fixing
  and re-auditing until a clean pass — even without naming the axes.
  NOT one axis alone (/code-clean, /cso, /audit-delta, /reconcile, /doc),
  one bug (/hotfix, /bugfix), dashboard (/health), branch diff (/review).
  Triggers: "tour", "tir groupé", "grand ménage", "fais un tour sur les
  projets", "sweep", "full pass", "vérifie et corrige tout".
argument-hint: "[project paths… — blank = current repo] [--report-only]"
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

# /tour — grouped multi-axis sweep (clean + security + reconcile + doc)

One pipeline per project: **security → clean → re-verify → reconcile →
doc → convergence re-audit**, looping until a full pass applies zero new
fixes. Auto mode by design: fixes are committed on a dedicated
`chore/tour-<date>` branch that this skill **never merges** — the branch
plus its report IS the approval gate, reviewed by the human afterwards.

Core principle: **autonomy on the working branch, never on shared
state.** The skill may edit code freely on its own branch; it may NOT
silently rewrite declared state (target TODO, memory registries) or
integrate anything (merge/finish/push).

## When NOT to use

| Situation | Skill |
|-----------|-------|
| One axis only (cleanup / security / TODO / doc) | `/code-clean`, `/cso`, `/reconcile`, `/doc` |
| Recurring single-axis audit scoped to the delta | `/audit-delta` |
| One obvious bug | `/hotfix`, `/bugfix` |
| Quality dashboard, no fixes | `/health` |
| Review a branch/PR diff | `/review`, `/code-review` |
| All axes, fix, loop to clean, 1..N projects | **this skill** |

## STEP 0 — ARGS & PROJECT LIST

- Paths in `$ARGUMENTS` → project list, processed **sequentially** in
  the given order. No paths → current repo only.
- `--report-only` → run every audit, apply NO fix, write reports only.
- A failure in one project never aborts the tour: record it in that
  project's report section and move to the next.

## STEP 1 — PRECONDITIONS (per project)

All git commands use `git -C <project>`. Check, in order:

1. Is a git repository → else SKIP (recorded, not an error).
2. Working tree **clean** (`git status --porcelain` empty) → else this
   project runs **report-only**: never mix the user's WIP with tour
   fixes, never stash someone else's work.
3. `develop` exists and `~/.claude/lib/gitflow.sh` is available → start
   the working branch via the lib, never by hand:
   `bash ~/.claude/lib/gitflow.sh start chore tour-YYYY-MM-DD`
   (append `-2`, `-3`… if the branch already exists). Missing develop
   or lib → **report-only** + suggest `gitflow init` in the report.
4. Detect project checks once (tests, lint, build, type-check — from
   package.json/Makefile/CLAUDE.md). Record what exists; "none found"
   is itself a report line.

Report file: `.claude/audits/TOUR.md` in the target project (create
`.claude/audits/` if absent). Append-only — never rewrite past runs.

## STEP 2 — ITERATION LOOP (max 3 per project)

Each iteration runs phases A→D in fixed order. **Convergence** = one
full iteration that applies **zero fixes** and finds **zero new
findings** with project checks green. Converged → STEP 3. Not converged
after 3 iterations → STOP, residuals stay `open` in the report, say so
honestly in the summary. Never loop past 3.

### Phase A — SECURITY (deterministic floor first)

1. Dispatch the SAST gate (fresh every iteration):
   ```
   Agent(subagent_type="security-auditor", description="tour security — semgrep SAST",
     prompt="MODE: audit\nSCOPE: project (full tree, respect .gitignore)\nPROJECT: <path>\nREPORT: .claude/audits/.tour-semgrep.md\nFollow agents/security-auditor.md exactly. Pinned rulesets, no login. Write ONLY to REPORT. End with REPORT_WRITTEN: <path>.")
   ```
   semgrep ABSENT → DEGRADED (checklist only) is surfaced in the
   report, not a silent downgrade and not a blocker.
2. gstack ON (`/cso` available) → **iteration 1 only**, dispatch a cso
   posture audit (deps CVE, OWASP) in audit mode; fold its findings in.
3. Fix policy (skip in `--report-only`): CRITICAL/HIGH → fix now.
   MEDIUM/LOW → fix only if local and behavior-preserving, else leave
   `open`. Every fix minimal, CLAUDE.md security defaults apply.
   A CRITICAL/HIGH fix that changes the API contract (new required
   header/param, changed status codes, moved paths) is still applied —
   but its report row and the global summary line carry a **BREAKING**
   tag, so the human review cannot miss it.
4. Commit scoped: `git add <files touched>` (never `-A`),
   `fix(security): …`.

### Phase B — CLEAN

1. Dispatch a read-only cleanup audit (code-cleaner agent if available,
   else analyzer/general): dead code, unused imports/exports,
   commented-out blocks, stale flags, norm violations. Findings as
   `id | file:line | finding | proposed fix`.
2. Apply **behavior-preserving** fixes only. A finding that would change
   behavior is a bug, not cleanup → log to
   `.claude/audits/BUGS-FOUND.md`, leave the code alone.
3. Commit scoped: `chore(clean): …`.

### Phase C — RE-VERIFY (after any fix)

1. Run the project checks found in STEP 1. Lint alone is NOT
   verification when tests/build exist.
2. Fresh read-only subagent re-audits the files modified this
   iteration (same axis prompts). Pass = approved findings resolved AND
   zero new findings introduced.
3. Fail → fix → recheck, max 3 attempts inside the iteration; still
   failing → **revert this phase's commits** (fail closed), findings
   back to `open`, recorded in the report.

### Phase D — RECONCILE + DOC

1. **Reconcile — REPORT-ONLY, always, even in auto mode.** Confront
   declared state (target TODO checkboxes, registry statuses) against
   real state (git log, files, branches) — reuse `lib/reconcile.sh`
   oracles when available. Every gap goes in the report as
   `declared X | real Y | suggested edit`. **Never check a box, never
   restructure, never edit the target project's TODO.md or
   `.claude/memory/`** — an inferred checkbox is exactly the lie
   /reconcile exists to catch. The human applies suggestions via
   `/reconcile` later.
2. **Doc sync** — dispatch doc-syncer in AUTOMATIC (silent) mode:
   public docs only (README, INSTALL, USAGE, CHANGELOG…), never
   `.claude/**`, never CLAUDE.md. Commit its `PATCHED_FILES:` via
   `bash ~/.claude/lib/doc-commit.sh` when available, else a scoped
   `docs: …` commit of exactly those paths.

### End of iteration

Fixes were applied (any phase) OR new findings appeared → run another
iteration (fixes can invalidate earlier audits — that is the point of
the loop). Otherwise → converged.

## STEP 3 — REPORT, CLEANUP & SUMMARY (per project, then global)

Append to `.claude/audits/TOUR.md`, then close the run in this exact
order:

1. Write the run section (template below).
2. **Delete the scratch audit files** this run created
   (`.claude/audits/.tour-semgrep*` and similar) — their content is
   folded into TOUR.md. A tree left dirty here forces the NEXT tour
   into report-only: the skill must not self-block.
3. Commit the report as the run's final commit (`docs(tour): report`).
4. Confirm `git status --porcelain` is clean (runtime junk the sandbox
   cannot delete, e.g. `__pycache__/`, becomes a report residual line).

```markdown
## Tour 2026-07-04 — branch chore/tour-2026-07-04 — 2 iterations — CONVERGED
| ID | Axis | File | Sev | Finding | Status |
|----|------|------|-----|---------|--------|
| SEC-1 | security | app.py:17 | high | shell=True + concat | fixed |
| SEC-2 | security | app.py:14 | high | no authz on POST /backup | fixed — **BREAKING**: new required X-Backup-Token header |
| CLN-1 | clean | utils.py:9 | - | dead legacy_md5 | fixed |
| REC-1 | reconcile | TODO.md | - | "/health" unchecked, shipped 2d92696 | suggested |
| DOC-1 | doc | README.md | - | phantom /status endpoint | fixed |
Checks: pytest PASS, ruff PASS. Residuals: none. Commits: 5. BREAKING: 1 (SEC-2).
```

Global summary inline, one line per project (append `BREAKING: n` to
any project line whose fixes changed an API contract):

```
TOUR COMPLETE — 2026-07-04
  ~/proj/api    : CONVERGED (2 it.) — 3 fixed, 1 suggested | chore/tour-2026-07-04, 4 commits
  ~/proj/site   : NOT CONVERGED (3 it.) — 2 open residuals  | chore/tour-2026-07-04, 6 commits
  ~/proj/lib    : report-only (dirty tree)                  | no branch
  Branches left UNMERGED — review each, then `gitflow finish` on your GO.
  Reconcile suggestions pending — apply via /reconcile.
```

Then offer to capitalize (gated, per CLAUDE.md): recurring cross-project
patterns → learnings, tour verdict → evals. Never write registries
without that approval — neither this repo's nor any target project's.

## Rules

- Branch via the gitflow lib; **never `gitflow finish`, never merge,
  never push** — no exceptions, "the tour is green" is not a signal.
- Scoped pathspecs only; `git add -A` is forbidden.
- Target TODO.md and target `.claude/memory/` are READ-ONLY. Reconcile
  produces suggestions, not edits.
- Only the four axes. No unrequested bootstrap (.gitignore, registries,
  configs, features) — infrastructure gaps are report lines, not work.
- Security floor = security-auditor (pinned semgrep + checklist). An
  ad-hoc grep is never "the security pass".
- Max 3 iterations per project; max 3 fix attempts per re-verify.
  Residuals are reported, not silently retried forever.
- Dirty tree / no develop / no gitflow lib → report-only, stated in the
  report. Never stash, never branch by hand.
- Reports append-only. One report per project, in that project.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Checking TODO boxes "obviously done" during reconcile | Report-only. Suggested edits, human applies. |
| Writing BDR/LRN/journal entries in the target project | Registries only via the gated capitalize offer, end of tour. |
| grep/ruff pass = security done | security-auditor agent (pinned semgrep) is the floor, every iteration. |
| Findings live only in the final chat message | TOUR.md is what the human reviews before merging. Write it. |
| "Bonus hygiene" (.gitignore, templates, bootstrap) | Out of scope. Report line, not work. |
| Loop "until clean" with no bound | Max 3 iterations, then honest residuals. |
| Merging/finishing because everything is green | Green ≠ GO. Branch stays; human merges. |
| Stashing a dirty tree to proceed | Report-only for that project. |
| One TOUR.md for all projects in the config repo | Each project gets its own `.claude/audits/TOUR.md`. |
| Fixing a behavior-changing "cleanup" finding | That is a bug → BUGS-FOUND.md, untouched code. |
| Scratch audit files left untracked at the end | Delete them in STEP 3.2 — a dirty tree self-blocks the next tour. |
| Contract-changing security fix reported as plain "fixed" | Tag **BREAKING** in the row AND the summary line. |

## Red flags — STOP

- About to `Edit` a target project's TODO.md or `.claude/memory/*`.
- About to run `gitflow finish`, `git merge`, or `git push`.
- About to `git add -A` or commit on `main`/`develop`.
- Starting iteration 4, or "just one more loop, it's almost clean".
- Security phase done without the security-auditor agent and without a
  DEGRADED notice in the report.
- Creating any file the audit did not require (.gitignore, templates).
- Ending a project's run with `git status --porcelain` non-empty and no
  residual line explaining every leftover path.

## TDD note (skill itself)

Baseline-tested per superpowers:writing-skills (2026-07-04, seeded
fixture, no skill): the agent branched correctly via gitflow and did not
merge, BUT (1) silently rewrote the target TODO (checked boxes,
restructured) during "reconcile"; (2) authored BDR/journal registry
entries autonomously; (3) ran security as ad-hoc grep + ruff — no
semgrep, no pinned rulesets; (4) left findings only in its final chat
message — no persistent report to review before merge; (5) bootstrapped
unrequested .gitignore + memory registries ("bonus hygiene");
(6) looped without a stated bound (converged at pass 2 by luck). Phase
D.1, the registry rule, Phase A.1, STEP 3, the scope rule and the
3-iteration bound counter each observed failure.

GREEN run (same day, fresh fixture, skill followed): all six gaps
closed — TODO zero-diff, no registry writes, semgrep every iteration,
TOUR.md committed, no scope creep, converged in 3 bounded iterations on
an unmerged chore branch. Two new holes surfaced and patched
(REFACTOR): scratch semgrep files left untracked (would self-block the
next run — STEP 3.2) and a contract-changing security fix not flagged
(BREAKING tag in template). The REFACTOR additions are
template-structural and were not re-run through a third full fixture
pass — re-test on first real use.
