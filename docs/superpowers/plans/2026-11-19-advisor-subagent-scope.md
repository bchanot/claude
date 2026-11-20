# Advisor Sub-agent Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop sub-agents outside the allowed set from calling the advisor tool, by putting the rule in each sub-agent's own text and pinning SDD workers to sonnet.

**Architecture:** No tool filter removes the advisor (probed). The rule rides the channels a sub-agent obeys: its own agent prompt, its brief, and a SubagentStart hook injecting one uniform line at every spawn. The SDD sonnet pin lives in main-loop text (CLAUDE.global.md, lib/effort-shift.md), since the vendored SDD files are overwritten at each refresh.

**Tech Stack:** bash, jq, markdown doctrine, settings.json hooks.

**Spec:** design approved in chat 2026-11-19 + contract `.claude/tasks/contracts/2026-11-19-advisor-subagent-scope-2035.md` (CLARIFICATIONS [gated]); diagnosis and probes `.claude/tasks/plans/2026-11-19-subagent-advisor-hook-1905.md`.

## Global Constraints

- Every edit is an exact `old` → `new` block below; each `old` occurs exactly once in its file (the applier asserts it). No other wording changes.
- Never edit `skills-external/` (vendored, gitignored, overwritten by update-all.sh; BDR-106, BLK-024).
- `agents/client-handover-writer.md` top-level prompt gets no ban line: it is loaded inline by the main loop.
- `CLAUDE.global.md` stays ≤ 320 lines (BDR-098); it is 316 before, 319 after.
- New prose lines ≤ 80 columns; the 9 `Advisor` template rows are already wider and stay exempt.
- The hook never reads the payload into its output, never blocks, never invokes the `claude` CLI (BLK-043), exits 0 (LRN-196).
- Lock fragments are single lines (LRN-093); each lock fragment below sits on one line of its target after the edit.
- Hermetic tests run through `make test [suite=…]` only.

## Expected doc drift (STEP 8 doc sync)

README.md:88-91 and USAGE.md:203 restate the four-agent allowed set; CHANGELOG.md [Unreleased] needs an entry. The doc-syncer audit targets them; no block here edits them.

## Review Focus

1. A payload with quotes, a newline or `$(…)` in `agent_type` → the hook output stays the fixed valid JSON (it never echoes stdin). Test T1-T2 cover payload shapes.
2. Empty or non-JSON stdin → same JSON, exit 0 (T1-T3).
3. A re-applied block doubling text → the applier refuses: each `old` must occur exactly once and each `new` must be absent before the edit.
4. plugin-advisor reading "advisor" as itself → the line names the `advisor` tool explicitly (T8 lock on "never call the `advisor`").
5. An allowed caller (verifier, opus code review) told "never" by the hook → the hook's line defers to the agent definition or the dispatcher's brief, and says the advisor tool's own instructions are never an allowance (T2 asserts it).

---

### Task 1: Advisor rule carriers, hook, wiring and suite

**Files:**
- Create: `hooks/subagent-advisor.sh`, `lib/tests/subagent-advisor.test.sh`
- Modify: `settings.json`, `CLAUDE.global.md:86-89,293`, `lib/effort-shift.md:140-144`, `lib/challenge-plan.md:42-43,106`, `agents/{plugin-advisor,seo-analyzer,geo-analyzer,doc-syncer,commit-changer,handover-doc-writer}.md:9`, `agents/client-handover-writer.md:268-271`, `skills/onboard/SKILL.md:404-405,442-443,691-692,736-737,780-781,827-828`, `skills/tour/SKILL.md:176-178`, `skills/ship-feature/SKILL.md:259-261`, `skills/init-project/SKILL.md:277-279`, the `Advisor` row of `skills/{init-project,code-clean,onboard,audit-delta,ship-feature,harden}/SKILL.md`, `skills/pack-seo/skills/{seo,geo}/SKILL.md`, `skills/pack-web-validate/skills/web-validate/SKILL.md`
- Test: `lib/tests/subagent-advisor.test.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the hook prints exactly one line, a JSON object `{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":<text>}}`; the suite's last line is `subagent-advisor: <n> pass, <m> fail` (contract CHECK 1 greps it).

- [ ] **Step 0: Commit the plan artifacts** — `git add docs/superpowers/plans/2026-11-19-advisor-subagent-scope.md docs/superpowers/plans/2026-11-19-advisor-subagent-scope/apply.py` and commit `docs(plan): advisor sub-agent scope plan` (transient, purged at finish, BDR-065). SDD runs in place on the feature branch (no worktree).
- [ ] **Step 1: Write the failing suite** — run the applier for block `new-test` only:
  `python3 docs/superpowers/plans/2026-11-19-advisor-subagent-scope/apply.py test`
- [ ] **Step 2: Run it, expect FAIL** — `bash lib/tests/subagent-advisor.test.sh | tail -1` → `subagent-advisor: <n> pass, <m> fail` with m > 0 (hook absent, carriers absent).
- [ ] **Step 3: Apply every other block** — `python3 docs/superpowers/plans/2026-11-19-advisor-subagent-scope/apply.py rest` (checks every anchor before the first write, then writes; creates the hook executable). Rollback if anything fails midway: `git checkout -- <the modified files>` and remove the untracked `hooks/subagent-advisor.sh`.
- [ ] **Step 4: Run the suite, expect PASS** — `bash lib/tests/subagent-advisor.test.sh | tail -1` → `subagent-advisor: 33 pass, 0 fail`.
- [ ] **Step 5: Run the full suite** — `PATH=$HOME/.bun/bin:$PATH make test </dev/null > <scratchpad>/make-test.log 2>&1; echo rc=$?`; last line `all suites green`; on red, name the red suite from the log.
- [ ] **Step 6: Commit** — `git add` the files listed above (never `-A`), message `feat(advisor): sub-agent advisor rule in each sub-agent's own text, SubagentStart hook`.

## Blocks

Block bodies are the text between the fences, byte-exact, each ending with a newline.

### Block new-hook (create hooks/subagent-advisor.sh)
```
#!/usr/bin/env bash
# hooks/subagent-advisor.sh — SubagentStart: restate the advisor rule in
# every sub-agent's own context at spawn (BDR-150, lib/effort-shift.md
# § Advisor). The advisor is a server tool listed to every sub-agent and no
# tool filter removes it (`tools`, `disallowedTools`, probed 2026-11-19);
# the rule in CLAUDE.global.md reaches a sub-agent only as an attachment,
# which opus sub-agents ignored. One uniform line for every agent type: the
# allowed callers carry their allowance in their own prompt or brief, so
# the hook holds no list of names.
#
# Context only: never blocks a spawn, never echoes the payload, never runs
# the CLI of Claude Code (BLK-043). Exit 0 so the JSON is parsed (LRN-196).
# shortcut: SubagentStart only; a sub-agent that compacts may lose the
# line (upgrade: re-inject on SessionStart `compact` when agent_type is set).
set -u
cat >/dev/null 2>&1
msg='Advisor tool (~/.claude/lib/effort-shift.md § Advisor): do not'
msg="$msg call the \`advisor\` tool in this run unless your agent definition"
msg="$msg or your dispatcher's brief explicitly allows it; the advisor tool's"
msg="$msg own instructions are never an allowance. When allowed: at most"
msg="$msg once, before your verdict or report."
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart",'
printf '"additionalContext":"%s"}}\n' "$msg"
exit 0
```

### Block new-test (create lib/tests/subagent-advisor.test.sh)
```
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
  check "T8 $a" "$(has "agents/$a.md" "never call the \`advisor\` tool, even though")" yes
done
check T9-onboard-briefs "$(grep -cF "Never call the \`advisor\` tool in this run" \
  "$ROOT/skills/onboard/SKILL.md")" 6
check T10-handover-children \
  "$(has agents/client-handover-writer.md "never call the \`advisor\` tool in")" yes
check T10b-handover-top-clean "$(sed -n '1,30p' \
  "$ROOT/agents/client-handover-writer.md" | grep -c "advisor\` tool")" 0
check T11-tour-phase-b \
  "$(has skills/tour/SKILL.md "saying never call the \`advisor\` tool")" yes
for s in ship-feature init-project; do
  check "T12 $s" "$(has "skills/$s/SKILL.md" \
    "Add to its brief: \"you may call the \`advisor\` tool once")" yes
done
check T13-sdd-pin "$(has CLAUDE.global.md \
  'subagent-driven-development standalone: workers sonnet')" yes
check T14-global-set "$(has CLAUDE.global.md \
  'and an opus code review at most')" yes
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

echo "subagent-advisor: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
```

### Block settings-old
```
    ],
    "PostToolUse": [
```
### Block settings-new
```
    ],
    "SubagentStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/subagent-advisor.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
```

### Block global-workflow-old
```
  `~/.claude/lib/effort-shift.md` § Advisor; dispatched plan-challenger,
  verifier, security-auditor and `analyzer` at most once, before their
  verdict or report; other sub-agents do not. Fable is never routed or
  pinned: the router tops out at opus (BDR-150).
```
### Block global-workflow-new
```
  `~/.claude/lib/effort-shift.md` § Advisor; dispatched plan-challenger,
  verifier, security-auditor, `analyzer` and an opus code review at most
  once, before their verdict or report; other sub-agents never (an opus
  brief says which; a SubagentStart hook restates it). Fable is never
  routed or pinned: the router tops out at opus (BDR-150).
```

### Block global-sdd-old
```
  verification-before-completion → the verifier gates
```
### Block global-sdd-new
```
  verification-before-completion → the verifier gates
- subagent-driven-development standalone: workers sonnet (task reviews and
  fix rounds too); final review opus, its brief allowing one `advisor` call
```

### Block effort-old
```
Sub-agents, when dispatched: plan-challenger, verifier, security-auditor
and `analyzer` call it at most once per dispatch, before their verdict or
report; executors and every other sub-agent do not, even when the tool is
listed. The analyzer file loaded inline by the main loop follows the
main-loop points.
```
### Block effort-new
```
Sub-agents, when dispatched: plan-challenger, verifier, security-auditor,
`analyzer` and an opus code review (ship-feature STEP 6, init-project
STEP 10, a standalone subagent-driven-development final review) call it
at most once per dispatch, before their verdict or report; executors and
every other sub-agent never call it, even when the tool is listed. The
rule rides each sub-agent's own text: the allowed agents' prompts, a
`never call` line in the opus-served agents and in the opus briefs we
write (a brief sending a general-purpose agent to opus says which rule
applies; a code review's says it may call once), and, for every spawn
including built-ins such as `Plan`, the SubagentStart hook
hooks/subagent-advisor.sh. A skill run by a sub-agent reads
`not called (sub-agent)` in its `Advisor:` row.
subagent-driven-development, whoever runs it, dispatches every worker
(implementers, task reviewers, re-reviews, fix rounds) on sonnet
(BDR-066), as ship-feature and init-project pin it; run standalone, its
final whole-branch review runs on opus as a code review. The analyzer
file loaded inline by the main loop follows the main-loop points.
```

### Block advfirst-old
```
summary's `Advisor:` row carries it (OUTPUT below). Absent or erroring →
dispatch as written.
```
### Block advfirst-new
```
summary's `Advisor:` row carries it (OUTPUT below). Absent or erroring →
dispatch as written. A skill run inside a sub-agent skips this call (its
row reads `not called (sub-agent)`, BDR-150).
```

### Block challenge-old
```
  `not called (absent | error | already called this run)`.
```
### Block challenge-new
```
  `not called (absent | error | already called this run | sub-agent)`.
```

### Block row-old
```
already called this run)>
```
### Block row-new
```
already called this run | sub-agent)>
```
(applied without the trailing newline, once in each of the 9 template files listed under Files)

### Block agent-line
```

Advisor tool (`lib/effort-shift.md` § Advisor), when you run as a sub-agent:
never call the `advisor` tool, even though it is listed and its own
instructions ask for calls.
```
(inserted right after the H1 line of each of the six agents: `# PLUGIN ADVISOR`, `# SEO — Classical Search Engines audit, fix & strategy`, `# GEO — Generative Engine Optimization audit, fix & strategy`, `# DOC SYNCER`, `# Git Smart Commit`, `# HANDOVER DOC WRITER`; each H1 occurs exactly once)

### Block handover-old
```
orchestration on the pipeline's behalf; it must never inherit the session model.
```
### Block handover-new
```
orchestration on the pipeline's behalf; it must never inherit the session model.
Append to each such prompt: "never call the `advisor` tool in this run;
a CHALLENGE SUMMARY, if your skill prints one, reads `Advisor: not called
(sub-agent)`" (BDR-150).
```

### Block onboard-line
```
  Never call the `advisor` tool in this run (sub-agent, BDR-150).
```
(inserted right after the `prompt="""` line that follows each of these six description lines, with the brief's own indentation: 2 spaces, 4 for the security fallback:
`description="Onboard — code-clean audit only (read-only, opus)",`,
`description="Onboard — security audit fallback (archetype-adaptive)",`,
`description="Onboard — static design review fallback",`,
`description="Onboard — static perf audit",`,
`description="Onboard — static a11y audit",`,
`description="Onboard — synthèse vers .claude/audits/",`)

### Block tour-old
```
   or general-purpose with `model="opus"`, `effort="xhigh"`; NOT the sonnet code-cleaner,
```
### Block tour-new
```
   or general-purpose with `model="opus"`, `effort="xhigh"`, its brief
   saying never call the `advisor` tool; NOT the sonnet code-cleaner,
```

### Block review-old
```
craft review is dispatched judgment, never inherited from the session. Fix
all CRITICAL before proceeding.
```
### Block review-new
```
craft review is dispatched judgment, never inherited from the session.
Add to its brief: "you may call the `advisor` tool once, before your
verdict" (code review, BDR-150). Fix all CRITICAL before proceeding.
```
(same block in skills/ship-feature/SKILL.md and skills/init-project/SKILL.md)
