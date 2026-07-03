---
type: journal
schema:
  entry: one date heading per working session
  body: 3-5 lines max - what was done, decided, blocked
rules:
  - One heading per date (YYYY-MM-DD), not per session.
  - Append at end. Never edit past entries.
  - Keep terse. Details belong in decisions/learnings/blockers - timeline only.
---

# Journal

## 2026-04-23

- Restructured tree: `tasks/` → `.claude/tasks/`, created `.claude/memory/` (5 registries) + `.claude/audits/`.
- Adapted CLAUDE.md + skills `onboard`, `init-project` + agent `onboarder` + `lib/project-archetypes/dotfiles-meta.md`.
- Added CAPITALIZE step in `ship-feature`, `bugfix`, `hotfix`, `feat`, `commit-change` + created `/close` skill for session-end ritual.
- 2nd user verify-gate caught bugs: `.gitignore` broke tracking (fixed BDR-003); harden/validate dispatcher bash broken after audit move (LRN-002).
- Audits routed to `.claude/audits/` (seo/geo/harden/validate/code-clean) + `MIGRATION.md` written for existing projects.
- 9 atomic commits (`c721a36..a9606aa`) via `/commit-change` — first real exec of Phase 4 CAPITALIZE.
- Decisions logged: BDR-002, BDR-003. Learnings: LRN-002. Blockers: BLK-002.
- English-only rule enforced in all CAPITALIZE specs (commit `bfcca72`); 9 existing entries retrofitted to English in follow-up commit.

## 2026-04-27

- Settings: switched `permissions.defaultMode` from `"default"` to `"auto"` and dropped `disableAutoMode: "disable"` (BDR-004); reorganised top-level keys + added `effortLevel: "xhigh"`; removed stale root `TODO.md` (already migrated to `.claude/tasks/TODO.md`).
- Learning: Claude Code `disable*` settings use sentinel string `"disable"`, not boolean (LRN-003).
- 3 atomic commits (`f7f033f..1421578`) via `/commit-change`.
- Animation lib autoflow added: new helper `lib/animation-lib-check.sh` + STEP 5e in `/init-project` (auto-install) + STEP 2.5 in `/onboard` (opt-in) + read-only detection in `plugin-advisor` PHASE 1/2/3 + signal in `lib/design-gate.md` + scaffolder note. `motion` chosen over legacy `framer-motion` (BDR-005, LRN-004).

## 2026-05-03

- Added `JuliusBrussee/caveman` as 4th always-on plugin (BDR-006). Full install: plugin + standalone hooks + caveman-shrink MCP scaffold (snippet only, not auto-registered — proxy needs upstream wrapper, LRN-006).
- Discovered two co-masking bugs: `claude plugin install` doesn't enable (LRN-005) + `session-start.sh` hardcoded "✅ ON: security-guidance rtk superpowers" regardless of actual state. Added `enable_plugin()` helper + `plugin_enabled()` detector reading `enabledPlugins` from `settings.json`. Banner now reflects reality.
- Side fix: doctor.sh exited under `set -euo pipefail` when gstack/skills/ missing — wrapped find in brace + `|| true`.
- 3 atomic commits (`0184818..2ec7935`).

## 2026-05-04

- Built skill profile system (BDR-007): `lib/profile.sh` + `lib/profiles/{design,dev,qa,audit,minimal}.profile` partition gstack + personal skills by purpose. Activation toggles symlinks `skills/` ↔ `skills-disabled/`.
- Wired into `agents/plugin-advisor.md` (DETECT call to `profile.sh current` + new `PROFILE` line in OUTPUT + new "Skill profiles" subsection in TOGGLING EXTERNAL TOOLS), `lib/toggle-external.sh` (header pointer), `Makefile` (4 targets), `skills/profile/SKILL.md` (`/profile` slash command).
- `cmd_current` honestly reports "full" when no `gstack__*` entry exists in `skills-disabled/` — avoids "100% match" trap when full gstack on.
- Tested end-to-end: list/show/current/diff/set/reset/apply all green; shellcheck clean; symlink state restored after reset.
- Profile system v2 (BDR-008): extended `profile.sh` to toggle Claude plugins (`claude plugin enable|disable`) + MCP servers (`magic` via `lib/toggle-external.sh`). Added 4 new profiles: `web`, `seo`, `web-full`, `backend`. Refined existing profiles to use `plugin@<marketplace>` syntax + `cli` entries. Always-on plugins protected by `MANAGED_PLUGINS` allowlist + `PROTECTED_PLUGINS` denylist.
- Verified: `set web` enables ui-ux-pro-max + magic; `set seo` disables ui-ux-pro-max; `set minimal` disables ui-ux-pro-max but spares caveman/security-guidance/superpowers. `current` heuristic respects ties (web-full beats web at 100%).

## 2026-05-05

- Mandated caveman format on all `.claude/memory/*.md` writes (BDR-009). Rule added to CLAUDE.md "Memory registries" section. Self-applied: CLAUDE.md prose compressed in same pass.
- Compressed 5 existing registries via `/caveman:compress` (decisions, learnings, blockers, journal, evals) — ~40% input-token reduction per session-start load.
- Side chores: disabled `example-skills@anthropic-agent-skills` plugin in settings.json; gitignored `*.original.md` compress backups (recoverable via git history).
- 4 atomic commits (`0275eed..639486a`) via `/commit-change`.

## 2026-05-06

- darwin-skill round 1 across 18 personal skills. Mean 83.4 → 88.7 (+5.3). 16 keeps, 2 reverts (code-clean, doc — D2 dry_run noise). Branch `auto-optimize/skills-20260506-1730`. 22 commits, 35 files changed.
- Top gains (analyze +18.5, skills-perso +11.9, refactor +11.0, hotfix +9.0) all from same shape: edge-case table in agent file. Captured as LRN-008.
- LRN-009: dry_run ratchet too strict for skills already >91; LRN-010: `~/.claude/skills,agents` symlink to Documents/claude — git operations must run from there.
- Audit report `.claude/audits/DARWIN-SKILL-OPTIMIZATION.md`. Eval log `~/.agents/skills/darwin-skill/results.tsv` (38 rows). Branch awaits manual review before merge.

## 2026-05-07

- /client-handover gates SEO classique + GEO (IA) independently at ≥17/20 (BDR-010). Was: combined display only, gate fired on SEO alone. Now: 4-axis gate (SEO, GEO, HARDEN, VALIDATE), axis-aware fix loop, per-axis override transparency.
- Pattern captured as LRN-011: single subagent emits N gated scores → labeled extraction + axis-aware loop + per-axis escalation. Generalizes to future multi-metric audits (e.g. /harden split TLS/headers/redirects).
- 1 atomic commit `5569a80` (`feat(client-handover): split SEO + GEO scores, gate GEO at ≥17/20`). Bash unit tested `extract_score_labeled` on 4 cases (new format, /100 normalize, legacy fallback, GEO UNKNOWN strict) — all OK.
- /client-handover deliverable refactor (BDR-011): 4-chapter structure (brief+pourquoi / fait ≤300w sans jargon / actions client / détails techniques) + branded HTML+PDF via ZenQuality identity (greens `#1A3A25/#2D5A3D/#4A7C59/#87A878`, Inter+Playfair Display, cover page logo+tagline). Cascade renderer: MD→HTML (pandoc>python markdown>npx marked) then HTML→PDF (weasyprint>wkhtmltopdf>chromium).
- STEP 15 hard gates: chapter 2 word count ≤300 (`wc -w`) + forbidden-token grep (no `/seo`, `/harden`, `/validate`, `SEO.md`, `SCORE_*` etc. in chapters 1–3). Chapter 4 may use them in glossary.
- LRN-012 captured: bash heredoc + stdin pipe collision (`printf | python3 - <<'PY' ... PY`) silently drops piped data — heredoc wins stdin. Diagnose via `bash -x`. Fix: pass via env var or file path, never via stdin combined with heredoc. Hit during v1 `handover-to-pdf.sh`, fixed before commit.
- 1 atomic commit `e06b52a` (`feat(client-handover): 4-chapter doc structure + branded HTML/PDF rendering`). End-to-end tested with synthetic boulangerie handover (179w chapter 2, no leaks, HTML 11KB + PDF 33KB via weasyprint).
### 2026-05-07 — /client-handover PDF rendering bugfix

- Fixed 3 bugs in `/client-handover` PDF generation reported on `LIVRAISON.pdf` test render.
- **Bug 1** (critical): MD→HTML converter chain — host had no pandoc, no python-markdown, fell to `npx marked < "$src"` which dumped marked CLI's own `cli.js` source instead of converting (marked 16.x stdin regression). PDF was 2 pages of marked binary source. Fix: `npx --yes marked --gfm -i "$src"`. → LRN-013.
- **Bug 2**: cover bg was cream `#F5F0EB` with 8mm green stripe — washed out. Final state after iteration: `--white-pure` bg + subtle radial sage/forest tints + `--black-deep` text + `--green-forest` accents (eyebrow/meta labels/footer/border). Solid green-dark tried first then rejected (too heavy for long client doc). → BDR-012.
- **Bug 3**: SVG logo `logo-horizontal.svg` blended into cream bg. Default `LOGO_URL` switched to `https://zenquality.fr/assets/logo-horizontal-1024.png` (URL provided by user). High contrast on white bg.
- Verified: regenerated `LIVRAISON.pdf` → 164 KB, 19 pages, full content rendered, white cover with black title + green-forest accents + visible PNG logo.
- Files touched: `skills/client-handover/scripts/handover-to-pdf.sh`, `skills/client-handover/resources/branding/zenquality.css`, `agents/client-handover-writer.md`.

## 2026-05-11

- Personal-skills orchestrator audit via `/darwin-skill`. 18 skills classified: 5 true orchestrators (ship-feature, seo, init-project, onboard, client-handover) + 12 single-delegation (justified — 6 agents reused multi-place) + 1 self-contained (skills-perso). All orchestrators verified doing real multi-agent dispatch.
- `client-handover` pattern is skill→1 agent→subagents (3-level indirection) vs other 4 orchestrators' skill→multi-agent (2-level). Justified by agent complexity (1703 lines) — moving orchestration into SKILL.md would bloat. Description updated to make orchestrator role explicit.
- `/seo`, `/harden`, `/validate` execution verified inside client-handover-writer agent — dispatches general-purpose subagents reading the target skill files. Real parallelization, not sequential.
- Description CSO fix per `/writing-skills`: 5 skills had frontmatter >1024 chars (client-handover 1920, doc 1390, seo 1378, geo 1189, validate 1050) — all compressed under spec. 3 orchestrators (ship-feature, init-project, onboard) had workflow-summary descriptions (shortcut risk) — rewritten to "Use when [triggers]…" pattern. Captured as BDR-014.
- client-handover deliverable restructured 4→6 chapters (BDR-013 supersedes BDR-011): scores promoted to §2 for 30s visual-proof-of-impact, NAP table promoted to §4 as prerequisite before §5 todos. Pandoc bumped to `gfm+gfm_auto_identifiers` for internal anchor links (LRN-014).
- NAP checklist polish (commit `abd2612`): added "Description courte" field + replaced retired BrightLocal Free Tools with Moz Local Citation Checker (LRN-015).
- CSS bugfix (commit `465fe9e`): pandoc GFM checkbox markup `<li><input ...> text…</li>` has no wrapper class, adjacent-sibling rule `li input + *` yanks `<a>`/`<code>` siblings out of flow. Fixed by targeting `li > input[type="checkbox"]` directly. Captured as LRN-016.
- 4 atomic commits `b15b275..1da6a31` via `/commit-change`. Decisions BDR-013, BDR-014 + learnings LRN-014, LRN-015, LRN-016 capitalized. Pre-existing BDR-012 + LRN-013 Index rows backfilled (prior session entries existed in body but missing from Index).

## 2026-05-12

- Ran `/darwin-skill` full pipeline on cwd repo (real skill source, not `~/.claude/skills/` runtime mirror). Baseline scored 23 personal skills + 5 broken gstack symlinks excluded. Avg baseline 75.6.
- Phase 2 round 1 on bottom 5: status 45.3→76.2 (+30.9), refactor 48.4→74.3 (+25.9), plugin-check 59.2→76.8 (+17.6), skills-perso 66.4→80.1 (+13.7), commit-change 69.6→83.5 (+13.9). All KEEP. Avg 58.0→78.2 (+20.2/skill).
- Rounds 2-3 skipped — diminishing returns past round 1 on dispatcher pattern. graphify (29.0, 62KB SKILL.md) deferred to Phase 2.5 exploratory rewrite per user.
- Pattern observed: thin-dispatcher round-1 invariant = fallback + frontmatter triggers. Replicable across the 4 dispatchers tested. Captured as LRN-017.
- Methodology gotcha: darwin eval subagents drift on total math (factor-10 errors, D8 weight 7 vs 25). Direction reliable, magnitude noisy. Captured as LRN-018. Recompute totals in main thread going forward.
- BDR-015: broken gstack symlinks (5 dirs) excluded from darwin scope — external ownership + missing targets.
- BLK-003: `scripts/screenshot.mjs` hardcoded macOS path → PNG cards skipped on Linux. Markdown report + 5 new test-prompts.json + 5 optimized SKILL.md only. Upstream issue, workaround in place.
- Branch `auto-optimize/20260512-1319` merged via `--no-ff` to master. 6 commits land. Report at `.claude/audits/DARWIN-SKILL-2026-05-12.md`. results.tsv at `~/.agents/skills/darwin-skill/results.tsv` (33 rows).
- Pre-existing uncommitted `agents/doc-syncer.md` (mtime 15:33, before session) NOT touched — left for the work session that owns it.

## 2026-05-15

- `/commit-change` over working tree: 2 commits land. `7ee9b42 feat(doc-syncer): README mandatory + 14-section prod-only DEPLOY.md` reworks STEP 5/6/8/A4 — README AUTO+unconditional, DEPLOY.md prod-only, 14-section VPS template. `f57a7f2 chore(settings): enable ui-ux-pro-max skill` toggles `ui-ux-pro-max@ui-ux-pro-max-skill` false → true.
- BDR-016 capitalized — README AUTO+unconditional + DEPLOY prod-only is design decision: opt-out makes repo look abandoned, mixed dev/prod DEPLOY = drift source. README has only `yes`/`edit` at validation gate, no `skip`.
- LRN-019 capitalized — doc split by audience (README=dev, DEPLOY=ops) generalizes across deployable projects. 14-section VPS template = ceiling not floor, drop sections that don't apply. Audience test: junior dev → README, on-call SRE → DEPLOY.
- Skipped: `skills-external/gstack` (submodule pointer unchanged, only `.gbrain/`+`.hermes/` untracked inside), `Screenshot from 2026-05-09 02-40-42.png` (binary, default-exclude).

## 2026-05-18

- `/feat` adds `lib/profiles/full.profile` — superset of web-full + plan + dev + audit + deploy + session hygiene. Use case: `/profile set full` before `/init-project` to have brainstorm → design → architecture review → scaffold → implement → ship → audit pipeline in one session.
- BDR-017 capitalized — `full` profile rationale: init-project covers 13 steps touching all skill families; existing profiles slice (web-full = website, dev = code, audit = audit). One named profile beats `apply web-full && apply dev && apply audit`.
- LRN-020 capitalized — sentinel/identifier collision pattern: `cmd_current`'s "full (no profile set)" literal collided with new profile name. Rule: sentinels must be outside the entity namespace. Renamed to "none".
- Commit `feat(profile): add full profile` — 3 files (+86 -1).

## 2026-05-20

- `/bugfix` on `/ship-feature` blocker — orphan wrapper at `~/.claude/commands/ship-feature.md` referenced 6 agent files; 5 deleted by refactor commits `0241e1d` + `21960e0`. Removed wrapper; skill at `~/.claude/skills/ship-feature/SKILL.md` is sole `/ship-feature` resolver.
- BLK-004 capitalized — wrapper survived refactor because untracked in `~/.claude` git repo + never sweep-audited post-migration.
- LRN-021 capitalized — post-refactor sweep rule: `grep -rln "agents/foo.md" ~/.claude/commands/` after any orchestrator migration. Add to `/onboard` + `/init-project` audit phase.

## 2026-05-21

- `/hotfix` on `/profile set full` warning — `⚠ missing: checkpoint — try: bash link.sh` despite link.sh reporting all symlinks up to date. Root cause: gstack upstream renamed `checkpoint` skill to `context-save` (shadow conflict with Claude Code native `/checkpoint` rewind alias). Five profile files (dev, backend, full, web, web-full) + `CLAUDE.md` routing line referenced dead `checkpoint` name. link.sh can't materialize a skill that no longer exists upstream → misleading next-step hint.
- Fixed: `s/checkpoint/context-save/` in 5 profiles (commit `69c5ded`). `CLAUDE.md:193` routing line also updated locally but left uncommitted — file carries unrelated in-progress graphify section rewrite.
- BLK-005 capitalized — gstack submodule bump can silently break profile entries; status: resolved.
- LRN-022 capitalized — post-submodule-bump audit rule: diff `skills-external/gstack/` skill list against `lib/profiles/*.profile` entries before pushing.
- `/hotfix` follow-up — `bash "$HOME/.claude/lib/profile.sh" current` falsely reported `none (all gstack skills enabled — no profile set)` even with profile applied + 14 gstack__* entries in repo's `skills-disabled/`. Root cause: `lib/profile.sh:43` used `cd "$(dirname $BASH_SOURCE)/.."` — default bash `cd` preserves symlinks, so `$REPO` resolved to `/home/bchanot-ubuntu/.claude` (symlink dir) instead of real repo path. `$DISABLED_DIR` then pointed at near-empty `~/.claude/skills-disabled/` (2 stale npx symlinks only). Fixed by adding `-P` to `cd` (commit `a4558ee`). `cmd_current` now correctly reports `full (100% match, 14 gstack skills disabled)`.
- BLK-006 capitalized — `cmd_current` false-negative when invoked via `~/.claude/lib/profile.sh` symlink; status: resolved.
- LRN-023 capitalized — `$REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` mandatory pattern for any script meant to be invoked via a symlink into the install location.

## 2026-06-02

- Added `profile gstack on|off` verb to `lib/profile.sh`. `on` = re-enable all parked gstack keeping `.active-profile` label intact (vs `reset` which clears to "none"); `off` = disable gstack not in active profile (errors if none). User wanted centralized toggle without losing profile context.
- Extracted 3 helpers (`enable_all_gstack`/`disable_gstack_not_in`/`parked_gstack_count`); refactored `cmd_reset`+`cmd_set` to reuse — behavior preserved, 6-case test + exact state-restore assertion PASS, shellcheck CLEAN. Doc: SKILL.md argument-hint + examples + output-policy. Makefile generic `make profile cmd="gstack on"` already covers it.
- Corrected own false flag: full.profile omitting ios-*/spec is curation by design (BDR-017 caveat), NOT a bug — caught before any edit. Surfaced real gap: 6 gstack source skills unlinked post-submodule-bump → BLK-007 (open, gstack ./setup domain, not auto-fixed).
- Backfilled index drift: decisions (BDR-017), blockers (BLK-005/006).
- BDR-018 + LRN-024 + BLK-007 + EVAL-002 capitalized.
- Treated BLK-007 (resolved). Root: gstack submodule bump added `spec` (v1.47) + iOS device-farm 5 skills (v1.43); gstack `./setup` not re-run → 6 source-only, unlinked. Decision: linked `spec` only (surgical symlink matching setup:440-476), added to `full`+`web-full` profiles; iOS NOT linked (Linux host, needs Mac daemon+Tailscale = dead skills). Completed `.gitignore` gstack allowlist (12 missing added incl. 6 parked that would noise on `gstack on`, stale `checkpoint` removed). Verified: spec enabled, allowlist drift EMPTY, profile.sh parses.
- LRN-025 capitalized — `.gitignore` allowlist must cover ALL toggleable gstack skills (parked too), else `gstack on` surfaces untracked symlinks; reconcile profiles + gitignore + link/no-link per platform after every submodule bump.

## 2026-06-09

- Built `/capitalize` skill (`skills/capitalize/`) — pre-`/clear`/`/compact` flush: scan conversation → dedup vs registries → propose only NEW + uncaptured → approval gate → write all 5 registries. Distinct from `/close` (no dedup) + `/prune-memory` (curation).
- Baseline-tested per superpowers:writing-skills: RED (no skill) double-logged one incident across LRN+BLK; GREEN (skill) passed clean on isolated fixture (2 new written, 2 dups dropped, trivial skipped, correct IDs, append-only). REFACTOR added "one incident → one primary registry" counter. Dedup half inconclusive (toy fixture eyeball-able — value shows at real registry scale).
- Removed `disable-model-invocation` from all 19 editable skills (8 `true` blocked model+orchestrator routing incl `ship-feature`; 11 `false` were no-op noise). Aligns with CLAUDE.md routing — model/orchestrator can now self-route. Conceded own wrong "destructive" framing; real guard = careful/guard hooks.
- BDR-019 + LRN-026 capitalized.

## 2026-06-11

- Built `/audit-delta` skill (`skills/audit-delta/`) — recurring multi-axis audit (conformity CLAUDE.md / errors / deadcode / security), checkbox selection, scope = delta since last run via per-axis SHA markers in `.claude/audits/audit-delta-state.json`. Per axis: read-only audit → approval gate → fix → mandatory re-verify (same-axis re-audit + project checks) → marker advance. Answered user need: no existing skill covered "since last run" (health re-scans all, retro time-window, code-review branch-only).
- TDD per superpowers:writing-skills, 4 worktree-isolated subagent tests: RED baseline 7 gaps (file-date boundary guess, prose checkpoint, single marker, no gate under "fix + meeting" pressure, lint=verify, mixed pass, auto registry writes); GREEN passed under same pressure (gate held, 0 fixes); REFACTOR found + patched unreachable-first-run hole (default full report-only, never from-HEAD); re-test pass. Worktrees cleaned.
- BDR-020 + LRN-027 capitalized. Uncommitted — /commit-change pending.
- Darwin run on `audit-delta`: 87.5 → 89.9, 2 rounds kept (0d2ece7 unreachable-user branches, 9fc93fa contradiction + corrupted-JSON + fail-closed revert), 8 live fixture tests + 4/4 blind-judge consensus, HL-4 stop, ff-merged to master. Result card generated. LRN-028 (baseline contamination) + LRN-029 (judges catch self-review misses) + EVAL-003 capitalized.
- Darwin eval 26 perso skills: 5 judges structure (33.5–66.8/76), 5 full_tests. Stubs score low but execute great (substance in agents/*.md) — judge system not file. 4 confirmed bugs fixed + merged (geo headless gate ★, init-project broken ref, analyzer contradiction, onboard frontmatter); geo re-test 0 source edits, judges 2/2. Overwrote 5 existing test-prompts.json by mistake — restored. EVAL-004.

## 2026-06-12

- Fable 5 audit global CLAUDE.md → refactor e7e9dac: 4 contradictions (graphify x2 stale, plan-skip, deviations, append-only), 3 dead refs, restructure (Tooling & skills + This-repo-only sections), routing +8 skills + gstack-OFF rule, caveman compress non-critical only (-1471 chars net). Security/Architecture verbatim by design. BDR-021.

## 2026-06-18

- Explained `claude-agent-sdk` = lib to build YOUR own agent programs (NOT a powers-boost for the running Claude Code); pipx `--include-deps` wrong for a library (polluted PATH w/ 6 CLIs + jsonschema collision), venv is right home. Install deferred pending user's intended use.
- Added CLAUDE.md `## Workflow` subagent-delegation rule (fan-out → delegate, not serial) countering Opus 4.8 under-delegate trait. 2 commits: bc7f657 (settings model-pin removal), 02a0ba0 (CLAUDE.md). LRN-030 capitalized.
- Note: learnings.md Index missing LRN-028/029 rows (pre-existing gap, left untouched — out of scope).
- Rewrote `agents/doc-syncer.md` (commit edff761): scope = public docs only; `.claude/` + `CLAUDE.md` read-only context (never target, never copied into public doc); added CONVENTIONS (Standard-Readme/Diátaxis/Keep-a-Changelog+SemVer/Conventional Commits), lean README, CLEAN mode. Conserved stack/DEPLOY-14/gate/AUTO-MODE. BDR-022 capitalized. decisions.md Index also missing BDR-021 row (same pre-existing gap).

## 2026-06-19

- Merged `/close` into `/capitalize` — 2 modes (default flush + `--ritual` reflection), new STEP 2B TODO reconcile (PASS A restraint-only, PASS B explicit-capture + anti-noise filter + orientation→BDR routing), STEP 3 gate gains separate TODO block. `/close` now thin alias → `/capitalize --ritual`. BDR-023.
- Built via superpowers:writing-skills TDD: RED v1 baseline too easy (passed) → strengthened to RED v2 (pressured) which failed on anti-noise + invented subtask + no gate → GREEN passed. Gate STOP itself untested (non-interactive harness) — flagged as skill Red flag.
- LRN-031: skill value = gate + anti-noise + determinism, NOT re-coding what a capable agent does free; if RED baseline passes, harden the fixture before writing.
- Docs routing synced (CLAUDE.md table + README + USAGE) in separate commit; caveman-purge WIP in those files left unstaged. Commits 9dc2b83, be0f047, 765e9d7.

## 2026-06-23

- Reverted commit 1ddeed1 (centralized `lib/install-prereqs.sh`) — over-engineered for the real blocker. Replaced with minimal npm-via-nvm fallback in `install.sh` (b6cc8b1). Re-added `jq` prereq inline + `doctor.sh` fail-level (2194b11). BDR-027.
- Diagnosed gstack chromium fail on Ubuntu 26.04: Playwright 1.58.2 doesn't list 26.04. Fix = gated `PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntu24.04-x64`, wrapper-only (no submodule edit), install + runtime (211c7d4). Verified ldd + headless render on 26.04. BLK-008, LRN-038.

- Fresh-install audit: `make install` drifted 4 repo files. Root-caused each: graphify installer clobbers `CLAUDE.md` (deletes `# This repo only` header) + injects MANDATORY hooks in `.claude/settings.json`; `claude plugin install` flips `example-skills`→true + adds `plugin-dev` in `settings.json`; example-skills `cp` churns `frontend-design`; `npx skills add` pollutes repo `.agents/` + `skills-lock.json`.
- Fix: reverted current drift (`git checkout` 3 configs); added snapshot+trap-restore guard in `install-plugins.sh` (curated config now install-immutable); de-vendored frontend-design + gitignored `/.agents/` + `/skills-lock.json` (anchored so `agents/` stays tracked). Guard tested drift→restore. Commits 51afe9b / 7de8761. BDR-028, LRN-039.

- gstack chromium fix BACKFIRED: the `PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntu24.04-x64` pin made `make plugin` HANG at extraction on real 26.04 (download hits 100%, chrome never extracts) — worse than the original 0.5s fast-fail. Reverted (b9c3937). Root: isolated `ldd`+render proof used a sibling already-extracted build (rev 1228), masking the rev-1208 install-path hang. gstack browser stays unavailable on 26.04 (OFF by default); real fix upstream. Corrected BLK-008 + LRN-038.

- gstack browser FIXED on Ubuntu 26.04 (full saga). `git submodule update` would NOT help (latest gstack still pins playwright 1.58.2). Two layers: (1) bumped Playwright→1.61 in submodule (native 26.04 build), (2) GSTACK_CHROMIUM_NO_SANDBOX=1 for AppArmor userns block. Both automated in install-plugins.sh (auto-bump gated on dep support-list grep; env gated on apparmor sysctl) + env to .bashrc. Verified browse drives a real page (200). Discovered user's .bashrc is hand-managed (installer's env lines had been wiped by a restore). Commit 3b8ffb1. BDR-029, LRN-040, BLK-008 resolved.

- Fixed MAGIC_API_KEY false-negative: check grep'd `repo/.env` (symlink), never created because `~/.claude/.env` was made AFTER link.sh on the fresh machine (and `make plugin` skips link.sh). install-plugins.sh now self-heals the symlink + both scripts use a tolerant regex (export/whitespace/non-empty). Immediate fix: `make link`. Sandbox blocked all `.env*` reads → diagnosed via dir listing + synthetic-line regex tests. Commit 1b028cb. LRN-041.

- Removed obsolete `alias claude='claude --effort max'` from install Step 9 — settings.json `effortLevel: xhigh` is the source of truth and the CLI alias would override it (forcing max over xhigh). Step 9 now also strips the alias + old CLAUDE_EFFORT from the profile if present. A dtach `cc` launcher was prototyped then dropped — deferred to a later sprint (per user). Why missed earlier = EVAL-005 (never cross-audited existing Step 9 lines vs settings.json).

- Made install self-sufficient + gstack on-demand per profile (user: "make install doit TOUT installer"). 3 root causes via install log: (A) install.sh ran link.sh BEFORE install-plugins.sh which never re-linked → npx-skill symlinks never created on fresh run; (B) `npx skills add` + gstack `./setup` resolve target relative to CWD → darwin-skill landed in `$REPO/.agents/skills`+`$REPO/.claude/skills`, not `$HOME/.agents/skills` (self-reinforcing once `$REPO/.agents` exists); (C) `profile.sh set full` → 35 "missing — try bash link.sh" (wrong remedy) because gstack OFF + skills never in `skills/`. Fixes: install-plugins.sh runs npx from `$HOME` + cleans parasites + Step 10 final re-link; update-all.sh same npx fix; profile.sh `enable_skill gstack` symlinks on-demand from submodule (gstack OFF default, ON per profile). Verified live: link.sh → darwin OK; `set full` → 0 missing / 35 on-demand; minimal↔full cycle re-parks/restores; git clean. Residual: `$REPO/.claude/skills/darwin-skill` rm blocked by `.claude/` permission guard → auto-cleaned next `make plugin`. BDR-030, LRN-042.

## 2026-06-25

- Probe #21858: user-level path-scoped rules (`paths:` frontmatter in `~/.claude/rules/`) don't load in CC 2.1.190. 3-file probe → control (no-paths) PRESENT, path-scoped ABSENT. Native auto-memory on but empty (fresh machine). Probe files cleaned. BLK-009.
- Compressed global CLAUDE.md 317→275 (−42, loaded every session): routing (cut name-obvious lines, keep non-derivable signal + dense catch-all; restored `validate`/`plan-eng-review`, feat/hotfix pointer), design (+ explicit FILE signal), graphify, then decorative `---` + blank rognage. Caveman→250 declined (readability + instruction-fidelity). Commits ba743cf, 990318c. BDR-031, LRN-043.
- Edit/Write refuse write-through-symlink → resolve real path (`readlink -f`); `~/.claude/CLAUDE.md` → repo. LRN-044.
- Inspected dirty gstack submodule (parent showed `m`): `package.json`+`bun.lock` = the Playwright 1.58.2→1.61 bump (BDR-029/BLK-008), NOT restore noise → left intact, NOT cleaned, NOT committed (submodule ref stays at clean 070722ace; local patch re-applied by installer by design).
- Renamed skill `/validate` → `/web-validate` (user-surface only): git mv + name + H1 + CLAUDE.md routing + 6 profiles (functional) + cross-refs + agent dispatch + README/USAGE. KEPT: `validator-analyzer` name (lockstep), `.validate-cache`/`VALIDATE.md` (audit-file family), `.claude/` history (append-only), NL triggers. Critical catch: client-deliverable leak-guard regex (`client-handover-writer.md:1462`) matched `/validate` by exact token — `web-` prefix broke the anchored match → extended to `web-validate|validate` (covers legacy docs). Verified complete: `/validate` 0 in active code, `html-validate` 15 intact, regex shows both. Commits e5e673a + dbab542 (BDR-032/LRN-045) + a1cc753 (TODO L167 annotated additively). gstack submodule untouched.
- TDD'd `/prune-memory` (only destructive skill, untested + carried a false `Fixed in v1.1 (TDD found it)` claim): 6 dangers (RED-1..6) closed by deterministic guards, skill `0a3e766`. Real-data run on learnings.md exposed SAFE≠USEFUL (compression marginal on dense; value = index/merge, not C) + a 13/13-false-positive line-grep fidelity guard → replaced by a per-entry count census (0 FP, proven counting both sides). RED-7 (example-priming) + RED-8 (added-negation) filed in BACKLOG. EVAL-006, LRN-046/047/048.
- Wired `design-gate.md` §4: anim-lib suggestion when a design task hits a motion signal — suggest-only, non-blocking, stateless 1-line (no marker). `motion`/`animate` added to §DETECTION (source). Chose stateless-minimal over a state marker, conditional on stakes: a 1-line cosmetic note's re-fire is annoyance not risk → no marker-grade infra (unlike LRN-046/047's destructive context). Helper unchanged, no 3rd copy of the lib list. Live via symlink. BDR-033, LRN-049.
- Process: caught "write-before-show" twice this session on a live (symlinked) file → on edit=deploy targets the pre-write diff is the only control gate → inverted to show→validate→write. LRN-050.

## 2026-06-26
- Coupled-capitalize invariant v1: dev flows auto-commit memory via include `lib/capitalize-commit.md` + helper `lib/memory-commit.sh` (surgical pathspec, never `-A`; hash→stdout). Frame 2 (après-code-couplé, hash-anchoring kept, 2 commits, memory commit automatic per flow). 6 commits `58cb91d..df60df6`. BDR-034, LRN-051/052, EVAL-007.
- Caught `git commit -- pathspec` strict-on-no-match by real-exec test (would silent-abort on majority of flows) → `_changed_paths` filter (LRN-051). ship-feature reordered CAPITALIZE→before FINISH (fixes memory stranded outside PR). init-project STEP 10b founding decisions (no hash by nature, LRN-052). Hook v2 + doc-sync twin chantier deferred.
- TDD: 13 deterministic + in-vivo e2e, shellcheck clean (EVAL-007). Pre-existing Index drift (decisions 11, learnings 21 rows missing) noted for /prune-memory — not backfilled here.
- analyze-before-plan v1 — read-before bookend of coupled-capitalize. Include `lib/analyze-before-plan.md` (two-pass on `## ID` headings, disposition-not-reading invariant, guarded no-op). Wired: ship-feature 0d (inject+reconcile gate), bugfix 2.5, feat 0.6, hotfix opt-in; init/onboard no-op (test-backed). Index drift measured exact: decisions 11/34, learnings 21/52, blockers 2/9. Code commit 67c6a81. BDR-035, LRN-053/054/055/056/057.

## 2026-06-27
- Doc-sync coupled invariant (twin of BDR-034, BUILT not reordered): new `lib/doc-commit.sh` (inverse-scope surgical, fail-closed exit 4 on `.claude/`) + `lib/doc-commit.md` include; doc-syncer emits `PATCHED_FILES` (one path/line) → agent → distinct argv (space-safe). 2 orchestrators reordered DOC SYNC before FINISH (ship-feature 9→8, init-project 12→10c, GSD 13→12), 3 inline flows wired (feat/bugfix/hotfix). 6 commits `ae1f218` · `4a54a65` · `fb1f359` · `636b491` · `e81f629` · `1b01b95`. 28/28 real-exec, shellcheck clean. BDR-036, LRN-058/059/060, EVAL-008.
- Sweep caught PRIOR-chantier debt (README:153 stale since e8eff7e's swap) + expanded scope to 3 inline flows (asymmetry vs memory was decider). Swap flips meanings ≠ letter-insertion (LRN-059). Deferred note "reorder only" refuted in read-phase — doc-syncer commits nothing (LRN-058). BLK-010 (scaffold/unborn HEAD + worktree) + BLK-011 (GSD ROADMAP post-FINISH) deferred = new work.
- v2 capitalize Stop-hook REJECTED on facts: `Stop`=per-turn (self-defeat, nags mid-flush, LRN-047), `SessionEnd`=debug-log-only (can't nag) + gate-bypass. Real gap = OUBLI de câblage: `/capitalize`+`/close` never call `capitalize-commit.md` (predate it 7-60d; wiring commits never touched them; commit done by hand 35×, orphans self-heal). Redirect = wire the include (STEP 5B); `/close` alias follows. BDR-037 + LRN-061 (capstone: runtime net for an unwired skill → check wiring first; deterministic gap = fix structurally, non-det aléa = net OK cf BDR-033). Next: câblage + dogfood (5B commits future capitalizations).
- /deploy skill built (subagent-driven, 4 tasks + opus keystone review + pressure-test + final whole-branch review). 5 artifacts (.claude/deploy/), two-moment cold-resume via PENDING.json, atomic learn coupling, new lib/deploy-commit.sh (allowlist .claude/deploy/). Branch feat/deploy-skill (b210e8d..79741e3, kept un-merged). BDR-038 + LRN-062..066 + EVAL-009 capitalized; TODO unchanged.

## 2026-06-28
- /deploy MERGED to master (fast-forward cd375dd..135b487; 12 files, 1189 ins) on review + pressure-test confidence — SUPERSEDES "kept un-merged" in 2026-06-27 line. First REAL deploy still pending (its 1st incident = runbook-learn's 1st exercise). Branch feat/deploy-skill kept (reference/revert). master ahead of origin (push pending).

## 2026-06-29

- gitflow lib bug found & fixed at ROOT: `_gitflow_init_existing` swallowed the socle-commit failure → hook activated on a PARTIAL run → every re-run self-blocks (BLK-012). Fix = fatal socle commit + identity precheck (`gitflow_init`) + identity guard (`migrate_local`); 57/57 green, abort-zero-mutation proven on identity-less repo. LRN-068 (transactional enforcement-bootstrap).
- Migrated ALL 6 repos to gitflow one-by-one (faunosteo, config, bchanot-cv, zenquality, game, claude): master→main, develop, Option-1 owner-pushable protection, master deleted — each delete behind a user eyeball + GO, ZERO loss, no force/`--no-verify`, settings intact. game = already-on-main variant (no master); zenquality keeps `cleanup/post-smtp-fix` (out-of-convention, conscious); bchanot-cv adopted a pre-existing clone (surfaced, not assumed).
- claude SELF-APPLIED (ultimate dogfood): its own committed lib migrated it. Chantier landed C1 `feat(gitflow)` 167ea96 + C2 `chore(memory)` 1254643 + socle 620071b; hook now governs claude. gstack submodule dirty (BLK-008 Playwright bump) excluded via `submodule.ignore=dirty` (LRN-070), not reset.
- Permission insight: `Bash(export *)` deny false-positives inline-env; `git push` ASK = the real remote-write gate (LRN-069). BLK-010 CLOSED (verified `gitflow_init` root commit closes all 3 components — index+body, append-only).

## 2026-06-29 (cont.) — MINOR-gate strengthening (doc-syncer)
- Read-first cartography REFUTED the literal premise: "strengthen MINOR gate" = 3 distinct problems; the literal reading (blocking gate on MINOR, option B) contradicts engraved [[BDR-036]]. Same trap as gitflow — premise refuted by the real, not assumed.
- Scope tranché ①+②, ② first, never B, ③ deferred. Built test-first (Iron Law RED→GREEN, RED shown before each GREEN).
- ② masked-commit fix ([[LRN-071]]) — 3rd occurrence of the swallowed-commit pattern ([[LRN-066]], [[LRN-068]]/[[BLK-012]]). `doc-commit.sh` exit 5 fail-loud. RED T8 proved the masking (rc 0 + stale hash + false "committed"), GREEN 32/32.
- ① MINOR-shape oracle ([[BDR-040]], `lib/doc-shape.sh`) — 19/19 + behavioral Scenario D. Engraved limit: structural floor, NOT semantic (reduction of RISK-1's gross cases, not elimination).
- Branch `feature/minor-gate-strengthening`; committed code + memory; FINISHED → develop (`0f0bd7f`) on explicit signal. Held the merge until the explicit go — the "avis-en-question" wasn't it.

## 2026-06-29 (cont. 2) — BLK-011 resolved by REMOVAL (init-project GSD bootstrap)
- User challenge reframed the chantier: don't plumb a commit for the stranded ROADMAP — ask if gsd belongs at init AT ALL. Read REFUTED both my option-premises (gsd ≫ roadmap; TODO ≠ gsd ROADMAP) but conclusion A (remove STEP 12) held for a STRONGER reason: speculative auto-bootstrap of an unused multi-session engine at creation is bad per se. Best fix = NEGATIVE diff ([[LRN-072]]).
- Removed init-project STEP 12 (+ header 12→11-step, 10c note, 4 USAGE coherence fixes). Coherence sweep = zero dangling STEP-12 refs (the "test" for a removal). Deliberate gsd use KEPT (onboarder PHASE 6, plugin-advisor, status-reporter). [[BLK-011]] → resolved.
- Branch `bugfix/blk-011-gsd-roadmap`; FINISHED → develop (`ce4391a`) on explicit signal; pushed develop to origin (6 commits, SSH).

## 2026-06-29 (cont. 3) — prune-memory hardening (RED-7/8 + index backfill)
- Read-first cartography (confirmed my own measurements). RED-7 (example-priming): the STEP-2 example named live LRN-014+016 and modeled merging them — verified COMPLEMENTARY, a merge the skill forbids. Fix = fictionalize example to 9xx + DETERMINISTIC test ([[LRN-046]], not flaky behavioral). [[LRN-073]].
- RED-7 test caught its OWN false-green in real time: ugrep parsed `-9..` as an option → empty → green; fixed via /usr/bin/grep. 4th command-assumption miss this session → [[LRN-074]] (2nd engraved pattern-family, alongside fail-silent [[LRN-066]]/[[LRN-071]]).
- RED-8 (added-negation): consciously ACCEPTED as documented limit ([[LRN-047]] — FP-prone guard worse than honest limit on a destructive skill).
- Index backfill: 34 missing rows (decisions 11, learnings 21, blockers 2) composed + ID-sorted insert; drift 34→0, STEP-4 verify OK. Re-read the 5 awk-missed Applies-to → 4 corrected a nuance the title dropped. Moved pre-existing out-of-order LRN-021. [[EVAL-010]].
- Branch `bugfix/prune-memory-hardening`; no finish yet (awaiting signal). LAST of 3 chantiers.

## 2026-06-29 (cont. 4) — TODO reconcile + /reconcile skill queued
- Session question "open-work queue really empty?" answered by READING sources (TODO, BLK, BDR/LRN deferred) vs REAL git state, not conversation memory. TODO lied 7 lines: FINISH+PUSH prune-memory already done (merge `73e12be`, develop==origin), 3× `[ ] Commit` (tree clean → shipped), `.gitmodules` follow-up (a) done (`be1dcef`), doc-sync twin done ([[BDR-036]]), v2 Stop-hook marked "deferred" but REJECTED ([[BDR-037]]).
- Contradiction caught: chantier `--help` (STEP 0.5 per SKILL.md) contradicts [[BDR-001]] accepted (helper via session-start hook; per-SKILL.md copy REJECTED) → `--help` BLOCKED pending BDR-001 resolution (supersede or re-route).
- Our OWN manual inventory had an error: line 26 cleanup-machine declared "auto-cleaned next make plugin" but fs shows darwin-skill still present → demoted "done"→"still deferred" after fs check. Proof-by-example the queue needs a RECONCILER (declared-vs-real), not a `[ ]`-grepper.
- Reconciled TODO (5 ticked + 1 requalify + 1 split, annotated `reconcile 2026-06-29` w/ evidence) + queued `/reconcile` skill chantier (4-cat output, inter-registry contradiction detection, GATED TODO edit). Sequencing: /reconcile FIRST (oracle = today's inventory, perishable) → resolve BDR-001 → --help.

## 2026-06-30 — /reconcile skill shipped (declared-vs-real reconciler)
- Built `/reconcile` via superpowers:writing-skills (TDD): engine `lib/reconcile.sh` + harness 20/20 + thin gated skill. Recursive coherence (never trust a declarative source, incl. Index) made a TESTED guarantee — T1 reds on an Index-reader shim. [[BDR-041]].
- RED 2-arm: guided baselines succeed (contaminated) / unguided mirror the TODO (real failure) → value = determinism+gate, not teaching ([[LRN-075]]). GREEN behavioral confirmed; dogfooded on its own chantier (S3 marked partial honestly). [[EVAL-011]].
- Learnings: unguided-control RED ([[LRN-075]]); last-block-wins status + BLK-004 bleed bug ([[LRN-076]]); neutral fixture names = same symptom/distinct cause as [[LRN-074]] ([[LRN-077]]).
- Ship: feature/reconcile-skill → develop (gitflow finish). Push to origin gated (ASK).

## 2026-06-30 (cont.) — /release-candidate skill built (gitflow release orchestrator)
- Built `/release-candidate` via writing-skills TDD: thin orchestrator over gitflow release + the version tag the lib lacks (grep-confirmed no `git tag` in gitflow.sh). RED (gitflow fans out, no tag) → GREEN 5/5 on a throwaway repo. [[BDR-042]], [[EVAL-012]].
- Decisions: tag in the skill not the lib (release-specific vs generic mechanic); canonical sole release path (direct-lib release wouldn't tag, accepted); vX.Y.Z continues the lineage.
- Learnings: semver derives from change nature, caveman = Removed not breaking ([[LRN-078]]); orchestrator-skill TDD = throwaway-repo flow replay ([[LRN-079]]).
- CHANGELOG [Unreleased]: added /reconcile + /release-candidate under ### Added (so the eventual v4.0.0 captures them — /reconcile shipped without its entry, rectified here).
- Ship: feature/release-candidate-skill → develop (gitflow finish). Push gated (ASK). Real v4.0.0 cut = separate later act (layer 2).

## 2026-06-30 (cont.) — make plugin fixed (npm) + deferred-items requalif (③ doc-commit, BDR-015 darwin)
- 2 code vérifs (subagents, no-memory) + `make plugin` action. VÉRIF③: gitflow hook (`lib/gitflow.sh:199-225`, exempts `.claude/**` + merges + root) installed by init-project STEP 5f + onboard STEP 2.6 → branch guard covered everywhere EXCEPT repos outside `gitflow init` (doc-commit.sh has NO branch guard — `_unsafe_state` skips main/develop). ③ = confirmed REAL but NARROW hole, already graved [[BDR-040]]/TODO:292 → NOT re-graved.
- ③ nuance (only new bit, logged here): a future doc-commit guard must REPLICATE the hook's `.claude/` whitelist (hook EXEMPTS 100%-`.claude/` commits on main/develop — memory follows the work), NOT blanket-block main/develop → 3rd copy of the whitelist predicate, not "4 lines". Low priority, stays deferred.
- VÉRIF symlinks: 0 broken / 83 today → BDR-015 trigger cleared, darwin re-baseline UNBLOCKED (NOT run). [[BDR-043]].
- `make plugin` Error 127 (npm absent, apt-`nodejs` host) → fixed via corepack (npm 11.18.0 → `~/.local/bin`, prefix `~/.local`), EXIT=0, Step 4 ✓, stray-dir residual cleanup ([[BDR-030]]/[[LRN-042]]) finally ran. [[BLK-013]].
- BLK-013 + BDR-043 capitalized; ③ requalif dropped (already captured), whitelist nuance logged here. Surgical memory commit (blockers+decisions+journal only, NOT TODO — user's uncommitted planning note left untouched).

## 2026-06-30 (cont.) — close ritual (LRN-081 + TODO reconcile) + gate-suspense gap caught
- Ran /close (capitalize --ritual). After a fresh capitalize → registries propose near-nothing (BLK-013/BDR-043 already this session); live work = TODO reconcile + 1 LRN.
- GAP caught: the prior STEP-3 gate (LRN-081 + TODO check L26 + 2 adds) had stayed UNRESOLVED — conversation diverted to an out-of-band /reconcile + EVAL-013 (`437697e`, author user, NOT Claude) which never touched the gate items. Verified absent, then completed. Exactly the declared-vs-real drift /reconcile exists to catch.
- LRN-081: Claude commit trailers only on Claude-COMPOSED content; staging user-authored text gets none (staging ≠ authorship). Born of `e591510` (clean) vs `5b03ac2` (trailers).
- TODO: checked L26 "Cleanup machine courante" DONE (`make plugin` EXIT=0 this session ran Step 8.5; fs-verified both strays absent — closes the session's opening "cleanup ligne 26"); added (a) harden install-plugins.sh Step 1 npm-via-corepack ([[BLK-013]] fix-forward); added (b) darwin re-baseline of the 5 ex-broken skills ([[BDR-043]], promoted from its action-field).
- LRN-081 capitalized; checked 1 done, added 2.

## 2026-06-30 (cont.) — BLOC1 darwin re-baseline → resolved-MOOT (measure-first)
- Searched for results.tsv instead of assuming its state → GONE (wiped by 23/06 make-plugin reinstall; was a local May-2026 artifact, not shipped upstream). No darwin baseline survives at all → not even a re-baseline, a fresh-from-zero one.
- BDR-043 cleared only motif (a) of BDR-015's TWO exclusion grounds (symlinks repaired ✅, 0 broken); motif (b) external-ownership INTACT — 5 resolve to skills-external/gstack/ (submodule), darwin edits SKILL.md → would dirty submodule ([[LRN-070]]). Re-baseline = unactionable score = phantom value. Twin of --help ([[LRN-080]]), distinct mechanism (residual motif vs absent value).
- Decision A (won't-run): TODO (b) → resolved-MOOT (not done, not open). LRN-082 capitalized (multi-motif trigger lesson). The "montre la table avant de décider" gate paid off — looking found the table gone instead of assuming status=error.

## 2026-06-30 (cont.) — BLOC2 auto-skill-dispatch → WON'T-BUILD (discernment measured)
- Cartography: routing = STACK L0(design-hook)→L1(superpowers "1%→MUST invoke", dominant)→L2(CLAUDE.md prose)→L3(frontmatter)→L4([[BDR-019]]). L1 over-determines invocation → "auto-call?" = already yes.
- Reframe C (user): real question = DISCERNMENT not "does it route"; risk inverts under→OVER-routing (L1 mandate vs Workflow "ask if needed / pragmatic on trivial").
- Subagent RED (6 reps, toy tasks) → 0/6 routed → RETIRED as non-discriminating (SUBAGENT-STOP + delegated framing = floor artifact, not signal); did NOT report as a number → [[LRN-083]].
- Discernment-RED in REAL fresh sessions (user-run, 8 prompts / 3 classes): CLEAR→route ✓, AMBIGUOUS→ask (refuses to guess, investigates for a useful Q) ✓, TRIVIAL→abstain ✓. Over-routing risk does NOT materialize — model balances L1 vs Workflow rules.
- Verdict: WON'T-BUILD ([[BDR-044]]) — 3rd measured moot of the session (--help, darwin re-baseline, auto-skill-dispatch). LRN-083 capitalized; [[LRN-080]] corroborated (3-in-a-row → measure-first sweep heuristic). TODO auto-skill-dispatch → won't-build. ALL actionables soldés.

## 2026-07-01
- gitflow aiguillage-standalone (BDR-045): chore type + 4 standalone memory/doc skills branch off develop before writing; hook exemption kept. 64/64 green (e8807a7). Then repaired 5 direct-on-main `chore(memory)` → chore/reconcile-memory branches (LRN-084, LRN-034 corrob).
- BLK-014 fixed: install.sh npm EEXIST on `~/.local/bin/claude` (native symlink, npm prefix `~/.local` from BLK-013) → skip-if-present guard + channel-aware update-all.sh (`claude update` for native). LRN-085. Commit 8dc4027, branch bugfix/install-claude-idempotent pending merge.
- BDR-046: install.sh switched fresh-install from npm → official native installer (`curl claude.ai/install.sh | bash`); npm no longer a documented channel (verified quickstart). Aligns with install-plugins.sh. Commit 6be627e, same branch.
- /reconcile show-only (claude repo, engine-verified): confronted TODO+registries vs git/fs. Real state = 1 actionable (install-plugins npm harden), 3 blocked-upstream (BLK-001 rtk / BLK-003 darwin / BLK-009 CC #21858, re-test on CC MAJ), 3 deferred-on-trigger, release-decision live (develop 20 ahead of v4.0.0). Engine false-flagged BLK-014 (last-status-wins caught Reference "open" vs Status resolved) — verified merged. "canal d'install" = already decided by BDR-046, NOT open; faunosteo/WARN-manuel = not in this repo.
- (c) TODO drift fixed: 7 `--help` WON'T-BUILD subtasks `[ ]`→`[-]` (chore/reconcile-todo-drift, 9c02406) → naive open-count 10→3, survivors all genuine deferred-open. Registries left read-only during reconcile (staleness deferred to this capitalize).
- (a) BLK-013 fix-forward BUILT: install-plugins.sh unconditional npm guard (corepack→distro→fatal), placed after `NODE_OK` short-circuit so node>=22-but-no-npm hosts don't skip it. shellcheck/`bash -n` clean, 1f2c1cc. Capitalize refreshed BLK-013 (NOT built→built), BLK-014 + BDR-046 (pending→merged) via append-only Update blocks. Both branches finished into develop.

## 2026-07-02
- Fable 5 exhaustive audit (read-only, 5 subagents + real suites): 24 findings — 5 bugs (rtk DEAD silently since .bashrc wipe → [[LRN-087]]; session-start update-check on gone origin/master; run-reconcile T6c parasite path → [[LRN-077]] corrob; doctor 3 false sentinels incl. BDR-019 contradiction), token overhead measured 14.6k/session → [[LRN-088]].
- 3 lots merged on explicit GO (suites green after each, reconcile 20/20 post-LOT1): bugfix/audit-bugs (rtk absolute-path heal + re-pin ×2, origin/main, T6c, doctor sentinels); feature/audit-hardening (.bak purge, banner ALWAYS_ON derived + graphify label, ok-gated installers, design-hook regex tightened, update-all bun+exclusions, deny 99→113 + rtk read-only allowlist + .env mirrors, cleanup batch, origin/HEAD→main); feature/audit-tokens (pr-review-toolkit OFF −2.2k tok, kept in audit.profile as reactivation channel; 10 descriptions compressed −540 tok).
- #11 rtk auto-allow DROPPED — permission control back in settings.json (rtk registry was a parallel authority bypassing deny/ask). #10 rules/context7.md deleted (−493 tok; find-docs survives, stable — regen keyed on its absence); faulty examples → upstream issue draft (upstash/context7, gh unauthenticated). plugin-dev uninstalled + dropped from installer.
- Incidents: magic API key printed into transcript from ~/.claude.json → rotated, [[BDR-026]] update (copies of secrets); gitflow_finish ignores its args (operates on CURRENT branch, lib/gitflow.sh:104) → LOT 3 merged first by mistake, final develop state identical (disjoint hunks) — UX trap noted, not fixed.
- Residuals (flagged, not built): doctor "Cargo not found (RTK unavailable)" parenthesis now misleading; doctor symlink-check false-warns on dir-level symlinks; doctor token constants stale; find-docs faulty examples ctx7-owned.

## 2026-07-03
- bugfix/gitflow-finish-args: `gitflow_finish` contract fix — args now optional safety ASSERTION (present + ≠ current branch → refuse rc2 "operates on current branch X, you asked Y — checkout Y first"); no-args unchanged (only real caller SKILL.md:36 + all tests pass none → zero regression). +7 T12 assertions. [[BLK-015]], [[LRN-089]]. Off-by-one caught at capitalize: next free BLK = 015 not 016 (gate proposal said 016) → gitflow.sh comment corrected pre-finish via soft-reset+redo of the 3 commits.
- Same branch, 3 doctor false-warns fixed ([[LRN-047]] corrob — a doctor that cries false is ignored): cargo "(RTK unavailable)" → optional info (RTK prebuilt, detect_rtk); check_symlink passes children of dir-level symlinks (hooks/session-start.sh); gstack counts 34 per-skill symlinks not a mythical skills/gstack link (link.sh removes it); token budget vs 200k context window not bogus 11k "session budget" → killed false "92% CRITICAL" (measured ~11.4k [[LRN-088]]; 200k confirmed by user — 1M pin revoked at audit #7, calibrate on default not the exceptional session).
- Suites green: gitflow 71/71 (+7), deterministic 13, doc-commit 32, doc-shape 19, reconcile 20, deploy-commit 13, release-candidate 5/5 tag-mode. doctor: 0 false-warn (1 legit survivor = gstack tracks branch=main advisory). shellcheck clean. T12 named to dodge collision with reconcile's own T6c (darwin path, audit #3).
- 3 atomic commits (fix gitflow / fix doctor / docs changelog Unreleased) + memory. finish bugfix→develop on GO; user pushes develop.
