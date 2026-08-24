# PLAN v2 — De-prescribe seo-analyzer.md + geo-analyzer.md for Opus 5

Date: 2026-07-30 · Branch: feature/seo-geo-deprescription (off develop, started)
KIND: build-plan · Author: main-loop session (Fable 5)
Parent decision: BDR-081 N5 (deferred as separate project) · Method: LRN-139
v2: revised after the 3-lens challenge (§5bis) — every BLOCKER closed by a
named change; one confirmation challenger pass follows before execution.

## 1. Context & evidence (v2 — sizing corrected per simplicity#1)

Both agents are opus-pinned (BDR-076) → every judge phase runs Opus 5.
BDR-081 profile applies: literal following, over-verification when told
to verify, conflicting/duplicated rules burn reasoning tokens. These are
the LONGEST agent files in the repo (1528 + 1106 l) with real downstream
parsers — NOT the densest (measured: ~4.5 directive hits/100 l, ranks
20th/22nd; security-auditor is 17/100). What this pass buys, honestly:
(a) removal of self-output-verification demands (the one pattern the
baseline dogfood caught live: the judge reported "run twice, identical
output" — seo:970 firing), (b) removal of vestigial pre-BDR-061 lines
and 2 real contradictions, (c) small same-audience/same-range dedup,
(d) caps→when-guidance on choreography. The verification apparatus
(census + 3-lens challenge + before/after dogfood) is USER-DIRECTED for
this chantier, not derived from the density premise.

## 2. Contract surface (v2 — split per correctness#5)

### 2a. Machine-parsed (named non-LLM consumer: test, script, or literal
grep in a dispatcher step) — byte-frozen
- `model: opus`, `MODE: collect|judge|template`, `COLLECTION COMPLETE`
  (model-routing.test.sh:67-68,150-157).
- `fetch.sh crux|queries` + `Performance GSC` (seo), `fetch.sh
  schema_gen|content_quality` (geo) (seo-data.test.sh:538-543).
- `SEO|GEO JUDGE — VERDICT: ERROR(` — dispatcher ERROR CONTRACT
  fail-closes on it (skills/seo:316-318, skills/geo:65-68).
- `## FIX BUNDLE` + sentinel `READY TO APPLY — awaiting dispatcher
  confirmation` — apply step keys on it (skills/seo:524, skills/geo:101;
  reused by /harden:366).
- `.audit/<seo|geo>-signals-<RUNID>.md` names + fail-closed load.
- STEP numbering: dispatchers address ranges literally (seo 2-5/6-11/
  12-14; geo 0-5/6-12/13-15; depth-matrix:17-19,37).
- `**Score SEO** : XX.X / 20` / `**Score GEO** : XX.X / 20` labels —
  client-handover-writer.md:344-345 labeled grep (BDR-010/LRN-011);
  losing the SEO label silently falls back to first-X/20-in-file.
- Bundle item fields `id: applier: files: current: expected:` — pasted
  verbatim into hotfixer/feater at L1; `applier: bash` run in-loop.
- url-guard call sites: seo-analyzer.md:287-295, geo-analyzer.md:273-280
  (NOT ":257" as v1 said — robustness#5) + sitemap-URL guard seo:573-582.
- `NARROW-SCOPE` keying of the I4 carve-out (seo:981-983) — /harden's
  dispatch prompt relies on it.

### 2b. LLM-convention contracts (no code consumer; the dispatcher LLM
merges by these shapes) — locked in the census, still frozen
`SEO|GEO AGENT RESULT` envelopes · `## SECTION FOR SEO.md §N` ·
`## ENTRIES FOR SEO.md` · `SEO|GEO SCORING (` blocks + `COVERAGE
SOURCE`/`COVERAGE LIVE` lines + `GLOBAL (weighted)` · `TRAJECTORY TO
17/20 (code-only)` · `FIX PLAN (` (seo) · batch labels A-F / G1-G7
(tier recognition tolerant, labels nominal) · `COLLECT REPORT` +
`STATUS: DONE|BLOCKED` · `Automatisation possible avec:` · §0-§15
report skeleton + Historique. CROSS-AGENT NOTES emit-instruction lives
in /seo's dispatch prompts (dispatcher-side lock only).

## 3. Class B invariants — obligation kept, single strongest statement;
security ORDERINGS byte-frozen (robustness#5/#7)

- Guard-first orderings, frozen verbatim: seo:287-291 / geo:273-277
  ("Guard the domain before it reaches a shell… Run the guard FIRST…
  never 'clean up' the value and retry") + seo:573-582 URL loop.
- seo:550 "Record the denominator BEFORE sampling" — the ordering IS
  the honesty mechanism (a post-hoc denominator is self-serving);
  frozen; only surrounding prose may compress.
- NAP direction rule (LRN-032-zenquality — keep the qualifier, the bare
  ID is ambiguous in this repo), R2 refuse-to-score (BDR-072), COVERAGE
  obligations (LRN-133 — note :436-439 is a DISTINCT index-reach
  obligation, not a repeat), §14 mandatory disclosure lines (BDR-071
  backlinks verbatim line, I4 security-headers), never-apply/L1
  (BDR-061; LRN-105 named ban), C1a build-output ban, no-invented-
  content/DGCCRF, deterministic scoring (BDR-073), fail-closed judge,
  shared-file Edit-not-Write discipline, honest llms.txt framing,
  cite-sources (LRN-131).
- External-freshness checks are NOT self-verification (robustness#6):
  seo:1522-1523 + geo:1102-1103 verify a DRIFTING WORLD feeding an
  AUTO-tier robots.txt edit — kept, reworded as when-guidance ("crawler
  lists shift; cross-check before emitting G1 from the dated resource").

## 4. Work items v2

- P0 SEQUENCING + LIVE-TREE EXPOSURE (robustness#4, conf#2/#3/#4/#9):
  agents/ resolves through ~/.claude symlinks to the WORKING TREE —
  edits are live between Edit calls, before any commit. Rules:
  (1) the FULL baseline completes before the first agent edit —
  signals + judge reports + TEMPLATE envelopes + merged SEO.md +
  HUMAN-ACTIONS.md (conf#2: without frozen template artifacts the
  template-range edits would have no differential and P0 makes one
  unobtainable later);
  (2) all baseline artifacts copied to the DURABLE, gitignored
  `.audit/dogfood-baseline/` in this repo before the first edit
  (conf#9: the session scratchpad dies with the session/reboot;
  LRN-124: .audit/** is never committed);
  (3) freeze window: no /seo //geo //harden //onboard AND no
  /client-handover (spawns /seo — conf#3) nor any skill transitively
  dispatching either analyzer, in ANY project, until the after-dogfood
  verdict;
  (4) aborts (conf#4): mid-reword interrupt or after-dogfood failure →
  `git checkout HEAD -- agents/seo-analyzer.md agents/geo-analyzer.md`
  (in-flight revert, index-safe); `git checkout develop -- agents/…`
  is reserved for a WHOLE-BRANCH abandon; after an abort the named
  exit is either (a) fix + re-run the after-dogfood, or (b) present
  the static evidence (census + git diff review) to the human who may
  accept or abandon at the gate — no open-ended reverted state.
- P1 CENSUS (commit 1, test-only, green pre-reword — compatible with
  §7's same-commit rule: it locks EXISTING state and changes no agent
  file; reword commits carry any census DELTA): DONE in working tree —
  lib/tests/seo-geo-contract.test.sh 54/0, shellcheck clean, real
  flip-test run: 7 scratch mutations → 7 FAILs (not "by construction" —
  robustness#10). File-qualified locks (correctness#4): `FIX PLAN (` +
  `applier: bash` + `Score SEO` seo-only; `Score GEO` geo-only.
  Incidental locks dropped (CROSS-AGENT NOTE agent-side, bare
  `applier:`). Item fields locked both files. v3 (conf#5): EVERY
  `## STEP n —` header locked, interiors included (seo 0-14, geo 0-15)
  — census now 71/0. Freeze mechanism for the
  ~40 A-sites the census does not cover: reviewed `git diff -U0
  agents/*.md` on each reword commit (simplicity#4).
- P2 REWORD seo-analyzer.md (commit 2):
  (a) Self-OUTPUT verification, v3 (conf#1/#8 — neither is deleted
      outright): :970-971 "run it twice" → when-guidance integrity
      guard ("if the findings JSON changed after scoring, re-run and
      explain the move" — score.py is deterministic, so a moving
      output means mutated findings: anti-score-shopping, BDR-073;
      the unconditional double-run the baseline judge burned goes
      away, the guard stays); :1217 "Do not proceed until printed" →
      when-guidance scoped to the single-shot path ("single-shot runs
      print the FIX PLAN before STEP 12 serializes it" — MODE: judge
      stops at 11, but /harden //onboard execute the whole file,
      conf#1). The completeness checklist :1309-1320 is NOT deleted:
      its routing rows (stock-photo→GATED(E), compression→AUTO(bash)
      or §11, aggregateRating→AUTO(hotfixer), structural→GATED(D)…)
      are unique routing content (robustness#3) — reshape into a plain
      mapping table, drop only the checkbox self-audit framing.
  (b) DELETE vestigial :1525-1526 (contradicts BDR-061; Q4).
  (c) DEDUP under the invariant (correctness#1 + robustness#1): only
      VERBATIM same-AUDIENCE (spec rule / bundle-item payload /
      phase-local caveat) same-MODE-RANGE (collect 0-5 / judge 6-11 /
      template 12-14 / RULES=global) repeats merge. Expected survivors
      per family listed at execution in the commit message; honest
      net: never-apply 4→3 (RULES pair merges; template-range
      statements stay), sentinel-verbatim reminders 3→2, landing-page
      3→2 (payload instance :1260 + one spec statement; :1342 vs
      :1502 merge), bundle-self-containment 2→1 (same range).
      NOT deduped (v1 was wrong — distinct rules or cross-range):
      COVERAGE ×4, 30/70 ×3, security-headers ×3, shared-file
      discipline (payload vs spec audiences).
  (d) SOFTEN caps/orderings to when-guidance, keeping semantics:
      :61, :508 (gate stays before on-page scoring; emphasis drops),
      :875, :1147, :1149-1157 CMS-plugin-first folded together with
      :143-148 into ONE statement (correctness#3 — two strengths of
      one rule otherwise), :1159-1162 Bing (content rule kept, caps
      drop; FULL-only → statically verified), essays :606-618 +
      :661-680 compressed keeping the rule + LRN citations; :602-604
      kept as a when-guidance failure detector ("families ≈ URLs →
      the heuristic broke — say so"), not deleted (robustness#8).
  (e) Dispositions completing the C-list (correctness#3): :208-210 →
      static pointer ("the CDN/WAF twin check lives in geo STEP 4");
      :1504 KEEP as-is (one-line scope guard).
- P3 REWORD geo-analyzer.md (commit 3), same invariant:
  PERMISSIVE ×3: ALL survive (collect/template/RULES ranges;
  :873 is the item-level default guarding an unconfirmed AUTO
  robots.txt edit — named survivor, robustness#9). never-apply 4→3
  (RULES pair merges). tier-mapping :824/:850 BOTH stay (judge vs
  template ranges). content_quality-advisory 2→1 (same range).
  shared-file 2× stays (payload vs spec). llms-honest 2× stays
  (collect vs RULES). cite-sources 2× stays (:17 guards the header
  stats specifically). :1106 vestigial → reworded to the truth
  (dispatcher fills the log — matches :959; Q4). :777-786 caps →
  plain content rule (FULL-only). :1102-1103 → freshness
  when-guidance (kept — §3). :394 quantity softened ("substantial,
  real customer questions"). :48 softened. :124-139 ask-block KEPT
  (standalone path). Orderings :360/:811/:823 softened. :376-377
  uncited claim → honest framing (no invented source).
- P4 DOGFOOD AFTER (v3 — ordered by decisiveness, conf#7): fresh copy
  of zenquality-frozen; phases in this order so a mid-run death still
  leaves the decisive evidence (billing class already realised once):
  (ii-first) judges fed the FROZEN baseline signals
  (.audit/dogfood-baseline/) → judge reports vs frozen baseline judge
  reports, ZERO collect variance — the decisive Opus-judge-prose
  differential; (iii) templates on those judge reports → envelopes,
  compared against the frozen BASELINE envelopes — the template
  verdict anchors on ENVELOPES only (SEO.md/HUMAN-ACTIONS.md are
  dispatcher-merged by this authoring session, non-attributable —
  conf#10); (i-last) fresh collects, same pre-answered context →
  (a) shape check of signals/COLLECT REPORT vs baseline, (b)
  FIELD-LEVEL diff of the fresh signals vs baseline signals (record
  blocks, COVERAGE counts, denominators — a shape-valid file with a
  dropped field must be caught, conf#6), and (c) ONE end-to-end seo
  judge on the FRESH signals (the domain with the most collect-range
  edits) so the reworded collect→judge handoff runs at least once.
  Comparison mechanical-first: presence-assertion script (named home:
  `.audit/dogfood-baseline/assert-after.sh`, session-reproducible,
  never committed — conf#11) + a FRESH reader agent diffing
  before/after WITHOUT this plan in context (correctness#7); the
  authoring session only arbitrates its report. If the after-run dies:
  P0(4) abort + named exit applies; no merge request meanwhile.
- P5 GATES: make test full suite (census + model-routing + seo-data +
  no-vacuous-locks) · shellcheck on touched .sh · per-RANGE grep sweep
  for every deduped family (asserts the named survivor lines exist in
  their ranges — mode-blind ≥1× sweep is insufficient, robustness#1) ·
  MEASURED deltas recorded (simplicity#7): wc -l + directive-token
  census (annex §0 grep set) per file, before/after, into the BDR.
  (v1's manual MODE/STEP sweep dropped — the census asserts it,
  simplicity#5.)
- P6 CAPITALIZE: BDR (decision, invariant, deltas, alternatives), LRN
  (audience×range dedup invariant — reusable), journal, CHANGELOG.
  TODO C1 checked. NO merge (human gate). Checkpoint report includes
  the DYNAMICALLY-UNVERIFIED list (§6bis).

## 4b. Dispatcher decisions (v2)

- Q1 freeze scope: all §2a byte-frozen + §2b frozen via census; the
  remaining unlocked A-prose freeze = per-commit git diff review.
- Q2 census: done (P1), flip-proven.
- Q3 dedup: WITHIN-file, same-AUDIENCE, same-MODE-RANGE, verbatim
  repeats only. Cross-agent + agent↔dispatcher twins stay. (Mechanism
  note correcting robustness#1's premise: every dispatch loads the FULL
  agent file; the risk is ATTENTIONAL — a literal-following model told
  "run STEP 13-15" deprioritizes guidance scoped to another step's
  body — not access. Same fix either way.)
- Q4 vestigial: seo :1525-1526 DELETE; geo :1106 REWORD to
  dispatcher-owns-log (correctness#6 resolved).
- Q5 /harden //onboard: out of scope (N6); their dispatch-prompt
  contracts are untouched by agent-file rewording; `NARROW-SCOPE`
  keying frozen (§2a).

## 5. Dogfood protocol (v2)

Baseline (DONE for collect+judge SEO; geo judge in flight at v2 time):
frozen zenquality copy (no .env), inline pipeline (canonical /seo shape
— the nested-CLI attempt died on the CLI monthly spend limit, recorded),
absolute PROJECT ROOT in every dispatch, `/seo local conservative`,
STEP 0 pre-answered, NAP = NAP-KIT.md (user-confirmed 2026-07-10).
Baseline artifacts frozen under the DURABLE `.audit/dogfood-baseline/`
(gitignored, never committed — conf#9): signals ×2, judge reports ×2,
template ENVELOPES ×2, merged SEO.md, HUMAN-ACTIONS.md (conf#2 — the
template phase runs to completion BEFORE the first agent edit).
After-run per P4. LIMITS stated honestly
(robustness#2): conservative never enters STEP 1b/1.5 (no applier parses
an item this run — the item-field contract is census-locked statically);
LOCAL never executes STEP 3-4/6-7 FULL branches (Bing/AI-index emission
text, live checks — the FULL-only conditionals were exercised and
correctly declined in the baseline judge). These stay on the
§6bis unverified list for the human gate; a FULL/aggressive dry-run is
an OPTION the user may order at checkpoint, not part of this plan.

## 5bis. CHALLENGE SYNTHESIS (2026-07-30)

Verdicts: correctness FATAL(3) [1 BLOCKER, 2 MAJOR, 4 MINOR] ·
robustness FATAL(9) [3 BLOCKER, 6 MAJOR, 2 MINOR] · simplicity
CONCERNS(3) [3 MAJOR, 4 MINOR]. All three lenses returned. Every
BLOCKER closed by a named v2 change:
- correctness#1 (audience-blind dedup) + robustness#1 (mode-blind
  dedup) → §4b Q3 invariant + P2(c)/P3 rewritten + P5 per-range sweep.
- robustness#2 (dogfood can't reach riskiest edits) → §5 honest limits
  + §6bis unverified list + P2(d)/P3 minimal-diff on FULL-only sites +
  static census cover; FULL/aggressive run offered to the human, not
  silently added (billing exposure robustness#11).
- robustness#3 (routing table misfiled as self-check) → P2(a) keeps
  routing rows verbatim.
Majors adopted: R4 live-tree abort path (P0) · R5 url-guard anchors
corrected + security orderings frozen (§2a/§3) · R6 external-freshness
kept (§3) · R7 :550 frozen (§3) · R8 :602 kept as detector (P2(d)) ·
R9 :873 named survivor (P3) · C2 folded into R2's resolution · C3 full
dispositions (P2(d)/(e), P3) · S1 §1 rewritten · S2 controlled
judge-replay (P4) · S3 mechanical presence script (P4). Minors adopted:
C4 file-qualified locks · C5 §2 split · C6 three inconsistencies
resolved (P1 note, Q4, N1 marker) · C7 fresh-reader diff · S4 diff-
review freeze · S5 sweep dropped · S6+R10 census corrected+flip-proven ·
S7 measured deltas. Rejected/scoped: S1's apparatus-shrinking (the
apparatus is user-directed); R1's access premise corrected to
attentional (fix adopted unchanged).

CONFIRMATION PASS (robustness lens, v2 → v3): FATAL(9) — 2 BLOCKER +
7 MAJOR/MINOR, all targeting the v2 amendments as asked. Closed by
name: conf#1 no-MODE single-shot → §6bis + P2(a) :1217 scoped-softened
· conf#2 missing baseline template artifacts → P0(1) full-baseline
precondition · conf#3 /client-handover freeze → P0(3) · conf#4 abort
HEAD-vs-develop + named exit → P0(4) · conf#5 interior STEP locks →
census extended to all headers (71/0) · conf#6 collect→judge seam →
P4(i) field-diff + one end-to-end seo judge on fresh signals · conf#7
decisiveness order → P4 reordered (ii)→(iii)→(i) · conf#8 :970
anti-score-shopping → when-guidance reword, not deletion · conf#9
volatile baseline → durable .audit/dogfood-baseline/ · conf#10
dispatcher-owned artifacts → envelope-anchored template verdict ·
conf#11 script home named. Challenge budget exhausted (1 re-pass max):
residual risk goes to the human gate with this record.

## 6. Explicitly NOT doing

- N1 No dispatcher (SKILL.md) edits.
- N2 No scoring-weight, axis, or depth-matrix changes.
- N3 No model-pin changes (BDR-076).
- N4 No weakening of class-B invariants (§3 hardened in v2: security
  orderings byte-frozen).
- N5 No new modes, no pipeline reshaping (BDR-077).
- N6 No /harden //onboard contract reconciliation (annex §7.5).
- N7 No collect-boundary wording fix (works by prompt override).
- N8 No cross-agent shared-resource consolidation.
- N9 No deterministic GEO score engine (annex §7.9).
- N10 No FULL/aggressive dogfood in this plan (user option at gate).

## 6bis. Dynamically-unverified edit surface (for the human gate)

Sites edited by P2/P3 that no dogfood run executes: FULL-branch content
(seo :1159-1162 Bing emission, geo :777-786 AI-index emission, both
freshness when-guidances), apply-path parsing (STEP 1b/1.5 — item
pasted into appliers; covered statically by census item-field locks +
frozen bundle templates), STEP 6-7 external-presence prose, and the
no-MODE single-shot path (conf#1: /harden and /onboard dispatch the
agents without a MODE line — "all steps in sequence" — so the whole
reworded body drives those runs; every never-apply and ordering
statement that path relies on keeps a surviving instance, and :1217
is softened-scoped to it, never deleted). Mitigation: minimal diffs
there (caps→plain only), census locks, git-diff review.

## 4c. Backlog surfaced (not this branch)

- Score-label fallback fragility in client-handover-writer.md (can read
  `TRAJECTORY TO 17/20` as 17.0 if the label vanishes) — annex §7.8.
- Stale lib/ line-number comments pointing at agent lines (annex §1).
- Baseline judge's gate observation: /client-handover 17/20 gate passes
  with an open `critique` finding — "open critique = independent
  blocker" is worth its own decision.

## 7. Constraints for challengers

- Registries append-only; census green throughout; reword commits keep
  54/0 + model-routing + seo-data locks green.
- Agent files symlink-live INCLUDING between Edit calls (P0 abort path).
- §2a byte-identical; §2b frozen; STEP numbering preserved; §3 security
  orderings verbatim.
- Dedup only same-audience + same-mode-range verbatim repeats; named
  survivors per family in commit messages; P5 per-range sweep.
- The judge phase is Opus 5; collect/template Sonnet — literal
  following applies to all (E5 "since 4.7").
- Baseline artifacts frozen before first edit; after-run design per P4.
