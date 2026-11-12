# PLAN — model-router mod (feature/model-router-mod)

User ask 2026-10-08: one Claude Code mod that routes every request to the
model and effort its task deserves, main loop and sub-agents alike, declared
or automatic, configurable, loaded in every session (user scope). Replaces
the five `effort-*` shifter skills, the `effort:` / `model:` frontmatter
pins, `lib/effort-pins.txt` + `.sh` and `lib/model-gate.md` once proven.

Decisions taken 2026-10-08 (user, AskUserQuestion):
- Main-loop MODEL switch: spike first, then behind a userConfig flag, off by
  default, applied only on explicit declaration. Main-loop EFFORT always routed.
- Loading: `CLAUDE_CODE_PLUGIN_DIRS` in settings.json `env`, mod lives in the
  repo under `mods/model-router/`, symlinked by link.sh. No marketplace.
- Migration: wave 2, after wave 1 is proven. Mod = single source of truth.
- Names: mod `model-router`, tool `route` (model sees `mcp__model-router__route`),
  command `/route`, config `~/.claude/model-router.json`.

## Routing rule (user, 2026-10-08): pin = entry default, sub-tasks route finer
The existing pins and `effort-*` shifters were built for this same goal with
the tools of their time; the mod replaces them (or nearly). A pin is not to
be contested one by one, but some were forced: a skill pinned to one level
does many different things inside one run. So:
- the entry pin of a skill or agent (today frontmatter / effort-pins.txt,
  tomorrow the config table) = the DEFAULT route of the run, never a ceiling
  or a floor;
- inside the run every sub-task routes to its own phase: declared by the
  skill through the `route` tool (replaces `Skill(effort-*)` + pairing rule),
  or derived by the mod (Agent dispatch → orchestrate, Skill load → its
  entry phase, Read/Grep result → comprehension level, bookkeeping tail →
  mechanical);
- an explicit per-call choice (Agent `model`/`effort` param, `/route`,
  `ultrathink`) beats the derived phase for that span;
- wave 1 keeps the frontmatter pins as the entry defaults (the mod reads the
  same values), wave 2 moves them into the config table and deletes the
  frontmatter + shifters. Skills get their intra-run `route` calls in wave 2
  (the 15 `Skill(effort-*)` citers first).

## Spike facts so far (2026-10-08)
- (a) main-loop effort rewrite at `turn.step` reaches the API: transcript
  records flip `effort: high` → `medium` after a `route` call. `CLAUDE_EFFORT`
  is NOT an oracle (turn-level setting); the transcript `effort` field is.
- (c) sub-agent steps are visible by `agentId`; an explicit Agent `model`
  param resolves fine (sonnet → claude-sonnet-5-5, haiku → claude-haiku-4-5-20251001;
  haiku steps carry `effort: undefined`, no effort on that model).
- ROOT CAUSE of the 404 (T1-T3, 2026-10-08): a model set by a hook as an
  ALIAS is resolved by a stale table (`sonnet` -> `claude-sonnet-5`, 404);
  the Agent tool's own enum resolves the same alias to `claude-sonnet-5-5`.
  T1 param rewrite + alias: 404. T2 spawn rewrite + alias: 404. T3b spawn
  rewrite + full id `claude-sonnet-5-5`: OK, every step answered by
  claude-sonnet-5-5 at effort medium (turn.step by agentId also OK).
  Rule for the mod: ALWAYS write full model ids from its own alias -> id
  table in the config (one place to bump when a tier ships). The Agent tool
  schema accepts only aliases, so full ids can only come from the hooks.
  To report upstream: hook-side alias resolution lags the tool's.
- T4 main-loop model switch (fable -> claude-sonnet-5-5/low, switch on): WORKS.
  Steps 11 and 12 answered by claude-sonnet-5-5 at effort low, transcript
  records agree, thinking still produced (4.6 s), conversation intact (897
  messages, tools and results carried across). COST: the first step after a
  switch read 0 cached tokens on a ~260k context (cache is per model), the
  next step read 237k. Switching BACK to fable at step 14 read 263k cached
  tokens: the fable cache survived three sonnet steps (per-model caches,
  1 h TTL), so the return is free. Every switch INTO another model pays one
  cold-cache step on the full context. Consequence for the design: main-loop
  model switches only for spans long enough to amortize (many mechanical
  steps), never per tool call; short mechanical work goes to a haiku
  sub-agent whose context is small. Flag stays off by default.
- Open: T3a (param rewrite + full id), fable/opus ids for the table,
  switching back mid-turn, behavior with thinking blocks from another model
  in history (no error seen), headless `-p` run.

## Harness facts (types 2.1.292, CLI 2.1.294)
- `turn.step` (async generator) rewrites `model` and `effort` per request;
  `e.agentId` set inside a sub-agent loop. Pinned: turn, index, messageCount.
- `agent.spawn` rewrites `model` (not effort); result carries `agentId`.
- `tool.call {tool:'Agent'}` sees and rewrites the call's `model` / `effort`
  params; `tool.call {tool:'Skill'}` names the skill loading.
- `$.tool.register` / `$.command.register` (`immediate: true` runs mid-turn).
- `$.model.classify(text, labels)`, `$.session.usage().rateLimits`.
- Hooks run under `claude -p` too (closes the BDR-107 headless gap).
- Hook budget 10 s own code; `$` calls do not count.
- Honest limit: a hook cannot know what the NEXT request will decide to do.
  Routing = declared phase (skill table, `route` tool, `/route`, prompt
  rules) + conservative after-the-fact heuristics on the following step.

## Phase table (proposal, config-driven)
| phase | model | effort | when |
|---|---|---|---|
| plan | session | xhigh | brainstorm, plan, architecture, challenge synthesis, audit verdict |
| reflect | session | high | diagnosis, reading to understand, contract, review |
| orchestrate | session | medium | between dispatches, reading a report |
| escalate | session | max | `ultrathink`, stuck loop, STOP relaunch |
| judge | opus | xhigh | dispatched challengers, analyzers, audits (BDR-076) |
| implement | sonnet | medium | code from a closed plan (feater, bugfixer, …) |
| write | sonnet | medium | docs, prose from decided content |
| verify | sonnet | xhigh | verifier, security-auditor |
| mechanical | haiku | low | cp/mv, git bookkeeping, status collection, listing |

## Decisions 2026-10-08 (evening, user via AskUserQuestion)
- LOADING (supersedes "CLAUDE_CODE_PLUGIN_DIRS via settings.json + link.sh"):
  PLUGIN_DIRS needs absolute paths, settings `env` has no `$HOME`
  expansion, settings.json is tracked and shared across machines; a local
  marketplace `add` writes an absolute path into settings.json too. Chosen:
  tracked relative symlink `skills/<name>` → `../mods/<name>`; Claude Code
  loads it as `<name>@skills-dir`, in place (docs plugins/loading; probe in
  an isolated HOME: listed, enabled, loaded). Repo scripts walking skills/
  glob `*/SKILL.md` or fixed names: unaffected. User asked why not
  `~/.claude/mods`: Claude Code scans no such folder, a link there loads
  nothing.
- PRECEDENCE: `ultrathink` (prompt rule) and a typed `/effort-<l>` become a
  FLOOR for the main turn: derived routes may go above, never below; it
  lifts a lower sticky `/route`. Main loop only.
- settings.json: the user's uncommitted `/model` change (model → opus) is
  theirs to manage; never staged.
- Live 2026-10-08: Skill(effort-low) bridge answered in place, next request
  `low`; `ultrathink` turn on Opus ran at `max` (engine base `medium`);
  Explore without params spawned on `claude-sonnet-5-5`, all 3 steps
  `medium` (no spawn/step race observed).

## Decisions 2026-10-09 (user, after the wave-1 table was shown)
- No "session model" phase: every phase names an ABSOLUTE tier (best = fable,
  opus, sonnet · big = opus, fable, sonnet · work = sonnet, opus · cheap = haiku,
  sonnet); a haiku session asked to plan runs on fable. Reflection and planning
  always on the best available model.
- Availability = circuit breaker (turn error/refusal, engine auto switch), not
  quota reading (rateLimits are account windows). Fallback fable → opus →
  sonnet → haiku, effort unchanged ("plus de crédit fable → opus xhigh").
- The user never types /route: prompt default rules, dispatch push/pop
  (orchestrate while agents run, previous route restored), skills table
  (wave 2), optional classifier. Main upgrade allowed by default, downgrade
  still gated (cold-cache cost).
- Sequence agreed: 1-C lands → user /reload-plugins → live test → commit →
  wave 2.

## Wave 0 — spike (dev-mods folder, hot reload, this session)
- [x] W0.1 minimal mod: `/route` command, `route` tool, `turn.step` logging +
      rewrite, `agent.spawn` rewrite, `ultrathink` → max, spinner suffix
- [x] W0.2 `claude plugin validate` clean; type-check with the header tsconfig
- [x] W0.3 facts to establish, each with its evidence (usage.model, CLAUDE_EFFORT,
      debug log): (a) effort rewrite on main loop takes effect; (b) model rewrite
      on main loop mid-turn: works / breaks (thinking signatures, cache, tools);
      (c) sub-agent model via spawn + effort via step by agentId; (d) `/route`
      immediate mid-turn; (e) load via `CLAUDE_CODE_PLUGIN_DIRS` from settings env → moved to W1.10
- [x] W0.4 record facts → journal + BDR draft; freeze wave 1 scope (facts in this file; registries pending user go)

## Wave 1 — core (repo `mods/model-router/`)
- [ ] W1.1 config loader: `~/.claude/model-router.json` (phases, agents,
      skills, prompt rules, defaults); schema check; `/route reload`
- [ ] W1.2 state: per-loop phase (main + agentId map), reset at `turn.start`
      to the prompt-derived phase; explicit > table > heuristic
- [ ] W1.3 `route` tool + `/route [phase|show|reload|clear]` (immediate)
- [ ] W1.4 agents: `tool.call Agent` param rewrite + `agent.spawn` model +
      `turn.step` effort by agentId; covers built-ins (Explore, Plan, general-purpose)
- [ ] W1.5 skills: `tool.call Skill` → phase from the skills table; any
      skill load RESETS the main route to that skill's entry phase (table,
      else the frontmatter `effort:` the harness just applied), so no route
      declared earlier in the turn survives a skill change silently
- [ ] W1.5b single-writer bridge for the legacy shifters (user, 2026-10-08:
      doublon + silent one-way conflict): `tool.call {tool:'Skill', skill:
      /^effort-/}` answers WITHOUT `next` (skill text never loaded, no pairing
      rule) and translates the level into a route on the calling loop;
      `skill.prompt {skill:/^effort-/}` does the same for a user-typed
      `/effort-max` and returns a one-line text. The 15 citers keep working
      untouched until wave 2 rewrites them to `route`. Rule: every effort
      change goes through the mod's state; frontmatter values are inputs.
- [ ] W1.6 prompt rules: `ultrathink` → escalate; keyword → phase (effort up
      only; never a main-loop model change without declaration)
- [ ] W1.7 visibility: Spinner suffix `· <model>/<effort>`, `$.ui.status`,
      `$.ui.log` when verbose, `/route show`
- [ ] W1.8 userConfig: `mainLoopModelSwitch` (false), `verbose` (false),
      `classifier` (false)
- [ ] W1.9 tests `*.test.ts` under `claude plugin test`; `claude plugin validate`
- [ ] W1.10 install: `mods/` symlink + `CLAUDE_CODE_PLUGIN_DIRS` in settings.json
      env via link.sh; doctor line; README/USAGE/CHANGELOG
- [ ] W1.11 contract + GATE 0 + fresh verifier + security gate; `make test`

## Wave 2 — migration (after wave 1 proven)
- [ ] W2.1 15 skills `Skill(effort-*)` → `route` tool calls (lib/effort-shift.md rewritten)
- [ ] W2.2 remove `skills/effort-*`, `lib/effort-pins.txt`, `lib/effort-pins.sh`,
      install/update steps, `effort:` frontmatter on skills and agents
- [ ] W2.3 `lib/model-gate.md` + `lib/model-check.sh` → mod rule (reflect on a
      small model → raise); census tests repointed to the config table
- [ ] W2.4 docs + CHANGELOG + registries (BDR, LRN, EVAL via effort-audit.py)

## Wave 3 — optional
- [ ] W3.1 per-step heuristics (Read/Grep → +1 level next step; Agent return → orchestrate)
- [ ] W3.2 haiku classifier on `prompt.submit` (`$.model.classify`)
- [ ] W3.3 quota-aware downgrade from `$.session.usage().rateLimits`
- [ ] W3.4 A/B via `lib/effort-audit.py`

## Risks
- Main-loop model switch mid-turn unproven (W0.3b decides).
- A mod bug cuts all routing at once: fail-open (`.catch` → `next(e)`), never deny.
- Two sources of truth during wave 1 (pins + mod): mod must agree with the
  pins until wave 2 removes them.
- API early access: types change between releases; pin the CLI version in the README.
