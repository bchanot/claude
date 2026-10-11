# PLAN r3 — model-router wave 4-B: prompt classifier (2026-10-11)

r1 → r2 after simplicity CONCERNS(4), robustness FATAL(6) (BLOCKER: the
classify await is unbounded on the critical path), correctness CONCERNS(4).
r2 → r3 after the confirmation (robustness CONCERNS(4)). Precedence
r3 > r2 > r1. Contract `.claude/tasks/contracts/2026-10-11-model-router-
w4b-classifier-1858.md`. Base: feature/model-router-w4 at 86845fc.
Corrected facts: default keyword rules never run mid-turn and only write
plan/reflect (they never lower); `mainEffort` ranks sticky > turn > run >
floor > engine and `mainModel` ranks turn above floor; `runMain` holds a
typed best-tier skill's route across the run's turns; `$` calls do not
count against the hook budget (an unbounded `classify` await freezes the
prompt), while `$.clock.sleep` does; `ClassifyOptions` has `model` only;
`claude -p` prompts arrive with origin `sdk`; the breaker is fed by
`classic.StopFailure` only; `warnOnce` fires once per session; config
switches (`enabled`, `verbose`, `mainModelSwitch`) are Config keys read
through `pickSwitch` with session toggles; `confirmPhase` (T3) is
confirm-only, so a dialog on a classified phase would decide nothing.

## Decisions
- D1 no first-use dialog on classified phases (Later and Keep would apply
  the same route). Visibility = the status line (`route: classifier
  <phase>`) and the W4-A transition line (needs `/route verbose on`).
- D2 `classify` is a Config key (default `true`), read from the machine
  override through `pickSwitch` (invalid → default + one log), with a
  session toggle `/route classify on|off` next to `switch`/`verbose`,
  printed on the `router:` line of `/route show`. Persistent off =
  `"classify": false` in `~/.claude/model-router.json`. routing.json is
  NOT touched; no new writer.
- D3 the classifier fills only an EMPTY route: it runs only when no route
  is in force on main (`mainRoute(st) === null && st.turnFloor === null`:
  no sticky `/route`, no turn route from a rule/skill/tool, no run slot
  from a typed skill, no floor), evaluated after `routeFromPrompt`. Real
  coverage, stated in the docs: a typed best-tier skill (feat, bugfix,
  ship-feature…) holds its run slot across turns, so nothing is
  classified until `/route clear`, `/route off`, a user `/model` or a
  typed non-best skill; a non-best skill's row is turn-scoped, so its
  follow-up prompts ARE classified (accepted: those rows are low/medium
  and a complex follow-up may rightly rise). Never mid-turn (`e.turnId !==
  undefined` → skip, as the rules). Never for a non-composer origin (so
  never under `-p`). Never for a sub-agent prompt (prompt.submit is main
  only; a test proves an agent's prompt is not classified).
- D4 a classified route carries the EFFORT ONLY: `turnMain = { phase,
  route: { effort: cfg.phases[phase].effort }, source: 'classifier' }`.
  No tier, so the main model never moves because of a guess (no cold
  context re-reads on opus/sonnet sessions, no cost surprise). It may
  lower the effort (coding = medium, bookkeeping = low); turn-scoped.
  An explicit user `/effort` beats it: `st.engineBase` = the engine
  effort of the first main step of the session (kept across /clear);
  at `turn.step`, when `e.effort !== st.engineBase` (the user moved the
  builtin effort) a `classifier`-sourced turn route is ignored for that
  step (the engine effort applies) — "un choix explicite bat la phase
  déduite" (BDR-115 amendment b).
- D5 bounded call: `label = await Promise.race([classify, $.clock.sleep(
  CLASSIFY_MS = 3000, { signal: next.signal }).then(() => TIMEOUT)])`
  inside try/catch: in the catch, `next.signal.aborted` is tested FIRST
  (a user interrupt: no count, no write, return); a TIMEOUT counts as a
  failure (D7) and gives no route; after the await every guard of D8 is
  RE-CHECKED (`st.off`, the switch, no route in force, not paused) before
  the write, and `next.signal.aborted` skips it (a late result never
  lands in a later turn). The losing classify promise is left to settle
  (the kit offers no cancel); stated.
- D6 labels are descriptive and mapped: `design` → plan, `analysis` →
  reflect, `coding` → implement, `bookkeeping` → apply, `chat` → none
  (lookup with `hasKey`; a mapped phase without an effort → no route).
  The call passes no `model` option (the engine's small fast model; no
  alias from a hook, LRN-203). The sample = the whole trimmed text when
  ≤ `CLASSIFY_MAX = 2000` code points, else the first `CLASSIFY_HEAD =
  500` + last `CLASSIFY_TAIL = 1500` code points (cut by code points,
  never a lone surrogate). A pasted tail can steer the label for one
  turn (effort only, no file write): accepted and documented.
- D7 failures: a rejected call (classify's own `aborted` cause excepted)
  or a TIMEOUT increments `st.classifyFails`; a settled answer resets it;
  at `CLASSIFY_FAILS = 3` the classifier pauses until `clock.now() +
  cooldownMinutes * 60000` (`st.classifyUntil`) with one toast
  "classifier paused <n> min (3 failures)" and the status marker
  `classifier: paused`; both fields are in `resetSession`'s kept set and
  cleared by `/route reload` (like the breaker); the expiry check runs
  BEFORE the route-in-force guard (the marker never stays stale); an
  unknown label neither warns nor counts; the classifier is skipped while
  `cfg.models.haiku` (a stated proxy for the engine's small model) is in
  `st.down`, and when the main loop itself runs on haiku (the effort is
  stripped there anyway).
- D8 guards summary (in order): `st.off` → `cfg.classify` (+ toggle) →
  composer → `e.turnId === undefined` → not a slash → trimmed length ≥ 12
  → no rule matched this prompt → no route in force → not paused, model
  not down → classify.

## Steps
- [ ] S1 config: `classify` key (DEFAULT true, pickSwitch), toggle,
      `/route classify on|off`, show `router:` line, argumentHint.
- [ ] S2 `classifyPrompt($, st, e, next)` in the prompt.submit hook after
      `routeFromPrompt` and the typed marker; `LABELS`/`LABEL_PHASE`
      tables; the sample helper; the race; the failure counter and pause;
      the effort-only route write with source `classifier`; `Source`
      gains `'classifier'`; `slotWord` maps it to `classifier`; the
      status line already prints `route: <source> <phase>`.
- [ ] S3 docs: README (classifier paragraph: what, one small-model call
      per typed prompt when no route is in force, effort only, `/route
      classify off` or `"classify": false` per machine, where to see it:
      status line, `/route verbose on`); the `/route` subcommand lists
      (README ×2, USAGE) gain `classify on|off`; the machine keys lists
      (README, USAGE) gain `classify`; USAGE "Niveau d'effort" one
      sentence; CHANGELOG Unreleased Added; `lib/effort-shift.md` ≤ 2
      lines (the plain conversation routes by content now).
- [ ] S4 kit tests (a bottom `model.classify` mock; `$.clock` mock for
      the race), one per clause: called once with the head+tail sample
      and the five labels, no model option; each label → its phase effort
      only (no tier on the route) and `chat`/`undefined` → none; never
      resolving → no route after 3 s, prompt proceeds; rejection ×3 →
      pause + toast + status marker, then no call during the cooldown,
      a success resets the counter; `aborted` → no count, no warn; small
      model down → not called; not called: short text, slash, sdk origin,
      mid-turn (`turnId`), rule matched (keyword and ultrathink), sticky
      `/route`, run slot held, floor carried, `classify` off (config,
      toggle), mod off, an agent's prompt; turn-scoped (gone at
      turn.complete); effort lowered to low for bookkeeping; the main
      model unchanged on a sonnet session for `design`; `/route show`
      prints `classify: on`; status line `route: classifier reflect`;
      W4-A line "(reflect: classifier)"; invalid config value; 3 timeouts
      → pause; a dispatch abort mid-race → no count, no write; a `/route
      <phase>` landing during the await → the classifier result dropped;
      pause expiry at cooldown-1 ms (still paused) and +1 ms (resumes);
      `/clear` keeps the pause, `/route reload` clears it; a user
      `/effort` change (engine effort ≠ baseline) → the classified effort
      ignored at the step; a 2000-code-point text sent whole, a longer
      one head+tail with no lone surrogate; `constructor` label → none;
      a phase without effort → none; main on haiku → not called; a
      non-best skill's follow-up prompt classified; a plain prompt after
      a finished best-tier run not classified until `/route clear`.
- Edge cases: a prompt that is only a URL or code (the classifier
  decides; no special-casing); every classified prompt waits one small-
  model round trip (typically under a second, 3 s at most: stated in the
  README and measured in the AC9 live check); a `[1m]` session (no
  effect: effort only).
- Disposition: honors BDR-115 (no alias from a hook, no model write, no
  file write), BDR-116 (writers unchanged; no new dialog), LRN-203,
  LRN-210, LRN-212 (live mod: the first plain prompt after the feater
  saves is classified).
- Docs note for the user: a misclassification lowers one turn's effort
  only; `/route <phase>` or `ultrathink` overrides it at once.

## Challenge ledger (r1 → r2)
- simp 1, corr 3/7, rob 6 (dialog decides nothing / misstates) → D1 dropped.
- simp 2, corr 11, rob 11 (flag plumbing, new writer) → D2 Config key.
- simp 3/4, corr 1/2/12, rob 3/4 (mid-turn, run slot, floor) → D3.
- rob 5 (model flips per turn) → D4 effort only.
- rob 1 BLOCKER, corr 9 (unbounded await, late write) → D5.
- simp 5, corr 4 (alias from a hook) → D6 no model option.
- corr 8, simp 8 (label words) → D6 descriptive labels mapped.
- rob 7 (head-only sample) → D6 head + tail.
- rob 2, corr 5 (failure handling, warn spent) → D7.
- corr 6, rob 9 (`-p`) → D3 never.
- corr 10 (sub-agent clause) → S4 test.
- simp 6, rob 10 (visibility) → status line + verbose note.
- simp 7 (doc lists) → S3 lists named.

## Confirmation ledger (r2 → r3)
- conf 1 (timeouts uncounted) → timeouts count toward the pause.
- conf 2 (abort lands in the counted branch) → `next.signal.aborted`
  tested first in the catch.
- conf 3 (classifier overrides a user `/effort`) → `engineBase` guard at
  the step: an explicit builtin effort beats a classified route.
- conf 4 (run coverage) → D3 states the real coverage; docs name it.
- conf 5 (guards not re-checked after the await) → re-checked.
- conf 6 (pause bookkeeping) → ×60000, kept across /clear, cleared on
  reload, expiry checked first, boundary tests.
- conf 7 (sample, labels) → whole text ≤ 2000 cp, code-point cuts,
  hasKey, no-effort phase skipped.
- conf 8 (down check) → haiku id as a stated proxy; skip on a haiku main.
- conf 9 (pasted tail) → accepted, documented.
- conf 10 (latency) → stated in the README and measured live.
