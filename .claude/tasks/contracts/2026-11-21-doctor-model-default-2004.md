# CONTRACT — doctor-model-default
- date: 2026-11-21 | flow: hotfix | branch: bugfix/doctor-model-default
- status: active
- run-base: 0d0ba78484e3356b661f3bc8577ed970c9036974

## REQUEST (verbatim — IMMUTABLE)
doctor.sh:155-156 warns "settings.json model is opus[1m] (tracked default is opus)" on every run, but the user decided 2026-11-21 to keep `opus[1m]` as the tracked default ("laisse le opus 1m"; committed 2bcb75b 2026-11-16). Fix: doctor passes on `opus[1m]` (the tracked default) and warns on anything else, naming opus[1m] as the default.

## CLARIFICATIONS
none — request complete

## ACCEPTANCE CRITERIA
1. Symptom gone: doctor.sh passes on `opus[1m]` with "settings.json model is opus[1m]" and its warn branch names `opus[1m]` as the tracked default; no "tracked default is opus)" text left.
   CHECK: grep -q '^if \[ "$_m" = "opus\[1m\]" \]; then pass "settings.json model is opus\[1m\]"$' doctor.sh && grep -q '(tracked default is opus\[1m\])"; fi$' doctor.sh && [ "$(grep -c 'tracked default is opus)' doctor.sh)" -eq 0 ] && bash doctor.sh 2>&1 | grep -q 'settings.json model is opus\[1m\]$' && echo DOCTOR_OK
   EXPECT: DOCTOR_OK
   EVIDENCE: MET exit=0 marker-found :: DOCTOR_OK
2. Shell lint stays clean on doctor.sh.
   CHECK: shellcheck doctor.sh && echo LINT_OK
   EXPECT: LINT_OK
   EVIDENCE: MET exit=0 marker-found :: LINT_OK

## FILE SCOPE
- doctor.sh
- this contract (run artifact)
