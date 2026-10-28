# Memory v2 write side (phase 4a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lib/memory.sh` becomes the only writer of `.claude/memory` registries, one status parser serves memory.sh and reconcile, this repo's registries move to v2 (no `## Index`), every citer writes through the lib.

**Architecture:** One sourceable bash lib on the `lib/project-rules.sh` skeleton (`-C <dir>`, verbs, rc 2 + named reason). The awk status parser lives once in `_MEM_AWK` and is shared by `index`, `upgrade` and `lib/reconcile.sh`. Writers serialize through a noclobber lock file in the git common dir. `memory-commit.sh` runs `check --staged` as the chokepoint.

**Tech Stack:** bash 5, POSIX awk (no gawk-only features, no `{n}` intervals), git. Tests via `make test`.

**Spec:** `docs/superpowers/specs/2026-10-27-memory-v2-write-design.md` (user-approved 2026-10-27). Contract: `.claude/tasks/contracts/2026-10-27-memory-v2-write-2030.md`.

**Reference implementation (proven before this plan was written):** `docs/superpowers/plans/memory-v2-write/` holds `memory.sh`, `memory.test.sh` and `blockers-v2-status.md`. They were run in a mock repo: suite `PASS=72 FAIL=0` five runs in a row, shellcheck clean, no line over 80 chars; `upgrade` on a copy of this repo's live registries is oracle-green, `check`-green, idempotent, and its diff passes `check --staged`. Task 1 copies them; do not rewrite them.

## Global Constraints

- Branch `feature/memory-v2-write` (already started, spec at cdc0a47). Never switch, never merge, never push by hand (hooks push).
- Our code: functions ≤ 25 logic lines (an embedded awk program counts as one statement), ≤ 5 locals, ≤ 5 params, lines ≤ 80 chars in `lib/*.sh`.
- No `# shellcheck disable` anywhere in the diff (floor guard, LRN-234). `# shellcheck source=/dev/null` directives are allowed.
- `/usr/bin/grep` pinned in libs (`MEM_GREP`, LRN-074); no `grep -q` reading a pipe under pipefail (LRN-189); no `sed -i`, `stat -c`, `realpath -m`, `grep -P` (portability census, BDR-110).
- No recursive delete through a variable except the existing `trap 'rm -rf "$FIX"' EXIT` mktemp pattern.
- Hermetic tests run through `make test [suite=…]` only.
- Census-cited strings stay byte-identical: every `CLAUDE.md "Memory registries" (Always English, always caveman)` citation, the CLAUDE.global.md heading `## Memory registries (\`.claude/memory/\`)` and the bold label `**Always English, always caveman**` (doctrine-citers, LRN-166). Single-line fixed strings: do not rewrap a line that holds one.
- CLAUDE.global.md line count must not exceed 333 after the edit.
- Worked examples use fictional 9xx IDs (LRN-073).
- Entry text written to registries is English caveman (BDR-009).

## Deviations from the spec (found while proving the reference)

- Lock = a file created under bash noclobber, not a `mkdir` dir: uutils `mkdir` 0.10 on this host is not atomic (5 concurrent adds lost 2-4 entries). Same path (`<git-common-dir>/memory.lock`), same 30 s steal.
- `journal` takes no `--date` flag: `MEMORY_DATE` already pins the date for tests; YAGNI.
- `upgrade` writes an Index status into the body only when the body has none, or when the Index says superseded/deprecated and the body does not. Otherwise the body wins: the Index is the stale copy (BDR-012: Index accepted, body shipped). Status words rank in `_MEM_WORDS` order with `open` last, measured on the live registries: identical verdicts to today's reconcile on every blocker except BLK-032..034.

## Review Focus

1. **Concurrent writers.** Two sessions capitalizing at once must get two IDs; a lock that is not atomic loses entries silently. Found while proving the reference: `mkdir` from uutils coreutils 0.10 (this host) is NOT atomic, two concurrent `mkdir` both succeed; the lock uses bash noclobber (`open(O_EXCL)`). T6e/T6f are the flip test (they were red with the mkdir lock).
2. **Status words in prose.** A Solution line saying "fail-open" or "`data:` OPEN" must never reopen a resolved blocker; "accepted. Behavioral check OPEN" must read accepted. Covered by T10b/c/e and run-reconcile T8.
3. **Index-only facts lost at upgrade.** 13 BDR statuses, 2 BDR + 2 BLK + 12 LRN supersessions and ~130 dates live only in Index rows today; a stale Index status (BDR-012 says accepted, body says shipped) must NOT overwrite the body. The upgrade oracle refuses on any loss; T9e pins the stale case.
4. **v1 projects keep working.** 13 other repos on this machine run this lib through `~/.claude/lib`; a v1 registry is written leniently, `check` never fails on it, `--staged` ignores it, memory-commit keeps committing it. T7e/f and the memory-commit v1 test pin this.
5. **The chokepoint must not block the upgrade commit itself.** Removing the Index (lines before the first entry) and inserting Date/Status lines are not "removed lines inside an entry". Proven on the live copy; Task 7 commits it through memory-commit.sh.

---

### Task 1: lib/memory.sh, its suite and the parser fixture

**Files:**
- Create: `lib/memory.sh` (copy of `docs/superpowers/plans/memory-v2-write/memory.sh`)
- Create: `lib/tests/memory.test.sh` (copy of `docs/superpowers/plans/memory-v2-write/memory.test.sh`)
- Create: `lib/tests/fixtures/blockers-v2-status.md` (copy of `docs/superpowers/plans/memory-v2-write/blockers-v2-status.md`)

**Interfaces:**
- Produces (sourceable, used by Tasks 2-7): `memory_entry_status <file> <ID>` (winning candidate line, rc 1 if none), `memory_status_word <line>` (status word or first 40 chars), `memory_check [--staged] [<dir>]` (rc 2 on a culprit), `memory_add`, `memory_status`, `memory_journal`, `memory_index`, `memory_upgrade`. CLI: `bash lib/memory.sh [-C dir] add|status|journal|index|check|upgrade …`. Env: `MEMORY_DATE`, `MEM_GREP`, `MEM_LOCK_TRIES`.

- [ ] **Step 1: Copy the three files**

```bash
cp docs/superpowers/plans/memory-v2-write/memory.sh lib/memory.sh
cp docs/superpowers/plans/memory-v2-write/memory.test.sh lib/tests/memory.test.sh
cp docs/superpowers/plans/memory-v2-write/blockers-v2-status.md lib/tests/fixtures/blockers-v2-status.md
chmod +x lib/memory.sh lib/tests/memory.test.sh
```

- [ ] **Step 2: Run the suite and the static checks**

Run: `make test suite=lib/tests/memory.test.sh` → expected last lines `PASS=72 FAIL=0` and `all suites green`. Run it three times (the race test T6e must be stable).
Run: `shellcheck lib/memory.sh lib/tests/memory.test.sh && awk 'length > 80' lib/memory.sh` → no output after shellcheck.
Run: `make test suite=lib/tests/portability-census.test.sh` → green.

- [ ] **Step 3: Commit**

```bash
git add lib/memory.sh lib/tests/memory.test.sh lib/tests/fixtures/blockers-v2-status.md
git commit -m "feat(memory): lib/memory.sh single registry writer — add/status/journal/index/check/upgrade, shared status parser, noclobber lock"
```

---

### Task 2: reconcile reads status through the shared parser

**Files:**
- Modify: `lib/reconcile.sh:57-67` (`reconcile_blk_current_status`) and its header comment `:8-12`
- Modify: `lib/tests/run-reconcile.sh` (new T8 block before the final summary line)
- Modify: `skills/reconcile/SKILL.md:25`

**Interfaces:**
- Consumes: `memory_entry_status` from Task 1.
- Produces: `reconcile_blk_current_status <file> <ID>` unchanged signature, now prints the winning candidate line (empty when none).

- [ ] **Step 1: Write the failing test** — insert before the `echo; echo "================  $pass GREEN` line of `lib/tests/run-reconcile.sh`:

```bash
echo; echo "=== T8 shared parser — header [tag] + labelled lines, prose never (BLK-032..034) ==="
v2="$FIX/blockers-v2-status.md"
open_v2=$(reconcile_blk_open "$v2" | cut -f1 | sort | tr '\n' ' ')
if [ "$open_v2" = "BLK-041 BLK-042 " ]; then ok "T8a open = {041,042}: 032..034, 008, 040 read resolved/accepted"; else no "T8a open = [$open_v2], expected {041,042}"; fi
case "$(reconcile_blk_current_status "$v2" BLK-034)" in
  *'[resolved]'*) ok "T8b BLK-034 status = its own header tag";;
  *) no "T8b BLK-034 read from prose (fail-open), not the header tag";;
esac
```

- [ ] **Step 2: Run it, expect red**

Run: `make test suite=lib/tests/run-reconcile.sh` → `RED ✗ T8a open = [BLK-032 BLK-033 BLK-034 BLK-040 BLK-041 BLK-042 ]…` (exact list may differ; it must be red).

- [ ] **Step 3: Delegate the parser** — in `lib/reconcile.sh`, after the `RECONCILE_GREP=` line add:

```bash
# the status parser is shared with lib/memory.sh (BDR-125 phase 4a)
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/memory.sh"
```

and replace the whole `reconcile_blk_current_status` function and the two comment lines above it with:

```bash
# --- registry status: LAST candidate wins (the BLK-008 trap A fell into) ---
# $1 blockers file, $2 id. Echoes the winning status line: the entry's own
# header `[tag]` or a labelled body line (lib/memory.sh); a status word in
# prose is never read (the BLK-032..034 false-open). Empty when none.
reconcile_blk_current_status() {
  memory_entry_status "$1" "$2"
}
```

In the header comment, insert one line right after line 12 (`# preaches — the recursive-coherence test (run-reconcile.sh T1) reds if this is broken.`):
`# v2 registries carry no Index at all (lib/memory.sh); v1 ones still may.`

- [ ] **Step 4: Run, expect green**

Run: `make test suite=lib/tests/run-reconcile.sh` → `T8a`, `T8b` green, T1-T7 still green, `0 RED`.
Run: `make test suite=lib/tests/run-review-guards.sh` → green (G4: run-reconcile must not read `.claude/memory`; T8 reads the fixture).

- [ ] **Step 5: Skill line** — `skills/reconcile/SKILL.md:25`, replace
`` (`reconcile_oracle_*`, `reconcile_blk_current_status` = last block wins) `` by
`` (`reconcile_oracle_*`, `reconcile_blk_current_status` = last candidate wins: header `[tag]` or a labelled status line, via `lib/memory.sh`) ``

- [ ] **Step 6: Commit**

```bash
git add lib/reconcile.sh lib/tests/run-reconcile.sh skills/reconcile/SKILL.md
git commit -m "fix(reconcile): blocker status through the shared memory.sh parser — BLK-032..034 no longer false-open"
```

---

### Task 3: memory-commit.sh refuses a staged in-place edit (rc 6)

**Files:**
- Modify: `lib/memory-commit.sh` (header usage comment, `commit_memory` between `git add` and `git diff --cached --quiet`)
- Modify: `lib/tests/run-deterministic.sh` (two new tests before the summary)
- Modify: `lib/capitalize-commit.md` (rc table)

**Interfaces:**
- Consumes: `bash lib/memory.sh check --staged .claude/memory`.
- Produces: `memory-commit.sh commit` rc 6 = check refused, nothing committed.

- [ ] **Step 1: Write the failing tests** — read `lib/tests/run-deterministic.sh` first (helpers `new_repo`, `ok`, `ko`, `HELPER`); append before its final summary block:

```bash
echo "== check --staged chokepoint (v2 registry, phase 4a)"
d="$(new_repo)"
printf -- '---\nformat: 2\ntype: decisions_registry\nentry_prefix: BDR\n---\n\n## BDR-001 — kept (2026-10-27)\n- **Status**: accepted\n' \
  > "$d/.claude/memory/decisions.md"
git -C "$d" add -A && git -C "$d" commit -qm v2
head_before=$(git -C "$d" rev-parse HEAD)
printf -- '---\nformat: 2\ntype: decisions_registry\nentry_prefix: BDR\n---\n\n## BDR-001 — rewritten (2026-10-27)\n- **Status**: accepted\n' \
  > "$d/.claude/memory/decisions.md"
out="$(cd "$d" && bash "$HELPER" commit "chore(memory): bad" 2>/dev/null)"; rc=$?
if [ "$rc" -eq 6 ] && [ -z "$out" ] && [ "$(git -C "$d" rev-parse HEAD)" = "$head_before" ]; then ok "in-place edit of a v2 entry → rc 6, nothing committed"; else ko "rc=$rc out=[$out] — in-place edit was committed or wrong rc"; fi
git -C "$d" checkout -q HEAD -- .claude/memory/decisions.md
printf '\n## BDR-002 — added (2026-10-27)\nbody\n' >> "$d/.claude/memory/decisions.md"
out="$(cd "$d" && bash "$HELPER" commit "chore(memory): BDR-002" 2>/dev/null)"; rc=$?
if [ "$rc" -eq 0 ] && [ -n "$out" ]; then ok "append to a v2 registry → committed"; else ko "append refused rc=$rc"; fi
```

(The existing tests write `baseline` registries with no frontmatter: v1, `check` skips them, they must stay green unchanged.)

- [ ] **Step 2: Run, expect red**

Run: `make test suite=lib/tests/run-deterministic.sh` → the rc 6 test fails (today rc 0, the edit is committed).

- [ ] **Step 3: Implement** — in `lib/memory-commit.sh`:
  - under `MC_PATHS=(...)` add:

```bash
MC_MEMORY_SH="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/memory.sh"
```

  - in `commit_memory`, right after `git add -- "${changed[@]}"`, insert:

```bash
  # Chokepoint (BDR-125 phase 4a): a staged v2 registry may only grow. An
  # in-place rewrite of an existing entry is curation: /prune-memory, then
  # /commit-change. v1 registries are skipped by the check.
  if [ -d .claude/memory ] \
    && ! bash "$MC_MEMORY_SH" check --staged .claude/memory; then
    echo "memory-commit: REFUSED — memory.sh check --staged failed (above);" \
      "NOTHING committed, the scoped paths stay staged." >&2
    return 6
  fi
```

  - header usage line becomes `#   memory-commit.sh commit "<message>"  # surgical commit; exit 0 ok/no-op, 3 unsafe state, 5 commit rejected, 6 check --staged refused`

- [ ] **Step 4: Run, expect green**

Run: `make test suite=lib/tests/run-deterministic.sh` → all green including the two new ones.

- [ ] **Step 5: Document rc 5 and rc 6** — in `lib/capitalize-commit.md` step 3 "Report by (rc, mem_hash)", after the `rc 3` bullet add:

```
   - rc 5                     → `git commit` rejected (hook, protected branch,
                                signing); nothing committed, surface stderr.
   - rc 6                     → `memory.sh check --staged` refused: a staged
                                v2 registry rewrites an existing entry line
                                (only appends pass). Curation goes through
                                /prune-memory then /commit-change; surface
                                the culprit lines, never bypass the helper.
```

- [ ] **Step 6: Commit**

```bash
git add lib/memory-commit.sh lib/tests/run-deterministic.sh lib/capitalize-commit.md
git commit -m "feat(memory): memory-commit refuses a staged in-place edit of a v2 registry (rc 6); rc 5/6 documented"
```

---

### Task 4: v2 templates and the registry v1 banner line

**Files:**
- Modify: `templates/memory/{decisions,learnings,blockers,evals}.md`
- Modify: `hooks/session-start.sh` (after the CLAUDE.global.md line-count guard, before `# Version check`)
- Modify: `lib/tests/memory.test.sh` (T13, before the final `echo "PASS=…"`)
- Modify: `agents/onboarder.md:126` (template description)

- [ ] **Step 1: Write the failing test** — insert before `echo "PASS=$pass FAIL=$fail"` in `lib/tests/memory.test.sh`:

```bash
# T13 templates are born v2; the session banner names a v1 project only
for t in decisions learnings blockers evals; do
  check "T13-template-$t-v2" "$(sed -n 2p "$ROOT/templates/memory/$t.md")" 'format: 2'
  check "T13b-template-$t-no-index" "$(grep -c '^## Index$' "$ROOT/templates/memory/$t.md")" 0
done
banner() { (cd "$1" && SESSION_START_OFFLINE=1 bash "$ROOT/hooks/session-start.sh" \
  </dev/null 2>/dev/null); }
check T13c-banner-v1 "$(banner "$FIX/v1-proj" | grep -c 'registry v1: 1 file')" 1
check T13d-banner-v2 "$(banner "$FIX" | grep -c 'registry v1')" 0
```

and, just above it, the v1 fixture project:

```bash
mkdir -p "$FIX/v1-proj/.claude/memory"
printf '# Decisions\n\n## BDR-001 - legacy\n' > "$FIX/v1-proj/.claude/memory/decisions.md"
```

- [ ] **Step 2: Run, expect red** — `make test suite=lib/tests/memory.test.sh` → T13 checks fail.

- [ ] **Step 3: Templates** — in each of the four templates: insert `format: 2` as line 2 (right after the opening `---`); delete the `## Index` heading, the blank line after it, the two table lines and the blank line after them; replace the `<!-- Append entries below. Template: … -->` comment by this shape (per file, adapt the kind, title word and body labels already in that template; the heading line is indented two spaces so no line starts with `## `):

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

Kinds and labels: decisions → `decision`, `<title>`, `[accepted]`, labels Decision / Why / Rejected alternatives / Reference; learnings → `learning`, `<abstract pattern>`, no status, labels Pattern / Context / Future application; evals → `eval`, `<output>`, `[keep]`, labels Output / Method / Anomalies / Action. `journal.md` template unchanged.

- [ ] **Step 4: Banner** — in `hooks/session-start.sh`, after the `fi` that closes the CLAUDE.global.md line-count guard, insert:

```bash
# Registry v1 (BDR-125 phase 4a): a project registry without `format: 2`.
if [ -n "$REPO_DIR" ] && [ -d .claude/memory ]; then
  _v1=$(bash "$REPO_DIR/lib/memory.sh" check .claude/memory 2>&1 >/dev/null \
    | grep -c '^memory: v1: ' || true)
  if [ "${_v1:-0}" -gt 0 ]; then
    _v1_line="registry v1: ${_v1} file(s), see memory.sh upgrade"
    printf "│  ⚠️  %-44s│\n" "${_v1_line:0:44}"
  fi
  unset _v1 _v1_line
fi
```

- [ ] **Step 5: Onboarder line** — `agents/onboarder.md:126`, replace `(YAML schema + empty index + inline template comment)` by `(YAML schema with \`format: 2\` + inline template comment; no Index, entries go through \`lib/memory.sh\`)`.

- [ ] **Step 6: Run, expect green** — `make test suite=lib/tests/memory.test.sh` → `FAIL=0`; `make test suite=lib/tests/push-guard.test.sh` → green (banner unchanged for this repo, which is v1 until Task 7: if push-guard counts banner lines exactly, read its T44-T46 and confirm none breaks; the new line appears only in a project with a v1 registry).

- [ ] **Step 7: Commit**

```bash
git add templates/memory hooks/session-start.sh lib/tests/memory.test.sh agents/onboarder.md
git commit -m "feat(memory): templates born v2 (format: 2, no Index); session banner names a v1 registry"
```

---

### Task 5: flows write through the lib (capitalize, CAPITALIZE steps, analyzer, doctrine)

**Files (one edit each, exact text below):**
- `skills/capitalize/SKILL.md` STEP 2 (`:143`), STEP 4 items 1-4 (`:247-255`), STEP 5 (`:267-273`)
- `skills/feat/SKILL.md:248`
- `skills/bugfix/SKILL.md:275`
- `skills/hotfix/SKILL.md:234` (+ the two proposal bullets `:228-229` unchanged)
- `skills/ship-feature/SKILL.md:273-274`
- `skills/init-project/SKILL.md:301-303`
- `agents/commit-changer.md:220-223`
- `skills/onboard/SKILL.md` S7 (`:1181-1183`)
- `lib/analyze-before-plan.md:42-43` and `:100-102`
- `agents/analyzer.md:98-99`
- `CLAUDE.global.md` § Memory registries (two sentences)

The one canonical write instruction (W) used below:

> W = Write each approved entry's caveman body to a scratch file, then `bash "$HOME/.claude/lib/memory.sh" add <decision|learning|blocker|eval> --title "<title>" --body-file <file> [--status <status>]` (one call per entry; it allocates the ID and prints it; never Edit or append to a registry, there is no Index to update). A status change on an existing entry: `bash "$HOME/.claude/lib/memory.sh" status <ID> "<text>"`. The journal line: `bash "$HOME/.claude/lib/memory.sh" journal "<line>"`.

- [ ] **Step 1: capitalize**
  - `:143` `(Index + bodies)` → `(headings + bodies)`.
  - STEP 4 items 1-4 (from `1. Read the target registry file.` through the Index-row item ending `match that file's header row).`) become:

```
1. Body to a scratch file, then `bash "$HOME/.claude/lib/memory.sh" add
   <decision|learning|blocker|eval> --title "<title>" --body-file <file>
   [--status <status>] [--supersedes <ID>]`: it allocates the next ID from
   the headings under a lock, appends at the end, prints the ID. Never Edit
   or append to a registry by hand; there is no Index to update.
2. A status change on an existing entry (a blocker now resolved):
   `bash "$HOME/.claude/lib/memory.sh" status <ID> "<text>"`.
3. A refusal (rc 2) names its reason (title chars, empty body, a blocker
   body without one backtick-quoted error): fix the input, re-run.
```

    Old item 5 (caveman) stays, renumbered 4.
  - STEP 5: replace the two bullets `- Heading exists → append a bullet.` / `- Missing → create …` by `- \`bash "$HOME/.claude/lib/memory.sh" journal "<line>"\` (one call per bullet; it creates today's heading when missing).`

- [ ] **Step 2: feat** `:248` (`Always append a 1-line entry to today's heading in \`.claude/memory/journal.md\`.`) → two lines, the **Language rule** line after them untouched:

```
Approved entries: caveman body to a scratch file, then `bash "$HOME/.claude/lib/memory.sh" add <decision|learning> --title "<title>" --body-file <file>` (one call each; it allocates the ID; never Edit a registry).

Always append a 1-line entry: `bash "$HOME/.claude/lib/memory.sh" journal "<line>"`.
```

- [ ] **Step 3: bugfix** `:275` → `4. Write approved entries with \`bash "$HOME/.claude/lib/memory.sh" add <kind> --title … --body-file <file> --status resolved\` (one call each, it allocates the ID; an existing blocker now fixed: \`memory.sh status <ID> "resolved <hash>"\`). Journal line: \`bash "$HOME/.claude/lib/memory.sh" journal "<line>"\`.`

- [ ] **Step 4: hotfix** `:234` → `Always append a 1-line entry with \`bash "$HOME/.claude/lib/memory.sh" journal "<line>"\` (even trivial hotfix — journal is timeline, not signal). A proposed BLK/LRN, once approved: \`bash "$HOME/.claude/lib/memory.sh" add <blocker|learning> --title … --body-file <file>\`.`

- [ ] **Step 5: ship-feature** `:273-274` → 
```
4. Write approved entries with `bash "$HOME/.claude/lib/memory.sh" add <kind> --title "<title>" --body-file <file> [--status <s>]`, one call each (it allocates the ID; no Index to update).
5. Journal line: `bash "$HOME/.claude/lib/memory.sh" journal "<line>"`.
```

- [ ] **Step 6: init-project** `:301-303` → `3. Write approved entries to the registries bootstrapped at STEP 5 (in the root commit) with \`bash "$HOME/.claude/lib/memory.sh" add <kind> --title … --body-file <file>\`, one call each; journal line with \`bash "$HOME/.claude/lib/memory.sh" journal "<line>"\`.`

- [ ] **Step 7: commit-changer** `:220-223` (item 2 of Phase 4) → 
```
2. Write each resolved entry with `bash "$HOME/.claude/lib/memory.sh" add
   <decision|learning|blocker|eval> --title "<title>" --body-file <file>`
   (one call each; it allocates the ID, no Index to update), then one
   journal line for the batch: `bash "$HOME/.claude/lib/memory.sh" journal
   "<summary>"`.
```

- [ ] **Step 8: onboard S7** — replace `append to that project's \`.claude/memory/journal.md\` under today's date:` by `append to that project's journal with \`bash "$HOME/.claude/lib/memory.sh" -C <ROOT> journal\`:` (the quoted line text after it unchanged).

- [ ] **Step 9: analyze-before-plan + analyzer**
  - `lib/analyze-before-plan.md:42-43`: `Do NOT read the \`## Index\` table: it drifts (entries land in the body, the manual Index update lapses — measured 32-40% missing on a mature repo); headings cannot.` → `Do NOT read a \`## Index\` table (v1 registries may still carry one; it drifted 32-40% on a mature repo; v2 has none); headings cannot drift.`
  - `:100-102`: `No write, no Index update, no memory mutation.` → `No write, no memory mutation.` and `Index backfill, if ever wanted, is \`/prune-memory\` passe D — never this snippet.` → `Registry writes go through \`lib/memory.sh\`, never this snippet.`
  - `agents/analyzer.md:98-99`: `Index backfill or new entries are never your job` → `new entries or status lines are never your job (writes go through lib/memory.sh)`.

- [ ] **Step 10: CLAUDE.global.md** (line-neutral):
  - `Append-only: never rewrite past entries; curation (merge, supersede,\ncompress) only via \`/prune-memory\`.` → `Append-only, written only through \`bash ~/.claude/lib/memory.sh\` (add,\nstatus, journal), never by Edit; curation only via \`/prune-memory\`.`
  - `exact. Pattern \`[thing] [action] [reason]. [next step].\` Registries load\nevery session; caveman cuts ~40% of the tokens with no substance lost.` → `exact. Pattern \`[thing] [action] [reason]. [next step].\` Planning flows\nread the registries; caveman cuts ~40% of every read, no substance lost.`

- [ ] **Step 11: Verify**
Run: `grep -rn 'Index' skills/capitalize/SKILL.md skills/feat/SKILL.md skills/bugfix/SKILL.md skills/hotfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md agents/commit-changer.md` → no line telling a writer to update an Index.
Run: `wc -l < CLAUDE.global.md` → ≤ 333.
Run: `make test suite=lib/tests/doctrine-citers.test.sh` and `make test suite=lib/tests/effort-routing.test.sh` → green (no rewrap of a census string; every `route(phase="apply") … memory-commit` line untouched).

- [ ] **Step 12: Commit**

```bash
git add skills/capitalize/SKILL.md skills/feat/SKILL.md skills/bugfix/SKILL.md skills/hotfix/SKILL.md skills/ship-feature/SKILL.md skills/init-project/SKILL.md agents/commit-changer.md skills/onboard/SKILL.md lib/analyze-before-plan.md agents/analyzer.md CLAUDE.global.md
git commit -m "docs(memory): every writer goes through lib/memory.sh; Index steps removed; doctrine names the single writer"
```

---

### Task 6: /prune-memory on v2 (no § D, status through the lib, check as verify)

**Files:**
- Modify: `skills/prune-memory/SKILL.md` (`:83-85`, `:111-115`, `:130`, `:141-143`, `:153-158`, `:177`, STEP 4 block `:190-206`, report `:274`, failure row `:305`, `:322-323`)
- Modify: `skills/prune-memory/tests/run-deterministic.sh` (RED-6 rewritten)
- Create: `skills/prune-memory/tests/fixtures/red6-check/.claude/memory/decisions.md`
- Delete: `skills/prune-memory/tests/fixtures/red6-orphan/.claude/memory/decisions.md` (`git rm`)
- Modify: `skills/prune-memory/test-prompts.json` (id 1 `expected`)

- [ ] **Step 1: Write the failing test** — replace the whole RED-6 block (from `# ---- RED-6:` through its closing `fi`) in `skills/prune-memory/tests/run-deterministic.sh` by:

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

Create `skills/prune-memory/tests/fixtures/red6-check/.claude/memory/decisions.md`:

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

`git rm -q skills/prune-memory/tests/fixtures/red6-orphan/.claude/memory/decisions.md`. In the suite header comment, `RED-2/RED-6 execute the REAL bash blocks` stays true.

- [ ] **Step 2: Run, expect red** — `make test suite=skills/prune-memory/tests/run-deterministic.sh` → `RED-6: RED`.

- [ ] **Step 3: SKILL.md edits**
  - § A bullet `:83-85`: `Decisions whose body contains "superseded by <ID>" but Index row still says \`accepted\` → propose Index row fix to \`superseded by <that-ID>\`.` → `Decisions whose body names a successor ("superseded by <ID>", "Supersedes [[<ID>]]" on the newer one) but whose current status (\`bash "$HOME/.claude/lib/memory.sh" index decision\`) still reads \`accepted\` → propose \`memory.sh status <ID> "superseded by <that-ID>"\`.`
  - Delete § D (`### D. Index drift` and its two bullets, `:111-115`).
  - STEP 2 example: `→ fix Index: status = "superseded by BDR-903"` → `→ memory.sh status BDR-902 "superseded by BDR-903"`; delete the `[D. Index drift]` + `(none)` lines; `Approve per category? (all / a / b / c / d / edit <ID> / skip)` → `(all / a / b / c / edit <ID> / skip)`.
  - STEP 3 list becomes:

```
1. **Status flag updates** — `bash "$HOME/.claude/lib/memory.sh" status <ID>
   "<text>"` appends a dated status line; the body above stays verbatim.
2. **Merges** — write the merged body to a scratch file, then
   `bash "$HOME/.claude/lib/memory.sh" add <kind> --title "<title>"
   --body-file <file> --supersedes <first source>` (next-free ID, forward
   link, the first source marked superseded); each other source:
   `memory.sh status <ID> "superseded by <new-ID>"`. Source bodies stay
   verbatim for history. Merged body:
```
    followed by the existing merged-body sub-bullets (Reference lines, caveman pass, frontmatter fields) and the existing item 4 renumbered 3 (inline caveman compression, unchanged). Delete `After each write, regenerate Index from body when rows changed.`
  - STEP 4 block: delete the `PREFIX_MAP` declaration, its comment and the `# All body entries have Index rows; no orphans` loop (through its `done`), and put in their place:

```bash
# Structure: heading shape + unique IDs (v2 registries; a v1 one is named
# and skipped). Same verify the writer runs after every add.
bash "$HOME/.claude/lib/memory.sh" check .claude/memory \
  || echo "CHECK FAILED: fix the lines above before certifying"
```
  - Report sample `INDEX SANITY: OK` → `CHECK: OK`.
  - Failure table row `| Index sanity FAILED at STEP 4 | Print exact missing/orphan IDs. …` → `| \`memory.sh check\` FAILED at STEP 4 | Print its culprit lines. Do NOT auto-fix — user re-runs or hand-edits. |`.
  - `:322-323` fixtures list `red6-orphan` → `red6-check`.

- [ ] **Step 4: test-prompts.json** id 1 `expected` → `"Skill runs PRECHECK (refuses if working tree dirty on .claude/memory/), audits all 5 registries for A) obsolete/superseded entries B) similar merge candidates C) bloated prose, presents the per-registry PRUNE PLAN with category-level approval gate, applies only approved changes (status lines and merges through lib/memory.sh, never hard-delete), then runs memory.sh check and the fidelity census at STEP 4."`

- [ ] **Step 5: Run, expect green** — `make test suite=skills/prune-memory/tests/run-deterministic.sh` → RED-1..7 all GREEN (RED-5 still green: its journal-only sandbox has no registry, `check` prints nothing).
Run: `grep -n 'Index' skills/prune-memory/SKILL.md` → no writer step mentions an Index.

- [ ] **Step 6: Commit**

```bash
git add skills/prune-memory
git commit -m "feat(prune-memory): v2 registries — § D dropped, status and merges through memory.sh, STEP 4 verify = memory.sh check"
```

---

### Task 7: upgrade this repo's registries (the one curation)

**Files:**
- Modify: `.claude/memory/{decisions,learnings,blockers,evals}.md` (by the lib only)

- [ ] **Step 1: Dry run on a copy** — 

```bash
d=$(mktemp -d); mkdir -p "$d/.claude/memory"; cp .claude/memory/*.md "$d/.claude/memory/"
bash lib/memory.sh -C "$d" upgrade && bash lib/memory.sh -C "$d" check && echo DRY-OK
```
Expected: four `memory: upgraded …` lines, `DRY-OK`.

- [ ] **Step 2: Upgrade in place and commit through the chokepoint**

```bash
bash lib/memory.sh upgrade
bash lib/memory.sh check && echo CHECK-OK
bash lib/memory.sh index blocker | grep -E 'BLK-03[234]'
bash "$HOME/.claude/lib/memory-commit.sh" commit "chore(memory): registries v2 — Index removed, Index-only dates and statuses materialized (memory.sh upgrade)"
```
Expected: `CHECK-OK`; BLK-032..034 rows read `resolved` with a date; memory-commit prints a hash (rc 0: the Index lines sit before the first entry, every other change is an insertion).

- [ ] **Step 3: Verify the live facts**
Run: `make test suite=lib/tests/memory.test.sh` → T12 (live check) green.
Run: `bash -c '. lib/reconcile.sh; reconcile_blk_open .claude/memory/blockers.md | cut -f1 | tr "\n" " "'` → `BLK-001 BLK-003 BLK-017 BLK-018 BLK-021 BLK-022 BLK-029 ` (no 032..034).
Run: `grep -c '^## Index' .claude/memory/*.md` → 0 everywhere.

---

## Final verification (main loop, after Task 7)

`make test` all suites green; `shellcheck lib/memory.sh lib/reconcile.sh lib/memory-commit.sh hooks/session-start.sh`; `bash lib/memory.sh check`; `git status --short` clean; no file outside this repo changed (`git -C <proj> status --short .claude/memory` empty for the projects listed in the spec § 2.4 note).
