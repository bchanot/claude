# CONTRACT — site-motion-skill
- date: 2026-09-27 | flow: feat (ad-hoc dispatch, /feat gates replayed by the orchestrator) | branch: feature/mengto-site-motion
- status: active

## REQUEST (verbatim — IMMUTABLE)
> Write the personal skill `skills/site-motion/SKILL.md` (+ `test-prompts.json` for darwin, same schema as the 32 existing ones): site-level motion choreography for lively modern sites, distilling the invariants of the MengTo motion pack (LRN-141: invariants, never machinery), aligned with rules/web-building.md, BDR-005 (`motion` is the default library; GSAP allowed for scroll choreography when the project already uses it or the effect needs pin/scrub) and the design toolchain. Sections: when to use versus the component-level skills (emil-design-eng, design-motion-principles, impeccable animate) and the audits; gates first (reduced motion renders final states, never shortened animations; content visible without JS, `html.js` gate set only after plugin registration; compositor-only properties, `will-change` only during an animation, offscreen pause, first-viewport CTA never covered by a preloader, no preloader on a timer); engine choice (exactly one smooth-scroll engine; Lenis ↔ ScrollTrigger sync through `gsap.ticker` with `lagSmoothing(0)`; CSS `animation-timeline` first when the effect is plain progress); Astro lifecycle with ClientRouter (init on `astro:page-load`, teardown on `astro:before-swap`, `transition:persist` for canvases, `transition:name` for morphs, test with and without JS); recipes as numbers (reveal at `top 82%`, once; scrub 0.8-1.4 with `ease: "none"` and eased children; sticky card stack scale `0.92 + i*0.015` from the next card `top 78%` → `top 24%`; 0.7-1.8 viewport heights of scroll per story beat; video scrub encoded with `ffmpeg -g 8 -keyint_min 8 -sc_threshold 0 -movflags +faststart`; image sequences cancel stale requests; word split through `TreeWalker` with the original text kept readable and no `aria-label` on paragraphs; progressive blur = stacked `backdrop-filter` layers 0.5 → 64 px in 12.5 % mask bands with the `-webkit-` prefix, top ≤ 12 %, bottom ≤ 65 %; marquee = duplicated track, `translateX(-50%)` linear, `aria-hidden` clone, paused offscreen; magnetic and cursor effects through `gsap.quickTo`; WebGL: one lane per page, pricing decorative only, poster fallback built first, context loss handled, DPR 1.25-1.5 on mobile with 150-300k triangles and 50-90 draw calls, exact progress for navigation and ARIA versus damped progress for the camera; offscreen census through `document.getAnimations()` and route-cycle leak sampling); an upstream-pitfalls list; a verification checklist. Routing: one line in CLAUDE.global.md § Design work, "Build UI" chain, and in lib/design-gate.md's toolchain list, doctrine budget ≤ 320 lines. User go 2026-09-27 ("ok pour 1, l'hybride", case 7).

## CLARIFICATIONS
- Length 140-220 lines, English, frontmatter `name: site-motion` and a `description:` that states what it does then FR+EN triggers ("site mouvementé", "scroll storytelling", "smooth scroll", "hero WebGL", "transitions de page", "Lenis", "ScrollTrigger", "Awwwards"), plus the frontmatter keys the sibling personal skills carry (read skills/feat/SKILL.md and one design-side skill for the shape).
- Sources: the upstream texts are already on disk, read them, never re-fetch: /tmp/claude-1000/-home-bchanot-Documents-claude/977f1703-f01d-497a-b794-5b69fafcd35f/scratchpad/mengto/ (11 small skills) and .../scratchpad/mengto-heavy/ (11 heavy ones, extras under x/). Distil; never copy paragraphs.
- Never prescribe: glow or gradient hover, reveal on every section, permanent `will-change`, Inter or Geist, preloaders on timers, entrances from `scale(0)`, ease-in exits. Point to rules/web-building.md by path instead of restating it.
- Pitfalls to list (found upstream by reading): `clearProps` under reduced motion leaving text hidden behind a visibility gate; `registerPlugin` after the `html.js` gate; per-frame `phi += 0.01` without delta time; WebGL context recreated on every resize; preloader on a fixed timer; `aria-label` on `<p>`; content left at opacity 0 without JS.
- Citations of doctrine use the exact heading: `CLAUDE.md § Design work — full toolchain (tiered by scope)`; any other citation must resolve for lib/tests/doctrine-citers.test.sh.
- No profile edits (the sibling contract adds `site-motion personal` to the design profiles); no CHANGELOG; no README.
- test-prompts.json: ≥ 4 prompts, at least one French, following the existing schema.

## ACCEPTANCE CRITERIA
1. Shape: frontmatter, name, description, length, valid test prompts.
   CHECK: f=skills/site-motion/SKILL.md; [ -f "$f" ] && [ "$(head -1 "$f")" = "---" ] && grep -q "^name: site-motion$" "$f" && grep -qE "^description:" "$f" && n=$(wc -l < "$f") && [ "$n" -ge 140 ] && [ "$n" -le 220 ] && python3 -c 'import json; d=json.load(open("skills/site-motion/test-prompts.json")); p=d if isinstance(d,list) else next(v for v in d.values() if isinstance(v,list)); assert len(p)>=4' && echo SHAPE
   EXPECT: SHAPE
   EVIDENCE: MET exit=0 marker-found :: SHAPE
2. Content markers present.
   CHECK: f=skills/site-motion/SKILL.md; ok=1; for k in "prefers-reduced-motion" "astro:page-load" "astro:before-swap" "transition:persist" "transition:name" "lagSmoothing" "animation-timeline" "TreeWalker" "-webkit-backdrop-filter" "getAnimations" "quickTo" "keyint_min" "top 82%" "0.015" "draw call" "poster" "html.js" "emil-design-eng" "design-motion-principles" "web-building.md"; do grep -qi -- "$k" "$f" || { echo "missing $k"; ok=0; }; done; [ "$ok" -eq 1 ] && echo CONTENT
   EXPECT: CONTENT
   EVIDENCE: MET exit=0 marker-found :: CONTENT
3. No default-reflex prescriptions.
   CHECK: f=skills/site-motion/SKILL.md; ! grep -qE "\b(Inter|Geist)\b" "$f" && ! grep -qiE "scale\(0\)[^)]*(entrance|enter|in\b)" "$f" && echo NO_DEFAULT_REFLEXES
   EXPECT: NO_DEFAULT_REFLEXES
   EVIDENCE: MET exit=0 marker-found :: NO_DEFAULT_REFLEXES
4. Routing wired within budget.
   CHECK: grep -q "site-motion" CLAUDE.global.md && grep -q "site-motion" lib/design-gate.md && [ "$(wc -l < CLAUDE.global.md)" -le 320 ] && echo ROUTED
   EXPECT: ROUTED
   EVIDENCE: MET exit=0 marker-found :: ROUTED
5. Citations resolve and the skill routes without collision.
   CHECK: out=$(make test suite="lib/tests/doctrine-citers.test.sh lib/tests/skill-routing-census.test.sh" 2>&1); echo "$out" | grep -qE "FAIL=[1-9]" && { echo "$out" | tail -15; exit 1; }; echo "$out" | grep -E "^(WARN|FAIL) " | grep -q "site-motion" && { echo "site-motion collides"; echo "$out" | grep -E "site-motion"; exit 1; }; echo CITED_AND_ROUTABLE
   EXPECT: CITED_AND_ROUTABLE
   EVIDENCE: MET exit=0 marker-found :: CITED_AND_ROUTABLE
6. Every local path the skill names exists.
   CHECK: ok=1; for p in $(grep -oE "\b(skills-external|skills|rules|lib)/[A-Za-z0-9_./-]+" skills/site-motion/SKILL.md | sed 's/[.,;:)]*$//' | sort -u); do [ -e "$p" ] || { echo "missing $p"; ok=0; }; done; [ "$ok" -eq 1 ] && echo LINKS_OK
   EXPECT: LINKS_OK
   EVIDENCE: MET exit=0 marker-found :: LINKS_OK

## FILE SCOPE
- skills/site-motion/SKILL.md (new), skills/site-motion/test-prompts.json (new)
- CLAUDE.global.md (one line, § Design work, "Build UI" chain), lib/design-gate.md (toolchain list lines)

## PLAN
1. Read the shape precedents (skills/feat/SKILL.md frontmatter, one design-side personal skill, skills/feat/test-prompts.json), rules/web-building.md, the "Design work" section of CLAUDE.global.md, lib/design-gate.md lines 40-50 and 130-140, and the upstream scratch copies.
2. Draft the skill: When to use / not; Gates first; Engine choice; Astro lifecycle; Recipes (numbers); Upstream pitfalls; Verification. Link to the local skills by path.
3. test-prompts.json; routing line + design-gate list; run criteria 1-6.
