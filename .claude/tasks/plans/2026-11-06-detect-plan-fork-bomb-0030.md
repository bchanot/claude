# Bugfix plan: detect_plan fork bomb (2026-11-06)

## Diagnosis

BUG: running `lib/tests/session-digest.test.sh` (uncommitted SD13 cases)
filled 14 GiB of RAM in 45 s; 2026-11-05 23:49 → OOM → reboot 23:55.
Kernel OOM dump: 126 `claude`, 396 `bash`, 124 `sh`, all
`oom_score_adj=-1000`.

ROOT CAUSE: `lib/detect-plugins.sh:85` `detect_plan` falls back to
`claude config get planType` when `$HOME/.claude.json` lacks the plan
markers or is absent. claude 2.1.318 has no `config` subcommand
(`claude config --help` prints the main usage), so the words are read
as a prompt and a full session starts. Its SessionStart hook
(`hooks/session-start.sh:158` → `detect_plan`) runs with the same HOME,
finds the same missing markers, starts another `claude`: unbounded
recursion. SD13's `mkhome` builds a HOME that links `~/.claude/*` but
not `~/.claude.json`, so the fallback fires.

EVIDENCE: journal boot -1 (earlyoom + kernel OOM table), transcript
90b2c305 (`make test suite=lib/tests/session-digest.test.sh` at
23:49:07, result at 23:51:28), `claude config --help` output.

BLAST RADIUS: production too. Real sessions survive only because
`~/.claude.json` holds `tengu_cobalt_compass` + `tengu_harbor` (internal
feature flags). If upstream renames them, every session start recurses.
`detect_plan` is called only from `hooks/session-start.sh:158`. No other
hook or lib calls the `claude` CLI (`lib/cc.sh` is the user launcher).
The hook header already promises "Filesystem only, except one git fetch".

RELATED MEMORY: no BLK/BDR/LRN bears (grep detect_plan, fork, recurs,
oom, planType).

## Fix plan

1. `lib/detect-plugins.sh` `detect_plan`: delete the `claude config get
   planType` fallback and its `case`; markers absent → `echo "pro"`
   (the existing default). Comment states why the CLI is never called
   (a hook-launched `claude` re-enters this hook).
2. `hooks/session-start.sh`: recursion guard at the top, before stdin
   is read: `[ -n "${CLAUDE_SS_RUNNING:-}" ] && exit 0; export
   CLAUDE_SS_RUNNING=1`. The variable lives only in the hook's process
   tree: a sibling session never sees it; any `claude` a future change
   spawns from the hook gets a silent no-op hook instead of a cascade.
3. `lib/tests/session-digest.test.sh` (keeps the uncommitted SD13/SD14
   cases intact):
   - suite-wide stub: `$WORK/stub/claude` writes one line to
     `$WORK/claude-calls` and exits 0; `PATH="$WORK/stub:$PATH"` exported
     before any case. A regression then records a call instead of
     forking a real session. SD13h's `PATH="$bin"` already holds no
     claude.
   - SD15a: `HOME` without `.claude.json` (mkhome as is), hook runs →
     `claude-calls` absent/empty.
   - SD15b: `CLAUDE_SS_RUNNING=1` set → hook prints nothing, rc 0.
   - SD15c: `detect_plan` sourced alone with an empty HOME prints `pro`.
   Replaces the `ulimit -u` idea: the per-user process cap counts every
   process of the user (hundreds of live ones), so a value is either
   too tight (spurious red) or too loose (no protection); the stub is
   deterministic.

ORDER: fix 1 lands before the suite runs again (DO NOT run the suite
on the current tree).

RISK: low. Plan detection for users without the markers now always
reports Pro (banner budget label only). Guard: a user who runs the hook
by hand from inside a hook-spawned shell sees nothing (no such use).

Out of scope: origin of `oom_score_adj=-1000` on claude processes
(recorded as an open BLK), plan detection accuracy.

## Revision r2 (after 3-lens challenge, 2026-11-06)

Challenge: simplicity SOLID (4 MINOR), correctness CONCERNS (1 MAJOR),
robustness CONCERNS (3 MAJOR). Named changes:

- R1 (correctness 1, robustness 3: landing). The fallback is on main and
  develop. The fix splits in two:
  - Part A, on its own branch off main or develop (user choice), in a
    separate `git worktree` (so `~/.claude/hooks` and `~/.claude/lib`,
    symlinked to the main working tree, never flip to another branch and
    the uncommitted 4c work stays untouched): fix 1, fix 2, and a
    standalone regression suite `lib/tests/detect-plan.test.sh` that
    needs nothing from feature/memory-recall.
  - Part B, on feature/memory-recall after Part A merges: suite-wide
    stub in session-digest.test.sh + final empty-log assertion.
- R2 (robustness 1+2, correctness 2+4: proof). The stub is written with
  the log path expanded at creation, `chmod +x`, and a positive control
  first calls `claude` through PATH and asserts 1 logged line (stub
  reached). The regression case calls `detect_plan` directly (no hook,
  no recursion path) with an empty HOME and asserts output `pro` AND
  0 new log lines. Red proof: that case runs once against the pre-fix
  lib (safe: stub catches the single call) and must fail, then pass
  after fix 1. Copied into the contract as [gated]: never run the hook,
  `make test` or the session-digest suite before fix 1 is on disk.
- R3 (correctness 3, robustness 5: guard). Guard kept as
  defense-in-depth (the -1000 adj made the runaway unkillable), renamed
  `SESSION_START_RUNNING` (simplicity 4, repo convention). The hook
  comment says it has no live caller and that it relies on claude
  passing env to its hooks. Test: hook run with the variable set prints
  nothing, rc 0; and a PATH stub `git` writes `$SESSION_START_RUNNING`
  seen by the hook's child, asserting `1` (proves the export).
- R4 (simplicity 2, correctness 5: dead code). detect_plan docstring
  "max or pro"; the `free)` arm at session-start.sh:162 dropped.
- R5 (simplicity 3): SD15a/SD15c dropped from Part B; one final
  cumulative empty-log check covers every hook run of the suite.
- R6 (robustness 6: containment). The first run of each suite after the
  fix goes through `systemd-run --user --scope -p TasksMax=256` (cgroup
  pids cap counting only that scope).
- Deferred to TODO (robustness 4, MINOR): stub in memory, graphify-gate
  and push-guard suites, which run the hook with the real HOME.
