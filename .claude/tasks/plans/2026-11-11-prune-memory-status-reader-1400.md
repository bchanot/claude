# FEAT — prune-memory-status-reader (/feat D4, 2026-11-11) — r3

Source: .claude/tasks/TODO.md § Release 3.0.0 scope, D4 (user 2026-11-11 [gated]: "/prune-memory reads statuses through memory.sh (v1+v2), example IDs 9xx"); evidence .claude/tasks/plans/2026-11-09-bdr125-obsolescence-clean-1650.md D4.

## User decisions 2026-11-11 [gated] (after challenge round 1)
- ONE classifier for decisions and blockers: generalize `reconcile_blk_classify` to a prefix (strict word on v2, single status word on v1 via `_mem_v1_word`, never the `## Index`, never prose). Same grammar for both registries.
- Unreadable statuses: ONE count line per registry, info only: outside "all", never a candidate, never written by the skill; the status word comes from the user, per ID, never from the entry text. Dialect migration is a separate follow-up, logged, not done here.

## Round 2 rulings (no BLOCKER; CONCERNS robustness 4, simplicity 1, correctness 2)
- STEP 4 status drift check DROPPED (simplicity 1: ungated new certification gate; it misfires on every approved merge and on v1 prose compression, robustness 2/3, correctness 2). Logged as follow-up.
- v1 decisions line selector widened (robustness 1): `statut`, `superseded`, `deprecated` added for the BDR range, through an env override of the existing selector (BLK path untouched).
- One status-line rule for compression and merges, v1 included (correctness 1); merged status written by `--status <word>` shown on the [B] line, evals included (robustness 4, 9).
- v1 date dialects give no 90-day candidate: stated in 1.A, part of the dialect follow-up (simplicity 2, correctness 6).
- RED-9: no `grep -P`, no `sed -i` (portability census); BLK rows cut to one; census on `status: ` (catches backticked forms); extract_block anchored.

## Context
- skills/prune-memory/SKILL.md raw `status: …` wording at :33-34, :81-82, :87-89, :122-123, :130, :252, :260-261; "frontmatter" at :157, :159. v2 registries have no per-entry frontmatter: heading `## ID — title [status] (date)` + `- **Label**: value` lines + dated `- **Status (date)**:` lines. On v1 files `memory.sh add --status s` writes a `- **Status**: s` body line (lib/memory.sh:396-399).
- Real data (read-only, challenge rounds): `memory.sh index decision` Status empty for game 107/107 (`format: 2` but `date: … · status:` dialect), config 19/19, faunosteo 76/80 (v1 words `closed`, `active`), faunosteo-v1-2 79/110. Most stay unreadable with any reader: hence the count line.
- `reconcile_blk_classify` (lib/reconcile.sh:116-137) is BLK-only. Column 2 is `open` for every known non-closed word; the word is column 3.
- `memory_legacy_status <file> <ID> <end>` (lib/memory.sh:642-663) keeps the LAST line of the range matching `_MEM_LEGACY_RE='status|RESOLVED|REVERTED|upstream|resolved|[^a-z]open'` (case-insensitive in the `<end>` awk branch via `RE="$_MEM_LEGACY_RE"`); `_mem_v1_word` needs exactly ONE known word after a status/statut label, else empty.
- run-deterministic.sh: RED-1,2,5,6,7 in Makefile SUITES; `extract_block` matches `"^## " h` unanchored, so "STEP 0" re-arms on `## STEP 0b` (step0.sh today also carries STEP 4's block). RED-6 pins HOME to a sandbox whose `.claude/lib` links this repo's lib. lib/tests/portability-census.test.sh flags `grep -…P` and `sed -i` in tracked *.sh. tests/BACKLOG.md already has a "RED-8 (candidate)": the new test is RED-9.

## Plan
1. lib/memory.sh `memory_legacy_status`, `<end>` branch only: `RE="$_MEM_LEGACY_RE"` → `RE="${MEM_LEGACY_RE:-$_MEM_LEGACY_RE}"`; one comment line: callers may widen the selector (reconcile's decisions range). Default branch untouched; no other memory.sh change.
2. lib/reconcile.sh — generalize, BLK output byte-identical:
   - constant near RECONCILE_DEFER_RE: `RECONCILE_BDR_RE="$_MEM_LEGACY_RE|statut|superseded|deprecated"` with a comment (v1 decisions carry `**Statut** :` and `Superseded by …` lines the blocker selector skips; an unlabelled winner stays unreadable through `_mem_v1_word`).
   - helper:
     ```bash
     _reconcile_status() {  # <file> <ID> <PREFIX> → the current status line
       [ "$3" = BLK ] && { reconcile_blk_current_status "$1" "$2"; return; }
       if memory_is_v2 "$1"; then memory_entry_status "$1" "$2"; return; fi
       MEM_GREP="$RECONCILE_GREP" MEM_LEGACY_RE="$RECONCILE_BDR_RE" \
         memory_legacy_status "$1" "$2" "^##* *$3-[0-9]"
     }
     ```
   - `reconcile_status_classify <file> <PREFIX>` = today's `reconcile_blk_classify` body with `BLK` → `$2` (enumerate, `_mem_heading_ids`) and the status call → `_reconcile_status "$1" "$id" "$2"`; `reconcile_blk_classify() { reconcile_status_classify "$1" BLK; }`. Header "Layers" list: add `reconcile_status_classify` (any prefix; `reconcile_blk_classify` = its BLK wrapper).
3. skills/prune-memory/SKILL.md STEP 1 — AUDIT: right after "For each target registry…", the status source, run once:
   ```bash
   # Current statuses: one reader for decisions and blockers (BDR-129:
   # strict word on v2, one status word on v1, never the ## Index, never a
   # word in prose). Rows: ID<TAB>open<TAB>word | ID<TAB>unreadable<TAB>line;
   # closed entries (resolved, superseded, deprecated) are omitted.
   for k in decisions:BDR blockers:BLK; do
     f=".claude/memory/${k%%:*}.md"
     [ -f "$f" ] || { echo "== $f: no-file"; continue; }
     echo "== $f"
     ( . "$HOME/.claude/lib/reconcile.sh" \
         && reconcile_status_classify "$f" "${k#*:}" ) \
       || echo "== $f: reader-unavailable"
   done
   ```
   Prose under it: these rows are the ONLY status source of STEP 1.A; a status word in an entry's prose or title is never a status. With a `$ARGUMENTS` filter, use only the rows of the filtered registries. `reader-unavailable` → no status-based candidate for that registry this run (say so in STEP 2). `unreadable` rows → the `[Status unreadable]` count line (STEP 2), never an A candidate.
4. STEP 1.A rules on that source (word = column 3):
   - "Decisions whose word is `proposed` and whose date is older than 90 days → propose `memory.sh status <ID> "deprecated, no follow-up after 90 days"`. Date = the newer of the `memory.sh index decision` Date cell and the date of the entry's last `- **Status (YYYY-MM-DD)**:` line; no date → not a candidate (v1 dialect dates such as `| date |` headings or `date: … ·` lines give none)."
   - Successor rule: "… whose word is still `accepted`" (drop its `memory.sh index decision` mention).
   - "Blockers whose word is exactly `open` (never upstream, accepted or any other word) whose root cause matches a commit in the last 30 days (grep `git log --since=30.days --grep=<keyword>`) → propose `memory.sh status <ID> "resolved <commit>"`."
   - Journal rule unchanged.
5. STEP 2 — PRESENT PLAN example (9xx IDs only, RED-7):
   - :122-123 → `BDR-901 — example proposed decision — word proposed, dated <90+ days ago>` / `→ memory.sh status BDR-901 "deprecated, no follow-up after 90 days"`.
   - [B] line :128-130 → `→ propose: merge into NEW LRN-904 (learnings carry no status) with both bodies appended + caveman pass; sources: memory.sh status <ID> "superseded by LRN-904"`. Census reminder: nowhere in SKILL.md may `status` be followed by a colon and a space in lowercase.
   - new block after [C]:
     ```
     [Status unreadable — info only, never applied, not part of "all"]
       decisions.md: 3 (BDR-905, BDR-906, BDR-907)
       → you give the word per ID: memory.sh status <ID> "<word>"
     ```
   - Prose after the example: a [B] merge of decisions, blockers or evals names the merged entry's status word on its line (default: the sources' common word; sources differ → ask in `edit <ID>`); the count line folds IDs (first 10, then `+N more`); the word always comes from the user, never from the entry text; on a v1 file the status text carries one status word only (else it stays unreadable); a row `heading level` needs its heading fixed to `## ID` first (`memory.sh status` cannot reach it). Approve prompt unchanged.
6. STEP 3, one definition used by 3.2 and 3.3 — a STATUS LINE is any line of the entry that holds (case-insensitive) `status`, `statut`, `resolved`, `reverted`, `upstream`, `superseded`, `deprecated` or the word `open`, or a `- **<label>**:` line whose label holds status/resolution/action/update/final.
   - 3.2 Merges: `memory.sh add <kind> --title … --body-file … [--status <word>] --supersedes …` with the word shown on the [B] line (decisions, blockers, evals; learnings none). The merged body drops the sources' labelled status lines (`- **Status…**:`, `Status:` / `statut` lines, `- **Resolution|Action|Update|Final…**:`); the new entry's status is the `--status` word (v2: heading tag; v1: a `- **Status**:` body line, and a later prose STATUS LINE can make it unreadable: it then shows in the count line). Replace the "Keeps frontmatter fields: …" bullet with "`memory.sh add` writes the heading (new ID, title, date) and the status; the body keeps the union of `**Reference**:` lines."
   - 3.3 Compression: "preserve frontmatter exactly (id, date, title, status, references)" → "keep VERBATIM the heading line, every `- **Label**:` key and every STATUS LINE; rewrite only the other prose."
7. Core principles :33-34, What NOT to prune :252, Common mistakes :260-261: `status: superseded by …` / `status: deprecated` / `status: superseded` → "a `superseded by <ID>` / `deprecated` status written by `memory.sh status`"; "Entries the user marked `status: accepted` in the current session" → "Entries whose status the user set this session". After the run SKILL.md holds no `status: ` (lowercase, colon, space) and no `frontmatter`.
8. skills/prune-memory/tests/run-deterministic.sh:
   - `extract_block`: anchor the heading, `$0 ~ "^## " h "( |$)"` (STEP 0 no longer re-arms on STEP 0b); RED-2 and RED-6 stay GREEN.
   - RED-9 (behaviour, LRN-276: runs the shipped STEP 1 block), fixtures written with printf in `$SANDBOX/red9a` and `$SANDBOX/red9b` (no fixture files), HOME pinned like RED-6, `TAB=$'\t'`, assertions `/usr/bin/grep -qxF "<row>"` on the block output (whole-line, fixed string; unreadable rows matched with `/usr/bin/grep -qF "BDR-905${TAB}unreadable${TAB}"`). No `grep -P`, no `sed -i`.
     - red9a decisions.md v2 (`---` / `format: 2` / `---` frontmatter): `## BDR-901 — old idea [proposed] (2026-01-01)` with body "resolved later" → `BDR-901${TAB}open${TAB}proposed`; `## BDR-902 — kept [accepted] (2026-02-01)` + `- **Status (2026-03-01)**: superseded by BDR-903` → no BDR-902 row. red9a blockers.md v1: `## BLK-903 — c` + `- **Status**: upstream` → `BLK-903${TAB}open${TAB}upstream` (wiring only; HM3a covers the BLK cases).
     - red9b decisions.md v1 (no frontmatter): `## BDR-904 — x` + `date: 2026-01-01 · status: accepted` → `BDR-904${TAB}open${TAB}accepted`; `## BDR-905 — y` + `Status: closed.` → unreadable row; `## BDR-906 — z` + `Status: proposed` then a later `- **Statut** : accepted (2026-05-01)` → `BDR-906${TAB}open${TAB}accepted`; `## BDR-907 — w` + `- Status: proposed` then `Superseded by BDR-911 (2026-05-01).` → no `open` row for BDR-907 (unreadable).
     - Census: `/usr/bin/grep -c 'status: ' "$SKILL"` = 0 and `/usr/bin/grep -c 'frontmatter' "$SKILL"` = 0.
     - GREEN when every assertion holds; a RED message names the first failing one.
   - Header comment lists RED-9; summary lines unchanged.

## Edge cases
- No decisions.md / blockers.md: `no-file` line. reconcile.sh missing or failing: `reader-unavailable` line.
- BLK output unchanged (wrapper, default selector): HM1-HM3 and run-reconcile.sh stay green.
- Fixture IDs 9xx only. learnings / evals / journal are not read by the STEP 1 block.
- G7 (memory.sh upgrade may take a stale v1 Index cell): the remedy names `memory.sh status`, never `upgrade`.

## Disposition
honors BDR-129 (strict v2, legacy v1, never the Index: one classifier, both registries), BDR-133 (negated words: `_mem_v1_word`), LRN-276 (RED-9 runs the shipped STEP 1 block), LRN-277 (executor brief forbids stdin readers), LRN-275 (explicit staging), LRN-271 (make test env), LRN-074 (pinned /usr/bin/grep). Deviation from the gated wording "through memory.sh": the classifier lives in lib/reconcile.sh, built on memory.sh readers (user chose it 2026-11-11). Foreign-code style.

## Files (4)
lib/memory.sh, lib/reconcile.sh, skills/prune-memory/SKILL.md, skills/prune-memory/tests/run-deterministic.sh.

## Follow-ups (log in BUGS-FOUND / TODO, not done)
- Dialect migration: `format: 2` registries in `date: … · status:` (game 107 decisions), v1 words outside `_MEM_WORDS` (`closed`, `active`, faunosteo), v1 date dialects invisible to the 90-day rule.
- Status drift check at /prune-memory STEP 4 (classify HEAD vs working, expected-drift set from STEP 2 incl. merges, whole-file restore remedy): dropped from D4 round 2.
