# CONTRACT — bugs-found-prose (BUGS-FOUND agent/skill/doc items, block H6a)
- date: 2026-11-13 | flow: bugfix | branch: bugfix/bugs-found-prose (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Fix the BUGS-FOUND entries unfixed since 2026-11-09 that live in agent, skill, lib-prose and doc files: handover-doc-writer §6.1 status filter; handover STEP 10 paths not rooted on the PACKAGE root + space-split PROJECT line; handover/client-handover ROOT double-quoted literal + unquoted `-C <root>` remedy; plugin-advisor `embedded` from REQUEST keywords alone; plugin-gate accepts pack `extras`; onboard/plugin-advisor "pinned ctx7" wording; `make plugin` cwd-dependent remedy + undefined "A) fix plugins"; plugin-gate templates double quotes, linked-worktree apply-check path, PROJECT_ROOT = $HOME; "gstack ON/OFF" vocabulary in onboard/tour + unwrapped lines; stale graphify claims (.gitignore, plugins.lock.json, update-all.sh, install-plugins.sh labels/comment, LRN-154).

## CLARIFICATIONS
- [gated 2026-11-13, orchestrator per user brief: the fix that answers each finding, no new design]
  1. handover-doc-writer §6.1: only BDRs whose current word (from `memory.sh -C "$ROOT" index decision`, the reader STEP 9 already uses) is accepted/implemented/proposed enter the vulgarized list; superseded/deprecated are left out (one sentence says so in the deliverable's method note).
  2. handover STEP 10 + every other git/file read in that agent: `git -C "$ROOT" …` / `"$ROOT/…"`; the PACKAGE carries the root on its own line `PROJECT_ROOT: <path>` read whole-line (spaces kept); client-handover-writer emits that line.
  3. ROOT assignment: the agents take the root from that whole line into a variable via a read (no pasted double-quoted literal), and every printed remedy quotes it: `memory.sh -C "<root>" status …`.
  4. plugin-advisor: `embedded` → `↻ SET : minimal` only from project-level signals (files, manifests), never REQUEST keywords alone; REQUEST keywords may only add a NOTE.
  5. plugin-gate.md: `extras` removed from the accepted advisor tokens (same reason as higgsfield: 21st-ai metered); the user can still `profile.sh enable extras` by hand.
  6. ctx7 wording: "installs ctx7 (latest, plugins.lock.json pins `latest`)" in onboard SKILL.md and plugin-advisor (no pin added).
  7. `make plugin` remedies: `make -C ~/Documents/claude plugin` is not portable: write "run `make plugin` in your claude-config checkout" (print-only); plugin-gate "A) fix plugins" defined as exactly that print.
  8. plugin-gate templates: tokens and `<PROJECT_ROOT>` in single quotes; the apply check compares the parent of `git rev-parse --git-common-dir` (what profile.sh writes) and refuses PROJECT_ROOT equal to `$HOME`.
  9. onboard SKILL.md:387-762 and tour SKILL.md:155 "gstack ON/OFF" → the packs vocabulary used since D3 (`pack gstack-dev on/off`, `profile.sh current`); rewrap plugin-check SKILL.md:17, plugin-gate.md:45, USAGE.md:182; USAGE.md:1022 transcript gains the ↻ glyph.
  10. graphify: .gitignore:54-56, plugins.lock.json:37, update-all.sh:310-312 (point at `make plugin`, no manual `graphify claude install`), install-plugins.sh:688/690/1269 labels and :694-695 comment say what the steps do now (the trap reverts the CLAUDE.md block and hook). LRN-154 gets a `memory.sh status` correction line in STEP 8 (registry append-only), not an edit.

- [gated 2026-11-13, round 2: GATE 1 ECARTS(2) + GATE 2 MEDIUM/LOWs] FILE SCOPE += lib/tests/session-banner.test.sh (SB10 locks follow item 8: lock `diff '<profile>'` single-quoted and `--git-common-dir`), lib/profile.sh + lib/tests/profile.test.sh (deterministic refusal: `find_root`/`require_project_root` reject a root that resolves (`cd -P`) to `$HOME`, test included), skills/init-project/SKILL.md:43, skills/ship-feature/SKILL.md:27 (the "A) fix plugins" citers get the print-only definition).
  R2-a plugin-gate + plugin-check: before any template, a PROJECT_ROOT holding `'` or a newline or control char is never substituted: print the commands and run nothing (one rule sentence); refusal text at :75-76 names the three causes (no git root, linked worktree/submodule, $HOME).
  R2-b handover-doc-writer: the ROOT read block opens EVERY Bash call that uses $ROOT (say so once), uses `"${ROOT:?}"` at each use; :158-159 commits read rooted with `git -C "${ROOT:?}"`; draft/audit paths rooted (`"${ROOT:?}/.audit/…"`) in both agents; a root holding a newline or control char → `STATUS: BLOCKED` (client-handover-writer checks before writing the PACKAGE).
  R2-c client-handover-writer remedy: `memory.sh -C '<root>' status …` single-quoted, plus the same "root holding `'` → print with a warning, never run" rule.
  R2-d item 9 residue: plugin-gate.md:46 ≤ 80, tour SKILL.md:155 ≤ 80, onboard :673/:682/:706 consistent (the design-review fallback condition and its note name the SAME pack, the one the L3b probe at :610-611 actually reads, or add the gstack-design probe there), onboard :549-550 qualified `make plugin`, plugin-advisor :265-266 drops `extras` from pack values, USAGE.md:179 ≤ 80.
  R2-e handover §6.1: decisions with an empty status word are listed separately as "status unreadable (n)" in the method sentence, not silently dropped; the sentence sits at the close of §6.1 (no method-note section exists).

- [gated 2026-11-13, round 2 executor deviation accepted] the $HOME refusal sits in `require_project_root` (every mutating command); `find_root` still answers $HOME for read-only `current`/`diff`.

## ACCEPTANCE CRITERIA
1. Each of the 10 items changed in its file (read check by the verifier, item by item).
   CHECK: cd /home/bchanot/Documents/claude && git diff --stat develop -- agents/handover-doc-writer.md agents/client-handover-writer.md agents/plugin-advisor.md lib/plugin-gate.md skills/onboard/SKILL.md skills/tour/SKILL.md skills/plugin-check/SKILL.md USAGE.md .gitignore plugins.lock.json update-all.sh install-plugins.sh | tail -1 | grep -c '12 files changed'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
2. No "gstack ON/OFF" left in onboard/tour; no `extras` among plugin-gate's accepted tokens.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'gstack ON/OFF\|gstack ON\b' skills/onboard/SKILL.md skills/tour/SKILL.md | grep -vc ':0$')
   EXPECT: 0
   EVIDENCE: MET exit=0 marker-found :: 0
3. plugins.lock.json valid JSON; shellcheck clean on update-all.sh and install-plugins.sh changes (no new finding vs develop).
   CHECK: cd /home/bchanot/Documents/claude && jq . plugins.lock.json >/dev/null && echo JSON-OK
   EXPECT: JSON-OK
   EVIDENCE: MET exit=0 marker-found :: JSON-OK
4. Suites that read these files stay green: handover-memory-contract, doctrine-citers, skill-routing-census, curated-config-guard, portability-census.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/handover-memory-contract.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
6. session-banner and profile suites green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite="lib/tests/session-banner.test.sh lib/tests/profile.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
5. make test green (manual, bun on PATH).
   (manual: full run by the round-2 executor 2026-11-13 → "SUITE: all GREEN / all suites green")

## FILE SCOPE
agents/handover-doc-writer.md, agents/client-handover-writer.md, agents/plugin-advisor.md, lib/plugin-gate.md, skills/onboard/SKILL.md, skills/tour/SKILL.md, skills/plugin-check/SKILL.md, USAGE.md, .gitignore, plugins.lock.json, update-all.sh, install-plugins.sh. LRN-154 + BUGS-FOUND → STEP 8.
