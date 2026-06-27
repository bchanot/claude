# Deploy Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `deploy` skill — a per-project shell runbook that re-instantiates from the delta since the last deploy, hands control to the user for out-of-band execution, resumes cold (even in a new session), and learns from deploy errors in place.

**Architecture:** A surgical-commit helper (`lib/deploy-commit.sh`, allowlist-scoped to `.claude/deploy/`) is the foundation. Five per-project artifacts under `.claude/deploy/` carry runbook, incident ledger, deploy oracle, in-flight bridge, and the instantiated checklist. The skill is a two-moment SKILL.md (before → user deploys out-of-band → after, on the user's report), resumable cold from the JSON bridge per the `audit-delta` state-file convention. Bootstrap scaffolds the runbook for a project that has none.

**Tech Stack:** Bash (helper + git), Markdown (SKILL.md + runbook + ledger), JSON (oracle + bridge). No new runtime deps — Claude reads JSON natively in skill steps; the helper never parses JSON.

## Global Constraints

- Surgical commits only: `deploy-commit.sh` commits via explicit argv pathspec, never `git add -A`. (mirror BDR-034/036)
- Allowlist scope = `.claude/deploy/` ONLY; any other path is a loud rc-4 refusal. Inverse of `doc-commit.sh`'s `.claude/**` exclusion (BDR-022). Verified: real `doc-commit.sh` returns rc 4 on `.claude/deploy/PROCEDURE.md`.
- Delta = `git diff --name-only <base_sha> HEAD` — **explicit two endpoints, no dots** (two-dot ≡ this; three-dot undercounts — verified). Never `git rev-list` ancestry (phantom deltas on rebase — verified).
- First-deploy detection = `[ -f .claude/deploy/STATE.json ]` (deterministic). NEVER `git describe` (hard-errors rc 128 on no tag — verified).
- Resume convention = `audit-delta`: "the state file is the only memory between runs; never infer prior scope from context." Bridge read at STEP 0.
- Helper inherits from `lib/memory-commit.sh`/`lib/doc-commit.sh`: rc 3 on unsafe git state (detached/merge/rebase/cherry-pick), short-hash on stdout only on a real commit, per-file changed-paths filter, diagnostics to stderr.
- User executes the deploy out-of-band (prod ssh) — the skill NEVER runs deploy commands itself.
- Registries/spec language English; the spec of record is `docs/specs/2026-06-27-deploy-skill-design.md`.

---

## Decisions resolved at plan time

**§10 (cross-session state) — TRANCHÉ: separate bridge artifact.**
- Bridge = `.claude/deploy/PENDING.json` (JSON), **distinct from the ephemeral `NEXT.sh`**, **uncommitted** (transient local working state; gitignored). Schema:
  ```json
  { "base_sha": "<deployed STATE sha>", "target_sha": "<HEAD at instantiation>",
    "delta": ["supabase/migrations/0033_x.sql", "docker-compose.yml"],
    "step_reached": "awaiting-user", "started_at": "<ISO-8601>", "runbook_rev": "<PROCEDURE.md commit sha>" }
  ```
- Follows `audit-delta` ("state file is the only memory between runs"). Resolves the n°1↔n°3 coupling: NEXT.sh stays ephemeral per §3; the bridge persists and carries base+target+delta so moment 3 lays the correct marker and capitalizes the correct incident — **without re-parsing shell**, readable cold.
- Form-novelty (mid-flow pause-resume) is new → `writing-skills` formalizes the convention in Task 3.
- **LIMIT (acknowledged, not to be discovered):** `PENDING.json` is gitignored ⇒ cold-resume is **same-machine only** — it does not survive a clone or a move to another machine. Acceptable because a project's deploys run from one local; recorded as a constraint, not assumed away.

**§8 item 1 — tag push:** annotated tag `git tag -a deploy/<YYYY-MM-DD> <target_sha> -m "<summary>"` laid in MARK (success). **Project knob `# @config push_deploy_tags=true|false`** in the `PROCEDURE.md` header (default `false`): when true, MARK runs `git push origin deploy/<date>` — always **best-effort/non-fatal** (the push never blocks the deploy; tag is a bookmark, STATE.json is the oracle). Same-day re-deploy → suffix `-N`.

**§8 item 2 — INCIDENTS ID/name:** `.claude/deploy/INCIDENTS.md`, append-only, entries `DEP-NNN` (next = `grep '^## DEP-' | max+1`), fields mirror `blockers.md`: date, step, error (verbatim), root cause, fix. Resolution derivable from git: the commit that adds the entry IS the fix (atomic patch+incident); recover via `git log -S 'DEP-NNN' -- .claude/deploy/INCIDENTS.md`. Name confirmed `INCIDENTS.md` (not `ERRORS-LEARNED.md`).

**§8 item 3 — `@delta:` grammar:** directives on a runbook step's preceding comment line, patterns matched against the delta file list. `glob=` carries TWO required semantics (a single "checklist-only" reading was REJECTED — it breaks the game example, where step 3 runs `psql -f 0033` THEN `psql -f 0034` = one command PER file):
- `# @delta:<name> glob=<pat>:each` — **repeat**: emit the step's command once per delta file matching `<pat>` (e.g. `psql -f <each>`).
- `# @delta:<name> glob=<pat>:list` — **checklist**: emit the command once, with matching files as `# VERIFY:` items (e.g. `supabase migration up`).
- `# @delta:<name> when=<pat>[,<pat>...]` — **conditional**: include the step only if the delta intersects any pattern (e.g. rebuild when compose/Dockerfile changed).
- Patterns are git-pathspec/shell-glob; comma-separates alternatives. **Un-annotated step = fixed**, always emitted verbatim. The exact `:each`/`:list` keyword spelling is DEFERRED to `writing-skills` (Task 3); both semantics are mandatory.

**§8 item 4 — frontmatter / gates:**
```yaml
name: deploy
description: |
  Use when deploying a project via its per-project runbook — instantiates the
  delta since last deploy, hands off for out-of-band execution, resumes cold,
  learns from errors.
  Triggers: "deploy", "déploie", "run the deploy", "ship to prod", "deploy runbook".
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion]
```
Gate vocabulary reused from `capitalize`/`client-handover`: `all / pick <IDs> / edit <ID> / skip-all`. Gates marked **[GATE]** in Task 3.

---

## File Structure

- Create `lib/deploy-commit.sh` — surgical commit helper, allowlist `.claude/deploy/`. (Task 1)
- Create `lib/tests/deploy-commit.test.sh` — real-git behavioral tests. (Task 1)
- Create `skills/deploy/SKILL.md` — the two-moment skill. (Task 3)
- Create `templates/deploy/PROCEDURE.md` — annotated starter runbook (scaffold source). (Task 2/4)
- Create `templates/deploy/INCIDENTS.md` — empty ledger header. (Task 2)
- Modify `.gitignore` — ignore `.claude/deploy/NEXT.sh` and `.claude/deploy/PENDING.json`. (Task 2)
- Per-project, created at runtime (NOT in this repo): `.claude/deploy/{PROCEDURE.md, INCIDENTS.md, STATE.json, PENDING.json, NEXT.sh}`.

**Artifact lifecycle:**

| Artifact | Committed? | Lifecycle |
|---|---|---|
| `PROCEDURE.md` | yes (deploy-commit) | in-place edits (learning) |
| `INCIDENTS.md` | yes (deploy-commit) | append-only `DEP-NNN` |
| `STATE.json` | yes (deploy-commit) | overwritten on success = oracle |
| `PENDING.json` | **no** (gitignored) | written at hand-back, deleted on success = cold-resume bridge |
| `NEXT.sh` | **no** (gitignored) | regenerated per deploy, ephemeral checklist |

---

### Task 1: `lib/deploy-commit.sh` — surgical commit helper (FOUNDATION, TDD)

**Files:**
- Create: `lib/deploy-commit.sh`
- Test: `lib/tests/deploy-commit.test.sh`

**Interfaces:**
- Produces: `deploy-commit.sh pending <file>...` → exit 0 if any passed file in-scope has changes, else 1. `deploy-commit.sh commit "<msg>" <file>...` → commits ONLY passed in-scope files, prints short hash on stdout; rc 0 success, rc 1 clean/no-op, rc 3 unsafe git state, rc 4 out-of-scope path.
- Consumes: nothing (foundation).

- [ ] **Step 1: Write the failing test harness**

```bash
# lib/tests/deploy-commit.test.sh
#!/usr/bin/env bash
set -u
H="$(cd "$(dirname "$0")/.." && pwd)/deploy-commit.sh"
pass=0; fail=0
mkrepo() { local d; d=$(mktemp -d); git -C "$d" init -q; git -C "$d" config user.email t@t;
  git -C "$d" config user.name t; mkdir -p "$d/.claude/deploy"; printf 'x\n' >"$d/seed";
  git -C "$d" add seed; git -C "$d" commit -q -m seed; printf '%s' "$d"; }
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }

d=$(mkrepo); printf 'run\n' >"$d/.claude/deploy/PROCEDURE.md"
out=$( cd "$d" && bash "$H" commit "docs(deploy): t" .claude/deploy/PROCEDURE.md ); rc=$?
check T1-rc "$rc" 0
check T1-committed-only "$(git -C "$d" show --name-only --format= HEAD)" ".claude/deploy/PROCEDURE.md"
check T1-hash-nonempty "$([ -n "$out" ] && echo y || echo n)" y

d=$(mkrepo); printf 'b\n' >"$d/src.txt"
( cd "$d" && bash "$H" commit "x" src.txt ) >/dev/null 2>&1; check T2-out-of-scope-rc "$?" 4

d=$(mkrepo)
( cd "$d" && bash "$H" commit "x" ".claude/deploy/../memory/secret" ) >/dev/null 2>&1
check T3-traversal-rc "$?" 4

d=$(mkrepo); printf 'p\n' >"$d/.claude/deploy/PROCEDURE.md"; printf 's\n' >"$d/src.txt"
( cd "$d" && bash "$H" commit "x" .claude/deploy/PROCEDURE.md src.txt ) >/dev/null 2>&1
check T4-mixed-refuses-all "$?" 4
check T4-nothing-committed "$(git -C "$d" rev-list --count HEAD)" 1

d=$(mkrepo); git -C "$d" checkout -q --detach
printf 'p\n' >"$d/.claude/deploy/PROCEDURE.md"
( cd "$d" && bash "$H" commit "x" .claude/deploy/PROCEDURE.md ) >/dev/null 2>&1
check T5-unsafe-rc "$?" 3

d=$(mkrepo)
( cd "$d" && bash "$H" pending .claude/deploy/PROCEDURE.md ); check T6-pending-clean-rc "$?" 1

d=$(mkrepo); printf 'p\n' >"$d/.claude/deploy/PROCEDURE.md"
printf 'i\n' >"$d/.claude/deploy/INCIDENTS.md"; printf '{}\n' >"$d/.claude/deploy/STATE.json"
( cd "$d" && bash "$H" commit "docs(deploy): learn" .claude/deploy/PROCEDURE.md \
   .claude/deploy/INCIDENTS.md .claude/deploy/STATE.json ) >/dev/null 2>&1
check T7-atomic-rc "$?" 0
check T7-three-files "$(git -C "$d" show --name-only --format= HEAD | grep -c deploy)" 3

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run the test, verify it FAILS**

Run: `bash lib/tests/deploy-commit.test.sh`
Expected: FAIL (helper absent) — every check fails or the harness errors on missing `lib/deploy-commit.sh`.

- [ ] **Step 3: Implement `lib/deploy-commit.sh`**

```bash
#!/usr/bin/env bash
# deploy-commit.sh — surgical commit for the .claude/deploy/ runbook family.
# Allowlist scope = .claude/deploy/ ONLY (inverse of doc-commit's .claude exclusion).
set -u

_in_git_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

_unsafe_state() {                       # 0 = unsafe
  local g; g=$(git rev-parse --git-dir 2>/dev/null) || return 0
  git symbolic-ref -q HEAD >/dev/null 2>&1 || return 0     # detached HEAD
  [ -e "$g/MERGE_HEAD" ] || [ -d "$g/rebase-merge" ] || \
    [ -d "$g/rebase-apply" ] || [ -e "$g/CHERRY_PICK_HEAD" ] && return 0
  return 1
}

_out_of_scope() {                       # 0 = forbidden, 1 = in scope
  case "$1" in
    *..*) return 0 ;;                   # traversal — forbidden FIRST
    .claude/deploy/*) return 1 ;;       # allowed
    *) return 0 ;;                      # everything else forbidden
  esac
}

_scope_violations() { local p; for p in "$@"; do _out_of_scope "$p" && printf '%s\n' "$p"; done; }

_changed_only() {                       # echo passed files that actually have changes
  local p; for p in "$@"; do
    [ -n "$(git status --porcelain -- "$p" 2>/dev/null)" ] && printf '%s\n' "$p"; done
}

cmd="${1:-}"; shift || true
_in_git_repo || { echo "deploy-commit: not a git repo" >&2; exit 2; }

case "$cmd" in
  pending)
    [ "$#" -gt 0 ] || { echo "deploy-commit: pending needs file args" >&2; exit 2; }
    [ -n "$(_changed_only "$@")" ] && exit 0 || exit 1 ;;
  commit)
    msg="${1:-}"; shift || true
    [ -n "$msg" ] && [ "$#" -gt 0 ] || { echo "deploy-commit: commit needs <msg> <file>..." >&2; exit 2; }
    viol=$(_scope_violations "$@")
    if [ -n "$viol" ]; then
      { echo "deploy-commit: REFUSED — path(s) outside .claude/deploy/ allowlist:";
        printf '  - %s\n' $viol;
        echo "deploy-commit: NOTHING committed. Caller must pass only .claude/deploy/ files."; } >&2
      exit 4
    fi
    _unsafe_state && { echo "deploy-commit: unsafe git state (detached/merge/rebase) — not committing" >&2; exit 3; }
    mapfile -t changed < <(_changed_only "$@")
    [ "${#changed[@]}" -gt 0 ] || exit 1
    git commit -q -m "$msg" -- "${changed[@]}" || { echo "deploy-commit: git commit failed" >&2; exit 1; }
    git rev-parse --short HEAD ;;
  *) echo "usage: deploy-commit.sh pending <file>... | commit \"<msg>\" <file>..." >&2; exit 2 ;;
esac
```

- [ ] **Step 4: Run the test, verify it PASSES**

Run: `bash lib/tests/deploy-commit.test.sh`
Expected: `PASS=11 FAIL=0` (exit 0).

- [ ] **Step 5: shellcheck**

Run: `shellcheck lib/deploy-commit.sh lib/tests/deploy-commit.test.sh`
Expected: clean (matches repo Health Stack norm).

- [ ] **Step 6: Commit**

```bash
git add lib/deploy-commit.sh lib/tests/deploy-commit.test.sh
git commit -m "feat(deploy): deploy-commit.sh — allowlist surgical commit for .claude/deploy/"
```

---

### Task 2: Artifacts + bridge formats (§10 materialized)

**Files:**
- Create: `templates/deploy/PROCEDURE.md`, `templates/deploy/INCIDENTS.md`
- Modify: `.gitignore`

**Interfaces:**
- Produces: the on-disk shapes the skill reads/writes — `PROCEDURE.md` annotation grammar, `INCIDENTS.md` `DEP-NNN` template, `STATE.json` and `PENDING.json` schemas.
- Consumes: nothing.

- [ ] **Step 1: Write `templates/deploy/PROCEDURE.md`** (annotated starter — fixed steps verbatim, dynamic steps annotated)

```bash
#!/usr/bin/env bash
# === deploy runbook (reference) — NOT run directly. Instantiated to NEXT.sh per delta. ===
# Fixed steps run every deploy; `# @delta:` steps re-instantiate from the delta.
# @config push_deploy_tags=false
# NOTE grammar: glob=<pat>:each repeats the command per matching file (e.g. psql -f <each>);
#               glob=<pat>:list runs once + lists matching files as VERIFY items; when=<pat,...> is conditional.

# 1) backup BEFORE any forward-only migration
ssh "$DEPLOY_HOST" 'pg_dump "$DB" > ~/backups/pre-deploy-$(date +%F-%H%M).sql'   # VERIFY: dump size > 0

# @delta:migrations glob=supabase/migrations/*.sql:list
# 2) apply NEW migrations (one command; skill lists the delta migrations to VERIFY)
ssh "$DEPLOY_HOST" 'supabase migration up'                                       # VERIFY: "Applied" for each

# @delta:rebuild when=docker-compose*.yml,Dockerfile,*.dockerfile
# 3) rebuild + restart services (only if build inputs changed)
ssh "$DEPLOY_HOST" 'docker compose up -d --build'                                # VERIFY: docker compose ps healthy

# @delta:deps when=package.json,*lock*,requirements.txt,pyproject.toml
# 4) install deps (only if manifests changed)
ssh "$DEPLOY_HOST" 'cd app && npm ci'                                            # VERIFY: exit 0

# 5) reload cache + smoke test (fixed)
ssh "$DEPLOY_HOST" 'systemctl reload app'
curl -fsS https://$DEPLOY_HOST/health                                            # VERIFY: HTTP 200
```

- [ ] **Step 2: Write `templates/deploy/INCIDENTS.md`** (ledger header)

```markdown
# Deploy incidents (append-only) — DEP-NNN

<!-- One entry per incident. Next ID = grep '^## DEP-' | max+1. Mirrors blockers.md. -->
<!-- Resolution = the commit that adds this entry (atomic patch+incident). Recover: git log -S 'DEP-NNN' -- .claude/deploy/INCIDENTS.md -->
<!-- ## DEP-NNN — <step> failed
     - date: YYYY-MM-DD
     - step: <runbook step + label>
     - error: `<verbatim error>`
     - cause: <root cause>
     - fix: <what changed in PROCEDURE.md> -->
```

- [ ] **Step 3: Record the JSON schemas** (no parsing in shell — Claude reads them in skill steps)

`STATE.json` (committed oracle, overwritten on success):
```json
{ "deployed_sha": "<sha>", "deployed_at": "<ISO-8601>", "outcome": "ok",
  "tag": "deploy/<YYYY-MM-DD>" }
```
`PENDING.json` (gitignored bridge, deleted on success): schema as in "Decisions resolved at plan time / §10".

- [ ] **Step 4: Update `.gitignore`**

```gitignore
# deploy: transient per-deploy state (the runbook/ledger/oracle ARE committed)
.claude/deploy/NEXT.sh
.claude/deploy/PENDING.json
```

- [ ] **Step 5: Verify templates are well-formed**

Run: `bash -n templates/deploy/PROCEDURE.md && grep -c '@delta:' templates/deploy/PROCEDURE.md`
Expected: no syntax error; `3` annotations.

- [ ] **Step 6: Commit**

```bash
git add templates/deploy/PROCEDURE.md templates/deploy/INCIDENTS.md .gitignore
git commit -m "feat(deploy): runbook/ledger templates + bridge schemas + gitignore transient state"
```

---

### Task 3: `skills/deploy/SKILL.md` — the two-moment skill (REQUIRES writing-skills)

> **At this task, invoke `superpowers:writing-skills`** to shape SKILL.md to house conventions AND to formalize the **cross-session cold-resume** form (deploy's defining novelty; `audit-delta` is the state-file precedent, `client-handover` only an in-context pause). The step behaviors below are the contract; writing-skills governs structure/frontmatter/spine.

**Files:**
- Create: `skills/deploy/SKILL.md`

**Interfaces:**
- Consumes: `lib/deploy-commit.sh` (Task 1); artifact shapes (Task 2).
- Produces: the runtime behavior. STEP spine below.

**STEP spine (each = a SKILL.md section; [GATE] = mandatory stop):**

- [ ] **STEP 0 — PRE-FLIGHT + RESUME BRANCH.** Read `.claude/deploy/PENDING.json` FIRST (state file = only memory between runs).
  - `PENDING.json` present → **RESUME**: jump to STEP 3 with its `{base, target, delta, step_reached}` (do not recompute).
  - else `PROCEDURE.md` absent → **BOOTSTRAP** (Task 4).
  - else → FRESH: continue STEP 1.
- [ ] **STEP 1 — DELTA.** `base = STATE.json.deployed_sha` (or, if `STATE.json` absent, first-deploy = full runbook). `git diff --name-only <base> HEAD` → delta file list. `target = git rev-parse HEAD`.
- [ ] **STEP 2 — INSTANTIATE + [GATE].** Expand `PROCEDURE.md`: emit fixed steps verbatim; expand `@delta:glob=…:each` steps by repeating the command per matching delta file, and `@delta:glob=…:list` steps once with matching files as `# VERIFY:` items; include `@delta:when=` steps only if the delta intersects. Read `INCIDENTS.md` and prepend matching `# PRE-WARN: DEP-NNN …` notes. Write `NEXT.sh`. **[GATE]** present `NEXT.sh` → `all / edit / skip-all`. On approve: write `PENDING.json` (`step_reached: awaiting-user`), then **hand back** (AskUserQuestion: "Run NEXT.sh step by step. Report back: Deployed OK / Failed at step X / Not yet").
- [ ] **STEP 3 — RESUME / REACT** (entry point on the user's report; may be a fresh session).
  - "Deployed OK" → STEP 5.
  - "Failed at step X: <err>" → STEP 4.
  - "Not yet" → re-state pending, stop.
- [ ] **STEP 4 — LEARN + [GATE] + ATOMIC COMMIT.** Diagnose. Draft: (a) in-place `PROCEDURE.md` patch to step X; (b) `INCIDENTS.md` append `DEP-NNN` (error verbatim). **[GATE]** `all / pick / edit / skip-all` (significant edit). On approve: write both, then **one atomic** `bash lib/deploy-commit.sh commit "docs(deploy): patch <step> — recovered from <err>" .claude/deploy/PROCEDURE.md .claude/deploy/INCIDENTS.md`. The commit that adds `DEP-NNN` IS its resolution (derive via git later). Then bump `PENDING.json.runbook_rev` to the new `PROCEDURE.md` commit sha (keep `step_reached` at X). **Resume = REGENERATE `NEXT.sh` from `step_reached` against the PATCHED runbook** (steps X…end — X+1…end never ran), NOT replay a single step. The bumped `runbook_rev` is exactly the trigger: runbook changed ⇒ prior `NEXT.sh` is stale ⇒ regenerate. Re-present via STEP 2's hand-back.
- [ ] **STEP 5 — MARK (success).** Write `STATE.json` (`deployed_sha = PENDING.target_sha`, outcome ok, tag). `git tag -a deploy/<date> <target> -m "<summary>"`; **if `@config push_deploy_tags=true`** then `git push origin deploy/<date>` (best-effort, non-fatal). `bash lib/deploy-commit.sh commit "chore(deploy): mark <date> @ <short>" .claude/deploy/STATE.json`. **Delete `PENDING.json`** (+ `NEXT.sh`). Report.

- [ ] **Verification scenarios** (dry-run walkthroughs, no prod):
  - First deploy (no `STATE.json`): full runbook fires; STATE laid; PENDING deleted.
  - Delta deploy: only changed-bucket steps instantiate; `git diff` form is `<base> HEAD`.
  - **Cold resume**: write a `PENDING.json` by hand, start `deploy` in a *fresh* context → STEP 0 detects it, resumes at STEP 3 from disk alone (no conversation memory).
  - Failure→learn: report "failed at step X" → patch + DEP append committed atomically (one sha, both files).
- [ ] **Commit:** `git add skills/deploy/SKILL.md && git commit -m "feat(deploy): two-moment cross-session skill (resumes cold from PENDING.json)"`

---

### Task 4: Bootstrap (project without a runbook)

**Files:**
- Modify: `skills/deploy/SKILL.md` (STEP 0 BOOTSTRAP branch)

**Interfaces:**
- Consumes: `templates/deploy/*` (Task 2); STEP spine (Task 3).

- [ ] **Step 1 — BOOTSTRAP branch + [GATE].** When `PROCEDURE.md` absent, offer two paths (AskUserQuestion):
  - **Paste** — user provides an existing runbook → adopt verbatim, then propose `@delta:` annotations for migration/build/deps steps.
  - **Scaffold** — detect artifacts (`supabase/migrations/`, `docker-compose*.yml`/`Dockerfile`, `package.json`/lockfiles, `.env*`) + short interview (ssh host, backup cmd, health URL, rollback note) → fill `templates/deploy/PROCEDURE.md`.
  - **[GATE]** present drafted `PROCEDURE.md` → `all / edit / skip-all`. On approve: write `PROCEDURE.md` + empty `INCIDENTS.md`; `bash lib/deploy-commit.sh commit "feat(deploy): bootstrap runbook" .claude/deploy/PROCEDURE.md .claude/deploy/INCIDENTS.md`. First deploy then proceeds (no STATE.json ⇒ full runbook).
- [ ] **Step 2 — Verify:** dry-run on a repo with `supabase/migrations/` + `docker-compose.yml` present → scaffold proposes migration + rebuild steps annotated; on a bare repo → interview-only path.
- [ ] **Commit:** `git add skills/deploy/SKILL.md && git commit -m "feat(deploy): bootstrap — paste-or-scaffold initial runbook"`

---

## Gates identified

- **[GATE] STEP 2** — approve instantiated `NEXT.sh` before hand-back.
- **[GATE] STEP 4** — approve runbook patch + `DEP-NNN` incident before the atomic learning commit.
- **[GATE] STEP 0/Task 4** — approve scaffolded `PROCEDURE.md` before first write.
- **Hand-back (STEP 2→3)** — AskUserQuestion is the resume point; the user executes out-of-band.
- **Task gates** — each Task ends test-green + shellcheck-clean + committed before the next (deps: 1 → 2 → 3 → 4).

## Self-review

- **Spec coverage:** 4 artifacts + bridge (§3/§10) → Task 2; STATE-oracle + `<base> HEAD` delta (§4) → Task 1 constraints + STEP 1; runbook+INCIDENTS learning, atomic couple (§5) → STEP 4; `deploy-commit.sh` inverse allowlist (§6) → Task 1; bootstrap (§7) → Task 4; two-moment cold resume (§10) → STEP 0/2/3 + PENDING.json. All §8 items resolved above. ✓
- **Placeholder scan:** none — helper code, test code, schemas, annotation grammar all concrete.
- **Type consistency:** `STATE.json.deployed_sha` (STEP 1 base, STEP 5 write), `PENDING.json.{base_sha,target_sha,delta,step_reached}` (STEP 0 read, STEP 2 write, STEP 4 update), `deploy-commit.sh commit "<msg>" <file>...` (Tasks 1/3/4) — names align.
- **Open at execution (not assumed):** the `writing-skills` consultation in Task 3 may rename/restructure SKILL.md sections to match the formalized cold-resume convention, and finalizes the `@delta:` `:each`/`:list` keyword spelling (both semantics mandatory); STEP behaviors and the §6 helper contract above are fixed regardless.

## Execution Handoff

Build order is strict by dependency: **Task 1 (helper, foundation) → Task 2 (formats) → Task 3 (skill, writing-skills) → Task 4 (bootstrap)**.
