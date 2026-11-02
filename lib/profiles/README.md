# Profiles

A profile is a literal Claude Code settings fragment: `enabledPlugins`
(every pack `pack-<n>@skills-dir` and managed plugin, explicit), optional
`deniedMcpServers` (the two higgsfield claude.ai connectors), optional
`model`. Per project: `bash ~/.claude/lib/profile.sh set <name>` writes it
into `.claude/settings.local.json`, then `/reload-plugins`. Per
conversation: `cc <session> <name>` (lib/cc.sh) runs
`claude --settings lib/profiles/<name>.json`; that conversation is frozen
(no reload brings a pack back; relaunch instead). No profile = the manifest
defaults = `full` with the connectors present. `deniedMcpServers` is a union
across files: a `cc x web` over a project set to `dev` keeps the connectors
denied; `set web` in the project brings them back next session.

`profile.sh list` reads these lines (format `- **name**: text`):

- **full**: every pack except higgsfield and extras; ui-ux-pro-max on; connectors present. The default.
- **max**: everything on, pr-review-toolkit included; for a one-off session, not a project.
- **minimal**: no pack, no design plugin, connectors denied; the smallest listing.
- **dev**: gstack-dev only; backend or tooling work without UI.
- **design**: design, scroll3d, gstack-design, gstack-browser, ui-ux-pro-max; connectors present.
- **web**: design + scroll3d + web-validate + the three gstack packs + ui-ux-pro-max; public site work.
- **seo**: seo, web-validate, gstack-browser, gstack-dev; audit and fixes on a live site.
- **qa**: gstack-browser + web-validate; dogfooding and conformance only.
- **audit**: seo, web-validate, gstack-dev, gstack-browser, pr-review-toolkit; read-mostly audits.

Invariants (checked by `lib/pack-census.sh`): the same key set in every
fragment; `model-router@skills-dir` and `security-guidance@claude-code-plugins`
true everywhere; `example-skills@anthropic-agent-skills` and
`brightdata-plugin@synced` false everywhere; the connectors denied on exactly
minimal, dev, seo, qa, audit; `full` equal to the manifest defaults.
Add your own profile as another `<name>.json` with the same key set.
