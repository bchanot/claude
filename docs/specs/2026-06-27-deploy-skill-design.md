# Deploy skill — design spec

- **Date:** 2026-06-27
- **Status:** Design approved (5 knobs settled). **No skill code written yet.** Next step = implementation plan.
- **Scope:** A new `deploy` skill = a per-project shell RUNBOOK that lives in `.claude/deploy/`, gets re-instantiated from the delta since the last deploy, and LEARNS from deploy errors in place.

## 1. Vision — deployment memory that learns

Three moments:

1. **BEFORE** — produce the *instantiated* runbook: reference runbook + delta since last deploy, parameterized steps rewritten with the real artifacts (e.g. the migration step lists the migrations actually added since last deploy, not the runbook's examples).
2. **DURING** — the **user executes out-of-band** (prod ssh — Claude must not run it) and reports `deployed and tested` OR `failed at step X, here is the error` → fix together until success.
3. **AFTER** — on confirmed success: (a) if errors were hit + fixed, update the reference runbook so the next deploy does not repeat them; (b) lay the marker "deployed up to here" for the next diff.

Structural ancestor in the corpus: `client-handover` (BEFORE baseline → DURING user-deploy gate via `AskUserQuestion` → AFTER validate + react). No existing skill owns a learning per-project runbook — clean gap, no `.claude/deploy/` precedent.

## 2. Locked decisions

| # | Knob | Decision |
|---|------|----------|
| 1 | Marker / oracle | **STATE file is the oracle** (deployed SHA), **annotated tag** added as a human bookmark only |
| 2 | Learning storage | **In-place runbook edits + append-only `INCIDENTS.md`** (distinct jobs, atomic coupling) |
| 3 | Parameterization | **`# @delta:` annotations** bind dynamic steps to path-patterns; un-annotated steps are fixed |
| 4 | Bootstrap | **Offer both** — user pastes an existing runbook OR skill scaffolds via artifact detection + interview |
| 5 | Execution model | **`NEXT.sh` is a step-by-step CHECKLIST** — runnable shell, but driven by hand with manual `# VERIFY:` gates; never `bash NEXT.sh` unattended |

**Why #5 is design-time, not impl:** the execution model is load-bearing for moments 2 and 3. Moment 2 is defined as "user reports *failed at step X*", and moment 3's LEARN loop must know *which* step failed to patch it. A single `bash NEXT.sh` blob collapses both into "exited non-zero somewhere" and can strand a prod deploy (migrations, restarts) in partial state with no step control. Checklist is *entailed* by the three-moment structure, not merely safer.

Treated as settled corollaries: user executes out-of-band; a **new** `lib/deploy-commit.sh` helper (existing helpers cannot commit the runbook — see §6, verified).

## 3. Architecture

```
.claude/deploy/
  PROCEDURE.md   reference runbook — fixed shell + `# @delta:` annotated steps   (edited IN-PLACE)
  INCIDENTS.md   DEP-NNN incident ledger: date, step, error verbatim, root cause,
                 fix, -> resolving commit hash                                    (APPEND-ONLY)
  STATE          deployed SHA + timestamp + outcome — the diff oracle             (overwritten each deploy)
  NEXT.sh        instantiated runbook — EPHEMERAL, not committed ; run STEP-BY-STEP
                 (checklist, manual # VERIFY: gates) — never `bash NEXT.sh` unattended

lib/deploy-commit.sh   surgical commit, allowlist = .claude/deploy/ , rc3 unsafe-git guard, short-hash stdout

Skill STEP spine (PRE-FLIGHT -> PROPOSE+GATE -> WRITE+COMMIT, house style):
  0 PRE-FLIGHT  runbook present?  absent -> bootstrap (paste | scaffold+interview)
  1 DELTA       STATE absent -> first deploy = full runbook ; else diff <STATE_SHA> HEAD
  2 INSTANTIATE expand @delta steps + read INCIDENTS pre-warns -> NEXT.sh -> GATE
  3 (user executes out-of-band; reports "done" | "failed at step X: <err>")
  4 LEARN       on failure: patch PROCEDURE step + append DEP-NNN -> GATE -> deploy-commit (ATOMIC)
  5 MARK        on success: write STATE@sha ; annotate + push tag ; optional doc
```

## 4. Delta mechanism — verified (git 2.53.0)

All three facts re-run live before writing this spec; observed output recorded, not assumed.

**First-deploy detection = STATE-absent, deterministic. `describe` is off the detection path.**
```
[ -f .claude/deploy/STATE ]            => exit 1 (absent = first deploy)  <- THE detector
git describe --tags --match 'deploy/*' => fatal: No names found ; exit 128 <- only the reason NOT to use describe
[ -f .claude/deploy/STATE ]            => exit 0 (present = delta path)
```

**Delta = `git diff --name-only <STATE_SHA> HEAD`** (two explicit endpoints; no dots, so it cannot be misread as three-dot).
```
LINEAR   git diff --name-only <sha> HEAD   => 0033_new.sql, svc.yml   (== two-dot == three-dot; merge-base == STATE)
DIVERGED two-dot   sideA sideB             => fileA.txt, fileB.txt     (both endpoints = true tree delta)
DIVERGED three-dot sideA...sideB           => fileB.txt                (merge-base — UNDERCOUNTS)
```
Two-dot/explicit-endpoints is the literal tree difference between the deployed tree and HEAD = what deploy needs. It is also rebase-robust: an orphaned marker still yields the correct tree diff, whereas `git rev-list A..B` (ancestry) reports phantom deltas after history rewrite (LRN-054's trap; verified in an earlier run). **Never use `rev-list` ancestry for the artifact list.**

**delta -> steps:** `# @delta:<kind>` annotations bind a dynamic step to the path-pattern that feeds it; the diff buckets straight into steps:
```
# @delta:migrations glob=supabase/migrations/*.sql
# @delta:rebuild   when=docker-compose*.yml,Dockerfile
# @delta:deps      when=package.json,*lock*
```

## 5. Learning model — runbook + INCIDENTS, non-redundant

| Artifact | Job | Lifecycle |
|---|---|---|
| `PROCEDURE.md` | The corrected procedure you run. A fix is baked into the step so the next run cannot repeat it. | in-place |
| `INCIDENTS.md` | The incident ledger; **read at BEFORE-time to pre-warn** ("0033 hit a lock timeout last deploy; runbook already carries `--timeout`, watch for it"). | append-only |

The pre-warn read is the function `git log` serves badly — that is why the ledger is not duplication. This mirrors the memory system's own split (append-only `journal.md`/`blockers.md` alongside in-place TODO/code).

**Coupling invariant:** one incident → **one in-place `PROCEDURE.md` patch + one `INCIDENTS.md` append, committed atomically in a single `deploy-commit.sh` call.** Never one without the other (mirrors BDR-034/036 "couple the commit to the integration step"). Significant patch (changes a prod path) → surface + approve before writing.

## 6. `lib/deploy-commit.sh` — new helper, inverse `.claude/` rule (verified)

Neither existing helper can commit the runbook — confirmed live:
```
REAL doc-commit.sh  .claude/deploy/PROCEDURE.md => rc 4 "REFUSED — out-of-scope ... BDR-022 ... NOTHING committed"
REAL memory-commit.sh pending (deploy changed)  => rc 1 (ignores it; allowlist = .claude/memory|tasks only)
```
`doc-commit.sh` is built to keep `.claude/**` *out* of public-doc commits; `.claude/deploy/` is under `.claude/`, so reuse is not just blocked, it is semantically wrong. `deploy-commit.sh` needs the **inverse** rule: a TARGET allowlist for `.claude/deploy/*`, modeled on `memory-commit.sh` (rc 3 unsafe-git guard, short-hash on stdout, `chore(deploy):`/`docs(deploy):` messages).

Allowlist guard — traversal reject ordered FIRST. Prototype matrix verified live:
```sh
_in_deploy_scope() {
  case "$1" in
    *..*) return 1 ;;                 # reject path traversal FIRST
    .claude/deploy/*) return 0 ;;     # ALLOW the deploy family only
    *) return 1 ;;                    # reject everything else
  esac
}
```
```
ALLOW  .claude/deploy/{PROCEDURE.md,INCIDENTS.md,STATE}
REJECT .claude/memory/*  .claude/tasks/*  .claude/secret  CLAUDE.md  src/*
REJECT .claude/deploy            (bare dir, no slash)
REJECT .claude/deploy-other/x    (trailing-slash requirement closes prefix confusion)
REJECT .claude/deploy/../memory/secret   (traversal closed by *..* matched first)
```

## 7. Bootstrap

`STEP 0 PRE-FLIGHT`: `PROCEDURE.md` present? Absent → bootstrap, two offered paths:
1. **Paste** — user supplies an existing runbook (the game example); skill adopts + annotates it.
2. **Scaffold** — skill detects deploy artifacts (migrations dir, compose/Dockerfile, package scripts, `.env`) + a short interview (ssh target, backup cmd, rollback note) → writes an annotated `PROCEDURE.md`.

First deploy has no marker → STATE-absent ⇒ full runbook fires; then lay STATE at the deployed SHA. The first deploy *is* the creation of the runbook + the first marker.

## 8. Open items (for the implementation plan)

> `NEXT.sh` execution model resolved → decision #5 (checklist), promoted to design-time.

- Tag push: tags don't push by default → AFTER step should `git push --tag deploy/<date>` or remind.
- `INCIDENTS.md` ID/format detail (mirror `blockers.md` `DEP-NNN`); confirm name vs `ERRORS-LEARNED.md`.
- `@delta:` annotation grammar (glob= vs when=) — finalize the small DSL.
- Frontmatter `allowed-tools` set; STEP gate wording reuse from `capitalize`/`client-handover`.

## 9. Build sequencing & a structural flag

**Two distinct disciplines, in order — do not conflate:**
1. `writing-plans` — global task ordering (helper → skill → bootstrap), dependencies, gates. The build plan.
2. → execution →
3. At the *skill* task ONLY: `writing-skills` — the discipline for the SKILL.md itself (structure, frontmatter, spine, config conventions). Used WHEN we reach the skill task, **not before** (it does not fire at plan time).

**Structural flag for `writing-skills` to resolve — do NOT assume the linear-spine convention suffices:**
deploy's spine is unusual — **two parts split by out-of-band execution**: STEP 0–2 before → *user deploys by hand* → STEP 4–5 after, on the `done`/`failed` report. A skill that **hands back control mid-run and resumes**.

Preliminary recon (confirm at the skill task — NOT verified now):
- The 6 completion flux (close, ship-feature, feat, bugfix, hotfix, commit-change) appear linear one-shot — synchronous gates at most, no out-of-band hand-back.
- The relevant precedent is OUTSIDE those 6: `client-handover` already hands back — a synchronous "Deploy done?" `AskUserQuestion` pause (STEP 5) — but it holds state in *conversation context*, not on disk.
- deploy's genuinely-new bit *may* be **disk-bridged resume** (`NEXT.sh` + `STATE` on disk as the bridge) — but **whether `NEXT.sh` alone suffices to resume cross-session is an OPEN design question, not a settled answer** (see §10). An earlier draft of this spec framed it as resolved; it is not. `writing-skills` must establish the convention (how to mark "I wait for your return here", detect + resume a pending deploy, hold state across the gap) — confirm there, do not assume the linear mould suffices.

## 10. Open design question (DESIGN-TIME, unresolved) — state across the two moments

deploy is a **two-moment skill**: moments 0–2 (BEFORE) → user deploys out-of-band → moment 3 (AFTER) on the `done`/`failed` report. **The report may arrive in a different session.** So the design must answer how state crosses the gap and what moment 3 must know to resume correctly.

> **`skill deux-temps, état entre temps = [à concevoir : NEXT.sh seul suffit-il pour reprendre cross-session ?]`**

Sub-questions (to settle when we resume — NOT now, NOT assumed):
- **What must the bridge record?** Moment 3 must (a) lay the correct marker = `STATE ← target sha`, and (b) capitalize the correct incident (which step, which delta). HEAD may have moved since NEXT.sh was generated → "current HEAD" is unsafe. The bridge must persist at least **{base STATE sha, target sha, delta manifest}** — inside NEXT.sh (header block) or a sidecar (`.claude/deploy/PENDING`)? Undecided.
- **Resume detection (re-entrancy):** STEP 0 PRE-FLIGHT must detect "a deploy is pending, awaiting your report" — likely *pending-bridge present + STATE not advanced to target* — and branch RESUME (ask done/failed) vs FRESH. Is moment 3 a new `deploy` call that re-detects from disk, or a `deploy --report`? Undecided.
- **Ephemeral vs persistent tension — LINKED to sub-question 1 (not independent).** §3 calls NEXT.sh "EPHEMERAL, not committed", yet a cross-session bridge MUST survive on disk. So: **if the bridge must persist, NEXT.sh-as-bridge is impossible while NEXT.sh stays ephemeral.** Likely *binary* resolution at plan time — either (a) NEXT.sh becomes persistent (contradicts §3), or (b) the bridge is a **separate** "deploy-in-progress" artifact `{base/target/delta}` distinct from NEXT.sh. Settle with `writing-skills`. (Uncommitted local state is fine; note the single-machine assumption — an uncommitted bridge won't follow a clone.)
- **Form-novelty — deploy's DEFINING characteristic: cross-session COLD resume.** `client-handover` is a *near* precedent, not exact: it hands back **in-context** (same conversation, state held in memory). deploy must resume with the **context lost** — so the **disk alone must carry everything to resume cold**. No existing skill resumes without context; that is what sets deploy apart, and it makes sub-question 1 **load-bearing** (disk must suffice for a cold restart). deploy likely introduces a NEW skill form → `writing-skills` establishes the convention. Confirm there.

**Next step:** `writing-plans` to turn this spec into an implementation plan (helper first, then skill); at the skill task, `writing-skills` to shape it to convention and **resolve the §10 two-moment state question** — which is design-time, deferred only because we are stopped here, not because it is impl detail.
