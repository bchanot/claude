#!/usr/bin/env bash
# lib/tests/seo-geo-contract.test.sh — census: seo/geo agent ⇄ dispatcher
# machine contract (C1 de-prescription, 2026-07-30). Locks every string a
# consumer parses BEFORE the choreography reword, so the reword commits
# prove contract preservation by keeping this green. Complements
# model-routing.test.sh (which already locks model pins + MODE:* +
# COLLECTION COMPLETE).
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }

SEO=agents/seo-analyzer.md
GEO=agents/geo-analyzer.md

# 1) judge verdict grammar — DISPATCHER ERROR CONTRACT (skills/seo STEP 1,
#    skills/geo STEP 1B) fail-closes on this exact shape
has "$SEO" 'SEO JUDGE — VERDICT: ERROR('
has "$GEO" 'GEO JUDGE — VERDICT: ERROR('
has "skills/seo/SKILL.md" 'SEO JUDGE — VERDICT: ERROR('
has "skills/geo/SKILL.md" 'GEO JUDGE — VERDICT: ERROR('

# 2) fix-bundle section + apply sentinel — parsed by /seo STEP 1b/1.5 and
#    /geo STEP 1b/2 before any L1 apply
for f in "$SEO" "$GEO" skills/seo/SKILL.md skills/geo/SKILL.md; do
  has "$f" '## FIX BUNDLE'
  has "$f" 'READY TO APPLY — awaiting dispatcher confirmation'
done

# 3) signals handoff — judge loads the collect artifact fail-closed
has "$SEO" '.audit/seo-signals-'
has "$GEO" '.audit/geo-signals-'
has "skills/seo/SKILL.md" '.audit/seo-signals-<RUNID_SEO>.md'
has "skills/geo/SKILL.md" '.audit/geo-signals-<RUNID>.md'

# 4) STEP numbering — dispatchers reference agent step ranges literally:
#    /seo: "STEP 2-5" collect · "STEP 6-11" seo judge · "STEP 6-12" geo
#    judge · "STEP 12-14" seo template · "STEP 13-15" geo template;
#    /geo: "STEP 0-5". Lock EVERY step header on the agent side (interiors
#    too — merging/renumbering one silently re-points the dispatch ranges)
#    and the ranges on the dispatcher side.
for n in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do has "$SEO" "## STEP $n —"; done
for n in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do has "$GEO" "## STEP $n —"; done
has "skills/seo/SKILL.md" 'STEP 2-5'
has "skills/seo/SKILL.md" 'STEP 6-11'
has "skills/seo/SKILL.md" 'STEP 6-12'
has "skills/seo/SKILL.md" 'STEP 12-14'
has "skills/seo/SKILL.md" 'STEP 13-15'
has "skills/geo/SKILL.md" 'STEP 0-5'
has "skills/geo/SKILL.md" '6-12, report scoring'   # "STEP\n6-12" line-wraps
has "skills/geo/SKILL.md" 'STEP 13-15'

# 5) collect-mode report emission (dispatcher waits on it between phases)
has "$SEO" 'COLLECT REPORT'
has "$GEO" 'COLLECT REPORT'

# 6) bundle-item routing + the item fields the L1 appliers parse
#    (the item is pasted verbatim into hotfixer/feater — /seo STEP 1.5)
for f in "$SEO" "$GEO"; do
  has "$f" 'applier: hotfixer'
  has "$f" 'applier: feater'
  has "$f" '  files:'
  has "$f" '  current:'
  has "$f" '  expected:'
done
has "$SEO" 'applier: bash'

# 7) cross-agent escalation block — merged into SEO.md §11 by /seo STEP 2.
#    The emit instruction lives in /seo's DISPATCH PROMPTS, not in the agent
#    specs (geo-analyzer.md never mentions it; seo-analyzer.md only once,
#    incidentally — NOT locked, it is prose). Lock the dispatcher side only.
has "skills/seo/SKILL.md" 'CROSS-AGENT NOTES TO'

# 8) trajectory block — mandatory in envelopes (/geo audit-end deliverables,
#    /seo §1 merge)
has "$SEO" 'TRAJECTORY TO 17/20'
has "$GEO" 'TRAJECTORY TO 17/20'

printf 'seo-geo contract locks: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
