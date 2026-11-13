# PLAN — skill-routing-descriptions (r1)
- CLAUDE.global.md:270-302: delete lines "- Bug / error / 500 → bugfix …" (3 lines), "- feat / hotfix / bugfix distinguished …", "- Ship / PR → ship-feature … runs it)" (3 lines), "- Grouped all-axes sweep … → tour", "- Open-work inventory … → reconcile", "- Before /clear or /compact → capitalize; end-of-session ritual → close"; rewrite "- SEO+GEO → seo … → web-validate;\n  security audit (secrets, CVE, OWASP) → cso" to "- Security audit (secrets, CVE, OWASP) → cso"; last paragraph "use the fallback above, else say so" → "use the fallback their descriptions or the lines above name, else say so". Intro sentence stays.
- skills/bugfix/SKILL.md description (YAML block `|`): append two lines: `  Also: error / 500 / stack trace. gstack /investigate only on explicit` / `  ask (cross-project learnings, /freeze, long open-ended investigation).` (keep ≤ 80 cols, same indentation).
- skills/ship-feature/SKILL.md description (single-quoted YAML string): append inside the quotes ` Ship / PR → this skill, never gstack ship (its base origin/HEAD = main skips develop).` — single quotes inside must be doubled if any (none in the added text).
- Edge: the skill listing budget (SLASH_COMMAND_TOOL_CHAR_BUDGET) grows by ~200 chars: accepted (CLAUDE.global.md shrinks by ~10 lines, always-on).
- Tests: no suite pins these lines (doctrine-citers cites headings/labels; "Skill routing" heading kept); YAML parse check: `python3 -I -c 'import yaml,sys…'` not available → `claude plugin validate` not applicable; run `make test` (skills frontmatter census, model-routing census reads descriptions? check: lib/tests/effort-routing or routing census reads `description:` only for presence).
- Disposition: honors BDR-125 phase 1/3 (routing lines → descriptions, vendored aliases stay), BDR-130 (CLAUDE.global.md density), BDR-022 (no .claude content in public docs).

## r2 (correctness CONCERNS(2), robustness CONCERNS(3), simplicity SOLID; no BLOCKER) — r2 wins over r1
- KEPT always-on (robustness MAJOR 1+2): (a) one gstack line replacing the Bug and Ship lines: `- gstack investigate / ship only on explicit ask: bug, error, 500 → bugfix (contract, verifier and security gates, registries); ship / PR → ship-feature; deploy → deploy (runbook, the user runs it)` — counterweight to gstack's own "Bugs/errors → /investigate" routing injection; (b) the SEO/GEO/W3C line kept, pack-aware: `- SEO+GEO → seo (GEO only → geo); W3C + WCAG → web-validate (packs: off → \`profile.sh enable <pack>\` or say so); security audit (secrets, CVE, OWASP) → cso`.
- DROPPED (carried by always-listed descriptions of our core skills): "feat / hotfix / bugfix distinguished by file count", "Grouped all-axes sweep → tour", "Open-work inventory → reconcile", "Before /clear or /compact → capitalize; ritual → close".
- Descriptions (simplicity MINOR 1-2, correctness MINOR 3): bugfix `Trigger:` list gains `"error", "500", "stack trace"` (no new "Also:" line); ship-feature description gains PR triggers `"open a PR", "ship this feature"` at the end of its sentence list (no "never gstack ship" text: gstack ship is retired from every pack, lib/gstack-removed.list). No bare "ship" (deploy owns "ship to prod").
- OFF paragraph: `gstack or other packs OFF (\`profile.sh current\`) → their skills are gone: use the fallback our skills' descriptions or the lines above name, else say so.`
- Oracles (correctness/robustness MAJOR): AC2 → `echo $(grep -c '"stack trace"' skills/bugfix/SKILL.md)$(grep -c '"open a PR"' skills/ship-feature/SKILL.md)` EXPECT `11`; new AC5 YAML: `python3 -I -c 'import yaml,sys; [yaml.safe_load(open(f).read().split("---")[1]) for f in sys.argv[1:]]; print("YAML-OK")' skills/bugfix/SKILL.md skills/ship-feature/SKILL.md` EXPECT `YAML-OK`; suite under watch: lib/tests/skill-routing-census.test.sh (no new WARN/FAIL).
- Accepted: no persistence pin for the description triggers (darwin rewrite risk, MINOR).

## r3 (confirmation CONCERNS(1), no BLOCKER; folded, no further challenge) — FINAL TEXT, r1 body above is VOID for CLAUDE.global.md
Result in CLAUDE.global.md § Skill routing (replace lines 270-302 by exactly this list, intro sentence kept):
- Product idea, "worth building?" → office-hours
- gstack investigate only on explicit ask: bug, error, 500 → bugfix (contract,
  verifier and security gates, registries). gstack ship is retired (BDR-105):
  ship / PR → ship-feature; deploy → deploy (runbook, the user runs it)
- Docs post-ship → document-release (doc if gstack off); stale-doc audit → doc
- Design / UI (build, system, audit, polish) → Read
  `~/.claude/rules/web-building.md` § "Design work" first
- Architecture review → plan-eng-review
- superpowers aliases block (unchanged, 6 lines)
- SEO+GEO → seo (GEO only → geo); W3C + WCAG → web-validate. Pack off →
  propose `profile.sh enable seo` (seo, geo) or `enable web-validate`, the
  user runs `/reload-plugins`; else say so. Security audit (secrets, CVE,
  OWASP) → cso
- Media generation block (unchanged)
gstack or other packs OFF (`profile.sh current`) → their skills (investigate,
qa, review, health, retro, office-hours, seo, web-validate…) are gone: use the
fallback our skills' descriptions or the lines above name, else say so.
Descriptions: bugfix `Trigger:` list gains `"error", "500", "stack trace + fix"`; ship-feature gains the trigger `"ship this feature"` (no "open a PR": no skill opens a PR).
Oracles (contract): every CHECK prefixed `cd /home/bchanot/Documents/claude &&`; AC1 also asserts presence: `grep -c 'gstack investigate only on explicit ask\|W3C + WCAG → web-validate' CLAUDE.global.md` → 2; line count below develop's; AC2 → `"stack trace + fix"` + `"ship this feature"` → 11.
