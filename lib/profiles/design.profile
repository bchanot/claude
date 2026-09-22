# DESC: Design work — visual QA, design systems, mockups, polish
# Activate when: building/reviewing UI, picking aesthetics, design tokens.
# Companion CLIs (advisory): graphify (visual structure).
#
# Gate scope (design-tool-gate.sh): only the tools on the GATE-BLOCK lines
# below trip the design gate. The rest of this profile (browser/plan/shotgun
# tooling, graphify) is bundled for convenience but never blocks. Keep these
# lines in sync when adding/removing a core design tool.
# GATE-BLOCK: frontend-design ui-ux-pro-max emil-design-eng design-html
# GATE-BLOCK: design-motion-principles design-review design-consultation
# GATE-BLOCK: 21st 21st-ui-build

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
impeccable                        external

# External: 21st.dev pack — CLI-driven (no MCP, no API key). 21st-registry
# and 21st-design-sync are publishing flows; installed but left parked.
21st-ui-build                     external
21st-ui-explore                   external
21st-ui-review                    external
21st-cli-use                      external
21st-ai                           external

# Plugin (auto-toggle)
ui-ux-pro-max                     plugin@ui-ux-pro-max-skill

# CLIs (advisory only — installed/not-installed)
# 21st is NOT advisory: it is on the GATE-BLOCK list, so a missing CLI trips
# the design gate. Install: npm i -g @21st-dev/cli  then  21st login
21st                              cli
graphify                          cli
