# CONTRACT — skill-catalog-prune
- date: 2026-09-28 | flow: feat (ad-hoc dispatch, /feat gates replayed by the orchestrator, 3 parallel feater executors) | branch: feature/skill-catalog-prune
- status: active

## REQUEST (verbatim — IMMUTABLE)
> j'aimerias que tu fasse le tour des skills perso et installe, gstack compris, superpowers compris, que tu vois si il y a des doublons, S'il y en as, supprime le moins performant de l'installation auto, update etc (on supprimera le skill / agent en question apres installation du plugin si necesaire) on va faire en sorte d'economiser le plus de token possible comme ca. Fais le tour d'analyse,  vois les doublons, vois les quels supprimer et retirer de la config car inutile

User answers to the decision batch (verbatim):
> Tier 1 → "Go, tout le tier 1 (Recommended)"
> Superpowers → "Vendoriser 7, retirer le plugin (Recommended)"  [tier 2, separate branch, NOT this contract]
> 21st → "21st est en cli, et j'ai connecté le cli, n'est-ce pas ? On a retiré le mcp sinon 1"  [CLI answers `Not logged in` → option 1: park 21st-ai, 21st-ui-explore, 21st-ui-review]
> gstack reste → "Parquer les 10 redondants hors full, Réparer make-pdf et diagram dans link.sh, Parquer make-pdf et diagram aussi, Avoir la possibilité de choisir un profil avec si on en a besoin, du style full + parked"

Tier 1 as presented and approved: disable brightdata (synced), remove the duplicate
frontend-design plugin, take the 9 broken/doctrine-breaking gstack skills (ship,
land-and-deploy, setup-deploy, autoplan, context-save, learn, careful, guard,
design-shotgun) out of the profiles with the routing lines corrected, switch the
security-guidance Stop layer off, fix doctor.sh and the "0 tokens" claims.

## CLARIFICATIONS
- Pass A: none — request complete (outcome, scope and constraints derivable from the audit).
- Live state already changed by the orchestrator before dispatch (user go): `claude plugin disable brightdata-plugin@synced` wrote `"brightdata-plugin@synced": false` into settings.json; `claude plugin uninstall frontend-design@claude-plugins-official` removed its enabledPlugins entry and cache. The executor keeps both states.
- The superset profile carries a header line `# SUPERSET-OF: full` so oracles find it by content, not by name (internal choice).
- "Parked" = kept installed, out of the default `full` profile, listed only in the superset profile (and in the specialized profiles that already carry them, see pass B). The 9 removed gstack skills go in NO profile, superset included: they are broken (autoplan, careful/guard hooks exit 127, context-save without restore) or break doctrine (ship base = origin/HEAD = main, land-and-deploy auto-merges and deploys), or need an absent key (design-shotgun → OPENAI_API_KEY).
- security-guidance stays installed and enabled (PROTECTED); only the Stop-hook LLM review is switched off through the plugin's own env switch `ENABLE_STOP_REVIEW=0` in settings.json `env`; commit/push agentic review and the regex layer stay on.
- [gated 2026-09-28] Q: superset profile name? / A: `max`.
- [gated 2026-09-28] Q: 11 redundant gstack out of the specialized profiles too? / A: NO — user rule: "full must already carry what every other profile has; max has everything; these gstack matter in full because full must do what each profile does". So the 11 redundant gstack STAY in full (and in their specialized profiles). Parked = only what no specialized profile carries: make-pdf, diagram, and the 21st trio. `full` ⊇ union of every non-max profile, minus the 9 removed names and the 21st trio, minus an explicit exception allowlist written in the census test with its reason (pr-review-toolkit: plugin deliberately out of full, audit 2026-07-02 #12, ~2.2k tokens; measured 2026-09-28: it is the ONLY name any specialized profile carries that full lacks).
- [gated 2026-09-28] Q: 21st-ai / 21st-ui-explore / 21st-ui-review scope? / A: out of all four design-bearing profiles (full, web, web-full, design), kept in `max`; CLAUDE.global.md "Review / audit" line drops "+ 21st-ui-review"; GATE-BLOCK untouched.
- [gated 2026-09-28] Q: add the `freeze/bin` helper link too? / A: yes, same fix as make-pdf/diagram.
- [challenge 2026-09-28, 3 blind challengers, no BLOCKER, 8 MAJOR adopted] (a) the broken-wiring class is every `~/.claude/skills/gstack/<path>` the gstack skills hardcode (bin, scripts, ETHOS.md, lib, design/dist, extension, */sections, review/checklist+specialists, make-pdf/dist, freeze/bin…), fixed by one shared `lib/gstack-links.sh` used by link.sh AND install-plugins.sh, exposing no SKILL.md; (b) `profile.sh apply` is additive, only `set`/`reset` park: the live tree is proven by criterion 16 (`set full`); (c) `gstack on` / `toggle-external enable gstack` honor the `GSTACK_REMOVED` denylist (`lib/gstack-removed.sh`, single source); (d) `max` ⊇ union of every profile − GSTACK_REMOVED (so it carries pr-review-toolkit); (e) census test = passing baseline then one mutant per invariant; (f) doctor reuses lib/skill-routing-census.py's parser through `lib/doctor-skills.sh`; (g) no synced-bucket line in doctor (scope). These refine criteria 2, 3, 8, 9 and add 16-18 below; they are reported to the human at the merge gate.
- [confirmation pass 2026-09-28, robustness FATAL(4), every finding closed by a named plan change, r4] helper lib skips nested-SKILL.md dirs and removes/refuses a dst symlink; update-all.sh joins the shared lib (criterion 18); the three existing profile/toggle suites copy lib/gstack-removed.sh into their fixtures; `gstack on` reports the real restored count; doctor stats warn on fallback.
- Functions ≤ 25 logic lines, 80-char lines, ≤ 5 params, ≤ 5 locals (CLAUDE.global.md). Shell edits shellcheck-clean.
- Executors never run `gitflow`, never commit, never run `claude plugin …`, never touch `skills/`, `skills-external/`, `~/.claude` outside link.sh's own effect, never delete anything.

## ACCEPTANCE CRITERIA
1. The 9 removed gstack skills appear as an entry in no profile (positive control first).
   CHECK: pat='^(ship|land-and-deploy|setup-deploy|autoplan|context-save|learn|careful|guard|design-shotgun)([[:space:]]|$)'; printf 'ship\n' | grep -qE "$pat" || { echo control-failed; exit 1; }; if grep -lE "$pat" lib/profiles/*.profile; then echo listed-somewhere; exit 1; fi; echo PROFILES_CLEAN
   EXPECT: PROFILES_CLEAN
   EVIDENCE: MET exit=0 marker-found :: PROFILES_CLEAN
2. `full` lists none of the 5 parked names; exactly one profile carries `# SUPERSET-OF: full` (it is `max`), it lists every entry of full, every parked name, and every name any profile carries (max ⊇ union − removed). [gated 2026-09-28: parked set = 5; challenge: union]
   CHECK: python3 .claude/tasks/contracts/2026-09-28-skill-catalog-prune-0554.oracles/c2.py
   EXPECT: SUPERSET_OK
   EVIDENCE: MET exit=0 marker-found :: SUPERSET_OK
3. After link.sh, every helper path the gstack skills hardcode under `~/.claude/skills/gstack/` and that exists in the submodule resolves (recomputed from a grep census of the skills; `<skill>/SKILL.md` cross-reads and `.git` excluded), and no SKILL.md is exposed anywhere under the helper tree. [challenge 2026-09-28: whole class, was 3 paths]
   CHECK: bash link.sh >/dev/null 2>&1; python3 .claude/tasks/contracts/2026-09-28-skill-catalog-prune-0554.oracles/c3.py
   EXPECT: LINKS_OK
   EVIDENCE: MET exit=0 marker-found :: LINKS_OK
4. doctor.sh counts every skill reachable through `~/.claude/skills/*/SKILL.md` (symlinks included) and sums block-scalar descriptions too (recomputed independently, ±5 %).
   CHECK: python3 .claude/tasks/contracts/2026-09-28-skill-catalog-prune-0554.oracles/c4.py
   EXPECT: DOCTOR_COUNTS
   EVIDENCE: MET exit=0 marker-found :: DOCTOR_COUNTS
5. settings.json: Stop review off, brightdata off, frontend-design plugin gone.
   CHECK: python3 -c "import json;d=json.load(open('settings.json'));e=d['enabledPlugins'];assert d['env']['ENABLE_STOP_REVIEW']=='0';assert e['brightdata-plugin@synced'] is False;assert 'frontend-design@claude-plugins-official' not in e;print('SETTINGS_OK')"
   EXPECT: SETTINGS_OK
   EVIDENCE: MET exit=0 marker-found :: SETTINGS_OK
6. No repo doc still claims security-guidance costs 0 tokens (positive control first).
   CHECK: pat='security-guidance.*0 tokens|0 tokens.*security-guidance'; echo 'security-guidance (0 tokens)' | grep -qE "$pat" || exit 1; if grep -rnE "$pat" install-plugins.sh agents/plugin-advisor.md; then exit 1; fi; echo DOCS_OK
   EXPECT: DOCS_OK
   EVIDENCE: MET exit=0 marker-found :: DOCS_OK
7. Routing: Ship/PR routes to ship-feature, the gstack-off list no longer names ship/context-save, deploy's table no longer routes to land-and-deploy/setup-deploy; the 21st trio is out of full/web/web-full/design and off the Design Review line. [gated 2026-09-28]
   CHECK: grep -qE '^- Ship / PR → ship-feature' CLAUDE.global.md && ! grep -qE 'Ship / PR → ship \(' CLAUDE.global.md && ! grep -q 'context-save' CLAUDE.global.md && ! grep -qE 'land-and-deploy|setup-deploy' skills/deploy/SKILL.md && ! grep -q '21st-ui-review' CLAUDE.global.md && ! grep -lE '^21st-(ai|ui-explore|ui-review)([[:space:]]|$)' lib/profiles/full.profile lib/profiles/web.profile lib/profiles/web-full.profile lib/profiles/design.profile && echo ROUTING_OK
   EXPECT: ROUTING_OK
   EVIDENCE: MET exit=0 marker-found :: ROUTING_OK
8. Hermetic profile census suite green: baseline fixture passes, each of the three mutants is detected for its own reason. [challenge 2026-09-28]
   CHECK: out=$(make test suite=lib/tests/profile-census.test.sh 2>&1); echo "$out" | grep -qE 'FAIL=[1-9]' && { echo "$out" | tail -15; exit 1; }; for k in FIXTURE_BASELINE_OK FIXTURE_REMOVED_DETECTED FIXTURE_SUPERSET_DETECTED FIXTURE_FULLGAP_DETECTED; do echo "$out" | grep -q "$k" || { echo "missing $k"; exit 1; }; done; echo "$out" | grep -qE 'PASS=[1-9]' && echo SUITE_GREEN
   EXPECT: SUITE_GREEN
   EVIDENCE: MET exit=0 marker-found :: SUITE_GREEN
9. shellcheck clean on every touched shell file; doctrine-citers census and the four new hermetic suites green, existing profile/toggle suites still green. [challenge 2026-09-28]
   CHECK: shellcheck link.sh doctor.sh install-plugins.sh update-all.sh lib/profile.sh lib/toggle-external.sh lib/gstack-links.sh lib/gstack-removed.sh lib/doctor-skills.sh lib/tests/profile-census.test.sh lib/tests/gstack-removed.test.sh lib/tests/gstack-links.test.sh lib/tests/doctor-skills.test.sh && for s in doctrine-citers gstack-removed gstack-links doctor-skills profile-default profile-set-managed toggle-external-repo-resolution; do out=$(make test suite=lib/tests/$s.test.sh 2>&1) || { echo "$s rc"; exit 1; }; echo "$out" | grep -qE 'FAIL=[1-9]' && { echo "$s FAIL"; exit 1; }; done; echo SHELL_DOCTRINE_OK
   EXPECT: SHELL_DOCTRINE_OK
   EVIDENCE: MET exit=0 marker-found :: SHELL_DOCTRINE_OK
10. Profile docs name the superset profile and full's new meaning: skills/profile/SKILL.md table, README.md (`/profile` row and `make profile` lines), USAGE.md `/profile` row.
11. install-plugins.sh STEP 5 carries two notes (frontend-design@claude-plugins-official never installed: byte-identical duplicate of the managed skills-external copy; brightdata-plugin@synced kept disabled: account-synced, keyless-useless, its bright-data-mcp skill would hijack WebFetch/WebSearch) and the summary line describes security-guidance truthfully (hooks + out-of-band LLM reviews, quota not context).
12. agents/plugin-advisor.md describes security-guidance's real mechanics (regex on Edit/Write, agentic review on commit/push, Stop review disabled by env) and drops the "Hook-only / 0 tokens" wording.
13. CHANGELOG.md `[Unreleased]` entry describing the prune (Removed / Changed / Fixed as fits Keep a Changelog).
14. The 9 removed gstack skills are removed from every profile that listed them (dev, backend, web, web-full, design, full), not only from full.
15. `full` carries every entry of every other non-max profile, minus the 9 removed names, the 21st trio and the allowlisted exceptions (each with a reason in the census test). [gated 2026-09-28 — user rule "full does what each profile does"]
   CHECK: python3 .claude/tasks/contracts/2026-09-28-skill-catalog-prune-0554.oracles/c15.py
   EXPECT: FULL_UNION_OK
   EVIDENCE: MET exit=0 marker-found :: FULL_UNION_OK
16. Live tree after `bash lib/profile.sh set full`: none of the 9 removed nor the 5 parked names resolves under `~/.claude/skills/`, and `profile current` names full. [challenge 2026-09-28: apply is additive, set parks]
   CHECK: bash lib/profile.sh set full >/dev/null 2>&1; bad=""; for n in ship land-and-deploy setup-deploy autoplan context-save learn careful guard design-shotgun make-pdf diagram 21st-ai 21st-ui-explore 21st-ui-review; do [ -e "$HOME/.claude/skills/$n" ] && bad="$bad $n"; done; [ -z "$bad" ] || { echo "live:$bad"; exit 1; }; [ -e "$HOME/.claude/skills/browse" ] || { echo browse-missing; exit 1; }; [ "$(bash lib/profile.sh current 2>/dev/null | awk '{print $1}')" = full ] && echo LIVE_CLEAN
   EXPECT: LIVE_CLEAN
   EVIDENCE: MET exit=0 marker-found :: LIVE_CLEAN
17. `gstack on` and `toggle-external.sh enable gstack` skip the removed names (hermetic suite, see criterion 9), and both scripts source lib/gstack-removed.sh.
   CHECK: grep -q 'gstack-removed.sh' lib/profile.sh && grep -q 'gstack-removed.sh' lib/toggle-external.sh && grep -q 'gstack_is_removed' lib/profile.sh && grep -q 'gstack_is_removed' lib/toggle-external.sh && echo DENYLIST_WIRED
   EXPECT: DENYLIST_WIRED
   EVIDENCE: MET exit=0 marker-found :: DENYLIST_WIRED
18. Neither install-plugins.sh nor update-all.sh carries its own copy of the helper-link block; link.sh and both installers go through lib/gstack-links.sh. [confirmation pass 2026-09-28]
   CHECK: grep -q 'gstack-links.sh' link.sh && grep -q 'gstack-links.sh' install-plugins.sh && grep -q 'gstack-links.sh' update-all.sh && ! grep -q 'ln -sf "$GSTACK_DIR/browse/dist"' install-plugins.sh && ! grep -q 'ln -sf "$GSTACK_SRC/browse/dist"' link.sh && ! grep -q 'ln -sf "$GSTACK_DIR/bin"' update-all.sh && echo LINKS_SHARED
   EXPECT: LINKS_SHARED
   EVIDENCE: MET exit=0 marker-found :: LINKS_SHARED

## FILE SCOPE
- lib/profiles/full.profile, lib/profiles/max.profile (new), lib/profiles/{dev,backend,web,web-full,design}.profile
- lib/tests/profile-census.test.sh, lib/tests/gstack-removed.test.sh, lib/tests/gstack-links.test.sh, lib/tests/doctor-skills.test.sh (new)
- lib/gstack-removed.sh (orchestrator-written), lib/gstack-links.sh, lib/doctor-skills.sh (new); lib/profile.sh, lib/toggle-external.sh (denylist)
- link.sh, doctor.sh, update-all.sh (helper-link block), install-plugins.sh (STEP 2 helper-link block, STEP 5 comments, summary lines)
- lib/tests/{profile-default,profile-set-managed,toggle-external-repo-resolution}.test.sh (fixture copy of lib/gstack-removed.sh only)
- settings.json (env block + enabledPlugins only)
- agents/plugin-advisor.md
- CLAUDE.global.md (Skill routing lines + Design work Review line only), skills/deploy/SKILL.md (routing table rows only)
- skills/profile/SKILL.md, README.md, USAGE.md, CHANGELOG.md
- Orchestrator-only: .claude/tasks/**, .claude/memory/**
