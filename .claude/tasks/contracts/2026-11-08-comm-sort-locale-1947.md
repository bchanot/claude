# CONTRACT — comm-sort-locale
- date: 2026-11-08 | flow: hotfix | branch: bugfix/comm-sort-locale (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
oui regarde le warning comm

(context: memory-commit.sh printed "comm: file 2 is not in sorted order" / "comm: input is not in sorted order" on a commit; reproduced: uutils coreutils 0.10.0 sort collates by locale, uutils comm expects byte order.)

## CLARIFICATIONS

## ACCEPTANCE CRITERIA
1. _partial_stages sorts and compares in the C locale; no "sorted order" warning; both partial stages listed.
   CHECK: cd /home/bchanot/Documents/claude && grep -q 'LC_ALL=C comm' lib/memory-commit.sh && systemd-run --user --scope -q -p TasksMax=256 make test suite=lib/tests/run-deterministic.sh </dev/null > /home/bchanot/.cache/claude-tmp/claude-1000/-home-bchanot-Documents-claude/049658c4-3f30-4849-8ba6-906177262d8a/scratchpad/comm.out 2>&1 && echo C1_GREEN
   EXPECT: C1_GREEN
   EVIDENCE: MET exit=0 marker-found :: C1_GREEN
2. shellcheck clean.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck lib/memory-commit.sh lib/tests/run-deterministic.sh && echo C2_LINT
   EXPECT: C2_LINT
   EVIDENCE: MET exit=0 marker-found :: C2_LINT

## FILE SCOPE
- lib/memory-commit.sh
- lib/tests/run-deterministic.sh
