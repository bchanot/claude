---
type: learnings_registry
entry_prefix: LRN
schema:
  id: LRN-XXX
  date: YYYY-MM-DD
  pattern: string (what was observed, abstracted)
  context: string (where/when it happened - concrete)
  future_application: string (when to recall this)
rules:
  - Capture learnings that apply beyond current task.
  - Abstract from incident — pattern reusable, not one-shot fact.
  - Link to source (commit, file, PR) when possible.
  - Replaces previous LESSONS.md format. Old file empty — no content to migrate.
---

# Learnings registry (LRN)

## Index

| ID | Date | Pattern | Applies to |
|----|------|---------|------------|
| LRN-001 | 2026-04-22 | `rtk` shape-compression breaks pipes | any pipeline chaining `rtk curl/cat/read` into `jq`, `python -c`, `awk` |
| LRN-002 | 2026-04-23 | Moving report-file paths requires grepping bash READS, not just WRITES | any refactor that moves a generated file used by a dispatcher |
| LRN-003 | 2026-04-27 | Claude Code `disable*` settings use sentinel string `"disable"`, not boolean | any change to `permissions.defaultMode` or related blocker keys |
| LRN-004 | 2026-04-27 | `framer-motion` rebranded `motion` Nov 2024 — different packages per framework | any new project recommending animation lib; auditing legacy imports |
| LRN-005 | 2026-05-03 | `claude plugin install` does NOT enable — separate `claude plugin enable` required | every plugin installer targeting ALWAYS-ON status |
| LRN-006 | 2026-05-03 | `caveman-shrink` (and any MCP middleware proxy) non-functional without upstream wrapper | any MCP middleware/proxy package — never `claude mcp add` it bare |
| LRN-007 | 2026-05-06 | `toggle-external.sh enable` missed source-only state (3rd lifecycle case) | toggle scripts for tools with separate install + symlink steps |
| LRN-008 | 2026-05-06 | Biggest skill-quality wins from edge-case tables, not workflow rewrites | any skill <85 — first check for FAILURE PATHS / EDGE CASES / ERROR HANDLING section |
| LRN-009 | 2026-05-06 | Dry-run scoring noise wrongly triggers reverts on already-strong skills | darwin-skill ratchet on skills >91 — relax or use real subagent eval |
| LRN-010 | 2026-05-06 | `~/.claude/skills,agents` symlink to Documents/claude — git from `~/.claude` fails | any optimization or batch edit on personal skills/agents |
| LRN-011 | 2026-05-07 | Single subagent emits N independently-gated scores → labeled extraction + axis-aware loop + per-axis escalation | any audit pipeline shipping multiple gated metrics from one subagent |
| LRN-012 | 2026-05-07 | Bash heredoc + stdin pipe collision = silent empty output | any shell pipeline piping data into `python3 - <<'PY' ... PY` (or any heredoc'd interpreter) |

---

## LRN-001 — `rtk` shape-compression silently breaks downstream parsers

- **Date**: 2026-04-22
- **Pattern**: when tracking tool (`rtk`) intercepts stdout and returns schematized/compressed representation instead of raw payload, every downstream parser breaks silently — user (or LLM) never sees `rtk`'s output, only parser error.
- **Context**: `rtk curl` replaces raw JSON output with tokenized version, regardless of TTY vs pipe. Claude Code hooks auto-rewrite `curl` → `rtk curl`, so behavior impossible to anticipate without knowing hook.
- **Future application**: for any tool auto-rewriting standard commands, explicitly verify pipe behavior. Documented workaround: `exclude_commands=["curl"]` in `~/.config/rtk/config.toml`, or `rtk proxy`. See `BLK-001`.

## LRN-002 — Moving report-file paths requires grepping bash READS, not just WRITES

- **Date**: 2026-04-23
- **Pattern**: when moving write path of generated file (report, artifact, cache), must also grep places that READ that file — not only those that write it. Dispatchers (orchestrator skills dispatching to agent then parsing result) typically contain bash commands like `test -s X.md`, `grep ... X.md`, `wc -l X.md` — refs invisible if only grep for "write" or "output path".
- **Context**: `.claude/audits/` refactor (commit `5c5e82c`). First pass: updated write paths across 5 skills (seo/geo/harden/validate/code-clean) and 3 agents. User asked for verify-gate. They re-grepped, found 10+ bare bash refs (e.g. `test -s HARDEN.md`, `grep -oE ... VALIDATE.md`) missed — dispatchers broken (looking at project root while agent writing to `.claude/audits/`). Fixed in commit `5c5e82c` (bundled with same commit).
- **Future application**:
  - Before declaring file-path migration "complete", grep **basename** (`grep -rn "HARDEN\.md"`) plus full path — catch bare bash usages.
  - If file used in pipelines (`test`, `grep`, `wc`, `cat`, `head`), search for those verbs explicitly.
  - **Verify-gates save work**: one extra round forced exhaustive re-grepping. Without it, two dispatchers shipped broken.

## LRN-003 — Claude Code `disable*` settings use sentinel string `"disable"`, not boolean

- **Date**: 2026-04-27
- **Pattern**: Claude Code blocker-style settings (`disableAutoMode`, `disableBypassPermissionsMode`) use literal string `"disable"` as sentinel. Key absent = feature available; value `"disable"` turns blocker on. Any other value (including `false`, `true`, `null`) has no effect — doc explicitly states this.
- **Context**: switching `permissions.defaultMode` to `"auto"` while `disableAutoMode: "disable"` still present would have failed at startup ("auto mode unavailable"). Naming `disable<Foo>: "disable"` reads ambiguously — easy to assume boolean toggle and leave key in place.
- **Future application**:
  - Before changing `defaultMode`, audit matching `disable*` key in same `permissions` block. If present with value `"disable"`, remove it.
  - Same logic for `bypassPermissions` mode and `disableBypassPermissionsMode`.
  - Don't trust doc's naming — read value semantics. Sentinel strings beat booleans here because harness can distinguish "unset" from "explicitly off" (admin policy).
- **Reference**: commit `1421578`, doc `https://code.claude.com/docs/en/settings`.

## LRN-004 — `framer-motion` rebranded `motion` (Nov 2024) — different packages per framework

- **Date**: 2026-04-27
- **Pattern**: `framer-motion` renamed `motion` November 2024. Rename not cosmetic: bundles React (`motion/react`), Svelte, vanilla-JS support under single npm package, while Vue gets own parallel package `motion-v`. Legacy package `framer-motion` still installs and works but in maintenance mode — recommending it in new framework default locks projects into legacy import paths day one. Detection of "is animation already covered" must include both names plus broader anim ecosystem (`gsap`, `lottie-react`, `react-spring`, `popmotion`, `@formkit/auto-animate`) to avoid double-installs.
- **Context**: building animation-lib auto-install in `/init-project` and `/onboard`. Initial user phrasing "framer-motion" (old name remembered). Picking package name without verifying rename would have shipped legacy imports in every new scaffold.
- **Future application**:
  - For React / Next.js / Remix / Astro+React / Svelte: `motion` (`import { motion } from 'motion/react'`).
  - For Vue 3 / Nuxt: `motion-v` (separate package, separate API).
  - For React Native: do NOT recommend `motion` — use `react-native-reanimated` (motion targets DOM).
  - When auditing existing projects, check both `framer-motion` and `motion` keys in `package.json` deps; treat either as "animation already covered".
  - Before adopting any "industry default" lib in framework, verify canonical package name current — naming churn (rebrand, scope change `@org/lib`, fork) common in JS land.
- **Reference**: helper `lib/animation-lib-check.sh`, BDR-005.

## LRN-005 — `claude plugin install` does NOT enable — `claude plugin enable` separate step

- **Date**: 2026-05-03
- **Pattern**: Claude Code CLI splits "available" from "active" for marketplace plugins. `claude plugin install --scope user name@source` only copies plugin into `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. Does NOT write `name@source: true` into user's `settings.json:enabledPlugins` map. Without explicit `claude plugin enable name@source`, plugin sits dormant — installed but unloaded. Symmetric with `claude plugin disable`, which keeps cache and only removes enabledPlugins entry.
- **Context**: discovered auditing why `security-guidance` and `superpowers` were ✘ disabled in `claude plugin list` despite project's `install-plugins.sh` summary banner declaring them "ALWAYS ON". Root cause: `install_plugin()` only ran `claude plugin install`, never `enable`. Bug stayed invisible because hardcoded `printf "│  ✅ ON  : security-guidance rtk superpowers │"` in `session-start.sh` printed same names regardless of actual state — lying banner agreed with lying install.
- **Future application**:
  - For any plugin meant ALWAYS ON, follow `claude plugin install` with `claude plugin enable name@source` (idempotent — no-op if already enabled).
  - Detect "actually enabled" via `enabledPlugins[name@source] === true` in `settings.json`, NOT presence of cache dir. Pattern implemented in `lib/detect-plugins.sh:plugin_enabled()` (filesystem grep, no subprocess).
  - Any banner / status display claiming plugin on must read state, never hardcode names. Hardcoded labels turn single bug into two co-conspiring bugs masking each other.
- **Reference**: commit `2ec7935`, `lib/detect-plugins.sh:plugin_enabled`, `install-plugins.sh:enable_plugin()`.

## LRN-006 — `caveman-shrink` (and any MCP middleware proxy) needs upstream wrapper to function

- **Date**: 2026-05-03
- **Pattern**: some MCP packages are middleware proxies, not standalone servers. They wrap upstream MCP server and transform its responses (e.g. `caveman-shrink` compresses prose fields). Running them bare via `claude mcp add proxy-name -- npx -y proxy-pkg` registers server that errors immediately with "missing upstream command" — every health check fails, and Claude Code reports MCP broken until human intervenes. CLI `claude mcp add` doesn't validate that configured command launches working stdio MCP, so bad registration silently lands.
- **Context**: when adding caveman, upstream installer auto-registers `claude mcp add caveman-shrink -- npx -y caveman-shrink` and prints "registered. wrap an upstream by editing the mcpServers entry". Following that flow leaves user with permanently failing MCP entry until they realize they must edit `~/.claude.json` manually.
- **Future application**:
  - For any MCP that is proxy/middleware (read package docs for "upstream", "wraps", "proxy"), register under DERIVED name `<proxy>-<upstream>` with upstream baked into args. Example for caveman-shrink wrapping filesystem server:
    ```
    claude mcp add caveman-shrink-fs --scope user -- \
      npx -y caveman-shrink npx -y @modelcontextprotocol/server-filesystem /path
    ```
  - Detection of "is this MCP correctly set up?" must look for the derived name (`caveman-shrink-*`), not the bare proxy name. Bare-name registration is treated as broken.
  - Default install scripts should NOT auto-register middleware MCPs — print the snippet for the user to choose an upstream. See `install-plugins.sh` STEP 5.5.
- **Reference**: commit `9b20b84`, `lib/detect-plugins.sh:detect_caveman_shrink`, `install-plugins.sh` STEP 5.5 MCP block.

## LRN-007 — `toggle-external.sh enable` missed source-only state

- **Date**: 2026-05-06
- **Pattern**: `lib/toggle-external.sh enable <tool>` for npx/external skills (`darwin-skill`, `find-skills`, `emil-design-eng`) handled 2 states only: symlink in `skills-disabled/` → move to `skills/`, or symlink in `skills/` → already enabled. Missed 3rd: source dir at `~/.agents/skills/<tool>` but no symlink. First-run after `make plugin` lands here until `bash link.sh` runs. `enable` errored `not installed — run: make plugin` — misleading, plugin already installed.
- **Context**: user ran `./lib/toggle-external.sh enable darwin-skill` after fresh install. `~/.agents/skills/darwin-skill/` populated by `install-plugins.sh` STEP 8.5 npx call, but `link.sh` (separate step) not run, so `skills/darwin-skill` symlink never created. Fix `lib/toggle-external.sh:161-179` — add `elif [ -d "$src" ]` branch creating symlink direct when source dir present. Error message now show resolved source path.
- **Future application**:
  - Any toggle script for tools with separate install + symlink steps must check 3 states: disabled-dir, enabled-dir, source-only. Source-only branch create symlink in place, not fail.
  - Error messages name path checked, not abstract tool name — caller verify install vs symlink state without rereading script.
  - Symmetric pairs (`enable`/`disable`) both handle same lifecycle states; missing state in one half = silent dead end.
- **Reference**: `lib/toggle-external.sh:161-179`, `link.sh:69-83`, `install-plugins.sh:598-633` STEP 8.5.

## LRN-008 — biggest skill-quality wins come from edge-case tables, not workflow rewrites

- **Date**: 2026-05-06
- **Pattern**: darwin-skill round 1 across 18 personal skills. Top 4 gains (analyze +18.5, skills-perso +11.9, refactor +11.0, hotfix +9.0) all from same shape: add 1-page failure-mode table (file-not-found, malformed input, partial state, denied user input) with concrete action per row. Skills already had clean happy-path workflows; D3 (edge cases) was systemic gap.
- **Context**: most personal skills delegate to single agent file. Workflow steps already explicit. Missing: explicit "what when X unexpected" rows. Adding 5-12 row table with `| situation | action |` shape moved D3 from 3-7 → 9-10 and total +5 to +18.
- **Future application**:
  - Skill scoring <85: first inspect agent file for EDGE CASES / FAILURE PATHS / ERROR HANDLING section. Absence = strong predictor of D3 weakness.
  - Template: rows for `target not found`, `input malformed`, `tool/API timeout`, `user denies action`, `partial output`, `permission denied`. Map each → fallback / retry / ask-user / fail-fast.
  - Costs ~15-50 lines, unlocks +5 to +15 score.
- **Reference**: `.claude/audits/DARWIN-SKILL-OPTIMIZATION.md`, commits `649351b`, `eb34627`, `1768d04`, `ef87074`, `a3f28d5`.

## LRN-009 — dry-run scoring noise wrongly triggers reverts on already-strong skills

- **Date**: 2026-05-06
- **Pattern**: darwin-skill ratchet rule = revert if new < old. Dry_run scoring (subagent reads SKILL.md, mentally simulates, scores 8 dims) has ±1pt noise per dim per re-eval. Skill at 91-94 has small headroom, so single noisy -1 on D2 flips total from +1 to -1 (false revert). code-clean + doc both reverted with objectively useful content (empty-approval branch, README/DEPLOY templates) — revert was dry_run noise artifact, not real regression.
- **Context**: ratchet preserves only commits with strict total > old. For dry_run near ceiling, too strict. Real subagent eval would have lower noise floor since output quality differences observable.
- **Future application**:
  - Skills baseline >91: skip optimization (diminishing returns), OR use real subagent eval not dry_run, OR relax ratchet to "new ≥ old - 1" with manual diff review.
  - Edits to high-scoring skills must be minimal (1-3 lines, surgical) so D2 (workflow clarity) not perturbed by added bulk.
  - When reverting content-rich change, log content elsewhere (`~/.claude/notes/`) so work not lost — second smaller patch can reintroduce idea.
- **Reference**: `.claude/audits/DARWIN-SKILL-OPTIMIZATION.md`, commits `63e08f9`→`822d437` revert (code-clean), `c7b8522`→`765d1c1` revert (doc).

## LRN-010 — ~/.claude/skills + ~/.claude/agents symlink to /home/bchanot-ubuntu/Documents/claude

- **Date**: 2026-05-06
- **Pattern**: editing `~/.claude/skills/<x>/SKILL.md` or `~/.claude/agents/<x>.md` modifies file at `/home/bchanot-ubuntu/Documents/claude/{skills,agents}/`. `~/.claude` is empty config dir with symlinks; actual git repo + working tree is in Documents/claude. `git add` from `~/.claude` fails with `pathspec is beyond a symbolic link`. Must operate git from Documents/claude.
- **Context**: darwin-skill run created branch in `~/.claude` first (separate git repo, mostly empty). Real branch with skill changes had to be created in Documents/claude. Two repos, two branches.
- **Future application**:
  - Any optimization or batch edit on personal skills/agents operates from `/home/bchanot-ubuntu/Documents/claude` for git to track changes.
  - `readlink ~/.claude/skills` + `readlink ~/.claude/agents` first if unsure. Both point to Documents/claude/{skills,agents}.
  - Don't waste branch in `~/.claude` — nothing to track for skill content.
- **Reference**: `.claude/audits/DARWIN-SKILL-OPTIMIZATION.md`, branch `auto-optimize/skills-20260506-1730` in Documents/claude.

## LRN-011 — Single subagent emits N independently-gated scores: pattern

- **Date**: 2026-05-07
- **Pattern**: when one subagent produces 2+ scores that each must clear independent thresholds (e.g. `/seo` subagent → SEO classique + GEO scores in same `SEO.md`), orchestrator must:
  1. Extract each score via labeled grep (`extract_score_labeled f "Score SEO" + "Score GEO"`) — never fall back to "first /20 found" (collapses scores or fakes duplicate).
  2. Loop continuation: `while (any axis < threshold) AND iter ≤ MAX`. Single-axis condition exits early while other axis still below.
  3. Re-dispatch prompt labels each axis with current score + PASS/FAIL state, plus axis-specific fix list. Generic "improve the audit" wastes iterations on already-passing axis.
  4. Escalation prompt names affected axes explicitly. User chooses per-axis (continue / stop / override per axis).
  5. Override transparency file lists axes separately (e.g. `SEO classique: NOT overridden, GEO (IA): overridden`).
  6. Backward compat: `allow_fallback` flag — fall back to generic single-score parse for primary axis (legacy compat) but NOT for secondary axis (UNKNOWN forces re-dispatch with explicit format demand).
- **Context**: client-handover pipeline gates SEO + GEO independently (BDR-010). Both scores live in same `.claude/audits/SEO.md`, written by one /seo subagent in one dispatch. Naive "extract first /20" collapsed both into SEO classique value — gate fired on SEO only. Pattern above generalizes to any future audit shipping multiple gated metrics from one subagent (e.g. /harden could split TLS + headers + redirects).
- **Future application**:
  - Any audit subagent emitting multiple scores → use labeled extractor pattern + axis-aware loop + per-axis escalation. Never collapse to single score for gate.
  - When designing new audits with multiple metrics, mandate labeled score format in skill SKILL.md (e.g. `Score <axis> : X.X / 20`). Avoids retrofit later.
  - When 2+ scores share one subagent, prompt template lists both PASS/FAIL state + axis-specific fix categories. Otherwise subagent wastes iterations on passing axis.
- **Reference**: `agents/client-handover-writer.md` (`extract_score_labeled` STEP 3, axis-aware loop STEP 4, escalation STEP 4, threshold strictness STEP 8 SEO.md branch). BDR-010.

## LRN-012 — Bash heredoc + stdin pipe collision = silent empty output

- **Date**: 2026-05-07
- **Pattern**: when running an inline-heredoc'd interpreter — `python3 - <<'PY' ... PY`, `bash <<'SH' ... SH`, `node -e <<'JS' ... JS` etc. — the heredoc IS the interpreter's stdin. Any data piped from upstream is **silently discarded**. Symptom: `sys.stdin.read()` (or equivalent) returns the heredoc body itself (often empty after the script consumes it via the read), and the produced output is empty. Exit code is `0`, no error message — silent failure. Diagnose via `bash -x` trace: you see the python ran, but no upstream data ever reached it.
  - Anti-pattern (broken): `printf '%s' "$DATA" | python3 - <<'PY' \n template = sys.stdin.read() \n ... \n PY`
  - Fix 1 (env var): `DATA="$DATA" python3 - <<'PY' \n import os; template = os.environ['DATA'] \n PY`
  - Fix 2 (file path arg): `python3 - "$FILE_PATH" <<'PY' \n import sys; template = open(sys.argv[1]).read() \n PY` — note `"$FILE_PATH"` AFTER `-` becomes `sys.argv[1]`.
  - Fix 3 (write tempfile, read inside): `echo "$DATA" > /tmp/x; FILE=/tmp/x python3 - <<'PY' \n template = open(os.environ['FILE']).read() \n PY`.
- **Context**: `skills/client-handover/scripts/handover-to-pdf.sh` v1 piped HTML template through a `substitute()` function that ran `python3 - <<'PY'` and read `sys.stdin`. Pipe dropped silently, `.html` output 0 bytes. Caught by post-write `wc -l`; root cause found via `bash -x`. Fixed by passing template path through `HQ_TEMPLATE_PATH` env var, python opens the file directly (`render_template()` in current script).
- **Future application**:
  - Never combine an inline heredoc with an upstream pipe targeting the same interpreter. Pick one input channel: heredoc OR pipe, not both.
  - When in doubt: pass data via env vars (small payloads), file paths (large payloads), or argv. Reserve stdin for cases where the interpreter has NO heredoc.
  - Add post-write size check (`test -s "$FILE"` or `wc -l`) for any generated artifact in a shell pipeline — surfaces silent-failure modes immediately.
  - When debugging "script ran but file empty", run `bash -x script.sh` and look for the `+ python3 -` line — if you see no upstream data being consumed, you have the heredoc-pipe collision.
- **Reference**: `skills/client-handover/scripts/handover-to-pdf.sh` `render_template()` (env-var-based, current); BDR-011 caveat list; commit `e06b52a` (final fix shipped with the renderer).
---

## LRN-013 — marked CLI 16.x ignore stdin, dump own cli.js source

- **Date**: 2026-05-07
- **Context**: `/client-handover` PDF rendering. `handover-to-pdf.sh` fallback chain pandoc → python-markdown → npx marked. On host with only npx, pipeline ran `npx --yes marked < "$src"` and produced 2-page PDF where body = marked package's `cli.js` source (`#!/usr/bin/env node`, `Marked CLI`, copyright, `import { main } from './main.js'`). Real MD content (30 KB) entirely lost.
- **Pattern**: marked 16.x CLI regression — stdin path broken, ignores piped input, prints its own binary source. Only `-i FILE` flag works. Verified: `echo "test" | npx marked` → marked source. `npx marked -i FILE` → correct HTML.
- **Why**: do not assume marked CLI accepts stdin like awk/jq/sed. Check actual conversion output before shipping any MD→HTML renderer.
- **How to apply**: any shell md→html using marked CLI must call `npx --yes marked --gfm -i "$src"`. Keep pandoc + python-markdown ahead in fallback chain — more stable. Smoke-test: render small MD, grep output for known content; fail loudly if mismatch.
- **Reference**: `skills/client-handover/scripts/handover-to-pdf.sh` line ~140 (npx fallback fixed). Commit fixing bug.
