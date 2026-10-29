# Architecture defaults — read before proposing a stack

Read at project creation, scaffolding, a stack brainstorm or a whole-project
rewrite (BDR-125 phase 1). The three defaults are named always-on in
`~/.claude/CLAUDE.md` § "Architecture decisions"; the detail lives here.

## Public websites — never SPA
A public site meant to be indexed (landing, portfolio, blog, e-commerce,
docs) is never a pure SPA (CRA, Vite React, Vue SPA): the empty HTML shell
hides content from search and AI engines, SEO and GEO destroyed.
- **Astro** by default for informational sites: static HTML at build, zero
  JS by default, React/Vue/Svelte islands for interactive parts.
- **Next.js** when dynamic SSR is needed (personalized content, server-side
  auth, API routes, hybrid app).
- **React SPA** only for what needs no indexing: admin panels, dashboards,
  auth-gated apps, internal tools. Mixed project: Astro/Next for public,
  React island (`client:only`) for admin.
- At brainstorming (`/init-project`, `/ship-feature` STEP 1), public site
  and no framework named → propose Astro, explain why not SPA. Never
  silently pick React CRA.

## Default language — Rust

Scope: a new project, a project from scratch, or a whole-project
refactor or rewrite the user asks for. Not a module refactor or a feature
inside an existing codebase: that keeps the codebase's language.

Rust is the default. Two candidates equal on features, security,
performance, reliability and ease of use or maintenance → Rust wins.
Where Rust can do the job, Rust does it.

Another language needs a demonstrated gain on one of those axes, stated
at the choice: a browser frontend (TypeScript, Astro per the web rules),
a platform that mandates its language (Swift, Kotlin), an ecosystem Rust
lacks (ML research → Python), a throwaway script where Rust's build
cycle costs more than it returns. "Rust is slower to write" alone is not
a gain.

At brainstorming (`/init-project`, `/ship-feature` STEP 1, `/refactor`
of a whole project): language not named → propose Rust, name the
contraindication if you pick something else. Never silently default to
Python, Node or Go. Mixed project: Rust for everything server-side,
CLI, systems and tooling; the exception stays scoped to the part that
earned it.

## Web APIs — always versioned
Every endpoint `/api/v1/...` from day one; breaking change → `v2`, the old
version keeps working. Full rule: `~/.claude/rules/rest-api.md` § Versioning
(loads on API files).
