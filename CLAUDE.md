<!-- PROJECT SCOPE ONLY (claude-config repo). The user-scope GLOBAL memory is
     ./CLAUDE.global.md, deployed as ~/.claude/CLAUDE.md by link.sh — edit
     THAT file for cross-project doctrine. -->

# claude-config — project instructions

## Health Stack
- shell: `shellcheck *.sh hooks/*.sh lib/*.sh`

## Path-scoped rules
Project rules live in `.claude/rules/<name>.md` and load on Read of a file
matching their `paths:` (never at session start): rules-maintenance,
graphify-vendored, mods, transient-artifacts. Check: `bash
lib/project-rules.sh check` (runs in `make test`).
