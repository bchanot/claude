---
name: deploy
description: |
  Use when deploying a project via its per-project runbook — instantiates the delta
  since last deploy, hands off for out-of-band execution, resumes cold, learns from errors.
  Triggers: "deploy", "déploie", "run the deploy", "ship to prod", "deploy runbook".
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion]
---

# /deploy — per-project runbook, instantiated from the delta, resumed cold

Run a project's deploy from its committed runbook (`.claude/deploy/PROCEDURE.md`):
instantiate only the steps the delta-since-last-deploy needs, hand the checklist
to the user for **out-of-band** execution, then **resume on their report — even
in a different session with no conversation memory** — and patch the runbook in
place when a step fails.

**Core principle — the disk is the only memory between the two moments.** This
skill runs in two moments split by a manual deploy you do not control. The report
that closes it may land in a fresh session. So everything moment 3 needs lives on
disk in `.claude/deploy/`, never in conversation context. Never reconstruct the
deploy from memory, commit messages, or `git describe`.

**Claude never runs the deploy.** Prod commands run by hand, out-of-band. This
skill only writes the checklist (`NEXT.sh`), reacts to the user's report, and
records the outcome.

## The two-moment contract — cold cross-session resume

This is the skill's defining form. No other skill resumes with the context gone.

| | |
|---|---|
| **Moment 1 (BEFORE)** | STEP 0–2: detect the delta, instantiate `NEXT.sh`, write the `PENDING.json` bridge, hand back. |
| **the gap** | The user deploys by hand. May take minutes or days. **May cross sessions.** |
| **Moment 2 (AFTER)** | STEP 3–5: on the user's report, react — mark success, or learn from a failure and re-hand-back. |

**How the wait is marked:** a `PENDING.json` on disk with `step_reached`
recorded **IS** the marker "a deploy is in flight, I am waiting for your report
here." Its presence is the whole signal — no flag in memory, no open question in
context. `STATE.json` is the deployed-up-to-here oracle; `PENDING.json` is the
in-flight bridge that outlives the session.

**How a cold resume detects + resumes (STEP 0):** every invocation reads
`PENDING.json` FIRST. Present ⇒ a deploy is mid-flight ⇒ jump straight to STEP 3
using the bridge's `{base_sha, target_sha, delta, step_reached}`. **Do not
recompute any of them** — HEAD may have moved during the gap, so "current HEAD"
is wrong; the bridge holds the truth captured at instantiation.

**Read the JSON natively.** Open `PENDING.json` / `STATE.json` with the Read
tool and parse the fields directly. NO `jq`, NO shell JSON parsing — there is no
jq dependency.

## When to use / When NOT to use

| Situation | Skill |
|-----------|-------|
| Run this project's deploy runbook, delta-instantiated, learning | **this skill** |
| Project has no `.claude/deploy/PROCEDURE.md` yet | this skill's **bootstrap** branch (see STEP 0) |
| Merge a branch + trigger CI deploy (gstack) | `/land-and-deploy` |
| Configure deployment settings | `/setup-deploy` |
| Document a release after shipping | `/document-release`, `/doc` |

## Artifacts — `.claude/deploy/` (five files)

| File | Committed? | Role |
|------|-----------|------|
| `PROCEDURE.md` | yes | reference runbook — fixed shell + `# @delta:` steps; edited IN PLACE |
| `INCIDENTS.md` | yes | `DEP-NNN` ledger, append-only; read at instantiation for pre-warns |
| `STATE.json` | yes | deploy oracle — the SHA deployed up to here |
| `PENDING.json` | **no (gitignored)** | in-flight bridge; written at hand-back, deleted on success |
| `NEXT.sh` | **no (gitignored)** | instantiated checklist; run BY HAND, never `bash NEXT.sh` |

**Schemas (document of record — recover the shapes from here):**

```jsonc
// STATE.json — overwritten each successful deploy (the diff oracle)
{ "deployed_sha": "<sha>", "deployed_at": "<ISO-8601>", "outcome": "ok", "tag": "deploy/<YYYY-MM-DD>" }
```

```jsonc
// PENDING.json — the cold-resume bridge; gitignored; deleted on success
{ "base_sha": "<deployed STATE sha>", "target_sha": "<HEAD at instantiation>",
  "delta": ["<path>", ...], "step_reached": "awaiting-user", "started_at": "<ISO-8601>",
  "runbook_rev": "<PROCEDURE.md commit sha>" }
```

`step_reached` = where the next `NEXT.sh` must start: `"awaiting-user"` = run from
the top; a step number `X` = regenerate from step X (set after a learn at X).
`runbook_rev` = the commit sha of `PROCEDURE.md` at instantiation; a mismatch
versus the live runbook means `NEXT.sh` is stale and must be regenerated.

## `@delta:` grammar (PROCEDURE.md)

A directive sits on the comment line **above** the step it governs; patterns are
matched against the delta file list. Un-annotated step = **fixed**, always
emitted verbatim.

| Directive | Meaning | Instantiation |
|-----------|---------|---------------|
| `# @delta:<kind> glob=<pat>:each` | per-file command | repeat the command once **per** matching delta file (file substituted in) |
| `# @delta:<kind> glob=<pat>:list` | one command, many inputs | emit the command **once**; list matching files as `# VERIFY:` items |
| `# @delta:<kind> when=<pat,...>` | conditional | include the step **only if** the delta intersects a pattern |

`<kind>` is a human label. `<pat>` is a git-pathspec / shell glob; `when=`
comma-separates alternatives. Zero matches → omit that step. Both `:each` and
`:list` are first-class (e.g. apply each new migration with its own command vs.
one `migration up` that lists which migrations to verify).

---

## STEP 0 — PRE-FLIGHT + RESUME BRANCH

Read `.claude/deploy/PENDING.json` **first** (it is the only memory between runs).

- **`PENDING.json` present → RESUME.** A deploy is in flight. Parse its
  `{base_sha, target_sha, delta, step_reached}` and jump to **STEP 3**. Announce:
  "A deploy started `<started_at>` is awaiting your report (target `<target_sha>`)."
  **Do not** recompute the delta, re-read HEAD, or re-instantiate from scratch —
  the bridge is authoritative.
  - *Staleness guard:* if `runbook_rev` ≠ the live runbook commit
    (`git log -1 --format=%h -- .claude/deploy/PROCEDURE.md`), the on-disk
    `NEXT.sh` is stale (a patch landed) — regenerate it from `step_reached`
    (STEP 2's expansion) before reacting.
- **`PENDING.json` absent + `PROCEDURE.md` absent → BOOTSTRAP.** No runbook yet:
  interview the project and scaffold an annotated `PROCEDURE.md` (or adopt one
  the user pastes), then continue at STEP 1. *(Bootstrap is its own procedure —
  not covered in this section.)*
- **`PENDING.json` absent + `PROCEDURE.md` present → FRESH.** Continue to STEP 1.

First-deploy / fresh detection is **file existence only**. Never `git describe`
(it errors when no `deploy/*` tag exists and is not the detection path).

## STEP 1 — DELTA

Set the base, compute the changed-file list, capture the target.

- **`STATE.json` absent → FIRST DEPLOY.** No base (`PENDING.json.base_sha: null`).
  The **full runbook** fires: delta = the entire tracked tree (`git ls-files`), so
  every fixed step and every applicable `@delta:` step instantiates.
- **`STATE.json` present →** read `deployed_sha` as `base`, then:
  ```bash
  git diff --name-only <base_sha> HEAD     # two explicit endpoints, no dots
  ```
  This is the literal tree difference deployed→HEAD. **Never** `git rev-list`
  ancestry (phantom deltas after a rebase) and **never** three-dot `<base>...HEAD`
  (merge-base undercounts).
- `target = git rev-parse HEAD` — the SHA this deploy carries to prod.

## STEP 2 — INSTANTIATE + [GATE] + HAND BACK

**Build `NEXT.sh` (the recipe — it IS this shape):**

1. Walk `PROCEDURE.md` in order. For each step:
   - un-annotated (fixed) → emit verbatim;
   - `@delta:…:each` → emit the command once per matching delta file, file
     substituted; zero matches → omit;
   - `@delta:…:list` → if any delta file matches, emit the command once and list
     the matches as `# VERIFY:` items; zero matches → omit;
   - `@delta:…when=` → emit verbatim only if the delta intersects a pattern.
2. Read `INCIDENTS.md`; for each `DEP-NNN` whose step matches an emitted step,
   prepend `# PRE-WARN: DEP-NNN <one-line summary>` above it.
3. Keep every `# VERIFY:` gate. Header the file: *"Run by hand, step by step.
   Never `bash NEXT.sh` unattended."*
4. Write `.claude/deploy/NEXT.sh`.

**[GATE] — present `NEXT.sh` → `all / edit / skip-all`.**
- `all` → proceed. `edit` → revise the listed steps, re-present.
- `skip-all` → abort: write no `PENDING.json`, discard the draft `NEXT.sh`, stop.

**On approve:** write `.claude/deploy/PENDING.json`:
```jsonc
{ "base_sha": "<STEP 1 base>", "target_sha": "<STEP 1 target>",
  "delta": [<STEP 1 file list>], "step_reached": "awaiting-user",
  "started_at": "<now, ISO-8601>",
  "runbook_rev": "<git log -1 --format=%h -- .claude/deploy/PROCEDURE.md>" }
```
**Then HAND BACK** (AskUserQuestion): *"Run NEXT.sh step by step against prod.
Report back: **Deployed OK** / **Failed at step X: <err>** / **Not yet**."* Then
**stop** — control is the user's; `PENDING.json` on disk now marks the wait.

## STEP 3 — RESUME / REACT

Entry point on the user's report — reached inline after STEP 2, **or cold via
STEP 0** in a later session. Branch on the report:

- **"Deployed OK"** → STEP 5.
- **"Failed at step X: <err>"** → STEP 4.
- **"Not yet"** → restate what is pending (`step_reached`, target, the command to
  run) and stop. `PENDING.json` stays; the wait continues.

## STEP 4 — LEARN + [GATE] + ATOMIC COMMIT

Diagnose the root cause of the step-X failure, then draft a **coupled pair**:

- **(a)** an in-place patch to step X in `PROCEDURE.md` so the next run cannot
  repeat the failure;
- **(b)** an append to `INCIDENTS.md` — a new `DEP-NNN`
  (`next = grep '^## DEP-' INCIDENTS.md | max+1`) with date, step, **error
  verbatim**, root cause, fix, and `resolved-by` (filled after commit).

**[GATE] — `all / pick <IDs> / edit <ID> / skip-all`** (significant edit — it
changes a prod path).
- **Coupling invariant:** the patch and the incident are **one unit** — never
  commit one without the other. `pick <IDs>` / `edit <ID>` apply only when
  diagnosis yields **multiple** incidents (several failing steps); each selected
  incident still commits its own patch+append together.

**On approve — one ATOMIC commit of both files:**
```bash
bash lib/deploy-commit.sh commit \
  "docs(deploy): patch <step> — recovered from <err>" \
  .claude/deploy/PROCEDURE.md .claude/deploy/INCIDENTS.md
```
Return codes: **0** committed (short-hash on stdout) · **1** no-op (nothing
changed — investigate, you should have written both) · **3** unsafe git state
(detached/merge/rebase — STOP, tell the user) · **4** out-of-scope path (you
passed a non-`.claude/deploy/` path — fix the call) · **2** usage error.

Then:
1. Set the new `DEP-NNN`'s `resolved-by:` to the returned short-hash. (This is a
   metadata-only line; it rides along on the next `INCIDENTS.md` commit — do not
   churn a second commit for it.)
2. Bump `PENDING.json.runbook_rev` to that commit's sha; keep `step_reached` = `X`.
3. **Regenerate `NEXT.sh` from `step_reached` against the PATCHED runbook**
   (steps X…end — X+1…end never ran). This is NOT replaying one step: the bumped
   `runbook_rev` is exactly the staleness trigger — runbook changed ⇒ prior
   `NEXT.sh` is stale ⇒ regenerate.
4. Re-present via **STEP 2's [GATE] + hand-back** (the regenerated `NEXT.sh`;
   `PENDING.json` keeps `base/target/delta`, `step_reached` back to
   `awaiting-user`).

## STEP 5 — MARK (success)

The deploy succeeded. Lay the oracle and close out.

1. Read `# @config push_deploy_tags=` from the `PROCEDURE.md` header (default
   `false`). Pick `date = today` (`YYYY-MM-DD`); if `deploy/<date>` exists, suffix
   `-N`.
2. Write `.claude/deploy/STATE.json` (overwrite):
   ```jsonc
   { "deployed_sha": "<PENDING.target_sha>", "deployed_at": "<now ISO-8601>",
     "outcome": "ok", "tag": "deploy/<date>" }
   ```
   **`deployed_sha` = `PENDING.target_sha`, NOT current HEAD** — HEAD may have
   moved during the gap; the bridge's target is the deployed truth.
3. `git tag -a deploy/<date> <PENDING.target_sha> -m "<summary>"`.
4. If `push_deploy_tags=true` → `git push origin deploy/<date>` — **best-effort,
   non-fatal**: a push failure logs a warning, never blocks the mark (the tag is a
   bookmark; `STATE.json` is the oracle).
5. Commit the oracle:
   ```bash
   bash lib/deploy-commit.sh commit "chore(deploy): mark <date> @ <short>" \
     .claude/deploy/STATE.json
   ```
6. **Delete `.claude/deploy/PENDING.json` and `.claude/deploy/NEXT.sh`** — the
   deploy is no longer in flight; the bridge is consumed.
7. Report: deployed SHA, tag (+ push result), state committed, any `DEP-NNN`
   learned this deploy. Then offer to capitalize per CLAUDE.md (recurring failure
   pattern → `learnings.md`; deploy verdict → `evals.md`), gated, never silent.

---

## Rules

- `PENDING.json` is the only memory across the gap. Read it first, every run.
- On RESUME, never recompute `{base, target, delta}` — the bridge is authoritative.
- `deployed_sha` is `PENDING.target_sha`, never live HEAD.
- Delta is `git diff --name-only <base> HEAD` (two endpoints). No `rev-list`, no
  three-dot, no date ranges.
- First-deploy / fresh detection is file existence only — never `git describe`.
- Claude never executes the deploy. `NEXT.sh` is hand-run; `# VERIFY:` gates stay.
- Patch + incident commit **atomically**, one `deploy-commit.sh` call, both files.
- A learn bumps `runbook_rev` and **regenerates** `NEXT.sh` from `step_reached`;
  it never replays a single step.
- Tag push is best-effort; `STATE.json` is the oracle.
- JSON is read natively (Read tool), never parsed with `jq`/shell.
- `STATE.json` written only on confirmed success (STEP 5). A failed/partial deploy
  leaves the oracle untouched, `PENDING.json` alive — fail closed, resume later.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| On resume, recomputing delta from current HEAD | HEAD moved during the gap. Use `PENDING.json.{base,target,delta}` verbatim. |
| `git describe` to detect first deploy | Errors with no tag. Detect by `STATE.json` / `PENDING.json` existence. |
| `git rev-list` or three-dot for the delta | Phantom/undercounted deltas. Two-dot `<base> HEAD` only. |
| `bash NEXT.sh` to "just run it" | Claude never deploys. Hand back; user runs by hand with `# VERIFY:` gates. |
| Committing the patch without the incident (or vice versa) | Coupling invariant. One atomic `deploy-commit.sh` call, both files. |
| Replaying only the failed step after a patch | Steps X…end never ran. Regenerate `NEXT.sh` from `step_reached`. |
| Writing `STATE.json` before the user confirms success | Oracle marks success only. Failed deploy leaves it untouched. |
| Setting `deployed_sha` to HEAD at MARK time | Use `PENDING.target_sha` — the SHA actually deployed. |
| Parsing the JSON bridges with `jq` | Read them natively. No jq dependency. |
| Deleting `PENDING.json` before STEP 5 | The bridge is the resume marker — delete it only on confirmed success. |

## Red flags — STOP

- About to recompute the delta or re-read HEAD while a `PENDING.json` exists.
- About to run `git describe`, `git rev-list`, or a three-dot diff for the delta.
- About to `bash NEXT.sh` or run any prod command yourself.
- About to commit `PROCEDURE.md` without `INCIDENTS.md` in the same call.
- About to write `STATE.json` before the user reported "Deployed OK".
- About to replay one failed step instead of regenerating from `step_reached`.

## Note on this skill (authoring)

Shaped via `superpowers:writing-skills`. The **cold cross-session resume** is the
novel form (design §10): the disk alone must carry the deploy across the
out-of-band gap, so `PENDING.json`'s presence marks the wait and STEP 0 resumes
from it without conversation memory — the `audit-delta` "state file is the only
memory between runs" convention, extended to a *mid-flow* pause. The forms here
match the failure modes the design identified: **discipline** failures
(recompute-on-resume, run-the-deploy, advance-the-oracle-early) get the
rationalization table + red flags; the **shape** of `NEXT.sh` and the schemas get
positive recipes; the patch↔incident **omission** is a structural atomic-commit
requirement. Pressure-scenario baseline testing per the writing-skills Iron Law
is a follow-up — the failure modes were taken from the design spec, not a fresh
RED run.
