# CONTRACT — docker-mount-deny (phase 2 residual, TODO.md:89)
- date: 2026-11-15 | flow: bugfix | branch: bugfix/docker-mount-deny (off develop)
- status: active

## REQUEST (verbatim — IMMUTABLE)
Phase 2 residual (TODO.md:89, security gate 2026-10-23, "Not folded by phase 2 (2026-11-02): needs its own bench rows"): docker host-root mount spellings uncovered by settings.json deny: `--volume /:/x`, `-v=/:/x`, `--mount type=bind,source=/,...` (the deny covers `Bash(docker run * -v /:/*)` only). Prove each spelling with a harmless analogue (`--settings` one-rule file) before adding the deny rows; push-guard T41 lists the new rows.

## CLARIFICATIONS
- [gated 2026-11-15, challenge r1-r3] plan .claude/tasks/plans/2026-11-14-docker-mount-deny-1400.md § r3 wins: 7 shapes × 4 prefixes, no bare leading `*`, bench in .claude/tasks/plans/2026-11-14-docker-mount-bench/ first, only bench-proven shapes land, self-denial hygiene, legacy row removal is the user's hand edit, residual list in TODO.

## ACCEPTANCE CRITERIA
1. Bench present with a result row per case and every control RAN.
   CHECK: cd /home/bchanot/Documents/claude/.claude/tasks/plans/2026-11-14-docker-mount-bench && test -s results.tsv && awk -F'\t' '$1=="control" && $3!="RAN"' results.tsv | wc -l
   EXPECT: 0
   EVIDENCE: MET exit=0 marker-found :: 0
2. push-guard suite green (T41 lists every new row).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test suite=lib/tests/push-guard.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
3. settings.json valid JSON.
   CHECK: cd /home/bchanot/Documents/claude && jq -e .permissions.deny settings.json >/dev/null && echo JSON-OK
   EXPECT: JSON-OK
   EVIDENCE: MET exit=0 marker-found :: JSON-OK
4. Every gating bench row hits its want; MEASURE rows reported; residual TODO line present; make test green (manual).

## FILE SCOPE
settings.json (permissions.deny, autoMode.soft_deny docker entry widened additively), lib/tests/push-guard.test.sh (T41 heredoc), .claude/tasks/plans/2026-11-14-docker-mount-bench/ (new), .claude/tasks/TODO.md:89.
