# CONTRACT — memory-v2-minors-docs

## REQUEST (verbatim — IMMUTABLE)
Phase 4a parked minors, doc half (5 doc files, no code): (1) lib/capitalize-commit.md § WRITE: with `-C <project root>`, memory.sh does `cd` before reading `--body-file`, so a relative body-file path resolves against the project root, not the caller's cwd; say to pass an absolute `--body-file` with `-C`. (2) skills/tour/SKILL.md, skills/deploy/SKILL.md, skills/audit-delta/SKILL.md: their "offer to capitalize" sentence names the registries but not the write path; add the pointer "per `lib/capitalize-commit.md` § WRITE" like feat/bugfix/hotfix/capitalize do. (3) templates/memory/evals.md: add the "Later status" line that blockers.md and decisions.md templates carry (`bash ~/.claude/lib/memory.sh status EVAL-NNN "correct …"` / `"deprecate, see BDR-NNN"`). The rc 6 text in capitalize-commit.md was already updated by the code half's doc sync (18e6370).

## CLARIFICATIONS
- Plan r2: `.claude/tasks/plans/2026-11-01-memory-v2-minors-docs-1130.md`. Wording closed there; the `-C` sentence sits in the § WRITE intro (covers add, status, journal), the Entry bullet's own `-C` sentence is removed; the executor changes nothing else in the five files.
- 2026-11-01 user [gated]: evals `Later status` example = `deprecate, see BDR-NNN`; the pointer sentence is the same short form in all three skills: "Approved entries per `lib/capitalize-commit.md` § WRITE."
- Code half shipped as feature/memory-v2-minors → develop c92381e; this contract is the doc half only.

## ACCEPTANCE CRITERIA
1. lib/capitalize-commit.md § WRITE says, once for every verb, that `-C` `cd`s first and the `--body-file` path is absolute.
   CHECK: cd /home/bchanot/Documents/claude && sed -n '/^## WRITE/,/^## /p' lib/capitalize-commit.md | tr -s ' \n' ' ' | grep -q 'body-file. an absolute path' && [ "$(sed -n '/^## WRITE/,/^## /p' lib/capitalize-commit.md | grep -c 'when the cwd is not the project root')" = 1 ] && echo WRITE-OK
   EXPECT: WRITE-OK
   EVIDENCE: MET exit=0 marker-found :: WRITE-OK
2. The capitalize offer in skills/tour, skills/deploy and skills/audit-delta points at `lib/capitalize-commit.md` § WRITE.
   CHECK: cd /home/bchanot/Documents/claude && for s in tour deploy audit-delta; do grep -q 'lib/capitalize-commit.md` § WRITE' skills/$s/SKILL.md || exit 1; done && echo POINTER-OK
   EXPECT: POINTER-OK
   EVIDENCE: MET exit=0 marker-found :: POINTER-OK
3. templates/memory/evals.md carries a `Later status:` line naming `memory.sh status EVAL-NNN`, inside the template comment like blockers.md and decisions.md.
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'Later status: `bash ~/.claude/lib/memory.sh status EVAL-NNN' templates/memory/evals.md && awk '/^<!--/{c=1} /^-->/{c=0} /Later status/{print c}' templates/memory/evals.md | grep -q 1 && echo EVALS-OK
   EXPECT: EVALS-OK
   EVIDENCE: MET exit=0 marker-found :: EVALS-OK
4. `make test` green (doctrine-citers census, project-rules); the diff vs develop adds no line over 80 bytes in lib/capitalize-commit.md (templates are not held to 80: decisions.md:32 is 84), and touches only the five files.
   CHECK: cd /home/bchanot/Documents/claude && t=$(make test 2>&1) && printf '%s\n' "$t" | grep -q 'all suites green' && [ "$(git diff develop -- lib/capitalize-commit.md | grep '^+' | grep -v '^+++' | LC_ALL=C awk 'length($0) > 81' | wc -l)" = 0 ] && [ "$(git diff develop --name-only -- . ':!settings.json' ':!.claude' | sort | tr '\n' ' ')" = "lib/capitalize-commit.md skills/audit-delta/SKILL.md skills/deploy/SKILL.md skills/tour/SKILL.md templates/memory/evals.md " ] && echo DOCS-LINT-OK
   EXPECT: DOCS-LINT-OK
   EVIDENCE: MET exit=0 marker-found :: DOCS-LINT-OK

## FILE SCOPE
- lib/capitalize-commit.md
- skills/tour/SKILL.md
- skills/deploy/SKILL.md
- skills/audit-delta/SKILL.md
- templates/memory/evals.md
