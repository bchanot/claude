# PLAN — guard-fail-closed (BDR-125 gap audit A6)

## CONTEXT
- mods/model-router/hooks/register.ts ~:4397-4465. `guardWrite($, st, e)`
  awaits `ensureConfig` first, then checks `st.off`, `e.agentId`,
  `inRun(st)`, then `writtenPath` and `isFreePath(path, await
  $.session.root())`. `registerGuard` registers three `tool.call` handlers
  (Edit, Write, NotebookEdit): `guardWrite` true → `{ deny: GUARD_REASON }`,
  else `next(e)`; each `.catch(($, e, next) => { warnOnce(...); return
  next(e) })` fails open for ANY error, the guard's own or the downstream
  tool's.
- Comment above (~:4402) says "Fail-open like every hook here".
- `errWord(err)` (~:367) = the log-safe error kind. `warnOnce(st, $, hook,
  kind)` (~:1092) logs once per hook key with the fixed tail "routing
  skipped for this event".
- Tests: register.test.ts GUARD section (~:7288-7470), helpers
  `guardRig`, `write`, `denied`, constant `GUARD`.

## APPROACH
1. Reorder `guardWrite` so the cheap, infallible checks come first and the
   code that can fail is reached only for a main-loop out-of-run write:
   `if (e.agentId !== undefined || inRun(st)) return false` →
   `const path = writtenPath(e); if (path === undefined) return false` →
   `if (DOC_FILE.test(path) && !dotDot(path)) return false` is NOT added
   separately: instead split `isFreePath` so the doc-file test runs before
   `$.session.root()` is awaited (the `/../` rejection stays first, as
   today) → `await ensureConfig($, st)` → `if (st.off) return false` →
   `return !isFreePath(path, await $.session.root())`.
   Result for every input the guard decided before: unchanged (same
   predicates, same outcome; only order differs; ensureConfig is an
   idempotent lazy load that every other hook also calls).
2. Fail closed on the guard's own failure only: each handler wraps the
   `guardWrite` call, not `next(e)`:
   ```
   let held: boolean
   try { held = await guardWrite($, st, e) } catch (err) {
     return guardFailed($, st, '<Tool> guard', err)
   }
   if (held) return { deny: GUARD_REASON } as never
   return next(e)
   ```
   Factor the three identical handlers into one helper
   `guardHandler(tool)` returning the handler, so the try/catch exists
   once (the file already repeats the block three times; one helper is
   the minimum that keeps the new logic in one place).
   `guardFailed` logs once per hook key via the existing `warnOnce`
   mechanism (new optional 5th param `effect`, default `'routing skipped
   for this event'`; the guard passes `'write held'`) and returns
   `{ deny: GUARD_FAIL(errWord(err)) }` where
   `GUARD_FAIL = (kind) => 'model-router: the write guard failed (' + kind
   + '), so this write is held. Enter /hotfix, /feat, /bugfix or ' +
   '/ship-feature, or re-enter the skill you were running, then make ' +
   'this edit.'` (exact user-chosen text).
3. The existing `.catch(... warnOnce; return next(e))` stays for errors
   thrown by `next(e)` (downstream tool): today's behavior, untouched.
4. Comment above the guard: replace "Fail-open like every hook here" with
   one sentence: the guard's own failure holds a main-loop code write
   (fail closed, BDR-125 phase 2 rule); sub-agents, skill runs and doc
   files never reach the code that can fail; a downstream tool error
   passes through as before.

## EDGE CASES
- `ensureConfig` throws (config read error) on a main-loop code write
  outside a run → denied with GUARD_FAIL. Same write inside a skill run or
  from a sub-agent → allowed (never reaches ensureConfig).
- `$.session.root()` throws → a `.md`/`.txt` path still passes (doc test
  runs first); any other path → denied.
- A path with `/../` → not free (unchanged), reaches root().
- `st.off` (mod off) → allowed, but only once ensureConfig succeeded; if
  config cannot be read the mod's off state is unknown → held (fail
  closed). Entering a skill still writes.
- warnOnce dedupe: one log line per tool key per session, as today.

## TESTS (register.test.ts, GUARD section)
Make a guard step throw in the rig (e.g. a `$.session.root` that throws,
or a config read that throws; use whatever the rig already offers to
inject failures, read neighbouring tests for the idiom):
- GUARD fail-closed: root() throws, main code write → deny contains
  "the write guard failed (" and "so this write is held".
- GUARD fail-closed: root() throws, `README.md` write → not denied.
- GUARD fail-closed: root() throws, sub-agent write (`agentId` set) → not
  denied.
- GUARD fail-closed: root() throws, inside a skill run (latch opened as
  the existing "a typed skill opens it" test does) → not denied.
- GUARD fail-closed: Edit and NotebookEdit get the same deny.
- Downstream error untouched: a bottom `tool.call` handler that throws
  for a free path → the error behaves as before (not converted to the
  GUARD_FAIL deny).
- Existing GUARD tests stay green unchanged.
The fail-closed tests must fail on the pre-change register.ts.

## DISPOSITION
Honors BDR-125 (phase 2 shared rule: guards fail closed) and follows
BDR-112's precedent (push-guard text-only deny, fail closed). Honors the
model-router CLAUDE.md doctrine (main loop writes no code outside a skill
run): entering a skill stays the way out when the guard fails.

## FILES
mods/model-router/hooks/register.ts, mods/model-router/hooks/register.test.ts.

## r2 (challenge r1: correctness CONCERNS(2), robustness CONCERNS(1), simplicity CONCERNS(1)) — SUPERSEDES APPROACH, EDGE CASES and TESTS above
Landed: (a) when ensureConfig throws, every latch hook (Skill tool.call
:4566, skill.prompt :4588, prompt.submit :4899, /route) also fails before
latching, so "enter a skill" led nowhere (robustness 1); (b) config READ
errors never throw (readLayer/readOverride catch; an unreadable override at
first load turns the router off → write passes): the r1 edge case was false
(correctness 2); the real throw sources are `$.session.root()` and a raw
`$.ui.log` in reloadConfig (:2139) / registerTool's catch (:3612);
(c) guardHandler + guardFailed + a warnOnce 5th param were heavier than
needed (simplicity 1-2); (d) moving ensureConfig later dropped the lazy
load other hooks rely on after /reload-plugins (robustness 2); (e) shared
warnOnce key with the downstream .catch (robustness 3, correctness 5);
(f) the rig cannot make session.root fail (correctness 1); (g) BDR-136
point 4 records the guard as fail-open (correctness 7).

1. `guardWrite($, st, e): Promise<string | undefined>` returns the deny
   text, undefined = allow. Order:
   a. `let cfgErr: unknown; try { await ensureConfig($, st) } catch (err)
      { cfgErr = err ?? 'error' }` — the lazy load still runs on every
      write, as today (keeps other hooks' first load after
      /reload-plugins).
   b. `e.agentId !== undefined || inRun(st)` → undefined.
   c. `path = writtenPath(e)`; undefined → undefined.
   d. root-free check, new function `freeWithoutRoot(path): boolean |
      undefined`: `/../` or trailing `/..` → false (not free, keep
      going); DOC_FILE → true (allow, return undefined); else undefined
      (needs the root).
   e. `cfgErr !== undefined` → `heldBy(st, $, cfgErr)`.
   f. `st.off` → undefined.
   g. `let root; try { root = await $.session.root() } catch (err) {
      return heldBy(st, $, err) }`.
   h. root-dependent check, `isFreePath(path, root)` reduced to the tree
      test only (`startsWith(root/)`, `.claude/` minus
      `.claude/worktrees/`, `docs/`); the `/../` rejection stays in front
      of it via step d (a `docs/../src/a.ts` path is never free).
      Not free → `GUARD_REASON`; free → undefined.
   `heldBy(st, $, err)`: `warnOnce(st, $, 'write guard', errWord(err))`
   (unchanged warnOnce, own key 'write guard', distinct from the
   '<Tool> guard' keys of the .catch blocks) and returns
   `GUARD_FAIL(errWord(err))`, `GUARD_FAIL` = the user-chosen text
   verbatim with the kind spliced in.
   Handlers change by one line each: `const deny = await guardWrite($,
   st, e); if (deny !== undefined) return { deny } as never; return
   next(e)`. The three `.catch` blocks stay as they are (downstream tool
   errors: unchanged behavior). No handler factory, warnOnce untouched.
2. The exit always works:
   - reloadConfig's `log` (:2139) and registerTool's catch log (:3612)
     go through the existing `tryLog` so a failing ui.log can no longer
     abort the config load.
   - Skill tool.call `.catch` (:~4583): after `const out = await next(e)`,
     latch like the main handler does: main loop (`e.agentId ===
     undefined`) and `out` not a deny → `st.skillRun = true`; return out.
   - skill.prompt `.catch` (:~4598): `if (typedPath(st, e.skill) !==
     undefined) st.skillRun = true` before `return next(e)` (typedPath is
     config-independent; it reads typedSlash/promptAllowed/loops).
3. Comment above the guard (:~4402) replaces "Fail-open like every hook
   here": the guard's own failure (session.root, a config load that
   throws) holds a main-loop code write outside a skill run (fail closed,
   BDR-125 phase 2 rule, amends BDR-136 (4)); sub-agents, skill runs and
   doc files are decided before anything that can fail; entering a skill
   latches even when the config load failed; a downstream tool error
   passes through the .catch as before.

EDGE CASES (real behavior):
- Unreadable or broken routing.json / override: no throw; first load with
  an unreadable override → router off → write passes (unchanged).
- session.root throws: doc file passes, sub-agent passes, in-run passes,
  main code write outside a run → GUARD_FAIL deny.
- ensureConfig throws (residual, after tryLog): same as above for main
  code writes; a model Skill call or a typed skill still latches through
  the .catch paths, then writes pass.
- `/../` paths: never free (unchanged), held or redirected.

TESTS (register.test.ts):
- Rig: World gains `root?: 'fail'` (pattern of `repo: 'fail'`); the
  session.root mock (:209) reads `w.root` per call and throws when
  'fail', so a test flips it after boot. FILE SCOPE widened to the rig
  lines.
- Red-first (fail on the pre-change code): root fails → main code Write
  denied with text containing "the write guard failed (" and "so this
  write is held"; same for Edit and NotebookEdit (one test, as :7423).
- Regression guards (pass before and after): root fails → README.md
  write passes; sub-agent write passes; in-run write (typed skill latch,
  as :7347) passes.
- Exit test: root fails → main code write held → a model Skill call
  (the existing "model-loaded skill opens it" idiom, :7366) → the same
  write passes.
- If the rig can make ensureConfig throw (e.g. an unrecorded ui.log on a
  warning config at first load with st.loaded false), add: write held,
  then a model Skill call, then the write passes. If it cannot, say so in
  the report with the reason; do not invent a rig path beyond the World
  `root` knob.
- No downstream-error test (behavior unchanged, re-run semantics already
  pinned at :6403).
- Existing GUARD tests unchanged and green.

CAPITALIZE (closing step, not the executor): BDR-136 status line through
`memory.sh status` naming the amendment of point (4).
FILES: mods/model-router/hooks/register.ts,
mods/model-router/hooks/register.test.ts.

## r3 (re-challenge r2: correctness CONCERNS(2 MAJOR), robustness CONCERNS(1 MAJOR)) — SUPERSEDES r2 §1-3, EDGE CASES and TESTS
Landed: (a) after tryLog no known source makes ensureConfig throw: the
cfgErr hold and both new .catch latches had no reachable trigger and no
test; the skill.prompt latch could not fire in its target state (prompt
.submit fails before noteTyped) (corr 1-2, rob 3); (b) the engine API
documents the guard pattern: `.catch(($, e, next) => next.called ? next(e)
: { deny })` (claude-code.d.ts tool.call remark ~:4744-4747; Caught
~:1500-1511: when `called`, next(e) replays the settled result, nothing
beneath runs again) — it covers EVERY guard-own failure, not two sources
(corr 7, rob 4); (c) pre-existing latch hole: a Skill call the engine
refused or that failed returns `isError` with no `deny` key (BDR-137), yet
the main latch (:4577-4579) opens the guard for the session (rob 1; the
memory mod already tests both, mods/memory/hooks/register.ts:1441);
(d) warnOnce's fixed tail says "routing skipped" on a held write (corr 6,
rob 5).

1. `guardWrite` and `isFreePath`: UNCHANGED (order, ensureConfig first,
   lazy load kept, `/../` handling kept). No tryLog change, no latch in
   any .catch, no prompt.submit change.
2. The three guard `.catch` blocks (Edit, Write, NotebookEdit) call one
   new helper `guardCaught(st, $, e, next, hook)`:
   - `next.called` → `warnOnce(st, $, hook, next.error.kind); return
     next(e)` (downstream tool error: exactly today's behavior, replayed,
     nothing re-run).
   - not called (the guard itself failed): if `e.agentId !== undefined ||
     inRun(st)` or the write is a doc file (`writtenPath(e)` undefined, or
     DOC_FILE matches and the path has no `/../` and does not end in
     `/..`) → `warnOnce(st, $, hook, next.error.kind); return next(e)`
     (writes the guard never holds still pass).
   - else → log once per session through `tryLog` under the
     `st.warned` key `'write guard held'`: `model-router: write guard
     failed (<kind>): main-loop code writes are held until a skill runs`;
     return `{ deny: GUARD_FAIL(next.error.kind) }` with GUARD_FAIL = the
     user-chosen text verbatim, kind spliced in. A `.claude/` or `docs/`
     path is held too in this branch (the root is unknown when the guard
     failed: it could not decide).
   Type `next` as the engine's `Next & Caught` (or what the handler's
   inferred type is); no new dependency.
3. Latch predicate fix (pre-existing hole, in scope per the user's
   "fill every gap found" instruction for this run): the Skill handler's
   `refused` (:~4577) = not a successful output: `typeof out !== 'object'
   || out === null || 'deny' in out || (out as { isError?: unknown })
   .isError === true`; latch only when main loop and not refused.
4. Comment above the guard: replace "Fail-open like every hook here" with:
   the guard's own failure holds a main-loop code write outside a skill
   run (fail closed via `next.called`, BDR-125 phase 2 rule, amends
   BDR-136 (4)); sub-agents, skill runs and doc files still pass; a
   downstream tool error is replayed as before. Residual (one line): if
   the config load itself threw, only a model Skill call can latch (no
   known throw source today).

TESTS (register.test.ts):
- Rig: World gains `root?: 'fail'` (pattern of `repo: 'fail'`); the
  session.root mock (:209) reads `w.root` per call and throws when
  'fail'. Flip it after boot.
- Red-first: root fails → main code Write, Edit and NotebookEdit each
  denied with text containing "the write guard failed (" and "so this
  write is held" (one test, as :7423).
- Regression guards: root fails → README.md write passes; sub-agent write
  passes; in-run write (typed-skill latch, as :7347) passes.
- Exit: root fails → main code write held → model Skill call (idiom
  :7366) → same write passes.
- Latch hole, red-first: a Skill bottom returning `{ isError: true, ... }`
  (shape per the kit; read :7450-7471 for the deny variant) → a later
  main code write is still redirected with GUARD.
- Existing GUARD tests unchanged and green; full suite green.
FILES unchanged (register.ts, register.test.ts incl. rig lines).
