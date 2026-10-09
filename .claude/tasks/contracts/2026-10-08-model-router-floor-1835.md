# CONTRACT — model-router-floor (wave 1-B1: user effort floor for the turn)
- date: 2026-10-08 | flow: feat | branch: feature/model-router-mod
- status: active

## REQUEST (verbatim — IMMUTABLE)
AskUserQuestion 2026-10-08, question: "Aujourd'hui, `ultrathink` met le tour en max, mais si je déclare une phase (ex. orchestrate) puis charge un skill, ton max est perdu pour la suite du tour. Ça contredit notre règle « un choix explicite bat la phase déduite ». Quel sens donner à `ultrathink` et à un `/effort-x` tapé par toi ?"
User's answer: "Plancher pour le tour (Recommended)" — option text: "Ton niveau est un minimum pour tout le tour. Les routes du modèle et des skills peuvent monter au-dessus (escalade à max), jamais descendre en dessous. Il passe aussi par-dessus un /route sticky plus bas."
Session rule this fixes (wave plan, user-approved 2026-10-08): "an explicit per-call choice (Agent `model`/`effort` param, `/route`, `ultrathink`) beats the derived phase for that span".
User, same turn: "continu avec Opus en /ultrathink".

## CLARIFICATIONS
Q: which loops does the floor cover? / A: the MAIN loop only ("le tour" = the user's turn); sub-agents keep their own routes and pins. [orchestrator — derived, stated to the user]
Q: model axis / A: one rule: `userMain?.route.model ?? turnMain?.route.model ?? turnFloor?.route.model`, applied only with the switch on (r2). [orchestrator — internal]
Q (r2): default vs minimum / A: the user's level is the turn's default when no sticky or turn route names an effort AND its minimum; a typed `/effort-low` therefore still lowers an unrouted turn. Derived from the chosen option ("Ton niveau est un minimum pour tout le tour") plus the challenge finding that a pure floor would make `/effort-low` a no-op. [orchestrator — r2]
Q (r2): mid-turn prompt / A: applied to the running turn AND kept for the next (`wait` ignored, the engine queues either way). [orchestrator — r2]
Q (r2): per-machine off switch / A: `"enabled": false` in `~/.claude/model-router.json` (untracked); an `enabledPlugins` entry would dirty the tracked settings.json on every machine. [orchestrator — r2, from the user's "configurable"]
Q: numeric or absent engine effort / A: the floor level replaces it (the user's explicit level wins over an unknown budget); the haiku effort omission still applies after flooring. [orchestrator — internal]
Q: who clears the floor / A: main turn end (a queued prompt's floor is then promoted), `/route clear`, `/route off` (pass-through). A model `route({clear})`, a `Skill(effort-*)` or any skill load never touches it. [orchestrator — derived from "jamais descendre en dessous"]

## ACCEPTANCE CRITERIA
1. Suite green with the new tests: `claude plugin test` passes with at least 22 `test(` calls; `claude plugin validate` passes with no warning; no line over 80 chars; no `any` type.
   CHECK: cd mods/model-router && out=$(claude plugin test . 2>&1); rc=$?; echo "$out" | tail -n 3; [ $rc -eq 0 ] && [ "$(grep -cE '^\s*test\(' hooks/register.test.ts)" -ge 22 ] && v=$(claude plugin validate . 2>&1) && echo "$v" | grep -q 'Validation passed' && ! echo "$v" | grep -qi 'warning' && ! grep -nE '.{81,}' hooks/register.ts hooks/register.test.ts && ! grep -nE ':\s*any\b|<any>|as any\b' hooks/register.ts && echo FLOOR-SUITE-OK
   EXPECT: FLOOR-SUITE-OK
   EVIDENCE: pending
2. Type-check clean against this build's declarations.
   CHECK: T=/Users/b.chanot/.claude/dev-mods/385f7190-70f5-4bdd-b0d8-e4566cd412fd/model-router/.claude-plugin/types; [ -d "$T" ] || T=/Users/b.chanot/Documents/claude/mods/model-router/.claude-plugin/types; W=$(mktemp -d) && printf '{"compilerOptions":{"target":"es2023","lib":["es2023"],"types":[],"module":"esnext","moduleResolution":"bundler","strict":true,"noUncheckedIndexedAccess":true,"noEmit":true,"skipLibCheck":true,"jsx":"react","jsxFactory":"h","jsxFragmentFactory":"Fragment"},"include":["%s/claude-code/index.d.ts","%s/claude-code-tools/index.d.ts","%s/hooks"]}' "$T" "$T" "$PWD/mods/model-router" > "$W/tsconfig.json" && (cd "$W" && npx --yes -p typescript@5 tsc -p tsconfig.json) && echo TSC-OK
   EXPECT: TSC-OK
   EVIDENCE: pending
3. The floor is its own slot: `turnFloor` is declared in `State`, initialised in `newState`, written by the prompt rule and by a typed `/effort-<l>`, cleared by `/route clear` and at main turn end; the suite carries at least 8 tests whose name contains `floor`; one helper `mainEffort` decides the main effort; the config key `enabled` exists.
   CHECK: cd mods/model-router/hooks && [ "$(grep -c 'turnFloor' register.ts)" -ge 6 ] && [ "$(grep -cE "^\s*test\('[^']*floor" register.test.ts)" -ge 8 ] && grep -q 'mainEffort' register.ts && grep -q 'enabled' register.ts && echo FLOOR-SLOT-OK
   EXPECT: FLOOR-SLOT-OK
   EVIDENCE: pending
4. Judged by reading: effective main effort comes from ONE helper `mainEffort` used by `mainPlan` and by every answer text: base `(userMain ?? turnMain)?.route.effort ?? turnFloor?.route.effort ?? e.effort`, then floored by `turnFloor` (LEVELS order; a numeric or absent value is replaced); the floor never applies to a sub-agent step; `turnMain` only ever holds 'model' or 'skill' sources; the prompt rule writes `turnFloor` (keeping the higher of two) and, when typed mid-turn (`turnId` set, `wait` ignored), also `pendingPrompt`, promoted into `turnFloor` at main turn end; `"enabled": false` in the override file makes every hook pass through after each config load (`/route on` re-enables for the session); a non-effort skill load resets `turnMain` only; a model `route({clear})` clears `turnMain` only; every answer that the floor overrides says so truthfully (Skill bridge context, route tool text, `/effort-<l>` text); `/route show` and the status line display the floor; every criterion of `.claude/tasks/contracts/2026-10-08-model-router-w1a-1533.md` still holds; no function over 25 logic lines.

## FILE SCOPE
mods/model-router/hooks/register.ts · mods/model-router/hooks/register.test.ts
