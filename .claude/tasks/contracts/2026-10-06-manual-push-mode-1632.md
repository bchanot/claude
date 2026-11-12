# CONTRACT — manual-push-mode
- date: 2026-10-06 | flow: feat | branch: feature/manual-push-mode (run A of 2; run B = push-guard hook + banner)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (fr): "est-ce qu'on a un moyen de regler le flow automatique de git. Activer / desactiver le fait que ca pousse tout seul, que ca ne merge pas tout seul etc. Q`'il y ai forcement la demande ou l'authorisation humaine pour cela ? Il faut pouvoir le toggle on ou toggle off"
User (fr): "ok donc ou sera la cle gitflow.mode ? Pour expliaquer, c'est pour pouvoir utiliser la config au taff. Il faut tout faire pareil, juste rien push seul. Mais faire les branches locale,ment, faire les commits localements etc. Juste il faut pas push. seulement manuel"
/feat args: Manual-push mode via the existing `gitflow.autopush` git-config key (no new key). Scope: (1) lib/gitflow.sh `_gitflow_push_branch` must honour `gitflow.autopush=false` like the hooks and `_gitflow_delete_remote` do (today `start`/`finish` push regardless, bug); (2) guard-bash: when `git config --bool --default true gitflow.autopush` is false in the cwd repo, deny any `git push` from Claude with a message pointing to `! git push` (human runs it); (3) hooks/unpushed-guard.sh: in manual mode, SessionStart emits "push manuel : N commit(s) à pousser" info only, Stop emits nothing; (4) hooks/session-start.sh banner shows push mode (auto/manual); (5) CLAUDE.global.md: one line in the gitflow section, autopush=false → unpushed work is expected, never push unless the user asks; (6) tests updated (guard-bash.test.sh, unpushed-guard.test.sh, gitflow-test.sh). User decisions already taken: mechanical block of git push (chosen), guard info at SessionStart only (chosen).

## CLARIFICATIONS
Q: Mechanical block of `git push` when autopush=false? / A: yes, block (user, pre-flow) [gated 2026-10-06]
Q: unpushed-guard behaviour in manual mode? / A: info at SessionStart only, silent at Stop (user, pre-flow) [gated 2026-10-06]
Q: scope split — request spans ~10 files (> /feat max 5) / A: run A (this contract) = items 1, 3, 5 + their tests; run B = items 2, 4 as `hooks/push-guard.sh` + test + settings.json wiring + banner. `hooks/guard-bash.sh` does not exist (BLK-022), so item 2 lands in a new dedicated hook, and `guard-bash.test.sh` (spec of an absent hook) is left untouched. [gated 2026-10-06, orchestrator — scope class, surfaced to user in pass B]
Q: manual-mode SessionStart message language / A: English, consistent with the hook family. Exact line: `ℹ manual push mode: <N> commit(s) on '<branch>' to push by hand (git push)`; no-upstream variant: `ℹ manual push mode: '<branch>' has no upstream (<N> commit(s) on this disk only), push by hand: git push -u origin <branch>`; the existing `; <d> uncommitted change(s) in <cwd>` clause follows when the tree is dirty. [gated 2026-10-06]
Q: run B hook name / A: `hooks/push-guard.sh` + `lib/tests/push-guard.test.sh` [gated 2026-10-06]
Q: challenge r1 — skills push on their own (`skills/capitalize/SKILL.md:338` `git push origin develop` after the BDR-068 auto-finish; `skills/client-handover/SKILL.md:48` + `agents/client-handover-writer.md:586` `git push`; `skills/release-candidate/SKILL.md:96` and `skills/tour/SKILL.md:273` claim the branch is already on origin) and `settings.json` environment prose (lines ~480, ~499) says unpushed = defect / A: out of run A's 5-file scope. Run B (settings.json: hook wiring + widen the `gitflow.*` deny to `git config * gitflow.*`, `git -c gitflow.*`, `GIT_CONFIG_COUNT=*` + prose) and run C (the 5 skill/agent files: gate each push on `git config --bool --default true gitflow.autopush`, report `manual push mode: <ref> not pushed`). DEPLOYMENT ORDER: `gitflow.autopush false` is not to be set on the work machine before B and C are merged. [gated 2026-10-06, orchestrator — scope class, surfaced to the user]
Q: challenge r1 — manual-mode count scope / A: all local branches (`--branches --not --remotes`), listing the ahead branches; the gated sentence shape stays (`ℹ manual push mode: <n> commit(s) not on origin (<b1>, <b2>), push by hand: git push -u origin <branch>`). Auto mode unchanged. [gated 2026-10-06, orchestrator — refinement of the chosen wording, surfaced to the user]

## ACCEPTANCE CRITERIA
1. `_gitflow_push_branch` returns without pushing when `gitflow.autopush` is false: `gitflow start` under autopush=false creates the branch locally and origin has no copy; `gitflow finish` under autopush=false merges locally and origin's develop tip is unchanged. A branch whose upstream lags (pushed once by hand, then committed to) is still deleted by `finish` (rc 0): `--unset-upstream` before `-d` (LRN-161). Skipped remote delete says `left in place`. A base that cannot fast-forward from origin warns `behind origin/<base>`; offline stays silent. Locked by the new isolated gitflow-test block T18i–T18n.
   CHECK: out=$(make test suite=lib/gitflow-test.sh 2>&1); printf '%s' "$out" | grep -q '  FAIL ' && exit 1; for t in T18m0 T18i T18j T18k T18o T18n T18l; do printf '%s' "$out" | grep -q "ok   $t" || exit 1; done; echo GITFLOW-MANUAL-OK
   EXPECT: GITFLOW-MANUAL-OK
   EVIDENCE: MET exit=0 marker-found :: GITFLOW-MANUAL-OK
2. Auto mode unchanged: existing T18a–T18h, T24a–T24f and the T19 installed==emitted drift gate stay green (no hook emitter touched).
   CHECK: out=$(make test suite=lib/gitflow-test.sh 2>&1); printf '%s' "$out" | grep -q '  FAIL ' && exit 1; for t in T18a T18b T18c T18h T18f T19a T19b T19c T22i T22j T24b T24f; do printf '%s' "$out" | grep -q "ok   $t" || exit 1; done; echo GITFLOW-AUTO-OK
   EXPECT: GITFLOW-AUTO-OK
   EVIDENCE: MET exit=0 marker-found :: GITFLOW-AUTO-OK
3. `hooks/unpushed-guard.sh` in manual mode (`gitflow.autopush=false` in the cwd repo): Stop emits nothing even with unpushed commits; SessionStart emits the manual-mode info line (`ℹ manual push mode: <n> commit(s) not on origin (<branches>), push by hand: …`) counting every local branch, silent at n=0 with a clean tree, plus the existing uncommitted-changes clause; an invalid `gitflow.autopush` value is named at SessionStart and treated as auto; no "⚠ unpushed work" wording in manual mode. Auto mode output unchanged (T1–T9). Locked by new test cases T10–T16.
   CHECK: out=$(make test suite=lib/tests/unpushed-guard.test.sh 2>&1); printf '%s' "$out" | grep -q '^FAIL' && exit 1; printf '%s' "$out" | grep -qE 'PASS=(1[6-9]|[2-9][0-9]) FAIL=0' && echo GUARD-OK
   EXPECT: GUARD-OK
   EVIDENCE: MET exit=0 marker-found :: GUARD-OK
4. `CLAUDE.global.md` gitflow section gains one statement: `gitflow.autopush false` = manual-push mode, unpushed work is expected there, Claude never pushes unless the user asks; the "ahead of its upstream is a defect" sentence is scoped to auto mode. File stays within the 320-line density budget.
   CHECK: grep -q 'autopush false' CLAUDE.global.md && grep -qi 'manual' CLAUDE.global.md && [ "$(wc -l < CLAUDE.global.md)" -le 320 ] && echo DOCTRINE-OK
   EXPECT: DOCTRINE-OK
   EVIDENCE: MET exit=0 marker-found :: DOCTRINE-OK
5. shellcheck clean on the two touched scripts.
   CHECK: shellcheck lib/gitflow.sh hooks/unpushed-guard.sh && echo SHELLCHECK-OK
   EXPECT: SHELLCHECK-OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK-OK
6. Full hermetic suite green.
   CHECK: make test >/dev/null 2>&1 && echo SUITE-GREEN
   EXPECT: SUITE-GREEN
   EVIDENCE: NOT-MET exit=2 (nonzero) :: 
7. No new git-config key, no new env var, no change to `GITFLOW_NO_PUSH` semantics, no edit to hook emitters (`_gitflow_emit_*`) or to `githooks/`/`.githooks/`.
8. shellcheck stays clean on `lib/gitflow-test.sh` and `lib/tests/unpushed-guard.test.sh` too (Health Stack `shellcheck lib/*.sh`).
   CHECK: shellcheck lib/gitflow-test.sh lib/tests/unpushed-guard.test.sh && echo SHELLCHECK-TESTS-OK
   EXPECT: SHELLCHECK-TESTS-OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK-TESTS-OK

## FILE SCOPE
lib/gitflow.sh · hooks/unpushed-guard.sh · CLAUDE.global.md · lib/gitflow-test.sh · lib/tests/unpushed-guard.test.sh
