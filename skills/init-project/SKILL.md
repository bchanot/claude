---
name: init-project
description: 'Use when initializing a brand-new project from scratch — needs interview, design, scaffold, and TDD implementation. Multi-agent orchestrator: plugin-advisor + interviewer + analyzer + scaffolder with two validation gates. Triggers: "init project", "new project", "start project from scratch", "scaffold project", "init-project".'
argument-hint: <project idea or description>
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: INIT PROJECT

## MODEL GATE (blocking — run before any other step)

Run `$HOME/.claude/lib/model-gate.md`. Reflection here (planning, audit
judgment, loop decisions) requires Fable/Opus. Verdict `small` → STOP: the
gate prints the remedy; end the turn — no later step, no dispatch. Nominal
(big) path is silent.

## REQUEST
$ARGUMENTS

---

## PROGRESS PROTOCOL

Every STEP must announce itself with a header BEFORE its work block, so the
user always sees where they are in the 12-step pipeline (STEP 0–11):

```
━━━ STEP <N>/11 — <TITLE> ━━━  (~<estimated minutes>)
why: <one sentence — what's at risk if this step is skipped>
```

Long-running steps (5 SCAFFOLD, 8 IMPLEMENT) must print a 1-line
liveness ping every ~30 s of agent work — `… still working: <last action>` —
so the user does not assume Claude has hung.

---

## STEP 0 — PLUGIN CHECK + AUTO-ACTIVATE
Run `$HOME/.claude/lib/plugin-gate.md`. Feed request (dispatch plugin-probe →
checkpoint → dispatch plugin-advisor; gates stay in this loop — BDR-077).
- ACTION REQUIRED → show RECOMMENDATIONS block, offer: A) fix plugins B) type "force". STOP.
- PROPOSED CHANGES exist → show list, ask "Apply? (yes / no / customize)". Apply on confirm.
- OK → `✅ Plugin check passed — [active plugins] — complexity: <score>%`, continue.

## STEP 1 — INTERVIEW
Before loading the interviewer, check for an existing CLAUDE.md:
```bash
ls CLAUDE.md .claude/CLAUDE.md 2>/dev/null | head -1
```
- **Found** (either `CLAUDE.md` or `.claude/CLAUDE.md`) → read it silently.
  Pre-fill all interview answers already documented (stack, purpose, features, conventions).
  Load `$HOME/.claude/agents/interviewer.md` and ask ONLY what is genuinely missing.
  Print: "📄 Existing CLAUDE.md found — using as context."
- **Not found** → standard mode: load `$HOME/.claude/agents/interviewer.md`,
  ask all unanswered questions.

In both cases: MANDATORY STOP until user answers remaining questions. Produce PROJECT BRIEF.

**Then run `$HOME/.claude/lib/contract-interview.md`** seeded from the BRIEF:
REQUEST verbatim = the user's project description; ACCEPTANCE CRITERIA = the
V1 FEATURES (each testable); FILE SCOPE = the planned tree. No new questions
(the interview already asked). It writes
`.claude/tasks/contracts/<date>-<slug>-<HHMM>.md`; the DESIGN approved at STEP
4 ENRICHES it, and STEP 9's verifier judges the MVP against the enriched
contract.

## STEP 2 — ANALYZE
Load `$HOME/.claude/agents/analyzer.md`. Analyze BRIEF: existing code, stack constraints, infra risks, open decisions. Produce ANALYSIS REPORT.

## STEP 3 — DESIGN
Invoke `superpowers:brainstorming` with BRIEF + ANALYSIS REPORT.
Produce DESIGN: stack+versions, full folder tree, module responsibilities, data flow, interfaces (signatures only), config+tooling, test strategy, resolved decisions, prereqs list.

## STEP 4 — VALIDATION GATE #1 ★ MANDATORY STOP
Present:
```
INIT PROJECT — ARCHITECTURE VALIDATION
PROJECT : <3-5 line recap>
STACK   : <versions>
PREREQS : <install list>
TREE    : <folder tree>
V1 FEATURES: <numbered list>
CONVENTIONS: <naming, doc, test>
EXCEPTIONS : <list or none>
Approve? (yes / request changes)
```
Changes → back to STEP 3. Approved → continue.

**On approval — ENRICH the STEP 1 contract**: append the DESIGN-derived
acceptance criteria (resolved decisions, interfaces, test strategy) to the
contract, each tagged `[gated <date>]`. STEP 9's verifier judges against this
enriched contract.

## STEP 5 — SCAFFOLD
Load `$HOME/.claude/agents/scaffolder.md`. Pass: BRIEF + DESIGN + `~/.claude/templates/project-CLAUDE.md` + `~/.claude/CLAUDE.md`.
Creates: CLAUDE.md, `.claude/settings.json`, `.claudeignore`, `.gitignore`, `.env.example`, empty entry points. NO README, NO features, NO `.claude/tasks/` or `.claude/memory/` (not bootstrapped by this flow — copy from `~/.claude/templates/memory/` manually if wanted before STEP 10b's memory commit).
Verify: `git init` + build passes.

## STEP 5b — CREATE README
Load `$HOME/.claude/agents/doc-syncer.md` (AUTO MODE, scope: full project). README.md missing → its README bootstrap creates it. No stop.

## STEP 5c — CTX7 PRE-FETCH (if fast-libs detected)
If `fast-libs` signal was detected in STEP 0 (Next.js, React 18+, Prisma, Supabase, Drizzle, etc.):
1. Create `.ctx7-cache/` directory in project root.
2. For each detected fast-lib, fetch core docs:
   ```bash
   mkdir -p .ctx7-cache
   # Example for detected libs — adapt to actual deps:
   ctx7 docs /vercel/next.js "app router middleware routing" > .ctx7-cache/nextjs-core.md 2>/dev/null || true
   ctx7 docs /prisma/prisma "schema client queries" > .ctx7-cache/prisma-core.md 2>/dev/null || true
   ```
3. Add `.ctx7-cache/` to `.gitignore` (local dev cache, not committed).
4. Print: `📚 ctx7 docs pre-fetched for: <libs>. Cache at .ctx7-cache/`
If `ctx7` not installed or no fast-libs → skip silently.

## STEP 5e — ANIMATION LIB (auto-install)
Install `motion` (ex-`framer-motion`, rebranded Nov 2024) when the stack supports it.
The scaffold has just been validated by the user, so install proceeds silently.

```bash
source "$HOME/.claude/lib/animation-lib-check.sh"
if result=$(detect_anim_eligibility); then
  pkg=$(echo "$result" | cut -d'|' -f2)
  if ! is_anim_lib_installed >/dev/null; then
    cmd=$(recommend_anim_install_cmd "$pkg")
    echo "🎬 Installing animation lib: $cmd"
    eval "$cmd"
  else
    installed=$(is_anim_lib_installed)
    echo "🎬 Animation lib already present: $installed — skipping install"
  fi
else
  echo "🎬 Animation lib: stack not eligible — skipping ($(echo "$result" | cut -d'|' -f3))"
fi
```

Rules:
- `motion` for React-family / Svelte / vanilla JS stacks.
- `motion-v` for Vue 3 / Nuxt.
- React Native, Flutter, backend, embedded, static HTML → skipped.
- If another animation lib (gsap, lottie-react, react-spring, …) is already present → skipped.

## STEP 5f — GITFLOW INIT
After every scaffold file exists (STEP 5–5e have run), establish the gitflow
layout and the deterministic root commit:
```bash
bash "$HOME/.claude/lib/gitflow.sh" init "chore: scaffold <project-name>"
```
Creates `main`+`develop`, root-commits the FULL scaffold (CLAUDE.md, README,
config, `.gitignore`, deps), reconciles the `.gitignore` socle, and installs the
versioned pre-commit hook — all embedded in the root commit, working tree clean.
This is the deterministic scaffold commit owner (closes BLK-010). The MVP is
implemented on a `feature/*` branch off `develop` (STEP 8).

## STEP 6 — PLAN
Invoke `superpowers:writing-plans` with BRIEF + skeleton.
Granular tasks (2-5 min each), exact file paths, TDD: tests before code.

## STEP 6b — CHALLENGE THE PLAN (before the gate)
Before the human sees the implementation plan, harden it. Run
`$HOME/.claude/lib/challenge-plan.md` with `PLAN` = the plan STEP 6 wrote under
`docs/superpowers/plans/`, `KIND` = `build-plan`, `SCOPE` = the skeleton + task file
paths, `CONSTRAINTS` = the STEP 4-validated architecture + founding decisions.
Three blind challengers (correctness / robustness / simplicity) attack it; the main
loop RE-THINKS every aspect a BLOCKER lands (a named plan change, or `[deferred]`),
re-challenges once if the plan materially changed, and feeds the REVISED plan + a
CHALLENGE SUMMARY into STEP 7. Advisory — the human remains the decider.

## STEP 7 — VALIDATION GATE #2 ★ MANDATORY STOP
```
INIT PROJECT — IMPLEMENTATION PLAN
SKELETON: ✅ build passes
FEATURES: <N> → <M> tasks
<numbered task list with paths>

CHALLENGE SUMMARY (STEP 6b — 3 lenses):
  BLOCKERs addressed : <n> — <finding → the named plan change that closes it>
  Deferred (human-ack): <list | none>
  Lenses returned    : correctness / robustness / simplicity (NAME any that failed to return)
Approve and start? (yes / request changes)
```
Changes → back to STEP 6. Approved → continue.

## STEP 8 — IMPLEMENT
Start the MVP feature branch off develop, then implement on it:
```bash
bash "$HOME/.claude/lib/gitflow.sh" start feature mvp
```
Invoke `superpowers:subagent-driven-development` for the per-task implement loop
**and** the final whole-branch review **only**. Do NOT run its terminal
`finishing-a-development-branch` step — this orchestrator owns integration via
`gitflow finish` (STEP 11). When SDD's flow reaches "Use
finishing-a-development-branch", stop and return.

**Model routing (BDR-066):** every subagent dispatched under SDD — per-task
implementers AND its reviewers — MUST carry `model: "sonnet"` in the Agent
call. The plan is closed; execution and plan-conformity review are sonnet
work. Reflection (task decomposition, review verdict arbitration) stays in
this loop.

## STEP 8b — GRAPHIFY FULL (after implementation)
If `graphify` CLI is installed AND complexity >= 30%:
1. Run full graphify on the implemented project:
   ```bash
   graphify . --out graphify-out 2>/dev/null || true
   ```
2. Print: `🔗 Full project graph updated at graphify-out/`
If `graphify` not installed or complexity < 30% → skip silently.

## STEP 9 — VERIFY + SECURE (fresh gates, bounded loops)
Run the two fresh gates per `$HOME/.claude/lib/verify-secure-loop.md` with
`CONTRACT` = the STEP 1 path (ENRICHED at STEP 4), `DIFF` = the MVP branch
diff (`develop..HEAD`), `TEST` = the project suite:
- GATE 1 — a FRESH verifier judges the MVP against the enriched contract (V1
  features + `[gated]` design criteria). CONFORME → GATE 2. ECARTS → fix,
  re-verify, max 3 → STOP + human escalation with the CRITERIA table.
- GATE 2 — a FRESH security-auditor (`MODE: gate`, `SCOPE: develop..HEAD`).
  PASS → STEP 10. BLOCK → fix, re-verify request THEN re-scan, max 3 →
  escalate.

This adds the security gate init-project previously lacked (security was only
deferred to a later /onboard) and turns the informal analyze into a verdict
against the founding contract. Distinct axis from STEP 10 code review
([[LRN-095]]) — both run.

## STEP 10 — CODE REVIEW
Invoke `superpowers:requesting-code-review`. **Model routing (BDR-077):** the
review subagent it dispatches MUST carry `model: "opus"` in the Agent call —
craft review is dispatched judgment, never inherited from the session. Fix
all CRITICAL before proceeding.

## STEP 10b — CAPITALIZE FOUNDING DECISIONS (memory registries)
A greenfield's founding architecture decisions are the highest-value BDRs — the
"why Astro not Next", the SPA-ban for a public site, the API-versioning policy.
Losing them means losing the rationale of the foundations. Capture them BEFORE
STEP 11 FINISH so the memory commit lands on the branch FINISH integrates.

Capture ONLY structuring decisions, not scaffold detail:

| Capitalize — founding (BDR)                                  | Skip — scaffold detail            |
|--------------------------------------------------------------|-----------------------------------|
| Stack / framework choice + why (Astro vs Next)               | directory names, scaffolded files |
| Architecture pattern, data-flow shape                        | dev-tooling / formatter config    |
| Doctrinal exclusions (public site = no SPA, API /v1 day one) | which template files were copied  |
| Security defaults adopted; conventions binding future code   | anything reversible / obvious     |

Source the candidates from: the PROJECT BRIEF (STEP 1), the DESIGN's resolved
decisions (STEP 3), and the validated STACK / CONVENTIONS / EXCEPTIONS (STEP 4
gate). These ARE the founding decisions — the user just approved them.

**No decision → no entry.** A trivial project with no genuine structuring choice
capitalizes NOTHING. Do NOT fabricate a BDR to fill the step. Print
`CAPITALIZE: no founding decision to log`; the memory commit below then no-ops.

1. Pre-fill a BDR-XXX entry per founding decision (id, date, title, decision,
   why, alternatives rejected — from the DESIGN's rejected options).
2. Present grouped:
   ```
   CAPITALIZE — founding decisions proposées
   [ decisions.md ]  BDR-XXX — <decision> — <1-line why>
   Valider lesquels ? (all / <IDs> / edit / skip)
   ```
3. Append approved entries + update the Index. Append a journal line under today.

**Hash rule — founding decisions carry NO commit hash; use path + date only.**
This is by nature, not an omission: a founding decision is made at DESIGN
(STEP 3), BEFORE any code, attested by no implementing commit — there is no hash
to anchor. Anchoring it to the unrelated scaffold commit would be a FALSE anchor
that dilutes what `Reference: commit <hash>` means everywhere else (the commit
that IMPLEMENTS the decision, e.g. BDR-033 → 11792cc). This is the SECOND case
where hash-anchoring does not apply — the first being a squash-merged PR, whose
anchored commit ceases to exist.

**Language rule**: written entries are ALWAYS in English (CLAUDE.md "Memory
registries"). The gate may mirror the user's language; entries must not.

**Then commit the memory** — follow `$HOME/.claude/lib/capitalize-commit.md`: it
surgically commits the approved founding decisions (`.claude/memory` +
`.claude/tasks` only, never `git add -A`) as one `chore(memory)` commit, BEFORE
STEP 11 FINISH so the memory is integrated with the branch, not stranded. If
nothing was capitalized, the helper no-ops — no commit.

## STEP 10c — DOC SYNC
Run BEFORE STEP 11 FINISH (moved here from post-FINISH). doc-syncer PATCHES public docs but
does NOT commit them, and `gitflow finish` integrates only COMMITTED history
— so a patch left uncommitted never reaches the merge/PR. Same PR-stranding class as the
STEP 10b capitalize fix (BDR-034).

Load `$HOME/.claude/agents/doc-syncer.md` (AUTO MODE, scope: files changed this session).
Detect drift, update cmds/vars/structure, add recent changes entry.

**Then commit the docs** — follow `$HOME/.claude/lib/doc-commit.md`: it surgically commits
ONLY the files doc-syncer patched (its `PATCHED_FILES` output, one path per line → one argv
arg each), never `git add -A`, never `.claude/`/`CLAUDE.md`, and no-ops if nothing was
patched. Report per its rc table — rc 4 = a LOUD upstream BDR-022 anomaly, not a silent skip.

> **Scaffold commit owner = STEP 5f `gitflow init`** (root commit embeds scaffold + README +
> `.gitignore` socle + hook, tree clean — BLK-010 closed). This doc-sync commit lands the
> patched docs on the MVP feature branch so they reach the merge.

## STEP 11 — FINISH
Tests pass, build clean, no placeholders. Integrate the MVP feature into develop
— **only on the user's explicit go** (the `gitflow` finish gate):
```bash
bash "$HOME/.claude/lib/gitflow.sh" finish   # feature/mvp → develop
```

---

## RULES
- No skipping steps. No merged agent responsibilities.
- No implement without user approval at STEP 4 and STEP 7.
- Scaffolder = skeleton only, zero logic.
- Features → subagent pipeline only.
- Broken build = unacceptable output.
- Fix all CRITICAL review issues before proceeding.
- Stop if requirements unclear at any step.

---

## FINAL OUTPUT

Two-part output: human recap first, then status table.

### Plain-language recap (2-4 lines)

Write 2-4 sentences a non-technical reader could scan: what was built, what
stack it runs on, whether everything passed, and what to run first. Example:

```
Your <stack> project "<n>" is ready. Build passes, <N> tests green, V1 features
implemented. Open the project with the command shown below to start the dev
server. Anything that's still pending is listed under REMAINING.
```

### Status table

```
PROJECT INITIALIZED: <n>
LOCATION: <path> | STACK: <stack> | BUILD: ✅/❌ | TESTS: ✅<N>/❌
V1 FEATURES: ✅<f> / ⚠️<f> partial: <reason>
REMAINING ISSUES: <list or none>
QUICK START: <exact cmds>
CLAUDE.md ✅ | README ✅ | SETTINGS ✅
```
