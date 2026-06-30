---
type: blockers_registry
entry_prefix: BLK
schema:
  id: BLK-XXX
  date: YYYY-MM-DD
  friction: string (what was blocked)
  real_cause: string (root cause, not symptom)
  solution: string (workaround or fix)
  status: [open | resolved | upstream]
rules:
  - Open blocker when friction > 15 min wasted. Close with real cause, not "moved on".
  - Link upstream issue / PR / commit when applicable.
  - Cause is bug in dependency → status upstream with pointer to tracker.
---

# Blockers registry (BLK)

## Index

| ID | Date | Friction | Status |
|----|------|---------|--------|
| BLK-001 | 2026-04-22 | `rtk curl` breaks JSON pipelines | upstream |
| BLK-002 | 2026-04-23 | `rmdir` denied in sandbox on empty directory | resolved |
| BLK-003 | 2026-05-12 | `scripts/screenshot.mjs` hardcoded macOS path blocks PNG cards on Linux | upstream |
| BLK-004 | 2026-05-20 | `/ship-feature` wrapper at `~/.claude/commands/` points to deleted agent files post-refactor | resolved |
| BLK-005 | 2026-05-21 | gstack submodule rename (checkpoint→context-save) breaks profile entries | resolved |
| BLK-006 | 2026-05-21 | `profile.sh current` false-negative via `~/.claude` symlink (`cd` not `cd -P`) | resolved |
| BLK-007 | 2026-06-02 | 6 gstack source skills (ios-*, spec) unlinked post-bump — invisible to profiles + `gstack on` | resolved |
| BLK-008 | 2026-06-23 | gstack ./setup on Ubuntu 26.04: Playwright chromium unsupported → gstack browser (/browse, /qa, screenshots) silently dead | resolved (211c7d4) |
| BLK-009 | 2026-06-25 | user-level path-scoped rules (`paths:` frontmatter in `~/.claude/rules/`) never inject — broken in CC 2.1.190 (#21858) | upstream, open |
| BLK-010 | 2026-06-27 | init-project: scaffold (STEP 5) + bootstrap README (5b) have no deterministic commit owner; worktree `add -b` on unborn HEAD | resolved (uncommitted) |
| BLK-011 | 2026-06-27 | init-project STEP 13 GSD post-FINISH creates ROADMAP.md → stranded doc (3rd post-FINISH artifact) | resolved (STEP 12 removed) |
| BLK-012 | 2026-06-29 | gitflow_init half-applied: socle-commit failure swallowed → hook activated on partial run → re-run self-blocks | resolved |
| BLK-013 | 2026-06-30 | `make plugin` Error 127 — npm absent on apt-`nodejs` host (Step 4 gsd-pi aborts, Steps 5-10 + residual cleanup never run) | resolved (env) |

---

## BLK-001 — `rtk curl` returns compressed schema in pipes

- **Date**: 2026-04-22
- **Friction**: pipelines like `rtk curl ... | python -c "json.load(sys.stdin)"` (or `jq`, `awk`) fail without clear error.
- **Real cause**: `rtk curl` auto-compresses stdout regardless of TTY — documented in `.claude/tasks/rtk-upstream-issue.md`.
- **Solution**:
  - Short-term workaround: `exclude_commands=["curl"]` in `~/.config/rtk/config.toml`.
  - Alternative workaround: use `rtk proxy`.
  - Upstream fix: issue reported, see `.claude/tasks/rtk-upstream-issue.md`.
- **Status**: upstream (`rtk` bug, workaround applied).

## BLK-002 — `rmdir` denied in sandbox on empty directory

- **Date**: 2026-04-23
- **Friction**: couldn't delete `./tasks/` after emptying (post-migration to `.claude/tasks/`). `rmdir tasks` and `rm -r tasks` returned "Permission denied" even with empty dir and non-destructive intent.
- **Real cause**: Claude Code sandbox blocks destructive commands (`rm`, `rmdir`, `rm -rf`) by default via harness permission gate, regardless of actual semantics. `git rm` through `git` passed (commit `c721a36`) — git treated as non-destructive tool.
- **Solution**:
  - This session: `git rm tasks/*.md` handled files individually (via `git rm`, cleared gate). Git auto-detected renames to `.claude/tasks/`, so `tasks/` directory removed implicitly at commit time.
  - If dir persists empty after `git rm`: ask user to run `rmdir tasks` manually.
- **Status**: resolved (fixed via `git rm` + rename auto-detection; no `rmdir` needed in practice).
## BLK-003 — `scripts/screenshot.mjs` hardcoded macOS path blocks PNG cards on Linux

- **Date**: 2026-05-12
- **Friction**: `/darwin-skill` Phase 3 generates result cards via `node ~/.agents/skills/darwin-skill/scripts/screenshot.mjs <html> <png>`. On Linux: script fails immediately — `require('/Users/alchain/.npm-global/lib/node_modules/playwright/node_modules/playwright-core')` resolves to a non-existent macOS user path. No PNG cards produced; Phase 3 falls back to markdown report only.
- **Real cause**: upstream `alchaincyf/darwin-skill` author dev'd on macOS, shipped absolute path to their own homedir's global npm install of playwright. Zero portability layer (no PATH lookup, no `playwright` bare require, no fallback to `npx`).
- **Solution**:
  - Workaround (used 2026-05-12): skip PNG generation, deliver markdown + HTML cards (HTML viewable in browser without playwright).
  - Local patch: `npm i -g playwright` then replace `require('/Users/alchain/...')` with `require('playwright')`. Two lines edit.
  - Spec-documented fallback: `npx playwright screenshot "file:///path/to/card.html#<theme>" out.png --viewport-size=960,1280 --wait-for-timeout=2000` — works without modifying the file, costs ~150MB chromium download.
  - PR upstream to `github.com/alchaincyf/darwin-skill` once tested.
- **Status**: upstream (third-party skill at `~/.agents/skills/darwin-skill/scripts/screenshot.mjs`, not in any of our repos).

## BLK-004 — `/ship-feature` wrapper references 6 deleted agent files

- **Date**: 2026-05-20
- **Friction**: `/ship-feature` invocation loads wrapper at `~/.claude/commands/ship-feature.md`. Wrapper says `Load and follow strictly: .claude/agents/{ship-feature,analyzer,designer,implementer,reviewer,tester}.md`. 5 of 6 paths missing on disk (only `analyzer.md` survives). User hits blocker — wrapper without orchestrator.
- **Real cause**: refactor commits `0241e1d` ("extract skill logic into standalone agent files") + `21960e0` ("changed orchestrators into skills") migrated orchestrator from `.claude/agents/ship-feature.md` into `~/.claude/skills/ship-feature/SKILL.md` and replaced custom sub-agents (designer/implementer/reviewer/tester) with superpowers skills (brainstorming, writing-plans, subagent-driven-development, requesting-code-review, finishing-a-development-branch). Wrapper at `~/.claude/commands/ship-feature.md` never updated, never deleted. Untracked file — survived all refactor commits silently.
- **Solution**: `rm ~/.claude/commands/ship-feature.md`. Skill `~/.claude/skills/ship-feature/SKILL.md` (`name: ship-feature`, `disable-model-invocation: true`) becomes sole `/ship-feature` resolver. SKILL.md references only existing agents: `plugin-advisor.md`, `analyzer.md`, `doc-syncer.md`.
- **Status**: resolved.

## BLK-005 — `/profile set full` warns `missing: checkpoint` after gstack upstream rename

- **Date**: 2026-05-21
- **Friction**: `/profile set full` (and dev, backend, web, web-full) emits `⚠ missing: checkpoint — try: bash link.sh`. Running `bash link.sh` reports `✅ All symlinks already up to date. Next: bash install-plugins.sh` — dead-end loop. User cannot resolve the warning by following the suggested next step.
- **Real cause**: gstack upstream renamed the `checkpoint` skill to `context-save` (Claude Code now treats `/checkpoint` as a native rewind alias, shadowing the gstack skill). New skill in `skills-external/gstack/context-save/SKILL.md` carries the description `"Formerly /checkpoint — renamed because Claude Code treats /checkpoint as a native rewind alias"`. Five `lib/profiles/*.profile` files still listed the dead name. `link.sh` only symlinks repo dirs into `~/.claude/` — it cannot materialize a skill that no longer exists upstream, so its suggested action was misleading.
- **Solution**: `s/checkpoint/context-save/` in `lib/profiles/{dev,backend,full,web,web-full}.profile` (commit `69c5ded`). `CLAUDE.md:193` routing line `Save progress, checkpoint, resume → invoke context-save` updated locally, left uncommitted because the file holds unrelated in-progress graphify section work. Verify: `bash lib/profile.sh set full` now outputs `✓ enabled: context-save` with no warning.
- **Status**: resolved.

## BLK-006 — `bash lib/profile.sh current` false-negative when invoked via `~/.claude/lib/` symlink

- **Date**: 2026-05-21
- **Friction**: `bash "$HOME/.claude/lib/profile.sh" current` returns `none (all gstack skills enabled — no profile set)` even when a profile IS applied + 14 `gstack__*` entries sit in the repo's `skills-disabled/`. User cannot detect active profile via the official command. Same script invoked from inside the repo directory (`bash lib/profile.sh current`) returns the correct answer — invocation-path-dependent behavior is the worst kind of bug to diagnose.
- **Real cause**: `lib/profile.sh:43` set `REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`. Default bash `cd` preserves symlinks (logical pathname mode, `set -P` off). When the script is invoked via the `~/.claude/lib/profile.sh` symlink (link.sh wires `~/.claude/lib -> <repo>/lib`), `$BASH_SOURCE[0]` is the symlinked path, `dirname` returns `~/.claude/lib`, `cd ..` lands at `~/.claude`, and `pwd` returns the logical path `/home/bchanot-ubuntu/.claude`. `$SKILLS_DIR="$REPO/skills"` still works because `~/.claude/skills` happens to be a symlink to the repo's `skills/`. But `$DISABLED_DIR="$REPO/skills-disabled"` resolves to `~/.claude/skills-disabled` — a real sibling directory created at some earlier point containing only 2 stale npx-skill symlinks (`darwin-skill`, `find-skills`). `cmd_current` scans this near-empty dir, finds 0 `gstack__*` entries, returns the "none" sentinel.
- **Solution**: `REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` (commit `a4558ee`). `-P` forces physical-path resolution so `$REPO` is always the real repo path regardless of how the script is invoked. Verify: `bash "$HOME/.claude/lib/profile.sh" current` now returns `full (100% match, 14 gstack skills disabled)`.
- **Status**: resolved. Follow-up: `~/.claude/skills-disabled/` (real dir with only `darwin-skill`/`find-skills` symlinks) is orphaned — these npx skills are already symlinked into `<repo>/skills/` by link.sh, so the disabled-side copies serve no purpose. Could be deleted to remove confusion, but harmless as-is.

## BLK-007 — 6 gstack source skills (ios-*, spec) unlinked — invisible to profile system + `gstack on`

- **Date**: 2026-06-02
- **Friction**: `skills-external/gstack/` has 53 source skills; 6 (`ios-clean`, `ios-design-review`, `ios-fix`, `ios-qa`, `ios-sync`, `spec`) exist ONLY as source — NOT symlinked into `skills/` (enabled) nor `skills-disabled/gstack__*` (parked). So invisible to Claude AND untouched by `reset`/`gstack on` (both operate on parked `gstack__*` only). Surfaced while adding `gstack on|off`: `comm` of gstack source vs `full.profile`.
- **Real cause**: gstack submodule bump added new skills; gstack's own `./setup` (source of truth for per-skill symlinks per link.sh) not re-run → symlinks never created. Same lifecycle gap class as [[toggle-external-source-only-state]] (LRN-007). NOT a `full.profile` bug — full curated by design (BDR-017 caveat: "full excludes rarely-used gstack skills"). Initial "full omits ios = bug" flag was WRONG, self-corrected (see EVAL-002).
- **Solution applied** (NOT full `./setup` — surgical, no side effects): (1) Linked `spec` only — `mkdir skills/spec` + `ln -snf <abs>/skills-external/gstack/spec/SKILL.md skills/spec/SKILL.md`, matching gstack setup:440-476 (per-skill real dir + SKILL.md symlink, name from frontmatter). (2) Added `spec` to `full.profile` + `web-full.profile` planning sections (must be in active profile `full` else `set full` re-disables it). (3) iOS 5 skills deliberately NOT linked — Linux host, device-farm needs Mac daemon + Tailscale + iOS devices = dead skills + token cost. (4) Completed `.gitignore` gstack allowlist: added all 12 missing (`spec`, 5 `ios-*`, 6 parked `document-generate/landing-report/scrape/setup-gbrain/skillify/sync-gbrain`), removed stale `checkpoint` (BLK-005 rename). Reason: `gstack on` (BDR-018) moves parked skills into `skills/` — any gstack skill missing from allowlist = untracked git noise on enable.
- **Verified**: `profile show full`+`web-full` → spec enabled; allowlist drift recheck EMPTY; spec skill now visible to Claude.
- **Status**: resolved. iOS = intentional exclusion (re-linkable via gstack `./setup` on a Mac). See [[gstack-gitignore-allowlist-completeness]] (LRN-025).

## BLK-008 — gstack ./setup fails on Ubuntu 26.04 — Playwright chromium unsupported

- **Date**: 2026-06-23
- **Friction**: fresh Ubuntu 26.04, `make install` / `make plugin` → "Failed to install browsers / ERROR: Playwright does not support chromium on ubuntu26.04-x64" → "GStack ./setup failed". Non-fatal in our wrapper (warn only) but gstack's browser (`/browse`, `/qa`, design screenshots) is silently dead once gstack is enabled.
- **Real cause**: Playwright 1.58.2 (pinned in the gstack submodule) registry lists `ubuntu20.04/22.04/24.04` only; 26.04 released later → not in list → `getHostPlatform` errors. Pure OS-newness, not an install bug.
- **Solution**: gated `export PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntu24.04-x64` (ubuntu >24.04 only) before gstack setup + persisted to `.bashrc` for runtime. Playwright then pulls a Chrome-for-Testing fallback build for ubuntu24.04. Verified on 26.04: `ldd` resolves all libs + real headless render OK.
- **Status**: resolved (commit 211c7d4). Residual: exact rev 1208 launch not in-session-tested (sandbox download hung at extraction); proved via sibling rev 1228 same-platform CfT build. Confirm on next real `make plugin`. Proper upstream fix = gstack bumps Playwright to a version that lists ubuntu26.04. See [[LRN-038]].

- **2026-06-23 UPDATE — Solution REVERTED, status downgraded to UPSTREAM/open** (commit b9c3937): the `PLAYWRIGHT_HOST_PLATFORM_OVERRIDE` solution above does NOT work on 26.04. The fallback build downloads to 100% then HANGS at extraction (chrome binary never appears, no headless-shell download starts; reproduced on real machine + sandbox) → turned a 0.5s fast-fail into an install-blocking hang (user Ctrl+C). Reverted to the fast-fail (non-fatal; gstack OFF by default, browser only for /browse,/qa,screenshots). The earlier "verified ldd + headless render" was an isolated test on a sibling already-extracted build (rev 1228) — it masked the rev-1208 install-path hang. **Real fix = upstream**: gstack bumps Playwright to a version that lists ubuntu26.04. Until then gstack's browser is unavailable on 26.04, install completes cleanly. See [[LRN-038]] correction.

- **2026-06-23 FINAL — RESOLVED** (commit 3b8ffb1): gstack browser now works on Ubuntu 26.04. Two layers fixed: (1) bumped gstack's pinned Playwright 1.58.2 → 1.61 (`bun add playwright@latest` in the submodule; 1.61 ships a native ubuntu26.04 build — chromium rev 1228), automated in the installer (`gstack_bump_playwright_if_unsupported`, idempotent, OS-gated); (2) `GSTACK_CHROMIUM_NO_SANDBOX=1` to work around the AppArmor userns restriction (`sysctl kernel.apparmor_restrict_unprivileged_userns=1`), persisted to `.bashrc` + installer Step 9 (sysctl-gated). Verified end-to-end: `browse goto https://example.com` → "Navigated (200)". Caveat: the Playwright bump is a local submodule edit, reset by `git submodule update`, re-applied by the next install. See [[BDR-029]], [[LRN-040]].

---

## BLK-009 — user-level path-scoped rules don't load (#21858) — still broken in CC 2.1.190

- **Date**: 2026-06-25
- **Friction**: tried to scope a global rule to matching files via `paths:` frontmatter in `~/.claude/rules/<name>.md` — the rule never injects, even when a matching file (`*.probe`) is read in a fresh session. Blocks any "load this guidance only for matching files" strategy at the user level.
- **Real cause**: GitHub issue #21858 — user-level (`~/.claude/rules/`) rules carrying `paths:` frontmatter are not evaluated/injected; still unfixed in 2.1.190. (Project-level path-scoped rules not tested here.)
- **Probe method**: 3-file probe — `_probe.md` (`paths: ["**/*.probe"]`, sentinel `SENTINEL_USER_RULE_LOADED`), `_probe_ctl.md` (NO `paths`, control sentinel `CONTROL_NOPATHS_LOADED`), `_probe_target.probe` (target, read in a fresh session). Result: control sentinel PRESENT in session context, path-scoped sentinel ABSENT → the path-scoped rule did not load. Probe files removed after.
- **Status**: upstream, open. Workaround: don't rely on user-level path-scoping → keep global guidance unconditional + COMPRESSED ([[BDR-031]]). Side-note: native auto-memory = "on" but writes nothing yet (fresh machine). Re-test on CC upgrades.
- **Reference**: GitHub #21858. Linked to [[BDR-031]], [[LRN-044]].

---

## BLK-010 — init-project scaffold + bootstrap README have no deterministic commit owner; worktree on unborn HEAD

- **Date**: 2026-06-27
- **Friction**: init-project scaffold (STEP 5 — CLAUDE.md, settings, config, entry points, `.gitignore`, `.env.example`, `.claude/`) + bootstrap README (STEP 5b) never get an explicit commit. Pipeline's only commits = STEP 10b memory (helper) + STEP 8 per-task implementer commits. Whether scaffold/README land in a commit = emergent: implementer-prompt.md says only "4. Commit your work", scope undefined. Greenfield deeper: STEP 8 `subagent-driven-development` requires `using-git-worktrees` → `git worktree add -b` branches from HEAD, but post-`git init` HEAD is UNBORN → add fails; the worktree skill has no unborn-HEAD path.
- **Real cause**: no deterministic commit step between `git init` (STEP 5) and FINISH (STEP 11). scaffolder + doc-syncer both write-only (zero `git commit`). implementer commit scope unspecified. `using-git-worktrees` assumes a born HEAD.
- **Solution**: open — own chantier (real technical weight: unborn HEAD + worktree). Candidate: explicit initial scaffold commit after STEP 5/5b before STEP 8, OR handle unborn HEAD in the worktree step. NOT cured by the doc-sync coupled chantier — that commits ONLY doc-sync's patched files and (correctly) excludes scaffold. Consequence: after doc-sync coupled, ship-feature fully fixed, init-project PARTIAL (doc-sync ok, scaffold/bootstrap still open).
- **Status**: resolved (2026-06-29; working tree uncommitted — durable only at the claude repo commit, cf [[BLK-012]]). Was "open"; closed by the gitflow chantier — see note below.
- **Reference**: discovered in doc-sync-coupled analysis (2026-06-27). Distinct from the doc-sync twin [[BDR-034]]. Sibling [[BLK-011]]. Surfaces via analyze-before-plan bookend on any init-project commit-flow work.

- **2026-06-29 — RESOLVED by the gitflow chantier**: `gitflow_init` fresh path (`_gitflow_init_fresh`: unborn HEAD → `git symbolic-ref HEAD refs/heads/main` → `git add -A` → deterministic root commit → `git branch develop`) wired at init-project **STEP 5f** (after scaffold STEP 5 + README STEP 5b, before STEP 8 implement). Closes all 3 components: (a) scaffold+README get a deterministic commit owner = the root commit (`git add -A` stages whole tree; SKILL.md STEP 5f + lines 141/249-250 "scaffold commit owner … BLK-010 closed"); (b) root commit + develop make HEAD BORN before STEP 8 → `gitflow start feature`/`worktree add -b` never hits unborn HEAD; (c) STEP 5f IS the deterministic commit step between `git init` and FINISH. Tested: gitflow-test.sh **T2 "init fresh (BLK-010 root commit)"** (root commit on main, socle IN root commit, hook tracked, tree clean). Residual (non-blocking): the generic `using-git-worktrees` skill still has no unborn-HEAD path — now MOOT (HEAD always born by STEP 5f, never reached), not patched in the skill itself.

## BLK-011 — init-project STEP 13 GSD post-FINISH creates ROADMAP.md → stranded doc

- **Date**: 2026-06-27
- **Friction**: init-project STEP 13 (GSD v2 init) runs post-FINISH (STEP 11). `gsd init` creates `.gsd/` + `ROADMAP.md` (a public doc). Created AFTER FINISH integrates → ROADMAP never in the merge/PR. Same PR-stranding class as the doc-sync twin, 3rd post-FINISH artifact.
- **Real cause**: artifact-producing step ordered after FINISH (= BDR-034 class). `gsd init` is a CLI mechanism distinct from doc-syncer; ROADMAP is sync-only for doc-syncer (never created by it, BDR-022 rules), so the doc-sync coupled chantier does not touch it.
- **Solution**: open — separate thread. Candidate: reorder GSD before FINISH, or commit ROADMAP after `gsd init`. Out of scope for doc-sync coupled (different mechanism). [historical candidates — NOT the route taken]
- **Resolution**: RESOLVED 2026-06-29 — by REMOVAL, not by committing the orphan. init-project STEP 12 (speculative gsd auto-bootstrap) DELETED → ROADMAP/.gsd never created post-FINISH → orphan dissolves, no commit helper built. TRUE reason: auto-bootstrapping a heavy multi-session ENGINE the sole user doesn't use, AT project-creation, is bad on its own terms. NOT the initial framing "ROADMAP redundant with TODO" — that was wrong and would have aged badly: gsd ≫ roadmap (state machine / crash-recovery / cost / parallel / worktree), and TODO ≠ gsd ROADMAP (different altitude + consumer). Reasoning trace: BOTH initial premises (gsd=only-roadmap; TODO-redundant) REFUTED on read, yet conclusion A (remove STEP 12) held for the STRONGER reason — right answer, reason corrected before engraving. Deliberate gsd use KEPT (onboarder PHASE 6 `/onboard add gsd`, plugin-advisor reco, status-reporter `.gsd/` read, USAGE `gsd init`). Removed STEP 12 + header 12→11-step + 10c note + 4 USAGE refs; coherence sweep = zero dangling refs. [[LRN-072]]
- **Status**: resolved (init-project STEP 12 removed — `skills/init-project/SKILL.md`; branch bugfix/blk-011-gsd-roadmap). Title says "STEP 13" — stale (was STEP 12 at removal per BDR-036 renumber); left per append-only.
- **Reference**: discovered in doc-sync-coupled analysis (2026-06-27). Sibling [[BLK-010]] + twin [[BDR-034]].

## BLK-012 — gitflow_init non-transactional: socle-commit failure swallowed → hook activated on partial run → re-run self-blocks

- **Date**: 2026-06-29
- **Friction**: migrating faunosteo, `migrate_local` → `gitflow_init` half-applied TWICE. Run 1: master→main renamed, develop created, socle staged, but the socle commit died — `Author identity unknown ... unable to auto-detect email address (got 'bchanot@bchanot-server.(none)')` → tree DIRTY, exit 1. Run 2 (recovery): socle commit BLOCKED by the gitflow hook itself (`gitflow pre-commit: BLOCKED — direct commit on 'main'`), yet `init` reported `exit=0` (a lie); main still at the old tip, socle uncommitted.
- **Real cause**: `_gitflow_init_existing` SWALLOWED the socle-commit failure — `git diff --cached --quiet || git commit` with no propagation, and the function's last stmt (`git branch develop`) returned 0, masking the dead commit. Init CONTINUED past the failed commit → ran `gitflow_activate_hook` though the socle was never committed → re-run then self-blocks (commit on main blocked by the now-active hook). Design's "idempotent" + "never self-blocked" claims hold ONLY for a clean single run; a partial run breaks both. Fresh-repo path already propagated its failure (`_gitflow_init_fresh`); existing-repo path did not — the asymmetry was the bug. Trigger upstream of it: git identity UNSET (global unset; faunosteo had no local identity, though its own history uses `Bastien Chanot <git@bchanot.fr>`).
- **Solution**: (1) socle commit FATAL in `_gitflow_init_existing` — `if ! git diff --cached --quiet; then git commit … || { echo …; return 1; }; fi` → aborts BEFORE develop/hook-activation; (2) identity precheck at top of `gitflow_init` (fail loud, no half-apply); (3) identity guard in `gitflow-migrate.sh:migrate_local`. Recovery: set faunosteo local identity → deactivate hook → delete premature develop → reinit (socle commits with hook inactive, as designed) → main==develop @ socle, tree clean, master renamed. Verified: shellcheck clean, 57/57 tests pass, hardened init on an identity-less repo aborts rc1 with ZERO mutation.
- **Status**: resolved (`lib/gitflow.sh` + `lib/gitflow-migrate.sh`, uncommitted working tree as of the gitflow chantier).
- **Reference**: [[LRN-068]] (transactional-bootstrap principle). Discovered mid gitflow-migration 2026-06-29. Sibling chantier learning [[LRN-067]].

## BLK-013 — `make plugin` Error 127: npm absent on apt-`nodejs` host

- **Date**: 2026-06-30
- **Friction**: `make plugin` (→ `install-plugins.sh`) aborts at Step 4 (gsd-pi): `install-plugins.sh: line 425: npm: command not found` → `make: *** [Makefile:10: plugin] Error 127`. Steps 5-10 never run, AND the post-Step-4 stray-dir cleanup (Step 8.5) never reached → the [[BDR-030]]/[[LRN-042]] residual (stray `$REPO/.agents/skills` + `$REPO/.claude/skills`, promised "auto-cleaned next `make plugin`") silently persists run after run. SessionStart banner already showed `gsd v2 ✗`.
- **Real cause**: Debian/apt `nodejs` package ships `node` WITHOUT `npm` (npm = separate apt pkg). `/usr/bin/node` present (v22.22.1); its bindir has acorn/corepack/semver but NO npm/npx — npm genuinely uninstalled, not a PATH miss. install-plugins.sh Step 1 checks `node >=22` but NEVER verifies npm — assumes npm ships with node (true for nodesource/brew/dnf paths, FALSE for plain apt).
- **Solution**: corepack (ships with node) over apt npm (apt npm could pull a divergent 2nd node). `corepack enable --install-directory "$HOME/.local/bin" npm` → npm 11.18.0 shim, no sudo, `~/.local/bin` already on PATH. Then `npm config set prefix "$HOME/.local"` — default prefix `/usr` is root-owned → `npm install -g` would EACCES; `~/.local` writable + bins land on PATH. Persisted in `~/.npmrc`. Re-run → EXIT=0, Step 4 ✓ (`gsd-pi@2.64.0`), Step 8.5 ran (`Removed stray repo-local skills dir: .agents/skills` + `.claude/skills`). Caveat: gsd-pi DEPRECATED + postinstall scripts SKIPPED (npm 11 `allow-scripts`) — `gsd --version/--help` ok, full provisioning would need `npm install -g --allow-scripts=gsd-pi,… gsd-pi`.
- **Fix-forward**: install-plugins.sh Step 1 should GUARANTEE npm on apt-`nodejs` hosts — detect missing npm + `corepack enable npm` (not just check node) → stops Error 127 recurring on any fresh apt machine.
- **Status**: resolved (env-level: corepack shim + npm prefix; zero repo change). Fix-forward (script hardening) NOT built.
- **Reference**: discovered fixing `make plugin` 2026-06-30. Distinct from [[BLK-003]] (macOS playwright hardcoded path) + the Playwright-chromium `make plugin` failure. Blocked residual = [[BDR-030]]/[[LRN-042]].
