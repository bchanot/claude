# CONTRACT — memory-capture (phase 4b)
- date: 2026-11-03 | flow: ship-feature | branch: feature/memory-capture (off develop 29624d7)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Phase 4b of the context mod queue (BDR-125), TODO.md "Phase 4b-4d, memory v2 capture, read, feedback" — the 4b capture part: failure ledger (tool results with isError, deny or non-zero exit carrying a distinctive error line → normalized + verbatim + command, redacted at capture, bounded ring per session in $.store, matched against the registry error index; unmatched = new failure modes), milestones (feat/fix commit, gitflow finish, a suite red then green), a `memory_pending` tool returning unmatched failures + milestones, called first by /capitalize, /close and every CAPITALIZE step; one context note at the next prompt after a milestone, never per turn, never at Stop; writing stays model draft + user approval + lib/memory.sh. Designed 2026-10-25 (measured: 5 of 7 real errors had no entry, error 4-gram match exact). 4c (read side) is the next ship-feature; 4d stays deferred.

(user brief 2026-11-02, step 3: "Phases 4b à 4d". The TODO bullet "4b capture (mod)" at develop 29624d7 is the design seed.)

Session constraints (same brief): default model opus; verifier, security-auditor and plan-challengers pinned on opus; never commit a `/model` or UI write of settings.json (LRN-253); plan text through Write/Edit (BLK-039); destructive steps on the live tree in the main loop after the user's go, `mv` over `rm` (BLK-040).

## CLARIFICATIONS
Pass A (gaps found by the STEP 0d read-before, put to the user at the STEP 1 brainstorm; answers land `[gated]`):
- Engine facts that reshape the seed (types 2.1.277 on disk, CLI 2.1.317): a non-zero Bash exit is an `isError` result whose text starts `Exit code N` (no exit-code field; the typed record with stdout/stderr/gitOperation exists on success only); `$.store` is per plugin, machine-wide, cross-project, 4 MiB total (not per session); there is no `$.state`; a registered tool exists from the prompt after `session.start`; sub-agents with a `tools:` allowlist cannot call an MCP tool (commit-changer); gitleaks rules are compiled into the binary (no data to port as-is); `session.id` changes on /clear and resume.
- Spike 2026-11-03 (probe mod, headless, CLI 2.1.317; `.claude/tasks/plans/2026-11-03-memory-capture-spike/REPORT.md`): a non-zero exit, a deny rule and an unapproved ask all come back from `next(e)` as `isError: true` with the reason only in `text` (`Exit code N\n<stderr>`, `Permission to use Bash with command … has been denied.`, `Claude requested permissions to use Bash, but you haven't granted it yet.`), never a `deny` field; `classic.PermissionDenied` never fired; `classic.PostToolUseFailure` fires on non-zero exits (`error` = text); success results carry `{stdout, stderr, interrupted}` and NO `gitOperation`, even on real commits (direct and in a script); stdout reaches the hook in clear (`TOKEN=abc123`), so redaction is needed.

Brainstorm answers `[gated 2026-11-03]` (user: "oui" to recommendations 1-8):
1. Host: a new mod `mods/memory/` (it will also host 4c), tool `memory_pending` → `mcp__memory__memory_pending`.
2. Failure = a Bash `isError` result whose text starts `Exit code N`, main loop and sub-agents; excluded: permission refusals (`Permission to use …`, `… haven't granted it yet`), guard redirects (`model-router: …`), `tool_use_error`, and a failure with no error line after `Exit code N`; distinctive line = the last non-empty line after `Exit code N`; deduplicated per session by normalized line.
3. Store: keyed by project root; ≤ 50 failures per session, ≤ 2 KiB per entry, the 3 most recent sessions per project kept (survives /clear), global cap 1 MiB of the 4 MiB `$.store`.
4. Match: index built at call time from backticked spans of BLK and LRN bodies (superseded excluded); known = shares ≥ 1 normalized word 4-gram (digits, paths, hex → placeholders); known entries carry the ID, the rest are "new".
5. Milestones: a successful `git commit` whose message starts `feat` or `fix` (read from the command text), a successful `gitflow.sh finish` except `finish chore`, the same `make test …` command going red then green; one-line note at the next prompt, once per milestone.
6. Redaction: TS pattern set = `KEY=value` for TOKEN|API_KEY|SECRET|PASSWORD|PASSWD, the 7 /guardrails SECRET_PATTERNS, `Bearer` tokens, URLs with `user:pass@`; 40-hex SHAs kept; no gitleaks call.
7. Consumers: /capitalize, /close and CAPITALIZE steps call it first; /commit-change calls it before dispatching commit-changer and passes the result; /hotfix stays silent unless the tool returns a new failure.
8. The tool stays deferred like `route`; skills load it with `ToolSearch` once per session.

## ACCEPTANCE CRITERIA (seed, enriched at STEP 3 `[gated]`)
1. A mod captures failures (scope decided at the brainstorm) as entries {normalized line, verbatim excerpt, command, tool, time}, redacted BEFORE storage, in a bounded store layout decided at the brainstorm (entries per session, bytes per entry, eviction of stale sessions, total under the 4 MiB `$.store` cap).
2. Each captured failure is matched against an error index built from the project's `.claude/memory/` registries (rule decided at the brainstorm); matched ones carry the entry ID, unmatched ones are "new failure modes".
3. Milestones (definitions decided at the brainstorm) are recorded per session.
4. A `memory_pending` tool returns the unmatched failures and the milestones of the current session (shape decided at the brainstorm); it never writes a registry.
5. One context note at the first prompt after a milestone, at most once per milestone, never per turn, never at Stop.
6. /capitalize, /close and the CAPITALIZE steps of feat, bugfix, hotfix, ship-feature and commit-change call `memory_pending` first and feed its output to their candidate scan; the approval gate and `lib/memory.sh` writing are unchanged; every citer patched, doctrine-citers census green.
7. Redaction proven by a test whose oracle does not share the redactor (LRN-237): fixtures carrying secret-shaped strings (allowlisted for gitleaks) come out redacted.
8. The mod fails open on every hook, has the `~/.claude/<name>.json` `"enabled": false` off switch, passes `claude plugin validate --strict` and `claude plugin test` (mods suite green), and `make test` is green.
9. Proof: a failure in session N is visible through `memory_pending` in the same session and survives a /clear as decided; the noise rate measured on real transcripts before shipping (LRN-047).

## FILE SCOPE (seed; final at STEP 3)
- mods/<name>/ (new mod: .claude-plugin/plugin.json, hooks/hooks.json, hooks/register.ts, hooks/register.test.ts), skills/<name> link — or mods/model-router if the brainstorm picks it as host
- skills/capitalize/SKILL.md, skills/close/SKILL.md, skills/{feat,bugfix,hotfix,ship-feature,commit-change}/SKILL.md, agents/commit-changer.md, lib/capitalize-commit.md
- CLAUDE.global.md ("Proactive capitalization", only if the brainstorm changes it), README.md, USAGE.md, CHANGELOG.md, ARCHITECTURE.md
- .claude/tasks/TODO.md, .claude/tasks/plans/ (spike notes), docs/superpowers/{specs,plans} (transient)
