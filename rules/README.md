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

- `context7.md` — written by `ctx7 setup --claude --cli`
  (install-plugins.sh STEP ctx7). Not vendored: ctx7 owns its content
  and rewrites it on setup; the repo would fight the generator. Same
  treatment as `skills/find-docs/`.

Hand-written rules ARE tracked — add them normally.
