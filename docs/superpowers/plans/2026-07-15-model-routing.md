# Model Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reflection (planning, audits, loop decisions) stays on the session big model behind a blocking gate; execution (code from a closed plan, fix-bundle application) runs on sonnet-pinned subagents.

**Architecture:** A deterministic witness (`lib/model-check.sh`) + a blocking include (`lib/model-gate.md`) wired into 12 reflection orchestrators; frontmatter `model:` pins on executor agents; `/feat` re-architected from inline playbook to "plan inline → dispatch sonnet executor"; SDD implementation subagents and web-validate fix application routed to sonnet.

**Tech Stack:** bash (shellcheck-clean), Claude Code SKILL.md/agent.md markdown, agent frontmatter `model:` field, Makefile test loop.

**Spec:** `docs/superpowers/specs/2026-07-15-model-routing-design.md` (approved 2026-07-15).

## Global Constraints

- Work on branch `feature/model-routing` (already checked out). Commit per task. NEVER merge/finish — human gate.
- NO commit attribution trailers of any kind (Co-Authored-By, Claude-Session) — user ban, guards will red.
- `make test` must be green at every commit (run from repo root `/home/bchanot/Documents/claude`).
- New/edited `.sh` files: `shellcheck <file>` clean and `bash -n <file>` clean.
- The `config-protection` PreToolUse hook BLOCKS Edit/Write on `lib/tests/*`, `hooks/*`, `settings.json`, `lib/gitflow.sh`. Before EACH Edit/Write to `lib/tests/*` in this plan, write the one-shot bypass sentinel (consumed per use): `printf 'model-routing plan: <what you are writing>' > .claude/.config-edit-ok`
- Agent frontmatter must stay `yaml.safe_load`-parseable (job9 gate): if a value contains `: `, quote it.
- Memory registries: append-only, caveman format, English.
- SPEC §5 (client-handover conversion) is DEFERRED to a separate plan — do NOT touch `agents/client-handover-writer.md` or `skills/client-handover/SKILL.md` in this plan.

---

### Task 1: `lib/model-check.sh` witness + flip-tests

**Files:**
- Create: `lib/model-check.sh`
- Test: `lib/tests/model-check.test.sh` (guarded path — sentinel required)

**Interfaces:**
- Consumes: `$HOME/.claude/settings.json` `"model"` key; env override `MODEL_CHECK_SETTINGS=<path>` for fixtures.
- Produces: stdout `<class>:<raw>` where class ∈ `big|small|unknown`; exit `0`=big, `2`=small, `3`=unknown. Task 2's `lib/model-gate.md` calls `bash "$HOME/.claude/lib/model-check.sh"` and branches on these exact codes.

- [ ] **Step 1: Write the failing test**

```bash
printf 'model-routing plan: create model-check flip-tests' > .claude/.config-edit-ok
```

Then create `lib/tests/model-check.test.sh` with exactly:

```bash
#!/usr/bin/env bash
# lib/tests/model-check.test.sh — flip-tests for lib/model-check.sh (LRN-096)
set -u
S="$(cd "$(dirname "$0")/../.." && pwd)/lib/model-check.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

fx()  { printf '{"model": "%s"}' "$1" > "$T/s.json"; }
run() { MODEL_CHECK_SETTINGS="$T/s.json" bash "$S" >"$T/out" 2>&1; echo "$?"; }

fx 'claude-fable-5[1m]';        check T1-fable-exit "$(run)" 0
check T1-fable-class "$(cut -d: -f1 <"$T/out")" big
fx 'claude-opus-4-8';           check T2-opus       "$(run)" 0
fx 'claude-sonnet-5';           check T3-sonnet     "$(run)" 2
fx 'claude-haiku-4-5-20251001'; check T4-haiku      "$(run)" 2
fx 'opusplan';                  check T5-opusplan   "$(run)" 3
fx 'gpt-9-mega';                check T6-foreign    "$(run)" 3
printf '{"no_model": true}' > "$T/s.json"; check T7-no-key    "$(run)" 3
printf '{broken'            > "$T/s.json"; check T8-malformed "$(run)" 3
check T9-missing-file "$(MODEL_CHECK_SETTINGS="$T/absent.json" bash "$S" >/dev/null 2>&1; echo $?)" 3

printf 'model-check: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash lib/tests/model-check.test.sh`
Expected: FAIL on every check (script missing → bash exits non-zero, got[127]-style mismatches), final line `model-check: 1 pass, 9 fail` or similar non-zero fail count, exit 1. (T1-fable-class may pass vacuously on empty output only if cut returns empty — any red is enough: the suite CAN fail.)

- [ ] **Step 3: Write the implementation**

Create `lib/model-check.sh` with exactly:

```bash
#!/usr/bin/env bash
# lib/model-check.sh — classify the persisted session model: big | small | unknown
#
# Witness for lib/model-gate.md (reflection requires a big model). Reads the
# "model" key of the user-scope settings (the file /model rewrites — LRN-098).
# Override the source with MODEL_CHECK_SETTINGS (tests use fixtures).
#
# stdout : <class>:<raw>   (raw = value found, empty if none)
# exit   : 0 = big (fable/opus) · 2 = small (sonnet/haiku) · 3 = unknown
set -u

SETTINGS="${MODEL_CHECK_SETTINGS:-$HOME/.claude/settings.json}"

raw=""
if [ -f "$SETTINGS" ]; then
  raw="$(python3 - "$SETTINGS" 2>/dev/null <<'PY'
import json, sys
try:
    v = json.load(open(sys.argv[1])).get("model", "")
    print(v if isinstance(v, str) else "")
except Exception:
    print("")
PY
)"
fi

norm="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
case "$norm" in
  *opusplan*)       printf 'unknown:%s\n' "$raw"; exit 3 ;; # opus-for-plan, sonnet otherwise — ambiguous
  *fable*|*opus*)   printf 'big:%s\n'     "$raw"; exit 0 ;;
  *sonnet*|*haiku*) printf 'small:%s\n'   "$raw"; exit 2 ;;
  *)                printf 'unknown:%s\n' "$raw"; exit 3 ;;
esac
```

(The heredoc passes the settings path as `sys.argv[1]` — never pipe INTO a heredoc'd interpreter, LRN-012.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bash lib/tests/model-check.test.sh`
Expected: `model-check: 10 pass, 0 fail`, exit 0.

- [ ] **Step 5: Lint**

Run: `shellcheck lib/model-check.sh lib/tests/model-check.test.sh && bash -n lib/model-check.sh`
Expected: no output (clean), exit 0.

- [ ] **Step 6: Full suite + commit**

Run: `make test`
Expected: every suite line green, exit 0.

```bash
git add lib/model-check.sh lib/tests/model-check.test.sh
git commit -m "feat(model-routing): model-check witness (big/small/unknown) + flip-tests"
```

---

### Task 2: `lib/model-gate.md` blocking include

**Files:**
- Create: `lib/model-gate.md`

**Interfaces:**
- Consumes: `lib/model-check.sh` exit codes (Task 1).
- Produces: the include that Tasks 3 and 5 reference verbatim as `` `$HOME/.claude/lib/model-gate.md` ``.

- [ ] **Step 1: Create the include**

Create `lib/model-gate.md` with exactly:

```markdown
# Model gate — reflection requires a big model (BLOCKING)

Shared include. Runs FIRST in any orchestrator whose reflection —
brainstorming, planning, contract, audit judgment, loop decisions —
executes inline or in inherit-model subagents. Sonnet-pinned executors are
not what this gate protects; it protects the thinking around them (BDR-066).

## 1. Self-check

Your system prompt names the model powering this session. Fable or Opus →
big. Sonnet, Haiku, anything else → small.

## 2. Witness — deterministic check

    bash "$HOME/.claude/lib/model-check.sh"

Output `<class>:<raw>`; exit 0 = big, 2 = small, 3 = unknown. The witness
reads the PERSISTED model (settings.json — the file `/model` rewrites,
LRN-098). It can lag reality (session launched with `--model`, settings not
yet rewritten) — that is why the self-check exists alongside it.

## 3. Verdict

| self-check | witness | action |
|---|---|---|
| big | big (0) | proceed, SILENT — the nominal path prints nothing |
| small | any | **STOP** |
| big | small (2) | disagreement — **STOP**, surface BOTH values; the user confirms or relaunches |
| big | unknown (3) | fail-visible: print `model gate: witness unknown (<raw>) — self-check says <model>` and ask the user to confirm before continuing (BDR-025: unknown never silently passes) |

**STOP means**: print exactly

    ⛔ MODEL GATE — session on <model>. Reflection steps of this skill
    require Fable or Opus. Switch with /model, then relaunch the skill.

then end the turn. No later step runs, no agent is dispatched, nothing is
edited.
```

- [ ] **Step 2: Commit**

```bash
git add lib/model-gate.md
git commit -m "feat(model-routing): blocking model-gate include (self-check + witness)"
```

---

### Task 3: Wire the gate into the 12 reflection orchestrators

**Files:**
- Modify: `skills/ship-feature/SKILL.md`, `skills/init-project/SKILL.md`, `skills/onboard/SKILL.md`, `skills/seo/SKILL.md`, `skills/geo/SKILL.md`, `skills/web-validate/SKILL.md`, `skills/harden/SKILL.md`, `skills/audit-delta/SKILL.md`, `skills/tour/SKILL.md` (orchestrator idiom), `skills/feat/SKILL.md`, `skills/bugfix/SKILL.md`, `skills/code-clean/SKILL.md` (thin-wrapper idiom)

**Interfaces:**
- Consumes: `lib/model-gate.md` (Task 2).
- Produces: the string `lib/model-gate.md` present in each of the 12 files — Task 8's census greps exactly this.

- [ ] **Step 1: Insert the orchestrator gate block (9 files)**

For each of the 9 orchestrator skills, Edit with `old_string` = the file's unique H1 line (below), `new_string` = the same H1 line followed by a blank line and this exact block:

```markdown
## MODEL GATE (blocking — run before any other step)

Run `$HOME/.claude/lib/model-gate.md`. Reflection here (planning, audit
judgment, loop decisions) requires Fable/Opus. Verdict `small` → STOP: the
gate prints the remedy; end the turn — no later step, no dispatch. Nominal
(big) path is silent.
```

H1 anchors (verbatim, one per file):
- `skills/ship-feature/SKILL.md` → `# ORCHESTRATOR: SHIP FEATURE`
- `skills/init-project/SKILL.md` → `# ORCHESTRATOR: INIT PROJECT`
- `skills/onboard/SKILL.md` → `# ORCHESTRATOR: ONBOARD`
- `skills/seo/SKILL.md` → `# /seo — parallel SEO + GEO dispatcher`
- `skills/geo/SKILL.md` → `# /geo — GEO (AI-search) audit + fix dispatcher`
- `skills/web-validate/SKILL.md` → `# /web-validate — web standards audit (W3C + WCAG)`
- `skills/harden/SKILL.md` → `# /harden — web hardening audit`
- `skills/audit-delta/SKILL.md` → `# /audit-delta — Incremental multi-axis code audit`
- `skills/tour/SKILL.md` → `# /tour — grouped multi-axis sweep (clean + security + reconcile + doc)`

- [ ] **Step 2: Insert the thin-wrapper gate paragraph (3 files)**

For `skills/feat/SKILL.md`, `skills/bugfix/SKILL.md`, `skills/code-clean/SKILL.md`: Edit with `old_string` = `Load and follow strictly:` and `new_string` =

```markdown
MODEL GATE (blocking): run `$HOME/.claude/lib/model-gate.md` BEFORE loading
the agent below. Verdict `small` → STOP — print the gate's remedy, end the
turn, do not load the agent.

Load and follow strictly:
```

(`Load and follow strictly:` occurs once per file — safe anchor.)

- [ ] **Step 3: Verify the wiring by census**

Run: `for s in ship-feature init-project feat bugfix onboard seo geo web-validate harden audit-delta tour code-clean; do grep -L 'lib/model-gate.md' "skills/$s/SKILL.md"; done`
Expected: no output (grep -L lists files MISSING the pattern — empty = all wired).

Run: `for s in hotfix commit-change doc status release-candidate; do grep -l 'lib/model-gate.md' "skills/$s/SKILL.md"; done`
Expected: no output (excluded skills stay unwired).

- [ ] **Step 4: Full suite + commit**

Run: `make test`
Expected: green, exit 0.

```bash
git add skills/ship-feature/SKILL.md skills/init-project/SKILL.md skills/onboard/SKILL.md skills/seo/SKILL.md skills/geo/SKILL.md skills/web-validate/SKILL.md skills/harden/SKILL.md skills/audit-delta/SKILL.md skills/tour/SKILL.md skills/feat/SKILL.md skills/bugfix/SKILL.md skills/code-clean/SKILL.md
git commit -m "feat(model-routing): wire blocking model gate into 12 reflection orchestrators"
```

---

### Task 4: Frontmatter pins — hotfixer sonnet, analyzer un-pinned

**Files:**
- Modify: `agents/hotfixer.md:1-5` (frontmatter)
- Modify: `agents/analyzer.md:1-7` (frontmatter)

**Interfaces:**
- Produces: `model: sonnet` line in hotfixer frontmatter (Task 7's applier dispatches and seo/geo L1 appliers ride on it); NO `model:` line in analyzer frontmatter (inherits session). Task 8's census greps both.

- [ ] **Step 1: Pin hotfixer**

Edit `agents/hotfixer.md`, `old_string`:

```
tools: Read, Edit, Write, Bash, Grep, Glob, Agent
---
```

`new_string`:

```
tools: Read, Edit, Write, Bash, Grep, Glob, Agent
model: sonnet
---
```

- [ ] **Step 2: Un-pin analyzer**

Edit `agents/analyzer.md`, `old_string`:

```
tools: Read, Grep, Glob, Bash
model: haiku
memory: project
```

`new_string`:

```
tools: Read, Grep, Glob, Bash
memory: project
```

- [ ] **Step 3: Verify YAML stays parseable**

Run: `python3 -c "import yaml,sys; [yaml.safe_load(open(f).read().split('---')[1]) for f in ['agents/hotfixer.md','agents/analyzer.md']]; print('YAML OK')"`
Expected: `YAML OK`.

- [ ] **Step 4: Full suite + commit**

Run: `make test`
Expected: green (includes the job9 review guards).

```bash
git add agents/hotfixer.md agents/analyzer.md
git commit -m "feat(model-routing): pin hotfixer sonnet (executor), un-pin analyzer (inherits session)"
```

---

### Task 5: `/feat` re-architecture — reflection inline, execution dispatched

**Files:**
- Modify (full rewrite): `skills/feat/SKILL.md`
- Modify (full rewrite): `agents/feater.md`
- Modify (3 surgical edits): `lib/verify-secure-loop.md`

**Interfaces:**
- Consumes: `lib/model-gate.md` (Task 2), `lib/verify-secure-loop.md`, `lib/contract-interview.md`, `lib/gitflow-aiguillage.md`, `lib/analyze-before-plan.md`, `lib/design-gate.md` (all existing).
- Produces: `Agent(subagent_type="feater")` dispatch in feat/SKILL.md; feater `FEAT-EXEC REPORT` grammar `STATUS : DONE | NEED-DECISION | BLOCKED`; `model: sonnet` in feater frontmatter. Task 8's census greps `subagent_type="feater"`, `verify-secure-loop.md`, feater `model: sonnet`, feater has NO `AskUserQuestion`.

- [ ] **Step 1: Rewrite `skills/feat/SKILL.md`**

Replace the ENTIRE file content with:

````markdown
---
name: feat
description: |
  Small feature implementation (1-5 files). Reflection inline (scope,
  plan, contract — session model), execution dispatched to the
  sonnet-pinned feater executor. For features that don't need the full
  /ship-feature pipeline (no design brainstorm, no plugin check gate).
  Trigger: "feat", "small feature", "add this", "petite feature",
  "quick feature", "ajoute ca", "implement this small thing".
  For multi-file features needing design → use /ship-feature.
  For bug fixes → use /hotfix or /bugfix.
argument-hint: <feature description>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
---

# /feat — small-feature orchestrator (reflection inline, execution dispatched)

MODEL GATE (blocking): run `$HOME/.claude/lib/model-gate.md` BEFORE any
step below. Verdict `small` → STOP — print the gate's remedy, end the
turn, dispatch nothing.

## REQUEST
$ARGUMENTS

---

## STEP 0 — SCOPE CHECK

Before starting, verify this is actually a small feature:

```bash
git status
git log --oneline -3
```

Read the relevant existing code to understand the context.

### Decision rules (apply in order — first match wins)

| Rule | Trigger | Action |
|---|---|---|
| 1 | Estimated diff < 2 files AND no logic (config value, copy fix, missing field) | DOWNGRADE → load `$HOME/.claude/agents/hotfixer.md` |
| 2 | New external dependency (`npm install <x>`, `pip install`, `cargo add`) required | ESCALATE → `/ship-feature` (dep choices need design gate) |
| 3 | New route family / new top-level module / new DB migration | ESCALATE → `/ship-feature` |
| 4 | Estimated diff > 5 files | ESCALATE → `/ship-feature` |
| 5 | User wording is uncertain ("not sure how", "what do you think") | ESCALATE → `/ship-feature` (needs brainstorming) |
| 6 | UI feature on a stack with a design system AND the design toolchain incomplete | Proceed in `/feat`, but flag it in STEP 0.5 design gate |
| 7 | Otherwise | PROCEED in `/feat` |

### Worked examples

- "Add `/health` endpoint returning `{status:"ok",version}`" → 1-2 files, no new dep, route added to existing router → **PROCEED**.
- "Add a dark-mode toggle bound to `prefers-color-scheme`" → 2-3 files, design system exists → **PROCEED** (design gate triggers in STEP 0.5).
- "Add OAuth login (Google + GitHub providers)" → new deps, new routes, secrets handling → **ESCALATE** to `/ship-feature`.
- "Show a 'New' badge on items created this week" → 1-2 files, pure UI predicate → **PROCEED**.
- "Fix copy: 'Sign In' → 'Sign in'" in 1 file → **DOWNGRADE** to `/hotfix`.

Print a one-line scope confirmation (use the rule that fired):
```
FEAT: <feature name> — rule <N>, ~<N> files, <brief approach>
```

## STEP 0.5 — DESIGN GATE

Follow `$HOME/.claude/lib/design-gate.md`:
- Scan $ARGUMENTS and target files for design/UI/style signals.
- If signals found → run `design-tool-gate.sh`; if it reports INCOMPLETE,
  tell the user to run `/profile design` before proceeding.
- If no signals → skip (zero overhead).

## STEP 0.6 — MEMORY READ-BEFORE (decisions-first)

Run the scan per `$HOME/.claude/lib/analyze-before-plan.md`, decisions-weighted: a BDR may
already constrain or forbid the approach; an LRN may name a gotcha to apply. Emit RELATED
MEMORY; feed STEP 1 PLAN. Inline consumption — reader = planner, no injection.
`.claude/memory/` absent → guarded no-op (zero overhead on a memory-less repo).

## STEP 0.7 — CONTRACT

Run `$HOME/.claude/lib/contract-interview.md` (main loop — you are it). It
captures the request verbatim, asks 0-3 questions PROPORTIONAL to ambiguity
(a complete request → zero questions, silent), derives testable acceptance
criteria + file scope, and writes the contract to
`.claude/tasks/contracts/<date>-<slug>-<HHMM>.md`. Keep the path — the
executor reads it first and GATE 1 (STEP 4) hands it to a fresh verifier.

## STEP 1 — PLAN (dispatch-ready)

The executor follows this plan to the letter and CANNOT ask questions —
close every decision here:

1. Files to create or modify (with line references).
2. Approach in 2-5 bullets — name every choice (naming, data shape, API
   surface); an open choice left here comes back as a NEED-DECISION
   round-trip.
3. Edge cases to handle.
4. Tests to add/update (exact files).
5. Disposition (from STEP 0.6): name each in-force BDR/LRN this plan honors
   (`honors BDR-xxx by …`), or state `no in-force decision constrains this feature`.
   A plan with neither = read-then-ignore; the disposition must surface as a trace.

Print the plan as a compact checklist:
```
PLAN:
  [ ] <file> — <what to do>
  [ ] <file> — <what to do>
  [ ] <test file> — <test to add>
```

If the approach is ambiguous: ask the user ONE focused question BEFORE
dispatching — never after (the executor cannot relay questions).

## STEP 2 — BRANCH

**Gitflow aiguillage (before dispatch):** follow `$HOME/.claude/lib/gitflow-aiguillage.md`
— your type = `feature`. On `main`/`develop` it branches first; on a working
branch it's a no-op (commit in place). Never `finish`.

## STEP 3 — DISPATCH EXECUTOR

Dispatch the executor — sonnet by frontmatter pin, do not override:

```
Agent(subagent_type="feater")
prompt: "CONTRACT: <path from STEP 0.7>
PLAN: <the STEP 1 checklist + approach bullets + edge cases, verbatim>
BRANCH: <current branch — verify with git branch --show-current, never switch>
Implement the plan to the letter. Tests alongside code. No commit, no
branch ops, no new dependencies, no files outside the contract FILE SCOPE.
Finish with the FEAT-EXEC REPORT."
```

Parse the `FEAT-EXEC REPORT`:
- `STATUS : DONE` → STEP 4.
- `STATUS : NEED-DECISION` → make the decision HERE (that is reflection),
  append it to the plan, re-dispatch a FRESH feater with plan + decision.
  Max 2 decision round-trips → escalate to the user.
- `STATUS : BLOCKED` → surface the blocker to the user, stop.

## STEP 4 — VERIFY + SECURE (fresh gates, bounded loops)

Run the two fresh gates per `$HOME/.claude/lib/verify-secure-loop.md` with
`CONTRACT` = the STEP 0.7 path, `DIFF` = the working-tree diff the executor
produced, `TEST` = the suite named in its report:

- GATE 1 — a FRESH verifier judges the diff against the contract (blind).
  CONFORME on the first pass → straight to GATE 2, no loop. ECARTS → the
  "dev" of the loop is the dispatched executor: re-dispatch a FRESH feater
  with the CONTRACT path + the exact gap lines, nothing else. Max 3 →
  escalate.
- GATE 2 — a FRESH security-auditor (`MODE: gate`) scans the diff. PASS →
  STEP 5. BLOCK → re-dispatch a FRESH feater with the BLOCKING list + the
  CONTRACT path; re-verify the request THEN re-scan, max 3 → escalate.

Loop decisions stay HERE, in the main loop (LRN-083). Nominal (clear
request, conform first pass, clean diff) = one executor + one verifier +
one security dispatch.

## STEP 5 — COMMIT

Commit using conventional format:
```
feat(<scope>): <what was added>

<brief description of the feature>
```

If the feature touched multiple concerns (e.g., feature + config +
test), consider splitting into 2-3 atomic commits — load
`$HOME/.claude/agents/commit-changer.md` and follow its grouping logic.

Print summary:
```
FEAT COMPLETE
FEATURE  : <name>
FILE(S)  : <created/modified files>
TEST(S)  : <added tests>
VERIFIED : <what was checked>
```

## STEP 6 — DOC SYNC (automatic)

Load `$HOME/.claude/agents/doc-syncer.md`.
Execute in automatic mode:
`auto-mode scope: <list of files modified during this session>`

**Then commit the docs** — follow `$HOME/.claude/lib/doc-commit.md`: it surgically commits
ONLY the files doc-syncer patched (its `PATCHED_FILES` output), never `git add -A`, never
`.claude/`/`CLAUDE.md` (rc 4 = a loud BDR-022 anomaly, not a silent skip), and no-ops when
nothing was patched — the common case for a trivial change. No FINISH in an inline flow, so
it just commits the docs on the current branch (no ordering concern).

## STEP 7 — CAPITALIZE (memory registries)

A small feature may or may not involve a design choice. Scan the work for:

- **Non-trivial design choice** (even small: a library pick, a naming convention, a data-model tradeoff) → propose `BDR-XXX` in `.claude/memory/decisions.md` with alternatives considered.
- **Reusable pattern or gotcha encountered** → propose `LRN-XXX` in `.claude/memory/learnings.md`.

Present the candidates grouped:
```
CAPITALIZE — proposé
  [decisions.md]   BDR-XXX — <titre> (optionnel)
  [learnings.md]   LRN-XXX — <pattern> (optionnel)
Valider ? (all / <IDs> / edit / skip)
```

Always append a 1-line entry to today's heading in `.claude/memory/journal.md`.

**Language rule**: written entries are ALWAYS in English (see CLAUDE.md "Memory registries" § Language). The interactive gate may mirror the user's language; the appended entries must not.

If no substantive capture candidate → skip with `CAPITALIZE: nothing to log`.

**Then commit the memory** — follow `$HOME/.claude/lib/capitalize-commit.md`: it
surgically commits what capitalize just wrote (`.claude/memory` + `.claude/tasks`
only, never `git add -A`) as one `chore(memory)` commit, reports the memory-commit
hash, and no-ops if nothing was written.

---

## RULES
- Max 5 files. If more needed → `/ship-feature`.
- Reflection (scope, plan, contract, loop decisions) NEVER leaves this main
  loop; execution NEVER stays in it — the executor is the sonnet-pinned
  feater subagent (BDR-066).
- The executor is dispatched FRESH on every round-trip — feedback travels
  as contract path + named gaps/decisions, never as transcript.
- Design gate only (not full plugin check). See STEP 0.5.
- No brainstorm/design phase (if needed → `/ship-feature`).
- Keep scope tight. If scope creep happens mid-work, stop
  and suggest splitting into `/feat` + follow-up task.
- Follow existing code patterns. Don't introduce new patterns
  for a small feature.
````

(Note: this rewrite REPLACES the Task 3 thin-wrapper gate paragraph for feat — the gate line is now native under the H1. The census greps `lib/model-gate.md`, satisfied either way.)

- [ ] **Step 2: Rewrite `agents/feater.md`**

Replace the ENTIRE file content with:

````markdown
---
name: feater
description: Small-feature EXECUTOR — dispatched by /feat with a closed plan + contract. Implements to the letter, tests, reports. No planning, no questions, no commit.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
---

# FEATER — plan executor

You receive a CLOSED plan from the /feat orchestrator. Your job is faithful
execution, not design. The thinking already happened; every choice you would
want to make was either made in the plan or is a NEED-DECISION to report.

## INPUT (in the dispatch prompt)

- `CONTRACT`: path to the contract file — read it FIRST; its acceptance
  criteria + FILE SCOPE bound everything you do.
- `PLAN`: files + approach + edge cases + tests.
- `BRANCH`: verify with `git branch --show-current`; mismatch → STATUS
  BLOCKED — never create or switch branches.
- `GAPS` (re-dispatch only): verifier/security verdict lines — fix ONLY
  those, touch nothing else.

## EXECUTION RULES

- Follow the plan to the letter. A plan hole or an open choice (naming,
  data shape, API surface, dependency) → STOP, report `NEED-DECISION` with
  the precise question. Never improvise a design decision.
- Stay inside the contract FILE SCOPE. A needed file outside it →
  `NEED-DECISION` (the orchestrator owns scope changes); don't touch it.
- Write tests alongside the code, as the plan names them. Run the relevant
  suite incrementally; run it fully before reporting.
- Follow existing code patterns and CLAUDE.md limits (function size,
  params, no global state). Match comment density and naming.
- FORBIDDEN: `git commit`, branch ops, push, merge, new dependencies,
  editing `.claude/**` or memory registries, user questions (you cannot
  ask — report instead), attribution trailers of any kind.

## OUTPUT — end with exactly this report (your final message)

```
FEAT-EXEC REPORT
STATUS   : DONE | NEED-DECISION | BLOCKED
FILES    : <created/modified paths>
TESTS    : <added/updated + final suite run result, verbatim line>
NOTES    : <DONE: deviations (must be none) | NEED-DECISION: the exact
           question + the options you see | BLOCKED: the blocker verbatim>
```
````

- [ ] **Step 3: Update `lib/verify-secure-loop.md` (3 surgical edits)**

Edit 1 — header, `old_string`:

```
finished diff into a verified, security-cleared change through two fresh
gates and bounded loops. The dev stays inline (LRN-083: subagents =
execution + report; loop decisions live here, in the main loop).
```

`new_string`:

```
finished diff into a verified, security-cleared change through two fresh
gates and bounded loops. Loop decisions live here, in the main loop
(LRN-083: subagents = execution + report). The dev step is either inline
(bugfix) or a dispatched sonnet executor (/feat's feater): "hand the dev"
below means fix inline, or re-dispatch a FRESH executor with exactly those
inputs.
```

Edit 2 — GATE 1 ECARTS bullet, `old_string`:

```
  lines (NOT-MET / out-of-scope), nothing else. Dev fixes inline, then
  re-dispatch a FRESH verifier.
```

`new_string`:

```
  lines (NOT-MET / out-of-scope), nothing else. Inline dev fixes in place;
  a dispatched dev is re-dispatched FRESH with those inputs only. Then
  re-dispatch a FRESH verifier.
```

Edit 3 — GATE 2 BLOCK bullet, `old_string`:

```
- `BLOCK(n)` → hand the dev the `BLOCKING` list + the CONTRACT path. Dev
  fixes inline. Then **re-verify the REQUEST first** (GATE 1, fresh
```

`new_string`:

```
- `BLOCK(n)` → hand the dev the `BLOCKING` list + the CONTRACT path (inline
  fix, or FRESH executor re-dispatch). Then **re-verify the REQUEST first** (GATE 1, fresh
```

- [ ] **Step 4: Structural verification**

Run: `grep -c 'subagent_type="feater"' skills/feat/SKILL.md; grep -c 'verify-secure-loop.md' skills/feat/SKILL.md; grep -c 'model: sonnet' agents/feater.md; grep -c 'tools: Read, Edit, Write, Bash, Grep, Glob$' agents/feater.md; grep -c 'AskUserQuestion' agents/feater.md; true`
Expected: `1` / `1` (or more) / `1` / `1` (exact tools line — no Agent tool) / `0` (no AskUserQuestion anywhere).

Run: `python3 -c "import yaml; yaml.safe_load(open('agents/feater.md').read().split('---')[1]); print('YAML OK')"`
Expected: `YAML OK`.

- [ ] **Step 5: Full suite + commit**

Run: `make test`
Expected: green.

```bash
git add skills/feat/SKILL.md agents/feater.md lib/verify-secure-loop.md
git commit -m "feat(model-routing): /feat re-architecture — reflection inline, feater = sonnet executor (partial supersede BDR-050)"
```

---

### Task 6: Pin SDD implementation subagents to sonnet (ship-feature, init-project)

**Files:**
- Modify: `skills/ship-feature/SKILL.md:144-148`
- Modify: `skills/init-project/SKILL.md:166-170`

**Interfaces:**
- Produces: the literal `model: "sonnet"` in both files — Task 8's census greps it.

- [ ] **Step 1: ship-feature STEP 4**

Edit `skills/ship-feature/SKILL.md`, `old_string`:

```
`finishing-a-development-branch` step — this orchestrator owns integration via
`gitflow finish` (STEP 9). When SDD's flow reaches "Use
finishing-a-development-branch", stop and return.
```

`new_string`:

```
`finishing-a-development-branch` step — this orchestrator owns integration via
`gitflow finish` (STEP 9). When SDD's flow reaches "Use
finishing-a-development-branch", stop and return.

**Model routing (BDR-066):** every subagent dispatched under SDD — per-task
implementers AND its reviewers — MUST carry `model: "sonnet"` in the Agent
call. The plan is closed; execution and plan-conformity review are sonnet
work. Reflection (task decomposition, review verdict arbitration) stays in
this loop.
```

- [ ] **Step 2: init-project STEP 8**

Edit `skills/init-project/SKILL.md`, `old_string`:

```
`finishing-a-development-branch` step — this orchestrator owns integration via
`gitflow finish` (STEP 11). When SDD's flow reaches "Use
finishing-a-development-branch", stop and return.
```

`new_string`:

```
`finishing-a-development-branch` step — this orchestrator owns integration via
`gitflow finish` (STEP 11). When SDD's flow reaches "Use
finishing-a-development-branch", stop and return.

**Model routing (BDR-066):** every subagent dispatched under SDD — per-task
implementers AND its reviewers — MUST carry `model: "sonnet"` in the Agent
call. The plan is closed; execution and plan-conformity review are sonnet
work. Reflection (task decomposition, review verdict arbitration) stays in
this loop.
```

- [ ] **Step 3: Verify + commit**

Run: `grep -c 'model: "sonnet"' skills/ship-feature/SKILL.md skills/init-project/SKILL.md`
Expected: `1` for each file.

Run: `make test` — Expected: green.

```bash
git add skills/ship-feature/SKILL.md skills/init-project/SKILL.md
git commit -m "feat(model-routing): SDD implementation + review subagents dispatched model sonnet"
```

---

### Task 7: web-validate fixes via hotfixer L1 applier

**Files:**
- Modify: `skills/web-validate/SKILL.md:274-277` (STEP 3, options A and B)

**Interfaces:**
- Consumes: hotfixer sonnet pin (Task 4); mirrors the geo L1 applier idiom (`skills/geo/SKILL.md:72-77`).
- Produces: `subagent_type="hotfixer"` in web-validate — Task 8's census greps it.

- [ ] **Step 1: Replace inline-Edit application with L1 dispatch**

Edit `skills/web-validate/SKILL.md`, `old_string`:

```
4. On `A` : apply each bundle via `Edit` (targeted `old_string` /
   `new_string`). Never use `Write` on shared templates (risk of
   overwriting /seo or /geo content — meta tags, JSON-LD).
5. On `B` : for each diff, show and ask yes/no/skip.
```

`new_string`:

````
4. On `A` : dispatch each file-group's applier at L1 (execution = sonnet;
   this loop only orchestrates), serially — one applier at a time, appliers
   share files:

   ```
   Agent(subagent_type="hotfixer")
   prompt: "<paste the file-group's bundle items: file, issue, current,
     expected fix>.
     Context: web-validate fix bundle, user-approved scope — no
     confirmation needed. Apply via targeted Edit (old_string/new_string);
     NEVER Write whole files (shared templates carry /seo and /geo
     content — meta tags, JSON-LD). Do NOT commit — apply and self-verify
     only."
   ```

5. On `B` : for each diff, show and ask yes/no/skip; apply approved diffs
   as in `A` (hotfixer dispatch).
````

- [ ] **Step 2: Verify + commit**

Run: `grep -c 'subagent_type="hotfixer"' skills/web-validate/SKILL.md`
Expected: `1`.

Run: `make test` — Expected: green.

```bash
git add skills/web-validate/SKILL.md
git commit -m "feat(model-routing): web-validate fix bundle applied via hotfixer at L1 (BDR-061 alignment)"
```

---

### Task 8: Census guard `lib/tests/model-routing.test.sh` + flip-test

**Files:**
- Test: `lib/tests/model-routing.test.sh` (guarded path — sentinel required)

**Interfaces:**
- Consumes: every string produced by Tasks 3-7 (see greps below). Auto-discovered by the Makefile `test` glob `lib/tests/*.test.sh` — no runner edit needed.

- [ ] **Step 1: Write the census test**

```bash
printf 'model-routing plan: add census guard test' > .claude/.config-edit-ok
```

Then create `lib/tests/model-routing.test.sh` with exactly:

```bash
#!/usr/bin/env bash
# lib/tests/model-routing.test.sh — census: gate wiring + pins + executor shape (BDR-066)
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
lacks() { if grep -qF "$2" "$R/$1"; then ko "$1 must NOT contain: $2"; else ok; fi; }
fm_lacks() { if awk 'NR<=10' "$R/$1" | grep -qF "$2"; then ko "$1 frontmatter must NOT contain: $2"; else ok; fi; }

# 1) gate wired in the 12 reflection orchestrators
for s in ship-feature init-project feat bugfix onboard seo geo web-validate harden audit-delta tour code-clean; do
  has "skills/$s/SKILL.md" 'lib/model-gate.md'
done
# 2) gate NOT wired in the excluded skills (encodes the spec exclusion list)
for s in hotfix commit-change doc status release-candidate; do
  lacks "skills/$s/SKILL.md" 'lib/model-gate.md'
done
# 3) executor + gate pins
has "agents/feater.md"          'model: sonnet'
has "agents/hotfixer.md"        'model: sonnet'
has "agents/verifier.md"        'model: sonnet'
has "agents/security-auditor.md" 'model: sonnet'
fm_lacks "agents/analyzer.md"   'model:'
# 4) /feat executor shape
has "skills/feat/SKILL.md" 'subagent_type="feater"'
has "skills/feat/SKILL.md" 'verify-secure-loop.md'
lacks "agents/feater.md" 'AskUserQuestion'
# 5) SDD execution pinned
has "skills/ship-feature/SKILL.md" 'model: "sonnet"'
has "skills/init-project/SKILL.md" 'model: "sonnet"'
# 6) web-validate applies via L1 applier
has "skills/web-validate/SKILL.md" 'subagent_type="hotfixer"'

printf 'model-routing census: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run — expect green (everything already wired by Tasks 3-7)**

Run: `bash lib/tests/model-routing.test.sh`
Expected: `model-routing census: 28 pass, 0 fail`, exit 0. (Count: 12 wired + 5 excluded + 5 pins + 3 feat-shape + 2 SDD + 1 web-validate.)

- [ ] **Step 3: Flip-test the guard (LRN-096 — prove it CAN fail)**

```bash
sed -i 's|lib/model-gate.md|lib/model-gate-REMOVED.md|' skills/tour/SKILL.md
bash lib/tests/model-routing.test.sh; echo "exit=$?"
git checkout -- skills/tour/SKILL.md
bash lib/tests/model-routing.test.sh; echo "exit=$?"
```

Expected: first run prints `FAIL skills/tour/SKILL.md missing: lib/model-gate.md` and `exit=1`; second run prints `28 pass, 0 fail` and `exit=0`.

- [ ] **Step 4: Lint + full suite + commit**

Run: `shellcheck lib/tests/model-routing.test.sh && make test`
Expected: clean + green.

```bash
git add lib/tests/model-routing.test.sh
git commit -m "test(model-routing): census guard — gate wiring, pins, executor shape (flip-tested)"
```

---

### Task 9: README + CHANGELOG

**Files:**
- Modify: `README.md` (agent/model documentation)
- Modify: `CHANGELOG.md` (Unreleased section)

- [ ] **Step 1: Locate the README insertion point**

Run: `grep -niE 'agents?/|sonnet|haiku|model' README.md | head -20`

If README has a table listing agents (a row per agent), refresh/add its model info from the table below. If not, insert a new subsection `### Agent model routing (BDR-066)` immediately after the section that documents `agents/` (fallback: before the "Skills" section), with exactly:

```markdown
### Agent model routing (BDR-066)

Reflection (brainstorm, plan, contract, audit judgment, loop decisions) runs
INLINE on the session model — assumed Fable/Opus, enforced by a blocking
gate (`lib/model-gate.md` + `lib/model-check.sh`) at the entry of the 12
reflection orchestrators. Execution runs on pinned subagents:

| Agent | Model | Tier |
|---|---|---|
| feater, hotfixer | sonnet (pinned) | executors — code from a closed plan, fix-bundle appliers |
| verifier, security-auditor | sonnet (pinned) | fresh gates (≤3×/loop) |
| doc-syncer, onboarder, scaffolder, refactorer, interviewer, plugin-advisor | sonnet (pinned) | workers |
| status-reporter | haiku (pinned) | mechanical collector |
| client-handover-writer | opus (pinned, currently inert — inline-loaded; sonnet conversion planned) | deliverable writer |
| analyzer, seo-analyzer, geo-analyzer, validator-analyzer, code-cleaner, bugfixer, commit-changer | inherit session (Fable/Opus) | reflection / audit / inline playbooks |
```

- [ ] **Step 2: CHANGELOG**

Run: `grep -n 'Unreleased' CHANGELOG.md`

Under the `## [Unreleased]` heading (create `### Added` / `### Changed` subsections if absent), add:

```markdown
### Added
- Model routing (BDR-066): blocking model gate (`lib/model-gate.md` +
  `lib/model-check.sh`, flip-tested) wired into 12 reflection orchestrators;
  census guard `lib/tests/model-routing.test.sh`.
- `/feat` re-architected: reflection inline (scope/plan/contract), execution
  dispatched to the sonnet-pinned `feater` executor; verify+secure loop
  decided in the main loop with fresh executor re-dispatches.

### Changed
- `hotfixer` pinned `model: sonnet` (seo/geo/web-validate L1 applier);
  `analyzer` haiku pin removed (inherits the session model).
- ship-feature / init-project: SDD implementation + review subagents
  dispatched with `model: "sonnet"`.
- web-validate `--fix`: bundle applied via `hotfixer` at L1 instead of
  inline Edit (BDR-061 alignment).
```

- [ ] **Step 3: Commit**

Run: `make test` — Expected: green.

```bash
git add README.md CHANGELOG.md
git commit -m "docs(model-routing): README agent-model table + CHANGELOG entry"
```

---

### Task 10: Capitalize memory + TODO follow-up

**Files:**
- Modify: `.claude/memory/decisions.md` (append BDR-066 + Index row)
- Modify: `.claude/memory/journal.md` (1 line under a `## 2026-07-15` heading)
- Modify: `.claude/tasks/TODO.md` (chantier section + plan-2 backlog)

- [ ] **Step 1: Append BDR-066 to `.claude/memory/decisions.md`**

Add to the Index table (after the BDR-065 row):

```markdown
| BDR-066 | 2026-07-15 | Model routing: reflection inline (session big model) + sonnet-pinned executors + blocking gate | accepted |
```

Append at end of file:

```markdown
## BDR-066 — Model routing: reflection inline (session big model), executors pinned sonnet, blocking gate

- **Date**: 2026-07-15
- **Status**: accepted (partial supersede of BDR-050: /feat dev no longer inline; bugfix/hotfix dev-inline CONSERVED)
- **Decision**: reflection (brainstorm, plan, contract, audit judgment, loop decisions) runs on session model (Fable; Opus fallback) — inline or inherit subagents, never pinned down. Execution (code from closed plan, fix-bundle application) runs sonnet-pinned subagents: feater + hotfixer pinned sonnet; SDD implementation+review subagents dispatched `model: "sonnet"` (ship-feature/init-project); web-validate fixes via hotfixer L1 (was inline Edit). analyzer haiku pin REMOVED (digest feeds plan = reflection tier). verifier + security-auditor STAY sonnet (job9 confirmed — procedural gates, ≤3×/loop). Blocking gate `lib/model-gate.md` (self-check + witness `lib/model-check.sh`) wired in 12 reflection orchestrators; small → STOP, unknown → fail-visible; census guard `lib/tests/model-routing.test.sh` flip-tested.
- **Why**: big-model quota burned on mechanical execution (Fable exhausted mid-job8); plan closed at dispatch → executor needs obedience not judgment; fresh sonnet gates catch executor drift.
- **Alternatives rejected**: opus pins on audit agents (session-independent) — rejected: session assumed big + blocking gate as backstop, one tier fewer; advisory gate — rejected by user, blocking; split bugfix/hotfix too — rejected: bugfix investigation interleaved w/ fix, hotfix gain marginal vs dispatch overhead.
- **Caveats**: client-handover-writer conversion (inline-load → sonnet dispatch, 11 human-gate sites to relocate) DEFERRED to own plan — its opus pin stays inert meanwhile; feater cannot ask → NEED-DECISION report = escalation valve, plan must close decisions; witness reads settings.json — lags `--model`-launched sessions (self-check compensates).
- **Reference**: spec `docs/superpowers/specs/2026-07-15-model-routing-design.md` + plan `docs/superpowers/plans/2026-07-15-model-routing.md` (transient, BDR-065 lifecycle), branch `feature/model-routing`.
```

- [ ] **Step 2: Journal line**

Append under a `## 2026-07-15` heading (create it if absent) in `.claude/memory/journal.md`:

```markdown
- model routing shipped on feature/model-routing: BDR-066 (reflection inline big / executors sonnet / blocking gate), /feat re-arch, census guard. client-handover conversion deferred to plan 2.
```

- [ ] **Step 3: TODO follow-up entry**

Add at the top of `.claude/tasks/TODO.md` (above the 2026-07-08 section):

```markdown
## 2026-07-15 — model routing (feature/model-routing)
Spec + plan in docs/superpowers/ (transient, BDR-065). BDR-066. Branch
unmerged — human gate.
- [x] gate lib/model-check.sh + lib/model-gate.md (flip-tested) wired ×12
- [x] pins: hotfixer/feater sonnet, analyzer un-pinned; SDD model:"sonnet";
      web-validate → hotfixer L1; census guard model-routing.test.sh
- [x] /feat re-arch: reflection inline → feater sonnet executor (partial
      supersede BDR-050)
- [ ] DOGFOOD (manual, next sessions): /feat live run — plan closes
      decisions, dispatch carries sonnet, verify loop in main loop; gate
      STOP on a sonnet session (LRN-079 class, not automatable here)
- [ ] PLAN 2 — client-handover conversion (spec §5): inline-load → sonnet
      dispatch, relocate 11 human-gate sites to dispatcher (inventory in
      plan-1 session), or lighter variant: dispatch only the redaction
      phase. Decide shape at plan time.
```

- [ ] **Step 4: Commit memory scoped**

```bash
git add .claude/memory/decisions.md .claude/memory/journal.md .claude/tasks/TODO.md
git commit -m "chore(memory): BDR-066 model routing + journal + TODO follow-ups"
```

- [ ] **Step 5: Final gate**

Run: `make test`
Expected: green, exit 0. Then report the full commit list (`git log --oneline develop..HEAD`) for the human merge gate. Do NOT run `gitflow finish`.

---

# WAVE 2 — pure-execution + reflection-split skills (user directive 2026-07-15)

The wave-1 exclusion list left `hotfix, commit-change, doc, status, release-candidate`
inheriting the session model — i.e. running EXECUTION on the big model, the
waste the split exists to kill. User verdicts (2026-07-15):
- **doc / status** = pure non-interactive execution → convert inline-load to a
  dispatched subagent so its pin takes effect. doc-syncer stays sonnet;
  status-reporter stays **haiku** (right tier for a read-only collector; the
  win is getting it off the big model, not the tier).
- **hotfix** = reflection (locate root cause + propose fix) + execution → split
  like /feat: reflection inline (+ MODEL GATE), execution dispatched to the
  sonnet hotfixer executor. hotfix JOINS the gated group (12→13).
- **commit-change** = grouping (judgment) + committing (execution), interactive
  → dispatch EVERYTHING (grouping included) to a sonnet commit-changer, relocate
  the two approval gates to the dispatcher (propose→confirm→execute, seo-applier
  shape). No MODEL GATE (no inline reflection — grouping runs on sonnet).
- **release-candidate** = create a sonnet `release-executor` agent for the
  mechanical spans (version.txt, CHANGELOG rewrite, gitflow start/finish, tag),
  relocate the two human gates (when-to-release, push) to the dispatcher. No
  MODEL GATE (user's explicit choice — force dispatch, not gate).

Post-wave-2 gate exclusion list = `commit-change, doc, status, release-candidate`
(hotfix removed — now wired).

## Global Constraints (wave 2)

Same as wave 1: branch `feature/model-routing`, no merge, no attribution
trailers, `make test` green per commit, shellcheck clean, config-protection
sentinel before each `lib/tests/*` write, YAML `safe_load`-parseable frontmatter.

---

### Task 11: doc + status → dispatched execution

**Files:**
- Modify: `skills/doc/SKILL.md` (add `Agent` to allowed-tools; body → dispatch)
- Modify: `skills/status/SKILL.md` (add `Agent` to allowed-tools; body → dispatch)

**Interfaces:** doc-syncer.md is already `model: sonnet`; status-reporter.md is
already `model: haiku` — no agent edits. Only the skills change from inline-load
to `Agent(subagent_type=…)` so the pins take effect.

- [ ] **Step 1: doc → dispatch.** In `skills/doc/SKILL.md`, add `  - Agent` to the
  `allowed-tools` list, and replace the body block
  ```
  Load and follow strictly:
  - $HOME/.claude/agents/doc-syncer.md

  Execute the DOC SYNCER on this project.

  Context from the user (if any):
  $ARGUMENTS
  ```
  with:
  ```
  Dispatch the doc-syncer as a subagent so its `model: sonnet` pin takes
  effect (doc-sync = execution, not the session's big model):

  Agent(subagent_type="doc-syncer")
  prompt: "Audit + sync public docs for this project. Context from the user:
    $ARGUMENTS. Report PATCHED_FILES and a summary — do NOT commit."

  Then commit the patched docs from THIS loop per `$HOME/.claude/lib/doc-commit.md`
  (surgical: only doc-syncer's PATCHED_FILES, never `.claude/`/`CLAUDE.md`,
  no-op if nothing patched).
  ```

- [ ] **Step 2: status → dispatch.** In `skills/status/SKILL.md`, add `Agent` to
  `allowed-tools` (`Read, Bash, Glob, Grep, Agent`), and replace the body
  `Load and follow strictly:\n- $HOME/.claude/agents/status-reporter.md\n\nProduce the full PROJECT STATUS report for the current working directory.`
  with a dispatch:
  ```
  Dispatch the status-reporter as a subagent so its `model: haiku` pin takes
  effect (read-only collection = cheapest tier, off the big session model):

  Agent(subagent_type="status-reporter")
  prompt: "Produce the full PROJECT STATUS report for the current working
    directory. $ARGUMENTS"
  ```
  Keep the existing "Fallback when agent file missing" section intact (it still
  applies — if the dispatch target is unreachable, emit the missing-agent line
  and STOP).

- [ ] **Step 3: Verify + commit.** `grep -c 'subagent_type="doc-syncer"' skills/doc/SKILL.md`
  → 1; `grep -c 'subagent_type="status-reporter"' skills/status/SKILL.md` → 1.
  `make test` green.
  ```bash
  git add skills/doc/SKILL.md skills/status/SKILL.md
  git commit -m "feat(model-routing): doc/status dispatch their agent (sonnet/haiku pins take effect)"
  ```

---

### Task 12: hotfix — reflection inline + dispatched sonnet executor (/feat pattern)

**Files:**
- Modify (rewrite): `skills/hotfix/SKILL.md` — becomes the reflection orchestrator
- Modify (rewrite): `agents/hotfixer.md` — becomes pure executor
- Modify: `lib/tests/loops-light.test.sh` — repoint hotfix structure locks (guarded)

**Pattern:** mirror the shipped `/feat` split (skills/feat/SKILL.md + agents/feater.md).

- [ ] **Step 1: Rewrite `skills/hotfix/SKILL.md` as the orchestrator.** Keep `Agent`
  in allowed-tools. Structure:
  - `# /hotfix — quick-fix orchestrator (reflection inline, execution dispatched)`
  - `MODEL GATE (blocking): run $HOME/.claude/lib/model-gate.md BEFORE any step. small → STOP.`
    (hotfix now has a reflection phase → it joins the gated group.)
  - STEP 1 LOCATE (reflection, inline): find the bug from the description, read
    the file(s), CONFIRM the root cause is obvious/superficial, escalate to
    `/bugfix` if deeper. Optional blockers-only memory glance (as today).
  - STEP 1.5 DESIGN GATE (`lib/design-gate.md`, as today).
  - STEP 1.7 CONTRACT (silent autofill, `lib/contract-interview.md`, zero
    questions, as today).
  - STEP 2 PRE-FLIGHT (inline): gitflow aiguillage (type `hotfix`); snapshot
    `git rev-parse HEAD` (the revert SHA) + dirty-tree check (as today's STEP 2
    pre-flight).
  - STEP 3 DISPATCH EXECUTOR: `Agent(subagent_type="hotfixer")` with the
    contract path, the located file(s), the proposed minimal fix, and the branch.
    Parse a `HOTFIX-EXEC REPORT` with `STATUS : DONE | BLOCKED`.
  - STEP 4 VERIFY + SECURE + COMMIT (main loop, LRN-083): on executor DONE, the
    smoke result is in its report; then the security gate — dispatch a FRESH
    security-auditor (`MODE: gate`, SCOPE = diff vs the pre-flight SHA). **hotfix
    keeps revert-not-loop**: smoke FAIL or security BLOCK → `git restore .` to the
    pre-flight SHA + STOP + "escalate to /bugfix" (verbatim from today's STEP 3).
    No verifier at hotfix weight. Commit only after smoke + security pass.
  - STEP 5 DOC SYNC + STEP 6 CAPITALIZE: identical to today's STEP 4/5 (doc-sync
    auto-mode + `doc-commit.md`; lightweight capitalize + always-on journal +
    `capitalize-commit.md`).
  - RULES: max 2 files; execution never stays inline, reflection never leaves it
    (BDR-066); executor dispatched fresh; revert-not-loop preserved.

- [ ] **Step 2: Rewrite `agents/hotfixer.md` as the executor.** Frontmatter:
  `tools: Read, Edit, Write, Bash, Grep, Glob` (DROP `Agent` — no nested dispatch;
  security moved to the orchestrator), `model: sonnet`. Body: receive
  CONTRACT + located file(s) + proposed fix + BRANCH (verify with
  `git branch --show-current`, never switch). Apply the minimal edit (no
  refactoring), run the stack smoke/test cascade (keep today's detection cascade),
  report. FORBIDDEN: git commit, branch ops, security dispatch, user questions,
  attribution trailers. End with:
  ```
  HOTFIX-EXEC REPORT
  STATUS  : DONE | BLOCKED
  FILE(S) : <changed files>
  FIX     : <one-line description>
  SMOKE   : <test/build result, verbatim line>
  NOTES   : <BLOCKED: the blocker; DONE: none>
  ```

- [ ] **Step 3: Repoint `lib/tests/loops-light.test.sh` hotfix locks** (guarded —
  sentinel first). The hotfix block currently checks `agents/hotfixer.md` for
  orchestration clauses now moved to the skill. Introduce `HSKL="$REPO/skills/hotfix/SKILL.md"`
  and repoint: contract/silent → HSKL `STEP 1.7 — CONTRACT`; security gate +
  `failure REVERTS, never loops` + `No verifier is dispatched at hotfix weight`
  → HSKL; `hotfix skill has Agent` (HSK `  - Agent`) unchanged. The
  `hotfix has Agent tool` lock on hotfixer INVERTS (hotfixer no longer has Agent)
  → change to assert hotfixer LACKS Agent and carries `model: sonnet` + the
  `HOTFIX-EXEC REPORT` grammar. Add a `hotfix dispatches hotfixer` lock
  (`subagent_type="hotfixer"` in HSKL). Keep include/feat/bugfix blocks untouched.
  Add a negative-match helper `tn()` (mirror `tf`, invert the grep) if asserting
  Agent-absence.

- [ ] **Step 4: Wire hotfix into the census + gate lists.** In
  `lib/tests/model-routing.test.sh` (guarded — sentinel first): MOVE `hotfix`
  from the excluded loop to the wired loop (`has "skills/hotfix/SKILL.md" 'lib/model-gate.md'`).
  Update the expected count in the run message accordingly.

- [ ] **Step 5: Verify + commit.** `bash lib/tests/loops-light.test.sh` green;
  `bash lib/tests/model-routing.test.sh` green; YAML check both rewritten files;
  `make test` green.
  ```bash
  git add skills/hotfix/SKILL.md agents/hotfixer.md lib/tests/loops-light.test.sh lib/tests/model-routing.test.sh
  git commit -m "feat(model-routing): /hotfix split — reflection inline + gate, hotfixer = sonnet executor"
  ```

---

### Task 13: commit-change — dispatch grouping+commit to sonnet, relocate approval gates

**Files:**
- Modify (rewrite): `skills/commit-change/SKILL.md` — dispatcher owns the two gates
- Modify (rewrite): `agents/commit-changer.md` — sonnet, propose/execute phases, no AskUserQuestion

**Pattern:** seo-applier shape (subagent proposes → dispatcher confirms → subagent executes).

- [ ] **Step 1: Rewrite `agents/commit-changer.md`.** Frontmatter:
  `tools: Bash, Read, Grep, Glob` (DROP `AskUserQuestion` — gates move to the
  dispatcher), `model: sonnet`. Body: two modes driven by the dispatch prompt.
  - `MODE: propose` → Phase 0 (gitflow aiguillage, type chore — bash), Phase 1
    (gather), Phase 2 (reconstruct steps), Phase 2.5 → EMIT the `COMMIT PLAN`
    block + any edge-case flags (sensitive files, staged-only, conflicts) +
    Phase-4 capitalize candidates, then STOP with
    `READY TO APPLY — awaiting dispatcher confirmation`. Writes NOTHING.
  - `MODE: apply` → receive the APPROVED plan (steps + messages) + approved
    capitalize entries; execute Phase 3 (stage-per-step + commit) and write the
    approved memory via `capitalize-commit.md`; report the commit hashes.

- [ ] **Step 2: Rewrite `skills/commit-change/SKILL.md` as dispatcher.** Keep
  `Agent` + `AskUserQuestion` in allowed-tools. Flow: pre-flight (detached HEAD /
  conflicts / identity — STOP as today) → `Agent(subagent_type="commit-changer")`
  with `MODE: propose` → show the returned COMMIT PLAN, `AskUserQuestion`
  (all / numbers / edit / skip) → show capitalize candidates, `AskUserQuestion`
  (all / IDs / skip) → `Agent(subagent_type="commit-changer")` with `MODE: apply`
  + the approved plan + approved entries → report hashes. NO MODEL GATE (grouping
  runs on the sonnet subagent — no inline reflection to protect).

- [ ] **Step 3: Verify + commit.** `grep -c 'subagent_type="commit-changer"' skills/commit-change/SKILL.md`
  ≥ 1; `grep -c 'model: sonnet' agents/commit-changer.md` → 1;
  `grep -c 'AskUserQuestion' agents/commit-changer.md` → 0; YAML check; `make test` green.
  ```bash
  git add skills/commit-change/SKILL.md agents/commit-changer.md
  git commit -m "feat(model-routing): /commit-change dispatch to sonnet commit-changer, gates relocated to dispatcher"
  ```

---

### Task 14: release-candidate — sonnet release-executor, human gates relocated

**Files:**
- Create: `agents/release-executor.md` — sonnet, mechanical release spans
- Modify (rewrite): `skills/release-candidate/SKILL.md` — dispatcher owns the two human gates

- [ ] **Step 1: Create `agents/release-executor.md`.** Frontmatter:
  `tools: Read, Edit, Write, Bash, Grep, Glob`, `model: sonnet`. Two-span
  executor driven by the dispatch prompt (a human gate sits BETWEEN the spans, so
  it cannot be one dispatch):
  - `SPAN: prep <X.Y.Z>` → `gitflow start release <X.Y.Z>`, set `version.txt`,
    rewrite CHANGELOG (`## [Unreleased]` → `## [<X.Y.Z>] — <date>`, re-open empty
    Unreleased; a MAJOR must spell out breaking), run the test suite (RC gate —
    never release red), commit the prep on the release branch. Report the branch
    + test result. No merge, no tag, no push.
  - `SPAN: finish <X.Y.Z>` → `gitflow finish` (fan-out), `git tag -a v<X.Y.Z> main
    -m "release <X.Y.Z>"` AFTER finish. Report. NEVER push (dispatcher's gate).
  - FORBIDDEN: deciding the version number (dispatcher/user owns it), the
    when-to-release decision, `git push`, attribution trailers.

- [ ] **Step 2: Rewrite `skills/release-candidate/SKILL.md` as dispatcher.** Add
  `allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion` to
  the frontmatter (it currently has none). Keep all the Overview/Versioning/Common-
  mistakes doctrine. Flow: preconditions (clean tree, identity, develop ahead of
  main) → the version-number decision stays HERE (judgment: derives from change
  nature; decide before running) → `Agent(subagent_type="release-executor")`
  `SPAN: prep <X.Y.Z>` → **HUMAN GATE — when to release** (`AskUserQuestion`,
  explicit go, never on "tests pass") → `Agent(subagent_type="release-executor")`
  `SPAN: finish <X.Y.Z>` → **push GATE (ASK)** (`AskUserQuestion`; on go only,
  LRN-069): `git push origin main develop && git push origin v<X.Y.Z>` from THIS
  loop. No MODEL GATE.

- [ ] **Step 3: Verify + commit.** `RC_WORK=$(mktemp -d) RC_TAG=1 bash lib/tests/run-release-candidate.sh`
  → 5/5 (the release mechanics test is unchanged — the lib still fans out + the
  dispatcher still tags); `grep -c 'subagent_type="release-executor"' skills/release-candidate/SKILL.md`
  ≥ 1; YAML check the new agent; `make test` green.
  ```bash
  git add agents/release-executor.md skills/release-candidate/SKILL.md
  git commit -m "feat(model-routing): /release-candidate dispatches sonnet release-executor, human gates in dispatcher"
  ```

---

### Task 15: census + docs + memory for wave 2

**Files:**
- Modify: `lib/tests/model-routing.test.sh` (guarded) — wave-2 assertions
- Modify: `README.md`, `CHANGELOG.md`, `.claude/memory/decisions.md`, `.claude/tasks/TODO.md`

- [ ] **Step 1: Extend the census** (`lib/tests/model-routing.test.sh`, guarded —
  sentinel first). The excluded loop drops `hotfix` (moved to wired by Task 12 Step 4)
  and now reads `for s in commit-change doc status release-candidate`. Add
  execution-dispatch asserts: `has skills/doc/SKILL.md 'subagent_type="doc-syncer"'`;
  `has skills/status/SKILL.md 'subagent_type="status-reporter"'`;
  `has skills/commit-change/SKILL.md 'subagent_type="commit-changer"'`;
  `has skills/release-candidate/SKILL.md 'subagent_type="release-executor"'`;
  pins `has agents/commit-changer.md 'model: sonnet'`,
  `has agents/release-executor.md 'model: sonnet'`; and executor-shape
  `lacks agents/commit-changer.md 'AskUserQuestion'`. Update the printed expected
  count. Flip-test one new assertion (LRN-096).

- [ ] **Step 2: README + CHANGELOG.** Update the BDR-066 agent-model table:
  hotfixer stays sonnet (now an effective executor), commit-changer → sonnet,
  release-executor (new) → sonnet, status-reporter → haiku (now effective via
  dispatch). Move doc/status/commit-change/release-candidate out of the "inherit"
  row into a new "execution — dispatched" line. CHANGELOG Unreleased: add the
  wave-2 bullets (doc/status/hotfix/commit-change/release-candidate routing).

- [ ] **Step 3: Capitalize.** Append to the BDR-066 entry a `**Wave 2**` bullet:
  doc/status dispatched (sonnet/haiku pins effective); hotfix split like /feat
  (joins gated group); commit-change dispatched sonnet with relocated gates;
  release-candidate sonnet release-executor with relocated human gates; exclusion
  list now commit-change/doc/status/release-candidate. Journal line +
  TODO tick under the 2026-07-15 section.
  ```bash
  git add lib/tests/model-routing.test.sh README.md CHANGELOG.md .claude/memory/decisions.md .claude/memory/journal.md .claude/tasks/TODO.md
  git commit -m "chore(model-routing): wave-2 census + docs + BDR-066 update"
  ```

- [ ] **Step 4: Final wave-2 review** — dispatch a whole-branch reviewer (opus) over
  the wave-2 range; confirm both consumers of verify-secure-loop still coherent,
  hotfix revert-not-loop preserved, no execution left on the big model in the
  five converted skills. Report the full `git log --oneline develop..HEAD`. Do NOT
  merge.

---

# WAVE 3 — reflection-split the last two inline execution-carrying agents (user directive 2026-07-15)

`/bugfix` and `/code-clean` are still thin wrappers that inline-load an agent
doing BOTH reflection and execution on the big session model — the exact
pre-split state `/feat` (Task 5) and `/hotfix` (Task 12) were in. Split each
like the shipped pattern: reflection inline (session model, behind the MODEL
GATE both skills already carry), execution dispatched to a sonnet executor.

**Honest tradeoff (recorded in the wave-3 BDR bullet):** bugfix's investigation
and fix are tightly coupled; handing a context-free sonnet executor a closed
FIX PLAN is the same bet `/feat` makes — mitigated by the structured DIAGNOSIS
+ the verify loop catching drift. Further supersedes the BDR-050 "bugfix stays
inline" carve-out (hotfix already reversed in wave 2). code-clean's win is
larger than it looks: today it INLINE-LOADS the refactorer (so the refactor
runs on the big model, sonnet pin inert) — after the split the refactor runs
inside the sonnet executor for the first time.

Gate membership is UNCHANGED: both skills keep reflection (investigation /
audit), so both STAY in the wired gate list — this wave only adds
executor-shape asserts, it does not move either skill between the wired and
excluded lists.

## Global Constraints (wave 3)

Same as waves 1–2: branch `feature/model-routing`, no merge, no attribution
trailers, `make test` green per commit, shellcheck clean, config-protection
sentinel before each `lib/tests/*` write (controller applies guarded test
edits — subagents cannot create the sentinel), YAML `safe_load`-parseable
frontmatter.

---

### Task 16: `/bugfix` split — reflection inline + dispatched sonnet executor

**Files:**
- Modify (rewrite): `skills/bugfix/SKILL.md` — thin wrapper → reflection orchestrator
- Modify (rewrite): `agents/bugfixer.md` — full agent → pure sonnet executor
- Modify (surgical): `lib/verify-secure-loop.md` — bugfix's dev is now dispatched too
- Modify: `lib/tests/loops-light.test.sh` — repoint bugfix locks (guarded — CONTROLLER applies)

**Pattern:** mirror the shipped `/hotfix` split (skills/hotfix/SKILL.md — it is
the closest template: reflection orchestrator + a security gate whose decisions
live in the main loop) and `/feat` (agents/feater.md — the pure-executor shape).
The difference from hotfix: bugfix keeps the FULL verify+secure loop (fresh
verifier + fresh security, bounded 3×, per `lib/verify-secure-loop.md`) and the
interactive pre-commit + capitalize gates — hotfix has none of those.

- [ ] **Step 1: Rewrite `skills/bugfix/SKILL.md` as the reflection orchestrator.**
  Keep `Agent` in allowed-tools; the frontmatter description block is unchanged.
  Keep the existing `MODEL GATE (blocking)` line verbatim (bugfix stays gated).
  Absorb, INLINE (session model), what were bugfixer STEPs 1–3.5 — reflection:
  - STEP 1 GATHER CONTEXT (git status/log; what/where/when).
  - STEP 1.5 DESIGN GATE (`$HOME/.claude/lib/design-gate.md`, unchanged).
  - STEP 2 INVESTIGATE (trace symptom → root cause, blast radius).
  - STEP 2.5 MEMORY READ-BEFORE (`$HOME/.claude/lib/analyze-before-plan.md`,
    blockers-weighted; keep the TEETH clause — DIAGNOSIS must name any binding
    prior or state none bears).
  - STEP 3 DIAGNOSE + PLAN — emit the `BUGFIX — DIAGNOSIS` block (BUG / ROOT
    CAUSE / EVIDENCE / BLAST RADIUS / FIX PLAN / RISK) verbatim from today's
    bugfixer STEP 3. Keep the significance gate: trivial → proceed; significant
    (>10 lines / multi-file / behavior change) → wait for user approval;
    root-cause unclear → list ranked hypotheses, ask before proceeding.
  - STEP 3.5 CONTRACT (`$HOME/.claude/lib/contract-interview.md`, main loop;
    DIAGNOSIS feeds it — REQUEST verbatim = the bug report, ACCEPTANCE =
    symptom reproduced-then-gone + regression test present+passing, FILE SCOPE
    = the FIX PLAN files; keep the contract path for STEP 5).
  - STEP 4 BRANCH: gitflow aiguillage (`$HOME/.claude/lib/gitflow-aiguillage.md`,
    type `bugfix`; never finish).
  - STEP 5 DISPATCH EXECUTOR:
    ```
    Agent(subagent_type="bugfixer")
    prompt: "CONTRACT: <path from STEP 3.5>
    DIAGNOSIS: <ROOT CAUSE + EVIDENCE from STEP 3>
    FIX PLAN: <the STEP 3 FIX PLAN — exact edits + the regression test to add>
    BRANCH: <current branch — verify with git branch --show-current, never switch>
    Apply the fix to the letter + the regression test. No commit, no branch
    ops, no security dispatch. Finish with the BUGFIX-EXEC REPORT."
    ```
    Parse `BUGFIX-EXEC REPORT`: `STATUS : DONE` → STEP 6; `NEED-DECISION` →
    decide HERE (reflection), append to the plan, re-dispatch a FRESH bugfixer,
    max 2 round-trips → escalate; `BLOCKED` → surface + stop.
  - STEP 6 VERIFY + SECURE + PRE-COMMIT GATE + COMMIT (main loop, LRN-083):
    run the two fresh gates per `$HOME/.claude/lib/verify-secure-loop.md` with
    `CONTRACT` = STEP 3.5 path, `DIFF` = the executor's working-tree diff,
    `TEST` = the suite from its report (the loop's "dev" is the dispatched
    bugfixer — re-dispatched FRESH on ECARTS/BLOCK). After both gates pass,
    keep today's interactive `BUGFIX — READY TO COMMIT` pre-commit gate
    (diff-stat + message → yes / edit message / skip / amend last), then commit
    with the conventional `fix(<scope>):` message, then print `BUGFIX COMPLETE`.
  - STEP 7 DOC SYNC (doc-syncer auto-mode + `$HOME/.claude/lib/doc-commit.md`,
    verbatim from today's bugfixer STEP 6).
  - STEP 8 CAPITALIZE (BLK-XXX pre-filled from DIAGNOSIS + optional LRN;
    interactive gate; `$HOME/.claude/lib/capitalize-commit.md`; verbatim from
    today's bugfixer STEP 7).
  - RULES: no fix without root cause first; execution never stays inline,
    reflection never leaves it (BDR-066); executor dispatched fresh; keep
    regression-test + scoped-fix + escalate-to-/ship-feature-if->5-files rules.

- [ ] **Step 2: Rewrite `agents/bugfixer.md` as the pure executor.** Replace the
  ENTIRE file with exactly:

````markdown
---
name: bugfixer
description: Bug-fix EXECUTOR — dispatched by /bugfix with a closed DIAGNOSIS + FIX PLAN + contract. Applies the fix and a regression test, runs the suite, reports. No investigation, no questions, no commit.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
---

# BUGFIXER — fix executor

You receive a CLOSED diagnosis + fix plan from the /bugfix orchestrator. The
investigation already happened; your job is faithful execution, not analysis.
Every choice was made in the plan or is a NEED-DECISION to report.

## INPUT (in the dispatch prompt)

- `CONTRACT`: path to the contract file — read it FIRST; its acceptance
  criteria (symptom reproduced-then-gone + a regression test present) + FILE
  SCOPE bound everything you do.
- `DIAGNOSIS`: root cause + evidence, from the orchestrator's investigation.
- `FIX PLAN`: the exact edits (file:line → change) + the regression test to add.
- `BRANCH`: verify with `git branch --show-current`; mismatch → STATUS
  BLOCKED — never create or switch branches.
- `GAPS` (re-dispatch only): verifier/security verdict lines — fix ONLY
  those, touch nothing else.

## EXECUTION RULES

- Apply the FIX PLAN to the letter — fix the ROOT CAUSE named in DIAGNOSIS,
  not the symptom. A plan hole or an open choice (naming, data shape, API
  surface, dependency) → STOP, report `NEED-DECISION` with the precise
  question. Never re-investigate or improvise a different fix.
- Stay inside the contract FILE SCOPE. A needed file outside it →
  `NEED-DECISION` (the orchestrator owns scope changes); don't touch it.
- Add or update the regression test the plan names — it must fail before the
  fix and pass after. Run the relevant suite incrementally; run it fully
  before reporting.
- Follow existing code patterns and CLAUDE.md limits (function size, params,
  no global state). Keep the fix minimal — no "while we're here" cleanups.
- FORBIDDEN: `git commit`, branch ops, push, merge, new dependencies,
  security/verifier dispatch, editing `.claude/**` or memory registries, user
  questions (you cannot ask — report instead), attribution trailers of any kind.

## OUTPUT — end with exactly this report (your final message)

```
BUGFIX-EXEC REPORT
STATUS   : DONE | NEED-DECISION | BLOCKED
FILE(S)  : <created/modified paths>
TEST(S)  : <regression test added/updated + final suite run result, verbatim line>
SMOKE    : <build/typecheck result if run, or n/a>
NOTES    : <DONE: deviations (must be none) | NEED-DECISION: the exact
           question + the options you see | BLOCKED: the blocker verbatim>
```
````

- [ ] **Step 3: Update `lib/verify-secure-loop.md` (both consumers now dispatched).**
  The header line `(feat, bugfix)` stays. In the intro, the sentence that says
  the dev step is "either inline (bugfix) or a dispatched sonnet executor
  (/feat's feater)" is now stale — BOTH are dispatched. Edit it to: the dev
  step is a dispatched sonnet executor (feat's `feater`, bugfix's `bugfixer`);
  "hand the dev" below means re-dispatch a FRESH executor with exactly those
  inputs. Keep GATE 1 / GATE 2 / order-invariant bodies unchanged (they already
  read "inline dev fixes in place; a dispatched dev is re-dispatched FRESH" —
  the inline branch simply no longer has a consumer, harmless).

- [ ] **Step 4 (CONTROLLER — guarded): repoint `lib/tests/loops-light.test.sh`
  bugfix locks.** Sentinel first:
  `printf 'model-routing plan: repoint bugfix structure locks to the skill orchestrator' > .claude/.config-edit-ok`
  Introduce `BSK="$REPO/skills/bugfix/SKILL.md"`. The `bugfixer.md (bugfix wiring)`
  block currently greps `$BUG` for orchestration clauses now moved to the skill —
  repoint them to `$BSK`: `STEP 3.5 — CONTRACT`, `feeds it: REQUEST verbatim`,
  `Fresh gates (verify + secure)` (or the skill's actual STEP-6 wording — match
  it), `lib/verify-secure-loop.md`. Add a new `bugfixer.md (executor — sonnet,
  no Agent)` block mirroring the hotfixer one: `tn` bugfixer LACKS `Agent`,
  `tf` `model: sonnet`, `tf` `BUGFIX-EXEC REPORT`. Add `tf "bugfix dispatches
  bugfixer" "$BSK" 'subagent_type="bugfixer"'`. Keep include/feat/hotfix blocks
  untouched.

- [ ] **Step 5: Verify + commit.** `bash lib/tests/loops-light.test.sh` green;
  YAML check both rewritten files
  (`python3 -c "import yaml; [yaml.safe_load(open(f).read().split('---')[1]) for f in ['agents/bugfixer.md','skills/bugfix/SKILL.md']]; print('YAML OK')"`);
  `make test` green.
  ```bash
  git add skills/bugfix/SKILL.md agents/bugfixer.md lib/verify-secure-loop.md lib/tests/loops-light.test.sh
  git commit -m "feat(model-routing): /bugfix split — reflection inline, bugfixer = sonnet executor (supersedes BDR-050 bugfix carve-out)"
  ```

---

### Task 17: `/code-clean` split — audit + gate inline + dispatched sonnet executor

**Files:**
- Modify (rewrite): `skills/code-clean/SKILL.md` — thin wrapper → audit orchestrator
- Modify (rewrite): `agents/code-cleaner.md` — full agent → pure PHASE-2 sonnet executor

**Pattern:** mirror `/feat` (skill = orchestrator holding reflection + interactive
gate; agent = pure executor). The interactive VALIDATION GATE must stay in the
orchestrator (a dispatched subagent cannot ask). code-cleaner gains `model: sonnet`.

- [ ] **Step 1: Rewrite `skills/code-clean/SKILL.md` as the audit orchestrator.**
  Add `Agent` to allowed-tools (keep `AskUserQuestion`, `Read/Edit/Write/Bash/
  Grep/Glob`). Keep the existing `MODEL GATE (blocking)` line verbatim (audit =
  reflection, stays gated). Absorb code-cleaner's PHASE 1 INLINE (session model):
  - `# /code-clean — cleanup orchestrator (audit inline, execution dispatched)`
  - STEP 1 LOAD PROJECT NORMS (CLAUDE.md > lang configs > community defaults).
  - STEP 2 SCAN (A dead code / B style / C structural — verbatim from today's
    code-cleaner PHASE 1 STEP 2, keep the TODO-age bash).
  - STEP 3 BUILD REPORT (the `CODE-CLEAN AUDIT` block, severity levels).
  - STEP 4 VALIDATION GATE (interactive, `AskUserQuestion`): present the report;
    approve all / cherry-pick / clarify. Do NOT proceed until explicit approval.
    Exported/public-API symbols flagged in the audit are resolved HERE, per-item
    (this is where the today's guard-rail consent lives — the executor never asks).
  - STEP 5 PERSIST SCOPE + DISPATCH: write the approved items to
    `.claude/audits/CODE-CLEAN-SCOPE.md` (`mkdir -p .claude/audits` first), one
    per line `file:line — item — severity — proposed fix`, then:
    ```
    Agent(subagent_type="code-cleaner")
    prompt: "SCOPE: .claude/audits/CODE-CLEAN-SCOPE.md
    APPROVED: <the approved item list, incl. any per-item exported-symbol clears>
    BRANCH: <current branch — verify with git branch --show-current, never switch>
    Execute PHASE 2 on the approved scope only. Zero behavior change. No commit.
    Finish with the CODE-CLEAN-EXEC REPORT."
    ```
    Parse `CODE-CLEAN-EXEC REPORT`: `DONE` → STEP 6; `BLOCKED` → surface + stop.
  - STEP 6 SUMMARY: present the `CODE-CLEAN COMPLETE` block (removed / refactored
    / skipped / bugs-found / tests) from the executor's report. No commit here
    (code-clean has never auto-committed — leave the working tree for the user
    or a follow-up `/commit-change`; keep today's behavior).
  - RULES: zero behavior change; no scope creep; exported symbols need explicit
    per-item consent AT THE GATE; bugs → BUGS-FOUND.md not fixed; no plugin
    check (lightweight); systemic issues → suggest `/ship-feature`.

- [ ] **Step 2: Rewrite `agents/code-cleaner.md` as the PHASE-2 executor.** Replace
  the ENTIRE file with exactly:

````markdown
---
name: code-cleaner
description: Cleanup EXECUTOR (PHASE 2) — dispatched by /code-clean with an APPROVED scope. Deletes approved dead code, hands style/structural items to the refactorer, re-audits. Zero behavior change. No audit, no questions, no commit.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
---

# CODE-CLEANER — cleanup executor (PHASE 2)

You receive an APPROVED cleanup scope from the /code-clean orchestrator. The
audit and the user approval already happened; your job is faithful execution.
The iron law is unchanged: ZERO behavior change — identical observable output
before and after.

## INPUT (in the dispatch prompt)

- `SCOPE`: path to `.claude/audits/CODE-CLEAN-SCOPE.md` — the approved items
  (`file:line — item — severity — proposed fix`), the on-disk contract.
- `APPROVED`: the item list the user confirmed (may be a subset of the audit),
  including any exported/public-API symbols the gate explicitly cleared.
- `BRANCH`: verify with `git branch --show-current`; mismatch → STATUS
  BLOCKED — never create or switch branches.

## EXECUTION — in order

### 1. Delete approved dead code (safest first)

Remove approved unused imports / variables / functions, commented-out blocks,
stale TODO/FIXME. **Guard rail**: an exported / public-API symbol the
`APPROVED` list did NOT explicitly clear → do NOT delete; SKIP it and record
it under NOTES. The per-item exported-symbol consent lives in the
orchestrator's gate — you never ask.

### 2. Style + structural fixes → INLINE-LOAD the refactorer

Load `$HOME/.claude/agents/refactorer.md` and continue AS the refactorer in
THIS SAME context — you *become* it. This is an inline load, NOT a subagent
dispatch: the `Agent` tool is not involved and no new context is spawned. Its
scope = the style / structural items in `SCOPE`. Its own safety process runs
(pre-report, function-by-function, test after each) — zero behavior change.
Running inside this sonnet executor, the refactor finally runs on sonnet (the
refactorer pin was inert under the old inline-load on the session model).

### 3. Log discovered bugs (do NOT fix)

Real defects found during cleanup (not style issues) → append each to
`.claude/audits/BUGS-FOUND.md` (`mkdir -p .claude/audits` first): file:line,
description, severity, discovered-while. Cleanup and bugfixing are separate
concerns — never fix a bug here.

### 4. Re-audit

Re-scan only the modified files; verify no new issues were introduced; run the
project test suite + linter/formatter if available.

## RULES

- Zero behavior change. Unsure a deletion is safe → leave it, record under NOTES.
- No "while we're here" scope creep — only the APPROVED items.
- FORBIDDEN: `git commit`, branch ops, push, merge, new dependencies, user
  questions (report instead), editing `.claude/**` or memory registries,
  attribution trailers of any kind.

## OUTPUT — end with exactly this report (your final message)

```
CODE-CLEAN-EXEC REPORT
STATUS    : DONE | BLOCKED
REMOVED   : <N dead-code items (imports, functions, commented blocks)>
REFACTORED: <N style + N structural, via the refactorer>
SKIPPED   : <exported-symbol / unsafe items left, with reason — or none>
BUGS      : <N logged to .claude/audits/BUGS-FOUND.md — or none>
TESTS     : <suite result verbatim, or "no test suite">
NOTES     : <BLOCKED: the blocker verbatim; DONE: none>
```
````

- [ ] **Step 3: Verify + commit.**
  `grep -c 'subagent_type="code-cleaner"' skills/code-clean/SKILL.md` → 1;
  `grep -c 'model: sonnet' agents/code-cleaner.md` → 1;
  `grep -c 'AskUserQuestion' agents/code-cleaner.md` → 0;
  YAML check both files; `make test` green.
  ```bash
  git add skills/code-clean/SKILL.md agents/code-cleaner.md
  git commit -m "feat(model-routing): /code-clean split — audit+gate inline, code-cleaner = sonnet PHASE-2 executor"
  ```

---

### Task 18: wave-3 census + docs + memory

**Files:**
- Modify: `lib/tests/model-routing.test.sh` (guarded — CONTROLLER applies) — wave-3 asserts
- Modify: `README.md`, `CHANGELOG.md`, `.claude/memory/decisions.md`,
  `.claude/memory/journal.md`, `.claude/tasks/TODO.md`

- [ ] **Step 1 (CONTROLLER — guarded): extend the census.** Sentinel first:
  `printf 'model-routing plan: wave-3 executor-shape asserts (bugfix, code-clean)' > .claude/.config-edit-ok`
  In `lib/tests/model-routing.test.sh`, add a `# 8) wave-3 — bugfix/code-clean
  reflection-split executors` section:
  `has skills/bugfix/SKILL.md 'subagent_type="bugfixer"'`;
  `has agents/bugfixer.md 'model: sonnet'`;
  `lacks agents/bugfixer.md 'AskUserQuestion'`;
  `has skills/code-clean/SKILL.md 'subagent_type="code-cleaner"'`;
  `has agents/code-cleaner.md 'model: sonnet'`;
  `lacks agents/code-cleaner.md 'AskUserQuestion'`.
  (bugfix + code-clean stay in the existing `# 1)` wired-gate loop — do NOT move
  them.) Update the printed expected count. Flip-test one new assertion (LRN-096:
  e.g. temporarily break the bugfixer dispatch string, confirm red, restore).

- [ ] **Step 2: README + CHANGELOG.** In the BDR-066 agent-model table, MOVE
  `bugfixer` and `code-cleaner` out of the "inherit session" row into the
  executor/dispatched rows (bugfixer → sonnet executor; code-cleaner → sonnet
  PHASE-2 executor). The "inherit session" row keeps analyzer + seo/geo/validator
  analyzers (+ commit-changer stays wherever wave-2 placed it). CHANGELOG
  Unreleased `### Changed`: add the wave-3 bullet (bugfix/code-clean split —
  reflection inline, executors sonnet; refactor now runs on sonnet inside the
  code-clean executor).

- [ ] **Step 3: Capitalize.** Append a `**Wave 3**` bullet to the BDR-066 entry
  in `.claude/memory/decisions.md`: bugfix + code-clean reflection-split
  (executors sonnet); supersedes the BDR-050 "bugfix inline" carve-out (hotfix
  went in wave 2, bugfix now); code-clean refactor finally on sonnet (inline-load
  pin was inert). Note the accepted tradeoff (bugfix investigation↔fix coupling,
  mitigated by DIAGNOSIS + verify loop). Journal line under 2026-07-15 + TODO
  tick.
  ```bash
  git add lib/tests/model-routing.test.sh README.md CHANGELOG.md .claude/memory/decisions.md .claude/memory/journal.md .claude/tasks/TODO.md
  git commit -m "chore(model-routing): wave-3 census + docs + BDR-066 update (bugfix/code-clean split)"
  ```

- [ ] **Step 4: Final wave-3 review** — dispatch a whole-branch reviewer (opus)
  over the wave-3 range; confirm: bugfix keeps root-cause-first + the pre-commit
  gate + verify+secure loop with the executor as the loop's dev; code-clean keeps
  the interactive validation gate + exported-symbol per-item consent at the gate
  (not in the executor); zero execution left on the big model in either skill;
  both executors have no `AskUserQuestion` and are `model: sonnet`. Report the
  full `git log --oneline develop..HEAD`. Do NOT merge.

---

# WAVE 4 — client-handover whole-writer dispatch (spec §5, user directive 2026-07-15)

**Status: NOT YET SPEC'd — needs a dedicated design pass.** The user chose the
"dispatch the whole writer" variant of spec §5 (over the lighter redaction-only
split). This converts `agents/client-handover-writer.md` (1774 lines) from an
inline-loaded session-model agent into a dispatched sonnet subagent. It is the
single largest conversion in this effort and requires designing a resumable-gate
protocol before task decomposition. Key constraints already established:

- The writer has ~8–11 mid-pipeline `AskUserQuestion` gates (STEP 4 fix-loop
  escalation, STEP 5 push + push-failed, STEP 6 deploy pause + deployed-URL,
  STEP 11 Q1/Q2, STEP 13 NAP asks, …). A dispatched subagent cannot ask.
  Convert each to a `GATE NEEDED: <id> <payload>` yield: the writer STOPs and
  returns it; the dispatcher (`skills/client-handover/SKILL.md`, main loop)
  runs the `AskUserQuestion`; then RESUMES the writer via SendMessage with the
  answer. Remove `AskUserQuestion` from the writer's tools.
- **CORRECTNESS (spec §5 OPEN VERIFY POINT — resolved: force big):** the
  writer's nested audit dispatches (STEP 3 baseline SEO/HARDEN/CSO, STEP 4 fix
  loops, STEP 7 web-validate — all `general-purpose`) MUST carry an explicit
  big-model `model` param so audits do NOT inherit the sonnet parent. Running
  audits on sonnet would silently violate the "audits on the big model" rule.
  The fix-application re-dispatches (execution) stay sonnet.
- Dispatcher collects params inline (URL, logo, options), then
  `Agent(subagent_type="client-handover-writer")`; writer keeps `Agent` (nested
  dispatches) + gains no `AskUserQuestion`.
- Add the MODEL GATE to `skills/client-handover/SKILL.md` (it orchestrates
  audits = reflection) and add it to the census wired list.
- Census + README/CHANGELOG + BDR-066 wave-4 bullet + journal + TODO.

Tasks 19+ to be written after reading the writer's STEP 12–14 (doc synthesis +
render + remaining gates, lines 1123–1774) and mapping every gate to a yield id.
