# CAPITALIZE-COMMIT — couple the memory commit to the dev flow

Inline snippet. Include at the END of any dev flow's CAPITALIZE step, AFTER the
approved registry / journal / TODO entries are written. It commits ONLY the
memory, surgically, so the flow never leaves an uncommitted `.claude/memory`
behind and never embarks dangling code.

This is the TAIL of capitalize, not a replacement: the SCAN + APPROVAL GATE that
decide WHAT to write are unchanged and run before this snippet. Only the COMMIT
of the already-approved entries is automated here.

## WHEN TO RUN

At the capitalize step, once the approved entries are written to
`.claude/memory/*` (and any `.claude/tasks/TODO.md` reconcile is done), with the
code already committed.

- Inline-commit flows (feat / hotfix / bugfix / commit-change): run it right
  after writing the entries, on the current branch.
- Orchestrators that integrate via `superpowers:finishing-a-development-branch`
  (ship-feature / init-project): run it BEFORE the FINISH step — otherwise the
  memory commit strands outside the merge/PR. See ORDERING.

This snippet commits whatever is PENDING under `.claude/memory` + `.claude/tasks`;
it does NOT decide content. A flow whose gate wrote only a journal line yields a
`chore(memory): journal — …` commit (one memory commit per flow — Frame 2 / F3).
If a flow should stay fully silent on a trivial run, that is the FLOW's gate
policy (e.g. hotfix skipping the journal line), not this snippet's concern —
tune it there.

## DO

1. Compose the message from the IDs just written + the flow, matching repo style
   `chore(memory): <IDs> — <flow> <short>`. Examples:
   - `chore(memory): BDR-034 + LRN-051 — feat dark-mode toggle`
   - `chore(memory): BLK-010 resolved — bugfix profile path`
   - `chore(memory): journal — hotfix copy typo`   (journal-only, nothing else)

2. Commit surgically via the helper, capturing the memory-commit hash it prints:

       mem_hash=$(bash "$HOME/.claude/lib/memory-commit.sh" commit "<message>")
       rc=$?

3. Report by (rc, mem_hash):
   - rc 0, mem_hash non-empty → `✅ mémoire committée <mem_hash>`
   - rc 0, mem_hash empty     → `CAPITALIZE: rien à committer` (helper no-op)
   - rc 3                     → unsafe git state (detached / merge in progress);
                                memory stays in the working tree for a manual
                                commit — surface the helper's stderr.

   `<mem_hash>` is the MEMORY commit (the one that ADDS the entries). It is NOT
   the code-commit hash that capitalize anchored INSIDE the entries
   (`Reference: commit <code-hash>`). Two commits, two hashes — never report the
   code hash here.

## HARD RULE — surgical scope

The helper stages and commits ONLY `.claude/memory` + `.claude/tasks`, filtered
to paths with real changes, via pathspec — never `git add -A` / `git add .` /
`git commit -a`. Automation removes the human diff review that would catch an
accidental stage, so the scope IS the safety. Do NOT bypass the helper with a
manual `git add` / `git commit`: that reintroduces the exact risk the helper
removes (proven: dangling code, untracked or pre-staged, is never embarked; a
no-match pathspec is filtered, not fatal).

## ORDERING (orchestrators only)

`finishing-a-development-branch` may merge-and-delete the branch or push a PR. A
memory commit created AFTER it lands outside the integrated history — stranded
on the PR path. So in ship-feature / init-project this snippet runs BEFORE
FINISH. The code commits already exist (implementation step), so the entries'
hash references are valid at this point.

## WHAT THIS DOES NOT DO

- Does NOT commit code — the code commit happened upstream (implementation step).
- Does NOT push — pushing / merging is FINISH's job, which runs AFTER this in
  orchestrators.
- Does NOT decide WHAT to capitalize — the scan + approval gate upstream own
  that; this only commits what was already approved and written.
- Does NOT reference or echo the code-commit hash anchored in the entries — it
  reports only the memory-commit hash the helper returns.
- Does NOT run if you hand-roll `git add` / `git commit` instead of the helper —
  bypassing it drops the surgical-scope guarantee. Always call the helper.

## IDEMPOTENT

Safe to run when memory is already clean: the helper no-ops (exit 0, empty
stdout, no commit). Running it twice creates at most one commit.
