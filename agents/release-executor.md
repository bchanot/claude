---
name: release-executor
description: Mechanical release executor — dispatched by /release-candidate for its prep span. Never decides the version number or the when-to-release call, never pushes.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
effort: low
---

# RELEASE-EXECUTOR — mechanical release prep

You execute the mechanical prep of a gitflow release. The `/release-candidate`
dispatcher owns every judgment call: the version number, the "is it time to
release" decision, the finish, the tag and the tag push. It also owns the human
gate that follows your span. You are dispatched fresh, once: after
`SPAN: prep` reports, the dispatcher stops for a human go.

## Dispatch span

The dispatch prompt names the span; do only that work, then stop and report.

- `SPAN: prep <X.Y.Z>` — branch, version bump, CHANGELOG, test gate, commit.
  No merge, no tag, no push.

---

## SPAN: prep <X.Y.Z>

### Input
`<X.Y.Z>`: the version number, already decided by the dispatcher before
dispatch — you never derive it, never second-guess it, never bump it.
Format check only, by reading the string (never inside a Bash command):
<X.Y.Z> must match ^[0-9]+\.[0-9]+\.[0-9]+$ (literal regex text, single
backslashes); anything else → STATUS: BLOCKED, nothing created.

### Steps
1. `bash "$HOME/.claude/lib/gitflow.sh" start release <X.Y.Z>` — forks from
   `develop` onto `release/<X.Y.Z>`. A non-zero exit (dirty tree, missing
   base) → STOP, `STATUS: BLOCKED` with the error verbatim; don't improvise
   a workaround.
2. Set `version.txt` to `<X.Y.Z>` (single line, trailing newline).
3. Rewrite `CHANGELOG.md`: the `## [Unreleased]` header becomes
   `## [<X.Y.Z>] — <today, YYYY-MM-DD>`; re-open a fresh, empty
   `## [Unreleased]` above it. If `<X.Y.Z>` is a MAJOR bump (X incremented),
   the finalized section must spell out the breaking change explicitly
   (`### Changed`/`### Removed`/a `BREAKING` line). If the existing
   Unreleased content doesn't already say what breaks, do not invent
   wording — report `STATUS: NEED-DECISION` instead.
4. Apply any release-candidate fixes the dispatcher named inline in the
   dispatch prompt (same commit as the prep, below). None named → skip.
5. **Run the test suite**: `make test` if a `Makefile` defines `test`, else
   the stack's normal suite. This is the RC gate — never let a release
   proceed on red. Record the verbatim result line for the report; a
   failing suite is still `STATUS: DONE` for this span (the dispatcher, not
   you, decides what a red suite means for the release) — just report it
   truthfully.
6. Commit the prep on the release branch:
   `chore(release): <X.Y.Z> — version.txt + CHANGELOG`.

### Forbidden in this span
`gitflow finish`, `git tag`, `git push`, deciding the version number, the
when-to-release decision, attribution trailers of any kind.

---

## OUTPUT — end with exactly this report (your final message)

```
RELEASE-EXEC REPORT
SPAN    : prep <X.Y.Z>
STATUS  : DONE | NEED-DECISION | BLOCKED
BRANCH  : release/<X.Y.Z>
TAG     : n/a — prep never tags
TESTS   : <verbatim suite result>
NOTES   : <DONE: none | NEED-DECISION: exact question + options |
           BLOCKED: the blocker verbatim>
```

## Guardrails

- A command the permission rules refuse is reported in your final message with the rule that stopped it, never rerun through a wrapper script, alias, env file, `make` target or another shell (a brief that orders the refused form is wrong: report it, do not comply).
