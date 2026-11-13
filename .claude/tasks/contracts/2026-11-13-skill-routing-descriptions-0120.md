# CONTRACT — skill-routing-descriptions (E2)
- date: 2026-11-13 | flow: feat | branch: feature/skill-routing-descriptions (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
E2 (user decision 2026-11-12, block E: "lignes « Skill routing » → `description:` des skills concernés"; phase 1 deferred item, phase 3 bullet: "the Skill routing table lines move into our own skills' `description:`, ≤3 lines for vendored aliases stay in CLAUDE.global.md"). CLAUDE.global.md § "Skill routing": every line whose target is one of OUR skills moves into (or is already carried by) that skill's `description:`; lines for vendored / gstack / pack-off cases stay.

## CLARIFICATIONS
- [gated 2026-11-13 r3: plan § r3 is the final CLAUDE.global.md text; gstack ship retired per BDR-105; triggers "stack trace + fix" and "ship this feature"] 
- [gated 2026-11-13 r2, supersedes the clarification below where they differ] kept always-on: a gstack line (investigate / ship only on explicit ask, bugs → bugfix, ship/PR → ship-feature, deploy → deploy) and the pack-aware SEO/GEO/W3C + cso line; dropped: file-count, tour, reconcile, capitalize/close lines; descriptions gain triggers only (bugfix "error", "500", "stack trace"; ship-feature "open a PR", "ship this feature").
- [gated 2026-11-13, orchestrator per user brief] Dropped from CLAUDE.global.md (already in the target description): "feat / hotfix / bugfix distinguished by file count", "tour", "reconcile", "Before /clear or /compact → capitalize; ritual → close", "SEO+GEO → seo (GEO only → geo); W3C + WCAG → web-validate" (cso part stays: gstack). Moved: "Bug / error / 500 → bugfix … investigate only on explicit ask (gstack: cross-project learnings, /freeze, long open-ended investigation)" → skills/bugfix description; "Ship / PR → ship-feature (never gstack ship: base origin/HEAD = main skips develop); deploy → deploy (runbook, the user runs it)" → skills/ship-feature description (ship part) — deploy description already says "hands off for out-of-band execution". Kept: office-hours, document-release / doc fallback, Design / UI pointer, plan-eng-review, superpowers aliases block, cso, media generation, the gstack-OFF paragraph (reworded "use the fallback above" → "use the fallback the skill descriptions or the lines above name").
- [gated] the 3-line "≤3 lines for vendored aliases" target is a phase 3 estimate, not a hard cap: superpowers aliases stay as one block (4 aliases).

## ACCEPTANCE CRITERIA
1. Dropped lines gone from CLAUDE.global.md (r3 text is final); the two kept lines present; line count lower than develop's.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'gstack investigate only on explicit ask\|W3C + WCAG → web-validate' CLAUDE.global.md)$( [ $(wc -l < CLAUDE.global.md) -lt $(git show develop:CLAUDE.global.md | wc -l) ] && echo LT)
   EXPECT: 2LT
   EVIDENCE: PENDING
1b. Dropped lines absent.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c 'distinguished by file count\|Grouped all-axes sweep\|Open-work inventory\|Before /clear or /compact\|Bug / error / 500' CLAUDE.global.md)
   EXPECT: 0
   EVIDENCE: PENDING
2. bugfix and ship-feature descriptions gain the r3 triggers.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c '"stack trace + fix"' skills/bugfix/SKILL.md)$(grep -c '"ship this feature"' skills/ship-feature/SKILL.md)
   EXPECT: 11
   EVIDENCE: PENDING
3. Census + skill frontmatter suites green.
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/doctrine-citers.test.sh 2>&1 | tail -1
   EXPECT: FAIL=0
   EVIDENCE: PENDING
4. make test green (manual, bun on PATH); skill-routing-census no new WARN/FAIL.
5. Both frontmatters parse as YAML.
   CHECK: cd /home/bchanot/Documents/claude && python3 -I -c 'import yaml,sys; [yaml.safe_load(open(f).read().split("---")[1]) for f in sys.argv[1:]]; print("YAML-OK")' skills/bugfix/SKILL.md skills/ship-feature/SKILL.md
   EXPECT: YAML-OK
   EVIDENCE: PENDING

## FILE SCOPE
CLAUDE.global.md (§ Skill routing), skills/bugfix/SKILL.md (frontmatter), skills/ship-feature/SKILL.md (frontmatter). README/USAGE routing mirrors → STEP 6 doc sync.
