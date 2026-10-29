---
paths: ["**/*.html", "**/*.astro", "**/*.css", "**/*.scss", "**/*.tsx", "**/*.jsx", "**/*.vue", "**/*.svelte"]
---

# Web building — no default reflexes + done checklist

## Avoid unless the user asks for them
- Purple gradient, purple/black, neon, washed-out pastels, rainbow.
- Drop shadow on everything; the same border-radius on every element.
- Bento grid, dot grid, glowing background orbs, decorative color strip.
- Sparkle icons, animated arrows, emojis as icons, decorative fake
  terminal window.
- Hover animation on every element; scroll-reveal animations everywhere.
- Three aligned feature cards, three pricing tiers, checkmark bullets.
- Vague hero title ("unleash your potential"): state what the product does.
- Fake testimonials, fake visitor or client counters, invented numbers.
  Never, in any context.
- Inter, Geist or Space Grotesk as the default font: propose an
  alternative and justify it. Existing brand identities keep their fonts.

## Write-time reflexes (stack-agnostic, from ui-skills)
- Full height: `100dvh`, never `100vh`; fixed elements respect
  `safe-area-inset`. Never block paste in inputs.
- Numbers: `tabular-nums`. Headings `text-wrap: balance`, body `pretty`.
  Long labels: truncate or line-clamp, never overflow.
- One z-index scale from tokens, no arbitrary values.
- Motion: transform and opacity only; feedback under 200 ms, ease-out on
  entrances, never from scale(0); `will-change` only during an active
  animation; pause loops off-screen; honor `prefers-reduced-motion`.
- Touch targets 44 px minimum; keyboard and focus per `rules/a11y.md`; status never
  by color alone, add text or an icon.
- Errors next to the field; empty state = one clear action; destructive
  action confirmed first.
- One accent color per view; solid modal backdrop, no full-screen blur.

## Before declaring a public site done
Check: custom 404 · call to action in the first viewport · per-page
title + description · share/OG image · favicons · robots.txt · sitemap ·
accessibility baseline (`rules/a11y.md`) · layout tested at 375 px · loading states · form
error messages · confirmation page · real legal mentions · cookie banner
with a working refuse option · audience measurement · contact address ·
compressed images.
Report the missing items to the user instead of inventing them. Internal
tools and dashboards: only the relevant items apply. Deep audits stay
with /seo, /harden, /web-validate.

## Design work — full toolchain (tiered by scope)
Trigger = UI work: editing a component/style file (.tsx/.vue/.svelte/.css…)
or a design/UI request, not the word "design" alone. Single source for
design routing; the design-toolchain hook reinforces it.
- Trivial (≤2 files, one cosmetic value) → /hotfix, no toolchain.
- Build UI (component, page, redesign) → impeccable (build path: init,
  shape, new-work, craft floor, fresh finish reviewer) + ui-ux-pro-max +
  21st-ui-build (catalog + generation) + emil-design-eng (polish) +
  design-motion-principles (motion) + design-html (static) + site-motion.
  Floor: `impeccable detect <files>` (61 rules, exit 2). frontend-design
  only for a one-off visual with no project context, not beside impeccable.
- Design system / brand → design-consultation first, then the build tools.
- Review / audit → design-review + emil-design-eng + design-motion-principles
  + /impeccable audit|critique + `impeccable detect` floor.
- The vendored stack members route to `reflect` (high) through their
  model-router rows (`mods/model-router`); the last rowed skill loaded
  wins and an unrowed member (plugin, gstack) changes nothing.
Scope doubt → ask or default to Build, never silently skip. Gate: light
skills run `~/.claude/lib/design-gate.md`, orchestrators plugin-check. 21st =
CLI (`npm i -g @21st-dev/cli`, `21st login`), no MCP, no key; search free,
`21st get`/`generate` metered → generation, not micro-tweaks. 21st-ai /
ui-explore / ui-review are `max`-profile only.
