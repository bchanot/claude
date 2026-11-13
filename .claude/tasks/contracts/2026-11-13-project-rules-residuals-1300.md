# CONTRACT — project-rules-residuals (phase 0 leftovers, block H1)
- date: 2026-11-13 | flow: bugfix | branch: bugfix/project-rules-residuals (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Phase 0 / 0b leftovers (extract-hardening 14a93e3, lib/project-rules.sh): `emit`: reuse `_rules_out_path_ok` (today `-e` only, a dangling link at the target is followed) and check the `mkdir -p` and `> "$2"` rc (today "emitted" rc 0 on a failed write). `extract` rewrite failure mid-`cat` (ENOSPC/EIO after the truncation of `$src`): keep `$tmp` and name it on stderr instead of `rm -f` (today "$src not rewritten" can be false, the two copies gone; onboarder S1 rollback covers the split path, not direct lib use). shortcut `_rules_out_path_ok`: the `..` check is lexical, a symlinked parent component (`.claude` or `.claude/rules` pointing elsewhere) is not resolved; upgrade = `cd -P` on the parent dir, compare with `$PWD` (no portable `realpath -m`).

## CLARIFICATIONS
- [gated 2026-11-13, challenge r2] the cat-failure branch keeps BOTH `$tmp` and `$out` (the request's "keep $tmp" alone would drop the section's last copy); callers onboarder.md:144 / scaffolder.md:86-89 read an rc 2 not ending in ` exists` as STOP. Compare with `pwd -P` on both sides (the request's `$PWD` is logical under `-C`). Plan: .claude/tasks/plans/2026-11-13-project-rules-residuals-1300.md § r2.

## ACCEPTANCE CRITERIA
1. Physical parent check present; `$PWD` never used; CDPATH neutralized.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c "CDPATH='' cd -P" lib/project-rules.sh)$(grep -c '\$PWD' lib/project-rules.sh)$(grep -c 'must stay under the project' lib/project-rules.sh)
   EXPECT: 101
   EVIDENCE: MET exit=0 marker-found :: 101
2. emit routes through `_rules_out_path_ok` and checks the write; extract's cat-failure branch keeps both files.
   CHECK: cd /home/bchanot/Documents/claude && echo $(grep -c '_rules_out_path_ok' lib/project-rules.sh)$(grep -c 'not written' lib/project-rules.sh)$(grep -c 'rewrite failed' lib/project-rules.sh)
   EXPECT: 321
   EVIDENCE: MET exit=0 marker-found :: 321
3. Suite green with the new cases (escape refused for extract and emit, `-C <symlink>` accepted, emit write failure named, T9h re-asserted).
   CHECK: cd /home/bchanot/Documents/claude && bash lib/tests/project-rules.test.sh 2>&1 | tail -1
   EXPECT: FAIL=0
   EVIDENCE: MET exit=0 marker-found :: PASS=153 FAIL=0
4. New cases exist.
   CHECK: cd /home/bchanot/Documents/claude && grep -c 'must stay under the project\|link-esc\|cannot create' lib/tests/project-rules.test.sh | grep -c '^[3-9]'
   EXPECT: 1
   EVIDENCE: MET exit=0 marker-found :: 1
5. Callers patched.
   CHECK: cd /home/bchanot/Documents/claude && grep -c 'any other rc 2 → STOP' agents/onboarder.md agents/scaffolder.md | grep -c ':1$'
   EXPECT: 2
   EVIDENCE: MET exit=0 marker-found :: 2
6. shellcheck -x clean on lib/project-rules.sh and lib/tests/project-rules.test.sh; new/changed lines ≤ 80 cols; `_rules_out_path_ok` ≤ 25 logic lines.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -x lib/project-rules.sh lib/tests/project-rules.test.sh && echo SC-OK
   EXPECT: SC-OK
   EVIDENCE: MET exit=0 marker-found :: SC-OK
7. make test green (manual, bun on PATH).
   (manual: run 2026-11-13 on the bugfixer diff, `PATH=$HOME/.bun/bin:$PATH make test` → "SUITE: all GREEN / all suites green", rc=0)

## FILE SCOPE
lib/project-rules.sh, lib/tests/project-rules.test.sh, agents/onboarder.md (:144 one line), agents/scaffolder.md (:86-89 one line). TODO phase 0 lines → STEP 8.
