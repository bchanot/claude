# ANNEX — directive-language inventory (analyzer report, 2026-07-30)

Produced by a read-only analyzer dispatch over agents/seo-analyzer.md
(1528 l) + agents/geo-analyzer.md (1106 l), cross-referenced against
every consumer. Referenced by the C1 plan (same folder, -1402.md).

## 0. Token census (raw)

| Token family | seo-analyzer.md | geo-analyzer.md |
|---|---|---|
| MUST/must | 12 | 6 |
| MANDATORY/mandatory | 8 | 4 |
| NEVER/never | 42 | 33 |
| ALWAYS/always | 6 | 1 |
| CRITICAL/critical | 3 | 1 |
| Do NOT / do not | 24 | 8 |
| verbatim | 6 | 3 |
| STOP | 3 | 4 |
| refuse/REFUSE | 6 | 4 |
| ⚠️ blocks | 0 | 0 |

## 1. Test locks on these files (complete list — 6 per file)

model-routing.test.sh:67-68 `model: opus` (both) · :150-157 `MODE:
collect|judge|template` + `COLLECTION COMPLETE` (both) ·
seo-data.test.sh:538-540 `fetch.sh crux` / `fetch.sh queries` /
`Performance GSC` (seo) · :542-543 `fetch.sh schema_gen` /
`fetch.sh content_quality` (geo).
NOT locked by any test: READY-TO-APPLY sentinel, envelope headings,
score-block shapes, JUDGE-ERROR strings, batch labels — contracts by
consumer only; a rewrite can break them silently and make test stays
green. Sibling dispatcher locks: model-routing.test.sh:159-166.
Stale line-number comments (no enforcement): lib/url-guard.sh:9,
url-guard.test.sh:20, source-scope.sh:25, seo-data/README.md:196/309,
drift.py:4, linkgraph.py:4 — all already drifted.

## 2. Format contract (artifact → consumer) — FREEZE SET

seo-analyzer: signals `.audit/seo-signals-<RUNID>.md` (+clean/load sites
in /seo) · `COLLECTION COMPLETE — RUNID: <RUNID>` terminal ·
`COLLECT REPORT` w/ `STATUS: DONE|BLOCKED` · `SEO JUDGE — VERDICT:
ERROR(<reason>)` · judge report forwarded verbatim to template ·
`SEO SCORING (<depth>)` block w/ `COVERAGE SOURCE:`/`COVERAGE LIVE  :`
+ 7 axes + `SEO GLOBAL (weighted): XX.X/20` (score.py:26-37 mirrors
weights) · `TRAJECTORY TO 17/20 (code-only)` · `fetch.sh score` JSON
(`axes.{technical,on-page,seo-local,off-page,social,competitive,legal}`,
severities `critique|haute|moyenne|basse`, `status:"na"`) · `FIX PLAN (N
findings total)` + BATCH A…F (tier-mapping tolerant) · `## FIX BUNDLE
(for dispatcher)` + `### AUTO/### GATED/### USER ACTIONS` + item fields
`id: applier: files: concern: current: expected:` · sentinel `READY TO
APPLY — awaiting dispatcher confirmation` (also reused by /harden:366) ·
envelope `SEO AGENT RESULT` + `## SECTION FOR SEO.md §2…§6` + `## ENTRIES
FOR SEO.md §0/§8/§9/§10/§11/§15` · `Automatisation possible avec:` per
§11 entry · standalone `.claude/audits/SEO.md` w/ `**Score SEO** : XX.X
/ 20` (client-handover-writer.md:344 labeled grep) + §0-§15 + Historique.
geo-analyzer: same families with GEO names; envelope `GEO AGENT RESULT`
+ `## SECTION FOR SEO.md §7` (7.1-7.6); `**Score GEO** : XX.X / 20`
(handover parses it only inside SEO.md, allow_fallback=no); G1-G7
batches (G1-G4/G6 AUTO · G5 GATED · G7 USER). Both: STEP NUMBERS are
addressed by dispatchers (seo: 2-5/6-11/12-14; geo: 0-5/6-12/13-15;
also depth-matrix.md:17-19,37) — renumbering re-points dispatch prompts.
Engine interfaces: fetch.sh verbs {crux,queries,inspect,cannibal,
sitemap,rendercheck,linkgraph,score,schema_gen,content_quality} ·
url-guard.sh host|url · source-scope.sh findargs|list · resources/*.md.

## 3-4. Site classification counts

| | seo | geo | total |
|---|---|---|---|
| A machine-parsed contract | ~52 | ~41 | ~93 (12 test-locked) |
| B safety/policy invariant | ~30 | ~31 | ~61 |
| C process choreography | ~21 | ~12 | ~33 |
| D other/domain-fact | ~20 | ~13 | ~33 |

### Class C sites — seo-analyzer.md (rewrite targets)
:61 "First action." · :143-148 CMS-detect-before-edit ordering ·
:208-210 "keep the two consistent" (runtime cross-file reconcile) ·
:508 "run this BEFORE anything else in STEP 5" (ordering; the refusal
rule itself is B) · :550-553 "Record the denominator BEFORE sampling"
(ordering; honesty rule is B) · :602-604 "Sanity-check the grouping
before trusting it" (self-verify) · :606-618 sampling-method essay ·
:661-680 C1a 20-line rationale (rule itself is B at :1493-1501) ·
:875 per-item method · :970-971 "Run it twice on the same file before
publishing" (exact BDR-081 over-verification class) · :1147 "AUTO items
are a commitment, not a suggestion." · :1149-1157 P0 CMS-plugin-first
mandate · :1159-1162 P0 Bing mandate (dup of geo :777-786) · :1217 "Do
not proceed to STEP 12 until this plan is printed." · :1260-1261 +
:1342-1350 + :1502-1503 landing-page rule ×3 · :1309-1320 bundle
completeness checklist (10 checkboxes self-audit) · :1504 "Preserve
existing valid SEO." · :1522-1523 WebSearch-on-FULL extra-verify ·
:1525-1526 "Transparency. Every automated change logged" (VESTIGIAL —
agent applies nothing, pre-BDR-061).

### Class C sites — geo-analyzer.md
:48 "copy these patterns" · :124 "First action." + :127-139 ask-block
(unreachable when dispatched) · :230 conditional skip · :262-269 +
:873 + :1063-1065 PERMISSIVE default ×3 · :360 ordering · :394 "20-50
real customer questions (P0)" · :777-786 MANDATORY AI-index submission
(dup of seo :1159-1162) · :811 "Consolidate EVERY finding" · :823
"Print the plan before STEP 13" · :1102-1103 WebSearch extra-verify ·
:1106 "Every automated change logged in §14" (VESTIGIAL; §15 log is
dispatcher's per :959).

### Class B anchors (keep obligation, dedup emphasis)
CWD/TARGET MISMATCH twins (seo :117-126 ≈ geo :173-181) · url-guard
mandatory (seo :287-291 ≈ geo :273-277) · R2 refuse-to-score (seo
:519-548, geo :548-557; BDR-072) · NAP direction rule (seo :801-812,
geo :1073-1087; LRN-032-zenquality) · COVERAGE mandatory (seo
:1110-1130, geo :725-729; LRN-133) · never-apply/L1 (BDR-061; LRN-105
named-ban) · C1a build-output ban · no-invented-content/DGCCRF ·
"Compute the scores, do not feel them (I7)" (BDR-073) · §14 mandatory
disclosure lines (backlinks BDR-071, security headers I4) · honest
llms.txt framing · cite-sources (LRN-131).

## 6. Duplication map (sweep ALL twins — LRN-113)

seo internal: never-apply ×4 (:1227-1234, :1352-1357, :1468-1472,
:1527-1528) · landing-page ×3 (:1260, :1342, :1502) · shared-file
discipline ×2 (:1254, :1486) · bundle self-containment ×2 (:1249,
:1473) · COVERAGE ×4 (:438, :1000, :1096, :1110) · security-headers-
not-scored ×3 (:281, :977, :994) · 30/70 ×3 (:397, :614, :1165) ·
sentinel-verbatim ×3 (:1301, :1304, :1397).
geo internal: PERMISSIVE ×3 · never-apply ×4 (:826-832, :842-848,
:1031-1034, :1104-1105) · tier-mapping ×2 (:824, :850) ·
content_quality-advisory ×2 (:584, :622) · shared-file ×2 (:858,
:1047) · llms-honest ×2 (:337, :1066) · cite-sources ×2 (:17, :1089).
Cross-agent twins (stay twins — both files dispatch standalone):
CWD block · url-guard block · MODE DETECTION · MODE BOUNDARY · R2 ·
COVERAGE · NAP rule · RULES section skeleton · C1a · automation rule ·
Bing/AI-index action · CDN/WAF check.
Agent↔dispatcher duplication (stays — dispatch prompt is per-run
context, agent spec serves standalone/no-MODE paths): NAP ×4 total ·
shared-file ×7 · security-headers ×5 · domain split · weights 80/20-
75/25 · Historique · never-re-derive (test-locked dispatcher side).

## 7. Contradictions / ambiguities found

1. seo :1525-1526 + geo :1106 vestigial "automated change logged"
   (agent applies nothing; geo :959 says dispatcher fills §15).
2. Ask-the-user blocks unreachable in dispatched path (seo :64-75,
   :88-112; geo :127-139, :153-168); /geo:41 states it outright.
3. Collect boundary wording: agents "STEP 0-5 ONLY" vs /seo "STEP 2-5
   only (context replaces STEP 0-1)" — works by prompt override.
4. geo judge does live work (sameAs curls :477-492, web_search) unlike
   pure-judgment seo judge — asymmetric split, by design.
5. /harden imposes its own output contract (HARDEN.md, /100) the agent
   spec never acknowledges; keys on "NARROW-SCOPE" in dispatch prompt.
6. "LRN-032" cite is ambiguous in THIS repo (local LRN-032 = different
   lesson; the NAP lesson is zenquality's registry) — keep the
   "zenquality" qualifier wherever cited.
7. geo :376-377 uncited FAQ-citation-rate claim vs geo :1089-1097
   cite-sources rule (LRN-131 failure class).
8. Score-label parse fragility: client-handover extract_score fallback
   greps FIRST X/20 in file — losing the `Score SEO` label would
   silently read `TRAJECTORY TO 17/20` as 17.0. (Latent, downstream.)
9. GEO scoring has no deterministic engine (score.py covers SEO axes
   only) — BDR-073 binds only half the pair.

## 8. Binding memory (from the analyzer's read-before)

IN FORCE: BDR-081 (premise) · LRN-139 (when-guidance shape) · BDR-061
(bundle+sentinel decision) · BDR-077 (mode split, fail-closed, locks
survive) · BDR-073 (deterministic scoring) · BDR-072 (R2 refuse) ·
BDR-071 (off-page ceiling + §14 line) · BDR-010/LRN-011 (labeled
scores gate) · LRN-133 (omission legible) · LRN-131/132/EVAL-025
(WebSearch ≠ verification) · LRN-105 (named ban stays explicit) ·
LRN-080/088 (measure before delete → dogfood) · LRN-113 (sweep whole
surface) · LRN-093 (no vacuous locks; single-line anchors) ·
LRN-126/137 (mode split carries data paths) · BLK-017 (Bing deferred).

## 9. Open questions → dispatcher decisions (see plan §4b)

Q1 freeze scope · Q2 census extension · Q3 dedup strategy ·
Q4 vestigial lines · Q5 /harden //onboard reconciliation.
