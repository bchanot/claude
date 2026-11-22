#!/usr/bin/env bash
# lib/tests/mwg-skill.test.sh — skills/modern-web-guidance: Read is the
# only pre-approved tool, no effort pin and no routing.json row (a row
# reroutes the main loop on load), no npx or network command in a fenced
# block, the relative link into skills-external/mwg, the disclosure
# format, a description within the listing budget.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/skills/modern-web-guidance"
pass=0; fail=0
check() { if [ "$2" = 1 ]; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
fm() { awk '/^---$/{n++; next} n==1' "$S/SKILL.md"; }
check exists "$([ -f "$S/SKILL.md" ] && echo 1)"
check tools "$(fm | grep -qx 'allowed-tools: Read' && echo 1)"
check no-effort "$(fm | grep -q '^effort:' || echo 1)"
desc_len="$(fm | awk '/^description:/{f=1; next} /^[a-z-]+:/{f=0} f' | tr -s ' \n' ' ' | wc -c)"
check desc-budget "$([ "$desc_len" -gt 100 ] && [ "$desc_len" -le 400 ] && echo 1)"
fenced="$(awk '/^```/{f=!f; next} f' "$S/SKILL.md" | grep -c 'npx\|pnpx\|curl\|wget')"
check no-fenced-network "$([ "$fenced" -eq 0 ] && echo 1)"
check never-run "$(grep -q 'Never run npx' "$S/SKILL.md" && echo 1)"
check read-index "$(grep -q 'Read `mwg/INDEX.md` whole' "$S/SKILL.md" && echo 1)"
check search-root "$(grep -q '~/.claude/skills/modern-web-guidance/mwg/guides/' "$S/SKILL.md" && echo 1)"
check disclosure "$(grep -q '`Modern Web Guidance: <id>, <id>`' "$S/SKILL.md" && echo 1)"
check link-mwg "$([ -L "$S/mwg" ] && [ "$(readlink "$S/mwg")" = ../../skills-external/mwg ] && echo 1)"
check tracked-link "$([ "$(cd "$ROOT" && git ls-files skills/modern-web-guidance/mwg | wc -l)" -eq 1 ] && echo 1)"
check no-routing-row "$(grep -q '"modern-web-guidance"\|"chrome-extensions"' "$ROOT/mods/model-router/routing.json" || echo 1)"
check prompts "$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if len(d)>=3 else 1)" "$S/test-prompts.json" && echo 1)"
echo "mwg-skill: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
