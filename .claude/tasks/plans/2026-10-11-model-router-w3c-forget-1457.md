# PLAN r3 — model-router wave 3-C: `/route forget` (2026-10-11)

r1 → r2 after simplicity CONCERNS(3), correctness CONCERNS(4), robustness
CONCERNS(4); r2 → r3 after the confirmation (correctness CONCERNS(3)).
Precedence r3 > r2 > r1. Contract
`.claude/tasks/contracts/2026-10-11-model-router-w3c-forget-1457.md`.
Base W3-B (604a6c4 + 32b71d2 + 938c3d1). Corrected facts: `Memory` holds
ok/ask/askLocal/base/confirmed/about/local/key only (no `changed`, no
`projects`); the composer gate lives in `registerCommandHook`, not in
`handleCommand`; `writeNow` always writes once the patch ran and toasts
UPDATED, returns false on refusal, throws when the rebuild fails after a
landed write; `show` prints no command list (the only visible list is the
`argumentHint`); `routeMainBySkill` copies a route into `turnMain`/`runMain`
and a rebuild never touches those slots; the shipped file holds one changed
row (security-auditor verify → judge) whose frontmatter floor was aligned
to `opus`: restoring it without re-aligning the floor makes the census
FAIL (no `changed` entry = no WARN exemption).

## Behaviour (composer `/route forget <arg>`, exactly ONE argument)
- Parsing: no arg or more than one → "usage: /route forget <name|all|projects>".
  Reserved words `all` and `projects`; a row or phase named like them
  cannot be forgotten by name (answer says "edit routing.json by hand").
- Guard: while a dialog is open (`st.asking !== null`) → "answer the open
  dialog first", nothing written. The forget confirmation TAKES the slot
  itself (`st.asking = 'forget:<target>'` in a try/finally around `askOr`)
  so no first-use dialog opens under it and two forgets cannot stack.
- The decision runs on the FRESH file, twice: a PRE-read (after awaiting
  `st.writes`, so a landed Keep is visible) decides the no-write paths and
  the confirmation counts; the PATCH itself re-runs `forgetPlan(file,
  target)` on `writeNow`'s own freshly read `file` (the closure exports the
  counts actually applied; the answer reports those). Pre-read missing or
  unparsable → the writer's refusal path ("routing.json is missing or
  unreadable: nothing saved"); nothing to remove, no refused restore and
  the key(s) not in `st.asked` → "nothing to forget for <name>" / "nothing
  to forget", NO write; only a refused restore → its reason, NO write;
  key(s) only in `st.asked` → reset them, NO write, "asked again at the
  next use, nothing was saved" (when the key is decided by the machine
  override or a project row, say "still decided by …" instead).
- `<name>`: for EVERY kind in KINDS (skills, agents, phases): delete
  `confirmed.<kind>.<name>`; restore `changed.<kind>.<name>` → row =
  `from` ONLY when `from` is a string, the row exists, the row equals
  `changed.to`, and `from` is a phase of `file.phases` or
  `DEFAULT_CONFIG.phases` (else the entry is kept and the answer says
  why); delete `projects[k].<kind>.<name>` for every k, pruning an emptied
  kind table then an emptied `projects[k]`; then `st.asked.delete(key)`.
- `all`: the same over every entry of `confirmed`, `changed`, `projects`;
  `projects`: only `projects` emptied. Both ASK FIRST through `askOr`:
  "Forget <n> decision(s): <m> row(s) restored, <k> project exception(s)
  in <r> repo(s)?" options ["Cancel", "Forget"] (Cancel first; any other
  answer, a dismissed dialog or headless = cancelled, nothing written);
  skipped when every count is zero ("nothing to forget").
- Write: ONE `writeRouting` patch (the closure carries the counts out);
  outcomes: false → "nothing saved" (the writer's toast already explains);
  true → asked keys deleted, config rebuilt; a rebuild failure after a
  landed write is signalled by a dedicated error class (`RebuildFailed`,
  thrown by `writeNow` there and only there) → "saved, config not rebuilt:
  /route reload" (asked keys untouched); any other throw (patch, fs.write)
  → "forget not applied (<err kind>)", asked keys untouched.
- Answer, one formatter (used by every form, per restored row): "forgot
  <label>: <c> confirmed, <m> row(s) restored, <k> project exception(s)
  removed[, <j> restore(s) kept: <reasons>]" + per restored row " (<kind>.
  <name> → <from>: <alias> at <effort>; if <file> was aligned to <to>, set
  model: <alias>, effort: <effort> and its lock in
  lib/tests/model-routing.test.sh, then `make test`)" where `<file>` =
  `agents/<name>.md` or `skills/<name>/SKILL.md` (no file clause for a
  built-in agent such as Explore/Plan), alias = head of the phase's tier in
  the SHIPPED `DEFAULT_CONFIG.tiers` (or the phase's model), effort from
  the phase;
  + "; ~/.claude/model-router.json still sets <name> and wins here" when
  `mem.local` has it, checked only after a successful rebuild;
  + "; current run may keep <phase>: /route clear to apply" when a
  restored SKILL row's `to` phase equals the phase of `runMain` or
  `turnMain` with source `run`/`skill`;
  + "; other live sessions see it after /route reload".
- `all` prunes emptied kind tables in `confirmed`, `changed`, `projects`
  (a kept unrestorable `changed` entry stays and is reported).
- `decisions` count = confirmed entries + changed entries + project rows
  (an entry counted once per table it sits in).
- The route tool has no `forget`; sub-agents cannot run commands; the
  origin gate is the existing one in `registerCommandHook`.

## Docs and comments (same commit)
- `argumentHint` gains `forget <name|all|projects>` (locked by a grep in
  the contract CHECK, not by a kit test); register.ts comment "Only a
  dialog answer or `/route ask` writes" → "… or `/route ask` / `/route
  forget` writes".
- README.md: the `/route` subcommand list (~138) gains `forget
  <name|all|projects>` and the writers sentence (~140) names it;
  USAGE.md: the sentence "`/route pending` liste …, `/route ask off|on`
  …" (~190) gains `/route forget <nom|all|projects>` (efface une
  décision, la ligne revient à la phase livrée); CHANGELOG.md: the
  argument form (~10) and the writers sentence (~11); `lib/effort-shift.md`
  commands line.

## Steps
- [ ] S1 `forgetPlan(file, target)` (pure over the fresh file data:
      removals, restores, counts, skipped restores with reasons) and
      `forgetCommand($, st, args)` (arity, reserved words, asking guard,
      read, no-write paths, confirmation for all/projects, write via
      `writeRouting` with a patch that applies the plan, outcome branches,
      asked reset, answer); `handleCommand` case `forget`; argumentHint.
- [ ] S2 docs/comments above.
- [ ] S3 kit tests, folded: forget a confirmed skill → entry gone, asked
      again in the same session, `/route pending` lists it; forget a changed
      agent → row restored, entry gone, the next spawn on the restored model,
      answer carries the realign clause with the file and values; forget a
      phase → confirmed.phases gone, T3 asks again; forget a name with a
      project exception in two repos → both rows removed, emptied keys
      pruned; undecided row → "nothing to forget", no write; asked-only key
      → reset, no write; unknown name → "nothing to forget for", no write;
      arity (two words → usage); reserved word collision answer; open dialog
      → refused; `all` cancelled → nothing written; `all` confirmed →
      everything empty, counts in the answer; `projects` → only projects
      emptied; restore refused (row ≠ to / from unknown) → entry kept, reason;
      override-pinned row → the "wins here" clause; restored skill with a run
      slot → the "/route clear" clause; missing file → "nothing saved";
      rebuild throw → "saved, config not rebuilt"; route tool `clear` leaves
      decisions; the existing origin test extended with `forget x`;
      `failWrite` → "forget not applied"; (argumentHint: grep lock in the
      contract, no kit test).
- [ ] S4 live smoke after the feater (orchestrator, user): one `/route
      forget projects` (or a name) typed in the terminal with the dialog
      answered → recorded `[gated]` in the contract (`$.ui.ask` from an
      `immediate` command is unverified live).
- Disposition: honors BDR-116 (user-only writers, same path/caps; the
  shared tracked memory stays the user's choice), LRN-210 (one clause per
  test, folded where one setup proves two clauses), LRN-212.

## Challenge ledger (r1 → r2)
- simp 1, corr 1, rob 2 (false `st.mem` premise) → plan over the fresh
  file, closure counts, pre-read no-write paths.
- simp 2, corr 2, rob 7 (kind order, reserved words, no-op writes) → all
  kinds, removed-count rule, arity, reserved-word answer.
- simp 3, corr 4/9/10, rob (docs) → docs/comment scope, AC4 = argumentHint.
- simp 4 (projects form) → kept, one-liner, with the confirmation.
- simp 5/6, corr 3/7, rob 3/9 (restore + floors + validation) → guarded
  restore, realign clause with file + values, one formatter.
- corr 5, rob 8 (override-pinned) → "wins here" clause.
- corr 6, rob 6 (dialog in flight) → refuse while asking.
- corr 8, rob 4 (run slot) → "/route clear" clause.
- rob 1 (no confirmation) → askOr confirmation for all/projects, Cancel first.
- rob 5 (three write outcomes) → branches.
- simp 7 (test folds) → S3 folded.

## Confirmation ledger (r2 → r3)
- conf 1 (throw mapping) → `RebuildFailed` class; other throws "not applied".
- conf 2 (slot not taken) → forget takes `st.asking` around its askOr.
- conf 3 (stale plan at write) → patch recomputes on its own file; pre-read
  awaits `st.writes`; applied counts reported.
- conf 4 (run-slot rule) → kind skills, source run/skill, phase == `to`.
- conf 5 (realign clause) → conditional, shipped tiers, no file for built-ins.
- conf 6 (argumentHint test) → grep lock in the contract CHECK.
- conf 7 (live dialog from a command) → S4 smoke.
- conf 8 (ambiguities a-f) → sentences added.
- conf 9 (docs anchors) → README list + USAGE anchor + CHANGELOG form.
