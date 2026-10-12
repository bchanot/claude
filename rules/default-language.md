# Default language — Rust

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
