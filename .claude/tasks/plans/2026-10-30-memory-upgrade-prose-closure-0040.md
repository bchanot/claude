# /bugfix memory-upgrade-prose-closure — DIAGNOSIS + FIX PLAN r2 (BLK-038)

r2 2026-10-30 after 3 lenses: robustness FATAL(4), correctness FATAL(2),
simplicity CONCERNS(1). Changes vs r1 named in § R2 CHANGES.

## Bug
`bash lib/memory.sh upgrade` (v1 → v2) writes `- **Status (<date>, upgrade)**: resolved`
under blockers that are open, and writes it twice when a sub-heading repeats the ID.
Seen 2026-10-30 on orbistep (`/home/bchanot/Documents/game`, HEAD of chore/memory-v2):
BLK-021 (`date: 2026-09-20 · status: open …`, "Fix direction (not decided)"),
BLK-030 (`date: 2026-10-17 | status: code resolved (df5818c) · SMTP open (upstream
OVH)`) get `resolved`; BLK-008 gets it twice (its body holds `### BLK-008 UPDATE …`).
zenquality BLK-006 (`- **Statut** : resolved (blockage), open (root delivery cause …)`)
gets `resolved`. The oracle reported the open set unchanged: both its readers agreed.

## Root cause
- `_mem_upgrade_repair` (lib/memory.sh ~644) writes the v1 verdict for every blocker
  `_mem_verdict_diff` reports "v1 closed, strict open". The v1 verdict comes from
  `memory_legacy_status` (~592): LAST entry line matching `_MEM_LEGACY_RE`, then
  `_mem_legacy_open` says closed when it contains `resolved`/`RESOLVED`. Prose and
  mixed lines qualify. A lexical guess becomes an explicit status line.
- `_mem_verdict_diff` (~630) iterates `_mem_heading_ids "$2" BLK` (any heading level):
  `### BLK-008 UPDATE` yields BLK-008 twice → two inserts.
- Upgrade's v1 range (`_mem_legacy_open`, end `'^##* *BLK-[0-9]'`) stops at a
  same-ID `### BLK-x …` sub-heading, while reconcile's v1 reader and the strict reader
  continue: a later `Status: open, reopened` under the sub-heading is unseen by upgrade.

## Evidence
Scratchpad classify over the 13 repos' pre-upgrade blockers: prose or mixed v1
closures exist (orbistep BLK-021 really open, BLK-026 prose addendum really resolved,
BLK-030 mixed, zenquality BLK-006 mixed). BLK-021 and BLK-026 share a shape with
opposite truth: no lexical rule decides prose. User decision 2026-10-30: refuse and
name, never guess.

## Fix plan (r2)
1. `memory_legacy_status` with `<end>` (upgrade-only branch; reconcile's default
   2-arg branch untouched): a heading matching `<end>` whose ID equals the entry's ID
   does NOT end the range (same-ID `###` sub-heading = continuation). Pass the ID to
   awk through ENVIRON or the existing `-v id` (an ID, not free text).
2. `_mem_verdict_diff`: (a) iterate unique IDs, first-occurrence order; (b) an ID
   whose v1 line from OLD (`memory_legacy_status "$1" "$id" '^##* *BLK-[0-9]'`, step-1
   range) is BYTE-EQUAL to the strict winning candidate in NEW, and that line matches
   `^- \*\*Status \([0-9]` and does not contain `, upgrade)`, is an explicit status
   written by `memory.sh status`: emit row `ID<TAB>explicit` (strict wins). The repair
   names `explicit` rows once on stderr and writes nothing; the oracle's filter stays
   `$2 == "resolved"`, so `explicit` never refuses. A dated line followed by a later
   prose closure is NOT byte-equal to the v1 line → normal path → refused (never a
   guess). Index-derived `, upgrade)` lines are already excluded by the `ix` skip
   (`_mem_index_stated`) and by the `, upgrade)` filter (not by timing: r2 claimed they
   did not exist yet, false, `_mem_upgrade_text` writes them before repair).
3. `_mem_upgrade_repair`, for each `resolved` row: read the v1 line once
   (`memory_legacy_status "$1" "$id" '^##* *BLK-[0-9]'`). Labelled = the line holds a
   `status`/`statut` label (case-insensitive, `[^a-z:]*:` then optional `*`/spaces)
   AND the label's value holds exactly ONE distinct `_MEM_WORDS` word AND that word is
   closed (memory_closed). Labelled → insert `- **Status (<date>, upgrade)**: <that
   word>` and name the ID + v1 line on stderr (every write visible at the approval).
   Not labelled → no insert; stderr: `memory: <ID>: v1 closed by an unlabelled or mixed
   line, status unknown: <v1 line, cut>` + remedy `record it from the project root:
   memory.sh status <ID> "<word>, …" (the leading word decides), then re-run upgrade`.
4. `_mem_upgrade_oracle`: keep the existing verdict refusal unchanged (it refuses any
   ID still v1-closed / strict-open after repair → unlabelled ones refuse the file,
   rc 2, file left as it was). ADD an independent entry-level assert not using
   `_mem_verdict_diff`: at most one `, upgrade)**:` line per entry ID in the new file
   (heading of the entry = `## ID `), else `memory: upgrade lost: <ID>:dup` rc 2.
5. Tests, lib/tests/memory.test.sh T15 (fixtures via `v1blk`; remedy cases under
   `d15/<x>/.claude/memory` and `-C d15/<x>`, the relpath pattern):
   a. `## BLK-001 — x` / `date: 2026-09-20 · status: open` / `prose: another tab already
      resolved it` → rc 2, file byte-identical, stderr names BLK-001 and the remedy.
   b. `date: 2026-10-17 | status: code resolved (abc) · SMTP open` → rc 2.
   b2. `- **Statut** : resolved (x), open (y)` → rc 2.
   b3. boundary: `status: code resolved (abc) · SMTP open` (strict candidate, both
       readers closed) → rc 0, no `upgrade)` line.
   c. existing T15-datestatus fixture: add a `memory_word_of` assert = resolved.
   d. `## BLK-008 — x` / `date: 2026-07-20 · status: RESOLVED 2026-07-20` / `### BLK-008
      UPDATE 2026-07-20 (y)` / `body` → rc 0, exactly one `upgrade)` line.
   d2. same with `Status: open, reopened` under the `###` → rc 0, no `upgrade)` line,
       strict open.
   e. remedy round trip on (a)'s shape: `memory.sh -C d15/e status BLK-001 "upstream,
      SMTP OVH; code resolved (x)"` then `memory.sh -C d15/e upgrade` → rc 0, strict
      word upstream, no `upgrade)` line.
   e2. same remedy on an entry with a `### BLK-001 UPDATE` sub-heading → rc 0.
   (r3: fixture f dropped: a v1-closed line always holds `resolved`, so the single
   closed word written is in practice `resolved`; the code still writes the word it
   found.)
   e3. dated line then later prose closure: `## BLK-001 — x` / `date: x · status: open`
       / `- **Status (2026-10-30)**: open, waiting` / `later prose: fixed, resolved in
       abc` → rc 2 (no `explicit` skip: v1 line is the prose).
   e4. step-1 guard: e2's shape WITHOUT the remedy line, prose closure above the
       `### BLK-001 UPDATE` and `Status: open, reopened` below it → rc 0, no
       `upgrade)` line (fails if the range still stops at the sub-heading).
   g. oracle dup assert: a built text with two `upgrade)` lines under one ID is refused
      (tamper pattern, T15-tamper style).
6. Real-data proof before merge-ready (main loop, scratchpad, `MEMORY_DATE=2026-10-30`
   = the live pass date). Per repo a fresh `mktemp -d` project with
   `.claude/memory` filled from:
   - committed repos (config, integration_alphalink, robin_petier, trucks_at_work,
     bchanot-cv, game-deploy, gitea-deploy, angelscar356, for_you, nuit-folle): `git
     show <upgrade-commit>^:.claude/memory/<f>.md`; trucks_at_work gets the 3 bullet
     Indexes dropped first (live precondition). Baseline = `git show
     <upgrade-commit>:…` (robin_petier: 88f8dbc, before its status-line commit;
     trucks_at_work: 17536ce minus the BLK-001 status line and journal line).
   - orbistep: `git show HEAD:` of chore/memory-v2 + the live 16-line heading sed
     (precondition); baseline = its current working tree (uncommitted upgrade).
   - zenquality: `git show HEAD:` of chore/memory-v2; baseline = its working tree.
   - faunosteo: `git show 81f7639:`; baseline = scratchpad fauno.6sTi/after.
   Run `memory.sh -C <copy-proj> upgrade`. Expected: orbistep blockers.md refused
   naming BLK-021, BLK-026, BLK-030; zenquality blockers.md refused naming BLK-006;
   every other registry rc 0 and byte-identical to its baseline (journal excluded: the
   live pass appended a line). Any other difference is reported, not waived.

## R2 CHANGES
- Classifier moved from `_mem_verdict_diff` into `_mem_upgrade_repair`; no `unclear`
  protocol word; oracle verdict check unchanged (simplicity 1).
- Labelled = exactly one distinct status word, closed (robustness 1: zenquality
  BLK-006); repair writes that word (robustness 5, correctness 5, simplicity 3).
- Dated `Status (date)` lib lines win over the v1 reader in `_mem_verdict_diff`
  (correctness 2, robustness 3): the remedy converges even when its text says
  "resolved".
- Same-ID sub-heading continues the upgrade's v1 range (robustness 4, correctness 3,
  simplicity 5); fixtures d2, e2.
- Every repair write named on stderr + independent dup assert in the oracle
  (robustness 2, correctness 6).
- Fixture shapes fixed: b with `date: … |` prefix, b3 boundary, remedy under
  `.claude/memory` with `-C` (correctness 1, 4; simplicity 4); old 3c folded into the
  datestatus fixture (simplicity 2).
- Real-data run over the 13 copies with `-C` (correctness 7, LRN-237).
- Remedy message names the project-root invocation (robustness 6).

## R3 ADDENDUM — race found while building the step-6 oracle (main loop, 2026-10-30)
`_mem_upgrade_repair` reads `_mem_verdict_diff "$1" "$2"` through `< <(…)` while
`_mem_insert` rewrites "$2" in place (`cat "$tmp" > "$1"`, memory.sh ~288): the diff's
readers can see a torn file and report an extra blocker. Measured on config's
pre-upgrade blockers (4dc8e77): stage-by-stage trace = 2 rows (BLK-002, BLK-004); the
CLI upgrade = 3 repair lines (BLK-003 extra, its `Status: SUPERSEDED …` line is a
strict candidate, so it is never a real verdict move), 6 of 6 runs; the live run
345ee68 wrote 2. Fix: step 3 captures the full diff into a variable BEFORE the first
insert, then loops over it. Covered by the step-6 oracle (config replay must equal
345ee68); a unit test cannot force the interleaving deterministically.

## R3 CHANGES (confirmation pass correctness FATAL(3), folded without a 3rd pass)
- Fixture f dropped (unreachable); repair word in practice `resolved` (C1).
- Step 2b skip only when OLD v1 line byte-equals NEW strict winner, dated, not
  `, upgrade)`; row `explicit`, named once by the repair; new fixtures e3, e4 (C2, C4).
- Rationale for `, upgrade)` exclusion corrected (C5).
- Step 6 sources, preconditions, MEMORY_DATE and baselines named per repo (C3).

## Out of scope
reconcile's default v1 reader, the strict parser, heading normalization, other parked
4a minors.

## Follow-up after the fix (not in this diff)
Reset orbistep and zenquality `.claude/memory` to HEAD on chore/memory-v2 (user
approved), re-apply orbistep's 16-line heading fix, ask the user the real status of
orbistep BLK-021/026/030 and zenquality BLK-006, write them with `memory.sh status`,
re-run upgrade; regenerate the faunosteo patch with the fixed lib.
