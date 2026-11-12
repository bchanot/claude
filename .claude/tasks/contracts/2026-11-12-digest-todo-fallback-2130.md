# CONTRACT — digest-todo-fallback (D1b)
- date: 2026-11-12 | flow: feat | branch: feature/digest-todo-fallback (off develop d3d5e6c)
- status: active

## REQUEST (verbatim — IMMUTABLE)
D1b: every project TODO readable by the session digest. (1) hooks/session-start.sh `_digest_todo`: read a `## Actionable` or `### Actionable` heading (items = top-level `- [ ] ` lines until the next heading), and when that section is absent or holds no unchecked item, fall back to the first 3 top-level `- [ ] ` items of the whole file (indented sub-items never count); same `- todo:` line format, same 3 cap, bash 3.2 safe; tests in lib/tests/session-digest.test.sh (Actionable present, `##` level, absent → fallback, empty section → fallback, indented items ignored, HTML comment items ignored like _digest_journal). (2) skills/init-project/SKILL.md:118 seed becomes `# TODO\n\n## Actionable\n<!-- next items; the session digest shows the first 3 unchecked (else the first 3 of the file) -->\n\n## <date>\n`; skills/onboard/SKILL.md STEP 9 format emits the same `## Actionable` block + comment right under the `# TODO — onboard backlog` title (P0 section unchanged, the fallback then shows P0 items). (3) CLAUDE.global.md "Session start" step 1: drop the instruction to Read `.claude/tasks/TODO.md` at session start (the digest carries open BLK, actionable TODO and last journal); keep "Read TODO.md when the task needs it"; grep and patch every citer (skills/capitalize/SKILL.md:375 cited by D1, doctrine-citers census). NOT in scope here: the per-repo migration (done after merge on chore branches, insert-only empty `## Actionable` under each repo's H1 because feature branches in game/faunosteo edit TODO.md and a content move would conflict).

(user brief 2026-11-12 block D: "le digest replie sur les premiers items si `### Actionable` manque ; templates init-project et onboard émettent le titre ; migrer les TODO des repos locaux ... puis retirer la ligne doctrine Session start (le digest suffit), census des citers".)

## CLARIFICATIONS
- [gated 2026-11-12, orchestrator per user brief "decision not listed: take it, note it"] migration = insert-only empty `## Actionable` + comment under each repo's H1 (conflict-free with active feature branches editing TODO.md); the fallback covers empty sections.
- [gated] new Session start step 1 text: "The banner's `memory digest` lists open blockers, the first unchecked TODO items (`## Actionable`, else the file's first) and the last journal line: apply them before touching anything; a `- open: +N` line → read those entries in `blockers.md`. No digest (foreign repo, memory mod off) → read `.claude/tasks/TODO.md` and list the open blockers yourself." Step 2 adds `.claude/tasks/TODO.md` to what is read when the task needs it.
- [gated] capitalize:375 closing line: "Next session: the startup digest (open blockers, actionable TODO, last journal line)."

## ACCEPTANCE CRITERIA
1. (r2: plus the `- todo: +N not shown, read .claude/tasks/TODO.md` marker when the 800 cap drops todo lines; headings inside comments ignored; regex `/^###? Actionable([ \t\r]|$)/`) `_digest_todo` reads `## Actionable` and `### Actionable` sections; absent or no unchecked item → first 3 top-level `- [ ] ` of the file; indented items and items inside `<!-- -->` blocks never count.
   CHECK: bash lib/tests/session-digest.test.sh 2>&1 | tail -1
   EXPECT: , 0 failed
   EVIDENCE: MET exit=0 marker-found :: session-digest: 70 passed, 0 failed
2. init-project seed and onboard STEP 9 format carry `## Actionable` + the comment line.
   CHECK: echo $(grep -c '^## Actionable' skills/onboard/SKILL.md)$(grep -c 'Actionable' skills/init-project/SKILL.md | grep -c '^[1-9]')
   EXPECT: 11
   EVIDENCE: MET exit=0 marker-found :: 11
3. CLAUDE.global.md Session start no longer orders a Read of TODO.md at start; capitalize:375 updated; doctrine-citers census green.
   CHECK: echo $(grep -c '^1\. Read `.claude/tasks/TODO.md`' CLAUDE.global.md)$(grep -c 'Next session: TODO.md' skills/capitalize/SKILL.md)
   EXPECT: 00
   EVIDENCE: MET exit=0 marker-found :: 00
4. Citers census + shellcheck on session-start.sh.
   CHECK: bash lib/tests/doctrine-citers.test.sh >/dev/null 2>&1 && shellcheck -S warning hooks/session-start.sh lib/tests/session-digest.test.sh && echo SC-OK
   EXPECT: SC-OK
   EVIDENCE: MET exit=0 marker-found :: SC-OK
5. make test green with bun on PATH (manual: exceeds 120 s gate timeout).
6. Limits: changed functions ≤ 25 logic lines, added lines ≤ 80 cols; bash 3.2 safe (SD11 stays green).

## FILE SCOPE
hooks/session-start.sh, lib/tests/session-digest.test.sh, skills/init-project/SKILL.md, skills/onboard/SKILL.md, CLAUDE.global.md, skills/capitalize/SKILL.md (:375 line + :83 seed). README.md/USAGE.md digest bullets → STEP 6 doc sync.
