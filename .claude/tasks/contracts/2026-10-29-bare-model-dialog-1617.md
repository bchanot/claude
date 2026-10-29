# CONTRACT — bare-model-dialog
- date: 2026-10-29 | flow: feat | branch: feature/bare-model-dialog (off develop 9a20ca7)
- status: active

## REQUEST (verbatim — IMMUTABLE)
"quand je fais un /model ça change pas le fable 5.1 comme ça devrait" → (after the /bugfix test) "ça prompt bien la question. il faut que ça soit systématique" → option A chosen: "A. et oui tu dois faire le feat"

Option A as presented (2026-10-29): a bare `/model` opens the mod's own dialog in two steps: (1) which model, from the router's table (Fable 5.1, Opus 5.5, Sonnet 5.5, Haiku 5.5, with [1m] variants) plus an "Other model (native picker)" entry; (2) the scope question This project / This conversation / Everywhere. It always asks, the current model included. Everywhere runs the native command; non-Anthropic models and anything outside the table stay reachable through the native entry.

## CLARIFICATIONS
Q: root cause of the report? / A: /bugfix diagnosis 2026-10-29: picking the model already active in the native picker fires no PreModelSwitch (nothing to switch) → no question, project pin stays; a different-model pick asks (user-run: "Model switch to Sonnet 5.5 was blocked by a PreModelSwitch hook"). Gateway-id normalization dropped (3 lenses FATAL: logged-out OpenRouter session, would switch on automatic routing). Plan `.claude/tasks/plans/2026-10-29-picker-gateway-ids-1523.md` superseded.
Q: step 1 rows? / A: with [1m] variants: `fable (best)`, `fable [1m]`, `opus (big)`, `opus [1m]`, `sonnet (work)`, `sonnet [1m]`, `haiku (cheap)`, `Other model (native picker)` (labels from modelLabel; tier name in parentheses as the table says). [gated 2026-10-29]
Q: Escape at step 1? / A: nothing changes, text `model: no model chosen, nothing changed`. [gated 2026-10-29]

Q: the engine's `$.ui.ask` takes 2-4 labels (3 lenses BLOCKER on the 8-row layout): which layout? / A: step 1 `fable (best)`, `opus (big)`, `sonnet (work)`, `Other model (native picker)` (haiku through the native picker or `/model haiku`); step 2 `Standard` / `[1m]`; step 3 the scope question. Supersedes the 8-row answer above. [gated 2026-10-29]

## ACCEPTANCE CRITERIA
1. [gated 2026-10-29, layout] A bare `/model` (composer origin, router on, surface present, no dialog open) asks step 1 with exactly `fable (best)`, `opus (big)`, `sonnet (work)`, `Other model (native picker)` in that order, header `model-router`, text naming the session model and ending `Which model?`; a table row then asks `Standard` / `[1m]` (text ending `?`); no ask ever carries fewer than 2 or more than 4 options (the test kit refuses it); native is not run before an answer.
2. The variant answer then asks the existing scope question (scopeDialog, same three scopes and texts) for the token (`opus`, `opus[1m]`, …), even when it is the session's current model.
3. This project writes the token's full id (`[1m]` kept verbatim: opus + `[1m]` → `claude-opus-5-5[1m]`) into `.claude/settings.local.json` and sets the sticky route; This conversation sets the route only; Everywhere runs the native `/model` with args = the token; none of these runs native with empty args.
4. `Other model (native picker)` runs native with the original empty args (the native picker), no scope question, with the dialog slot already free (a pick inside that picker is held and asks its scope, never the BUSY toast); a native throw there returns a text and native is not run again.
5. Escape / dismiss / free text at step 1 or 2: text `model: no model chosen, nothing changed`, native not run, no scope question, nothing written, no route change.
6. Unchanged: `/model <name>` typed (scope dialog as today), the PreModelSwitch picker hold (handlePicker), and every native passthrough except the empty-args case (`fable opus`, `default`, `opusplan`, unknown ids, `haiku[1m]`, another origin, router off, no surface, a dialog already open → native, no question).
7. lib/effort-shift.md and README.md describe the bare `/model` dialog (Other model = native picker, Esc changes nothing) and no longer list "no args" among the native passthroughs; CHANGELOG [Unreleased] carries the change. [gated 2026-10-29: README + CHANGELOG added]
   CHECK: grep -q 'Other model (native picker)' lib/effort-shift.md && ! grep -q 'Picker Default, no args' lib/effort-shift.md && ! grep -q "Default, no args" README.md && grep -q 'bare `/model`' CHANGELOG.md && echo DOC-OK
   EXPECT: DOC-OK
   EVIDENCE: pending
8. Mod suite green (register.test.ts through `claude plugin test`) and the full suite green.
   CHECK: make test 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: pending
9. Live proof (controller, after `/reload-plugins`, user-run): bare `/model` shows step 1; opus → `[1m]` → This project → `.claude/settings.local.json` `model` becomes `claude-opus-5-5[1m]`. If the engine never routes a bare `/model` through `command.run`, this criterion fails and is reported, not worked around.

## FILE SCOPE
mods/model-router/hooks/register.ts, mods/model-router/hooks/register.test.ts, lib/effort-shift.md, README.md, CHANGELOG.md [gated 2026-10-29], .claude/tasks/contracts/2026-10-29-bare-model-dialog-1617.md, .claude/tasks/plans/2026-10-29-bare-model-dialog-1617.md
