# CONTRACT — gstack-playwright-extract-hang
- date: 2026-11-26 | flow: bugfix | branch: bugfix/gstack-playwright-extract-hang
- status: active
- run-base: 81cf9507e91415ba91287e4ef2c87ab00e98302d

## REQUEST (verbatim — IMMUTABLE)
User message 1:
j'ai encore les blocage sur mac sur l'installation de chromium tu peux corriger cela dans l'installation de claude.
(pasted log: gstack setup, "Installing Playwright Chromium...", "Removing unused browser at .../ms-playwright/chromium-1208", "Downloading Chrome for Testing 145.0.7632.6 (playwright chromium v1208) ... mac-arm64", progress rows up to 90% of 162.3 MiB)

User message 2:
ok. il faut faire la correction de l'installation du playwright de gstack la maintenant

## CLARIFICATIONS
Q: build the local-bump fix although the cause is not confirmed on the Mac / A: yes, build now [gated 2026-11-26]
Q: time bound on the gstack setup step / A: later, not in this run [gated 2026-11-26]
Q: after the plan challenge (local bump dirties the submodule; upstream already fixed) / A: test first without code; then, same day: "il faut faire la correction ... maintenant" [gated 2026-11-26]
Orchestrator note 2026-11-26: moving the submodule pointer is out (upstream main dropped the cso and investigate skills; first pin-raising upstream commit changes 1935 files). No Node-version gate. Plan: .claude/tasks/plans/2026-11-26-gstack-playwright-extract-hang-1211.md (revised after 3 challengers).
Declined (robustness MAJOR): manual-discard hint in update-all.sh; goes with the gstack migration.

Q: security gate MEDIUM, the bump installs `playwright@latest` unpinned, now on every host / A: commit round 1, then pin an exact version in a second commit before any merge proposal [gated 2026-11-26]
Orchestrator note 2026-11-26: pinned version 1.65.0 (what upstream gstack pins; carries the macOS sandbox-escape fix of 1.64.1). Round 2 amends criterion 5: `_gspw_bump_add_latest` becomes `_gspw_bump_add` with the exact version.

## ACCEPTANCE CRITERIA
1. The bump no longer returns early on a host without /etc/os-release: on
   any OS, an installed gstack Playwright older than 1.60.0 triggers
   the bump (`bun add` of the pinned version, criterion 7) before ./setup; the threshold lives in one
   constant. A regression test covers the no-os-release host.
   CHECK: cd /home/bchanot/Documents/claude && f=lib/gstack-playwright.sh; n=$(grep -c -- '-r /etc/os-release \] || return 0' $f); [ "$n" -eq 0 ] && grep -q '^_GSPW_EXTRACT_FIX_MIN="1.60.0"' $f && grep -q 'T20' lib/tests/gstack-playwright.test.sh && echo any-os-bump
   EXPECT: any-os-bump
   EVIDENCE: MET exit=0 marker-found :: any-os-bump
2. Suite green, new cases T18..T27 present: version read, floor compare,
   bump on version reason, no bump when safe, OS reason kept (failed and
   successful bump), failed-bump warning naming the expected freeze,
   bun-install failure warned, errexit safety on the bump path.
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'T27' lib/tests/gstack-playwright.test.sh && make test suite=lib/tests/gstack-playwright.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
3. shellcheck clean on the lib, its suite and install-plugins.sh.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck lib/gstack-playwright.sh lib/tests/gstack-playwright.test.sh install-plugins.sh && echo clean
   EXPECT: clean
   EVIDENCE: MET exit=0 marker-found :: clean
4. Every path of the bump prints what it did: install failed, version and
   "no bump needed", the bump reason, the outcome (bumped to X, or left
   as is, with the expected-freeze warning only when the remaining reason
   is the version one).
   Function returns 0 on every path.
5. The code of `_gspw_bump_install` and
   `gstack_submodule_update_with_bump` is unchanged (a comment may be
   reworded); `_gspw_bump_add_latest` is renamed `_gspw_bump_add` (round 2); the lib holds no
   destructive command (existing T8); one reader for the version field
   (`_gspw_install_label` calls `gstack_pw_version`).
7. The bump installs an exact version held in one constant
   (`_GSPW_BUMP_VERSION`), with `bun add --exact`; the lib never asks for
   `playwright@latest`. An oversized version field counts as unknown (no
   bump).
   CHECK: cd /home/bchanot/Documents/claude && f=lib/gstack-playwright.sh; grep -q '^_GSPW_BUMP_VERSION="1.65.0"' $f && grep -q 'bun add --exact' $f && ! grep -q 'playwright@latest' $f && grep -q 'T28' lib/tests/gstack-playwright.test.sh && echo pinned
   EXPECT: pinned
   EVIDENCE: MET exit=0 marker-found :: pinned
6. Not verified on macOS from this machine: the user runs
   `make test suite=lib/tests/gstack-playwright.test.sh` and `make plugin`
   on the Mac from the branch. The root cause is a hypothesis until then.

## FILE SCOPE
lib/gstack-playwright.sh
lib/tests/gstack-playwright.test.sh
install-plugins.sh (comment above the bump call only)
