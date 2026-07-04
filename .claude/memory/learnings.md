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
| LRN-013 | 2026-05-07 | marked CLI 16.x ignore stdin, dump own cli.js source | any shell MD→HTML via npx marked — use `-i FILE` not stdin |
| LRN-014 | 2026-05-11 | Pandoc base gfm strips header id attrs — need `gfm+gfm_auto_identifiers` | any MD→HTML/PDF with cross-references (`[§4](#nap)`) via pandoc |
| LRN-015 | 2026-05-11 | BrightLocal Free Tools retired 2026 — Moz Local Citation Checker is free replacement | client SEO/NAP docs — re-validate tool URLs + free-tier status annually |
| LRN-016 | 2026-05-11 | Pandoc GFM checkbox markup breaks adjacent-sibling CSS — target `li > input` directly | styling task-list checkboxes in pandoc-rendered HTML/PDF |
| LRN-017 | 2026-05-12 | Thin-dispatcher SKILL.md round-1 win = fallback + frontmatter triggers (+15 to +30) | any `/darwin-skill` round-1 on a dispatcher SKILL.md |
| LRN-018 | 2026-05-12 | Darwin eval subagents drift on total math — recompute in main thread | any subagent-driven SKILL.md rescore |
| LRN-019 | 2026-05-15 | Deployable-project doc split: README dev-quickstart + DEPLOY 14-section prod-VPS topology | any onboard/doc-syncer/scaffold producing docs for a deployable project |
| LRN-020 | 2026-05-18 | profile-sentinel-collision: literal labels in cmd output must not match profile filenames | a CLI reporting a real named-identifier OR a "nothing applied" state — keep sentinels outside the namespace (string-eq consumers break) |
| LRN-021 | 2026-05-20 | Refactor commands→skills must sweep `~/.claude/commands/` for orphan wrappers | any refactor moving `agents/foo.md` → `skills/foo/SKILL.md`; onboard/init-project audits |
| LRN-022 | 2026-05-21 | audit `lib/profiles/*.profile` against the gstack skill list after every submodule bump | any gstack submodule bump / external-skill-source move; a "missing:" warning = upstream rename/deletion (link.sh can't fix) |
| LRN-023 | 2026-05-21 | scripts invoked via symlink must resolve `$REPO` with `cd -P` (physical), not logical `cd` | any script invoked via a symlink that derives its repo root from `$BASH_SOURCE` (cd -P/realpath; Python .resolve()) |
| LRN-024 | 2026-06-02 | New sibling command sharing logic → extract helper + refactor existing caller, never copy-paste; assert pre/post state equality | adding a subcommand/branch reusing logic inline in a peer command |
| LRN-025 | 2026-06-02 | `.gitignore` gstack allowlist must cover ALL toggleable skills (incl. parked) — else enabling one = untracked git noise | any toggle that moves local-symlink skills into a tracked dir; post-submodule-bump reconcile |
| LRN-026 | 2026-06-09 | `disable-model-invocation: false` = ENABLED not blocking; only `true` blocks (model + orchestrator); binary, no per-caller | Claude Code skill frontmatter; deciding self-route/chain vs human-only entry point |
| LRN-027 | 2026-06-11 | Agents improvise audit boundaries from file dates when no machine state — periodic skills need machine-readable state file, never inference | any recurring/periodic skill needing "since last run" semantics |
| LRN-028 | 2026-06-11 | "no-skill" subagent baselines invalid when the skill is installed globally | any A/B skill eval / TDD RED baseline / darwin with-vs-without — control must REMOVE the capability, not omit mention |
| LRN-029 | 2026-06-11 | an edit adding an exception to a blanket rule will contradict it — counterbalanced blind judges catch it | skill/doc/spec edits adding a branch/exception; scoring any self-modified artifact (counterbalanced blind judges) |
| LRN-030 | 2026-06-18 | Opus 4.8 under-delegates subagents/memory/custom-tools by default — counter via explicit CLAUDE.md fan-out rule | any Opus 4.8 session; tuning delegation; inline-vs-subagent decision |
| LRN-031 | 2026-06-19 | Skill value = gate + anti-noise + determinism, not re-coding what a capable agent does free | building/reviewing any skill; writing-skills TDD fixture design |
| LRN-032 | 2026-06-19 | a rule has a domain; applying it outside = category error — check artifact type first | invoking a limit/convention/style rule — confirm it governs THIS artifact class |
| LRN-033 | 2026-06-19 | multibyte separator breaks `printf %-Ns` byte-width padding — pad via `${#}` char-count | aligning any column with non-ASCII (·, —, box-drawing, accents) |
| LRN-034 | 2026-06-21 | narrated state ≠ ground truth; the missed alarm was internal contradiction — verify vs git | anyone asserts "X is done" — verify (git/file/grep) before building on it |
| LRN-035 | 2026-06-21 | honest dedup: name-mention ≠ definition-instance; a dosage rule can make "dedup" a no-op | any "X repeated N times → factor it" — audit what each occurrence IS |
| LRN-036 | 2026-06-21 | `command -v <cli>` in a shelled-out script depends on PATH carrying the cli's bin, not the alias | any script shelling out a CLI from a hook/subshell |
| LRN-037 | 2026-06-21 | verify the load-bearing scenario on the REAL subject in REAL context, not a stub/logic argument | any "fixed/works" claim on a critical path — produce the real run output |
| LRN-038 | 2026-06-23 | Playwright host-platform override for distros newer than its hardcoded support list | any pinned tool with an OS allowlist breaking on a fresh OS upgrade |
| LRN-039 | 2026-06-23 | installers drift hand-curated config → snapshot+trap-restore guard; anchor gitignore for pollution | audit a fresh install with `git status` right after `make install` |
| LRN-040 | 2026-06-23 | OS newer than a pinned tool = TWO layers (version build + security policy) | "tool X broke after an OS upgrade" — check both build-support and OS hardening |
| LRN-041 | 2026-06-23 | a check reading a symlink an earlier install step makes → false negative if that step's precondition unmet | any "X not found in FILE" where FILE is a symlink/derived path |
| LRN-042 | 2026-06-23 | `npx skills add` / gstack `./setup` resolve install target RELATIVE TO CWD — repo CWD = wrong dir | before any `npx <x> add` / `<tool> init` that materializes a dotfile dir, set CWD |
| LRN-043 | 2026-06-25 | CLAUDE.md skill-routing: cut name-obvious lines, keep only non-derivable signal + dense catch-all | compressing any routing/dispatch table whose entries the model sees elsewhere |
| LRN-044 | 2026-06-25 | Edit/Write refuse to write THROUGH a symlink — pass the resolved real path | before editing any `~/.claude/...` config file — resolve it first |
| LRN-045 | 2026-06-25 | renaming a command: audit exact-name leak-guard / forbidden-token regexes | when renaming, grep the BARE old token inside regex/test/gate files |
| LRN-046 | 2026-06-25 | Destructive skill: deterministic oracle (byte-identical / count census) > semantic judge | any destructive/irreversible skill; behavioral-oracle TDD |
| LRN-047 | 2026-06-25 | A noisy safety guard (13/13 FP) = a guard you learn to ignore = risk → refine, don't tolerate | any guard/alert/lint that can false-positive |
| LRN-048 | 2026-06-25 | A "0/OK/pass" must prove it LOOKED (counted both sides), else verify hard-wired to pass | any verify/test/lint reporting success |
| LRN-049 | 2026-06-25 | non-destructive repeated nudge: stateless-minimal surface > state marker (conditional on stakes) | any repeated advisory in a stateless surface — bound noise before reaching for a marker |
| LRN-050 | 2026-06-25 | on a symlinked/live file, show-before-write is the ONLY control gate | before editing any file — check if it is live, treat pre-write diff as an approval gate |
| LRN-051 | 2026-06-26 | `git commit -- pathspec` strict on no-match → filter scoped commits to changed paths | any scoped-commit automation |
| LRN-052 | 2026-06-26 | Hash-anchoring: 2 cases it does NOT apply (pre-code founding, squash-merge) | capitalizing founding/arch decisions; squash repos |
| LRN-053 | 2026-06-26 | Read-before teeth = verifiable disposition in the artifact, not the act of reading | any read-before / check-before wiring |
| LRN-054 | 2026-06-26 | No deterministic oracle for "already in context" → never add a presence-skip branch | skip-if-seen optimizations over conversation state |
| LRN-055 | 2026-06-26 | Body `## ID —` headings = drift-immune index; the `## Index` table is not | choosing a substrate to index/select over |
| LRN-056 | 2026-06-26 | `grep PAT dir/*.md` on absent dir ERRORS (exit 2), not no-op → guard `[ -d ]` | any glob-fed scan that must no-op on nothing |
| LRN-057 | 2026-06-26 | Match consumption mechanism to consumer (mechanical / external-cognitive / inline) | wiring any produce→consume invariant |
| LRN-058 | 2026-06-27 | Same bug-class ≠ same fix — verify the twin shares the fix's PRECONDITION before replicating | porting a fix to a "same bug" twin |
| LRN-059 | 2026-06-27 | Step-number SWAP flips meanings (sweep refs) ≠ letter-suffix insertion (shifts nothing) | any pipeline renumber |
| LRN-060 | 2026-06-27 | Fail-closed guard proven by what it REFUSES (loudly); pass dynamic lists as argv not separator-string | automated scoped-commit / destructive guards |
| LRN-061 | 2026-06-27 | Runtime net for an unwired skill → check the wiring first (deterministic gap = fix structurally; non-det aléa = net OK, cf BDR-033) | "build a hook/watcher to catch when X isn't done" |
| LRN-062 | 2026-06-27 | deploy first-run detection = file-existence, never `git describe` | any "first run vs incremental" tool — detect by explicit on-disk marker |
| LRN-063 | 2026-06-27 | delta-since-marker = `git diff --name-only X HEAD` (two endpoints), never rev-list/three-dot | any delta-since-checkpoint over git — explicit two endpoints for tree diff |
| LRN-064 | 2026-06-27 | surgical-commit helper family partitions `.claude/`; new subtree needs own allowlist sibling | adding a committable `.claude/X` subtree |
| LRN-065 | 2026-06-27 | cross-session cold-resume skill = disk-bridge read-first (audit-delta convention) | any "do work → user acts out-of-band → resume later" skill |
| LRN-066 | 2026-06-27 | surgical-commit must fail LOUD on git-ignored target paths (else silent no-op) | any helper relying on `git status --porcelain` to detect changes |
| LRN-067 | 2026-06-28 | pipeline that LOOKS 2-level can terminate at SAME level; human-mediated step (interactive menu) masks the double-action until automated | replacing an interactive/human step with a deterministic one over a delegated sub-skill |
| LRN-068 | 2026-06-29 | enforcement-bootstrap must be transactional: activate the guard LAST + gate it on the bootstrap commit succeeding; precheck identity | any init that installs a hook/protection AND commits |
| LRN-069 | 2026-06-29 | token-authed remote writes under CC perms: inline-env (never `export`), token in header not argv, keep `git push` on ASK as the gate | scripting git/curl writes to a private remote from tool calls |
| LRN-070 | 2026-06-29 | clean-tree-gated migration blocked by a dirty submodule → diagnose pointer-vs-content; for a local edit use `submodule.<name>.ignore=dirty`, never blind reset | migrating/releasing a superproject whose submodule carries intentional local edits |
| LRN-071 | 2026-06-29 | fail-loud must cover the helper's OWN commit, not just its inputs — 3rd occurrence of the swallowed-commit pattern (a failed op masked by a later returning-0 statement) | any helper whose return value gates a downstream "success" — audit every fallible internal op propagates, esp. the commit |
| LRN-072 | 2026-06-29 | a stranded-artifact bug can be fixed by NOT creating the artifact (negative diff), not by plumbing its commit — if the producing step is speculative/unused, delete it | a stranded/duplicated/uncommitted-artifact bug — before building machinery, ask if the PRODUCING step is wanted; speculative-at-creation → remove, deliberate-on-demand → keep |
| LRN-073 | 2026-06-29 | a skill's worked-example must use FICTIONAL ids, never live registry ids (they prime real-data behavior) | any skill/agent with a worked example over the SAME data it operates on — use reserved/fictional ids; test deterministically that no live id appears |
| LRN-074 | 2026-06-29 | system `grep`/`awk` may be ugrep/mawk: don't assume flag-parsing, use `/usr/bin/grep`, watch the RED go red (4th command-assumption miss this session) | any shell test/guard riding on grep/awk/sed semantics — pin `/usr/bin/<tool>`, run the assertion, confirm it reds on the defect before trusting green |
| LRN-075 | 2026-06-30 | skill-vs-no-skill RED must test the UNGUIDED control: a "use git + justify" baseline makes a capable agent succeed (contaminated RED); real failure shows only on the tempting prompt | building any skill whose value is determinism/gate over a capable agent — strip guidance AND tempt the failure; control succeeds → don't author (or rescope) |
| LRN-076 | 2026-06-30 | append-only registry status mutates in place (UPDATE/FINAL blocks): CURRENT status = LAST status line, not Index, not first; range scan inclusive of next header bleeds a sibling's status word | parsing any in-place-mutated status; take last line, bound entry exclusive of next header |
| LRN-077 | 2026-06-30 | test fixtures must carry NEUTRAL names — a name that telegraphs the answer lets the subject pass by reading the name, not doing the work | designing any test fixture/path; same symptom as [[LRN-074]] (passes for WRONG reason), distinct cause (leaky fixture vs assumed command) |
| LRN-078 | 2026-06-30 | semver number DERIVES from the change nature, not "justify a target"; solo-repo "breaking" = requires a migration of own usage; a removal nothing invokes = Removed not breaking | choosing a release version; classifying MAJOR/MINOR/PATCH; deciding if a removal is breaking |
| LRN-079 | 2026-06-30 | orchestrator-skill TDD = replay the prescribed flow on a throwaway repo (gitflow-test style): RED runs the flow minus the new step → the outcome assertion reds on the gap | testing a skill that orchestrates an existing mechanic + one new step |
| LRN-080 | 2026-06-30 | before adding an instruction "to make the model do X", measure if it ALREADY does X — universal conventions (--help…) it often does; the behavioral RED can KILL the chantier (phantom value) | proposing any global instruction to elicit a behavior; CLAUDE.md additions |
| LRN-081 | 2026-06-30 | Claude commit trailers (Co-Authored-By + Claude-Session) only on Claude-COMPOSED content; a commit merely STAGING user-authored text gets none — staging ≠ authorship | committing on the user's behalf; memory-commit.sh appends trailers by default |
| LRN-082 | 2026-06-30 | Trigger-cleared on a multi-motif exclusion lifts only the named motif — re-check the others before acting | any "exclusion lifted / precondition cleared" — verify ALL grounds, not just the named one |
| LRN-083 | 2026-06-30 | subagents are an INVALID instrument for measuring main-loop spontaneous routing — SUBAGENT-STOP + delegated framing pin them to the no-route floor | any RED of whether the MAIN loop self-invokes; use fresh main-loop sessions, observe via the human |
| LRN-084 | 2026-07-01 | protection hook enforces PROD not the full branch-flow; exemption masked the rule-vs-guard divergence | a guard exempts a class / checks one predicate — verify it encodes full intent |
| LRN-085 | 2026-07-01 | Idempotent CLI install/update: `command -v` skip-if-present guard + detect channel (`npm ls -g` vs native symlink) before choosing updater; never `npm --force` over a bin npm doesn't own | any installer/updater for a CLI with >1 install channel |
| LRN-086 | 2026-07-02 | External-tool-generated skill: prove provenance by mtime (not repo grep), gitignore + regen via install-step; guard regen on ABSENCE when the tool co-writes a user-editable config | any untracked skill/dir a tool (ctx7, etc.) drops into the repo |
| LRN-087 | 2026-07-02 | presence-flag ≠ capability — rtk silently dead after .bashrc wipe; emitted commands need ABSOLUTE bin paths (they run in another shell); integrity pin = live machinery, re-pin on hook edit | any PATH-dependent capability + hand-managed shell profile; hooks emitting commands for another shell |
| LRN-088 | 2026-07-02 | token-cutting intuition inverts under measurement — verbosity beats cardinality (gstack 34 skills ≈ 592 tok vs pr-review 6 agents ≈ 2,183) | any "disable X to save tokens" — measure per-item bytes first; profiles toggle skills, not plugin payloads |
| LRN-089 | 2026-07-03 | pass-through wrapper (CLI `"$@"` → fn deriving target from ambient state: HEAD/cwd/env) silently ignores its args = silent contract violation; guard = args are an ASSERTION, refuse when they disagree with state | any dispatcher forwarding args to a callee that reads ambient state instead of the args |
| LRN-090 | 2026-06-30 | external-repo audit: open WIRED subsystems (hooks/runners) before declarative (docs/rules); described capability ≠ wired capability | auditing an external config/framework repo for transferable value |
| LRN-091 | 2026-07-03 | keyword-triggered soft-nudge hook w/ bare common tokens over-fires on non-UI work → tuned out; bare only when UI sense dominates, else bigram-or-drop | any advisory/nudge hook keyed on keywords |
| LRN-092 | 2026-07-03 | SAST smoke test w/ the OFFICIAL example secret = vacuous pass (rules exclude documented example keys by design); validate w/ realistic payloads + measure tier coverage before trusting a gate ruleset | smoke-testing any detector/gate — never the canonical example payload |
| LRN-093 | 2026-07-03 | grep -F pattern w/ embedded newline = per-line OR = lock that matches anything; structure locks single-line only, flip-test new locks | writing any grep-based structure lock / census test |
| LRN-094 | 2026-07-03 | SAST severity ≠ exploitability — semgrep ERROR conflates real vulns + hardening recos; metadata does NOT cleanly separate them (measured) → metadata refinement = noisy gate; ERROR-threshold + diff-scoping is the containment | mapping a SAST tool's output to a blocking gate |
| LRN-095 | 2026-07-03 | orthogonal gates don't contaminate — a conformity verifier must PASS correct-but-insecure code (security is a separate gate's job); proven live (CONFORME on a feature carrying a SQLi); fusing the two degrades each | designing multi-dimension review/verify/audit gates |
| LRN-096 | 2026-07-04 | a backstop/guard is code — reliable ONLY after a flip-test proves it CAN fail; an unproven guard replacing an advisory = a vacuous guard (LRN-048 applied to guards); flip-test mandatory at guard creation | building any deterministic guard/lint/backstop |

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
- **corroboration 2026-07-01**: multi-repo raccord (6 repos) — mapped each repo's REAL git/fs state (read-only cartography) before EVERY write/destructive op, gated per-gap, re-verified each subagent oracle in the main loop. Declared TODO/registry/checkbox drift confirmed repeatedly; the discipline KILLED false simplifications: a blind `master→main` CHANGELOG swap (reflog showed master renamed AWAY, not a live branch), "just remove the `.claude/**` exemption" (would have broken standalone `/capitalize`, [[LRN-084]]), a config supersession grep that failed on a line-wrap (supersession was real). Narrated/declared state ≠ ground truth, at multi-repo scale.

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

---

## LRN-037 — Verify the load-bearing scenario on the REAL subject in REAL context, not a stub or a logic argument

- **Date**: 2026-06-21
- **Context**: design-gate chantier. 4 successive plausible claims each REFUTED only by running the real thing: (1) .env read path was `$REPO/.env`, not `~/.claude/.env` (read the actual script); (2) fail-open — unknown folded into silent READY (saw it in live output); (3) "alias dies in subshell = cause" (refuted: real binary on inherited PATH → `command -v` succeeds); (4) real cause = PATH carrying nvm bin (proven by `PATH=/usr/bin:/bin` run). Logic/stub never caught any. The DISCRIMINATING magic-OFF-under-stripped-PATH → exit 10 is what proved the gate truly runs `claude mcp list` vs. defaulting to READY.
- **Pattern**: for the load-bearing scenario, run it on the REAL subject in the REAL invocation context (prod path `$HOME/.claude/lib/...`, prod-like PATH), not a stub or a "the code path is correct" argument. A stub proves branch coverage; only the real subject proves the integration. Always add a DISCRIMINATING case — force the failure state; the check must REPORT it, not pass by default (a check that only ever passes proves nothing).
- **Future application**: any "fixed/works" claim on a critical path → produce the real run output (command + lines + exit code) before capitalizing or shipping; don't summarize ("condition met") in place of the output. Stub/logic = necessary for branch coverage, never sufficient for the integration claim. Most rentable discipline of the whole segment: every refutation came from execution, none from reasoning.
- **Reference**: design-gate chantier, the `PATH=/usr/bin:/bin` matrix (magic-on → READY/0, magic-off → INCOMPLETE/10), commits 4d19135 / f963318. Linked to [[LRN-036]] (the concrete instance: the PATH cause surfaced only by the real run), [[LRN-034]] (its twin — 034 = don't trust a narrated *claim*; 037 = don't trust a *stub/logic argument* as proof; both demand execution against ground truth).

---

## LRN-038 — Playwright host-platform override for distros newer than its hardcoded support list

- **Date**: 2026-06-23
- **Context**: fresh Ubuntu 26.04. gstack `./setup` aborted: "Playwright does not support chromium on ubuntu26.04-x64". Playwright 1.58.2's registry hardcodes `ubuntu20.04/22.04/24.04` only; a newer release → no matching build → hard error. gstack is a pinned submodule (must not edit).
- **Pattern**: `PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntuXX.04-<arch>` forces a fallback build. MUST include arch (`x64`/`arm64`) — bare `ubuntu24.04` fails ("does not support … ubuntu24.04"). Set it from the WRAPPER: `export` before the submodule's setup (install-time download) AND persist to the shell profile (runtime launch) — both paths call `getHostPlatform`. No submodule edit. Gate on real OS version (`sort -V` compare) so supported distros are untouched. Test with the LOCAL `./node_modules/.bin/playwright` — `bunx playwright` pulls the LATEST playwright (different browser revision than the local import), which masks the result.
- **Future application**: any pinned tool that hardcodes an OS allowlist breaks on a fresh OS upgrade. Look for a host-platform override env before bumping/forking the dep. Prove the fallback binary actually runs (`ldd` = no missing libs + a real headless render), not just that the download resolves.
- **Reference**: `install-plugins.sh` `playwright_platform_override()`, commit 211c7d4. Linked to [[BLK-008]].
- **2026-06-23 CORRECTION (override REVERTED, commit b9c3937)**: the override is NOT a usable fix on Ubuntu 26.04. It makes `playwright install` switch to the ubuntu24.04 fallback build, which downloads to 100% then HANGS at extraction (chrome binary never materializes; real machine + sandbox). Turned a 0.5s fast-fail into an install-blocking hang. The isolated proof (`ldd` + headless render) PASSED but used an already-extracted sibling build (rev 1228) — it masked the install-path hang in the real flow (rev 1208). **Sharpened lesson**: proving the binary launches in isolation is NOT proving the install path works — run the ACTUAL install command end-to-end (it must COMPLETE, not just "download resolves" nor "a binary launches"). The override technique stays valid in general, but the EXTRACTION/COMPLETE step is part of "does it work".

---

## LRN-039 — Installers drift hand-curated config → snapshot+trap-restore guard; anchor gitignore for pollution

- **Date**: 2026-06-23
- **Context**: fresh Ubuntu `make install`. 3rd-party installers mutated repo files: graphify rewrote `CLAUDE.md`+hooks (every `graphify install`, Step 7), `claude plugin install` flipped `enabledPlugins`, the example-skills `cp` churned `frontend-design`, `npx skills add` wrote project-scope `.agents/` + `skills-lock.json`.
- **Pattern**: file an installer rewrites but YOU curate → snapshot to a `mktemp -d` at start + `trap restore EXIT` (`cmp -s` before `cp`, revert only real diffs). Preserves pre-existing edits, no git dependency, idempotent, survives early-exit. Pure generated pollution → gitignore. ANCHOR the ignore (`/.agents/`, NOT `.agents/` and NOT `agents`) so it can't catch a legit sibling — our agents live in `agents/` (no dot). Verify with `git check-ignore -v <legit-dir>` that the pattern doesn't over-match.
- **Future application**: audit a fresh install = `git status` right after `make install`; classify every drift as (a) curated → guard, or (b) pollution → anchored gitignore. Never `git checkout` to clean drift (destroys uncommitted work). Prove the guard with an isolated drift→restore test before trusting it.
- **Reference**: `install-plugins.sh` `restore_curated_configs` + EXIT trap, `.gitignore` `/.agents/`, commits 51afe9b / 7de8761. Linked to [[BDR-028]].

---

## LRN-040 — OS newer than a pinned tool supports = TWO distinct layers (version build + security policy)

- **Date**: 2026-06-23
- **Context**: gstack browser on fresh Ubuntu 26.04. Layer 1 = Playwright 1.58.2 ships no browser build for 26.04 → install errors (the host-platform override "fixes" the error but its fallback build HANGS at extraction — dead end, [[BLK-008]]). Layer 2 = even with Playwright 1.61 (native 26.04 build that launches fine in isolation), the real browse path aborts "No usable sandbox" because Ubuntu 24.04+ restricts unprivileged user namespaces via AppArmor.
- **Pattern**: (a) bump the tool PAST the OS-support threshold — don't force the OS to look older (overrides/fallbacks are fragile; prove the install COMPLETES, not just that a binary launches). For a pinned submodule dep: `bun add X@latest` in the submodule, automatable in the installer, idempotent by grepping the dep's support list for the running OS tag before bumping. (b) SEPARATELY handle OS security hardening: Chromium needs `--no-sandbox` where `sysctl kernel.apparmor_restrict_unprivileged_userns=1`; gstack exposes `GSTACK_CHROMIUM_NO_SANDBOX=1` (#1562). Gate persistence on the sysctl, not an OS-version guess.
- **Future application**: "tool X broke after an OS upgrade" → check BOTH (1) does X ship a build / support entry for the new OS (bump if not), and (2) does the new OS's hardening (userns/AppArmor/SELinux) block X at runtime (needs an opt-out flag). Fix one without the other and it still fails. Verify the FULL runtime path (drive a real page) — here the isolated `chromium.launch()` PASSED while the real `browse` path failed on the sandbox.
- **Reference**: `install-plugins.sh`, `.bashrc` `GSTACK_CHROMIUM_NO_SANDBOX=1`, gstack `browse/src/browser-manager.ts` `shouldEnableChromiumSandbox()`, commit 3b8ffb1. Linked to [[BDR-029]], [[BLK-008]], [[LRN-038]].

---

## LRN-041 — A check reading a symlink an EARLIER install step makes → false negative if that step's precondition wasn't met

- **Date**: 2026-06-23
- **Context**: install warned "MAGIC_API_KEY not found in ~/.claude/.env" though the key WAS set there. Root: the check grep'd `$REPO/.env` — a symlink → `~/.claude/.env` ([[BDR-026]]) created by `link.sh`'s `link_env`. On a fresh machine `~/.claude/.env` is created AFTER `link.sh` runs (install first warns "create it"), so the symlink was never made and the key was unreachable via `$REPO/.env`. `make plugin` also never runs `link.sh`. The warning misleadingly blamed `~/.claude/.env`.
- **Pattern**: a check that reads a path PRODUCED by an earlier setup step silently fails when that step's precondition wasn't met yet (target absent → symlink skipped). Fix: read the CANONICAL source and/or self-heal (create the missing symlink when the canonical exists). Env-key greps must tolerate `export `/leading whitespace and require a non-empty value: `^[[:space:]]*(export[[:space:]]+)?KEY=.` — and the message must name the real gap (symlink missing vs key absent), with an actionable hint (`run make link`).
- **Future application**: any "X not found in FILE" where FILE is a symlink/derived path → verify the producing step ran with its precondition, prefer the canonical source, self-heal or give an actionable message. Sandbox note: `.env*` reads were blocked — diagnosed via directory listing + regex tests on SYNTHETIC lines, never reading the secret.
- **Reference**: `install-plugins.sh` magic check (self-heal symlink + tolerant regex), `link.sh` `link_env`, commit 1b028cb. Linked to [[BDR-026]].

---

## LRN-042 — `npx skills add` / gstack `./setup` resolve install target RELATIVE TO CWD — run from repo = wrong dir, breaks `$HOME` symlink assumptions

- **Date**: 2026-06-23
- **Context**: darwin-skill `npx -y skills add` (Step 8.5) + gstack `./setup` (Step 2) both ran with CWD=repo. The `skills` CLI writes to `<cwd>/.agents/skills`; gstack `./setup` likewise wrote per-skill dirs into repo-local `.agents/skills`/`.claude/skills`. So darwin landed in `$REPO/.agents/skills/darwin-skill` + `$REPO/.claude/skills/darwin-skill`, NOT `$HOME/.agents/skills/darwin-skill` where `link.sh` (NPX_EXTERNAL_SKILLS) + `install-plugins.sh` (`_dst`) look → symlink never created, "darwin-skill not installed — run make plugin" though it WAS installed. SELF-REINFORCING: once `$REPO/.agents` exists, every later `skills add` targets it. `find-skills` only worked because an earlier run (before `$REPO/.agents` existed) wrote it to `$HOME`. BDR-028/LRN-039 had already gitignored repo `.agents/`+`skills-lock.json` as "drift noise" — masked the symptom, never saw the install was landing in the WRONG PLACE.
- **Pattern**: a per-user installer that resolves its target relative to CWD (walks up for / creates `.<tool>/` in CWD) silently installs into the project tree when run from a repo that already carries such a dir. Gitignoring the junk hides it but the artifact is unreachable from `$HOME`-based consumers. Fix: run the installer from `$HOME` (`(cd "$HOME" && npx -y skills add …)`) so it targets `$HOME/.agents/skills`; clean up the repo-local copies (gitignored → safe `rm -rf`). Also fix the ordering twin: `link.sh` must re-run AFTER the install steps that produce what it symlinks (install.sh ran link FIRST; install-plugins never re-linked) — added a final `link.sh` step so `make plugin`/`make install` finish self-sufficient.
- **Future application**: before running any `npx <x> add` / `<tool> init` / `setup` that materializes a dotfile dir, set CWD to where the artifact MUST live (usually `$HOME`), don't trust the script's default resolution. When a "X not installed" warning contradicts a "successfully installed" log line → diff the EXPECTED path vs where the log says it wrote (here log line showed `~/Documents/claude/.agents/skills/darwin-skill`). When an installer A produces inputs for symlinker B, B must run after A in the same invocation.
- **Reference**: `install-plugins.sh` Step 8.5 (`cd "$HOME"` + parasite cleanup) + Step 10 (final `link.sh`), `update-all.sh` Step 7.5, log `install-20260623-181416.log:1399`. Extends [[LRN-039]] (BDR-028 — gitignored the symptom) + [[LRN-007]] (toggle-external source-only state) + [[LRN-041]] (install-ordering false-negative). gstack on-demand consumer = [[BDR-030]].

---

## LRN-043 — CLAUDE.md skill-routing: cut name-obvious lines (already in skill descriptions), keep only non-derivable signal + dense catch-all

- **Date**: 2026-06-25
- **Context**: compressing the Skill-routing block of the global CLAUDE.md. Claude already sees every skill's `description` in session context (the available-skills list). A routing line that merely restates "task X → skill named X" duplicates that description → pure token waste loaded every session.
- **Pattern**: in a routing list, KEEP only lines carrying signal NOT derivable from the skill name — (a) conditional fallbacks (gstack ON/OFF), (b) misleading/cryptic names where name ≠ function (`validate` → W3C/WCAG, not form/data/build validation; `cso` → security audit; `plan-eng-review` → architecture review), (c) disambiguation between near-twins (feat/hotfix/bugfix by file-count). CUT the name-obvious rest, replace with ONE dense catch-all ("most skills route by name — match the request to the skill whose description fits"). GUARD: a misleading name is NOT transparent → it needs its own explicit line or it mis-routes; never cut those to save a line (user restored `validate` + `plan-eng-review` for exactly this).
- **Future application**: compressing any routing/dispatch table whose entries the model already sees elsewhere → delete the redundant majority, keep the non-obvious minority + a generic fallback. Test each candidate cut: "is this mapping derivable from the skill name + its own description?" Yes → cut. No → keep explicit.
- **Reference**: `~/.claude/CLAUDE.md` §Skill routing, commit ba743cf (routing block 40 → 23 lines). Linked to [[BDR-031]].

---

## LRN-044 — Edit/Write tools refuse to write THROUGH a symlink — pass the resolved real path

- **Date**: 2026-06-25
- **Context**: editing `~/.claude/CLAUDE.md`, a symlink → `~/Documents/claude/CLAUDE.md` (the tracked repo file). Read worked through the symlink; Edit errored: "Refusing to write through symlink … Resolve the symlink and pass the real target path explicitly."
- **Pattern**: many of this user's `~/.claude/*` config files are symlinks INTO the claude-config repo (`~/Documents/claude/`). Edit/Write block writes through a symlink (safety against clobbering link targets); Read does not — so Read-through-link succeeds then Edit-through-link fails on the same path.
- **Future application**: before editing any `~/.claude/...` config file, resolve it first (`readlink -f <path>`, or `ls -la` to spot the arrow). Then Read AND Edit the RESOLVED real path so the harness's read-tracking matches what you write — and `git` status/diff/commit land naturally in the repo that owns the file.
- **Reference**: hit while editing `~/.claude/CLAUDE.md` → `~/Documents/claude/CLAUDE.md`. Linked to [[BDR-031]].

---

## LRN-045 — Renaming a command: audit exact-name leak-guard / forbidden-token regexes

- **Date**: 2026-06-25
- **Context**: rename `/validate` → `/web-validate`. A client-deliverable leak-guard in `agents/client-handover-writer.md:1462` greps generated docs for internal tool names via `grep -niE '/(seo|harden|validate|cso|...)\b'`. The `web-` prefix means `/web-validate` no longer matches the `/validate` branch (the `/` must sit immediately before `validate`; post-rename a `-` sits there) → renamed command leaks SILENTLY into client-facing output. No error — the gate just stops catching it.
- **Pattern**: any rename of a command/skill/identifier must sweep regexes/allowlists/denylists that match the OLD name by exact token — leak guards, forbidden-token gates, routing dispatchers, CI greps. A prefix/suffix rename breaks anchored matches (`/oldname\b`) with zero error. Fix = alternation covering BOTH names (`web-validate|validate`), NOT replacement — old artifacts (already-shipped client docs, logs) still carry the legacy name and must stay caught.
- **Future application**: when renaming, grep the BARE old token inside regex/test/gate files, not just `/oldname` command refs. A blind `replace_all '/old' '/new'` MISSES these because the guard stores the name inside an alternation (`|old|`), not as `/old`. For each guard found, extend to `new|old`; verify the gate line shows both names.
- **Reference**: `agents/client-handover-writer.md:1462`, rename commit `e5e673a`. Linked to [[BDR-032]].

## LRN-046 — Destructive skill: deterministic oracle > semantic judge

- **Date**: 2026-06-25
- **Pattern**: On a DESTRUCTIVE skill the binding oracle must be DETERMINISTIC (byte-identical, or count-based census per-entry × per-category), not a semantic judge. A judge false-greens twice: (a) PRESERVED-but-MUTATED content — RED-4, a "meaning preserved" collapse still rewrote a permanent safety rule; byte-identical caught it, the judge would not; (b) a 0-result that happened by CHANCE — "no negation inverted" ≠ protected, it was the dice not a guard. If the oracle must be behavioral/LLM, pair it with a deterministic check that is the gate.
- **Context**: prune-memory v1.1 TDD (EVAL-006, skill `0a3e766`). RED-4 collapse + RED-3 compression.
- **Future application**: any destructive/irreversible skill or safety check; any TDD whose natural oracle is an LLM judge — make the binding check deterministic, keep the judge as a secondary net.
- **Reference**: skill `0a3e766`, `tests/run-behavioral.md`. Linked to [[EVAL-006]].

## LRN-047 — A noisy safety guard is a risk, not discomfort

- **Date**: 2026-06-25
- **Pattern**: A safety guard that cries wolf (13/13 false positives on real data) is a guard you learn to IGNORE → the day of the true positive you skip it by habit. On a destructive op a noisy guard = security RISK, not annoyance → REFINE it (here line-grep → count-based census), don't tolerate. Measure the false-positive rate on REAL data, not fixtures — all-green fixtures hid the 13.
- **Context**: prune-memory v1.1 (EVAL-006). The RED-5 line-grep fidelity guard fired 13/13 false positives on the live learnings.md (line-sharing) → replaced by a per-entry census (0 FP, proven).
- **Future application**: any guard/alert/lint/test that can false-positive — measure FP on real data before shipping; a guard habitually ignored is worse than none.
- **Reference**: skill `0a3e766`, `tests/run-deterministic.sh` (RED-5). Linked to [[EVAL-006]].

## LRN-048 — A "0 / OK / pass" must prove it LOOKED

- **Date**: 2026-06-25
- **Pattern**: A passing result ("0 errors", "OK", "clean") must PROVE it inspected — show the work counted something on both sides (census non-zero on HEAD and WORK). Else it is a verify hard-wired to pass = the original prune-memory v1 lie (`basename | cut -c1-3` never matched any heading → verify always printed blank-OK). A 0 by inaction is indistinguishable from a 0 by correctness; force the success path to surface its coverage.
- **Context**: prune-memory v1.1 (EVAL-006). v1 STEP-4 verify always reported OK (wrong prefix → 0 markers → blank). The fix's 0-false-positive is only trustworthy because the census was shown counting both sides.
- **Future application**: any verify/test/lint reporting success — design the pass to surface what it examined (counts / files / lines) so a vacuous pass is visible, not silent.
- **Reference**: skill `0a3e766`, EVAL-006 (verify-proof anomaly). Linked to [[EVAL-006]].

## LRN-049 — Non-destructive repeated nudge: stateless-minimal surface > state marker (conditional on stakes)

- **Date**: 2026-06-25
- **Pattern**: To dedup a REPEATED but NON-DESTRUCTIVE suggestion (hint/nudge/advisory in a stateless flow — gate, hook, lint note), minimize the surface (always 1 line) instead of a persistence marker. A marker buys "exactly once" but costs state (file + gitignore + location), wrong scope ("session" via a plain file = forever-per-project), and staleness with no cleanup. Goal is not "prevent re-fire" but "make re-fire cheap enough to never be noise" — strip the per-occurrence richness and there is nothing left to dedup. **Conditional on stakes**: [[LRN-046]]/[[LRN-047]] ("deterministic > behavioral", "noisy guard = risk") were forged on a DESTRUCTIVE skill where a false-green = data loss → there a deterministic marker earns its cost. Here it is a 1-line cosmetic note → re-fire is annoyance, not risk → do NOT import marker-grade infra. Same determinism requirement, opposite cost/benefit.
- **Context**: design-gate §4 anim-lib suggestion ([[BDR-033]]). User reserved the marker-vs-refire call; winning third option was "always 1 line, stateless".
- **Future application**: any repeated advisory in a stateless surface — first bound the noise by minimizing the surface; reach for a marker/flag-file ONLY when a missed dedup is costly (destructive, irreversible, money, security), not merely repetitive. Match the guard's cost to the stake it protects.
- **Reference**: `lib/design-gate.md` §4, [[BDR-033]]. Conditions [[LRN-046]], [[LRN-047]].

## LRN-050 — On a symlinked/live file, show-before-write is the ONLY control gate

- **Date**: 2026-06-25
- **Pattern**: When the edit target is symlinked into the live path (`~/.claude/lib/`→repo, `~/.claude/CLAUDE.md`→repo …), saving the file IS deploying it — write and go-live collapse into one act. No later deploy step catches a bad change, so the pre-write review (show the drafted diff, get explicit go) is the ONLY checkpoint before the change is in service — unlike a normal file where build/commit/deploy offers a second net. On live/symlinked targets, show→validate→write is mandatory, not courtesy; "edit silently then show" forfeits the only gate.
- **Context**: this session twice wrote-then-showed on `lib/design-gate.md` (live via symlink). Both harmless (non-destructive), but the pattern would bite on a destructive live edit. User flagged it → inverted to show→validate→write.
- **Future application**: before editing any file, check if it is live (`readlink -f`, compare to `~/.claude/`); if live, treat the pre-write diff as a mandatory approval gate, not an optional preview. Generalizes to any "edit = deploy" target (dotfiles, served config, hot-reloaded sources).
- **Reference**: `lib/design-gate.md` (symlink → `~/.claude/lib/`). Sibling to [[LRN-044]] (write-through-symlink → resolve real path). Linked to [[BDR-033]].

## LRN-051 — `git commit -- <pathspec>` strict on no-match → filter scoped commits to changed paths

- **Date**: 2026-06-26
- **Pattern**: Automating a scoped commit (commit only subtree X), pass to `git add`/`git commit` ONLY paths with real pending changes. `git add -- <pathspec>` TOLERATES a no-match pathspec (rc 0, stages the matching ones); `git commit -- <pathspec>` is STRICT — one no-match pathspec ABORTS the whole commit (`error: pathspec '<x>' did not match any file(s) known to git`). So a clean scoped path (e.g. empty `.claude/tasks`) silently aborts the commit on most runs. Filter via `git status --porcelain -- <path>` to changed paths only. Bonus: `git commit -- pathspec` = PARTIAL commit (working-tree of those paths, ignores rest of index) → surgical-scope safety: dangling code (untracked OR pre-staged) never embarked.
- **Context**: building `lib/memory-commit.sh`. Naive `git commit -- .claude/memory .claude/tasks` aborted whenever `.claude/tasks` was clean. Caught by real-exec test (T1/T2/T2-bis), NOT by assuming git's behavior — `add` and `commit` are NOT symmetric on pathspecs.
- **Future application**: any "commit only subtree X" automation — filter to changed paths; rely on partial-commit for surgical scope; never assume tool behavior symmetric across sibling subcommands — exec-test it.
- **Reference**: commit `58cb91d` (`_changed_paths` filter + T1/T2/T2-bis), `bbef41c` (stdout hash contract). See [[BDR-034]].

## LRN-052 — Hash-anchoring applicability — 2 cases where `Reference: commit <hash>` does NOT apply

- **Date**: 2026-06-26
- **Pattern**: The anchoring convention (`Reference: commit <hash>`) means "the commit that IMPLEMENTS this decision" (BDR-033 → 11792cc). It does NOT apply in 2 cases: (1) a FOUNDING decision made pre-code (at design time) — attested by no implementing commit; anchoring it to the unrelated scaffold commit is a FALSE anchor. (2) a SQUASH-MERGED PR — the anchored commit ceases to exist post-squash. Forcing a hash in either case dilutes what "anchored" means everywhere else. Rule: pre-code founding decisions carry NO hash (path+date suffice); squash-merge workflows can't anchor.
- **Context**: building init-project STEP 10b (capitalize founding architecture decisions). A founding "Astro not Next" has no implementing commit. Surfaced the BOUNDARY of the anchoring convention — completes it, not contradicts it.
- **Future application**: capitalizing founding/architecture decisions, or working in squash-merge repos — do NOT fabricate a hash; the anchor only means something when a real implementing commit exists.
- **Reference**: commit `df60df6` (init-project STEP 10b hash rule), `lib/capitalize-commit.md` (2-hash non-confusion). See [[BDR-034]], [[BDR-033]].

## LRN-053 — Read-before teeth = verifiable disposition in the artifact, not the act of reading

- **Date**: 2026-06-26
- **Pattern**: An "always read X before planning" invariant guarantees NOTHING by the read alone — "ran before the plan" proves the digest was PRODUCED, not CONSUMED. The teeth are a verifiable DISPOSITION: the plan/diagnosis must NAME each surfaced item it honors, or state none binds. [[LRN-048]] ("a 0/OK must prove it LOOKED") one step further — the guarantee is "did it STATE a verdict on each?" (checkable), not "did it look?" (not). Without the trace, even natural consumption (inline reader=planner) degrades to read-then-ignore.
- **Context**: analyze-before-plan ([[BDR-035]]). feat's first draft ("feed the MINI-PLAN") had no forced trace → user flagged it as the link where wiring goes cosmetic; strengthened to "MINI-PLAN names in-force or states none". bugfix DIAGNOSIS names `PRIOR: BLK-xxx`.
- **Future application**: any read-before / check-before / advisory wiring — force the consuming artifact to emit a per-item verdict; never trust "data was available" = "data was used".
- **Reference**: `lib/analyze-before-plan.md` (OUTPUT), `agents/feater.md` STEP 0.6, `agents/bugfixer.md` STEP 2.5. Extends [[LRN-048]]. See [[BDR-035]].

## LRN-054 — No deterministic oracle for "already in context" → never add a presence-skip branch

- **Date**: 2026-06-26
- **Pattern**: "Skip the work if the info is already in my context" has no clean implementation: (1) self-judgment = the behavioral guard [[LRN-046]] rejects, unreliable on long convos ([[LRN-034]]); (2) a session marker records "was read", NOT "still present" → after a compaction the body is gone but the marker says skip → FALSE-SKIP (the marker cost [[BDR-033]] priced); (3) the agent cannot grep its own context window. No presence oracle exists. Do the work unconditionally when cheap; bite on the verifiable disposition.
- **Context**: analyze-before-plan ([[BDR-035]]). Tried to skip PASS-2 full-read for "already in context" entries; predicate had no oracle. Resolved: PASS-2 reads selected set unconditionally (~tens of transient lines, digest-only persists). A decision WRITTEN earlier same-conversation must still re-surface as in-force (content in context ≠ flow treated it as a constraint).
- **Future application**: any "skip if already seen/in-context" optimization over conversation state — reject; no oracle. Make the work cheap+unconditional, or use a deterministic EXTERNAL ledger (not context introspection).
- **Reference**: `lib/analyze-before-plan.md` (THE INVARIANT). Conditions [[LRN-046]], [[LRN-034]], [[BDR-033]]. See [[BDR-035]].

## LRN-055 — Body `## ID —` headings are a drift-immune index; the maintained `## Index` table is not

- **Date**: 2026-06-26
- **Pattern**: When a registry keeps both per-entry `## ID — title` headings AND a hand-maintained `## Index` table, the Index DRIFTS (entries land in the body, the manual update lapses) while headings cannot (an entry IS its heading — 100% coverage by construction). Measured: decisions 11/34 (32%), learnings 21/52 (40%), blockers 2/9 (22%) missing from the Index — scattered in large blocks (e.g. decisions BDR-024–033 unindexed while the newer BDR-034 is), not an old/new split. The manual Index-update step is simply unreliable. Key any selector/scan off `grep '^## <PREFIX>-'`, never the convenience Index. Backfill (prune-memory passe D) = human-TOC hygiene, NOT a selector dependency.
- **Context**: analyze-before-plan ([[BDR-035]]) two-pass. First instinct "reuse the Index capitalize maintains"; measuring the drift killed it — the convenient artifact was the unreliable one, the guaranteed one (headings) sat free.
- **Future application**: choosing a substrate to index/select over — prefer what the STRUCTURE guarantees over what a step PROMISES to maintain. Verify maintained-artifact completeness before depending on it.
- **Reference**: `lib/analyze-before-plan.md` (PASS 1). `skills/prune-memory` passe D. See [[BDR-035]].

## LRN-056 — `grep PAT dir/*.md` on an absent dir ERRORS (exit 2), it does not no-op → guard with `[ -d ]`

- **Date**: 2026-06-26
- **Pattern**: A bare `grep -E PAT dir/*.md` over a glob matching nothing (dir absent, or present with no `.md`) does NOT return clean-empty — the unmatched glob is passed LITERALLY to grep, which fails: `No such file or directory`, **exit 2** (grep error). Distinct from a real no-match: grep over an existing file with no hit = **exit 1**. Verified: bare grep on absent dir → 2; `[ -d dir ] && ls dir/*.md >/dev/null 2>&1 && grep …` on absent dir → 1 (`[ -d ]` false, short-circuits, grep never runs); grep on present-but-empty registry → 1. exit 2 = grep error; exit 1 = guard-skip OR clean no-match.
- **Context**: analyze-before-plan include ([[BDR-035]]). DO step said "absent → no-op" but the bare grep would ERROR at init-project STEP 2 (registries created STEP 5, absent at analyze). Caught by exec-test, not assumption.
- **Future application**: any glob-fed scan that must no-op on "nothing there" — guard `[ -d dir ]` (+ file-exists) BEFORE the glob; never assume grep degrades. Exec-test the absent/empty case.
- **Reference**: `lib/analyze-before-plan.md` (PASS 1 guard). Sibling to [[LRN-051]] (exec-test tool behavior, never assume). See [[BDR-035]].

## LRN-057 — Match the consumption mechanism to the consumer (mechanical / external-cognitive / inline-cognitive)

- **Date**: 2026-06-26
- **Pattern**: When a produced artifact must be CONSUMED downstream, the mechanism depends on the consumer: (a) MECHANICAL (git merge integrating a branch) — production on the shared substrate = consumption, automatic ([[BDR-034]]'s "commit before FINISH"); (b) EXTERNAL-COGNITIVE (an unmodifiable skill like `superpowers:brainstorming`) — "produced before" ≠ "consumed"; INJECT the artifact into the consumer's INPUT at the invocation boundary (orchestrator = adapter) + a RECONCILIATION gate that EXPOSES the disposition for review (not auto-detect); (c) INLINE-COGNITIVE (same agent reads then plans) — reader=planner, same context → natural consumption, just force the trace ([[LRN-053]]). Don't import (b)'s machinery where (c) suffices, nor assume (a)'s automatism when the consumer is cognitive.
- **Context**: analyze-before-plan ([[BDR-035]]). ship-feature brainstorm = external-cognitive → STEP 0d injection + STEP 3 expose-for-review gate; feat/bugfix = inline-cognitive → natural + trace, no injection. The asymmetry vs [[BDR-034]] (mechanical merge) was the chantier's hardest point.
- **Future application**: wiring ANY produce→consume invariant — classify the consumer first (mechanical / external-cognitive / inline-cognitive), pick the lightest sufficient mechanism. Stops reflexively importing orchestrator-grade injection+gate where an inline trace would do.
- **Reference**: `skills/ship-feature/SKILL.md` STEP 0d/1/2/3, `agents/bugfixer.md`+`feater.md`. Contrast [[BDR-034]] (mechanical). See [[BDR-035]], [[LRN-053]].

## LRN-058 — Same bug-class ≠ same fix: verify the twin shares the fix's PRECONDITION before replicating

- **Date**: 2026-06-27
- **Pattern**: A deferred "twin" fix ("doc-sync = same PR bug → reorder before FINISH like memory") REFUTED on inspection: memory's reorder worked because memory ALREADY committed (helper existed, only timing wrong); doc-syncer committed NOTHING → reordering uncommitted docs still misses the merge. The fix relied on a PRECONDITION (artifact already committed) the twin did NOT share. "Same symptom" ≠ "same mechanism". A read-phase grep (zero git commit in doc-syncer) caught it before any code — saved shipping an illusion-of-fix.
- **Context**: doc-sync coupled ([[BDR-036]]). The chantier's central lesson; the user named the trap upfront ("même bug ≠ même fix").
- **Future application**: any "fix X like we fixed Y" — NAME Y's load-bearing precondition, CONFIRM X has it, before replicating. Cheap read-phase check beats a shipped non-fix.
- **Reference**: [[BDR-036]], [[BDR-034]].

## LRN-059 — A step-number SWAP flips meanings → sweep external refs; a letter-suffix insertion shifts nothing

- **Date**: 2026-06-27
- **Pattern**: Renumbering a pipeline has two shapes, opposite ref-risk. (1) SWAP (STEP 8↔9 = FINISH↔DOC SYNC) flips what each number MEANS → every external ref can go silently false OR accidentally true; grep the WHOLE repo, read each hit individually. PROVEN: ship-feature's swap silently broke README:153 — which a PRIOR chantier's swap had ALSO broken (e8eff7e moved DOC SYNC 8→9, missed the ref) → debt COMPOUNDS across chantiers. (2) LETTER-SUFFIX insertion (10b, 0d) shifts NO existing number → breaks nothing (init-project's 10b left zero stale refs). Discipline: prefer letter-suffix insertions; on a swap do a full external sweep + per-ref verify; COMPLETE an accidentally-true ref (don't lean on the coincidence — it re-breaks at the next swap).
- **Context**: doc-sync coupled ([[BDR-036]]). The Task-6 sweep caught README:153 (prior debt) + verified 5 USAGE refs post-swap.
- **Future application**: any pipeline renumber — classify swap vs insertion; swap → grep+read every ref. The external sweep catches PAST chantiers' debt, not only the current one.
- **Reference**: [[BDR-036]]. Sibling [[LRN-002]], [[LRN-045]] (grep reads not just writes).

## LRN-060 — A fail-closed guard is proven by what it REFUSES (loudly); pass dynamic lists as argv, not a separator-string

- **Date**: 2026-06-27
- **Pattern**: Two robustness lessons from doc-commit. (a) The inverse-`.claude/` exclusion is a SECURITY guard (BDR-022) → test it by what it must REFUSE (forbidden path ALONE, and MIXED with legit), not only what it accepts; and refuse LOUDLY (dedicated exit 4, names the offender, refuse-ALL on mixed) — silent-filtering would MASK an upstream violation (doc-syncer surfaced a `.claude/` it must never patch). The refusal IS the alarm. (b) Pass a dynamic file list as ARGV, never a separator-joined string: argv has no in-band delimiter → a path with spaces survives as one element (proven, T7); newline is only the producer's text format the agent maps to argv. Space-join-then-resplit would mis-split + the `[ -e ]` filter then silently drops it.
- **Context**: doc-commit.sh ([[BDR-036]]), T1a/b/c (refuse paths) + T7 (argv space-safe), all real-exec.
- **Future application**: any automated scoped-commit / destructive guard — test the REFUSAL path + refuse loud; pass lists as argv. Same family as [[LRN-046]] (deterministic oracle for a destructive guard).
- **Reference**: [[BDR-036]], [[LRN-051]] (changed-paths filter), [[LRN-046]].

## LRN-061 — Runtime net proposed for an unwired skill → check the wiring first

- **Date**: 2026-06-27
- **Pattern**: Tempted to build a runtime guard/hook/monitor that watches for a bad OUTCOME (memory written but uncommitted)? First ask if the outcome is a MISSING WIRING, not a behavioral lapse. A per-turn Stop-hook was proposed to catch "dirty memory" — but the cause was `/capitalize`+`/close` not calling the commit include (they predate it). Fix for an unwired skill = WIRE it (deterministic, zero-noise, at source); a monitor over a wiring hole pays RECURRING cost to detect a ONE-TIME omission, and a frequent ignored nag is itself a risk ([[LRN-047]]). **NOT "runtime nets are bad"** — the split is by DETERMINISM: a MISSING WIRING is deterministic → repair structurally; a genuinely NON-DETERMINISTIC aléa → a runtime net IS the right tool. Good counter-example: [[BDR-033]] anim-lib nudge — "will the user want motion?" is unknowable statically → a stateless 1-line suggestion is correct. Same determinism test as [[LRN-046]]/[[LRN-049]], applied to the build-or-not question.
- **Context**: deferred "v2 capitalize hook" ([[BDR-037]]). Read-phase killed it before code: git proved skills predate the include (oubli), memory already committed by hand 35×, orphans self-heal via `commit_memory`. The hook would've been disabled within an hour (frequent ignored nag).
- **Future application**: any "build a hook/watcher/lint to catch when X isn't done" — first grep whether X is even WIRED at its source. Deterministic/structural gap (missing include/call) → fix structurally; reserve runtime nets for non-deterministic lapses, never to complete a rollout. Classify by determinism BEFORE building.
- **Reference**: [[BDR-037]], [[BDR-034]] (rollout this completes), [[BDR-033]] (the GOOD net — contrast). Conditions [[LRN-047]], [[LRN-049]], [[LRN-054]].

## LRN-062 — deploy first-run detection = file-existence, never `git describe`
- **pattern**: detect "first deploy / no prior marker" by `[ -f .claude/deploy/STATE.json ]` (deterministic). NEVER `git describe --tags --match 'deploy/*'` — it errors `fatal: No names found, cannot describe anything`, exit 128, when no matching tag exists (verified git 2.53). Oracle = committed `STATE.json` holding `deployed_sha` (external ledger; never infer from context — [[LRN-054]]).
- **context**: deploy skill design. The describe-128 result is only the REASON NOT to use describe — never the detection path.
- **future application**: any "first run vs incremental" tool — detect by an explicit on-disk marker's existence, not by a git query that errors on the empty case.

## LRN-063 — delta-since-marker = `git diff --name-only <base> HEAD` (two endpoints), never rev-list/three-dot
- **pattern**: "files changed since marker X" = `git diff --name-only <X_sha> HEAD` — two explicit endpoints = literal tree diff. NEVER `git rev-list X..HEAD` (ancestry → phantom deltas after rebase: an orphaned marker yields the whole history). NEVER three-dot `X...HEAD` (merge-base → UNDERCOUNTS on divergence). Verified git 2.53 (linear: all forms agree; diverged: two-dot = both sides, three-dot = one side only).
- **context**: deploy delta mechanism. Footgun: `git diff A..B` ≡ `git diff A B` (two endpoints), but `rev-list A..B` = ancestry — same `..` token, different meaning per command.
- **future application**: any delta-since-checkpoint over git — explicit two endpoints for the tree diff (artifact list); reserve `rev-list` for commit-counting only.

## LRN-064 — surgical-commit helper family partitions `.claude/`; a new subtree needs its own allowlist sibling
- **pattern**: the surgical-commit helpers each own a `.claude/` partition by OPPOSITE rules — `memory-commit.sh` ALLOWLISTS `.claude/memory`+`.claude/tasks`; `doc-commit.sh` EXCLUDES all `.claude/**` (loud rc 4, BDR-022 — [[LRN-060]], [[BDR-036]]). So committing a NEW `.claude/` subtree (e.g. `.claude/deploy/`) can reuse NEITHER: doc-commit refuses it, memory-commit ignores it. Verified live: real `doc-commit.sh` → rc 4 on `.claude/deploy/PROCEDURE.md`. Solution: mint a sibling (`deploy-commit.sh`) with a TARGET allowlist for the new subtree — guard order = traversal `*..*` reject FIRST, then `.claude/deploy/*` allow, else refuse. Inherit rc 3 unsafe-git, short-hash stdout, changed-paths filter.
- **future application**: adding a committable `.claude/X` subtree → new allowlist sibling, don't bend an existing helper; order the path guard traversal-first.

## LRN-065 — cross-session cold-resume skill = disk-bridge read-first (audit-delta convention)
- **pattern**: a skill that hands BACK control mid-flow (user acts out-of-band) and RESUMES — possibly in a NEW session, context gone — must carry ALL resume state on disk. A bridge file's PRESENCE = the wait-marker ("in flight, awaiting report"); STEP 0 reads it FIRST and resumes from its captured `{base, target, delta, step_reached}` WITHOUT recomputing (HEAD may have moved during the gap → "current HEAD" is wrong). Convention = audit-delta "the state file is the only memory between runs", extended from run-to-run to a MID-FLOW pause. `client-handover` only pauses in-context (synchronous), NOT cold — deploy is the first cold-resume form. A `runbook_rev` (FULL sha) does double duty: in-flow regenerate trigger + cold-resume staleness check; regenerate the instantiated artifact if ABSENT or stale. Pressure-test confirmed (fresh agent resumed from the bridge, excluded the moved-HEAD temptation).
- **future application**: any "do work → user acts out-of-band → resume later" skill — persist a disk bridge, read it first, never recompute on resume; mark the wait by the bridge's existence, not by conversation context.

## LRN-066 — surgical-commit must fail LOUD on git-ignored target paths (else silent no-op)
- **pattern**: `git status --porcelain -- <path>` HIDES git-ignored paths → a surgical-commit helper that filters changes via porcelain SILENTLY no-ops (rc 1) when the target project ignores the path (e.g. `.claude/` wholesale) → the artifact never persists, the skill silently forgets. Fix: guard with `git check-ignore -q <path>` BEFORE the changed-filter; any passed path ignored → LOUD refusal + dedicated rc (5), never a silent no-op. Fail-closed/loud over silent. (Same porcelain mechanism as the changed-filter — [[LRN-051]].)
- **context**: `deploy-commit.sh`; the FINAL whole-branch review caught it (per-task reviews could not — it is a skill↔target-repo seam). Applies to the whole memory/doc/deploy-commit family.
- **future application**: any helper relying on `git status --porcelain` to detect changes — add a `git check-ignore` guard; a path that must persist but is ignored has to fail loud, not no-op.

## LRN-067 — a pipeline that looks 2-level can finish at the SAME level; a human-mediated step masks the collision until automated
- **pattern**: an orchestrator delegating to a sub-skill can LOOK two-level (sub assembles parts, orchestrator integrates) yet the sub's TERMINAL node operates at the SAME level as the orchestrator's own finish → double-integration. `subagent-driven-development` assembles tasks on ONE branch (no per-task sub-branches — true) BUT its last flowchart node IS `finishing-a-development-branch` = feature→base merge, the SAME act as the orchestrator's FINISH. init-project (STEP 8 SDD + STEP 11 finish) AND ship-feature (STEP 4 SDD + STEP 9 finish) BOTH invoked finish TWICE. Latent, not visibly broken: SDD's terminal finish is INTERACTIVE (menu → human picks "keep as-is"), so the human SILENTLY de-duplicated. Collision SURFACES the moment the orchestrator's finish becomes DETERMINISTIC (gitflow finish) → real double-merge. Fix = scope the sub-skill by instruction to stop before its terminal step (NO fork — the finish is a flowchart node the controller follows, not a script; verified by reading SDD's scripts). Pressure-test: RED agent chained the finish ("literal next node in the flowchart"); GREEN with the scope instruction stopped + returned.
- **context**: gitflow chantier, wiring orchestrators onto `gitflow finish`. Mapping (premise #6) caught it by READING the real (SDD `SKILL.md` + `scripts/`) BEFORE coding — the seam-bug class `deploy` hit, caught earlier this time. Two human-gate backstops survive a missed instruction: SDD's interactive menu + the `gitflow finish` human gate ([[LRN-054]] — no oracle; deterministic layer carries the dangerous case).
- **future application**: before replacing an interactive/human-mediated step with a deterministic one, check whether a delegated sub-skill's TERMINAL step operates at the same level — the human gate may have been silently de-duplicating a double-action. Read the sub-skill's real flow (nodes + scripts), don't assume "distinct levels".

## LRN-068 — enforcement-bootstrap must be transactional: activate the guard LAST and gate it on the bootstrap commit succeeding
- **pattern**: a routine that BOTH installs an enforcement guard (pre-commit hook, branch protection, lock) AND makes a bootstrap commit must be transactional, else a partial run strands it. Two teeth: (a) precheck preconditions (git identity, clean tree) and fail LOUD before ANY mutation; (b) the guard-activation step must NOT run if the guarded bootstrap commit failed — order activation LAST and gate it on commit success. A `cmd_a || cmd_b` form SWALLOWS cmd_b's failure when a later stmt returns 0 → the failure never propagates; use explicit `if ! …; then … || return 1; fi`.
- **context**: `gitflow_init` ([[BLK-012]]). Existing-repo path swallowed the socle-commit failure (`git diff --cached --quiet || git commit`, then `git branch develop` returned 0 masking it) → init CONTINUED and ran `gitflow_activate_hook` though the socle was never committed → every re-run self-blocked (commit on main blocked by the hook just installed). Fresh-repo path already propagated → the asymmetry was the bug. Fix: fatal socle commit + identity precheck; verified on an identity-less repo → aborts rc1 with ZERO mutation, 57/57 tests green.
- **future application**: any init/bootstrap installing enforcement (hooks, protection, immutability) + committing — activate LAST, gate on the commit, precheck identity/clean-tree up front, make every link propagate (no `||` swallow). TEST the partial-failure path (identity-less / commit-blocked repo) → must abort with zero mutation and stay re-runnable.

## LRN-069 — token-authed remote writes under CC perms: inline-env (never `export`), token in the header, keep `git push` on ASK as the real gate
- **pattern**: a secrets-guard `Bash(export *)` in `permissions.deny` auto-denies ANY command whose FIRST token is `export …` — a false positive (`export GIT_CONFIG_VALUE_0="Authorization: token $TOK" …` reads as blocked when only the `export` prefix tripped it, not the git/curl op). Correct model for token-authed remote writes from tool calls: (a) INLINE env assignment `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.extraHeader GIT_CONFIG_VALUE_0="Authorization: token $TOK" git push …` (no `export` keyword → passes; token rides the http header via git env-config, NEVER in argv nor written to the clone's `.git/config`); (b) keep `Bash(git push *)` on ASK (not deny) — that prompt IS the per-write human gate; don't suppress it, don't allow-list pushes in settings.
- **context**: gitflow migration on Gitea. 3 consecutive tool-call denials traced to `Bash(export *)` (false positive); an earlier INLINE-env `ls-remote` passed; the user's own `!` shell ran the same `git push` fine (not under CC perms). Confirmed `git push` is ASK by design = the right gate locus, NOT `export *`.
- **future application**: scripting token-authed git/curl writes under CC perms → inline env (never `export`), token in `Authorization` header (curl `-H`, git `GIT_CONFIG_*` extraHeader), keep `git push` on ASK as the approval. Tool-call denied unexpectedly → read `permissions.deny` for an over-broad prefix rule (`export *`, `env`, `printenv`) catching a false positive BEFORE concluding the op itself is blocked.

## LRN-070 — clean-tree-gated migration + a dirty submodule: diagnose pointer-vs-content, ignore=dirty not blind reset
- **pattern**: an op gated on a clean tree (`git status --porcelain`) is blocked by a submodule showing ` M`. FIRST distinguish: (a) **pointer move** — gitlink (HEAD) ≠ submodule HEAD → resettable via `git submodule update`/`checkout`; (b) **dirty content** — gitlink UNCHANGED, files modified INSIDE the submodule → a local edit. For an intentional local edit, `checkout --`/`submodule update` correctly REFUSE to discard it, and a blind "reset" would DESTROY it. Exclude it non-destructively: `git config submodule.<name>.ignore dirty` (local `.git/config`) → status stops reporting the submodule's dirty content, gate passes, edit preserved. Commit it to `.gitmodules` to share the ignore across clones.
- **context**: claude gitflow self-migration. `skills-external/gstack` showed ` M`; gitlink `070722a` == submodule HEAD `070722a` (NOT a pointer move), 2 tracked-modified files (`bun.lock`+`package.json`) = the [[BLK-008]] Playwright 1.61 bump (Ubuntu 26.04 browser). The planned "reset" (D2) would have discarded the browser fix; `submodule.skills-external/gstack.ignore=dirty` cleared the tree for `migrate_local`, bump intact.
- **future application**: any clean-tree-gated op (migrate/release/bisect) on a superproject with a submodule carrying intentional local edits → diagnose pointer-vs-content FIRST (compare gitlink to submodule HEAD); for content, `submodule.<name>.ignore=dirty`, never a blind reset. Cross-ref [[BLK-008]] (gstack -dirty by design).

## LRN-071 — fail-loud must cover the helper's OWN commit, not just its inputs — 3rd occurrence of the swallowed-commit pattern
- **pattern**: a surgical-commit helper guarded LOUD on its INPUTS (scope) but SILENT on its OWN `git commit`. `doc-commit.sh`: `set -uo pipefail` (no `-e`) + unguarded `git commit` → on rejection (pre-commit hook on a protected branch / signing / etc.) execution CONTINUES: `printf "committed"` lies, `git rev-parse --short HEAD` emits the PREVIOUS HEAD hash, function exits 0. Orchestrator reads rc 0 + non-empty hash → believes success; docs silently uncommitted, tree dirty (RISK-2).
- **RECURRENT (3×) — audit systematically, not an isolated bug**: same fail-silent-where-it-must-fail-loud class in the surgical-commit family — [[LRN-066]] (`deploy-commit.sh`: porcelain hides a git-ignored path → silent no-op; fix = loud rc 5) + [[LRN-068]]/[[BLK-012]] (`gitflow_init`: socle-commit failure swallowed by `||` then `git branch` returned 0 → init continued past the dead commit) + this. The common mechanism: a fallible op (esp. a commit) whose failure isn't propagated, MASKED by a later returning-0 statement. The motif RETURNS; treat it as a known smell.
- **fix**: guard the commit — `if ! git commit …; then LOUD + return 5; fi`. rc 5 = "tried, git refused" (distinct from rc 3 = "could not start"). Empty stdout (no stale hash), loud stderr. Proven by T8: RED showed the masking (rc 0 + stale hash + false "committed"), GREEN rc 5 + empty + REJECTED, 32/32.
- **future application**: any helper whose RETURN VALUE gates a downstream "success" — audit that EVERY fallible internal op propagates its failure, ESPECIALLY the load-bearing commit. `set -uo pipefail` without `-e` does NOT abort mid-function; an unchecked failing command followed by a returning-0 line exits 0 and lies. Check `cmd || other` forms, no-`-e` blocks, every "report success after the op" line. Test the partial-failure path (commit-blocked repo) → must fail loud, empty, non-zero.

## LRN-072 — a stranded-artifact bug can be fixed by NOT creating the artifact (negative diff), not by plumbing its commit
- **pattern**: 3rd member of the post-FINISH-artifact class (memory, docs, GSD ROADMAP) — but UNLIKE the first two (real artifacts ALWAYS produced → couple a commit), the GSD artifact came from a SPECULATIVE, opt-in, rarely-used producer (init-project auto-bootstrapping a multi-session engine at project creation). The reflex fix (reorder + build `gsd-commit.sh` + tests) would have added machinery to faithfully commit an artifact nobody uses. The right fix was a NEGATIVE diff: delete the producer → orphan never created → bug dissolves, zero new code (BLK-011).
- **the refutation that got there**: the framing "ROADMAP redundant with TODO" was WRONG (gsd ≫ roadmap = state machine/crash-recovery/cost/parallel/worktree; TODO ≠ gsd ROADMAP = different altitude + consumer). Reading REFUTED both premises, yet the CONCLUSION (remove the step) held for a STRONGER reason: speculatively scaffolding a heavy engine the sole user doesn't use, at creation, is bad per se. Right answer, reason corrected before engraving — change the QUESTION before changing the code.
- **future application**: a stranded / duplicated / uncommitted-artifact bug → BEFORE building machinery to handle the artifact, ask whether the step that PRODUCES it is actually used / wanted / non-speculative. Speculative or unused (esp. a personal/single-user repo) → DELETE the producer; the cleanest fix is the absent one. Distinguish speculative-at-creation (REMOVE) from deliberate-on-demand (KEEP). Family: [[BLK-010]], [[BLK-011]], [[BDR-036]].

## LRN-073 — a skill's worked-example must use FICTIONAL ids, never live registry ids (they prime real-data behavior)
- **pattern**: prune-memory's STEP-2 plan example named real LRN-014 + LRN-016 ("merge these"). A real-data run merged exactly that pair — though they're COMPLEMENTARY (header-ids vs checkbox-CSS), a merge its own rule forbids. Example ids that match live entries, in context at audit time, PRIME the action: you can't tell "judged correctly" from "pattern-matched its own example".
- **fix**: fictionalize example ids (9xx — can't match a live registry) + make the example model a CORRECT action. Lock it DETERMINISTICALLY ([[LRN-046]]): assert the example carries only fictional ids — not a flaky behavioral "did priming fire" test (RED-7).
- **future application**: any skill/agent whose instructions contain a worked example over the SAME data it operates on (registries/files/records) → use reserved/fictional identifiers; test deterministically that no live id appears in the example block.

## LRN-074 — system `grep`/`awk` may be ugrep/mawk: don't assume flag-parsing, use `/usr/bin/grep`, watch the RED go red
- **pattern**: a RED-7 test used `grep -vE '-9[0-9][0-9]$'`; the system grep is UGREP → parsed the leading `-9..` as an OPTION → errored → empty → FALSE GREEN (a RED that never goes red). Caught only because the output was READ, not assumed. 4th time this session an assumed command behavior was false on execution (after `set -o pipefail` + `grep -q` SIGPIPE, …). The skill's own verify already hard-codes `/usr/bin/grep` (line 189) for this exact reason — re-learned.
- **fix**: `/usr/bin/grep` (GNU) where GNU semantics matter; avoid leading-dash regex args (or use `-e`/`--`); never trust the system tool is GNU/POSIX (mawk≠gawk, ugrep≠grep).
- **future application**: any shell test/guard whose correctness rides on grep/awk/sed semantics → pin `/usr/bin/<tool>` AND run the assertion, confirming it goes red on the defect before trusting green. Execute, don't assume command behavior. RECURRENT motif — audit any "assumed tool behavior" the way the fail-silent family ([[LRN-066]]/[[LRN-071]]) is audited.

## LRN-075 — skill-vs-no-skill RED must test the UNGUIDED control, not a leading one
- **Date**: 2026-06-30
- **pattern**: building `/reconcile`, the first baseline ("repo git — use git + justify each item") made a capable agent reconcile correctly → CONTAMINATED RED (writing-skills: control doesn't exhibit the failure → nothing to fix). Real failure surfaced only on the UNGUIDED tempting prompt ("is the queue empty?", todo-pointed, no git hint): agent MIRRORED the TODO — stale `[ ]` reported open (false positives), decisions.md never opened, contradiction missed. Variance: one rep FLAIRED staleness but wrote a disclaimer ("à vérifier") instead of verifying — a disclaimer is not a verification.
- **why**: skill value was never "teach an agent to reconcile" (it can, guided) — it is determinism + cheapness + gate ([[LRN-031]]), so the answer never depends on phrasing or whether the agent felt like checking git. Confirmed engine-heavy / skill-thin design.
- **future application**: any skill-vs-no-skill / TDD RED — the control must REMOVE guidance AND tempt the failure ([[LRN-028]] sibling). Unguided control still succeeds → don't author (or rescope to determinism/gate). The skill also helps the agent who SUSPECTS but doesn't verify, not only the ignorant one.

## LRN-076 — append-only registry status mutates in place: LAST block wins
- **Date**: 2026-06-30
- **pattern**: a BLK entry evolves via `UPDATE`/`FINAL` blocks (BLK-008: `resolved` → middle `REVERTED, UPSTREAM/open` → `FINAL — RESOLVED`). A guided baseline read the MIDDLE block → reported BLK-008 upstream/open, wrong. Current status = the LAST status-bearing line in the body, never the Index, never the first. Bonus bug the harness caught mid-build: a `sed` range inclusive of the NEXT entry's header bled a sibling's status word (BLK-005 header "...upstream rename" polluted BLK-004) → drop `^## BLK-` header lines before extracting.
- **future application**: parsing any in-place-mutated status (blockers, revision blocks) — take the LAST status line, bound the entry EXCLUSIVE of the next header. Don't trust Index/first-line.

## LRN-077 — test fixtures must carry NEUTRAL names (pass for the right reason)
- **Date**: 2026-06-30
- **pattern**: a baseline agent on a worktree named `wt-pre-reconcile` read "pre-reconcile" FROM THE DIR NAME and inferred staleness — reasoning for the WRONG reason (the name), not the right one (verify git). Fixtures + the GREEN test were re-frozen under NEUTRAL names so the engine reaches truth by querying git, never by reading a path hint.
- **meta — same symptom, distinct cause as [[LRN-074]]**: 074 = a COMMAND-ASSUMPTION (ugrep parsed `-9..` → false green); 077 = a LEAKY FIXTURE (name telegraphs the answer). Different mechanisms, SAME symptom: the test passes/fails for the wrong reason. Cross-cutting lesson = verify a test passes for the RIGHT reason, not merely that it passes — whether the false signal comes from an assumed command (074) or a leaky fixture (077).
- **future application**: name fixtures/paths neutrally; for any green, ask "did it pass because the subject did the work, or because something leaked the answer?"
- **corroboration 2026-07-02 (T6c)**: 3rd family member — test truth borrowed from TRANSIENT env state. run-reconcile T6c asserted `$MEM/../skills/darwin-skill` = `.claude/skills/` (the [[LRN-042]] parasite dir), not canonical `skills/`; born green because the parasite still existed, red since the same-day cleanup, unnoticed until the 2026-07-02 audit re-ran the suite ([[EVAL-011]]'s "20/20" silently 19/1 for 2 days). Oracles target CANONICAL paths (never derived `X/../Y`); re-run suites after ANY env cleanup tests may have silently depended on; "green at build" ≠ "green now".

## LRN-078 — semver number DERIVES from the change nature; "breaking" = requires a migration
- **Date**: 2026-06-30
- **pattern**: framing a release as "it's 4.0.0 → find the breaking changes to justify it" is backwards. Semver runs the other way: the number FOLLOWS the nature of the changes. The real question = "is there a breaking change?", not "how do I justify the target". Solo / mono-user repo, no public API ⇒ "breaking" = casse mon propre usage / EXIGE une migration de ma part.
- **applied (v4.0.0)**: gitflow universal = a TRUE breaking workflow change (master→main, mandatory branches, hook, 6-repo migration) → MAJOR on its own. caveman removal = VERIFIED nothing invoked it (grep: only the kept memory format-rule + frozen fixtures, settings/hooks clean) → a clean `### Removed` (capability gone, nothing breaks, no migration), NOT breaking. The MAJOR rests on gitflow alone; don't mislabel a removal as breaking.
- **future application**: pick MAJOR/MINOR/PATCH from the changes, then the lineage gives the digits. Verify "does X actually break / require migration?" from the refs (grep), not from the size of the change or the desire for a round number.

## LRN-079 — orchestrator-skill TDD: replay the flow on a throwaway repo, RED = flow minus the new step
- **Date**: 2026-06-30
- **pattern**: a thin orchestrator skill (composes an existing tested mechanic + ONE new step) is not unit-testable as a function, but its FLOW is testable by replay on a throwaway repo (gitflow-test style). RED = run the prescribed sequence WITHOUT the new step (the existing mechanic alone) and assert the desired outcome → it reds on exactly the gap. GREEN = add the step. For `/release-candidate`: `gitflow start release`→prep→`finish` (no tag) → assert `vX.Y.Z` on main → REDS (gitflow fans out but never tags); add `git tag` → 5/5. Teeth: the single toggled line (`RC_TAG`) flips red↔green so GREEN can't pass by accident.
- **future application**: for any orchestrator over a lib mechanic, test the END-TO-END flow on a disposable repo; isolate the NEW step so the RED reds precisely on it (don't re-test the lib's generic part — it has its own tests).

## LRN-080 — measure whether the model already does X before adding an instruction to make it do X
- **Date**: 2026-06-30
- **pattern**: the --help chantier (implement [[BDR-001]] as a global CLAUDE.md instruction "on --help → render help + stop") was KILLED by its behavioral RED. Before writing a line, measured the control (6 reps, `/web-validate` + `/harden`, no instruction): **6/6 already rendered rich help AND stopped without dispatching** — the supposedly-absent behavior was fully present. Residual value = format consistency across 6 divergent shapes → not worth ~5 lines in a compressed CLAUDE.md on a solo repo. A phantom-value addition avoided.
- **why it matters**: [[LRN-075]] (test the UNGUIDED control) paying off one chantier later — measuring the RED before building is what caught it. For UNIVERSAL conventions the model already honors (--help, common flags, standard shapes), a "teach it to do X" instruction buys nothing but tokens; the only thing left to buy is consistency, which must clear its own ROI bar.
- **future application**: before adding any global instruction to ELICIT a behavior, run the behavioral control first — does the model already do it unaided? If yes, the only remaining value is standardization; price it honestly vs the cost (esp. a compressed CLAUDE.md). Often: don't add it.
- **corroboration 2026-06-30**: 3 consecutive "make the model do X" chantiers — --help ([[BDR-001]]), darwin re-baseline ([[BDR-043]]/[[LRN-082]]), auto-skill-dispatch ([[BDR-044]]) — ALL measured won't-build/moot. A backlog of "add instruction to elicit behavior Y" has a high phantom-value rate (universal conventions + aggressive existing mandates like superpowers L1 already elicit Y) → sweep such backlogs measure-first, expect kills.

## LRN-081 — Commit trailers: Claude-COMPOSED content only, never on staging of user-authored text
- **Date**: 2026-06-30
- **pattern**: the Claude commit trailers (`Co-Authored-By: Claude …` + `Claude-Session: …`) mark Claude's ACTUAL contribution. They belong on commits whose CONTENT Claude composed — memory entries, code, docs, TODO lines drafted from intent/BDRs. A commit that merely STAGES content the USER wrote (queuing the user's own raw note) gets NEITHER trailer — author = the user, clean. Staging ≠ authorship.
- **why it matters**: memory-commit.sh + the dev flows append the trailers BY DEFAULT → committing user-authored text through them mis-credits Claude on every note/spec the user writes. A `Claude-Session:` on a 100%-user addition is traceability noise pointing at no Claude contribution.
- **context**: 2026-06-30 — user's `auto-skill-dispatch` planning note committed `chore(todo)` CLEAN, no trailer (`e591510`, author Bastien Chanot); vs `chore(memory)` BLK-013/BDR-043 (`5b03ac2`) WITH trailers (Claude composed those entries). The split IS the rule.
- **future application**: before committing on the user's behalf ask "did Claude COMPOSE this content?" Composed (entry/code/doc/TODO-from-intent) → trailers. Merely staging user-written text → no trailers, user-authored. Self-referential proof: this entry + the promoted TODO follow-ups = Claude-composed → trailers OK on their commit.
- **correction 2026-06-30**: the mechanism claim above ("memory-commit.sh appends trailers by default", body + Index cell) is WRONG. `memory-commit.sh` does NOT append trailers — it commits `git commit -m "$msg"` verbatim (`memory-commit.sh:86`; trailer-agnostic; no `commit.template`, no `prepare-commit-msg` hook). Trailers are MODEL-composed message content (harness git-commit convention). Control point = the composed MESSAGE, not the helper. Proven live: a bare one-liner through the helper (`532ae69`) landed with ZERO trailers → had to amend (`c09f2b2`). Teeth = consciously ADD trailers on Claude-composed commits + OMIT on user-staging; the helper enforces NEITHER. The PRACTICAL guidance above (composed→trailers, staged→none) stays correct — only the mechanism was wrong; the false entry already mis-led one commit (the bare-msg miss). DEFERRED to /prune-memory: rewrite the false "helper appends" wording in this body + the Index cell (curation = not append-only → wrong tool here); this bullet marks WHAT to clean.

## LRN-082 — Trigger-cleared on a MULTI-MOTIF exclusion lifts only the NAMED motif — re-check the others before acting
- **Date**: 2026-06-30
- **pattern**: an exclusion justified by ≥2 independent grounds lifts only for the ground that actually changed. A "trigger cleared / precondition gone" note naming ground A leaves ground B in full force. Geometric trigger lifted ≠ value trigger lifted; acting on cleared-A without re-checking B = false unblock.
- **why it matters**: [[BDR-015]] excluded 5 gstack skills from /darwin-skill on TWO grounds — (a) broken symlinks AND (b) external ownership (never modify a third-party submodule). [[BDR-043]] cleared (a) only (symlinks repaired, 0 broken) → marked re-baseline "unblocked". (b) intact: darwin optimizes by EDITING SKILL.md → would edit the gstack submodule = forbidden ([[LRN-070]]). Re-baseline = a score we can't act on → phantom value.
- **context**: 2026-06-30 — measure-first: searched for results.tsv instead of assuming → GONE (wiped by 23/06 make-plugin reinstall) → no baseline survives + (b) never lifted → action resolved-MOOT, not run. Twin of [[LRN-080]] (--help): trigger fired, measurement showed phantom value (distinct mechanism: there value-absent, here residual-motif).
- **future application**: before acting on any "exclusion lifted / precondition cleared", enumerate ALL original grounds and verify EACH is gone — not just the one the trigger names. Cleared-A says nothing about B.

## LRN-083 — Subagents are an INVALID instrument for measuring MAIN-LOOP spontaneous routing
- **Date**: 2026-06-30
- **pattern**: to measure whether the MAIN loop self-invokes a skill on implicit intent, dispatched subagents are non-discriminating — SUBAGENT-STOP tells them to SKIP the L1 routing mandate, and a delegated-execute framing suppresses meta-routing → they hand-do the task regardless of how strong/weak the main-loop prose is. Result pins to the no-route FLOOR (artifact, not signal). Complement of [[LRN-028]] (there subagents OVER-saw installed skills, invalidating a no-skill baseline; here they UNDER-route, invalidating a routing-measurement) — both = subagent ≠ main-loop condition.
- **why it matters**: a 0/N subagent RED reads as "under-triggers → build the chantier" but is the [[LRN-028]] trap — the instrument can't tell strong prose from weak. Concluding from it = a pass/fail for the WRONG reason ([[LRN-074]]/[[LRN-077]]).
- **context**: 2026-06-30 auto-skill-dispatch RED. 6 subagents on toy implicit-intent tasks → 0/6 routed → RETIRED as non-discriminating, NOT reported as a number. Reframed; measured instead in REAL fresh main-loop sessions.
- **future application**: measure main-loop spontaneous routing/discernment in FRESH main-loop sessions (full L0–L4, no SUBAGENT-STOP, real user-turn). Observable instrument = the HUMAN typing the prompts + watching live — cron/schedule-spawned fresh sessions are the right CONDITION but UNOBSERVABLE to the orchestrator (they notify the owner, not the dispatcher), so they can't be the measurement vehicle. Never substitute a subagent for a fresh session in a routing RED. See [[LRN-028]], [[LRN-075]], [[LRN-080]].

## LRN-084 — A protection hook enforces PROD safety, not the full branch-flow — the exemption masked the rule-vs-guard divergence

- **Date**: 2026-07-01
- **pattern**: the gitflow pre-commit hook is a PROTECTION guard (block code on main/develop), NOT a flow enforcer. It exempts `.claude/**` and can only test "on a protected base" — it can NEVER verify "branched FROM develop" (no base knowledge). So "every change via a branch from develop" is only HALF-encoded by the hook; the base half lives solely upstream in `gitflow_start`. The exemption is scoped to the SIDE-CAR ([[BDR-034]]); it has no branch to follow when memory IS the work → standalone memory fell back to `main`.
- **why it matters**: a multi-repo raccord committed 5 `chore(memory)` direct on `main` and NOTHING flagged it — nothing was violated, the exemption worked as designed. The divergence was guard (declares PROD protection) vs intended rule (all via branch); the exemption MASKED it, the raccord revealed it by violating the unencoded half. A guard encoding only PART of the intent reads as full enforcement — a false-green.
- **future application**: when a guard exempts a class or checks one predicate, ask what it does NOT encode and whether a human leans on it for MORE than it enforces. Enforce the unencoded half where it actually lives (the aiguillage at skill start, [[BDR-045]]), do not push it into a guard that structurally can't hold it. Verify the guard's real scope against the rule's full scope before trusting "it would have caught it." See [[BDR-034]], [[BDR-045]], [[LRN-034]].

---

## LRN-085 — Idempotent CLI install/update: presence guard + channel detection, never `--force`

- **Date**: 2026-07-01
- **Context**: install.sh npm-installed claude blindly → EEXIST abort when claude present via native installer (symlink npm doesn't own). Sibling steps (RTK/GSD) already had `command -v` skip guards; install.sh didn't. See [[BLK-014]].
- **Pattern**: (a) idempotent install step = `command -v <bin>` guard → skip-if-present with version echo, install only in `else`/`elif`. For a BINARY this IS a deterministic oracle (contrast [[LRN-054]]: conversation-state presence has none → don't skip-branch). (b) a CLI can ship via >1 channel (npm vs native). npm can't clobber a bin symlink it doesn't own → EEXIST; `npm --force` = wrong (npm itself says "recklessly", breaks native self-update). Detect channel first: `npm ls -g <pkg>` succeeds → npm-managed → npm; else native → `claude update` self-updater. (c) install ≠ update: first-time installer skips-if-present; the update script does the channel-aware upgrade.
- **Future application**: any installer/updater for a CLI reachable via multiple channels — guard with `command -v`, branch the updater on detected channel, never blind `--force` over a foreign-owned bin. Caveat [[LRN-036]]: `command -v` needs the bin dir on PATH in shelled-out/hook contexts.
- **Reference**: [[BLK-014]], mirrors RTK/GSD guard in install-plugins.sh. Related [[LRN-005]] (plugin enable idempotency), [[LRN-039]] (installer config drift).

---

## LRN-086 — External-tool-generated skill: prove provenance by mtime, gitignore + regen-on-absence (not unconditional) when the tool co-writes a user-editable config

- **Date**: 2026-07-02
- **Context**: `skills/find-docs/` showed untracked. `grep -rniE 'find-docs' --include='*.sh'` → 0 hits → wrongly read "hand-authored first-party skill, commit it". FALSE. Generator = external binary `ctx7 setup --claude --cli` (CLI+Skills mode), not any repo script. Oracle that flipped it: mtime `skills/find-docs/SKILL.md` (23:16:59.637) == ctx7 `~/.config/context7/credentials.json` write, same setup run → ctx7 co-created it. User held the correct premise; my repo-only grep was too narrow.
- **Pattern**: (a) provenance of an untracked artifact — a repo-script grep is BLIND to external-binary generators. Correlate its mtime with the tool's OWN files (creds/config) + read the tool's subcommands (`ctx7 setup --claude/--cli/--mcp`, `remove`) before deciding hand-authored vs tool-owned. (b) `ctx7 setup --claude --cli` writes TWO files 0.13s apart: `~/.claude/skills/find-docs/SKILL.md` (`~/.claude/skills` = symlink to repo `skills/` → lands IN repo) AND `~/.claude/rules/context7.md` (global config, real dir, NOT in repo, user-editable). (c) login ≠ setup: `ctx7 login` = auth/rate-limits only (help = only `--no-browser`), does NOT trigger setup. Orthogonal.
- **Rule**: tool-generated skill → gitignore it (like `skills-external/frontend-design/`) + regenerate via an install step, do NOT vendor. gitignore coherence: ignoring an artifact REQUIRES an install-step that regenerates it, else a fresh clone loses it. BUT when the same `setup` ALSO (re)writes a user-editable config, guard regen on ABSENCE (`[ ! -f .../find-docs/SKILL.md ]`) — an every-run `setup` would silently clobber that config once customized. Contrast frontend-design: unconditional re-sync is fine (its file is not user-editable).
- **Future application**: before gitignore-vs-commit on any untracked skill/dir, PROVE provenance (mtime + tool subcommands), never trust a repo grep alone. Tool-owned → gitignore + install-step regen; gate the regen on absence iff the generator co-writes anything the user may hand-edit. Reuses [[LRN-085]] presence-guard oracle (file presence = deterministic). See [[LRN-084]] (guard scope vs full intent), install-plugins.sh Step 6, commit `01d8b8f`.

## LRN-087 — presence-flag ≠ capability: rtk silently dead after .bashrc wipe

- **Date**: 2026-07-02
- **pattern**: binary installed + hook wired + registries say "always-on" ≠ capability LIVE. Hand-managed .bashrc restore dropped the cargo PATH line → `command -v rtk` failed in hook AND tool shell → hook warned+passed-through EVERY Bash call, input compression OFF ~9 days. Banner truthfully dropped rtk — but an ABSENT line is invisible signal, nobody noticed. Reality/registry gap held ([[BDR-006]]-era always-on belief survived).
- **fix shape (3 teeth)**: (1) consumer self-heals — probe known install dirs (`~/.cargo/bin`, `~/.local/bin`), never trust PATH ([[LRN-036]]); (2) an emitted/rewritten command executes in ANOTHER shell whose PATH the hook cannot fix → substitute the ABSOLUTE bin path at string head; compound rewrites with residual bare bin at a command position → pass through, never emit a 127 (global substitution unsafe: quoted text, e.g. commit messages, carries the same token at line start — proven live); (3) the rtk BINARY verifies its hook against `hooks/.rtk-hook.sha256` at execution and refuses a modified hook → every legit hook edit must re-pin. Pin = live machinery, NOT vestige — audit rec "delete it" REFUTED by execution ([[LRN-037]]).
- **future application**: any PATH-dependent capability + hand-managed shell profile → probe install dirs, absolute paths in emitted commands, verify capability END-TO-END; a status line that can silently disappear ≠ monitoring. Check for integrity pins before editing generated hooks.
- **Reference**: `hooks/rtk-rewrite.sh` (RTK_BIN + absolute-path substitution + compound pass-through), `lib/detect-plugins.sh` detect_rtk, branch bugfix/audit-bugs (audit 2026-07-02). [[BLK-001]] context. See [[LRN-036]], [[LRN-037]].

## LRN-088 — token-cutting intuition inverts under measurement: verbosity beats cardinality

- **Date**: 2026-07-02
- **pattern**: fixed per-session context overhead measured ~14.6k tok (audit 2026-07-02). The intuitive target (gstack, 34 skills) = only ~592 tok — terse one-liner descriptions. Real weights: CLAUDE.md 3,788 · personal skill descriptions ~3,488 (hand-written trigger lists, ~6× cost/skill vs gstack) · pr-review-toolkit agents 2,183 (6 agents, PR-only use) · superpowers session-inject 1,540 · context7 rule 493. Cutting by item-COUNT intuition misallocates effort ~4×.
- **actions taken**: pr-review-toolkit OFF by default (−2,183; audit.profile keeps it = reactivation channel), 10 fattest personal descriptions compressed 6,416→4,243 chars (−~540), context7 rule dropped for the find-docs skill (−493; skill body loads on-demand, stable — regen keyed on find-docs absence). Total ≈ −3.2k/session ≈ −22%.
- **future application**: before any "disable X to save tokens" → measure per-item bytes FIRST (frontmatter extraction, plugin cache); expect the fat where descriptions are hand-written rich, not where items are many. Profiles toggle SKILLS only — plugin payloads (agents/skills in cache) need `enabledPlugins`. [[LRN-080]] measure-first corroborated on a new axis (cost, not behavior).
- **Reference**: audit 2026-07-02 measurement + branch feature/audit-tokens. See [[BDR-014]], [[LRN-043]].

## LRN-089 — a pass-through wrapper whose callee reads ambient state silently ignores its args

- **Date**: 2026-07-03
- **pattern**: a CLI/dispatcher that forwards `"$@"` to a function which derives its TARGET from ambient state (HEAD, cwd, env, "current X") rather than from those args → the args are silently dropped. The call SITE looks parameterized (`finish bugfix audit-bugs`) but the callee acts on whatever state it's standing in → wrong-target action, NO error. `gitflow_finish` read `HEAD`, never `$1/$2`; `finish bugfix X` from another branch merged that other branch.
- **context**: audit 2026-07-02, `lib/gitflow.sh:257` `finish) gitflow_finish "$@"` passed args the function never consulted. Surfaced when a finish "for" one branch merged another (LOT3). [[BLK-015]].
- **future application**: any wrapper/dispatcher forwarding args to a callee that resolves its target from ambient state — either (a) make the callee USE the args as the target, or (b) if the ambient-state contract is deliberate, treat passed args as an ASSERTION and refuse loudly when they disagree with the state. Never let forwarded args be silently dropped: silent-drop = the caller believes they steered, the callee ignored them. Sibling of "presence-flag ≠ capability" [[LRN-087]] — both = a visible signal lying about the real behavior.
- **Reference**: `lib/gitflow.sh` gitflow_finish arg-guard, `lib/gitflow-test.sh` T12. [[BLK-015]].

## LRN-090 — external-repo audit: open WIRED subsystems before declarative
- **pattern**: auditing external config/framework repo for transferable value → rank subsystems WIRED (executable: hooks/, runners, dispatchers) vs DECLARATIVE (docs, rules/, aspirational frontmatter). Wired > declarative: declarative often inert (ECC rules/ `paths:` = 0 consumers; eval-harness = SKILL.md, no runner — "belle méthodo / vaporware"); wired = a real mechanism worth adapting.
- **context**: ECC 2nd-look 2026-07-03 (Opus 4.8, 6 agents, repo unchanged since 01/07). [[BDR-047]] audit (01/07) inventoried the declarative surface + concluded zero import — right on facts, but hooks/ (ECC's only live subsystem) was OUT of scope and held the sole real adaptation → config-protection PreToolUse guard.
- **future application**: next external-repo value audit → enumerate hooks/, scripts/, runners FIRST; treat rules/docs/SKILL.md as claims to verify ("is it wired?"), not value. Described capability ≠ wired capability.
- **cousin**: [[LRN-087]] presence-flag ≠ capability; [[LRN-089]] forwarded-args silently dropped — same family: a visible signal (a file, a flag, a `paths:`) lying about real behavior.

## LRN-091 — a soft-nudge hook that over-fires gets ignored (banner-blindness)
- **pattern**: keyword-triggered nudge (design-toolchain reminder) with bare common tokens fires on non-UI work → reader tunes it out. Same class as a diagnostic that cries false [[LRN-047]]: a signal wrong too often stops being read.
- **rule**: keep a token BARE only when its UI sense dominates largely in a dev context (glassmorphism, navbar). Token common in non-UI talk (design, component, theme, transition, frontend) → require a UI-specific bigram (design system, front-end design) or drop; in doubt → bigram-or-drop. Borderline standalone nouns (dashboard, animation) may stay bare as an assumed call — the fire-log arbitrates later on data, not gut. (NOT "never bare tokens" — animation stays bare here by design.)
- **context**: design-toolchain-reminder.sh — 07-02 tightening (dropped page/form/menu/…) insufficient; 6 bare tokens still false-fired ~6×/session during the ECC config audit (design, ecc_dashboard.py, component, frontend, theme, transition, palette). 07-03 fix: dropped them, dashboard→`\bdashboard\b` (filename match killed, "admin dashboard" kept), added a fire-log (time+token+excerpt). `lib/tests/design-toolchain-reminder.test.sh` locks it (18 checks).
- **cousin**: [[LRN-047]] a doctor that cries false is ignored.

## LRN-092 — SAST smoke test: official example keys are rule-excluded — "no findings" proves nothing
- **pattern**: smoke-testing a SAST/secret detector w/ the OFFICIAL example payload (AWS `AKIA...EXAMPLE`) → 0 findings BY DESIGN — rules exclude documented example keys to kill FP. A vacuous pass, [[LRN-048]] class (a pass must prove it looked). Validate w/ realistic-shaped payloads AND enumerate what the tier does NOT catch before trusting a ruleset as a gate.
- **context**: lot 1 semgrep-install dogfood 2026-07-03. `p/secrets`+`p/security-audit` community tier: anonymous fetch OK (52 rules, no login), `subprocess-shell-true` detected ERROR; MISSED %-format SQLi on bare cursor (no recognized DB-API context) + fake-checksum `ghp_` token. Gap logged for security-auditor agent design (consider adding `p/owasp-top-ten`).
- **future application**: any detector/gate smoke test — craft realistic payloads, never the canonical example; measure the miss-list on purpose-built fixtures; size the gate's blocking scope on that data.
- **cousin**: [[LRN-048]] a 0/OK must prove it looked; [[LRN-047]] noisy guard = ignored guard; conditions [[BDR-048]].

## LRN-093 — grep -F with an embedded newline = per-line OR = vacuous lock
- **pattern**: a fixed-string grep pattern containing a newline is treated as MULTIPLE patterns (one per line) — match succeeds if ANY line matches. A structure lock written that way passes on essentially anything (`"no\n    forced loop"` → matches any "no") = a lock that proves nothing, [[LRN-048]] class.
- **context**: lot 2 `lib/tests/contract-verifier.test.sh`, caught in self-review BEFORE first run; replaced by a single-line distinctive anchor ("proceed straight to the security gate").
- **future application**: structure locks / census greps = ONE line per pattern, always; a clause spanning lines → lock a distinctive single-line fragment. Flip-test every new lock (prove it CAN fail) before trusting its green.
- **cousin**: [[LRN-048]] a pass must prove it looked; [[LRN-046]] deterministic-oracle discipline.

## LRN-094 — SAST severity ≠ exploitability; metadata does not cleanly separate — don't refine on it
- **pattern**: semgrep `ERROR` conflates exploitable vulns (SQLi, secrets, command injection) with hardening recommendations (Dockerfile missing-USER, npm release-age). The obvious refinement — gate on `metadata.impact`/`likelihood`/`confidence` — does NOT work: measured, the Dockerfile hygiene ERROR (`impact=MEDIUM likelihood=LOW`) is indistinguishable from a tainted-SQL ERROR (`impact=MEDIUM likelihood=MEDIUM`), and a real command-injection reads `impact=LOW likelihood=HIGH`. Metadata-based severity = a noisy, non-deterministic gate ([[LRN-077]] class).
- **context**: lot 3 security-auditor design 2026-07-03. Measured on 2 real repos (faunosteo, game): the only added blocking ERROR from owasp-top-ten is Dockerfile hygiene, contained because gate mode scopes to the DIFF (a pre-existing infra finding can't block an unrelated code change).
- **future application**: mapping any SAST to a blocking gate — take the tool's ERROR/blocking level as the deterministic threshold, contain FP by SCOPING (diff, not repo), NOT by a metadata heuristic or a hand-maintained hygiene denylist ([[LRN-049]]: match guard cost to proven stake — build the denylist only if hygiene ERRORs prove noisy on a real project).
- **cousin**: [[LRN-047]] noisy gate = ignored; [[LRN-077]] non-deterministic gate; conditions [[BDR-048]].

## LRN-095 — Orthogonal gates don't contaminate: a conformity check must pass correct-but-insecure code
- **pattern**: when a pipeline has distinct gates (request-conformity, security), each judges ONLY its dimension. A conformity verifier must return CONFORME on code that is correct-but-insecure — the vuln is the SECURITY gate's job, not a conformity gap. Proven live: a `get_item` feature satisfying its contract but carrying a `%`-interpolation SQLi → verifier CONFORME, security-auditor BLOCK(1). Fusing the two into one "quality" gate makes each worse: the conformity check starts hunting vulns (scope creep, misses conformity), the security check starts judging feature-completeness (dilutes).
- **context**: lot 4 verify-secure-loop dogfood 2026-07-03. The orthogonality is WHY the order invariant matters (re-verify request before re-scan security) — two independent axes re-checked independently.
- **future application**: any multi-dimension gate (review lenses, verify+audit, correctness+perf) — keep each gate single-axis and let a finding on axis B pass axis A's gate; compose verdicts in the orchestrator, don't merge the judges.
- **cousin**: [[BDR-050]] the pipeline; [[BDR-049]] fresh verifier; conditions [[LRN-083]].

## LRN-096 — A backstop is code: prove it can FAIL (flip-test) before trusting its green
- **pattern**: a deterministic guard built to replace a forgettable advisory is itself code, and an UNPROVEN guard is a vacuous guard — [[LRN-048]] (a pass must prove it looked) applied to guards themselves. The LRN-093 backstop (refuse `\n` in grep/tf patterns) shipped with a regex requiring whitespace before `tf` → it silently MISSED `tf` at line start (exactly where the real locks sit). A flip-test (feed the guard a KNOWN offender, assert it bites) caught the hole; without it the guard would have green-lit the very class it was built to kill. So: a flip-test is MANDATORY at guard creation, part of the guard, not optional QA.
- **why it matters**: the whole point of a backstop is that it fires on the bad case; a guard that can't fail proves nothing and is WORSE than the advisory it replaced (false confidence). The advisory→backstop move ([[LRN-047]] [[LRN-091]], own doctrine) is only sound if the backstop is itself verified against a real miss.
- **context**: lot 5 `lib/tests/no-vacuous-locks.test.sh` 2026-07-04. Built the guard, its flip-test RED'd (regex too weak, missed line-start `tf`), fixed the regex, flip-test green. The guard now ships WITH the flip-test inline so it self-proves on every run.
- **future application**: building any guard/lint/census/backstop — bundle a flip-test (a synthetic offender the guard must catch) in the same file; a guard whose failure path was never exercised is untrusted. Corroborates [[LRN-047]]/[[LRN-091]] (advisory→deterministic) — this is the *quality bar* on the deterministic replacement.
- **cousin**: [[LRN-048]] prove it looked; [[LRN-093]] the class this guards; [[LRN-046]] deterministic-oracle discipline.
