# PLAN r3 — model-scope-dialog (feat)
Contract: `.claude/tasks/contracts/2026-10-25-model-scope-dialog-1450.md`
Scope rule: 7 (PROCEED), 4 files, logic in one mod hook + tests + docs.
r1 → r2 after 3 lenses (correctness FATAL(6), robustness CONCERNS(7),
simplicity CONCERNS(3)); r2 → r3 after the confirmation pass (CONCERNS(3), K1-K14).
Every change below is named at the finding it closes.

## Files
- `mods/model-router/hooks/register.ts`
  - `registerCommandHook` (l.3758): a second hook beside the `route` one:
    `on('command.run', { command: 'model' }, async ($, e, next) => handleModelCommand($, st, e, next))`
    `.catch(($, e, next) => { warnOnce(st, $, 'command.run model', next.error.kind); return next(e) })`.
    Own warnOnce key (C7/R1). The `.catch` can only be reached BEFORE an answer: the whole post-answer section runs inside its own try/catch that returns `{ text }` (K5: no shared flag). Fail-open to native only before an answer (C3/R1/S9).
  - `handleModelCommand($, st, e, next)` near `handleCommand` (l.2019), in this order:
    1. `await ensureConfig($, st)` (C2/R8/S7).
    2. gates, each `return next(e)`: `st.off`; `e.origin.kind !== 'composer'`; `tokens = e.args.trim().split(/\s+/)`, `tokens.length !== 1 || tokens[0] === ''` (no args or extra tokens: native owns its syntax); `bare = tokens[0].replace(ONE_M, '')`, `!knownModel(st.cfg, bare)`; `(await $.session.surfaces()).length === 0` (headless) BEFORE the slot check; then `st.asking !== null`; then `st.asking = \`model:${tokens[0]}\`` synchronously (R9 TOCTOU).
    3. `try { … } finally { st.asking = null }`.
  - `knownModel(cfg, token)`: `bare = token.replace(ONE_M, '')`; `hasKey(cfg.models, bare) || Object.values(cfg.models).includes(bare)`, AND NOT (`ONE_M.test(token)` and the resolved id starts with `HAIKU`) (K13: haiku has no `[1m]` tier, `haiku[1m]` goes to native). An alias or a full id IN THE TABLE. A shape-only `isFullId` (`claude-opus-5-6`) is NOT known → native (C10; refines the gated pick "unknown name → native": known = the router's table). `fullId(cfg, token)`: `hasKey(cfg.models, bare) ? cfg.models[bare] + (ONE_M.test(token) ? '[1m]' : '') : token`. NEVER `canonical()` (it strips `[1m]`, C11/R14/S6).
  - dialog: `askOr($, question, MODEL_SCOPES)` (S1: its LATER on a rejected dialog is the cancel; headless is already gated). Question text (ends with "where?"): `Switch main to <fullId> where?` preceded by one line per option: `This project: .claude/settings.local.json of this repo (wins at launch) + route now · This conversation: route now, nothing written · Everywhere: user settings.json, every project`; when the local file already holds a string `model` (read inside the slot through `readLocalSettings`, a cause word = no note, value through `clean(v, 60)`), one more line BEFORE the final question line: `Note: this project pins <that id> in .claude/settings.local.json: at launch here, the project pin wins over Everywhere` (C4b/R7, K9). Answer not in `MODEL_SCOPES` (LATER, free text) → `{ text: 'model: no scope chosen, nothing changed' }`.
  - `MODEL_SCOPES = [PROJECT_SCOPE, CONVERSATION, EVERYWHERE] as const` with `PROJECT_SCOPE = 'This project'` (comment: differs from `THIS_PROJECT` 'This project only', the first-use dialog's label; both fixed by their contracts) and `CONVERSATION = 'This conversation'`; reuse `EVERYWHERE` (S5).
  - branches (after `st.modelAnswered = true` for the first two):
    - `This conversation` → `stickyModel(st, bare)`; text = `model: sticky route ${bareFull} for this conversation` + ONE_M note + `\n` + `await show($, st)`. `bareFull` = the table id without `[1m]`; ONE_M note = ` ([1m] follows the session's variant)` whenever the token or the session model carries `[1m]` (K3: `route.model` cannot hold `[1m]`, `moveTo` carries the SESSION's variant, so the headline never promises `[1m]` the route cannot deliver; the file keeps the verbatim id).
    - `This project` → `const w = await writeLocalModel($, fullId)`; `stickyModel(st, bare)`; `ok = w === 'written' || w === 'created'`; text = (ok ? `model: ${fullId} written to .claude/settings.local.json (remove its "model" key to undo)` + (`w === 'created'` ? `, file created: keep it gitignored` : '') : `model: .claude/settings.local.json not written (${w})`) + `; sticky route ${bareFull} set` + ONE_M note (K3, below) + `\n` + `await show($, st)` (K12: awaited). On a cause word also `$.ui.toast(\`settings.local.json not written: ${w}\`)`.
    - `Everywhere` → `dropStickyModel(st)` (C4a/R3: a sticky model from an earlier answer would route main back after the native switch) then `return next(e)`; runMain is dropped by the native PostModelSwitch as today.
    - Post-answer section (the three branches) inside `try { … } catch (err) { failOnce or warnOnce; return { text: \`model failed (${errWord(err)}); the file write or the sticky route may have landed: check /route show and .claude/settings.local.json\` } }` (K5/K6).
  - `stickyModel(st, bare)`: `st.userMain = { phase: 'custom', route: { model: bare, ...(effort kept) }, source: 'user', ...(explicitEffort kept) }` where effort/explicitEffort come from the previous `st.userMain` (R11: a `/route effort=max` survives, native `/model` never touched effort); `st.runMain = null` (C6/R4: the two non-native answers mirror the native user switch, so "a user `/model` drops the run slot" stays true); `refresh($, st)`. `bare` routes without `[1m]`: `moveTo` (l.1206) carries the variant from the session model (C1).
  - `dropStickyModel(st)`: drop `route.model` AND `route.tier` from `st.userMain` (K10: `routeName = tier ?? model`, a sticky `/route plan` tier would upgrade main back); keep the effort if any, else `st.userMain = null`.
  - `writeLocalModel($, id): Promise<'written' | 'created' | string>` (string = a FIXED cause word, never `err.message`/`String(err)`: R6; causes: `project root unknown`, `.claude is a link`, `not a regular file`, `not JSON`, `not an object`, `too large`, `fs error <errWord>`):
    1. `root = await $.session.root()` (throw → `project root unknown`).
    2. `dir = ${root}/.claude`, `path = ${dir}/${LOCAL_SETTINGS_NAME}` (`LOCAL_SETTINGS_NAME = 'settings.local.json'`). `if (await $.fs.exists(dir))`: `st = await $.fs.stat(dir)` (reject → `fs error <errWord>`); `st.isLink` → `.claude is a link`; `st.kind !== 'dir'` (FsStat kinds are `file | dir | other`, K2) → `.claude is not a directory`. Absent → OK (`$.fs.write` creates it) (R5: the project tree is untrusted, BDR-116(3)).
    3. `readLocalSettings($, path)` (shared with the pre-dialog Note, K9; never throws, returns `{ data, created } | string`): `!(await $.fs.exists(path))` → `{ data: {}, created: true }` (absent is ONLY a false `exists`, K7); `stat = await $.fs.stat(path)` (reject → `fs error <errWord>`); `stat.isLink` → `settings.local.json is a link`; `stat.kind !== 'file'` → `not a regular file`; `stat.size > MAX_CONFIG_BYTES` → `too large`; `text = await $.fs.read(path)` (reject → `fs error <errWord>`); `JSON.parse` throw → `not JSON`; `!isRecord` → `not an object`. Own small reader instead of `readLayer` (K8: its log text folds I/O and syntax errors; the cause words here are fixed by the checks themselves).
    4. `data.model = id`; `await $.fs.write(path, JSON.stringify(data, null, 2) + '\n')` (fs throw → `fs error <errWord(err)>`). Return `created ? 'created' : 'written'`. SUCCESS = `'written' || 'created'` (K1); the toast fires only on a cause word.
- `mods/model-router/hooks/register.test.ts` (kit changes NAMED, C5/R12/S3):
  - `installWrite`: allow exactly `${ROOT}/.claude/settings.local.json` with or without a prior read; every other non-routing path stays loud (`expect(...)` unchanged for them). `slot()` maps that path to `'local'`.
  - `World`/`Fixture`: `surfaces: readonly string[]` (default `['terminal']`), `installWorld` adds `on('session.surfaces', () => ({ value: w.surfaces }))`; a `dirs: Map<string, { kind: 'dir' | 'file' | 'other'; isLink: boolean }>` the world's `fs.exists`/`fs.stat` answer for paths WITHOUT file text (K11: today stat throws for them), so `${ROOT}/.claude` can be an existing dir, a link, or a file.
  - a bottom `on('command.run', { command: 'model' }, () => ({ text: 'native' }))` installed per test (or a `NATIVE` plugin like `PROBE`) to witness the passthrough; `modelCmd($, args, origin?)` helper mirroring `route()`.
- `lib/effort-shift.md`: l.40 "a user `/model` drop it" → keep, then add to "Run slot and levers": `/model <name>` typed asks the scope (This project = `.claude/settings.local.json` + sticky model route, This conversation = sticky route only, Everywhere = the native write to user settings.json, every project); the two non-native answers set a sticky model route and drop the run slot like a native switch; Esc = nothing changes; no args, an unknown name or a headless run = native. l.53 "A user `/model` only moves the baseline" gets "(Everywhere; the two other scopes set a sticky route, which the classifier never overrides)". ≤ 80 cols.
- `README.md` (S8, in scope, two edits): l.139 "a user `/model`" → "a user `/model` (typed with a name it asks the scope: this project, this conversation, everywhere)"; the writes bullet ("Only a dialog answer, `/route ask on|off` or `/route forget` writes `routing.json`") gains ", and `/model <name>` → This project writes `model` into the project's `.claude/settings.local.json`".
- `register.ts` l.75 comment (`only a skill, /route clear|off or a user /model write or drop it`) stays true (runMain dropped on every answer path).

## Edge cases
- `/model fable[1m]`, `/model claude-fable-5-1[1m]`: bare `fable`/`claude-fable-5-1` is known → dialog; file gets `claude-fable-5-1[1m]`; `stickyModel(st, bare)` stores the BARE TOKEN as `/route model=` does (`fable` or `claude-fable-5-1`, K4); the session's `[1m]` is carried by `moveTo`, the token's is not promised. Tests for both (C1/R2).
- `haiku[1m]` → native (K13).
- Worktree session: `$.session.root()` follows the worktree, so "This project" writes that worktree's `.claude/settings.local.json`; named as a limit in effort-shift.md (K14), not handled.
- `.claude/settings.local.json` holds `null`, `[]`, `"x"` → `not an object`, nothing overwritten, route only (C8/S2).
- `.claude` or the file is a symlink → refused, nothing written, route only (R5).
- Dialog answered, then `show` throws → `.catch` returns `{ text: 'model failed …' }`, native never runs (C3).
- Free text under Other → cancel, same text as Esc.
- Headless (`surfaces()` = `[]`) → passthrough, no dialog.
- The sticky route may be HELD by `decideMain` caps (switch off, cold read > cap): the output never claims "routed now"; the appended `show` line tells the truth (C9/R10).
- `[deferred 2026-10-25]` R13: whether the engine gitignores a `settings.local.json` it creates is unverified; the output's "keep it gitignored" note stands in. R15 / C12: whether a live `model` change in the local file hot-switches the session (ConfigChange `local_settings`) is unverified → LRN-212 live check after the suite: after "This project", no PostModelSwitch, no down mark; output wording stays neutral ("written to", never "next launch").

## Tests (register.test.ts, "model command" block)
- asks the three scopes in order with header `model-router` for `/model fable` and for `/model claude-fable-5-1[1m]`; question names the full id; native not run.
- This project: writes `model` (full id, `[1m]` verbatim), keeps other keys (`permissions` fixture), `userMain.route.model` = bare token, `runMain` null, native not run, output names the file. Positive control with `${ROOT}/.claude` present as `{ kind: 'dir' }` (K2).
- This project: in a `[1m]` session and in a plain session, the output carries the `[1m] follows the session's variant` note only when the token or the session has it (K3).
- This project: creates the file when absent (success text + `file created: keep it gitignored`, no toast) (K1).
- This project: `null` / array file → `not an object`, file unchanged, route set, toast.
- This project: `.claude` link / `.claude` regular file / settings file link → refused with the matching cause word, file untouched; `exists` true but `stat` rejecting → `fs error`, file untouched (K7).
- This project: fs.write throws → `fs error …`, route set.
- This conversation: route = `/route model=` equivalent, sticky effort from a prior `/route effort=max` kept, nothing written, native not run.
- Everywhere: native run with args unchanged; a prior sticky model dropped (sequence: conversation X → everywhere Y → `userMain.route.model` undefined).
- passthrough, no question: no args; two tokens; `default`; `claude-opus-5-6` (shape only); `haiku[1m]`; sdk origin; `st.off`; `st.asking` set; `surfaces = []`.
- question carries the project-pin note when the local file holds `model`, not otherwise (K9).
- Everywhere after `/route plan` (sticky tier) drops the tier too (K10).
- dismissed → cancel text, nothing written, nothing routed, native not run.
- post-answer throw → `model failed …` text naming `/route show`, native not run (make `ui.status` throw from the world: `refresh` inside `stickyModel`; `session.usage` is swallowed by `readTokens`, K12).

## Disposition (STEP 0.6)
- honors BDR-116 (composer-only writers; model never writes; project tree untrusted) by gating on `origin.kind === 'composer'`, refusing links, writing only the file the user chose.
- honors BDR-125 amendment 8 by making `.claude/settings.local.json` the "This project" target and leaving the native user-settings write to "Everywhere".
- honors BDR-115/LRN-203 (full ids in anything a hook writes) via `fullId()`; never `canonical()`.
- honors LRN-098 (`/model` rewrites settings.json) by naming the user-settings write in the Everywhere option and by never reaching native after an answer.
- applies LRN-212 (hot-loaded working-tree mod) for the live check named above.
