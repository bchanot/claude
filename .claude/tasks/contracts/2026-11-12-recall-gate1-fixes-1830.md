# CONTRACT — recall-gate1-fixes (phase 4d gate 1 + 4d.4)
- date: 2026-11-12 | flow: feat | branch: feature/recall-gate1-fixes (off develop b661fb9)
- status: active

## REQUEST (verbatim — IMMUTABLE)
memory recall gate 1 (EVAL-058) fixes in mods/memory + /prune-memory step D (4d.4). Scope: (1) mods/memory/hooks/register.ts `triggerKind`: the `idle` trigger fires only when the prompt has at least 8 content words (new constant, `fresh` and `keyword` keep MIN_CONTENT_WORDS=5) and the idle gap stays the measured IDLE_MS since the last composer prompt; (2) MAX_PICKS 3 → 2 (rerank prompt text + parseIds cap); kit tests updated/added in register.test.ts; (3) skills/prune-memory/SKILL.md gains STEP 1 "D. Feedback — noisy and promotion (phase 4d.4)": reads `~/.claude/memory-feedback/FEEDBACK.md` lines `Noisy:` and `Promotion candidates:` filtered on the current repo tag (`basename#sha1(root)[0:6]`, same tag the reader writes; lib/memory-feedback/labels.ts has it), a noisy entry → candidate "inline rewrite: title + lesson narrowed to the concrete trigger so BM25/rerank stop picking it for unrelated prompts" (allowed under a /prune-memory curation commit like C), a promotion candidate → BDR-100 proposal: name the mechanism (rule line, hook, guard, test) in STEP 2, user decides; on accept the entry gets `memory.sh status <ID> "promoted to <mechanism>"` and the mechanism is a separate /feat; no FEEDBACK.md → "no feedback run" line in STEP 2; test in skills/prune-memory/tests/run-deterministic.sh with a fixture FEEDBACK.md (tag match, tag mismatch, absent file). Docs: BDR-140 "4d.4 conditional" amended by a dated status line, CHANGELOG Unreleased, USAGE if /prune-memory is described there. NOT in scope: body indexing (already indexed, register.ts docOf; replay 2026-11-12 shows the 4 "no-overlap" misses rank 53-322 with body overlap → accepted ranking limit), IDLE_MS change, logging candidate IDs.

(user decisions 2026-11-12, close-out brief: idle "resserrer, pas supprimer" = ≥ 8 words + real idle gap; cap 2; no-overlap misses = accepted after the replay; 4d.4 built now.)

## CLARIFICATIONS
- [gated 2026-11-12, user brief "a decision not listed: take the one answering the phase's original ask, note it, continue"] constant name `IDLE_MIN_WORDS = 8` exported beside `MIN_CONTENT_WORDS`; the idle gap keeps `IDLE_MS` (30 min, measured from the last composer prompt of the session, in-process; a new process = no idle).
- [gated] STEP 2 block `[D. Feedback — noisy rewrite / promotion]` printed after `[C. Bloated]`; with no FEEDBACK.md the line reads `[D. Feedback] no feedback run (~/.claude/memory-feedback/FEEDBACK.md absent)`; a FEEDBACK.md whose Noisy/Promotion lines carry no entry of this repo's tag reads `[D. Feedback] none for <tag>`.
- [gated, amended 2026-11-12 after challenge: `promoted` is not a memory.sh status word] status wording on an accepted promotion (r3): `memory.sh status <ID> "<current word>, promoted to <mechanism>"`, `implemented` when the entry has no readable word, so a closed entry stays closed; a noisy rewrite is an inline edit of the title + lesson under the curation commit (append-only exception already granted to C), never a status line.
- [gated] the repo tag is computed in the SKILL.md bash block as `"$(basename "$root")#$(printf '%s' "$root" | sha1sum | cut -c1-6)"` with `root = git rev-parse --show-toplevel` (must equal labels.ts `tagOf` for the same absolute root; locked by a test that compares both on one path).

## ACCEPTANCE CRITERIA
1. `triggerKind(text, false, IDLE_MS)` returns `undefined` for a prompt of 5-7 content words and `'idle'` at 8+; `fresh` (5+ words) and `keyword` (5+ words) unchanged; `IDLE_MIN_WORDS` exported = 8; `MIN_CONTENT_WORDS` stays 5.
   CHECK: cd mods/memory/hooks && grep -c IDLE_MIN_WORDS register.ts register.test.ts | grep -c ':[1-9]'
   EXPECT: 2
   EVIDENCE: MET exit=0 marker-found :: 2
2. `MAX_PICKS` = 2: the rerank prompt ends "at most 2 candidate IDs", `parseIds` through the rerank path keeps 2 at most (existing test at register.test.ts:1991 updated; a test feeding a 3-ID answer gets 2 entries injected).
   CHECK: cd mods/memory/hooks && echo $(grep -c 'MAX_PICKS = 2' register.ts)$(grep -c 'at most 2 candidate IDs' register.test.ts)
   EXPECT: 11
   EVIDENCE: MET exit=0 marker-found :: 11
3. Mod kit green: `claude plugin test mods/memory` (or the suite `make test suite=lib/tests/mods.test.sh`) passes with the new tests.
   CHECK: cd mods/memory && PATH=$HOME/.bun/bin:$PATH timeout 300 claude plugin test . 2>&1 | tail -5
   EXPECT:  0 fail
   EVIDENCE: MET exit=0 marker-found :: (pass) FR4: the protect read happens once per root and session [25.33ms] 288 pass 0 fail Ran 288 tests across 1 file. [6.81s]
4. skills/prune-memory/SKILL.md STEP 1 has a `### D. Feedback — noisy and promotion (phase 4d.4)` subsection with ONE fenced bash block that prints, for the current repo tag, lines `noisy<TAB><ID>` and `promote<TAB><ID>` from `~/.claude/memory-feedback/FEEDBACK.md` (`Noisy:` / `Promotion candidates:` lines, comma-separated `<tag> <ID>` items), `no-feedback-run` when the file is absent, header lines `tag\t<tag>` / `date\t<date>` and `other\t<tag>` lines but no `noisy`/`promote` row when no item carries the tag (r3); the path is `$HOME/.claude/memory-feedback/FEEDBACK.md` (same as lib/memory-feedback-remind.sh); tests pin `HOME` like RED-6/RED-9, no new env seam.
   CHECK: grep -c '### D. Feedback' skills/prune-memory/SKILL.md
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
5. STEP 2 example block gains `[D. Feedback — noisy rewrite / promotion]` with fictional 9xx IDs: a noisy row proposes the inline rewrite (title + lesson narrowed), a promotion row proposes a named mechanism per BDR-100 and the status line `memory.sh status <ID> "<current word>, promoted to <mechanism>"`; `d` joins the approve list (`all / a / b / c / d / edit <ID> / skip`); STEP 3 applies a noisy rewrite like C and a promotion as the status line only (the mechanism = separate /feat, named in the final report).
   CHECK: grep -c 'promoted to' skills/prune-memory/SKILL.md | grep -c '^[2-9]'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
6. `skills/prune-memory/tests/run-deterministic.sh` gains RED-10 executing the REAL step D block (extract_block on `### D.` heading or the STEP 1 block index) in a sandbox repo with `HOME` pinned to a sandbox dir holding `.claude/memory-feedback/`: (a) FEEDBACK.md with this sandbox's tag → both rows printed; (b) a FEEDBACK.md carrying another tag only → no row; (c) directory without FEEDBACK.md → `no-feedback-run`; (d) the tag the block computes equals `tagOf` from lib/memory-feedback/labels.ts for the sandbox root (bun available → compare; bun absent → skip (d) with a SKIP line, (a)-(c) still run).
   CHECK: PATH=$HOME/.bun/bin:$PATH bash skills/prune-memory/tests/run-deterministic.sh 2>&1 | tail -1
   EXPECT: SUITE: all GREEN
   EVIDENCE: MET exit=0 marker-found :: SUITE: all GREEN
7. `make test` green (suites touched: mods, prune-memory deterministic via its runner if wired, doctrine-citers), shellcheck clean on changed .sh.
   (manual: make test exceeds the 120 s gate timeout; run 2026-11-12 on the feater diff: "all suites green")
8. Limits on our code: new functions ≤ 25 logic lines / 5 params / 5 locals, lines ≤ 80 in .ts and .sh and SKILL.md bash blocks.

## FILE SCOPE
(r2: README.md:165, USAGE.md:163/217 patched by the STEP 6 doc-syncer, not the executor.)
mods/memory/hooks/register.ts, mods/memory/hooks/register.test.ts, skills/prune-memory/SKILL.md, skills/prune-memory/tests/run-deterministic.sh (+ a fixture under skills/prune-memory/tests/fixtures/ if the runner uses files rather than printf), CHANGELOG.md (STEP 6 doc sync), .claude/memory/decisions.md (BDR-140 status line, STEP 7 via memory.sh).
