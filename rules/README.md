---
paths: ["rules/**"]
---

# rules/

Modular instruction files loaded by Claude Code alongside `CLAUDE.md`.
Symlinked to `~/.claude/rules` by `link.sh`, same model as `agents/`,
`skills/`, `lib/`.

## What belongs here

One rule = one file = one concern. Candidates: instructions that are
self-contained enough to live outside `CLAUDE.md`'s main flow, or that
tooling generates/owns.

Rules support an optional `paths:` YAML frontmatter (glob list). A rule
WITH `paths` loads lazily — only when Claude reads a file matching a
glob; a rule WITHOUT it loads at session start, same cost as CLAUDE.md.
So: extract from CLAUDE.md only what can be path-scoped (the token win)
or what is generated; always-on doctrine stays in CLAUDE.md.
Docs: https://code.claude.com/docs/en/memory.md#path-specific-rules

## Machine-owned files (gitignored, regenerated)

- `context7.md` — DELETED BY DESIGN (BDR-053, 2026-07-06): `ctx7 setup
  --claude --cli` still writes it, but install-plugins.sh STEP ctx7
  purges it right after — the find-docs skill is the single ctx7
  surface; the rule was a ~490 tok/session session-start duplicate
  (job1 F10). If it reappears (manual `ctx7 setup`), delete it or
  re-run `make plugin`.

Hand-written rules ARE tracked — add them normally.
