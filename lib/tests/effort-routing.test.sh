#!/usr/bin/env bash
# lib/tests/effort-routing.test.sh — census: effort tiering (BDR-107)
# agent pins, skill entry levels, shifter skills, orchestrator wiring, settings.
# shellcheck disable=SC2015,SC2016  # A && ok || ko is deliberate (ok/ko never fail); '$REPO' locks are literal source text
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
# BDR-108 round: the three repo skills that had no level
fm_has_effort "skills/skills-perso/SKILL.md" low
fm_has_effort "skills/pdf-translate/SKILL.md" medium
fm_has_effort "skills/site-motion/SKILL.md" high

# ── 9) vendored externals carry the level of lib/effort-pins.txt (BDR-108). The files live in
#      skills-external/ (gitignored, machine-owned): the durable artifact is the map + the re-apply
#      after the last vendoring step of install-plugins.sh AND update-all.sh; a skill not vendored
#      yet SKIPs visibly (fresh clone before make plugin).
while read -r s lvl _; do
  case "$s" in ''|'#'*) continue ;; esac
  if [ -f "$R/skills-external/$s/SKILL.md" ]; then fm_has_effort "skills-external/$s/SKILL.md" "$lvl"
  else printf 'SKIP skills-external/%s/SKILL.md not vendored yet (run make plugin)\n' "$s"; fi
done < "$R/lib/effort-pins.txt"
has "lib/effort-pins.txt" 'brainstorming xhigh'; has "lib/effort-pins.txt" 'writing-plans xhigh'
has "install-plugins.sh" 'apply_effort_pins "$REPO"'; has "update-all.sh" 'apply_effort_pins "$REPO"'
lacks "install-plugins.sh" 'for _s in brainstorming writing-plans; do'
ln_last() { grep -n "$2" "$R/$1" | tail -1 | cut -d: -f1; }
[ "$(ln_last install-plugins.sh 'apply_effort_pins "$REPO"')" -gt "$(ln_last install-plugins.sh 'rm -rf "$TFD_STAGE"')" ] \
  && ok || ko "install-plugins.sh: effort pins must be re-applied after the 21st pack refresh"
pins_ln=$(ln_last update-all.sh 'apply_effort_pins "$REPO"')
[ "$pins_ln" -gt "$(ln_last update-all.sh 'skills-external/$_tfd_name')" ] \
  && [ "$pins_ln" -gt "$(ln_last update-all.sh 'vendor_pinned_skills superpowers refresh')" ] \
  && ok || ko "update-all.sh: effort pins must be re-applied after the last vendoring step (21st pack)"
[ -x "$R/lib/effort-pins.sh" ] && ok || ko "lib/effort-pins.sh missing or not executable"
# 9b) design stack = ONE level (last loaded wins); site-motion (repo skill) pins the same one
stack_levels() { awk '/^# design stack/{f=1;next} f&&/^#$/{f=0} f&&!/^#/&&NF==2{print $2}' "$R/lib/effort-pins.txt" | sort -u; }
[ "$(stack_levels | wc -l)" -eq 1 ] && ok || ko "design stack must share ONE level in lib/effort-pins.txt (got: $(stack_levels | tr '\n' ' '))"
[ "$(stack_levels | wc -l)" -ge 1 ] && fm_has_effort "skills/site-motion/SKILL.md" "$(stack_levels | head -1)"
has "lib/effort-shift.md" 'Stacked skills share one level'
has "CLAUDE.global.md" 'lib/effort-pins.txt'

# ── 5) shifter skills + include (spec D4)
for l in low medium high xhigh max; do fm_has_effort "skills/effort-$l/SKILL.md" "$l"; has "skills/effort-$l/SKILL.md" "name: effort-$l"; done
has "lib/effort-shift.md" 'Headless sessions'
has "lib/effort-shift.md" 'Skill(effort-max)'
has "lib/effort-shift.md" 'never inside a dispatched agent'
has "lib/model-gate.md" 'lib/effort-shift.md'

# ── 6) orchestrator wiring (spec D4)
for s in feat hotfix bugfix ship-feature init-project onboard tour code-clean seo geo harden web-validate audit-delta; do
  has "skills/$s/SKILL.md" 'lib/effort-shift.md'; has "skills/$s/SKILL.md" 'a lone Skill call is a no-op'; done
for s in feat hotfix bugfix ship-feature init-project code-clean seo geo harden web-validate audit-delta; do
  has "skills/$s/SKILL.md" 'Skill(effort-medium)'; done
lacks "skills/onboard/SKILL.md" 'Skill(effort-medium)'; lacks "skills/tour/SKILL.md" 'Skill(effort-medium)'
has "agents/client-handover-writer.md" 'lib/effort-shift.md'; lacks "agents/client-handover-writer.md" 'Skill(effort-medium)'; has "agents/client-handover-writer.md" 'Skill(effort-high)'
for s in feat hotfix bugfix; do has "skills/$s/SKILL.md" 'Skill(effort-high)'; done
for s in ship-feature init-project onboard code-clean audit-delta; do has "skills/$s/SKILL.md" 'Skill(effort-xhigh)'; done
for s in seo geo harden web-validate; do has "skills/$s/SKILL.md" 'Skill(effort-high)'; done
for s in feat hotfix bugfix ship-feature init-project; do has "skills/$s/SKILL.md" 'Skill(effort-low)'; done
has "skills/feat/SKILL.md" 'effort-shift: nested commit-change'

# ── 6b) pairing rule documented (R11)
has "lib/effort-shift.md" 'lone Skill call is a no-op'
has "lib/effort-shift.md" 're-applies its'
[ "$(grep -c 'a lone Skill call is a no-op' "$R/skills/feat/SKILL.md")" -ge 1 ] && ok || ko "feat INC line must carry the pairing rule"

# ── 7) escalation at max (spec D4)
[ "$(grep -c 'Skill(effort-max)' "$R/lib/verify-secure-loop.md")" -eq 3 ] && ok || ko "verify-secure-loop.md must shift to max at its 3 caps"
has "skills/ship-feature/SKILL.md" 'Skill(effort-max)'
has "lib/challenge-plan.md" '/effort-max'
has "lib/verify-secure-loop.md" '/effort-max'

# ── 8) turn-reset re-assert after a prose gate followed by reflection
has "skills/bugfix/SKILL.md" 'effort-shift: turn reset'

# ── 11) audit tooling
has "lib/effort-shift.md" 'effort-audit.py'
[ -x "$R/lib/effort-audit.py" ] && ok || ko "lib/effort-audit.py missing or not executable"

# ── 6c) judgment dispatches re-raised, planning re-asserts, stronger locks (final review I1/I2/M5)
for s in ship-feature init-project; do has "skills/$s/SKILL.md" 'effort-shift: judgment dispatch'; has "skills/$s/SKILL.md" 'effort-shift: turn reset'; done
has "agents/client-handover-writer.md" 'effort-shift: judgment dispatch'
has "lib/effort-shift.md" 'Before any built-in or unpinned dispatch'
has "lib/model-gate.md" 'built-ins inherit the effort in force'
has "skills/ship-feature/SKILL.md" 'effort-shift: error recovery'
for s in feat hotfix bugfix seo geo harden web-validate ship-feature init-project onboard code-clean audit-delta; do has "skills/$s/SKILL.md" 'effort-shift: own level before the challenge'; done
has "update-all.sh" 'source "$REPO/lib/effort-pins.sh"'

# ── summary (later tasks insert their locks ABOVE this line)
printf 'effort-routing census: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
