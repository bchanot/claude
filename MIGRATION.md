# Migration guide — `.claude/` restructure (2026-04-23)

The claude-config layout moved task tracking, memory registries, and audit
reports out of scattered roots (`tasks/`, `SEO.md`, `HARDEN.md`, etc.) into
a single governance root: `.claude/{tasks,memory,audits}/`.

This guide walks through the migration for **existing projects** that use
claude-config skills and were onboarded before this change.

---

## TL;DR — full migration in one block

Run from the project root. Inspect the output before committing.

```bash
# 1. Create the new directory layout
mkdir -p .claude/tasks .claude/memory .claude/audits

# 2. Move task files
[ -d tasks ] && {
  for f in tasks/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      LESSONS.md)
        # Deprecated - content goes into learnings.md (see step 3)
        mv "$f" .claude/tasks/LESSONS.legacy.md
        ;;
      AUDIT_GOOD.md|AUDIT_ISSUES.md|AUDIT_PROPOSALS.md|ONBOARD_REPORT.md)
        mv "$f" ".claude/audits/$(basename "$f")"
        ;;
      *)
        mv "$f" ".claude/tasks/$(basename "$f")"
        ;;
    esac
  done
  # Remove the empty tasks/ dir if nothing's left
  rmdir tasks 2>/dev/null
}

# 3. Move orphan audit reports from project root
for f in SEO.md GEO.md HARDEN.md VALIDATE.md BUGS-FOUND.md; do
  [ -f "$f" ] && mv "$f" ".claude/audits/$f"
done

# 4. Seed the 5 memory registries from the shipped templates
#    (only if they don't exist yet - never overwrite real content)
for reg in decisions learnings blockers journal evals; do
  target=".claude/memory/${reg}.md"
  src="$HOME/.claude/templates/memory/${reg}.md"
  if [ ! -f "$target" ] && [ -f "$src" ]; then
    cp "$src" "$target"
    echo "✅ Created $target"
  elif [ -f "$target" ]; then
    echo "⏭️  Kept existing $target"
  else
    echo "⚠️  Template missing: $src"
  fi
done

# 5. If LESSONS.legacy.md had useful entries, convert them manually into
#    .claude/memory/learnings.md (LRN-XXX format) then delete LESSONS.legacy.md

# 6. Update .gitignore - see "Gitignore patch" section below

# 7. Update CLAUDE.md - see "CLAUDE.md patch" section below

# 8. Verify
git status
git check-ignore -v .claude/memory/decisions.md .claude/tasks/TODO.md 2>&1
```

---

## Gitignore patch

If your project's `.gitignore` contains a bare `.claude/` rule, it will ignore
every memory/tasks/audit file you just created. Replace that line with:

```gitignore
# Local project config (per-machine)
.claude/*
!.claude/tasks/
!.claude/memory/
!.claude/audits/
!.claude/settings.json
# These stay ignored (per-machine state)
.claude/settings.local.json
.claude/agent-memory/
```

Verify after edit:

```bash
# These MUST be trackable (exit 1)
git check-ignore .claude/memory/decisions.md .claude/tasks/TODO.md .claude/audits/

# These MUST still be ignored (exit 0)
git check-ignore .claude/settings.local.json .claude/agent-memory/
```

---

## CLAUDE.md patch

If your project's `CLAUDE.md` references `tasks/LESSONS.md` / `tasks/TODO.md`,
update the `## Session start`, `## Workflow`, `## After code changes`, and
`## Task tracking` sections to use `.claude/tasks/TODO.md` and reference the
5 memory registries.

Fastest route: run `/onboard` on the project (safe, won't overwrite existing
CLAUDE.md — it will merge). Otherwise, apply this diff manually:

```diff
 ## Session start
-1. Read `tasks/LESSONS.md` — apply all lessons before touching anything.
-2. Read `tasks/TODO.md` — understand current state.
-3. If neither exists, create both before starting.
+1. Read `.claude/memory/` — the 5 registries (decisions, learnings, blockers, journal, evals).
+2. Read `.claude/tasks/TODO.md` — understand current state.
+3. If missing, create from `~/.claude/templates/memory/`.
```

Add a new section referencing the registries (full template in
`~/.claude/CLAUDE.md` — copy the `## Memory registries (.claude/memory/)` block).

---

## What gets committed vs ignored

| Path | Committed? | Reason |
|------|-----------|--------|
| `.claude/tasks/*.md` | ✅ yes | Shared project backlog |
| `.claude/memory/*.md` | ✅ yes | Shared decisions/learnings/blockers |
| `.claude/audits/*.md` | ✅ yes | Snapshot of project state — version-able |
| `.claude/settings.json` | ✅ yes | Shared project config |
| `.claude/settings.local.json` | 🚫 no | Per-machine overrides |
| `.claude/agent-memory/` | 🚫 no | Per-session agent state |

---

## Post-migration sanity check

```bash
# 1. No legacy tasks/ dir left
[ -d tasks ] && echo "⚠️ tasks/ still exists" || echo "✅ tasks/ gone"

# 2. No orphan audit files at project root
for f in SEO.md GEO.md HARDEN.md VALIDATE.md BUGS-FOUND.md; do
  [ -f "$f" ] && echo "⚠️ $f still at root"
done

# 3. Structure in place
ls .claude/tasks .claude/memory .claude/audits

# 4. Git sees the new files as trackable
git status -u .claude/ --short
```

All four checks should be clean before committing the migration.

---

## If anything goes wrong

- The migration block only uses `mv`, not `rm` — nothing is deleted.
- Old `LESSONS.md` is preserved as `LESSONS.legacy.md` — review it, copy
  meaningful entries into `.claude/memory/learnings.md` (with `LRN-XXX` IDs),
  then delete.
- To undo: `git checkout .` before commit.
