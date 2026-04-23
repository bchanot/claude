---
type: decisions_registry
entry_prefix: BDR
schema:
  id: BDR-XXX
  date: YYYY-MM-DD
  title: string (<= 80 chars)
  decision: string (what was chosen)
  why: string (motivation, context)
  alternatives: list of strings (what was rejected + why)
  status: [proposed | accepted | deprecated | superseded]
  supersedes: BDR-XXX (optional)
rules:
  - Append-only. Never rewrite past entries - add a new one with status superseded if needed.
  - One entry per non-trivial choice. Trivial = reversible in under 10 min with no cross-file impact.
  - Capture why more carefully than what - the what rots, the why lasts.
---

# Decisions registry (BDR)

## Index

| ID | Date | Title | Status |
|----|------|-------|--------|
| BDR-001 | 2026-04-22 | Uniform --help helper via session-start hook (option C) | accepted |
| BDR-002 | 2026-04-23 | Move tasks/ + introduce memory + audits under .claude/ | accepted |
| BDR-003 | 2026-04-23 | Gitignore wildcard + negations pattern for .claude/ | accepted |

---

## BDR-001 — Uniform --help helper via session-start hook (option C)

- **Date**: 2026-04-22
- **Status**: accepted
- **Decision**: every skill exposes `--help` via a shared snippet injected by the session-start hook, rather than duplicating the helper in each SKILL.md.
- **Why**: 25+ skills — keeping the same helper synced across every file guarantees drift. A single injection point = single source of truth.
- **Alternatives rejected**:
  - Option A (copy the helper into each SKILL.md) — rejected: maintenance entropy.
  - Option B (external wrapper `/help <skill>`) — rejected: breaks the "one command = one skill" experience.
- **Reference**: commit 3968a29.

## BDR-002 — Move tasks/ + introduce memory + audits under .claude/

- **Date**: 2026-04-23
- **Status**: accepted
- **Decision**: migrate `./tasks/` to `.claude/tasks/`, create `.claude/memory/` (5 registries BDR/LRN/BLK/journal/EVAL) and `.claude/audits/` for AUDIT_* files. Adapt skills/agents/CLAUDE.md. Integrate a CAPITALIZE step into completion skills (ship-feature, feat, bugfix, hotfix, commit-change) and add a `/close` skill for the session-end ritual.
- **Why**: grouping all meta-project state (AI config + tasks + memory + audits) under `.claude/` isolates Claude governance from real code. Aligned with the official Claude Code memory docs. Without integration in completion skills, the registries would stay empty (aspirational text).
- **Alternatives rejected**:
  - Keep `./tasks/` at root — rejected: clutters the repo, mixes code signal with governance signal.
  - Use `.claude/agent-memory/` for everything — rejected: `agent-memory/` has a distinct role (already used by other tools).
  - Ritual as aspirational text only in CLAUDE.md — rejected: zero execution guarantee, registries would stay empty.
  - `Stop` hook to ask the 3 questions every turn — rejected: too noisy.

## BDR-003 — Gitignore wildcard + negations pattern for `.claude/`

- **Date**: 2026-04-23
- **Status**: accepted
- **Decision**: use `.claude/*` (wildcard match of immediate children) + negations `!.claude/tasks/`, `!.claude/memory/`, etc., rather than `.claude/` (recursive ignore).
- **Why**: when a parent is ignored via `.claude/`, git does not descend into it (performance optimization) and negations on children are **ignored** — documented in `gitignore(5)`. With `.claude/*`, git matches each child individually, making negations active.
- **Alternatives rejected**:
  - `.claude/` + `!.claude/tasks/` (naive) — rejected: negations have no effect, everything stays ignored.
  - Drop `.claude/` from gitignore entirely — rejected: `.claude/settings.local.json` and `.claude/agent-memory/` must stay ignored (per-machine).
  - Track paths via `.gitattributes` or an external tool — rejected: over-engineering, git handles this natively.
- **Reference**: commit `499cd07`, `git check-ignore -v` verified on 4 paths (2 tracked, 2 ignored).
