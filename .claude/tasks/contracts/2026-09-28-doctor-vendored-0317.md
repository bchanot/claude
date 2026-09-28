# CONTRACT — doctor-vendored
- date: 2026-09-28 | flow: feat (ad-hoc dispatch, /feat gates replayed by the orchestrator) | branch: feature/doctor-vendored-skills
- status: active

## REQUEST (verbatim — IMMUTABLE)
> Add a `make doctor` check for the externally vendored skills, which doctor.sh ignores today (it only checks the gstack submodule). New `lib/doctor-vendored.sh` exposing `check_vendored_skills <repo> <claude_home> [profile_file]`, sourced and called by doctor.sh in a new "Vendored skills" section right after the gstack section. Expected state: (1) every plugins.lock.json entry with `managed_by: curl` has its files under `skills-external/`: `skills` as a list → `<name>/SKILL.md` each; `skills` as a dict → every listed file; single-file `path` shape (emil-design-eng) → `<key>/SKILL.md`; (2) every name in link.sh's `EXTERNAL_SKILLS` array has `skills-external/<name>/SKILL.md` and, when the name is listed in the active profile file (or when no profile file is given), a symlink `<claude_home>/skills/<name>` → `<repo>/skills-external/<name>`; a name absent from the active profile is reported as parked, not failed. Outcomes use doctor's helpers: `fail` "<name>: <what is missing> — run: make plugin" for files, `fail` "<name>: symlink missing/wrong — run: make link (or: bash lib/profile.sh apply <profile>)" for links, `info` "<name>: parked by profile <p>", `pass` "<name>: vendored + linked" otherwise, `warn` when the lock or link.sh cannot be read. Hermetic suite `lib/tests/doctor-vendored.test.sh`. README's doctor line names the new check. User go 2026-09-28 ("ok ajoute le check doctor").

## CLARIFICATIONS
- The lib defines fallback `pass/fail/warn/info` only when the caller has not (same `declare -F` guard as lib/vendor-skills.sh) so doctor.sh's counters (`ERRORS`, `WARNS`) keep working.
- Lock parsing with python3 via argv (never string-spliced); `EXTERNAL_SKILLS` parsed from link.sh with a single-purpose grep/sed of the array line(s), tolerant to the multi-line array.
- Active profile in doctor.sh: resolve the way lib/profile.sh's `active_profile()` does (read its code; the cache path it reads; no `claude` invocation); pass the profile file path `lib/profiles/<name>.profile` to the check; if it cannot be resolved, call the check without a profile file (every external expected linked).
- A name in the profile counts whatever its label column says (external / personal), match on the first token of the line.
- Functions ≤ 25 logic lines, 80-char lines, ≤ 5 params, ≤ 5 locals.
- Suite: fixture repo under mktemp with a fake lock (list, dict with a references/ file, single-path shapes), a fake link.sh holding an `EXTERNAL_SKILLS=(...)` array, a fake `<claude_home>/skills` dir and a fake profile file; cases print `PASS <NAME>`: ALL_PRESENT, FILE_MISSING, DICT_FILES_COMPLETE (dict entry missing one references file → fail names that file), SYMLINK_MISSING_ACTIVE, SYMLINK_WRONG_TARGET, SYMLINK_PARKED (name absent from the profile → info, no fail), NO_PROFILE_EXPECTS_LINK, LOCK_UNREADABLE (warn, rc 0). `PASS=n FAIL=m` summary.
- doctor.sh is read-only; the executor MAY run `bash doctor.sh` live for the criterion below (it inspects, never writes).

## ACCEPTANCE CRITERIA
1. Lib exists and doctor.sh is wired.
   CHECK: [ -f lib/doctor-vendored.sh ] && grep -q '^check_vendored_skills()' lib/doctor-vendored.sh && grep -q 'doctor-vendored.sh' doctor.sh && grep -q 'check_vendored_skills' doctor.sh && echo WIRED
   EXPECT: WIRED
   EVIDENCE: MET exit=0 marker-found :: WIRED
2. Hermetic suite green with every case.
   CHECK: out=$(make test suite=lib/tests/doctor-vendored.test.sh 2>&1); echo "$out" | grep -qE "FAIL=[1-9]" && { echo "$out" | tail -15; exit 1; }; for k in ALL_PRESENT FILE_MISSING DICT_FILES_COMPLETE SYMLINK_MISSING_ACTIVE SYMLINK_WRONG_TARGET SYMLINK_PARKED NO_PROFILE_EXPECTS_LINK LOCK_UNREADABLE; do echo "$out" | grep -q "PASS $k" || { echo "missing PASS $k"; exit 1; }; done; echo SUITE_GREEN
   EXPECT: SUITE_GREEN
   EVIDENCE: MET exit=0 marker-found :: SUITE_GREEN
3. Live doctor on this machine: the eleven externals pass.
   CHECK: out=$(bash doctor.sh 2>&1); ok=1; for s in emil-design-eng frontend-design design-motion-principles observability-and-instrumentation deprecation-and-migration ci-cd-and-automation scroll-world-storytelling build-threejs-scroll-worlds scroll-scrubbed-visual-sequence scroll-scrubbed-word-reveal scroll-progress-timeline; do echo "$out" | grep -qE "✓.*\b$s\b" || { echo "no pass line for $s"; ok=0; }; done; [ "$ok" -eq 1 ] && echo LIVE_PASS
   EXPECT: LIVE_PASS
   EVIDENCE: MET exit=0 marker-found :: LIVE_PASS
4. shellcheck clean.
   CHECK: shellcheck doctor.sh lib/doctor-vendored.sh lib/tests/doctor-vendored.test.sh && echo SHELLCHECK_OK
   EXPECT: SHELLCHECK_OK
   EVIDENCE: MET exit=0 marker-found :: SHELLCHECK_OK
5. README names the check; doctrine citations resolve.
   CHECK: grep -qi "vendored" README.md && out=$(make test suite=lib/tests/doctrine-citers.test.sh 2>&1) && ! echo "$out" | grep -qE "FAIL=[1-9]" && echo DOC_OK
   EXPECT: DOC_OK
   EVIDENCE: MET exit=0 marker-found :: DOC_OK

## FILE SCOPE
- lib/doctor-vendored.sh (new), lib/tests/doctor-vendored.test.sh (new)
- doctor.sh (source line + one section), README.md (the `make doctor` / `bash doctor.sh` description lines)

## PLAN
1. Read doctor.sh (helpers lines 12-15, `check_symlink` 38, the gstack section ~90-118, `check_automode` 258 + its call 310, the summary), lib/vendor-skills.sh (lock read pattern, fallback helpers), lib/profile.sh `active_profile()` + `read_profile()`, link.sh lines 90-105, one hermetic suite for the style.
2. lib/doctor-vendored.sh: `_dv_lock_expectations` (python3 argv → lines `<name>\t<file>`), `_dv_link_names` (parse EXTERNAL_SKILLS), `_dv_profile_has <file> <name>`, `_dv_check_files`, `_dv_check_link`, `check_vendored_skills`.
3. doctor.sh: source the lib; section header in the file's style; resolve the profile file; call the check.
4. README lines; suite; run criteria 1-5.
