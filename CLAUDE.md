<!-- PROJECT SCOPE ONLY (claude-config repo). The user-scope GLOBAL memory is
     ./CLAUDE.global.md, deployed as ~/.claude/CLAUDE.md by link.sh — edit
     THAT file for cross-project doctrine. -->

# claude-config — project instructions

## Health Stack
- shell: `shellcheck *.sh hooks/*.sh lib/*.sh`

## rules/ maintenance

Modular instruction files loaded by Claude Code alongside the global memory.
`rules/` is symlinked to `~/.claude/rules` by `link.sh` (user scope, ALL
projects). One rule = one file = one concern.

A rule WITH `paths:` YAML frontmatter (glob list) loads lazily — only when
Claude reads a file matching a glob; a rule WITHOUT it loads at session
start, same cost as the global memory. Extract from CLAUDE.global.md only
what can be path-scoped (the token win) or what is generated; always-on
doctrine stays in CLAUDE.global.md. `paths:` globs match against the
CURRENT project's tree — a broad glob (e.g. `rules/**`) can fire in foreign
projects; keep rule bodies tiny.
Docs: https://code.claude.com/docs/en/memory.md#path-specific-rules

Machine-owned: `rules/context7.md` is DELETED BY DESIGN (BDR-053,
2026-07-06) — `ctx7 setup --claude --cli` still writes it, but
install-plugins.sh STEP ctx7 purges it right after; the find-docs skill is
the single ctx7 surface. If it reappears (manual `ctx7 setup`), delete it
or re-run `make plugin`.

## Transient planning artifacts

`docs/superpowers/specs/**` and `docs/superpowers/plans/**` are run-time
artifacts of a feature pipeline (subagent briefs, reviewer references).
They are committed DURING the run (the SDD worktree + reviewers read them
from disk — NOT gitignored), then AUTO-PURGED by `gitflow finish` on a
`feature`/`bugfix` branch, before the merge, so develop's tip stays clean
(BDR-065, `lib/gitflow.sh` `_gitflow_purge_transient`). The feature commits
stay reachable from develop, so `git show <sha>:docs/…` is still the archive.
Opt out with `GITFLOW_PURGE_TRANSIENT=0`. NOT in scope: `.claude/tasks/{contracts,plans}`
(durable, versioned, referenced by decisions.md). Durable knowledge goes to
`.claude/memory/` registries, never to these files. Derived scan/audit
outputs (`.audit/**`) are gitignored and never committed, even redacted
(LRN-124).
