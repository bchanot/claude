# CONTRACT — modern-web-guidance
- date: 2026-11-21 | flow: ship-feature | branch: feature/modern-web-guidance
- status: active
- run-base: d74dd2c8fadad2cba5de5118593aa9837b3efb5c

## REQUEST (verbatim — IMMUTABLE)
j'aimerias qu'on rajoute un skill ou une guidance pour tout ce qui est front, web ou non, tout ce qui s'applique, utiliser le modern web guidance de google https://developer.chrome.com/docs/modern-web-guidance?hl=fr pour tout ce qui est ajour sur les facon de faire  et qu'il soit utiliser systematiquement sur les front donc avec les autre skill et agents de front

## CLARIFICATIONS
Q: delivery of the upstream package (its skill runs `npx -y modern-web-guidance@latest` on every call) / A: pinned vendor copy at v1.0.1, our own thin skill reads the local guides, no npx, no network, no remote code; upstream SKILL.md not linked [gated 2026-11-21]
Q: where it is wired / A: path rule rules/web-building.md + design skills (not audit skills, not agents) [gated 2026-11-21]
Q: disclosure / A: short, one line at the end of a front-end answer naming the guide ids consulted, no quotes [gated 2026-11-21]
Q: chrome-extensions skill of the same package / A: installed too, vendored and pinned [gated 2026-11-21]
Q: name and placement of our skill / A: `modern-web-guidance`, flat in skills/, always on in every profile; the vendored dir carries another name [gated 2026-11-21]
Q: guide vs our web rules when they disagree / A: the guide wins on how to use the platform; our rule is adjusted (e.g. motion line) [gated 2026-11-21]
Q: path rule globs / A: unchanged (no .js/.mjs/.ts); plain client JS relies on the skill description [gated 2026-11-21]
Q: chrome-extensions placement / A: always on, as is (its CHROMEWEBSTORE.md behaviour accepted, it only triggers on extension work) [gated 2026-11-21]
Q: plugin gate, switch this repo to the dev profile / A: no, keep full [gated 2026-11-21]
Q: challenge deferred point (confirmation MAJOR): any main-loop Skill call sets model-router `st.skillRun` (register.ts:4634) and opens the write guard for the session, so the rule's skill call would let the main loop write front code outside a code skill (find-docs already does) / A: reopen — model-router gets a reference-skill list (`modern-web-guidance`, `find-docs`) that never opens the guard, with tests; FILE SCOPE gains mods/model-router/hooks/register.ts and register.test.ts [gated 2026-11-22]

## ACCEPTANCE CRITERIA
1. The Modern Web Guidance guides of tag v1.0.1 (commit 64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65) and the chrome-extensions skill are vendored, pinned by that commit in plugins.lock.json, installed by `make plugin` and refreshed at the pin by `make update`; no install or use path runs `npx modern-web-guidance` or reaches the network at use time.
2. Our own skill exposes the local guides (search and read by id) with no npx and no network, and states the short disclosure line.
3. rules/web-building.md tells any front-end work to consult the guidance before writing code, and § Design work makes every design-stack step consult it.
4. The upstream modern-web-guidance SKILL.md is not linked into ~/.claude.
5. `make test` stays green (bun on PATH) and `make doctor` reports no new error.

6. [gated 2026-11-22] Pin, install wiring and the live copy: plugins.lock.json key `modern-web-guidance` holds tag v1.0.1 and commit 64a6d708…; both install-plugins.sh and update-all.sh call `vendor_pinned_tree modern-web-guidance` inside `if !` (a fetch failure warns, never aborts); skills-external/mwg is at the pin, INDEX.md has one line per guide, no upstream SKILL.md; the vendor-tree suite is green.
   CHECK: python3 -c "import json;e=json.load(open('plugins.lock.json'))['modern-web-guidance'];assert e['commit']=='64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65' and e['tag']=='v1.0.1'" && grep -q 'if ! vendor_pinned_tree modern-web-guidance; then' install-plugins.sh && grep -q 'if ! vendor_pinned_tree modern-web-guidance; then' update-all.sh && [ "$(cat skills-external/mwg/.vendored-commit)" = 64a6d708f5a43f2cd3fde5d4d7db3905ba1bdf65 ] && [ "$(grep -c '^- ' skills-external/mwg/INDEX.md)" -eq "$(find skills-external/mwg/guides -name '*.md' | wc -l)" ] && [ -f skills-external/chrome-extensions/SKILL.md ] && [ ! -e skills-external/mwg/SKILL.md ] && make test suite=lib/tests/vendor-tree.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
7. [gated 2026-11-22] Our skill skills/modern-web-guidance: allowed-tools Read only, no effort, no routing row (NO_ROW_SKILLS), description within 400 characters, reads mwg/INDEX.md then guides by local path, never runs npx or a network command, one tracked `mwg` symlink, the disclosure line scoped to answers that deliver a front-end change.
   CHECK: make test suite=lib/tests/mwg-skill.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
8. [gated 2026-11-22] Rule wiring: rules/web-building.md has the section `## Modern Web Guidance first` (sub-agent path without the Skill tool, guide wins on platform usage, an executor reports a plan/guide conflict as an open choice) and § Design work makes every Build, polish, motion and scroll step consult it; the Design work heading and the locked `reflect` line stay byte-identical; site-motion carries the same line.
   CHECK: grep -qx '## Modern Web Guidance first' rules/web-building.md && grep -q 'Read `~/.claude/skills/modern-web-guidance/SKILL.md` and follow it.' rules/web-building.md && grep -q '`modern-web-guidance` first for the platform features it uses.' rules/web-building.md && echo WIRED
   EXPECT: WIRED
   EVIDENCE: MET exit=0 marker-found :: WIRED
9. [gated 2026-11-22] The upstream modern-web-guidance SKILL.md (npx search/retrieve) is linked nowhere under ~/.claude/skills; chrome-extensions is linked as an always-on flat skill.
   CHECK: ! grep -l 'modern-web-guidance@latest search' ~/.claude/skills/*/SKILL.md 2>/dev/null | grep -q . && [ -L ~/.claude/skills/chrome-extensions ] && echo NOT_LINKED
   EXPECT: NOT_LINKED
   EVIDENCE: MET exit=0 marker-found :: NOT_LINKED
10. [gated 2026-11-22] Full suite green and doctor reports no error (baseline 2026-11-22: "No errors, 2 warning(s)").
   CHECK: PATH="$HOME/.bun/bin:$PATH" make test 2>&1 | tail -1 | grep -qx 'all suites green' && bash doctor.sh 2>&1 | grep -q 'No errors' && echo SUITE_DOCTOR_OK
   EXPECT: SUITE_DOCTOR_OK
   EVIDENCE: MET exit=0 marker-found :: SUITE_DOCTOR_OK
11. [gated 2026-11-22] model-router: a main-loop Skill call to a reference skill (`modern-web-guidance`, `find-docs`) never sets `st.skillRun`, typed or by name; any other skill still opens the write guard; covered by register.test.ts.
   CHECK: grep -q "'modern-web-guidance', 'find-docs'," mods/model-router/hooks/register.ts && PATH="$HOME/.bun/bin:$PATH" make test suite=lib/tests/mods.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
12. [gated 2026-11-22] Doctor: check_vendored_trees warns (never errors) on a missing or stale vendored tree with the remedy `make plugin`, and a missing vendored copy no longer stops doctor under `set -euo pipefail`.
13. [gated 2026-11-22] vendor_pinned_tree refuses before writing anything: a commit not upstream, unsafe lock paths, a dest it did not create (no marker), a symlink in the fetched content or a listed path leaving the checkout; a failed swap restores the previous copy.

## FILE SCOPE
[gated 2026-11-22, STEP 3 approved plan docs/superpowers/plans/2026-11-21-modern-web-guidance.md]
- lib/vendor-skills.sh, lib/tests/vendor-tree.test.sh
- plugins.lock.json, install-plugins.sh, update-all.sh, link.sh, .gitignore
- lib/doctor-vendored.sh, doctor.sh, lib/tests/doctor-vendored.test.sh
- skills/modern-web-guidance/ (SKILL.md, test-prompts.json, `mwg` symlink), lib/tests/mwg-skill.test.sh, lib/tests/effort-routing.test.sh
- rules/web-building.md, skills/pack-design/skills/site-motion/SKILL.md
- mods/model-router/hooks/register.ts, mods/model-router/hooks/register.test.ts
- docs (STEP 8): README.md, USAGE.md, CHANGELOG.md, docs/superpowers/specs/2026-11-21-modern-web-guidance-design.md, docs/superpowers/plans/2026-11-21-modern-web-guidance.md
- generated, gitignored (Task 6): skills-external/mwg/, skills-external/chrome-extensions/, skills/chrome-extensions link
