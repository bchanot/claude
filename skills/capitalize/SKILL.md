---
name: capitalize
description: |
  Use when about to /clear or /compact, or when closing a session, and the
  conversation holds decisions, learnings, blockers, eval results, or
  finished/new TODO items not yet written to `.claude/memory/` or
  `.claude/tasks/TODO.md`. Plain invocation = pre-wipe flush; `--ritual` (or the
  word "close"/"ritual" in the request) = end-of-session reflection mode. NOT
  registry curation (that is /prune-memory).
  Triggers: "capitalize", "capitalise", "before clear", "before compact",
  "save before clear", "flush memory", "don't lose this", "what's not logged
  yet", "avant de clear", "avant compact", "sauvegarde avant clear",
  "capitalise ce qui manque", "close", "end session", "session close",
  "ferme la session", "checkpoint memory", "what did we learn", "retro rapide",
  "fin de journée".
argument-hint: "[--ritual] (scans conversation + git + TODO against .claude/memory/; --ritual adds the 3-question reflection)"
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
---

# /capitalize — Flush uncapitalized context (two modes)

Salvage the registry-worthy insights from **this conversation** that were never
written down — before `/clear` or `/compact` destroys them, or as a deliberate
end-of-session ritual. Also reconciles `.claude/tasks/TODO.md` against what
actually shipped.

Operates on conversation memory + git state + the existing registries + the
TODO. Does NOT re-read source code.

## Modes

| Mode | How triggered | Adds |
|------|---------------|------|
| **default** (pre-wipe flush) | plain `/capitalize`, "before clear", "flush memory" | auto-scan + dedup + TODO reconcile |
| **--ritual** (session-close) | `--ritual` flag, OR `$ARGUMENTS` contains "close"/"ritual", OR invoked via `/close` | everything above **+ STEP 1B** 3-question reflection |

Detect the mode first. Both modes share the SAME dedup (STEP 2), TODO reconcile
(STEP 2B), and approval gate (STEP 3). The signature move is **STEP 2 — DEDUP**:
every candidate is checked against what is already in the registries, and
anything already captured is dropped (its existing ID shown in the footer).
Running `/capitalize` right after a ritual should propose (near) nothing.

This skill is NOT `/prune-memory` (registry curation — merge, compress,
mark-superseded). It only appends.

## STEP 0 — PRECHECK

```bash
ls .claude/memory/decisions.md .claude/memory/learnings.md \
   .claude/memory/blockers.md .claude/memory/evals.md \
   .claude/memory/journal.md 2>/dev/null
ls .claude/tasks/TODO.md 2>/dev/null
```

- `.claude/memory/` missing entirely → print and STOP (do NOT create here —
  that is `/onboard` / `/init-project` responsibility):
  ```
  ⚠️  .claude/memory/ absent. Lance `/onboard` (ou `/init-project`) pour créer
     les registres avant de capitaliser.
  ```
- Some registry files missing → name them, create each from
  `~/.claude/templates/memory/<name>.md`, continue.
- `.claude/tasks/TODO.md` missing → the TODO reconcile volet (STEP 2B) is
  **skipped**. Do NOT create it (same posture as the registries). Registries
  still run.

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

For each candidate, draft the fields the target registry's schema expects (read
the YAML header of that file if unsure).

**Skip the trivial.** If it is reversible in under 10 min with no cross-file
impact, it is not a decision. If it is a one-shot fact, not a reusable pattern,
it is not a learning. Noise hurts the every-session re-read.

**One incident → one primary registry.** Do not fan a single event across
registries. A resolved gotcha that cost time is a *learning* (the reusable
pattern) — not *also* a blocker. Open a blocker only when the friction is
unresolved, or when the friction itself (not the lesson) is the durable record.
The same event written to two registries is a near-duplicate in the
every-session re-read.

## STEP 1B — RITUAL REFLECTION (only in --ritual mode)

Default mode skips this entirely. In ritual mode, after the auto-scan, force the
end-of-session reflection — three questions that surface what the scan may have
missed:

1. **What did you decide?** → decisions.md (BDR)
2. **What did you learn?** → learnings.md (LRN)
3. **What blocked you?** → blockers.md (BLK)

Each answer becomes an additional candidate. It does NOT bypass dedup: every
ritual answer flows into STEP 2 exactly like an auto-scanned candidate. A
reflection answer that is already captured is **dropped, and its existing
`<ID>` is shown in the footer** — same as any other dup, never re-logged. This
is the key difference from the legacy `/close`, which wrote ritual answers fresh
with no dedup.

## STEP 2 — DEDUP AGAINST THE REGISTRIES ★ the whole point

For every candidate from STEP 1 (and STEP 1B), check whether it is already
captured before proposing it. Pull the distinctive keyword(s) of the candidate
and grep the relevant registry (Index + bodies):

```bash
# Example: candidate is a learning about "cd -P symlink resolution"
grep -niE 'symlink|cd -P|BASH_SOURCE' .claude/memory/learnings.md
```

Also scan the journal tail for `<ID> capitalized` lines — the session may have
already logged it earlier:

```bash
grep -nE '(BDR|LRN|BLK|EVAL)-[0-9]+ capitalized' .claude/memory/journal.md | tail -20
```

Classify each candidate:

- **ALREADY CAPTURED** — strong match on an existing entry → drop it silently,
  remember the existing ID (shown in the report footer, not proposed).
- **POSSIBLE DUP** — partial / uncertain overlap with `<ID>` → propose it but
  flag `⚠ maybe dup of <ID> — confirm or skip`.
- **NEW** — no match → propose it normally.

Dedup is **semantic, not string-equality**. The same insight reworded with
different vocabulary is still a dup — read the registry entries and reason about
meaning, do not rely on keyword grep alone. (A reworded "Tailwind classes built
by concatenation get purged at build" still matches an existing "purge strips
concatenated class names" entry.)

## STEP 2B — TODO RECONCILE (both modes)

Runs only if `.claude/tasks/TODO.md` exists (STEP 0). Two passes.

**PASS A — done-detection (TODO → reality).** For each unchecked `- [ ]`, decide
whether the session actually finished it, grounding on git (`git log`,
`git diff HEAD`, `git show`) AND the conversation. Propose `[x]` ONLY when the
task ↔ commit/code map is unambiguous (task "add retry-with-backoff" ↔ a commit
that adds exactly that).
- Partial / umbrella tasks ("harden X" covering 3 things when only 1 shipped) →
  leave unchecked.
- Vague tasks ("Commit", "Deploy", "test it") with no precise git evidence →
  leave unchecked. Never check on assumption or on a guess.

**PASS B — capture (conversation → TODO).** Spot explicit to-dos voiced in the
session ("il faut X", "TODO Y", "à corriger Z", new directives) that are absent
from the TODO → propose adding them as `- [ ]`. Dedup semantically against
existing items first. Capture ONLY what was explicitly stated — do not invent,
expand, or decompose a task into subtasks the user never named.

**Anti-noise filter (PASS B).** NEVER add — or fold into an existing item —
commit / deploy / push / release / tag actions. These are systematic steps the
user performs every session, not tracked work. "push la branche + tag v0.3.0" is
noise even when phrased with action verbs. If such an item ALREADY exists in the
TODO, PASS A may check it when proven done, but PASS B never creates it nor
enriches one with session-derived push/tag/release detail.

**Routing.** A directive that changes the project's ORIENTATION (a policy /
architecture choice, e.g. "GraphQL for all new endpoints from now on") is a
DECISION, not a task → it flows through STEP 1 into decisions.md (BDR), never
into the TODO. Don't confuse an actionable task with an architecture decision.

**Language.** The TODO is **NOT caveman**. Tasks stay in readable, actionable
prose. Caveman is reserved for the `.claude/memory/` registries (STEP 4).

## STEP 3 — PRESENT PLAN ★ MANDATORY STOP (approval gate)

One compact screen. Pre-filled drafts — registry bodies in caveman-English, TODO
lines in plain prose. Group by registry, then a **SEPARATE TODO.md block**. Mark
dup flags inline.

```
═══ CAPITALIZE — <pre-wipe flush | session-close ritual> ═══

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

TODO.md
  ☑ check  "<task>"  (done @ <hash> | conversation)
  + add    "[ ] <new task>"  (said in session, absent)

Already captured this session (dropped): LRN-023, BLK-006
Ignored as noise: "push branch + tag v0.3.0" (systematic action)

Action ? (all / pick <IDs> / edit <ID> / skip-all)
```

The **TODO.md block is approved / edited / skipped INDEPENDENTLY** of the
registry blocks. If a section has zero NEW + zero DUP → print
`(rien de neuf — déjà à jour)`. If a dup was dropped (incl. a ritual answer),
name its existing ID on the `Already captured` line. If the anti-noise filter
dropped a parasite, name it on the `Ignored as noise` line (no silent drops).
Wait for input. Default = nothing written (journal line still goes in STEP 5).

## STEP 4 — WRITE APPROVED ENTRIES

Registries first (in registry order), then the TODO.

Registry entries — for each approved:

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

TODO — for each approved:

- **Check**: flip the exact `- [ ]` line to `- [x]`, leaving the text unchanged.
- **Add**: append `- [ ] <task>` under the right `##` section (create a section
  only if none fits). Plain readable prose, NOT caveman.

## STEP 5 — JOURNAL LINE (always)

Write one timeline line under today's `## YYYY-MM-DD` heading — even if every
candidate was skipped or already captured.

- Heading exists → append a bullet.
- Missing → create `## YYYY-MM-DD` and write 3-5 bullets summarizing the session.

Reference any IDs written this run AND the TODO ops:
`BDR-019 + LRN-026 capitalized; checked 1 done, added 1 task.`

## STEP 6 — FINAL OUTPUT + HANDOFF

```
CAPITALIZE COMPLETE — <YYYY-MM-DD>  (<pre-wipe flush | session-close>)
  decisions.md : +<N> (BDR-019)        | 0
  learnings.md : +<N> (LRN-026)        | 0
  blockers.md  : 0 — already up to date
  evals.md     : +<N> (EVAL-003)       | 0
  TODO.md      : checked <N>, added <M>
  journal.md   : +1 line under ## <date>
  dropped as already-captured: LRN-023, BLK-006
  ignored as noise: push/tag release
```

Then the mode-specific closing line:

- **pre-wipe flush** → `✅ Context flushed. Safe to /clear or /compact now.`
- **session-close ritual** → `✅ Session closed. Next session: read .claude/memory/ at startup.`

The closing line matters — confirm the wipe is safe (default) or the session is
checkpointed (ritual).

## Rules

- **Never invent.** Every entry grounded in this conversation or git history. No
  fabricated "lessons" to fill the screen, no invented TODO subtasks.
- **Dedup before proposing.** Re-logging an existing entry is the #1 failure mode.
  When in doubt, flag as `⚠ DUP?` and let the user decide. Dedup is semantic —
  a reworded dup is still a dup. Applies to ritual answers too.
- **Append-only.** Never overwrite or renumber existing registry entries.
- **Caveman English** registry bodies, always English. **The TODO is plain
  prose, never caveman** — caveman is registries-only.
- **TODO reconcile runs only if TODO.md exists.** Never create it (STEP 0).
- **PASS A checks only on an unambiguous task↔code/commit map.** Partial /
  umbrella / vague → leave unchecked. Never on assumption.
- **PASS B captures only explicit to-dos**, deduped — never invented or
  decomposed.
- **Anti-noise**: never track commit / deploy / push / release / tag.
- **Orientation directive → decisions.md (BDR)**, not the TODO.
- **Journal always writes**, even on `skip-all`.
- **Skip trivial** for the 4 ID registries; journal excepted.
- `.claude/memory/` missing → STOP at STEP 0, do not create the structure here.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Proposing items already in the registries | STEP 2 dedup is mandatory. Grep keywords + read entries + journal `capitalized` lines first. |
| Re-running after a ritual and re-logging the same items | Expected output after a ritual is `(rien de neuf)`. If it proposes the just-closed items, dedup failed. |
| Treating a reworded insight as new | Dedup is semantic, not lexical. Read the entry's meaning, not just its keywords. |
| Renumbering or reusing an ID | IDs are stable + sequential. Max existing +1. |
| Writing prose registry bodies | Registries are caveman-English. Fragments, no articles/filler. (TODO stays prose.) |
| Logging a trivial reversible tweak as a decision | Decision = tradeoff you'd defend, cross-file or >10 min to reverse. Else skip. |
| Fanning one incident across registries (a resolved gotcha as both LRN and BLK) | One incident → one primary registry. Reusable pattern → LRN. Unresolved friction / the friction itself → BLK. |
| Folding push / tag / release / deploy into the TODO | Anti-noise filter. Those are systematic actions, not tracked work — drop them, even phrased as tasks. |
| Checking an umbrella/partial task because "some of it shipped" | PASS A needs the WHOLE task proven done with a clear git map. Partial → leave unchecked. |
| Inventing a subtask the user never voiced | PASS B captures only explicit to-dos. No decomposition, no expansion. |
| Dumping an architecture directive as a TODO task | Route orientation/policy directives to decisions.md (BDR), not the TODO. |
| Writing a ritual answer fresh without dedup | Ritual answers go through STEP 2 like any candidate; a dup shows its existing ID. |
| French/English entry text | Prompt may be French; written registry entry is always English. |
| Creating `.claude/memory/` or `.claude/tasks/TODO.md` when absent | Not this skill's job — registries STOP and point to `/onboard`; TODO volet is skipped. |

## Red flags — STOP

- About to append a registry entry without having grepped + read the registry
  for it → dedup skipped.
- About to treat a reworded item as new without checking meaning → semantic
  dedup skipped.
- Proposing 6+ entries from a short conversation → over-capturing noise.
- Rewriting an existing entry "to update it" → append-only violation; add a new
  entry with `supersedes`.
- Same incident headed for two registries (LRN + BLK for one event) → pick one.
- About to add / relabel a TODO item with push / tag / release / deploy → noise.
- About to check a `- [ ]` with no commit/code proving the WHOLE task done → stop.
- About to write a TODO item the user never explicitly asked for → stop.
- Writing the TODO in caveman → TODO is plain prose.

## TDD note (skill itself)

Baseline (RED, 2026-06-19): a no-skill agent on a pressured fixture deduped
correctly (incl. a reworded semantic dup), routed an architecture directive to
BDR, and checked a cleanly-done task — but (a) folded a "push branch + tag
release" parasite into the TODO, (b) invented a subtask the user never voiced,
(c) wrote everything with no approval stop, and (d) fanned one incident across
two registries on an earlier run (non-deterministic). This skill's mandatory
gate (STEP 3), anti-noise filter (STEP 2B), explicit-only capture, and
one-incident-one-registry rule make those deterministic.

GREEN re-run on the same fixture must: stop at the gate, drop both dups (footer
shows existing IDs), log jigsaw as ONE learning, check only the cleanly-done
task, leave the umbrella "harden" task unchecked, add only the explicit README
to-do, ignore the push/tag parasite, and route the GraphQL directive to BDR.
