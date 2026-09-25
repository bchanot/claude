# CONTRACT — full-profile-web-doc-skills
- date: 2026-09-25 | flow: hotfix | branch: bugfix/full-profile-web-doc-skills
- status: active

## REQUEST (verbatim — IMMUTABLE)
User (after the assistant listed what `full` excludes and offered `scrape`, `skillify`, `diagram`, `make-pdf`):
> oui je veux bien

/hotfix $ARGUMENTS:
> Ajouter les skills gstack `scrape`, `skillify`, `diagram` et `make-pdf` au profil `full` (`lib/profiles/full.profile`), user go après ma proposition : outils web/doc que superpowers n'apporte pas, exclus de full par BDR-017 ; le reste de la liste exclue (ios-*, connect-chrome doublon, outillage interne gstack) reste exclu.

## CLARIFICATIONS
none — pass A silent autofill (hotfix weight); pass B: placement inside the
profile file is internal (sections "Browser + dogfooding" for scrape/skillify,
"Docs + translation" for diagram/make-pdf), nothing visible left open.

## ACCEPTANCE CRITERIA
1. Symptom gone: `bash lib/profile.sh show full --plain` lists `scrape`,
   `skillify`, `diagram`, `make-pdf` as gstack entries; no other profile changed.
   CHECK: out=$(bash lib/profile.sh show full --plain 2>/dev/null); for s in scrape skillify diagram make-pdf; do printf '%s\n' "$out" | grep -qE "(^|[[:space:]])$s([[:space:]]|$)" || exit 1; done; [ "$(git diff --name-only HEAD -- lib/profiles | grep -vc '^lib/profiles/full.profile$')" -eq 0 ] && echo FULL_HAS_4
   EXPECT: FULL_HAS_4
   EVIDENCE: MET exit=0 marker-found :: FULL_HAS_4
2. Build/tests green: the profile suites still pass.
   CHECK: bash lib/tests/profile-default.test.sh 2>&1 | tail -1 | grep -qE '^PASS=[0-9]+ FAIL=0$' && bash lib/tests/profile-set-managed.test.sh 2>&1 | tail -1 | grep -qE '^PASS=[0-9]+ FAIL=0$' && echo SUITES_OK
   EXPECT: SUITES_OK
   EVIDENCE: MET exit=0 marker-found :: SUITES_OK
3. (judgement) The four names resolve upstream (`skills-external/gstack/<name>/SKILL.md` exists — LRN-022), so `set full` emits no `missing:` warning for them.

## FILE SCOPE
- lib/profiles/full.profile (4 lines added, nothing removed)
