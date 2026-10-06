# CONTRACT — higgsfield-pack
- date: 2026-09-30 | flow: ship-feature | branch: feature/higgsfield-pack
- status: active

## REQUEST (verbatim — IMMUTABLE)
> [pasted content]
> Set up Higgsfield for me so I can generate images and videos from here.
>
> 1. Install the CLI: run `npm i -g @higgsfield/cli`.
> 2. Authenticate: run `higgsfield auth login` and complete the sign-in in the browser it opens.
> 3. Install the companion skills: run `npx skills add higgsfield-ai/skills`.
>
> Once that's done, let me know when it's ready.
> [end pasted content]
>
>  et ajoute cet instsallation au process d'installation de cette config

## CLARIFICATIONS
- Pass A: none — outcome and scope derivable (machine setup + install-process integration).
- Q: which of the 8 upstream skills? / A (user, 2026-09-30): "sans les sites, mais j'aimerais qu'on puisse l'appeler quand meme. PAr exemple la pour mon jeux ../game je vias vouloir faire une landing page avec certainement. ou pour un autre projet. Mais pas que ca soit systematique. Peut etre ajouter aux profil design (full par extension) une option + creative qu'on peut activer ou qui s'active avec un trigger explicite"
- Q: activation? / A: "Pack toggle, off par défaut" — `make plugin` installs CLI + skills, links nothing; `toggle-external.sh enable higgsfield` activates, state persists; enabled on THIS machine at the end of the run.
- Q: integration scope? / A: "Complet" — install-plugins.sh, plugins.lock.json, .gitignore, update-all.sh, doctor.sh, README; same coverage as 21st.
- Q: "+creative" shape? / A: "2 toggles + ligne de routing" — toggle `higgsfield` (7 media skills) + separate toggle `higgsfield-websites`, both off by default, additive on any profile, never in MANAGED_EXTERNALS nor any profile; routing lines in CLAUDE.global.md Skill routing (explicit ask → enable toggle → follow skill). Skills cloned from higgsfield-ai/skills into `skills-external/` (21st pattern), NOT `npx skills add` (it would re-link all 8 into skills/ on every refresh).
- Q: toggle names? / A: "higgsfield + higgsfield-websites".
- Delegated internals (orchestrator): lock `version: latest` (21st precedent, BDR-056); skills track upstream main, refreshed by `make update`; shared helper `lib/higgsfield-skills.sh` sourced by install-plugins.sh and update-all.sh (URL single source, env override for tests); refresh = rm+mv per skill, parked `skills-disabled/<n>` symlink untouched; whole skill dirs copied (md + py + yaml, MIT, no binaries — read 2026-09-30 at upstream f83af0b); no effort pins (BDR-107: machine-owned, not in the design stack) but the sync sits BEFORE `apply_effort_pins` in both scripts (BDR-108, BLK-024); pack status = enabled when ANY member is linked (21st semantics); auth oracle `timeout 15 higgsfield auth token </dev/null >/dev/null 2>&1` (locality unverified: CLI source is closed, hence the timeout; token never printed, never logged).
- No settings.json edit: `higgsfield website deploy|publish` already falls under the hard_deny "Production deployment"; the routing line says so.
- The browser sign-in (`higgsfield auth login`) is a user action outside the diff: two attempts timed out unapproved on 2026-09-30; state reported in the final message, not a criterion.
- CLI already installed on this machine by the orchestrator (`npm i -g @higgsfield/cli`, 1.1.26) before the `Bash(npm install -g *)` deny rule was read: the `i` alias slipped past the pattern. User named the package and the command; disclosed in the final message. The installer's own npm call runs under `make plugin`, by the user.
- Live steps are the orchestrator's: first sync of the 8 skills on this machine (helper call) and `toggle-external.sh enable higgsfield`. Executors never run install-plugins.sh, update-all.sh, link.sh, doctor.sh, `npm install`, or the live helper against the network. Under subagent-driven-development each executor commits its own task on feature/higgsfield-pack, explicit paths only.
- [gated 2026-09-30] Design presented in chat, approved. User reply verbatim: "1 oui ajoute a deny , j'ai bien auth sur le cli, oui non on deploy pas de site entier, je vais juste men servir pour aider a faire des landing pages c'est tout, integre au reste de l'archi. et oui A"
- [gated 2026-09-30] Deny hole closed: settings.json `permissions.deny` gains `Bash(npm i -g *)` (asked), plus the two `--global` spellings of the same command (orchestrator, same hole, restriction-only). Hand edit by the orchestrator, guarded config (BDR-028).
- [gated 2026-09-30] `higgsfield-websites` is an AID for landing pages inside the existing Design work stack and site rules (Astro by default): assets and references only. Never `higgsfield website create|deploy|publish`. The routing line says so.
- [gated 2026-09-30] TTY login, option A: the two existing dead login offers (ctx7 Step 6, 21st Step 8.7) are fixed in this feature. `[ -t 0 ] && [ -t 1 ]` becomes `[ -t 0 ]` (stdout is the tee pipe since install-plugins.sh:22; update-all.sh:75 already tests stdin alone); the Higgsfield block uses the same test.
- Machine state 2026-09-30: user signed in (`auth token` rc 0); orchestrator selected the only workspace (`higgsfield workspace set`, Private, plus plan) so `account status` answers.
- Pass B [2026-09-30]: plan `docs/superpowers/plans/2026-09-30-higgsfield-pack.md` read against the three classes; no visible / public-name / scope choice left open beyond what the three question rounds and the design approval settled (step numbers 8.6 / 7.3b, doctor wording and README placement follow the 21st precedent). Proceeds silently.
- [challenge 2026-09-30, 3 lenses: simplicity CONCERNS(1 MAJOR), robustness CONCERNS(3 MAJOR), correctness CONCERNS(2 MAJOR), no BLOCKER; every MAJOR closed by a named plan change, r2] (a) CLI presence = `higgsfield_cli_ok` probe (`higgsfield version`) in Step 8.6, 7.3b, doctor and the toggle hints: the npm shim can sit on PATH with no binary after a skipped postinstall; (b) every toggle probe bounded (`bounded`, 15 s) like the helper's; (c) media pack = allowlist `HIGGSFIELD_MEDIA_SKILLS` of the 7 names (default deny: upstream is unpinned), unlisted synced skills reported and never linked; (d) sync stages inside skills-external/ (rename on one filesystem), counts a skill only once moved, skips symlinked entries, `GIT_TERMINAL_PROMPT=0`; (e) vacuous fixtures fixed (SKILL.md-less dir now tracked by git, symlink points at a surviving target); (f) Step 8.6 loses its hardcoded `higgsfield-generate` fallback branch; (g) exact-count message locks dropped; (h) routing entry cut to 6 lines (312/320); (i) `enable higgsfield-websites` prints the CLI hints too; (j) suite builds its own clean PATH instead of failing on a system-wide CLI; (k) rollback note + known limits in the plan. Not taken: pruning skills upstream removes (known limit, documented), one parametrised enumerator for 21st and higgsfield (the allowlist makes them differ).
- [confirmation pass 2026-09-30, correctness CONCERNS(1 MAJOR, 6 MINOR), all closed by named changes, r3] clone disables every credential prompt (GIT_ASKPASS / SSH_ASKPASS emptied, credential.helper and core.askPass reset, stdin closed; tried live against a missing repo: rc 128 in 0 s); doctor version read cannot trip errexit; block 7.3b reports three states (no answer / updated / update failed, old binary kept); criterion 2 control uses `--no-index`; criterion 3 tells `higgsfield` from `higgsfield-websites`; criterion 6 and the suite check the probe comes AFTER the npm call; rollback note names the synced sources.
- [gated 2026-09-30] STEP 3 validation gate: user answered "yes" to the 9-task plan, the r2/r3 design changes (allowlist, CLI probe, hardened clone) and the challenge summary. Criteria 2, 3, 4, 5, 6 as revised by the challenge are the gated versions.
- [final review 2026-09-30, opus, whole branch: 0 Critical, 1 Important, 8 Minor → one fix wave, commit 4c7db88] `enable higgsfield` on an already-enabled pack now runs the hints, so upstream drift is reported in the steady state (README said "reported"); `make update` runs npm only for an npm-installed CLI (`npm ls -g`), else an info line; probes fall back to `gtimeout`; CHANGELOG names the remaining npm-deny gap; README gains the workspace step; two fixtures carry a space in their path. Deferred with rulings: remedy text under a pinned version, redundant probes in Step 8.6, rollback note.
- [oracle maintenance 2026-09-30, orchestrator, NOT a human gate — surfaced in the final report] Criterion 5's CHECK counted the redirect inside the first 6 lines of `_higgsfield_probe`; the gtimeout fallback reshaped the function (a loop), so that count went from 2 to 1 within the window while both invocations still redirect. The CHECK now extracts the whole function body and requires EVERY `higgsfield "$@"` invocation line to carry `</dev/null >/dev/null 2>&1`. Criterion text unchanged; the check is stricter, not looser.
- [gated 2026-09-30] Doc sync: user answered "A, all , P7 seul". A = keep the four audit retouches (README + CHANGELOG committed as d9617d8; the `lib/toggle-external.sh` header comment committed apart as 2560905 after the doc-shape oracle refused a script path in a MINOR doc patch). P7 = one line in agents/plugin-advisor.md (5350221): never recommend the Higgsfield toggles from project signals. all = registries BDR-109, LRN-183..188, BLK-025, EVAL-039. GATE 0 replayed MET, floor clean, `make test` rc 0 (45 suites) on 5350221.
- Functions ≤ 25 logic lines, ≤ 5 locals, shellcheck clean; logic lines within 80 columns. Message strings on ok/info/warn/err/echo/printf lines and the pre-existing long `case` patterns of toggle-external.sh follow the surrounding installer style and may run longer [challenge 2026-09-30]. README prose follows rules/writing-style.md.

## ACCEPTANCE CRITERIA
1. plugins.lock.json carries a `higgsfield` entry: source `npm:@higgsfield/cli`, version `latest`, no `managed_by` (doctor-vendored must ignore it), a note naming the skills repo.
   CHECK: python3 -c "import json;d=json.load(open('plugins.lock.json'))['higgsfield'];assert d['source']=='npm:@higgsfield/cli' and d['version']=='latest' and 'managed_by' not in d and 'higgsfield-ai/skills' in d['note'];print('LOCK_OK')"
   EXPECT: LOCK_OK
   EVIDENCE: MET exit=0 marker-found :: LOCK_OK
2. .gitignore covers both states of the pack and the sync stage: the `skills/higgsfield-*` links, the `skills-external/higgsfield-*/` sources, `skills-external/.higgsfield-stage.*/` (positive control: a tracked skill is NOT ignored). [stage: challenge 2026-09-30]
   CHECK: git check-ignore -q --no-index skills/feat/SKILL.md && exit 1; git check-ignore -q skills/higgsfield-generate && git check-ignore -q skills-external/higgsfield-generate/SKILL.md && git check-ignore -q skills-external/higgsfield-websites/SKILL.md && git check-ignore -q skills-external/.higgsfield-stage.abc123/src/x && echo IGNORED_BOTH
   EXPECT: IGNORED_BOTH
   EVIDENCE: MET exit=0 marker-found :: IGNORED_BOTH
3. Off by default, never resurrected: no higgsfield name in link.sh, in lib/profile.sh MANAGED_EXTERNALS, or in any lib/profiles/*.profile; both toggles are in toggle-external.sh MANAGED_TOOLS (positive control on the grep first).
   CHECK: echo 'higgsfield-generate external' | grep -q higgsfield || exit 1; grep -q higgsfield link.sh && exit 1; grep -q higgsfield lib/profile.sh && exit 1; grep -lq higgsfield lib/profiles/*.profile && exit 1; awk '/^MANAGED_TOOLS=\(/,/\)/' lib/toggle-external.sh | grep -qE '(^|[( ])higgsfield( |$)' && awk '/^MANAGED_TOOLS=\(/,/\)/' lib/toggle-external.sh | grep -qE '(^|[( ])higgsfield-websites( |$)' && echo OFF_BY_DEFAULT
   EXPECT: OFF_BY_DEFAULT
   EVIDENCE: MET exit=0 marker-found :: OFF_BY_DEFAULT
4. Hermetic suite `lib/tests/higgsfield.test.sh` exists and is green through `make test`: sync helper (moves only real `higgsfield-*` dirs holding a SKILL.md, skips a pack-named symlink, no `.git`, stale upstream file gone after refresh, parked link survives, failed clone keeps the existing copy and returns non-zero), silent CLI probes (binary answers / shim without binary / no CLI / no `timeout`; nothing printed), toggles (`enable higgsfield` links the allowlisted media skills and NOT websites; an unlisted synced skill is reported and never linked; `enable higgsfield-websites` links only it; disable parks; status missing/disabled/enabled; signed-out, shim-only and absent CLI warn, never block; 21st behaviour unchanged) and static wiring locks, with a fake `higgsfield` on PATH. [allowlist, probes: challenge 2026-09-30]
   CHECK: out=$(make test suite=lib/tests/higgsfield.test.sh 2>&1); echo "$out" | grep -q '^FAIL' && exit 1; for c in SYNC_MOVES_PACK_ONLY SYNC_REFRESH_DROPS_STALE SYNC_KEEPS_PARKED SYNC_FAIL_KEEPS_COPY PROBES_SILENT STATUS_STATES ENABLE_PACK_EXCLUDES_WEBSITES UNLISTED_NOT_LINKED ENABLE_WEBSITES_ALONE DISABLE_PARKS SIGNED_OUT_WARNS ENABLE_MISSING_ERRS PACK_21ST_UNCHANGED OFF_BY_DEFAULT_WIRING INSTALL_WIRING UPDATE_WIRING; do echo "$out" | grep -q "PASS $c" || { echo "missing $c"; exit 1; }; done; echo SUITE_OK
   EXPECT: SUITE_OK
   EVIDENCE: MET exit=0 marker-found :: SUITE_OK
5. install-plugins.sh: a Higgsfield step sits between Step 8.5 and Step 8.7; it proves the CLI with the `higgsfield_cli_ok` probe (never `command -v` alone: the npm shim can outlive its binary), installs per the lock entry, prints the `--allow-scripts=` remedy on failure, syncs the skills through the shared helper BEFORE the last `apply_effort_pins`, offers `higgsfield auth login` only when stdin is a terminal, and never lets `auth token` output reach the log (every call goes through `_higgsfield_probe`, which redirects to /dev/null); the summary lists the pack. [probe: challenge 2026-09-30]
   CHECK: a=$(grep -n 'Step 8.5: External skills' install-plugins.sh | head -1 | cut -d: -f1); h=$(grep -n 'higgsfield_sync_skills' install-plugins.sh | tail -1 | cut -d: -f1); b=$(grep -n 'Step 8.7: 21st.dev' install-plugins.sh | head -1 | cut -d: -f1); p=$(grep -n 'apply_effort_pins "\$REPO"' install-plugins.sh | tail -1 | cut -d: -f1); [ -n "$a" ] && [ -n "$h" ] && [ -n "$b" ] && [ -n "$p" ] && [ "$a" -lt "$h" ] && [ "$h" -lt "$b" ] && [ "$h" -lt "$p" ] && [ "$(grep -c 'if higgsfield_cli_ok' install-plugins.sh)" -ge 3 ] && grep -q -- '--allow-scripts=' install-plugins.sh && grep -q 'higgsfield auth login' install-plugins.sh && grep -q 'source "\$REPO/lib/higgsfield-skills.sh"' install-plugins.sh && ! grep -q 'auth token' install-plugins.sh && grep -q '_higgsfield_probe auth token' lib/higgsfield-skills.sh && body=$(awk '/^_higgsfield_probe\(\)/,/^}/' lib/higgsfield-skills.sh) && c=$(echo "$body" | grep -c 'higgsfield "\$@"') && [ "$c" -ge 1 ] && [ "$c" -eq "$(echo "$body" | grep 'higgsfield "\$@"' | grep -c '</dev/null >/dev/null 2>&1')" ] && sed -n '/Install Summary/,$p' install-plugins.sh | grep -q 'enable higgsfield' && echo INSTALL_WIRED
   EXPECT: INSTALL_WIRED
   EVIDENCE: MET exit=0 marker-found :: INSTALL_WIRED
6. update-all.sh refreshes the CLI and the skills through the same helper, before the 21st block and before the `apply_effort_pins` re-apply, skipping when the CLI is absent, and proves the updated CLI with `higgsfield_cli_ok` (a shim left without its binary gets a warning, not a success line). [probe: challenge 2026-09-30]
   CHECK: h=$(grep -n 'higgsfield_sync_skills' update-all.sh | tail -1 | cut -d: -f1); t=$(grep -n '7.4. Update the 21st.dev' update-all.sh | head -1 | cut -d: -f1); p=$(grep -n 'apply_effort_pins "\$REPO"' update-all.sh | tail -1 | cut -d: -f1); [ -n "$h" ] && [ -n "$t" ] && [ -n "$p" ] && [ "$h" -lt "$t" ] && [ "$h" -lt "$p" ] && grep -q '@higgsfield/cli' update-all.sh && n=$(grep -n 'npm install -g "\$HF_PKG"' update-all.sh | tail -1 | cut -d: -f1) && k=$(grep -n 'higgsfield_cli_ok' update-all.sh | head -1 | cut -d: -f1) && [ -n "$n" ] && [ -n "$k" ] && [ "$k" -gt "$n" ] && echo UPDATE_WIRED
   EXPECT: UPDATE_WIRED
   EVIDENCE: MET exit=0 marker-found :: UPDATE_WIRED
7. doctor.sh reports the Higgsfield CLI and its session at info level (never a warn or a fail when absent or signed out), errexit-safe.
   CHECK: grep -q 'Higgsfield' doctor.sh && ! grep -E '(warn|fail) .*[Hh]iggsfield' doctor.sh | grep -q . && out=$(bash doctor.sh 2>/dev/null; true) && echo "$out" | grep -q 'Higgsfield' && echo DOCTOR_OK
   EXPECT: DOCTOR_OK
   EVIDENCE: MET exit=0 marker-found :: DOCTOR_OK
8. CLAUDE.global.md Skill routing names both toggles (explicit ask → enable → follow the skill; metered credits; `higgsfield-websites` as a landing-page aid inside the Design work stack, never `higgsfield website create|deploy|publish`) and the file stays within the 320-line guard (BDR-062, BDR-098).
   CHECK: flat=$(tr '\n' ' ' < CLAUDE.global.md | tr -s ' '); echo "$flat" | grep -q 'toggle-external.sh enable higgsfield' && echo "$flat" | grep -q 'higgsfield-websites' && echo "$flat" | grep -q 'create|deploy|publish' && [ "$(wc -l < CLAUDE.global.md)" -le 320 ] && echo ROUTING_OK
   EXPECT: ROUTING_OK
   EVIDENCE: MET exit=0 marker-found :: ROUTING_OK
9. Shellcheck clean on every touched shell file; the suites that census the touched surfaces stay green.
   CHECK: shellcheck install-plugins.sh update-all.sh doctor.sh lib/toggle-external.sh lib/higgsfield-skills.sh lib/tests/higgsfield.test.sh || exit 1; for s in effort-routing toggle-external-repo-resolution profile-set-managed profile-default gstack-removed profile-census curated-config-guard no-vacuous-locks; do out=$(make test suite=lib/tests/$s.test.sh 2>&1) || { echo "red: $s"; exit 1; }; done; echo SUITES_OK
   EXPECT: SUITES_OK
   EVIDENCE: MET exit=0 marker-found :: SUITES_OK
10. Docs: README has a Higgsfield section (what the CLI is, install, sign-in, the two toggles, off by default, refresh by `make update`, credits are metered) and CHANGELOG `[Unreleased]` → `### Added` has a Higgsfield bullet.
   CHECK: grep -q '^### Higgsfield' README.md && grep -q 'toggle-external.sh enable higgsfield' README.md && awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | grep -qi 'higgsfield' && echo DOCS_OK
   EXPECT: DOCS_OK
   EVIDENCE: MET exit=0 marker-found :: DOCS_OK
11. Live on this machine (orchestrator step): the 8 skills sit under skills-external/higgsfield-*/, the `higgsfield` toggle is enabled with its 7 links resolving under ~/.claude/skills, and `higgsfield-websites` stays disabled.
   CHECK: n=$(ls -d skills-external/higgsfield-*/SKILL.md 2>/dev/null | wc -l); [ "$n" -eq 8 ] || { echo "sources: $n"; exit 1; }; [ "$(bash lib/toggle-external.sh status higgsfield)" = enabled ] || exit 1; [ "$(bash lib/toggle-external.sh status higgsfield-websites)" = disabled ] || exit 1; for s in generate soul-id product-photoshoot brandkit marketplace-cards video-explainer youtube-thumbnail; do [ -f "$HOME/.claude/skills/higgsfield-$s/SKILL.md" ] || { echo "no link $s"; exit 1; }; done; echo LIVE_OK
   EXPECT: LIVE_OK
   EVIDENCE: MET exit=0 marker-found :: LIVE_OK
12. Full `make test` green (orchestrator run, output quoted in the final report); new functions within the house limits; README prose within rules/writing-style.md.

13. settings.json denies the npm global-install aliases the original rule missed: `npm i -g`, `npm install --global`, `npm i --global` (the original `npm install -g` entry kept). [gated 2026-09-30]
   CHECK: python3 -c "import json;d=json.load(open('settings.json'))['permissions']['deny'];need=['Bash(npm install -g *)','Bash(npm i -g *)','Bash(npm install --global *)','Bash(npm i --global *)'];assert all(n in d for n in need),[n for n in need if n not in d];print('DENY_OK')"
   EXPECT: DENY_OK
   EVIDENCE: MET exit=0 marker-found :: DENY_OK
14. install-plugins.sh login offers are reachable under the tee redirect: no `-t 1` test remains, and the ctx7, 21st and Higgsfield offers each test stdin alone (positive control on the pattern first). [gated 2026-09-30]
   CHECK: echo 'if [ -t 0 ] && [ -t 1 ]; then' | grep -q -- '-t 1' || exit 1; grep -q -- '-t 1' install-plugins.sh && exit 1; [ "$(grep -c -- '\[ -t 0 \]' install-plugins.sh)" -ge 3 ] && echo TTY_OK
   EXPECT: TTY_OK
   EVIDENCE: MET exit=0 marker-found :: TTY_OK

## FILE SCOPE
- install-plugins.sh (new Step 8.6 + summary lines), update-all.sh (new block before 7.4), doctor.sh (section 4), lib/toggle-external.sh (header, MANAGED_TOOLS, pack arms), lib/higgsfield-skills.sh (new), lib/tests/higgsfield.test.sh (new), plugins.lock.json, .gitignore
- settings.json (permissions.deny, orchestrator hand edit) [gated 2026-09-30]; install-plugins.sh Step 6 + Step 8.7 login tests [gated 2026-09-30]
- agents/plugin-advisor.md (one line, TOGGLING EXTERNAL TOOLS) [gated 2026-09-30]
- CLAUDE.global.md (Skill routing lines), README.md, CHANGELOG.md; doc-syncer may touch USAGE.md / skills/profile/SKILL.md at STEP 8
- Orchestrator-only, live: skills-external/higgsfield-* (gitignored), skills/higgsfield-* links (gitignored)
- Orchestrator-only: .claude/tasks/**, .claude/memory/**, docs/superpowers/{specs,plans}/** (transient)
