# PLAN — Adapt claude-config for the Claude 5 family (Opus 5 focus)

Date: 2026-07-30 · Branch (planned): feature/opus5-config-tuning (off develop)
KIND: build-plan · Author: main-loop session (Fable 5)

## 1. Context & evidence

Opus 5 (`claude-opus-5`, released 2026-07-24) now backs every `model: opus`
agent pin in this repo (analyzer, plan-challenger, seo/geo-analyzer,
plugin-advisor — BDR-076/077) and any session the user switches to via
`/model opus`. Its documented behavioral profile differs from Opus 4.8 in
ways that make parts of this config counterproductive:

- E1 **Over-delegation**: Opus 5 "delegates to subagents more readily than
  prior models" (official prompting guide). Opus 4.8 had the OPPOSITE trait
  (LRN-030), and `CLAUDE.global.md:43-47` was written to counter it
  ("Counters model tendency to under-delegate"). The premise is inverted.
- E2 **Anti-delegation already injected by the harness**: Claude Code
  v2.1.219 server-gates an Opus-5-only prompt section (`heron_brook` +
  `subagent_steer_delegation`, GitHub issue #80988) that says "Do not call
  the AgentTool unless the user requested it" and "Subagents multiply cost
  and time…". Stacking our own hard cap on top would triple-constrain;
  keeping a pro-delegation nudge would fight the injection. Model-neutral
  when-guidance is the stable middle.
- E3 **Over-verification**: official guidance — "If your prompt contains
  explicit verification instructions … remove them: instructions like these
  cause over-verification on Claude Opus 5, and removing them reduces wasted
  tokens with no loss in quality." Also true of per-prompt "double-check"
  phrasing. Targets PROSE told to the model, not harness-level gates.
- E4 **Scope expansion**: named Opus 5 regression ("can expand the scope of
  a task, adding steps that weren't requested"). Anthropic ships a literal
  counter-block; tested to reduce scope changes "to nearly zero".
- E5 **Literal instruction following** (since 4.7, stronger now): aggressive
  MUST/CRITICAL language over-triggers; conservative-reporting instructions
  ("only report high-severity") measurably depress recall in review/challenge
  harnesses.
- E6 **Longer written deliverables**: files written to disk run ~30-40%
  longer; `effort` does NOT control visible/deliverable length — only prose
  instructions do.
- E7 **Overconstraint costs reasoning**: Anthropic removed >80% of Claude
  Code's system prompt for Claude-5-generation models "with no measurable
  loss"; named mechanism = tokens burned resolving conflicting rules.
- E8 **Hook false positive (today)**: `\bux\b` in
  `hooks/design-toolchain-reminder.sh:47` fired on French prose ("changement
  ux vu" — matches after apostrophe/slash/space); 2nd `ux` FP in the log,
  both French. Continues the LRN-1005/1007 false-positive series. No test
  row covers `\bui\b`/`\bux\b`.
- E9 **Effort carry-over trap**: Opus 5 has no model-default effort hold in
  Claude Code — a persisted `xhigh` (our `settings.json:333`) silently
  carries onto Opus 5 sessions, against Anthropic's "start at high, sweep
  low/medium" guidance for that model.

## 2. Design decisions

- D1 The global instruction layer must be MODEL-NEUTRAL across the Claude 5
  family (sessions run Fable 5 by default; dispatched judgment agents run
  Opus 5; executors Sonnet). Fixes therefore express WHEN-guidance and
  outcome bars, not directional compensation for one model's trait.
- D2 Harness-level quality gates (fresh blind verifier + security-auditor,
  BDR-049/050; plan-challenge, BDR-075) are architecture, not model
  self-check prompting. They stay. E3 applies only to prose that tells the
  MODEL to verify its own work.
- D3 Per BDR-021, the Security and Architecture-decisions sections of
  CLAUDE.global.md stay verbatim (deliberate policy). No softening there.
- D4 Registries are append-only: LRN-030 is not edited; a new LRN records
  the trait inversion and points back to it.
- D5 Deterministic backstops (gitflow pre-commit, Gitea protection,
  permissions.deny, rtk pinning) are explicitly out of "more freedom" scope
  — community reports show Opus 5 working AROUND soft controls, which argues
  for keeping hard ones.

## 3. Work items

### W1 — CLAUDE.global.md: rewrite the delegation block (:43-47)
Replace the 5-line block (incl. "Default to delegation for multi-file
exploration. Counters model tendency to under-delegate.") with model-neutral
when-guidance, same footprint (≤5 lines):

```
- Sub-agents: one task per sub-agent, main context stays clean.
  Delegate genuinely independent, sizeable tracks (wide multi-file
  exploration, parallel audits) — not work doable in a few tool
  calls, and not self-verification (harness gates own that). Brief
  precisely, then commit to the delegation — don't redo its work.
```
Rationale: E1+E2. No hard spawn cap in prose (harness already injects one on
Opus 5; Fable benefits from delegation).

### W2 — CLAUDE.global.md: reframe "After code changes" (:75-83)
Keep the concrete quality bar; drop the proof-mandate/self-check phrasing
(E3). Replace steps 2-4 with faithful-outcome reporting:

```
## After code changes
1. Run tests, lint, build, type-check if available.
2. Report outcomes faithfully: what passed, what wasn't run,
   remaining risks, surviving deviations. Completion claims only
   for verified work.
3. Correction or notable event → capitalize to right registry.
```
Net: -2 lines. "Would staff engineer approve?" bar and "Don't mark complete
without proof" are removed as self-check choreography; honest-reporting
line preserves the intent (grounded completion claims) without mandating an
extra verification pass.

### W3 — CLAUDE.global.md: add scope fence (Workflow section)
Append (adapted from Anthropic's tested block, caveman-compressed, ~5 lines):

```
- Scope: deliver what was asked, at the scope intended. Routine
  judgment calls → decide alone; materially different readings →
  ask. Better approach spotted → say so in one line, still do the
  task as asked. Finish the whole task; genuinely blocked → do the
  rest, state plainly what's missing.
```
Rationale: E4. Complements existing "Scope changes to task — no unrelated
edits" (line ~15) without contradicting it.

### W4 — CLAUDE.global.md: add deliverable-length rule (Code style / Comments area)
~2 lines:

```
- Written deliverables (docs, reports, .md): length matched to what
  the task needs — no filler sections, no boilerplate summaries.
```
Rationale: E6. Registries already covered by caveman rule.

### W5 — Line budget
After W1-W4: expected ~309 lines. Hard check: `wc -l CLAUDE.global.md` ≤ 320
(session-start.sh warning threshold at :202-213).

### W6 — hooks/design-toolchain-reminder.sh: drop `\bui\b` and `\bux\b`
- Remove the two 2-char alternatives from the pattern at :47. Keep
  `ui/ux|ux/ui|ui kit` and all other tokens.
- Add a dated header comment (3rd tightening pass, 2026-07-30, cites the
  two French-prose `ux` FPs; series LRN-1005/1007).
- Trade-off accepted: a bare "améliore l'ux" prompt with no other design
  token goes quiet — the CLAUDE.global.md "Design work" section still
  routes it (the hook is a belt, self-described soft nudge).
- Update `lib/tests/design-toolchain-reminder.test.sh`: add 2 quiet rows
  (the real FP prompt excerpt; a bare "l'ui" French sentence) — flip-tested
  per LRN-096. Existing 9 must-fire rows unaffected (none uses ui/ux).

### W7 — agents/plan-challenger.md: coverage-first reporting line
Add one clause to the findings rules (add-only, no removal): uncertain or
low-severity findings are REPORTED with an explicit confidence + severity
tag rather than self-censored — severity filtering happens in the
orchestrator's synthesis, not in the challenger. Rationale: E5 (literal
Opus 5 + "manufactured concern is a failure" wording risks suppressing real
low-confidence findings). Must not touch: verdict grammar, MANDATORY PROOF
clause, blind-dispatch rules (test-locked in plan-challenger.test.sh).

### W8 — Memory + docs capitalization (same branch, follows the work)
- decisions.md: new BDR (config adapted for Claude 5 family — scope,
  rationale, alternatives incl. "leave config as-is" and "hard spawn caps"
  rejected).
- learnings.md: new LRN — Opus 5 behavioral profile (over-delegation
  inverts LRN-030's Opus 4.8 trait; over-verification; literal following;
  no effort hold on Opus 5 in Claude Code; heron_brook/#80988 injection).
- journal.md: one line.
- CHANGELOG.md: entry under Unreleased.

### W9 — Gates (before commit)
- `shellcheck hooks/design-toolchain-reminder.sh` clean.
- Manual flip-test of the hook: FP prompt → quiet; "redesign the navbar" →
  fires.
- `make test` full suite green (design-toolchain-reminder.test.sh,
  plan-challenger.test.sh, model-routing.test.sh untouched-but-must-pass,
  curated-config-guard, loops-light…).
- `wc -l CLAUDE.global.md` ≤ 320.

### W10 — Gitflow
`bash ~/.claude/lib/gitflow.sh start feature opus5-config-tuning` off
develop; atomic commits (hook+test / CLAUDE.global.md / agent / memory+docs);
NO `gitflow finish` — merge only on explicit human signal.

## 4. Explicitly NOT doing (considered, rejected)

- N1 Touching lib/verify-secure-loop.md or the fresh-verifier/security
  gates: harness architecture (BDR-049/050, D2), verifies SONNET executor
  output — not Opus 5 self-check prose.
- N2 Softening the Security / Architecture sections (BDR-021, D3).
- N3 Editing the superpowers plugin's "1% chance → MUST invoke" language:
  external upstream code; flagged as residual over-triggering risk in the
  new LRN, revisit as its own decision if observed.
- N4 Changing `settings.json` `effortLevel: "xhigh"`: user preference,
  optimal for the Fable 5 session default; the Opus 5 carry-over trap (E9)
  is documented in the LRN + surfaced to the user for a manual decision.
- N5 De-prescribing seo-analyzer.md / geo-analyzer.md (1528/1106 lines,
  heavy MUST density): separate project, backlog note in TODO.md.
- N6 Removing or session-gating the design/ctx7 reminder hooks: soft
  nudges, cheap, deliberately built; tightened only (W6).
- N7 Any model pin change: `model: opus` pins now resolve to Opus 5 —
  desired outcome, census (model-routing.test.sh) untouched.
- N8 Committing settings.json for any reason (LRN-098/1049 /model-churn
  trap): file is currently clean; keep it out of every commit.

## 5bis. CHALLENGE SYNTHESIS (2026-07-30) — FINAL amendments (v2)

Verdicts: correctness CONCERNS(4) · robustness FATAL(5, 1 BLOCKER) ·
simplicity CONCERNS(4). Every fix below is the challenger's own named FIX,
adopted as written. No re-challenge pass: scope narrowed, no new dependency;
W0 is an execution-time safety procedure, not a new config mechanism.

- **W0 (NEW — robustness BLOCKER)**: all edited surfaces are symlink-deployed
  LIVE (~/.claude/CLAUDE.md, hooks/, agents/ → this repo); edits take effect
  machine-wide at save time, before any W9 gate. Mitigations:
  (a) `gitflow start` BEFORE any live-file edit; never checkout develop
  mid-work; (b) hook regex change validated on a SCRATCH copy first
  (bash -n + shellcheck + pattern replay), then written to the live file in
  ONE atomic Edit; (c) named reverts: `git show develop:<file> > <file>`;
  escape hatch = remove the hook registration block from settings.json.
- **W1 v2** (robustness#3, correctness#2): replacement text carves out the
  mandated gates explicitly and scopes "don't redo":
  "Skill-mandated gates (fresh verifier/security/challenge) always dispatch
  as written. Don't redo delegated work by hand — failed gates re-dispatch
  fresh executors instead."
- **W2 v2** (simplicity#2): minimal diff — delete ONLY the line
  `Bar: "would staff engineer approve?"`. Steps 1-4 + capitalize step stay.
- **W3 v2** (simplicity#1, robustness#4): no new bullet. Fold the only new
  clause into the existing Deviations bullet: "Finish the whole task:
  blocked on an independent sub-part → do the rest, state what's missing.
  Gone WRONG → still STOP, re-plan." (net +2 lines, no conflict with :53).
- **W4**: unchanged (+2 lines). Budget v2: 304 +1 −1 +2 +2 = 308 ≤ 320.
- **W6 v2** (all lenses): drop `\bux\b` ONLY — keep `\bui\b` (zero evidenced
  FP; one logged true positive). Accepted trade-off: the 2026-07-21 "ameliore
  le tutoriel…gamifier" ux row (plausible TP) goes quiet; CLAUDE.global.md
  design-routing section remains the router. Header comment notes the log
  records `head -1` only → per-token FP rate not fully derivable. Tests:
  quiet row = synthetic "changement ux vu…" (verified matches pre-change →
  flips); must-fire row = "revois l'ui du panneau admin" (locks `\bui\b`;
  apostrophe escaped correctly, doubles as JSON-path control per
  robustness#7). No log-excerpt rows (vacuous — 100-char truncation).
- **W7 v2** (all lenses): in-place reword of the `:82-83` sentence (NOT
  test-locked; plan v1 misstated that) instead of an add-only clause:
  "No invention — ungrounded is noise. Silently dropping a grounded doubt is
  equally a failure: file it as `[MINOR]` with the uncertainty stated in
  `WHY:`. Nothing real at all → `SOLID` with `FINDINGS: none`."
  OUTPUT grammar byte-identical; no confidence axis; no consumer change.
  Census: add `has "$A" "grounded doubt"` row to plan-challenger.test.sh in
  the same commit.
- **W9 v2**: adds the W0 scratch-validation step; rest unchanged.
- **W10 v2**: branch creation moves FIRST in execution order.

## 5. Constraints for challengers

- Registries append-only; curation only via /prune-memory.
- Census tests lock behavior: any hook/agent edit must land with its test
  update in the same commit; `make test` must stay green.
- CLAUDE.global.md ≤ 320 lines (runtime warning threshold).
- BDR-021: Security + Architecture sections verbatim.
- Gitflow: feature branch off develop, no merge without human signal.
- The global file serves ALL models (Fable sessions, Opus 5 dispatches,
  Sonnet executors read skill/agent prompts instead) — no Opus-5-only
  wording in CLAUDE.global.md.
