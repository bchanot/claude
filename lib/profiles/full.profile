# DESC: Maximum mode — web-full + plan + dev for end-to-end MVP via /init-project
# Activate when: scaffolding new project with /init-project and need
# brainstorm → design → architecture review → scaffold → implement → ship → audit
# pipeline available in one session. Superset of web-full + dev.

# === Brainstorm + plan-mode reviews ==================================
office-hours
plan-ceo-review
plan-eng-review
plan-design-review
plan-devex-review
autoplan
spec

# === Design pipeline =================================================
design-shotgun
design-review
design-consultation
design-html

# === Browser + dogfooding ============================================
browse
open-gstack-browser
setup-browser-cookies
scrape
skillify

# === Code work — implementation ======================================
feat                              personal
ship-feature                      personal
hotfix                            personal
bugfix                            personal
investigate
refactor                          personal
code-clean                        personal
commit-change                     personal

# === Ship + review + land ============================================
ship
review
context-save
land-and-deploy
setup-deploy

# === Second opinion ==================================================
codex

# === SEO / GEO / standards / security ================================
seo                               personal
geo                               personal
web-validate                      personal
harden                            personal
analyze                           personal
cso

# === Perf + canary + QA ==============================================
health
benchmark
canary
qa
qa-only

# === Docs + translation ==============================================
doc                               personal
document-release
diagram
make-pdf
pdf-translate                     personal

# === Session hygiene + memory ========================================
close                             personal
prune-memory                      personal
status                            personal
learn
retro
careful
freeze
unfreeze
guard

# === External + plugin + MCP =========================================
emil-design-eng                   external
frontend-design                   external
design-motion-principles          external
impeccable                        external
ui-ux-pro-max                     plugin@ui-ux-pro-max-skill
# pr-review-toolkit REMOVED from full (audit 2026-07-02 #12): heaviest
# single plugin cost (~2.2k tokens of agent descriptions/session), useful
# only when reviewing PRs. Reactivate per PR session:
#   claude plugin enable pr-review-toolkit@claude-code-plugins
# or profile-based: bash lib/profile.sh apply audit (audit.profile keeps it;
# a later `set full` re-disables it — MANAGED_PLUGINS lifecycle).
21st-ui-build                     external
21st-ui-explore                   external
21st-ui-review                    external
21st-cli-use                      external
21st-ai                           external

# === CLIs (advisory) =================================================
21st                              cli
ctx7                              cli
graphify                          cli
gsd                               cli
