# CONTRACT — doctor-skilloverrides-residue (block H7)
- date: 2026-11-14 | flow: hotfix | branch: bugfix/doctor-skilloverrides-residue (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
doctor.sh skillOverrides residue (block H7, TODO H line "doctor skillOverrides residue" + TODO:64 follow-up candidate): doctor.sh:145-152 user-scope residue check compares only `jq -S .enabledPlugins` HEAD vs working settings.json; a UI write into user-scope `skillOverrides` dirties tracked settings.json unseen. Fix: compare `jq -S '{enabledPlugins, skillOverrides}'` on both sides (HEAD and work), pass/skip/warn messages name both keys. 1 file, doctor.sh only.

## CLARIFICATIONS
- [gated 2026-11-14] challenge step skipped: diagnostic-only warn, one jq filter widened on both sides, no control-flow change.

## ACCEPTANCE CRITERIA
1. Both sides read the two keys; no `.enabledPlugins`-only filter left in the check.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c "jq -S '{enabledPlugins, skillOverrides}'" doctor.sh)$(grep -c 'jq -S .enabledPlugins' doctor.sh)
   EXPECT: 20
   EVIDENCE: MET exit=0 marker-found :: 20
2. Messages name both keys.
   CHECK: cd /home/bchanot/Documents/claude && grep -c 'enabledPlugins and skillOverrides\|enabledPlugins/skillOverrides' doctor.sh | grep -c '^[2-9]'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
3. shellcheck clean on doctor.sh.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -x doctor.sh && echo SC-OK
   EXPECT: SC-OK
   EVIDENCE: MET exit=0 marker-found :: SC-OK
4. make doctor prints the pass line on the clean tree; make test green (manual, bun on PATH).

## FILE SCOPE
doctor.sh (:145-152). TODO lines → STEP 6.
