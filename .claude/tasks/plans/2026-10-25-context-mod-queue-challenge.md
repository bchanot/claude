# PLAN — context mod queue (BDR-125), full re-challenge on request (2026-10-25)

Challenge target: the WHOLE multi-phase plan below, verbatim from
.claude/tasks/TODO.md. Question for every lens: is there a BETTER solution
(simpler, native, more reliable, cheaper in tokens) than what each phase plans?
A finding that only restates a settled constraint (see CONSTRAINTS) is not a
finding. Facts the plan cites were measured in these benches:
.claude/tasks/plans/2026-10-24-context-mod-probe/ (context levers),
.claude/tasks/plans/2026-10-25-routing-probe/ (skill routing),
.claude/tasks/plans/2026-10-25-bash-deny-probe/ (shell deny matcher).
Decisions: .claude/memory/decisions.md BDR-125 + amendments 1-6.

## CONSTRAINTS (settled by the user, not to re-litigate)
- Always-on doctrine moves to "hard" mechanisms so the user never has to think
  about it; subtract-only, mod off = today's behaviour.
- Profiles per project AND per concurrent conversation; tracked settings.json
  keeps deny/allow only; global toggle mode deleted; 11 profiles kept.
- Code always written through a skill (routing guard); merge gate = $.ui.ask
  confirmation dialog; defaultMode stays auto.
- Phase order 0 → 4a → 1 → 5 → 2 → 3 → 4b-4d; listing budget raised after packs.
- Memory: 5 registries augmented in place (no one-file-per-entry migration now);
  caveman English, append-only; writes need user approval.
- Never: Stop block, per-turn nag, forced skill, hiding dispatchable agents.
- Destructive tools never run live, even in tests.

## PLAN (TODO.md section, verbatim)
### Context mod queue (BDR-125): one /ship-feature per phase, order (user 2026-10-25): 0 → 4a → 1 → 5 → 2 → 3 → 4b-4d
Shared rules for every phase:
- Baseline first: `claude -p "/context"` at repo root (2026-10-23: 30.2k always-on = memory files 11.6k, skills 10k, agents 2.6k, system 2.5k, MCP instr 2.2k, tools 1.1k). Same measure after; the delta is a phase criterion.
- Proof bench: `.claude/tasks/plans/2026-10-24-context-mod-probe/` (canary per lever + negative control, fresh `claude -p --plugin-dir`). Every lever a phase uses is re-proved there before code, every "to verify" below becomes a canary criterion.
- Subtract-only: source text stays in CLAUDE.global.md / rules / CLAUDE.md, marked `<!-- jit:<id> -->` … `<!-- /jit -->`; the mod drops a marked section only where it re-delivers it on a trigger. Mod off (`~/.claude/context-mod.json` `"enabled": false`) or hook throws → full text loads as today. Guards use `.catch` deny (fail closed); injections fail open.
- Inject once per context: mod ledger in `$.state` of what it injected; reset on `session.compact` and `session.end` reason `clear`; re-inject at the next trigger. Canary test after a real compaction is a criterion (documented, not yet proved).
- Never: forced continuation / Stop block (BDR-083, BDR-087), per-turn nag (BDR-037), forced skill invocation, hiding a dispatchable agent via `agent.offer` (breaks dispatch, proved).
- Cleanup is part of each phase: delete what the phase makes obsolete (scripts, hooks, tests, doctrine lines, Makefile targets, doctor checks), grep every citer and patch in the same branch (doctrine-citers census in `make test`).

- [ ] **Phase 0, no mod: split project CLAUDE.md + fix higgsfield MCP**
  - Move the 4 project CLAUDE.md sections (graphify vendored skill 1.4k chars, mods/ 1.3k, rules/ maintenance 1.3k, transient planning artifacts 0.9k) to `.claude/rules/<name>.md` with `paths:` (`skills/graphify/**`; `mods/**`, `skills/model-router`; `rules/**`; `docs/superpowers/**`). Project scope only: no ~/.claude link points at `.claude/` (checked 2026-10-24); never into `rules/` (= ~/.claude/rules, every project).
  - `.gitignore:122` ignores `.claude/*`: add `!.claude/rules/`.
  - Higgsfield: MCP declared user-scope in ~/.claude.json (`higgsfield` http) and connected while `toggle-external.sh` says disabled; make `toggle-external.sh enable|disable higgsfield` own `claude mcp add|remove -s user higgsfield` (the user runs the first removal), + doctor check "toggle state = MCP state".
  - Proof: canary per moved rule (ABSENT at start, PRESENT after Read of a matching file); `/context` delta (~1.9k memory files + higgsfield MCP share).
  - Cleanup: CLAUDE.md keeps a 2-line pointer ("rules under .claude/rules load on path"); fix citers of the moved headings.
  - Other projects (user ask 2026-10-24). Measured project CLAUDE.md, loaded every session of that project: faunosteo 50,228 chars (bigger than the global one), zenquality 23,378, game 14,918, robin_petier 12,895, config 4,990, integration_alphalink 4,249; none has `.claude/rules/`. Splitting is judgment (always-on: overview, stack, commands, conventions; path-scoped: one module, Docker, a folder), so no background automation and no new skill:
    - `/onboard` gets a `split` mode (skill edit through /writing-skills: pressure test RED first): read the project CLAUDE.md, classify each section always-on vs path-scoped, propose globs from the real tree, user approves per project, write `.claude/rules/<name>.md` + slim CLAUDE.md + `!.claude/rules/` in .gitignore when `.claude/*` is ignored.
    - Generators fixed at the source: onboarder + scaffolder (init-project) emit path rules from day one, so new projects are born split.
    - One pass over the git repos in ~/Documents/ (this repo first, then by size: faunosteo, zenquality, game, robin_petier, config, integration_alphalink): one `chore/claude-md-split` branch per repo, per-project approval, never an automatic merge (user signal per repo), `/context` before/after per project recorded in that project's journal.
    - Proof: per project, canary that a moved section is ABSENT at start and PRESENT after a Read of a matching file; total always-on delta across the 7 projects.

- [ ] **Phase 1, native context diet: no mod** (redesigned 2026-10-24 after challenge: the engine already does most of it)
  - Facts 2026-10-24 (scratchpad pathtest, memtest): a `paths:` rule loads on Read of a matching file, NOT on Write of a new file (S1 ABSENT, S2 after Write ABSENT, S3 after Read PRESENT); `"autoMemoryEnabled": false` removes the auto-memory system section (PRESENT → ABSENT); classic SessionStart / UserPromptSubmit hooks inject additionalContext (seen live in every session); instruction files reload on compaction natively (InstructionsLoaded `load_reason: compact` in the 2.1.306 types). So each section goes to the native carrier that matches its trigger, with no mod code, no fail-open risk, and it works with the mod off and in sub-agents.
  - Section → carrier:
    - auto-memory system section → `"autoMemoryEnabled": false` in settings.json (one line, proven).
    - Design work (1.5k chars) → user rule `rules/design-work.md` with the UI globs of rules/web-building.md (fires on UI file Read) + `hooks/design-toolchain-reminder.sh` injects the section text itself when it detects UI work in a prompt (covers new files created from a prompt); drop its "(already in context)" wording.
    - graphify (0.6k) → `hooks/session-start.sh` injects the section only when `graphify-out/graph.json` exists (it already computes graph presence for the banner).
    - Public websites never SPA + default language + web APIs versioned (2.3k) → into the skills that brainstorm (init-project, ship-feature STEP 1, brainstorming, refactor whole-project, onboard) + session-start injects them when the cwd has no tracked code file (new project); dedupe "Web APIs" against rules/rest-api.md.
    - secure-by-default domains 4 Supabase + 6 cloud functions → user path rules (`supabase/**`, `**/*.sql`; `functions/**`, `**/serverless.*`, `**/firebase.json`); keep "Every API", hosting, injection, exposure and SMS/email always-on (no reliable path for messaging, 325 chars).
    - Our code vs foreign code → session-start runs `lib/code-origin.sh` once and injects one line ("this repo: ours, strict limits" / "foreign, keep its style"); both short sections stay always-on.
    - Registry format → compressed in phase 4a (lib/memory.sh enforces it); gitflow detail → compressed in phase 2 cleanup (hooks + lib + merge gate enforce it). No JIT needed for either.
  - Project fingerprint (stack, supabase, messaging, functions, graph, origin) moves to phase 3, its first consumer (listing filter), reused by phase 5.
  - Proof: canary per moved section (ABSENT without trigger, PRESENT after it: UI Read, UI prompt, graph.json present, empty dir, skill load, supabase Read); a new-file-only UI turn still gets Design work through the prompt hook; `/context` delta (~4.4k est. across phases 1, 2, 4a); hook tests extended (design-toolchain-reminder, session-start).
  - Cleanup: CLAUDE.global.md loses the moved sections (one pointer line each where needed), citers patched (doctrine-citers census); BDR-031 citers.
  - The `context` mod is born in phase 2 or 3 (first need: guards or listing rewrite); challenge at phase 2 launch whether guards fit better as classic hooks (push-guard pattern, transcript_path gives the last user message) or as the mod.

- [ ] **Phase 2, guards** (redesigned 2026-10-25 after a 3-lens challenge: correctness FATAL(10), robustness FATAL(13), simplicity FATAL(6); plan `.claude/tasks/plans/2026-10-24-context-mod-phase2.md`)
  - Killed by the challenge: the phrase-list merge gate (false allows: "don't merge it yet", "should we merge it?", pasted text, skill bodies in the transcript; false denies: a plain "oui"; it blocked the BDR-068 /close auto-finish and the release-executor sub-agent finish; "ship it" contradicts the doctrine); G2 destructive guard (BLK-022: the content is withheld, not the language; stays a user-driven task with its two listed options); whole-file code-limit reports (measured 1498 lines > 80 cols across 92 files, lib/gitflow.sh 81: over-fires, LRN-091); parsing commit text from Bash (heredoc `-m "$(cat <<'EOF' …)"`, `-F`, `-C`); registry format (in 4a).
  - Merge gate (user pick 2026-10-25: confirmation dialog). Mod `tool.call` on Bash|Monitor matching `gitflow.sh finish`, `gitflow_finish`, or `git merge` while develop/main is checked out → `$.ui.ask("Merge <branch> → <target> ?")`, one per branch, single use; dismissed, rejected, `-p`, or no surface → deny with reason "confirm at the terminal, then re-run". Named exceptions: BDR-068 ritual (this turn's prompt.submit command is capitalize or close, `gitflow.sh start chore <name>` seen this session, diff touches only `.claude/**`); release path in a decision table (verify that `$.ui.ask` works for a sub-agent's tool.call; else /release-candidate runs finish inline, BLK-018 option b). Cheap synchronous prefilter before the `.catch` deny, so a guard bug never denies every Bash call. Banner or doctor line when the guard is not live. settings.json hard_deny names mod refusals and the mod disarm paths (`mods/<name>/` sources, `~/.claude/<name>.json` `"enabled": false`, `enabledPlugins` `<name>@skills-dir`, dev-copy shadow). The finish prose stays until canaries pass across sessions. This is the first piece of the context mod.
  - Routing guard (user pick 2026-10-25: "always through a skill"). Measured: "j'aimerais que doctor.sh affiche la version de rtk" was coded inline with no skill (routing probe L3); history 2026-09-23 → 10-24: 10 code-writing bug/feature turns went through a skill, 11 coded inline (long pasted faunosteo briefs). Mod `tool.call` on Edit/Write/NotebookEdit of a code file by the MAIN loop (no `agentId`) while no skill run is active (model-router run slot or a `skill.prompt` seen this turn for feat/bugfix/hotfix/ship-feature/refactor/code-clean/tour…) → deny with reason "route through /hotfix (≤2 files, obvious), /feat, /bugfix or /ship-feature". Free: docs (.md), `.claude/**`, sub-agents (executors), any write inside a skill run. Bash write forms to a code file by the main loop (`>`/`>>` redirect, `tee`, `sed -i`, `cat <<EOF > f`, `python3 -c 'open(…,"w")'`) → same deny, cheap regex prefilter, unparseable → allow (never deny every Bash). Doctrine follows in the same change: the ceiling bullet becomes "the main loop writes no code outside a skill run, whatever the model". Proof: routing bench `.claude/tasks/plans/2026-10-25-routing-probe/` cases (L3 must now enter a skill), long-brief replay in a clone, false-deny fixtures (doc edits, executor edits, in-skill edits, Bash writes inside a run).
  - Shell deny hygiene (measured 2026-10-25, bench `.claude/tasks/plans/2026-10-25-bash-deny-probe/`; user pick: stay in `defaultMode: auto`). Facts: the native matcher already sees through `&&` `;` `||` `|` newline `( )` `env` `command` `\cmd` `timeout` `nohup` `xargs` quoted command word and simple assignments (no per-rule duplication needed); it misses `sh -c`, bare `bash`/`sh` + heredoc, `$(…)` in command position, absolute paths, interpreters (`python3 -c`, `awk system()`, `node -e`) and a quoted literal argument (`git push origin ":feature"` escapes `:**`); under auto every miss was approved by the classifier, not prompted; the rtk-rewrite PreToolUse hook runs BEFORE permission evaluation and the deny is evaluated on the REWRITTEN command (`cat SECRET.txt` under deny `cat SECRET*`: DENIED hooks off, RAN hooks on; `git push origin :feature` → rc=3 → `rtk git push origin :feature`, so deny `git push * :**` (hotfix ac23cc6) and ask `git push *` are bypassed in real use; rc=2 forms `--delete` `+ref` `--force*` `.env` `id_rsa` `.aws` `find -delete|-exec` `git branch -D` are left unchanged and hold; rc=0 misses `cat */*.pem`, `cat */secrets/*`); Bash redirects into an Edit-denied path ARE denied; `ask` beats `allow` (an `ask Bash(bash *)` prompts every lib script: never).
    - rtk hook: rc=3 → pass through unchanged (no `updatedInput`), native deny/ask see the original; re-pin `hooks/.rtk-hook.sha256`; hook test with the `cat SECRET*` analogue hooks-on. rc=0 reads: census test that every `Bash(cat|head|tail <glob>)` deny has its `Bash(rtk read <glob>)` twin, twins added.
    - settings.json `ask` += `Bash(sh -c *)`, `Bash(bash)`, `Bash(sh)`, `Bash(bash -s*)`, `Bash(bash <(*)`, `Bash(/*)`, `Bash(python3 -c *)`, `Bash(python -c *)`, `Bash(node -e *)`; `deny` += `Bash(awk *system*)` (`awk *` stays allowed; proven: plain awk RAN, system() DENIED). Each pattern proven in the bench (r3) before landing. P41 (templates: "ask inert under auto") is contradicted by measurement (`bash -c` prompted under auto in -p): re-check and fix the item, not the config.
    - Limits written down, one place: settings.json soft_deny note + README permissions: `$(…)` in command position and a quoted literal argument have no matchable rule and rest on the classifier; mode stays auto.
    - Folds TODO Actionable "docker host-root mount spellings" (prove with the same bench, same change) and the T42 dead-entry drop list (`git push * :*` etc.) if the release lands first.
    - Interim (accepted with the order 0 → 4a → 1 → 5 → 2): until this lands, a `git push origin :ref` deletion rests on the classifier and rtk's registry, not on settings.json.
  - Commit message: `commit-msg` git hook emitted by the gitflow hook generator (global core.hooksPath, T10 drift test), active only when `CLAUDECODE=1`, words counted with trailers excluded, limit read from lib/commit-message.md (one place), exemption only on deterministic convention files (commit template, .gitmessage, commitlint config). A failure is a git error to fix by shortening, not a permission refusal.
  - Code limits: classic PostToolUse hook, added lines only (Edit new_string, Write content), our code only (`lib/code-origin.sh` on the edited file's repo), 80 columns only, at most 5 reports, once per file per turn, `additionalContext`, never a deny. Function length deferred (or the project's own linter rule).
  - Proof: an evasion matrix per rule (the bash-deny-probe bench: quoting, cd and -C, bash -c, sh -c, heredoc, $(…), absolute path, interpreters, rtk rewrite hooks-on, Monitor, sub-agent, non-composer turn); false-allow fixtures for the gate (negation, question, paste); the /close ritual still finishes; the release decision table is tested; destructive commands are never run live (plugin test with stubs only).
  - Cleanup: compress the gitflow section only for the forms now enforced; the commit-message line already points at the lib.

- [ ] **Phase 3, listings** (scope note 2026-10-25: this is NOT the plugin advisor; per-project profiles are phase 5. Once phase 5 packs exist, the skill listing shrinks natively, so the mod listing filter shrinks to restoring truncated descriptions of kept skills; the routing hint, agent description trim and MCP names stay here; the fingerprint built here also feeds phase 5 profile detection.)
  - Skill listing: `prompt.attachment` type `skill_listing` (30,031 chars measured) rewritten from the fingerprint: categories per skill live in routing.json (new `contexts` field beside the phase row); a skill with no category stays SHOWN (new skills always appear); census test in make test fails on an uncategorised skill; kept skills get their full description back from SKILL.md frontmatter (LRN-175 truncation). Handle the listing delta sent mid-session.
  - To verify first (canary): a skill hidden from the listing still runs when typed (`/name`) and through the Skill tool.
  - Routing hint: classifier (reuse model-router's small-model call) maps a typed prompt to one skill; inject one line via `prompt.submit` `context` only above a confidence threshold, never on slash prompts, mid-turn or inside a run; names hidden skills too. Replaces the CLAUDE.global.md "Skill routing" table (2.1k chars).
  - Agent listing: `agent_listing_delta` (9,098 chars) rewritten with short descriptions for skill-dispatched executors, names kept. To verify first: dispatch of a trimmed agent still works (agent.offer untouched).
  - MCP: drop instructions + deferred tool names of servers the fingerprint/toggles mark irrelevant (higgsfield off, claude.ai connectors in a coding repo) via `mcp_instructions_delta` / `deferred_tools_delta`; ToolSearch still finds them.
  - Proof: canaries (hidden skill ABSENT, control PRESENT, typed hidden skill runs, trimmed agent dispatches), hint precision measured on a fixed prompt set (no hint on chat/bookkeeping), `/context` delta (~5-7.5k est.).
  - Cleanup: CLAUDE.global.md Skill routing section → 2 lines; LRN-043 routing-line rule superseded; doctor skill-listing budget check updated.

- [ ] **Phase 4, memory v2: write, capture, read, feedback** (redesigned 2026-10-24 after measurement; 4a needs no mod and can run right after phase 0)
  - Facts 2026-10-24 (scratchpad memeval, 434 entries): registries ~1M chars (decisions 319k, learnings 357k, journal 168k, evals 85k, blockers 68k), never in always-on context, read only by /feat /bugfix /ship-feature (analyze-before-plan); Index drift 6 rows (decisions 121/125, evals 46/48); status in 3 places (title tag, body Status line, Index column; LRN/EVAL none) → reconcile false-open BLK-032..034; no single writer (skill says Edit + manual Index row; Edit needs a Read of a 357k file, so real writes are ad hoc python/bash); 93-100% of entries carry a language-neutral artifact (path, command, quoted string); lesson field present in 98% LRN, 85% BLK, 98% EVAL (median 170-560 chars vs body 1.2-2k); 2 near-duplicate title pairs only; 325/434 entries have [[links]] (1080); growth 40-90 entries/month; 44 files cite registry paths; 8 projects on this machine hold v1 registries. "Session start: read .claude/memory/" is unrealistic; caveman premise "registries load every session" is false.
  - Measured recall (5 real FR prompts, 22 relevant entries): BM25 titles 7/22, BM25 full text 9/22, haiku rerank of lexical top-30 14/22 (~8.5k chars), haiku over all titles 14/22 (~43k chars). Error 4-gram match on today's real errors: 429 credits → BLK-030 + BLK-031 exact, BLK-034 suite error exact, no false positive; 5 of 7 real errors of 2026-10-23 had NO entry (never captured): capture is the weak link, not search.
  - Storage choice: augment in place (5 files, headings and paths unchanged) + per-entry Meta line + generated Index. Rejected for now: one file per entry with frontmatter (better concurrency and per-entry history, but 44 citers + 8 project migrations; a commit-time validator + backfill give the same machine fields). Revisit if same-repo concurrent writes conflict.
  - **4a write side (shell, no mod).** `lib/memory.sh` = single writer and reader, like gitflow.sh: `add <kind> --title --apply --body-file [--status --scope --supersedes --critical]` allocates next ID from headings (never the Index), appends the entry ending with `- **Meta**: status=…; scope=project|global; triggers=path:…,cmd:…,skill:…,err:"…"; supersedes=…; critical=yes|no`, regenerates `## Index` from headings + Meta; `status <ID> <new>` appends a dated status line (append-only); `journal "<line>"` appends under today's heading; `derive <ID>` prints derived triggers (paths, commands, skill names, quoted errors normalized); `index`; `check [--staged]`.
    - Validator: pre-commit (only when `.claude/memory/` is staged; diff-based on added/changed entries, so legacy entries in the 8 projects pass) + make test: heading pattern, ID = max+1 and unique, Meta on new entries, Index == generated, no removed line from an existing entry outside a /prune-memory curation commit, English (accent-ratio threshold proven zero false positive on all 8 projects' registries). New BLK must quote ≥1 error verbatim.
    - Backfill via /prune-memory (deterministic script + user review): Meta for the 434 entries; status from the 3 legacy forms (last wins); triggers derived; Apply = LRN/BLK/EVAL lesson field, BDR = first sentence of **Decision**; scope proposed by the model, reviewed (global = applies in other projects too: Claude Code behaviour, permissions, mod API, CLI quirks). Coverage report is a criterion.
    - Citers: capitalize, close, prune-memory, CAPITALIZE steps of feat/bugfix/hotfix/ship-feature/commit-change, lib/capitalize-commit.md, lib/analyze-before-plan.md, lib/reconcile.sh (Meta status first, legacy fallback: fixes BLK-032..034 false-open), templates/memory, onboard/init-project; doctrine-citers census. CLAUDE.global.md Memory registries: write only via lib/memory.sh; fix the false "load every session" premise (keep caveman: it keeps reads and injections small).
  - **4b capture (mod).** Failure ledger: every tool result with isError, deny or non-zero exit carrying a distinctive error line → normalized + verbatim + command, kept per session in `$.store`, matched against the registry error index; unmatched = new failure modes. Milestones observed: feat/fix commit, `gitflow finish`, a suite red then green. `memory_pending` tool (`isDeferred: false`) returns unmatched failures + milestones verbatim; /capitalize, /close and every CAPITALIZE step call it first; one context note at the next prompt after a milestone, never per turn, never at Stop. Judgment triggers (design choice, surprising discovery, dead end) stay with the model: "Proactive capitalization" paragraph KEPT. Writing always = model draft + user approval + lib/memory.sh (validated).
  - **4c read side (mod).** Tier 1 always-on: ≤10 user-marked `critical=yes` lessons, one line each (~1k chars) in `prompt.context`. Session digest in `prompt.context` (open BLK from Meta status, actionable TODO, last journal line; re-read by the engine on compaction and /clear). Intent recall at `prompt.submit` only for model-router classifier labels design/analysis or the first coding prompt after idle: BM25 top-30 over title + Apply + triggers + body → haiku keeps ≤3 (option: same call as the classifier, no added latency), bounded 3 s, fail open. Execution recall: Read path triggers (lands before the edit), Bash command triggers (after the result; `critical` → deny once with the Apply line, retry allowed), tool error 4-gram match. Injection = ID + title + Apply only; superseded entries never injected (successor shown); linked IDs as one-line see-also; EVAL excluded from auto recall; budget ~1.5k chars per turn; once per context (ledger reset on compact/clear). Config-repo entries with scope=global indexed in every project (repo resolved from the ~/.claude/lib link). `memory_search` tool for skills (analyze-before-plan pass 1 calls it).
  - **4d feedback and promotion.** Log each injection (ID, trigger kind, turn) and whether the turn cited the ID or the retried action succeeded; /prune-memory reads it: never-recalled entries, noisy entries (injected often, never used) get triggers fixed; entries recalled ≥N times → proposed promotion to a mechanism (guard, test, skill step), BDR-100 "mechanisms, not lessons".
  - Proof: validator zero false positive on the 8 projects; writer round-trip; backfill coverage; recall precision on ≥20 real prompts and ≥10 real errors (journal + transcripts), target ≥ the 14/22 baseline; digest canary after a compaction; haiku rerank latency inside the mod measured; `/context` delta; captured-failure demo: an error from session N recalled by match in session N+1.
  - Cleanup: hand-maintained Index steps in skills, "add one row to the Index" instructions, ad hoc append snippets, the false doctrine premise, reconcile legacy-only status parsing once backfill lands.

- [ ] **Phase 5, per-project and per-conversation profiles, native packs** (redesigned 2026-10-25, facts + user answers)
  - Facts 2026-10-24/25 (scratch projects, fresh headless sessions, canaries, run concurrently, one shared ~/.claude): `.claude/settings.local.json` `enabledPlugins` per project works both ways and concurrently (ui-ux-pro-max off in A while on in B; pr-review-toolkit on in A only); `claude --settings '<json>'` gives two SIMULTANEOUS conversations in the SAME project different plugin sets; a skills-dir plugin (`~/.claude/skills/<name>` + `.claude-plugin/plugin.json`, like model-router) obeys both; plugin skills keep their short name (Skill tool `ui-styling` and typed `/ui-styling` resolve); plugin agents need the `plugin:` prefix (`silent-failure-hunter` → not found); `permissions.deny Skill(x)` does not hide a skill; a user-scope MCP cannot be switched off per project by settings (`disabledMcpjsonServers` and `disabledMcpServers` had no effect): project-specific MCP belongs in a pack plugin or at local scope; claude.ai connectors do not load under `-p` (untestable headless).
  - User answers 2026-10-25: profile can change per project and per conversation, never one profile for all conversations; tracked `.claude/settings.json` keeps deny/allow only, profiles go local; a project without a profile gets a detected proposal once, written on accept; the global mode (skills/ ↔ skills-disabled/ symlinks + user-scope plugin toggling) is DELETED; core = everything except the heavy packs (design, seo/geo, web-validate, scroll/3d, higgsfield, gstack); agents stay global (no packs, short names kept); a skill needing an off pack proposes to enable it then `/reload-plugins` (spike first; fallback: stop and name the pack); all 11 profiles kept, rewritten as pack compositions.
  - Packs: each heavy group becomes a skills-dir plugin `skills/pack-<name>/` (`.claude-plugin/plugin.json` + `skills/<skill>/SKILL.md`, + `.mcp.json` for higgsfield, + hooks if a pack has any). Spike first: nested skills inside a skills-dir plugin load as plugin skills and not twice as user skills; gstack (external installer, symlinks) as a pack.
  - Profile = `lib/profiles/<name>.profile` → generated `~/.claude/profiles/<name>.json` (`{"enabledPlugins": {...}}`). Per project: `profile.sh set <name>` writes `enabledPlugins` into the cwd project's `.claude/settings.local.json` (never user scope; gitignore line checked). Per conversation: launcher `claude --settings ~/.claude/profiles/<name>.json` (shell function or `make` helper, named with the user), wins over the project default for that conversation only.
  - Detection: session-start hook reads the fingerprint (stack, web public vs app, supabase, messaging, graph; from phase 3, or a minimal shell version here) when the project has no profile and proposes one in one line; writing it needs the user's yes.
  - Pack needed mid-skill: orchestrators' existing gates (lib/design-gate.md + design-tool-gate.sh, lib/plugin-gate.md) check the required packs; off → propose enabling for this conversation/project + `/reload-plugins`; spike that a settings change + `/reload-plugins` loads the pack mid-session.
  - Listing budget (user pick 2026-10-25: after the packs): measured 124 skills listed, 46 name-only at the default budget (incl. tour, seo, web-validate, status, profile, plugin-check, review, qa, spec, test-driven-development); `SLASH_COMMAND_TOOL_CHAR_BUDGET=60000` → 0 name-only, listing 30k → 47k chars (~+5.7k tokens). Once packs shrink the listing, set the budget in settings.json `env` to the smallest value that leaves 0 name-only in the full profile (measured with the ctxprobe bench), and record the cost.
  - Spikes listed: nested skills in a pack, `/reload-plugins` after a settings change, claude.ai connectors per project (interactive session only), user-scope MCP moved into packs (higgsfield first).
  - Proof: two concurrent conversations in one project and two projects, canaries prove different listings, MCP and hooks per pack; `/context` per profile; old global toggling gone and nothing references `skills-disabled/`.
  - Cleanup: `lib/profile.sh` symlink toggling + `skills-disabled/` (24 entries), user-scope plugin toggling in `set|apply|reset`, Makefile `profile*` targets rewired, `/profile` skill rewritten for packs, plugin-gate prose tied to global toggling, banner hint "/plugin-check before starting a new project", doctor profile checks, profile tests rewritten; `lib/profiles/*.profile` stay as the definitions.


## RE-CHALLENGE 2026-10-25 (Fable) — synthesis

Lenses: correctness CONCERNS(13), robustness FATAL(18, 1 BLOCKER),
simplicity CONCERNS(14), native-features guide (CLI 2.1.308, code.claude.com),
own bench r3 (gitflow finish ask rules G1-G7). Facts re-verified by main:
reconcile.sh:60-67 drops the entry's own header while BLK-032..034 carry
`[resolved]` there (false-open); brainstorming vendored + gitignored
(.gitignore:78); nothing machine-reads `## Index` (analyze-before-plan.md:42,
reconcile.sh:9).

### BLOCKER (robustness 1) — closed by plan change
hard_deny naming mod disarm paths/sources → the auto classifier would refuse
all later mod maintenance and every `--plugin-dir` bench. CHANGE: hard_deny
names only off switches (`~/.claude/<mod>.json` `"enabled": false`,
`enabledPlugins` false, `disableAllHooks`) and "never edit
`permissions.ask/deny` to pass a gate"; never a path, file or source line.

### Cross-phase changes
- P-A proof budget (simp 15): a moved path rule gets a static check
  (frontmatter parses, each glob matches ≥1 `git ls-files` path per project)
  + one session logged by the InstructionsLoaded hook. Model canaries only
  for hook/mod levers.
- P-B status model (corr, rob, simp 12): one parser, "last status-bearing
  line wins", own-header `[tag]` read first; fix reconcile_blk_current_status.
  No Meta backfill, no fourth status location.
- P-C Index (simp 13): remove the four generated Index blocks in one
  /prune-memory curation; `memory.sh index` prints it on demand; drop the
  Index steps in capitalize, ship-feature, commit-changer, prune-memory §D.
- P-D doctrine never deleted while a mod replaces it (corr, rob): phase 3
  "cleanups" become jit-marks; mod-off contract = text still present.

### Phase 0
- KEEP gitignore socle; ADD `!.claude/rules/` (directory-form ignores would
  untrack rules).
- CHANGE higgsfield MCP (simp 4, guide): one-time user-run `claude mcp remove
  -s user higgsfield`; no toggle-external ownership, no doctor check; the
  phase 5 pack `.mcp.json` owns it. `disabledMcpjsonServers` does not reach
  user-scope servers; the `/mcp` toggle writes `~/.claude.json`.
- CHANGE proof budget → P-A.

### Phase 4a
- SHRINK to `memory.sh add|status|journal|check|index` + flock on add + P-B
  + P-C. Validator runs inside `add`/`check`, not the generated pre-commit
  (undecidable there, exits 0 on working branches anyway).
- DROP Meta backfill (434 entries), `scope`/`critical` labels, English
  validator (1 of 1,290 entries above 1% accents), Index==generated check.
- ADD per-file v2 marker: 8 v1 projects keep working, doctor warns.

### Phase 1
- Design work (simp 9): append the section to rules/web-building.md (same
  globs); design-toolchain-reminder.sh keeps a one-liner pointing there
  (2,131 fires logged: no 1.5k per fire).
- SPA/language/API (simp 10): one lib/architecture-defaults.md read by our
  own skills; Web APIs into rules/rest-api.md; no empty-dir injection; no
  edit in vendored brainstorming.
- Supabase / cloud functions: path rules fail open at scaffold → keep the
  always-on lines in CLAUDE.global.md, body path-scoped in
  rules/secure-by-default.md (supabase/**, functions/**, migrations).
- Graphify threshold: one always-on line stays.
- DROP "origin line" item (session-start.sh:240-251 already prints it).
- ADD agent description diet here (simp 1): trim `description:` in
  agents/*.md (5,755 of 9,098 chars), no mod, no canary.

### Phase 5
- Profiles: lib/profiles/<name>.json is the source of truth, no generator,
  no `~/.claude/profiles/` artifact (simp 19).
- Detection: /plugin-check advisor maps to pack profiles; session-start
  prints one line when no profile is set; no fingerprint (simp 6).
- Cleanup list += lib/toggle-external.sh (retire or rewire to packs),
  lib/tests/higgsfield.test.sh, the CLAUDE.global.md toggle line, every
  writer of the old layout (install-plugins.sh, update-all.sh, gstack, 21st).
- `autoMemoryEnabled:false`: migrate existing auto memories first
  (faunosteo, jeux-deploy, robin-petier), doctor warns.
- Enable scope: `--settings` conversation copy when present, else
  `.claude/settings.local.json` (local > project > user); never user scope
  mid-skill. `skillOverrides` does not reach plugin skills: packs hide by
  disabling. Router rows must also match `<plugin>:<name>` (test).

### Phase 2
- Merge gate → native ask rules, no mod (simp 7, bench r3):
  `Bash(bash */gitflow.sh finish*)`, `Bash(gitflow_finish*)`,
  `Bash(git merge *)`; evaluate `Bash(git pull *)` and `git push x:develop`
  forms. Trade-off: BDR-068 /close auto-finish gets one dialog click (ask
  beats allow, no exemption). The three-condition exception detector was
  never true anyway (finish runs in the user's reply turn).
- Routing guard hosted in model-router (owner of `turnMain.source`; mod
  state is plugin-private): write free when `turnMain.source ∈ {skill,
  model}` this turn or a `/route` sticky; Edit/Write/NotebookEdit only; Bash
  write forms deferred until a measured evasion; the deny names the skill;
  hard_deny gains "a guard redirect is not a refusal to route around".
- Shell deny hygiene: keep rtk rc=3 passthrough + re-pin + twin census.
  Interpreters (`python3 -c` 211, `node -e` 450 calls in 14 days, 491 from
  sub-agents) → autoMode soft_deny prose, not static ask. Static ask only:
  `Bash(sh -c *)`, `Bash(bash)`, `Bash(sh)`, `Bash(bash -s*)`,
  `Bash(bash <(*)`. Replace `Bash(/*)` (kills rtk absolute twins) by
  `Bash(/bin/sh *)`, `Bash(/bin/bash *)`, `Bash(/usr/bin/env bash*)`,
  `Bash(/usr/bin/env sh*)`. Deny `Bash(awk *system(*`.
- Commit-msg hook: DEFER (4 of 78 commits over 50 words since
  lib/commit-message.md; generated hooks miss 6 of 7 repos on
  `core.hooksPath=.githooks`). Code-limit hook stays (462 of 19,161 added
  lines over 80 cols).
- Alternative noted: mods `tool.check` (2.1.304+) returns ask/deny after
  PreToolUse; still heavier than an ask rule.

### Phase 3
- DROP skill listing filter, `contexts` field, census (phase 5 packs +
  SLASH_COMMAND_TOOL_CHAR_BUDGET already give 0 name-only lines); routing
  hint classifier (no measured miss; table lines move into our skills'
  descriptions, ≤3 lines for vendored aliases stay); agent listing rewrite
  (phase 1 diet); higgsfield deltas. `prompt.attachment` kinds are not
  confirmed by the docs text (types file only).
- REMAINS: prompt.compose deltas for doctrine a carrier replaced + P-D.
  Phase 3 becomes CONDITIONAL: measure the always-on residual after
  0/4a/1/5/2; build only if the residual a mod can carry conditionally is
  worth it. Shared rules (jit-marker, $.state ledger) move into 4c.

### Phase 4b-4d
- 4c = intent rerank (14/22) + error 4-gram (exact); digest in
  session-start.sh on `source: compact|clear` (SessionStart matchers;
  mods' session.compact only skips); SubagentStart twin if needed. Defer
  read-path triggers, Bash command triggers, "critical → deny once",
  Tier 1, cross-repo index, memory_search.
- 4b: redact at capture, bounded ring, gitleaks in add; $.store 4 MiB cap.
- 4d: deferred until an injection log shows misses or noise.

### Not verified / residual
- `updatedInput` then deny: measured here (deny after rewrite); docs silent.
- `$.ui.ask` inside a sub-agent: unverified, moot with the native gate.
- Path rules after compaction: unproven (rob minor).
