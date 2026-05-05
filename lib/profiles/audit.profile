# DESC: Comprehensive audit — security + SEO + GEO + W3C + perf + health
# Activate when: doing a top-to-bottom audit pass on an existing project.
# Wider than `seo` (adds security + dependency review).

# Security
cso
harden                            personal
analyze                           personal

# SEO / GEO / web standards
seo                               personal
geo                               personal
validate                          personal

# Code + perf health
health
benchmark
review

# Browser tooling for live audits
browse
open-gstack-browser

# Plugin: PR review toolkit (audit context for diffs)
pr-review-toolkit                 plugin@claude-code-plugins

# CLI: graphify for code structure
graphify                          cli
