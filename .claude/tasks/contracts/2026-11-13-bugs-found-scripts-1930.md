# CONTRACT — bugs-found-scripts (BUGS-FOUND script/test items, block H6b)
- date: 2026-11-13 | flow: bugfix | branch: bugfix/bugs-found-scripts (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Fix the BUGS-FOUND entries unfixed since 2026-11-09 that live in scripts and tests: lib/profile-state.jq newline in a settings value can forge a `plugin:<id>=on` line; skills/prune-memory/tests/run-deterministic.sh:13 unchecked mktemp; session-start digest blocker line fails open (print `- open: none` after a successful read); curated-config-guard does not lock the Step 7 `(cd "$REPO" && graphify claude install)` subshell; push-guard T42c passes if the probe jq write fails; deny_lost has no pipefail; T62F mktemp outside $WORK without trap. Plus the GATE 2 LOW of 2026-11-13: push-guard T63 presence check reads ask+deny, so a deny row demoted to ask still passes.

## CLARIFICATIONS
- [gated 2026-11-13, orchestrator per user brief]
  1. profile-state.jq: every value printed into the plain text goes through one sanitizer (`gsub("[\n\r]"; " ")` or `@json` on free-text values) so no value can start a new line; plugin ids are printed only when they match the id shape `^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$`. Test: a settings fixture whose value holds `\nplugin:evil@x=on` shows no `evil` line (in the existing profile or session-banner suite).
  2. run-deterministic.sh: `SANDBOX="$(mktemp -d …)" || exit 1` and an empty-value guard; SKILL.md:34 rewrap ≤ 80 (cosmetic part of the same finding).
  3. session-start `_digest_blockers`: when the `index blocker` read succeeds with zero open rows, print `- open: none`; a failed or timed-out read prints `- open: unknown (memory.sh index failed)`. Test in session-digest.test.sh (both cases).
  4. curated-config-guard.test.sh: one lock asserting install-plugins.sh Step 7 still runs `graphify claude install` inside `(cd "$REPO" && …)` (fixed-string grep, flip-tested).
  5. push-guard T42c: assert the probe file exists and parses before using it (`jq -e . "$WORK/s-probe.json"` → check); deny_lost: `set -o pipefail` local to the function (or explicit rc checks) so a missing list or jq failure fails the check, flip-tested; T62F: settings copy under `$WORK` (cleaned by the suite trap).
  6. T63: split the presence list into a deny list checked against `.permissions.deny` only and an ask list checked against `.permissions.ask` only (rows assigned by where they sit in settings.json today).

## ACCEPTANCE CRITERIA
1. Suites green: profile (or session-banner), session-digest, curated-config-guard, push-guard, prune-memory deterministic.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/push-guard.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
2. session-digest green with the two new cases.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'open: none' hooks/session-start.sh lib/tests/session-digest.test.sh | grep -c ':[1-9]')$(PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/session-digest.test.sh 2>&1 | tail -1)
   EXPECT: 2all suites green
   EVIDENCE: MET exit=0 marker-found :: 2all suites green
3. curated-config-guard and prune-memory suites green.
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite="lib/tests/curated-config-guard.test.sh skills/prune-memory/tests/run-deterministic.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
4. Forged-line test present and green.
   CHECK: cd /home/bchanot/Documents/claude && grep -rlc 'evil@' lib/tests/*.sh | wc -l
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
5. shellcheck -x clean on every changed .sh (no new directive); make test green (manual, bun on PATH).

## FILE SCOPE
lib/profile-state.jq, lib/detect-plugins.sh (only if the sanitizer belongs there), hooks/session-start.sh (`_digest_blockers`), skills/prune-memory/tests/run-deterministic.sh, skills/prune-memory/SKILL.md (:34 rewrap), lib/tests/{session-digest,curated-config-guard,push-guard,profile or session-banner}.test.sh. BUGS-FOUND/TODO → STEP 8.
