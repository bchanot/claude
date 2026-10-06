# PLAN — superpowers-vendored (feat, ad-hoc dispatch) — r3 (after confirmation pass)
- r3 closes the confirmation pass (correctness CONCERNS(1)): MAJOR 1 — the
  CLAUDE.global.md map keeps every skill identifier whole on one line (grep
  is line-based); MINOR 2 — `always_on` mechanism pinned: the python lock
  reader emits a third column, `_dv_check_link` gets a 5th param, headers
  updated, a helper extracted if `check_vendored_skills` would exceed 5
  locals; MINOR 3 — stale "uninstall || true" edge case deleted; MINOR 4 —
  settings.json edit moves to the orchestrator, AFTER criterion 2 is green
  (a disabled plugin + a failed fetch must never coincide); MINOR 5 —
  profile.sh comments located by grep, doctor pass line worded on what is
  proven.
- r2 closes: correctness BLOCKER 1 (the CLAUDE.global.md map never spells the
  colon form — criterion 3 greps it), MAJOR 2 (doctor-vendored gains an
  always-on class driven by a lock field `always_on`, so the 7 are
  link-checked instead of "parked"), MAJOR 3 + robustness MAJOR 1 (NO
  uninstall code in the installer — comment only, one-shot by the
  orchestrator after criterion 2 is green), MAJOR 4 + robustness MAJOR 3
  (settings.json hand-edited: enabledPlugins key and
  extraKnownMarketplaces.superpowers-marketplace block removed, committed),
  MAJOR 5 + robustness MAJOR 2 + simplicity MAJOR 1 (detect_superpowers =
  one file test on the linked skill, no plugin fallback, no new global),
  simplicity MAJOR 2 (same: no installer uninstall), MINORs: session-start
  line deleted plainly, map trimmed to the four referenced skills, lock note
  kept to maintainer facts, summary line placement pinned, rollback step,
  mixed-version rollback note.
- date: 2026-09-28 | contract: contracts/2026-09-28-superpowers-vendored-1357.md
- branch: feature/superpowers-vendored
- executors: 2 feater (sonnet-pinned), parallel, disjoint file sets

## Ground truth (verified 2026-09-28)
- Plugin superpowers 6.4.1 installed at
  `~/.claude/plugins/cache/superpowers-marketplace/superpowers/6.4.1/`
  (gitCommitSha 5bf4e78011075bcfc0dc295f0724994cd123ee71 = upstream tag
  v6.4.1 on obra/superpowers; raw files served at
  `https://raw.githubusercontent.com/obra/superpowers/<sha>/skills/<skill>/<file>`,
  brainstorming/SKILL.md md5 identical local vs raw). Enabled in settings.json
  (`superpowers@superpowers-marketplace: true`), PROTECTED in lib/profile.sh,
  installed + enabled by install-plugins.sh STEP 5 (marketplace add,
  install_plugin, enable_plugin), summary line "ALWAYS ON … superpowers".
  Its hooks.json SessionStart (startup|clear|compact) injects
  using-superpowers (~3.6 KB) every start.
- The 7 skills to vendor and their files (upstream layout `skills/<name>/`):
  brainstorming: SKILL.md, spec-document-reviewer-prompt.md, visual-companion.md,
    scripts/frame-template.html, scripts/helper.js, scripts/server.cjs,
    scripts/start-server.sh, scripts/stop-server.sh
  writing-plans: SKILL.md, plan-document-reviewer-prompt.md
  subagent-driven-development: SKILL.md, implementer-prompt.md,
    re-review-prompt.md, task-reviewer-prompt.md, scripts/review-package,
    scripts/sdd-workspace, scripts/task-brief
  test-driven-development: SKILL.md, writing-good-tests.md
  requesting-code-review: SKILL.md, code-reviewer.md
  using-git-worktrees: SKILL.md
  writing-skills: SKILL.md, anthropic-best-practices.md,
    examples/CLAUDE_MD_TESTING.md, graphviz-conventions.dot,
    persuasion-principles.md, render-graphs.js, testing-skills-with-subagents.md
  Scripts are invoked upstream as `bash scripts/<x>` (SDD lines 137, 252,
  290…; brainstorming visual-companion.md) → no exec bit needed.
- Internal cross-references that will dangle (byte-for-byte text):
  writing-plans → superpowers:subagent-driven-development, superpowers:executing-plans (dropped), superpowers:using-git-worktrees;
  SDD → superpowers:finishing-a-development-branch ×4 (dropped), superpowers:using-git-worktrees, superpowers:requesting-code-review, executing-plans ×2;
  TDD → superpowers:writing-skills; writing-skills → superpowers:test-driven-development ×4, superpowers:systematic-debugging (dropped), using-superpowers, verification-before-completion.
- `lib/vendor-skills.sh` `vendor_pinned_skills <lock-key> [refresh]`: lock
  entry `{source, commit (40 hex), path, skills: {name: [files]}, managed_by}`;
  files must match `[A-Za-z0-9._/-]+`, no `..`; tmp+mv; skips existing files
  unless `refresh`. install-plugins.sh STEP 8e calls it for agent-skills and
  mengto-skills with `EXT_SKILL_NAMES` symlink check; update-all.sh 7.3 calls
  it with `refresh`. link.sh `EXTERNAL_SKILLS=(…)` symlinks
  `skills-external/<name>` into `~/.claude/skills/<name>`; .gitignore lists
  `skills/<name>` (symlink) and `skills-external/<name>/` (vendored text) per
  external. lib/doctor-vendored.sh reads the lock + EXTERNAL_SKILLS generically.
- lib/profile.sh: `PROTECTED_PLUGINS=("security-guidance@claude-code-plugins"
  "superpowers@superpowers-marketplace")`; MANAGED_EXTERNALS is the allowlist
  `set` parks — the 7 are NOT added (always on, like darwin-skill).
- lib/detect-plugins.sh `detect_superpowers`: plugin cache glob then `claude
  plugin list`. Consumers: hooks/session-start.sh:122 (`+ 800` passive),
  doctor.sh:225-228 (pass/fail "Superpowers plugin detected / not detected —
  orchestrators will fail") and :423 (`+ 1500`).
- `superpowers:` citers (personal): skills/ship-feature:103,117,176,237;
  skills/init-project:71,182,215,259; skills/tour:318; skills/deploy:515;
  skills/audit-delta:321; lib/analyze-before-plan.md:106;
  lib/capitalize-commit.md:20 (finishing-a-development-branch);
  agents/plugin-advisor.md:182. Prose mentions of
  finishing-a-development-branch: lib/capitalize-commit.md:68,
  lib/doc-commit.md:84, lib/analyze-before-plan.md:108, skills/gitflow:16,110.
  Docs: README.md:121 (component table), USAGE.md ×19 (plugin/cost
  narrative), agents/plugin-advisor.md ×19 (matrix, recommended sets, remedy
  :324), skills/profile/SKILL.md:59, install-plugins.sh:1210 summary.
  `docs/superpowers/` paths (CLAUDE.md, gitflow, onboard) stay: brainstorming
  and writing-plans still write there.
- lib/tests: gitflow-test.sh mentions superpowers only through the purge
  path (unchanged). No suite asserts PROTECTED_PLUGINS content.

## Approach

### E1 — wiring (lock, installers, link, gitignore, profile, detect, doctor)
Files: plugins.lock.json, install-plugins.sh, update-all.sh, link.sh,
.gitignore, lib/profile.sh, lib/detect-plugins.sh, hooks/session-start.sh,
doctor.sh, lib/doctor-vendored.sh, lib/tests/doctor-vendored.test.sh,
lib/vendor-skills.sh (header comment line only).
1. plugins.lock.json: new entry `"superpowers"` after `"mengto-skills"`:
   source `https://github.com/obra/superpowers`, commit
   `5bf4e78011075bcfc0dc295f0724994cd123ee71`, path `skills`, `skills` = the
   dict above (exact file lists), managed_by `curl`, `"always_on": true`,
   note (maintainer facts only, history lives in CHANGELOG/BDR-106): "Seven
   superpowers skills vendored byte-for-byte at the v6.4.1 tag commit
   (obra/superpowers), always on (no profile lists them). Bump the commit
   deliberately. Scripts inside run as `bash scripts/<x>`, no exec bit
   needed. Upstream cross-references to the plugin prefix and to the 8
   non-vendored skills stay in the text; CLAUDE.global.md Skill routing maps
   them."
2. install-plugins.sh STEP 5: delete the three superpowers lines (marketplace
   add, install_plugin, enable_plugin) and replace with a 3-line comment
   "Superpowers plugin removed 2026-09-28 (tier 2 of the skill-catalog prune):
   its 7 wired skills are vendored in Step 8e (plugins.lock.json
   'superpowers'); a still-cached plugin is uninstalled by hand once
   (claude plugin uninstall superpowers@superpowers-marketplace), never here".
   NO uninstall code in the installer (precedent: frontend-design, caveman).
   Update the `enable_plugin` comment (:490) to name only security-guidance.
   STEP 8e: heading/comment mention superpowers; `EXT_SKILL_NAMES` += the 7;
   `vendor_pinned_skills superpowers` after mengto. Summary: replace line
   ~1210 ("✅ superpowers — brainstorm/plan/implement/debug workflow", ALWAYS
   ON block) by "✅ superpowers skills  — 7 vendored (brainstorming,
   writing-plans, subagent-driven-development, test-driven-development,
   requesting-code-review, using-git-worktrees, writing-skills), pinned
   v6.4.1, curl → symlink, no plugin, no session injection"; add one "at:"
   line right after the mengto "at:" line (~1234): "Superpowers skills at:
   ~/.claude/skills/{brainstorming,…}/ (symlink → skills-external)".
3. update-all.sh 7.3: `echo "── Updating superpowers skills (obra/superpowers)..."`
   + `vendor_pinned_skills superpowers refresh`; comment names it.
4. link.sh EXTERNAL_SKILLS += the 7 (keep the array multi-line ≤ 80 chars).
5. .gitignore: 7 `skills/<name>` lines next to the other external symlinks
   (:65-68 block) and 7 `skills-external/<name>/` lines next to the mengto
   block (:203-207), each block with a one-line comment "superpowers, vendored
   (plugins.lock.json 'superpowers')".
6. lib/profile.sh: PROTECTED_PLUGINS keeps only security-guidance; every
   comment naming superpowers as an always-on plugin (`grep -n superpowers
   lib/profile.sh`, currently ~:22 and ~:65) reworded ("superpowers is
   vendored skills now, not a plugin").
7. lib/detect-plugins.sh `detect_superpowers`: exactly
   `[ -f "$HOME/.claude/skills/brainstorming/SKILL.md" ]` (the linked
   vendored skill: proves vendored AND linked; no plugin cache glob, no
   `claude plugin list`, no new global, no fallback). Comment: "superpowers
   = 7 vendored skills since 2026-09-28; the plugin is gone". A negative
   control (empty HOME) must return 1.
7b. lib/doctor-vendored.sh: lock entries may carry `"always_on": true`
   (the `superpowers` entry does). Skills of such an entry are expected
   LINKED whatever the active profile says (today every EXTERNAL_SKILLS name
   absent from the profile is reported `parked`, link unchecked — the 7 are
   in no profile by design). Mechanism: `_dv_lock_expectations` (python)
   prints a THIRD column `name\tfile\t1` for skills of an `always_on` entry
   (awk `$1==n {print $2}` in `_dv_check_files` keeps working unchanged);
   `check_vendored_skills` reads the flag and passes it as a 5th parameter to
   `_dv_check_link`, which treats `1` as "expected linked whatever the
   profile says". If `check_vendored_skills` would exceed 5 locals, extract
   the per-name dispatch into a helper (≤ 25 logic lines each). Update the
   file header ("A name absent from the profile is reported parked" → "…
   unless its lock entry is always_on") and the test header. Message
   unchanged for the linked case, fail "<name>: symlink missing/wrong — run:
   make link" when absent. Add a case
   `ALWAYS_ON_LINK_CHECKED` to lib/tests/doctor-vendored.test.sh (fixture
   entry with always_on true, name absent from the profile, link missing →
   fail line, never `parked`). Document the field in lib/vendor-skills.sh's
   lock-shape header comment (one line: ignored by the vendor helper, read
   by doctor-vendored).
8. hooks/session-start.sh: delete line 122 (`detect_superpowers … + 800`)
   outright — the banner's ALWAYS_ON list comes from detect_rtk + settings
   enabledPlugins (lines ~147-160), not from this call. doctor.sh :225-228:
   pass "superpowers: 7 skills vendored + linked (plugins.lock.json, v6.4.1)"
   / fail "superpowers skills not linked — run: make plugin && make link";
   the pass line is worded on what `detect_superpowers` proves
   ("superpowers skills linked (brainstorming found); per-skill check under
   Vendored skills"); :423 delete the `+ 1500` line (comment: counted by the
   skill catalog stats).
9. settings.json: NOT an executor file any more — the orchestrator edits it
   after criterion 2 is green (see Orchestrator steps), so a disabled plugin
   never coincides with a failed fetch.

### E2 — citers, routing map, docs
Files: skills/{ship-feature,init-project,tour,deploy,audit-delta,gitflow,profile}/SKILL.md,
lib/{analyze-before-plan,capitalize-commit,doc-commit}.md,
agents/plugin-advisor.md, CLAUDE.global.md, README.md, USAGE.md, CHANGELOG.md.
1. `superpowers:<x>` → `<x>` (bare) in ship-feature ×4, init-project ×4,
   tour:318, deploy:515, audit-delta:321, lib/analyze-before-plan.md:106,
   agents/plugin-advisor.md:182. Wording around them: "Invoke `brainstorming`
   (vendored superpowers skill)" on first mention per file, bare afterwards.
2. finishing-a-development-branch prose: lib/capitalize-commit.md:20 → "Orchestrators
   that integrate via `gitflow finish` (the upstream
   finishing-a-development-branch is not vendored)"; :68, lib/doc-commit.md:84,
   lib/analyze-before-plan.md:108, skills/gitflow:16,110 → say "upstream
   superpowers skill, not vendored here; `gitflow finish` is the only
   integration path" where they present it as available.
3. CLAUDE.global.md § Skill routing, after the "Before /clear or /compact"
   line, ≤ 80 chars per line, about 4 lines, and NEVER the literal
   "superpowers" followed by a colon (criterion 3 greps that string):
   "- superpowers skills are vendored, called by bare name; an upstream
     `superpowers` prefix means the bare skill. Not vendored:
     executing-plans → subagent-driven-development;
     finishing-a-development-branch → `gitflow finish` (human signal);
     systematic-debugging → bugfix; verification-before-completion → the
     verifier gates."
   Every skill identifier stays WHOLE on its line (criterion 7 greps
   `finishing-a-development-branch`, `executing-plans`, `systematic-debugging`
   line by line); wrap at spaces only.
4. README.md:121 row → "**Superpowers skills** | Vendored (7, always on) |
   brainstorming, writing-plans, subagent-driven development, TDD, code
   review request, git worktrees, writing-skills — pinned v6.4.1 in
   plugins.lock.json, no plugin, no session injection | obra/superpowers".
   README:208 unchanged.
5. USAGE.md: every line presenting superpowers as a plugin to keep ON/OFF or
   as ~800 t passive (184-185, 589, 650, 751, 864, 959-965, 971, 995, 1018)
   → "skills superpowers (vendorisés, toujours actifs, 0 t passif)" or the
   equivalent in the sentence's French; keep the narrative otherwise.
6. agents/plugin-advisor.md: rows 177-182 (compat matrix) → "superpowers
   skills (vendored)" wording, drop the plugin-dev overlap row's "plugin"
   framing; recommended-set table 190-198: replace "superpowers" by
   "(superpowers skills always on)" in the ON column and subtract ~800 t from
   each cost; :80, :146, :242, :254, :298 reword; :324 remedy → "Superpowers
   skills missing → `make plugin` (vendors them) then `make link`".
7. skills/profile/SKILL.md:59: "Always-on plugins (`security-guidance`) and
   the vendored superpowers skills are never toggled by a profile".
8. CHANGELOG `[Unreleased]`: Changed (superpowers plugin → 7 vendored skills,
   pinned, always on; `superpowers:` citers renamed), Removed (plugin, its 8
   duplicate skills, the SessionStart injection), Known residual (upstream
   cross-references inside the vendored text; CLAUDE.global.md map).

## Orchestrator steps
- Criterion 2 vendors + links live (network fetch of 30 files); only when
  every file is present and byte-identical (c2.py) does the next step run.
- Then the orchestrator edits settings.json by hand: remove the
  `"superpowers@superpowers-marketplace": true` key from `enabledPlugins` and
  the whole `extraKnownMarketplaces."superpowers-marketplace"` block, nothing
  else; validate with `python3 -c 'import json;json.load(open("settings.json"))'`.
- Then, one shot by hand: `claude plugin uninstall superpowers@superpowers-marketplace`
  and `claude plugin marketplace remove superpowers-marketplace`; re-check
  `git diff settings.json` afterwards (the CLI must not have re-added
  anything), then criterion 8.
- Rollback if criterion 8 fails: `claude plugin marketplace add
  obra/superpowers-marketplace && claude plugin install superpowers@superpowers-marketplace`,
  `git checkout -- settings.json`, stop and report.
- Verifier; security; commit; BDR-106 + journal.

## Edge cases
- Mid-migration machine (plugin cached, skills not yet vendored): doctor
  fails "not vendored or linked — run make plugin && make link"; the user
  uninstalls the plugin by hand (CHANGELOG says so). No fallback that could
  print "vendored" for a plugin-only machine.
- Mixed-version rollback (an older checkout re-installs the plugin while the
  7 symlinks are still linked → duplicate descriptions): CHANGELOG note
  "after a rollback, delete skills/<7> symlinks or re-run the new make plugin".
- The running session keeps the plugin's `superpowers` skills until restart;
  the bare names appear after `make link` + a new session.
- Fresh clone: link.sh symlinks a non-existent skills-external dir only if
  present (existing `[ -d ]` guard).
- skill-routing-census live run gains 7 descriptions: brainstorming's "You
  MUST use this before any creative work" vs personal descriptions — the
  suite's live FAIL threshold must not trip (check by running it).

## Tests
- make test suite= vendor-skills, doctor-vendored (with the new
  ALWAYS_ON_LINK_CHECKED case), doctrine-citers, skill-routing-census,
  profile-default, profile-set-managed.
- shellcheck on every touched shell file.

## Disposition (RELATED MEMORY)
- honors BDR-102 / BDR-104 — vendor over plugin, shared helper, pinned commit,
  byte-for-byte text.
- honors BDR-105 — tier 2 of the prune decision.
- honors BDR-065 — docs/superpowers transient path unchanged.
- honors LRN-178 — no new top-level `source`; detect-plugins reads a path.
- honors BDR-077 — requesting-code-review's reviewer dispatch keeps the
  model-routing note in ship-feature/init-project.
