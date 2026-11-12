# PLAN — manual-push-skills-c1 — REVISED r2 (3 lenses + correctness confirmation)
Contract: .claude/tasks/contracts/2026-10-07-manual-push-skills-c1-1304.md

## Context
`/close` STEP 5C runs `gitflow.sh finish chore <name>` then `git push origin develop`. Since BDR-095 (9da5d8d, 2026-09-22) `finish` already pushes develop itself (`_gitflow_merge_into` → `_gitflow_push_branch`, mode-aware since run A), so the explicit push has been redundant for two weeks; in manual mode push-guard (run B) would deny it, and a shell gate `[ "$mode" = auto ] && git push …` is denied as a whole by the text-only guard while `$mode` does not survive between Bash calls. Fix = remove the push text entirely and REPORT from facts read after finish. Skills can no longer read `gitflow.autopush` via `git config` (BDR-112) → the lib verb `push-mode` is the sanctioned reader. Invalid value: lib/hooks still push (fail-open until run D), so the wording must not claim "not pushed" — the ahead count tells the truth.

## Checklist
- [ ] lib/gitflow.sh — `gitflow_push_mode()` in the predicates section (after `gitflow_release_open`):
    ```
    # gitflow_push_mode → stdout auto | manual | invalid, rc 0 always. The ONE
    # reader skills may call: `git config … gitflow.*` is statically denied to
    # Claude (BDR-112). manual = key reads false; auto = true or unset; invalid =
    # anything else (unparseable value, git failure) — the raw value goes to
    # stderr so the caller can name it. Reads only. Ignores GITFLOW_NO_PUSH (a
    # test-repo switch, not a mode): a caller that pushes must not rely on this
    # verb alone — the lib's own push sites use _gitflow_push_off.
    gitflow_push_mode() {
      local val rc raw
      val=$(git config --bool gitflow.autopush 2>/dev/null); rc=$?
      case "$rc:$val" in
        0:false)    echo manual ;;
        0:true|1:*) echo auto ;;
        *) raw=$(git config gitflow.autopush 2>/dev/null)
           if [ -n "$raw" ]; then
             echo "gitflow.sh push-mode: gitflow.autopush='$raw' is not a boolean (git rc $rc)" >&2
           else
             echo "gitflow.sh push-mode: could not read gitflow.autopush (git rc $rc)" >&2
           fi
           echo invalid ;;
      esac
      return 0
    }
    ```
    CLI dispatcher: `push-mode)      gitflow_push_mode ;;` after `merged`; add `push-mode` to the usage string. `_gitflow_push_off` UNCHANGED (run D).
- [ ] lib/gitflow-test.sh — NEW block after T11, own repo (hooks on from init, irrelevant: config reads/writes only): `echo "T11b — push-mode verb (the sanctioned reader for skills, BDR-112)"`; `newrepo pm; echo a>a; bash "$HERE/gitflow.sh" init >/dev/null 2>&1`;
    `chk "cli push-mode default auto" '[ "$(bash "$HERE/gitflow.sh" push-mode)" = auto ]'`;
    `git config gitflow.autopush true` → `chk "cli push-mode true auto" …= auto`;
    `git config gitflow.autopush false` → `chk "cli push-mode manual" …= manual`;
    `git config gitflow.autopush flase` → `pm_out=$(bash "$HERE/gitflow.sh" push-mode 2>"$WORK/pm.err"); pm_rc=$?` (same line) → `chk "cli push-mode invalid, rc 0, value on stderr" "[ $pm_rc -eq 0 ] && [ \"$pm_out\" = invalid ] && grep -q flase \"$WORK/pm.err\""`;
    corrupt config: `printf '[gitflow\n' >> .git/config` → `pm2_out=$(bash "$HERE/gitflow.sh" push-mode 2>/dev/null); pm2_rc=$?` → `chk "cli push-mode corrupt config → invalid, rc 0" "[ $pm2_rc -eq 0 ] && [ \"$pm2_out\" = invalid ]"`;
    `chk "cli usage lists push-mode" 'grep -q push-mode <<<"$(bash "$HERE/gitflow.sh" nope 2>&1)"'`.
    Variables read in double-quoted assertions (no SC2034 suppression). Config writes live in the test FILE only.
- [ ] skills/capitalize/SKILL.md — STEP 5C (heading UNCHANGED; repo-wide grep shows no citer; the citers census does not cover skill headings). Body rewrite below the three fire-conditions:
    "Skip this step entirely (go to STEP 6, which prints the hold note) on `--no-push`, on a WORKING branch, or when STEP 5B returned rc 3.
    Otherwise, from the `chore/<name>` branch, THREE separate Bash calls, never combined. INVARIANT: no `git push` inside any Bash call of this skill (push-guard reads command text; the lib pushes develop itself in auto-push mode). The hints that tell the USER what to type (`! git push …`) are prose, kept on single lines.
    1. `bash "$HOME/.claude/lib/gitflow.sh" finish chore <name>` — merge → develop, delete branch, push develop in auto-push mode. rc≠0 → skip calls 2-3, go to STEP 6 with the `finish failed` line: rc 4 = conflict, develop mid-merge, `chore/<name>` kept, NOT merged; rc 1 = checkout failed, NOT merged; rc 5/2/6 come from the delete AFTER the merge: check `git merge-base --is-ancestor chore/<name> develop` and report `merged, branch not deleted (rc <n>)` when it holds, `NOT merged` otherwise. Never say "merged" without that check.
    2. `bash "$HOME/.claude/lib/gitflow.sh" push-mode` → `auto | manual | invalid` (stderr names an invalid value).
    3. `git rev-list --count origin/develop..develop 2>/dev/null || echo unknown` → `ahead` (0 = on origin; `unknown` = no origin/develop ref, e.g. no origin remote).
    Outcomes, evaluated IN THIS ORDER (all require finish rc 0):
    - push mode `invalid` → `merged to develop — gitflow.autopush=<value from stderr> is not a boolean: the lib and hooks still push on an invalid value until run D (origin/develop is <ahead> commit(s) behind, or unknown); fix the value by hand`.
    - `ahead` = 0 → `develop <short> pushed` (auto-push mode did it).
    - `ahead` = unknown → `merged to develop — not on origin (no origin/develop ref; no remote or never fetched)`; push mode manual → add `You: ! git push origin develop once a remote exists`.
    - `ahead` > 0, push mode `manual` → `merged to develop — manual push mode: not pushed. You: ! git push origin develop`.
    - `ahead` > 0, push mode `auto` → `merged to develop — push FAILED (see finish stderr); push manually`. Do NOT retry or reset the merge."
    Keep the three existing bullets' intent inside the list above (the first qualified as auto-push mode). Recap line ~358 `persisted :` values → `develop <short> pushed | merged, manual push mode: not pushed | merged, not on origin (no origin/develop) | merged, push FAILED | merged, gitflow.autopush invalid (<ahead> behind) | finish rc <n>, not merged | merged, branch not deleted (rc <n>) | on chore/<name>, not merged (--no-push)`.
    STEP 6 (lines ~366-368): `<mode>` stays the session label (`Context flushed` / `Session closed`); the conditions below say "push mode". On the `--no-push` path (and on any 5B-committed path where 5C did not run) read TWO facts, each its own call: `bash "$HOME/.claude/lib/gitflow.sh" push-mode` and `git rev-list --count origin/chore/<name>..chore/<name> 2>/dev/null || echo unknown` (`branch_ahead`). Lines (single-line bullets, as the existing ones):
    - auto-persisted (ahead 0) — unchanged.
    - `--no-push`, `branch_ahead` = 0 → `✅ <mode> + committed on chore/<name> — pushed to origin by the hooks (auto-push mode), NOT merged (--no-push). Merge when ready.`
    - `--no-push`, `branch_ahead` > 0 or unknown → `✅ <mode> + committed on chore/<name> — this disk only, not pushed (<push mode manual | no origin/chore ref>), NOT merged. You: ! git push -u origin chore/<name>; merge when ready.` With push mode `invalid`, append ` gitflow.autopush=<value> is not a boolean: fix it by hand`.
    - manual (merged, `ahead` > 0) → `✅ <mode> + merged to develop — manual push mode: not pushed. You: ! git push origin develop`.
    - not on origin (merged, `ahead` unknown) → `✅ <mode> + merged to develop — not on origin (no origin/develop ref).`
    - invalid (merged) → `⚠️ <mode> + merged to develop — gitflow.autopush=<value> is not a boolean; lib/hooks still push on it until run D (origin/develop <ahead> behind). Fix the value by hand.`
    - push failed — unchanged.
    - finish failed → `⚠️ <mode> + finish rc <n>: <stderr> — chore/<name> kept, NOT merged (or: merged, branch not deleted); resolve by hand.`
    argument-hint (line 13): `pushed to origin by the hooks` → `pushed to origin by the hooks in auto-push mode`. Rules line ~403: append ` — the lib pushes develop in auto-push mode only; manual mode merges and leaves the push to the user`.
- [ ] skills/close/SKILL.md — argument-hint (line 12): same `in auto-push mode` wording; line 31 `STEP 5C auto-persist: finish + push, BDR-068` → `STEP 5C auto-persist: finish (push rides it in auto-push mode), BDR-068`.
- [ ] lib/gitflow-aiguillage.md — lines 40-42: `(finish → develop + push)` → `(finish → develop; the lib pushes develop in auto-push mode only)`. One line.

## Edge cases
- INVARIANT: no `git push` inside any Bash CALL of capitalize/close (the user-facing `! git push …` hints are prose on single lines) → push-guard never fires on /close. The verifier judges it by reading; a negative grep would itself carry `git push` and be denied in manual mode (LRN-194 b).
- `origin/develop` ref absent (no origin, never fetched) → `unknown` → its own outcome ("not on origin"), never "push FAILED" (in auto mode without origin the lib is silently a no-op, lib/gitflow.sh:90).
- Invalid value: truth comes from `ahead`, not from the mode; wording never says "not pushed" without `ahead` > 0.
- The verb ignores GITFLOW_NO_PUSH by design (documented in its comment); 5C never runs in a test repo; C2 callers that push must gate on the verb AND respect push-guard (they will not contain `git push` text in manual mode anyway).
- Heading kept → no citer risk; BDR-100 census does not apply to skill headings (manual repo-wide grep done: none).

## Disposition
- honors BDR-068 (auto-persist: merge always, push rides finish in auto mode) and BDR-111/BDR-112 (verb = sanctioned reader; zero `git config` in skills; zero `git push` inside Bash calls).
- honors BDR-095 (truth from the remote state, never from intent: `ahead` count) and LRN-104 (every new output string lives in the skill text; the verb's outputs locked in T11b incl. stderr and rc).
- honors LRN-191 (`grep -q … <<<"$(…)"`), LRN-194 (fixtures in files), LRN-193 (fresh confirmation pass after this revision).
