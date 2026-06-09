---
name: prune-memory
description: |
  Use when .claude/memory/ registries grow too large or noisy — superseded
  entries verbose, similar entries cluttering, journal stale, caveman style
  drifted. Curates the 5 registries via mark-superseded + merge + inline
  caveman compression. Append-only safe (no hard delete). Git is the backup.
  Triggers: "prune memory", "compact memory", "clean memory", "memory
  hygiene", "trier memoire", "nettoyer memoire", "registres trop longs",
  "compresse les memoires".
argument-hint: [optional: decisions|learnings|blockers|journal|evals — default all 5]
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
---

# /prune-memory — Memory registry curation

Operates on `.claude/memory/` in the current project (CWD). Curates the
5 registries: `decisions.md`, `learnings.md`, `blockers.md`, `journal.md`,
`evals.md`.

## Core principles

- **Git is the backup.** Skill writes in-place. PRECHECK refuses to run
  if working tree dirty on registry files.
- **Append-only friendly.** Marks entries `status: superseded by <new-ID>`
  or `status: deprecated` instead of deleting. Body of old entry stays
  for history.
- **IDs stable.** Never renumber. Merges create a new ID; sources keep
  their ID with superseded status.
- **Caveman style enforced.** Per CLAUDE.md memory rule, all writes are
  caveman-style English. Compression rewrites prose to fragments.
- **User approves every category.** No silent changes.

## Quick reference

| When | Use |
|------|-----|
| Add new entry this session | `/close` |
| Token-compress one file (not curating) | `/caveman:compress <file>` |
| Curate: obsolete + merge + caveman | `/prune-memory` (this skill) |

## STEP 0 — PRECHECK

```bash
test -d .claude/memory/ || { echo "no .claude/memory/ in $(pwd)"; exit 1; }
git status --short .claude/memory/ 2>/dev/null
```

If working tree is dirty on any registry file → STOP with: "Commit or
stash pending changes in `.claude/memory/` first. Skill writes in-place.
Git is the only backup."

## STEP 1 — AUDIT (per registry)

For each target registry (filter by `$ARGUMENTS` or all 5):

Read file. Classify candidates into A/B/C/D below. Use today's date for
age comparisons. Today's date is in the system context.

### A. Obsolete — mark-superseded candidates
- Decisions `status: proposed` older than 90 days → propose
  `status: deprecated` (no follow-up).
- Decisions whose body contains "superseded by <ID>" but Index row still
  says `accepted` → propose Index row fix to
  `superseded by <that-ID>`.
- Blockers `status: open` whose root cause matches a commit in last 30
  days (grep `git log --since=30.days --grep=<keyword>`) → propose
  `status: resolved` with commit ref.
- Journal entries older than 180 days with zero cross-reference from
  later entries → propose collapse into 1-line month summary
  (`## YYYY-MM` heading replaces detail).

### B. Similar — merge candidates
- Two+ entries sharing root keyword in title (e.g. `pandoc`,
  `client-handover`, `CSS overlay`).
- Shared file paths in `**Reference**:` lines.
- Same week + adjacent IDs + same domain.
- Use semantic judgment on overlap; don't merge complementary entries
  that cover different angles of one concept.

### C. Bloated — inline caveman-rewrite candidates
- Body > 150 words AND prose-heavy.
- Detect filler density: count `\b(the|a|an|just|really|basically|actually|simply)\b`
  matches; if > 5% of word count → bloated.

### D. Index drift
- Body `## (BDR|LRN|BLK|EVAL)-NNN` heading exists but no matching row
  in `## Index` table → propose Index backfill.
- Index row exists but body entry missing → propose `status: deleted
  (orphaned)` tombstone or removal of Index row (user decides).

## STEP 2 — PRESENT PLAN ★ MANDATORY STOP

Print one block per registry. Example:

```
PRUNE PLAN — decisions.md (N entries → M after if approved)

[A. Obsolete — mark superseded]
  BDR-003 — Gitignore wildcard pattern — status: proposed since 2026-03-12
            → mark: status: deprecated (no follow-up after 90 days)
  BDR-011 — Client handover 4-chapter — body says superseded by BDR-013
            → fix Index: status = "superseded by BDR-013"

[B. Similar — merge]
  LRN-014 + LRN-016 — both pandoc rendering quirks
            → propose: merge into NEW LRN-017 ("Pandoc rendering quirks")
              with both bodies appended + caveman pass; sources marked
              status: superseded by LRN-017

[C. Bloated — inline caveman rewrite]
  BDR-011 — body 612 words, filler density 7.2% → ~380 expected (-38%)

[D. Index drift]
  (none)

Approve per category? (all / a / b / c / d / edit <ID> / skip)
```

Wait for user input. Default = nothing applied.

## STEP 3 — APPLY APPROVED CHANGES

Order: safe → destructive.

1. **Index drift fixes** — no body changes. Backfill missing rows, mark
   orphans.
2. **Status flag updates** — Index row status field only. Body untouched.
3. **Merges** — write new merged entry (next-free ID); source IDs marked
   `status: superseded by <new-ID>` in Index (body kept verbatim for
   history). Merged body:
   - Preserves all `**Reference**:` lines (dedupe identical paths).
   - Caveman pass on prose during merge.
   - Keeps frontmatter fields: id (new), date (today), title, status
     (accepted), references (union).
4. **Inline caveman compression** — preserve frontmatter exactly (id,
   date, title, status, references). Rewrite prose body to fragments:
   - Drop articles (`a`, `an`, `the`).
   - Drop filler (`just`, `really`, `basically`, `actually`, `simply`).
   - Short synonyms (`big` not `extensive`, `fix` not `implement a solution for`).
   - Keep code blocks, URLs, error messages, file paths VERBATIM.
   - Keep IDs (BDR-XXX, LRN-XXX, commit hashes) verbatim.

After each write, regenerate Index from body when rows changed.

## STEP 4 — VERIFY

```bash
# Filename → ID-prefix map. Hard-mapped because filenames don't share
# their first 3 chars with the prefix (decisions → BDR, not DEC).
# v1 bug: derived prefix via `basename | cut -c1-3` → never matched,
# verify printed false-clean signal. Fixed in v1.1 (TDD found it).
declare -A PREFIX_MAP=(
  [decisions]=BDR
  [learnings]=LRN
  [blockers]=BLK
  [evals]=EVAL
)

# All body entries have Index rows; no orphans
for fname in decisions learnings blockers evals; do
  f=".claude/memory/${fname}.md"
  [ -f "$f" ] || continue
  prefix="${PREFIX_MAP[$fname]}"

  /usr/bin/grep -oE "^## (${prefix})-[0-9]+" "$f" | while read marker; do
    id="${marker##\#\# }"
    /usr/bin/grep -q "^| ${id} " "$f" || echo "MISSING INDEX: $id in $f"
  done
  /usr/bin/grep -oE "^\| (${prefix})-[0-9]+ " "$f" | while read row; do
    id=$(echo "$row" | awk '{print $2}')
    /usr/bin/grep -q "^## ${id} " "$f" || echo "ORPHAN INDEX: $id in $f"
  done
done
echo "(blank above = OK)"

wc -l .claude/memory/*.md | grep -v "\.original\.md"
```

Report:

```
PRUNE COMPLETE
  decisions.md : 226 → 184 lines (-19%)
  learnings.md : 190 → 165 lines (-13%)
  blockers.md  : no candidates
  journal.md   :  88 → 62 lines (-30%)
  evals.md     : no candidates

INDEX SANITY: OK
NEXT: review `git diff .claude/memory/`, then `/commit-change`
```

## What NOT to prune

- Journal entries < 30 days old.
- Decisions / learnings with commit references < 14 days old.
- Entries the user marked `status: accepted` in the current session.
- The current session's just-capitalized entries (read `journal.md`
  tail to identify them).

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Renumbering IDs after a merge | IDs are stable. Sources keep their ID + `status: superseded`. New merged entry gets next-free ID. |
| Hard-deleting "obsolete" entries | Forbidden by append-only rule. Use `status: deprecated`. Body stays. |
| Compressing code blocks / URLs / error messages | Caveman compression touches PROSE only. Code, URLs, IDs, error quotes stay verbatim. |
| Running on a dirty working tree | PRECHECK blocks this. Commit first. |
| Compressing the current session's journal entry | Excluded by "What NOT to prune" — current session capitalization is still useful. |
| Merging complementary entries that cover different angles | Merge only when same concept, same scope. Different angles = keep separate. |

## Failure paths

| Situation | Behavior |
|---|---|
| `.claude/memory/` missing | STOP: `no .claude/memory/ in current directory; run from project root` |
| Working tree dirty on registry files | STOP per PRECHECK; tell user to commit/stash first |
| User says `skip` at STEP 2 | Exit cleanly, no writes |
| Merge produces an entry > 600 words | Re-split — merge was too greedy. Re-prompt user to keep separate. |
| Index sanity FAILED at STEP 4 | Print exact missing/orphan IDs. Do NOT auto-fix — user re-runs or hand-edits. |
| Caveman compression result < 20% of original AND original had code blocks | Revert that entry's compression — flag as needing manual rewrite (likely stripped technical detail). |
| Same file already compressed in same session (e.g. via `/caveman:compress`) | Skip C-category for that file; warn user that double-pass risks technical drift. |

## Rules

- No silent writes — every change goes through STEP 2 approval gate.
- No renumbering — IDs are stable across all operations.
- No hard delete in v1 — only mark superseded. (Hard delete opt-in may
  arrive in v2 if explicit demand surfaces.)
- Working tree must be clean before any write — git is the only backup.
- Caveman compression touches prose only; code/URLs/error quotes
  verbatim per CLAUDE.md memory format rule.

## TDD note (skill itself)

v1 ships without baseline test scenarios per superpowers:writing-skills
Iron Law. Recommended before relying on the skill in production:

1. RED: spawn subagent, give it a real `.claude/memory/` snapshot, ask
   "prune obsolete entries". Document what it does naturally.
2. GREEN: invoke `/prune-memory` on the same snapshot. Verify it
   follows STEP 0–4 + respects append-only rule.
3. REFACTOR: log any new rationalizations the subagent finds; add
   counters to the "Common mistakes" / "Failure paths" tables.

Until TDD is done, the skill is v1-untested. STEP 2 approval gate is
the human safety net.
