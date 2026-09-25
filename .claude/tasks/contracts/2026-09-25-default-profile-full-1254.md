# CONTRACT — default-profile-full
- date: 2026-09-25 | flow: feat | branch: feature/default-profile-full
- status: active

## REQUEST (verbatim — IMMUTABLE)

User message:
> il faudrait retirer l'API de magic 21st comme on en a plus besoin vu qu'on utilise le cli maintenant. egalement, il faudrait mettre un profil par defaut, quand aucunprofil n'est selectionne il faudrait que ca soit le full qui est actif

/feat $ARGUMENTS:
> Profil par défaut = full : quand aucun profil n'est sélectionné (`.active-profile` absent, vide ou "none", après `reset`), c'est le profil `full` qui est actif (statusline, `profile current`, `gstack off`, `reset`). Même lot : retirer les résidus de l'API Magic 21st (commentaires/docs périmés MAGIC_API_KEY / magic MCP) puisque le CLI `21st` a remplacé le MCP.

## CLARIFICATIONS

Pass A: none — request complete (outcome, scope and constraints derivable).
Ground truth found before pass B: the magic MCP wiring is already gone from
the live code (BDR-093, 2026-09-22): no `mcpServers` entry in `~/.claude.json`,
no `claude()` wrapper in `~/.bashrc`, `MANAGED_MCPS` empty. What remains is
prose: stale comments in `lib/profile.sh` (incl. a wrong `usage()` NOTE
claiming `set` toggles "the magic MCP"), `.env.example`, `.gitleaks.toml`,
`install-plugins.sh`, `plugins.lock.json`, `lib/tests/profile-set-managed.test.sh`,
`README.md` — plus ONE live `MAGIC_API_KEY=` line still in `~/.claude/.env`
(count only; value never read).

Pass B [gated 2026-09-25] — 4 questions, all answered:
Q: `reset` semantics now that `full` is the default?
A: `reset` = `set full` (exclusive): the 20 gstack skills `full` does not list
   are parked, the 5 design skills of the 21st pack + full's plugins/externals
   are enabled. Label and state coincide (LRN-020).
Q: Fresh install (`make plugin`) — apply the default profile when none is selected?
A: Yes. install-plugins.sh ends by applying the default profile
   (`bash lib/profile.sh reset`) when `.active-profile` is absent, empty or
   reads `none`; an existing selection is left alone. Adds install-plugins.sh
   to the executor scope (6 files — /feat cap of 5 exceeded by one 15-line
   guarded block; accepted, not escalated to /ship-feature).
Q: README depth for the magic-MCP mentions?
A: One sentence of history: the 21st section is renamed "21st.dev CLI", keeps
   one sentence ("replaces the former magic MCP, same endpoint, no key"),
   drops the MCP-era risk / API-key / bashrc-wrapper paragraphs (that wrapper
   no longer exists in `~/.bashrc`). CHANGELOG untouched.
Q: Delete the leftover `MAGIC_API_KEY=` line in `~/.claude/.env`?
A: Yes — done by the orchestrator (targeted `sed -i` on that one line, count
   before 1 / after 0; value never read).

## ACCEPTANCE CRITERIA

1. `lib/profile.sh` declares the default profile ONCE, `DEFAULT_PROFILE="full"`,
   and `hooks/statusline.sh` derives its fallback from that constant (reads it
   from the lib; a literal `full` may exist there only as the unreadable-lib
   fallback).
   CHECK: grep -q '^DEFAULT_PROFILE="full"' lib/profile.sh && grep -q 'DEFAULT_PROFILE' hooks/statusline.sh && echo CONST_OK
   EXPECT: CONST_OK
   EVIDENCE: MET exit=0 marker-found :: CONST_OK

2. [revised after challenge, 2026-09-25] `profile.sh current` is label-driven:
   it names `$(active_profile)` as its FIRST WORD in every state and never
   infers the profile from the parked-gstack count. With `.active-profile`
   absent, empty or `none` the line contains `default — not applied yet`;
   with a cache naming a profile it contains `% match`; with a cache naming
   a profile that has no `.profile` file it contains `unknown profile`.
   Right after `reset` on a clean tree (no gstack linked, nothing parked —
   how a real tree looks under BDR-030) the line contains `100% match` and
   NOT `not applied`. No output claims "all gstack skills enabled".
   (judgement + suite criterion 6, tests T1/T4/T5/T6/T7)

3. `profile.sh gstack off` with `.active-profile` absent, empty, or reading
   `none` exits 0 and trims gstack to the default profile's list (no
   "no active profile" error for those three states). A cache naming a profile
   whose file does not exist still errors (rc 1).
   (judgement + suite criterion 6, tests T2/T2b/T3/T4)

4. `profile.sh reset` lands on the default profile: it writes `full` to
   `.active-profile`, and the resulting skill/plugin/external state is what
   the gated answer below specifies. The literal `write_active "none"` no
   longer exists; nothing in `lib/profile.sh` writes `none` to the cache.
   CHECK: ! grep -q 'write_active "none"' lib/profile.sh && ! grep -qE 'write_active +none' lib/profile.sh && echo NONE_GONE
   EXPECT: NONE_GONE
   EVIDENCE: MET exit=0 marker-found :: NONE_GONE

5. `hooks/statusline.sh` prints `profile: full` when `.active-profile` is
   absent, empty or reads `none`, and `profile: <name>` when the cache names a
   profile.
   (judgement + suite criterion 6, tests T8/T9/T10/T11)

6. New hermetic suite `lib/tests/profile-default.test.sh` (fixture repo via
   `PROFILE_REPO_OVERRIDE` + `TOGGLE_EXTERNAL_REPO_OVERRIDE`, fake `claude` on
   PATH, same harness as `profile-set-managed.test.sh`) passes and covers
   criteria 2, 3, 4, 5.
   CHECK: bash lib/tests/profile-default.test.sh 2>&1 | tail -1 | grep -qE '^PASS=[0-9]+ FAIL=0$' && echo DEFAULT_SUITE_OK
   EXPECT: DEFAULT_SUITE_OK
   EVIDENCE: MET exit=0 marker-found :: DEFAULT_SUITE_OK

7. The existing managed-set suite stays green.
   CHECK: bash lib/tests/profile-set-managed.test.sh 2>&1 | tail -1 | grep -qE '^PASS=[0-9]+ FAIL=0$' && echo MANAGED_SUITE_OK
   EXPECT: MANAGED_SUITE_OK
   EVIDENCE: MET exit=0 marker-found :: MANAGED_SUITE_OK

8. Help and docs in scope describe the new behaviour: `usage()` + the header
   block of `lib/profile.sh`, `skills/profile/SKILL.md` (reset line, output
   policy, failure-mode row about `current` saying `none`), and the Makefile
   `profile-reset` help string name the default profile and no longer describe
   `reset` as "re-enable all gstack skills" nor `current` as returning `none`.
   CHECK: grep -qi 'default profile' skills/profile/SKILL.md && grep -qi 'default' Makefile && ! grep -q 'Re-enable all gstack skills (undo any profile set)' Makefile && ! grep -q '`current` says `none`' skills/profile/SKILL.md && echo DOCS_OK
   EXPECT: DOCS_OK
   EVIDENCE: MET exit=0 marker-found :: DOCS_OK

9. Magic 21st residue is gone from the tracked tree outside history and
   registries: no `MAGIC_API_KEY`, `@21st-dev/magic`, or the word `magic` as a
   standalone token (the MCP) in any tracked file except `CHANGELOG.md`,
   `.claude/**`, `lib/tests/fixtures/**` (frozen snapshots) and
   `lib/project-archetypes/**` ("magic numbers" is prose) and, [gated
   2026-09-25] exactly ONE line of `README.md` (the history sentence the
   user chose to keep). Positive control: the same search on `develop`
   still trips.
   CHECK: git grep -qiI -e 'MAGIC_API_KEY' develop -- . ':!CHANGELOG.md' ':!.claude' ':!lib/tests/fixtures' || exit 1; git grep -iIl -e 'MAGIC_API_KEY' -e '@21st-dev/magic' -- . ':!CHANGELOG.md' ':!.claude' ':!lib/tests/fixtures' | grep -q . && exit 1; git grep -iIl -e '[^a-zA-Z]magic[^a-zA-Z-]' -- . ':!CHANGELOG.md' ':!.claude' ':!lib/tests/fixtures' ':!lib/project-archetypes' ':!README.md' | grep -q . && exit 1; [ "$(grep -ci 'magic' README.md)" -eq 1 ] && echo RESIDUE_GONE
   EXPECT: RESIDUE_GONE
   EVIDENCE: MET exit=0 marker-found :: RESIDUE_GONE

10. shellcheck clean on every touched shell file.
   CHECK: shellcheck lib/profile.sh hooks/statusline.sh lib/tests/profile-default.test.sh lib/tests/profile-set-managed.test.sh install-plugins.sh lib/toggle-external.sh >/dev/null 2>&1 && echo SHELLCHECK_OK
   EXPECT: SHELLCHECK_OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK_OK

11. (judgement) No new dependency. LRN-020 honoured: `full` names the real
    default profile, `reset` applies it and a fresh install applies it when
    nothing is selected, so no label denotes "nothing applied"; the
    parenthetical after the name says whether the profile is applied
    (`% match`) or merely in force (`default — not applied yet`). The
    cross-profile "best guess" scan is replaced by the match of the labelled
    profile only (one profile scored instead of ten).

12. [gated 2026-09-25, revised after challenge] `install-plugins.sh` applies
    the default profile at the very end of the install (a Step 11 AFTER the
    Step 10 `link.sh` refresh, BEFORE the Install Summary) by calling
    `bash "$REPO/lib/profile.sh" reset` ONLY when `.active-profile` is
    absent, empty or reads `none`; the call is guarded (`|| warn …`, the
    installer runs under `set -e`) so a failure never hides the Summary; an
    existing selection is re-applied with `bash "$REPO/lib/profile.sh" set
    "$SEL"` (same guard) because Step 2 re-parks gstack and Step 10's
    `link.sh` re-links the design externals on every run — the label never
    changes, its state comes back; a missing `lib/profile.sh`
    warns and skips. Step 8.7 no longer parks the 21st pack unconditionally
    (that block is removed: a re-run must never re-park what the selected
    profile or the user enabled); its comments and the Summary line say the
    design skills follow the profile and the publishing skills stay on
    demand, with no hard-coded counts. The installer itself is NEVER
    executed during this run (side effects: npm, claude plugin) —
    `bash -n` + shellcheck only.
    CHECK: r=$(grep -n 'lib/profile.sh" reset' install-plugins.sh | head -1 | cut -d: -f1); l=$(grep -n 'bash "$REPO/link.sh"' install-plugins.sh | head -1 | cut -d: -f1); s=$(grep -n 'Install Summary' install-plugins.sh | head -1 | cut -d: -f1); [ -n "$r" ] && [ -n "$l" ] && [ -n "$s" ] && [ "$l" -lt "$r" ] && [ "$r" -lt "$s" ] && grep -q 'active-profile' install-plugins.sh && grep -A1 'lib/profile.sh" reset' install-plugins.sh | grep -q '|| *warn' && grep -A1 'lib/profile.sh" set "$SEL"' install-plugins.sh | grep -q '|| *warn' && ! grep -q 'toggle-external.sh" disable 21st' install-plugins.sh && bash -n install-plugins.sh && echo INSTALL_DEFAULT_OK
    EXPECT: INSTALL_DEFAULT_OK
    EVIDENCE: MET exit=0 marker-found :: INSTALL_DEFAULT_OK

13. [revised after challenge] The citers of the old `current`/`reset`
    semantics outside the profile files are patched in the same diff:
    `agents/plugin-advisor.md` no longer expects `"custom"` from `current`
    nor states that `reset` leaves plugin state untouched; the
    `lib/toggle-external.sh` header names `reset` as the way back to the
    default profile. `cmd_gstack on` and SKILL.md no longer claim to
    "(re-)enable ALL gstack".
    CHECK: ! grep -q 'or "custom"' agents/plugin-advisor.md && ! grep -q 'Plugin state is NOT touched by reset' agents/plugin-advisor.md && grep -qi 'default profile' lib/toggle-external.sh && ! grep -q 'all gstack skills already enabled' lib/profile.sh && ! grep -q 'all gstack enabled' lib/profile.sh && ! grep -qi 're-enable ALL gstack' skills/profile/SKILL.md && echo CITERS_OK
    EXPECT: CITERS_OK
    EVIDENCE: MET exit=0 marker-found :: CITERS_OK

## FILE SCOPE

Executor (feater) — the feature:
- lib/profile.sh                       (DEFAULT_PROFILE, active_profile(), reset, current, gstack off, usage, header)
- hooks/statusline.sh                  (fallback = default profile)
- lib/tests/profile-default.test.sh    (new)
- skills/profile/SKILL.md              (docs)
- Makefile                             (profile-reset help string)
- install-plugins.sh                   ([gated 2026-09-25] final default-profile step + 8.7 comment + summary line)
- agents/plugin-advisor.md             ([revised after challenge] two citers of `current`/`reset` semantics)
- lib/toggle-external.sh               ([revised after challenge] one header-comment citer of `reset`)

Orchestrator, committed BEFORE dispatch as `chore(21st): drop magic MCP residue`
(prose only, no logic — the executor's diff starts after it):
- .env.example, .gitleaks.toml, install-plugins.sh (Step 8.7 header comment),
  plugins.lock.json (21st note), lib/profile.sh (comments + usage NOTE),
  lib/tests/profile-set-managed.test.sh (header comment), README.md
  (21st section + MCP-secret section wording).

Out of scope: CHANGELOG.md history, `.claude/**` registries (append-only),
`lib/tests/fixtures/**` snapshots, `lib/profiles/*.profile` contents, the
gstack submodule, `~/.claude/.env` (user's file — gated question).
