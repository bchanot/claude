---
name: client-handover
description: |
  Final ship-and-handover orchestrator. End-to-end pipeline that hardens the
  project, commits, pauses for deploy, validates the live site, and only then
  generates the non-technical client deliverable (LIVRAISON.md / HANDOVER.md).
  Pipeline: (1) /seo (SEO+GEO) and /harden run in parallel with auto-fix loops
  until each score ≥17/20, (2) /commit-change + push if changes made, (3) pause
  to tell user what to deploy and wait for confirmation, (4) /validate against
  the live site, (5) per-audit gate ≥17/20 — stop and analyze if any below,
  (6) write client doc with before/after score table and explicit
  owner-maintenance checklist. Reads git history + .claude/memory/ registries.
  For local-business projects, appends manual SEO/GEO platform checklist (NAP
  consistency across Google Business, Pages Jaunes, Yelp, Facebook, Instagram,
  TikTok, Apple Maps, Bing Places, TripAdvisor, etc.). Asks whether to include
  build/deploy chapter.
  Trigger: "client handover", "compte rendu client", "livraison client",
  "synthese projet", "rapport client", "deliverable", "summary for client",
  "recap projet", "handover doc", "livrable", "ship and handover",
  "finaliser et livrer".
argument-hint: [optional: language fr|en, --include-deploy, --skip-deploy, --skip-seo, --skip-audits, --skip-fix-loop, --max-iterations N, --audit-max-age <duration>, --output <path>]
disable-model-invocation: false
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - WebSearch
  - WebFetch
  - AskUserQuestion
  - Agent
---

Load and follow strictly:
- $HOME/.claude/agents/client-handover-writer.md

Execute the CLIENT HANDOVER WRITER agent on this project.

The agent runs a **ship-and-handover pipeline** with explicit gates:

1. **PRE-FLIGHT** — Detect git repo, project root, language, project type, web sub-type, NAP signals, stack.
2. **BASELINE AUDITS** — Run /seo (SEO+GEO) and /harden in parallel. Capture initial scores (`SCORE_SEO_BEFORE`, `SCORE_HARDEN_BEFORE`).
3. **FIX LOOPS (parallel, bounded)** — For each audit < 17/20:
   - Re-invoke the audit subagent with explicit instruction to apply auto-fixes.
   - Re-score.
   - Repeat up to `MAX_ITERATIONS` (default 5).
   - If still < 17/20 after cap → escalate to user with concrete remaining issues; user decides continue / stop / manual intervention.
4. **COMMIT + PUSH** — If files changed during fix loops, run /commit-change (atomic logical commits) then `git push`.
5. **DEPLOY PAUSE** — List exact deploy artifacts: changed files since baseline, deploy hints from project (vercel.json, netlify.toml, Dockerfile, .github/workflows/deploy.yml, etc.), and the deploy process in plain words. Use AskUserQuestion: "Deploy done? (Yes / Not yet / Skip validate)". Block until Yes or Skip.
6. **/validate (live site)** — Run validator-analyzer against the deployed URL. Capture `SCORE_VALIDATE`.
7. **GATE — per-audit threshold ≥17/20** — Compute final `SCORE_*_AFTER` for SEO, HARDEN, VALIDATE. If ANY < 17/20: STOP. Generate `.claude/audits/HANDOVER-ROADMAP.md` with prioritized analysis of what's blocking each below-threshold audit. Do NOT write the client deliverable. Report to user.
8. **DOC GENERATION (only if all scores ≥17/20)** — Read `.claude/memory/` registries + full git history. Ask whether to include build/deploy chapter. Synthesize concise client deliverable with:
   - Before/after score table (SEO, HARDEN, VALIDATE — values + delta).
   - Plain-language summary of all changes since first commit.
   - **Owner responsibilities** section: explicit checklist of what the client must do / maintain (SEO platforms, content updates, monitoring, deploy if self-hosted).
   - Optional build/deploy chapter.
   - For web projects with local-business signals: manual SEO/GEO platform checklist with registration links.
9. **OUTPUT** — Write to `LIVRAISON.md` (fr) or `HANDOVER.md` (en) at project root.

Flags:
- `--skip-fix-loop` — run baseline audits once, skip auto-fix iterations.
- `--max-iterations N` — cap fix loop iterations (default 5).
- `--skip-audits` — bypass entire pipeline; jump straight to doc generation from existing audit files.
- All previous flags still supported (see argument-hint).

Context from the user (if any):
$ARGUMENTS
