# DOC-COMMIT — couple the public-doc commit to the dev flow

Inline snippet. Include at the END of an orchestrator's DOC SYNC step, AFTER doc-syncer
has patched the public docs (and any SIGNIFICANT gate is resolved). It commits ONLY the
files doc-sync patched, surgically, so the flow never leaves patched docs uncommitted —
and, run BEFORE FINISH, so those docs reach the merge/PR instead of stranding.

This is the TAIL of doc-sync, not a replacement: doc-syncer's DRIFT DETECTION + PATCH
(and its SIGNIFICANT gate) are unchanged and run before this snippet. Only the COMMIT of
the already-patched files is automated here. Twin of `capitalize-commit.md` (memory TAIL).

## WHEN TO RUN

At the doc-sync step, once doc-syncer has applied its patches (AUTO MODE MINOR auto-patch
and any SIGNIFICANT-gated patch), with the code already committed.

- Orchestrators (ship-feature / init-project): run it BEFORE the FINISH step — otherwise
  the doc commit strands outside the merge/PR (the exact bug this fixes). See ORDERING.

doc-syncer runs DISPATCHED (BDR-077: `MODE: audit` on opus → dispatcher gate
→ `MODE: patch` on sonnet); its patch-mode report hands the orchestrator BOTH
machine blocks: `PATCHED_FILES:` (ONE PATH PER LINE — pass each line as a
SEPARATE argument, see DO step 3) and `CHANGE SUMMARY` (one line per patched
file — the patch context that used to be in-thread now crosses the dispatch
boundary through this block, LRN-126).

## DO

1. Collect `PATCHED_FILES` — the public-doc paths doc-syncer wrote this run (its OUTPUT
   block, ONE PATH PER LINE). Empty → nothing to commit; the helper no-ops.

2. Compose — from doc-syncer's `CHANGE SUMMARY` block (the patcher held the
   patch context and reported it; a dispatched patcher with NO summary block
   in its report = incomplete report, re-dispatch rather than invent) —
   BOTH artifacts:
   - the COMMIT MESSAGE, repo style `docs: <summary> — <flow>`
     (`docs: README features + USAGE flags — ship-feature dark-mode`);
   - the CHANGE SUMMARY for the rc 0 surface (e.g. "README features section + USAGE
     --export flag") — derived from the block, never a bare file count.
   Both are the ORCHESTRATOR's to write — the helper produces NEITHER (its only stdout
   is the hash). This is the load-bearing point of the visible surface: see the rc 0 row.

3. Commit surgically via the helper, passing EXACTLY the patched files — each path as a
   SEPARATE argument (split `PATCHED_FILES` on NEWLINES only), capturing the hash:

       doc_hash=$(bash "$HOME/.claude/lib/doc-commit.sh" commit "<message>" "<path-1>" "<path-2>" …)
       rc=$?

   SEPARATOR — the helper takes argv (no in-band separator), so a path with spaces
   (`docs/My Guide.md`) survives as ONE argument and commits correctly (proven, T7). NEVER
   flatten the list into a single space-joined string and re-split it: that mis-splits a
   spaced path into garbage args, which the helper's `[ -e ]` filter then silently drops —
   the spaced doc would strand. Newline is doc-syncer's OUTPUT format (paths carry no
   newlines); argv is the handoff to the helper.

4. REPORT BY (rc, doc_hash) — handle EVERY exit, not just success:

   | rc | doc_hash | meaning | what to do |
   |----|----------|---------|------------|
   | 0 | non-empty | docs committed | `✅ committed <files> — <one-line of what changed>` — VISIBLE surface. `<files>` = the paths the agent passed (also echoed on the helper's stderr); `<one-line>` = the CHANGE SUMMARY the AGENT composed in DO step 2, NOT returned by the helper (stdout is the hash only). That summary is what makes the surface REPLACE the MINOR gate — a bare file count degenerates it back to what we removed. No summary → don't report success silently; name what changed. |
   | 0 | empty | helper no-op (nothing pending) | `DOC SYNC: docs already current — nothing to commit`. doc-sync found no drift, or patched nothing. |
   | 3 | empty | unsafe git state (detached / merge / rebase) | docs stay in the working tree for a manual commit; surface the helper's stderr. Do NOT retry blindly — the tree is mid-operation. |
   | 4 | empty | **SCOPE VIOLATION — upstream anomaly** | doc-syncer surfaced a `.claude/**` or `CLAUDE.md` path in `PATCHED_FILES`, which it must NEVER patch (BDR-022). STOP. Signal: `⚠️ doc-commit REFUSED — doc-syncer listed a forbidden path (<offender, from stderr>); this violates BDR-022 upstream. Investigate why doc-syncer touched/listed it before re-running.` Do NOT swallow it, do NOT hand-commit the rest — the refusal IS the alarm. |
   | 5 | empty | **COMMIT REJECTED — nothing committed** | `git commit` exited non-zero — a pre-commit hook blocked it (e.g. a doc commit on a protected `main`/`develop`), a signing failure, or similar. The docs are STILL in the working tree, uncommitted, on a dirty tree. STOP — do NOT proceed to FINISH as if docs landed (that re-creates the stranding bug this whole snippet fixes). Signal: `⚠️ doc-commit FAILED — the doc commit was rejected (<helper stderr>); docs remain uncommitted. Investigate (hook / branch / signing) before retrying.` No hash is emitted; do NOT retry blindly. |
   | 2 | empty | usage error (no message / bad invocation) | internal bug in this include — fix the call, don't paper over it. |

   `<doc_hash>` is the DOC commit (the one that adds the patched docs). Docs carry NO
   code-commit hash (unlike memory entries, LRN-052) — there is no second hash to report.

## HARD RULE — surgical, dynamic scope

The helper stages and commits ONLY the patched files passed as args, filtered to those
with real changes (LRN-051) — never `git add -A` / `git add .` / `git commit -a`. Automation
removes the human diff review, so the scope IS the safety. Two guards live in the helper;
do NOT bypass them:
- DYNAMIC pathspec: only the passed docs, changed-filtered.
- INVERSE exclusion (fail-closed, exit 4): a `.claude/**` / `CLAUDE.md` path aborts the
  WHOLE commit, loudly. Mirror-image of memory-commit (which TARGETS `.claude/`): doc-commit
  must never touch it (BDR-022). The refusal surfaces an upstream bug — treat it as rc 4
  above, never filter-and-commit-the-rest.

## ORDERING (orchestrators)

`finishing-a-development-branch` merges/pushes COMMITTED history only — it never commits
working-tree changes. A doc patch left uncommitted (or committed AFTER it) never reaches
the merge/PR. So this snippet runs BEFORE FINISH: the doc commit lands on the branch FINISH
integrates. Consumption is MECHANICAL (LRN-057 case a, like the memory commit) — production
on the branch = consumption by the merge, automatic.

## ACKNOWLEDGMENTS (conscious, not glossed)

- **MINOR doc content is non-gated yet auto-committed.** doc-syncer AUTO MODE patches MINOR
  drift silently (factual: command/param/path/version/dead-link — same bar as AUTO). This
  snippet commits it without a blocking gate, BY CHOICE. NOT the memory case: memory CONTENT
  was always gated, so its auto-commit only embarked approved entries. Here the VISIBLE
  surface (rc 0 row, agent-composed summary) REPLACES the gate as the review surface — name
  files + summarize, and the PR diff re-shows it. UPSTREAM of this snippet, doc-syncer now
  runs a deterministic shape oracle (`lib/doc-shape.sh`) on each MINOR patch: a patch whose
  SHAPE belies "minor" (adds a heading, is large, is a new file) is escalated to the
  SIGNIFICANT gate BEFORE it reaches here — so what this snippet auto-commits is shape-verified
  MINOR. The oracle is a STRUCTURAL floor, not a semantic SIGNIFICANT-detector (a small
  meaning-changing edit still reads MINOR); the visible surface stays the content backstop.
- **Partial init-project fix.** This commits the docs doc-sync patched. It does NOT commit the
  scaffold or the STEP 5b bootstrap README (no deterministic owner — [[BLK-010]]); ramassing
  them would re-create the over-reach we ban. ship-feature ends fully fixed; init-project's
  scaffold/bootstrap stays open.

## WHAT THIS DOES NOT DO

- Does NOT push / merge — FINISH does, AFTER this.
- Does NOT decide WHAT to sync — doc-syncer's drift detection + patch own that; this commits
  what was already patched.
- Does NOT commit code or memory — those are upstream (implementation step; capitalize-commit).
- Does NOT produce the surface's change summary — the helper returns only the hash; the AGENT
  composes `<files>` + `<one-line>` from the patch context (DO step 2). Surface ownership = agent.
- Does NOT reference a code-commit hash — docs anchor none (LRN-052); reports only the doc hash.
- Does NOT silently drop a forbidden path — rc 4 is an alarm, not a filter.
- Does NOT run if you hand-roll `git add` / `git commit` — bypassing the helper drops the
  dynamic-scope + inverse-exclusion guarantees. Always call the helper.

## IDEMPOTENT

Safe to run when docs are already current: empty list or clean tree → helper no-ops (exit 0,
empty stdout, no commit). Running twice creates at most one commit.
