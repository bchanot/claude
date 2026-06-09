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
