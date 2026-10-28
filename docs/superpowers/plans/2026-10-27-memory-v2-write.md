# Memory v2 write side (phase 4a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lib/memory.sh` becomes the only writer of `.claude/memory` registries, one status parser and one classifier serve memory.sh and reconcile on v2 registries, this repo's registries move to v2 (no `## Index`), every citer writes through the lib.

**Architecture:** One sourceable bash lib on the `lib/project-rules.sh` skeleton (`-C <dir>`, verbs, rc 2 + named reason). The awk parser lives once in `_MEM_AWK` and is shared by `index`, `upgrade` and `lib/reconcile.sh` (v2 files). Writers serialize through a noclobber lock file in the git common dir. `memory-commit.sh` runs `check --staged` as the chokepoint. Revision r2 (2026-10-28) after a 3-lens challenge: FATAL(2) simplicity, CONCERNS(5) robustness, FATAL(6) correctness, every BLOCKER and MAJOR closed. Revision r3 (2026-10-28) after the confirmation round (CONCERNS(1) / CONCERNS(3) / CONCERNS(3), no BLOCKER): any-level ID allocation, open fence always refused, v1 status as a body line, one verified backup + trap for every writer, token lock with a serialized steal, exact journal key, staged-dir guard.

**Tech Stack:** bash 5, POSIX awk (no gawk-only features, no `{n}` intervals, no byte-count slicing around `—`), git. Tests via `make test`.

**Spec:** `docs/superpowers/specs/2026-10-27-memory-v2-write-design.md` (user-approved 2026-10-27). Contract: `.claude/tasks/contracts/2026-10-27-memory-v2-write-2030.md`.

**Reference implementation (proven r3):** `docs/superpowers/plans/memory-v2-write/` holds `memory.sh`, `memory.test.sh`, `blockers-v2-status.md`, `blockers-v1-dialects.md`. Proven on a `git clone --shared` of this repo through `make test`: suite `PASS=112 FAIL=0` five runs in a row and under `LC_ALL=C` (the 15 r3 checks T14* are red against the r2 lib, 12 of them), 12 concurrent writers starting from a stale lock: 0 overlaps, 12 distinct IDs, no lock left (3 rounds), shellcheck clean, no `# shellcheck disable`, no line over 80 chars. `upgrade` on a copy of this repo's live registries: oracle-green, `check`-green, idempotent, its diff `--staged`-green, 26 statuses and 129 dates materialized, one Index status dropped and named (BDR-012). Task 2, 3 and 4 code below was applied to that clone and run through `make test` (run-reconcile 28 GREEN / 1 RED where the red is T6c, the gitignored `skills/darwin-skill` absent from a clone; run-deterministic 18/18; memory suite with T13 122/122). `_mem_next_id` equals max heading ID + 1 on all 59 registries of the 15 repos on this machine (r2 gave BDR-001 / LRN-001 / BLK-001 on trucks_at_work's `###` registries: duplicates). Task 1 copies the files; do not rewrite them.

## Global Constraints

- Branch `feature/memory-v2-write` (already started, spec at cdc0a47). Never switch, never merge, never push by hand (hooks push).
- Our code: functions ≤ 25 logic lines (see Deviations for awk programs), ≤ 5 locals, ≤ 5 params, lines ≤ 80 chars in `lib/memory.sh`.
- No `# shellcheck disable` anywhere in the diff (floor guard, LRN-234). `# shellcheck source=/dev/null` directives are allowed.
- `/usr/bin/grep` pinned in libs (`MEM_GREP`, LRN-074); no `grep -q` reading a pipe under pipefail (LRN-189); no `sed -i`, `stat -c`, `realpath -m`, `grep -P` (portability census, BDR-110).
- No recursive delete through a variable except the existing `trap 'rm -rf "$FIX"' EXIT` mktemp pattern.
- Hermetic tests run through `make test [suite=…]` only.
- Census-cited strings stay byte-identical: every `CLAUDE.md "Memory registries" (Always English, always caveman)` citation, the CLAUDE.global.md heading `## Memory registries (\`.claude/memory/\`)` and the bold label `**Always English, always caveman**` (doctrine-citers, LRN-166). Do not rewrap a line that holds one.
- CLAUDE.global.md line count must not exceed 333 after the edit.
- Worked examples use fictional 9xx IDs (LRN-073).
- Entry text written to registries is English caveman (BDR-009).

## Deviations from the spec (named for the human gate)

1. **Lock and backup**: the lock is a file created under bash noclobber (`open(O_EXCL)`), not a `mkdir` dir: uutils `mkdir` 0.10 on this host is not atomic (5 concurrent adds lost 2-4 entries). It holds `<epoch> <pid>.<RANDOM>` and is removed only by its owner's token. A lock older than 30 s, or seen empty on 10 consecutive tries (holder died between create and write), is stolen by one waiter at a time (`memory.lock.steal`, itself noclobber, age re-read under it). Every writer (`add`, `status`, `journal`, `upgrade`) runs on a backup of its file verified by `cmp` (rc 2 before any write if the copy is short), restored on failure or on INT/TERM/HUP; the caller's own traps are saved and put back. No EXIT trap: a sourced lib must not own the caller's EXIT. **Residuals for the gate:** (a) a holder alive but slower than 30 s loses the lock to a stealer and both write (its token no longer matches, so it never removes the new lock); (b) a stealer that dies holding `memory.lock.steal` makes the next waiter clear it once older than 30 s; two waiters doing that at the same moment can both enter the steal section. Both need a crash or a 30 s stall; a write lost that way shows as a `check` culprit (duplicate ID) or a missing entry, never silently in v2.
2. **`journal` takes no `--date`**: `MEMORY_DATE` already pins the date for tests.
3. **`upgrade` body wins**: an Index status reaches the body only when the body has none, or when the Index says superseded/deprecated and the body does not. Every other conflicting Index status is dropped and named on stderr (`memory: BDR-012: kept body shipped, dropped Index accepted`, the only one on this repo).
4. **Status word**: a lib-written `**Status (YYYY-MM-DD…)**:` line reads its leading word (`status` requires the text to start with one: "open, reopened by abc"); other labelled lines rank words in `_MEM_WORDS` order, `open` last ("accepted. check OPEN" = accepted). A heading candidate is its `[tag]` only, never the title.
5. **One classifier on v2, the lexical reader kept on v1**: on a v2 registry reconcile classifies by word (`memory_closed`: resolved | superseded | deprecated); `accepted` on a blocker stays open. On a v1 registry reconcile keeps today's lexical reader verbatim: the strict parser, measured on copies of all 13 other projects' blockers, changed the open set of 4 (config `— RESOLVED` title suffix, game `date: … · status:`, zenquality and angelscar356 `**Statut** :`); with the v1 branch the 13 sets are identical to today.
6. **Heading dialects**: `mem_key` accepts `## ID` followed by any non-alphanumeric char (` — `, ` - `, ` | `), so `status` and `--supersedes` work on v1 hyphen and pipe files. ID allocation reads every heading level, fenced or not (`### BDR-001` in trucks_at_work, a stray fence elsewhere), and a v1 add whose ID already sits in any heading is refused. `status` on a `###` registry stays rc 2 "no entry" (loud, not silent). A v1 `add --status s` writes `- **Status**: s` as the first body line instead of a heading tag: the v1 reconcile reader never reads the entry's own heading. The em-dash shape check is v2-only. `upgrade` refuses a non-em-dash file (`heading dialect " - ": not upgraded`) and a file without frontmatter; the banner says `memory.sh check`, never promises an upgrade.
7. **Journal template** carries no `format: 2`: journal.md is not a registry (`check` excludes it). Contract criterion 8 says "every `templates/memory/*.md`": the four registry templates.
8. **awk programs**: an embedded awk program counts as one statement toward the 25-logic-line limit (`_mem_upgrade_text`, `_mem_upgrade_oracle`, `_mem_index_rows` hold 20-30 awk lines). Splitting them would scatter one parser across files.
9. **`--staged` removal rule**: a removed line counts only from the first entry heading down (the spec said any `-` line). The Index sits above the first entry, so Task 7's upgrade commit goes through memory-commit like any memory commit; the diff runs with `-c diff.interHunkContext=0 --no-color --no-ext-diff --no-textconv` so user git config cannot fold or hide hunks. An open code fence always counts as a culprit, even when it predates the commit (it hides headings from allocation).

## Review Focus

1. **Concurrent writers.** The noclobber lock is proven by T6e/T6f (red with the mkdir lock on this host) and T14i (12 writers from a stale lock). Unlock by token (T14g), empty-lock steal (T14h). Every writer restores its verified backup on failure or signal and frees the lock. Residuals named in Deviation 1.
2. **Status words in prose and titles.** "fail-open", "`data:` OPEN", a title saying "DNS resolved", "open again, not resolved by abc": T10b/c/h/i and run-reconcile T8a/b.
3. **Index-only facts at upgrade.** 13 BDR statuses, BDR-038 + BLK-019/020 + 12 LRN supersessions, 129 dates; a stale Index (BDR-012) never overwrites the body and is named. BLK-019/020 must read closed after Task 7 (superseded).
4. **v1 projects keep working.** 13 other repos run this lib through `~/.claude/lib`: v1 writes are lenient, `check` never fails on v1, `--staged` ignores v1, reconcile on v1 is byte-for-byte today's reader (Deviation 5), `status` works on hyphen and pipe headings (T10m-o).
5. **The chokepoint never blocks a legitimate commit.** Only NEW culprits count (a duplicate a merge left behind blocks neither `add` nor a staged append: T7i-k), except an open code fence, which always blocks until fixed (T14e/f); the upgrade commit passes (Index lines sit above the first entry); a refused commit leaves nothing staged.

---

### Task 1: lib/memory.sh, its suite and the parser fixtures

**Files:**
- Create: `lib/memory.sh` (copy of `docs/superpowers/plans/memory-v2-write/memory.sh`)
- Create: `lib/tests/memory.test.sh` (copy of `…/memory.test.sh`)
- Create: `lib/tests/fixtures/blockers-v2-status.md` (copy of `…/blockers-v2-status.md`)
- Create: `lib/tests/fixtures/blockers-v1-dialects.md` (copy of `…/blockers-v1-dialects.md`; used by Task 2)

**Interfaces (produced, used by Tasks 2-7):** `memory_entry_status <file> <ID>` (winning candidate: `[tag]` or the labelled line; rc 1 if none), `memory_status_word <line>` (status word or first 40 chars), `memory_closed <word>` (rc 0 for resolved | superseded | deprecated), `memory_is_v2 <file>`, `memory_check [--staged] [<dir>]` (prints `memory: v1: <file>` per v1 registry on stderr, the banner's input), `memory_add`, `memory_status`, `memory_journal`, `memory_index`, `memory_upgrade`. CLI: `bash lib/memory.sh [-C dir] add|status|journal|index|check|upgrade …`. Env: `MEMORY_DATE`, `MEM_GREP`, `MEM_LOCK_TRIES`.

- [ ] **Step 1: Copy the four files**

```bash
cp docs/superpowers/plans/memory-v2-write/memory.sh lib/memory.sh
cp docs/superpowers/plans/memory-v2-write/memory.test.sh lib/tests/memory.test.sh
cp docs/superpowers/plans/memory-v2-write/blockers-v2-status.md lib/tests/fixtures/blockers-v2-status.md
cp docs/superpowers/plans/memory-v2-write/blockers-v1-dialects.md lib/tests/fixtures/blockers-v1-dialects.md
chmod +x lib/memory.sh lib/tests/memory.test.sh
```

- [ ] **Step 2: Run the suite and the static checks**

Run: `make test suite=lib/tests/memory.test.sh` three times → each ends `PASS=112 FAIL=0` and `all suites green` (T6e and T14i races must be stable).
Run: `shellcheck lib/memory.sh lib/tests/memory.test.sh && awk 'length > 80' lib/memory.sh` → no output after shellcheck.
Run: `make test suite=lib/tests/portability-census.test.sh` → green.

- [ ] **Step 3: Commit**

```bash
git add lib/memory.sh lib/tests/memory.test.sh lib/tests/fixtures/blockers-v2-status.md lib/tests/fixtures/blockers-v1-dialects.md
git commit -m "feat(memory): lib/memory.sh single registry writer — add/status/journal/index/check/upgrade, shared status parser, noclobber lock"
```

---

### Task 2: reconcile reads v2 status through the shared parser and classifier

**Files:**
- Modify: `lib/reconcile.sh` (source line after `RECONCILE_GREP=`; `reconcile_blk_current_status` and `reconcile_blk_open` with their comments)
- Modify: `lib/tests/run-reconcile.sh` (T8 block before the final summary line)
- Modify: `skills/reconcile/SKILL.md:25` and `:54`

**Interfaces:** consumes `memory_is_v2`, `memory_entry_status`, `memory_status_word`, `memory_closed`. `reconcile_blk_current_status` and `reconcile_blk_open` keep their signatures.

- [ ] **Step 1: Write the failing test** — insert before the `echo; echo "================  $pass GREEN` line of `lib/tests/run-reconcile.sh`:

```bash
echo; echo "=== T8 shared parser — header [tag] + labelled lines, prose never (BLK-032..034) ==="
v2="$FIX/blockers-v2-status.md"
open_v2=$(reconcile_blk_open "$v2" | cut -f1 | sort | tr '\n' ' ')
if [ "$open_v2" = "BLK-040 BLK-041 BLK-042 BLK-043 BLK-044 " ]; then ok "T8a open = {040..044}: 032..034 and 008 closed, accepted stays open"; else no "T8a open = [$open_v2], expected {040,041,042,043,044}"; fi
case "$(reconcile_blk_current_status "$v2" BLK-034)" in
  '[resolved]') ok "T8b BLK-034 status = its own header tag, title never read";;
  *) no "T8b BLK-034 read from prose (fail-open), not the header tag";;
esac
v1d="$FIX/blockers-v1-dialects.md"
open_v1=$(reconcile_blk_open "$v1d" | cut -f1 | tr '\n' ' ')
if [ "$open_v1" = "BLK-002 " ]; then ok "T8c v1 hyphen and pipe headings still parsed"; else no "T8c v1 dialects open = [$open_v1], expected {002}"; fi
v1w=$(mktemp -d)
mkdir "$v1w/.claude" "$v1w/.claude/memory"
printf '# Blockers\n' > "$v1w/.claude/memory/blockers.md"
printf -- '- **Cause**: `x`\n' > "$v1w/b.md"
bash "$REPO/memory.sh" -C "$v1w" add blocker --title fixed \
  --body-file "$v1w/b.md" --status resolved >/dev/null 2>&1
open_v1w=$(reconcile_blk_open "$v1w/.claude/memory/blockers.md" | cut -f1)
if [ -z "$open_v1w" ]; then ok "T8d lib-written v1 blocker --status resolved reads closed"; else no "T8d lib-written v1 blocker reads open [$open_v1w]"; fi
rm -f "$v1w/.claude/memory/blockers.md" "$v1w/b.md"
rmdir "$v1w/.claude/memory" "$v1w/.claude" "$v1w"
```

- [ ] **Step 2: Run, expect red** — `make test suite=lib/tests/run-reconcile.sh` → T8a and T8b red (today: 032..034 open, BLK-034 read from prose).

- [ ] **Step 3: Implement** — in `lib/reconcile.sh`, right after the `RECONCILE_GREP=…` line add:

```bash
# the status parser and classifier are shared with lib/memory.sh (BDR-125 4a)
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/memory.sh"
```

Replace everything from the comment `# --- registry status: LAST status-bearing line wins …` through the closing `}` of `reconcile_blk_open` by:

```bash
# --- registry status: LAST candidate wins (the BLK-008 trap A fell into) ---
# $1 blockers file, $2 id. A v2 registry (lib/memory.sh): the entry's own
# header `[tag]` or a labelled body line, never a status word in prose or in
# the title (the BLK-032..034 false-open). A v1 registry keeps the lexical
# reader below: its dialects (title suffix `— RESOLVED`, `date: … · status:`,
# `**Statut** :`) carry status where the strict parser cannot see it.
reconcile_blk_current_status() {
  if memory_is_v2 "$1"; then memory_entry_status "$1" "$2"; return; fi
  # v1: drop ALL `## BLK-` header lines first: the range is inclusive of the
  # NEXT entry's header, and a sibling header may carry a status word.
  sed -n "/^## ${2} /,/^## BLK-/p" "$1" \
    | "$RECONCILE_GREP" -v '^## BLK-' \
    | "$RECONCILE_GREP" -iE 'status|RESOLVED|REVERTED|upstream|resolved|[^a-z]open' \
    | tail -1
}
# blockers whose CURRENT status does not close them → "id<TAB>status".
# v2: memory_closed (resolved | superseded | deprecated); v1: the substring.
reconcile_blk_open() {
  local id st v2=""
  memory_is_v2 "$1" && v2=1
  for id in $(reconcile_enumerate_ids "$1" BLK); do
    st=$(reconcile_blk_current_status "$1" "$id")
    if [ -n "$v2" ]; then
      memory_closed "$(memory_status_word "$st")" && continue
    else
      case "$st" in *RESOLVED*|*resolved*) continue ;; esac
    fi
    printf '%s\t%s\n' "$id" "$st"
  done
}
```

Header comment: insert one line right after line 12 (`# preaches — the recursive-coherence test (run-reconcile.sh T1) reds if this is broken.`): `# v2 registries carry no Index at all (lib/memory.sh); v1 ones still may.`

- [ ] **Step 4: Run, expect green** — `make test suite=lib/tests/run-reconcile.sh` → `29 GREEN / 0 RED` (T1-T7 unchanged, T8a/b/c/d green; T8d is red against the r2 lib, which put the status in the heading tag the v1 reader drops). `make test suite=lib/tests/run-review-guards.sh` → green (G4: T8 reads fixtures only).

- [ ] **Step 5: Skill lines** — `skills/reconcile/SKILL.md:54`: `→ 25/25,` → `→ 29/29,`. `skills/reconcile/SKILL.md:25`: replace `` (`reconcile_oracle_*`, `reconcile_blk_current_status` = last block wins) `` by `` (`reconcile_oracle_*`, `reconcile_blk_current_status` = last candidate wins: header `[tag]` or a labelled status line on a v2 registry via `lib/memory.sh`, today's lexical reader on v1) ``.

- [ ] **Step 6: Commit**

```bash
git add lib/reconcile.sh lib/tests/run-reconcile.sh skills/reconcile/SKILL.md
git commit -m "fix(reconcile): v2 blocker status through the shared memory.sh parser and classifier — BLK-032..034 no longer false-open; v1 reader unchanged"
```

---

### Task 3: memory-commit.sh refuses a staged in-place edit or new culprit (rc 6)

**Files:**
- Modify: `lib/memory-commit.sh` (usage comment, `MC_MEMORY_SH`, `commit_memory` right after `git add`)
- Modify: `lib/tests/run-deterministic.sh` (block before the final `echo` + `printf 'RESULT: …'`)
- Modify: `lib/capitalize-commit.md` (rc table)

- [ ] **Step 1: Write the failing tests** — insert right before the final `echo` / `printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"` lines of `lib/tests/run-deterministic.sh`:

```bash
echo "== check --staged chokepoint (v2 registry, phase 4a)"
d="$(new_repo)"
printf -- '---\nformat: 2\ntype: decisions_registry\nentry_prefix: BDR\n---\n\n## BDR-001 — kept (2026-10-27)\n- **Status**: accepted\n' \
  > "$d/.claude/memory/decisions.md"
git -C "$d" add -A && git -C "$d" commit -qm v2
head_before=$(git -C "$d" rev-parse HEAD)
sed 's/kept/rewritten/' "$d/.claude/memory/decisions.md" > "$d/x.tmp" \
  && cat "$d/x.tmp" > "$d/.claude/memory/decisions.md"
out="$(cd "$d" && bash "$HELPER" commit "chore(memory): bad" 2>/dev/null)"; rc=$?
staged="$(git -C "$d" diff --cached --name-only)"
if [ "$rc" -eq 6 ] && [ -z "$out" ] && [ -z "$staged" ] && [ "$(git -C "$d" rev-parse HEAD)" = "$head_before" ]; then ok "in-place edit of a v2 entry → rc 6, nothing committed, nothing staged"; else ko "rc=$rc out=[$out] staged=[$staged] — in-place edit committed or left staged"; fi
git -C "$d" checkout -q HEAD -- .claude/memory/decisions.md
printf '\n## BDR-002 — added (2026-10-27)\nbody\n' >> "$d/.claude/memory/decisions.md"
out="$(cd "$d" && bash "$HELPER" commit "chore(memory): BDR-002" 2>/dev/null)"; rc=$?
if [ "$rc" -eq 0 ] && [ -n "$out" ]; then ok "append to a v2 registry → committed"; else ko "append refused rc=$rc"; fi
```

(Existing tests write `baseline` registries with no frontmatter: v1, skipped by the check, unchanged and green.)

- [ ] **Step 2: Run, expect red** — `make test suite=lib/tests/run-deterministic.sh` → the rc 6 test fails (today rc 0, the edit is committed).

- [ ] **Step 3: Implement** — in `lib/memory-commit.sh`:
  - after `MC_PATHS=(".claude/memory" ".claude/tasks")` add `MC_MEMORY_SH="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/memory.sh"`;
  - in `commit_memory`, right after `git add -- "${changed[@]}"`, insert:

```bash
  # Chokepoint (BDR-125 phase 4a): a staged v2 registry may only grow and
  # never gains a new culprit (duplicate ID, bad heading, open fence). v1
  # registries are skipped. Unstage on refusal so no later plain commit
  # sweeps the refused change in.
  if [ -d .claude/memory ] \
    && ! bash "$MC_MEMORY_SH" check --staged .claude/memory; then
    git reset -q -- "${changed[@]}"
    echo "memory-commit: REFUSED — memory.sh check --staged failed (above);" \
      "NOTHING committed, nothing left staged." >&2
    return 6
  fi
```

  - usage comment line becomes two lines: `#   memory-commit.sh commit "<message>"  # surgical commit; exit 0 ok/no-op, 3 unsafe` / `#                                        # state, 5 commit rejected, 6 check refused`.

- [ ] **Step 4: Run, expect green** — `make test suite=lib/tests/run-deterministic.sh` → `RESULT: 18 passed, 0 failed`.

- [ ] **Step 5: Document rc 5 and rc 6** — `lib/capitalize-commit.md` step 3 "Report by (rc, mem_hash)", after the `rc 3` bullet:

```
   - rc 5                     → `git commit` rejected (hook, protected branch,
                                signing); nothing committed, surface stderr.
   - rc 6                     → `memory.sh check --staged` refused, nothing
                                committed, nothing left staged. Two causes,
                                named on stderr: a line removed inside an
                                existing v2 entry (only appends pass), or a NEW
                                culprit (duplicate ID, heading shape); an open
                                code fence counts even when it predates the
                                commit. Fix the file, then commit the fix with
                                /commit-change; never bypass the helper.
```

- [ ] **Step 6: Commit**

```bash
git add lib/memory-commit.sh lib/tests/run-deterministic.sh lib/capitalize-commit.md
git commit -m "feat(memory): memory-commit refuses a staged in-place edit or new culprit in a v2 registry (rc 6, unstaged); rc 5/6 documented"
```

---

### Task 4: v2 templates and the registry v1 banner line

**Files:**
- Modify: `templates/memory/{decisions,learnings,blockers,evals}.md` (journal.md unchanged, Deviation 7)
- Modify: `hooks/session-start.sh` (before `# Version check: compare local vs remote (non-blocking)`)
- Modify: `lib/tests/memory.test.sh` (T13, before the final `echo "PASS=…"`)
- Modify: `agents/onboarder.md:126`

- [ ] **Step 1: Write the failing test** — insert before `echo "PASS=$pass FAIL=$fail"` in `lib/tests/memory.test.sh`:

```bash
# T13 templates are born v2; the session banner names a v1 project only
for t in decisions learnings blockers evals; do
  check "T13-template-$t-v2" "$(sed -n 2p "$ROOT/templates/memory/$t.md")" 'format: 2'
  check "T13b-template-$t-no-index" "$(grep -c '^## Index$' "$ROOT/templates/memory/$t.md")" 0
done
banner() { (cd "$1" && SESSION_START_OFFLINE=1 bash "$ROOT/hooks/session-start.sh" \
  </dev/null 2>/dev/null) | grep -c "${2:-registry v1}"; }
check T13c-banner-v1-v2 "$(banner "$FIX/v1h" 'registry v1: 1 file(s) (memory.sh check)')/$(banner "$FIX")" 1/0
cp "$FIX/v1h/.claude/memory/blockers.md" v1h.bak
printf -- '---\nformat: 2\n---\n' > "$FIX/v1h/.claude/memory/blockers.md"
check T13d-banner-flips-off "$(banner "$FIX/v1h")" 0
cat v1h.bak > "$FIX/v1h/.claude/memory/blockers.md"
```

(`$FIX/v1h` is the v1 pipe/hyphen project T10 built; `$FIX/.claude/memory` is v2. T13c reads both projects in one check (`1/0`), red until the banner exists; T13d turns the same v1 project v2 and expects the line gone. The hook resolves `memory.sh` next to itself, so the test exercises `$ROOT/lib/memory.sh`, never the installed copy.)

- [ ] **Step 2: Run, expect red** — `make test suite=lib/tests/memory.test.sh` → 9 checks red (the eight template checks and T13c); T13d is green before and after, it guards the flip-off once T13c is green.

- [ ] **Step 3: Templates** — in each of the four registry templates: insert `format: 2` as line 2 (right after the opening `---`); delete `## Index`, the blank line after it, the two table lines and the blank line after them; replace the `<!-- Append entries below. Template: … -->` comment by (shown for blockers; the heading line is indented two spaces so no line starts with `## `):

```
<!-- Written only by `bash ~/.claude/lib/memory.sh add blocker --title "<friction>"
--body-file <file> [--status open]` (it allocates the ID). Entry shape:

  ## BLK-NNN — <friction> [open] (YYYY-MM-DD)
  - **Friction**: <what was blocked>
  - **Real cause**: <root cause>
  - **Solution**: <workaround or fix>

Later status: `bash ~/.claude/lib/memory.sh status BLK-NNN "resolved <hash>"`.
-->
```

decisions → `decision`, `<title>`, `[accepted]`, labels Decision / Why / Rejected alternatives / Reference, later status `superseded by BDR-NNN`; learnings → `learning`, `<abstract pattern>`, no tag, labels Pattern / Context / Future application, no "Later status" line; evals → `eval`, `<output>`, `[keep]`, labels Output / Method / Anomalies / Action.

- [ ] **Step 4: Banner** — in `hooks/session-start.sh`, right before `# Version check: compare local vs remote (non-blocking)`:

```bash
# Registry v1 (BDR-125 phase 4a): a project registry without `format: 2`.
# The lib names each v1 registry on stderr (`memory: v1: <file>`).
_mem_lib="$(dirname "${BASH_SOURCE[0]}")/../lib/memory.sh"
if [ -f "$_mem_lib" ] && [ -d .claude/memory ]; then
  _v1=$(bash "$_mem_lib" check .claude/memory 2>&1 >/dev/null \
    | grep -c '^memory: v1:' || true)
  if [ "${_v1:-0}" -gt 0 ]; then
    printf "│  ⚠️  %-44s│\n" "registry v1: ${_v1} file(s) (memory.sh check)"
  fi
  unset _v1
fi
unset _mem_lib
```

- [ ] **Step 5: Onboarder line** — `agents/onboarder.md:126`: `(YAML schema + empty index + inline template comment)` → `(YAML schema with \`format: 2\` + inline template comment; no Index, entries go through \`lib/memory.sh\`)`.

- [ ] **Step 6: Run, expect green** — `make test suite=lib/tests/memory.test.sh` → `PASS=122 FAIL=0`. `make test suite=lib/tests/push-guard.test.sh` → green: its banner checks grep specific strings. From this task until Task 7 this repo's own banner shows `registry v1: 4 file(s) (memory.sh check)` (its registries are still v1); that is expected.

- [ ] **Step 7: Commit**

```bash
git add templates/memory hooks/session-start.sh lib/tests/memory.test.sh agents/onboarder.md
git commit -m "feat(memory): templates born v2 (format: 2, no Index); session banner names a v1 registry"
```

---

### Task 5: flows write through the lib (one WRITE section, cited everywhere)

**Files:** `lib/capitalize-commit.md` (new WRITE section), `skills/capitalize/SKILL.md` (STEP 2 `:143`, STEP 4 items 1-4, STEP 5 bullets, STEP 5B rc list), `skills/feat/SKILL.md:248`, `skills/bugfix/SKILL.md:275`, `skills/hotfix/SKILL.md:234`, `skills/ship-feature/SKILL.md:273-274`, `skills/init-project/SKILL.md:301-303`, `agents/commit-changer.md:220-223`, `skills/onboard/SKILL.md` S7, `lib/analyze-before-plan.md:42-43` and `:100-102`, `agents/analyzer.md:98-99`, `CLAUDE.global.md`.

- [ ] **Step 1: The one WRITE section** — in `lib/capitalize-commit.md`, first the intro: `Inline snippet. Include at the END of any dev flow's CAPITALIZE step, AFTER the` / `approved registry / journal / TODO entries are written. It commits ONLY the` → `Inline snippet for any dev flow's CAPITALIZE step: § WRITE says how the approved` / `registry and journal entries are written, then the rest commits ONLY the` (the two lines after it unchanged), and `decide WHAT to write are unchanged and run before this snippet. Only the COMMIT` / `of the already-approved entries is automated here.` → `decide WHAT to write are unchanged and run before this snippet; § WRITE then` / `writes them through lib/memory.sh and the COMMIT is automated here.`. Then insert before `## DO`:

```
## WRITE (before the commit)

Registry entries and journal lines are written only by `lib/memory.sh`,
never by Edit or append; there is no `## Index` to update.

- Entry: caveman body to a scratch file, then
  `bash "$HOME/.claude/lib/memory.sh" [-C <project root>] add
  <decision|learning|blocker|eval> --title "<title>" --body-file <file>
  [--status <status>] [--supersedes <ID>]`. One call per entry; it
  allocates the ID under a lock and prints it. A blocker body quotes ≥1
  error in backticks. `-C` when the cwd is not the project root.
- Status change on an existing entry:
  `bash "$HOME/.claude/lib/memory.sh" status <ID> "<word> …"`, the text
  starting with a status word (`resolved abc1234`, `open, reopened by …`,
  `superseded by BDR-NNN`).
- Journal: `bash "$HOME/.claude/lib/memory.sh" journal "<line>"`.
- rc 2 names its reason (title chars, empty body, a status not starting
  with a status word, an open code fence in the body or the registry,
  unknown ID, lock busy): fix the input and re-run.
```

- [ ] **Step 2: capitalize**
  - `:143` `(Index + bodies)` → `(headings + bodies)`.
  - STEP 4 items 1-4 (from `1. Read the target registry file.` through `match that file's header row).`) → one item: `1. Write each approved entry per \`lib/capitalize-commit.md\` § WRITE (\`memory.sh add\`, one call each; a resolved blocker: \`memory.sh status <ID> "resolved <hash>"\`).` Old item 5 (caveman) stays, renumbered 2.
  - STEP 5: the two bullets `- Heading exists → append a bullet.` / `- Missing → create …` → `- \`bash "$HOME/.claude/lib/memory.sh" journal "<line>"\` per bullet (it creates today's heading when missing).`
  - STEP 5B step 3: after the `**rc 3**` bullet add `- **rc 5 / rc 6** → nothing committed; surface the helper's stderr; meaning and recovery in \`lib/capitalize-commit.md\` (rc 6: fix the registry, then /commit-change). STEP 6 says NOT committed.`

- [ ] **Step 3: flow citations** (each a one-line replacement; the **Language rule** lines untouched):
  - feat `:248` (`Always append a 1-line entry to today's heading in \`.claude/memory/journal.md\`.`) → `Approved entries and the always-written 1-line journal entry: per \`lib/capitalize-commit.md\` § WRITE (\`memory.sh add\` / \`memory.sh journal\`).`
  - bugfix `:275` → `4. Write approved entries per \`lib/capitalize-commit.md\` § WRITE: a new blocker \`add blocker … --status resolved\`, an existing one now fixed \`status <BLK-ID> "resolved <hash>"\`, an LRN \`add learning …\` (no status); the journal line \`memory.sh journal\`.`
  - hotfix `:234` → `Always append a 1-line journal entry (even trivial hotfix — journal is timeline, not signal) and any approved BLK/LRN per \`lib/capitalize-commit.md\` § WRITE.`
  - ship-feature `:273-274` → `4. Write approved entries per \`lib/capitalize-commit.md\` § WRITE (\`memory.sh add\`, one call each; no Index to update).` / `5. Journal line: \`memory.sh journal\` (same section).`
  - init-project `:301-303` → `3. Write approved entries to the registries bootstrapped at STEP 5 (in the root commit), and the journal line, per \`lib/capitalize-commit.md\` § WRITE.`
  - commit-changer `:220-223` (Phase 4 item 2) → `2. Write each resolved entry and one journal line for the batch per \`$HOME/.claude/lib/capitalize-commit.md\` § WRITE (\`memory.sh -C <repo root> add …\`, \`memory.sh -C <repo root> journal …\`; no Index to update).`
  - onboard S7: the source text spans a line break, `append to that` (end of the line starting `S7 — AFTER.`) + newline + `project's \`.claude/memory/journal.md\` under today's date:`. Replace the tail `append to that` / `project's \`.claude/memory/journal.md\` under today's date:` by `append to that` / `project's journal (\`bash "$HOME/.claude/lib/memory.sh" -C <ROOT> journal\`):` — same two-line wrap, the quoted line text after it unchanged.

- [ ] **Step 4: analyze-before-plan + analyzer**
  - `lib/analyze-before-plan.md:42-43`: `Do NOT read the \`## Index\` table: it drifts (entries land in the body, the manual Index update lapses — measured 32-40% missing on a mature repo); headings cannot.` → `Do NOT read a \`## Index\` table (v1 registries may still carry one; it drifted 32-40% on a mature repo; v2 has none); headings cannot drift.`
  - `:100-102`: `No write, no Index update, no memory mutation.` → `No write, no memory mutation.`; `Index backfill, if ever wanted, is \`/prune-memory\` passe D — never this snippet.` → `Registry writes go through \`lib/memory.sh\`, never this snippet.`
  - `agents/analyzer.md:98-99`: `Index backfill or new entries are never your job` → `new entries or status lines are never your job (writes go through lib/memory.sh)`.

- [ ] **Step 5: CLAUDE.global.md** (line-neutral):
  - `Append-only: never rewrite past entries; curation (merge, supersede,` / `compress) only via \`/prune-memory\`.` → `Append-only, written only through \`bash ~/.claude/lib/memory.sh\` (add,` / `status, journal), never by Edit; curation only via \`/prune-memory\`.`
  - `exact. Pattern \`[thing] [action] [reason]. [next step].\` Registries load` / `every session; caveman cuts ~40% of the tokens with no substance lost.` → `exact. Pattern \`[thing] [action] [reason]. [next step].\` Planning flows` / `read the registries; caveman cuts ~40% of every read, no substance lost.`

- [ ] **Step 6: Verify** — `grep -rn 'Index' skills/capitalize/SKILL.md skills/feat/SKILL.md skills/bugfix/SKILL.md skills/hotfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md agents/commit-changer.md` → no line telling a writer to update an Index. `wc -l < CLAUDE.global.md` → ≤ 333. `make test suite=lib/tests/doctrine-citers.test.sh` and `make test suite=lib/tests/effort-routing.test.sh` → green.

- [ ] **Step 7: Commit**

```bash
git add lib/capitalize-commit.md skills/capitalize/SKILL.md skills/feat/SKILL.md skills/bugfix/SKILL.md skills/hotfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md agents/commit-changer.md skills/onboard/SKILL.md lib/analyze-before-plan.md agents/analyzer.md CLAUDE.global.md
git commit -m "docs(memory): one WRITE section in capitalize-commit.md, every flow cites it; Index steps removed; doctrine names the single writer"
```

---

### Task 6: /prune-memory on v2 (no § D, status through the lib, check as verify)

**Files:** `skills/prune-memory/SKILL.md` (§ A `:83-85`, § D `:111-115`, STEP 2 example, STEP 3 list, `:177`, STEP 4 block, report sample, failure row, `:322-323`), `skills/prune-memory/tests/run-deterministic.sh` (RED-6), new `skills/prune-memory/tests/fixtures/red6-check/.claude/memory/decisions.md`, `git rm` of `skills/prune-memory/tests/fixtures/red6-orphan/.claude/memory/decisions.md`, `skills/prune-memory/test-prompts.json` (id 1).

- [ ] **Step 1: Write the failing test** — replace the whole RED-6 block (from `# ---- RED-6:` through its closing `fi`) by:

```bash
# ---- RED-6: STEP 4 verify runs memory.sh check (duplicate ID caught) --------
# v2 registries carry no Index; the structural verify is `memory.sh check`
# (heading shape, unique IDs). HOME is pinned to a sandbox whose .claude/lib
# is this repo's lib, so the run never depends on the machine's ~/.claude.
S6="$SANDBOX/red6"; mkdir -p "$S6/.claude/memory" "$S6/home/.claude"
ln -s "$HERE/../../../lib" "$S6/home/.claude/lib"
cp "$HERE/fixtures/red6-check/.claude/memory/decisions.md" \
   "$S6/.claude/memory/decisions.md"
extract_block "STEP 4" > "$S6/step4.sh"
out="$( cd "$S6" && HOME="$S6/home" bash step4.sh 2>&1 )"
if printf '%s\n' "$out" | grep -qE 'duplicate BDR-009'; then
  green 6 "verify runs memory.sh check and names the duplicate BDR-009"
else
  red 6 "verify misses the duplicate BDR-009 (no memory.sh check in STEP 4)"
fi
```

Fixture `skills/prune-memory/tests/fixtures/red6-check/.claude/memory/decisions.md`:

```
---
format: 2
type: decisions_registry
entry_prefix: BDR
---

# Decisions registry (BDR)

## BDR-009 — first (2026-06-01)
- **Status**: accepted

## BDR-009 — duplicate, the trap (2026-06-02)
- **Status**: accepted
```

`git rm -q skills/prune-memory/tests/fixtures/red6-orphan/.claude/memory/decisions.md`.

- [ ] **Step 2: Run, expect red** — `make test suite=skills/prune-memory/tests/run-deterministic.sh` → `RED-6: RED`.

- [ ] **Step 3: SKILL.md edits**
  - § A `:83-85` → `Decisions whose body names a successor ("superseded by <ID>", "Supersedes [[<ID>]]" on the newer one) but whose current status (\`bash "$HOME/.claude/lib/memory.sh" index decision\`) still reads \`accepted\` → propose \`memory.sh status <ID> "superseded by <that-ID>"\`.`
  - Delete § D (`### D. Index drift` and its two bullets).
  - STEP 2 example: `→ fix Index: status = "superseded by BDR-903"` → `→ memory.sh status BDR-902 "superseded by BDR-903"`; delete `[D. Index drift]` + `(none)`; `(all / a / b / c / d / edit <ID> / skip)` → `(all / a / b / c / edit <ID> / skip)`.
  - STEP 3 list (replacing items 1-3; old item 4 becomes 3, unchanged):

```
1. **Status flag updates** — `bash "$HOME/.claude/lib/memory.sh" status <ID>
   "<word> …"` appends a dated status line (text starts with a status word:
   `deprecated, no follow-up after 90 days`); the body above stays verbatim.
2. **Merges** — write the merged body to a scratch file, then
   `bash "$HOME/.claude/lib/memory.sh" add <kind> --title "<title>"
   --body-file <file> --supersedes <first source>` (next-free ID, forward
   link, the first source marked superseded); each other source:
   `memory.sh status <ID> "superseded by <new-ID>"`. Source bodies stay
   verbatim for history. Merged body:
```
    followed by the existing merged-body sub-bullets. Delete `After each write, regenerate Index from body when rows changed.`
  - STEP 4 block: delete the `PREFIX_MAP` declaration, its comment and the `# All body entries have Index rows; no orphans` loop through its `done`; in their place:

```bash
# Structure: heading shape + unique IDs + no open fence (v2 registries; a
# v1 one is named and skipped). Same verify the writer runs after every add.
bash "$HOME/.claude/lib/memory.sh" check .claude/memory \
  || echo "CHECK FAILED: fix the lines above before certifying"
```
  - Report sample `INDEX SANITY: OK` → `CHECK: OK`; `NEXT: review \`git diff .claude/memory/\`, then \`/commit-change\`` unchanged (curation edits are removals: they never go through memory-commit's chokepoint).
  - Failure row `| Index sanity FAILED at STEP 4 | …` → `| \`memory.sh check\` FAILED at STEP 4 | Print its culprit lines. Do NOT auto-fix — user re-runs or hand-edits. |`.
  - `:322-323` fixtures list `red6-orphan` → `red6-check`.

- [ ] **Step 4: test-prompts.json** id 1 `expected` → `"Skill runs PRECHECK (refuses if working tree dirty on .claude/memory/), audits all 5 registries for A) obsolete/superseded entries B) similar merge candidates C) bloated prose, presents the per-registry PRUNE PLAN with category-level approval gate, applies only approved changes (status lines and merges through lib/memory.sh, never hard-delete), then runs memory.sh check and the fidelity census at STEP 4."`

- [ ] **Step 5: Run, expect green** — `make test suite=skills/prune-memory/tests/run-deterministic.sh` → RED-1..7 GREEN (RED-5's journal-only sandbox has no registry, `check` prints nothing). `grep -n 'Index' skills/prune-memory/SKILL.md` → no writer step mentions an Index.

- [ ] **Step 6: Commit**

```bash
git add skills/prune-memory
git commit -m "feat(prune-memory): v2 registries — § D dropped, status and merges through memory.sh, STEP 4 verify = memory.sh check"
```

---

### Task 7: upgrade this repo's registries (the one curation)

**Files:** `.claude/memory/{decisions,learnings,blockers,evals}.md` (by the lib only). `upgrade` already transforms on a temp copy and runs its oracle before replacing any file; the registries are tracked, so no dry run.

- [ ] **Step 0: Clean memory precondition** — `git diff --quiet HEAD -- .claude/memory .claude/tasks || { echo "STOP: uncommitted memory or tasks; commit them first"; exit 1; }`. The rollback below and the memory-commit sweep both rely on it.

- [ ] **Step 1: Upgrade in place and commit through the chokepoint**

```bash
bash lib/memory.sh upgrade
bash lib/memory.sh check && echo CHECK-OK
bash "$HOME/.claude/lib/memory-commit.sh" commit "chore(memory): registries v2 — Index removed, Index-only dates and statuses materialized (memory.sh upgrade)"
```
Expected: four `memory: upgraded …` lines and one stderr line `memory: BDR-012: kept body shipped, dropped Index accepted`; `CHECK-OK`; memory-commit prints a hash (Index lines sit above the first entry, every other change is an insertion). If `upgrade` returns rc 2: each file is already restored from its verified backup; `git checkout -- .claude/memory` (safe only after Step 0) puts any upgraded sibling back, report the stderr, stop.

- [ ] **Step 2: Verify the live facts**
Run: `bash -c '. lib/reconcile.sh; reconcile_blk_open .claude/memory/blockers.md | cut -f1 | tr "\n" " "'` → exactly `BLK-001 BLK-003 BLK-017 BLK-018 BLK-021 BLK-022 BLK-029 ` (measured on an upgraded copy 2026-10-28: 032..034 resolved, 019/020 superseded = closed).
Run: `bash lib/memory.sh index blocker | grep -E 'BLK-0(19|20|32|33|34)'` → dates `2026-09-01 2026-09-02 2026-10-19 2026-10-21 2026-10-22`, statuses superseded, superseded, resolved ×3.
Run: `grep -c '^## Index' .claude/memory/*.md` → 0 everywhere; `make test suite=lib/tests/memory.test.sh` → T12 green; the session banner no longer shows `registry v1`.

---

## Final verification (main loop, after Task 7)

`make test` all suites green; `shellcheck lib/memory.sh lib/reconcile.sh lib/memory-commit.sh hooks/session-start.sh`; `bash lib/memory.sh check`; `git status --short` clean except the user-owned `settings.json`. No other project changed: `git -C <dir> status --short .claude/memory` empty, and `bash -c '. lib/reconcile.sh; reconcile_blk_open <dir>/.claude/memory/blockers.md'` equal to the pre-branch reader, for each of:

```
/home/bchanot/Documents/config
/home/bchanot/Documents/faunosteo
/home/bchanot/Documents/game
/home/bchanot/Documents/game-deploy
/home/bchanot/Documents/integration_alphalink
/home/bchanot/Documents/robin_petier
/home/bchanot/Documents/zenquality
/home/bchanot/repos/bchanot/angelscar356
/home/bchanot/repos/bchanot/bchanot-cv
/home/bchanot/repos/bchanot/for_you
/home/bchanot/repos/bchanot/game-deploy
/home/bchanot/repos/bchanot/gitea-deploy
/home/bchanot/repos/bchanot/nuit-folle
/home/bchanot/repos/bchanot/trucks_at_work
```
(pre-branch reader: `git show develop:lib/reconcile.sh > <tmp>` then source `<tmp>`; measured 2026-10-28 on copies: 13 of 13 distinct files identical.)

---

### Task 8: `upgrade` migrates every v1 dialect (user ask at the gate, 2026-10-28)

User at STEP 3: "Il faudrait un système de migration pour que les fichiers v1 deviennent des fichiers v2 pour tout harmoniser". Same files, same `.claude/memory/` place, versioned and pushed with the code; v2 = `format: 2` + no Index.

**Files:** `lib/memory.sh` (`upgrade` path only), `lib/tests/memory.test.sh` (new T15 block), `lib/tests/fixtures/blockers-v1-dialects.md` (extend if needed).

**Behaviour** (replaces the dialect refusal of Deviation 6 for `upgrade` only):
1. No frontmatter → prepend the matching `templates/memory/<name>.md` frontmatter (with `format: 2`) and keep the file's own body verbatim below it.
2. Heading normalization, entry headings only (`^#+ *PREFIX-[0-9]+`): `## ID - t`, `## ID | date | t`, `### ID — t`, `## ID — t — date` → `## ID — t (date)`; the date comes from the heading, else the Index row, else the first `Date`/`date:` body line, else none. The title text is kept verbatim (only separators change). IDs never change.
3. Status preservation: before rewriting, compute every entry's open/closed verdict with the v1 lexical reader (reconcile's legacy path, blockers) and the status word (all registries); after rewriting, if the strict v2 parser would read a different verdict or no status where the legacy reader had one, append `- **Status (<today>, upgrade)**: <word>` to that entry.
4. Oracle (file untouched on any failure, rc 2, culprit named): same ID set and order; every entry's verdict before == after (blockers via the legacy reader vs `memory_closed`, others by status word when one existed); `check` green; idempotent second run.
5. `upgrade` no longer refuses any of the measured dialects; it refuses only what the oracle cannot prove.

**Tests (T15):** one fixture per dialect (hyphen, pipe, `###`, title-suffix `— RESOLVED`, `date: … · status:`, `**Statut** :`, no frontmatter) → upgraded, `check` green, verdicts preserved, idempotent; a tampered case where the oracle refuses and the file stays byte-identical. Proof on copies (read-only on the real repos): `upgrade` on a copy of each of the 13 other projects' registries is oracle-green; report the per-repo line counts.

**Out of this branch:** applying it to the 13 other repos happens after the merge, one `chore/memory-v2` branch per repo, user approval per repo (phase 0b pattern), committed through `/commit-change` (a heading rename is an in-place edit, memory-commit refuses it by design).
