---
name: site-motion
description: |
  Site-level motion choreography: scroll engine choice, page-transition
  rules, and pin/scrub sequencing across a whole page or Astro route —
  not one component's hover or enter/exit (that's design-motion-principles
  or emil-design-eng). Distills the invariants behind smooth scroll,
  scroll storytelling, sticky card stacks, video/image scrubbing, and
  WebGL hero lanes into gates, numbers, and pitfalls.
  Triggers: "site mouvementé", "scroll storytelling", "smooth scroll",
  "hero WebGL", "transitions de page", "page transitions", "Lenis",
  "ScrollTrigger", "Awwwards".
argument-hint: <page, section or route to choreograph>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

# Site motion — page-level scroll and transition choreography

Invariants, not machinery: numbers and gates that hold across whichever
scroll library the project already runs (LRN-141). Defaults follow
`rules/web-building.md`; this skill only adds the site-level layer on
top of it.

## When to use this, not the component skills

- One component's hover, tap feedback, or enter/exit → the target feels
  small and self-contained → `skills-external/design-motion-principles/SKILL.md`
  (component motion, frequency/duration framework) or
  `skills-external/emil-design-eng/SKILL.md` (taste, polish).
- The choice is page-wide: which scroll engine, whether to pin a section,
  how a route transition should morph, how a WebGL hero should degrade →
  this skill.
- Linting already-shipped motion against anti-slop rules →
  `skills/impeccable/reference/animate.md` (`impeccable detect`) as the
  deterministic floor, or design-motion-principles' own audit workflow
  (`skills-external/design-motion-principles/workflows/audit.md`).
- Non-motion defaults (fonts, color, spacing, the public-site checklist)
  stay in `rules/web-building.md` — read it, don't restate it here.

## Gates first (fail closed, not invisible)

- Under `prefers-reduced-motion: reduce`, every animation renders its
  FINAL state, never a shortened version of the same tween — jump, don't
  rush.
- Content is visible with JavaScript disabled; no permanent
  `opacity: 0` gated only by a script that might fail to run.
- Any `html.js` (or `.has-motion`) class that hides the pre-animation
  state is added only AFTER `gsap.registerPlugin(...)` and the reveal
  setup both succeed — never before. An error between the two otherwise
  leaves real content stuck invisible with no JS path left to reveal it.
- Animate compositor-only properties: `transform`, `opacity`, short-lived
  `filter`/`clip-path`. Never a layout property during scroll.
- `will-change` only while an element is actively animating; drop it
  once the animation ends.
- Every RAF loop, CSS animation, and WebGL render loop pauses when its
  section leaves the viewport and resumes on re-entry.
- The first-viewport CTA is never covered by a preloader.
- No preloader on a fixed timer — tie its exit to real load state.

## Engine choice

- Exactly one smooth-scroll engine per page. A second scroller (native
  plus Lenis, or two libraries) fights the first over wheel/touch input
  and desyncs from anything watching scroll position.
- Lenis feeds `ScrollTrigger` through `gsap.ticker`, with
  `gsap.ticker.lagSmoothing(0)` — without it, a tab-switch catch-up jump
  throws scrub position out of sync with the visuals.
- Reach for CSS `animation-timeline: scroll()` / `view()` first when the
  effect is a plain progress mapping with no pin and no cross-timeline
  coordination. GSAP/Lenis earn their cost on pin, scrub-linked
  sequencing, or a timeline shared across sections (BDR-005: `motion` is
  the default library; GSAP is allowed once the project already uses it
  or the effect needs pin/scrub).

## Astro lifecycle (ClientRouter)

Route swaps replace the DOM without a full reload, so `DOMContentLoaded`
fires once and never again.

- Init scroll engines, `ScrollTrigger` instances, and RAF loops on
  `astro:page-load` — it fires after every swap, including the first.
- Teardown on `astro:before-swap`: kill ScrollTriggers, stop the
  scroller, cancel RAF, disconnect observers, before the old DOM is
  replaced — otherwise the previous route's loop keeps running detached.
- `transition:persist` on a WebGL canvas or renderer that should survive
  the swap instead of losing its context every navigation; pair it with
  hooks that update the scene, not rebuild it.
- `transition:name` for element morphs (hero image to detail image)
  across routes; leave unrelated elements unnamed to avoid accidental
  cross-fades.
- Test every scene with JavaScript on and off — without it, the
  ClientRouter falls back to a normal navigation and the page still has
  to make sense.

## Recipes (the numbers)

- Reveal: trigger at `top 82%`, once; ease the entrance tween itself,
  never the trigger point.
- Scrub scenes: `scrub: 0.8` to `1.4`, `ease: "none"` on the
  scroll-driven tween — ease the child tweens inside it instead, so the
  outer timeline stays scroll-linear while the content still feels eased.
- Sticky card stack: the receding card scales to `0.92 + i * 0.015`
  (`i` = card index), scrubbed from the next card crossing `top 78%` to
  `top 24%`.
- Story pacing: budget `0.7` to `1.8` viewport heights of scroll per
  story beat — below that it reads as a flicker, above it as a stall.
- Video scrub: encode with
  `ffmpeg -g 8 -keyint_min 8 -sc_threshold 0 -movflags +faststart` — a
  keyframe every 8 frames so scrubbed `currentTime` seeks land on-frame.
- Image sequences: preload the current frame first, prefetch neighbors,
  and cancel stale in-flight requests on a fast scroll so a slow response
  can't paint an out-of-order frame.
- Word-level reveal on marked-up text (links, `em`, `strong` inside):
  walk it with `TreeWalker`, wrap non-whitespace tokens in spans, keep
  the original text and its inline markup intact.
- Progressive blur: stack `backdrop-filter` layers from `0.5px` to
  `64px`, each masked to a `12.5%` band of the gradient; add the
  `-webkit-backdrop-filter` prefix for Safari; cap the band at `12%` of
  viewport height from the top edge, `65%` from the bottom.
- Marquee: duplicate the track, animate `translateX(-50%)` linear, mark
  the duplicate `aria-hidden`, pause the track while its section is
  offscreen.
- Magnetic and cursor motion: drive with `gsap.quickTo()` so a pointer
  move updates the existing tween instead of creating a new one per
  event.
- WebGL hero, one lane per page:
  - A pricing or checkout page keeps the WebGL lane decorative only.
  - Build the poster fallback first, enhance after — the poster is the
    page when WebGL fails or the tab throttles.
  - Handle `webglcontextlost`/`webglcontextrestored` explicitly.
  - Mobile budget: DPR `1.25` to `1.5`, `150k` to `300k` visible
    triangles, `50` to `90` draw calls.
  - Track two progress values: exact scroll progress for navigation and
    ARIA state, a damped one for the camera — the camera can lag, the
    nav state cannot.
- Leak census: sample `document.getAnimations()` before and after a
  route round-trip. A count that grows across `astro:page-load` cycles
  means a teardown is missing, not that more is animating.

## Upstream pitfalls

- `clearProps` combined with a visibility override in the same
  reduced-motion call clears that override before the CSS-hidden class
  it was meant to defeat ever lifts — text stays hidden. Clear props or
  drop the hiding class; don't do both in one step.
- `registerPlugin` running after the `html.js` gate is already set: see
  Gates above, this is the concrete failure it prevents.
- A per-frame increment (`phi += 0.01`) with no delta-time factor ties
  rotation speed to frame rate — the same globe spins at a different
  real-world speed on a 30 Hz and a 120 Hz display.
- A WebGL context torn down and rebuilt on every `resize` event: expensive,
  and rapid resizing (mobile keyboard, orientation flicker) can trigger a
  real context loss. Resize the renderer/camera in place; debounce first.
- A preloader gated on a fixed timer exits early on a slow connection and
  late on a fast one; gate it on real asset load state instead.
- `aria-label` set on a `<p>` after flattening it to plain text: any
  inline link, `em`, or `strong` it contained is gone for assistive tech,
  which now hears the label instead of the real content. Use `TreeWalker`
  splitting on paragraphs with inline markup; `aria-label` is fine only on
  a plain-text heading with nothing inside to lose.
- Critical CSS starting elements at `opacity: 0` with no fallback: if the
  script errors, is blocked, or never loads, the section stays invisible
  forever. Pair every such rule with the gates above.

## Verification checklist

- Reload each scene with reduced motion forced on: final states, no
  smooth scroll, no pinning.
- Disable JavaScript: every section is present and readable in order.
- Scrub through fast and reversed: same scroll position always yields
  the same visual state.
- Resize mid-scene, including orientation change on a real WebGL scene.
- Navigate the Astro route twice: `document.getAnimations()` count
  returns to baseline, no duplicate ScrollTriggers, no orphaned RAF loop.
- Throttle to a slow connection: preloader and poster still make sense,
  CTA is reachable immediately.
- Tab away mid-scrub, come back: no jump beyond what `lagSmoothing(0)`
  already accounts for.
- Run `impeccable detect` on the touched files as the anti-slop floor.
