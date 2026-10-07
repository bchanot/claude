# CONTRACT — manual-push-skills-c1 (run C1 of manual-push mode)
- date: 2026-10-07 | flow: feat | branch: feature/manual-push-mode (runs A 2fc8830, B a2ac018+6468eda landed; C2 = client-handover ×2, release-candidate, tour follows)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (fr): "ok enchaine sur le run C"
Run C as scoped in `.claude/tasks/TODO.md` "manual-push-mode": skills that push on their own, gate on the mode through a NEW lib verb `bash ~/.claude/lib/gitflow.sh push-mode` (prints auto|manual|invalid; the bare `git config … gitflow.autopush` read is denied for Claude after run B): capitalize STEP 5C (`git push origin develop`), client-handover SKILL:48 + agents/client-handover-writer.md:586, release-candidate:96 + tour:273 "already on origin" claims. User's framing (2026-10-06): "Il faut tout faire pareil, juste rien push seul. Mais faire les branches localement, faire les commits localement etc. Juste il faut pas push. seulement manuel".

## CLARIFICATIONS
Q: scope split / A: C1 (this contract) = lib verb + its test + `/capitalize` STEP 5C + the `--no-push` hints in capitalize and close; C2 = client-handover skill + agent, release-candidate STEP 6, tour rule. 8 files > the /feat cap of 5. [orchestrator — scope, surfaced]
Q: does `/close` still merge the memory chore branch into develop in manual mode? / A: yes — local merges are part of "tout faire pareil"; only the push is withheld, and the handoff line says so. [orchestrator, from the user's own words]
Q: `invalid` mode in STEP 5C / A: challenge r1 — the lib and hooks still PUSH on an invalid value (fail-open until run D), so the handoff never claims "not pushed" from the mode alone: it reports the real `origin/develop..develop` count and names the value from the verb's stderr. [orchestrator, revised]
Q: challenge r1 — explicit `git push origin develop` in STEP 5C / A: removed. `finish` has pushed develop itself since BDR-095 (mode-aware since run A); a shell gate containing `git push` would be denied whole by push-guard in manual mode and `$mode` does not persist across Bash calls. 5C = finish, then two read-only facts (verb, ahead count), then prose. [orchestrator — internal]
Q: challenge r1 — scope / A: `lib/gitflow-aiguillage.md` (one line, "finish → develop + push") joins FILE SCOPE (5 files). [orchestrator — scope]
Q: `_gitflow_push_off` refactor onto the new verb / A: no — unchanged this run (run D owns every reader's fail-closed semantics). [orchestrator — internal]

## ACCEPTANCE CRITERIA
1. `bash ~/.claude/lib/gitflow.sh push-mode` prints exactly one word on stdout: `manual` when `git config --bool gitflow.autopush` returns false, `auto` when it returns true or the key is unset (rc 1), `invalid` for any other rc (unparseable value, corrupt config, git failure) with the raw value named on stderr; rc 0 in all cases; the usage line lists the verb; the verb never writes config. Locked by the new T11b block.
   CHECK: out=$(make test suite=lib/gitflow-test.sh 2>&1); printf '%s' "$out" | grep -q '  FAIL ' && exit 1; for t in "cli push-mode default auto" "cli push-mode true auto" "cli push-mode manual" "cli push-mode invalid, rc 0, value on stderr" "cli push-mode corrupt config" "cli usage lists push-mode"; do grep -qF "ok   $t" <<<"$out" || exit 1; done; echo PUSH-MODE-OK
   EXPECT: PUSH-MODE-OK
   EVIDENCE: MET exit=0 marker-found :: PUSH-MODE-OK
2. `skills/capitalize/SKILL.md` STEP 5C contains NO `git push` text and no `git config` read: three separate calls (finish; `gitflow.sh push-mode`; `git rev-list --count origin/develop..develop`), a finish failure outcome (rc≠0 → kept, NOT merged, no "merged" wording), and outcomes keyed on the ahead count + mode (`develop pushed` / `manual push mode: not pushed, you: ! git push origin develop` / `push FAILED` / invalid value named from stderr with the real ahead count). STEP 6 reads the mode on every 5B-committed path and the `--no-push` closing line has a manual-mode variant ("this disk only, not pushed"); the recap carries the new values. The `--no-push` argument-hint in capitalize AND close says "in auto-push mode"; `lib/gitflow-aiguillage.md` no longer says "+ push" unconditionally.
   CHECK: grep -q 'gitflow.sh" push-mode' skills/capitalize/SKILL.md && grep -q 'manual push mode: not pushed' skills/capitalize/SKILL.md && grep -q 'rev-list --count origin/develop..develop' skills/capitalize/SKILL.md && grep -q 'this disk only' skills/capitalize/SKILL.md && ! grep -q 'git config.*gitflow' skills/capitalize/SKILL.md skills/close/SKILL.md && grep -q 'auto-push mode' skills/capitalize/SKILL.md && grep -q 'auto-push mode' skills/close/SKILL.md && grep -q 'auto-push mode' lib/gitflow-aiguillage.md && echo CAPITALIZE-OK
   EXPECT: CAPITALIZE-OK
   EVIDENCE: MET exit=0 marker-found :: CAPITALIZE-OK
3. Doctrine citers census green (skill prose changed).
   CHECK: make test suite=lib/tests/doctrine-citers.test.sh >/dev/null 2>&1 && echo CITERS-OK
   EXPECT: CITERS-OK
   EVIDENCE: MET exit=0 marker-found :: CITERS-OK
4. shellcheck clean on lib/gitflow.sh and lib/gitflow-test.sh; no `# shellcheck disable` added; floor guard clean.
   CHECK: shellcheck lib/gitflow.sh lib/gitflow-test.sh && [ "$(git diff -- lib/gitflow.sh lib/gitflow-test.sh | grep -c '^+.*shellcheck disable')" -eq 0 ] && echo SHELLCHECK-OK
   EXPECT: SHELLCHECK-OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK-OK
5. Every hermetic suite green except the declared environmental red `lib/tests/design-tool-gate.test.sh`.
   CHECK: fail=0; for t in $(ls lib/tests/*.test.sh lib/seo-data/*.test.sh lib/gitflow-test.sh lib/tests/run-*.sh | grep -v design-tool-gate.test.sh); do make test suite="$t" >/dev/null 2>&1 || { fail=1; echo "RED $t"; }; done; [ $fail -eq 0 ] && echo SUITES-OK
   EXPECT: SUITES-OK
   EVIDENCE: MET exit=0 marker-found :: SUITES-OK
6. No behaviour change elsewhere in lib/gitflow.sh (`_gitflow_push_off`, hooks emitters, start/finish/delete untouched; T18/T19/T22/T24 green — covered by criterion 1's FAIL grep); no edits outside FILE SCOPE; the verb never writes config. INVARIANT judged by reading (a negative grep would itself carry the denied text): no `git push` inside any Bash call in skills/capitalize/SKILL.md or skills/close/SKILL.md — the `! git push …` user hints are prose on single lines; every 5C outcome (invalid first, ahead 0, unknown, >0 manual, >0 auto; finish rc 1/4 vs 5/2/6) has a STEP 6 line and a recap value.

## FILE SCOPE
lib/gitflow.sh · lib/gitflow-test.sh · skills/capitalize/SKILL.md · skills/close/SKILL.md · lib/gitflow-aiguillage.md
