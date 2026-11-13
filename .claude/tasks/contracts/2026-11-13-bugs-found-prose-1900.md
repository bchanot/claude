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

## ACCEPTANCE CRITERIA
1. Each of the 10 items changed in its file (read check by the verifier, item by item).
   CHECK: cd /home/bchanot/Documents/claude && git diff --stat develop -- agents/handover-doc-writer.md agents/client-handover-writer.md agents/plugin-advisor.md lib/plugin-gate.md skills/onboard/SKILL.md skills/tour/SKILL.md skills/plugin-check/SKILL.md USAGE.md .gitignore plugins.lock.json update-all.sh install-plugins.sh | tail -1 | grep -c '12 files changed'
   EXPECT: 1
   EVIDENCE: PENDING
2. No "gstack ON/OFF" left in onboard/tour; no `extras` among plugin-gate's accepted tokens.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'gstack ON/OFF\|gstack ON\b' skills/onboard/SKILL.md skills/tour/SKILL.md | grep -vc ':0$')
   EXPECT: 0
   EVIDENCE: PENDING
3. plugins.lock.json valid JSON; shellcheck clean on update-all.sh and install-plugins.sh changes (no new finding vs develop).
   CHECK: cd /home/bchanot/Documents/claude && jq . plugins.lock.json >/dev/null && echo JSON-OK
   EXPECT: JSON-OK
   EVIDENCE: PENDING
4. Suites that read these files stay green: handover-memory-contract, doctrine-citers, skill-routing-census, curated-config-guard, portability-census.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/handover-memory-contract.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: PENDING
5. make test green (manual, bun on PATH).

## FILE SCOPE
agents/handover-doc-writer.md, agents/client-handover-writer.md, agents/plugin-advisor.md, lib/plugin-gate.md, skills/onboard/SKILL.md, skills/tour/SKILL.md, skills/plugin-check/SKILL.md, USAGE.md, .gitignore, plugins.lock.json, update-all.sh, install-plugins.sh. LRN-154 + BUGS-FOUND → STEP 8.
