# FIX — handover-memory-status (/bugfix G5, 2026-11-10) — r3 after two challenge rounds

Source: .claude/audits/BUGS-FOUND.md entry G5.

## Diagnosis
Symptom: the client deliverable can list a closed blocker as open, or an open one as closed. `agents/handover-doc-writer.md` STEP 9 (:71-87) says "read each file (full contents, parse manually)" and "`blockers.md` → BLK-XXX entries (open vs resolved)"; §5 "Ce qui vous reste à faire" (:315-318) lists "open `blockers.md` entries" to the client. Statuses parsed from prose are the BLK-032..034 false-open class (BDR-129): a word like "resolved" in a Solution or title line is not a status; the status is the heading `[tag]` or a labelled Status/Resolution/Action/UPDATE/FINAL line, last candidate wins (lib/memory.sh header :28-38). Also `MEMORY_DIR=".claude/memory"` is relative while a dispatched agent's cwd is the session's, not necessarily the project's; the PACKAGE carries `PROJECT: … root=`.
Evidence (2026-11-10, scratch fixtures): `memory.sh index` on a v1 registry whose statuses live only in `## Index` prints empty Date and Status. Robustness r2 probes: `reconcile_blk_open`'s v1 branch drops any line containing the substring "resolved" (reconcile.sh:103), so `Statut : unresolved` and `open (not resolved)` vanish as closed (contradicts BDR-133); a v1 `- **Status**: closed` or a prose `HTTP status 500` line comes out of memory_status_word as a non-word and would land in §5; `### BLK-` entries are invisible to reconcile_enumerate_ids (`^## ` only). Real data: /home/bchanot/Documents/game blockers.md (v2) gives an empty strict status for 15 of 34 blockers (v1 `date: · status:` lines left in an upgraded file), BLK-019 `status: upstream (ops)` among them.
Blast radius: handover-doc-writer synthesize mode only; its orchestrator agents/client-handover-writer.md relays the reports. Other memory readers already go through memory.sh or headings.
RELATED MEMORY: honors BDR-129 (strict reader on v2, legacy lexical reader on v1, never the Index), BDR-133 (a negated status word does not count, v1 included), LRN-055 (a reconciler never trusts the Index); BLK-032..034 (the false-open class); LRN-271 (make test env); LRN-274 (pipefail-safe lib functions); LRN-275 (stage by explicit paths, check commit stat).

## User decisions (2026-11-10) [gated]
- Open blocker for §5 = status not closed (closed = resolved | superseded | deprecated, `memory_closed`): `open` and `upstream` both listed.
- A blocker whose status cannot be read: kept out of §5, flagged in the SYNTH REPORT and relayed to the user by the orchestrator.
- Reading of "cannot be read" (orchestrator, from decision 2, both r2 lenses): no reader maps the status to exactly one known word of `$_MEM_WORDS` (empty, prose, mixed, negated, `closed`/`fixed`/`done`, or an entry under a `###` heading). Fail-safe: such an entry is never listed open and never dropped silently.

## Fix plan (r3)
1. `lib/reconcile.sh`: new public function after `reconcile_blk_open` (header Layers list gets one line):
   ```bash
   # blockers for a client deliverable → "id<TAB>open|unreadable<TAB>word or
   # line": closed ones are omitted. A status no reader maps to exactly one
   # known word is unreadable, never open (BDR-129, BDR-133): v2 strict word,
   # v1 the single word of a status/statut label (_mem_v1_word: prose, mixed
   # or negated lines give none). Entries under a heading the enumerator
   # cannot see (`### BLK-`) are unreadable too.
   reconcile_blk_classify() {
     local id st w v2=""
     memory_is_v2 "$1" && v2=1
     for id in $(reconcile_enumerate_ids "$1" BLK); do
       st=$(reconcile_blk_current_status "$1" "$id")
       if [ -n "$v2" ]; then w=$(memory_status_word "$st")
       else w=$(_mem_v1_word "$st"); fi
       [ -n "$st" ] || w=""
       memory_closed "$w" && continue
       case " $_MEM_WORDS " in
         *" $w "*) [ -n "$w" ] && { printf '%s\topen\t%s\n' "$id" "$w"; continue; } ;;
       esac
       printf '%s\tunreadable\t%s\n' "$id" "${st:0:80}"
     done
     MEM_GREP="$RECONCILE_GREP" _mem_heading_ids "$1" BLK | sort -u \
       | comm -23 - <(reconcile_enumerate_ids "$1" BLK) \
       | while read -r id; do printf '%s\tunreadable\theading level\n' "$id"; done
     return 0
   }
   ```
   (Exact shape is the executor's within the file's style; the contract is the output format and the classification. `return 0`: LRN-274, rc must not depend on the last test under pipefail.) `reconcile_blk_open` is unchanged (/reconcile keeps its own semantics).
2. `agents/handover-doc-writer.md` STEP 9 — LOAD MEMORY REGISTRIES (:71-87), rewrite:
   ```bash
   ROOT="<PROJECT root from the PACKAGE>"
   MEMORY_DIR="$ROOT/.claude/memory"
   test -d "$MEMORY_DIR" || MEMORY_DIR=""
   # Blocker statuses through the shared reader (BDR-129): never parsed by hand.
   B="$MEMORY_DIR/blockers.md"
   if [ -z "$MEMORY_DIR" ] || [ ! -f "$B" ]; then echo "blockers: no-file"
   elif . "$HOME/.claude/lib/reconcile.sh"; then reconcile_blk_classify "$B"
   else echo "blockers: reader-unavailable"; fi
   ```
   (no `bash -c`: settings.json asks on it.) Prose after it:
   - Rows `ID<TAB>open<TAB>word` = the open blockers for §5. Rows `ID<TAB>unreadable<TAB>…` = kept out of §5, their IDs go on the SYNTH REPORT `MEMORY:` line.
   - `blockers: no-file` → no blocker in §5, `MEMORY: no blockers file`. `blockers: reader-unavailable` → no blocker in §5, `MEMORY: reader unavailable`.
   - Read each registry file in full for the narrative fields (titles, decisions, why, alternatives, cause, solution, journal summaries). A blocker's status is never taken from the file's prose, only from the reader above.
   - Bullet list kept; the `blockers.md` line → "BLK-XXX entries: open/unreadable from the reader above, narrative from the file". The `decisions.md` bullet keeps "status" (BDR status handling = G6, not this fix).
   - Memory dir missing or empty: unchanged (git data only, flagged).
3. `agents/handover-doc-writer.md` §5 source list (:317-318): "open `blockers.md` entries" → "open blockers from STEP 9 (unreadable ones excluded)".
4. `agents/handover-doc-writer.md` synthesize mode (:56-57): the inline SYNTH REPORT list becomes a fenced template, same layout as the HANDOVER-DOC REPORT (:842-853):
   ```
   SYNTH REPORT
   STATUS: DONE | BLOCKED
   RUNID: <RUNID>
   PHASE CLUSTERS: <n>
   WORDS: §1=<n> §2=<n> §3=<n> §4=<n> §5=<n> §6=<n>
   MEMORY: unreadable BLK: <IDs comma-separated | none> | no blockers file | reader unavailable
   ```
   The MEMORY line is mandatory on DONE.
5. `agents/client-handover-writer.md` SYNTH REPORT parse (:1150-1152): `STATUS: DONE` with no `MEMORY:` line = malformed (existing retry-once-then-escalate path). `MEMORY: no blockers file` or `MEMORY: reader unavailable` while `<PROJECT root>/.claude/memory/blockers.md` exists = malformed too (a mis-parsed root or a broken lib, never a quiet empty §5). Any MEMORY value other than `unreadable BLK: none` → printed to the user before render, and repeated in the 9.7 final report as a bullet `- Memory: <value>`, with for unreadable IDs the remedy `bash ~/.claude/lib/memory.sh -C <root> status <ID> "<word>, …"` then a re-run.
6. Regression test: new `lib/tests/handover-memory-contract.test.sh` (house style: `set -u`, pass/fail counters, final `handover-memory-contract: %d passed, %d failed`, exit 1 on fail; fixtures under `mktemp -d`, cleanup only by the EXIT trap, printf-built, no link to the real ~/.claude):
   - HM1 census agents/handover-doc-writer.md: contains `reconcile_blk_classify`, `MEMORY: unreadable BLK:`, `reader-unavailable`, a fenced `SYNTH REPORT`; no `parse manually`; no `MEMORY_DIR=".claude/memory"`; no `bash -c`.
   - HM2 census agents/client-handover-writer.md: the SYNTH REPORT parse names `MEMORY:`, treats its absence as malformed, and the 9.7 report carries `- Memory:`.
   - HM3 behaviour, on the SHIPPED snippet: extract the first fenced bash block under `## STEP 9` of agents/handover-doc-writer.md, substitute `<PROJECT root from the PACKAGE>` with the fixture root and `$HOME/.claude/lib` with the repo's lib dir, run it with bash. Fixtures:
     (a) v1 blockers.md (no `format: 2`): `## Index` row says open but body `- **Statut** : resolved` → absent; `- **Statut** : upstream` → `open upstream`; `- **Status**: superseded by BLK-002` → absent; no status line → unreadable; `- **Status**: closed` → unreadable; `- **Statut** : upstream (superseded by #42)` → unreadable (mixed); `- **Statut** : open (not resolved)` → `open open` (negated word ignored, BDR-133; probed 2026-11-10); `- **Statut** : unresolved` → unreadable, never absent; `- **Status**: open` → `open open`; a `### BLK-009` entry → unreadable `heading level`.
     (b) v2 blockers.md (`format: 2`): `## BLK-001 — t [open]` whose Solution says "resolved the issue partially" → `open open`; `- **Status (2026-11-01)**: resolved` → absent; `[upstream]` → `open upstream`; no status → unreadable.
     (c) no blockers.md → `blockers: no-file`; (d) lib dir substituted with an empty dir → `blockers: reader-unavailable`.
7. Bookkeeping (orchestrator): BUGS-FOUND G5 FIXED; new BUGS-FOUND lines (not fixed here): (G6) handover-doc-writer §6.1 vulgarizes BDRs with no status filter (a superseded decision can read as current); (G7, unverified) `memory.sh upgrade` `mem_want` may take a stale v1 Index cell over a `**Statut** :` body (`_mem_verdict_diff` skips Index-stated IDs): check before recommending upgrade on v1 repos; (G8) handover-doc-writer STEP 10 `git log` and other paths are cwd-relative, not `$ROOT`-rooted, and the PACKAGE `PROJECT:` line is space-separated (a root with a space mis-parses; the step 5 check only catches it when blockers.md exists).

## Edge cases
- Agent cwd ≠ project: STEP 9 is rooted on `$ROOT` (other relative paths: G8).
- A v1 `## Index` placed after the last entry can leak into that entry's legacy range (memory_legacy_status reads to the next `## BLK-`): an Index row's text may become its status line. _mem_v1_word then needs a status/statut label with exactly one word, so a table row gives none → unreadable (flagged), not a false open.
- v1 title-suffix statuses (`— RESOLVED` in the heading) are not read by memory_legacy_status's default range: such entries come out unreadable (flagged), the remedy is `memory.sh status` or `upgrade`.
- v2 registries with leftover v1 `status:` lines (game repo: 15/34) come out unreadable: correct per BDR-129, the flag + remedy reach the user in 9.7.
- Entries after an unclosed fence: the enumerator and `_mem_heading_ids` are both plain greps, same view; accepted limit as in /reconcile.
- No `bash -c`, no write: the snippet only reads. Sourcing reconcile.sh sets `-uo pipefail` in the agent's shell, as /reconcile already does.

## In-force
BDR-129, BDR-133, LRN-055, BLK-032..034, LRN-271, LRN-274, LRN-275. Foreign-code style (prompt files keep their voice and layout; reconcile.sh keeps its function/comment style).
Files: lib/reconcile.sh, agents/handover-doc-writer.md, agents/client-handover-writer.md, lib/tests/handover-memory-contract.test.sh (new).

## Challenge summary
- Round 1: BLOCKER (v1 Index fallback re-opened the bug) → r2 legacy reader.
- Round 2 (cap reached, no round 3): correctness CONCERNS(3), robustness CONCERNS(3), simplicity CONCERNS. Folded into r3: classification by known word (v1 `_mem_v1_word`, unreadable bucket), reconcile_blk_open dropped from the snippet (its v1 substring close), `###` entries flagged, no-file vs reader-unavailable split + orchestrator check, MEMORY carried to the 9.7 report with remedy, fenced SYNTH REPORT, HM3 runs the shipped block, decisions bullet keeps "status", Index-after-entries edge case.
