# CONTRACT — model-router-w4b-classifier
- date: 2026-10-11 | flow: feat | branch: feature/model-router-w4
- status: active

## REQUEST (verbatim — IMMUTABLE)
okm j'aimerais que tu corrige donc les residus techniques, et aussi que tu fasse cette wave optionnelle du classifieur. [earlier, same day: "est-ce quil y a une comande pour clear…"; "tu me dit le routing de tout skills et agents, mais c'est valable aussi pour la conversatio principale ? Si tu invoaue ni skill ni agebt il faut que ca route aussi on est d'accord ?" → orchestrator: the plain conversation routes only through prompt keywords, ultrathink, derived orchestrate and the route tool; the missing piece is the planned haiku classifier on each typed prompt → user chose it]

## CLARIFICATIONS
(pass A: none — the W1 plan § W3.2 and the 2026-10-11 exchange define outcome and scope)
Q: public shape (after three lenses, orchestrator default, user may veto): labels `design | analysis | coding | bookkeeping | chat` mapped to plan / reflect / implement / apply / none; the classified phase becomes the TURN DEFAULT route carrying its EFFORT ONLY (never a model move), and only when NO route is in force (no typed skill, no run slot, no route tool, no sticky `/route`, no floor, no keyword rule, not mid-turn, composer only); no first-use dialog on it (visibility: status line `route: classifier <phase>` and the transition line with `/route verbose on`); `classify` is a machine config key (default `true`, `"classify": false` in `~/.claude/model-router.json` turns it off) with a session toggle `/route classify on|off`; the call is bounded to 3 s and pauses for `cooldownMinutes` after 3 failures; one small-model call per typed prompt of ≥ 12 characters [stated 2026-10-11]

Q: the abort paths (`next.signal.aborted` first in the catch and after the await; classify's own `aborted` cause not counted) cannot be driven by the kit (no abortable dispatch, a throwing bottom hook becomes "no implementation") / A: judged by reading; the live check covers the rest [gated 2026-10-11]

## ACCEPTANCE CRITERIA
1. On a composer `prompt.submit` with `classify` on, not mid-turn, a trimmed text ≥ 12 chars not starting with `/`, no prompt rule matched and NO route in force on main (no sticky, turn, run or floor), the mod calls `$.model.classify(<first 500 + last 1500 chars>, [design, analysis, coding, bookkeeping, chat])` once, with no `model` option, and writes the turn route `{ effort }` of the mapped phase with source `classifier` (`chat` or an unknown label → nothing); it never runs for a sub-agent prompt, a non-composer origin (so never under `-p`), mid-turn, with the mod off, with `classify` off, when a rule matched, or when a route is in force. One kit test per clause (a bottom `model.classify` mock).
2. The classified route is turn-scoped (gone at `turn.complete`), carries the effort only (the main model never moves because of it: no tier), may lower the effort (coding → medium, bookkeeping → low), is replaced by any later route tool call or typed skill in the turn, and is ignored at a step whose engine effort differs from the session's baseline (a user `/effort` beats it). One kit test per clause.
3. Bounded and fail-safe: the call races a 3 s `$.clock.sleep` (timeout → no route, counts as a failure); a user interrupt (`next.signal.aborted`) neither counts nor writes; every guard is re-checked after the await (a route landing meanwhile wins); a rejection or timeout counts, three in a row pause the classifier for `cooldownMinutes` (×60000, kept across `/clear`, cleared by `/route reload`) with one toast and a status marker, a settled answer resets the counter; an unknown label neither warns nor counts; the classifier is skipped while the haiku id is marked down or the main loop runs on haiku. The prompt always proceeds. One kit test per clause.
4. No dialog and no file write: a classified route opens no first-use dialog and never writes routing.json. One kit test (no `ui.ask`, no `fs.write` on a classified prompt).
5. Config and command: `classify` is a Config key (default `true`) read from the machine override through `pickSwitch` (invalid → default + one log); `/route classify on|off` is a session toggle (composer only) that survives a rebuild like `switch`/`verbose`; `/route show` prints `classify: on|off` on the `router:` line; the argumentHint lists it. One kit test per clause.
6. Visibility: the status line reads `route: classifier <phase>` and the main transition line "(<phase>: classifier)" (with verbose on). One kit test per clause.
7. Kit suite, mods suite, validate and census green.
   CHECK: cd mods/model-router && out="$(claude plugin test . 2>&1)" && printf '%s\n' "$out" | grep -qE '[0-9]+ pass' && ! printf '%s\n' "$out" | grep -qE '[1-9][0-9]* fail' && claude plugin validate . 2>&1 | grep -q 'passed' && cd ../.. && make test suite=lib/tests/mods.test.sh 2>&1 | grep -q 'all suites green' && bash lib/tests/effort-routing.test.sh >/dev/null 2>&1 && echo W4B-GREEN
   EXPECT: W4B-GREEN
   EVIDENCE: MET exit=0 marker-found :: W4B-GREEN
8. Docs: README (`classifier` paragraph in the model-router section: what, cost, `/route classify`), USAGE (`/route` row + one sentence in "Niveau d'effort"), CHANGELOG Unreleased Added, `lib/effort-shift.md` (≤ 2 lines).
   CHECK: grep -qi 'classif' README.md && grep -qi 'classif' USAGE.md && grep -qi 'classif' CHANGELOG.md && grep -qi 'classif' lib/effort-shift.md && echo W4B-DOCS
   EXPECT: W4B-DOCS
   EVIDENCE: MET exit=0 marker-found :: W4B-DOCS
9. Live check (orchestrator + user, after the gates, `[gated]`): a few plain prompts typed in the terminal, each with the label it got (status line `route: classifier <phase>`, transition line with verbose on); drop `bookkeeping` if it misfires.

## FILE SCOPE
mods/model-router/hooks/register.ts, mods/model-router/hooks/register.test.ts, README.md, USAGE.md, CHANGELOG.md, lib/effort-shift.md, lib/tests/effort-routing.test.sh (only if a lock needs it)
