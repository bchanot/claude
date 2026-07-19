#!/usr/bin/env bash
# lib/tests/model-routing.test.sh — census: gate wiring + pins + executor shape (BDR-066, BDR-076)
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok() { pass=$((pass+1)); }
ko() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
has()   { if grep -qF "$2" "$R/$1"; then ok; else ko "$1 missing: $2"; fi; }
lacks() { if grep -qF "$2" "$R/$1"; then ko "$1 must NOT contain: $2"; else ok; fi; }
fm_lacks() { if awk 'NR<=10' "$R/$1" | grep -qF "$2"; then ko "$1 frontmatter must NOT contain: $2"; else ok; fi; }

# 1) gate wired in the 15 reflection skills (orchestrators + /analyze)
for s in ship-feature init-project feat bugfix onboard seo geo web-validate harden audit-delta tour code-clean hotfix client-handover analyze; do
  has "skills/$s/SKILL.md" 'lib/model-gate.md'
done
# 2) gate NOT wired in the pure-execution/read-only skills (exclusion list)
for s in commit-change doc status release-candidate refactor; do
  lacks "skills/$s/SKILL.md" 'lib/model-gate.md'
done
# 3) executor + gate pins
has "agents/feater.md"          'model: sonnet'
has "agents/hotfixer.md"        'model: sonnet'
has "agents/verifier.md"        'model: sonnet'
has "agents/security-auditor.md" 'model: sonnet'
has "agents/analyzer.md"        'model: opus'
# 4) /feat executor shape
has "skills/feat/SKILL.md" 'subagent_type="feater"'
has "skills/feat/SKILL.md" 'verify-secure-loop.md'
lacks "agents/feater.md" 'AskUserQuestion'
# 5) SDD execution pinned
has "skills/ship-feature/SKILL.md" 'model: "sonnet"'
has "skills/init-project/SKILL.md" 'model: "sonnet"'
# 6) web-validate applies via L1 applier
has "skills/web-validate/SKILL.md" 'subagent_type="hotfixer"'
# 7) wave-2 — pure-execution skills dispatch their agent (pin takes effect, off the big session model)
has "skills/doc/SKILL.md"               'subagent_type="doc-syncer"'
has "skills/status/SKILL.md"            'subagent_type="status-reporter"'
has "skills/commit-change/SKILL.md"     'subagent_type="commit-changer"'
has "skills/release-candidate/SKILL.md" 'subagent_type="release-executor"'
has "skills/hotfix/SKILL.md"            'subagent_type="hotfixer"'
has "agents/commit-changer.md"          'model: sonnet'
has "agents/release-executor.md"        'model: sonnet'
lacks "agents/commit-changer.md"        'AskUserQuestion'
# 8) wave-3 — bugfix/code-clean reflection-split executors (skills stay gated)
has "skills/bugfix/SKILL.md"     'subagent_type="bugfixer"'
has "agents/bugfixer.md"         'model: sonnet'
lacks "agents/bugfixer.md"       'AskUserQuestion'
has "skills/code-clean/SKILL.md" 'subagent_type="code-cleaner"'
has "agents/code-cleaner.md"     'model: sonnet'
lacks "agents/code-cleaner.md"   'AskUserQuestion'
# 9) wave-4 — client-handover: pipeline (big) inline + gated, doc-gen dispatched to sonnet
has "agents/handover-doc-writer.md"     'model: sonnet'
lacks "agents/handover-doc-writer.md"   'AskUserQuestion'
lacks "agents/handover-doc-writer.md"   'Agent('
has "agents/client-handover-writer.md"  'subagent_type="handover-doc-writer"'
# 10) post-merge edge fixes (ronde): F1 feater applier carve-out, F2 /refactor
#     dispatch + pin, F3 /analyze gated (in loop 1)
has "agents/feater.md"                       'Applier path'
has "skills/refactor/SKILL.md"               'subagent_type="refactorer"'
has "agents/refactorer.md"                   'model: sonnet'
# 11) BDR-076 — session model (Fable) = orchestration + inline reflection ONLY.
#     Dispatched judgment agents pinned OPUS (big tier, session-independent;
#     never sonnet — that would silently downgrade a live audit). Inline-load-
#     only agents (interviewer, client-handover-writer) STAY unpinned: they run
#     IN the main loop, a frontmatter pin there is inert and misleads.
has "agents/seo-analyzer.md"                 'model: opus'
has "agents/geo-analyzer.md"                 'model: opus'
has "agents/validator-analyzer.md"           'model: opus'
has "agents/plan-challenger.md"              'model: opus'
fm_lacks "agents/client-handover-writer.md"  'model:'
fm_lacks "agents/interviewer.md"             'model:'
has "skills/onboard/SKILL.md"                'model="opus"'
has "skills/tour/SKILL.md"                   'model="opus"'
has "lib/challenge-plan.md"                  'BDR-076'
# 12) BDR-077 W1 — no-inherit: skill-runner children pinned fable at every
#     call site; code-review dispatches carry opus; doctrine in model-gate.
#     (fable dispatch alias spike-verified 2026-07-19: resolves
#     claude-fable-5, enum-validated, loud failure — never silent fallback)
has "agents/client-handover-writer.md"       'model: "fable"'
has "skills/ship-feature/SKILL.md"           'model: "opus"'
has "skills/init-project/SKILL.md"           'model: "opus"'
has "lib/model-gate.md"                      'model: "fable"'
lacks "lib/model-gate.md"                    'model: "sonnet" in the Agent call'
# 13) BDR-077 W2 — plugin split: probe (sonnet, facts only) + advisor
#     reasoner (opus, PROBE REPORT is ground truth, fail-closed); gate
#     include owns checkpoint + apply; 4 consumers run the include, none
#     inline-loads the advisor anymore
has "agents/plugin-probe.md"                 'model: sonnet'
lacks "agents/plugin-probe.md"               'AskUserQuestion'
has "agents/plugin-advisor.md"               'model: opus'
has "agents/plugin-advisor.md"               'PROBE REPORT'
lacks "agents/plugin-advisor.md"             'PHASE 1 — DETECT'
has "lib/plugin-gate.md"                     'subagent_type="plugin-probe"'
has "lib/plugin-gate.md"                     'subagent_type="plugin-advisor"'
for s in plugin-check onboard init-project ship-feature; do
  has "skills/$s/SKILL.md" 'lib/plugin-gate.md'
  # shellcheck disable=SC2016 # literal $HOME wanted: matching the exact inline-load string
  lacks "skills/$s/SKILL.md" 'Load `$HOME/.claude/agents/plugin-advisor.md`'
done

printf 'model-routing census: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
