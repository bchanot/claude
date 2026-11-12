# CONTRACT — manual-push-prose-d3 (run D3 of manual-push mode)
- date: 2026-10-07 | flow: feat | branch: feature/manual-push-mode (after D1 + D2: every reader fails closed)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (fr): "ok enchaine sur le run D"
Run D as consolidated in `.claude/tasks/TODO.md`; D3 slice: skill/agent prose — drop the "until run D" caveats now that every reader fails closed, stale "COMMIT + PUSH" headings in client-handover, release-executor own version regex; then doc-sync (CHANGELOG, SETTINGS "still push on an invalid value" sentences).

## CLARIFICATIONS
Q: heading rename "COMMIT + PUSH" / A: agents/client-handover-writer.md `## STEP 5 — COMMIT + PUSH (only if files changed)` → `## STEP 5 — COMMIT + PUSH STATE READ (only if files changed)`; skills/client-handover/SKILL.md step 4 bold label `**COMMIT + PUSH**` → `**COMMIT + PUSH STATE READ**` (the agent's own term for the sub-step; "PUSH STATE" alone could read as "push the state"). Repo-wide grep shows no other citer of either string (checked 2026-10-07: only those two lines). [orchestrator — public-name-ish label, surfaced in the final report]
Q: invalid-value wording after D1 / A: challenge r1 — the ahead count DECIDES the wording: `ahead` > 0 or unknown → "treated as manual push mode by every reader, nothing pushed"; `ahead` = 0 → "pushed anyway: a hook in this repo still fails open (stale .githooks/, refreshed next session)". The verb's stderr line is quoted verbatim (never a templated value). [orchestrator]
Q: executor version check / A: prep span only (finish's branch precondition already depends on prep), checked by reading the string, never inside a Bash command. [orchestrator — revised]
Q: D1/D2 precondition / A: the executor's first step greps for any surviving `--default true gitflow.autopush` reader; a hit → BLOCKED. [orchestrator]
Q: release-executor version check / A: SUPERSEDED by the "revised" entry below (prep span only, by reading). [orchestrator]

## ACCEPTANCE CRITERIA
1. skills/capitalize/SKILL.md: no "until run D" text; the invalid-mode outcome is split on the ahead count in 5C and in STEP 6 (`> 0`/unknown → treated as manual by every reader, nothing pushed, user command with the `once a remote exists` qualifier when unknown; `= 0` → pushed anyway, stale fail-open hook named); the verb's stderr line is quoted verbatim; the `--no-push` ahead-0 line carries the invalid qualifier.
   CHECK: [ "$(grep -c 'until run D' skills/capitalize/SKILL.md)" = 0 ] && [ "$(grep -c 'treated as manual push mode by every reader' skills/capitalize/SKILL.md)" -ge 2 ] && [ "$(grep -c 'still fails open' skills/capitalize/SKILL.md)" -ge 2 ] && [ "$(grep -c 'verb stderr line verbatim' skills/capitalize/SKILL.md)" -ge 5 ] && grep -q 'pushed anyway' skills/capitalize/SKILL.md && grep -q 'push mode `auto`, finish rc 0' skills/capitalize/SKILL.md && echo CAPITALIZE-OK
   EXPECT: CAPITALIZE-OK
   EVIDENCE: MET exit=0 marker-found :: CAPITALIZE-OK
2. client-handover: both labels renamed to "COMMIT + PUSH STATE READ"; the STEP 5 residual lines ("Before any commit or push", "do NOT commit, do NOT push", "Commit/push skipped") no longer imply the pipeline pushes; the skill's step 4 names the invalid value.
   CHECK: grep -q 'COMMIT + PUSH STATE READ' agents/client-handover-writer.md && grep -q 'COMMIT + PUSH STATE READ' skills/client-handover/SKILL.md && [ "$(grep -h 'COMMIT + PUSH' agents/client-handover-writer.md skills/client-handover/SKILL.md | grep -vc 'COMMIT + PUSH STATE READ')" = 0 ] && ! grep -q 'Commit/push skipped' agents/client-handover-writer.md && grep -q 'invalid gitflow.autopush' skills/client-handover/SKILL.md && echo HANDOVER-OK
   EXPECT: HANDOVER-OK
   EVIDENCE: MET exit=0 marker-found :: HANDOVER-OK
3. agents/release-executor.md: the prep span's Input carries the format-check sentence (by reading, never in a Bash command) with the literal regex; the manual-mode line also names an invalid value.
   CHECK: grep -qF '^[0-9]+\.[0-9]+\.[0-9]+$' agents/release-executor.md && grep -q 'by reading the string' agents/release-executor.md && grep -q 'invalid gitflow.autopush' agents/release-executor.md && echo EXECUTOR-OK
   EXPECT: EXECUTOR-OK
   EVIDENCE: MET exit=0 marker-found :: EXECUTOR-OK
4. Doctrine citers census green; floor guard clean; every hermetic suite green except the declared environmental red.
   CHECK: make test suite=lib/tests/doctrine-citers.test.sh >/dev/null 2>&1 && bash ~/.claude/lib/floor-guard.sh develop -- skills/capitalize/SKILL.md skills/client-handover/SKILL.md agents/client-handover-writer.md agents/release-executor.md >/dev/null 2>&1 && fail=0 && for t in $(ls lib/tests/*.test.sh lib/seo-data/*.test.sh lib/gitflow-test.sh lib/tests/run-*.sh | grep -v design-tool-gate.test.sh); do make test suite="$t" >/dev/null 2>&1 || fail=1; done && [ $fail -eq 0 ] && echo SUITES-OK
   EXPECT: SUITES-OK
   EVIDENCE: MET exit=0 marker-found :: SUITES-OK
5. Judged by reading: no `git push` entered any Bash call; frontmatter and agent pins unchanged; no file outside FILE SCOPE (doc-sync handles CHANGELOG/SETTINGS afterwards, through its own gate).

## FILE SCOPE
skills/capitalize/SKILL.md · skills/client-handover/SKILL.md · agents/client-handover-writer.md · agents/release-executor.md
