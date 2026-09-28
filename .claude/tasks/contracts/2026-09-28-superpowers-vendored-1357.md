# CONTRACT — superpowers-vendored
- date: 2026-09-28 | flow: feat (ad-hoc dispatch, /feat gates replayed by the orchestrator, 2 parallel feater executors) | branch: feature/superpowers-vendored
- status: active

## REQUEST (verbatim — IMMUTABLE)
> ok merge le tout et écris les registres puis fais le tier 2

Tier 2 as decided 2026-09-28 (batch 1, option "Vendoriser 7, retirer le plugin (Recommended)"): vendor brainstorming, writing-plans, subagent-driven-development, test-driven-development, requesting-code-review, using-git-worktrees, writing-skills from obra/superpowers at the v6.4.1 commit via `lib/vendor-skills.sh`, drop the superpowers plugin (its 8 other skills and its session-start injection), rename the `superpowers:` citers.

## CLARIFICATIONS
- Pass A: none — request complete (the decision batch fixed scope and outcome).
- Pass B: no visible / public-name choice left open — the vendored skills keep their upstream names (bare, no `superpowers:` prefix; renaming would break their internal cross-references), the lock key is `superpowers`, the always-on status is inherited (not in MANAGED_EXTERNALS, like darwin-skill). Proceeds silently.
- Byte-for-byte upstream text (BDR-104 convention): the vendored files are never edited, so their internal `superpowers:<x>` mentions and references to the 8 dropped skills (executing-plans, finishing-a-development-branch, systematic-debugging, verification-before-completion, dispatching-parallel-agents, receiving-code-review, using-superpowers, diagnosing-superpowers) stay in the text; CLAUDE.global.md carries the routing map (bare names; executing-plans → subagent-driven-development; finishing-a-development-branch → `gitflow finish` on a human signal; systematic-debugging → bugfix; verification-before-completion → the verifier gates). Known residual, documented.
- Scripts inside the vendored skills are invoked as `bash scripts/<x>` upstream: no exec bit needed after curl.
- `docs/superpowers/{specs,plans}` stays the transient path (brainstorming/writing-plans still write there; gitflow purge unchanged, BDR-065).
- Live steps are the orchestrator's: criterion 2 runs the vendor helper (network) + link.sh; the plugin uninstall (`claude plugin uninstall superpowers@superpowers-marketplace`) runs AFTER the 7 skills are linked, then criterion 8 checks the catalog. Executors never run `claude plugin …`, the vendor helper against the network, link.sh, `profile.sh set`, never commit.
- [challenge 2026-09-28, 3 lenses: simplicity CONCERNS(2), robustness CONCERNS(3), correctness FATAL(5); every BLOCKER/MAJOR closed by a named plan change, r2] (a) CLAUDE.global.md map never spells the colon form; (b) `always_on` lock field + doctor-vendored always-on class, test case; (c) no uninstall code in the installer, one-shot by the orchestrator after criterion 2, marketplace removed too, rollback step; (d) settings.json hand-edited (enabledPlugins key + marketplace block) and committed; (e) detect_superpowers = file test on the linked skill, no fallback, negative control in criterion 5; (f) map trimmed, lock note trimmed, session-start line deleted plainly.
- [confirmation pass 2026-09-28, correctness CONCERNS(1), all closed by named changes, r3] map identifiers kept whole per line (grep is line-based); `always_on` mechanism pinned (third lock column, 5th `_dv_check_link` param, headers); settings.json edited by the orchestrator only after criterion 2 is green; stale installer edge case removed; doctor pass line worded on what it proves.
- Functions ≤ 25 logic lines, 80-char lines, shellcheck clean.

## ACCEPTANCE CRITERIA
1. plugins.lock.json carries the `superpowers` entry: obra/superpowers, commit 5bf4e78011075bcfc0dc295f0724994cd123ee71 (v6.4.1), path `skills`, dict of exactly the 7 skills with every upstream file listed (SKILL.md each; SDD scripts, code-reviewer.md, anthropic-best-practices.md included).
   CHECK: python3 .claude/tasks/contracts/2026-09-28-superpowers-vendored-1357.oracles/c1.py
   EXPECT: LOCK_OK
   EVIDENCE: MET exit=0 marker-found :: LOCK_OK
2. Vendored + linked live: every listed file is under skills-external/<skill>/, byte-identical to the plugin cache copy, and the 7 symlinks resolve under ~/.claude/skills.
   CHECK: bash -c 'source lib/vendor-skills.sh; vendor_pinned_skills superpowers' >/dev/null 2>&1; bash link.sh >/dev/null 2>&1; python3 .claude/tasks/contracts/2026-09-28-superpowers-vendored-1357.oracles/c2.py
   EXPECT: VENDORED_LINKED
   EVIDENCE: MET exit=0 marker-found :: VENDORED_LINKED
3. No `superpowers:` prefix remains in the personal catalog, agents, lib, hooks or doctrine (fixtures excluded; positive control first).
   CHECK: echo 'x superpowers:brainstorming' | grep -q 'superpowers:' || exit 1; if git grep -n 'superpowers:' -- skills agents lib hooks CLAUDE.global.md ':!lib/tests/fixtures' | grep -v '^skills/synced'; then exit 1; fi; echo NO_PREFIX
   EXPECT: NO_PREFIX
   EVIDENCE: MET exit=0 marker-found :: NO_PREFIX
4. Installers and link wired: install-plugins.sh no longer installs/enables the plugin and vendors `superpowers` in STEP 8e; update-all.sh refreshes it; link.sh EXTERNAL_SKILLS lists the 7; .gitignore ignores the 7 skill symlinks and the 7 skills-external dirs.
   CHECK: ! grep -qE 'install_plugin +"superpowers"|enable_plugin +"superpowers"' install-plugins.sh && grep -q 'vendor_pinned_skills superpowers' install-plugins.sh && grep -q 'vendor_pinned_skills superpowers refresh' update-all.sh && for s in brainstorming writing-plans subagent-driven-development test-driven-development requesting-code-review using-git-worktrees writing-skills; do grep -qE "^skills/$s\$" .gitignore || { echo "gitignore skills/$s"; exit 1; }; grep -qE "^skills-external/$s/\$" .gitignore || { echo "gitignore ext $s"; exit 1; }; sed -n '/^EXTERNAL_SKILLS=(/,/)/p' link.sh | grep -qw "$s" || { echo "link $s"; exit 1; }; done && echo WIRED
   EXPECT: WIRED
   EVIDENCE: MET exit=0 marker-found :: WIRED
5. profile.sh no longer protects the plugin; detect_superpowers is true on the linked vendored skill alone and false under an empty HOME (no plugin-cache glob, no claude call). [challenge r2]
   CHECK: ! grep -q 'superpowers@superpowers-marketplace' lib/profile.sh && bash -c 'source lib/detect-plugins.sh; detect_superpowers' && E=$(mktemp -d) && ! HOME="$E" bash -c 'source lib/detect-plugins.sh; detect_superpowers' && rmdir "$E" && ! grep -qE 'compgen.*superpowers|plugin list.*superpowers' lib/detect-plugins.sh && echo DETECT_OK
   EXPECT: DETECT_OK
   EVIDENCE: MET exit=0 marker-found :: DETECT_OK
6. Suites and shellcheck: vendor-skills, doctor-vendored (with the new ALWAYS_ON_LINK_CHECKED case), doctrine-citers, skill-routing-census (live catalog with the 7), profile-default, profile-set-managed green; shellcheck clean on every touched shell file. [challenge r2]
   CHECK: shellcheck install-plugins.sh update-all.sh link.sh lib/profile.sh lib/detect-plugins.sh hooks/session-start.sh doctor.sh lib/doctor-vendored.sh lib/vendor-skills.sh lib/tests/doctor-vendored.test.sh && out=$(make test suite=lib/tests/doctor-vendored.test.sh 2>&1) && echo "$out" | grep -q 'PASS ALWAYS_ON_LINK_CHECKED' && for s in vendor-skills doctor-vendored doctrine-citers skill-routing-census profile-default profile-set-managed; do out=$(make test suite=lib/tests/$s.test.sh 2>&1) || { echo "$s rc"; exit 1; }; echo "$out" | grep -qE 'FAIL=[1-9]|^FAIL ' && { echo "$s FAIL"; exit 1; }; done; echo SUITES_OK
   EXPECT: SUITES_OK
   EVIDENCE: MET exit=0 marker-found :: SUITES_OK
7. CLAUDE.global.md Skill routing carries the map for the dropped skills and says the seven are vendored, bare names.
   CHECK: grep -q 'finishing-a-development-branch' CLAUDE.global.md && grep -q 'executing-plans' CLAUDE.global.md && grep -q 'systematic-debugging' CLAUDE.global.md && grep -qi 'vendored' CLAUDE.global.md && echo ROUTING_OK
   EXPECT: ROUTING_OK
   EVIDENCE: MET exit=0 marker-found :: ROUTING_OK
8. Live after the orchestrator's uninstall + marketplace removal: no superpowers plugin installed, no enabledPlugins key, no extraKnownMarketplaces block, the 7 skills still resolve, `make doctor` reports superpowers as vendored, not failed. [challenge r2]
   CHECK: ! claude plugin list 2>/dev/null | grep -q 'superpowers@superpowers-marketplace' && python3 -c "import json,sys;d=json.load(open('settings.json'));assert 'superpowers@superpowers-marketplace' not in d['enabledPlugins'];assert 'superpowers-marketplace' not in d.get('extraKnownMarketplaces',{})" && for s in brainstorming writing-plans subagent-driven-development test-driven-development requesting-code-review using-git-worktrees writing-skills; do [ -f "$HOME/.claude/skills/$s/SKILL.md" ] || { echo "missing $s"; exit 1; }; done && bash doctor.sh 2>/dev/null | grep -qi 'superpowers.*vendored' && ! bash doctor.sh 2>/dev/null | grep -qi 'Superpowers not detected' && echo PLUGIN_GONE
   EXPECT: PLUGIN_GONE
   EVIDENCE: MET exit=0 marker-found :: PLUGIN_GONE
9. doctor.sh and session-start.sh stop charging the plugin injection (no `+ 1500` / `+ 800` superpowers constant; doctor message names the vendored skills).
   CHECK: ! grep -qE 'detect_superpowers.*\+ ?(1500|800)' doctor.sh hooks/session-start.sh && grep -qi 'vendored' doctor.sh && echo DOCTOR_OK
   EXPECT: DOCTOR_OK
   EVIDENCE: MET exit=0 marker-found :: DOCTOR_OK
10. Docs: README component table row (vendored skills, pinned v6.4.1, lock entry), USAGE.md mentions of "superpowers" as a plugin or a passive cost reworded, agents/plugin-advisor.md compatibility/recommended-set rows and the "not active → install" remedy reworded, skills/profile/SKILL.md:59 always-on sentence updated, CHANGELOG `[Unreleased]` entry (Changed: superpowers plugin → 7 vendored skills; Removed: the 8 other skills + injection; Known residual: upstream cross-references).
11. lib/capitalize-commit.md, lib/doc-commit.md, lib/analyze-before-plan.md and skills/gitflow/SKILL.md describe finishing-a-development-branch as the upstream skill this config does not vendor (gitflow finish replaces it), not as an active skill.
12. doctor-vendored treats the 7 as always-on: `bash doctor.sh` prints a pass line for each of the 7 (linked) and never "parked" for them. [challenge r2]
   CHECK: out=$(bash doctor.sh 2>/dev/null); for s in brainstorming writing-plans subagent-driven-development test-driven-development requesting-code-review using-git-worktrees writing-skills; do echo "$out" | grep -qE "✓.*\b$s\b" || { echo "no pass for $s"; exit 1; }; echo "$out" | grep -qE "$s.*parked" && { echo "parked $s"; exit 1; }; done; echo ALWAYS_ON_OK
   EXPECT: ALWAYS_ON_OK
   EVIDENCE: MET exit=0 marker-found :: ALWAYS_ON_OK

## FILE SCOPE
- plugins.lock.json, install-plugins.sh (STEP 5 superpowers block, STEP 8e, summary lines), update-all.sh (7.3), link.sh (EXTERNAL_SKILLS), .gitignore, lib/profile.sh (PROTECTED_PLUGINS + comments), lib/detect-plugins.sh, hooks/session-start.sh, doctor.sh, lib/doctor-vendored.sh, lib/tests/doctor-vendored.test.sh, lib/vendor-skills.sh (lock-shape header comment line)
- skills/{ship-feature,init-project,tour,deploy,audit-delta,gitflow,profile}/SKILL.md, lib/{analyze-before-plan,capitalize-commit,doc-commit}.md, agents/plugin-advisor.md, CLAUDE.global.md (Skill routing lines), README.md, USAGE.md, CHANGELOG.md
- Orchestrator-only, after criterion 2: settings.json (enabledPlugins key + extraKnownMarketplaces block, hand edit), `claude plugin uninstall` + `claude plugin marketplace remove` (cache), rollback if criterion 8 fails; skills-external/<7> (gitignored, curl) and ~/.claude/skills symlinks are written by criterion 2
- Orchestrator-only: .claude/tasks/**, .claude/memory/**
