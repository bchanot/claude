# FIX — digest-journal-comment (/hotfix, 2026-11-09)

Contract: .claude/tasks/contracts/2026-11-09-digest-journal-comment-1810.md

## Root cause
hooks/session-start.sh `_digest_journal`:
```bash
last=$(grep '^- ' "$1/.claude/memory/journal.md" | tail -1)
```
picks the last `- ` line of the file, including the example bullets inside the template's HTML comment (templates/memory/journal.md:14-22: `<!-- Append new date-heading entries below. Template:` … `- <line 1>` `- <line 2>` `- <line 3-5 max>` … `-->`). `memory.sh journal` appends real entries AFTER that comment, so the bug shows only until the first write.

## Edit 1 — hooks/session-start.sh `_digest_journal`
Replace the grep line with an awk that tracks HTML comment BLOCKS (r2 after challenge: opener anchored to line start, CommonMark rule; an inline `<!--` inside a bullet is text, not a block):
```bash
  last=$(awk '/^[ \t]*<!--/ { c = 1 } !c && /^- / { l = $0 } /-->/ { c = 0 }
    END { if (!c) print l }' "$1/.claude/memory/journal.md")
```
A block opens only on a line that starts with `<!--` (after optional blanks); bullets start with `- ` so they never open one. A single-line `<!-- x -->` opens and closes on the same line. An unclosed block at EOF prints nothing (END guard). `[ -n "$last" ] && echo …` unchanged: empty → no journal line. Missing file: awk prints an error to stderr and nothing to stdout, same as grep did (the hook runs with stderr not shown in the digest; unchanged behavior).

## Edit 2 — lib/tests/session-digest.test.sh new case SD18 (before SD15, which must stay last)
```bash
# SD18: a journal born from the template prints no journal line (the
# example bullets sit in an HTML comment); a real entry appended after the
# comment is the one shown (G3, code-clean 2026-11-09)
p=$(mkproj sd18)
cp "$ROOT/templates/memory/journal.md" "$p/.claude/memory/journal.md"
check SD18-template-no-journal "$(run "$p" "$WORK/startup.json" | digest | grep -c '^- journal:')" 0
printf '\n## 2026-11-09\n\n- real entry\n' >> "$p/.claude/memory/journal.md"
check SD18-real-entry "$(run "$p" "$WORK/startup.json" | digest | grep '^- journal:')" '- journal: real entry'
printf -- '- note on `<!--` parser\n- newest\n' >> "$p/.claude/memory/journal.md"
check SD18-inline-marker "$(run "$p" "$WORK/startup.json" | digest | grep '^- journal:')" '- journal: newest'
```
Red before the fix: SD18-template-no-journal gets 1 (prints `- journal: <line 3-5 max>`).
Note: with no BLK, no TODO and no journal line, the digest block may be absent entirely; `grep -c` then prints 0 (exit 1 ignored inside $()), which is the wanted result.

## Edge cases
- Comment block with no closing `-->`: everything after is comment and END prints nothing (no stale line).
- Inline `<!--` inside a bullet (in backticks or not): not a block opener (anchored regex); covered by SD18-inline-marker.

## Edit 3 — bookkeeping (orchestrator, not the executor)
.claude/audits/BUGS-FOUND.md, under the G3 entry ("hooks/session-start.sh:404-408 (`_digest_journal`)…"): add a continuation line `  FIXED 2026-11-09 (/hotfix, bugfix/digest-journal-comment): the digest skips HTML comment blocks (opener anchored at line start); the template stays byte-identical (copied by onboarder/init-project/memory.sh), so "fix template and digest together" was not needed.`
- Real bullets before the comment (v1 journals that put entries above): still captured (c=0 before the comment).
- Template unchanged (criterion 1 checks `git diff --quiet develop -- templates/memory/journal.md`).
