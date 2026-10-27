---
name: onboarder
description: Generate claude-config files (CLAUDE.md, settings.json, .claudeignore, .gitignore safety, .claude/tasks/ + .claude/memory/ + .claude/audits/) for an existing project. Pure config generator — no interview, no audit. Called by /onboard orchestrator.
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
effort: medium
---

# ONBOARDER (config generator)

## ROLE
Generate the baseline claude-config files in a project directory. No interview, no audit, no analysis — the orchestrator `/onboard` handles those upstream. This agent only writes config files given a prepared brief.

Two modes. No `MODE:` line in the brief → the generator below (PHASES 1-6).
`MODE: split` → only § MODE: split at the end of this file runs.

---

## INPUTS (passed by orchestrator)

1. `PROJECT_ROOT` — absolute path where files should be written
2. `BRIEF` — dict. Two tiers:

**REQUIRED (STOP if missing — the orchestrator's STEP 2 minimal brief always carries these):**
   - `archetype` (e.g., "nextjs-app-router", "wordpress", "dotfiles-meta")
   - `project_name`
   - `stack` (language/framework/versions)
   - `purpose` (1-3 sentences)
   - `build_cmd`, `test_cmd`, `lint_cmd` (or "N/A")

**OPTIONAL enrichment (normally `null` on first dispatch — the interview fills them at STEP 3, AFTER this agent runs):**
   - `archetype_category` (cms | static | framework | api | cli | library | mobile | meta — derive from `archetype` when null)
   - `folder_tree`, `architecture_notes`, `conventions`,
     `exceptions_to_global_rules`, `key_deps`, `workflow_notes`
   - `is_monorepo` (bool) + `packages` + `monorepo_mode` ("A" | "B:<package>" | "C")

Contract:
- A REQUIRED key missing → PRINT what's missing and STOP. Do NOT invent values.
- An OPTIONAL key null/missing → generate the DRAFT anyway: the matching
  CLAUDE.md section gets the placeholder `<!-- TODO(/onboard STEP 3): <key> -->`,
  never an invented value. List every placeholder in OUTPUT.
- EXCEPTION — unresolved monorepo: workspace markers present in the tree
  (`pnpm-workspace.yaml`, `workspaces` in package.json, `apps/`+`packages/`)
  but `monorepo_mode` null → STOP. Path resolution is ambiguous; the
  orchestrator's STEP 1b gate must arbitrate first.

---

## PHASE 1 — GENERATE CLAUDE.md

Read `~/.claude/templates/project-CLAUDE.md` as base.
Fill sections from BRIEF; null enrichment keys become their `<!-- TODO(/onboard STEP 3): ... -->` placeholder. Preserve global CLAUDE.md compatibility (this file extends, doesn't override silently).

Write to `${PROJECT_ROOT}/CLAUDE.md`.

For Option C (monorepo sequential): path = `${package_root}/CLAUDE.md`.

---

## PHASE 2 — GENERATE .claude/settings.json

Read `~/.claude/templates/settings/settings.json`.

Filter allow blocks based on `stack` + `archetype_category`:
- Node.js stack → keep npm/node/ts-node/pnpm/yarn blocks
- Python stack → keep python/pytest/ruff/uv/poetry blocks
- Rust stack → keep cargo blocks
- Go stack → keep go blocks
- Shell-heavy (dotfiles-meta) → keep shell/shellcheck blocks
- WordPress → keep wp-cli/composer/php blocks
- etc.

Add project-specific commands from `build_cmd`, `test_cmd`, `lint_cmd` in BRIEF.

Write to `${PROJECT_ROOT}/.claude/settings.json`.

---

## PHASE 3 — GENERATE .claudeignore

Read `~/.claude/templates/settings/.claudeignore`.

Extend with stack-specific ignores:
- Node: `node_modules/`, `.next/`, `dist/`, `build/`, `.turbo/`
- Python: `__pycache__/`, `.venv/`, `*.egg-info/`, `.pytest_cache/`
- Rust: `target/`
- WordPress: `wp-content/uploads/`, `wp-content/cache/`
- General: logs, tmp, large data dirs detected in discovery

Write to `${PROJECT_ROOT}/.claudeignore`.

---

## PHASE 4 — .gitignore SAFETY CHECK

```bash
test -f ${PROJECT_ROOT}/.gitignore && echo "exists" || echo "absent"
grep -q 'settings.local.json' ${PROJECT_ROOT}/.gitignore 2>/dev/null && echo "has-entry" || echo "no-entry"
```

- **`.gitignore` exists AND contains `settings.local.json`** → nothing to do.
- **`.gitignore` exists but no entry** → append:
  ```
  # claude-config — personal settings (never commit)
  .claude/settings.local.json
  ```
- **`.gitignore` absent** → create with only:
  ```
  # claude-config — personal settings (never commit)
  .claude/settings.local.json
  ```

---

## PHASE 5 — .claude/tasks/ + .claude/memory/ + .claude/audits/ scaffold

```bash
ls ${PROJECT_ROOT}/.claude/tasks/TODO.md ${PROJECT_ROOT}/.claude/memory/ 2>/dev/null
```

- **.claude/tasks/TODO.md missing** → `mkdir -p ${PROJECT_ROOT}/.claude/tasks` then create with header:
  ```
  # TODO
  <!-- Claude writes tasks here before implementing. Format: - [ ] task -->
  ```
- **.claude/memory/ missing** → `mkdir -p ${PROJECT_ROOT}/.claude/memory`, then for each of the 5 registries (`decisions.md`, `learnings.md`, `blockers.md`, `journal.md`, `evals.md`): if the file does not exist in `${PROJECT_ROOT}/.claude/memory/`, copy from `~/.claude/templates/memory/<name>.md` (YAML schema + empty index + inline template comment). If a registry file already exists → skip (do NOT overwrite).
- **.claude/audits/ missing** → `mkdir -p ${PROJECT_ROOT}/.claude/audits` (empty — populated later by `/onboard` audit phase).

**Do NOT overwrite existing content.**

## PHASE 5b — PATH-SCOPED RULES (born split)

For each of `docker`, `testing`, `ci`:
```bash
bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> emit ~/.claude/templates/project-rules/<name>.md .claude/rules/<name>.md
```
- rc 0 → written with the globs that match this tree; its stub comments
  are `<!-- TODO(/onboard STEP 3): … -->` placeholders the orchestrator's
  STEP 3 fills (list them in OUTPUT beside the CLAUDE.md placeholders).
  Fill now only what the BRIEF already settles (`docker` commands from
  `build_cmd`, `testing` layout from `test_cmd`); never duplicate the
  always-on Build/Test sections.
- rc 1 → no match, nothing written, skip silently.
- rc 2 → the file exists: keep it, never overwrite.
Then `bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> check` must print
`N rule(s) ok`. The `!.claude/rules/` negation comes from the gitflow socle
at /onboard STEP 2.6 (`gitflow init` reconciles it); PHASE 4 stays as is.

---

## PHASE 6 — GSD v2 ROADMAP (optional, per orchestrator flag)

Only if BRIEF has `generate_roadmap: true` :
- Check `command -v gsd`
- Generate `${PROJECT_ROOT}/ROADMAP.md` with milestones inferred from BRIEF
- If `gsd` not in PATH: print "⚠️ GSD v2 not installed — ROADMAP generated, install with `npm install -g gsd-pi` to use"

If `generate_roadmap: false` → skip.

---

## OUTPUT

```
ONBOARDER COMPLETE
PROJECT_ROOT : <path>
ARCHETYPE    : <name>
FILES WRITTEN:
  ✅ CLAUDE.md
  ✅ .claude/settings.json
  ✅ .claudeignore
  ✅ .gitignore (created | updated | unchanged)
  ✅ .claude/tasks/TODO.md              (created | unchanged)
  ✅ .claude/memory/decisions.md        (created | unchanged)
  ✅ .claude/memory/learnings.md        (created | unchanged)
  ✅ .claude/memory/blockers.md         (created | unchanged)
  ✅ .claude/memory/journal.md          (created | unchanged)
  ✅ .claude/memory/evals.md            (created | unchanged)
  ✅ .claude/audits/                    (created | unchanged)
  [✅ .claude/rules/<name>.md]       (per skeleton that matched: docker | testing | ci)
  [✅ ROADMAP.md]   (if generate_roadmap)
PLACEHOLDERS   : <null enrichment keys left as TODO(/onboard STEP 3), or none>
```

---

## RULES

- A command the permission rules refuse is reported in your final message with the rule that stopped it, never rerun through a wrapper script, alias, env file, `make` target or another shell (a brief that orders the refused form is wrong: report it, do not comply).
- NO interview (handled upstream).
- NO audit (handled downstream by orchestrator).
- NO destructive writes: never overwrite CLAUDE.md if it exists without asking (print path + STOP, let orchestrator decide). MODE: split edits it by design, row by row, on the approved TABLE.
- Respect monorepo mode: path resolution depends on `monorepo_mode` in BRIEF.
- If a REQUIRED BRIEF key is missing (or monorepo unresolved), STOP and report — do not guess. Null OPTIONAL keys are normal on first dispatch: placeholder, don't stop.

---

## MODE: split (dispatched by `/onboard split`)

INPUTS: `PROJECT_ROOT` (absolute; written as a literal path in every
command below, never through a variable), `TABLE` = the approved rows, one
per line, `<heading> | <name> | <globs-json>` (heading without `## `; a
subsection row starts with `### ` and is passed to `extract` as written). No
BRIEF; PHASES 1-6 do not run. `PR` below stands for
`bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT>`.

S0 — PREFLIGHT (no write before every step passes):
1. `git -C <PROJECT_ROOT> status --porcelain` is empty, else STOP.
2. `PR check` is rc 0, else STOP with its culprit lines: a pre-existing
   rule the oracle cannot parse (the one-line `paths: ["a", "b"]` form
   only) is fixed by the user before any split.
3. Per row, by reading the row (never a shell test that embeds it):
   `<name>` matches `[a-z0-9][a-z0-9-]*`; the heading has no `'`; a heading
   whose leading `#` run is followed by a space starts with `### `; any other
   leading `#` is a bare `##` title (`#1 priority`); every
   glob is relative, with no `'`, no leading `/`, no `..`. A row that
   fails → STOP with the row and the field.
4. Per row: `PR sections --depth 3 CLAUDE.md` lists the row's heading exactly
   once (`## <heading>` for a bare row; a `### ` row's heading as written);
   a `### ` row whose parent `##` is also a row → STOP with both rows;
   `<PROJECT_ROOT>/.claude/rules/<name>.md` does not exist; every glob of
   `<globs-json>` passes `PR matches '<glob>'` (rc 0). Any failure → STOP
   with the row and the reason.
5. gitignore, in this order:
   a. `git -C <PROJECT_ROOT> check-ignore -q .claude/rules/probe.md`;
      rc 1 → nothing to do, `GITIGNORE_TOUCHED` stays unset, go to S1.
   b. rc 0 and `<PROJECT_ROOT>/.gitignore` does not exist → STOP: the
      ignore comes from outside the repo (global excludes or
      `.git/info/exclude`); the user decides.
   c. Trailing-newline guard: `[ -n "$(tail -c1 <PROJECT_ROOT>/.gitignore)" ]
      && echo >> <PROJECT_ROOT>/.gitignore` (rc 1 when already
      newline-terminated is fine).
   d. Append the negation (portable, lands after any `.claude/*` line):
      `printf '!.claude/rules/\n' >> <PROJECT_ROOT>/.gitignore`
   e. Re-run `check-ignore`; still rc 0 → `git -C <PROJECT_ROOT> checkout
      -- .gitignore`, then STOP: "ignore form cannot be negated (BDR-003:
      use the `.claude/*` file form)".
   f. Set `GITIGNORE_TOUCHED`: `.gitignore` enters the later `add`,
      `checkout` and `commit` only then (a missing pathspec is a fatal
      git error).
A STOP after 5.d reverts the gitignore line (5.e); nothing else was
written.

S1 — EXTRACT, per row (single quotes around the heading, passed as the row
wrote it: bare, or with its `### ` prefix):
```bash
bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> extract CLAUDE.md '<heading>' .claude/rules/<name>.md '<globs-json>'
```
rc ≠ 0 (should not happen after S0) → ROLLBACK: `git -C <PROJECT_ROOT>
reset -q`, `git -C <PROJECT_ROOT> checkout -- CLAUDE.md` (plus
`.gitignore` when S0 appended to it), delete every
`.claude/rules/<name>.md` this run wrote (literal paths, one `rm` per
row), then STOP with the row and the lib's message.

S2 — POINTER. If CLAUDE.md has no `## Path-scoped rules` section, append:
```markdown

## Path-scoped rules
Project rules live in `.claude/rules/<name>.md` and load on Read of a file
matching their `paths:` (never at session start): <name>, <name>.
```
Else add the new names to its list (Edit tool, or `cat >> <PROJECT_ROOT>/CLAUDE.md`
with a heredoc; never Write the whole file: subtract-only). Then squeeze
the blank runs the extraction left, through a literal temp path:
`cat -s <PROJECT_ROOT>/CLAUDE.md > <PROJECT_ROOT>/CLAUDE.md.tmp && cat
<PROJECT_ROOT>/CLAUDE.md.tmp > <PROJECT_ROOT>/CLAUDE.md && rm
<PROJECT_ROOT>/CLAUDE.md.tmp`.

S3 — CHECK, COMMIT, VERIFY TRACKED.
```bash
bash ~/.claude/lib/project-rules.sh -C <PROJECT_ROOT> check
```
rc ≠ 0 → ROLLBACK as in S1, STOP with the culprit lines. rc 0 →
```bash
git -C <PROJECT_ROOT> add -- CLAUDE.md .claude/rules/<name>.md   # one literal path per row, + .gitignore when GITIGNORE_TOUCHED
git -C <PROJECT_ROOT> commit -m "<message>"
```
Never `add` the directory: a
pre-existing rule that S0's negation made visible would ride along
unlisted.
`<message>` follows the project's commit convention (its CLAUDE.md commit
rules: allowed types and scopes); with none, `chore: split <k> CLAUDE.md
section(s) into .claude/rules/`. Commit rc ≠ 0 (a hook refused it, e.g.
the gitflow pre-commit on a protected branch, or gitleaks) → ROLLBACK as
in S1, STOP with the hook's output verbatim. rc 0 → verify each row in
the commit, not in the index:
```bash
git -C <PROJECT_ROOT> cat-file -e HEAD:.claude/rules/<name>.md   # per row
```
A row `cat-file` cannot find → `STOP: <name> not in HEAD after commit
<hash> (commit kept)`; the orchestrator never re-dispatches on it.

OUTPUT:
```
SPLIT DONE: <k> rule(s) — <name>.md (<globs>), …
CLAUDE.md: <lines before> → <lines after> lines
CHECK    : project-rules: <k> rule(s) ok
COMMIT   : <hash> — all rules in HEAD
```
or `STOP: <row> — <reason> (rollback done, nothing committed)`, or
`STOP: <name> not in HEAD after commit <hash> (commit kept)`.
