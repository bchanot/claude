# PLAN — index-fail-closed (BDR-125 gap audit A3, BUGS-FOUND:87)

## DIAGNOSIS
BUG: session digest prints `- open: none` when blockers.md is a directory,
a FIFO, unreadable, or when the index emits unparsable `| BLK-` rows: a
false all-clear.
ROOT CAUSE:
1. lib/memory.sh:594-603 `memory_index`: `[ -f "$file" ] || continue`
   treats a present non-regular registry like an absent one; the awk rc of
   `_mem_index_rows` is dropped (the function's rc is the trailing `echo`).
   So `memory.sh index blocker` exits 0 with no rows.
2. hooks/session-start.sh:331-351 `_digest_blockers`: a `| BLK-` row whose
   fields do not parse is skipped (`continue`), so malformed output with
   rc 0 also ends as `- open: none`.
EVIDENCE: SD9b (stub prints malformed rows, rc 0) and SD9c (blockers.md is a
directory) both pin `- open: none` today (lib/tests/session-digest.test.sh:
206-213). BUGS-FOUND.md:87 states the same.
RELATED MEMORY: BDR-147/BDR-144 (digest is the start-of-session source:
a false none hides blockers, so fail closed honors them); CLAUDE.global.md
"`- open: unknown` → read blockers.md yourself" (the existing line is the
fail-closed output, reused verbatim, no new public string); LRN-274/LRN-233
(pipefail callers, capture output). No BLK names this cause.

## FIX PLAN
1. lib/memory.sh `memory_index`:
   - `[ -e "$file" ] || continue` (absent stays silent, as today; a
     dangling symlink counts as absent: `-e` false).
   - present but not (`-f` and `-r`) → `echo "memory: $file: not a readable
     regular file" >&2; return 1` (never opens it: a FIFO cannot block).
   - `_mem_index_rows "$file" "${spec#* }" || return 1`.
   Applies to every kind (`index` with no kind too): a bad registry fails
   the whole call, the callers (digest, prune-memory, memory-feedback) then
   say unknown instead of reading a partial table.
2. hooks/session-start.sh `_digest_blockers`: buffer the `- open: BLK…`
   lines in a local variable instead of echoing inside the loop; a `| BLK-`
   row that does not split into id | date | title | status (the existing
   `[[ "$rest" == *" | "* ]] || continue` branch) → print the existing
   `- open: unknown (memory.sh index failed)` line and `return 0`. Only on
   a clean pass print the buffered lines, then the none/more lines as today.
   Banner and exit code unchanged (rc 0).
3. Tests:
   - lib/tests/session-digest.test.sh SD9b-none → SD9b-unknown (exact
     unknown line, count 1, and `- open: none` count 0); SD9c-none →
     SD9c-unknown likewise. New SD9f: blockers.md is a FIFO (mkfifo in the
     test temp project) → unknown line, run returns (bounded by the
     harness's existing timeout), rc 0. New SD9g: blockers.md mode 000 →
     unknown, skipped with a SKIP line when `id -u` is 0.
   - lib/tests/memory.test.sh: new T-index-dir: `index blocker` with
     blockers.md a directory → rc 1 and stderr names the file; T-index-ok
     unchanged rows still rc 0 (existing T1f covers it).
   - Fix the stale comment at session-digest.test.sh:245 only if it is the
     SD9 block (it is not: out of scope, C5 handles it).

RISK: low. A caller that relied on rc 0 with a broken registry now gets
rc 1; grep shows the only runtime caller is the digest (already handles
non-zero). Skill callers run it interactively and print the error.

## FILES
lib/memory.sh, hooks/session-start.sh, lib/tests/session-digest.test.sh,
lib/tests/memory.test.sh.

## r2 (challenge r1: correctness CONCERNS(1), robustness CONCERNS(2), simplicity SOLID) — SUPERSEDES FIX PLAN 1-3 and RISK above
BLOCKERs landed: (a) `index` with no kind is a live runtime caller
(mods/memory/hooks/register.ts:671, stdout dropped on rc != 0 at :657 →
recall blackout); (b) `-e` false ≠ absent (dangling symlink, unsearchable
.claude/memory). Minors folded: rc 2 per lib convention (memory.sh:528,598),
`-f` guard only and awk rc propagation tested by mode 000, no buffer in the
digest, SD9f replaced by a timed memory.test.sh FIFO case, explicit rc 0
asserts on healthy trees.

1. lib/memory.sh `memory_index` (extract a per-registry helper if the
   function passes 25 logic lines):
   - strict = a kind was named (`index blocker`); lax = no kind.
   - `.claude/memory` absent → every registry absent (silent, rc 0, as today).
   - `.claude/memory` present but not searchable (`! -x`) → BAD.
   - file absent = `! -e` AND `! -L` → silent skip (as today).
   - present but `! -f` (dir, FIFO, dangling symlink, socket) → BAD, never
     opened.
   - rows captured first: `rows=$(_mem_index_rows …)`; awk rc != 0 (mode 000:
     gawk exits 2) → BAD. Header and rows printed only after a clean read,
     so no partial table reaches stdout.
   - BAD → stderr `memory: <file>: not a readable regular file`; strict →
     `return 2`; lax → skip this registry, continue, final rc 0
     (register.ts keeps the healthy registries; it already reports bad files
     itself via tryRead).
2. hooks/session-start.sh `_digest_blockers`: the `[[ "$rest" == *" | "* ]]
   || continue` branch → `{ echo "- open: unknown (memory.sh index
   failed)"; return 0; }`. No buffering (real memory.sh never emits such a
   row; this guards version skew/stubs; an earlier printed BLK line plus
   unknown still fails closed). Empty or unknown status words stay "not
   open" (game has 14, config 3 empty-status rows from v1: treating them as
   unknown would flag every session) → residual in BUGS-FOUND.
3. Tests:
   session-digest.test.sh: SD9b → exact unknown line count 1 and
   `- open: none` count 0; SD9c (dir) → same; new SD9f dangling symlink
   blockers.md → unknown; SD9g blockers.md mode 000 → unknown; SD9h
   .claude/memory mode 600 (not searchable) → unknown, restore 700 after
   the run; SD9g/SD9h print SKIP when `id -u` is 0. chmod only on literal
   paths inside the test's own temp project, never -R.
   memory.test.sh: healthy `index blocker` rc 0 and healthy `index` rc 0
   (explicit); blockers.md a directory → `index blocker` rc 2 + stderr names
   blockers.md; same tree `index` (no kind) → rc 0, stderr warning, a
   learnings row still printed; blockers.md a FIFO (mkfifo in the test's
   mktemp dir) → `timeout 5 bash "$MEM" index blocker` rc 2 (not 124).
4. Out of the executor's scope, handled by the run's closing steps: README.md
   :167 / USAGE.md:220 wording (doc sync), BUGS-FOUND:87 marked FIXED + a new
   residual line (unknown/empty status words counted not-open; an unclosed
   ``` fence hides later entries with no banner warning).

RISK (corrected): runtime callers are the digest (`index blocker`, strict)
and register.ts (`index`, lax: unchanged rc 0, bad registry now skipped with
a stderr line instead of silently). Skill/agent callers (prune-memory with
a kind, memory-feedback without) get rc 2 / a stderr line on a broken
registry, which they print.

## r3 (re-challenge: correctness SOLID, robustness SOLID; minors folded) — amends r2
- Dir rule: `.claude/memory` present (`-e` or `-L`) but `! -d` or `! -x` →
  BAD with its own stderr line `memory: .claude/memory: not a searchable
  directory`; absent only when neither `-e` nor `-L` holds AND `.claude`
  (if present) is searchable, else BAD.
- Healthy output byte-identical: print a registry's table only after the
  read; rows printed only when non-empty (`[ -n "$rows" ] && printf
  '%s\n' "$rows"`), then the trailing blank line as today. Test: full
  `index` output on the shared healthy $FIX equals a capture taken with the
  pre-fix logic (store the expected text literally in the test).
- Usage line lib/memory.sh:12: name the contract `index [<kind>]` → with a
  kind rc 2 on an unreadable registry; without, bad registries skipped
  with a stderr line, rc 0.
- agents/handover-doc-writer.md:120: one sentence: `index decision` rc != 0
  → write `MEMORY: decisions reader unavailable` instead of an empty §6.1.
  (5th file in scope.)
- Test placement: SD9f/g/h each on its own `mkproj`, run with `run "$p" -`
  (real lib, as SD9c), never `"$S9"` (still the malformed stub). The
  memory.test.sh dir/FIFO/no-kind cases use their own `-C` subtree (pattern
  v1h, memory.test.sh:320) seeded with one BLK and one LRN entry; the shared
  $FIX blockers.md is never touched.
- Skip idiom: after chmod, SKIP when the read still works (`[ -r
  blockers.md ]` for SD9g, `[ -x .claude/memory ]` for SD9h), as
  push-guard.test.sh:220-222. SD9h restores 700 right after the run
  (`chmod 700 … || true`) AND in the EXIT trap before `rm -rf`.
- Residuals (BUGS-FOUND, closing step): empty/unknown status words counted
  not-open; unclosed ``` fence hides later entries without a banner line;
  `index` reads without the lock while `status`/`_mem_restore` rewrite in
  place (truncate then write, memory.sh:262,319): a racing digest can read
  an empty file.
FILES (final): lib/memory.sh, hooks/session-start.sh,
lib/tests/session-digest.test.sh, lib/tests/memory.test.sh,
agents/handover-doc-writer.md.
