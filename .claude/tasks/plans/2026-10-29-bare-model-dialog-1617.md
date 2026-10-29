# Plan r2 — bare `/model` opens the router's dialog (feat)

Contract: `.claude/tasks/contracts/2026-10-29-bare-model-dialog-1617.md`. r1 had 8 rows in one `$.ui.ask`: the engine takes 2-4 labels (claude-code.d.ts:468, :2122; repo fact w3b plan l.7) → 3 lenses BLOCKER; user re-gated the layout 2026-10-29 (3 steps below).

## Approach
- Constants (register.ts, near MODEL_SCOPES ~201): `NATIVE_PICKER = 'Other model (native picker)'`, `NO_MODEL = 'model: no model chosen, nothing changed'`, `BARE_ALIASES = ['fable', 'opus', 'sonnet']`, `STANDARD = 'Standard'`, `LONG = '[1m]'`.
- ONE guard in `handleModelCommand` (~2348): `const bare = token === ''` (`''.trim().split(/\s+/)` = `['']`, so `tokens.length === 1`); passthrough when `st.off || origin !== 'composer' || tokens.length !== 1 || (!bare && !knownModel(st.cfg, token)) || no surface || st.asking !== null`. Same slot `st.asking = \`model:${token}\``, same try/finally.
- Inside the try: `bare` → `await bareModelDialog($, st, e, next)`; else the existing `scopeDialog` call unchanged.
- `bareModelDialog` returns a `CommandRunResult` or the marker `'native'`:
  - Step 1: `askOr($, text1, [...BARE_ALIASES.map(a => modelLabel(st.cfg, a)), NATIVE_PICKER])` with `text1 = \`Session: ${clean(st.sessionModel || 'unknown', 60)}\nWhich model?\``. Answer = NATIVE_PICKER → `'native'`; a label of BARE_ALIASES → that alias; anything else (Later, free text) → `{ text: NO_MODEL }`.
  - Step 2: `askOr($, text2, [STANDARD, LONG])`, `text2 = \`${STANDARD}: standard context · ${LONG}: 1M context (a conversation route follows the session's variant)\nWhich variant of ${alias}?\``. STANDARD → token `alias`; LONG → `alias + '[1m]'`; anything else → `{ text: NO_MODEL }`.
  - Step 3: `scopeDialog($, st, token, { everywhere: () => next({ ...e, args: token }), warnKey: 'command.run model' })` (texts, scopes, note, file write unchanged).
- Back in `handleModelCommand`: on `'native'`, the slot is freed by the `finally` FIRST, then `try { return await next(e) } catch (err) { warnOnce(st, $, 'command.run model', errWord(err)); return { text: \`model: native picker failed (${errWord(err)})\` } }` — a pick inside the native picker then reaches handlePicker with a free slot (deny + scope question, not BUSY), and a native throw never re-runs native.
- Haiku: not in step 1 (4-label cap); reachable through the native picker row or a typed `/model haiku`.
- Test kit (register.test.ts ~236-252, `installDialog`): reject an AskUserQuestion whose options count is outside 2-4 (throw like an engine refusal), so a too-wide ask fails the suite.

## Edge cases
- Router off / sdk origin / `-p` (no surface) / a dialog already open → native with `''` (the native picker), no question.
- Free-text "Other" at step 1 or 2 → NO_MODEL, no toast.
- `[1m]` + This conversation → the route holds the bare alias; variantNote prints "([1m] follows the session's variant)" (token carries `[1m]`).
- `[1m]` + This project → `fullId` keeps `[1m]` verbatim in settings.local.json.
- The current session model is offered and asks the scope like any other (the point of the feat).

## Tests (register.test.ts, `/model` block ~6066)
1. bare `/model`: step 1 options exactly `['fable (best)', 'opus (big)', 'sonnet (work)', 'Other model (native picker)']`, header `model-router`, text ends `Which model?` and names the session id; `ran` empty.
2. opus → `[1m]` → This project: three questions; local `model` = `claude-opus-5-5[1m]`; `ran` empty.
3. opus (session OPUS) → Standard → This conversation: sticky route `claude-opus-5-5` (route show); `ran` empty.
4. Other model → `ran` = `['']`, one question; a second test whose native stub calls `pick($, SONNET)` before returning: the pick gets DENY and, after 300 ms, the scope question (not the BUSY toast).
5. dismiss at step 1 → NO_MODEL, one question, `ran` empty, no local file; dismiss at step 2 → NO_MODEL, two questions.
6. sonnet → Standard → Everywhere → `ran` = `['sonnet']`; sonnet → `[1m]` → Everywhere → `['sonnet[1m]']`.
7. `[1m]` + This conversation → output contains `[1m] follows the session's variant`.
8. native throw on the Other-model row → text `model: native picker failed (…)`, native ran once.
9. guards: the existing off / sdk / no-surface / dialog-open tests run `''` too (native `''`, no question).
10. 'no dialog for a call native owns': drop `''` from its args list.
11. kit: a direct `$.tool.call({ tool: 'AskUserQuestion', … })` with 5 options rejects (drives the kit hook itself, not `$.ui.ask`).

## Docs
- lib/effort-shift.md (44-56): after the first sentence add "A bare `/model` asks which model (fable, opus, sonnet, or `Other model (native picker)`, which opens the native picker; haiku goes through it or `/model haiku`), then Standard or `[1m]`, then the same scope question, the current model included; Esc changes nothing." Replace "Picker Default, no args, an unknown name or a run with no surface (`-p`) go native, no question." with "Picker Default, an unknown name or a run with no surface (`-p`) go native, no question."
- Keep the phrase `Other model (native picker)` on ONE line in every doc (the contract oracle greps a line).
- README.md:139 (triggers that ask the scope) and :146 (triggers of the project write): add the bare `/model` dialog.
- register.ts:2121-2122 section comment: name the bare `/model` dialog beside `/model <name>`.
- README.md:142: drop "no args" from the native-passthrough list and add one clause "a bare `/model` opens the router's model, variant and scope dialog".
- CHANGELOG.md [Unreleased]: one Changed line "model-router: a bare `/model` opens the router's dialog (model, variant, scope), so the scope question also comes when the pick is the current model (fable, opus, sonnet; a current haiku goes through `/model haiku`); `Other model (native picker)` keeps the native picker"; and fix the l.14 "no args" mention.

## Disposition
- supersedes BDR-126 on "no args → native picker untouched" (user option A, 2026-10-29); honors BDR-126/127 elsewhere (scopeDialog reused verbatim; picker hold kept, slot freed before the native picker so it still asks).
- honors LRN-231 (the dialog lives in command.run, never in PreModelSwitch).
- honors BLK-036 for fable/opus/sonnet (no silent user-settings write for a project intent); a current haiku keeps the gap through the native row, `/model haiku` covers it.

## Risk
Unverified live, first: that `$.ui.ask` awaited inside the `model` command.run hook draws in a real session (TODO.md:15 still lists the typed `/model <name>` live check as pending; LRN-231 froze in PreModelSwitch). User-run spike before code: `/model opus` typed.
Unverified live: that a bare `/model` reaches `command.run` before the engine draws its picker (the harness assumes it; contract criterion 9 proves it or reports the miss).
