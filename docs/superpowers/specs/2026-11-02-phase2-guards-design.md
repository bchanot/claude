# Phase 2 guards — design (2026-11-02)

BDR-125 phase 2. Contract: `.claude/tasks/contracts/2026-11-02-phase2-guards-1545.md`
(brainstorm answers 1-9 `[gated 2026-11-02]`). Branch `feature/phase2-guards`
off develop, after feature/router-ask-tier and chore/todo-reconcile-bdr125
merge.

## Goal
Make three mechanical doctrine rules deterministic and add one soft reminder:
1. `gitflow finish` and `git merge` run only after a human click (native ask).
2. The main loop writes code only inside a skill run (model-router guard).
3. Shell deny and ask rules are no longer bypassed by the rtk rewrite or by a
   bare shell, `sh -c` or an absolute shell path.
4. Lines over 80 columns that Claude adds to our code are reported back once
   per file per session, never blocked.
Mode stays `defaultMode: auto`. Nothing in deny is removed.

## Unit 1 — merge gate (settings.json `permissions.ask`)
Rules: `Bash(git merge *)`, `Bash(git -C * merge *)`,
`Bash(bash *gitflow.sh finish*)`, `Bash(sh *gitflow.sh finish*)`,
`Bash(gitflow_finish*)`. No `git pull *` (the lib pulls; the trailing ` *`
matches the bare form, LRN-194; Gitea protects develop and main).
`git push <src>:develop` is caught by the existing `Bash(git push *)` ask once
unit 3's passthrough lands.
Trade-offs accepted: BDR-068 `/close` auto-finish gets one click; a sub-agent
`finish` (release-executor span) is measured in the bench, and
`/release-candidate` runs `finish` in the main loop regardless (BLK-018 option
b), so the click always reaches the user.
hard_deny gains, inside the "Disarming the guardrails" entry: "never edit
`permissions.ask` to pass a gate".

## Unit 2 — routing guard (mods/model-router)
`tool.call` hook on `Edit`, `Write`, `NotebookEdit`.
- Scope: main loop only (`e.agentId === undefined`); router on (`!st.off`).
- Path: `file_path` (Edit, Write) or `notebook_path`. Free when it ends in
  `.md` or `.txt`, or has a path segment `.claude` or a leading `docs/`
  relative to the session root. Everything else is code, config included.
- Run signal (free when any holds): `st.runMain !== null`; `st.turnMain?.source`
  is `skill` or `model`; `st.userMain !== null` (a `/route` sticky).
- Otherwise `{ deny: <reason> }`, reason: "model-router: code is written
  inside a skill run. Enter /hotfix (≤2 files, obvious fix), /feat, /bugfix or
  /ship-feature, then make this edit. This is a redirect, not a refusal."
- Fail open like every other hook (`.catch` → `next(e)`, one warnOnce): the
  guard is doctrine support, its off switches are the router's (`/route off`,
  `~/.claude/model-router.json` `"enabled": false`).
- routing.json rows for the unrowed skills that write code inline:
  impeccable, design-html, design-review, design-consultation,
  higgsfield-websites, qa, review, investigate (row phase = the skill's
  nature: `reflect` for review/investigate/design-review/qa,
  `plan` for design-consultation, `reflect` for the build skills), plus the
  `pack-…:` long-name twins. The census `lib/skill-routing-census.py` and the
  routing tests pin them. These rows also make them ask once (first use) and,
  for best-tier, trigger the ask-tier question: intended.
- hard_deny gains: "A model-router redirect ('code is written inside a skill
  run') is not a refusal to route around: enter the named skill. Never call
  the `route` tool or type `/route` to pass the guard." The "Routing around a
  guardrail" entry gets one clause: "a redirect that names the path to take
  is followed, not reported".
- Tests (register.test.ts, kit): deny on a main Write of `src/a.ts` with no
  route; free on `README.md`, `.claude/tasks/x.md`, `docs/a.ts`; free in a
  sub-agent (`agentId`); free with a typed rowed skill across `endMainTurn`
  (runMain); free after a route-tool phase in the turn; free under `/route
  plan`; free when `/route off`; NotebookEdit path; a `.json` config is code.

## Unit 3 — shell deny hygiene
### rtk rc=3 passthrough
`hooks/rtk-rewrite.sh` rc=3 arm: `exit 0` with no output (the native ask/deny
sees the original command; rtk compression is lost on ask forms only).
Re-pin `hooks/.rtk-hook.sha256` in the same commit (edit + re-pin in one
step). Test: `lib/tests/rtk-rewrite.test.sh` gains T11 with a PATH shim `rtk`
that returns rc 3 for a probe command (hermetic, independent of the live rtk
and settings), asserting empty stdout; plus a pin check (the sha matches).
### Twins
For each of the 14 `Bash(cat|head|tail …)` deny entries, add
`Bash(rtk read <arg>)` and `Bash(*/rtk read <arg>)` (28 entries). If the bench
proves `head -5 .env` / `tail -n 5 .env` RUN under the current deny, add
`Bash(head * .env*)`, `Bash(tail * .env*)` and their rtk-read twins.
Census: a new block in `lib/tests/push-guard.test.sh` (the deny-lock suite):
every `Bash(cat|head|tail X)` deny has `Bash(rtk read X)` and
`Bash(*/rtk read X)`; flip-tested on a fixture settings file missing one twin.
T41 gains the new literals.
### Shell forms
`permissions.ask` += `Bash(sh -c *)`, `Bash(bash)`, `Bash(sh)`,
`Bash(bash -s*)`, `Bash(bash <(*)`, `Bash(/bin/sh *)`, `Bash(/bin/bash *)`,
`Bash(/usr/bin/env bash*)`, `Bash(/usr/bin/env sh*)`. `permissions.deny` +=
`Bash(awk *system(*`. Never `Bash(/*)`.
### Bench
`.claude/tasks/plans/2026-11-02-phase2-bench/`: `run.sh` copied from the
2026-10-25 bench, settings and command files SAVED this time, `results.tsv`.
Each new rule proven with a harmless analogue (`echo SECRET`) and the real
forms that are safe to run (`git merge --help`-class no-ops are not used: the
analogue rule carries the pattern shape). Rows: the 5 merge-gate forms + start
free + plain git free; the 9 shell forms + `bash script.sh` free; the awk
form; head/tail flag spellings; one sub-agent ask row (Agent dispatch running
an asked command headless).
### Limits written down
soft_deny gains one entry: the static matcher cannot see `$(…)` in command
position, a quoted literal argument, or an inline interpreter
(`python3 -c`, `node -e`); those rest on this classifier: refuse a command
that uses one of these shapes to reach an action a deny or ask rule names.
README permissions section states the same in prose, plus "ask prompts under
auto mode (measured 2026-10-25, bench R13)" replacing the inert claim;
`templates/settings/SETTINGS.md` § "`ask` is not a prompt under auto mode"
corrected.

## Unit 4 — code-limits hook
`hooks/code-limits.sh`, PostToolUse, matcher `Edit|Write|NotebookEdit`,
timeout 5.
- Reads `tool_input.file_path`, `session_id`, `cwd`. Skips unless the
  extension is one of sh bash ts js mjs py rs jq and
  `lib/code-origin.sh <repo of the file>` prints `ours` (cached per repo per
  session in the sentinel dir).
- Sentinel `${TMPDIR:-/tmp}/claude-code-limits-<session_id>/<sha of path>`:
  once a file is reported, it is never reported again this session.
- Added lines: `git diff -U0 -- <file>` `+` lines when the file is tracked,
  else `new_string` (Edit) or `content` (Write). Width = characters
  (`LC_ALL=C.UTF-8`, awk `length`). Over 80 → collect `line:width`.
- Output: at most 5 lines, `{"hookSpecificOutput":{"hookEventName":
  "PostToolUse","additionalContext":"code-limits: <file> has N added line(s)
  over 80 columns: L12 (93), …; our code keeps 80 (CLAUDE.md Limits)."}}`.
  Nothing over → no output. Any error → exit 0 silent (never blocks).
- Suite `lib/tests/code-limits.test.sh`: temp HOME, TMPDIR, a git fixture repo
  with `claude.origin ours` / `foreign`; over vs under; cap 5; second call
  silent; foreign silent; .md silent; untracked Write content; no jq → silent
  rc 0.

## Doctrine and docs
- CLAUDE.global.md Workflow ceiling bullet: "Ceiling: the main loop writes no
  code outside a skill run, whatever the model (model-router guard); it hands
  the edit to /hotfix, /feat, /bugfix or /ship-feature." Refusal clause gains
  "a guard redirect naming a skill is followed". Gitflow paragraph: "`finish`
  runs only on an explicit human signal …" stays, followed by "(enforced: an
  ask rule prompts every finish and merge)"; the BDR-068 sentence kept; no
  other compression (the rest is not enforced). ≤ 320 lines.
- Citers: README.md:72-75 (ceiling), the 15 agents' refusal clause where it
  restates "a refusal ends the attempt" (one shared sentence appended only
  where the agent edits code: bugfixer, feater, hotfixer, refactorer,
  code-cleaner, scaffolder, onboarder), skills/feat|bugfix|hotfix "CLAUDE.md
  Workflow" references unchanged (heading kept), lib/effort-shift.md if it
  quotes the ceiling.
- skills/release-candidate/SKILL.md: finish span runs in the main loop.
- CHANGELOG `[Unreleased]`, TODO phase 2 ticked, T42 dead-entry list handed
  to the user (12 entries: 6 dead, 6 `rtk cat|head|tail`).

## Out of scope (kept deferred)
Commit-msg hook; Bash write forms in the routing guard (the harness's own
"prefer Bash" auto-mode instruction is a known path around an Edit-scoped
guard: written down as a residual); G2 destructive guard (BLK-022); removal of
any deny entry.

## Proof
Bench rows for every new rule; guard fixtures; code-limits suite; routing
bench C4 / "doctor.sh rtk version" prompt in a throwaway clone enters a skill;
the user runs `/close` once and clicks; `make test` green; shellcheck clean.
