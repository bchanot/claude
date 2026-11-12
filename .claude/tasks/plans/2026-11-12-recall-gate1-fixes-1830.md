# PLAN — recall-gate1-fixes (r2, after 3 lenses: correctness FATAL(7), robustness FATAL(4), simplicity CONCERNS(3))
Contract: `.claude/tasks/contracts/2026-11-12-recall-gate1-fixes-1830.md`

## Changes from r1 (named)
- R1 BLOCKER (all 3 lenses): `promoted` is not in `_MEM_WORDS` (lib/memory.sh:56-57) → status text = `implemented, promoted to <mechanism>` (leading word accepted, memory.sh untouched, classifier unchanged); RED-10e runs it through `memory.sh status` in the sandbox.
- R2 idle fixtures: NOTES (5 words) loses idle → new `NOTES8` constant with 8+ content words and no rule word drives LO2, IR2/IR3, SP2; :2729 SUITE (5 words) flips to false; 7-word false / 8-word true pair; one 5-7-word end-to-end case after 31 min asks nothing; idle+DESIGN_RULE → keyword pinned.
- R3 MAX_PICKS 2: SP1 (:2795-2813) updated to the 2-pick block size (it is the "3-ID answer → 2 injected" test; add a third live entry so 3 candidates really exist); TE9 (:3004-3021) rebuilt so the turn spends > budget − known-line before the checked line (pre-spend through a second known line refused, then a new prompt lets it through); no hardcoded "2" in the prompt template.
- R4 AC2 CHECK amended: `grep -c 'MAX_PICKS = 2' register.ts` + the test literal.
- R5 D block prints header lines `tag\t<tag>` and `date\t<FEEDBACK date>` first, then rows; tag = `basename#` + `{ sha1sum 2>/dev/null || shasum -a 1; }`; items split on `, `, matched on prefix `tag + " "`, ID = last field (spaces/commas in basenames survive); `no-git-root` when `git rev-parse` fails; `no-feedback-run` when the file is absent; unmatched tags present listed as `other\t<tag>` (visibility).
- R6 idempotence: `promote` rows dropped when the entry already has an `implemented, promoted to` status line; `noisy` rows dropped when `git log --since=<date> --grep="noisy-rewrite <ID>"` finds a curation commit (STEP 3 names `noisy-rewrite <ID>` in the commit message).
- R7 lesson field named: the rerank line is `id | title | lesson`, lesson = first sentence (≤ 280 chars) of the first labelled field in order BDR Decision; LRN Apply → Future application → Pattern; BLK Solution → Real cause (register.ts LESSON_LABELS). Noisy rewrite narrows the title and THAT sentence only; a title or sentence under the NEGATION GUARD → skipped, reported as manual; prompt-channel noise only (tool matcher reads body backtick spans: limit stated).
- R8 thresholds cited, never restated: `lib/memory-feedback/thresholds.ts` T.noisyHits / T.promoteHits / T.promoteSessions.
- R9 STEP 2: D is one run-level block after the per-registry blocks, fictional LRN-905/LRN-906, approve line keeps the `Approve per category?` prefix and gains `d`; no live ID, no `status: `, no `frontmatter` in the new prose (RED-7/RED-9 guards); rows filtered to registries in `$ARGUMENTS`. Stale "STEP 3.4 NEGATION GUARD" citation (SKILL.md:236) fixed to 3.3.
- R10 extract: `extract_block`'s heading regex `"^## " h` → `"^#+ " h` (no new helper); bun = `command -v bun` only; root resolved once with `git -C "$S10" rev-parse --show-toplevel` for fixture and tagOf.
- R11 docs: README.md:165 and USAGE.md:217 (5 words → idle needs 8, "at most 3" → 2) and USAGE.md:163 (/prune-memory: + feedback rewrite/promotion) go to STEP 6 doc sync (doc-syncer), BDR-140 status line in STEP 7 records the fix date and "later gate reads count rows after 2026-11-12 only".
- Deferred (TODO line, out of scope, lib/memory-feedback outside FILE SCOPE): retire the `thirdPick` metric/action and split pre-fix rows by date in metricsOf.

## Files
- `mods/memory/hooks/register.ts`
  - beside `MIN_CONTENT_WORDS` (:1641): `export const IDLE_MIN_WORDS = 8` (comment: gate 1 2026-11-12, idle 44 % on short follow-ups).
  - `triggerKind`: `const words = tokensOf(text).length`; `< MIN_CONTENT_WORDS` → undefined; fresh → 'fresh'; `idleMs >= IDLE_MS && words >= IDLE_MIN_WORDS` → 'idle'; keyword branch unchanged.
  - :707 `const MAX_PICKS = 2`. Nothing else.
- `mods/memory/hooks/register.test.ts`: import IDLE_MIN_WORDS; R2 + R3 edits (NOTES8, :2729 flip + 7/8 pair + `IDLE_MIN_WORDS` 8 + idle+design → keyword expect, 5-7-word idle e2e case, SP1, TE9, :1991 text "at most 2").
- `skills/prune-memory/SKILL.md`: STEP 1 `### D. Feedback — noisy and promotion (phase 4d.4)` (prose per R6-R8 + one bash block per R5/R6, ≤ 80 cols, mirrors the `for k in a:b` idiom of STEP 1), STEP 2 run-level D block (R9), STEP 3 item 4 (noisy = narrow title + lesson sentence per R7, commit message carries `noisy-rewrite <ID>`; promotion = `memory.sh status <ID> "implemented, promoted to <mechanism>"` only, the mechanism = separate /feat named in the report), 3.4 → 3.3 citation fix.
- `skills/prune-memory/tests/run-deterministic.sh`: extract regex (R10); RED-10 a (match → rows + tag/date header), b (other tag only → no row, `other` line), c (no file → `no-feedback-run`), d (bun present: fixture written with `tagOf(<physical root>)`, the block emits its row; absent: `RED-10d: SKIP`), e (`memory.sh status` on a sandbox LRN with the promotion text → rc 0, then the block drops that promote row), f (outside a git repo → `no-git-root`). Header comment updated.

## Disposition
honors BDR-140 (4d.4 built because gate 1 reported noisy + promotion), BDR-100 (promotion = mechanism, thresholds in one file), BDR-129 (writes through memory.sh, single status vocabulary untouched), registry append-only via the curation exception already granted to C; BDR-125 (no per-turn nag) untouched.

## r3 (confirmation CONCERNS(3), no BLOCKER; folded, no further challenge)
- C1/C2 noisy idempotence: no `--since` window. The D block drops a noisy row when `git log -E --format=%s --grep="noisy-rewrite ${id}([^0-9]|$)" -- .claude/memory` finds a commit (whole history). The skill writes the token itself: STEP 4's final report prints the exact commit subject `chore(memory): noisy-rewrite <ID>[, <ID>…]` and says /commit-change keeps it verbatim. RED-10g: a sandbox commit with that subject made today → the noisy row is dropped.
- C3 promotion status word: the leading word = the entry's CURRENT word (from `memory.sh index <kind>`): `memory.sh status <ID> "<current word>, promoted to <mechanism>"` (e.g. `resolved, promoted to …`, `accepted, promoted to …`); an entry with no readable word (LRN, v1) → `implemented, promoted to …`. A closed entry stays closed; RED-10e asserts the classifier word is unchanged after the status line on a resolved BLK. The D drop rule for promote = an existing status line containing `promoted to`.
- C4 SP1: three entries already exist; raise the KNOWN-1 claim cost to 800 (> 1500 − 778) and fix its comment.
- C5 tests import `triggerKind` (assert 'idle' / 'keyword' values); NOTES8 keeps the word `notes` (shares a token with LRN-002) and holds no DESIGN/ANALYSIS rule word.
- C6 AC4 amended (contract): header lines (`tag`, `date`) plus `other` lines may print; "no row" means no `noisy`/`promote` row.
- C7 parse anchored, case-sensitive, on `^Noisy: ` and `^Promotion candidates: `; the literal `none` skipped; the Actions section never parsed; "commas survive" claim dropped (a `, ` in a basename is an accepted limit, stated in the prose); RED-10 fixture includes `Noisy: none`.
- C8 STEP 3 item 4: only the title TEXT changes; `## <ID> — `, the `[status]` tag and the `(date)` stay verbatim; the lesson sentence is the only body change.
