# PLAN — claude-ai-skills-off (/feat, 2026-11-09) — r2 after challenge

Contract: `.claude/tasks/contracts/2026-11-09-claude-ai-skills-off-1253.md`

## Goal
Cut the claude.ai-synced skills from the skill listing of every Claude Code
session (profile or not), −3.7k tokens measured on full, with a per-project
way back.

## Facts (measured 2026-11-09, CLI 2.1.319, raw in scratchpad ctx/)
- `/context` headless full: Skills 16.2k, of which `claude.ai sync` 3.7k (19 items).
- `--settings` overlay `skillOverrides` {19 names: "off"} → Skills 12.5k, total 32.2k → 28.5k.
- Same object in a scratch project's `.claude/settings.local.json` → 0 synced skills listed: works from a settings file scope.
- Docs: values on | name-only | user-invocable-only | off; plugin skills unaffected. `syncClaudeAiSkills: false` rejected (moves synced skills to `~/.claude/skills/.trash/`).
- `~/.claude/settings.json` is a symlink to this repo's `settings.json`: the edit is live for every running session the moment it lands.
- `### Changed` already exists under CHANGELOG `[Unreleased]` (CHANGELOG.md:36-65).

## PLAN
  [ ] settings.json — ONE Edit-tool call on `/home/bchanot/Documents/claude/settings.json` (never a shell redirect, never the `~/.claude/settings.json` path, never `mv`): replace the `env` block's closing `  },` that precedes `  "attribution"` (settings.json:6-7) with `  },` + a new `  "skillOverrides": { … },` block, the 19 names in alphabetical order, each `"off"`, 2-space indent like the file, trailing comma before `"attribution"`. Then `jq empty settings.json` must exit 0.
  [ ] README.md § "Settings and permissions" (~317-340) — one short paragraph after the "DENY always wins" line: settings.json turns the claude.ai-synced skills off via `skillOverrides` (listing cost measured on the full profile 2026-11-09: 32.2k → 28.5k tokens headless); the list is by name, so a skill synced later stays listed until its name is added, and a same-named skill elsewhere is hidden too; a project re-enables one with `{"skillOverrides": {"<name>": "on"}}` in its `.claude/settings.local.json`. No hardcoded count, no em-dash.
  [ ] CHANGELOG.md — append one bullet at the end of `[Unreleased]` `### Changed` (before the next `###`/`##` heading): same facts, Skills 16.2k → 12.5k and total 32.2k → 28.5k (headless, full, CLI 2.1.319), budget unchanged (40000 and 50000 give the same listing once the synced skills are off), `syncClaudeAiSkills: false` not used (moves files to .trash), check `claude --version` on another machine before pulling.

## Edge cases
- Newly synced claude.ai skill: listed until named (README says so).
- Prefixed names (`anthropic-skills:deep-research`) keyed exactly as `/context` prints them.
- Per-key merge across scopes (user map + project "on"): proven by contract criterion 2 from a real `.claude/settings.local.json`; if it fails (wholesale replace), STOP: the README re-enable sentence is false.

## Tests
No new test file: no census covers settings.json beyond push-guard deny locks (untouched). Oracles: contract criteria 1-3 (`gates.sh`).

## Accepted risks (challenge 2026-11-09)
- An older CLI on another machine: behavior with `skillOverrides` unverified (CHANGELOG names the check).
- A UI write into user-scope `skillOverrides` would dirty this tracked file; doctor's residue check covers `enabledPlugins` only. Follow-up candidate, not this run.

## Disposition
- honors BDR-134 (packs and profiles untouched); the global key is the same kind as the global `env` budget BDR-134 set; user asked that a plain `claude` behave as full.
- honors LRN-088 / LRN-175: measured per-item cost first; the cut frees context because the budget sits above the natural listing on full.
- honors BDR-125 subtract-only spirit: nothing deleted, `"on"` restores per project.
