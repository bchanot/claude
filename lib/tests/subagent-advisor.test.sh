#!/usr/bin/env bash
# lib/tests/subagent-advisor.test.sh — the SubagentStart advisor line and
# the carriers of the sub-agent advisor rule (BDR-150). Locks are single
# lines (LRN-093).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
H="$ROOT/hooks/subagent-advisor.sh"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1));
  printf 'FAIL %s: got[%s] want[%s]\n' "$1" "$2" "$3"; fi; }
has() { grep -qF -- "$2" "$ROOT/$1" 2>/dev/null && echo yes || echo no; }
ctx() { printf '%s' "$1" | bash "$H" 2>/dev/null | jq -r \
  'select(.hookSpecificOutput.hookEventName == "SubagentStart")
   | .hookSpecificOutput.additionalContext' 2>/dev/null; }
in_ctx() { case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac; }

# hook: one valid object, same line whatever the payload
for p in '{"agent_type":"general-purpose"}' '' 'not json' \
  "{\"agent_type\":\"x\\\"y\\n\$(id)\"}"; do
  c=$(ctx "$p")
  check "T1 names the tool [$p]" "$(in_ctx "$c" "\`advisor\` tool")" yes
  check "T2 defers to brief [$p]" \
    "$(in_ctx "$c" 'own instructions are never an allowance')" yes
done
printf '{}' | bash "$H" >/dev/null 2>&1; check T3-exit-0 "$?" 0
check T2c-prohibits "$(in_ctx "$(ctx '{}')" \
  "do not call the \`advisor\` tool in this run unless")" yes
check T4-one-line "$(printf '{}' | bash "$H" | wc -l | tr -d ' ')" 1
check T5-no-cli "$(grep -v '^ *#' "$H" \
  | grep -cE '(^|[[:space:];&|(])claude([[:space:]]|$)')" 0
check T5b-no-echo "$(printf 'PAYLOADMARK' | bash "$H" | grep -c PAYLOADMARK)" 0

# wiring
S="$ROOT/settings.json"
check T6-wired "$(jq -r '.hooks.SubagentStart[0].hooks[0].command' "$S")" \
  "bash ~/.claude/hooks/subagent-advisor.sh"
check T7-timeout "$(jq -r '.hooks.SubagentStart[0].hooks[0].timeout' "$S")" 5

# carriers
for a in plugin-advisor seo-analyzer geo-analyzer doc-syncer \
  commit-changer handover-doc-writer; do
  check "T8 $a" "$(has "agents/$a.md" \
    "never call the \`advisor\` tool, even though")" yes
done
check T9-onboard-briefs \
  "$(grep -cF "Never call the \`advisor\` tool in this run" \
  "$ROOT/skills/onboard/SKILL.md")" 6
check T10-handover-children "$(has agents/client-handover-writer.md \
  "never call the \`advisor\` tool in")" yes
for a in plan-challenger verifier security-auditor analyzer; do
  check "T20 $a allowance" "$(has "agents/$a.md" \
    'Advisor, when dispatched as a sub-agent: exactly one call when')" yes
done
check T10b-handover-top-clean "$(sed -n '1,30p' \
  "$ROOT/agents/client-handover-writer.md" | grep -c "advisor\` tool")" 0
check T11-tour-phase-b \
  "$(has skills/tour/SKILL.md "saying never call the \`advisor\` tool")" yes
for s in ship-feature init-project; do
  check "T12 $s" "$(has "skills/$s/SKILL.md" \
    "Add to its brief: \"make exactly one \`advisor\` call when the tool is")" yes
done
check T13-sdd-pin "$(has CLAUDE.global.md \
  'subagent-driven-development standalone: workers sonnet')" yes
check T14-global-set "$(has CLAUDE.global.md \
  'and an opus code review exactly')" yes
check T15-effort-hook "$(has lib/effort-shift.md \
  'hooks/subagent-advisor.sh. A skill run by a sub-agent reads')" yes
check T16-effort-sdd "$(has lib/effort-shift.md \
  'subagent-driven-development, whoever runs it')" yes
check T17-row-reason "$(has lib/challenge-plan.md \
  'already called this run | sub-agent)')" yes
check T19-advisor-first-skip "$(has lib/challenge-plan.md \
  'A skill run inside a sub-agent skips this call')" yes
check T18-no-old-row "$(cd "$ROOT" && git grep -c 'already called this run)' \
  -- skills lib ':!lib/tests' | wc -l | tr -d ' ')" 0

# exactly one call and its effect line (user decision 2026-11-26)
check T21-hook-exactly "$(in_ctx "$(ctx '{}')" \
  'When allowed: exactly one call, before your verdict or report.')" yes
for a in plan-challenger verifier security-auditor analyzer; do
  check "T22 $a effect line" "$(has "agents/$a.md" \
    'ADVISOR: changed: <what> | no change | not called (absent | error)')" yes
  check "T22b $a no retry" "$(has "agents/$a.md" \
    'erroring → proceed, no retry.')" yes
done
check T22c-effect-grammar "$(has lib/effort-shift.md \
  "grammar: \`changed: <what>\` | \`no change\` | \`not called (<reason>)\`.")" yes
check T23-sec-report-clean "$(has agents/security-auditor.md \
  "this same block without its \`ADVISOR:\` line")" yes
check T23c-report-written-last "$(has agents/security-auditor.md \
  "\`REPORT_WRITTEN: <path>\`, after the \`ADVISOR:\` line.")" yes
check T23b-error-none "$(has agents/plan-challenger.md \
  "verdict carries no \`ADVISOR:\` line.")" yes
old_re='at most once, before|at most once per dispatch|one call allowed'
old_re="$old_re|tool once, before|may call once|allowing one"
joined() { tr '\n' ' ' < "$ROOT/$1" | tr -s ' '; }
check T24-control \
  "$(printf 'x at most once, before y' | grep -cE "$old_re")" 1
for f in CLAUDE.global.md lib/effort-shift.md agents/plan-challenger.md \
  agents/verifier.md agents/security-auditor.md agents/analyzer.md \
  skills/ship-feature/SKILL.md skills/init-project/SKILL.md; do
  check "T24 $f" "$(joined "$f" | grep -cE "$old_re")" 0
done
check T24-hook "$(ctx '{}' | grep -cE "$old_re")" 0

echo "subagent-advisor: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
