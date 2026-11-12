# PLAN — digest-todo-fallback (r1)
Contract: .claude/tasks/contracts/2026-11-12-digest-todo-fallback-2130.md

## Files
- hooks/session-start.sh:329-333 `_digest_todo` — one awk program over TODO.md:
  - track HTML comment blocks like `_digest_journal` (opener `^[ \t]*<!--` sets c, `-->` clears c; lines while c never count);
  - `/^#{2,3} Actionable([ \t]|$)/` (use `^##+ Actionable` portable form `/^###? Actionable/` for mawk/BSD awk: no `{2,3}` intervals) → on=1, next; any other `^#` line → on=0;
  - a top-level item = line matching `^- \[ \] ` (no leading space); in section → append to `a[]` (max 3); always → append to `f[]` (max 3);
  - END: print a[] when it holds ≥ 1, else f[]; each as `- todo: <text>`.
  - comment the function: "<root> → first 3 unchecked Actionable items, else the file's first 3".
- lib/tests/session-digest.test.sh: SD5 flips: TODO without Actionable → `- todo: hidden` shown (fallback); new SD5b `## Actionable` level read; SD5c empty Actionable section (only `- [x]`) → fallback to the file's first unchecked; SD5d indented `  - [ ] sub` never counts (section and fallback); SD5e items inside `<!-- -->` never count (template comment line with `- [ ]` inside); SD1 unchanged (### Actionable, `### Later` item not shown).
- skills/init-project/SKILL.md:118 printf seed → `'# TODO\n\n## Actionable\n<!-- next items; the session digest shows the first 3 unchecked (else the first 3 of the file) -->\n\n## %s\n'` (wrap at 80 if needed with a second printf or a variable).
- skills/onboard/SKILL.md STEP 9 format block: insert under `# TODO — onboard backlog (<date>)` (before the generated comment): `## Actionable` + the same comment line + blank line; the "append with separator" variant gets the same block under `# Onboard backlog (généré le …)`? NO: an appended backlog under an existing TODO must not add a 2nd Actionable heading → only when the file is created fresh; state that in one sentence.
- CLAUDE.global.md:52-61 per CLARIFICATION 2 (line count must not grow: CLAUDE.global.md density budget; keep ≤ current lines).
- skills/capitalize/SKILL.md:375 per CLARIFICATION 3.

## Edge cases
- `### Actionable` heading followed by `#### sub` heading: on=0 at sub (same as today; documented).
- TODO.md absent → awk prints nothing, error to /dev/null (today the call site already drops stderr? verify `_memory_digest` guards `[ -f ]`; if not, add `[ -f "$1/.claude/tasks/TODO.md" ] || return 0`).
- CRLF lines: unchanged behavior (out of scope).
- Fallback items from a DONE section with unchecked boxes are shown (accepted: first unchecked in file order).

## Tests
session-digest.test.sh SD5 flip + SD5b-e; SD7/SD7b (800-cap) unchanged.

## Disposition
honors BDR-125 4c (digest = open BLK + actionable TODO + last journal, never per turn), LRN-034 (verify state), D1 decision (TODO read at start kept until D1b, now dropped), BDR-022 (no .claude content in public docs).

## r2 (3 lenses: correctness CONCERNS(4), robustness CONCERNS(3), simplicity CONCERNS(1); no BLOCKER) — r2 wins over r1
- Regex pinned: `/^###? Actionable([ \t\r]|$)/` (mawk/gawk/busybox checked by the simplicity lens; `\r` keeps today's CRLF match). The other forms in r1 are void.
- Comment tracking (`<!--` at line start opens, `-->` closes, as `_digest_journal`) gates BOTH the heading rules and the item rule: inside a comment no heading toggles the section and no item counts.
- Overflow marker: `_digest_assemble` reserves room for one fixed line `- todo: +N not shown, read .claude/tasks/TODO.md` and prints it whenever the 800 cap dropped ≥ 1 todo line (N = dropped count). `_digest_todo` itself still emits at most 3 items. Header comment of `_digest_assemble` updated. SD7 and SD7b updated to expect the marker.
- Discriminating fixtures (session-digest.test.sh):
  - SD5 flipped: TODO without Actionable → `- todo: hidden` (fallback).
  - SD5b: `### Backlog\n- [ ] early\n## Actionable\n- [ ] act\n` → only `- todo: act` (section wins over earlier items; `##` level).
  - SD5c: `## Actionable\n- [x] done\n\n## Later\n- [ ] fb1\n- [ ] fb2\n` → fallback `fb1`, `fb2`.
  - SD5d: indented `  - [ ] sub` never counts (section and fallback).
  - SD5e: multi-line comment `<!--\n- [ ] ghost\n### Actionable\n-->\n- [ ] real` → only `- todo: real` in fallback mode; and the same ghost block inside a real `## Actionable` section → only that section's real item; a `# x` line inside a comment inside the section does not end it.
  - SD5f: `#### Actionable` and `### Actionables` are not sections (fallback).
- TODO.md absent: handled by the call site (`2>/dev/null`, :389); no guard added.
- init-project:118 stays ONE guarded command (`[ -f … ] || printf '<fmt>' "$(date …)" > …`), long line accepted (file style); never a second unguarded printf. AC6's 80-col limit = code files (session-start.sh, the test).
- capitalize:83 seed gets the same `## Actionable` + comment format (same file as :375). onboarder.md stub left as is (fallback covers it; FILE SCOPE stays ≤ 5 code files) — stated in the plan, not hidden.
- onboard STEP 9 sentence keyed on its own condition: "no user content (the onboarder stub counts as none) → write the full format, `## Actionable` block included; existing user content → append the backlog under the separator WITHOUT a second `## Actionable`".
- Order: hook + tests first, run `bash lib/tests/session-digest.test.sh` green, THEN CLAUDE.global.md and capitalize (both are live machine-wide through ~/.claude links).
- Oracles fixed in the contract (AC1 EXPECT `, 0 failed`, AC4 census gated with `&&`, shellcheck `-S warning` because SC2001 at :175 is pre-existing style).

## r3 (confirmation CONCERNS(1), no BLOCKER; folded, no further challenge) — r3 wins over r2
- SD5e fallback half: `- [ ] first` + ghost block (`<!--\n- [ ] ghost\n### Actionable\n-->`) + `- [ ] real` → expects `first`, `real` (an ungated heading would make `real` the only section item). SD5f: `- [ ] first\n#### Actionable\n- [ ] x\n### Actionables\n- [ ] y` → expects `first`, `x`, `y`. Fixtures written with `printf --` or `printf '%s\n'` (a format starting with `-` is rejected by bash printf).
- SD5c gets 4 fallback items, expects exactly 3 (fallback cap pinned).
- Marker reserved ONLY when the todos do not all fit: first try all todos under 800; if one drops, rebuild with room for the marker line (`- todo: +N not shown, read .claude/tasks/TODO.md`) and print it. SD7/SD7b expect the marker; new SD7c: a block whose 3 todos fit between 751 and 800 chars prints all 3 and no marker.
- Doctrine wording (CLARIFICATION 2 amended, orchestrator under the user brief): "a `- open: +N` line → read those entries in `blockers.md`".
- capitalize:83 becomes the same GUARDED one-liner as init-project:118 (`[ -f .claude/tasks/TODO.md ] || printf '<same fmt>' "$(date +%Y-%m-%d)" > .claude/tasks/TODO.md`).
