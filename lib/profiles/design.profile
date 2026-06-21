# DESC: Design work — visual QA, design systems, mockups, polish
# Activate when: building/reviewing UI, picking aesthetics, design tokens.
# Companion CLIs (advisory): graphify (visual structure).
#
# Gate scope (design-tool-gate.sh): only the tools on the GATE-BLOCK lines
# below trip the design gate. The rest of this profile (browser/plan/shotgun
# tooling, graphify) is bundled for convenience but never blocks. Keep these
# lines in sync when adding/removing a core design tool.
# GATE-BLOCK: frontend-design ui-ux-pro-max emil-design-eng design-html
# GATE-BLOCK: design-motion-principles design-review design-consultation magic

# Core design skills (gstack)
design-shotgun
design-review
design-consultation
design-html
plan-design-review

# Browser tooling — design-review and design-shotgun rely on it
browse
open-gstack-browser
setup-browser-cookies

# Plan-mode review companion (taste decisions before code)
plan-ceo-review

# External: design skills
emil-design-eng                   external
frontend-design                   external
design-motion-principles          external

# Plugin (auto-toggle)
ui-ux-pro-max                     plugin@ui-ux-pro-max-skill

# MCP — auto-toggle via lib/toggle-external.sh (needs MAGIC_API_KEY in .env)
magic                             mcp

# CLIs (advisory only — installed/not-installed)
graphify                          cli
