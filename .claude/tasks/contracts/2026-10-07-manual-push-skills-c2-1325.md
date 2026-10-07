# CONTRACT — manual-push-skills-c2 (run C2 of manual-push mode)
- date: 2026-10-07 | flow: feat | branch: feature/manual-push-mode (after C1: lib verb `gitflow.sh push-mode`)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (fr): "ok enchaine sur le run C"
Run C as scoped in `.claude/tasks/TODO.md` "manual-push-mode": skills that push on their own, gate on the mode through the lib verb `bash ~/.claude/lib/gitflow.sh push-mode` (auto|manual|invalid): client-handover SKILL:48 + agents/client-handover-writer.md (STEP 5 push GO), release-candidate STEP 6 ("main and develop are already on origin", tag push), tour rule ("pushed by the gitflow hooks … fixed with a plain git push -u"). User's framing (2026-10-06): "tout faire pareil, juste rien push seul … seulement manuel".

## CLARIFICATIONS
Q: scope / A: C2 = the four remaining sites + the one-line claim in agents/release-executor.md ("ride the lib's hook pushes"). 5 files. Prose only, no shell code change; the verb is read in its own Bash call and the decision is prose. [orchestrator — scope]
Q: invalid mode in these flows / A: push-guard denies Claude's push on an invalid value (fail closed, run B), while the lib/hooks still push on it (fail-open until run D): the skills treat `invalid` like `manual` for what CLAUDE does (no push attempt, the user runs the command), and name the value from the verb's stderr. [orchestrator]
Q: release in manual mode / A: no push at all by Claude: main, develop and the tag are left local; the skill prints ONE user command `! git push origin main develop v<X.Y.Z>` and stops (no AskUserQuestion, nothing to gate). The `hold` wording for auto mode stays. [orchestrator — visible wording derived from the user's rule]
Q: challenge r1 — truth source / A: every "on origin" / "not pushed" statement in these flows comes from `git rev-list --count origin/<br>..<br>` (or `<br> --not --remotes` for the tour), read in its own Bash call; the verb only words the reason. Invalid: the verb's stderr is quoted verbatim, never a templated value. [orchestrator]
Q: challenge r1 — client-handover push GO question / A: removed (it gated nothing: the hooks had already pushed in auto mode; push-guard denies it in manual mode). The pipeline never runs `git push`; the user is told to push BEFORE the deploy pause, and the deploy brief says "after your push". `Push:` line added to both end reports. [orchestrator — visible wording derived from the user's rule]
Q: challenge r1 — release command / A: `! git push --atomic origin main develop v<X.Y.Z>`; also used in auto mode when a lib push did not reach origin. Tag-push gate kept for auto mode with both counts 0. `hold` wording notes `--follow-tags` publishes the held tag on the next push of main. [orchestrator]
Q: confirmation r2 / A: PUSH STATE READ is one reusable paragraph, re-run at the top of STEP 6, after "Deployed", and right before every `Push:` line (states: on origin / nothing to push / uncommitted (gitflow fallback) / not on origin, no origin remote / pending + reason); the red-flag box is kept and reworded, not deleted; anything other than `auto` from the verb is treated like manual; the tour uses the branch name `gitflow start` returned (suffix-aware) and reads the fact after the report commit; multi-line Edit anchors given to the executor. [orchestrator]
Q: tour `push FAILED` residual / A: in every mode the USER fixes it (BDR-095: a rejected push warns, the user decides); the rule no longer reads as Claude retrying. [orchestrator]

## ACCEPTANCE CRITERIA
1. agents/client-handover-writer.md: the GO question and the push block are gone; a reusable PUSH STATE READ (branch, origin check, `git rev-list --count origin/<br>..<br>`, the verb when ahead ≠ 0) is defined in STEP 5 and re-run at the top of STEP 6, after "Deployed", and before every `Push:` line; `pending` tells the user `! git push -u origin <br>` BEFORE STEP 6 and the deploy brief opens with it and says "after your push"; `Push:` line (column 0) in the PIPELINE STOPPED template and a `- Push:` bullet in the 9.7 report; the red-flag box is kept and says the pipeline never pushes. No `git config` read.
   CHECK: grep -q 'gitflow.sh" push-mode' agents/client-handover-writer.md && grep -q 'rev-list --count origin/<br>..<br>' agents/client-handover-writer.md && grep -q 'First push:' agents/client-handover-writer.md && [ "$(grep -c '^Push: ' agents/client-handover-writer.md)" -ge 1 ] && grep -q 'after your push' agents/client-handover-writer.md && grep -q 'PUSH STATE READ' agents/client-handover-writer.md && grep -q 'Red flag' agents/client-handover-writer.md && ! grep -q 'git config.*gitflow' agents/client-handover-writer.md && ! grep -q 'Push to origin now' agents/client-handover-writer.md && echo HANDOVER-AGENT-OK
   EXPECT: HANDOVER-AGENT-OK
   EVIDENCE: MET exit=0 marker-found :: HANDOVER-AGENT-OK
2. skills/client-handover/SKILL.md step 4 says the hooks push in auto-push mode and that otherwise the agent tells the user to push BEFORE the deploy pause.
   CHECK: grep -q 'auto-push mode' skills/client-handover/SKILL.md && grep -q 'manual push mode' skills/client-handover/SKILL.md && grep -q 'BEFORE the deploy pause' skills/client-handover/SKILL.md && echo HANDOVER-SKILL-OK
   EXPECT: HANDOVER-SKILL-OK
   EVIDENCE: MET exit=0 marker-found :: HANDOVER-SKILL-OK
3. skills/release-candidate/SKILL.md STEP 6: reads two ahead counts + the verb (separate calls); manual/invalid or any count ≠ 0 → prints `! git push --atomic origin main develop v<X.Y.Z>` and stops (no question; invalid quotes the verb's stderr); auto with both counts 0 → the existing tag-push gate; `hold` notes `--follow-tags`. Overview and common-mistakes qualified. agents/release-executor.md: both push claims (step 2 and the forbidden-span note) say "in auto-push mode".
   CHECK: grep -q 'gitflow.sh" push-mode' skills/release-candidate/SKILL.md && grep -q -- '--atomic origin main develop v' skills/release-candidate/SKILL.md && grep -q 'rev-list --count origin/main..main' skills/release-candidate/SKILL.md && grep -q 'follow-tags' skills/release-candidate/SKILL.md && [ "$(grep -c 'auto-push mode' agents/release-executor.md)" -ge 2 ] && echo RELEASE-OK
   EXPECT: RELEASE-OK
   EVIDENCE: MET exit=0 marker-found :: RELEASE-OK
4. skills/tour/SKILL.md: the rule is mode-agnostic (hooks push in auto-push mode; otherwise the USER pushes with `! git -C <abs project> push -u origin <branch>`; the tour never pushes or retries); STEP 3 item 5 reads one `git -C <abs project> rev-list --count <branch> --not --remotes` fact per project after the report commit, with `<branch>` = the name gitflow start returned (suffix-aware); the summary row carries `on origin` / `local only → …`.
   CHECK: grep -q 'auto-push mode' skills/tour/SKILL.md && grep -q 'manual push mode' skills/tour/SKILL.md && grep -q 'git -C <abs project> push -u origin' skills/tour/SKILL.md && grep -q 'local only' skills/tour/SKILL.md && grep -q -- '--not --remotes' skills/tour/SKILL.md && echo TOUR-OK
   EXPECT: TOUR-OK
   EVIDENCE: MET exit=0 marker-found :: TOUR-OK
5. Doctrine citers census green; floor guard clean; every hermetic suite green except the declared environmental red.
   CHECK: make test suite=lib/tests/doctrine-citers.test.sh >/dev/null 2>&1 && bash ~/.claude/lib/floor-guard.sh develop -- skills/client-handover/SKILL.md agents/client-handover-writer.md skills/release-candidate/SKILL.md skills/tour/SKILL.md agents/release-executor.md >/dev/null 2>&1 && fail=0 && for t in $(ls lib/tests/*.test.sh lib/seo-data/*.test.sh lib/gitflow-test.sh lib/tests/run-*.sh | grep -v design-tool-gate.test.sh); do make test suite="$t" >/dev/null 2>&1 || fail=1; done && [ $fail -eq 0 ] && echo SUITES-OK
   EXPECT: SUITES-OK
   EVIDENCE: MET exit=0 marker-found :: SUITES-OK
6. Judged by reading: the only `git push` left inside a Bash block in the five files is release-candidate's tag push, reached only in auto mode with both counts 0 on explicit go; every other push is a `! git …` user hint in prose (complete: `-u`, `--atomic`, `-C <abs project>` where needed); no "on origin" / "not pushed" claim derives from the mode word alone; no file outside FILE SCOPE changes; frontmatter, agent pins and headings unchanged (release-candidate description + STEP 6 heading accepted residuals).

## FILE SCOPE
skills/client-handover/SKILL.md · agents/client-handover-writer.md · skills/release-candidate/SKILL.md · agents/release-executor.md · skills/tour/SKILL.md
