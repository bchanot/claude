# /feat memory-v2-minors-docs — PLAN r2

r2 2026-11-01 after 3 lenses: simplicity FATAL(2), correctness FATAL(1),
robustness FATAL(1). One shared BLOCKER (the 86-byte evals line vs criterion
4) and one MAJOR (the `-C` sentence must cover status/journal too) folded;
all MINORs folded. No deferral. The approach (same five files, same edits)
did not change, so no second pass.

FEAT: phase 4a parked minors, doc half — 5 doc files, wording only. Code half
shipped (develop c92381e). No logic, no test code: the oracles are greps.
User picks 2026-11-01 (gated): evals example word = `deprecate, see
BDR-NNN`; the same short pointer sentence in all three skills.

## Plan
- [ ] lib/capitalize-commit.md § WRITE intro (lines 34-35, "Registry entries
      and journal lines are written only by `lib/memory.sh`, never by Edit or
      append; there is no `## Index` to update."): append one sentence, wrapped
      at 80: "Every verb takes `-C <project root>` when the cwd is not the
      project root; it `cd`s first, so give `--body-file` an absolute path."
      Then DELETE the Entry bullet's last sentence "`-C` when the cwd is not
      the project root." (line 42) so `-C` is stated once, for add, status
      and journal alike. Keep the bullet's wrap.
- [ ] skills/tour/SKILL.md: after line 277 ("repo's nor any target
      project's."), add ONE new line "Approved entries per
      `lib/capitalize-commit.md` § WRITE." No reflow of the paragraph; the
      citation stays on one line.
- [ ] skills/deploy/SKILL.md step 7 (lines 449-450): after "gated, never
      silent." append " Approved entries per `lib/capitalize-commit.md` §
      WRITE." — put it on a NEW continuation line with the item's 3-space
      indent, citation on one line; no reflow of the existing lines.
- [ ] skills/audit-delta/SKILL.md: after line 251 ("`evals.md`. Behind
      approval, never silent."), add ONE new line "Approved entries per
      `lib/capitalize-commit.md` § WRITE." No reflow.
- [ ] templates/memory/evals.md: insert ONE line between the existing blank
      line (evals.md:30) and `-->` (evals.md:31), no new blank line:
      Later status: `bash ~/.claude/lib/memory.sh status EVAL-NNN "deprecate, see BDR-NNN"`.
      That is the shape of blockers.md:28-30 and decisions.md:31-33 (blank,
      `Later status:`, `-->`). The line is 86 bytes: templates are not held
      to 80 (decisions.md:32 is 84; evals.md:9,13,16,17 already exceed it),
      and criterion 4's width check covers lib/capitalize-commit.md only.
      `deprecate` is a status word (`_MEM_WORDS`) that names a successor; it
      does not close an entry (`memory_closed` = resolved|superseded|
      deprecated), which is fine for an eval.
- [ ] No test file: criteria 1-4 are grep/awk oracles run by gates.sh; the
      executor runs `make test` (doctrine-citers census: 8 citers already
      use the identical string `lib/capitalize-commit.md` § WRITE).

## Edge cases
- The three skills keep their CLAUDE.md gate sentence; the new line names
  the write path only.
- `~/.claude/lib/memory.sh` is a `.sh` path: the census never extracts it.
- Nothing parses the template comment block (init-project, capitalize and
  onboarder `cp -n` it; memory.sh reads only the frontmatter).

## Parked (TODO line, outside FILE SCOPE)
- MIGRATION.md:209 shows `memory.sh -C <project> add … --body-file …` with
  no absolute-path note: same trap, next doc pass.

## Disposition
Honors BDR-129 (single writer: every doc points at the one § WRITE entry
point) and BDR-022 (doc-commit never touches `.claude/`: FILE SCOPE is outside
it). No in-force LRN constrains a wording change.
