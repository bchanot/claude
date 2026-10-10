#!/usr/bin/env bash
# lib/tests/effort-routing.test.sh — wave-2 census of the model-router rows.
# Drift lock: every tracked skill/agent row in mods/model-router/hooks/
# register.ts equals its frontmatter (the off-state floor), the D3 wiring
# markers sit in the orchestrators, no shifter citer survives.
# shellcheck disable=SC2015,SC2016  # A && ok || ko is deliberate (ok/ko never fail)
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
REG="$R/mods/model-router/hooks/register.ts"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
lacks() { if grep -qF "$2" "$R/$1"; then ko "$1 must NOT contain: $2"; else ok; fi; }
# frontmatter = the lines between the first two '---' lines
fm() { awk 'NR==1&&/^---$/{p=1;next} p&&/^---$/{exit} p' "$1"; }
fm_val() { fm "$1" | grep -E "^$2: [a-z]+$" | head -1 | cut -d' ' -f2; }

# ── register.ts parsers (awk/sed on the DEFAULT_CONFIG literal) ──────────
# rows <file> <agents|skills> -> "name phase" per row
rows() {
  awk -v s="$2" '$0 ~ "^  "s": \\{"{f=1;next} f&&/^  \},?$/{f=0} f' "$1" \
    | grep -v '^ *//' | grep -oE "('[^']+'|[A-Za-z0-9_-]+): '[a-z]+'" \
    | sed -E "s/'//g; s/: / /"
}
# phase_effort <file> <phase> -> "<tier> <effort>"
phase_effort() {
  awk '/^  phases: \{/{f=1;next} f&&/^  \},?$/{f=0} f' "$1" \
    | sed -nE "s/^ *$2: \{ tier: '([a-z]+)', effort: '([a-z]+)' \},?$/\1 \2/p"
}
# tier_head <file> <tier> -> first alias of the tier list
tier_head() {
  awk '/^  tiers: \{/{f=1;next} f&&/^  \},?$/{f=0} f' "$1" \
    | sed -nE "s/^ *$2: \['([a-z]+)'.*$/\1/p"
}
row_of() { rows "$REG" "$1" | awk -v n="$2" '$1==n{print $2}'; }

# ── flip-test: the parsers read a fixture, reject a missing key ──────────
FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
cat > "$FIX/reg.ts" <<'FX'
  tiers: {
    big: ['opus', 'fable'],
  },
  phases: {
    judge: { tier: 'big', effort: 'xhigh' },
  },
  agents: {
    // judge
    Plan: 'judge', 'plan-challenger': 'judge',
  },
  skills: {
    'ship-feature': 'plan', doc: 'apply',
  },
FX
[ "$(rows "$FIX/reg.ts" agents | tr '\n' ,)" = "Plan judge,plan-challenger judge," ] \
  && ok || ko "flip: agents rows misparsed"
[ "$(rows "$FIX/reg.ts" skills | tr '\n' ,)" = "ship-feature plan,doc apply," ] \
  && ok || ko "flip: skills rows misparsed"
[ "$(phase_effort "$FIX/reg.ts" judge)" = "big xhigh" ] && ok || ko "flip: phase"
[ -z "$(phase_effort "$FIX/reg.ts" nothere)" ] && ok || ko "flip: ghost phase"
[ "$(tier_head "$FIX/reg.ts" big)" = "opus" ] && ok || ko "flip: tier head"
[ "$(rows "$REG" skills | wc -l)" -gt 40 ] && ok || ko "register.ts: skills rows not parsed"
[ "$(rows "$REG" agents | wc -l)" -gt 15 ] && ok || ko "register.ts: agents rows not parsed"

# ── (b) tracked skills: row exists, frontmatter effort equals the row ────
NO_ROW_SKILLS=" find-docs graphify impeccable model-router "
check_skill() {
  local f="$1" name phase want got
  name="$(basename "$(dirname "$f")")"
  case "$NO_ROW_SKILLS" in *" $name "*) return;; esac
  phase="$(row_of skills "$name")"
  [ -n "$phase" ] || { ko "skills/$name: no row in register.ts"; return; }
  want="$(phase_effort "$REG" "$phase" | cut -d' ' -f2)"
  got="$(fm_val "$R/$f" effort)"
  [ -n "$got" ] || { ko "skills/$name: routed skill without effort:"; return; }
  [ "$got" = "$want" ] && ok || ko "skills/$name: effort $got != row $phase ($want)"
}
while IFS= read -r f; do check_skill "$f"; done < <(
  cd "$R" && git ls-files 'skills/*/SKILL.md' 'skills-external/*/SKILL.md')

# ── (c) tracked agents with a row: tier head == model:, effort == effort: ─
NO_ROW_AGENTS=" interviewer client-handover-writer "
tier_alias() { tier_head "$REG" "$(phase_effort "$REG" "$1" | cut -d' ' -f1)"; }
check_agent() {
  local f="$1" name phase alias want got
  name="$(basename "$f" .md)"
  case "$NO_ROW_AGENTS" in *" $name "*) return;; esac
  case "$name" in impeccable-*) return;; esac
  phase="$(row_of agents "$name")"
  [ -n "$phase" ] || { ko "agents/$name: no row in register.ts"; return; }
  alias="$(tier_alias "$phase")"; got="$(fm_val "$R/$f" model)"
  [ "$got" = "$alias" ] && ok || ko "agents/$name: model $got != row $phase ($alias)"
  [ "$alias" = haiku ] && return
  want="$(phase_effort "$REG" "$phase" | cut -d' ' -f2)"
  got="$(fm_val "$R/$f" effort)"
  [ "$got" = "$want" ] && ok || ko "agents/$name: effort $got != row $phase ($want)"
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
has "CLAUDE.global.md" 'route to `reflect` (high) through their'

# ── (g) session default and hooks (unchanged locks) ──────────────────────
has "settings.json" '"effortLevel": "high"'
has "hooks/session-start.sh" 'CLAUDE_CODE_EFFORT_LEVEL'
has "hooks/statusline.sh" 'CLAUDE_EFFORT'

printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
