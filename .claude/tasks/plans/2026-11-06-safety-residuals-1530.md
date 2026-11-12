# Bugfix plan: five safety residuals from finished phases (2026-11-06) — r3

Branch: bugfix/safety-residuals off develop (ddb04f4). One commit per item.
r2 after the 3-lens challenge (correctness CONCERNS(2), robustness
CONCERNS(5), simplicity CONCERNS(1); no BLOCKER). Changes vs r1 are tagged
[r2: lens n].

## RELATED MEMORY
- BLK-043 / LRN-263 (item 1): hooks never call the claude CLI; hook-running
  tests stub it and cap tasks. Item 1 completes LRN-263's "future use".
- BDR-136 (item 2): shell rules are added only once bench-proven; the bench
  is `.claude/tasks/plans/2026-11-02-phase2-bench/`.
- LRN-074 (item 4): system awk may be mawk; no gawk-only flag.
- BDR-045, LRN-084 (item 5): the `.claude/**` exemption was kept so the
  side-car memory commit and standalone /capitalize, /close land in place;
  BDR-045 rejected "narrow by size/scope" as fuzzy. Item 5 narrows by an
  exact path allowlist (user choice 2026-11-06), a partial revision of
  BDR-045, recorded as a new BDR on commit.

## Safety rules for the whole run
- Every run of a hook-running suite, of `lib/gitflow-test.sh` and of the
  bench goes through `systemd-run --user --scope -q -p TasksMax=256`.
- The real `claude` CLI is never run, except by the bench's `run.sh`
  (`claude -p --setting-sources local`: no user settings, no hook).
- The bench runs only after its own hardening (item 2 step 1) and from a
  cwd holding no `.env` (the session scratchpad).
- Live paths: `settings.json`, `lib/`, `githooks/` (~/.claude links to
  this tree; global core.hooksPath = ~/.claude/githooks). settings.json is
  written only via `jq … > tmp && jq empty tmp && mv tmp settings.json`.
  [r2: robustness 7; r3: confirm 2]
- Rollback of an open item: `git restore --staged --worktree -- <its
  paths>` (or `git stash push -- <paths>`), THEN `git checkout develop`;
  the next session start in each onboarded repo re-syncs its `.githooks/`
  from the (restored) lib. [r3: confirm 1]
- Execution: one item at a time, in order 4, 3, 1, 2, 5 (smallest blast
  radius first, the machine-wide guard last); each item committed once
  its own suites pass, before the next starts.

## 1. Suites that can reach the real claude CLI

ROOT CAUSE: the LRN-263 stub is copied inline in detect-plan and
session-digest and is fail-open: `claude probe` runs before any check that
`command -v claude` is the stub; a failed stub write (no `set -e`) or a
noexec TMPDIR (command -v skips a non-executable file) reaches the real
CLI; a red positive control does not stop the suite. graphify-gate (:61),
memory (`banner()` :689) and push-guard (:356) run hooks/session-start.sh
with no stub. cc.test.sh (:30-38) shims `claude`, `systemd-run`, `dtach`
with the same fail-open shape while lib/cc.sh runs `systemd-run … dtach …
exec claude` [r2: robustness 3]. A relative work dir passes a
same-cwd check but stops resolving after the `cd` every hook run does
[r2: robustness 4].

FIX:
- New `lib/tests/claude-stub.sh` (sourced):
  - `stub_first_or_die <cmd> <expected-path>`: `command -v <cmd>` must
    equal the path, else print `<cmd> stub not first on PATH` on stderr
    and exit 1.
  - `claude_stub_install <work-dir>`: refuse empty or missing dir; make it
    absolute (`cd -P "$1" && pwd`) [r2: robustness 4]; write
    `<dir>/stub/claude` (log path expanded at creation), `chmod +x`, each
    step `|| exit 1`; prepend `<dir>/stub` to PATH and export it;
    `stub_first_or_die claude <dir>/stub/claude`; positive control run as
    a child from another cwd: `(cd / && claude probe)`, log must hold
    exactly 1 line else exit 1 [r2: robustness 4]; empty the log; export
    `GIT_CEILING_DIRECTORIES=<dir>` so no hook run walks into an enclosing
    repo [r2: robustness 9, simplicity 3: applied uniformly].
  - `claude_stub_calls`: line count of the log.
- detect-plan, session-digest: inline stub replaced by the helper.
- graphify-gate, memory, push-guard: helper installed before the first
  hook run (memory: directly above `banner()`, never near the top: $FIX is
  the fixture repo itself) [r3: confirm 6]; each suite ends with `no-claude-calls` = 0 before its summary.
- cc.test.sh: after writing its shims, `stub_first_or_die` for claude,
  systemd-run and dtach against `$FX/bin/*`. [r2: robustness 3]
- `X=$(mktemp -d) || exit 1` at the mktemp of each suite touched here
  (detect-plan, session-digest, graphify-gate, memory, push-guard, cc).
  [r2: robustness 10; no extra `[ -d ]`, simplicity 3]
- detect-plan: `bash -c 'source "$1"; detect_plan' _ "$LIB"` (both sites).
- Regression suite `lib/tests/claude-stub.test.sh`:
  (a) fail-closed: in a subshell, `chmod() { :; }` shadows chmod so the
  stub stays 0644; PATH also holds a second dir with a fake `claude` that
  writes a sentinel; `claude_stub_install` must exit 1 with
  `claude stub not first on PATH`, sentinel absent.
  [r2: correctness 5, simplicity 2]
  (b) relative dir: install from a relative dir name, then
  `(cd / && command -v claude)` = the absolute stub path.
  (c) happy path: rc 0, `claude_stub_calls` = 0 after install.

## 2. `rtk read` with a leading flag or file on a root-level `.env`

ROOT CAUSE: the rtk read deny twins were generated as `rtk read X*` and
`rtk read */X*`. A root-level target after a flag or another file
(`rtk read -n .env`, `rtk read a.txt .env`) matches neither; rtk rewrite
rc 3 passes it through (60ee4a9). Targets under a `*/` prefix are
already covered: the `*` right after `rtk read ` absorbs `-n sub` or
`a.txt sub` (matcher `*` spans spaces, bench A1, LRN-194(c)).
[r2: simplicity 1, correctness 6]

FIX:
- Step 1, harden the bench before any run [r2: robustness 5]:
  bench.sh `W="$(mktemp -d)" || exit 1`; run.sh `cd "${4:?}" || exit 1`,
  with run.sh's usage line and README.md making `dir` mandatory.
  [r3: confirm 7]
- Step 2, bench rows (cases.tsv), run from the scratchpad, contained:
  - R3 deny `Bash(rtk read * .env*)`, cmd `rtk read -n .env` → DENIED.
  - R4 deny `Bash(rtk read */.env*)` (the EXISTING rule), cmd
    `rtk read -n sub/.env` → DENIED (proves no `* */X` twin is needed).
  - R5 deny `Bash(rtk read * .env*)`, cmd `rtk read -n README.md` → RAN.
  - R6 deny `Bash(*/rtk read * .env*)`, cmd
    `/home/bchanot/.local/bin/rtk read -n .env` → DENIED.
    [r2: robustness 8]
  - R7 deny `Bash(*/rtk read */.env*)` (EXISTING), cmd
    `/home/bchanot/.local/bin/rtk read -n sub/.env` → DENIED. [r3: confirm 5]
  A NO_TOOL_CALL verdict, or a `sent` column that differs from the
  cases.tsv cmd, is rerun once, not counted as a rule failure.
  [r2: correctness 7; r3: confirm 4]
- Step 3, only if R3, R4, R6, R7 DENIED (each with `sent` = its cmd), R5 RAN and every control RAN: add
  `Bash(rtk read * .env*)` and `Bash(*/rtk read * .env*)` to
  `permissions.deny` (`.env.*` is contained in `.env*`), pin both in
  push-guard's T63 list. Any other outcome → item 2 stops, reported,
  nothing added. If R4 is not DENIED, item 2 stops too (the `*/` twins
  then need their own bench).

## 3. session-start `memory.sh check` not time-bounded

ROOT CAUSE: hooks/session-start.sh:319 runs `bash "$_mem_lib" check
.claude/memory` unbounded; the digest (:377) uses `timeout 2` when present.

FIX: same shape as the digest (`tmo=()`, `command -v timeout && tmo=(timeout
2)`, `"${tmo[@]}" bash …`, bash 3.2 safe as the digest is). Regression in
session-digest: a memory.sh that sleeps 10 s on `check` → hook returns in
< 3.5 s, rc 0 (mirror SD12).

## 4. awk reads an assignment-shaped path operand as an assignment

ROOT CAUSE: awk treats an operand matching `^[A-Za-z_][A-Za-z0-9_]*=` as a
variable assignment and reads stdin instead. memory.sh passes user paths as
awk operands: `--body-file` to `_mem_fence_open`, `_mem_body_heading` and
`_mem_entry_text` (the entry text itself is copied by awk, so today the
entry gets stdin's content, not the file's) [r2: correctness 4], and the
`check` / `upgrade` dir argument.

FIX: `_mem_path_safe <p>`: prints `./<p>` only when p matches the
assignment shape, else p unchanged; empty in, empty out
[r2: correctness 2+3, robustness 1]. Applied to the body file in
`memory_add` and to the `check` / `upgrade` dir AFTER the
`${1:-.claude/memory}` default and the usage guard. Every existing output
stays byte-identical (T7f unchanged). Regression in memory.test.sh, every
call `</dev/null` [r2: correctness 4, robustness 11]:
`add … --body-file x=1.md` whose body holds an unfenced `## ` line → rc 2;
`add … --body-file x=1.md` with a clean body → the entry holds that body;
`check a=b` reads `a=b/*.md`.

## 5. Pre-commit `.claude/**` exemption too wide

ROOT CAUSE: lib/gitflow.sh emit (:490) whitelists any staged set under
`.claude/` or `.githooks/`, listed with `git diff --cached --name-only`,
which shows only a rename's destination [r2: correctness 8,
robustness 2].

FIX (user choice 2026-11-06: memory, tasks, audits, deploy; settings.json
NOT exempt):
- Emitter: exempt only when every staged path is under `.claude/memory/`,
  `.claude/tasks/`, `.claude/audits/`, `.claude/deploy/` or `.githooks/`;
  list with `git diff --cached --name-only --no-renames`; BLOCKED hint
  names the allowlist.
- Order: emitter edit → tests (lib/gitflow-test.sh, contained) green on
  the emitter → only then regenerate. [r3: confirm 2]
- Regenerate both hooks in the same commit: `.githooks/pre-commit`
  (`bash lib/gitflow.sh install-hook`) and `githooks/pre-commit`
  (`bash lib/gitflow.sh global-hooks "$PWD/githooks" '~/.claude/githooks'`);
  drift proof T19a, T19d, G5. [r2: correctness 1, robustness 6]
- Tests in lib/gitflow-test.sh: relabel T3; add to T14/T21 on develop:
  `.claude/rules/x.md` only → BLOCKED; `.claude/settings.json` only →
  BLOCKED; `git mv .claude/rules/x.md .claude/tasks/x.md` → BLOCKED;
  memory-only, tasks-only, deploy-only, audits-only → allowed.
  [r3: confirm 3] [r2: simplicity 4]
- Citers reworded to the allowlist: CLAUDE.global.md:160, :172, :174;
  settings.json:606 (environment prose); lib/gitflow-aiguillage.md:35.
  Grep `\.claude/\*\*` again after the edit. [r2: simplicity 4]

RISK: medium. Item 5 changes a guard every repo runs: committing
`.claude/settings.json` or rules on develop now needs a branch (1 such
commit in develop's history, 858e7a7). Item 2 depends on the bench.
Items 1, 3, 4 are local to tests and libs.
