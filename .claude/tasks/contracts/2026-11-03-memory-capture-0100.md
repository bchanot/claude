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
2-amended `[gated 2026-11-04]` (noise gate, plan Task 7 step 3; user: option A): the distinctive line must hold an error-shaped word, matched case-insensitive on the redacted line by `error|fatal|cannot|can't|no such|not found|denied|failed|failure|unexpected|invalid|exception|traceback|panic|usage:|SC\d{4}|> \d+|assert`; a line without one is no line and the failure is dropped (same treatment as a letterless line). Measured on 14 days of transcripts (NOISE.md): 83 % noise on the shipped rule, every useful sample kept by the filter, 81 → 27 captures. Options B (no sub-agent capture) and C (ship as is) declined.
6-amended `[gated 2026-11-04]` (final review I2; user: "corriger les trois"): the KEY=value name class admits digits (`OAUTH2_CLIENT_SECRET=`, `S3_SECRET=`, `TOKEN_V2=` redacted); a JWT (`eyJ…`.`eyJ…`.`sig`, three base64url parts) → `<redacted:jwt>`; `-u user:pass` / `--user user:pass`, `--password value` / `--password=value`, and `Authorization: (Basic|Bearer|token) value` → redacted. Oracles literal; secret-shaped fixtures built at runtime.
4-amended `[gated 2026-11-04]` (final review I1, GATE 1 observation; user: "oui, les trois"): a 4-gram whose four words are all placeholders (`#`, `<path>`, `<hex>`) indexes nothing and matches nothing (on this repo's registries `# # # #` indexed LRN-074, so every IP:port or timestamp read known).
6-bis `[gated 2026-11-04]` (GATE 2 MEDIUM redaction-coverage; user: "ajouter ces formes"): vendor prefixes `sk-ant-`, `sk-proj-`, `github_pat_`, `glpat-`, `AIza`, `npm_` → `<redacted:kind>`; `--(token|api-key|secret)[ =]value` → `--<flag> <redacted>`; headers `X-Api-Key:`, `PRIVATE-TOKEN:`, `Cookie:` → `<header>: <redacted>`; JSON/YAML `"(password|token|secret|api_key)"\s*:\s*"…"` and `(password|token|secret|api_key)\s*[:=]\s*value` (spaces admitted, so `aws_secret_access_key = …` is caught) → `<key>: <redacted>`; a 40-hex token as URL user (`scheme://<hex>@host`) → `scheme://<redacted>@host` (bare 40-hex SHAs elsewhere stay). All bounded, measured on 64 KiB, literal oracles, runtime-built fixtures.
7-amended `[gated 2026-11-04]` (GATE 1 observation; user: "oui, les trois"): `init-project` STEP 10b (founding decisions of a new project) is excluded from the consumers by nature; the REQUEST's "every CAPITALIZE step" means the session-level steps listed in answer 7.

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

STEP 3 gate `[gated 2026-11-04]` (user: "oui aux deux, lance"): plan r3 (`docs/superpowers/plans/2026-11-03-memory-capture.md`, f2daf76, § R2 and § R3 override the task text) approved; the build-time off switch `~/.claude/memory.json` `{"enabled": false}` approved (written by the controller before Task 1, moved away before Task 9).

10. `[gated 2026-11-04]` Mod tests: `mods/memory/hooks/register.test.ts` holds the plan's named tests (TOFF, TFAIL, the redaction set, CAP1-CAP10, ID1, ID2, RACE1, TIME1, IDX1-IDX8, MS1-MS6, NT1-NT4) and the mods suite is green; `mods/memory/hooks/register.ts` holds no line over 80 columns.
   CHECK: cd /home/bchanot/Documents/claude && T=mods/memory/hooks/register.test.ts && for n in TOFF TFAIL CAP1 CAP3 CAP8 CAP10 ID1 ID2 RACE1 TIME1 IDX1 IDX3 IDX8 MS1 MS3 MS4 MS5 NT1 NT3; do /usr/bin/grep -q "$n" "$T" || exit 1; done && [ "$(awk 'length($0) > 80' mods/memory/hooks/register.ts | wc -l)" = 0 ] && a=$(make test suite=lib/tests/mods.test.sh 2>&1) && printf '%s\n' "$a" | /usr/bin/grep -q 'all suites green' && echo MOD-OK
   EXPECT: MOD-OK
   EVIDENCE: MET exit=0 marker-found :: MOD-OK
11. `[gated 2026-11-04]` Mod layout: manifest name `memory`, `hooks/hooks.json` modules `./register.ts`, tracked link `skills/memory -> ../mods/memory`; the tool name in code is `memory_pending` and the served name `mcp__memory__memory_pending`.
   CHECK: cd /home/bchanot/Documents/claude && jq -e '.name == "memory"' mods/memory/.claude-plugin/plugin.json >/dev/null && [ "$(readlink skills/memory)" = "../mods/memory" ] && git ls-files --error-unmatch skills/memory >/dev/null 2>&1 && /usr/bin/grep -q "mcp__memory__memory_pending" mods/memory/hooks/register.ts && echo LAYOUT-OK
   EXPECT: LAYOUT-OK
   EVIDENCE: MET exit=0 marker-found :: LAYOUT-OK
12. `[gated 2026-11-04]` Consumers: capitalize carries the bold label `**Captured first.**`; feat, bugfix, ship-feature, hotfix and commit-change name `memory_pending`; agents/commit-changer.md names the captured block and the heredoc channel.
   CHECK: cd /home/bchanot/Documents/claude && /usr/bin/grep -q '\*\*Captured first\.\*\*' skills/capitalize/SKILL.md && for f in feat bugfix ship-feature hotfix commit-change; do /usr/bin/grep -q 'memory_pending' "skills/$f/SKILL.md" || exit 1; done && /usr/bin/grep -q 'MEMCAP_EOF' agents/commit-changer.md && echo CONSUMERS-OK
   EXPECT: CONSUMERS-OK
   EVIDENCE: MET exit=0 marker-found :: CONSUMERS-OK
13. `[gated 2026-11-04]` Noise measured: `.claude/tasks/plans/2026-11-03-memory-capture-spike/NOISE.md` holds main-loop and sub-agent counts and the noise share, and no captured sample line (no `excerpt`, no `command:` lines).
   CHECK: cd /home/bchanot/Documents/claude/.claude/tasks/plans/2026-11-03-memory-capture-spike && [ -s NOISE.md ] && /usr/bin/grep -qi 'sub-agent' NOISE.md && /usr/bin/grep -qi 'noise' NOISE.md && ! /usr/bin/grep -qiE '^\s*-?\s*(excerpt|command):' NOISE.md && echo NOISE-OK
   EXPECT: NOISE-OK
   EVIDENCE: MET exit=0 marker-found :: NOISE-OK
14. `[gated 2026-11-04]` Whole branch: `make test` all suites green and shellcheck clean on the health stack; settings.json untouched by the branch.
   CHECK: cd /home/bchanot/Documents/claude && t=$(make test 2>&1) && printf '%s\n' "$t" | /usr/bin/grep -q 'all suites green' && shellcheck ./*.sh hooks/*.sh lib/*.sh && [ -z "$(git diff develop...HEAD --stat -- settings.json)" ] && echo BRANCH-OK
   EXPECT: BRANCH-OK
   EVIDENCE: MET exit=0 marker-found :: BRANCH-OK
15. `[gated 2026-11-04]` Error-shaped line filter (answer 2-amended): `register.ts` holds the `ERRORISH` pattern, `register.test.ts` holds `CAP11` (an `Exit code 1` whose last line is `rc=0` stores nothing; `ls: cannot access` and `unexpected EOF while looking for matching` lines are stored), the mods suite is green.
   CHECK: cd /home/bchanot/Documents/claude && /usr/bin/grep -q 'ERRORISH' mods/memory/hooks/register.ts && /usr/bin/grep -q 'CAP11' mods/memory/hooks/register.test.ts && a=$(make test suite=lib/tests/mods.test.sh 2>&1) && printf '%s\n' "$a" | /usr/bin/grep -q 'all suites green' && echo ERRORISH-OK
   EXPECT: ERRORISH-OK
   EVIDENCE: MET exit=0 marker-found :: ERRORISH-OK

## FILE SCOPE (final, STEP 3 `[gated 2026-11-04]`)
- mods/<name>/ (new mod: .claude-plugin/plugin.json, hooks/hooks.json, hooks/register.ts, hooks/register.test.ts), skills/<name> link — or mods/model-router if the brainstorm picks it as host
- skills/capitalize/SKILL.md, skills/close/SKILL.md, skills/{feat,bugfix,hotfix,ship-feature,commit-change}/SKILL.md, agents/commit-changer.md (§ Capitalize candidates, one line), lib/capitalize-commit.md (unchanged unless a citer needs it)
- CLAUDE.global.md ("Proactive capitalization", only if the brainstorm changes it), README.md, USAGE.md, CHANGELOG.md, ARCHITECTURE.md
- .claude/tasks/TODO.md, .claude/tasks/plans/ (spike notes), docs/superpowers/{specs,plans} (transient)
- `[gated 2026-11-04]` (GATE 1 micro-gate; user: "oui, les trois"): this contract file (committed per lib/contract-interview.md § Commit) and `.claude/memory/journal.md` (phase-3 close memory commit 60f28a6 landed on the branch; a `.claude/**` memory commit, BDR-068 class)
- `[gated 2026-11-04]` (STEP 7 capitalize, memory commit 08e36dc per lib/capitalize-commit.md): `.claude/memory/{decisions,learnings,blockers,evals}.md` (BDR-137, LRN-258..261, BLK-041, EVAL-057), same class; gated with the merge go
## PROOF (Task 9)
- Step 0 (2026-11-04, user go): `~/.claude/memory.json` moved to `$CLAUDE_JOB_DIR/tmp/memory.json.off`; capture is on from the next session.
- Step 1 headless (2026-11-04 12:08, `claude -p --model haiku`, live user settings, mod `memory@skills-dir`, scratch repo `$CLAUDE_JOB_DIR/tmp/proof9/repo.gYdo` on `feature/probe`, `GITFLOW_NO_PUSH=1`, fixture `.claude/memory/blockers.md` with one unrelated BLK): four tool calls as scripted (ToolSearch select, `ls /nonexistent-dir-xyz`, `git commit --allow-empty -m "fix: probe"`, `mcp__memory__memory_pending {}`), rc 0, cost $0.011. Answer: `memory_pending (project repo.gYdo, 1 session(s))` / `index: read blockers.md; skipped learnings.md (missing)` / `milestones (this session): - commit fix: probe (12:08)` (UTC at the time; local time after final review M5) / `failures: - NEW ×1 ls: cannot access '/nonexistent-dir-xyz': No such file or directory — command: ls /nonexistent-dir-xyz` + excerpt. Log: `$CLAUDE_JOB_DIR/tmp/proof9/out.jsonl`. The run leaves a `p:<tmp path>` key (one session, ~1 KiB) in the real store; the 1 MiB sweep drops it only when the store is over the cap (final review M10 corrected R3 conf 12), harmless.
- Step 3 interactive (user + model, R3 conf 5): pending — in a scratch repo on a feature branch the model runs `git commit --allow-empty -m "fix: probe"`, the user sends two composer prompts, the transcript grep expects exactly one `memory: commit fix: probe` on the first; then `/clear` and a `memory_pending` call lists the probe session `(earlier session)`.

