---
name: client-handover
description: |
  Use when finalizing a project for non-technical client delivery — needs
  final audits, deploy validation against live site, and a branded
  deliverable (Markdown + HTML + PDF). Multi-agent orchestrator: dispatches
  client-handover-writer which spawns parallel /seo + /harden subagents,
  then /validate, then writes the deliverable.
  Triggers: "client handover", "compte rendu client", "livraison client",
  "rapport client", "deliverable", "summary for client", "handover doc",
  "livrable", "ship and handover", "finaliser et livrer".
argument-hint: [optional: language fr|en, --include-deploy, --skip-deploy, --skip-seo, --skip-audits, --skip-fix-loop, --max-iterations N, --audit-max-age <duration>, --output <path>]
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
2. **BASELINE AUDITS** — Run /seo (SEO+GEO) and /harden in parallel. Capture initial scores (`SCORE_SEO_BEFORE`, `SCORE_GEO_BEFORE`, `SCORE_HARDEN_BEFORE`).
3. **FIX LOOPS (parallel, bounded)** — For each audit < 17/20:
   - Re-invoke the audit subagent with explicit instruction to apply auto-fixes.
   - Re-score.
   - Repeat up to `MAX_ITERATIONS` (default 5).
   - If still < 17/20 after cap → escalate to user with concrete remaining issues; user decides continue / stop / manual intervention.
4. **COMMIT + PUSH** — If files changed during fix loops, run /commit-change (atomic logical commits) then `git push`.
5. **DEPLOY PAUSE** — List exact deploy artifacts: changed files since baseline, deploy hints from project (vercel.json, netlify.toml, Dockerfile, .github/workflows/deploy.yml, etc.), and the deploy process in plain words. Use AskUserQuestion: "Deploy done? (Yes / Not yet / Skip validate)". Block until Yes or Skip.
6. **/validate (live site)** — Run validator-analyzer against the deployed URL. Capture `SCORE_VALIDATE`.
7. **GATE — per-axis threshold ≥17/20** — Compute final `SCORE_*_AFTER` for SEO classique, GEO (IA), HARDEN, VALIDATE. If ANY < 17/20: STOP. Generate `.claude/audits/HANDOVER-ROADMAP.md` with prioritized analysis of what's blocking each below-threshold axis. Do NOT write the client deliverable. Report to user.
8. **DOC GENERATION (only if all scores ≥17/20)** — Read `.claude/memory/` registries + full git history. Ask whether to include build/deploy chapter. Synthesize the client deliverable using the 4-chapter structure:
   - **§1 Ce qu'il fallait faire (et pourquoi)** — brief + motivation, 100–180 words.
   - **§2 Ce qui a été fait** — lay summary, **≤300 words, zero technical jargon**, **no internal tool/skill names** (no `/seo`, `/harden`, `/validate`, `seo-analyzer`, etc. — replace with concept names: référencement / sécurité / conformité technique). Forbidden-token grep gate runs before write.
   - **§3 Ce qui vous reste à faire** — action-only checklist grouped by cadence (one-time / monthly / quarterly / yearly / when something changes).
   - **§4 Détails techniques (pour les curieux)** — score table (SEO classique + GEO + sécurité + conformité, before/after, gated independently at ≥17/20), vulgarized BDR decisions, phases with technical detail, optional glossary.
   - **§5 Annexe — plateformes externes** (web/local-business only).
   - **§6 Annexe — build & déploiement** (only if requested).
9. **RENDER** — Write `LIVRAISON.md` (fr) or `HANDOVER.md` (en) at project root, then run `scripts/handover-to-pdf.sh` to produce the matching branded `.html` (always) and `.pdf` (when a PDF engine is on the host: weasyprint > wkhtmltopdf > chromium). HTML/PDF use the ZenQuality cover page, green palette, Inter + Playfair Display typography, running header/footer with project name + page numbers.

Flags:
- `--skip-fix-loop` — run baseline audits once, skip auto-fix iterations.
- `--max-iterations N` — cap fix loop iterations (default 5).
- `--skip-audits` — bypass entire pipeline; jump straight to doc generation from existing audit files.
- All previous flags still supported (see argument-hint).

Context from the user (if any):
$ARGUMENTS
