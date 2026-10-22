# CONTRACT — mods-validate-advisory (bugfix of lib/tests/mods.test.sh)

## REQUEST (verbatim)
lib/tests/mods.test.sh:57 fails on develop: Claude Code CLI 2.1.306 `claude plugin validate` prints an advisory "plugin directory warning" section (ICON_MISSING) and the suite treats any warning as a failure. Exclude that advisory section only; every other validate warning stays blocking. Suite: make test suite=lib/tests/mods.test.sh. Pre-existing on develop (proven via git archive baseline in the previous session).

## CLARIFICATIONS
- Internal (after the challenge, 3 lenses + 1 re-challenge): the "exclusion" is the CLI's own contract, `claude plugin validate --strict`: per-file warnings → rc 1, the plugin-directory advisory never changes the rc (only under `--profile directory`, never requested). No prose scraping is left in the suite.
- Internal: the regression proof is a positive control run through the gate's own helper on two scratch manifests (warnfix rc 1, cleanfix rc 0), written by the suite under a script-level `mktemp -d`; no tracked fixture.
- Internal: three historical contracts carry the old scrape as oracle (2026-10-08-model-router-w1a-1533.md:22, 2026-10-08-model-router-floor-1835.md:22, 2026-10-09-model-router-tiers-1237.md:23); left unedited, named at CAPITALIZE.
- Plan: `.claude/tasks/plans/2026-10-22-mods-validate-advisory-2004.md` (r3).
- GATE 1 ECARTS(2) → disposition (main loop): both gaps = criterion 6 on `mods/model-router/routing.json` (`confirmed.phases.audit` written by the mod on the main loop's first `route(phase="audit")`, register.ts:2054, after GATE 0 ran). Not an executor edit, not staged with this fix; commit of that dialog write = user call. Criterion 6 holds on the committed diff.

## ACCEPTANCE CRITERIA
1. The suite is green on CLI 2.1.306 with the ICON_MISSING advisory present in validate's output.
   CHECK: make test suite=lib/tests/mods.test.sh 2>&1 | grep -E '^mods: ' | sed 's/^/n=/'
   EXPECT: n=mods: 6 pass, 0 fail
   EVIDENCE: MET exit=0 marker-found :: n=mods: 6 pass, 0 fail
2. The validate verdict is the exit code of `--strict`, through one helper used by check_cli and the control; no `warning` scrape and no `Validation passed` scrape remain.
   CHECK: f=lib/tests/mods.test.sh; a=$(grep -c 'plugin validate --strict "' $f); b=$(grep -c 'validate_strict "' $f); c=$(grep -ciE "grep -qi? *'?warning|Validation passed" $f); echo "$a/$b/$c"
   EXPECT: 1/3/0
   EVIDENCE: MET exit=0 marker-found :: 1/3/0
3. Positive control: the clean scratch manifest passes `--strict` and the warning one fails it, both through the helper, both reported as suite checks.
   CHECK: make test suite=lib/tests/mods.test.sh 2>&1 | grep -cE '^PASS strict control: (clean fixture passes --strict|per-file warnings fail --strict)$'
   EXPECT: 2
   EVIDENCE: MET exit=0 marker-found :: 2
4. The control is not vacuous: with `--strict` removed from the helper the control goes red (the warning fixture passes).
   CHECK: S=/tmp/claude-1000/-home-bchanot-Documents-claude/09872630-52ba-43d2-b0a9-f9fe56869e15/scratchpad/chk; mkdir -p "$S"; sed 's/validate --strict "\$1"/validate "$1"/' lib/tests/mods.test.sh > "$S/m.sh"; MODS_ROOT=$PWD bash "$S/m.sh" 2>&1 | grep -c '^FAIL strict control: per-file warnings fail --strict'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
5. The scratch dir is script-level with an EXIT trap (never inside a function), and the ko tail names the rerun command.
   CHECK: f=lib/tests/mods.test.sh; a=$(grep -c "^WORK=\"\$(mktemp -d)\"; trap 'rm -rf \"\$WORK\"' EXIT$" $f); b=$(grep -c 'rerun: claude plugin validate --strict' $f); echo "$a/$b"
   EXPECT: 1/1
   EVIDENCE: MET exit=0 marker-found :: 1/1
6. Only lib/tests/mods.test.sh changes; shellcheck clean on it.
   CHECK: a=$(git status --short | grep -v '^?? .claude/' | grep -vc '^ M lib/tests/mods.test.sh$'); b=$(shellcheck lib/tests/mods.test.sh >/dev/null 2>&1 && echo ok || echo ko); echo "$a/$b"
   EXPECT: 0/ok
   EVIDENCE: MET exit=0 marker-found :: 0/ok
7. The suite still fails loudly when no mod exists (never vacuous): MODS_ROOT on an empty dir.
   CHECK: d=$(mktemp -d); MODS_ROOT=$d bash lib/tests/mods.test.sh 2>&1 | grep -c '^FAIL no mod found'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1

## FILE SCOPE
lib/tests/mods.test.sh
