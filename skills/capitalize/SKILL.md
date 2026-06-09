---
name: capitalize
description: |
  Use when about to /clear or /compact and the current conversation holds
  decisions, learnings, blockers, or eval results that were never written to
  `.claude/memory/`. Use to flush important uncapitalized context before it is
  wiped, or when unsure whether the session's insights already reached the
  registries. NOT the fresh end-of-session ritual (that is /close) and NOT
  registry curation (that is /prune-memory).
  Triggers: "capitalize", "capitalise", "before clear", "before compact",
  "save before clear", "flush memory", "don't lose this", "what's not logged
  yet", "avant de clear", "avant compact", "sauvegarde avant clear",
  "capitalise ce qui manque".
argument-hint: (none — scans the current conversation against .claude/memory/)
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
---

# /capitalize — Flush uncapitalized context before a wipe

Salvage the registry-worthy insights from **this conversation** that were
never written down, right before `/clear` or `/compact` destroys them.

Operates on conversation memory + git state + the existing registries. Does
NOT re-read source code.

## What makes this different from /close

| Situation | Skill |
|-----------|-------|
| About to `/clear` or `/compact` — salvage what the session produced but never logged | **/capitalize** (this) |
| Deliberate end-of-session ritual, fresh 3-question prompt | `/close` |
| Registries too long / noisy — curate, merge, compress | `/prune-memory` |
| Token-compress one registry file | `/caveman:compress <file>` |

The signature move of THIS skill is **STEP 2 — DEDUP**: every candidate is
checked against what is already in the registries, and anything already
captured is dropped silently. `/close` does not dedup; it asks fresh. Running
`/capitalize` right after a `/close` should propose (near) nothing.

## STEP 0 — PRECHECK

```bash
ls .claude/memory/decisions.md .claude/memory/learnings.md \
   .claude/memory/blockers.md .claude/memory/evals.md \
   .claude/memory/journal.md 2>/dev/null
```

- `.claude/memory/` missing entirely → print and STOP (do NOT create here —
  that is `/onboard` / `/init-project` responsibility):
  ```
  ⚠️  .claude/memory/ absent. Lance `/onboard` (ou `/init-project`) pour créer
     les registres avant de capitaliser.
  ```
- Some files missing → name them, create each from
  `~/.claude/templates/memory/<name>.md`, continue.

## STEP 1 — SCAN THE CONVERSATION

Mine the conversation (and git, for grounding) for capitalize-worthy items.
Route each by the CLAUDE.md "Memory registries" rules:

| Found in conversation | Registry | Prefix |
|-----------------------|----------|--------|
| Choice with tradeoffs you'd defend (framework, scope, naming, architecture) | `decisions.md` | BDR |
| Reusable pattern / gotcha / "don't do X" / surprising API behavior | `learnings.md` | LRN |
| Dead end with identified root cause, friction > 15 min, upstream bug | `blockers.md` | BLK |
| Quality verdict on something Claude produced (report, plan, generated code) | `evals.md` | EVAL |
| One-line timeline of the session | `journal.md` | (date) |

Grounding scan (do not re-read code):

```bash
git log --oneline -10
git diff HEAD --stat
git status --short
date +%Y-%m-%d
```

For each candidate, draft the fields the target registry's schema expects
(read the YAML header of that file if unsure — e.g. decisions need
decision/why/alternatives; blockers need friction/real_cause/solution/status).

**Skip the trivial.** If it is reversible in under 10 min with no cross-file
impact, it is not a decision. If it is a one-shot fact, not a reusable
pattern, it is not a learning. Noise hurts the every-session re-read.

**One incident → one primary registry.** Do not fan a single event across
registries. A resolved gotcha that cost time is a *learning* (the reusable
pattern) — not *also* a blocker. Open a blocker only when the friction is
unresolved, or when the friction itself (not the lesson) is the durable
record. The same event written to two registries is a near-duplicate in the
every-session re-read.

## STEP 2 — DEDUP AGAINST THE REGISTRIES ★ the whole point

For every candidate from STEP 1, check whether it is already captured before
proposing it. Pull the distinctive keyword(s) of the candidate and grep the
relevant registry (Index + bodies):

```bash
# Example: candidate is a learning about "cd -P symlink resolution"
grep -niE 'symlink|cd -P|BASH_SOURCE' .claude/memory/learnings.md
```

Also scan the journal tail for `<ID> capitalized` lines — the session may
have already logged it earlier:

```bash
grep -nE '(BDR|LRN|BLK|EVAL)-[0-9]+ capitalized' .claude/memory/journal.md | tail -20
```

Classify each candidate:

- **ALREADY CAPTURED** — strong match on an existing entry → drop it silently,
  remember the existing ID (shown in the report footer, not proposed).
- **POSSIBLE DUP** — partial / uncertain overlap with `<ID>` → propose it but
  flag `⚠ maybe dup of <ID> — confirm or skip`.
- **NEW** — no match → propose it normally.

Dedup is semantic, not string-equality. Same root cause described two ways is
still a dup.

## STEP 3 — PRESENT PLAN ★ MANDATORY STOP (approval gate)

One compact screen. Pre-filled drafts, caveman-English bodies (registry rule).
Group by registry. Mark dup flags inline.

```
═══ CAPITALIZE — uncapitalized context before wipe ═══

decisions.md
  ▸ NEW  BDR-019  <title>
         decision: <1 line>  | why: <1 line>  | alts: <if any>
  ⚠ DUP? BDR-0NN  <title>  (maybe dup of BDR-012 — confirm)

learnings.md
  ▸ NEW  LRN-026  <pattern> — <context> — <future use>

blockers.md
  (rien de neuf — tout déjà capitalisé)

evals.md
  ▸ NEW  EVAL-003  <output> — <method> — <anomalies> — action: <keep|correct|deprecate>

Already captured this session (dropped): LRN-023, BLK-006

Action ? (all / pick <IDs> / edit <ID> / skip-all)
```

If a registry has zero NEW + zero DUP → print `(rien de neuf — déjà à jour)`.
Wait for input. Default = nothing written (journal line still goes in STEP 5).

## STEP 4 — WRITE APPROVED ENTRIES

For each approved entry, in registry order:

1. Read the target registry file.
2. Next sequential ID = scan existing `## <PREFIX>-NNN` body headings, take max,
   +1 (e.g. last `## BDR-018` → `BDR-019`). Never reuse, never renumber.
3. Append the full entry at the **end** of the body (never rewrite existing
   entries — append-only).
4. Add one row to the `## Index` table at the top: `| <ID> | <date> | <title>
   | <status> |` (column set varies per file — match that file's header row).
5. Body in **caveman English** per CLAUDE.md memory format: drop articles +
   filler, fragments OK, short synonyms. Keep code/URLs/error-quotes/IDs/dates
   verbatim. Entries are ALWAYS English even if the STEP 3 prompt mirrored the
   user's language.

## STEP 5 — JOURNAL LINE (always)

Write one timeline line under today's `## YYYY-MM-DD` heading — even if every
candidate was skipped or already captured.

- Heading exists → append a bullet.
- Missing → create `## YYYY-MM-DD` and write 3-5 bullets summarizing the session.

Reference any IDs written this run: `BDR-019 + LRN-026 capitalized before /clear.`

## STEP 6 — FINAL OUTPUT + HANDOFF

```
CAPITALIZE COMPLETE — <YYYY-MM-DD>  (pre-wipe flush)
  decisions.md : +<N> (BDR-019)        | 0
  learnings.md : +<N> (LRN-026)        | 0
  blockers.md  : 0 — already up to date
  evals.md     : +<N> (EVAL-003)       | 0
  journal.md   : +1 line under ## <date>
  dropped as already-captured: LRN-023, BLK-006

✅ Context flushed. Safe to /clear or /compact now.
```

The closing line matters — this skill exists to make the wipe safe, so confirm
it explicitly.

## Rules

- **Never invent.** Every entry grounded in this conversation or git history.
  No fabricated "lessons" to fill the screen.
- **Dedup before proposing.** Re-logging an existing entry is the #1 failure
  mode of this skill. When in doubt, flag as `⚠ DUP?` and let the user decide —
  never silently create a near-duplicate.
- **Append-only.** Never overwrite or renumber existing entries.
- **Caveman English** bodies, always English, per CLAUDE.md memory format.
- **Journal always writes**, even on `skip-all` — timeline logging is cheap and
  noise-tolerant.
- **Skip trivial** for the 4 ID registries; journal excepted.
- `.claude/memory/` missing → STOP at STEP 0, do not create the structure here.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Proposing items already in the registries | STEP 2 dedup is mandatory. Grep keywords + journal `capitalized` lines first. |
| Re-running after `/close` and re-logging the same items | Expected output after `/close` is `(rien de neuf)`. If it proposes the just-closed items, dedup failed. |
| Renumbering or reusing an ID | IDs are stable + sequential. Max existing +1. |
| Writing prose bodies | Registries are caveman-English. Fragments, no articles/filler. |
| Logging a trivial reversible tweak as a decision | Decision = tradeoff you'd defend, cross-file or >10 min to reverse. Else skip. |
| Fanning one incident across registries (e.g. a resolved gotcha as both LRN and BLK) | One incident → one primary registry. Reusable pattern → LRN. Unresolved friction / the friction itself → BLK. Don't write the same event twice. |
| French/English entry text | Prompt may be French; written entry is always English. |
| Creating `.claude/memory/` when absent | Not this skill's job — STOP and point to `/onboard`. |

## Red flags — STOP

- About to append an entry without having grepped the registry for it → dedup skipped.
- Proposing 6+ entries from a short conversation → over-capturing noise; keep only what you'd defend.
- Rewriting an existing entry "to update it" → append-only violation; add a new entry with `supersedes`.
- Same incident headed for two registries (LRN + BLK for one event) → pick the one primary registry.

## TDD note (skill itself)

v1 ships without baseline pressure tests per superpowers:writing-skills Iron
Law. The STEP 3 approval gate is the human safety net (same posture as
`/prune-memory` v1). Recommended baseline before relying on it:

1. **RED** — give a subagent a synthetic transcript containing 2
   already-captured insights + 1 genuinely new learning, plus a registry
   snapshot. Ask it to "save what matters before /clear" WITHOUT this skill.
   Document whether it re-logs the captured ones (no dedup) or misses the new one.
2. **GREEN** — invoke `/capitalize` on the same inputs. Verify STEP 2 drops the
   2 dups and proposes only the 1 new entry.
3. **REFACTOR** — log any new rationalization (e.g. "it's basically the same so
   I'll just append anyway") and add a counter to Common mistakes / Red flags.

Until done, treat as v1-untested; the approval gate gates every write.
