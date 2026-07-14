# Design — CLAUDE.global.md rename + project-scope CLAUDE.md

- Date: 2026-07-12
- Flow: /ship-feature
- Contract: `.claude/tasks/contracts/2026-07-12-claude-global-md-rename-2342.md`
- Status: approved (design gate 2026-07-12)

## Problem

The repo-root `CLAUDE.md` is the user-scope global memory, symlinked to
`~/.claude/CLAUDE.md` by `link.sh`. Because the filename `CLAUDE.md` is taken
by global content, this repo has no project-level CLAUDE.md — repo-only
instructions (`# This repo only (claude-config)`) ride the global file and
load in every project (~40 tok/session waste), and the `rules/` maintenance
doctrine lives in `rules/README.md`, a user-scope rule whose
`paths: ["rules/**"]` glob over-matches any foreign project with a `rules/`
directory.

## Decision

Rename the global source file and free the `CLAUDE.md` name for a real
project-scope file. Name arbitrated: `CLAUDE.global.md`
(`CLAUDE.prod.md` rejected — "prod" implies a deployment environment that
does not exist here).

This does NOT contradict BDR-021's rejected "split into 2 files" alternative:
that rejection targeted splitting GLOBAL content into two synced files. Here
the scopes are disjoint — zero synchronization between the two files.

## Changes

### 1. File split

- `git mv CLAUDE.md CLAUDE.global.md` (history preserved; verify with
  `git log --follow`).
- `CLAUDE.global.md` drops the `# This repo only (claude-config)` section
  (6 lines) and gains a scope header above the title:

  ```markdown
  <!-- USER-SCOPE GLOBAL — deployed as ~/.claude/CLAUDE.md via link.sh symlink.
       Repo-specific instructions live in ./CLAUDE.md (project scope). -->
  ```

  Net ≈ 301 lines — under the 320 guard (BDR-062). Security, Architecture
  decisions, and the "Design work — full toolchain (tiered by scope)" heading
  stay byte-identical (BDR-021: hook quotes the heading verbatim).

- New project-scope `CLAUDE.md` (~25 lines), minimal structure (YAGNI — no
  empty template sections):
  - mirror scope header: project scope only; global doctrine is in
    `CLAUDE.global.md`, deployed as `~/.claude/CLAUDE.md`; edit THAT file for
    cross-project rules;
  - `## Health Stack` — `shellcheck *.sh hooks/*.sh lib/*.sh` (moved verbatim);
  - `## rules/ maintenance` — doctrine migrated from `rules/README.md`:
    what belongs in `rules/` (one rule = one file = one concern), lazy-load
    semantics (`paths:` frontmatter → loads on matching file read; no
    `paths:` → session-start cost, keep always-on doctrine in
    CLAUDE.global.md), machine-owned files note (context7.md DELETED BY
    DESIGN, BDR-053), link to the docs page.

### 2. link.sh

Mapping line changes: link `<repo>/CLAUDE.global.md` → `~/.claude/CLAUDE.md`.
`ln -sf` in `link_file()` replaces the stale symlink cleanly. Post-condition:
`readlink ~/.claude/CLAUDE.md` = `<repo>/CLAUDE.global.md`.

### 3. Dependent scripts (surgical)

| File | Change |
|---|---|
| `hooks/session-start.sh:205-206` | line-count guard reads `CLAUDE.global.md`; threshold 320 unchanged (BDR-062). Repo detection via `readlink` (line 81) already works post-rename. |
| `doctor.sh:251,277` | size/token stats read `CLAUDE.global.md`. Symlink check (line 65) unchanged — link name `~/.claude/CLAUDE.md` is stable. |
| `install-plugins.sh:33-41,66` | `GUARDED_CONFIGS` KEEPS `"CLAUDE.md"` (graphify's installer targets that name — now the project file, still needs the drift guard) and ADDS `"CLAUDE.global.md"`. Comment + mktemp error message updated. |
| `lib/doc-commit.sh:48` | add `CLAUDE.global.md` to the doc-sync exclusion list (BDR-022 spirit: memory/config files are never doc-commit targets). |

### 4. rules/README.md

Slimmed to a 3-line pointer, frontmatter kept:

```markdown
---
paths: ["rules/**"]
---
User-scope rules, deployed to `~/.claude/rules` by `link.sh`.
Maintenance doctrine (what belongs here, lazy-load semantics, machine-owned
files): see `CLAUDE.md` (project scope) at the claude-config repo root.
```

Over-match in foreign projects with a `rules/` dir becomes harmless (~30 tok).

### 5. Docs

`README.md`, `USAGE.md`, `MIGRATION.md`: update only references meaning the
repo-root GLOBAL file. References to the `~/.claude/CLAUDE.md` symlink name
and to the per-project CLAUDE.md concept are unchanged. `templates/project-CLAUDE.md`
unchanged (its "Global rules: ~/.claude/CLAUDE.md" line stays accurate).

## Verification

1. `shellcheck` on every modified `.sh` (repo Health Stack).
2. `bash link.sh` → `readlink ~/.claude/CLAUDE.md` resolves to
   `CLAUDE.global.md`; no dangling link.
3. `bash doctor.sh` → symlink check green, stats read the new file.
4. Residual grep: no script reference to the repo-root global file under the
   old name (`grep -rn 'CLAUDE\.md' *.sh hooks/*.sh lib/*.sh` reviewed).
5. Session-start guard smoke test: guard finds `CLAUDE.global.md`, no
   fail-open on the old path.
6. `git log --follow CLAUDE.global.md` shows pre-rename history.

## Constraints honored

- **BDR-062**: guard path follows the rename, threshold 320 untouched.
- **BDR-021**: Security/Architecture verbatim; design heading byte-identical.
- **BDR-031**: global file net-shrinks (−6 +2 lines); no re-inflation.
- **LRN-044**: all edits on resolved repo paths, never through
  `~/.claude/CLAUDE.md`.
- **Gitflow**: all commits on a `feature/*` branch off develop; this spec is
  committed as the branch's first commit (never directly on develop).

## Out of scope

- graphify-section extraction from the global file (separate suggestion,
  not requested here).
- Any content rewrite of the global doctrine beyond the section move and
  scope header.
