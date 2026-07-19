# ANALYSIS: model-tiering v2 — Fable = orchestration + plan/solution reflection only; dispatched fleet tiered opus/sonnet/haiku by task complexity; split mixed-tier agents

Produced by /analyze (main loop, Fable) + 4 subagent sweeps (2× agent-body
classification, dispatch map, test-lock inventory), 2026-07-19. Facts verified
against: model-routing.test.sh, challenge-plan.md, verify-secure-loop.md,
model-gate.md, BDR-050/061/066/076, LRN-113/125/126 (read in full inline).
Subagent-reported details not re-verified inline are marked (sub) — LRN-132
applies: re-verify load-bearing ones before cutting code.

## CONTEXT

- Current state (branch `feature/opus-pin-audit-agents`, 2 commits, UNMERGED):
  main loop = session model (Fable; model-gate blocks small models in 15
  reflection skills). Dispatched pins: opus = analyzer, plan-challenger,
  seo-analyzer, geo-analyzer, validator-analyzer (BDR-076); sonnet = 14
  executors; haiku = status-reporter. Unpinned = interviewer,
  client-handover-writer (inline-load only).
- Two execution modes with OPPOSITE tier semantics: Agent() dispatch →
  frontmatter pin applies; inline-load ("you become it") → pin INERT, runs on
  session model. 20 inline-load sites exist.
- Target policy (user directive): Fable does ONLY main-loop orchestration +
  reflection on plan/solution. Everything dispatched runs opus (deep judgment)
  / sonnet (standard execution) / haiku (mechanical) by ACTUAL task
  complexity. Agents mixing classes get split. Skills adapted. Zero loss, zero
  regression.

## KEY COMPONENTS — per-agent verdict vs target

### Fits, no change
| agent | tier | note |
|---|---|---|
| plan-challenger | opus | coherent monolith; verdict grammar + PROOF load-bearing |
| feater / bugfixer / hotfixer | sonnet | closed-plan executors; NEED-DECISION / BLOCKED valves |
| security-auditor | sonnet | deterministic SAST gate; `SECURITY — VERDICT:` grammar |
| scaffolder | sonnet (effort: high) | but see INERT-PIN below — never dispatched today |
| status-reporter | haiku | exemplar mechanical |
| client-handover-writer | none (inline orchestrator) | one haiku-able seam: STEP 1-2 git/context preflight |
| interviewer | none (inline) | INTERACTIVE — asks user inline; a dispatched agent cannot ask (uniform ban). Structurally main-loop. |

### Tier-down candidates (no split)
| agent | current → candidate | evidence |
|---|---|---|
| validator-analyzer | opus → sonnet | NOT mixed: runs external validators (authoritative), fixed severity tables, base-100 deduction scoring, allowlist-driven fix bundle; ambiguity punted to user §6. No deep judgment present. (sub) |
| onboarder | sonnet → haiku candidate | template-fill + conditional writes; only light stack-block filtering. (sub) Also inert-pin today. |
| release-executor | sonnet (keep, borderline) | mostly script runs + CHANGELOG templating, but carries a NEED-DECISION judgment valve (MAJOR-bump wording). (sub) |

### Split candidates (mixed classes inside one body)
| agent | geometry (factual boundary) | complication |
|---|---|---|
| seo-analyzer | collection (STEP 2-5 curls/CWV/GSC/greps → haiku-class) / judgment (STEP 6-11 sampling, competitive, scoring, triage → opus) / templating (STEP 12-14 bundle+report → sonnet/haiku) | BDR-061: no Agent tool in analyzers (single-dispatch doctrine) → a split must be ORCHESTRATED BY THE SKILL at L1 with disk handoffs, or BDR-061 revised (nesting works ≥2.1.172 per BDR-060, but version-robust-by-design was chosen). seo-data.test.sh locks `fetch.sh` wiring strings IN the agent body (6 locks). STEP 1-2 context feeds every later step → large LRN-126 contract surface. |
| geo-analyzer | identical 3-way geometry | same complications; shares severity vocab + sentinel |
| commit-changer | MODE propose (narrative reconstruction + capitalize routing = deep) / MODE apply (stage+commit = mechanical) — boundary ALREADY exists as dispatch modes | 2 dispatch sites in /commit-change; per-dispatch `model=` override is an available lighter mechanism than a file split |
| doc-syncer | drift detection + semantic doc-type analysis + MINOR/SIGNIFICANT calls (deep) / discovery + template render + PATCHED_FILES emit (mechanical) | 9 consumers on BOTH modes: dispatched ×2 (/doc, onboard) + inline-load ×7 (bugfix, hotfix, feat, init-project ×2, ship-feature, scaffolder) — LRN-125 dual-use-across-tiers hazard; runs its own user validation gate (STEP 8) → gate must be hoisted before any dispatch conversion |
| handover-doc-writer | synthesis/vulgarization STEP 10-12 (deep) / render+deterministic gates STEP 13-16 (mechanical) | skill-leak ban list + `HANDOVER-DOC REPORT` grammar must survive |
| plugin-advisor | detection PHASE 1 (mechanical) / complexity scoring + decision-table reasoning PHASE 2.5 (deep) | INERT PIN: inline-loaded ×4 (plugin-check, onboard, init-project, ship-feature), NEVER dispatched — sonnet pin is dead config; PHASE 4 asks the user (inline-only capability) |
| verifier | STEP 2 evidence adjudication = deep judgment inside a sonnet procedural gate | BDR-066 kept sonnet DELIBERATELY (oracle-anchored to contract, ≤3×/loop). Tier-up = design arbitrage, not a mechanical fix. contract-verifier.test.sh locks name/tools/body (33 asserts). |

### INERT-PIN finding (structural gap vs target)
scaffolder, onboarder, plugin-advisor are pinned sonnet but NEVER dispatched —
inline-load only → they run on Fable today. doc-syncer's doc-commit steps
(bugfix/hotfix/feat/init-project/ship-feature/scaffolder) also run inline on
Fable. Under the target policy these are EXECUTION tasks burning Fable — a
bigger real gap than any pin value. Each inline→dispatch conversion must hoist
its user gates into the dispatcher first (dispatched agents cannot ask).

## CONSUMER MAP (summary; full tables in the dispatch-map sweep)

- ~50 Agent() dispatch sites across 20 skills + 2 lib includes +
  client-handover-writer (9 internal dispatches, incl. skills-via-general-purpose).
- 20 inline-load sites (7× doc-syncer, 4× plugin-advisor, 3× analyzer, 2×
  interviewer, 1× each onboarder/scaffolder/client-handover-writer/refactorer).
- Includes: model-gate.md ×15 skills (+5 locked EXCLUDED), challenge-plan.md
  ×12, verify-secure-loop.md ×5, contract-interview ×5, capitalize-commit ×6,
  doc-commit ×6.
- ~30 prose refs claim current tiers (sonnet-pinned X, opus-pinned Y, BDR-066/
  BDR-076 citations) → all go stale on tier changes (LRN-113 sweep required).
- Only onboard uses explicit `model="opus"` dispatch params (7 sites); every
  typed agent relies on frontmatter pin; ship-feature/init-project mandate
  `model: "sonnet"` on SDD subagents by prose.

## CONSTRAINTS (zero-loss bar)

1. Verbatim machine-parsed grammars must survive verbatim: `VERIFY — VERDICT:
   CONFORME | ECARTS(n) | ERROR(<reason>)`, `SECURITY — VERDICT: PASS |
   BLOCK(n) | ERROR(<reason>)`, `CHALLENGE — LENS: … — VERDICT: SOLID |
   CONCERNS(n) | FATAL(n)`, mandatory `PROOF:` lines, sentinel `READY TO APPLY
   — awaiting dispatcher confirmation`, `<NAME>-EXEC REPORT` + `STATUS : DONE
   | NEED-DECISION | BLOCKED`, `PATCHED_FILES:`, `COMMIT PLAN`, labeled score
   lines parsed by client-handover extractors, `HANDOVER-DOC REPORT`.
2. BDR-050 + LRN-083: loops + decisions live in the MAIN loop; gates dispatched
   fresh, blind, zero iteration history. Splits must not move loop decisions
   into children.
3. BDR-061: seo/geo/validator have no Agent tool by doctrine (version-robust
   single dispatch level). Any intra-audit split is skill-orchestrated at L1
   unless BDR-061 is explicitly revised.
4. LRN-126: every implicit data path (ARGUMENTS flags, detected vars, STEP-N
   side outputs) must cross the new handoff contracts explicitly; census-style
   tests will NOT catch severed wires — a data-flow read per split is required.
5. LRN-125: no dual-use agent across tiers; audit consumer routes to the
   judgment agent, execution consumer to the executor.
6. Interactivity: dispatched agents cannot ask the user. All human gates
   (AskUserQuestion / inline approval) stay in main loop or inline-loaded
   orchestrators. doc-syncer STEP 8 + plugin-advisor PHASE 4 gates must be
   hoisted before dispatch conversion.
7. Test locks (fire on this refactor): model-routing (~61, epicenter — pins,
   dispatch strings, gate wiring loops, `model="opus"` literals, BDR-076 token),
   plan-challenger (~43 — frontmatter, grammar, challenge-plan doctrine
   sentences incl. BDR-066 token), loops-light (40 — verify-secure-loop 10
   sentences, sonnet pins, report grammars, "Agent" ABSENT from
   bugfixer/hotfixer — substring-fragile), contract-verifier (33),
   security-auditor (31), seo-data (6 body-wiring locks on seo/geo bodies),
   loops-heavy (19 skill prose), review-guards G3 (strict YAML on every agent
   file incl. new ones), no-vacuous-locks (no `\n` in new lock patterns —
   LRN-093), model-check (10 — tier vocabulary big/small; a new tier taxonomy
   must co-evolve witness + test). Census `for`-loops (model-routing:13-19,
   plan-challenger:42) must be edited for any new/renamed gated skill.
8. model-gate.md prose has NO deterministic lock (include-path only) — free to
   rewrite, but behavioral-only verification.
9. Gitflow: feature branch(es) via gitflow.sh; no merge without human signal.
   Unmerged branches in flight: `feature/opus-pin-audit-agents` (this refactor
   supersedes/absorbs it), `bugfix/seo-geo-integrity` (10 commits touching the
   seo surface → sequencing/conflict risk with a seo-analyzer split).
10. BDR-076 survival: opus tier for judgment agents survives as baseline;
    validator-analyzer's opus pin would be superseded (tier-down); seo/geo pins
    refined by splits; challenge-plan/plan-challenger doctrine text + census
    §11 rewritten again.

## RISKS

- Severed implicit data paths on splits (LRN-126 precedent: 2 silent input
  losses caught only by whole-branch review) — probability: HIGH without a
  per-split data-flow pass.
- Consumer staleness (LRN-113): ~30 prose refs + 9 identical gate preambles +
  2 census loops — partial sweep leaves contradictory doctrine — probability:
  HIGH without whole-surface grep + new guards.
- Lost human gates on inline→dispatch conversions (doc-syncer STEP 8,
  plugin-advisor PHASE 4) — probability: MEDIUM-HIGH; hoist-first pattern
  exists (BDR-066 wave 4 did exactly this for client-handover).
- Census under-coverage: NEW agent files are silently unlocked unless
  model-routing/census extended per agent (worse than a red) — MEDIUM.
- haiku reliability on long tool chains (seo/geo collection legs: GSC, CWV,
  curl loops, retry policies): only haiku precedent is status-reporter
  (short, deterministic) — MEDIUM; unproven.
- Split overhead: 3-dispatch audit pipeline re-serializes STEP 1-2 context per
  child; latency + token duplication vs today's monolith — MEDIUM.
- Merge sequencing with `bugfix/seo-geo-integrity` (10 commits on seo surface)
  — MEDIUM.
- Subagent-report trust (LRN-132): (sub)-marked classifications need spot
  re-verification during design — MEDIUM.

## OPEN QUESTIONS (design arbitrage needed)

1. verifier: keep sonnet (BDR-066 oracle-anchored rationale) or lift to opus
   (STEP 2 adjudication is the correctness gate)?
2. seo/geo split mechanics: skill-orchestrated L1 pipeline (BDR-061-compatible)
   vs nested dispatch inside the analyzer (requires revising BDR-061;
   version floor OK per BDR-060)?
3. Which inline-loads convert to dispatches (scaffolder, onboarder, doc-syncer
   doc-commit steps, plugin-advisor detection) vs stay inline as reflection?
4. commit-changer: file split vs per-mode `model=` override at the 2 existing
   dispatch sites?
5. haiku scope: which mechanical halves actually go haiku vs sonnet, given the
   reliability unknown on long tool chains?
6. Gate taxonomy: keep binary big/small model-gate (guards main loop only) or
   extend model-check.sh to the full 4-tier vocabulary?
7. Sequencing: land/absorb `feature/opus-pin-audit-agents` and
   `bugfix/seo-geo-integrity` before or during this refactor?

## DESIGN AMENDMENT (2026-07-19, user arbitrage — supersedes open questions)

User approved all 7 recommendations, PLUS one addition:

**No-inherit rule + fable pins.** No dispatched agent may inherit the session
model anywhere. Every dispatch site carries an explicit tier: typed agents via
frontmatter pin (`model: fable|opus|sonnet|haiku`), built-ins
(general-purpose / Explore / Plan) via a `model=` param at EVERY call site.
Rationale: sessions may run on another model (gate admits Opus; user may
launch anything) — inheritance would silently mis-tier dispatched work.
`model="fable"` lands where a dispatched child performs REFLECTION /
ORCHESTRATION on behalf of the main loop:
- client-handover-writer's 8 internal general-purpose skill-runner dispatches
  (/seo, /harden, /cso, /commit-change, /web-validate runs) — today they
  inherit; they host gated orchestration → `model="fable"`.
- Doctrine line (model-gate.md or routing doctrine): ad-hoc reflection
  dispatches from the main loop (Explore digest, Plan, general-purpose) carry
  `model="fable"`; non-reflection ad-hoc dispatches carry their complexity
  tier. New census locks accordingly.
- No TYPED agent moves to fable tier (plan-challenger/analyzer stay opus per
  approved verdicts). Inline-loads that remain (interviewer,
  client-handover-writer, analyzer-in-/analyze + DEBUG, init STEP 2) ARE the
  main loop — covered by model-gate, not pins.
- External/gstack skills with inheriting general-purpose dispatches
  (design-shotgun, review, graphify) — external ownership (BDR-015 class):
  covered by doctrine, not edited, unless owned locally. Verify ownership at
  implementation.

## TARGET MODEL MAP — ship-feature (example, per-step)

| Step | What runs | Where | Model (target) | Δ vs today |
|---|---|---|---|---|
| MODEL GATE | witness + self-check | main loop | session (Fable; Opus admitted) | — |
| 0 plugin check | detection probes | dispatched (plugin-advisor detection half) | haiku | today inline on session |
| 0 plugin check | complexity scoring + reco | dispatched (advisor judgment half) | opus | today inline on session |
| 0 plugin check | apply gate (user) | main loop | Fable | — |
| 0b/0c context + ctx7 | trivial bash probes | main loop | Fable (trivial) | — |
| 0d read-before digest | analyzer | dispatched | opus | pinned (BDR-076) |
| 0e contract | contract-interview + micro-gates | main loop | Fable | — |
| 1 brainstorm | superpowers:brainstorming | main loop | Fable | — |
| 2 plan | superpowers:writing-plans | main loop | Fable | — |
| 2b challenge | 3× plan-challenger | dispatched | opus | pinned |
| 2b synthesis + RE-THINK | severity merge, plan revision | main loop | Fable | — |
| 3 validation gate | human gate | main loop | Fable | — |
| 4 SDD implement | per-task implementers + reviewers | dispatched | sonnet (explicit `model:"sonnet"`) | — |
| 4 task decomposition / verdict arbitration | SDD driver | main loop | Fable | — |
| 4b error diagnosis | analyzer DEBUG (inline) | main loop | Fable (reflection on the solution) | — |
| 5 verify + secure | verifier, security-auditor (fresh) | dispatched | sonnet | — |
| 5 loop decisions | ECARTS/BLOCK routing | main loop | Fable | — |
| 6 code review | reviewer (superpowers) | dispatched | **opus explicit** | today INHERITS (leak) |
| 7 capitalize | registry gate + commit | main loop | Fable | — |
| 8 doc sync | doc-syncer | dispatched | sonnet | today INLINE on session |
| 9 finish | gitflow + human go | main loop | Fable | — |

## TARGET MODEL MAP — init-project (example, per-step)

| Step | What runs | Where | Model (target) | Δ vs today |
|---|---|---|---|---|
| MODEL GATE | witness + self-check | main loop | session (Fable; Opus admitted) | — |
| 0 plugin check | detection / scoring / gate | dispatched haiku / dispatched opus / main loop Fable | (as ship-feature) | today inline |
| 1 interview | interviewer (interactive Q&A) | main loop (inline — a dispatched agent cannot ask) | Fable | structural |
| 1 contract | contract-interview | main loop | Fable | — |
| 2 analyze brief | analyzer (inline — greenfield design reflection) | main loop | Fable | stays inline |
| 3 design | superpowers:brainstorming | main loop | Fable | — |
| 4 gate #1 + contract enrich | human gate | main loop | Fable | — |
| 5 scaffold | scaffolder | **dispatched** | sonnet (effort: high) | today INLINE on session — pin inert |
| 5b readme bootstrap | doc-syncer | **dispatched** | sonnet | today INLINE |
| 5c/5e/5f ctx7 + anim + gitflow init | deterministic bash | main loop | Fable (trivial) | — |
| 6 plan | superpowers:writing-plans | main loop | Fable | — |
| 6b challenge + synthesis | 3× plan-challenger / merge | dispatched opus / main loop Fable | — | pinned |
| 7 gate #2 | human gate | main loop | Fable | — |
| 8 SDD implement | implementers + reviewers | dispatched | sonnet | — |
| 8b graphify | bash | main loop | Fable (trivial) | — |
| 9 verify + secure | verifier, security-auditor | dispatched | sonnet | — |
| 10 code review | reviewer | dispatched | **opus explicit** | today INHERITS (leak) |
| 10b capitalize founding BDRs | registry gate | main loop | Fable | — |
| 10c doc sync | doc-syncer | **dispatched** | sonnet | today INLINE |
| 11 finish | gitflow + human go | main loop | Fable | — |

## RELATED MEMORY

- IN FORCE: BDR-066 — model routing waves 1-4 — the architecture being
  re-tiered; its rationale table is the baseline [accepted]. BDR-076 — opus
  pins on dispatched judgment — starting state, partially superseded by the
  new target [accepted, this branch]. BDR-050 — verify+secure loops in main
  loop, gates fresh [accepted]. BDR-049 — verifier fresh+blind+disk-contract
  [accepted]. BDR-048 — pinned semgrep gate [accepted]. BDR-061 — fix-bundle
  → L1 apply, analyzers have no Agent tool [accepted]. BDR-060 — nested
  dispatch floor v2.1.172 [accepted]. BDR-075+amendment — challenge phase in
  12 orchestrators [accepted]. BDR-025 — unknown never silently passes
  [accepted]. BDR-022 — doc-syncer never touches .claude/ [accepted].
  LRN-125 — no dual-use across tiers. LRN-126 — splits sever implicit data
  paths; forward every consumed field. LRN-113 — whole-surface sweep + guard.
  LRN-083 — loops in main loop. LRN-093 — no `\n` in grep locks. LRN-096 —
  flip-test new guards. LRN-112 — nesting supported. LRN-105/107 — explicit
  tool bans in read-only mandates. LRN-011 — one subagent, N gated scores
  (alternative to 3-way split). LRN-057 — match mechanism to consumer.
  LRN-102 — final-text-only rendering guarantee. LRN-132 — subagent claims
  need verification.
- ALREADY SEEN: BLK-004 — renamed/deleted agent files broke a consumer wrapper
  [resolved] (rename sweep discipline). EVAL-023 — BDR-066 post-merge ronde
  found 5 edge gaps [done] (plan a ronde here too). EVAL-026 — 3-way plan
  challenge caught 4 real BLOCKERs on its own plan [done] (run it on this
  refactor's plan).
- NON-BINDING: ~200 remaining headings surfaced nothing binding beyond the
  above — BDR-067/068/069 (release/permissions), LRN-first-100 (tooling),
  BLK-005..017 (env) — counted, not detailed.
- SELECTION: scanned ~230 headings — surfaced 28 = in-force 22 + seen 3 +
  non-binding (counted).
