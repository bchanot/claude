# PLAN — skill-catalog-prune (feat, ad-hoc dispatch) — r4 (after confirmation pass)
- r4 closes the confirmation pass (robustness FATAL(4)): BLOCKER 1 — the
  helper lib skips any non-skill dir holding a nested SKILL.md
  (browser-skills/, node_modules/, openclaw/) and `.git*`/`node_modules`
  by name, fixture `other/deep/SKILL.md`; MAJOR 2 — the three existing
  profile/toggle suites copy lib/gstack-removed.sh into their fixture
  (E1b scope); MAJOR 3 — the lib removes a stale `dst` symlink (gstack
  ./setup plants `~/.claude/skills/gstack -> submodule`) and refuses a dst
  that resolves inside src, fixture case added; MAJOR 4 — update-all.sh's
  third copy of the block goes through the lib too (criterion 18); MINOR
  5-8 — real restored count after the skip, policy message instead of the
  setup hint, `len(x or '')` + stderr warn on fallback, E2 owns every
  install-plugins.sh edit (E3 no longer touches it).
- date: 2026-09-28 | contract: contracts/2026-09-28-skill-catalog-prune-0554.md
- branch: feature/skill-catalog-prune
- executors: 4 feater (sonnet-pinned), parallel, disjoint file sets, same tree
- r3 closes: correctness MAJOR 1-3 / MINOR 4-9, robustness MAJOR 1-4 / MINOR
  5-9, simplicity MAJOR 1 / MINOR 2-5. Named changes: whole-class gstack
  helper links through one shared lib (E2), `GSTACK_REMOVED` denylist that
  `gstack on` / `enable gstack` honor (E1b), `max` = union of every profile
  (E1a), live `set full` as an oracle (criterion 16), census test with a
  passing baseline then one mutant per invariant (E1a), description parser
  reused from lib/skill-routing-census.py (E2), synced info line dropped,
  stale r1 wording swept.
- r2: superset = `max`; full keeps the 11 redundant gstack (user rule: full
  ⊇ every other profile, max = everything); parked = make-pdf, diagram,
  21st trio; 21st trio out of full/web/web-full/design; freeze/bin link.

## Ground truth (verified on the live tree, 2026-09-28)

- Catalog: 150 skills, 53.5k chars of descriptions; the harness lists only
  ~19k chars of them with a description (least-invoked skills lose theirs).
  78 skills are name-only in the current session.
- gstack skills are symlinked per profile (BDR-030), `full` is the default
  (BDR-101). `profile.sh apply` is ADDITIVE (enables only); `set` and `reset`
  park what the profile does not list (`disable_gstack_not_in`,
  `disable_externals_not_in`, `disable_plugins_not_in`) then apply. So a
  name dropped from full leaves the live tree only at the next `set full`
  or `reset`; nothing runs that automatically. `gstack on`
  (`enable_all_gstack`) and `lib/toggle-external.sh enable gstack` move
  EVERY `skills-disabled/gstack__*` back, with no denylist.
- gstack skills hardcode `~/.claude/skills/gstack/<path>` for shared
  assets, but link.sh (and a duplicate block in install-plugins.sh
  STEP 2) only create `gstack/bin` and `gstack/browse/dist`. Census of the
  hardcoded paths (`grep -rhoE '(~|\$HOME)/\.claude/skills/gstack/[A-Za-z0-9_./-]+'
  skills-external/gstack/*/SKILL.md`): bin/* (dozens), scripts/jargon-list.json,
  ETHOS.md, browse/bin/remote-slug, browse/dist/browse, design/dist/design,
  extension/, lib/diagram-render/dist/diagram-render.html, make-pdf/dist/pdf,
  freeze/bin/check-freeze.sh, careful/bin/check-careful.sh, */sections/*.md
  (plan-*-review, cso, office-hours, design-consultation, document-release),
  review/checklist.md, review/specialists/*.md, and other skills' SKILL.md
  (office-hours/SKILL.md, gstack-upgrade/SKILL.md). Everything but `bin` and
  `browse/dist` is unreachable today: make-pdf returns MAKE_PDF_NOT_AVAILABLE,
  diagram BUNDLE_MISSING, the careful/guard/freeze hooks exit 127 and never
  fire (LRN-096 class), cso and plan-*-review cannot read their sections.
- A global `skills/gstack -> skills-external/gstack` symlink is forbidden
  (link.sh comment): the top-level gstack SKILL.md then lists as a duplicate
  skill. Skill discovery reads `~/.claude/skills/<name>/SKILL.md`; a
  `SKILL.md` must therefore never sit at `~/.claude/skills/gstack/SKILL.md`,
  and no `<skill>/SKILL.md` is linked below `gstack/` either (only their
  non-SKILL.md children), so the helper tree exposes no skill file.
- gstack `ship` resolves its base from `origin/HEAD` on Gitea → main; it
  diffs and PRs against main, skipping develop. `land-and-deploy` runs
  `gh pr merge --squash --delete-branch` then waits for the deploy.
- security-guidance 2.0.0: SessionStart venv, UserPromptSubmit baseline,
  PostToolUse regex, Stop = direct POST /v1/messages (opus-4-7, thinking
  10000) on every turn that changed source, commit/push = Agent SDK review
  up to 18 turns. Log 2026-09-22→28: 0 findings, 1 recorded false positive
  (EVAL-024). `ENABLE_STOP_REVIEW=0` is the plugin's own switch.
- settings.json has NO top-level `env` key today (create it). It is the
  live `~/.claude/settings.json`: validate JSON right after the edit.
- doctor.sh: `find -maxdepth 2` without `-L` → 34 skills; `grep
  '^description:' | head -1` → block scalars count 0 chars. doctor.sh runs
  under `set -euo pipefail`. `lib/skill-routing-census.py` already has a
  tested `extract_description()` handling `|`/`>` blocks (hyphenated file
  name → load with importlib, not `import`).
- Specialized profiles carry exactly ONE name full lacks: pr-review-toolkit
  (audit.profile; plugin deliberately out of full, audit 2026-07-02 #12,
  ~2.2k tokens when enabled; MANAGED_PLUGINS so `set` toggles it).
- Already done live (user go): brightdata disabled (`false` in
  settings.json), frontend-design@claude-plugins-official uninstalled
  (entry removed). `lib/gstack-removed.sh` written by the orchestrator:
  `GSTACK_REMOVED=(…9…)` + `gstack_is_removed <name>`.

## Approach

### E1a — profiles + census suite + profile docs
Files: lib/profiles/{full,dev,backend,web,web-full,design}.profile,
lib/profiles/max.profile (new), lib/tests/profile-census.test.sh (new),
skills/profile/SKILL.md, README.md, USAGE.md.

1. Remove the 9 `GSTACK_REMOVED` entries (`ship land-and-deploy setup-deploy
   autoplan context-save learn careful guard design-shotgun`) from EVERY
   profile that lists them (dev, backend, web, web-full, design, full).
   Comment lines describing only them go too. Keep `freeze` and `unfreeze`.
2. `full.profile`: additionally remove the 5 parked entries `make-pdf
   diagram 21st-ai 21st-ui-explore 21st-ui-review`. The 11 redundant gstack
   (plan-ceo/design/devex-review, spec, review, retro, investigate, canary,
   qa, open-gstack-browser, setup-browser-cookies) STAY. Rewrite `# DESC:`:
   default profile; carries everything every other profile carries (user
   rule 2026-09-28, one exception: pr-review-toolkit); no broken or
   doctrine-breaking gstack (see lib/gstack-removed.sh); parked tools live
   in `max`. The pr-review-toolkit comment block stays.
3. `web`, `web-full`, `design`: also remove the 21st trio lines.
4. New `lib/profiles/max.profile`: header `# DESC: Everything — full + the
   parked tools (make-pdf, diagram, 21st-ai/ui-explore/ui-review) +
   pr-review-toolkit; switch here when one of them is wanted` and the marker
   line `# SUPERSET-OF: full`. Content = new full + the 5 parked names in
   their original sections + `pr-review-toolkit  plugin@claude-code-plugins`
   (the audit.profile line). NEVER a `GSTACK_REMOVED` name. Invariant: max ⊇
   union(every profile) − GSTACK_REMOVED.
5. `lib/tests/profile-census.test.sh` (hermetic, `set -u`, `check` helper
   and `trap 'rm -rf "$WORK"' EXIT` like lib/tests/skill-routing-census.test.sh):
   - Top of file: `source "$ROOT/lib/gstack-removed.sh"` (REMOVED comes
     from the single source), `PARKED=(make-pdf diagram 21st-ai
     21st-ui-explore 21st-ui-review)`, and `FULL_EXCEPTIONS=(pr-review-toolkit)`
     with the reason on comment lines ABOVE the array (names only inside it:
     contract criterion 15 parses the parentheses).
   - ONE assertion function `census_check <profiles_dir>` that runs an
     inline python3 heredoc taking the dir and the three lists as argv.
     Entry = first whitespace token of a non-blank line whose first non-blank
     char is not `#` (what `read_profile` links). It prints ONE reason code
     per violation on stdout — `REMOVED_LISTED:<profile>:<name>`,
     `NO_SUPERSET` / `MANY_SUPERSETS`, `SUPERSET_GAP:<name>` (full or a
     parked/exception name missing from the `# SUPERSET-OF: full` profile),
     `MAX_GAP:<name>` (a name some profile carries that max lacks),
     `FULL_GAP:<name>` (a name a non-max profile carries that full lacks,
     minus REMOVED, the 21st trio and FULL_EXCEPTIONS) — and returns 0 iff
     no violation.
   - Live part: `census_check "$ROOT/lib/profiles"` must return 0
     (`check T1-live-clean`).
   - Fixture part under `mktemp -d`: `baseline/` = a minimal profiles dir
     (full.profile with `alpha`, `beta`; qa.profile with `alpha`;
     max.profile with the marker + `alpha`, `beta`, `parked-x`; PARKED and
     FULL_EXCEPTIONS overridden for the fixture through the argv lists).
     The baseline MUST return 0 → print `FIXTURE_BASELINE_OK`. Then three
     mutants, each a copy of baseline with ONE change, each MUST return
     non-zero AND print its own code: `ship` added to qa.profile →
     `REMOVED_LISTED:qa:ship` → `FIXTURE_REMOVED_DETECTED`; `beta` deleted
     from max.profile → `SUPERSET_GAP:beta` → `FIXTURE_SUPERSET_DETECTED`;
     `gamma` added to qa.profile only → `FULL_GAP:gamma` →
     `FIXTURE_FULLGAP_DETECTED`. A detected mutant counts as a PASS of the
     test (it is the positive control); a mutant that returns 0 is a FAIL.
   - Summary `PASS=n FAIL=m`, rc 1 on any FAIL. Shell helpers ≤ 25 logic
     lines; the python heredoc is one function per invariant.
6. Docs: skills/profile/SKILL.md table gains the `max` row ("Everything —
   full + parked tools (make-pdf, diagram, 21st generation trio) +
   pr-review-toolkit") and full's row reads "Default — everything the other
   profiles carry, minus broken or doctrine-breaking gstack"; README line
   175 and 357-360 list `max`; README line 179 drops `context-save,
   context-restore` from its example list; USAGE line 166 lists `max`.

### E1b — denylist honored by every "gstack back" path
Files: lib/profile.sh, lib/toggle-external.sh, lib/tests/gstack-removed.test.sh (new),
lib/tests/{profile-default,profile-set-managed,toggle-external-repo-resolution}.test.sh
(fixture copy line only).

1. lib/profile.sh: `source "$(dirname "${BASH_SOURCE[0]}")/gstack-removed.sh"`
   next to the other top-level definitions. `enable_all_gstack`: skip a
   parked entry whose name `gstack_is_removed` (leave it parked, `info
   "skipped (removed by policy, lib/gstack-removed.sh): $name"`).
   `enable_skill` gstack branch: refuse a removed name with `warn` and
   return 0 (a profile listing one is a census failure, not a crash).
2. lib/toggle-external.sh `enable gstack` loop (the `for entry in
   "$DISABLED_DIR"/gstack__*` block): same skip, same source line
   (`source "$(dirname "$0")/gstack-removed.sh"`; note toggle-external
   resolves REPO from `$0`, keep that idiom).
3. `enable_all_gstack` echoes the REAL restored count on stdout (skipped
   names excluded); `cmd_gstack on` prints that count, not the pre-computed
   `parked_gstack_count` (profile.sh ~651-655). toggle-external.sh: when
   the loop skipped ≥ 1 removed name and moved 0, print "only policy-removed
   skills remain parked (lib/gstack-removed.sh)" and NOT the "re-run gstack
   setup" hint (setup would relink the 9 removed skills).
4. The three existing suites copy only profile.sh / toggle-external.sh into
   their fixture `lib/` and would die on the new `source`: add
   `cp "$ROOT/lib/gstack-removed.sh" "$FX/lib/"` (same for `$SANDBOX/repo/lib/`)
   in lib/tests/profile-default.test.sh (:27), lib/tests/profile-set-managed.test.sh
   (:22), lib/tests/toggle-external-repo-resolution.test.sh (:19). No other
   change to those suites.
5. `lib/tests/gstack-removed.test.sh`: fixture repo under mktemp (the
   `PROFILE_REPO_OVERRIDE` / `TOGGLE_EXTERNAL_REPO_OVERRIDE` harness as
   lib/tests/profile-default.test.sh and toggle-external-repo-resolution.test.sh
   use it — read them first): `skills-disabled/gstack__ship` and
   `gstack__browse` present → `profile.sh gstack on` restores browse only,
   ship stays parked, output names the skip; same for `toggle-external.sh
   enable gstack`; `gstack_is_removed` positive + negative. `PASS=n FAIL=m`.

### E2 — wiring: shared gstack helper links + doctor catalog stats
Files: lib/gstack-links.sh (new), link.sh, install-plugins.sh (STEP 2 helper
block, STEP 5 comment blocks, summary lines — E2 owns EVERY edit of this
file), update-all.sh (its helper-link block), lib/doctor-skills.sh (new),
doctor.sh, lib/tests/gstack-links.test.sh (new), lib/tests/doctor-skills.test.sh (new).

1. `lib/gstack-links.sh` — `link_gstack_helpers <src> <dst>` (split into
   small helpers, each ≤ 25 logic lines, no `set -e`, fallback ok/warn/info
   like lib/vendor-skills.sh):
   a. Guard: if `$dst` is a symlink → `rm -f "$dst"` + info (gstack ./setup
      plants `~/.claude/skills/gstack -> skills-external/gstack` when the
      dir is absent; link.sh's old stale-link removal moves here). Then if
      `realpath -m "$dst"` is inside `realpath "$src"` → warn, return 1
      (never write into the submodule). `mkdir -p "$dst"`.
   b. For every top-level entry E of `$src`, skip by name `.git*`,
      `node_modules`, `SKILL.md`. If E is a dir holding its own `SKILL.md`
      (a gstack skill) → `mkdir -p "$dst/E"` and `ln -sfn` each child of E
      except `SKILL.md`. Else if E is a dir and `find -L "$src/E" -name
      SKILL.md -print -quit` is non-empty (browser-skills/, openclaw/ …) →
      skip with info (would expose a nested skill). Else (file, or a clean
      non-skill dir such as bin, scripts, lib, design, extension, ETHOS.md)
      → `ln -sfn "$src/E" "$dst/E"`.
   c. Idempotent (`ln -sfn`), removes nothing but the stale dst symlink,
      echoes the number of links created THIS run on stdout (callers add it
      to CHANGED) and prints one `ok` summary on stderr. Rationale comment:
      the census above + why no SKILL.md is ever exposed under `<dst>`.
2. link.sh: replace the stale-global-link removal AND the `bin` /
   `browse/dist` blocks (lines ~55-91) with `source "$REPO/lib/gstack-links.sh"`
   + one call `n=$(link_gstack_helpers "$REPO/skills-external/gstack"
   "$CLAUDE/skills/gstack")` guarded by `[ -d "$REPO/skills-external/gstack" ]`,
   `CHANGED=$((CHANGED + n))`; keep the "submodule not found" warning; the
   comment says the helper tree replaces the hand-made links and exposes no
   SKILL.md.
3. install-plugins.sh STEP 2, the duplicate `GSTACK_DST` block (lines
   ~375-390): replace with the same source + call (after ./setup, so the
   lib's guard removes the global link setup may have planted).
   update-all.sh, its helper-link block (~106-116, `ln -sf` without `-n`
   → would nest `src/bin/bin` on a re-run): same source + call, right after
   the submodule update. STEP 5 comment blocks + summary lines: E2 does
   them (moved from E3, see E3.2 text below — same wording).
4. `lib/doctor-skills.sh` — `skill_catalog_stats <skills_dir>`: prints
   `<count> <desc_chars>` on stdout, ALWAYS exits 0 (prints `0 0` when the
   dir is absent or python fails). Implementation: one `python3 -` call that
   loads `lib/skill-routing-census.py` via `importlib.util.spec_from_file_location`
   (hyphenated name), globs `<dir>/*/SKILL.md` (glob follows symlinks),
   sums `len(extract_description(path) or '')` (the function takes a PATH
   and returns None when there is no description). On any python failure
   print `0 0` to stdout AND one `warn` line to stderr (doctor shows the
   failure instead of a healthy-looking zero). No awk parser.
5. doctor.sh token block: replace the loop + `find` with
   `read -r SKILL_COUNT SKILL_DESC_CHARS < <(skill_catalog_stats "$HOME/.claude/skills")`
   after `source "$REPO/lib/doctor-skills.sh"`. Constants: DELETE the
   gstack (2750), context7 (200) and graphifyy (300) lines — their skills
   sit in `~/.claude/skills` and are counted by the stats (one comment line
   says so); superpowers 800 → 1500 (~900 t session-start injection + ~600 t
   of 15 descriptions, measured 2026-09-28); ui-ux-pro-max 400 → 670 (7
   descriptions, 2 669 chars, measured 2026-09-28). The "measured ~11.4k
   post-audit, LRN-088" note → "(re-measure after a catalog change;
   LRN-088)". NO synced-bucket line (dropped: out of the request's scope;
   noted as a TODO follow-up by the orchestrator).
6. Tests. `lib/tests/gstack-links.test.sh`: fixture src under mktemp with
   `bin/x`, `ETHOS.md`, `SKILL.md`, `browse/{SKILL.md,dist/browse}`,
   `review/{SKILL.md,checklist.md,specialists/a.md}`, `.git/HEAD`,
   `other/deep/SKILL.md`, `node_modules/pkg/SKILL.md` → after
   `link_gstack_helpers`, `dst/bin`, `dst/ETHOS.md`, `dst/browse/dist`,
   `dst/review/checklist.md`, `dst/review/specialists` resolve;
   `find -L dst -name SKILL.md` is EMPTY (so no `dst/SKILL.md`,
   `dst/browse/SKILL.md`, `dst/other`, `dst/node_modules`), `dst/.git`
   absent; second run echoes 0 and changes nothing (idempotent); a dst
   that is a symlink to src → the symlink is removed, dst becomes a real
   dir, and `find src -type l` stays EMPTY (nothing written into src); a
   dst path inside src (`src/helpers`) → warn + rc 1, nothing created. `lib/tests/doctor-skills.test.sh`:
   fixture skills dir with an inline description, a `|` block scalar, a
   `>-` block, a SKILL.md with no description, a symlinked skill dir →
   count and chars equal the hand-computed sum; absent dir → `0 0` rc 0.
   `PASS=n FAIL=m` summaries.

### E3 — config + doctrine + docs
Files: settings.json, agents/plugin-advisor.md, CLAUDE.global.md,
skills/deploy/SKILL.md, CHANGELOG.md. (install-plugins.sh is E2's: the
E3.2 wording below is what E2 writes there.)

1. settings.json: CREATE the top-level key `"env": {"ENABLE_STOP_REVIEW": "0"}`
   (it does not exist), keep the two enabledPlugins states already written
   live. Immediately validate: `python3 -c 'import json;json.load(open("settings.json"))'`.
2. [DONE BY E2, wording kept here] install-plugins.sh STEP 5: after the ui-ux-pro-max block, a comment block
   "frontend-design@claude-plugins-official — NEVER installed: byte-identical
   to the skills-external copy Step 8b syncs from the example-skills cache;
   uninstalled 2026-09-28 (skill-catalog prune)" and "brightdata-plugin@synced
   — account-synced from claude.ai, kept `false` in settings.json: every skill
   needs a Bright Data account and its bright-data-mcp skill orders WebFetch/
   WebSearch replaced 'no exceptions' (would hijack /seo /geo /harden)".
   Summary line "security-guidance — PreToolUse security hook (0 tokens)" →
   "security-guidance — regex hints on Edit/Write + out-of-band LLM reviews
   on commit/push (Stop review off via ENABLE_STOP_REVIEW=0; quota, not
   context) [claude-code-plugins]". The frontend-design summary line stays
   (the managed copy stays).
3. agents/plugin-advisor.md: the `security-guidance ↔ any` row → "Hooks +
   out-of-band LLM reviews (agentic review on commit/push; Stop diff review
   disabled by ENABLE_STOP_REVIEW=0). No context injection unless a regex
   hits."; the "> security-guidance and rtk are ALWAYS ON (0 tokens)" note →
   "> rtk is always on at 0 context tokens; security-guidance is always on
   and costs quota out of band (LLM reviews), not context — both omitted
   from the estimates".
4. CLAUDE.global.md Skill routing: "- Ship / PR → ship (ship-feature if
   gstack off); deploy → deploy (runbook, the user runs it)" → "- Ship / PR →
   ship-feature (never gstack ship: it takes `origin/HEAD` = main as base
   and skips develop); deploy → deploy (runbook, the user runs it)". The
   gstack-OFF line lists "(investigate, qa, review, health, retro,
   office-hours…)". Design work "Review / audit" line: drop "+ 21st-ui-review"
   and add, at the end of the 21st sentence in that section, "21st-ai /
   ui-explore / ui-review are `max`-profile only." Keep every line ≤ 80 chars.
5. skills/deploy/SKILL.md table: drop the `/land-and-deploy` and
   `/setup-deploy` rows; add one row "Merge a finished branch | `gitflow
   finish` on an explicit human signal (skills/gitflow)".
6. CHANGELOG `[Unreleased]`: Removed (brightdata synced plugin disabled,
   frontend-design official plugin uninstalled, 9 gstack skills out of every
   profile with reasons, `GSTACK_REMOVED` denylist honored by `gstack on` /
   `enable gstack`), Changed (full = everything the other profiles carry,
   `max` = full + parked + pr-review-toolkit, 21st trio max-only,
   security-guidance Stop review off, doctor constants), Fixed (gstack helper
   tree: make-pdf, diagram, sections, jargon list, ETHOS, freeze hook now
   fires — `/unfreeze` clears `~/.gstack/freeze-dir.txt`; doctor.sh
   undercount; "0 tokens" claims; Ship/PR routing), Known residual (kept
   gstack skills still carry upstream prose routing to /ship,
   /land-and-deploy, /context-save, /autoplan, /design-shotgun; 21st-ui-build
   and 21st-cli-use point to the max-only trio — a Skill call on a parked
   name fails and the doctrine routing applies).

## Orchestrator steps after the executors
- Criterion 16 runs `bash lib/profile.sh set full` live (parks the 14 names,
  re-applies full) and checks none of them resolves under `~/.claude/skills`.
- Post-merge (user): `make link` (helper tree) and `bash lib/profile.sh set
  full` on any other machine.

## Edge cases
- A profile line may carry a trailing label column (`personal`, `external`,
  `# gstack`); entries match on the first token only.
- `design.profile` `# GATE-BLOCK:` lines name frontend-design, ui-ux-pro-max,
  emil-design-eng, design-html, design-motion-principles, design-review,
  design-consultation, the 21st CLI, 21st-ui-build: none of the removed or
  parked names → no gate edit (grep before editing).
- link.sh / install-plugins.sh run on machines without the gstack
  submodule: the call is guarded by `[ -d skills-external/gstack ]`.
- `skill_catalog_stats` never breaks doctor.sh's `set -euo pipefail`: it
  always exits 0 and always prints two integers.
- The helper tree never contains a `SKILL.md` at any depth: skill dirs
  expose only their non-SKILL.md children, non-skill dirs with a nested
  SKILL.md (browser-skills/, node_modules/, openclaw/) are skipped
  (asserted by the gstack-links test and criterion 3).
- `~/.claude/skills/gstack` may be a symlink to the submodule (planted by
  gstack ./setup on a fresh machine): the lib removes it before linking and
  never writes when dst resolves inside src.
- Kept gstack skills still name removed/parked skills in their upstream
  prose: documented as a known residual (CHANGELOG), not patched (machine-
  owned submodule files).

## Tests
- lib/tests/profile-census.test.sh, gstack-removed.test.sh,
  gstack-links.test.sh, doctor-skills.test.sh (new, hermetic; SUITES glob
  picks `lib/tests/*.test.sh` up automatically).
- make test suite=lib/tests/doctrine-citers.test.sh (routing text changed);
  existing profile-default / profile-set-managed / toggle-external suites
  must stay green (profile.sh and toggle-external.sh changed).
- shellcheck link.sh doctor.sh install-plugins.sh update-all.sh lib/*.sh lib/tests/*.test.sh.
- Full `make test` by the orchestrator at the end (2 pre-existing T16a
  gitleaks failures are known).

## Disposition (RELATED MEMORY, read-before)
- honors BDR-030 / BDR-101 — gstack via profiles, full default: every drop
  is a profile edit; the live tree follows through `set full`.
- honors BDR-025 — GATE-BLOCK single source untouched.
- honors BDR-093 — 21st pack stays installed; its generation/review trio
  leaves the four design-bearing profiles and lives in max; BDR amendment
  noted in registries.
- honors BDR-023 — close alias untouched.
- honors BDR-080 — investigate stays explicit-only and stays in full/dev/
  backend (user rule).
- honors BDR-095 — static deny beats `ask`: careful/guard removal loses no
  live protection (their hooks never fired).
- honors LRN-088 — measured before cutting: the gain is routing quality and
  no broken 100 KB body invoked, not listing chars.
- honors LRN-022 / BLK-005 — profiles audited with the skill change (census).
- honors LRN-096 — vacuous guard class: helper tree makes the freeze hook
  real; careful/guard are removed rather than left vacuous.
- honors BDR-070 — no rival SEO tooling: brightdata seo-audit stays off.
- does NOT touch BDR-104 (MengTo pack) nor the 2026-07-05 frontend-design +
  impeccable "both" decision (the managed copy stays).
