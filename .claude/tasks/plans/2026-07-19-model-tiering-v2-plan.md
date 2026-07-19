# PLAN: model-tiering v2 — full framework re-tier + splits

Input: `.claude/tasks/plans/2026-07-19-model-tiering-v2-analysis.md` (read it
first — consumer map, test locks, LRN/BDR constraints live there).
User arbitrage (2026-07-19): 7 recos approved + no-inherit/fable-pin amendment
+ Fable scope = REFLECTION / ORCHESTRATION / PLANNING / LOGIC only.

## D0 — DOCTRINE (end state)

1. Main loop (session model, gated big by model-gate) keeps ONLY: brainstorm,
   plan, contract, loop decisions, gate arbitration, human interaction,
   conversation-context work (capitalize), trivial glue bash (<~1k tokens).
   Retention criteria (any suffices): interactive | needs conversation context
   | orchestration decision | dispatch overhead > step cost.
2. NOTHING dispatched inherits. Typed agents: frontmatter pin. Built-ins
   (general-purpose/Explore/Plan): explicit `model=` at EVERY call site.
   VERIFIED (2026-07-19 spike, closes robustness BLOCKER): `model: "fable"`
   on a dispatch resolves to claude-fable-5 at runtime (echo spike via
   general-purpose); the harness enum-validates the `model` param — an
   invalid value fails LOUDLY (InputValidationError), no silent fallback.
   Call-site `model=` takes precedence over a typed agent's frontmatter pin
   (documented Agent-tool contract); fallback direction if a call site omits
   it = the frontmatter pin, i.e. today's behavior — fail-safe, never worse.
3. Tiers: fable = dispatched reflection-on-behalf-of-main-loop (skill-runner
   children ONLY); opus = deep judgment (audit scoring, plan critique, drift
   semantics, review, synthesis); sonnet = standard execution from closed
   instructions + collectors AND probes (wave-1 prudence — robustness MAJOR:
   plugin PHASE 1 is a ~26-call branching bash chain, not a short probe);
   haiku = status-reporter ONLY in wave 1; haiku expansion = wave 2 after
   reliability proven per candidate.
4. Grammars/sentinels/valves survive VERBATIM (list in analysis §CONSTRAINTS).
   Loops/gates stay in main loop (BDR-050/LRN-083). Fix-bundle → L1 apply
   (BDR-061) preserved: audit agents never get the Agent tool.
5. Every split: LRN-126 data-flow pass (enumerate child-read fields vs
   parent-set; explicit handoff contract on disk or in prompt) PLUS an
   IN-WAVE planted-input smoke proving the fields cross the dispatch boundary
   at runtime — the smoke GATES that wave's merge (confirmation MAJOR:
   enumeration is design-time reading; census can't catch severed wires; a
   split must never reach develop empirically unproven). Every change:
   LRN-113 whole-surface sweep + census lock + flip-test (LRN-096, no `\n` in
   patterns LRN-093, strict YAML G3).

## D1 — AGENT END STATE

Pins (frontmatter):
- opus: analyzer, plan-challenger, seo-judge*, geo-judge*, doc-auditor*,
  plugin-reasoner*, handover-synthesizer* (*new, from splits)
- sonnet: feater, bugfixer, hotfixer, code-cleaner, refactorer, verifier,
  security-auditor, scaffolder (effort high), onboarder, release-executor,
  commit-changer, doc-syncer (patcher half), validator-analyzer (TIER-DOWN
  from opus), seo-worker*, geo-worker* (2-way split per domain — simplicity
  MAJOR: collector+templater both sonnet in wave 1 → one worker file with
  `MODE: collect | template`, no cross-domain share: domain bodies genuinely
  diverge), handover-renderer* (renamed handover-doc-writer render half),
  plugin-probe* (wave-1 prudence; haiku candidate wave 2)
- haiku: status-reporter (only)
- none (inline-only, main loop, gate-protected): interviewer,
  client-handover-writer
Per-dispatch `model=` overrides (no new file): commit-changer propose=opus /
apply=sonnet (2 sites in /commit-change — precedence over the sonnet
frontmatter pin is the documented Agent-tool contract, verified direction
D0.2; the pin stays as the no-inherit fallback = today's behavior; both
call-site strings census-locked + W3 behavioral smoke); SDD
implementers+reviewers
sonnet (already prose-mandated → make it a census lock); code-review steps
(ship-feature 6, init-project 10) = opus explicit; client-handover-writer's 8
general-purpose skill-runners = fable; onboard's 7 general-purpose = opus
(keep); any Explore/Plan ad-hoc reflection dispatch = fable (doctrine line in
model-gate.md + CLAUDE.global routing note).

Splits (each = new agent file(s) + handoff contract + census + consumers):
S1 plugin-advisor → plugin-probe (SONNET wave 1; PHASE 1 CLI probes → PROBE
   REPORT) + plugin-reasoner (opus; PHASE 2/2.5 scoring + reco → PLUGIN CHECK
   block). PHASE 3-4 report+apply-gate HOISTED into ONE shared include
   `lib/plugin-gate.md` (simplicity MINOR — doc-commit.md ×6 pattern, never
   4 hand-copies), referenced by the 4 consumers (plugin-check, onboard
   STEP 0, init-project STEP 0, ship-feature STEP 0) — main loop. The
   pre-recommendation validation checkpoint (advisor :201-212, straddles the
   seam, can skip PHASE 4) runs IN THE CONSUMER between the two dispatches
   (correctness MINOR); its inputs (toggle-external availability,
   project-signal presence) are PROBE REPORT fields. Handoff: PROBE REPORT
   fields = plugin list, toggle state, profile, CLI/anim/monorepo/embedded
   signals + checkpoint inputs (enumerate ALL PHASE-2-read fields).
S2 doc-syncer → doc-auditor (opus; STEP 3-4 drift + semantic analysis + A3
   MINOR/SIGNIFICANT call w/ doc-shape.sh oracle → DRIFT REPORT [AUTO]/
   [HUMAN] items) + doc-syncer (sonnet; render/patch half, keeps
   PATCHED_FILES: grammar + BDR-022 bans). Validation gate stays in
   DISPATCHER (/doc skill, orchestrator steps) — auto-mode flows: auditor →
   dispatcher applies AUTO via doc-syncer → SIGNIFICANT escalates inline.
   Consumers rerouted: /doc, onboard, + doc-commit steps in bugfix/hotfix/
   feat/init-project(×2)/ship-feature (inline→dispatch conversion) +
   scaffolder PHASE 6 (scaffolder DISPATCHES nothing — it has no Agent tool:
   README bootstrap moves to init-project STEP 5b dispatch of doc-syncer).
   PLUS (robustness MAJOR): rework `lib/doc-commit.md`'s in-thread contract
   BEFORE converting any doc-commit site — it requires the orchestrator to
   "hold the patch context" to compose the rc-0 CHANGE SUMMARY (the review
   surface that replaced the removed MINOR gate). Dispatched doc-syncer adds
   a `CHANGE SUMMARY` block to its report grammar (per patched file: what
   changed and why, ≤1 line each); doc-commit.md's composer consumes THAT
   instead of in-thread context; census-locks the new field + a planted-input
   smoke proves the summary crosses the dispatch boundary.
S3 seo-analyzer → 2-WAY (simplicity MAJOR — 3-way was YAGNI while collector
   and templater share the sonnet tier; commit-changer mode-precedent):
   seo-worker (sonnet; `MODE: collect` = STEP 2-5 signals → SIGNALS file;
   `MODE: template` = STEP 12-14 FIX BUNDLE + sentinel + SEO.md + envelope)
   + seo-judge (opus; STEP 6-11 sampling judgment, competitive, scoring /20,
   trajectory, triage → FINDINGS+PLAN). Orchestrated by /seo at L1 (BDR-061
   conserved: no Agent tool in either). Wave-2 option: carve `MODE: collect`
   into a haiku file once proven — the mode boundary IS the future cut line.
   HANDOFF (robustness MAJOR — freshness/atomicity): run-scoped paths
   `.audit/seo-signals-<RUNID>.md` / `.audit/geo-signals-<RUNID>.md` —
   `.audit/` is the GITIGNORED derived-artifact tree (confirmation MINOR,
   LRN-124: a crash-stranded transient with scraped GSC/competitor content
   must never be committable; `.claude/audits/` keeps only the SEO.md/GEO.md
   deliverables). RUNID minted by the dispatcher per run, passed to every
   stage; the file ENDS with `COLLECTION COMPLETE — RUNID: <id>` and the
   judge FAILS CLOSED (report ERROR, never score) if the file is absent,
   RUNID mismatches, or the completeness sentinel is missing; dispatcher
   cleans the file post-run.
   DISPATCHER CONTRACT (confirmation MAJOR — fail-closed at the judge must
   not fail OPEN at the pipeline): on a judge ERROR the orchestrator
   (/seo /geo /harden /onboard) STOPS — no template dispatch, no L1 apply —
   surfaces the ERROR verbatim, retries ONCE with a fresh collect+judge,
   then escalates to the human. A mute or ERROR judge is NEVER carried into
   templating (verify-secure-loop discipline). This handler is part of the
   W5 skill rewrites, census-locked.
   Explicit field list per LRN-126 (STEP 1-2 business+tech context consumed
   by ALL later steps — full enumeration REQUIRED before cutting).
   seo-data.test.sh locks (fetch.sh wiring) move with the worker body —
   update suite same commit.
S4 geo-analyzer → geo-worker (sonnet, 2 modes) + geo-judge (opus) — mirror of
   S3 incl. run-scoped `.audit/geo-signals-<RUNID>.md` + the same dispatcher
   ERROR contract. No cross-domain file share:
   seo vs geo bodies genuinely diverge (different checks, scoring blocks,
   envelopes) — that divergence, not LRN-125, is the reason.
S5 handover-doc-writer → handover-synthesizer (opus; STEP 9 memory-registry
   load + STEP 10 phase clustering + STEP 12 6-chapter synthesis — STEP 9
   allocated here, it feeds the synthesis; correctness MINOR) +
   handover-renderer (sonnet; STEP 13-16 annex render, precheck apply,
   deterministic gates, HTML/PDF). client-handover-writer dispatches
   synthesizer then renderer; PACKAGE contract split per LRN-126
   (re-enumerate DEPLOY_HINTS/--skip-seo class fields — the EXACT prior
   failure). W4 MUST same-commit relock model-routing.test.sh:52-55 (the
   handover-doc-writer name + dispatch-string locks break on the rename;
   "make test green per wave" D4 invariant — correctness MINOR).
Tier-downs (no split): validator-analyzer opus→sonnet (deterministic
   validators+tables). onboarder stays sonnet wave 1 (haiku candidate wave 2).
   release-executor stays sonnet (NEED-DECISION valve).
Verifier: STAYS sonnet (approved — oracle-anchored gate).

## D2 — SKILL MAP (main loop = session model; every dispatch tier explicit)

Gated reflection skills (model-gate kept, 15):
- ship-feature / init-project: per the two example maps in the analysis file
  (amendment section) + S1 gate hoist at STEP 0 + doc-commit conversions.
- feat: scope/plan/contract/loop = main; challenge 3× plan-challenger opus;
  feater sonnet; verifier+security sonnet; doc-commit → doc-auditor opus +
  doc-syncer sonnet dispatch; commit via /commit-change (propose opus / apply
  sonnet).
- bugfix: investigation/diagnosis/contract = main (reflection); challenge
  opus (3b); bugfixer sonnet; verifier+security sonnet; doc-commit as feat.
- hotfix: LOCATE + guard = main (logic); challenge opus when guard fires;
  hotfixer sonnet; security gate sonnet (revert-not-loop conserved);
  doc-commit as feat.
- analyze: analyzer INLINE = main loop (it IS the reflection) — unchanged.
- code-clean: PHASE 1 audit inline = main (audit judgment feeding a human
  gate); code-cleaner sonnet PHASE 2 (hosts refactorer inline at SAME tier —
  LRN-125 OK); re-audit sonnet inside executor.
- seo / geo: skill = orchestration + GATED arbitrage (main); pipeline
  collector sonnet → judge opus → templater sonnet (L1 serial); appliers
  hotfixer/feater sonnet at L1; build-verify inline.
- web-validate: validator-analyzer sonnet; hotfixer applier sonnet; loop main.
- harden: audit dispatch follows S3 narrow-scope path (seo-judge opus on
  harden axes w/ collector reuse); direct-Edit apply stays inline (tiny
  scope, BDR-061 carve-out conserved).
- audit-delta: axis audits dispatched opus (delta judgment); security-auditor
  sonnet; fix gate + markers = main.
- tour: orchestration main; security-auditor sonnet; cleanup audit = analyzer
  opus (or general-purpose model="opus"); fixes via sonnet appliers; doc axis
  → S2 pipeline; reconcile axis = deterministic bash (main).
- onboard: onboarder DISPATCHED sonnet (was inline); plugin S1 pipeline;
  analyzer opus; general-purpose audits model="opus" (kept); seo/geo → S3/S4
  pipelines; security-auditor + doc pipeline as above; synthesis
  general-purpose model="opus"; backlog arbitration = main.
- client-handover: writer INLINE (orchestrator, main); its 8 skill-runner
  children model="fable"; handover S5 split (synth opus → render sonnet);
  gates all main.
Excluded-from-gate skills (5, stay ungated): commit-change (propose opus /
  apply sonnet via model=; approval gates main); doc (S2: auditor opus →
  gate main → patcher sonnet); status (haiku); release-candidate (executor
  sonnet; version/when/push decisions main); refactor (refactorer sonnet).
Memory/util skills (capitalize, close, prune-memory, reconcile, learn,
  profile, skills-perso, gitflow, deploy, plugin-check(S1), status): main
  loop by nature (conversation context, human gates, deterministic bash) —
  no dispatch changes except plugin-check S1.
External/gstack skills (graphify, design-*, review, qa, ship, investigate…):
  NOT edited (external ownership, BDR-015 class) — covered by doctrine line;
  local wrapper skills only if locally owned. Verify ownership per file
  before touching (symlink → skip).

## D3 — WAVES (each = gitflow feature branch, tests green, census extended)

W0 SEQUENCING: merge `feature/opus-pin-audit-agents` → develop (baseline,
   human gate). `bugfix/seo-geo-integrity` is ALREADY MERGED (correctness
   MAJOR — the TODO.md "UNMERGED" note was stale; verified `92301fe` is an
   ancestor of develop AND this branch): no arbitrage, no W5 wait — one-line
   ancestry re-check in W0 + fix the stale TODO.md entry (reconcile-class
   correction). Absorb the analysis+plan files into the new feature branch.
W1 NO-INHERIT ENFORCEMENT (small, high-value): code-review model= opus
   (ship-feature 6, init-project 10); client-handover-writer 8× model="fable";
   doctrine line in model-gate.md + census locks (`model="fable"`,
   `model=` presence per site); SDD sonnet prose → census lock. Prose sweep
   of stale BDR-066/076 claims touched by W1.
W2 INLINE→DISPATCH CONVERSIONS: scaffolder (init 5 — liveness pings move to
   orchestrator; scaffolder loses PHASE 6 inline-load → init 5b owns README
   via S2), onboarder (onboard), doc-commit steps ×5 flows → S2 pipeline
   (gate hoist FIRST: /doc + flows own the validation gate; doc-syncer body
   loses its inline gate → census re-lock), S1 plugin split + gate hoist ×4
   consumers. Data-flow pass per LRN-126 on each (fields enumerated in the
   wave's contract file before edits).
W3 TIER MOVES: validator-analyzer → sonnet (pin + prose + census flip);
   commit-changer per-mode model= (2 sites + prose + census).
W4 S5 handover split (synth opus / render sonnet) + PACKAGE re-enumeration.
W5 S3/S4 seo/geo pipelines: worker(2-mode)/judge ×2, /seo /geo /harden
   /onboard rerouted, seo-data.test.sh moved locks, run-scoped signals
   handoff (RUNID + completeness sentinel + fail-closed judge),
   envelope/sentinel/score grammars verbatim, COVERAGE lines preserved.
W6 DOCTRINE + CLOSE-OUT: model-gate.md rewrite (protects main loop; tier
   table; fable-dispatch doctrine), challenge-plan.md + plan-challenger
   ORCHESTRATOR PROTOCOL text (keep BDR-066+BDR-076 tokens per census, add
   BDR-077), census consolidation (model-routing new sections; every new
   agent: YAML G3, pin lock, dispatch-string lock, AskUserQuestion/Agent
   bans), LRN-113 whole-surface prose sweep (~30 refs list in analysis),
   BDR-077 + LRN entries + journal, EVAL-023-style post-merge ronde.
   Per-split planted-input smokes run IN their own waves (W2/W4/W5, merge
   gates) — W6 is the consolidated ronde only, never the first empirical
   proof of a split.

## D4 — ZERO-REGRESSION PROTOCOL (every wave)

- Before edits: wave contract file (.claude/tasks/contracts/) with FILE SCOPE
  + acceptance criteria; challenge-plan on THIS plan (done once, below);
  verify-secure-loop on each wave's diff (verifier sonnet + security sonnet).
- Grammar diff-guard: `grep -F` each verbatim marker (analysis §CONSTRAINTS
  list) pre/post per wave — zero drift.
- Census: flip-test every NEW lock (plant violation → RED) before trusting.
- `make test` green per wave; no wave merges without human signal (gitflow).
- Rollback story (robustness MINOR — waves are textually interdependent, an
  early wave is NOT independently revertible after later merges): revert in
  REVERSE merge order, or revert the whole stack; never a mid-stack single
  revert. Pre-merge, the rollback unit is the wave branch.

## CHALLENGE LOG (2026-07-19 — 3 blind lenses on plan v1)

- correctness: CONCERNS(2) — seo-geo-integrity phantom sequencing (fixed W0);
  commit-changer precedence ambiguity (fixed D1 + D0.2 citation + W3 smoke);
  3 MINORs (S5 STEP 9 + W4 relock; plugin checkpoint seam; templater label)
  — all fixed in place.
- robustness: FATAL(4) — BLOCKER fable-dispatch unverified → CLOSED by spike
  (D0.2: resolves to claude-fable-5, enum-validated, loud failure); doc-commit
  in-thread contract (fixed S2: CHANGE SUMMARY crosses the report grammar);
  plugin-probe haiku contradiction (fixed: sonnet wave 1); signals handoff
  freshness (fixed S3: RUNID + sentinel + fail-closed); rollback claim
  (fixed D4).
- simplicity: CONCERNS(1) — 3-way seo/geo YAGNI → 2-way worker/judge (fixed
  S3/S4); twin-templater share (dissolved by 2-way; divergence stated);
  plugin gate ×4 copies → lib/plugin-gate.md include (fixed S1).
- Confirmation pass (fresh robustness challenger on v2): CONCERNS(2) — v1
  fixes HOLD (doc-commit CHANGE SUMMARY, plugin-probe sonnet, rollback order,
  fable spike, RUNID); 2 new MAJORs + 1 MINOR opened by the revisions, all
  fixed in v3: (a) per-split planted-input smokes moved IN-WAVE as merge
  gates (W6 = ronde only); (b) dispatcher ERROR contract on judge failure
  (STOP, no templating/apply, retry once, escalate — pipeline never fails
  open); (c) transient signals files relocated to gitignored `.audit/`
  (LRN-124). Protocol cap reached (1 re-challenge) → to the human gate.
