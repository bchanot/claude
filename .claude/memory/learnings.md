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
| LRN-021 | 2026-05-20 | Refactor commands→skills must sweep `~/.claude/commands/` for orphan wrappers | any refactor moving `agents/foo.md` → `skills/foo/SKILL.md`; onboard/init-project audits |
| LRN-009 | 2026-05-06 | Dry-run scoring noise wrongly triggers reverts on already-strong skills | darwin-skill ratchet on skills >91 — relax or use real subagent eval |
| LRN-010 | 2026-05-06 | `~/.claude/skills,agents` symlink to Documents/claude — git from `~/.claude` fails | any optimization or batch edit on personal skills/agents |
| LRN-011 | 2026-05-07 | Single subagent emits N independently-gated scores → labeled extraction + axis-aware loop + per-axis escalation | any audit pipeline shipping multiple gated metrics from one subagent |
| LRN-012 | 2026-05-07 | Bash heredoc + stdin pipe collision = silent empty output | any shell pipeline piping data into `python3 - <<'PY' ... PY` (or any heredoc'd interpreter) |
| LRN-013 | 2026-05-07 | marked CLI 16.x ignore stdin, dump own cli.js source | any shell MD→HTML via npx marked — use `-i FILE` not stdin |
| LRN-014 | 2026-05-11 | Pandoc base gfm strips header id attrs — need `gfm+gfm_auto_identifiers` | any MD→HTML/PDF with cross-references (`[§4](#nap)`) via pandoc |
| LRN-015 | 2026-05-11 | BrightLocal Free Tools retired 2026 — Moz Local Citation Checker is free replacement | client SEO/NAP docs — re-validate tool URLs + free-tier status annually |
| LRN-016 | 2026-05-11 | Pandoc GFM checkbox markup breaks adjacent-sibling CSS — target `li > input` directly | styling task-list checkboxes in pandoc-rendered HTML/PDF |
| LRN-017 | 2026-05-12 | Thin-dispatcher SKILL.md round-1 win = fallback + frontmatter triggers (+15 to +30) | any `/darwin-skill` round-1 on a dispatcher SKILL.md |
| LRN-018 | 2026-05-12 | Darwin eval subagents drift on total math — recompute in main thread | any subagent-driven SKILL.md rescore |
| LRN-019 | 2026-05-15 | Deployable-project doc split: README dev-quickstart + DEPLOY 14-section prod-VPS topology | any onboard/doc-syncer/scaffold producing docs for a deployable project |
| LRN-024 | 2026-06-02 | New sibling command sharing logic → extract helper + refactor existing caller, never copy-paste; assert pre/post state equality | adding a subcommand/branch reusing logic inline in a peer command |
| LRN-025 | 2026-06-02 | `.gitignore` gstack allowlist must cover ALL toggleable skills (incl. parked) — else enabling one = untracked git noise | any toggle that moves local-symlink skills into a tracked dir; post-submodule-bump reconcile |
| LRN-026 | 2026-06-09 | `disable-model-invocation: false` = ENABLED not blocking; only `true` blocks (model + orchestrator); binary, no per-caller | Claude Code skill frontmatter; deciding self-route/chain vs human-only entry point |
| LRN-027 | 2026-06-11 | Agents improvise audit boundaries from file dates when no machine state — periodic skills need machine-readable state file, never inference | any recurring/periodic skill needing "since last run" semantics |
| LRN-030 | 2026-06-18 | Opus 4.8 under-delegates subagents/memory/custom-tools by default — counter via explicit CLAUDE.md fan-out rule | any Opus 4.8 session; tuning delegation; inline-vs-subagent decision |
| LRN-031 | 2026-06-19 | Skill value = gate + anti-noise + determinism, not re-coding what a capable agent does free | building/reviewing any skill; writing-skills TDD fixture design |

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

---

## LRN-014 — Pandoc base gfm strips header id attrs — need gfm+gfm_auto_identifiers

- **Date**: 2026-05-11
- **Pattern**: `pandoc --from=gfm --to=html5` does NOT auto-generate `id` attributes on header elements. Internal anchor links like `[§4 NAP](#nap)` become dead refs in rendered HTML/PDF. Symptom: rendered doc has `<h2>NAP</h2>` (no `id`), browser/PDF anchor resolves nowhere, user clicks link and goes nowhere. Enable id auto-gen by switching to `--from=gfm+gfm_auto_identifiers` — pandoc then emits `<h2 id="nap">NAP</h2>` (kebab-case slug from header text).
- **Context**: `skills/client-handover/scripts/handover-to-pdf.sh` MD→HTML cascade. 6-chapter handover doc added internal cross-references between chapters (§5 todo references back to §4 NAP table for values). Default `--from=gfm` produced HTML with no header ids — internal links dead. Discovered after rendering test handover, clicking link in PDF, going to top of doc instead of NAP section.
- **Future application**:
  - Any pandoc MD→HTML pipeline with `[text](#anchor)` cross-references → enable `gfm_auto_identifiers` extension explicitly.
  - Smoke-test internal anchors before shipping any renderer: render → `grep -E 'id="[^"]+"' out.html` → confirm headers have ids.
  - Slug rules: pandoc lowercases + replaces non-alpha with `-`, e.g. `## §4 NAP table` → `id="ss-4-nap-table"`. If you control header text, keep slugs predictable.
- **Reference**: `skills/client-handover/scripts/handover-to-pdf.sh` line 121 (`--from=gfm+gfm_auto_identifiers`). Commit `b15b275`.

---

## LRN-015 — BrightLocal Free Tools retired 2026, Moz Local Citation Checker is free replacement

- **Date**: 2026-05-11
- **Pattern**: SEO/NAP tool landscape churns yearly. BrightLocal Free Tools page (`brightlocal.com/free-local-tools/`) retired in 2026 — service now paid-only. Moz Local Citation Checker (`moz.com/local`, "Check My Listing" / "Get Free Audit") is current free replacement: 60s NAP-consistency audit across 50+ directories (Google Business, Apple Maps, Yelp, Pages Jaunes, Bing Places), no credit card required.
- **Context**: client-handover NAP checklist (FR + EN versions) recommended brightlocal.com free tools — link dead, page redirects to paid tier. Caught during handover-doc render. Swapped both language versions to Moz Local with explicit "no credit card" note + path through homepage (button labels can change, URL `moz.com/local` is stable).
- **Future application**:
  - Any client-facing doc recommending "free SEO/NAP tools" → verify URLs alive + tool still free annually. SEO vendors churn free tiers regularly.
  - Prefer linking to vendor homepage + naming the button ("click Check My Listing") over deep links to specific tool URLs. Vendor URLs deprecate; homepages persist.
  - Maintain a short list of "verified-recent" free tools in the handover skill rather than rediscovering on each render.
- **Reference**: `skills/client-handover/checklists/seo-geo-manual.md` (FR section line ~218, EN section line ~429). Commit `abd2612`.

---

## LRN-016 — Pandoc GFM checkbox markup breaks adjacent-sibling CSS — target `li > input` directly

- **Date**: 2026-05-11
- **Pattern**: pandoc GFM emits task-list checkboxes as `<li><input disabled type="checkbox"> text…</li>` with **no wrapper class** and **no list-item class**. Adjacent-sibling CSS rule `li input[type="checkbox"] + *` absolutely-positions the first element sibling AFTER the input — typically `<a>`, `<code>`, `<strong>`, or `<em>` inside the bullet text. Effect: that inline element gets yanked out of flow, overlaps adjacent content in rendered PDF. Symptom: PDF has links/code-spans visibly overlapping subsequent text.
- **Context**: `skills/client-handover/resources/branding/zenquality.css` task-list styling. Initial rule tried to render custom checkbox box via `+ *` selector targeting the first sibling after `<input>`. Worked when bullet was plain text (no inline elements), broke when bullet contained `<a href="...">` or `<code>…</code>` — those got absolutely-positioned. Caught in rendered LIVRAISON.pdf — checkbox icons OK but link/code text overlapped neighbors.
- **Future application**:
  - For pandoc GFM checkbox styling, target `li > input[type="checkbox"]` directly. Style native `<input>` via `appearance: none` + custom box rendering (background, border, size) on the input itself.
  - Avoid `+ *` and other sibling-selector tricks on bare-input markup — pandoc gives no wrapper to anchor to, siblings vary per bullet content.
  - Render checklist with realistic content (`<a>`, `<code>`, `<strong>`) before signing off — bare text bullets won't surface the bug.
  - Symptom signature: rendered PDF has overlapping inline elements ONLY in task lists — points to a sibling-selector rule firing on inline content.
- **Reference**: `skills/client-handover/resources/branding/zenquality.css` `li > input[type="checkbox"]` rule + `li.task-list-item::before` (lines 372–410). Commit `465fe9e`.

---

## LRN-017 — Thin-dispatcher SKILL.md round-1 win = fallback + frontmatter triggers (+15 to +30)

- **Date**: 2026-05-12
- **Pattern**: thin-dispatcher SKILL.md (delegates to `agents/<x>.md`, body 15-30 lines, no inline workflow) scores low on darwin rubric (45-70) because dims D2/D3/D4/D5 punish empty body. Round-1 universal fix:
  1. Add fallback clause — `If $HOME/.claude/agents/<x>.md unreachable, emit "<X> agent missing." and STOP. Never improvise — silent behavior change is unsafe.`
  2. Add triggers to frontmatter `description` — explicit `Triggers: "<keyword>", "<synonym>", "<i18n variant>".`
  3. For destructive skills (refactor, commit-change): add safety rationale + pre-flight check stub.
  Δ +13 to +31 observed: status 45.3→76.2 (+30.9), refactor 48.4→74.3 (+25.9), plugin-check 59.2→76.8 (+17.6), commit-change 69.6→83.5 (+13.9). 150% byte cap tight — trim aggressively.
- **Context**: `/darwin-skill` run 2026-05-12, branch `auto-optimize/20260512-1319` merged to master, 5 commits. skills-perso (66.4→80.1, +13.7) NOT a dispatcher — different patch (Known-limits subsection on the heuristic).
- **Future application**:
  - Any darwin round-1 on a dispatcher SKILL.md → skip diagnosis, apply this template directly. Saves one eval cycle.
  - After round 1, gains flatten near 75-80 → pivot to next-lowest skill, do not grind rounds 2-3 on same target.
  - For thin originals (<500B), 150% cap is the binding constraint — pre-trim drafts before committing.
- **Reference**: `.claude/audits/DARWIN-SKILL-2026-05-12.md`. Commits `512df48`..`134561d`. results.tsv at `~/.agents/skills/darwin-skill/results.tsv`.

---

## LRN-018 — Darwin eval subagents drift on total math — recompute in main thread

- **Date**: 2026-05-12
- **Pattern**: analyzer subagents asked to score SKILL.md and compute weighted total drift on the formula. Two recurring errors: (a) divide `Σ(dim×weight)` by `100` instead of `10` (off by factor 10 — produces 6.17 instead of 61.7, then sometimes the subagent silently re-multiplies); (b) use D8 weight 7 instead of the spec value 25 (status: spec says D8 weight = 25, easy to confuse with D4 weight = 7). Per-dim judgments themselves stable across runs; computed totals unreliable.
- **Context**: 5 round-1 evals during darwin 2026-05-12. Refactor subagent computed 743÷10 correctly in scratch but wrote `617/100 = 61.7` — actual correct total 74.3. Subsequent prompts explicitly stating "D8 weight is 25" cleared the second error.
- **Future application**:
  - Prompt subagent for dim scores only, not weighted total. Main thread computes `Σ(dim_i × weight_i) / 10` deterministically.
  - If subagent must compute, include weight table in prompt AND show example computation for one row.
  - When comparing baseline vs round-N, use main-thread recomputed totals on BOTH sides, not the two subagents' self-reported numbers.
  - Score recalibration between baseline subagent and round-1 subagent is real (independent re-anchoring) — first-round Δ tends to overstate improvement. Direction reliable, magnitude noisy.
- **Reference**: see "Methodology notes" section of `.claude/audits/DARWIN-SKILL-2026-05-12.md`.

---

## LRN-019 — Deployable-project doc split: README dev, DEPLOY prod-VPS 14 sections

- **Date**: 2026-05-15
- **Pattern**: deployable project → split docs by audience, not by topic. README = dev + features audience (one-line pitch, Features, Stack, Quick start (dev), Verifying a change, Build & deploy summary, Documentation cross-links, License). DEPLOY.md = ops/SRE audience, prod-only, 14 sections mirroring real VPS-deploy shape (topology table, env vars, VPS provisioning, two-layer firewall = cloud security group + UFW, Docker tuning = log caps + `live-restore`, first-time setup, routine deploys, persistence/volumes, backups + cron + retention, TLS = Caddy/nginx + ACME, observability = logs + healthchecks, hardening = SSH keys-only + fail2ban + unattended-upgrades, rollback, runbook). Dev quick-start NEVER in DEPLOY.md — mixed dev/prod = drift source. Trivial deploy (no Docker, no compose, no fly.toml, no k8s, no scripts/deploy.*) → fold into README, skip DEPLOY.md.
- **Context**: applied 2026-05-15 in `agents/doc-syncer.md` STEP 5/6 rewrite. Generalizes README-vs-DEPLOY ownership drift seen across multi-maintainer repos (devs read one doc, ops read another, both edit independently, conflicts pile up). 14-section template comes from real Scaleway DEV1-S walkthrough — shape works on any provider (Scaleway, Hetzner, OVH, DO, Vultr, plain bare-metal).
- **Future application**:
  - Any `/onboard` / `/doc` / `/init-project` producing docs for a deployable project → apply the split directly. Don't ask user "where should dev setup go" — README, always.
  - Existing repo has DEPLOY.md with "Local development" / "Dev setup" section → flag as drift, propose moving content to README, removing section from DEPLOY in same patch round.
  - Existing repo has README.md mixing prod topology details (firewall, TLS, backups) → flag as drift, propose moving to DEPLOY.md.
  - 14-section template = ceiling not floor. Drop sections that don't apply (no DB → drop "Managed DB" section, no domain → drop TLS section). Don't pad to hit 14.
  - Audience test before merging a doc section: "would a junior dev clone-and-run with this?" → README. "Would an on-call SRE provisioning a new VPS use this?" → DEPLOY. If both → split it.
- **Reference**: commit `7ee9b42`, `agents/doc-syncer.md` STEP 5 (README template lines 223–335), STEP 6 (DEPLOY.md 14-section template lines 338–541). Linked to [[doc-syncer-readme-auto-deploy-prod]] (BDR-016).

---

## LRN-021 — Refactor migrating commands→skills must sweep `~/.claude/commands/` for orphan wrappers

- **Date**: 2026-05-20
- **Pattern**: when refactor moves orchestrator from `.claude/agents/foo.md` into `~/.claude/skills/foo/SKILL.md`, any pre-existing wrapper at `~/.claude/commands/foo.md` that references the old agent path becomes orphan. Wrapper still resolves `/foo` (slash commands take precedence over skills in dispatch), executes broken `Load and follow: .claude/agents/foo.md` instructions, fails silently or hits "file not found" mid-orchestration. Untracked files in `~/.claude/commands/` survive every refactor commit invisibly — git status in project repo never shows them.
- **Context**: 2026-05-20, `/ship-feature` hit BLK-004. Wrapper from before refactor `21960e0` ("changed orchestrators into skills") referenced 6 agent files; 5 deleted by refactor. Wrapper untracked → never flagged for cleanup. Detected only when user invoked `/ship-feature` and read the broken `Load and follow strictly:` list.
- **Future application**:
  - Any commit moving orchestrator from `agents/foo.md` → `skills/foo/SKILL.md` → `grep -rln "agents/foo.md" ~/.claude/commands/` and delete stale wrappers in same commit.
  - `/onboard` + `/init-project` must check `~/.claude/commands/` for wrappers referencing paths that no longer exist; print warning.
  - When auditing skills (darwin-skill, /skills-perso, /profile), also list `~/.claude/commands/*.md` and cross-check each `Load and follow:` line resolves.
  - Skills with `disable-model-invocation: true` rely on slash-dispatch — when wrapper exists, wrapper wins. Removing wrapper exposes skill directly; replacing skill behavior requires updating BOTH wrapper and SKILL.md.
- **How to detect early**: post-refactor script — `for f in ~/.claude/commands/*.md; do grep -Eo '\.claude/agents/[a-z-]+\.md' "$f" | while read p; do test -f "$HOME/$p" || echo "ORPHAN $f → missing $p"; done; done`.
- **Reference**: BLK-004, commits `0241e1d` + `21960e0`.

---

## LRN-020 — profile-sentinel-collision: literal labels in cmd output must not match profile filenames

- **Date**: 2026-05-18
- **Context**: Adding `lib/profiles/full.profile` exposed an aliasing bug in `lib/profile.sh:421`. `cmd_current` returned literal "full (all gstack skills enabled — no profile set)" when no profile was applied — a sentinel meaning "no profile active, full gstack on". With a real profile now named `full`, output became ambiguous: same word, opposite meanings (sentinel = no profile vs. profile name = canonical full set). Renamed sentinel to "none".
- **Pattern**: when a CLI returns named identifiers from a known namespace (profiles, channels, modes), any sentinel/placeholder value MUST be outside that namespace. Reserve sentinel strings like `none`, `unset`, `default`, `<none>` — never reuse a real identifier as "absence of identifier".
- **Where applicable**:
  - Any `cmd_current` / `cmd_status` / `cmd_active` that reports either a real entity OR a "nothing applied" state.
  - Profile/preset systems with named profiles.
  - Selector outputs in shell scripts where downstream code does `[ "$x" = "<name>" ]`.
- **How to detect early**:
  - Before adding a new entity name to a namespace, grep the codebase for hardcoded literals matching the candidate name (`grep -rn '"full"\|"none"\|"default"' lib/`).
  - Audit `case` statements + `echo` lines in CLI commands for namespace-reserved labels.
- **Cost when missed**: shell-script consumers parsing the output break silently — `[ "$prof" = "full" ]` matches both meanings. User reads ambiguous status. No type system to catch it.
- **Reference**: `lib/profile.sh:421` sentinel rename in same commit as new `full.profile`. Linked to [[profile-full-superset]] (BDR-017).

---

## LRN-022 — Audit `lib/profiles/*.profile` against gstack skill list after every submodule bump

- **Date**: 2026-05-21
- **Context**: 2026-05-21, `/hotfix` on BLK-005. Gstack upstream renamed `checkpoint` skill to `context-save` (shadow conflict with Claude Code native `/checkpoint` rewind alias). Five local `lib/profiles/*.profile` files referenced the dead name. Warning `⚠ missing: checkpoint — try: bash link.sh` looked actionable but link.sh cannot resurrect an upstream-deleted skill — suggested next step dead end. Misdiagnosis cost user confused round-trip before `/hotfix` traced the rename.
- **Pattern**: profiles couple to external naming registry (`skills-external/gstack/*/`). When upstream renames or removes a skill, profiles silently break: `bash lib/profile.sh set <profile>` warns but does not fail; user has no signal at submodule-bump time. Same shape as any pinned-name reference into a vendored dep (config referring to npm subpath, k8s manifest referring to image tag, etc.).
- **Where applicable**:
  - Any `git submodule update` or `git pull` inside `skills-external/gstack/` — diff skill list before/after.
  - `make plugin`, `bash install-plugins.sh` — any time external skill source moves.
  - When `bash lib/profile.sh apply|set <name>` warns `missing: <skill>`, treat warning as ground truth: skill is genuinely absent from `skills-external/gstack/` AND `skills-disabled/`. `link.sh` cannot fix it.
- **How to detect early**:
  ```bash
  # After any gstack submodule bump:
  diff <(ls skills-external/gstack/ | grep -v '^\.' | sort) \
       <(awk '$2 != "personal" && $2 != "external" && $2 !~ /^(plugin|mcp|cli)/ && /^[a-z]/ {print $1}' lib/profiles/*.profile | sort -u) \
       | grep '^>'   # entries in profiles but not in gstack = stale references
  ```
  Run as part of post-submodule-bump audit. Pair with `bash lib/profile.sh set <each-profile>` smoke test — any `⚠ missing:` line = stale entry.
- **Cost when missed**: every profile listing dead name emits misleading warning on `set`. User chases `link.sh` (suggested by `enable_skill` at `lib/profile.sh:191`) which silently no-ops. "try: bash link.sh" message hardcodes a fix that only applies to a different failure mode (skill exists upstream but not symlinked yet) — should differentiate. Follow-up: make missing-skill warning say "missing upstream: not in skills-external/gstack/" when applicable.
- **Reference**: BLK-005, commit `69c5ded`. Linked to [[ship-feature-orphan-wrapper]] (LRN-021) — same shape: post-refactor stale references survive because no automated sweep catches them.

---

## LRN-023 — Scripts invoked via symlink must resolve `$REPO` with `cd -P` (physical path), not default `cd` (logical)

- **Date**: 2026-05-21
- **Context**: 2026-05-21, BLK-006. `lib/profile.sh:43` used `REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`. Default `cd` preserves the logical (symlink-following) pathname, so when invoked via `bash "$HOME/.claude/lib/profile.sh"` — a symlinked entry point wired by `link.sh` — `$REPO` resolved to `/home/bchanot-ubuntu/.claude` instead of the real repo `/home/bchanot-ubuntu/Documents/claude`. `$SKILLS_DIR` happened to keep working because `~/.claude/skills` was itself a symlink to the repo, but `$DISABLED_DIR` was a real sibling directory at `~/.claude/skills-disabled` — separate from the repo's actual `skills-disabled/`. `cmd_current` scanned the wrong dir and reported `none` even when 14 gstack skills were genuinely disabled in the repo.
- **Pattern**: any script that
  1. computes paths relative to `$BASH_SOURCE[0]` AND
  2. is meant to be invoked via a symlink at the install location (e.g. `~/.claude/lib/foo.sh -> <repo>/lib/foo.sh`) AND
  3. references sibling directories that are NOT also symlinked into the install location

  MUST resolve the script's home via `cd -P` (or `realpath` / `readlink -f`), never default `cd`. Default `cd` returns the logical path the user typed (or the symlinked entry point) — anything you build off that path will follow symlinks for some siblings and fall back to real directories for others, depending on whether each sibling has a symlink in the install location.
- **Where applicable**:
  - Any `lib/`, `bin/`, `scripts/` directory in a repo that gets symlinked into `~/.claude/`, `~/.config/`, `/usr/local/`, etc. via an install script.
  - Specifically in this repo: `lib/profile.sh`, plus any other script that derives `$REPO`/`$ROOT` from `$BASH_SOURCE`. Audit `grep -rn 'cd "$(dirname "${BASH_SOURCE' lib/ hooks/ agents/`.
  - Same pattern in Python (`Path(__file__).resolve().parent.parent` is the safe equivalent — `.resolve()` is the analog of `cd -P`; bare `Path(__file__).parent.parent` is the bug).
- **How to detect early**:
  - When writing or reviewing a `REPO=` / `ROOT=` line in a shell script: check whether the script is reachable via a symlink. If yes, `-P` is mandatory.
  - Smoke test: from a directory OUTSIDE the repo, invoke the script via both `bash /<real-path>/script.sh` and `bash /<symlinked-path>/script.sh`. Any path the script computes should be identical between the two runs.
  - Lint via: `grep -n 'cd "$(dirname "${BASH_SOURCE' <script>` — every match should also contain `cd -P` (or be followed by an explicit `realpath` call).
- **Cost when missed**: state lands in two parallel directories. Reads from one, writes from the other. False-negative status reports. Worst case: silent data loss when one dir is cleaned by a tool that thinks the other is canonical.
- **Reference**: BLK-006, commit `a4558ee`. Linked to [[gstack-rename-profile-audit]] (LRN-022) — both bugs surfaced from the same `/profile set full` invocation, but root causes are independent.

---

## LRN-024 — New sibling command sharing logic → extract helper + refactor caller, never copy-paste

- **Date**: 2026-06-02
- **Pattern**: New `gstack on|off` needed same skill-toggle loops already inline in `cmd_reset` (enable-all-parked) + `cmd_set` (disable-not-in-profile). Copy-paste = divergence risk (gstack__ prefix logic, mktemp keep-file). Instead extracted `enable_all_gstack()` + `disable_gstack_not_in()` + `parked_gstack_count()`; refactored `cmd_reset`/`cmd_set` to call them, then added `cmd_gstack` as 3rd caller. Behavior preserved exact (code MOVED not changed).
- **Why matters**: CLAUDE.md "more elegant solution exists?" — slight scope expansion (touch existing fns) beats duplication. Risk contained by test: snapshot original symlink state → run on/off cycle → re-park exact original → assert final == original. PASS, live env untouched.
- **Key trick**: when mutating shared resource (symlinks, files, db), verify refactor by asserting `final_state == original_state` after a round-trip, not just "command exited 0".
- **Applies to**: any new subcommand/branch reusing logic inline in a peer command — extract first, refactor existing caller, then add new caller. shellcheck after.
- **Reference**: BDR-018, `lib/profile.sh` enable_all_gstack/disable_gstack_not_in/parked_gstack_count. Linked to [[gstack-on-off-verb]] (BDR-018).

---

## LRN-025 — gstack `.gitignore` allowlist must cover ALL toggleable skills, not just currently-enabled ones

- **Date**: 2026-06-02
- **Pattern**: gstack per-skill symlinks are local (regenerated by gstack `./setup`), kept out of git by an explicit `.gitignore` allowlist (`skills/<name>` per skill). Parked skills hide in `skills-disabled/` (blanket-ignored), so a skill missing from the allowlist looks harmless — UNTIL `profile reset` / `gstack on` (BDR-018) moves it into `skills/`, where it surfaces as an untracked symlink (git noise, risk of accidental commit). Found 6 parked skills (`document-generate`, `landing-report`, `scrape`, `setup-gbrain`, `skillify`, `sync-gbrain`) + 6 new unlinked (`spec`, 5 `ios-*`) all absent from the allowlist.
- **Why matters**: allowlist completeness is invisible until a toggle exercises it. The `skills-disabled/` blanket-ignore masks the gap for parked skills.
- **Applies to**: any system where a local-only (gitignored) artifact gets MOVED into a tracked dir by a toggle. Allowlist/ignore rules must enumerate the artifact's BOTH states (parked + active). After a gstack submodule bump, reconcile THREE surfaces, not two: `lib/profiles/*.profile` (LRN-022) **AND** `.gitignore` skills allowlist **AND** decide link/no-link per skill (platform relevance — iOS skills are Mac-only).
- **Detect**: `comm -23 <(gstack source skill names) <(grep '^skills/' .gitignore | sed 's#skills/##')` should be empty after any bump.
- **Reference**: BLK-007, `.gitignore` gstack section. Linked to [[gstack-rename-profile-audit]] (LRN-022), [[gstack-on-off-verb]] (BDR-018).

---

## LRN-026 — `disable-model-invocation: false` means ENABLED, not blocked

- **Date**: 2026-06-09
- **Pattern**: frontmatter key reads as "disable?" → `false` = NOT disabled = model invocation ENABLED. Easy to misread `false` as "off/blocked"; it is the opposite. Only `true` blocks. Absent key = default = enabled. `true` blocks BOTH surfaces: model auto-routing (description-match) AND orchestrator/sub-skill chaining via the Skill tool. Binary — no per-caller granularity, so you cannot allow orchestrator-chaining while forbidding model auto-fire.
- **Why matters**: two traps. (1) Adding `disable-model-invocation: false` thinking you block invocation — you don't, it's a no-op noise line. (2) Keeping `true` "for safety" on a skill you actually want orchestrators to chain (e.g. `ship-feature`, `refactor`) — silently breaks your own CLAUDE.md routing; the model sees the intent but can't fire. Real destructive-action safety = careful/guard hooks (block `rm -rf`/force-push live), INDEPENDENT of this flag — so `true` on an orchestrator buys ~0 data-safety, only suppresses auto-fire (token/time cost).
- **Applies to**: any Claude Code skill frontmatter. Want skill model-routable + orchestrator-chainable → omit key (or `false`). Want human-only `/command` entry point → `true`, accepting it also blocks orchestrators. Guard genuinely dangerous ops at the hook layer, not via this flag.
- **Reference**: BDR-019, 19 `skills/*/SKILL.md`. Linked to [[remove-disable-model-invocation-repowide]] (BDR-019).

---

## LRN-027 — Periodic "since last run" skill needs machine-readable state file — agents improvise boundaries from file dates otherwise

- **Date**: 2026-06-11
- **Context**: TDD baseline for `/audit-delta` (superpowers:writing-skills RED phase, isolated worktree, no skill). Agent asked to "audit everything changed since last audit run". No recorded state → agent guessed boundary from most recent file mtime/date in `.claude/audits/` (grabbed `DARWIN-SKILL-2026-05-12.md` — darwin report, not audit checkpoint), used `git log --after=<date>` (date-based, drifts on rebase/timezone/amend), then wrote ITS checkpoint as prose inside dated report — next run must guess again, same failure loop. Also: zero approval gate under "fix what you find + I'm in meeting" pressure, shellcheck-pass called "verified", all axes one mixed pass.
- **Pattern**: any recurring skill with "since last run" semantics MUST persist machine-readable state (JSON, SHA-based, per-dimension if partial runs possible) + skill must FORBID inference fallbacks explicitly ("do NOT scan report dates", "no `--after`"). Baseline agents fill state vacuum with plausible-wrong heuristics, confidently.
- **Why matters**: improvised boundary = wrong scope silently. Date boundaries break on rebase. Prose checkpoints unparseable. Single marker desyncs partial runs.
- **Applies to**: future periodic skills (audit, sync, drift-check, recurring reports). Design state file FIRST, write anti-inference rules in skill body.
- **Reference**: `skills/audit-delta/SKILL.md` STEP 0 + Common mistakes table. Linked to [[audit-delta-design]] (BDR-020).

---

## LRN-028 — "No-skill" subagent baselines invalid when skill installed globally — subagents see + invoke installed skills

- **Date**: 2026-06-11
- **Context**: darwin run on `audit-delta`. 3 baseline subagents (prompt without skill) meant as no-skill control. All 3 followed skill protocol anyway — one report said "Invoked the /audit-delta skill". Skill symlinked in `~/.claude/skills/` → auto-listed in every subagent's available-skills → "baseline" = contaminated, differential comparison dead.
- **Pattern**: control condition must REMOVE capability, not omit mention. Globally installed skills leak into all subagents. True baseline: fixture env with skill uninstalled/renamed, or isolated worktree pre-install (how audit-delta's own TDD RED phase did it — only valid baseline evidence that run).
- **Detect**: baseline report cites skill name / follows its exact protocol → contaminated.
- **Applies to**: darwin dim8 with/without tests, any A/B skill eval, TDD RED baselines.
- **Reference**: darwin results.tsv 2026-06-11 baseline row. Linked to [[audit-delta-design]] (BDR-020), LRN-027.

---

## LRN-029 — Edit adding exception to blanket rule WILL contradict it — counterbalanced blind judges catch what self-review misses

- **Date**: 2026-06-11
- **Context**: darwin Round 1 added STEP 0 exception (dangling marker → marker frozen) to `audit-delta`. Pre-existing 3c blanket rule ("unreachable user → marker still updates") now contradicted it. Self-review missed; 4/4 independent blind judges (2 per round, doc order swapped to kill position bias) flagged the live contradiction. Round 2 fixed via explicit cross-ref exception clause in 3c.
- **Pattern**: (1) any edit adding exception → grep doc for blanket rules covering same variable (here: marker updates), cross-ref or contradict. (2) Judge protocol that works: 2+ judges, A/B order counterbalanced, blind to version age, score named dims, require consensus. SkillLens 46.4% solo-judge accuracy is real — consensus + counterbalance compensates.
- **Why matters**: improvement edits create inconsistency debt invisible to author in same context (darwin blacklist #1).
- **Applies to**: skill/doc/spec edits adding branches; any self-modified artifact scoring.
- **Reference**: commits 0d2ece7 (introduced), 9fc93fa (fixed). Linked to LRN-027.

---

## LRN-030 — Opus 4.8 under-delegates subagents/memory/custom-tools by default — counter with explicit fan-out rule in CLAUDE.md

- **Date**: 2026-06-18
- **Context**: User noticed Claude rarely spawns subagents. Real cause = Opus 4.8 documented behavioral trait (Anthropic migration notes, surfaced via claude-api skill): conservative reaching for capabilities needing explicit "decide-to-use" step — subagent delegation, file-based memory, custom tools — won't reach unless reasonably sure needed. Less than 4.6/4.7. Session was partly correct task-sizing (1-2 file reads → inline right), partly real under-reach.
- **Pattern**: model-level under-delegation steerable via explicit prompt/config, NOT hard hook. Counter = CLAUDE.md `## Workflow` rule: task fans out across independent items (many files, parallel searches, multi-point checks) → delegate to subagents, don't iterate serially; default to delegation for multi-file exploration.
- **Why matters**: long sessions grind serially + fill main context when 3 parallel agents (cavecrew-investigator / Explore) would map at once. Default tendency wastes the agents the config already defines.
- **Applies to**: any Opus 4.8 session; tuning delegation behavior; deciding inline vs subagent. Same trait drives memory + custom-tool under-use — same counter.
- **Reference**: commit 02a0ba0 (CLAUDE.md `## Workflow` edit).

---

## LRN-031 — Skill value = gate + anti-noise + determinism, NOT re-coding what a capable agent does free

- **Date**: 2026-06-19
- **Pattern**: capable agent + strong CLAUDE.md already nails the easy-path (dedup, semantic-dedup, routing, done-detection) unaided. A skill earns its complexity ONLY on guarantees the agent drops under pressure: mandatory approval gate, anti-noise filters, explicit-only capture, determinism (baseline non-deterministic across runs). Re-documenting free behavior = bloat. Corollary (TDD): if no-skill RED baseline PASSES, fixture under-probes — strengthen on the value dimensions (subtle/pressured cases), never ship a skill justified by a test its absence passes. Trim each procedure to its load-bearing rule (PASS A done-detection → keep restraint rule, drop git-command how-to the agent runs anyway).
- **Context**: built merged `/capitalize` (BDR-023) via writing-skills TDD. RED v1 baseline passed (deduped, checked done task, ignored parasite) — too easy. RED v2 (semantic dup + ambiguous umbrella task + parasite-phrased-as-task + orientation directive + rushed prompt) failed on anti-noise (folded push/tag into TODO) + invented subtask + no approval stop. Those 4 = the skill's real marginal value; rest the baseline did free.
- **Future application**:
  - Building/reviewing a skill → ask "does the baseline agent already do this for free?" Keep only gate + filters + determinism + non-obvious restraint rules; cut machinery re-describing capable-agent behavior.
  - RED baseline passes without the skill → harden the fixture before writing, don't ship.
  - Trim each procedure section to its load-bearing rule; delete how-to the agent performs anyway.
- **Reference**: BDR-023, `skills/capitalize/SKILL.md` STEP 2B + Red flags. Linked to [[LRN-008]] (skill wins from edge-cases not workflow rewrites), [[LRN-028]] ("no-skill" baseline contamination when skill installed globally).

---

## LRN-032 — Rule has a domain; applying it outside that domain = category error — check artifact type before invoking

- **Date**: 2026-06-19
- **Context**: enriching `profile.sh list` display. Cited CLAUDE.md `80 chars/line` to justify compact counters + reject ellipsis truncation. Measured: 7/10 `list` rows still >80 (max 97) — descriptions 58-73 chars, fixed prefix 24. Truncating to hit 80 would break `list` function (at-a-glance profile compare).
- **Pattern (general)**: every rule carries a DOMAIN. Applying it outside that domain = category error. Before invoking ANY rule, identify artifact class it governs + confirm THIS artifact is that class. Mismatch → don't apply. Never apply rules mechanically.
- **Specific instance**: `80 chars/line` = SOURCE-CODE domain (edit readability, diffs, split terminals). CLI runtime output = displayed, not diffed/edited → out of domain. So `list` overflow OK; keep aligned left block (name+counters), descriptions run full.
- **Future application**: invoking a limit/convention/style rule → first ask "what artifact class does this govern, is THIS that class?". Catches misapplied norms (line-length on output, lint on generated files, prose rules on data).
- **Reference**: `lib/profile.sh` `cmd_list`, commit 5776195. Linked to [[LRN-031]] — both meta-lessons on NOT applying mechanically (LRN-031 = value of a skill; LRN-032 = domain of a rule).

---

## LRN-033 — Multibyte separator breaks `printf %-Ns` (byte-width) padding — pad via `${#}` char-count

- **Date**: 2026-06-19
- **Context**: `profile.sh list` ITEMS column = compact counts "12s·1p·1m·1c" using `·` (U+00B7, 2 bytes UTF-8).
- **Pattern**: `printf '%-Ns'` pads to N BYTES, not display columns. Multibyte char → field over-counts → columns misalign (off by bytes-minus-chars). Fix: display width via `${#str}` (char-count, UTF-8-aware under multibyte locale) + pad with `printf '%*s' <gap> ''`. Alt: keep multibyte content in LAST column (no pad) — existing `cmd_list` already did this for descriptions.
- **Future application**: aligning any column with non-ASCII (`·` `—` box-drawing, accents) → never trust `%-Ns`; use `${#}` + manual space pad, or put multibyte field last. Verify with `wc -L` (display width), not `wc -c`.
- **Reference**: `rpad()` in `lib/profile.sh`, commit 5776195.

---

## LRN-034 — Narrated state ≠ ground truth; the missed alarm was internal contradiction — verify against git

- **Date**: 2026-06-21
- **Context**: CLAUDE.md audit reprise. Assistant first said correctly "P3 non écrit" (profile.sh pivot). User then asserted "P3 DÉJÀ appliqué" (diff-approval confused with diff-writing — user acknowledged). Assistant ACCEPTED it ("P3 clos, je n'y touche pas") without reopening git; it carried into the resume prompt as "P3 APPLIQUÉ et committé". On reprise, git log + file content (design routing still split 3×) proved P3 never applied. Eventually applied → commit 493b6b9.
- **Cause (shared)**: origin = ambiguous user assertion (approval ≠ application, acknowledged); assistant failure = swallowing it without verification. Not one party's fault — both unverified.
- **Lead lesson — the missed alarm was internal contradiction**: assistant had said "P3 non écrit", then accepted "P3 fait" two turns later. A claim contradicting what you said just before = loudest possible signal to re-check — and it was reconciled by quietly accepting the newer claim. THAT is the real failure.
- **Pattern**: narrated/remembered state from ANY source (user OR assistant) is not ground truth. Approval of a diff ≠ its application.
- **Future application**: anyone asserts "X is done" → verify (git log, file content, grep) before building on it; ESPECIALLY when it contradicts your own earlier statement, or after a context/window break. Internal contradiction → stop, re-check git, never reconcile by accepting the newer claim silently.
- **Reference**: P3 reprise, commit 493b6b9. Linked to [[LRN-032]] (verify before applying a rule), [[LRN-035]] (check the artifact, not the claim/count).

---

## LRN-035 — Honest dedup: name-mention ≠ definition-instance; a dosage rule can make a "dedup" task a no-op

- **Date**: 2026-06-21
- **Context**: P4 of CLAUDE.md audit = factor "≤2 files, obvious fix" "repeated ~8×". Inspection: 4/8 = skill NAME `hotfix` in lists (not scope defs); 3/8 = context-specialized scope phrasings (routing trigger "typo, CSS, config, ≤2 files" / design "single cosmetic value" / general exemption "obvious fix" — NOT identical), 2 in protected sections (routing table, P3-consolidated design); canonical single source already created by P5 in `## Planning & TODO`. Net: factorize nothing.
- **Pattern**: before factoring "duplication", separate name/reference mentions from actual definition instances; check whether copies are identical or context-specialized. Apply dosage (keep inline where read-in-isolation needs it; in doubt keep inline). A dedup proposal can correctly collapse to no-op — kill it by applying the rule, don't force factorization to honor the proposal.
- **Future application**: any "X repeated N times → factor it" → audit what each occurrence IS; count real dup-of-definition, not keyword hits. Manufacturing factorization degrades local readability for zero gain.
- **Reference**: P4 no-op, CLAUDE.md audit (commit 663b16c). Linked to [[LRN-031]] (skill value = don't re-code free behavior, don't force a procedure), [[LRN-032]] (rule has a domain).

---

## LRN-036 — `command -v <cli>` in a shelled-out script depends on PATH carrying the cli's bin, NOT on the alias

- **Date**: 2026-06-21
- **Context**: design-tool-gate.sh shelled out (`bash script.sh`) by skill/hook checks `command -v claude` to verify magic + ui-ux-pro-max. Live run reported "claude absent" → unverified, though `claude mcp list` worked elsewhere same shell.
- **Refuted hypothesis**: "claude = alias (claude→dtach_claude function), alias dies in non-interactive subshell → cause". Alias DOES die in `bash script.sh`, but HARMLESS: real binary on inherited PATH (`~/.nvm/versions/node/vX/bin/claude`), so `command -v claude` resolves it. Proven: normal `bash script.sh` → FOUND; `PATH=/usr/bin:/bin bash script.sh` → NOT FOUND. Lever = PATH, not alias.
- **Real cause**: `command -v claude` succeeds only when PATH carries the node bin dir. Skill/hook can shell script out with sanitized PATH lacking it; nvm path version-pinned → node upgrade moves it. Either → check = unknown.
- **Fix**: don't trust inherited PATH. `ensure_claude_on_path()` probes known dirs (`~/.claude/local`, `~/.local/bin`, `/usr/local/bin`, nvm glob `sort -V | tail -1` = newest) + prepends bin dir (carries claude AND its node runtime, same dir; claude shebang needs node). Fail-visible exit 11 = the MITIGATION/net, NOT the cause.
- **Future application**: any script shelling out a CLI that may run from hook/subshell → resolve the binary's bin dir explicitly, don't assume interactive PATH. Test under `PATH=/usr/bin:/bin` to simulate sanitized context. Distinguish alias/function (interactive-only, never in subshell) vs real binary on PATH (what `command -v` finds in scripts).
- **Reference**: `ensure_claude_on_path()` in `lib/design-tool-gate.sh`, commit f963318. Linked to [[LRN-034]] (narrated/plausible state ≠ ground truth — here the plausible alias theory was wrong; test the real subshell, don't accept it).
