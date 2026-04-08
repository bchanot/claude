---
name: init-project
description: Full project init: interview → design → scaffold → implement (TDD). Two validation gates.
argument-hint: <project idea or description>
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# ORCHESTRATOR: INIT PROJECT

## REQUEST
$ARGUMENTS

---

## STEP 0 — PLUGIN CHECK
Load `$HOME/.claude/agents/plugin-advisor.md`. Feed request.
- ACTION REQUIRED → show RECOMMENDATIONS block, offer: A) fix plugins B) type "force". STOP.
- OK → `✅ Plugin check passed — [active plugins]`, continue.

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

## STEP 5 — SCAFFOLD
Load `$HOME/.claude/agents/scaffolder.md`. Pass: BRIEF + DESIGN + `~/.claude/templates/project-CLAUDE.md` + `~/.claude/CLAUDE.md`.
Creates: CLAUDE.md, settings, structure, config, empty entry points, .gitignore, .env.example. NO README, NO features.
Verify: `git init` + build passes.

## STEP 5b — CREATE README
Load `$HOME/.claude/agents/readme-updater.md`. README.md missing → CREATE mode auto. No stop.

## STEP 6 — PLAN
Invoke `superpowers:writing-plans` with BRIEF + skeleton.
Granular tasks (2-5 min each), exact file paths, TDD: tests before code.

## STEP 7 — VALIDATION GATE #2 ★ MANDATORY STOP
```
INIT PROJECT — IMPLEMENTATION PLAN
SKELETON: ✅ build passes
FEATURES: <N> → <M> tasks
<numbered task list with paths>
Approve and start? (yes / request changes)
```
Changes → back to STEP 6. Approved → continue.

## STEP 8 — IMPLEMENT
Invoke `superpowers:subagent-driven-development`. Isolated subagents, TDD, 2-stage review per task.

## STEP 9 — ANALYZE
Load `$HOME/.claude/agents/analyzer.md`. Check: no regressions, no deviations, no stale scaffold, conventions respected.

## STEP 10 — CODE REVIEW
Invoke `superpowers:requesting-code-review`. Fix all CRITICAL before proceeding.

## STEP 11 — FINISH
Invoke `superpowers:finishing-a-development-branch`. Tests pass, build clean, no placeholders, initial commit ready.

## STEP 12 — SYNC README
Load `$HOME/.claude/agents/readme-updater.md` with arg `sync`. Detect drift, update cmds/vars/structure, add recent changes entry.

## STEP 13 — GSD v2 INIT (optional)
If `multi-session` signal was detected in STEP 0 OR the project has >3 planned milestones:
Ask: "Initialize GSD v2 for multi-session management? (yes / skip)"
- `yes` →
  1. First check: `command -v gsd` — if not found:
     Print: "⚠️ GSD v2 not installed. Run `npm install -g gsd-pi` then re-run `/onboard add gsd` or `/ship-feature` to initialize later."
     Do NOT attempt `gsd init`. Skip to RULES.
  2. If `gsd` is in PATH: run `gsd init` in the project directory to create `.gsd/` and `ROADMAP.md`.
     Populate ROADMAP.md with milestones from BRIEF (v1 features + any beyond-v1 items).
     Print: "✅ GSD v2 initialized — run `gsd` in terminal then `/gsd auto` to work autonomously."
- `skip` → print: "GSD v2 skipped — use `/ship-feature` for individual features."

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
```
PROJECT INITIALIZED: <n>
LOCATION: <path> | STACK: <stack> | BUILD: ✅/❌ | TESTS: ✅<N>/❌
V1 FEATURES: ✅<f> / ⚠️<f> partial: <reason>
REMAINING ISSUES: <list or none>
QUICK START: <exact cmds>
CLAUDE.md ✅ | README ✅ | SETTINGS ✅
```
