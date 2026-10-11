# PLAN r4 — model-router wave 3-A: first-use route confirmation + decision memory + project exceptions (2026-10-10)

r1 → r2 after simplicity CONCERNS(3) + correctness FATAL(8); r2 → r3 after
robustness CONCERNS(8) (fresh dispatch on r2 after the first died on a
network error); r3 → r4 after the confirmation pass (correctness
CONCERNS(6), no BLOCKER). Precedence: r4 > r3 > r2 > r1 where they differ. Contract
`.claude/tasks/contracts/2026-10-10-model-router-w3a-confirm-1201.md`.
Facts (kit types, checked 2026-10-10): `$.ui.ask(question, {options,
header})` opens the engine's AskUserQuestion dialog, resolves to the chosen
label or the "Other" free text, REJECTS when dismissed and in a `-p` run;
`$.fs.read/stat/exists/write` take absolute paths, write creates
directories; `$.session.root()` = the project root (follows /cd);
`$.plugin.root` = the plugin directory, absolute (routing.json =
`${$.plugin.root}/routing.json`, reached through the existing
`~/.claude/skills/model-router` link); `$.ui.toast`; `$` calls stop the
hook budget clock. The kit has no fs: tests mock bottom `fs.*`, `env.get`,
`session.root` and `tool.call AskUserQuestion` hooks.

## Data (one tracked source for rows AND phases; r3)
- `mods/model-router/routing.json` (tracked):
  `{ "phases": {11 full routes}, "skills": {56}, "agents": {23},
    "projects": { "<repo key>": { "skills": {}, "agents": {} } },
    "confirmed": { "skills": {}, "agents": {}, "phases": {} },
    "changed": { "skills": {}, "agents": {} }, "ask": true }`
  `confirmed.<kind>.<name>` = the routing.json phase endorsed by a Keep;
  `changed.<kind>.<name>` = `{ "from": <shipped phase>, "to": <phase> }` for
  an "Everywhere" change (the census reads `from`). `projects[key]` = the
  "This project only" exceptions. Key (r4) = the origin remote normalized:
  scheme and userinfo stripped, host lowercased, `.git` and trailing slash
  removed (`github.com/acme/app`); no remote → `local:<root realpath>`
  (meaningful on that machine only, stated in the toast); `session.repo`
  or the realpath failing → the `projects` layer is skipped and ASK2
  offers Everywhere only. Resolved once per decision and re-resolved on
  `classic.CwdChanged` (rebuild). No version key, no dates. Never a URL
  with credentials in the file.
- NEVER read from the project tree: `<root>/.claude/model-router.json` is
  not a layer (a cloned repo must not route the user's agents). Layers,
  later wins: routing.json (phases, rows, then `projects[key]` rows) <
  `~/.claude/model-router.json` (machine override; its `ask: false` also
  honored). Phases merge first, rows validate against the final table.
- Phases: routing.json `phases` replaces `DEFAULT_CONFIG.phases` route by
  route; an invalid or missing phase falls back to `DEFAULT_CONFIG.phases
  [name]` with one log line (a typo never removes a phase); alts offered
  by the dialog are filtered against the final table.
- Loading: full read at session.start, and LAZILY once when the State was
  never loaded (first prompt.submit / skill.prompt / agent.spawn / route
  tool after a `/reload-plugins`, which re-runs register() without
  session.start); a failed layer is skipped and logged at that first load
  only; afterwards any failed read, and a routing.json that went missing,
  keeps the WHOLE previous config (today's kill-switch rule), and no ask
  runs while routing.json is unreadable. `/route show` prints `config:
  routing.json` once loaded. `resetSession` keeps its current set (cfg
  included); the layers are re-read at the next `prompt.submit` and the
  cfg swapped only after a fully successful read. Session toggles
  (`/route switch`, `verbose`) live in State, re-applied after any rebuild,
  and added to resetSession's kept set (they survive /clear as today).
- `DEFAULT_CONFIG.skills/.agents` = `{}`; the file is the source. A
  missing routing.json → DEFAULT phases, no rows, one log, no asks, no
  writes (the writer never creates the file).

## Dialog (main loop only; `ask` true; mod on; never inside an agent)
- Trigger sites and guards:
  T1 typed skill with a row: `applyTypedSkill` made async, awaited in the
     skill.prompt hook OUTSIDE `safely`: route FIRST (`routeMainBySkill`,
     typed=true), build the text from the route now in force, ask, and on
     a change re-run `routeMainBySkill` with the recomputed `skillRow`
     (the model's `Skill` path never asks).
  T2 rowed agent spawn: in `registerSpawn` before `spawnTarget`, awaited;
     guards `e.parentAgentId === undefined`, not frozen, not shadowed, and
     `e.model === undefined` (an explicit model is not a routing decision).
  T3 route tool phase on main (`handleRouteTool`, no agentId, and only
     when `e.phase` is a phase key — never for an effort-only call):
     confirm-only.
- One dialog (ASK1), 4 options: question text built from the REAL decision:
  main → `decideFor`/`mainEffort` like `mainRoutedText` ("First route for
  /feat: reflect, next step claude-fable-5-1 at high. Keep it?"); spawn →
  `spawnTarget` + the explicit `effort` param when given ("First dispatch
  of feater: implement, claude-sonnet-5-5 at medium. Keep it?"); T3 →
  "First use of orchestrate on the main loop: claude-fable-5-1 at medium.
  Keep it?" with options ["Later", "Keep"] only.
  Options T1/T2: ["Later", "Keep", <altA>, <altB>] (Later FIRST: an idle
  auto-pick, if any surface does one, must never write), header
  "model-router";
  alts = the first two of [plan, reflect, implement, apply] (skills) or
  [judge, implement, verify, apply] (agents) minus the current phase;
  "Other" free text = a phase key of the final table (else toast "unknown
  phase <x>, default kept" → Later); an Other equal to the current phase
  = Keep. Any answer that is not exactly Keep, an alt, or a valid Other →
  Later (covers dismissed, rejected, auto-resolved idle answers). ASK2
  accepts only its two labels; anything else = Later.
  Before opening any dialog the mod re-reads routing.json (the pre-ask
  read) and re-checks `ask` AND "decided" for the key from that fresh
  content, so a decision taken in another live session is seen.
- Keep → `confirmed.<kind>.<name> = <routing.json phase>` AND
  `confirmed.phases[<phase>] = <phase>` (a Keep endorses the phase: no
  duplicate T3 later); the row applies. "Decided" = `confirmed` equals the
  routing.json row, OR a `projects[key]` / machine-override row exists for
  that name (presence = decided; never compared across layers).
- Change (alt/Other) → ASK2 scope ["Everywhere", "This project only"].
  Everywhere → routing.json row + `changed.<kind>.<name> = {from, to}`
  (`from` kept from the FIRST entry when one exists, `to` = the new row) +
  `confirmed.<kind>.<name> = to`; This project only → `projects[key]
  .<kind>.<name> = phase` (routing.json row untouched) + `confirmed.<kind>
  .<name> = the BASE routing.json row` (so no other project asks again). One file, one serialized write.
  Then rebuild; the new route applies to the current decision at once
  (T1: recompute `skillRow`; T2: recompute `spawnRoute` and pass it to the
  spawn bookkeeping). A write or rebuild failure → log once, default row
  applied, key left unasked (never escapes to the hook's `.catch`).
- Later → default applies, nothing written.
- One dialog in flight per session, ever (`st.asking: string | null`):
  a use that finds a dialog open (same key or another) applies its current
  route and stays unasked (asked later); the owner alone runs ASK1, ASK2
  and the write. A parallel spawn never awaits a promise it did not create
  (hook budget: only the owner's `$` call stops the clock). Asked-this-
  session = `Set<key>` in State, dropped by resetSession.
- Never on `turn.step`. The ask is awaited in the owning hook with
  `.catch(() => 'Later')`.

## Commands (composer only, as `/route` today)
- `/route pending` → keys not yet confirmed (asked-this-session first).
- `/route ask on|off` → `ask` in routing.json (write path below); the
  flag is re-read (one `$.fs.read`) right before each ask so another
  session's change is seen.
- `/route reload` → re-reads the three layers. (`set`, `confirm`, a show
  suffix: deferred to TODO; the dialog is the writer.)

## Writes
- `writeRouting($, st, patch)`: read-modify-write of the whole JSON
  (2-space; key order phases, skills, agents, projects, confirmed, changed,
  ask), serialized through ONE promise chain in State; refuses (toast,
  answer treated as Later) when routing.json is absent or unparsable:
  never creates the file; size cap as the override, `readCapped` takes
  the file label; after a write: rebuild (swap only on a successful read)
  + toast "routing.json updated: commit it from the config repo (chore
  branch, `gitflow.sh start chore …`)".
- Writers: dialog answers and composer `/route ask` ONLY. The route tool
  (model), prompt rules and sub-agents never write. Nothing is ever
  written into a project tree.

## Census and floors (BLOCKER closed)
- `lib/tests/effort-routing.test.sh`: rows AND phases read from
  routing.json (python3 json); tier heads still parsed from `register.ts`
  `tiers` (unchanged by this wave; the only register.ts read left); a new
  lock: `DEFAULT_CONFIG.phases` values == routing.json phases (the fallback
  never applies a stale route). The drift lock stays for every row EXCEPT
  one with a `changed.<kind>.<name>` entry whose `from` phase route equals
  the frontmatter AND whose `to` equals the current row: then one `WARN
  floor drift: <file> <value> vs row <to> (<value>)` line, no FAIL. A
  Keep-only row, an empty or unknown frontmatter value, a hand edit after
  a change (`to` ≠ row), or a drift not matching `from` still FAILs.
- BDR-115 amendment 2(a) "census-locked equal" → amended to "equal unless
  the row is a confirmed user decision (floor may lag; WARN)" at STEP 7.

## Steps
- [ ] S1 routing.json from the current DEFAULT_CONFIG (phases + rows +
      Explore/Plan), `projects`/`confirmed`/`changed` empty, `ask` true;
      DEFAULT rows → `{}`; `loadLayers` (two files + `projects[key]`),
      first-load degrade then keep-previous rule, phase fallback by name,
      session toggles in State, resetSession kept set unchanged + re-read
      at the next prompt.submit.
- [ ] S2 ask engine: `askFirst($, st, kind, name, text, options)` with the
      single-dialog guard + asked set; `decide(answer)`; `applyDecision`
      (Keep / change + scope) → serialized write → rebuild → recompute,
      wrapped so a failure logs once and applies the default.
- [ ] S3 wiring T1 (async applyTypedSkill), T2 (registerSpawn), T3
      (handleRouteTool, confirm-only).
- [ ] S4 commands `pending`, `ask on|off`; `reload` reads three layers.
- [ ] S5 census (rows + phases from JSON, drift lock with the decision
      exception) + `lib/effort-shift.md` ≤ 6 added lines (dialog, `/route
      pending`, `/route ask`).
- [ ] S6 kit tests. First: `boot()`/`bootRun()` gain a path-aware fixture
      (bottom `fs.exists`/`fs.stat` (+ `realPath`)/`fs.read`/`fs.write`,
      `env.get` HOME, `session.root`, `session.repo`) serving an inline
      routing.json with `ask: false`
      unless a test opts in (`boot($, on, {ask: true, project: {...},
      home: {...}})`); the existing `{verifier: null}` test becomes
      path-aware; all 86 tests green again. Then one test per clause:
      layer precedence (routing.json rows < projects[key] < machine
      override, null drop; a `.claude/model-router.json` in the project
      tree is NEVER read; machine `ask:false` honored); typed `/feat` first use → AskUserQuestion mock
      sees the id + "high" → "Keep" → fs.write of routing.json captured
      with confirmed.skills.feat = reflect AND confirmed.phases.reflect →
      second typed `/feat` → no ask; alt "implement" → ASK2 → "Everywhere"
      → routing.json row + main routed implement now; "This project only"
      → project file written, routing.json row untouched, confirmed in
      routing.json; "Later"/reject/free text garbage → default, no write,
      no second ask this session; agent first spawn → ask → Keep → model
      written; explicit `model` param → no ask; two parallel spawns → one
      ask, the second spawn routed on the current row without waiting; parentAgentId set → no ask; route tool phase first use → ask
      (Keep/Later) → Keep → confirmed.phases; phase already endorsed by a
      T1 Keep → no T3 ask; `/route ask off` → no asks + write; `/route
      pending` text; routing.json unreadable at start → DEFAULT phases, empty
      rows, one log, no asks; unreadable at a later rebuild → previous cfg
      kept; missing file → `/route ask off` refused with a toast, file not
      created; a phase typo in routing.json → DEFAULT phase by name + log,
      alts filtered; `/route switch on` survives a rebuild; writes are
      serialized (two decisions, one file, both present); row edited by
      hand after a Keep → asked again; census flip-tests: confirmed-only
      drift FAILs, `changed.from` drift WARNs, empty `model:` FAILs.
- [ ] S7 live checks after the user's /reload-plugins (EVIDENCE lines,
      answers committed on the branch before finish): `/route show`
      prints `config: routing.json` right after the reload (lazy load);
      one dialog at each of the three sites; a parallel same-agent dispatch answered after
      more than 10 s (the unowned spawn must be routed, not timed out);
      what an unanswered dialog resolves to on the terminal (and on sdk/
      bridge if reachable): any auto-pick must land on "Later".
- Disposition: honors BDR-115 (user writers only; full ids in texts;
  amendment 2(a) to be amended), BDR-107/108 (phases unchanged), LRN-206
  (kit facts), LRN-210 (one clause per test), LRN-211 (typed path only).
- Deferred (TODO): `/route set`, `/route confirm`, show suffix, dialog
  edits of phases, frontmatter auto-alignment, a session-start warning
  when routing.json is dirty, per-machine `projects` (today one tracked
  map keyed by repo).

## Challenge ledger (r1 → r2)
- correctness 1 BLOCKER + simplicity 3 (census red on a decision) → drift
  lock with the confirmed-decision exception (WARN), BDR-115 2(a) amended.
- correctness 2/5, simplicity 2 (partial phase overrides, blast radius) →
  phases move to routing.json as a full table, dialog never edits phases,
  T3 confirm-only, project layer rows only.
- correctness 3, simplicity 10 (kit loses rows) → S6 path-aware fixture first.
- correctness 4 (texts from the real decision) → ASK1 texts from
  decideFor/mainEffort and spawnTarget; T2 skipped on explicit model.
- correctness 6, simplicity 9 (sync site) → async applyTypedSkill awaited
  in the hook.
- correctness 7 (root == HOME) → layer 3 skipped, ASK2 skipped.
- correctness 8/9/10/16/17 (layers, /clear, validation order, stale root,
  concurrent writes) → re-read from disk on every rebuild, per-layer
  degrade, phases first, root re-resolved, one write chain.
- correctness 11/12 (Other, counts), simplicity 4/7 → one 4-option dialog,
  2 alts, non-matching answers = Later.
- correctness 13 (confirmed location) → always routing.json.
- correctness 14/15 (parentAgentId, fs.stat label) → written in.
- correctness 18 (no live proof) → S7.
- simplicity 1 (commands) → pending + ask only; set/confirm deferred.
- simplicity 5/6/8 → confirmed = phase, no version, one Map, Keep endorses
  the phase.
- simplicity 11 → project layer rows only.

## Challenge ledger (r2 → r3, robustness)
- rob 1/9 (shared promise burns the awaiters' budget; stacked dialogs) →
  one dialog in flight, owner-only; concurrent uses apply the current
  route unasked; S7 >10 s check.
- rob 2 (per-layer degrade wipes rows, reopens the kill switch) → degrade
  at first load only, then keep-previous; no asks while unreadable.
- rob 3 (a phase typo removes the phase, gate STOPs everywhere) → fallback
  to DEFAULT phase by name + log; alts filtered.
- rob 4 (writer creates a missing file) → writer refuses, never creates.
- rob 5 (global confirmed vs layered rows re-asks forever) → confirmed
  compared with the routing.json row only; layer rows = decided by
  presence; one file, one write.
- rob 6 (project-tree layer = security hole + foreign writes) → layer
  removed; exceptions in routing.json `projects[key]`; nothing written in
  a project tree.
- rob 7 (drift exception too wide) → exemption only for `changed.from`
  matches; Keep-only, empty and unknown values FAIL.
- rob 8 (/clear drops cfg/kill switch/breaker) → kept set unchanged;
  re-read at next prompt.submit, swap on success.
- rob 10 (session toggles reverted by rebuilds) → toggles in State.
- rob 11 (dirty tracked repo, S7 answers) → toast names the chore flow;
  S7 answers committed before finish; session-start warning deferred.
- rob 12 (idle auto-pick) → "Later" first; S7 verifies.
- rob 13 (`ask` only in the tracked file) → machine override `ask`
  honored; flag re-read before each ask.
- rob 14 (write failure escapes) → applyDecision wrapped.

## Confirmation ledger (r3 → r4, correctness)
- conf 1 (tier heads) → census keeps a tiers parser on register.ts; AC7
  CHECK narrowed to the rows/phases parser.
- conf 2 (rows lost after /reload-plugins) → lazy load once; S7 line.
- conf 3 (T1 text before routing) → route first, text, ask, re-route.
- conf 4 (exception re-asks elsewhere) → confirmed = base row on "This
  project only"; test X then Y.
- conf 5 (multi-session re-ask) → pre-ask read re-checks decided.
- conf 6 (raw remote URL / machine path as key) → normalized key, no
  userinfo, `local:` fallback, key failure skips projects only.
- conf 7 (leftovers, un-gated move of the exception file) → S6/contract
  fixed; named to the user at the gate.
- conf 8 (fixture) → session.repo + realPath mocked; key failure scoped.
- conf 9 (/cd) → rebuild on `classic.CwdChanged`.
- conf 10 (changed.from on a second change) → first `from` kept, exempt
  only when row == to.
- conf 11 (unspecified answers) → ASK2 two labels only; Other == current
  = Keep.
- conf 12 (DEFAULT phases drift) → census lock DEFAULT == routing.json.
- conf 13 (effort-only route call) → T3 only for a phase key.
- conf 14 (later absence) → treated as failed, previous kept.
- conf 15 (toggles across /clear) → added to the kept set.
