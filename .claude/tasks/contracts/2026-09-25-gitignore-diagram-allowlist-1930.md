# CONTRACT — gitignore-diagram-allowlist
- date: 2026-09-25 | flow: hotfix | branch: bugfix/gitignore-diagram-allowlist
- status: active

## REQUEST (verbatim — IMMUTABLE)
> `.gitignore` : l'allowlist des symlinks gstack (`skills/<name>`, lignes 3-56) ne contient pas `skills/diagram`, donc le symlink créé par `profile.sh apply full` apparaît untracked (`?? skills/diagram`). Ajouter la ligne `skills/diagram` à sa place alphabétique dans cette liste (LRN-025 : l'allowlist doit couvrir TOUS les skills gstack toggleables). Un seul fichier, une ligne.

## CLARIFICATIONS
none — pass A silent autofill (hotfix weight); pass B: nothing visible open
(the slot is alphabetical: between `skills/devex-review` and `skills/document-release`).

## ACCEPTANCE CRITERIA
1. Symptom gone: `skills/diagram` is ignored and no longer untracked.
   CHECK: git check-ignore -q skills/diagram && [ -z "$(git status --short -- skills/diagram)" ] && echo DIAGRAM_IGNORED
   EXPECT: DIAGRAM_IGNORED
   EVIDENCE: MET exit=0 marker-found :: DIAGRAM_IGNORED
2. Build/tests green: the allowlist covers every gstack skill that full lists (LRN-025 census) — every bare gstack entry of full.profile is matched by an ignore rule.
   CHECK: miss=0; for s in $(grep -v '^#' lib/profiles/full.profile | awk 'NF==1{print $1}'); do git check-ignore -q "skills/$s" || { echo "not ignored: skills/$s"; miss=1; }; done; [ "$miss" -eq 0 ] && echo ALLOWLIST_COVERS_FULL
   EXPECT: ALLOWLIST_COVERS_FULL
   EVIDENCE: MET exit=0 marker-found :: ALLOWLIST_COVERS_FULL

## FILE SCOPE
- .gitignore (one line added)
