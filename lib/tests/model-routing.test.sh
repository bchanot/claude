#!/usr/bin/env bash
# lib/tests/model-routing.test.sh — census: gate wiring + pins + executor shape (BDR-066)
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
lacks() { if grep -qF "$2" "$R/$1"; then ko "$1 must NOT contain: $2"; else ok; fi; }
fm_lacks() { if awk 'NR<=10' "$R/$1" | grep -qF "$2"; then ko "$1 frontmatter must NOT contain: $2"; else ok; fi; }

# 1) gate wired in the 12 reflection orchestrators
for s in ship-feature init-project feat bugfix onboard seo geo web-validate harden audit-delta tour code-clean; do
  has "skills/$s/SKILL.md" 'lib/model-gate.md'
done
# 2) gate NOT wired in the excluded skills (encodes the spec exclusion list)
for s in hotfix commit-change doc status release-candidate; do
  lacks "skills/$s/SKILL.md" 'lib/model-gate.md'
done
# 3) executor + gate pins
has "agents/feater.md"          'model: sonnet'
has "agents/hotfixer.md"        'model: sonnet'
has "agents/verifier.md"        'model: sonnet'
has "agents/security-auditor.md" 'model: sonnet'
fm_lacks "agents/analyzer.md"   'model:'
# 4) /feat executor shape
has "skills/feat/SKILL.md" 'subagent_type="feater"'
has "skills/feat/SKILL.md" 'verify-secure-loop.md'
lacks "agents/feater.md" 'AskUserQuestion'
# 5) SDD execution pinned
has "skills/ship-feature/SKILL.md" 'model: "sonnet"'
has "skills/init-project/SKILL.md" 'model: "sonnet"'
# 6) web-validate applies via L1 applier
has "skills/web-validate/SKILL.md" 'subagent_type="hotfixer"'

printf 'model-routing census: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
