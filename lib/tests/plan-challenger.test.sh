#!/usr/bin/env bash
# lib/tests/plan-challenger.test.sh — structure lock: the plan-challenger agent,
# the reusable lib/challenge-plan.md phase, and every reflection orchestrator that
# wires it (3-way adversarial plan challenge, BDR-066). STATIC only — the agent's
# adversarial behavior needs a live model (manual smoke), not a CI gate.
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has() { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
fm_lacks() { if awk 'NR<=10' "$R/$1" | grep -qF "$2"; then ko "$1 frontmatter must NOT contain: $2"; else ok; fi; }

A="agents/plan-challenger.md"
L="lib/challenge-plan.md"

# 1) agent shape
has "$A" "name: plan-challenger"
has "$A" "tools: Read, Grep, Glob, Bash"
fm_lacks "$A" "model: sonnet"                        # BDR-066: audit judgment → NOT sonnet-pinned
has "$A" "CHALLENGE — LENS:"                          # load-bearing verdict grammar
has "$A" "VERDICT: SOLID | CONCERNS(n) | FATAL(n)"
has "$A" "correctness"
has "$A" "robustness"
has "$A" "simplicity"
has "$A" "Report-only"

# 2) reusable phase — the mechanism lives here (one canonical include)
has "$L" 'subagent_type="plan-challenger"'
has "$L" "BDR-066"                                   # challengers on the big model
has "$L" "a mute verifier is NEVER a PASS"           # fail-safe (never fail open)
has "$L" "Severity-driven"                           # any single-lens BLOCKER = must-address
has "$L" "RE-THINK"                                  # findings re-plan the aspect, not just noted
has "$L" "correctness | robustness | simplicity"
has "$L" "CHALLENGE SUMMARY"
has "$L" "build-plan"                                # the three KINDs
has "$L" "proposals"
has "$L" "fix-bundle"

# 3) every reflection orchestrator wires the phase + carries a challenge summary
for s in ship-feature init-project feat bugfix onboard audit-delta code-clean seo geo harden web-validate; do
  has "skills/$s/SKILL.md" "lib/challenge-plan.md"
  has "skills/$s/SKILL.md" "CHALLENGE SUMMARY"
done

printf 'plan-challenge structure lock: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
