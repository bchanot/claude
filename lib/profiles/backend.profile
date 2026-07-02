# DESC: Backend / API / system dev — no design, no SEO, focused on logic
# Activate when: building backend services, APIs, CLIs, libraries, system
# code, data pipelines. UI/visual work is out of scope. SEO/GEO out of scope.

# Code work — primary
feat                              personal
ship-feature                      personal
hotfix                            personal
bugfix                            personal
investigate
refactor                          personal
code-clean                        personal
commit-change                     personal
analyze                           personal

# Ship + review + land
ship
review
context-save
land-and-deploy

# Second opinion for hard problems
codex

# Security + health (always relevant for backend)
cso
health

# Session hygiene
careful
freeze
unfreeze
guard
learn
retro

# pr-review-toolkit removed (audit 2026-07-02 #12 — ~2.2k tokens, PR-only):
# enable per PR session via `bash lib/profile.sh apply audit` or
# claude plugin enable pr-review-toolkit@claude-code-plugins

# CLIs (advisory)
ctx7                              cli
gsd                               cli
graphify                          cli
