---
paths: ["rules/**", "CLAUDE.global.md"]
---

# rules/ maintenance

Modular instruction files loaded by Claude Code alongside the global memory.
`rules/` is symlinked to `~/.claude/rules` by `link.sh` (user scope, ALL
projects). One rule = one file = one concern.

A rule WITH `paths:` YAML frontmatter (glob list) loads lazily — only when
Claude Reads a file matching a glob (never on the Write of a new file;
sub-agents too); a rule WITHOUT it loads at session start, same cost as the
global memory. Doctrine leaves CLAUDE.global.md only for a carrier that fires
when it is needed (BDR-125 phase 1: a path rule, a hook, a lib our skills
Read), with one always-on line wherever plain chat still needs the rule.
Exception: a standalone user-authored rule set that would bust the 320-line
density budget may live here WITHOUT `paths:` (always-on load) —
writing-style.md (BDR-085), secure-by-default.md (BDR-120);
`lib/tests/user-rules.test.sh` locks that set. `paths:` globs match against
the CURRENT project's tree, gitignore-style (a pattern without an inner `/`
matches at any depth, hidden dirs included) — a broad glob (e.g. `rules/**`)
can fire in foreign projects; keep rule bodies tiny.
Docs: https://code.claude.com/docs/en/memory.md#path-specific-rules

Machine-owned: `rules/context7.md` is DELETED BY DESIGN (BDR-053,
2026-07-06) — `ctx7 setup --claude --cli` still writes it, but
install-plugins.sh STEP ctx7 purges it right after; the find-docs skill is
the single ctx7 surface. If it reappears (manual `ctx7 setup`), delete it
or re-run `make plugin`.
