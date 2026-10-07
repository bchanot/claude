# PLAN — manual-push-failclosed-d1 — REVISED r2 (3 lenses + correctness confirmation)
Contract: .claude/tasks/contracts/2026-10-07-manual-push-failclosed-d1-1522.md

## Context
Every lib/hook reader of `gitflow.autopush` uses `git config --bool --default true … = false`. `--default` only covers a MISSING key: an unparseable value makes git die with empty output, `[ "" = false ]` is false, and the push runs — a typo silently re-enables every push on a work machine. push-guard (run B) already fails closed; the lib verb `push-mode` (run C) already prints `invalid`. D1 makes the lib, the two emitted push hooks and unpushed-guard agree: unset/true → auto, false → manual, anything else → NO push AND one stderr line naming it (the terminal user keeps a signal: today git's own `fatal: bad boolean` is that signal, and D1 must not remove it silently). `~/.claude/lib` and `~/.claude/githooks` are symlinks into this checkout: lib edits are live machine-wide at once, so tests run against the SOURCED emitter before the installed copies are regenerated, and regeneration comes last.

## Checklist (in this order)
- [ ] lib/gitflow-test.sh FIRST — NEW isolated block after T18m (before T19): `echo "T18q — fail closed: unparseable gitflow.autopush → nothing pushes, named (BDR-114)"`; `newrepo badval; echo a>a; hookon; gitflow_init`; bare origin; `git push -q -u origin main develop`; `git config gitflow.autopush flase`.
    T18q1 `gitflow_start feature bad >/dev/null 2>"$WORK/q1.err"` → local branch exists AND `! git ls-remote --exit-code --heads origin feature/bad` AND `grep -q 'not a boolean' "$WORK/q1.err"` (the verb's stderr passes through `_gitflow_push_off`).
    T18q2 `echo b>b.txt; git add b.txt; git commit -q -m b 2>"$WORK/q2.err"` → `! git ls-remote --exit-code --heads origin feature/bad` AND `grep -q 'NOT pushed' "$WORK/q2.err"` (the hook names it; hooks ON via hookon — note: the installed `.githooks/` in the throwaway repo is written by `gitflow_init` from the SOURCED emitter, so this tests the new text before any regen).
    T18q3 `dev_before=$(git -C "$bare" rev-parse develop)`; `gitflow_finish >/dev/null 2>&1; q_rc=$?` → `[ $q_rc -eq 0 ] && [ "$(git -C "$bare" rev-parse develop)" = "$dev_before" ] && ! git rev-parse --verify -q refs/heads/feature/bad`.
    T18q4 positive control for the hook's `0:true` arm: `git config gitflow.autopush true; gitflow_start feature good; echo g>g.txt; git add g.txt; git commit -q -m g` → `[ "$(git rev-parse HEAD)" = "$(git -C "$bare" rev-parse feature/good)" ]` (tips equal: the post-commit hook pushed; `ls-remote` alone would pass from the start's push).
    T18q5 POSIX-clean emitted hook: `_gitflow_emit_push_hook post-commit > "$WORK/pc.sh"` (SOURCED function, never a relative lib path from a fixture cwd); `[ -s "$WORK/pc.sh" ] && grep -qF 'case "$rc:$v"' "$WORK/pc.sh"`; then `if command -v shellcheck >/dev/null 2>&1; then chk "T18q5 emitted hook is POSIX-clean" 'shellcheck -s sh "$WORK/pc.sh"'; else ok "T18q5 skipped (no shellcheck)"; fi` (first shellcheck use in a hermetic suite → guarded).
    Variables read in double-quoted assertions (no SC2034 suppression). Config writes live in the test FILE. No T18q0 (duplicate of T11b).
- [ ] lib/gitflow.sh — `_gitflow_push_off`:
    ```
    # rc 0 when pushing is off: GITFLOW_NO_PUSH=1 (throwaway test repos), or
    # gitflow.autopush not readable as `true`/unset — manual-push mode (false,
    # human-set) AND fail closed on an unparseable value or a config read
    # failure (BDR-114). The verb's stderr passes through: it names an invalid
    # value and is silent for auto/manual. Single reader for the lib's push sites.
    _gitflow_push_off() {
      [ "${GITFLOW_NO_PUSH:-0}" = 1 ] && return 0
      [ "$(gitflow_push_mode)" != auto ]
    }
    ```
    Comments: line ~195 ("manual mode never deletes origin/<br>") → "push off (manual mode or invalid value) never deletes origin/<br>"; line ~206 ("skipped under GITFLOW_NO_PUSH=1, gitflow.autopush=false or no origin") → "skipped when push is off (see _gitflow_push_off) or no origin". `_gitflow_note_remote_left`'s message UNCHANGED ("manual push mode" is the doctrine name for the off state; skills/gitflow/SKILL.md:114 quotes it).
- [ ] lib/gitflow.sh — `_gitflow_emit_push_hook` heredoc: replace the two opt-out lines (`# Per-repo opt-out (no push rights on a foreign clone): git config gitflow.autopush false` / `[ "$(git config --bool --default true gitflow.autopush)" = false ] && exit 0`) with:
    ```
    # Manual-push mode (human-set): git config gitflow.autopush false. Fail closed:
    # an unparseable value or a config read failure also means "no push", named.
    # Mirrors gitflow_push_mode (lib/gitflow.sh); arms pinned by T18b/T18h/T18q2/T18q4.
    v=$(git config --bool gitflow.autopush 2>/dev/null); rc=$?
    case "$rc:$v" in
      0:true|1:*) ;;
      0:false) exit 0 ;;
      *) echo "gitflow $hook: gitflow.autopush unreadable (git rc $rc) — NOT pushed, treated as manual push mode; fix the value by hand" >&2; exit 0 ;;
    esac
    ```
    POSIX sh only. pre-commit and reference-transaction emitters untouched (byte for byte).
- [ ] hooks/unpushed-guard.sh — at the TOP (before `payload=$(cat …)` and before `cd "$cwd"`): `_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)/gitflow.sh"`. Replace lines 26-29 (the four lines `raw=`, `manual=0; invalid=0`, the `manual=` test, the `invalid=` test) AND lines 76-78 (the old invalid clause) — no `invalid` variable survives (SC2034 otherwise) — with:
    ```
    out=$(bash "$_lib" push-mode 2>&1); mode=${out##*$'\n'}; mode_err=${out%"$mode"}
    manual=0; [ "$mode" = auto ] || manual=1          # fail closed: anything but auto
    ```
    (the verb writes its stderr line BEFORE its stdout word, so the last line is the mode; no temp file, no delete). Invalid/unreadable clause (SessionStart only): `case "$mode" in invalid) msg="${msg:+$msg; }${mode_err#gitflow.sh push-mode: } — treated as manual push mode (nothing pushes); fix the value by hand" ;; manual|auto) ;; *) msg="${msg:+$msg; }push mode unreadable (lib verb printed '${mode:-nothing}') — treated as manual push mode" ;; esac` (strip the trailing newline of `mode_err`). Stop + manual=1 → silent (unchanged early exit). Header comment: "+ an unparseable value is treated as manual (fail closed, BDR-114); the mode comes from the lib verb". Functions ≤25 logic lines.
- [ ] lib/tests/unpushed-guard.test.sh — T14 rewrite (same fixture, key `flase`, one unpushed commit): T14-invalid-named → SessionStart contains `not a boolean`; T14-invalid-prefix → contains `ℹ manual push mode:`; T14-invalid-treated → contains `treated as manual`; T14-invalid-no-warn → NOT `unpushed work`; T14-invalid-stop-silent → Stop → `silent`. T15 unchanged.
- [ ] regenerate in the SAME step as the emitter edit (a SessionStart `reconcile-hooks` between the two would run `install-hook` and write a local hooks-path entry), files only, with NO config read or write of any kind: `bash lib/gitflow.sh emit-hook post-commit > .githooks/post-commit`, `… emit-hook post-merge > .githooks/post-merge`, `… emit-hook post-commit > githooks/post-commit`, `… emit-hook post-merge > githooks/post-merge` (writing into the existing files keeps mode 755). NOT `install-hook` (local config write) and NOT `global-hooks` (writes the GLOBAL config when `~/.gitconfig` lacks the hooksPath — which is the case right now: the user's gitconfig was overwritten by a dotfiles installer at 15:39 and must be restored by the user first). Evidence: `md5 -q .git/config` identical before/after; `~/.gitconfig` untouched (the executor never reads it); `git diff --stat` shows only the four hook files. If a command is refused, STOP and report; never hand-edit generated hooks.
- [ ] then run `make test suite=lib/gitflow-test.sh` again: T19a–e green = installed == emitted.

## Edge cases
- `GITFLOW_NO_PUSH=1` still short-circuits before any mode read (T18o).
- Terminal user with a typo: every commit prints the hook's one-line stderr and pushes nothing; `gitflow start`/`finish` print the verb's line. Inside Claude: unpushed-guard names it at SessionStart; the banner shows the lock line after D2.
- Lib path for the guard resolved before any `cd` (relative invocation safe).
- Onboarded projects keep their committed fail-open `.githooks/` until a session-start `reconcile-hooks` runs there and the user commits the refresh: documented at doc-sync (CHANGELOG scope note), not solvable from this repo.
- Skills/docs still carrying "until run D" (capitalize :346/:379, CHANGELOG, SETTINGS) become stale the moment D1 lands: D3 + doc-sync follow on the same branch before merge.
- Hooks in throwaway test repos are written by `gitflow_init` from the sourced emitter → T18q runs against the NEW hook text before regeneration.

## Disposition
- honors BDR-111/BDR-112 (fail-closed semantics chosen by the user, now every reader), BDR-095 (push every commit — unchanged in auto mode; T18b/T18q4 positive controls; a stopped push is always NAMED on stderr), LRN-114 (edit the generator → regenerate installed copies through the lib → T19 drift gate), LRN-113 (grep `--default true gitflow.autopush` across lib/ hooks/ githooks/ .githooks/ ends at zero after D1+D2), LRN-191, LRN-194, LRN-196 (read git's rc), BDR-087 (Stop stays message-only), LRN-193 (fresh confirmation after this revision).
- New BDR-114 proposed at capitalize: "every autopush reader fails closed and names the value; unset/true auto, false manual, else no push".
