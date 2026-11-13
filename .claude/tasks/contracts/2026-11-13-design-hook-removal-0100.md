# CONTRACT — design-hook-removal (E1)
- date: 2026-11-13 | flow: feat | branch: feature/design-hook-removal (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
E1 design hook removal (user decision 2026-11-12, block E: "hook design : SUPPRIMER", web-building.md loads by path; measured 2026-10-31: 59 fires, 0 Reads of web-building.md; fires on non-design prompts). Delete hooks/design-toolchain-reminder.sh and lib/tests/design-toolchain-reminder.test.sh; remove its UserPromptSubmit entry from settings.json (hooks.UserPromptSubmit[0].hooks[0], "Checking design signals...", keep ctx7-reminder); rules/web-building.md:50 drop "the design-toolchain hook reinforces it"; lib/tests/doctrine-citers.test.sh T7c uses the hook file as its real fixture for "pointer label checked whole" → retarget onto a synthetic fixture file under $FIX carrying the same pointer line (keep the property tested). The always-on CLAUDE.global.md "Design / UI → Read web-building.md § Design work" line stays (covers new-file turns the path rule misses). ARCHITECTURE.md:23 hooks comment → doc sync. The user's log ~/.claude/logs/design-toolchain-fires.log is left in place (user data).

## CLARIFICATIONS
- [gated 2026-11-12, user brief block E "hook design : SUPPRIMER"] deleted test authorized: lib/tests/design-toolchain-reminder.test.sh goes with the hook it tested (floor DELETED_TEST waived by the REQUEST, this line names it).
- [gated, challenge r2] T7c replaced by T8i on a one-line synthetic fixture (exact extracted row), not a count-2 copy.

## ACCEPTANCE CRITERIA
1. Hook, its test and its registration gone; ctx7 reminder still registered; settings.json valid.
   CHECK: echo $(ls hooks/design-toolchain-reminder.sh lib/tests/design-toolchain-reminder.test.sh 2>/dev/null | wc -l)$(jq -r '.hooks.UserPromptSubmit[].hooks[].command' settings.json | grep -c design-toolchain)$(jq -r '.hooks.UserPromptSubmit[].hooks[].command' settings.json | grep -c ctx7-reminder)
   EXPECT: 001
   EVIDENCE: MET exit=0 marker-found :: 001
2. web-building.md no longer names the hook.
   CHECK: grep -c 'design-toolchain hook' rules/web-building.md; true
   EXPECT: 0
   EVIDENCE: MET exit=0 marker-found :: 0
3. (r2: as T8i on a one-line synthetic fixture, exact extracted row) doctrine-citers T7c still tests "label checked whole" on a synthetic fixture; census green.
   CHECK: bash lib/tests/doctrine-citers.test.sh 2>&1 | tail -1
   EXPECT: FAIL=0
   EVIDENCE: MET exit=0 marker-found :: PASS=23 FAIL=0
4. No live reference to the deleted files outside history (.claude/, CHANGELOG.md, ARCHITECTURE.md handled by doc sync).
   CHECK: git grep -c 'design-toolchain-reminder' -- ':!.claude' ':!CHANGELOG.md' ':!ARCHITECTURE.md' | wc -l
   EXPECT: 0
   EVIDENCE: MET exit=0 marker-found :: 0
5. make test green with bun on PATH (manual, > 120 s).
   (manual: run 2026-11-13 on the feater diff, `PATH=$HOME/.bun/bin:$PATH make test` → "SUITE: all GREEN / all suites green", rc=0)
6. After STEP 6 doc sync, ARCHITECTURE.md names no design-toolchain hook (manual check at commit).

## FILE SCOPE
hooks/design-toolchain-reminder.sh (delete), lib/tests/design-toolchain-reminder.test.sh (delete), settings.json (one hooks entry), rules/web-building.md (:50), lib/tests/doctrine-citers.test.sh (T7c). ARCHITECTURE.md:23 → STEP 6 doc sync.
