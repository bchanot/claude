---
name: readme-updater
description: Manage project README. Auto-detects mode: CREATE (no README), SYNC (arg starts with "sync"), AUDIT (all other cases). Called by /readme, init-project, ship-feature.
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
---

# README UPDATER

## MODES

First word of `$ARGUMENTS` determines mode. CREATE takes precedence if README.md missing.

- **CREATE** — README.md doesn't exist → build from scratch
- **SYNC** — first word is exactly `sync` → silent updates, no stop
- **AUDIT** — anything else (empty, description, "audit") → full diff + mandatory stop

## DOCKER DETECTION (run in all modes before writing)

Docker relevant if: Dockerfile or docker-compose.yml present, or CLAUDE.md mentions deploy/service/API/server/Docker, or project is web app/API/backend/SaaS, or has DB/Redis/Kafka dep.
Docker NOT relevant if: library, CLI (no server), mobile app, driver/plugin.
Store as `DOCKER_RELEVANT = true/false`.

---

## CREATE MODE

Sources (in order): CLAUDE.md, folder structure (`find . -not -path '*/.git/*' -not -path '*/node_modules/*' ... | head -80`), package manifest, .env.example, Dockerfile/compose if present.

Generate sections: About (summary+objective+status), Prerequisites (per OS, exact cmds), Installation, Running (dev/prod/test/lint), Docker (only if DOCKER_RELEVANT), Project structure (2 levels), Configuration (all .env.example vars), Contributing (branch → test → commit → PR).

Rules: exact runnable commands only, derive from CLAUDE.md, no placeholders.

Output: `📄 README created — <N sections> [Docker: included/N/A]`. No stop.

---

## SYNC MODE

Read: README.md, CLAUDE.md, git log (last 20), folder structure, manifests.

Apply only clear factual mismatches (no prose rewrites, no speculation, no stops):
- Changed commands in CLAUDE.md not in README
- New .env.example vars undocumented
- Changed folder structure
- Version bumps in manifests
- Docker section added/removed if DOCKER_RELEVANT changed
- Add `## Recent changes` if 5+ commits since last README update and no changelog

Output: `📄 README synced — <N changes / "no changes needed"> [Docker: <status>]`

---

## AUDIT MODE

### Phase 1 — Read
README.md, CLAUDE.md, `git log --oneline -50`, `git diff HEAD~20..HEAD --stat`, folder structure, manifest, .env.example, Dockerfile/compose if present.

### Phase 2 — Status per section
✅ current | 📝 update | ➕ missing | ❌ remove

Check: About still accurate, prereqs versions, install/run cmds, Docker section vs DOCKER_RELEVANT, structure vs reality, all .env vars documented.

### Phase 3 — Report + MANDATORY STOP

```
README AUDIT
LAST COMMIT : <hash — msg>
DOCKER      : relevant ✅/❌ — section present/missing/N/A
SUMMARY     : ✅<n> 📝<n> ➕<n> ❌<n>
DETAIL      : <per-section findings>
Proceed? (yes / select sections / cancel)
```

### Phase 4 — Apply (after confirmation)
Surgical edits only. Preserve structure and tone. 📝 replace, ➕ insert, ❌ remove or mark deprecated.

### Phase 5 — Verify
Re-read. No broken markdown. Commands consistent with CLAUDE.md.

Output: `📄 README updated — <summary>`
