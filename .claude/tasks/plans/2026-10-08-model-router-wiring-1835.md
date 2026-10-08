# PLAN — model-router wave 1-B2: active in every session, tests, doctor (dispatch-ready)
Contract: .claude/tasks/contracts/2026-10-08-model-router-wiring-1835.md
Repo root: /Users/b.chanot/Documents/claude (branch feature/model-router-mod).

## Facts this plan rests on (verified 2026-10-08)
- Claude Code loads a folder holding `.claude-plugin/plugin.json` under
  `~/.claude/skills/` as `<name>@skills-dir`, in place, live at the next
  session start or `/reload-plugins` (docs: plugins/loading "In-place and
  copied plugins"; probe in an isolated HOME: listed, enabled, loaded).
- `~/.claude/skills` is already a symlink to the repo's `skills/` (link.sh).
- Repo scripts that walk `skills/` glob `*/SKILL.md` or fixed paths
  (doctor.sh, lib/skill-routing-census.py, the census suites);
  lib/profile.sh only moves entries named in a profile. An entry without
  SKILL.md is never counted, moved or flagged.
- The engine lays `<mod>/tsconfig.json` (extends the types) and
  `<mod>/.claude-plugin/types/` (own `.gitignore` holding `*`) when a mod
  loads; today `mods/model-router/tsconfig.json` shows as untracked.
- settings.json carries the user's uncommitted `/model` change: never
  stage, edit or restore it.

## Files
- [ ] `skills/model-router` — new RELATIVE symlink: from the repo root,
  `ln -s ../mods/model-router skills/model-router`. Nothing else in skills/.
- [ ] `.gitignore` — append a block:
  ```
  # mods/: files the engine lays beside a loaded mod (editor types)
  mods/*/tsconfig.json
  mods/*/.claude-plugin/types/
  ```
  Check first that no existing pattern ignores `skills/model-router` or
  the tracked mod files (contract AC1/AC2 oracles).
- [ ] `lib/tests/mods.test.sh` — new suite, style of the existing suites
  (read lib/tests/effort-pins.test.sh first and mirror its header, helpers
  and summary). Behaviour:
  - `ROOT="${MODS_ROOT:-<repo root from the script path>}"`.
  - Collect `$ROOT/mods/*/.claude-plugin/plugin.json`; none → FAIL
    ("no mod found") so the suite can never pass vacuously.
  - Per mod dir `<name>`: (1) the manifest `name` (python3 json, argv —
    never string-spliced) equals the folder name; (2) `$ROOT/skills/<name>`
    is a symlink whose `readlink` is exactly `../mods/<name>`; (3) when
    `command -v claude` succeeds: `claude plugin validate "$ROOT/mods/<name>"`
    prints `Validation passed` and no `warning` (case-insensitive);
    (4) same condition: `claude plugin test "$ROOT/mods/<name>"` exits 0.
  - `claude` absent → one `SKIP: claude CLI not found — validate/test not
    run` line; checks (1)-(2) still run and decide the exit code.
  - Exit 1 on any failure, 0 otherwise; one PASS/FAIL line per check and a
    final count line.
  - shellcheck clean. No network, no writes outside a `mktemp -d` if any
    scratch is needed (none expected).
- [ ] `doctor.sh` — new section `── Mods ──`, placed right after the
  "Vendored skills" section (read lines 120-160 first; mirror its
  `echo ""` / heading / pass-warn-fail-info style). For each
  `$REPO/mods/*/` holding `.claude-plugin/plugin.json` (`<name>` = folder):
  - link `$HOME/.claude/skills/<name>`: `readlink -f` equal to
    `$REPO/mods/<name>` → `pass "mod <name>: loading link ~/.claude/skills/<name>"`;
    missing → `fail "mod <name>: ~/.claude/skills/<name> MISSING — git checkout skills/<name>, then make link"`;
    elsewhere → `warn`. Do NOT call `check_symlink` (it feeds the core-link
    counter `_LINK_PASS` / `_EXPECTED_LINKS`).
  - `command -v claude` → `claude plugin list --json` parsed with python3
    (argv/stdin, no splicing): id `<name>@skills-dir` with `enabled: true`
    → `pass "mod <name>: loaded as <name>@skills-dir"`; present but
    disabled → `warn "... disabled (enabledPlugins \"<name>@skills-dir\": false)"`;
    absent → `warn "... not listed — new session or /reload-plugins"`.
    `claude` missing → `info "claude CLI not found — load state not checked"`.
  - `$HOME/.claude/<name>.json` present → `python3 -m json.tool` (quiet)
    → `pass "mod <name>: override ~/.claude/<name>.json parses"` or
    `fail "... invalid JSON"`; absent → nothing.
  - No mod at all → `info "no mods"`.
- [ ] `CLAUDE.md` (project, repo root) — new section `## mods/ — function-hooks
  plugins (Claude Code mods)` placed after the graphify section, terse
  English in the file's own style, at most ~14 lines, covering: what lives
  in `mods/<name>/`; it loads through the tracked relative symlink
  `skills/<name>` → `../mods/<name>` as `<name>@skills-dir` (in place, live
  at the next session or `/reload-plugins`); why not
  `CLAUDE_CODE_PLUGIN_DIRS` (absolute path, settings `env` has no `$HOME`
  expansion, settings.json is tracked) nor a local marketplace (its `add`
  writes an absolute path into settings.json); engine-laid
  `tsconfig.json` + `.claude-plugin/types/` are gitignored; optional user
  config `~/.claude/<name>.json`; tests `make test suite=lib/tests/mods.test.sh`
  (validate + `claude plugin test`); turn a mod off with
  `"<name>@skills-dir": false` in `enabledPlugins`; a dev copy loaded with
  `--plugin-dir` or the hot-reload folder shadows the skills-dir copy
  (same name, session-only wins).

## Verify (executor pastes outputs)
`ls -l skills/model-router`; `git check-ignore -v mods/model-router/tsconfig.json`;
`make test suite=lib/tests/mods.test.sh`; the contract AC3 positive control;
`bash doctor.sh | sed -n '/── Mods ──/,/^$/p'`; `shellcheck lib/tests/mods.test.sh doctor.sh`;
`git status --short` (settings.json still ` M`, untouched); then from the
repo root `bash ~/.claude/lib/gates.sh run .claude/tasks/contracts/2026-10-08-model-router-wiring-1835.md`.

## Edge cases
- The engine-laid `mods/model-router/tsconfig.json` already exists on disk:
  after the `.gitignore` change it must disappear from `git status`.
- doctor runs without `claude` on PATH (Linux box): info line, no failure.
- A second mod later: the suite and doctor loop over `mods/*/` already.
- A hot-reload or `--plugin-dir` copy of the same mod shadows the
  skills-dir copy in that session; doctor reads `claude plugin list` from a
  fresh process, which sees only the skills-dir copy.

## Disposition
- honors BDR-115 (mod in `mods/`, single source); amends its "Load:" line
  (PLUGIN_DIRS → skills-dir link), to be recorded at capitalize.
- honors the destructive-tools rule: no recursive delete, no transfer
  tool; LRN-150/LRN-171 shell hygiene (`command grep` where a shim can
  interfere is not needed here: plain bash).
