#!/usr/bin/env bash
# lib/tests/effort-routing.test.sh — wave-2 census of the model-router rows.
# Drift lock: every tracked skill/agent row of mods/model-router/routing.json
# equals its frontmatter (the off-state floor), except a row the user changed
# through the first-use dialog (WARN floor drift: the floor may lag a
# confirmed decision); the D3 wiring markers sit in the orchestrators, no
# shifter citer survives.
# shellcheck disable=SC2015,SC2016  # A && ok || ko is deliberate (ok/ko never fail)
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
MOD="$R/mods/model-router"
RJ="$MOD/routing.json"
REG="$MOD/hooks/register.ts"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
lacks() { if grep -qF "$2" "$R/$1"; then ko "$1 must NOT contain: $2"; else ok; fi; }
# frontmatter = the lines between the first two '---' lines
fm() { awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' "$1"; }
fm_val() { fm "$1" | grep -E "^$2: [a-z]+$" | head -1 | cut -d' ' -f2; }

# ── routing.json (rows, phases, decisions) and the tier heads ────────────
# dump <routing.json> -> "skills|agents <name> <phase>", "phases <p> <tier>
# <effort>", "changed <kind> <name> <from> <to>" lines
dump() {
  python3 -I - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for kind in ("skills", "agents"):
    for k, v in d.get(kind, {}).items():
        print(kind, k, v)
for k, v in d.get("phases", {}).items():
    print("phases", k, v.get("tier", ""), v.get("effort", ""))
for kind in ("skills", "agents"):
    for k, v in d.get("changed", {}).get(kind, {}).items():
        print("changed", kind, k, v["from"], v["to"])
PY
}
# lookups on a dump text: row_of D kind name · phase_effort D phase ·
# changed_of D kind name -> "from to"
row_of()       { printf '%s\n' "$1" | awk -v k="$2" -v n="$3" '$1==k&&$2==n{print $3}'; }
phase_effort() { printf '%s\n' "$1" | awk -v p="$2" '$1=="phases"&&$2==p{print $3, $4}'; }
changed_of()   { printf '%s\n' "$1" | awk -v k="$2" -v n="$3" '$1=="changed"&&$2==k&&$3==n{print $4, $5}'; }
# tier_head <file> <tier> -> first alias of the tier list
tier_head() {
  awk '/^  tiers: \{/{f=1;next} f&&/^  \},?$/{f=0} f' "$1" \
    | sed -nE "s/^ *$2: \['([a-z]+)'.*$/\1/p"
}
# the fallback copy of the phases inside the mod's code: "<tier> <effort>"
code_phase() {
  awk '/^  phases: \{/{f=1;next} f&&/^  \},?$/{f=0} f' "$REG" \
    | sed -nE "s/^ *$1: \{ tier: '([a-z]+)', effort: '([a-z]+)' \},?$/\1 \2/p"
}
# tier_floor <file> <tier> -> the model: floor of a tier's agents
# a best-tier row floors on its 2nd alias: inTier keeps the frontmatter when the head is down (Fable credits, BLK-030); a fable floor would spawn the gates on a dead model
tier_floor() {
  if [ "$2" != best ]; then tier_head "$1" "$2"; return; fi
  awk '/^  tiers: \{/{f=1;next} f&&/^  \},?$/{f=0} f' "$1" \
    | sed -nE "s/^ *best: \['[a-z]+', '([a-z]+)'.*$/\1/p"
}
# field_of <dump> <phase> <effort|model> -> that phase's frontmatter value
field_of() {
  local pe tier
  pe="$(phase_effort "$1" "$2")"
  if [ "$3" = effort ]; then printf '%s\n' "${pe#* }"; return; fi
  tier="${pe% *}"; tier_floor "$REG" "$tier"
}
# verdict <dump> <kind> <name> <effort|model> <got> <phase>: ok when the
# frontmatter equals the row's phase; warn when the row was changed through
# the dialog (changed.from is the shipped phase, changed.to the row) and the
# frontmatter still holds the shipped value; fail otherwise (a Keep alone,
# an empty or unknown value, a hand edit after a change)
verdict() {
  local D="$1" kind="$2" name="$3" field="$4" got="$5" phase="$6" ch from fromval
  [ -n "$got" ] || { echo fail; return; }
  [ "$got" = "$(field_of "$D" "$phase" "$field")" ] && { echo ok; return; }
  ch="$(changed_of "$D" "$kind" "$name")"; from="${ch% *}"
  [ -n "$ch" ] && [ "${ch#* }" = "$phase" ] || { echo fail; return; }
  fromval="$(field_of "$D" "$from" "$field")"
  [ -n "$fromval" ] && [ "$got" = "$fromval" ] && echo warn || echo fail
}
# floor_check <dump> <kind> <name> <effort|model> <got> <phase> <label>
floor_check() {
  case "$(verdict "$1" "$2" "$3" "$4" "$5" "$6")" in
    ok) ok;;
    warn) printf 'WARN floor drift: %s %s vs row %s (%s)\n' "$7" "$5" "$6" "$4"; ok;;
    *) ko "$7: $4 '$5' != row $6 ($(field_of "$1" "$6" "$4"))";;
  esac
}
RD="$(dump "$RJ")"

# ── flip-test: the readers parse a fixture and reject the wrong verdicts ──
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
cat > "$FIX/reg.ts" <<'FX'
  tiers: {
    best: ['fable', 'opus', 'sonnet'],
    big: ['opus', 'fable'],
  },
FX
cat > "$FIX/routing.json" <<'FX'
{
  "phases": {
    "judge": { "tier": "big", "effort": "xhigh" },
    "reflect": { "tier": "best", "effort": "high" },
    "implement": { "tier": "work", "effort": "medium" }
  },
  "skills": { "feat": "implement", "doc": "reflect" },
  "agents": { "Plan": "judge" },
  "changed": { "skills": { "feat": { "from": "reflect", "to": "implement" } } },
  "ask": true
}
FX
FD="$(dump "$FIX/routing.json")"
[ "$(row_of "$FD" agents Plan)" = judge ] && ok || ko "flip: agents row misread"
[ "$(row_of "$FD" skills feat)" = implement ] && ok || ko "flip: skills row misread"
[ -z "$(row_of "$FD" skills ghost)" ] && ok || ko "flip: ghost row"
[ "$(phase_effort "$FD" judge)" = "big xhigh" ] && ok || ko "flip: phase"
[ -z "$(phase_effort "$FD" nothere)" ] && ok || ko "flip: ghost phase"
[ "$(tier_head "$FIX/reg.ts" big)" = "opus" ] && ok || ko "flip: tier head"
[ "$(tier_floor "$FIX/reg.ts" best)" = opus ] && ok || ko "flip: best floors on its 2nd alias"
[ "$(tier_floor "$FIX/reg.ts" big)" = opus ] && ok || ko "flip: big floors on its head"
[ "$(changed_of "$FD" skills feat)" = "reflect implement" ] && ok || ko "flip: changed entry"
[ -z "$(changed_of "$FD" skills doc)" ] && ok || ko "flip: ghost changed entry"
# the drift verdicts (high = reflect's effort, medium = implement's)
[ "$(verdict "$FD" skills doc effort high reflect)" = ok ] && ok || ko "flip: equal must pass"
[ "$(verdict "$FD" skills doc effort medium reflect)" = fail ] && ok || ko "flip: a Keep-only drift must FAIL"
[ "$(verdict "$FD" skills feat effort high implement)" = warn ] && ok || ko "flip: changed.from drift must WARN"
[ "$(verdict "$FD" skills feat effort '' implement)" = fail ] && ok || ko "flip: an empty value must FAIL"
[ "$(verdict "$FD" skills feat effort banana implement)" = fail ] && ok || ko "flip: an unknown value must FAIL"
[ "$(verdict "$FD" skills feat effort low implement)" = fail ] && ok || ko "flip: a drift off the shipped value must FAIL"
[ "$(verdict "$FD" skills feat effort high reflect)" = ok ] && ok || ko "flip: row back to its shipped phase passes"
[ "$(verdict "$FD" skills feat effort high judge)" = fail ] && ok || ko "flip: a hand edit after a change must FAIL"
[ "$(echo "$RD" | grep -c '^skills ')" -gt 40 ] && ok || ko "routing.json: skills rows not read"
[ "$(echo "$RD" | grep -c '^agents ')" -gt 15 ] && ok || ko "routing.json: agents rows not read"

# ── the code's fallback phases equal routing.json's (never a stale route) ─
n_code="$(awk '/^  phases: \{/{f=1;next} f&&/^  \},?$/{f=0} f' "$REG" | grep -c "tier:")"
n_json="$(echo "$RD" | grep -c '^phases ')"
[ "$n_code" -eq "$n_json" ] && ok || ko "phases: $n_code in code vs $n_json in routing.json"
while read -r _ p tier effort; do
  [ "$(code_phase "$p")" = "$tier $effort" ] && ok \
    || ko "phase $p: code '$(code_phase "$p")' != routing.json '$tier $effort'"
done < <(echo "$RD" | grep '^phases ')

# ── (b) tracked skills: row exists, frontmatter effort equals the row ────
NO_ROW_SKILLS=" find-docs graphify impeccable model-router "
check_skill() {
  local f="$1" name phase
  name="$(basename "$(dirname "$f")")"
  case "$NO_ROW_SKILLS" in *" $name "*) return;; esac
  phase="$(row_of "$RD" skills "$name")"
  [ -n "$phase" ] || { ko "skills/$name: no row in routing.json"; return; }
  [ -n "$(fm_val "$R/$f" effort)" ] || { ko "skills/$name: routed skill without effort:"; return; }
  floor_check "$RD" skills "$name" effort "$(fm_val "$R/$f" effort)" "$phase" "skills/$name"
}
while IFS= read -r f; do check_skill "$f"; done < <(
  cd "$R" && git ls-files 'skills/*/SKILL.md' 'skills-external/*/SKILL.md')

# ── (c) tracked agents with a row: tier floor == model:, effort == effort: ─
NO_ROW_AGENTS=" interviewer client-handover-writer "
check_agent() {
  local f="$1" name phase
  name="$(basename "$f" .md)"
  case "$NO_ROW_AGENTS" in *" $name "*) return;; esac
  case "$name" in impeccable-*) return;; esac
  phase="$(row_of "$RD" agents "$name")"
  [ -n "$phase" ] || { ko "agents/$name: no row in routing.json"; return; }
  floor_check "$RD" agents "$name" model "$(fm_val "$R/$f" model)" "$phase" "agents/$name"
  floor_check "$RD" agents "$name" effort "$(fm_val "$R/$f" effort)" "$phase" "agents/$name"
}
while IFS= read -r f; do check_agent "$f"; done < <(
  cd "$R" && git ls-files 'agents/*.md' | grep -E '^agents/[^/]+\.md$' \
    | grep -v '/README\.md$')

# ── (d) no shifter citer in skills, agents, lib ──────────────────────────
if (cd "$R" && git grep -qE 'Skill\(effort-|EFFORT SHIFT[S]:' -- skills agents lib ':!lib/tests'); then
  ko "a shifter-skill or shift-header citer survives in skills/agents/lib"
else ok; fi
# paths split so this file itself matches no deleted-name grep
for s in skills/effort-low skills/effort-max lib/effort-""pins.txt lib/model-""check.sh; do
  [ ! -e "$R/$s" ] && ok || ko "$s must be deleted"
done

# ── (e) D3 wiring markers ────────────────────────────────────────────────
mark() { # mark <phase> <skills...>
  local ph="$1" s; shift
  for s in "$@"; do has "skills/$s/SKILL.md" "route(phase=\"$ph\")"; done
}
mark orchestrate feat hotfix bugfix ship-feature init-project code-clean seo geo harden web-validate audit-delta
mark apply feat hotfix bugfix ship-feature init-project
mark reflect feat hotfix bugfix seo geo harden web-validate
mark plan ship-feature init-project onboard code-clean audit-delta
mark escalate ship-feature
[ "$(grep -o 'route(phase="escalate")' "$R/lib/verify-secure-loop.md" | wc -l)" -eq 3 ] \
  && ok || ko "verify-secure-loop.md: escalate route must appear 3 times"
for s in ship-feature init-project; do has "skills/$s/SKILL.md" 'effort="xhigh"'; done
has "skills/tour/SKILL.md" 'effort="xhigh"'
n_opus="$(grep -c 'model="opus",$' "$R/skills/onboard/SKILL.md")"
n_eff="$(grep -c 'effort="xhigh",$' "$R/skills/onboard/SKILL.md")"
[ "$n_opus" -ge 7 ] && [ "$n_opus" -eq "$n_eff" ] && ok \
  || ko "onboard: $n_opus model=\"opus\" dispatches vs $n_eff effort=\"xhigh\""
bad="$(grep 'model: "fable"' "$R/agents/client-handover-writer.md" | grep -vc 'effort="high"')"
[ "$bad" -eq 0 ] && ok || ko "client-handover-writer: $bad model: \"fable\" line(s) without effort=\"high\""
for s in ship-feature init-project feat bugfix web-validate seo hotfix geo harden code-clean audit-delta tour onboard; do
  has "skills/$s/SKILL.md" 'ROUTING: follow $HOME/.claude/lib/effort-shift.md'
done
has "agents/client-handover-writer.md" 'ROUTING: follow $HOME/.claude/lib/effort-shift.md'

# ── (f) doctrine includes ────────────────────────────────────────────────
has "lib/model-gate.md" 'mcp__model-router__route'
has "lib/effort-shift.md" 'ToolSearch'
has "rules/web-building.md" 'route to `reflect` (high) through their'

# ── (g) session default and hooks (unchanged locks) ──────────────────────
has "settings.json" '"effortLevel": "high"'
has "hooks/session-start.sh" 'CLAUDE_CODE_EFFORT_LEVEL'
has "hooks/statusline.sh" 'CLAUDE_EFFORT'

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
