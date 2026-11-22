---
name: modern-web-guidance
description: >-
  Current web-platform practice from Google's Modern Web Guidance, read
  from a pinned local copy. Use FIRST, before writing or changing
  front-end code: HTML, CSS, client-side JS, UI components, forms,
  dialogs, layout, motion, Core Web Vitals, images, accessibility. Not
  for backend, infra, build tooling or tests.
allowed-tools: Read
---

# Modern Web Guidance (local, pinned)

This folder is `~/.claude/skills/modern-web-guidance/`. Its `mwg/` holds
`INDEX.md`, one line per guide (`- <id> | <category> | <summary>`), and the
guides at `mwg/guides/<category>/<id>.md`. They are a copy of
GoogleChrome/modern-web-guidance pinned in `plugins.lock.json`;
`mwg/NOTICE.md` names the commit and the licenses. Read is the only tool
needed, nothing here touches the network.

## Steps

1. Pick: Read `mwg/INDEX.md` whole (about 210 lines) and choose the
   guides whose summary matches a platform feature or UI pattern the
   task uses (a modal is `dialog`, an accordion animates to intrinsic
   sizes, a slow first paint is LCP). No summary fits a feature: search
   `~/.claude/skills/modern-web-guidance/mwg/guides/` once with the
   text-search tool at hand, else go on without a guide.
2. Read each chosen guide. Read a discipline guide (the one whose id
   equals its category: `html`, `css`, `js`, `forms`, `accessibility`,
   `performance`, `security`, `privacy`) only when building a new
   component or page, or when no specific guide matched; they are long.
3. Cross-references: a guide line `npx -y modern-web-guidance@latest
   retrieve "<id>"` names another guide. Find `<id>` in `mwg/INDEX.md`
   for its category and Read `mwg/guides/<category>/<id>.md`.
   Never run npx, the guidance CLI or any network command for this skill.
4. Apply: follow the guide, its fallbacks and its Baseline notes, without
   adding features the task did not ask for. Where a guide and a rule of
   `rules/web-building.md` disagree on how to use the platform, the guide
   wins. An executor whose closed plan contradicts a guide reports it as
   an open choice, never overrides the plan silently.
5. Disclose: the answer that delivers the front-end change (a sub-agent:
   its report) ends with one line, `Modern Web Guidance: <id>, <id>`.
   Guides checked and none applied: `Modern Web Guidance: checked <topics>,
   none applied`. No quotes.

## Missing copy

`mwg/INDEX.md` unreadable (the link dangles on a machine that never ran
the install): say once "Modern Web Guidance not installed, run
`make update`" and continue without it.
