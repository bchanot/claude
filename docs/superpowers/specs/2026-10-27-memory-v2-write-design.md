# Memory v2, write side: design

Phase 4a of BDR-125. Contract `.claude/tasks/contracts/2026-10-27-memory-v2-write-2030.md`.
Shell only, no mod. Four gated choices (2026-10-27): `memory.sh upgrade` runs in this
branch; mkdir lock in the git common dir; `registry v1` warn in the session banner;
the LRN "Applies to" and EVAL "Action" Index columns are dropped.

## 1. Problem

Five registries, ~1 MB, written by prose instructions in nine skills and agents: every
writer re-derives the next ID, appends by Edit or ad hoc shell, and is told to maintain a
`## Index` table that drifts (16 missing rows today). Status lives in three places (header
tag, body line, Index column) and `lib/reconcile.sh` reads it with a lexical grep that drops
the entry's own header and takes `fail-open` or `` `data:` OPEN `` in a Solution line for a
status: BLK-032..034 are `[resolved]` and reported open. Thirteen supersessions and eleven
BDR statuses exist only in an Index row.

## 2. Shape

### 2.1 `lib/memory.sh` (sourceable + CLI, the `project-rules.sh` skeleton)

```
memory.sh [-C <dir>] add <kind> --title <t> --body-file <f> [--status <s>] [--supersedes <ID>]
memory.sh [-C <dir>] status <ID> <text>
memory.sh [-C <dir>] journal <line> [--date YYYY-MM-DD]
memory.sh [-C <dir>] index [<kind>]
memory.sh [-C <dir>] check [--staged] [<memory-dir>]
memory.sh [-C <dir>] upgrade [<memory-dir>]
```
`<kind>` = `decision | learning | blocker | eval` → `decisions.md` BDR, `learnings.md` LRN,
`blockers.md` BLK, `evals.md` EVAL. Registry dir `.claude/memory` under `<dir>` (default
cwd). Unknown verb or bad arity → usage, rc 2. Every refusal names its reason on stderr,
rc 2, nothing written. `/usr/bin/grep` pinned (LRN-074), no `grep -q` in a pipe (LRN-189),
no census-banned idiom (BDR-110). Functions ≤ 25 logic lines, ≤ 5 locals, lines ≤ 80.

**add**: under the lock, next ID = max `^## <PREFIX>-[0-9]+` + 1, zero-padded to 3 digits
(4 past 999). Appends at end of file (after a blank line):
```
## BDR-129 — <title> [<status>] (<date>)
<body file verbatim, trailing blank lines trimmed>
```
`[<status>]` only with `--status`; `(<date>)` always (today, or `MEMORY_DATE` for tests).
Title refused when empty, over 160 chars, or containing a newline, `[`, `]` or `|`. Body
file refused when missing or empty; a blocker body must hold at least one backtick span
(the "quotes ≥ 1 error verbatim" rule). `--supersedes <ID>` (same registry, must exist):
the new body gets a last line `Supersedes [[<ID>]].` and the old entry gets a status line
`superseded by <new ID>` in the same lock. After the write, `check` runs on the file; a
failure restores the file from the pre-write copy and returns rc 2. On success the new ID is
the only stdout line. A v1 file (no marker, § 2.4) is written the same way with a stderr
warning; its post-write `check` is skipped.

**status**: `status <ID> <text>` inserts `- **Status (<date>)**: <text>` as the last body
line of the entry: before the `---`/blank run that precedes the next `^## ` heading, or at
end of file. Never rewrites a line. Unknown ID → rc 2.

**journal**: appends `<line>` under `## <date>` in `journal.md`; the heading is created at
end of file (preceded by a blank line) when absent; `(cont.)` legacy headings are not
matched. Multi-line input → rc 2.

**index**: prints a markdown table `| ID | Date | Title | Status |` for one kind or all four
(one table per registry, registry name as a line above). Date = heading `(YYYY-MM-DD)`, else
the first `- **Date**:` body line, else empty. Status = § 2.2 normalized value. Reads
headings and bodies only; a `## Index` block, if any, is ignored.

**check**: on every registry of the dir (journal excluded): every `^## <PREFIX>-` heading
matches `^## <PREFIX>-[0-9]{3,} — .+$`; IDs unique; a v2 file has `format: 2` and no
`^## Index` line; a v1 file is reported `v1: <file>` on stderr and does not fail the run
(lenient by design, the upgrade is the user's call).
`--staged`: `git diff --cached -U0 -- <registry files>` must contain no `-` line other than
the diff header, i.e. no removed line inside an existing entry (an appended line is a `+`).
`make test` runs `check` on this repo's `.claude/memory`. `lib/memory-commit.sh` runs
`check --staged` after `git add` and before `git commit`; a failure is rc 6, nothing
committed, so an in-place header flip (today's practice, 438462f) is caught at the one
chokepoint flows use. `/prune-memory` curation commits go through `/commit-change`, not
memory-commit.sh, so they need no marker; the removal rule is by chokepoint, not by commit
recognition.

**upgrade** (§ 2.3). The generated pre-commit hook (`lib/gitflow.sh`) is untouched.

### 2.2 Shared status parser (`lib/memory.sh`, sourced by `lib/reconcile.sh`)

`memory_entry_status <file> <ID>` prints the winning candidate line, `memory_status_word`
normalizes it. Entry = own heading through the line before the next `^## ` heading, fenced
blocks skipped. Candidates, in document order:
- the heading's trailing tag `[<tag>]` (optionally followed by `(<date>)`), never a `[…]`
  elsewhere in the title (BDR-014 `[triggers]`);
- a body line whose bold **label** carries a status keyword: `^- \*\*[^*]*(Status|Resolution|
  Action|UPDATE|FINAL)[^*]*\*\*` (BLK-008 `**2026-06-23 FINAL — RESOLVED**`, BLK-009
  `**2026-07-06 UPDATE — RESOLVED**`, `**Status (2026-10-23, reconcile)**`), plus the v1
  `^Status:` / `^- Status:` lines.
A word in free prose (`fail-open`, `` `data:` OPEN `` in a Solution line, `upstream` in a
sibling title) is never a candidate. Last candidate wins. Normalized value = first of
`resolved | upstream | open | accepted | implemented | shipped | superseded | deprecated |
proposed | keep | correct | deprecate` found case-insensitively in the candidate, else the
candidate's first 40 chars. `reconcile_blk_current_status` becomes a one-line call; its
`*RESOLVED*|*resolved*` classification stays. Regression fixture
`lib/tests/fixtures/blockers-v2-status.md`: BLK-032..034 copied as written today plus
BLK-008/009-shaped compounds and a Solution line with `fail-open`; expected open set
excludes all of them. `run-reconcile.sh` T1/T2 unchanged and green.

### 2.3 `upgrade` and the Index removal

`upgrade [<memory-dir>]`, idempotent, per registry (journal untouched): refuse without
frontmatter (rc 2, the two non-template dialects are not upgraded by this verb); already
`format: 2` → no-op. Steps, on a tmp copy, then one `cat` into place:
1. For every Index row `| ID | date | title | status |` with a known ID: if the heading has
   no `(date)` and the body no `- **Date**:` line, insert `- **Date**: <date>` as the first
   body line; if the status column is non-empty and its normalized value differs from the
   parser's (or the parser finds none), append `- **Status (<today>, upgrade)**: <column
   text verbatim>` as the last body line. LRN "Applies to" is dropped; EVAL "Action" is
   already a body label.
2. Insert `format: 2` after line 1 (`---`).
3. Delete from `^## Index` through the table's last `|` line and the blank line after it.
4. Oracle, before the file is replaced: heading count and every heading line unchanged;
   for every former row, `index` date == row date and normalized status == normalized
   column; `check` passes. Any failure → file untouched, rc 2, the row named.
Runs in this branch on this repo's four registries as one `chore(memory)` commit (gated
2026-10-27; BDR-045's chore branch is for a standalone curation, this one ships with its
tool). Other projects are not touched: the user runs `memory.sh -C <proj> upgrade` when
they choose to.

### 2.4 v2 marker and v1 projects

Marker = `format: 2` on line 2 of the YAML frontmatter. `templates/memory/*.md` carry it and
lose the `## Index` block (new projects born v2; the template comment keeps the entry
shape with `## <ID>-XXX — <title> (<date>)`). A registry without the marker is v1: `add`
and `status` still write (lenient), `check` names it, and `hooks/session-start.sh` prints
`│  ⚠️  registry v1: .claude/memory — memory.sh upgrade │` when the cwd has a
`.claude/memory/*.md` without the marker. doctor.sh is machine-scoped and stays untouched.

### 2.5 Lock

`add`, `status` and `journal` take `<git-common-dir>/memory.lock` by `mkdir` (atomic on
POSIX, no `flock(1)`: absent on macOS, BDR-110), retry every 0.2 s up to 10 s, steal a lock
older than 30 s. Outside a git repo → `${TMPDIR:-/tmp}/memory-<cksum of the dir path>.lock`.
Released by an EXIT trap. The lock serializes writers of one repository (worktrees share
the common dir); two branches allocating the same ID still collide at merge, and `check`
(ID uniqueness) in `make test` reports it.

## 3. Citers (same branch, census green)

- `skills/capitalize/SKILL.md` STEP 4/5: body to a scratch file, `memory.sh add`, `memory.sh
  journal`; dedup read (:143) on headings and bodies only. `close` inherits.
- CAPITALIZE steps of feat, bugfix, hotfix, ship-feature, init-project, commit-change +
  `agents/commit-changer.md` (MODE apply with `-C <dir>`): same calls, "Update the Index"
  lines removed. The `CLAUDE.md "Memory registries" (Always English, always caveman)`
  citations stay byte-identical.
- `skills/prune-memory/SKILL.md`: § D Index drift removed; STEP 3.2 status flags and 3.3
  mark-superseded go through `memory.sh status`; "regenerate Index" removed; STEP 4 verify
  runs `memory.sh check`; `tests/run-deterministic.sh` RED-6 asserts the STEP 4 block calls
  `memory.sh check` (flip test); `test-prompts.json` id 1 reworded.
- `lib/analyze-before-plan.md`, `agents/analyzer.md`, `skills/reconcile/SKILL.md`,
  `lib/reconcile.sh` header comment: "never the Index" sentences become "headings only, no
  Index exists in v2"; PASS 1 unchanged.
- `lib/capitalize-commit.md`: rc 5 and the new rc 6 documented.
- `CLAUDE.global.md` "Memory registries": one sentence "Write only via `bash
  ~/.claude/lib/memory.sh` (add / status / journal), never by Edit or append." and the
  "Registries load every session; caveman cuts ~40%…" sentence becomes "Registries are read
  by the planning flows, never loaded whole; caveman keeps every read and injection small."
  Net lines ≤ 0 (file at 333, warn at 320).
- `skills/onboard/SKILL.md` S7 journal line and `agents/onboarder.md` template copy: unchanged
  mechanism (templates now v2); onboard S7 may call `memory.sh -C <proj> journal`.
- `mods/model-router/routing.json`: no new row (lib, not a skill).

## 4. Tests (`lib/tests/memory.test.sh`, hermetic, mktemp fixture with a git init)

Round-trip (`add` → heading, ID on stdout, `index` row, `check` green); refusals (kind,
title chars, empty body, blocker without backtick, unknown ID); `status` placement before a
trailing `---` and at EOF; `journal` new and existing date; `--supersedes` both sides; race:
two `add` in background on the same registry → two distinct consecutive IDs, `check` green;
lock steal after a stale dir; v1 file: `add` warns and appends, `check` names v1,
session-start banner line present (fixture dir) and absent on v2; `check --staged` red on a
removed line, green on an appended one; `memory-commit.sh` rc 6 on that red; `upgrade`:
fixture with Index-only statuses, supersessions and dates → materialized, Index gone,
marker set, oracle green, idempotent second run; `upgrade` refuses a no-frontmatter file and
restores on an oracle failure (fixture with a tampered row). Parser: BLK-032..034 fixture
(§ 2.2). Doctrine-citers census, effort-routing lock, portability census, shellcheck,
`make test` all green. No other project's `.claude/memory` differs (`git -C <proj> status`
on the known registry projects, run by the verifier).

## 5. Out of scope (dropped or later)

Meta line, 434-entry backfill, scope/critical labels, triggers field, English validator,
upgrade of the pipe-heading (faunosteo) and `# Blockers (BLK)` (game) dialects, a `/memory`
skill, read-side changes (4b-4d), the "Session start" directive of CLAUDE.global.md.
