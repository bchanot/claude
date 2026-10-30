# CONTRACT — memory-upgrade-prose-closure

## REQUEST (verbatim — IMMUTABLE)
lib/memory.sh upgrade: _mem_upgrade_repair cements a v1 legacy-reader false-closed verdict as an explicit `- **Status (date, upgrade)**: resolved` line. Repro: orbistep (/home/bchanot/Documents/game) blockers.md BLK-021 (`date: 2026-09-20 · status: open …`, prose "another tab already resolved it" matched the case-insensitive legacy regex) and BLK-026 (`status: open (user: activate the Plus subscription)`) both get `resolved`; BLK-030 (`status: code resolved (df5818c) · SMTP open (upstream OVH)`) gets `resolved`; zenquality BLK-006 (`**Statut** : resolved (blockage), open (root delivery cause …)`) gets `resolved`. Second defect: the repair line is written twice when a `### BLK-008 UPDATE …` sub-heading repeats the ID (game BLK-008, blockers.md lines 102-103 after upgrade). The upgrade oracle cannot see it because the v1 reader already read these as closed, so the open set is "unchanged". After the fix: reset game and zenquality .claude/memory to HEAD on their chore/memory-v2 branches (user approved), re-apply game's 16-line heading fix, re-run upgrade, and verify. Also user-approved: record an open BLK in claude-config's blockers.md for this bug.

## CLARIFICATIONS
- 2026-10-30 user: an ambiguous v1 closure (prose or mixed label) → upgrade refuses the file (rc 2) and names the ID, never guesses a status ("Refuser et nommer").
- Plan r3: `.claude/tasks/plans/2026-10-30-memory-upgrade-prose-closure-0040.md` (fix plan steps 1-6 + R3 ADDENDUM race). The executor implements steps 1-5 + the race fix; step 6 is the oracle of criterion 4. The follow-up (resetting game/zenquality, statuses) is NOT in this diff.
- Diagnosis: BLK-038 (this repo's blockers.md).

## ACCEPTANCE CRITERIA
1. The memory suite is green with every new T15 fixture of plan step 5 (a, b, b2, b3, c, d, d2, e, e2, e3, e4, g), each check named with the prefix listed here: T15-prose-refused, T15-mixed-date-refused, T15-mixed-statut-refused, T15-mixed-strict-boundary, T15-datestatus-word, T15-subhead-one-repair, T15-subhead-reopened, T15-remedy-roundtrip, T15-remedy-subhead, T15-dated-then-prose-refused, T15-range-continues, T15-oracle-dup-refused.
   CHECK: cd /home/bchanot/Documents/claude && out=$(make test suite=lib/tests/memory.test.sh 2>&1) && printf '%s\n' "$out" | grep -q 'FAIL=0' && for n in T15-prose-refused T15-mixed-date-refused T15-mixed-statut-refused T15-mixed-strict-boundary T15-datestatus-word T15-subhead-one-repair T15-subhead-reopened T15-remedy-roundtrip T15-remedy-subhead T15-dated-then-prose-refused T15-range-continues T15-oracle-dup-refused; do grep -q "$n" lib/tests/memory.test.sh || exit 1; done && echo MEMORY-SUITE-OK
   EXPECT: MEMORY-SUITE-OK
   EVIDENCE: MET exit=0 marker-found :: MEMORY-SUITE-OK
2. The reconcile suite stays green and lib/reconcile.sh is unchanged (reconcile's default 2-arg v1 reader is out of scope).
   CHECK: cd /home/bchanot/Documents/claude && git diff --quiet develop -- lib/reconcile.sh && out=$(make test suite=lib/tests/run-reconcile.sh 2>&1) && printf '%s\n' "$out" | grep -q ' 0 RED' && echo RECONCILE-OK
   EXPECT: RECONCILE-OK
   EVIDENCE: MET exit=0 marker-found :: RECONCILE-OK
3. lib/memory.sh is shellcheck-clean and no added line exceeds 80 columns.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck lib/memory.sh && [ "$(git diff develop -- lib/memory.sh | grep '^+' | grep -v '^+++' | awk 'length($0) > 81' | wc -l)" = 0 ] && echo LINT-OK
   EXPECT: LINT-OK
   EVIDENCE: MET exit=0 marker-found :: LINT-OK
4. Real data (plan step 6): replaying the upgrade with the working-tree lib on the 13 repos' pre-upgrade registries refuses exactly orbistep blockers.md (BLK-021, BLK-026, BLK-030 named) and zenquality blockers.md (BLK-006 named), leaves both files byte-identical, and reproduces every other registry byte-for-byte; no entry carries two upgrade lines. Positive control done 2026-10-30 on the unfixed lib: rc 1 (config BLK-003 race line, game/zenquality not refused, BLK-008 duplicate).
   CHECK: bash /tmp/claude-1000/-home-bchanot-Documents-claude/a1113f35-c77c-47c4-95de-a37231ae0306/scratchpad/up4a/realdata.sh /home/bchanot/Documents/claude
   EXPECT: REALDATA-OK
   EVIDENCE: MET exit=0 marker-found :: work dir: /tmp/claude-1000/-home-bchanot-Documents-claude/a1113f35-c77c-47c4-95de-a37231ae0306/scratchpad/up4a/realdata.5uaw REALDATA-OK
5. The repair names on stderr every ID it writes (with its v1 line) and every ID it refuses (with its v1 line and the `memory.sh status <ID> …` remedy); `explicit` rows are named once and never refuse. Judged by the verifier from the code and fixture stderr assertions.
6. The v1-open / strict-closed direction (BLK-032..034 fix, BDR-129) is unchanged: such rows are still kept and named, never repaired. Judged by the verifier (existing tests stay green).

## FILE SCOPE
- lib/memory.sh (memory_legacy_status `<end>` branch, _mem_verdict_diff, _mem_upgrade_repair, _mem_upgrade_oracle; the header comment if the upgrade contract text changes)
- lib/tests/memory.test.sh (T15 additions)
