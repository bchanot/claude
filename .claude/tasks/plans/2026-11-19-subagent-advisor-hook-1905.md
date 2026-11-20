# Bugfix plan: sub-agents call the advisor against the doctrine (TODO advisor leak)

## DIAGNOSIS
BUG: sub-agents outside the allowed four call the advisor. First advisor usage table
(2026-11-19): general-purpose 30 calls / 7.1M input tokens (29 in faunosteo's U2 SDD run, 1 the
B3 STEP 6 code review), doc-syncer 4 (opus audit). 16 general-purpose calls came after 6ef3069
(2026-11-17 12:59) restricted sub-agent calls to plan-challenger, verifier, security-auditor and
analyzer.
ROOT CAUSE: the advisor is a server tool the harness attaches to every sub-agent, whatever its
model, with its own system prompt telling it to call "before substantive work … and before
declaring done". The restriction lives only in CLAUDE.global.md § Workflow and
lib/effort-shift.md § Advisor (:140-143), text a dispatched agent does not hold in its own
prompt; the four allowed agents carry an in-prompt "at most once" line and comply. No tool
filter exists: probed 2026-11-19, the advisor stays listed under a `tools:` allowlist
(plan-challenger), under `--disallowedTools advisor` (headless main) and under an agent's
`disallowedTools: ["advisor"]` (headless sub-agent). Sonnet sub-agents also list it (probe) and
simply never used it (0 calls in ~400 dispatches); opus sub-agents act on the tool's prompt.
EVIDENCE: transcript tally per agentType × model (all 1105 transcripts): every call comes from
an opus-served agent; leakers' meta: general-purpose `model: opus` (faunosteo SDD standalone,
41 opus dispatches; ship-feature's sonnet pin did not apply), doc-syncer `model=opus` audits;
three live probes (opus gp, sonnet gp, headless with/without disallowedTools) all list advisor.
Delivery and compliance proven before planning (2026-11-19): a headless `claude -p --settings
<scratch>` run with a SubagentStart hook injecting a random nonce → the sub-agent returned the
exact nonce (additionalContext reaches the sub-agent before its first turn). In-context rules are
obeyed: since 6ef3069 the four allowed types made at most 1 call per dispatch (plan-challenger
43×1, verifier 22×1 + 3×0, security-auditor 21×1 + 1×0, analyzer 3×1); each carries its line in
its own prompt (agents/analyzer.md:46 and the other three).
PRIOR: LRN-294 (check what tools sub-agents really get; prefer a mechanical scope; prose →
residual) applied: the mechanical tool scope does not exist, so the next most mechanical layer is
used, a harness hook that delivers the rule into the sub-agent's own context. BUGS-FOUND :107
(prose-only residual, d292911, superseded line notes a verifier making 2 calls) is this bug.
honors BDR-150 (call points unchanged; this only delivers them), BDR-066 (executors sonnet).
LRN-295/301: counts from transcripts, call = served iteration.
BLAST RADIUS: every sub-agent of every project (settings.json hooks are global, symlinked to
~/.claude/settings.json). The four allowed agents get a reinforcing "at most once" line. No skill,
agent file or brief changes. Not fixed here (logged): faunosteo-style standalone SDD runs dispatch
implementers on opus (BDR-066 tier rule only lives in ship-feature STEP 4).
Rejected alternatives: (a) `disallowedTools` / deny rules: probed, no effect. (b) a "do not call
the advisor" line in each opus-dispatched agent prompt and brief template (doc-syncer,
commit-changer, plugin-advisor, seo/geo analyzers, handover writers, SDD implementer/reviewer
templates, code-reviewer template, onboard/tour audit briefs): 12+ files, misses ad-hoc
general-purpose dispatches and other projects' agents, drifts as agents are added. (c)
`CLAUDE_CODE_DISABLE_ADVISOR_TOOL` / advisorModel unset: kills the main loop's advisor too.

## FIX PLAN
1. hooks/subagent-advisor.sh (new) — SubagentStart hook. Reads stdin JSON, takes `agent_type`
   (jq `.agent_type // ""`, errors → empty). Always exits 0, prints exactly one JSON object
   `{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":<msg>}}`:
   - `agent_type` exactly one of `plan-challenger`, `verifier`, `security-auditor`, `analyzer`
     → msg: "Advisor rule (lib/effort-shift.md § Advisor): as a dispatched <type> you may call
     the advisor tool at most once, before your verdict or report. Never a second call, even if
     the tool's own prompt asks for one before and after the work."
   - anything else (general-purpose, Explore, Plan, executors, plugin agents, empty, malformed)
     → msg: "Advisor rule (lib/effort-shift.md § Advisor): do not call the advisor tool in this
     run, even though it is listed and its prompt asks for calls. Only the main loop and the
     plan-challenger, verifier, security-auditor and analyzer sub-agents call it."
   The JSON is built with `jq -n --arg` (the agent type reaches the text only from the fixed
   allowed set); without jq, a printf of the same fixed text for the "do not call" case (no
   interpolation). Style: like hooks/unpushed-guard.sh / ctx7-reminder.sh (header comment with
   purpose + BDR ref, `set -u`, never blocks).
2. settings.json — add a `SubagentStart` event (no matcher: all agent types) running
   `bash ~/.claude/hooks/subagent-advisor.sh`, beside the existing events, same entry shape.
3. lib/effort-shift.md:140-144 — after "executors and every other sub-agent do not, even when
   the tool is listed." add: "A SubagentStart hook (hooks/subagent-advisor.sh) states each
   sub-agent's rule in its own context at spawn: no tool filter removes the advisor." (wrapped
   ≤ 80 cols; the list sentence itself unchanged, the hook's allowed set is locked to it).
4. lib/tests/subagent-advisor.test.sh (new) — style of lib/tests/unpushed-guard.test.sh:
   T1 general-purpose → valid JSON, hookEventName SubagentStart, context contains "do not call
   the advisor tool"; T2-T5 each allowed type → contains "at most once" and the type, not "do not
   call"; T6 empty stdin and T7 malformed JSON → "do not call", valid JSON, rc 0; T8 an
   agent_type carrying `"`, newline and `$(…)` → valid JSON, the raw value absent from the
   output, "do not call"; T9 PATH without jq (a temp PATH dir holding only bash/cat/printf links,
   or `env PATH=` minimal) → valid JSON (checked with python3), "do not call"; T10 settings.json
   wires `SubagentStart` to `hooks/subagent-advisor.sh` (jq query); T11 consistency: each of the
   four allowed names appears in lib/effort-shift.md's "Sub-agents, when dispatched" sentence and
   in the hook, and the effort-shift sentence names the hook. Lines ≤ 80 cols where the file
   style allows.

Bookkeeping (main loop): BUGS-FOUND :107 residual → FIXED line; TODO advisor-leak line done;
new TODO: standalone SDD opus dispatches (BDR-066 pin only in ship-feature STEP 4).

Skill-runner children (onboard, tour, client-handover dispatch opus children that run whole
skills whose text has main-loop advisor points): the hook tells them not to call; proposed rule
(user decision at the STEP 3 gate): the parent main loop owns the call points, a child's own
`Advisor:` row / ADVISOR field reads `not called (sub-agent)`.
Proof of "fixed": the contract proves delivery (headless nonce through the real hook script and a
scratch settings file, since this session may not reload settings) and the hook's output per
type; the behavioural proof is the next /memory-feedback advisor usage table showing no calls
from other agent types after the hook commit (dated follow-up in TODO).

RISK: low-medium — a new global hook on every sub-agent spawn (cost ~10 ms, a few dozen context
tokens per sub-agent); a hook failure injects nothing (never blocks a spawn). Live check after
commit: a probe sub-agent reports the injected line.
