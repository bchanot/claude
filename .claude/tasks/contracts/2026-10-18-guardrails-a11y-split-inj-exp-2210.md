# CONTRACT — guardrails-a11y-split-inj-exp
- date: 2026-10-18 | flow: ship-feature | branch: develop (feature branch at STEP 4)
- status: active

## REQUEST (verbatim — IMMUTABLE)
User message (typed):
"en vrai sur le skill guardrails , on va separer l'Accessibilite : Tout au clavier (focus visible), un texte alternatif a chaque image, un label sur chaque champs. ET on va ajouter aux guardrails la recherche de faille sql / injections sur bdd et aussi faire attention a ce que pas trop d'info soit visible sur le navigateur (console, network, dnas inspecter l'element"

Pre-brainstorm answers (AskUserQuestion, same turn):
- "Séparer a11y" → Skill autonome /a11y: nouveau skill avec son propre rapport et son parcours clavier; reprend les règles A11Y du scanner; /guardrails ne les contrôle plus; /web-validate garde le WCAG complet.
- "Noms" → injection + exposure: domaines `injection` (règles INJ-*) et `exposure` (règles EXP-*).
- "Portée exposure" → Statique + sonde en direct: le scanner repère dans le code les console.log de données, source maps publiques, état hydraté (__NEXT_DATA__) avec champs sensibles, commentaires et attributs data-* internes, erreurs détaillées renvoyées au client. La sonde GET existante vérifie aussi les réponses réelles (en-têtes, source maps servies, corps des erreurs, champs en trop).

Skill arguments ($ARGUMENTS to /ship-feature):
"Evolve the guardrails skill (skills/guardrails). Decisions already made by the user, do not re-ask: (1) Accessibility becomes a standalone skill /a11y: it takes over the A11Y-* rules and the Tab-only keyboard walk-through (keyboard reachability with visible focus, alt text on every image, a label on every field), has its own report and fix loop, and /guardrails stops checking the a11y domain (secure-by-default.md section 2, guardrails description and --domain list, scan.py DOMAINS, tests and docs updated; /web-validate keeps full WCAG). (2) Two new guardrails domains named `injection` (rule prefix INJ-) and `exposure` (rule prefix EXP-). `injection`: static search for SQL injection and DB injection (string concatenation or interpolation into SQL, raw query calls, unparameterized ORM raw escapes, NoSQL operator injection, shell/command injection into DB tooling), with proof via the existing fix loop. `exposure`: make sure not too much information is visible in the browser (console, network tab, element inspector): static rules for console.log of data, public source maps, hydrated state such as __NEXT_DATA__ carrying sensitive fields, internal comments and data-* attributes, verbose errors or stack traces returned to the client, over-wide API responses; PLUS extend the read-only GET probe (probe.py) to check real responses (source maps served, error bodies, extra fields). Update rules/secure-by-default.md, references/checks.md, SKILL.md, test-prompts.json, tests (lib/tests/guardrails-scan.test.sh and probe test), README/CHANGELOG, profiles and model-router rows if citers need it. Current git state: on develop with two pre-existing uncommitted changes (mods/model-router/routing.json, settings.json) that are not part of this task."

## CLARIFICATIONS
Q: Separate a11y how? / A: standalone skill /a11y (own report, own keyboard walk, own fix loop); /guardrails drops the domain; /web-validate keeps full WCAG.
Q: New domain names? / A: `injection` (INJ-*) and `exposure` (EXP-*).
Q: Exposure scope? / A: static rules + the existing read-only GET probe extended to real responses.
Pass B (STEP 2 PLAN, 2026-10-18): none. The design approved at the brainstorm gate settled every visible, public-name and scope choice: rule ids and severities, `skills/a11y/scripts/a11y_checks.py`, markers A11Y-CLEAR / A11Y-NO-NEW, report `.claude/audits/A11Y.md`, `rules/a11y.md` (lazy), probe plan keys `exposure.scripts` / `exposure.error_routes`, GUARDRAILS_JWT2 reused as bearer by the fields probe, profiles audit/dev/web/web-full/full/max, CHANGELOG bullet amended in place plus a new /a11y bullet. [gated 2026-10-18]
Amendment 2026-10-19 (after the plan challenge, before implementation; shown at the validation gate): criteria 4, 5 and 11 read the real module path `skills/a11y/scripts/a11y_checks.py`, require the file to exist and require a non-zero rule count, so an empty glob can no longer pass them vacuously.

## ACCEPTANCE CRITERIA
1. `skills/a11y/SKILL.md` exists, with frontmatter `name: a11y` and an `effort:` matching its routing.json row.
   CHECK: test -f 'skills/a11y/SKILL.md' && grep -q '^name: a11y$' 'skills/a11y/SKILL.md' && echo A11Y-SKILL-PRESENT
   EXPECT: A11Y-SKILL-PRESENT
   EVIDENCE: MET exit=0 marker-found :: A11Y-SKILL-PRESENT
2. /guardrails no longer scans a11y: `scan.py --domain a11y` is a usage error (exit 2) and the default run lists no `[a11y]` block.
   CHECK: python3 -B 'skills/guardrails/scripts/scan.py' 'lib/tests/fixtures/guardrails-good' --domain a11y >/dev/null 2>&1; [ $? -eq 2 ] && ! python3 -B 'skills/guardrails/scripts/scan.py' 'lib/tests/fixtures/guardrails-good' | grep -q '^\[a11y\]' && echo A11Y-DOMAIN-GONE
   EXPECT: A11Y-DOMAIN-GONE
   EVIDENCE: MET exit=0 marker-found :: A11Y-DOMAIN-GONE
3. /guardrails scans `injection` and `exposure`: both appear in the `scanned:` line on the clean fixture, and the clean fixture still reports ` 0 FAIL, 0 WARN`.
   CHECK: out=$(python3 -B 'skills/guardrails/scripts/scan.py' 'lib/tests/fixtures/guardrails-good'); echo "$out" | grep '^scanned:' | grep -q 'injection' && echo "$out" | grep '^scanned:' | grep -q 'exposure' && echo "$out" | grep -q ' 0 FAIL, 0 WARN' && echo INJ-EXP-SCANNED-CLEAN
   EXPECT: INJ-EXP-SCANNED-CLEAN
   EVIDENCE: MET exit=0 marker-found :: INJ-EXP-SCANNED-CLEAN
4. Every INJ-* and EXP-* rule the scanner can emit has a mutant in `lib/tests/guardrails-scan.test.sh` (one `mutant` call per rule id found in the checks modules).
   CHECK: n=0; missing=0; for r in $(grep -ho '"\(INJ\|EXP\)-[A-Z0-9-]*"' skills/guardrails/scripts/checks/*.py | tr -d '"' | sort -u); do n=$((n+1)); grep -q "$r" lib/tests/guardrails-scan.test.sh || { echo "no mutant: $r"; missing=1; }; done; [ $n -ge 15 ] && [ $missing -eq 0 ] && echo INJ-EXP-MUTANTS-PRESENT
   EXPECT: INJ-EXP-MUTANTS-PRESENT
   EVIDENCE: MET exit=0 marker-found :: INJ-EXP-MUTANTS-PRESENT
5. The A11Y-* rules still run, from the /a11y skill's scanner (`skills/a11y/scripts/a11y_checks.py`), on the a11y fixture, and each A11Y rule keeps a mutant in the a11y test suite. [amended 2026-10-19: real path, file must exist, at least 5 rules]
   CHECK: test -f 'skills/a11y/scripts/a11y_checks.py' && { n=0; missing=0; for r in $(grep -ho '"A11Y-[A-Z0-9-]*"' skills/a11y/scripts/a11y_checks.py | tr -d '"' | sort -u); do n=$((n+1)); grep -q "$r" lib/tests/a11y-scan.test.sh || { echo "no mutant: $r"; missing=1; }; done; [ $n -ge 5 ] && [ $missing -eq 0 ] && echo A11Y-MUTANTS-PRESENT; }
   EXPECT: A11Y-MUTANTS-PRESENT
   EVIDENCE: MET exit=0 marker-found :: A11Y-MUTANTS-PRESENT
6. probe.py has exposure probes and the probe suite exercises OPEN and CLOSED for each one.
   CHECK: grep -q 'def probe_exposure' 'skills/guardrails/scripts/probe.py' && grep -c 'exposure' 'lib/tests/guardrails-probe.test.sh' | awk '$1>=2{exit 0} {exit 1}' && echo EXP-PROBE-TESTED
   EXPECT: EXP-PROBE-TESTED
   EVIDENCE: MET exit=0 marker-found :: EXP-PROBE-TESTED
7. Guardrails scan and probe suites, and the new a11y suite, are green.
   CHECK: make test suite='lib/tests/guardrails-scan.test.sh lib/tests/guardrails-probe.test.sh lib/tests/a11y-scan.test.sh' >/dev/null 2>&1 && echo GUARDRAILS-SUITES-GREEN
   EXPECT: GUARDRAILS-SUITES-GREEN
   EVIDENCE: MET exit=0 marker-found :: GUARDRAILS-SUITES-GREEN
8. Censuses that bite on a new skill are green: effort-routing, profile-census, skill-routing-census, model-routing, loops-light.
   CHECK: make test suite='lib/tests/effort-routing.test.sh lib/tests/profile-census.test.sh lib/tests/skill-routing-census.test.sh lib/tests/model-routing.test.sh lib/tests/loops-light.test.sh' >/dev/null 2>&1 && echo CENSUS-GREEN
   EXPECT: CENSUS-GREEN
   EVIDENCE: MET exit=0 marker-found :: CENSUS-GREEN
9. No stale six-domain list or "five domains" wording survives in the skill, rules, agents, README, USAGE or CHANGELOG Unreleased.
   CHECK: ! grep -rn 'api,hosting,a11y,supabase,messaging,functions' skills/guardrails rules agents README.md USAGE.md >/dev/null && ! grep -n 'five domains\|five guardrail\|five baseline' rules/secure-by-default.md agents/interviewer.md README.md >/dev/null && echo NO-STALE-DOMAIN-LIST
   EXPECT: NO-STALE-DOMAIN-LIST
   EVIDENCE: MET exit=0 marker-found :: NO-STALE-DOMAIN-LIST
10. shellcheck clean on the shell surface.
   CHECK: shellcheck *.sh hooks/*.sh lib/*.sh && echo SHELLCHECK-CLEAN
   EXPECT: SHELLCHECK-CLEAN
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK-CLEAN
11. `references/checks.md` documents every INJ-* and EXP-* rule the scanner emits, and the a11y skill has its own rule reference for every A11Y-* rule. [amended 2026-10-19: real a11y path, file must exist, at least 5 rules]
   CHECK: missing=0; for r in $(grep -ho '"\(INJ\|EXP\)-[A-Z0-9-]*"' skills/guardrails/scripts/checks/*.py | tr -d '"' | sort -u); do grep -q "$r" skills/guardrails/references/checks.md || { echo "undocumented: $r"; missing=1; }; done; test -f 'skills/a11y/scripts/a11y_checks.py' && { n=0; for r in $(grep -ho '"A11Y-[A-Z0-9-]*"' skills/a11y/scripts/a11y_checks.py | tr -d '"' | sort -u); do n=$((n+1)); grep -rq "$r" skills/a11y/references/ || { echo "undocumented: $r"; missing=1; }; done; [ $n -ge 5 ] && [ $missing -eq 0 ] && echo RULES-DOCUMENTED; }
   EXPECT: RULES-DOCUMENTED
   EVIDENCE: MET exit=0 marker-found :: RULES-DOCUMENTED
12. The two pre-existing diffs (mods/model-router/routing.json dialog decisions, settings.json env-key move) are not swept into a feature commit: a routing.json commit on the branch contains only the a11y row. (judgement: read `git log -p develop..HEAD -- mods/model-router/routing.json settings.json`)
13. The scanner stays read-only, stdlib-only, FAIL/WARN/MANUAL only; the probe stays GET/HEAD/OPTIONS plus the opt-in POST burst, never fuzzes, same-host redirects only (judgement against BDR-120 invariants and probe doctrine).
14. The /a11y keyboard walk-through, report and fix loop are specified in its SKILL.md, with the walk marked "not done" when no browser tool is available (judgement).
15. Rule/heading/label citers patched in the same change: secure-by-default.md section numbering and title, guardrails description and argument-hint, interviewer.md domain count, README/USAGE/CHANGELOG, web-validate/guardrails routing boundaries (judgement, grep-by-discipline per BDR-100).
16. Both CLIs run on the shared engine: `skills/guardrails/scripts/scanner.py` defines `class Catalogue`, and both `scan.py` files import it (the a11y one through `importlib.import_module` after its `sys.path` insert, so no `noqa` suppression; oracle amended 2026-10-19 at GATE 1 iteration 1). [gated 2026-10-19]
   CHECK: grep -q '^class Catalogue' 'skills/guardrails/scripts/scanner.py' && grep -q '^import scanner' 'skills/guardrails/scripts/scan.py' && grep -Eq '^(import scanner|scanner = importlib\.import_module\("scanner"\))' 'skills/a11y/scripts/scan.py' && echo SHARED-ENGINE
   EXPECT: SHARED-ENGINE
   EVIDENCE: MET exit=0 marker-found :: SHARED-ENGINE
17. The guardrails and a11y descriptions are 1024 bytes or fewer (BDR-014). [gated 2026-10-19]
   CHECK: g=$(awk 'NR==4' skills/guardrails/SKILL.md | sed 's/^description: //' | wc -c); a=$(awk 'NR==4' skills/a11y/SKILL.md | sed 's/^description: //' | wc -c); [ "$g" -le 1024 ] && [ "$a" -le 1024 ] && echo "DESC-$g-$a-OK"
   EXPECT: -OK
   EVIDENCE: MET exit=0 marker-found :: DESC-1005-906-OK
18. The accessibility doctrine is a lazy rule: `rules/a11y.md` carries a `paths:` frontmatter, `rules/web-building.md` points at it, and `rules/secure-by-default.md` no longer has an Accessibility section. [gated 2026-10-19]
   CHECK: grep -q '^paths:' 'rules/a11y.md' && grep -q 'rules/a11y.md' 'rules/web-building.md' && ! grep -qi '^## [0-9]*\. Accessibility' 'rules/secure-by-default.md' && echo A11Y-RULE-LAZY
   EXPECT: A11Y-RULE-LAZY
   EVIDENCE: MET exit=0 marker-found :: A11Y-RULE-LAZY
19. The exposure probe fails closed: the probe suite asserts SKIPPED for a refused fields route and for a listed script answering 404, and the probe source validates every plan path. [gated 2026-10-19]
   CHECK: grep -q 'fields on a 401 is SKIPPED' 'lib/tests/guardrails-probe.test.sh' && grep -q 'answers 404 is SKIPPED' 'lib/tests/guardrails-probe.test.sh' && grep -q 'def _plan_paths' 'skills/guardrails/scripts/probe.py' && echo PROBE-FAIL-CLOSED
   EXPECT: PROBE-FAIL-CLOSED
   EVIDENCE: MET exit=0 marker-found :: PROBE-FAIL-CLOSED
20. The security-auditor keeps its scanner scope at `api,supabase` (no gate widening). [gated 2026-10-19]
   CHECK: grep -q -- '--domain api,supabase' 'agents/security-auditor.md' && echo AUDITOR-SCOPE-KEPT
   EXPECT: AUDITOR-SCOPE-KEPT
   EVIDENCE: MET exit=0 marker-found :: AUDITOR-SCOPE-KEPT
21. `/a11y` is registered: routing row `"a11y": "reflect"`, present in the full and max profiles, `effort: high` in its frontmatter. [gated 2026-10-19]
   CHECK: grep -q '"a11y": "reflect"' 'mods/model-router/routing.json' && grep -q '^a11y ' 'lib/profiles/full.profile' && grep -q '^a11y ' 'lib/profiles/max.profile' && grep -q '^effort: high$' 'skills/a11y/SKILL.md' && echo A11Y-REGISTERED
   EXPECT: A11Y-REGISTERED
   EVIDENCE: MET exit=0 marker-found :: A11Y-REGISTERED
22. `CLAUDE.global.md` stays at 320 lines and its routing line reads "W3C + WCAG conformance → web-validate". [gated 2026-10-19]
   CHECK: [ "$(wc -l < CLAUDE.global.md)" -eq 320 ] && grep -q 'W3C + WCAG conformance → web-validate' CLAUDE.global.md && echo GLOBAL-320
   EXPECT: GLOBAL-320
   EVIDENCE: MET exit=0 marker-found :: GLOBAL-320
23. The exposure probe is documented as a production-build check with dev-server OPENs marked as dev artefacts, in the guardrails skill and its reference. [gated 2026-10-19]
   CHECK: grep -q 'dev artefact' 'skills/guardrails/SKILL.md' && grep -q 'dev artefact' 'skills/guardrails/references/checks.md' && echo PROD-BUILD-CAVEAT
   EXPECT: PROD-BUILD-CAVEAT
   EVIDENCE: MET exit=0 marker-found :: PROD-BUILD-CAVEAT
24. `/web-validate` no longer carries the bare "a11y" and "accessibility" triggers and points the basics at /a11y. [gated 2026-10-19]
   CHECK: ! grep -q '"a11y"' 'skills/web-validate/SKILL.md' && grep -q '/a11y' 'skills/web-validate/SKILL.md' && echo WEB-VALIDATE-BOUNDARY
   EXPECT: WEB-VALIDATE-BOUNDARY
   EVIDENCE: MET exit=0 marker-found :: WEB-VALIDATE-BOUNDARY

## FILE SCOPE
- skills/guardrails/SKILL.md, scripts/scanner.py (new engine), scripts/scan.py, scripts/probe.py, scripts/checks/{common,injection,exposure,supabase,passwords}.py, scripts/checks/a11y.py (moved to skills/a11y/scripts/a11y_checks.py), references/checks.md, test-prompts.json
- skills/a11y/** (new: SKILL.md, scripts/scan.py, scripts/a11y_checks.py, references/checks.md, test-prompts.json)
- rules/secure-by-default.md, rules/a11y.md (new, lazy), rules/web-building.md (two fragments point at rules/a11y.md)
- skills/seo/SKILL.md, skills/harden/SKILL.md (routing citers)
- lib/tests/guardrails-scan.test.sh, lib/tests/guardrails-probe.test.sh, lib/tests/a11y-scan.test.sh (new), lib/tests/fixtures/guardrails-good/**, lib/tests/fixtures/a11y-good/** (new, if split)
- lib/tests/model-routing.test.sh, lib/tests/loops-light.test.sh (lock lists), lib/profiles/*.profile, mods/model-router/routing.json (a11y row only)
- agents/interviewer.md, agents/security-auditor.md (if the domain subset changes), agents/bugfixer.md (if /a11y reuses it)
- lib/verify-secure-loop.md, lib/contract-interview.md (flow enum, if /a11y gets the guardrails circuit)
- README.md, USAGE.md, CHANGELOG.md, CLAUDE.global.md (routing line, only within the 320 budget)
- skills/web-validate/SKILL.md (trigger boundary), skills/onboard/SKILL.md (a11y dispatch, if rerouted)
- docs/superpowers/specs/2026-10-18-guardrails-a11y-split-design.md, docs/superpowers/plans/2026-10-18-guardrails-a11y-split.md (ship-feature transient artifacts, committed during the run for the SDD reviewers, auto-purged by `gitflow finish`, BDR-065; the plan was approved at the STEP 3 validation gate) [gated 2026-10-19]
