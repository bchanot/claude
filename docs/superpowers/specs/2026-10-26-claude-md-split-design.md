# Phase 0 — split project CLAUDE.md into `.claude/rules/` (design)

Date: 2026-10-26 · flow: /ship-feature · branch: feature/claude-md-split
Contract: `.claude/tasks/contracts/2026-10-26-claude-md-split-0042.md`
Parent: BDR-125 (context mod queue), TODO.md "Phase 0, no mod".

## Intent

The project CLAUDE.md of this repo (5,285 chars) loads in every session of
this repo; four of its five sections only matter when a matching file is
being read. Move those four into project-scope path rules
(`.claude/rules/<name>.md` with `paths:` frontmatter), prove they load, and
give the other projects the same lever through a `/onboard split` mode and
generators that emit path rules from day one. No mod, subtract-only.

Decided with the user (2026-10-26): this run covers this repo, the mode and
the generators; the per-repo pass over the six other repos runs after the
merge through the shipped `/onboard split`, one `chore/claude-md-split`
branch per repo, user approval per repo, never an automatic merge. The
InstructionsLoaded proof hook is permanent. The transient-artifacts rule
carries a `# static-check: skip` marker. The gitignore socle gains
`!.claude/rules/`. Generator skeleton set: docker, testing, ci.

## 1. This repo's rules

| Rule file | `paths:` | Source section (CLAUDE.md, verbatim) |
|---|---|---|
| `.claude/rules/rules-maintenance.md` | `rules/**`, `CLAUDE.global.md` | `## rules/ maintenance` |
| `.claude/rules/graphify-vendored.md` | `skills/graphify/**`, `install-plugins.sh`, `.graphify_version` | `## Machine-owned: the vendored graphify skill` |
| `.claude/rules/mods.md` | `mods/**`, `skills/model-router/**`, `lib/tests/mods.test.sh` | `## mods/ — function-hooks plugins (Claude Code mods)` |
| `.claude/rules/transient-artifacts.md` | `docs/superpowers/**`, `.audit/**` (+ `# static-check: skip`) | `## Transient planning artifacts` |

Frontmatter shape = `rules/a11y.md`: `paths: ["glob", ...]` on one line.
The skip marker is a YAML comment line inside the frontmatter, invisible to
the engine. Body text moves verbatim; the title line becomes `# <section
title>`. CLAUDE.md keeps its header, `## Health Stack`, and a two-line
pointer: path-scoped rules live in `.claude/rules/` and load on Read of a
matching file; the four names listed.

`.gitignore`: `!.claude/rules/` right after `.claude/*` (line 122).
`templates/gitignore/standard.gitignore`: same line after `.claude/*`
(order matters: a negation must follow the ignore it carves; reconcile
appends missing lines at the end, which is after any existing `.claude/*`).
`lib/gitflow-test.sh`: one `chk "socle: !.claude/rules/"` beside the
`!.claude/deploy/` assertion.

## 2. Static check and proof hook

`lib/project-rules.sh` (our code, strict limits, shellcheck):
- `check [dir]` (default `.claude/rules`): for each `*.md`: frontmatter
  delimited by `---` present; a `paths:` line whose value is a JSON-style
  array of double-quoted globs; each glob matches ≥1 path in the working
  tree (`shopt -s globstar dotglob nullglob`, so the symlinked
  `skills/model-router/**` and the gitignored `skills/graphify/SKILL.md`
  count, and a typo matches nothing). A frontmatter line
  `# static-check: skip` exempts that file's globs (printed as SKIP). Exit 0
  and `project-rules: N rule(s) ok` on success; exit 2 and one
  `<file>: <reason>` line per failure. An empty or absent dir is exit 0
  with `0 rule(s)` (a project without rules is not an error).
- `sections <CLAUDE.md>`: prints `<chars>\t<line>\t## <heading>` per
  top-level section, for the split-mode classification table.
- `extract <CLAUDE.md> "<heading>" <out.md> <globs-json>`: writes
  `<out.md>` with the frontmatter and the section body (title demoted to
  `#`), removes the section from CLAUDE.md. Deterministic, idempotent
  failure (heading absent → exit 2, nothing written). Used by the onboarder
  in MODE: split and by the per-repo pass.

`lib/tests/project-rules.test.sh` (picked up by `make test` via the
`lib/tests/*.test.sh` glob): fixtures in `mktemp -d`: a good rule passes;
an unmatched glob fails with the culprit; a missing frontmatter fails; the
skip marker passes an unmatched glob; `sections` lists sizes; `extract`
round-trips (rule written, section gone, second call exit 2); then the real
check on this repo's `.claude/rules` (exit 0). PASS/FAIL tally like
`doctrine-citers.test.sh`.

`hooks/instructions-loaded.sh`: reads the hook JSON on stdin, appends one
`jq -c` line `{ts, cwd, file_path, memory_type, load_reason,
trigger_file_path}` to `~/.claude/logs/instructions-loaded.jsonl`
(`mkdir -p`), always exits 0, never prints to stdout (a stdout line would
reach the model). Registered in `settings.json` under `"InstructionsLoaded"`
beside the other classic hooks. No hooks suite exists: the hook test lives
in `lib/tests/project-rules.test.sh` (fixture JSON on stdin, `HOME` pointed
at a temp dir, the appended line asserted, stdout asserted empty).

Proof for this repo (recorded in the journal): `claude -p "/context"` on
develop BEFORE any edit (baseline, same measure as 2026-10-23), the same on
the branch after the split, one fresh interactive session that Reads one
matching file per rule, then `grep path_glob_match
~/.claude/logs/instructions-loaded.jsonl | tail -4` pasted.

## 3. `/onboard split`

`skills/onboard/SKILL.md`: right after the MODEL GATE, a MODE DISPATCH
paragraph: `$ARGUMENTS` starting with the token `split` → § SPLIT MODE;
anything else → the existing flow unchanged. The description gains the
trigger ("split CLAUDE.md", "découpe le CLAUDE.md"), the argument-hint gains
`split`, RULES line "NO skipping STEP 0, 1, 2" gains "(split mode runs its
own steps, § SPLIT MODE)". Routing rows, test locks (`model-routing`,
`effort-routing`, `loops-heavy`, `plan-challenger`, `security-auditor`) and
`routing.json:67` keep their anchors.

§ SPLIT MODE (steps):
1. Precondition: `CLAUDE.md` at the project root, else print "nothing to
   split, run /onboard" and stop. `git status --porcelain` clean on the
   CLAUDE.md path, else stop (an in-flight edit would be lost).
2. Baseline: `claude -p "/context"` at the root; refused → the user runs
   `! claude -p "/context"`; the always-on total is noted.
3. `bash ~/.claude/lib/project-rules.sh sections CLAUDE.md`; classify each
   `##` section: always-on (overview, stack, build/test/lint commands,
   conventions, workflow expectations, exceptions) or path-scoped (one
   module, one folder, Docker, migrations, CI, a tool's gotchas); propose a
   file name and globs from `git ls-files` for each path-scoped one, and
   verify every proposed glob matches ≥1 tracked path before showing it.
4. Gate (prose table, per project): section · chars · keep / move →
   `<name>.md` · globs. The user edits or approves; "keep everything" is a
   valid answer that ends the mode.
5. `bash ~/.claude/lib/gitflow.sh start chore claude-md-split` (a project
   without gitflow: a plain branch, said so).
6. Dispatch `Agent(subagent_type="onboarder")` with `MODE: split`, the
   project root, and the approved table verbatim (LRN-126: every field
   crosses the prompt). It runs `extract` per row, writes the pointer lines
   into CLAUDE.md, adds `!.claude/rules/` after `.claude/*` when that line
   is present and the negation absent, runs `check`, commits
   `chore(claude-md): split N sections into .claude/rules/`, reports.
7. After: `claude -p "/context"` again, the delta and the rule list go to
   that project's `.claude/memory/journal.md`; the InstructionsLoaded proof
   is the user's next session there (one Read per rule, grep the log).
   Never `finish`: merge on the user's signal.

Skill edit through /writing-skills: RED first (a sonnet subagent given the
CURRENT skill and a scratch repo holding a copy of this repo's pre-split
CLAUDE.md, asked to "/onboard split": it has no mode and runs or asks for
the full onboard), then the edit, then GREEN on the same scratch (the
subagent produces the classification table and stops at the gate).

`agents/onboarder.md`: a `MODE:` header: absent → today's PHASES 1-5
(generate config); `MODE: split` → the split executor above (PHASES
S1-S4: extract rows, pointer lines, gitignore negation, check + commit).
Stays sonnet, effort medium (BDR-077).

## 4. Generators born split

`templates/project-rules/` skeletons, each with `paths:` and 3-6 lines of
section stubs (HTML comments like the CLAUDE.md template):
- `docker.md`: `["Dockerfile*", "docker-compose*", "compose*.y*ml", ".dockerignore"]`
- `testing.md`: `["tests/**", "test/**", "**/*.test.*", "**/*.spec.*", "**/conftest.py"]`
- `ci.md`: `[".github/workflows/**", ".gitlab-ci.yml", ".circleci/**"]`

onboarder (default mode) PHASE 1b and scaffolder PHASE 1b: for each
skeleton, emit `.claude/rules/<name>.md` when ≥1 of its globs matches a
path in the project tree (onboarder: the real tree; scaffolder: the tree it
just scaffolded, so a Docker-relevant project gets `docker.md`), filled from
the BRIEF where known, else the template stubs. Then run `project-rules.sh
check` and report the emitted list. The onboarder's PHASE 4 gitignore check
also appends `!.claude/rules/` after an existing `.claude/*` line
(the socle covers gitflow-init projects; this covers the rest). The
scaffolder's `.gitignore` is reconciled by STEP 5f `gitflow init` before
the root commit, so the socle line lands first (LRN-066, BLK-010).
`templates/project-CLAUDE.md` keeps every section (commands stay always-on);
its header comment gains one line naming `.claude/rules/`.

## 5. Cleanup and citers

- `rules/README.md:9` → "see `.claude/rules/rules-maintenance.md` in the
  claude-config repo".
- `doctor.sh:76` comment: "the project CLAUDE.md" (drop "29-line").
- `ARCHITECTURE.md` tree gains `.claude/rules/` (doc pipeline, STEP 8).
- `install-plugins.sh` GUARDED_CONFIGS unchanged: `graphify claude install`
  still rewrites CLAUDE.md and the trap still reverts it.
- `.claude/tasks/TODO.md`: phase 0 item updated (done parts, per-repo pass
  queued as its own item with the repo order).
- Registries append-only: BDR-065 and LRN-154 keep their old location text.
- Manual step (user): `claude mcp remove -s user higgsfield`; journal line.

## 6. Testing and proof

- `make test` green (new suite + gitflow-test socle assertion + hook test).
- `shellcheck *.sh hooks/*.sh lib/*.sh` clean.
- `project-rules.sh check` exit 0 on this repo.
- `/context` before/after at the repo root; the four `path_glob_match`
  log lines from one real session.
- RED → GREEN pressure test transcript summary for `/onboard split`.

## 7. Out of scope, risks kept

- The per-repo pass (six repos) and whether path rules load inside
  sub-agents: measured on faunosteo first, during that pass.
- A `paths:` rule loads on Read, not on Write of a new file: generator
  rules load once the scaffolded file is edited (Edit needs a Read).
- The pre-commit `.claude/**` exemption lets a rules-only commit land on
  develop; split mode always branches first.
