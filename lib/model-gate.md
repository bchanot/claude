# Model gate — reflection requires a big model (BLOCKING)

Shared include. Runs FIRST in any orchestrator whose reflection —
brainstorming, planning, contract, audit judgment, loop decisions —
executes inline or in inherit-model subagents. Sonnet-pinned executors are
not what this gate protects; it protects the thinking around them (BDR-066).

## 1. Self-check

Your system prompt names the model powering this session. Fable or Opus →
big. Sonnet, Haiku, anything else → small.

## 2. Witness — deterministic check

    bash "$HOME/.claude/lib/model-check.sh"

Output `<class>:<raw>`; exit 0 = big, 2 = small, 3 = unknown. The witness
reads the PERSISTED model (settings.json — the file `/model` rewrites,
LRN-098). It can lag reality (session launched with `--model`, settings not
yet rewritten) — that is why the self-check exists alongside it.

## 3. Verdict

| self-check | witness | action |
|---|---|---|
| big | big (0) | proceed, SILENT — the nominal path prints nothing |
| small | any | **STOP** |
| big | small (2) | disagreement — **STOP**, surface BOTH values; the user confirms or relaunches |
| big | unknown (3) | fail-visible: print `model gate: witness unknown (<raw>) — self-check says <model>` and ask the user to confirm before continuing (BDR-025: unknown never silently passes) |

**STOP means**: print exactly

    ⛔ MODEL GATE — session on <model>. Reflection steps of this skill
    require Fable or Opus. Switch with /model, then relaunch the skill.

then end the turn. No later step runs, no agent is dispatched, nothing is
edited.
