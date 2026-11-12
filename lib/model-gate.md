# Model gate — reflection requires a big model (BLOCKING)

Shared include, runs FIRST in an orchestrator whose reflection executes
inline (BDR-066). The witness is the model-router mod's own route tool.

## Entry call
ALWAYS call `mcp__model-router__route` with `phase` = the skill's row phase
(reflect or plan), no self-check shortcut. Tool not loaded (deferred) →
`ToolSearch("select:mcp__model-router__route")` once per session, then
call. The answer names the id main runs on next.

| answer | action |
|---|---|
| names a fable or opus id | proceed, SILENT |
| names sonnet, haiku, anything else; "is off"; tool absent | **STOP** |

**STOP means**: print exactly `⛔ MODEL GATE — session on <model>.
Reflection steps of this skill require Fable or Opus. Switch with /model,
then relaunch the skill.` (mod off: say so, `/route on` resumes it), then
end
the turn. No later step runs, no agent is dispatched, nothing is edited.

## Dispatch tiers (BDR-077 — no inherit)
The gate guards the MAIN loop only. Typed agents are routed by their
model-router row (`model:` frontmatter = off-state floor). Built-ins
(general-purpose / Explore / Plan) carry an explicit `model=` at every call
site: `model: "fable"` when the child reflects/orchestrates for the main
loop (skill-runners), else its tier (opus = dispatched judgment, sonnet =
execution, haiku = mechanical probes). A built-in judgment dispatch also
carries an explicit `effort=` (`lib/effort-shift.md`).
