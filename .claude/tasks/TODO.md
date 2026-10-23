# TODO

## Open (reconciled 2026-10-23, /reconcile)
Done history before 2026-10-08 removed 2026-10-23 (git keeps it: `git log -p -- .claude/tasks/TODO.md`); decisions live in `.claude/memory/`.

### Actionable
- [ ] deferred (BDR-123): remap inline-writing best-tier skills (design Build stack, writing-skills, deprecation-and-migration, /tour single-project, /audit-delta 3d, /harden STEP 3); stale citers skills/feat/SKILL.md:6, skills/code-clean/SKILL.md:36; + impeccable row in routing.json (design Build stack has none; frontend-design has `reflect`; census test pins the table)
- [ ] parked (GATE 2 LOW, 5a98c2c): probe table names not checked with `IDENT.fullmatch` per table (a `/` walks a path on the approved Supabase host); `printable` lets Unicode bidi/format controls (U+202E, U+2066…) through to the tty
- [ ] profile name charset check (LOW, security gate): `^[A-Za-z0-9_-]+$` on the cached profile / `<prof>` argument before it becomes a path in `read_profile()` (lib/profile.sh:154-156) and install Step 11
- [ ] P22 `make new-skill` scaffold: agent stub lacks `effort:` pin, skill stub lacks entry level, body loads `.claude/agents/$(name).md` instead of `$HOME/.claude/agents/<name>.md` → /hotfix; also: no routing.json row reminder
- [ ] `lib/tests/design-tool-gate.test.sh` reds on any machine with the 21st CLI installed ("FAIL precondition: system-wide 21st present, CLI_ABSENT case not hermetic") — pre-existing on develop (fa67664), independent of the diff. Make the CLI_ABSENT case hermetic (PATH shim / stubbed probe) so `make test` is green on a design-profile machine. Until then full-suite oracles (`make test` exit 0) cannot be MET here.
- [ ] post-run-D residuals (gates, 2026-10-07): settings.json soft_deny names only `gitflow.autopush false` → add "or an unparseable value" (restriction only, settings run); capitalize STEP 6: manual mode with `ahead` = 0 (user pushed by hand between merge and read) matches no closing line, and the 5C `ahead` = 0 bullet still says "(auto-push mode did it)"; release-executor:86 line > 80 cols; push-guard header line 4 > 80 cols (pre-existing); unpushed-guard Stop silence now also covers a missing lib (SessionStart names it) — accepted
- [ ] gitflow LOW leftovers (run B, rest done in run D 472cccb): `--end-of-options`/`--` on refname args and `printf %q` in copy-paste hints; `gitflow_delete`: check `_gitflow_checkout_containing_base` rc (lib/gitflow.sh:270) before `--unset-upstream`

- [ ] docker host-root mount spellings uncovered by deny (security gate 2026-10-23, pre-existing): `--volume /:/x`, `-v=/:/x`, `--mount type=bind,source=/,...`; prove each with a harmless analogue (`--settings` one-rule file) before adding
- [ ] 6 dead deny entries (`Bash(docker run * -v /:*)`, `Bash(git push * :*)`, 4 `Write(...)`) kept by the push-guard T41/T42 non-weakening lock; drop them with a justified-removal list in T42 at the next release (working forms added 2026-10-23)

### Release 3.0.0
- [ ] MIGRATION.md "Upgrading to 3.0.0" (CHANGELOG Unreleased says breaking: typed `/effort-*` removed; only the 2.0.0 section exists)
- [ ] routing.json `confirmed` (15 agents, 11 phases, 3 skills) ships to every clone (by design: decisions travel); revisit at the 3.0.0 cut
- [ ] CHANGELOG [2.0.0] "Linux `make test` still to be done after 2.0.0" is stale: suite green on Linux (bchanot-server, 2026-10); note it under Unreleased
- [ ] BLK-018 decide at 3.0.0: release-executor finish span vs classifier (did not recur at 2.0.0, no fix applied)

### Docs backlog (doc-sync 2026-10-06)
- [ ] P17 README restructure to Standard-Readme (Install / Usage / Configuration / License); move inline reference parts to USAGE.md, CONFIGURE.md from settings.json + .env.example
- [ ] P18 README Requirements line (Linux apt/dnf/pacman + macOS brew): Linux run done, write the line
- [ ] P31 USAGE narrative: Exemple 9 "sans superpowers" (vendored, always on), "Edit tool" bypasses /hotfix, Pattern E + Exemple 9 route bugs to /ship-feature instead of /bugfix|/hotfix
- [ ] P32 USAGE missing sections: design work (21st CLI, design stack, /site-motion), media generation (Higgsfield toggles), gitflow auto-push + global hooks
- [ ] P33 USAGE token figures ("Budget Pro ~11k tokens/5h", per-pattern) have no source in code — verify or drop
- [ ] P34 USAGE + agents/plugin-advisor.md "gstack ON/OFF", "context7 ON" vocabulary — gstack is per-profile, ctx7 is a CLI; move both together
- [ ] P41 templates/settings/settings.json: `permissions.ask` entries (npx, docker rm, make deploy, psql…) inert under defaultMode auto → config fix, not doc

### User decisions and hand edits
- [ ] user decision: pin a commit for higgsfield-ai/skills and a version for `@higgsfield/cli` (security gate, 2 MEDIUM, accepted as is)
- [ ] user hand edit pending: remove the four `Bash(npm … -g|--global *)` lines from `permissions.deny` (they override the classifier); then the first global install is the live test of the entry

### Blocked
- [ ] G2 `hooks/guard-bash.sh` (BLK-022, safety classifier withheld the body): PreToolUse Bash, exit 2 + reason, `logger` trace, fail-closed without jq; spec `lib/tests/guard-bash.test.sh` (214 cases) SKIPs until it exists
- [ ] launch claude with `TMPDIR=$HOME/.cache/claude-tmp` in `dtach_claude()` (~/.bashrc), user side (BLK-021)

### Model-router live checks (opportunistic, need a real session or incident)
- [ ] LIVE CHECK after `/reload-plugins`: best-tier phase w/ Fable out of credits → `/route show` lists fable down (probe), main on opus, effort bumped.
- [ ] LIVE CHECK: does `parentModel` follow the turn.step rewrite or the session model? Read general-purpose's step-0 `message.model` in a transcript during a demoted turn (if it is already the session model, the pin is a harmless no-op).
- [ ] W1-C live verification part 2 (needs a real incident): StopFailure vs turn.complete order; `PostModelSwitch` `auto` semantics and its `from_model` after a router upgrade; whether a router rewrite raises `auto`; `[1m]` carry validity on opus (only on a session whose steps carry it)
- [ ] W4-B AC9: type a few plain prompts, read `route: classifier <phase>` (verbose line with `/route verbose on`), drop `bookkeeping` if it misfires
- [ ] W3-A: a parallel same-agent dispatch answered after > 10 s; what an unanswered dialog resolves to on the terminal (must be Later or nothing written). T1 skill-row dialogs seen live (f8665b2, d3635b6)
- [ ] cold-read cap on the opus session: a coding prompt → spinner `sonnet-5-5/medium`; above 120k cold read the skip line once; `/route show` cap text

### Optional backlog (user call)
- [ ] router: `/route set`, `/route confirm`, `(unconfirmed)` in show, dialog edits of phases, frontmatter auto-alignment, session-start warning when routing.json is dirty, per-machine `projects`.; step heuristics, quota-aware downgrade, A/B
- [ ] gates.sh could refuse a CHECK holding `<<`
- [ ] per-skill positive/negative prompt ranking (Tier 2 second half), not started
- [ ] frame floor-guard snippets as data in the verifier step (LOW)
- [ ] graphify pilot on robin_petier: graph + `.graphifyignore` + gitignore `graphify-out/` + `GRAPHIFY_FORCE=1 graphify update .` in the post-commit hook when a graph exists

### Parked
- [ ] Higgsfield parked (final review, rulings in BDR-109): remedy line ignores a pinned lock version (latent while `latest`); Step 8.6 spawns `higgsfield version` up to 3 times; rollback needs `npm uninstall -g @higgsfield/cli` + session removal + hand removal of `skills-external/higgsfield-*`
- [ ] Higgsfield parked (per-task minors, none blocking): "rename" comment vs rm-then-mv; no `--` before the clone URL; ssh URL can prompt; no sweep of a stale `.higgsfield-stage.*`; timeout path itself untested; "pack not installed" when only unlisted skills are synced; doctor version read unbounded
- Reticle pilot recipe: section "2026-09-27" below (trigger: first app-type project, BDR-103)

### Known limits (accepted, no action)
- model-router spawn path unprobed: 1st gate of an outage window dies once (seen live 2026-10-23, retry lands on the opus floor); tour/onboard/audit-delta no retry; onAutoSwitch with main on opus marks nothing if the engine auto-falls a gate off Fable
- Residuals (accepted): explicit `Agent(model:"fable")` pins (client-handover) still fail w/o credits (BDR-115 kept); spawn path not probed; session model itself out of credits → CLOSED 2026-10-16 c11cd3b (kept cur probed too); no cross-session persistence → ≤8 s stall per new session; timed-out probe keeps retrying in engine (no cancel); `[1m]` gating unverified (bare id probed); no Esc regression test (kit cannot abort signal); probe sleep eats ~8 of 10 s `turn.step` budget.
- Residuals left (accepted): TTL known only after the first PostModelSwitch of the process (no API exposes the account TTL; 60 min default before); hooks-below `context` and a dropped prompt leave the estimate conservative/stale; `onAutoSwitch` targets main's `lastPlan` even for a sub-agent's auto fallback (pre-existing); `agent_id: null` on a main switch (if the engine ever sends null) would freeze sessionModel/TTL updates.
- W1-C accepted-by-design (security 2026-10-09, MEDIUM, not coded around;): (1) the model itself can raise the main loop to fable for the rest of a turn through the `route` tool (plan/reflect/escalate/judge) or a background dispatch (derived orchestrate = best tier) — bounded by the turn and `upgradeMaxTokens`, no sticky route is model-callable; (2) CLOSED by feat C 786ee13 (keywords, ultrathink and derived orchestrate set effort only). Residuals: `PostModelSwitch` `auto` covers "other programmatic change" (a healthy model could be marked 15 min); strikes never decay inside a session; a `[1m]` variant's `model_not_found` marks the base model until reload; classifier deferred to W2. 2026-10-23 feat C 786ee13: (1) derived-orchestrate part and (2) keyword/ultrathink part CLOSED (effort-only routes); (1) route-tool lift stays by design (sanctioned path)
- W3-B residuals: SKILL.md symlink follow (LOW, kept: `skills/` itself is a symlink); `descs` cap and "(custom)" label untested. (security-auditor `changed` entry purged 2026-10-11.)
- W4-B: W4-B residuals: `smallModelBusy` assumes the engine's small model is the `haiku` alias (`$.model.classify` takes no model: documented in code 2026-10-11, no fix possible); abort paths judged by reading only; the 3-s tests pin the upper bound only.
- W3-A residuals (security LOW, accepted): non-atomic cross-process write (two sessions, crash mid-write → file reads as failed, previous config kept); `host/path` of a private remote in the tracked file; a persistent write failure re-asks every use (`asked.delete` in the catch); `out.length` vs byte size at the cap; `changePatch` scope 'project' with a vanished key writes Everywhere (cwd change mid-dialog).

## History (2026-10-08 → 2026-10-19, done)
## 2026-10-19 — guardrails split: /a11y + injection/exposure (feature/a11y-split-inj-exp)
- [x] run — SDD 9/9, gates 0/1/2 green, opus review Importants fixed (c0fdbec, 9275e0d, 63a88bc), capitalize BDR-122 LRN-219..221 BLK-032; merge = user go
- [x] parked review Minors + GATE 2 residuals (probe `supabase.url`, redirects, `_nonempty_rows`, printable) → /bugfix 2026-10-21, 5a98c2c + 633faa2, BLK-033
- [x] routing policy /feat (user 2026-10-19, BLK-032): settings model → Opus 5.5; `judge` split (security-auditor + verifier → Fable, plan-challenger/analyzer/code review → opus); executors stay sonnet, "what to write" on opus; ceiling rule: main on Fable never writes code beyond a hotfix edit → dispatched executor; BDR superseding part of BDR-066 / BDR-115.
  - [x] feat A audit phase: d3635b6 (dialog writes, session model opus), a7d747c (audit row, opus floor, census, citers), dae142b (docs); gates 0/1/2 green, LRN-224
  - [x] feat B (feature/routing-ceiling-rule): ceiling rule CLAUDE.global.md, README doctrine, challenge citers, deploy `effort: xhigh`, routing.json `changed` cleared; ef13713 + 887cf89, gates 0/1/2 green, BDR-123; merge = user go
  - [x] feat C: cap the default keyword prompt rules (plan|design|architecture, why|review|audit|analyze, ultrathink) at the session model, effort only like the classifier; close BLK-032 after — DONE 2026-10-23 feature/router-keyword-cap: 786ee13 effort-only routes (keywords, ultrathink, derived orchestrate), d2d590f docs, gates green, BLK-032 resolved; merge = user go
  - [x] bugfix lib/tests/mods.test.sh (bugfix/mods-validate-advisory): verdict = `--strict` rc, positive control warnfix/cleanfix; 801992a, gates green, BLK-034 LRN-225; merge = user go. Residual: 3 historical contracts keep the old scrape oracle (BLK-034)

## 2026-10-18 — secure-by-default guardrails: 5 domains + /guardrails skill (feature/secure-by-default)
User ask: hosting, a11y, Supabase, SMS/email consent, cloud functions must be baseline on every project, API and access secured systematically, plus a skill that tests all of it.
Language call: scanner is Python stdlib, not Rust (default-language contraindication: skill scripts here are interpreted, no build step, same as explain-diff checker).
- [x] T1 `rules/secure-by-default.md` always-on (no `paths:`, BDR-085 path: CLAUDE.global.md is at 320/320)
- [x] T2 `skills/guardrails/scripts/` scanner: common, apis, hosting, a11y, supabase, messaging, functions + `scan.py` CLI (FAIL / WARN / MANUAL, exit 1 on FAIL)
- [x] T3 `skills/guardrails/SKILL.md` + `references/checks.md` (rule catalogue, manual items, live Supabase queries) + `test-prompts.json`
- [x] T4 `lib/tests/guardrails-scan.test.sh`: clean fixture passes, one mutant per FAIL rule
- [x] T5 wiring: security-auditor checklist (+ scanner run), interviewer failure-mode row, init-project founding table
- [x] T6 registration: profiles full/max/dev, routing.json row, README, USAGE x2, CHANGELOG
- [x] T7 `make test` all green (70 guardrails checks), shellcheck clean, 25/80/5/5 limits met; calibrated on 8 real projects (game, faunosteo, zenquality, robin_petier, alphalink, game-deploy, config, explanations), 9 false-positive classes fixed and locked by benign tests. Journal done. BDR-120 accepted, merged bee377a.
- [x] T8 passwords (user ask 2026-10-18): doctrine bullet in the rule (argon2id, no clear compare, no log, no literal, delegated auth), `checks/passwords.py` in the api domain (API-PASSWORD-PLAINTEXT / WEAK-HASH / LOGGED FAIL, LITERAL WARN), 8 mutants + 10 benign locks (89 checks), auditor maps PLAINTEXT to CRITICAL; calibrated on 7 projects: 0 hits after one FP fix (yaml volume mount `htpasswd:/etc/...`)
- [x] T9 live probe (user ask 2026-10-18, "attaque de l'exterieur ?"): `skills/guardrails/scripts/probe.py` read-only (GET/HEAD/OPTIONS, `--authorized` gate, env secrets, same-host redirect only, request budget, 25-req burst cap). 5 probes: anon-read, cross-user, no-auth route, cors-reflect, rate-limit. Suite `lib/tests/guardrails-probe.test.sh` 16/16 vs a localhost http.server fixture. SKILL STEP 5 + checks.md section + CHANGELOG/README/USAGE. Redirect-guard unit test blocked by the auto-mode classifier (SSRF-shaped fixture), guard is code-reviewed.
- Fix loop (user ask 2026-10-18): audit -> fix proposals (Fable via route plan) -> user accepts -> fixes applied -> re-pass proves all fixed. Reuse /bugfix circuit: contract with scanner oracles, bugfixer executor, lib/verify-secure-loop.md gates.
- [x] T10 scan.py `--assert-absent RULE:path,...` (contract oracle: exit + marker reflect only the listed pairs, positive control = domain applies + files>0) and `--baseline <json>` (re-pass: fixed / remaining / new); tests incl. positive control
- [x] T11 SKILL.md: model gate, STEP propose (grouped per rule+path, visible choices named, MANUAL = user steps), STEP approve (prose gate), STEP fix (gitflow aiguillage, contract + oracles, bugfixer, verify-secure-loop), STEP re-pass (baseline diff + probe re-run on go, max 2 rounds), commit gate
- [x] T12 citers: verify-secure-loop header, contract-interview flow list, bugfixer description, model-routing census adds guardrails
- [x] T13 docs: checks.md oracle section, CHANGELOG, README, USAGE, test-prompts
- [x] T14 make test green (scan suite 106: check modes + gates.sh UNMET->MET), oracle calibrated read-only on game: real hit -> PRESENT rc1, self-baseline -> NO-NEW rc0

## 2026-10-17 — /explain-diff skill: HTML explanation of a diff (feature/explain-diff)
Source: geoffreylitt gist `explain-diff-html` (Notion variant dropped). Built through the skill-creator loop (draft, evals with/without skill, user review).
- [x] T1 `skills/explain-diff/SKILL.md` (target resolution, understand, 4 sections, style, save outside repo, check, hand-over) + `test-prompts.json`
- [x] T2 `assets/template.html` (self-contained skeleton: light/dark tokens, TOC, diagram primitives, diff + quiz JS) + `references/components.md`
- [x] T3 `scripts/check_explanation.py` (deterministic floor: name, location, sections, TOC, 5-question quiz, code escaping, no ASCII art, no em-dash, self-contained) + `lib/tests/explain-diff-check.test.sh` (17 checks: valid page, raw template, one mutant per check)
- [x] T4 registration: full/max/dev profiles, routing.json row `reflect`, README + USAGE x2 + CHANGELOG
- [x] T5 skill-creator iteration 1 (runs on opus: Fable out of credits): 3 evals x (with skill, baseline), graded, pass rate 100% vs 45%; fixes faedb98 (arrow/edge class collision, bundled fill_template.py). Static viewer in session scratchpad. + iteration 2
- [x] T6 `make test` all green, shellcheck clean, `impeccable detect` [] on the template, contrast >= 5.8:1 both themes; commits b353fac faedb98.

## 2026-10-16 — impeccable = Build path for all UI (chore/impeccable-build-path)
User validated: frontend-design overlaps impeccable 4.6; gate still blocked on frontend-design. Supersedes the 2026-07-05 "complementary, keep both" call.
- [x] CLAUDE.global.md Build line: impeccable leads, frontend-design = light path only, rule count 45 -> 61
- [x] design.profile GATE-BLOCK: frontend-design out, impeccable in (frontend-design stays installed, profile-listed)
- [x] lib/design-gate.md: core-set prose + section 5 (impeccable now blocking, so only the PRODUCT.md check remains)
- [x] agents/plugin-advisor.md: frontend/design-system rows, package rows, two RULE blocks
- [x] 45 -> 61 detector rules: README, plugins.lock.json note, install-plugins.sh comment + echo
- [x] BDR-119 + CHANGELOG Unreleased + journal
- [x] make test: 1 red suite = known design-tool-gate precondition (21st CLI installed, see 2026-10-06 entry), shellcheck clean, impeccable resolves under skills/

## 2026-10-15 — short commit messages (feature/short-commit-messages)
- [x] `lib/commit-message.md`: lookup of a documented convention (README, CONTRIBUTING, CLAUDE.md, `.claude/` rules, commitlint, template), else 50 words max, medium technical level. Git log is not a convention.
- [x] Citers patched: commit-changer, bugfix STEP 6, feat STEP 5, hotfix STEP 4, client-handover-writer, CLAUDE.global.md (1 line, 320-line budget).

## 2026-10-15 — model-router: probe a move target before routing main to it (bugfix/router-probe-before-route)
Contract `.claude/tasks/contracts/2026-10-14-router-probe-before-route-0005.md`, plan r3 `.claude/tasks/plans/2026-10-14-router-probe-before-route-0005.md`.
- [x] /bugfix run: Fable out of credits routed (BLK-030, LRN-218); r1 → r3; 497 tests, verifier CONFORME 11/11, security PASS; commit 2cccc43 + docs.

## 2026-10-13 — model-router: cold-read cap, switch on by default, classifier routes down (feature/router-downgrade-cap)
Contract `.claude/tasks/contracts/2026-10-13-router-downgrade-cap-0013.md`, plan r3 `.claude/tasks/plans/2026-10-13-router-downgrade-cap-0013.md`.
- [x] /feat run: 3 lenses (10 MAJOR) → r2; confirmation pass FATAL(7) (BLOCKER: served record only on routed steps) → r3; feater DONE (19 tests + 3 extra, 450 pass), GATE 0 MET 4/4, verifier CONFORME 10/10 first pass, security PASS. Commit 2ce203a.
- [x] Residuals (1)-(3) closed 2026-10-13, commit 1be57a3 (contract `.claude/tasks/contracts/2026-10-13-router-cap-residuals-1902.md`, plan r3): session pin for built-in `general-purpose` spawned by main below the session model; prompt-size estimate (text + context + typed skill body, code points / 3) added to the cap's size at the first main step unless usage grew by half; `document` attachment = unknown = blocked; engine `cache_ttl` ('5m'|'1h') adopted from main's PostModelSwitch. 3 lenses (2 BLOCKER same finding: frontmatter model invisible to the hook) → r2; confirmation CONCERNS(3) → r3; feater DONE 472 tests; verifier CONFORME 7/7; security PASS. Residual (4) "model unknown to the table" not reproduced since (later route answers named claude-fable-5-1): closed as transient.

## 2026-10-12 — code-clean whole repo (chore/code-clean)
- [x] audit r1→r3 (3 lenses + confirmation), user approved all 14 non-deferred items, code-cleaner DONE, make test 47 green — plan `.claude/tasks/plans/2026-10-12-code-clean-0103.md`, scope `.claude/audits/CODE-CLEAN-SCOPE.md`
- [x] fix BUGS-FOUND: toggle-external.sh usage() prints header 3-26, list ends at 32
- [x] C4/C5 deferred dedupes via /refactor (tool_kind/tool_source + shared gstack_* in lib/gstack-removed.sh; 496-run golden identical) (tool list ×4, profile/toggle-external twins)
- deferred: C1 gitflow-test.sh move (blocked: T19 drift lock), B13-B17 (no change by design)

## 2026-10-08 — model-router mod: one mod routes model + effort per request (feature/model-router-mod)
Plan `.claude/tasks/plans/2026-10-08-model-router-mod.md`. Decisions 2026-10-08: main-loop
model switch spike-first then flag off; load via `CLAUDE_CODE_PLUGIN_DIRS` + link.sh;
migration of shifters/pins/model-gate in wave 2 after proof; names model-router / route / /route.
- [x] W0 spike in dev-mods (hot reload): facts a-d established 2026-10-08 (plan file § Spike facts); e moved to W1.10
- [x] W1-A the mod in `mods/model-router/` (b721c94, contract `2026-10-08-model-router-w1a-1533`, plan r3): challenge 3 lenses + 1 confirmation (2 BLOCKER + 10 MAJOR closed by named changes), feater DONE first pass, GATE 0 MET 5/5, verifier CONFORME 6/6, security PASS (4 MEDIUM + 5 LOW reported, below)
- [x] W1-A hardening (user go "oui durcis", contract criteria 7-11): `/route` composer-only; no agent model axis (effort only after spawn); pattern ≤ 200 / scan ≤ 4096 / phase keys `^[a-z][a-z0-9_-]{0,31}$` / config ≤ 64 KB / `additionalProperties: false` / `typeof e.skill`; `warnOnce` in all 14 catches + config-drop logs; `safely` around post-`next` bookkeeping. feater DONE, gap round (dead `Loop.frozen`, spawn returns `started` verbatim, tool description), GATE 0 MET 9/9, verifier CONFORME 11/11, security PASS.
- [x] W1-A residuals CLOSED 2026-10-11 (bugfix/model-router-residuals): nested-quantifier patterns rejected (`NESTED_QUANT`); `stat.kind !== 'file'` → layer failed; rejected keys masked in logs (`keyWord`), alias keys `KEY_NAME`; route-tool catch text says the route may be partly applied. Left (accepted): `agentId` read from the flat tool event; closures without a kit test.
- [x] W1-B1 floor precedence (contract `2026-10-08-model-router-floor-1835`, 2026-10-09): `ultrathink` + typed `/effort-<l>` = the main turn's default AND minimum (r2 after 3 lenses: a pure floor made /effort-low a no-op); one helper `mainEffort`; per-axis precedence; mid-turn prompt floors now + next turn; `"enabled": false` per machine, kept across /clear and failed reload; typed slash attested. 30 tests; verifier CONFORME 6/6 (after 1 gap round); security PASS ×2
- [x] W1-B1 residuals CLOSED 2026-10-11: broken override at first load → router off (fail closed, logged); non-boolean `enabled` → off; `/route reload` answers `config unreadable; previous config kept`; `errWord` (name + code only) replaces every `String(err)` log. Superseded by W2-B: `skill.prompt` preload guard, `/effort-*` marker (bridge removed). Left (accepted): transient missing override lifts a config-set off (ENOENT must mean defaults on most machines); `/route show` display items (no defect named).
- [x] W1-B2 wiring (contract `2026-10-08-model-router-wiring-1835`, 2026-10-09): tracked symlink `skills/model-router` → `../mods/model-router` loads as `model-router@skills-dir` (fresh-process `claude plugin list --json` proves it), `.gitignore` `mods/*/tsconfig.json`, `lib/tests/mods.test.sh` (4 checks, capability probe, bounded, SKIP), doctor `── Mods ──` fail-soft, CLAUDE.md `## mods/`. Plan r2 from 3 lenses (5 MAJOR), feater DONE, gap round (4b label + unbounded probe), verifier CONFORME 8/8, security PASS
- [x] W1-B2 residuals CLOSED 2026-10-11: mods suite probe greps the `claude plugin test` usage line; doctor `plugin list --json` under `timeout 60`; update-all skips `@skills-dir` mods. Left (accepted): doctor `echo -e` helpers (tracked names only); fallback timeout guard orphans grandchildren without coreutils timeout.
- [x] W1 close-out (2026-10-09): doc-sync opus audit SIGNIFICANT → user go all 10 → patched (README effort routing + Explore row + /route, USAGE, ARCHITECTURE mods/, CHANGELOG Unreleased) b22f894; hot-reload link removed from `~/.claude/dev-mods/<session>/`; BDR-115 amended (a6e2003). Pending user: `/reload-plugins` in this session (new sessions load the skills-dir copy by themselves); merge decision on feature/model-router-mod (`gitflow finish`, human signal)
- [x] W1-C adaptive tiers (user 2026-10-09, contract `2026-10-09-model-router-tiers-1237`, plan r4 after 3 lenses + 2 confirmations: 6 BLOCKER + 29 MAJOR closed by named changes): phases name absolute tiers (best fable>opus>sonnet · big opus>fable>sonnet · work sonnet>opus · cheap haiku>sonnet); breaker fed by `classic.StopFailure` kinds rate_limit|overloaded|billing_error|model_not_found + `PostModelSwitch` auto (episode backoff 15→300 min, `/model` clears, `/clear` keeps, `/route reload` clears); fallback chain fable→opus→sonnet→haiku; main UPGRADE by default under `upgradeMaxTokens` 200k (fails closed on unknown usage), DOWNGRADE gated by `mainModelSwitch`; sticky `turnModel` per turn; derived `orchestrate` on background dispatches; prompt default rules (plan/reflect FR+EN, Unicode guards, skipped on `/…`, floor match, mid-turn). 58 tests; verifier CONFORME then 3 gap/hardening rounds; security PASS
- [x] W1-C live verification part 1 (2026-10-09 after `/reload-plugins`, skills-dir copy loaded, 12 hooks): derived orchestrate on a real background Explore (main high → medium while it ran → high after its end); Explore on sonnet/medium; `route plan` → next request xhigh (engine record); `Skill(effort-low)` bridged → next request low (engine record); `/route show` resolves all 10 phases to full ids, `down: none`; steps arrive as bare `claude-fable-5-1` (no `[1m]`) so the suffix carry never fires on this session
- [x] W2-A mod (2026-10-09, bb56f3e on feature/model-router-w2, contract `2026-10-09-model-router-w2a-1546`, plan r4 `2026-10-09-model-router-w2-1546`): user decisions — effort-* skills deleted (W2-B), pins REWORKED not deleted (rows = phases by role; frontmatter `model:`/`effort:` kept as census-locked off-state floor after a robustness BLOCKER), orchestrators declare phases, slim model gate. Phases `write` work/high + `apply` work/low; 56 skill rows, 21 agent rows; agents' model at spawn within tier, upward only, project-defined agents skipped (agent.offer); typed slash → name-bound marker (composer|sdk|bridge) + pending slot + idle fallback; best-tier rows in a `runMain` slot surviving turn end; unrowed skill leaves the route; route answer always names the id; `null` override rows. 3 lenses + 2 confirmations (1 BLOCKER each round closed), feater + 4 gap rounds, GATE 0 MET, verifier 3× ECARTS on coverage clauses only → user accepted at the cap, security PASS (2 MEDIUM pre-existing: first-load kill switch fails open, ReDoS size-bounded). Kit 58 → 88 tests. Doc-sync skipped for A (mod-only, docs at B).
- [x] W2 gate A→B (2026-10-10, engine records): typed `/status` → main low then medium during the dispatch; analyzer opus/xhigh from step 0 (frontmatter high) = spawn bookkeeping first, row beats frontmatter; status-reporter haiku step 0. Probe 3 dropped (gate always calls route). Probe 4 (typed skill while a background agent is live: marker vs fallback) NOT observed → limit in `lib/effort-shift.md`; re-check in the records whenever the user types a skill with an agent alive.
- [x] W2-B repo migration (2026-10-10, 1f2d33b, contract `2026-10-10-model-router-w2b-1045`): 15 citers → `mcp__model-router__route` per phase, `effort=` on built-in judgment dispatches + SDD sonnet implementers (`effort="medium"`), `lib/effort-shift.md` + `lib/model-gate.md` rewritten (witness = route answer, `/route on`), deletions (effort-*, effort-pins.*, model-check.sh, tests, installer blocks), bridge removed from the mod, census rewritten (140 checks, drift lock rows ↔ frontmatter), analyzer xhigh, CLAUDE.global.md Design-work line. Verifier ECARTS(7) → CONFORME 10/10, security PASS, full make test green (design-tool-gate env red). Docs P1-P8 user-approved; SemVer: breaking → next release 3.0.0 (MIGRATION section at release).
- [x] W2-A residuals CLOSED 2026-10-11 (first load fail closed, nested quantifiers, `errWord`, alias keys, `offers` capped at 256, `__proto__`/`constructor` keys tested). Known limits (unchanged): `skillCalls`/`spawning` counters are global; offers keyed by name only; builtin `/effort` is not a lever inside a run.
## 2026-10-10 — model-router wave 3-A: first-use route confirmation + decision memory (feature/model-router-confirm)
Plan `.claude/tasks/plans/2026-10-10-model-router-w3a-confirm-1201.md` r4, contract `2026-10-10-model-router-w3a-confirm-1201`. User decisions 2026-10-10: tracked routing.json reached through the plugin dir (no new link); blocking `$.ui.ask` dialog at first use; per skill row, agent row, main phase.
- [x] W3-A landed (22455c0, 2026-10-11): routing.json = phases + rows + decisions; T1/T2/T3 dialogs; project exceptions `projects[<normalized remote>]` in the tracked file (project-tree layer dropped: security); writers = dialog + `/route ask`; `/route pending`; census from the file with the `changed` WARN exemption; kit 86 → 190. Gates: 3 lenses + 1 confirmation (BLOCKER census), feater + 4 rounds, verifier CONFORME + re-verify, security BLOCK(1) credential leak fixed → PASS, full make test green (design-tool-gate env red). Live: T2 dialogs answered by the user (verifier Keep, feater Keep, security-auditor → implement then reset to verify on user go).
- [x] W3-B dialog with context (2026-10-11, 604a6c4, contract `2026-10-11-model-router-w3b-dialog-1240`, plan r3): descriptions (skill frontmatter / agent.offer / phase `about`), real id + effort in the question, Later / Keep / Change, model → effort (derived from the phases of that model) → scope, rows stay phases, T3 Later/Keep. 3 lenses (2 BLOCKERs on my r1 avoided) + 1 confirmation, feater + 2 rounds, verifier CONFORME (3rd), security PASS (4 LOW: symlinked SKILL.md read, TOCTOU, raw key in a log, any plugin hooking AskUserQuestion could answer). Live decisions: security-auditor → judge (kept, floor aligned `model: opus`), plan-challenger → verify (reset on user go), orchestrate Keep (T3 live check done).
- [x] "auto mode: use Bash/sed" block attributed to the mod: traced 2026-10-11 by reading, it is the harness's own auto-mode instruction rendered after the mod's MCP block; not in the mod source. Closed.
- [x] W3-C `/route forget` (2026-10-11, cd8d72f, contract `2026-10-11-model-router-w3c-forget-1457`, plan r3): name/all/projects, guarded restore, confirmation dialog for all/projects, no-write paths, docs. 3 lenses + 1 confirmation, feater + 3 rounds (1 real defect: `ForgetPlan` typo), verifier at the cap on coverage (user accepted), security PASS. Kit 232 → 284. Live: orchestrate + escalate T3 Keeps seen.
- [x] W3-C residuals closed in W4-A (68d7ea6). Live smoke of `/route forget` from the terminal still unseen.
- [x] W4-A transition logs + residuals (2026-10-11, 68d7ea6, contract `2026-10-11-model-router-w4a-logs-residuals-1637`, plan r3): verbose = transitions only (main line, hand-off per dispatch, agent moves, answered-by anomaly), stream lines removed, host prefix respected; residuals of W3-A/B/C closed (a)-(g). 3 lenses (BLOCKER: agent moves decided at spawn) + 1 confirmation, feater + 4 rounds, verifier at the cap on coverage (user accepted), security PASS + 2 MEDIUM fixed. Kit 284 → 358.
- [x] W4-A residuals CLOSED 2026-10-11: `errWord`; `logCall` → `tryLog`, `noteMain` refresh under `safely`.
- [x] push-guard argv check (2026-10-11, bugfix/push-guard-argv): the text match is now a prefilter; the command is split into simple commands (awk tokenizer: quotes, escapes, separators, heredoc bodies) and a push must be git's own subcommand (`push`/`send-pack`; `subtree`, wrappers, assignments, no-awk keep the text verdict). grep/heredoc/`git log -S`/`git stash push` over-blocks closed; `"git" push` miss closed. Suite 98 → 124 checks.
- [x] W4-B classifier (2026-10-11, e54a2b5, contract `2026-10-11-model-router-w4b-classifier-1858`, plan r3): `$.model.classify` on plain composer prompts with no route in force → turn effort only (design→plan, analysis→reflect, coding→implement, bookkeeping→apply, chat→nothing), 3-s race, abort not counted, 3 failures pause `cooldownMinutes`, no dialog, no file write, `classify` config key, `/route classify on|off`, status + verbose line. 3 lenses (BLOCKER: unbounded await) + 1 confirmation, feater + 1 round, verifier CONFORME (2nd), security PASS. Kit 358 → 428. Deviation from the TODO line: no first-use confirmation on classified phases (noise per prompt; T3 already confirms the phase).


## 2026-09-30 — Higgsfield pack: CLI + skills in the install process, off by default (feature/higgsfield-pack)
Contract `.claude/tasks/contracts/2026-09-30-higgsfield-pack-1412.md`, spec + plan under
`docs/superpowers/` (transient). Approved 2026-09-30: toggle pack off by default, two toggles,
routing lines, complete scope, TTY fix on ctx7 + 21st (option A), deny aliases.
- [x] /ship-feature run: 9 plan tasks, fix wave after the final review, doc sync, registries ([[BDR-109]])
- [x] user decision: close the remaining npm global-install spellings in settings.json deny (`npm i <pkg> -g`, `npm add -g`, `npm -g i`) — pattern grammar for a mid-string wildcard unverified ([[BLK-025]]) — CLOSED 2026-10-06 (reconcile, user go: soft_deny settings.json:472 names `npm add -g` + flag-after-package)
- feature/higgsfield-pack merged into develop 2026-09-30 (df6dbce, user go)
- [x] soft_deny "Global npm installs" entry merged 2026-09-30 (chore/npm-global-soft-deny)
- [x] (was) user decision pending: npm global installs from `deny` to a prompt tier — `ask` does not prompt under `defaultMode: auto` ([[BDR-090]]); option = one `autoMode.soft_deny` entry (vet the package first), deny lines removed by the user by hand — DONE 2026-09-30 (soft_deny "Global npm installs", 95168c1; reconcile 2026-10-06)

## 2026-09-27 — case 4 of the 6-repo review: reticle parked with a pilot recipe (chore/six-repo-review-notes)
User go "parquer avec la recette". Real gap (runtime store state, structured
verdicts with file:line, replayable flows, CI `gate --since`), no current project
needs it; cost = per-project build instrumentation in the client repo, ~4.9k
tokens of MCP schemas per session, PostHog telemetry on by default, a skill that
auto-runs `init` against "ask, don't guess". Trigger: first app-type project
(client state, forms, auth, cart).
- [ ] P1 external opt-in in lib/toggle-external.sh + profiles (off by default,
      qa-class); `@reticlehq/server` pinned in plugins.lock.json (plugin v3.3.0
      seen 2026-09-27), never `@latest`.
- [ ] P2 local wrapper skill replacing theirs: `npx @reticlehq/server init
      --dry-run` shown to the user, never run by the agent (runbook doctrine);
      MCP env `DO_NOT_TRACK=1` `RETICLE_TELEMETRY=0`; verify only after the
      user ran init.
- [ ] P3 pilot on staging only (secret redaction is name-based); flows
      committed, evidence gitignored; `gate --since` in CI evaluated before
      adoption.
- [ ] P4 measure tokens per verification loop vs gstack browse on one page.
Sources read 2026-09-27: docs/what-is-recorded.md, telemetry.md,
token-efficiency.md, enterprise.md (core verification free; SSO/SCIM/RBAC/
policy gates under ee/), LICENSE split FSL-1.1-ALv2 server+init, Apache
adapters/core/engine. Stars 898, created 2026-06-11, 2 551 commits.
