# Effort shift — phase-level reasoning effort on the main loop (BDR-NEXT)

Shared include, companion of `lib/model-gate.md`: the gate fixes WHICH model
reflects, this include fixes HOW HARD each phase thinks. The rungs are the
user's: low (fix a line, run a script) · medium (day-to-day) · high
(refactor, resisting bug) · xhigh (architecture, audit before validation) ·
max (stuck error, judged need).

## Mechanics (verified on Claude Code 2.1.283)

- **Pairing rule**: a `Skill(effort-<level>)` call applies its effort only
  when the same assistant message carries at least one other tool call
  after it; a lone Skill call is a no-op. Send the shift together with the
  step's first tool call, shift first. That paired call already runs at the
  new level: pair a downward shift with a pinned-agent dispatch or a
  Read/Bash, never with a built-in judgment dispatch (`general-purpose`,
  `model: "opus"`), which would inherit it.
- Re-loading a shifter already loaded in the conversation re-applies its
  effort (the harness only dedupes the skill text), so bounce-back
  sequences such as medium → max → medium work.
- A skill's `effort:` frontmatter applies from the moment it loads to the
  end of the turn: on the user's `/skill` and on a `Skill(...)` call by
  Claude in an interactive session. Last loaded wins, both directions. The
  prompt cache survives a shift.
- Dispatched agents run on their own `effort:` pin, never on a shift.
  Unpinned agents inherit the level in force at dispatch.
- Headless sessions (`-p`, `claude agents`, SDK) ignore skill-level effort:
  the run stays at the session level. `CLAUDE_CODE_EFFORT_LEVEL` beats every
  frontmatter; keep it unset (the session banner warns).

Measure the split any time: `python3 ~/.claude/lib/effort-audit.py`
(thinking/output/cache tokens per scope, model and effort).

## Shifters

`Skill(effort-low)` · `Skill(effort-medium)` · `Skill(effort-high)` ·
`Skill(effort-xhigh)` · `Skill(effort-max)`. One tool call, one-line body,
always sent with another tool call (Pairing rule).
Typed by the user, `/effort-max` is a turn-scoped max: the relaunch lever
after a STOP. `ultrathink` only adds an in-context nudge; the API level
does not move.

## Wiring — per orchestrator

1. A dispatch span starts (executor, collector, fan-out) →
   `Skill(effort-medium)`.
2. Reflection resumes after a dispatch span (challenge synthesis, verdict,
   plan revision) → `Skill(effort-<the skill's own level>)`. Concretely:
   the line before every `lib/challenge-plan.md` call.
3. The bookkeeping tail (memory commit, doc commit) → `Skill(effort-low)`.
4. Escalation → `Skill(effort-max)`, then the skill's own level again once
   the diagnosis is produced. Automatic points: verify-secure loop caps
   (GATE 0 floor, GATE 1 conformity, GATE 2 security) and ship-feature
   STEP 4b. Not automatic, by doctrine: the challenge fail-safe (a mute
   challenger is an infrastructure failure) and "gone WRONG → STOP" (STOP
   precedes any further reasoning); their STOP text names the level
   reached and suggests `/effort-max` for the relaunch.

## Re-assert

- After any nested `Skill(...)` whose frontmatter carries a different
  effort (feat → commit-change), reload the orchestrator's own level.
- After a prose gate that ends the turn, the resumed turn runs at the
  session level. If the resumed phase is reflection, its first step is
  `Skill(effort-<own level>)`; dispatch and orchestration phases need
  nothing.

## Never

- A shift never inside a dispatched agent: pins rule there.
- Max is for diagnosis, not for retrying the same fix harder.
