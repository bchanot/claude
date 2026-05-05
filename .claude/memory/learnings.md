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