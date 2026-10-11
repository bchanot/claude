# CONTRACT — model-router-w4a-logs-residuals
- date: 2026-10-11 | flow: feat | branch: feature/model-router-w4
- status: active

## REQUEST (verbatim — IMMUTABLE)
okm j'aimerais que tu corrige donc les residus techniques, et aussi que tu fasse cette wave optionnelle du classifieur. Et aussi, pour le moment on a beaucoup de log avec le mod de la route, par exemple [pasted: "model-router: step 3 answered by claude-sonnet-5-5", "model-router: step 18 agent af0b3fa5: claude-opus-5-5/xhigh → claude-opus-5-5/xhigh", "model-router: step 0 main: claude-fable-5-1/high → claude-fable-5-1/high" …] , est-ce auil y a moyen de reduire ces log la a juste on dit quand on chane de model / effort et 2 ou 3  mots de contextes. eviter les repetitions de model-router step. juste direm ah la on switch de ca a ca car blablabla.

## CLARIFICATIONS
(pass A: none. Split: W4-A = residuals + transition logs (this contract); W4-B = the prompt classifier (own contract))
Q: public shape (after the simplicity lens, orchestrator default, user may veto): `verbose` stays a boolean; `true` logs TRANSITIONS only ("model-router: <main|agent <type>>: <from> → <to> (<phase>: <cause>[, <model cause>])"); the four verbose stream lines (step, answered by, spawn, route-tool JSON, skill path) are removed, no `trace` level; `/route verbose on|off` unchanged [stated 2026-10-11]
Q: the "auto mode: use Bash/sed instead of Edit/Write" block attributed to the mod / A: traced by reading: it is the harness's own auto-mode instruction rendered right after the mod's MCP-instructions block; not in mods/model-router source; closed, no change [resolved 2026-10-11]

Q: the hand-off line fires on every rowed or explicit spawn, even when the pair equals main's (a dispatch is a hand-off) / A: accepted [stated 2026-10-11]

Q: three `clean()` sites are unreachable by construction (phases pass PHASE_KEY at load; `kept.to` equals a live slot's phase): kept as defence in depth without a test / A: accepted [gated 2026-10-11]
Q: the host prefixes every `$.ui.log` line with the plugin name (seen in the user's terminal): the new lines carry no literal "model-router: " prefix; the pre-existing warnings are left as they are [stated 2026-10-11]

Q: GATE 1 cap (verifier ECARTS(3): dedupe key + double prefix real, then coverage ×2; 358 kit tests) / A: user "Accepter et commiter"; security PASS then two MEDIUM (raw skill names in two lines) fixed with tests, no re-scan (two clean() calls); LOW parked: JSON parse error text in the load log, `logCall`/`noteMain` ui calls outside `safely` [gated 2026-10-11]

## ACCEPTANCE CRITERIA
1. `verbose: true` logs only transitions: main → one line per turn per (from → to) when the planned (model, effort) pair differs from main's previous plan (after /clear: from the engine input), built from the decision itself (effort cause = the slot that supplied it: `skill /<name>`, `route tool`, `sticky /route`, `prompt floor`, `dispatch`, `session`; model cause = the decision's why when the model moved: `upgrade`, `fallback: <alias> down`, `switch`), emitted inside `safely` BEFORE `next` (a log failure never unroutes a step); agent → one hand-off line per dispatch, deduped per turn per (type, to): "main <from> → agent <type> <to> (<model cause>, <effort cause>)" with causes `row <phase>` | `explicit` | `fallback: <alias> down` | `frontmatter` and `row` | `explicit` | `engine`, then one line per later effort move on that loop (`route tool`, `skill <name>`); a prompt-rule route reads "(<phase>: prompt rule)"; names cleaned (≤ 40 code points); no "step N" lines, no "answered by" lines, no spawn/route-JSON/skill-path lines at any level. `false` logs nothing but the existing warnings (`warnOnce`, `logCall`, `tierDownLog`, engine switch, config drops). One kit test per clause.
2. An agent answering on a model other than the planned one (canonical ids compared, `usage` null skipped) is logged once per (agent, model) at `true` ("model-router: agent verifier answered by opus instead of sonnet"); never for a `[1m]` suffix alone; main is not covered (the engine switch line exists). One kit test per clause.
3. Config: `verbose` stays boolean; an invalid override value (`"ON"`, 1, null) falls back to the default `false` with one log per load; `/route verbose on|off`, `/route show` and the session toggle unchanged. One kit test per clause.
4. Residuals closed (W3-C security + W3-B + W3-A): (a) `forget not applied` sends `String(err)` to `$.ui.log` and answers a generic text; (b) every file-sourced fragment in a forget answer (`from`, `to`, keys) passes `clean(…, 40)`; (c) `floorFile` returns undefined unless `SKILL_NAME` matches the name; (d) `restoreOf` refuses `__proto__` (plan and apply agree); (e) the `changed` scan is limited to ROWS (phases never restored); (f) a dialog Change offers and targets only SHIPPED phases (code defaults + the validated phases of routing.json, the machine override excluded), so a machine-only phase is never offered nor written into the tracked file; the empty case toasts "no shipped phase uses <alias>: add one to routing.json" → Later; (g) a failure AFTER the user answered keeps the key in `asked` (no re-ask every use; the next session asks again), a failure before the answer still leaves it unasked (that half judged by reading: the kit skips a throwing hook, no seam exists between `asked.add` and the answer [gated 2026-10-11]). One kit test per clause, each failing if its guard were removed.
5. Kit suite, mods suite, validate and census green.
   CHECK: cd mods/model-router && out="$(claude plugin test . 2>&1)" && printf '%s\n' "$out" | grep -qE '[0-9]+ pass' && ! printf '%s\n' "$out" | grep -qE '[1-9][0-9]* fail' && claude plugin validate . 2>&1 | grep -q 'passed' && cd ../.. && make test suite=lib/tests/mods.test.sh 2>&1 | grep -q 'all suites green' && bash lib/tests/effort-routing.test.sh >/dev/null 2>&1 && echo W4A-GREEN
   EXPECT: W4A-GREEN
   EVIDENCE: MET exit=0 marker-found :: W4A-GREEN
6. Docs: README (its three `verbose` sites say "transitions only"), USAGE (`/route` row), CHANGELOG Unreleased (Changed: transition logs; Fixed: the residuals), `lib/effort-shift.md` unchanged or ≤ 1 line.
   CHECK: grep -qi 'transition' README.md && grep -qi 'transition' USAGE.md && grep -qi 'transition' CHANGELOG.md && echo W4A-DOCS
   EXPECT: W4A-DOCS
   EVIDENCE: MET exit=0 marker-found :: W4A-DOCS

## FILE SCOPE
mods/model-router/hooks/register.ts, mods/model-router/hooks/register.test.ts, README.md, USAGE.md, CHANGELOG.md (one clause each), lib/effort-shift.md (≤ 1 line)
