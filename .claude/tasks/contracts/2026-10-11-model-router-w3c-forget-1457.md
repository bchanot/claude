# CONTRACT — model-router-w3c-forget
- date: 2026-10-11 | flow: feat | branch: feature/model-router-confirm (continues W3-A/B before their merge)
- status: active

## REQUEST (verbatim — IMMUTABLE)
d'ailleurs est-ce quil y a une comande pour clear les decision prise ? si jamais cest un user aure que moi si il peut clean me decisions de routage ?
[orchestrator proposal: `/route forget <nom|all|projects>` + an optional per-user decisions file] → "seulement le forget"

## CLARIFICATIONS
Q: scope / A: `/route forget` only; no per-user decisions file (the tracked routing.json stays the shared memory; another user inherits and may forget) [gated 2026-10-11]
Q: public shape (orchestrator default, user may veto): `/route forget <name>` (a skill row, an agent row or a phase), `/route forget all`, `/route forget projects`; forgetting a changed row RESTORES it to its shipped phase (`changed.from`); the frontmatter floors are never touched (the answer says so when a changed row is restored) [stated 2026-10-11]

Q: GATE 1 cap (verifier ECARTS(2) incl. one real defect `ForgetPlan` → `Plan`, then ECARTS(2)/(2) coverage only; 284 kit tests) / A: user "Accepter et commiter"; security PASS (1 MEDIUM + 4 LOW parked in TODO); live T3 Keeps on orchestrate and escalate seen during the run [gated 2026-10-11]

## ACCEPTANCE CRITERIA
1. `/route forget <name>` (composer only, exactly one argument): for every kind (skills, agents, phases) removes `confirmed.<kind>.<name>`; restores a `changed` row to its `from` only when `from` is a string, the row exists, equals `changed.to` and `from` is a known phase (else the entry is kept and the answer says why); removes every `projects[*].<kind>.<name>` (emptied tables pruned); drops the key(s) from this session's asked set; nothing removed and nothing asked → "nothing to forget for <name>" with NO write; key only asked this session → reset, no write; refused while a dialog is open; two words → usage. One kit test per clause (folded where one setup proves two).
2. `/route forget all` and `/route forget projects` ASK FIRST (engine dialog, options Cancel / Forget, Cancel first; anything else, dismissed or headless = cancelled, nothing written; skipped when there is nothing to forget; the forget holds the single-dialog slot while asking): `all` empties `confirmed`, `changed` (rows restored under the same guards) and `projects` and clears the asked set; `projects` empties only `projects`. One kit test per clause.
3. Writes go through the existing writer only (`writeRouting`: serialized, size-capped, refused when the file is absent or unparsable with the existing toast, config rebuilt after the write); the model (route tool, prompt rules, sub-agents) can never trigger a forget; a non-composer origin is refused like the other `/route` writes. Judged by reading + one kit test (route tool cannot forget) + the existing origin test extended.
4. One answer formatter: "forgot <label>: <c> confirmed, <m> row(s) restored, <k> project exception(s) removed"; a restored row adds "(<kind>.<name> → <from>: <alias> at <effort>; if <agents/<name>.md | skills/<name>/SKILL.md> was aligned to <to>, set model: <alias>, effort: <effort> and its lock in lib/tests/model-routing.test.sh, then `make test`)" (no file clause for a built-in agent: Explore, Plan); "; ~/.claude/model-router.json still sets <name> and wins here" when the machine override pins it; "; current run may keep <phase>: /route clear to apply" when the run slot came from a restored skill row [wording per plan r3, gated 2026-10-11]; write outcomes: refused → "nothing saved", rebuild failure after a landed write → "saved, config not rebuilt: /route reload". Write outcomes: refused → "nothing saved", rebuild failure after a landed write (dedicated error) → "saved, config not rebuilt: /route reload", any other failure → "forget not applied". One kit test per text.
5. `lib/effort-shift.md` names `/route forget` in ≤ 2 changed lines; README.md, USAGE.md and CHANGELOG.md no longer claim that only a dialog answer or `/route ask` writes routing.json (one clause each naming `/route forget`); the register.ts writer comment says the same; `/route pending` lists a forgotten key again.
   CHECK: grep -q 'forget <name|all|projects>' mods/model-router/hooks/register.ts && grep -q '/route forget' lib/effort-shift.md && [ "$(wc -l < lib/effort-shift.md)" -le 66 ] && grep -q 'route forget' README.md && grep -q 'route forget' USAGE.md && grep -q 'route forget' CHANGELOG.md && ! grep -q 'Only a dialog answer or `/route ask on|off` writes' README.md && echo W3C-DOC
   EXPECT: W3C-DOC
   EVIDENCE: MET exit=0 marker-found :: W3C-DOC
6. Kit suite, mods suite and validate green; the census stays green on the shipped file.
   CHECK: cd mods/model-router && out="$(claude plugin test . 2>&1)" && printf '%s\n' "$out" | grep -qE '[0-9]+ pass' && ! printf '%s\n' "$out" | grep -qE '[1-9][0-9]* fail' && claude plugin validate . 2>&1 | grep -q 'passed' && cd ../.. && make test suite=lib/tests/mods.test.sh 2>&1 | grep -q 'all suites green' && bash lib/tests/effort-routing.test.sh >/dev/null 2>&1 && echo W3C-GREEN
   EXPECT: W3C-GREEN
   EVIDENCE: MET exit=0 marker-found :: W3C-GREEN

7. Live smoke (orchestrator + user, after the gates, recorded `[gated]`): one `/route forget` typed in the terminal opens its dialog (`$.ui.ask` from an immediate command) and the answer lands in routing.json.

## FILE SCOPE
mods/model-router/hooks/register.ts, mods/model-router/hooks/register.test.ts, lib/effort-shift.md, README.md (one clause), USAGE.md (one clause), CHANGELOG.md (one clause under Unreleased)
