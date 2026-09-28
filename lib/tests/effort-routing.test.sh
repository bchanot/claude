#!/usr/bin/env bash
# lib/tests/effort-routing.test.sh — census: effort tiering (BDR-NEXT)
# agent pins, skill entry levels, shifter skills, orchestrator wiring, settings.
# shellcheck disable=SC2015  # A && ok || ko is deliberate here: ok/ko never fail, so C never masks a true A
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
lacks() { if grep -qF "$2" "$R/$1"; then ko "$1 must NOT contain: $2"; else ok; fi; }
# frontmatter = the lines between the first two '---' lines
fm() { awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' "$1"; }
fm_effort() { fm "$1" | grep -E '^effort: (low|medium|high|xhigh|max)$' | head -1 | cut -d' ' -f2; }
fm_has_effort() {
  got="$(fm_effort "$R/$1")"
  if [ "$got" = "$2" ]; then ok; else ko "$1 frontmatter effort must be '$2', got '${got:-none}'"; fi
}
fm_no_effort() { if fm "$R/$1" | grep -q '^effort:'; then ko "$1 must NOT pin effort"; else ok; fi; }

# ── flip-test: the frontmatter reader must accept a valid level and reject an invalid one
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
printf -- '---\nname: good\neffort: xhigh\n---\nbody with effort: low in prose\n' > "$FIX/good.md"
printf -- '---\nname: bad\neffort: turbo\n---\n' > "$FIX/bad.md"
[ "$(fm_effort "$FIX/good.md")" = "xhigh" ] && ok || ko "flip: valid level not read"
[ -z "$(fm_effort "$FIX/bad.md")" ] && ok || ko "flip: invalid level accepted"
[ "$(fm "$FIX/good.md" | grep -c 'prose')" -eq 0 ] && ok || ko "flip: body leaked into frontmatter"

# ── 1) session default (spec D1)
has "settings.json" '"effortLevel": "high"'

# ── 2) hooks: env-var warning + live effort in the statusline (spec D1, D5)
has "hooks/session-start.sh" 'CLAUDE_CODE_EFFORT_LEVEL'
has "hooks/statusline.sh" 'CLAUDE_EFFORT'

# ── 3) agent pins (spec D2): one effort per agent file, judgment mode wins on mode-based agents
for a in hotfixer release-executor plugin-probe validator-analyzer; do fm_has_effort "agents/$a.md" low; done
for a in feater bugfixer code-cleaner onboarder scaffolder; do fm_has_effort "agents/$a.md" medium; done
for a in refactorer analyzer commit-changer doc-syncer handover-doc-writer; do fm_has_effort "agents/$a.md" high; done
for a in plan-challenger plugin-advisor verifier security-auditor seo-analyzer geo-analyzer; do fm_has_effort "agents/$a.md" xhigh; done
for a in interviewer client-handover-writer status-reporter; do fm_no_effort "agents/$a.md"; done
has "skills/init-project/SKILL.md" 'pin sonnet, effort medium'

# ── 4) skill entry levels (spec D3): the user's invocation sets the run's level
for s in status commit-change release-candidate doc capitalize close reconcile deploy profile plugin-check; do fm_has_effort "skills/$s/SKILL.md" low; done
for s in gitflow prune-memory; do fm_has_effort "skills/$s/SKILL.md" medium; done
for s in feat hotfix bugfix refactor web-validate harden seo geo; do fm_has_effort "skills/$s/SKILL.md" high; done
for s in ship-feature init-project onboard tour audit-delta analyze code-clean client-handover; do fm_has_effort "skills/$s/SKILL.md" xhigh; done

# ── 9) vendored superpowers carry xhigh (spec D3). The files live in skills-external/ (gitignored,
#      machine-owned), so the durable artifact is the install-plugins.sh re-apply; the frontmatter
#      check skips VISIBLY when the skill is not vendored yet (fresh clone before make plugin).
for s in brainstorming writing-plans; do
  if [ -f "$R/skills-external/$s/SKILL.md" ]; then fm_has_effort "skills-external/$s/SKILL.md" xhigh
  else printf 'SKIP skills-external/%s/SKILL.md not vendored yet (run make plugin)\n' "$s"; fi
done
has "install-plugins.sh" 'effort: xhigh'

# ── 5) shifter skills + include (spec D4)
for l in low medium high xhigh max; do fm_has_effort "skills/effort-$l/SKILL.md" "$l"; has "skills/effort-$l/SKILL.md" "name: effort-$l"; done
has "lib/effort-shift.md" 'Headless sessions'
has "lib/effort-shift.md" 'Skill(effort-max)'
has "lib/effort-shift.md" 'never inside a dispatched agent'
has "lib/model-gate.md" 'lib/effort-shift.md'

# ── 6) orchestrator wiring (spec D4)
for s in feat hotfix bugfix ship-feature init-project onboard tour code-clean seo geo harden web-validate audit-delta; do
  has "skills/$s/SKILL.md" 'lib/effort-shift.md'; has "skills/$s/SKILL.md" 'Skill(effort-medium)'; done
has "agents/client-handover-writer.md" 'lib/effort-shift.md'; has "agents/client-handover-writer.md" 'Skill(effort-medium)'
for s in feat hotfix bugfix; do has "skills/$s/SKILL.md" 'Skill(effort-high)'; done
for s in ship-feature init-project onboard code-clean audit-delta; do has "skills/$s/SKILL.md" 'Skill(effort-xhigh)'; done
for s in seo geo harden web-validate; do has "skills/$s/SKILL.md" 'Skill(effort-high)'; done
for s in feat hotfix bugfix ship-feature init-project; do has "skills/$s/SKILL.md" 'Skill(effort-low)'; done
has "skills/feat/SKILL.md" 'effort-shift: nested commit-change'

# ── summary (later tasks insert their locks ABOVE this line)
printf 'effort-routing census: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
