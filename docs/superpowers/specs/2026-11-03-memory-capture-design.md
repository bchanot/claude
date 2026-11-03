# Phase 4b memory capture — design (2026-11-03)

BDR-125 phase 4b. Contract `.claude/tasks/contracts/2026-11-03-memory-capture-0100.md`
(brainstorm answers 1-8 `[gated 2026-11-03]`). Engine facts:
`.claude/tasks/plans/2026-11-03-memory-capture-spike/REPORT.md`. Branch
`feature/memory-capture`.

## Goal
Capture is the weak link of the memory loop (5 of 7 real errors of 2026-10-23
had no registry entry). A mod records what failed during a session and the
moments worth capitalizing, and hands them to /capitalize and the CAPITALIZE
steps through one tool. Writing stays exactly as today: the model drafts, the
user approves, `lib/memory.sh` writes. The mod never writes a registry.

## Unit 1 — mod `mods/memory/`
Layout like model-router (`.claude/rules/mods.md`): `.claude-plugin/plugin.json`
(name `memory`, version 0.1.0, description, author), `hooks/hooks.json`
(`{"modules": ["./register.ts"]}`), `hooks/register.ts`,
`hooks/register.test.ts`, tracked link `skills/memory -> ../mods/memory`.
Off switch: `~/.claude/memory.json` `{"enabled": false}` (read like
model-router's override; any read error → enabled). Fail open on every hook
(`.catch` → `next(e)`, one log line per hook per session). Closure state only;
persistence through `$.store`.

## Unit 2 — failure capture
- Hook: `tool.call` on `Bash`, after `const out = await next(e)`; the answer
  is returned unchanged.
- A failure: `out.isError === true` and `out.text` starts `Exit code ` + digits.
  Excluded: texts starting `Permission to use`, containing `haven't granted it
  yet`, starting `model-router:`, or containing `<tool_use_error>`.
- Distinctive line: the last non-empty line of `out.text` after the first line;
  none → not captured (`false`, `grep` with no match).
- Entry: `{ line, excerpt, command, agent, at }` where `line` is the redacted
  distinctive line (≤ 300 chars), `excerpt` the redacted last 1200 chars of the
  text, `command` the redacted command (≤ 300 chars), `agent` true when
  `e.agentId` is set, `at` the clock (ms).
- Normalized key: lowercase; numbers → `#`; absolute and relative paths
  (`/x/y`, `./x`, `x/y.ext`) → `<path>`; hex runs ≥ 7 → `<hex>`; whitespace
  folded. The same key twice in a session is stored once (a `count` field
  increments).
- Bounds: ≤ 50 entries per session (oldest dropped), entry ≤ 2 KiB after
  truncation, the 3 most recent sessions per project kept, the whole store
  value ≤ 1 MiB (oldest project sessions evicted first). Every regex over tool
  text runs on input capped at 64 KiB (LRN-219).

## Unit 3 — redaction (before anything is stored)
One function `redact(text)`, applied to line, excerpt and command:
- `NAME=value` where NAME matches `[A-Za-z_]*(TOKEN|API_KEY|SECRET|PASSWORD|PASSWD)[A-Za-z_]*` → `NAME=<redacted>` (same rule as the rtk env-dump redaction).
- The 7 `/guardrails` SECRET_PATTERNS (skills/guardrails/scripts/checks/apis.py:10-19: Stripe, AWS access key, GitHub token, Slack token, SendGrid key, Supabase secret, private key block) → `<redacted:kind>`.
- `Bearer <token>` → `Bearer <redacted>`; URLs `scheme://user:pass@host` → `scheme://<redacted>@host`.
- 40-hex SHAs are not secrets and stay.
Test oracle: fixtures written as literal expected strings in the test, never
computed by the redactor (LRN-237); secret-shaped fixtures use the gitleaks
allowlisted shapes (`test-secret-…` and the fake AWS key named in
`.gitleaks.toml`), in files the allowlist covers.

## Unit 4 — milestones
From successful Bash results (`out.isError` absent), on the main loop only:
- `commit`: the command's first simple command is `git commit` (optionally
  `git -C <dir> commit`) and the text holds `-m "feat` / `-m 'feat` / `-m feat`
  or `fix` (also `feat(` / `fix(` scopes). Other commits are not milestones.
- `finish`: the command runs `gitflow.sh finish` (bash or sh form) and not
  `finish chore` (the /capitalize and /close auto-finish, BDR-068).
- `green`: a command containing `make test` that succeeded, when the same
  command string (normalized whitespace) failed earlier in the session.
Stored per session with `{ kind, at, label }` (label: the commit subject's
first 80 chars, the branch named by finish if present, or the suite argument).
Note: at the first `prompt.submit` from the composer after a milestone, one
context line is attached: `memory: <kind> <label> — <n> new failure mode(s)
this session; /capitalize when ready.` One note per milestone (a milestone is
marked noted), never at Stop, never per turn, never in a sub-agent.

## Unit 5 — `memory_pending` tool
Registered at `session.start` (`$.tool.register`, name `memory_pending`,
public `mcp__memory__memory_pending`), input `{}`. Answer `{ result: <text> }`:
- `failures:` the entries of the project's stored sessions (current first),
  each `NEW` or `known <ID>`, with `count`, `line`, `command`, `excerpt`.
- `milestones:` the current session's milestones.
- an empty answer says `memory_pending: nothing captured`.
Index (built per call, no cache): read `<root>/.claude/memory/blockers.md` and
`learnings.md` with `$.fs.read` (missing file → empty index); per entry
(`## ID —` heading to the next `## `), skip entries whose status reads
superseded (header tag or last labelled status line, the memory.sh rule); take
the backticked spans of ≥ 12 chars; normalize like Unit 2; an entry's 4-grams
are its spans' word 4-grams. Known = the failure's normalized line shares ≥ 1
4-gram with one entry (first match wins, ID order). The tool never writes the
store's registries and never calls `lib/memory.sh`.
Every text the tool returns is data: the CAPITALIZE consumers quote it in the
draft for the user, never paste it into a shell argument (LRN-198).

## Unit 6 — consumers
- skills/capitalize/SKILL.md STEP 1 (scan) opens with: load the tool once
  (`ToolSearch("select:mcp__memory__memory_pending")`), call it, and treat each
  `NEW` failure and each milestone as a candidate source (blocker or learning
  draft), deduplicated against the conversation scan; mod off or tool absent →
  "memory_pending unavailable", the scan goes on as today. /close inherits it
  (alias).
- CAPITALIZE steps of feat (STEP 7), bugfix (STEP 8), ship-feature (STEP 7):
  the same opening line, pointing at capitalize's STEP 1 rule.
- hotfix STEP 6: stays silent (today's default) unless the tool returns a
  `NEW` failure; then it proposes one blocker draft.
- commit-change: the skill calls the tool before dispatching commit-changer
  and appends its output to the brief as data (commit-changer has no MCP).
- `lib/capitalize-commit.md` § WRITE unchanged; CLAUDE.global.md "Proactive
  capitalization" unchanged (the note is its mechanical half).

## Docs
README model-router-style bullet for the memory mod (what it records, where,
bounds, off switch, the tool), USAGE same in French, ARCHITECTURE mods line,
CHANGELOG `[Unreleased]`, TODO (4b ticked, 4c next).

## Proof
- Kit tests: capture (exit with/without line, exclusions, dedupe, bounds,
  sub-agent flag), redaction fixtures with literal expected strings, index and
  matching on fixture registries (a known BLK line, a NEW line, a superseded
  entry ignored), milestones (feat/fix commit, other commit ignored, finish vs
  finish chore, red→green), one note per milestone, tool answer shape,
  off switch, fail-open.
- Noise measured before shipping on real transcripts (LRN-047): replay the
  Bash results of the last 14 days of this repo's sessions through the
  capture rule (a small offline script over `~/.claude/projects/*/*.jsonl`,
  read-only), report captured per session and the share a human would call
  noise on a sample of 30.
- Live: in a fresh session, a failing command then `/capitalize` shows the
  failure as `NEW`; a `fix:` commit triggers one note at the next prompt.

## Out of scope
4c (intent recall, error 4-gram match at PostToolUse, session digest); 4d;
any write to registries by the mod; non-Bash tool failures; gitleaks as a
redaction engine.
