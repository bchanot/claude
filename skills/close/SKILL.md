---
name: close
description: |
  End-of-session ritual — capitalize the 3 registry questions: what was
  decided, what was learned, what was blocked. Writes approved entries
  into `.claude/memory/decisions.md`, `.claude/memory/learnings.md`, and
  `.claude/memory/blockers.md`, plus a timeline line in `.claude/memory/journal.md`.
  Trigger: "close", "end session", "ferme la session", "session close",
  "checkpoint memory", "what did we learn", "retro rapide", "fin de journée".
argument-hint: (none — operates on the current conversation context)
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

# CLOSE — Session-Close Ritual

Capture the 3 registry-worthy outputs from the current session before losing context. Operates entirely on conversation memory + git state — does NOT re-read code.

## STEP 0 — PRECHECK

Verify the registry files exist:

```bash
ls .claude/memory/decisions.md .claude/memory/learnings.md .claude/memory/blockers.md .claude/memory/journal.md 2>/dev/null
```

- If `.claude/memory/` is missing entirely → print:
  ```
  ⚠️  .claude/memory/ absent. Lance d'abord `/onboard` (ou `/init-project` pour un nouveau repo)
     pour créer la structure des registres.
  ```
  STOP.
- If some files are missing → print which, create them from `~/.claude/templates/memory/<name>.md`, continue.

## STEP 1 — GATHER SESSION CONTEXT

Collect the raw material without re-reading code:

```bash
git log --oneline -10
git diff HEAD --stat
git status --short
date +%Y-%m-%d
```

Extract from current conversation:
- Any decision made (framework pick, refactor scope, architecture choice, naming convention).
- Any learning surfaced (surprising API behaviour, reusable pattern, gotcha, "don't do X").
- Any blocker encountered (dead end, friction > 15 min wasted, upstream bug).

## STEP 2 — THE 3 QUESTIONS

Present the ritual compactly — one screen, 3 questions, pre-filled draft answers from STEP 1:

```
═══ SESSION-CLOSE RITUAL — 3 QUESTIONS ═══

1️⃣  Qu'est-ce que tu as décidé ?
    Proposition BDR-XXX :
      Titre   : <extrait de la conversation>
      Décision: <1 phrase>
      Pourquoi: <1-2 phrases>
      Alts rejetées: <si captable>
    → (accept / edit / skip / add another)

2️⃣  Qu'est-ce que tu as appris ?
    Proposition LRN-XXX :
      Pattern : <extrait abstrait>
      Contexte: <où/quand>
      Future  : <quand s'en rappeler>
    → (accept / edit / skip / add another)

3️⃣  Sur quoi es-tu bloqué ?
    Proposition BLK-XXX :
      Friction   : <extrait>
      Cause      : <si identifiée — sinon "à investiguer">
      Solution   : <workaround si déjà trouvé — sinon "open">
      Statut     : open | resolved | upstream
    → (accept / edit / skip / add another)

Action globale ? (all / pick <numbers> / edit / skip-all)
```

If nothing notable to propose for a given question → say `(rien à logger cette session)` for that question.

## STEP 3 — WRITE APPROVED ENTRIES

For each approved entry:

1. Read the target registry file.
2. Append the new entry at the end (never rewrite existing entries).
3. Add a line to the Index table at the top with the new ID, date, short title, status.
4. Generate next sequential ID by scanning existing IDs (e.g., if `BDR-007` exists, next is `BDR-008`).

## STEP 4 — JOURNAL ENTRY

Always write one line in `.claude/memory/journal.md` under today's heading — even if all 3 questions were skipped:

- If today's heading exists → append a new bullet under it.
- If not → create `## YYYY-MM-DD` heading and write 3-5 bullets summarising the session.

Template:
```markdown
## YYYY-MM-DD

- <what was done — 1 line from conversation>
- <what was decided — link to BDR-XXX if logged>
- <what was learned — link to LRN-XXX if logged>
- <what's blocked — link to BLK-XXX if logged>
- <commit hashes if any — `<hash1>..<hashN>`>
```

## STEP 5 — FINAL OUTPUT

```
CLOSE COMPLETE — session <YYYY-MM-DD>
  decisions.md  : +<N> entries (BDR-XXX, BDR-YYY)  |  0 entries
  learnings.md  : +<N> entries (LRN-XXX)           |  0 entries
  blockers.md   : +<N> entries (BLK-XXX)           |  0 entries
  journal.md    : +1 line under ## <date>
Prochaine session : lire `.claude/memory/` au démarrage pour rappel.
```

---

## RULES

- Never invent content. Every entry must be grounded in the current conversation or git history — no fabricated "lessons".
- Skip silently rather than log a trivial entry. Journal excepted (timeline logging is cheap, noise is fine).
- Never overwrite existing entries — append-only.
- If the user says `skip-all` → still write the journal line and exit.
- If `.claude/memory/` is missing → STOP at STEP 0, do not create it here (onboard / init-project responsibility).
- **Language rule**: written entries are ALWAYS in English (see CLAUDE.md "Memory registries" § Language). The 3-question prompt may mirror the user's language; the appended entries must not.
