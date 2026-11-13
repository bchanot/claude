# CONTRACT — npm-global-deny (hotfix)
- date: 2026-11-13 | flow: hotfix | branch: bugfix/npm-global-deny (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
settings.json npm -g (user decision 2026-11-12, block E; was "user hand edit pending", user confirmed at start: edit on a branch, classifier test with `npm install -g --dry-run cowsay`): remove the four `permissions.deny` entries `Bash(npm install -g *)`, `Bash(npm i -g *)`, `Bash(npm install --global *)`, `Bash(npm i --global *)` (settings.json:143-146) so the autoMode soft_deny "Global npm installs" entry (settings.json:600) decides instead of a hard deny. The push-guard T42 non-weakening lock (lib/tests/push-guard.test.sh ~:331-336, `removed-ok` heredoc) must justify them: replace the two dead rows (`Bash(docker run * -v /:*)`, `Bash(git push * :*)`, absent from the 3.0.0 release so no longer needed) with the four npm rows under a `# soft_deny "Global npm installs" decides (user 2026-11-12)` comment; `removed_ok_until` stays 3.0.0. 2 files, no logic.

## ACCEPTANCE CRITERIA
1. No npm -g deny entry left; settings.json valid JSON.
   CHECK: jq -r '.permissions.deny[]' settings.json | grep -c '^Bash(npm' ; true
   EXPECT: 0
   EVIDENCE: PENDING
2. push-guard suite green (T41/T42/T42e).
   CHECK: make test suite=lib/tests/push-guard.test.sh 2>&1 | grep -E "T42 base:|FAIL=0" | tail -1
   EXPECT: FAIL=0
   EVIDENCE: PENDING
3. Live: `npm install -g --dry-run cowsay` no longer hits a static deny; the classifier decides (outcome recorded in the journal).

## FILE SCOPE
settings.json, lib/tests/push-guard.test.sh. templates/settings/SETTINGS.md:115 ("are in permissions.deny") → STEP 5 doc sync.

## CLARIFICATIONS
- [gated 2026-11-13, orchestrator: the "stays 3.0.0" pin was the orchestrator's own wording, not the user's; two lenses MAJOR] `removed_ok_until=3.1.0` (the release that ships this removal, BDR-145); TODO "after 3.0.0 … empty the removed-ok list" reworded to "first bump past 3.1.0".
- [gated] T42d retargeted: simulate removing the four npm entries (comment updated), so it models this edit instead of the six already-gone entries.
- [gated] Live test expected verdict, written BEFORE running: `npm install -g --dry-run cowsay` is no longer refused by a static deny; the classifier applies soft_deny "Global npm installs" (held until the package is named this turn with the vetting statement) — any classifier outcome other than a static-rule refusal proves the edit; a static refusal in this session → re-run in a fresh session before concluding (settings snapshot at session start).
- [gated] Live window: settings.json is symlinked into ~/.claude; the change is live machine-wide from the executor's write; rollback = checkout develop's settings.json.
