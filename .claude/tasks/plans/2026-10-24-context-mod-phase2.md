# PLAN — context mod phase 2 (guards), for challenge (2026-10-24)

Source: TODO "Context mod queue (BDR-125)" phase 2, verbatim below. Decisions
already taken: BDR-125 (+ amendments 1-3): mod only where native carriers fail;
registry format guard moved to phase 4a (pre-commit validator, because registry
writes go through Bash/python, never Edit); phase 1 = native context diet.
Open question to challenge: guards as classic settings hooks (bash, like
hooks/push-guard.sh, which receives transcript_path so it can read the last
user message) versus as `tool.call` hooks of a new TS mod (`.catch` deny =
fail closed, `claude plugin test`, `$.state`). Existing enforcement to reuse,
not duplicate: githooks pre-commit (no code commit on main/develop),
post-commit/post-merge push, reference-transaction (no main/develop
deletion), push-guard.sh (manual-push mode), settings.json permissions.deny
+ autoMode hard_deny/soft_deny prose, lib/gitflow.sh (single branch writer,
`finish` merges + deletes), lib/commit-message.md (project convention lookup,
else 50 words), lib/code-origin.sh (ours vs foreign), lib/floor-guard.sh,
lib/tests/guard-bash.test.sh (214-case spec, hook absent: BLK-022 safety
classifier withheld the bash body).

- [ ] **Phase 2, guards in the context mod (deny with reason, deterministic)**
  - Registry format: moved to phase 4a (measured 2026-10-24: registry writes go through Bash/python, never Edit, since Edit needs a Read of a 357k-char file; a `tool.call` guard on Edit/Write would miss them; a pre-commit validator sees every write path).
  - Merge gate: Bash running `gitflow.sh finish` refused unless the last user message (recorded at `prompt.submit` origin composer) carries an explicit signal (merge it / merge le / merger / fusionne / feature OK / ship it, FR+EN list, tested on this session's real phrasings) or an AskUserQuestion answer approving the merge in the same turn.
  - Commit message: `git commit -m/-F` over 50 words refused unless a project convention file exists (lib/commit-message.md lookup order).
  - Code limits on OUR code only (origin from phase 1): after Edit/Write, report lines > 80 cols and functions > 25 logic lines as result `context`, never deny (language support: sh, ts/js, py, rs first; others skipped).
  - Destructive guard: re-attempt G2 (BLK-022) as a `tool.call` guard in TS against `lib/tests/guard-bash.test.sh` 214 cases; if the safety classifier withholds it again, record and stop.
  - Proof: one fixture per refusal + one benign twin per rule (no false positive), `.catch` fail-closed test, live canary run.
  - Cleanup: doctrine prose that only restated an enforced rule shrinks to one line + pointer (gitflow "finish only on explicit human signal", commit-message limit, registry format); `lib/commit-message.md` keeps the convention lookup only if still cited.

